local addonName, ns = ...

local Recipes = ns.Recipes or {}
ns.Recipes = Recipes

local L = function(key, ...) return ns.L(key, ...) end

local function catalogPrice(itemID, settings)
  local stats = ns.Market.GetPriceStats and ns.Market:GetPriceStats(itemID) or nil
  local price = stats and (stats.median or stats.min) or ns.Market:GetPrice(itemID)
  local outlier = stats and (stats.days >= (settings.minHistoryDays or 2) or (stats.samples or 0) >= 3)
    and stats.median and stats.median > 0
    and stats.deviation and math.abs(stats.deviation) > (settings.maxDeviation or 0.5)
  return price, outlier, stats
end

local SOURCE_LABELS = {
  [1] = "SOURCE_TRAINER",
  [2] = "SOURCE_DROP",
  [3] = "SOURCE_VENDOR",
  [4] = "SOURCE_QUEST",
  [5] = "SOURCE_DISCOVERY",
}

local function sourceLabel(sourceType)
  if sourceType == nil then return "—" end
  local key = SOURCE_LABELS[sourceType]
  return key and L(key) or ("источник " .. tostring(sourceType))
end

local function safeCall(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c = pcall(fn, ...)
  if ok then return a, b, c end
  return nil
end

local function currentProfessionInfo()
  if not C_TradeSkillUI then return nil end
  local base = safeCall(C_TradeSkillUI.GetBaseProfessionInfo)
  if base and base.professionName then
    return base.professionName, base.professionID
  end

  local lines = safeCall(C_TradeSkillUI.GetAllProfessionTradeSkillLines)
  if type(lines) == "table" then
    local fallback = nil
    for _, line in ipairs(lines) do
      local info = safeCall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, line)
      if info and info.professionName then
        if info.isPrimaryProfession then
          return info.professionName, info.professionID, line
        end
        if not fallback then
          fallback = { name = info.professionName, professionID = info.professionID, skillLineID = line }
        end
      end
    end
    if fallback then
      return fallback.name, fallback.professionID, fallback.skillLineID
    end
  end
  return nil
end

