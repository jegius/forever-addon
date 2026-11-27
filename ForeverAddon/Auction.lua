-- ForeverAddon — сканирование аукциона (browse summary)
local addonName, ns = ...

local Auction = {}
ns.Auction = Auction

local L = function(key, ...) return ns.L(key, ...) end

local frame = CreateFrame("Frame")
local scanning = false
local scan = nil
local ahOpen = false
local timeoutTimer = nil
local requestPending = false

local BROWSE_EVENTS = {
  "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
  "AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
  "AUCTION_HOUSE_BROWSE_FAILURE",
}

local function setEvents(register)
  if register then
    frame:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
    frame:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
    frame:RegisterEvent("AUCTION_HOUSE_BROWSE_FAILURE")
  else
    frame:UnregisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
    frame:UnregisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
    frame:UnregisterEvent("AUCTION_HOUSE_BROWSE_FAILURE")
  end
end

function Auction:IsScanning()
  return scanning
end

function Auction:GetLastScan()
  return ns.db and ns.db.scanLast or 0
end

function Auction:GetCooldown()
  local db = ns.db
  if not db then return 0 end
  local cooldown = db.settings.scanCooldown or 600
  local left = cooldown - (time() - (db.scanLast or 0))
  if left < 0 then return 0 end
  return left
end

function Auction:RefreshOpenState()
  ahOpen = false
  if AuctionHouseFrame and AuctionHouseFrame:IsShown() then
    ahOpen = true
  elseif AuctionFrame and AuctionFrame:IsShown() then
    ahOpen = true
  end
end

function Auction:IsOpen()
  return ahOpen
end

function Auction:Init()
  frame:SetScript("OnEvent", function(_, event, ...)
    Auction:OnEvent(event, ...)
  end)
  frame:RegisterEvent("AUCTION_HOUSE_SHOW")
  frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
  frame:RegisterEvent("AUCTION_HOUSE_DISABLED")
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  C_Timer.After(2, function()
    Auction:RefreshOpenState()
  end)
end

function Auction:OnEvent(event, ...)
  if event == "AUCTION_HOUSE_SHOW" then
    ahOpen = true
    if ns.UI then
      ns.UI:ScheduleRefresh()
    end

  elseif event == "AUCTION_HOUSE_CLOSED" or event == "AUCTION_HOUSE_DISABLED" then
    ahOpen = false
    if scanning then
      self:Abort(L("AH_CLOSED"))
    end
    if ns.Detail and ns.Detail:IsActive() then
      ns.Detail:Cancel(L("AH_CLOSED"))
    end
    if ns.UI then ns.UI:ScheduleRefresh() end

  elseif event == "PLAYER_ENTERING_WORLD" then
    self:RefreshOpenState()

  elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then
    if scanning then
      self:ProcessResults(C_AuctionHouse.GetBrowseResults())
    end

  elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
    if scanning then
      local added = ...
      self:ProcessResults(added)
    end

  elseif event == "AUCTION_HOUSE_BROWSE_FAILURE" then
    if scanning then
      self:Abort(L("ERR"))
    end
  end
end

function Auction:CanStart()
  if not ahOpen then
    return false, L("SCAN_NEED_AH")
  end
  if scanning then
    return false, L("SCAN_IN_PROGRESS")
  end
  local cooldown = self:GetCooldown()
  if cooldown > 0 then
    return false, L("SCAN_COOLDOWN", math.ceil(cooldown / 60))
  end
  if not C_AuctionHouse or not C_AuctionHouse.SendBrowseQuery then
    return false, L("NO_AH_API")
  end
  return true
end

function Auction:StartScan()
  local canStart, reason = self:CanStart()
  if not canStart then
    ns:Print(reason)
    return false
  end

  if ns.Detail and ns.Detail:IsActive() then
    ns.Detail:Cancel(L("DETAIL_CANCELLED", L("SCAN_STARTED")))
  end

  scan = {
    items = {},
    count = 0,
    started = GetTime(),
  }
  scanning = true
  requestPending = false
  setEvents(true)

  if timeoutTimer then
    timeoutTimer:Cancel()
  end
  timeoutTimer = C_Timer.NewTimer(120, function()
    if scanning then
      Auction:Abort(L("SCAN_TIMEOUT"))
    end
  end)

  ns:Print(L("SCAN_STARTED"))
  if ns.UI then ns.UI:SetScanStatus(L("SCAN_STARTED")) end
  local ok = pcall(C_AuctionHouse.SendBrowseQuery, {
    searchString = "",
    sorts = {},
    filters = {},
    itemClassFilters = {},
  })
  if not ok then
    self:Abort(L("ERR"))
    return false
  end
  if ns.UI then ns.UI:ScheduleRefresh() end
  return true
