local addonName, ns = ...
local FlipService = {}
ns.Flips = FlipService

function FlipService:GetDetailFlips(limit)
  local db = ns.db
  if not db then return {} end
  local settings = db.settings or {}
  local flips = {}
  for itemID, entry in pairs(db.prices) do
    local detail = entry.detail
    if detail and detail.min and detail.resale and detail.min > 0 and detail.resale > detail.min then
      local stats = ns.PriceService:GetPriceStats(itemID)
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

function FlipService:GetFlips(limit)
  local db = ns.db
  local settings = db.settings
  local flips = {}

  for itemID, entry in pairs(db.prices) do
    if entry.last and ns.Util:IsFlipItem(itemID) then
      local days = ns.PriceService:GetHistoryDays(itemID)
      local samples = entry.samples and #entry.samples or 0
      local market = ns.PriceService:GetMarketValue(itemID)
      local buy = entry.last.min
      local qty = entry.last.qty or 0

      if (days >= 2 or samples >= 2) and market and buy and market > 0 and buy > 0 and qty > 0 then
        local stats = ns.PriceService:GetPriceStats(itemID)
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

function FlipService:GetFarmGroups()
  local db = ns.db
  local groups = {}

  for itemID, entry in pairs(db.prices) do
    if entry.last and ns.Util:IsTradeGood(itemID) then
      local market = ns.PriceService:GetMarketValue(itemID) or entry.last.min
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


