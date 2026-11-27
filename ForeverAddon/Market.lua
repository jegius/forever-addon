-- ForeverAddon — рыночная аналитика: история, флипы, фарм
local addonName, ns = ...

local Market = {}
ns.Market = Market

local function nowDay()
  return math.floor(time() / 86400)
end

local function median(values)
  local count = #values
  if count == 0 then return nil end
  table.sort(values)
  local middle = math.floor((count + 1) / 2)
  if count % 2 == 0 then
    return (values[middle] + values[middle + 1]) / 2
  end
  return values[middle]
end

-- Запись сэмпла и дневной истории для отслеживаемого предмета.
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

function Market:GetPrice(itemID)
  local entry = ns.db and ns.db.prices[itemID]
  if entry and entry.last then
    return entry.last.min
  end
  return nil
end

function Market:GetQuantity(itemID)
  local entry = ns.db and ns.db.prices[itemID]
  if entry and entry.last then
    return entry.last.qty or 0
  end
  return 0
end

function Market:GetHistory(itemID, days)
  local entry = ns.db and ns.db.prices[itemID]
  if not entry or not entry.history then return {} end
  days = days or ns.db.settings.maxChartDays or 30
  local today = nowDay()
  local result = {}
  for day = today - days + 1, today do
    local record = entry.history[day]
    if record then
      result[#result + 1] = {
        day = day,
        min = record.min,
        qty = record.qty or 0,
      }
    end
  end
  return result
end

function Market:GetHistoryDays(itemID)
  local entry = ns.db and ns.db.prices[itemID]
  if not entry or not entry.history then return 0 end
  local count = 0
  for _ in pairs(entry.history) do count = count + 1 end
  return count
end

-- Детальный скан: применяем лестницу цен лотов.
-- resale — цена следующего уровня после выкупа самого дешёвого лота.
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

function Market:GetResale(itemID)
  local entry = ns.db and ns.db.prices[itemID]
  if not entry then return nil end
  local detail = entry.detail
  if detail and detail.resale and detail.resale > 0 then return detail.resale end
  return self:GetMarketValue(itemID) or (entry.last and entry.last.min) or nil
end

-- Серия для графика: дневная история, иначе сэмплы/детальный скан.
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
function Market:GetDetailFlips(limit)
  local db = ns.db
  if not db then return {} end
  local settings = db.settings or {}
  local flips = {}
  for itemID, entry in pairs(db.prices) do
    local detail = entry.detail
    if detail and detail.min and detail.resale and detail.min > 0 and detail.resale > detail.min then
      local stats = self:GetPriceStats(itemID)
      local maxDeviation = settings.maxDeviation or 0.5
      local minHistoryDays = settings.minHistoryDays or 2
      local outlier = stats and (stats.days >= minHistoryDays or (stats.samples or 0) >= 3)
        and stats.median and stats.median > 0
        and stats.deviation and math.abs(stats.deviation) > maxDeviation
      if not outlier then
        local profit = detail.resale * 0.95 - detail.min
        local roi = profit / detail.min
        if profit >= (settings.minProfit or 100) and roi >= (settings.minROI or 0.10) then
          local lots = detail.lots or 1
          local spread = (detail.p50 and detail.p50 > 0) and (detail.resale / detail.p50) or 1
          local confidence = ns.Util:Clamp(lots / 5, 0.2, 1) * (spread <= 2.5 and 1 or 0.6)
          local qty = math.max(1, math.floor(detail.qty or 1))
          flips[#flips + 1] = {
            itemID = itemID,
            buy = detail.min,
            market = detail.resale,
            profit = profit,
            roi = roi,
            qty = qty,
            days = stats and stats.days or 0,
            confidence = confidence,
            score = profit * (1 + math.min(qty, 50) / 50) * confidence,
            source = "detail",
          }
        end
      end
    end
  end
  table.sort(flips, function(a, b) return a.score > b.score end)
  local max = limit or 100
  while #flips > max do table.remove(flips) end
  return flips
end