end

function Auction:AddResults(results)
  if not results then return end
  local items = scan.items

  for _, result in ipairs(results) do
    local key = result.itemKey
    if key and key.itemID then
      local itemID = key.itemID
      local minPrice = result.minPrice
      local quantity = result.totalQuantity or 0
      local itemLevel = key.itemLevel or 0
      local itemSuffix = key.itemSuffix or 0
      local battlePet = key.battlePetSpeciesID or 0
      local isGear = ns.Util:IsGearClass(itemID)

      -- Base keys for trade goods/consumables; gear variants aggregate by itemID,
      -- remembering the cheapest variant key for the detail scan.
      if itemID and minPrice and minPrice > 0 and quantity > 0 and battlePet == 0 then
        if isGear or (itemLevel == 0 and itemSuffix == 0) then
          local entry = items[itemID]
          local descriptor = {
            itemID = itemID,
            itemLevel = itemLevel,
            itemSuffix = itemSuffix,
            battlePetSpeciesID = 0,
          }
          if not entry then
            entry = {
              min = minPrice,
              qty = quantity,
              gear = isGear,
              key = descriptor,
            }
            items[itemID] = entry
          else
            if minPrice < entry.min then
              entry.min = minPrice
              entry.key = descriptor
            end
            if isGear then
              entry.qty = (entry.qty or 0) + quantity
            else
              entry.qty = math.max(entry.qty or 0, quantity)
            end
            entry.gear = entry.gear or isGear
          end
        end
      end
    end
  end
end

function Auction:ProcessResults(results)
  if not scanning then return end
  scan.count = scan.count + (results and #results or 0)
  self:AddResults(results)

  if ns.UI then
    ns.UI:SetScanStatus(L("SCAN_PROGRESS", scan.count))
  end

  local hasFull = true
  if C_AuctionHouse.HasFullBrowseResults then
    hasFull = C_AuctionHouse.HasFullBrowseResults() and true or false
  end
  if hasFull then
    self:Finish()
  else
    self:RequestMore()
  end
end

function Auction:RequestMore()
  if requestPending or not scanning then return end
  requestPending = true
  C_Timer.After(0.1, function()
    requestPending = false
    if scanning and not C_AuctionHouse.HasFullBrowseResults() then
      pcall(C_AuctionHouse.RequestMoreBrowseResults)
    end
  end)
end

function Auction:Finish()
  if not scanning then return end
  scanning = false
  requestPending = false
  setEvents(false)

  if timeoutTimer then
    timeoutTimer:Cancel()
    timeoutTimer = nil
  end

  local elapsed = GetTime() - (scan.started or GetTime())
  local data = scan.items
  local count = scan.count
  scan = nil

  ns.Market:ApplyScan(data, count, elapsed)
  ns:Print(L("SCAN_DONE", count, ns.Util:TableSize(data), elapsed))
  if ns.UI then
    ns.UI:SetScanStatus("")
    ns.UI:ScheduleRefresh()
  end

  local shortlist = ns.Market:GetCandidates(ns.db and ns.db.settings.detailItems or 60)
  if #shortlist > 0 and ns.Detail then
    ns.Detail:Scan(shortlist, function()
      if ns.UI then ns.UI:ScheduleRefresh() end
    end, L("DETAIL_LABEL"))
  end
end

function Auction:Abort(reason)
  if not scanning then return end
  scanning = false
  requestPending = false
  setEvents(false)
  if timeoutTimer then
    timeoutTimer:Cancel()
    timeoutTimer = nil
  end
  scan = nil
  ns:Print(L("SCAN_FAILED", reason or L("ERR")))
  if ns.UI then
    ns.UI:SetScanStatus("")
    ns.UI:ScheduleRefresh()
  end
end

function Auction:GetStatusText()
  if scanning then
    return L("SCAN_BTN_BUSY")
  end
  return L("SCAN_BTN")
end