local function enumerateRecipeIDs()
  if not C_TradeSkillUI then return {} end
  local ids, seen = {}, {}
  local function add(value)
    if type(value) == "number" and value > 0 and not seen[value] then
      seen[value] = true
      ids[#ids + 1] = value
    end
  end

  local all = safeCall(C_TradeSkillUI.GetAllRecipeIDs)
  if type(all) == "table" then
    for _, recipeID in ipairs(all) do add(recipeID) end
  end

  if #ids == 0 then
    local _, professionID, skillLineID = currentProfessionInfo()
    local spells = safeCall(C_TradeSkillUI.GetProfessionSpells, professionID, skillLineID)
    if type(spells) == "table" then
      for _, recipeID in ipairs(spells) do add(recipeID) end
    end
  end
  return ids
end

-- Собирает известные рецепты всех профессий без открытия их окон.
-- Неизученные рецепты API отдаёт только для текущей открытой профессии
-- (GetAllRecipeIDs), поэтому они добавляются только для неё.
local function enumerateAllProfessions()
  if not C_TradeSkillUI then return {} end
  local result, byLine = {}, {}
  local currentName, currentProfessionID, currentLine = currentProfessionInfo()
  local lines = safeCall(C_TradeSkillUI.GetAllProfessionTradeSkillLines)

  local function addProfession(name, professionID, line, recipeIDs)
    if not name or name == "" then return end
    local entry = byLine[name]
    if not entry then
      entry = { name = name, ids = {}, seen = {} }
      byLine[name] = entry
      result[#result + 1] = entry
    end
    for _, recipeID in ipairs(recipeIDs or {}) do
      if type(recipeID) == "number" and recipeID > 0 and not entry.seen[recipeID] then
        entry.seen[recipeID] = true
        entry.ids[#entry.ids + 1] = recipeID
      end
    end
  end

  if type(lines) == "table" and #lines > 0 then
    for _, line in ipairs(lines) do
      local info = safeCall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, line)
      if info then
        local professionID = info.professionID
        local spells = safeCall(C_TradeSkillUI.GetProfessionSpells, professionID, line)
        if type(spells) ~= "table" or #spells == 0 then
          spells = safeCall(C_TradeSkillUI.GetProfessionSpells, professionID)
        end
        addProfession(info.professionName, professionID, line, spells)
      end
    end
  end

  -- Для текущей профессии добавляем и неизученные рецепты, если окно уже открыто.
  if currentName then
    local currentRecipes = safeCall(C_TradeSkillUI.GetAllRecipeIDs)
    if type(currentRecipes) == "table" and #currentRecipes > 0 then
      addProfession(currentName, currentProfessionID, currentLine, currentRecipes)
    end
  end

  if #result == 0 and currentName then
    addProfession(currentName, currentProfessionID, currentLine, enumerateRecipeIDs())
  end
  return result
end

local function buildRecipe(recipeID)
  if not C_TradeSkillUI then return nil end
  local info = safeCall(C_TradeSkillUI.GetRecipeInfo, recipeID)
  if not info then
    local spell = C_Spell and safeCall(C_Spell.GetSpellInfo, recipeID)
    if not spell then return nil end
    info = {
      recipeID = recipeID,
      name = spell.name,
      icon = spell.iconID,
      learned = false,
    }
  end
  if info.disabled or info.isGatheringRecipe or info.isDummyRecipe then
    return nil
  end

  local schematic = safeCall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
  local outputItemID = schematic and schematic.outputItemID or nil
  if not outputItemID then
    local output = safeCall(C_TradeSkillUI.GetRecipeOutputItemData, recipeID, {}, nil)
    if output then
      outputItemID = output.itemID or (output.hyperlink and ns.Util:FromLink(output.hyperlink))
    end
  end

  local reagents = {}
  local slots = schematic and schematic.reagentSlotSchematics or {}
  for _, slot in ipairs(slots) do
    local choices = {}
    for _, reagent in ipairs(slot.reagents or {}) do
      local itemID = type(reagent) == "number" and reagent or (reagent and reagent.itemID)
      if itemID then choices[#choices + 1] = itemID end
    end
    if #choices > 0 then
      reagents[#reagents + 1] = {
        choices = choices,
        itemID = choices[1],
        qty = slot.quantityRequired or 1,
        required = slot.required ~= false,
      }
    end
  end

  local quantity = 1
  if schematic then
    local quantityMin = schematic.quantityMin or 1
    local quantityMax = schematic.quantityMax or quantityMin
    quantity = (quantityMin + quantityMax) / 2
  end

  return {
    recipeID = recipeID,
    name = info.name or ("recipe:" .. tostring(recipeID)),
    icon = info.icon,
    outputItemID = outputItemID,
    outputQty = quantity,
    reagents = reagents,
    hasSchematic = schematic ~= nil,
    difficulty = info.relativeDifficulty,
    skillLineAbilityID = info.skillLineAbilityID,
    learned = info.learned ~= false,
    sourceType = info.sourceType,
    source = sourceLabel(info.sourceType),
  }
end

local function cheapestPrice(reagent)
  local best = nil
  for _, itemID in ipairs(reagent.choices or {}) do
    local price = ns.PriceService:GetRecommendedPrice(itemID) or ns.Market:GetPrice(itemID)
    if price and price > 0 and (not best or price < best) then best = price end
  end
  return best
end

local function compute(record)
  local cost = 0
  local missing = {}
  for _, reagent in ipairs(record.reagents or {}) do
    if reagent.required then
      local price = cheapestPrice(reagent)
      if price then
        cost = cost + price * (reagent.qty or 1)
      else
        missing[#missing + 1] = reagent.itemID
      end
    end
  end

  local outputPrice = record.outputItemID and ns.Market:GetResale(record.outputItemID) or nil
  local outputQty = record.outputQty or 1
  local gross = outputPrice and (outputPrice * outputQty * 0.95) or 0
  local profit = outputPrice and (gross - cost) or 0
  local roi = (cost > 0 and outputPrice) and (profit / cost) or 0
  local noPrice = (outputPrice == nil) or (record.hasSchematic == false)

  return {
    recipeID = record.recipeID,
    name = record.name,
    icon = record.icon,
    outputItemID = record.outputItemID,
    outputQty = outputQty,
    cost = cost,
    outputPrice = outputPrice,
    gross = gross,
    profit = profit,
    roi = roi,
    noPrice = noPrice,
    missing = missing,
    reagents = record.reagents,
    learned = record.learned,
    sourceType = record.sourceType,
    source = record.source,
    catalog = record.catalog,
  }
end

local function sortRecipes(list)
  table.sort(list, function(a, b)
    if a.noPrice ~= b.noPrice then return not a.noPrice end
    return a.profit > b.profit
  end)
end

ns.RecipeCore = {
  safeCall = safeCall,
  currentProfessionInfo = currentProfessionInfo,
  enumerateRecipeIDs = enumerateRecipeIDs,
  enumerateAllProfessions = enumerateAllProfessions,
  buildRecipe = buildRecipe,
  cheapestPrice = cheapestPrice,
  compute = compute,
  sortRecipes = sortRecipes,
  catalogPrice = catalogPrice,
}


