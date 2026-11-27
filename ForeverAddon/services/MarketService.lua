local addonName, ns = ...
local Market = {}
ns.Market = Market

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
  return true
end

function Market:GetDetail(itemID)
  local entry = ns.db and ns.db.prices[itemID]
  return entry and entry.detail or nil
end

function Market:GetChartSeries(itemID, days)
  local series = {}
  local history = self:GetHistory(itemID, days)
  if #history > 0 then
    for _, record in ipairs(history) do
      series[#series + 1] = { t = record.day * 86400, min = record.min, qty = record.qty, kind = "day" }
    end
    return series
  end
  local entry = ns.db and ns.db.prices[itemID]
  if not entry then return series end
  if entry.samples then
    for _, sample in ipairs(entry.samples) do
      series[#series + 1] = { t = sample.t, min = sample.min, qty = sample.qty, kind = "sample" }
    end
  elseif entry.detail then
    series[1] = { t = entry.detail.t, min = entry.detail.min, qty = entry.detail.qty, kind = "scan" }
  elseif entry.last then
    series[1] = { t = entry.last.t, min = entry.last.min, qty = entry.last.qty, kind = "scan" }
  end
  return series
end

-- Короткий список предметов для детального скана (ликвидные товары/реагенты + gear).
function Market:GetCandidates(limit)
  local db = ns.db
  if not db then return {} end
  local settings = db.settings or {}
  local normalLimit = limit or settings.detailItems or 60
  local gearLimit = settings.detailGearItems or 20
  local gearMinPrice = settings.gearMinPrice or 5000
  local normal, gear = {}, {}

  for itemID, entry in pairs(db.prices) do
    local last = entry.last
    if last and last.min and last.min > 0 and (last.qty or 0) > 0 and ns.Util:IsTrackedItem(itemID) then
      local score = (last.min or 0) * (1 + math.log((last.qty or 0) + 1))
      if entry.detail then score = score * 0.6 end
      local descriptor = { itemID = itemID, key = last.key }
      if ns.Util:IsGearClass(itemID) then
        if last.min >= gearMinPrice then
          gear[#gear + 1] = { descriptor = descriptor, score = score }
        end
      else
        normal[#normal + 1] = { descriptor = descriptor, score = score }
      end
    end
  end

  table.sort(normal, function(a, b) return a.score > b.score end)
  table.sort(gear, function(a, b) return a.score > b.score end)

  local result = {}
  for index = 1, math.min(#normal, normalLimit) do
    result[#result + 1] = normal[index].descriptor
  end
  for index = 1, math.min(#gear, gearLimit) do
    result[#result + 1] = gear[index].descriptor
  end
  return result
end

-- Флипы из одного детального скана: покупаем дешёвый лот, продаём на resale.
function Market:GetStats()
  local db = ns.db
  local itemCount = 0
  local historyItems = 0
  local detailItems = 0
  if db then
    for _, entry in pairs(db.prices) do
      itemCount = itemCount + 1
      if entry.history then
        historyItems = historyItems + 1
      end
      if entry.detail then
        detailItems = detailItems + 1
      end
    end
  end
  return {
    items = itemCount,
    historyItems = historyItems,
    detailItems = detailItems,
    rows = db and db.scanRows or 0,
    lastScan = db and db.scanLast or 0,
    duration = db and db.scanDuration or 0,
  }
end

function Market:GetSelectedItem()
  return ns.db and ns.db.selectedItem or nil
end

function Market:SetSelectedItem(itemID)
  if ns.db then
    ns.db.selectedItem = itemID
    if itemID and ns.db.prices[itemID] and not ns.db.prices[itemID].history then
      -- Start tracking from the next scan; keep a point for today if possible.
      local entry = ns.db.prices[itemID]
      if entry.last then
        local history = {}
        history[nowDay()] = { min = entry.last.min, qty = entry.last.qty or 0, n = 1 }
        entry.history = history
      end
    end
  end
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

function Market:GetPrice(itemID) return ns.PriceService:GetPrice(itemID) end
function Market:GetQuantity(itemID) return ns.PriceService:GetQuantity(itemID) end
function Market:GetHistory(itemID, days) return ns.PriceService:GetHistory(itemID, days) end
function Market:GetHistoryDays(itemID) return ns.PriceService:GetHistoryDays(itemID) end
function Market:GetResale(itemID) return ns.PriceService:GetResale(itemID) end
function Market:GetMarketValue(itemID) return ns.PriceService:GetMarketValue(itemID) end
function Market:GetRecommendedPrice(itemID) return ns.PriceService:GetRecommendedPrice(itemID) end
function Market:GetLowOutlier(itemID) return ns.PriceService:GetLowOutlier(itemID) end
function Market:GetPriceStats(itemID) return ns.PriceService:GetPriceStats(itemID) end
function Market:GetFlips(limit) return ns.Flips:GetFlips(limit) end
function Market:GetDetailFlips(limit) return ns.Flips:GetDetailFlips(limit) end
function Market:GetFarmGroups() return ns.Flips:GetFarmGroups() end
