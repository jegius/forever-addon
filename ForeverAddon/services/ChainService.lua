local addonName, ns = ...
local Recipes = ns.Recipes
local Core = ns.RecipeCore
local L = function(key, ...) return ns.L(key, ...) end
local catalogChainsCache, catalogChainsVersion
local craftUseCache, craftUseVersion

function Recipes:GetChains()
  local result = {}
  local db = ns.db
  if not db or not ns.Disenchant then return result end

  for professionName, profession in pairs(db.recipes or {}) do
    for _, recipe in ipairs(profession.list or {}) do
      if recipe.outputItemID and (recipe.cost or 0) > 0 then
        local de = ns.Disenchant:Estimate(recipe.outputItemID)
        if de and de.value > 0 then
          local qty = recipe.outputQty or 1
          local deValue = de.value * qty * 0.95
          local profit = deValue - recipe.cost
          local roi = recipe.cost > 0 and (profit / recipe.cost) or 0
          result[#result + 1] = {
            professionName = professionName,
            recipeID = recipe.recipeID,
            name = recipe.name,
            outputItemID = recipe.outputItemID,
            output = ns.Util:ItemName(recipe.outputItemID),
            outputQty = qty,
            cost = recipe.cost,
            deValue = deValue,
            profit = profit,
            roi = roi,
            learned = recipe.learned ~= false,
            de = de,
          }
        end
      end
    end
  end

  table.sort(result, function(a, b) return a.profit > b.profit end)
  return result
end

function Recipes:GetCatalogChains()
  return ns.CatalogChains:Get()
end

function Recipes:GetCatalogChainsSync()
  return ns.CatalogChains:GetSync()
end

function Recipes:RequestCatalogChains(callback)
  return ns.CatalogChains:Request(callback)
end

function Recipes:IsCatalogChainsBuilding()
  return ns.CatalogChains:IsBuilding()
end

function Recipes:HasCatalogChains()
  return ns.CatalogChains:HasCache()
end
function Recipes:GetCraftUseIndex()
  local catalog = ns.CatalogData
  if not catalog or not catalog.recipes then return {} end
  local version = tostring(catalog.build or "catalog") .. ":" .. tostring(#catalog.recipes)
  if craftUseCache and craftUseVersion == version then return craftUseCache end

  local index = {}
  for _, recipe in ipairs(catalog.recipes) do
    for _, reagent in ipairs(recipe.r or {}) do
      local itemID = reagent[1]
      if itemID then index[itemID] = true end
    end
  end
  craftUseCache, craftUseVersion = index, version
  return index
end

function Recipes:ScanCatalogPrices()
  local catalog = ns.CatalogData
  if not catalog or not catalog.recipes then return false end
  if not ns.Auction or not ns.Auction:IsOpen() then
    ns:Print(L("AH_OPEN_FIRST"))
    return false
  end
  if not ns.Detail then return false end

  local missing, seen, scores = {}, {}, {}
  for _, recipe in ipairs(catalog.recipes) do
    local outputPrice = ns.Market:GetRecommendedPrice(recipe.o) or 0
    local ids = { recipe.o }
    for _, reagent in ipairs(recipe.r or {}) do ids[#ids + 1] = reagent[1] end
    for _, itemID in ipairs(ids) do
      if itemID and not seen[itemID] then
        local stats = ns.Market.GetPriceStats and ns.Market:GetPriceStats(itemID) or nil
        if not stats or not stats.median then
          seen[itemID] = true
          missing[#missing + 1] = itemID
          scores[itemID] = math.max(scores[itemID] or 0, outputPrice)
        end
      end
    end
  end
  if #missing == 0 then
    ns:Print(L("CATALOG_NO_MISSING"))
    return false
  end
  table.sort(missing, function(a, b) return (scores[a] or 0) > (scores[b] or 0) end)
  while #missing > 50 do table.remove(missing) end
  ns:Print(L("CATALOG_PRICE_SCAN", #missing))
  ns.Detail:Scan(missing, function()
    if ns.UI then ns.UI:ScheduleRefresh() end
  end, L("CATALOG_LABEL"))
  return true
end

function Recipes:GetCatalogProfessions()
  local summary = {}
  local catalog = ns.CatalogData
  if not catalog or not catalog.recipes then return summary end

  local byProfession = {}
  for _, name in pairs(catalog.professions or {}) do
    local localized = ns.Util:LocalizeProfession(name)
    byProfession[localized] = {
      name = localized, best = 0, total = 0, count = 0,
      priced = 0, totalRecipes = 0,
      topName = "—", output = "—", roi = 0,
    }
  end
  for _, recipe in ipairs(catalog.recipes or {}) do
    local name = ns.Util:LocalizeProfession(catalog.professions[recipe.p] or tostring(recipe.p))
    local entry = byProfession[name]
    if entry then entry.totalRecipes = entry.totalRecipes + 1 end
  end
  for _, chain in ipairs(self:GetCatalogChains()) do
    local entry = byProfession[chain.profession]
    if entry then entry.priced = entry.priced + 1 end
    if not chain.suspicious then
      local name = chain.profession
      if not entry then
        entry = { name = name, best = chain.profit, total = 0, count = 0 }
        byProfession[name] = entry
      end
      if chain.profit > entry.best then
        entry.best = chain.profit
        entry.top = chain
      end
      if chain.profit > 0 then
        entry.total = entry.total + chain.profit
        entry.count = entry.count + 1
      end
      if entry.top then
        entry.topName = entry.top.name
        entry.output = entry.top.output
        entry.outputItemID = entry.top.outputItemID
        entry.roi = entry.top.roi
      end
    end
  end

  for _, entry in pairs(byProfession) do
    summary[#summary + 1] = entry
  end
  table.sort(summary, function(a, b)
    if a.total == b.total then return a.best > b.best end
    return a.total > b.total
  end)
  return summary
end


