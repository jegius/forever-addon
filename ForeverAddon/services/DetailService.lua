-- ForeverAddon — детальный скан лотов (лестницы цен через SendSearchQuery)
local addonName, ns = ...

local Detail = {}
ns.Detail = Detail

local frame = CreateFrame("Frame")
local queue = {}
local active = nil        -- itemID
local activeKey = nil
local callback = nil
local done = 0
local total = 0
local startedAt = 0
local pendingTimer = nil
local watchdog = nil
local throttle = 0.8      -- лимит Blizzard 100 запросов/мин; держим 75/мин
local MAX_LADDER = 400
local lastRequestAt = 0

local function now()
  return (GetTime and GetTime()) or time()
end

local function safe(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c = pcall(fn, ...)
  if ok then return a, b, c end
  return nil
end

local function fullResults(fn, arg)
  if type(fn) ~= "function" then return true end
  local ok, value = pcall(fn, arg)
  if not ok then return true end
  return value ~= false
end

local function cancelTimer(timer)
  if timer and timer.Cancel then pcall(timer.Cancel, timer) end
end

function Detail:Init()
  frame:SetScript("OnEvent", function(_, event, ...) Detail:OnEvent(event, ...) end)
  frame:RegisterEvent("ITEM_SEARCH_RESULTS_ADDED")
  frame:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
  frame:RegisterEvent("COMMODITY_SEARCH_RESULTS_ADDED")
  frame:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
  frame:RegisterEvent("COMMODITY_SEARCH_RESULTS_RECEIVED")
end

function Detail:IsActive()
  return active ~= nil or #queue > 0
end

function Detail:Progress()
  return done, total
end

function Detail:Scan(itemIDs, cb, label)
  if self:IsActive() then
    ns:Print(ns.L("DETAIL_BUSY"))
    return false
  end
  if not (C_AuctionHouse and C_AuctionHouse.SendSearchQuery and C_AuctionHouse.MakeItemKey) then
    ns:Print(ns.L("NO_AH_API"))
    return false
  end

  queue = {}
  local seen = {}
  for _, descriptor in ipairs(itemIDs or {}) do
    local itemID, key
    if type(descriptor) == "number" then
      itemID = descriptor
    elseif type(descriptor) == "table" then
      itemID = descriptor.itemID or (descriptor.key and descriptor.key.itemID)
      key = descriptor.key
    end
    if type(itemID) == "number" and itemID > 0 then
      local dedupe = tostring(itemID)
      if key then
        dedupe = dedupe .. ":" .. tostring(key.itemLevel or 0) .. ":" .. tostring(key.itemSuffix or 0)
      end
      if not seen[dedupe] then
        seen[dedupe] = true
        queue[#queue + 1] = { itemID = itemID, key = key }
      end
    end
  end
  if #queue == 0 then
    if cb then cb(0, 0) end
    return false
  end

  callback = cb
  done = 0
  total = #queue
  startedAt = now()
  lastRequestAt = 0
  ns:Print(ns.L("DETAIL_STARTED", total, label or ""))
  if ns.UI and ns.UI.SetDetailStatus then
    ns.UI:SetDetailStatus(ns.L("DETAIL_STARTED", total, label or ""))
  end
  self:Next()
  return true
end

function Detail:Cancel(reason)
  cancelTimer(pendingTimer); pendingTimer = nil
  cancelTimer(watchdog); watchdog = nil
  active = nil; activeKey = nil; queue = {}
  lastRequestAt = 0
  if ns.UI and ns.UI.SetDetailStatus then ns.UI:SetDetailStatus("") end
  if reason then ns:Print(ns.L("DETAIL_CANCELLED", reason)) end
  callback = nil; done = 0; total = 0
end

function Detail:Next()
  if active then return end
  if ns.Auction and ns.Auction.IsOpen and not ns.Auction:IsOpen() then
    self:Cancel(ns.L("AH_CLOSED"))
    return
  end
  if #queue == 0 then
    self:Finish()
    return
  end

  local entry = table.remove(queue, 1)
  local itemID = entry.itemID
  local key = entry.key
  if not key then
    local okKey, madeKey = pcall(C_AuctionHouse.MakeItemKey, itemID)
    if not okKey or type(madeKey) ~= "table" then
      done = done + 1
      C_Timer.After(0.05, function() Detail:Next() end)
      return
    end
    key = madeKey
  end

  active = itemID
  activeKey = key
  local sorts = {}
  if Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price then
    sorts[1] = { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false }
  end
  local sent = pcall(C_AuctionHouse.SendSearchQuery, key, sorts, false)
  if not sent then
    active = nil; activeKey = nil
    done = done + 1
    C_Timer.After(0.05, function() Detail:Next() end)
    return
  end

  local token = itemID
  watchdog = C_Timer.NewTimer(2.5, function()
    if active == token then Detail:Process(token) end
  end)
end

function Detail:OnEvent(event, arg)
  if not active then return end
  if event == "COMMODITY_SEARCH_RESULTS_RECEIVED" then
    -- без payload: обрабатываем текущий предмет
  elseif string.find(event, "COMMODITY", 1, true) then
    if arg and arg ~= active then return end
  else
    local id = type(arg) == "table" and arg.itemID or nil
    if id and id ~= active then return end
  end
  if pendingTimer then return end
  local token = active
  pendingTimer = C_Timer.NewTimer(0.25, function()
    pendingTimer = nil
    if active == token then Detail:MaybeProcess(token) end
  end)
end

-- Ждём полные результаты поиска: SendSearchQuery может отдавать страницы,
-- а не всю лестницу сразу. Иначе флипы считаются по неполным данным.
function Detail:MaybeProcess(token)
  if active ~= token then return end

  local itemID = token
  local key = activeKey
  local commodityCount = safe(C_AuctionHouse.GetNumCommoditySearchResults, itemID)
  local itemCount = safe(C_AuctionHouse.GetNumItemSearchResults, key)
  local ready = false

  if type(commodityCount) == "number" and commodityCount > 0 then
    ready = fullResults(C_AuctionHouse.HasFullCommoditySearchResults, itemID)
    if not ready and now() - lastRequestAt > 0.4 then
      lastRequestAt = now()
      safe(C_AuctionHouse.RequestMoreCommoditySearchResults, itemID)
    end
  elseif type(itemCount) == "number" and itemCount > 0 then
    ready = fullResults(C_AuctionHouse.HasFullItemSearchResults, key)
    if not ready and now() - lastRequestAt > 0.4 then
      lastRequestAt = now()
      safe(C_AuctionHouse.RequestMoreItemSearchResults, key)
    end
  end

  if ready then
    self:Process(token)
  else
    C_Timer.After(0.2, function()
      if active == token then Detail:MaybeProcess(token) end
    end)
  end
end

function Detail:Collect(itemID, key)
  local ladder, qty = {}, 0

  local numCommodity = safe(C_AuctionHouse.GetNumCommoditySearchResults, itemID)
  if type(numCommodity) == "number" and numCommodity > 0 then
    for index = 1, math.min(numCommodity, MAX_LADDER) do
      local result = safe(C_AuctionHouse.GetCommoditySearchResultInfo, itemID, index)
      if type(result) == "table" and result.unitPrice and result.quantity and result.quantity > 0 then
        local price = math.floor(tonumber(result.unitPrice) or 0)
        if price > 0 then
          ladder[#ladder + 1] = { p = price, q = result.quantity }
          qty = qty + result.quantity
        end
      end
    end
  end

  if #ladder == 0 then
    local numItems = safe(C_AuctionHouse.GetNumItemSearchResults, key)
    if type(numItems) == "number" and numItems > 0 then
      for index = 1, math.min(numItems, MAX_LADDER) do
        local result = safe(C_AuctionHouse.GetItemSearchResultInfo, key, index)
        if type(result) == "table" and result.buyoutAmount and result.quantity and result.quantity > 0 then
          local unit = math.floor((tonumber(result.buyoutAmount) or 0) / result.quantity + 0.5)
          if unit > 0 then
            ladder[#ladder + 1] = { p = unit, q = result.quantity }
            qty = qty + result.quantity
          end
        end
      end
    end
  end

  return ladder, qty
end

function Detail:Process(itemID)
  cancelTimer(pendingTimer); pendingTimer = nil
  cancelTimer(watchdog); watchdog = nil
  if active ~= itemID then return end
  local key = activeKey
  active = nil; activeKey = nil

  local ladder, qty = self:Collect(itemID, key)
  if #ladder > 0 then
    ns.Market:ApplyDetail(itemID, ladder, qty)
  end
  done = done + 1

  if ns.UI and ns.UI.SetDetailStatus then
    ns.UI:SetDetailStatus(string.format(ns.L("DETAIL_PROGRESS", done, total)))
  end

  if #queue == 0 then
    self:Finish()
  else
    C_Timer.After(throttle, function()
      if Detail:IsActive() then Detail:Next() end
    end)
  end
end

function Detail:Finish()
  local elapsed = now() - (startedAt or now())
  local finished = done
  local cb = callback
  callback = nil
  queue = {}
  done = 0; total = 0
  lastRequestAt = 0
  if ns.UI and ns.UI.SetDetailStatus then ns.UI:SetDetailStatus("") end
  ns:Print(ns.L("DETAIL_DONE", finished, elapsed))
  if cb then pcall(cb, finished, elapsed) end
  if ns.UI then ns.UI:ScheduleRefresh() end
end
