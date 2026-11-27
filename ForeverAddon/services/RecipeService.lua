local addonName, ns = ...
local Recipes = ns.Recipes
local Core = ns.RecipeCore
local L = function(key, ...) return ns.L(key, ...) end
local scanning = false
local job = nil

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

  local recipeIDs = Core.enumerateRecipeIDs()
  if #recipeIDs == 0 then
    ns:Print(L("RECIPE_NEED_PROF"))
    return false
  end

  local professionName = Core.currentProfessionInfo() or "Profession"
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
      list[#list + 1] = Core.compute(record)
    end
    Core.sortRecipes(list)
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
  if not ns.CatalogData or not ns.CatalogData.recipes then
    ns:Print(L("RECIPE_NEED_PROF"))
    return false
  end
  return self:ScanCatalog()
end

function Recipes:Step()
  if not job or not job.ids then return end
  local total = #job.ids
  local last = math.min(job.index + 14, total)

  for index = job.index, last do
    local ok, record = pcall(Core.buildRecipe, job.ids[index])
    if ok and record then
      job.raw[#job.raw + 1] = record
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
    list[#list + 1] = Core.compute(record)
  end
  Core.sortRecipes(list)
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
  local label = job.profession or "Profession"
  local total = storeProfession(label, raw, elapsed)
  ns:Print(L("RECIPE_DONE", total, label))

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
      if itemID and not Core.cheapestPrice(reagent) and not seen[itemID] then
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
        list[#list + 1] = Core.compute(record)
      end
      Core.sortRecipes(list)
      profession.list = list
    end
  end
end



