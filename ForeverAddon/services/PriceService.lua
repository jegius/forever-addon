local addonName, ns = ...

local PriceService = {}
ns.PriceService = PriceService

local function nowDay()
  return math.floor(time() / 86400)
end

local function sortPairs(pairs)
  table.sort(pairs, function(a, b) return a.value < b.value end)
end

local function weightedQuantile(pairs, fraction)
  if #pairs == 0 then return nil end
  sortPairs(pairs)
  local total = 0
  for _, pair in ipairs(pairs) do total = total + pair.weight end
  if total <= 0 then return pairs[#pairs].value end
  local target = total * fraction
  local acc = 0
  for _, pair in ipairs(pairs) do
    acc = acc + pair.weight
    if acc >= target then return pair.value end
  end
  return pairs[#pairs].value
end

local function weightedMedian(pairs)
  return weightedQuantile(pairs, 0.5)
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

local function collectPairs(entry)
  local pairsList = {}
  local history = entry and entry.history
  if history then
    local today = nowDay()
    for offset = 0, 6 do
      local record = history[today - offset]
      if record and record.min then
        pairsList[#pairsList + 1] = {
          value = record.min,
          weight = math.max(1, record.qty or 1),
        }
      end
    end
  end
  if #pairsList < 2 and entry and entry.samples then
    pairsList = {}
    for _, sample in ipairs(entry.samples) do
      if sample.min then
        pairsList[#pairsList + 1] = {
          value = sample.min,
          weight = math.max(1, sample.qty or 1),
        }
      end
    end
  end
  return pairsList
end

function PriceService:GetPrice(itemID)
  local entry = ns.db and ns.db.prices[itemID]
  if entry and entry.last then return entry.last.min end
  return nil
end

function PriceService:GetQuantity(itemID)
  local entry = ns.db and ns.db.prices[itemID]
  if entry and entry.last then return entry.last.qty or 0 end
  return 0
end

function PriceService:GetHistory(itemID, days)
  local entry = ns.db and ns.db.prices[itemID]
  if not entry or not entry.history then return {} end
  days = days or (ns.db and ns.db.settings.maxChartDays) or 30
  local today = nowDay()
  local result = {}
  for day = today - days + 1, today do
    local record = entry.history[day]
    if record then
      result[#result + 1] = { day = day, min = record.min, qty = record.qty or 0 }
    end
  end
  return result
end

function PriceService:GetHistoryDays(itemID)
  local entry = ns.db and ns.db.prices[itemID]
  if not entry or not entry.history then return 0 end
  local count = 0
  for _ in pairs(entry.history) do count = count + 1 end
  return count
end

function PriceService:GetResale(itemID)
  local entry = ns.db and ns.db.prices[itemID]
  if not entry then return nil end
  local detail = entry.detail
  if detail and detail.resale and detail.resale > 0 then return detail.resale end
  return self:GetMarketValue(itemID) or (entry.last and entry.last.min) or nil
end

function PriceService:GetMarketValue(itemID)
  local entry = ns.db and ns.db.prices[itemID]
  if not entry then return nil end

  local pairsList = collectPairs(entry)
  if #pairsList >= 2 then
    return weightedMedian(pairsList)
  end

  local detail = entry.detail
  if detail and detail.p50 and detail.p50 > 0 then return detail.p50 end
  if entry.last then return entry.last.min end
  return nil
end

function PriceService:GetRecommendedPrice(itemID)
  local value = self:GetMarketValue(itemID)
  if value and value > 0 then return value end
  local entry = ns.db and ns.db.prices[itemID]
  if entry and entry.detail and entry.detail.p50 and entry.detail.p50 > 0 then
    return entry.detail.p50
  end
  if entry and entry.last and entry.last.min and entry.last.min > 0 then
    return entry.last.min
  end
  return nil
end

-- Возвращает: текущий минимум, медиану, отклонение, флаг «подозрительно дёшево».
function PriceService:GetLowOutlier(itemID)
  local entry = ns.db and ns.db.prices[itemID]
  if not entry or not entry.last then return nil end
  local min = entry.last.min
  local rec = self:GetRecommendedPrice(itemID)
  if not min or not rec or rec <= 0 then return nil end
  local settings = (ns.db and ns.db.settings) or {}
  local deviation = (min - rec) / rec
  local suspicious = deviation < -(settings.maxDeviation or 0.5)
  return min, rec, deviation, suspicious
end

function PriceService:GetPriceStats(itemID)
  local entry = ns.db and ns.db.prices[itemID]
  if not entry then return nil end

  local pairsList = collectPairs(entry)
  local min = entry.last and entry.last.min or nil
  local qty = entry.last and entry.last.qty or 0
  local medianValue = #pairsList >= 2 and weightedMedian(pairsList) or
    (entry.detail and entry.detail.p50) or (entry.last and entry.last.min)
  local p25 = #pairsList >= 2 and weightedQuantile(pairsList, 0.25) or medianValue
  local p75 = #pairsList >= 2 and weightedQuantile(pairsList, 0.75) or medianValue
  local days = self:GetHistoryDays(itemID)
  local samples = entry.samples and #entry.samples or 0
  local detail = entry.detail
  local deviation = nil
  if min and medianValue and medianValue > 0 then
    deviation = (min - medianValue) / medianValue
  end
  local mad = nil
  if medianValue and #pairsList >= 2 then
    local deviations = {}
    for _, pair in ipairs(pairsList) do
      deviations[#deviations + 1] = math.abs(pair.value - medianValue)
    end
    mad = median(deviations)
  end

  local confidence = 0.2
  if days >= 2 then confidence = confidence + 0.3 end
  if samples >= 3 then confidence = confidence + 0.15 end
  if (detail and detail.lots or 0) >= 5 then confidence = confidence + 0.2 end
  if qty >= 20 then confidence = confidence + 0.15 end
  if confidence > 1 then confidence = 1 end

  return {
    itemID = itemID,
    min = min,
    median = medianValue,
    p25 = p25,
    p75 = p75,
    mad = mad,
    qty = qty,
    days = days,
    samples = samples,
    deviation = deviation,
    lots = detail and detail.lots or 0,
    confidence = confidence,
  }
end