function Market:GetMarketValue(itemID)
  local entry = ns.db and ns.db.prices[itemID]
  if not entry then return nil end

  local history = entry.history
  if not history then
    return nil
  end

  local today = nowDay()
  local values = {}
  for offset = 0, 6 do
    local record = history[today - offset]
    if record and record.min then
      values[#values + 1] = record.min
    end
  end

  if #values >= 2 then
    return median(values)
  end

  local samples = entry.samples
  if samples and #samples >= 2 then
    local sampleValues = {}
    for _, sample in ipairs(samples) do
      sampleValues[#sampleValues + 1] = sample.min
    end
    return median(sampleValues)
  end

  local detail = entry.detail
  if detail and detail.p50 and detail.p50 > 0 then
    return detail.p50
  end

  if entry.last then
    return entry.last.min
  end
  return nil
end

function Market:GetRecommendedPrice(itemID)
  local median = self:GetMarketValue(itemID)
  if median and median > 0 then return median end
  local entry = ns.db and ns.db.prices[itemID]
  if not entry then return nil end
  if entry.detail and entry.detail.p50 and entry.detail.p50 > 0 then
    return entry.detail.p50
  end
  if entry.last and entry.last.min and entry.last.min > 0 then
    return entry.last.min
  end
  return nil
end

-- Возвращает: текущий минимум, медиану, отклонение (доля), флаг «подозрительно дёшево».
function Market:GetLowOutlier(itemID)
  local entry = ns.db and ns.db.prices[itemID]
  if not entry or not entry.last then return nil end
  local min = entry.last.min
  local median = self:GetRecommendedPrice(itemID)
  if not min or not median or median <= 0 then return nil end
  local settings = (ns.db and ns.db.settings) or {}
  local deviation = (min - median) / median
  local suspicious = deviation < -(settings.maxDeviation or 0.5)
  return min, median, deviation, suspicious
end

function Market:GetPriceStats(itemID)
  local entry = ns.db and ns.db.prices[itemID]
  if not entry then return nil end
  local min = entry.last and entry.last.min or nil
  local qty = entry.last and entry.last.qty or 0
  local medianValue = self:GetMarketValue(itemID)
  local days = self:GetHistoryDays(itemID)
  local samples = entry.samples and #entry.samples or 0
  local detail = entry.detail
  local deviation = nil
  if min and medianValue and medianValue > 0 then
    deviation = (min - medianValue) / medianValue
  end
  return {
    itemID = itemID,
    min = min,
    median = medianValue,
    qty = qty,
    days = days,
    samples = samples,
    deviation = deviation,
    lots = detail and detail.lots or 0,
  }
end

function Market:GetFlips(limit)
  local db = ns.db
  local settings = db.settings
  local flips = {}

  for itemID, entry in pairs(db.prices) do
    if entry.last and ns.Util:IsFlipItem(itemID) then
      local days = self:GetHistoryDays(itemID)
      local samples = entry.samples and #entry.samples or 0
      local market = self:GetMarketValue(itemID)
      local buy = entry.last.min
      local qty = entry.last.qty or 0

      if (days >= 2 or samples >= 2) and market and buy and market > 0 and buy > 0 and qty > 0 then
        local stats = self:GetPriceStats(itemID)
        local maxDeviation = settings.maxDeviation or 0.5
        local outlier = stats and (stats.days >= (settings.minHistoryDays or 2) or (stats.samples or 0) >= 3)
          and stats.median and stats.median > 0
          and stats.deviation and math.abs(stats.deviation) > maxDeviation
        if not outlier then
          local net = market * 0.95
          local profit = net - buy
          local roi = profit / buy
          if profit >= (settings.minProfit or 100) and roi >= (settings.minROI or 0.10) then
            local confidence = ns.Util:Clamp(math.max(days, samples / 2) / 10, 0, 1) * ns.Util:Clamp(qty / 20, 0.2, 1)
            local score = profit * confidence * (1 + math.min(qty, 50) / 50)
            flips[#flips + 1] = {
              itemID = itemID,
              buy = buy,
              market = market,
              profit = profit,
              roi = roi,
              qty = qty,
              days = days,
              confidence = confidence,
              score = score,
            }
          end
        end
      end
    end
  end

  -- Детальные флипы по лестницам цен (работают с одного скана)
  local cap = limit or settings.maxFlips or 100
  local detailFlips = self:GetDetailFlips(cap * 2)
  local seen = {}
  for index, flip in ipairs(flips) do seen[flip.itemID] = index end
  for _, flip in ipairs(detailFlips) do
    local existing = seen[flip.itemID]
    if existing then
      if flip.score > flips[existing].score then flips[existing] = flip end
    else
      flips[#flips + 1] = flip
      seen[flip.itemID] = #flips
    end
  end

  table.sort(flips, function(a, b)
    return a.score > b.score
  end)

  while #flips > cap do
    table.remove(flips)
  end
  return flips
end

function Market:GetFarmGroups()
  local db = ns.db
  local groups = {}

  for itemID, entry in pairs(db.prices) do
    if entry.last and ns.Util:IsTradeGood(itemID) then
      local market = self:GetMarketValue(itemID) or entry.last.min
      local qty = entry.last.qty or 0
      if market and market > 0 and qty > 0 then
        local subclassName = ns.Util:ItemSubclassName(itemID)
        local group = groups[subclassName]
        if not group then
          group = { name = subclassName, items = {}, value = 0, qty = 0 }
          groups[subclassName] = group
        end
        local itemScore = market * (1 + math.log(qty + 1))
        group.items[#group.items + 1] = {
          itemID = itemID,
          price = market,
          qty = qty,
          score = itemScore,
        }
        group.value = group.value + market * qty
        group.qty = group.qty + qty
      end
    end
  end

  local result = {}
  for _, group in pairs(groups) do
    table.sort(group.items, function(a, b)
      return a.score > b.score
    end)
    result[#result + 1] = group
  end
  table.sort(result, function(a, b)
    return a.value > b.value
  end)
  return result
end

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
