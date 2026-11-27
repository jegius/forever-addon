-- ForeverAddon — прибыльность рецептов: реагенты, выход, цены аукциона
local addonName, ns = ...

local Recipes = {}
ns.Recipes = Recipes

local L = function(key, ...) return ns.L(key, ...) end

local scanning = false
local job = nil
local catalogChainsCache, catalogChainsVersion
local craftUseCache, craftUseVersion

local function catalogPrice(itemID, settings)
  local stats = ns.Market.GetPriceStats and ns.Market:GetPriceStats(itemID) or nil
  local price = stats and (stats.median or stats.min) or ns.Market:GetPrice(itemID)
  local outlier = stats and (stats.days >= (settings.minHistoryDays or 2) or (stats.samples or 0) >= 3)
    and stats.median and stats.median > 0
    and stats.deviation and math.abs(stats.deviation) > (settings.maxDeviation or 0.5)
  return price, outlier, stats
end

local SOURCE_LABELS = {
  [1] = "Тренер",
  [2] = "Дроп",
  [3] = "Продавец",
  [4] = "Квест",
  [5] = "Открытие",
}

local function sourceLabel(sourceType)
  if sourceType == nil then return "—" end
  return SOURCE_LABELS[sourceType] or ("источник " .. tostring(sourceType))
end

