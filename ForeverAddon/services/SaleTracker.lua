-- Mail/auction sale tracker. Mail is the only reliable client-side source
-- for "my auction sold" vs "my auction returned"; market-wide sale vs cancel
-- remains an estimate.
local addonName, ns = ...

local SaleTracker = {}
ns.SaleTracker = SaleTracker

local L = function(key, ...) return ns.L(key, ...) end
local frame

local function lower(value)
  return string.lower(tostring(value or ""))
end

local function isAuctionMail(sender, subject)
  local text = lower(sender) .. " " .. lower(subject)
  return text:find("аукцион", 1, true) or text:find("auction", 1, true)
end

local function classify(subject, money, hasItem)
  local text = lower(subject)
  if text:find("выигр", 1, true) or text:find("won", 1, true)
    or text:find("покуп", 1, true) or text:find("purchas", 1, true) then
    return "purchase"
  end
  if text:find("успеш", 1, true) or text:find("sold", 1, true)
    or text:find("продан", 1, true) then
    return "sold"
  end
  if text:find("истек", 1, true) or text:find("expired", 1, true) then
    return "returned"
  end
  if text:find("отмен", 1, true) or text:find("cancel", 1, true) then
    return "returned"
  end
  if (money or 0) > 0 and not hasItem then return "sold" end
  if hasItem then return "returned" end
  return "unknown"
end

local function parseItemID(link, text)
  local itemID = link and tonumber(link:match("item:(%d+)"))
  if itemID then return itemID end
  itemID = text and tonumber(text:match("item:(%d+)"))
  return itemID
end

local function ensureDB()
  local db = ns.db
  if not db then return nil end
  db.saleEvents = db.saleEvents or {}
  db.mailSeen = db.mailSeen or {}
  db.saleStats = db.saleStats or {}
  return db
end

function SaleTracker:Init()
  if frame then return end
  frame = CreateFrame("Frame")
  frame:SetScript("OnEvent", function(_, event)
    if event == "MAIL_SHOW" or event == "MAIL_INBOX_UPDATE" then
      self:ScanInbox()
    end
  end)
  for _, event in ipairs({ "MAIL_SHOW", "MAIL_INBOX_UPDATE" }) do
    pcall(frame.RegisterEvent, frame, event)
  end
end

function SaleTracker:ScanInbox()
  if not GetInboxNumItems or not GetInboxHeaderInfo then return 0 end
  local db = ensureDB()
  if not db then return 0 end
  local ok, total = pcall(GetInboxNumItems)
  if not ok or type(total) ~= "number" then return 0 end

  local added = 0
  for index = 1, total do
    local headerOk, _, _, sender, subject, money, _, _, hasItem, itemCount = pcall(GetInboxHeaderInfo, index)
    if headerOk and isAuctionMail(sender, subject) then
      local link
      if GetInboxItemLink then
        local linkOk, value = pcall(GetInboxItemLink, index, 1)
        if linkOk then link = value end
      end
      local text
      if GetInboxText then
        local textOk, value = pcall(GetInboxText, index)
        if textOk then text = value end
      end
      local itemID = parseItemID(link, text)
      local kind = classify(subject, money, hasItem)
      local signature = table.concat({
        tostring(sender or ""), tostring(subject or ""), tostring(money or 0),
        tostring(itemID or 0), tostring(hasItem and 1 or 0), tostring(itemCount or 0),
      }, "|")
      if not db.mailSeen[signature] then
        db.mailSeen[signature] = time()
        local event = {
          t = time(), kind = kind, itemID = itemID, money = money or 0,
          subject = subject, sender = sender, count = itemCount or 0,
        }
        db.saleEvents[#db.saleEvents + 1] = event
        while #db.saleEvents > 100 do table.remove(db.saleEvents, 1) end
        local key = itemID or 0
        local stats = db.saleStats[key] or { sold = 0, returned = 0, purchase = 0 }
        if kind == "sold" then stats.sold = stats.sold + 1
        elseif kind == "returned" then stats.returned = stats.returned + 1
        elseif kind == "purchase" then stats.purchase = stats.purchase + 1 end
        stats.lastT = event.t
        db.saleStats[key] = stats
        added = added + 1
      end
    end
  end
  db.mailScanAt = time()
  -- Keep the dedupe table bounded.
  local seen = 0
  for key in pairs(db.mailSeen) do
    seen = seen + 1
    if seen > 500 then db.mailSeen[key] = nil; seen = seen - 1 end
  end
  if added > 0 and ns.UI then ns.UI:ScheduleRefresh() end
  return added
end

function SaleTracker:GetStats(itemID)
  local db = ns.db
  if not db or not db.saleStats then return nil end
  return db.saleStats[itemID] or nil
end

function SaleTracker:GetRecent(limit)
  local db = ns.db
  local result = {}
  for index = #(db and db.saleEvents or {}), 1, -1 do
    result[#result + 1] = db.saleEvents[index]
    if limit and #result >= limit then break end
  end
  return result
end

function SaleTracker:GetTotals()
  local db = ns.db
  local totals = { sold = 0, returned = 0, purchase = 0 }
  for _, stats in pairs(db and db.saleStats or {}) do
    totals.sold = totals.sold + (stats.sold or 0)
    totals.returned = totals.returned + (stats.returned or 0)
    totals.purchase = totals.purchase + (stats.purchase or 0)
  end
  return totals
end

function SaleTracker:FormatStats(stats)
  if not stats then return L("SALES_NONE") end
  return L("SALES_FORMAT", stats.sold or 0, stats.returned or 0, stats.purchase or 0)
end
