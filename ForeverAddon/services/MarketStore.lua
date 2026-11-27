local addonName, ns = ...
local Market = ns.Market or {}
ns.Market = Market

local function nowDay()
  return math.floor(time() / 86400)
end

function Market:RecordSample(itemID, minPrice, qty)
  if not minPrice or minPrice <= 0 then return end
  if not ns.Util:IsTrackedItem(itemID) then return end
  local db = ns.db
  if not db then return end
  local entry = db.prices[itemID]
  if not entry then return end

  local timestamp = time()
  local day = nowDay()

  local samples = entry.samples
  if not samples then
    samples = {}
    entry.samples = samples
  end
  samples[#samples + 1] = { t = timestamp, min = minPrice, qty = qty or 0 }
  if #samples > 20 then
    table.remove(samples, 1)
  end

  local history = entry.history
  if not history then
    history = {}
    entry.history = history
  end
  local record = history[day]
  if record then
    record.min = math.min(record.min, minPrice)
    record.qty = qty or record.qty
    record.n = (record.n or 0) + 1
  else
    history[day] = { min = minPrice, qty = qty or 0, n = 1 }
  end
end

function Market:ApplyScan(scanData, rows, elapsed)
  local db = ns.db
  if not db then return end
  local settings = db.settings
  local day = nowDay()
  local timestamp = time()
  local tracked = 0

  for itemID, data in pairs(scanData) do
    if itemID and data.min and data.min > 0 then
      local entry = db.prices[itemID]
      if not entry then
        entry = {}
        db.prices[itemID] = entry
      end

      entry.last = {
        min = data.min,
        qty = data.qty or 0,
        t = timestamp,
        key = data.key,
        gear = data.gear,
      }

      if ns.Util:IsTrackedItem(itemID) then
        tracked = tracked + 1
        if db.itemNames then
          db.itemNames[itemID] = ns.Util:ItemName(itemID)
        end
      end
      self:RecordSample(itemID, data.min, data.qty or 0)
    end
  end

  db.scanLast = timestamp
  db.scanRows = rows or 0
  db.scanItems = ns.Util:TableSize(scanData)
  db.scanDuration = elapsed or 0
  db.trackedItems = tracked
  db.priceVersion = (db.priceVersion or 0) + 1

  self:Prune()
  if ns.DB then ns.DB:Prune() end
end

function Market:Prune()
  local db = ns.db
  if not db then return end
  local cutoff = nowDay() - (db.settings.historyDays or 30)
  for _, entry in pairs(db.prices) do
    if entry.history then
      for day in pairs(entry.history) do
        if type(day) == "number" and day < cutoff then
          entry.history[day] = nil
        end
      end
    end
  end
end

function Market:ApplyDetail(itemID, list, totalQty)
  if type(list) ~= "table" or #list == 0 then return false end
  table.sort(list, function(a, b) return a.p < b.p end)

  local qty = totalQty or 0
  if qty <= 0 then
    for _, lot in ipairs(list) do qty = qty + (lot.q or 0) end
  end
  if qty <= 0 then return false end

  local function quantile(frac)
    local target = qty * frac
    local acc = 0
    for _, lot in ipairs(list) do
      acc = acc + (lot.q or 0)
      if acc >= target then return lot.p end
    end
    return list[#list].p
  end

  local minPrice = list[1].p
  local maxPrice = list[#list].p
  local p50 = quantile(0.5) or minPrice
  local buyQty = math.max(1, list[1].q or 1)
  local frac = math.min(0.95, (buyQty * 1.5) / qty)
  local resale = quantile(frac) or p50

  local entry = ns.DB:GetItem(itemID)
  entry.detail = {
    t = time(), min = minPrice, max = maxPrice,
    p50 = p50, resale = resale, qty = qty, lots = #list,
  }
  entry.last = entry.last or {}
  entry.last.min = minPrice
  entry.last.qty = qty
  entry.last.t = entry.detail.t
  if ns.db.itemNames then
    ns.db.itemNames[itemID] = ns.Util:ItemName(itemID)
  end

  self:RecordSample(itemID, minPrice, qty)
  ns.db.priceVersion = (ns.db.priceVersion or 0) + 1
  if ns.DB then ns.DB:Prune() end
  return true
end
function Market:ResetPrices()
  if ns.db then
    ns.db.prices = {}
    ns.db.itemNames = {}
    ns.db.scanLast = 0
    ns.db.scanRows = 0
    ns.db.scanItems = 0
    ns.db.scanDuration = 0
    ns.db.selectedItem = nil
  end
end

