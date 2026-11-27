-- Portioned catalog-chain builder. Keeps the UI responsive on 2354 recipes.
local addonName, ns = ...

local CatalogChains = {}
ns.CatalogChains = CatalogChains

local Core = ns.RecipeCore
local cache, cacheVersion
local building = nil

local function version()
  local db = ns.db
  if not db then return "0" end
  local catalog = ns.CatalogData
  return table.concat({
    tostring(db.priceVersion or 0),
    tostring(ns.Util:TableSize(db.itemNames or {})),
    tostring((db.settings and db.settings.maxDeviation) or 0.5),
    tostring((db.settings and db.settings.minHistoryDays) or 2),
    tostring(catalog and catalog.build or ""),
    tostring(catalog and catalog.count or 0),
  }, ":")
end

local function isGearRecipe(recipe)
  local classID = ns.Util:ItemClass(recipe.o)
  if classID == 2 or classID == 4 then return true end
  if classID ~= 0 or not recipe.c then return false end
  local category = string.lower(recipe.c)
  return category:find("bracer") or category:find("boot") or category:find("glove")
    or category:find("chest") or category:find("leg") or category:find("belt")
    or category:find("shoulder") or category:find("helm") or category:find("cloak")
    or category:find("weapon") or category:find("sword") or category:find("axe")
    or category:find("mace") or category:find("dagger") or category:find("staff")
end

local function computeOne(recipe, settings)
  local cost, missing = 0, false
  local ingredients = {}
  for _, reagent in ipairs(recipe.r or {}) do
    local price, outlier = Core.catalogPrice(reagent[1], settings)
    if outlier then
      missing = true
    elseif price and price > 0 then
      local qty = reagent[2] or 1
      cost = cost + price * qty
      ingredients[#ingredients + 1] = {
        itemID = reagent[1], qty = qty, price = price,
        cost = price * qty, name = ns.Util:ItemName(reagent[1]),
      }
    else
      missing = true
    end
  end

  local outputPrice, outputOutlier, outputStats = Core.catalogPrice(recipe.o, settings)
  if outputOutlier then missing = true end
  if not outputPrice or cost <= 0 or missing then return nil end

  local outputQty = recipe.q or 1
  local direct = outputPrice * outputQty * 0.95 - cost
  local best, mode = direct, "direct"
  local de = nil
  if isGearRecipe(recipe) then
    de = ns.Disenchant and ns.Disenchant:Estimate(recipe.o, { category = recipe.c }) or nil
  end
  local deProfit
  if de and de.value > 0 then
    deProfit = de.value * outputQty * 0.95 - cost
    if deProfit > best then best, mode = deProfit, "de" end
  end
  if best <= 0 then return nil end

  local detail = ns.Market:GetDetail(recipe.o)
  local suspicious = false
  if detail then
    if (detail.lots or 0) < 3 then suspicious = true end
    if detail.min and detail.min > 0 and (detail.resale or 0) > detail.min * 10 then
      suspicious = true
    end
  elseif not ns.Market:GetMarketValue(recipe.o) then
    suspicious = true
  end
  local lots = detail and detail.lots or 0
  local volume = outputStats and outputStats.qty or 0
  local saleProbability = 0.2 + math.min(1, lots / 20) * 0.4 + math.min(1, volume / 100) * 0.4
  if saleProbability > 1 then saleProbability = 1 end
  local saleValue = mode == "de" and (de and de.value * outputQty or 0) or outputPrice * outputQty
  local deposit = math.floor(saleValue * 0.05)
  local expectedProfit = math.floor(best * saleProbability - deposit)
  local catalog = ns.CatalogData

  return {
    recipeID = recipe.id,
    name = ns.Util:SpellName(recipe.id, recipe.n),
    profession = ns.Util:LocalizeProfession(catalog.professions[recipe.p] or tostring(recipe.p)),
    professionID = recipe.p,
    outputItemID = recipe.o,
    output = ns.Util:ItemName(recipe.o),
    outputQty = outputQty,
    cost = cost,
    ingredients = ingredients,
    directProfit = direct,
    deValue = de and (de.value * outputQty * 0.95) or 0,
    deProfit = deProfit,
    deEstimated = de and de.estimated or false,
    profit = best,
    roi = cost > 0 and (best / cost) or 0,
    saleProbability = saleProbability,
    deposit = deposit,
    expectedProfit = expectedProfit,
    riskCapital = cost,
    mode = mode,
    de = de,
    suspicious = suspicious,
    historyDays = outputStats and outputStats.days or 0,
    skill = recipe.s,
    skillupHigh = recipe.u,
    category = recipe.c,
    kind = recipe.k,
  }
end

local function sortResult(result)
  table.sort(result, function(a, b)
    if a.suspicious ~= b.suspicious then return not a.suspicious end
    return a.profit > b.profit
  end)
end

local function finish(result, buildVersion)
  if buildVersion ~= version() then return end
  sortResult(result)
  cache, cacheVersion = result, buildVersion
  local callbacks = building and building.callbacks or {}
  building = nil
  for _, callback in ipairs(callbacks) do pcall(callback, result) end
end

local function step()
  local build = building
  if not build then return end
  local catalog = ns.CatalogData
  if not catalog or not catalog.recipes then
    building = nil
    return
  end
  if build.version ~= version() then
    building = nil
    return
  end
  local settings = (ns.db and ns.db.settings) or {}
  local last = math.min(build.index + 39, #catalog.recipes)
  for index = build.index, last do
    local chain = computeOne(catalog.recipes[index], settings)
    if chain then build.result[#build.result + 1] = chain end
  end
  build.index = last + 1
  if build.index > #catalog.recipes then
    finish(build.result, build.version)
  else
    C_Timer.After(0, step)
  end
end

function CatalogChains:Get()
  local current = version()
  if cache and cacheVersion == current then return cache end
  self:Request()
  return cache or {}
end

function CatalogChains:GetSync()
  local current = version()
  if cache and cacheVersion == current then return cache end
  local catalog = ns.CatalogData
  if not catalog or not catalog.recipes then return {} end
  local settings = (ns.db and ns.db.settings) or {}
  local result = {}
  for _, recipe in ipairs(catalog.recipes) do
    local chain = computeOne(recipe, settings)
    if chain then result[#result + 1] = chain end
  end
  sortResult(result)
  cache, cacheVersion = result, current
  return result
end

function CatalogChains:Request(callback)
  local current = version()
  if cache and cacheVersion == current then
    if callback then pcall(callback, cache) end
    return cache
  end
  if not building or building.version ~= current then
    building = { version = current, index = 1, result = {}, callbacks = {} }
    C_Timer.After(0, step)
  end
  if callback then
    if building then building.callbacks[#building.callbacks + 1] = callback
    else pcall(callback, cache) end
  end
  return cache or {}
end

function CatalogChains:IsBuilding()
  return building ~= nil
end

function CatalogChains:HasCache()
  return cache ~= nil and cacheVersion == version()
end

function CatalogChains:Invalidate()
  cache, cacheVersion = nil, nil
  building = nil
end