local function safeCall(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c = pcall(fn, ...)
  if ok then return a, b, c end
  return nil
end

local function currentProfessionInfo()
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
  local info = safeCall(C_TradeSkillUI.GetRecipeInfo, recipeID)
  if not info then
    local spell = safeCall(C_Spell.GetSpellInfo, recipeID)
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
    local price = ns.Market:GetPrice(itemID)
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

function Recipes:IsScanning()
  return scanning
end

function Recipes:Init()
  local frame = CreateFrame("Frame")
  frame:SetScript("OnEvent", function(_, event)
    if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" then
      self.open = true
    elseif event == "TRADE_SKILL_CLOSE" then
      self.open = false
    end
  end)
  pcall(frame.RegisterEvent, frame, "TRADE_SKILL_SHOW")
  pcall(frame.RegisterEvent, frame, "TRADE_SKILL_CLOSE")
  pcall(frame.RegisterEvent, frame, "TRADE_SKILL_LIST_UPDATE")
end

function Recipes:StartScan()
  if scanning then
    ns:Print(L("RECIPE_SCANNING"))
    return false
  end
  if not C_TradeSkillUI then
    ns:Print(L("RECIPE_NEED_PROF"))
    return false
  end

  local recipeIDs = enumerateRecipeIDs()
  if #recipeIDs == 0 then
    ns:Print(L("RECIPE_NEED_PROF"))
    return false
  end

  local professionName = currentProfessionInfo() or "Profession"
  job = {
    ids = recipeIDs,
    index = 1,
    raw = {},
    profession = professionName,
    started = GetTime(),
  }
  scanning = true
  ns:Print(L("RECIPE_SCANNING"))
  if ns.UI then ns.UI:ScheduleRefresh() end
  C_Timer.After(0, function() Recipes:Step() end)
  return true
end

function Recipes:ScanCatalog()
  local catalog = ns.CatalogData
  if not catalog or not catalog.recipes then return false end
  local db = ns.db
  local byProfession, ordered = {}, {}

  for _, recipe in ipairs(catalog.recipes) do
    local professionName = ns.Util:LocalizeProfession(catalog.professions[recipe.p] or tostring(recipe.p))
    local entry = byProfession[professionName]
    if not entry then
      entry = { name = professionName, raw = {} }
      byProfession[professionName] = entry
      ordered[#ordered + 1] = entry
    end
    local reagents = {}
    for _, reagent in ipairs(recipe.r or {}) do
      reagents[#reagents + 1] = {
        choices = { reagent[1] },
        itemID = reagent[1],
        qty = reagent[2] or 1,
        required = true,
      }
    end
    entry.raw[#entry.raw + 1] = {
      recipeID = recipe.id,
      name = ns.Util:SpellName(recipe.id, recipe.n),
      icon = ns.Util:ItemIcon(recipe.o),
      outputItemID = recipe.o,
      outputQty = recipe.q or 1,
      reagents = reagents,
      hasSchematic = true,
      learned = true,
      catalog = true,
      source = L("RECIPE_SOURCE_CATALOG"),
      sourceType = 0,
      skill = recipe.s,
      skillupHigh = recipe.u,
    }
  end

  local total = 0
  for _, profession in ipairs(ordered) do
    local list = {}
    for _, record in ipairs(profession.raw) do
      list[#list + 1] = compute(record)
    end
    sortRecipes(list)
    db.recipes[profession.name] = {
      name = profession.name,
      updated = time(),
      raw = profession.raw,
      list = list,
      catalog = true,
    }
    total = total + #list
  end

  ns:Print(L("RECIPE_DONE_ALL", total, #ordered, #ordered))
  if ns.UI then
    ns.UI:SetRecipeStatus(L("RECIPE_DONE_ALL", total, #ordered, #ordered))
    ns.UI:ScheduleRefresh()
  end
  return true
end

function Recipes:StartScanAll()
  if scanning then
    ns:Print(L("RECIPE_SCANNING"))
    return false
  end
  if ns.CatalogData and ns.CatalogData.recipes then
    return self:ScanCatalog()
  end
  if not C_TradeSkillUI then
    ns:Print(L("RECIPE_NEED_PROF"))
    return false
  end

  local professions = enumerateAllProfessions()
  local entries, seen = {}, {}
  for _, profession in ipairs(professions) do
    for _, recipeID in ipairs(profession.ids) do
      if not seen[recipeID] then
        seen[recipeID] = true
        entries[#entries + 1] = { recipeID = recipeID, profession = profession.name }
      end
    end
  end
  if #entries == 0 then
    ns:Print(L("RECIPE_ALL_EMPTY"))
    return false
  end

  job = {
    entries = entries,
    index = 1,
    raw = {},
    professionCount = #professions,
    started = GetTime(),
  }
  scanning = true
  ns:Print(L("RECIPE_SCANNING_ALL", #entries, #professions))
  for _, profession in ipairs(professions) do
    ns:Print(L("RECIPE_ALL_PROF", profession.name, #profession.ids))
  end
  if ns.UI then ns.UI:ScheduleRefresh() end
  C_Timer.After(0, function() Recipes:Step() end)
  return true
end

function Recipes:Step()
  if not job then return end
  local total = job.entries and #job.entries or #job.ids
  local last = math.min(job.index + 14, total)

  for index = job.index, last do
    if job.entries then
      local entry = job.entries[index]
      local ok, record = pcall(buildRecipe, entry.recipeID)
      if ok and record then
        record.profession = entry.profession
        job.raw[#job.raw + 1] = record
      end
    else
      local ok, record = pcall(buildRecipe, job.ids[index])
      if ok and record then
        job.raw[#job.raw + 1] = record
      end
    end
  end

  job.index = last + 1
  if ns.UI then
    ns.UI:SetRecipeStatus(L("RECIPE_PROGRESS", math.min(job.index - 1, total), total))
  end

  if job.index <= total then
    C_Timer.After(0.01, function() Recipes:Step() end)
  else
    self:Finish()
  end
end

local function storeProfession(professionName, raw, elapsed)
  local list = {}
  for _, record in ipairs(raw) do
    list[#list + 1] = compute(record)
  end
  sortRecipes(list)
  ns.db.recipes[professionName] = {
    name = professionName,
    updated = time(),
    elapsed = elapsed,
    raw = raw,
    list = list,
  }
  return #list
end

function Recipes:Finish()
  if not job then return end
  local raw = job.raw
  local elapsed = GetTime() - (job.started or GetTime())
  local all = job.entries ~= nil
  local label = all and L("ALL_PROFESSIONS") or job.profession

  if all then
    local groups = {}
    for _, record in ipairs(raw) do
      local professionName = record.profession or "Profession"
      if not groups[professionName] then groups[professionName] = {} end
      groups[professionName][#groups[professionName] + 1] = record
    end
    local total = 0
    local professions = 0
    for professionName, records in pairs(groups) do
      total = total + storeProfession(professionName, records, elapsed)
      professions = professions + 1
    end
    ns:Print(L("RECIPE_DONE_ALL", total, professions, job and job.professionCount or 0))
  else
    local total = storeProfession(label, raw, elapsed)
    ns:Print(L("RECIPE_DONE", total, label))
  end

  scanning = false
  job = nil

  -- Докачиваем недостающие цены (реагенты + выход) детальным сканом, но не больше 50 предметов
  local missing, seen = {}, {}
  for _, record in ipairs(raw) do
    if record.outputItemID and not ns.Market:GetResale(record.outputItemID) and not seen[record.outputItemID] then
      seen[record.outputItemID] = true
      missing[#missing + 1] = record.outputItemID
    end
    for _, reagent in ipairs(record.reagents or {}) do
      local itemID = reagent.itemID
      if itemID and not cheapestPrice(reagent) and not seen[itemID] then
        seen[itemID] = true
        missing[#missing + 1] = itemID
      end
    end
  end
  local limit = 50
  while #missing > limit do table.remove(missing) end

  if #missing > 0 and ns.Detail and ns.Auction and ns.Auction:IsOpen() then
    if ns.UI then ns.UI:SetRecipeStatus(L("RECIPE_PRICE_SCAN", #missing)) end
    ns.Detail:Scan(missing, function()
      Recipes:RecomputeAll()
      if ns.UI then ns.UI:ScheduleRefresh() end
    end, label)
  else
    if ns.UI then ns.UI:SetRecipeStatus("") end
    if ns.UI then ns.UI:ScheduleRefresh() end
  end
end

function Recipes:RecomputeAll()
  local db = ns.db
  if not db then return end
  for _, profession in pairs(db.recipes or {}) do
    if profession.raw then
      local list = {}
      for _, record in ipairs(profession.raw) do
        list[#list + 1] = compute(record)
      end
      sortRecipes(list)
      profession.list = list
    end
  end
end

function Recipes:GetAll()
  local result = {}
  local db = ns.db
  if not db then return result end

  for professionName, profession in pairs(db.recipes or {}) do
    for _, recipe in ipairs(profession.list or {}) do
      result[#result + 1] = {
        professionName = professionName,
        recipeID = recipe.recipeID,
        name = recipe.name,
        icon = recipe.icon,
        outputItemID = recipe.outputItemID,
        cost = recipe.cost,
        outputPrice = recipe.outputPrice,
        outputQty = recipe.outputQty,
        quantity = recipe.outputQty,
        profit = recipe.profit,
        roi = recipe.roi,
        noPrice = recipe.noPrice,
        missing = recipe.missing,
        learned = recipe.learned ~= false,
        source = recipe.source or "—",
        sourceType = recipe.sourceType,
        catalog = recipe.catalog or false,
      }
    end
  end

  table.sort(result, function(a, b)
    if a.noPrice ~= b.noPrice then return not a.noPrice end
    return a.profit > b.profit
  end)
  return result
end

function Recipes:GetIngredients()
  local rows = {}
  local db = ns.db
  if not db then return {} end

  for _, profession in pairs(db.recipes or {}) do
    for _, recipe in ipairs(profession.list or {}) do
      for _, reagent in ipairs(recipe.reagents or {}) do
        if reagent.required ~= false then
          local bestID, bestPrice = nil, nil
          for _, choice in ipairs(reagent.choices or {}) do
            local price = ns.Market:GetPrice(choice)
            if price and (not bestPrice or price < bestPrice) then
              bestID, bestPrice = choice, price
            end
          end
          if bestID and bestPrice then
            local row = rows[bestID]
            if not row then
              row = { itemID = bestID, price = bestPrice, uses = 0, qty = 0, cost = 0, profitable = 0 }
              rows[bestID] = row
            end
            row.price = math.max(row.price or 0, bestPrice)
            row.uses = row.uses + 1
            row.qty = row.qty + (reagent.qty or 1)
            row.cost = row.cost + bestPrice * (reagent.qty or 1)
            if (recipe.profit or 0) > 0 then row.profitable = row.profitable + 1 end
          end
        end
      end
    end
  end

  local result = {}
  for _, row in pairs(rows) do
    row.name = ns.Util:ItemName(row.itemID)
    row.source = ns.Util:IngredientSource(row.itemID)
    row.score = row.cost * (1 + row.profitable)
    result[#result + 1] = row
  end
  table.sort(result, function(a, b) return a.score > b.score end)
  return result
end

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
  local db = ns.db
  local version = db and ((tostring(db.priceVersion or 0)) .. ":" .. tostring(ns.Util:TableSize(db.itemNames or {}))) or "0"
  if catalogChainsCache and catalogChainsVersion == version then
    return catalogChainsCache
  end

  local result = {}
  local catalog = ns.CatalogData
  if not catalog or not catalog.recipes then return result end
  local settings = db.settings or {}

  for _, recipe in ipairs(catalog.recipes) do
    local cost, missing = 0, false
    local ingredients = {}
    for _, reagent in ipairs(recipe.r or {}) do
      local price, outlier = catalogPrice(reagent[1], settings)
      if outlier then
        missing = true
      elseif price and price > 0 then
        local qty = reagent[2] or 1
        cost = cost + price * qty
        ingredients[#ingredients + 1] = {
          itemID = reagent[1],
          qty = qty,
          price = price,
          cost = price * qty,
          name = ns.Util:ItemName(reagent[1]),
        }
      else
        missing = true
      end
    end

    local outputPrice, outputOutlier, outputStats = catalogPrice(recipe.o, settings)
    if outputOutlier then missing = true end
    if outputPrice and cost > 0 and not missing then
      local outputQty = recipe.q or 1
      local direct = outputPrice * outputQty * 0.95 - cost
      local best, mode = direct, "direct"
      local de = ns.Disenchant and ns.Disenchant:Estimate(recipe.o, { category = recipe.c }) or nil
      local deProfit
      if de and de.value > 0 then
        deProfit = de.value * outputQty * 0.95 - cost
        if deProfit > best then
          best, mode = deProfit, "de"
        end
      end
      if best > 0 then
        local detail = ns.Market:GetDetail(recipe.o)
      local suspicious = false
      if detail then
        local lots = detail.lots or 0
        if lots < 3 then suspicious = true end
        if detail.min and detail.min > 0 and (detail.resale or 0) > detail.min * 10 then
          suspicious = true
        end
      elseif not ns.Market:GetMarketValue(recipe.o) then
        suspicious = true
      end
      result[#result + 1] = {
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
    end
  end

  table.sort(result, function(a, b)
    if a.suspicious ~= b.suspicious then return not a.suspicious end
    return a.profit > b.profit
  end)
  catalogChainsCache, catalogChainsVersion = result, version
  return result
end

function Recipes:GetCraftUseIndex()
  local db = ns.db
  local version = db and ((tostring(db.priceVersion or 0)) .. ":" .. tostring(ns.Util:TableSize(db.itemNames or {}))) or "0"
  if craftUseCache and craftUseVersion == version then return craftUseCache end

  local index = {}
  for _, chain in ipairs(self:GetCatalogChains()) do
    if not chain.suspicious and chain.profit >= 1000 then
      for _, ingredient in ipairs(chain.ingredients or {}) do
        local current = index[ingredient.itemID]
        if not current or chain.profit > current then
          index[ingredient.itemID] = chain.profit
        end
      end
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

  local missing, seen = {}, {}
  for _, recipe in ipairs(catalog.recipes) do
    local ids = { recipe.o }
    for _, reagent in ipairs(recipe.r or {}) do ids[#ids + 1] = reagent[1] end
    for _, itemID in ipairs(ids) do
      if itemID and not seen[itemID] then
        local stats = ns.Market.GetPriceStats and ns.Market:GetPriceStats(itemID) or nil
        if not stats or not stats.median then
          seen[itemID] = true
          missing[#missing + 1] = itemID
        end
      end
    end
  end
  if #missing == 0 then
    ns:Print(L("CATALOG_NO_MISSING"))
    return false
  end
  while #missing > 50 do table.remove(missing) end
  ns:Print(L("CATALOG_PRICE_SCAN", #missing))
  ns.Detail:Scan(missing, function()
    if ns.UI then ns.UI:ScheduleRefresh() end
  end, L("CATALOG_LABEL"))
  return true
end

function Recipes:GetCraftableComponents()
  local catalog = ns.CatalogData
  if not catalog or not catalog.recipes then return {} end
  local settings = (ns.db and ns.db.settings) or {}
  local used = {}
  for _, recipe in ipairs(catalog.recipes) do
    for _, reagent in ipairs(recipe.r or {}) do
      used[reagent[1]] = (used[reagent[1]] or 0) + 1
    end
  end

  local result, seen = {}, {}
  for _, recipe in ipairs(catalog.recipes) do
    if used[recipe.o] and not seen[recipe.o] then
      seen[recipe.o] = true
      local cost, missing = 0, false
      for _, reagent in ipairs(recipe.r or {}) do
        local price, outlier = catalogPrice(reagent[1], settings)
        if outlier or not price or price <= 0 then
          missing = true
        else
          cost = cost + price * (reagent[2] or 1)
        end
      end
      local market, outlier = catalogPrice(recipe.o, settings)
      if market and cost > 0 and not missing and not outlier then
        local qty = recipe.q or 1
        local profit = market * qty * 0.95 - cost
        if profit > 0 then
          result[#result + 1] = {
            itemID = recipe.o,
            name = ns.Util:ItemName(recipe.o),
            profession = ns.Util:LocalizeProfession(catalog.professions[recipe.p] or tostring(recipe.p)),
            cost = cost,
            market = market * qty,
            profit = profit,
            roi = cost > 0 and profit / cost or 0,
            usedIn = used[recipe.o],
          }
        end
      end
    end
  end
  table.sort(result, function(a, b) return a.profit > b.profit end)
  return result
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

function Recipes:GetProfessionSummary()
  local summary = {}
  local db = ns.db
  if not db then return summary end

  for professionName, profession in pairs(db.recipes or {}) do
    local best = 0
    local total = 0
    local count = 0
    for _, recipe in ipairs(profession.list or {}) do
      if not recipe.noPrice then
        if recipe.profit > best then best = recipe.profit end
        if recipe.profit > 0 then total = total + recipe.profit end
      end
      count = count + 1
    end
    summary[#summary + 1] = {
      name = professionName,
      best = best,
      total = total,
      count = count,
      updated = profession.updated,
    }
  end

  table.sort(summary, function(a, b) return a.total > b.total end)
  return summary
end
