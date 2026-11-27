-- ForeverAddon — утилиты: предметы, деньги, форматирование
local addonName, ns = ...

local Util = {}
ns.Util = Util

local itemCache = {}
local classCache = {}
local pending = {}

local itemFrame = CreateFrame("Frame")
itemFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
itemFrame:SetScript("OnEvent", function(_, _, itemID)
  if pending[itemID] then
    pending[itemID] = nil
    itemCache[itemID] = nil
    if ns.db and ns.db.itemNames and C_Item and C_Item.GetItemInfo then
      local name = C_Item.GetItemInfo(itemID)
      if name then ns.db.itemNames[itemID] = name end
    end
    if ns.UI and ns.UI.ScheduleRefresh then
      ns.UI:ScheduleRefresh()
    end
  end
end)

local function getItemInfo(itemID)
  if C_Item and C_Item.GetItemInfo then
    return { C_Item.GetItemInfo(itemID) }
  end
  if GetItemInfo then
    return { GetItemInfo(itemID) }
  end
  return {}
end

local function getItemInfoInstant(itemID)
  if C_Item and C_Item.GetItemInfoInstant then
    return { C_Item.GetItemInfoInstant(itemID) }
  end
  if GetItemInfoInstant then
    return { GetItemInfoInstant(itemID) }
  end
  return {}
end

local function getItemSubClassInfo(classID, subclassID)
  if C_Item then
    if C_Item.GetItemSubClassInfo then
      return C_Item.GetItemSubClassInfo(classID, subclassID)
    end
    if C_Item.GetItemSubclassInfo then
      return C_Item.GetItemSubclassInfo(classID, subclassID)
    end
  end
  if GetItemSubClassInfo then
    return GetItemSubClassInfo(classID, subclassID)
  end
  return nil
end

local function getInfo(itemID)
  if type(itemID) ~= "number" then return nil end
  local cached = itemCache[itemID]
  if cached then return cached end

  local info = getItemInfo(itemID)
  local instant = getItemInfoInstant(itemID)

  local entry = {
    id = itemID,
    name = info[1],
    link = info[2],
    quality = info[3] or 1,
    itemLevel = info[4] or 0,
    classID = instant[6] or info[12],
    subclassID = instant[7] or info[13],
    icon = instant[5] or info[10],
  }

  if (not entry.name or not entry.classID or entry.classID <= 0 or entry.itemLevel <= 0)
    and C_Item.RequestLoadItemDataByID then
    pending[itemID] = true
    C_Item.RequestLoadItemDataByID(itemID)
  end

  itemCache[itemID] = entry
  return entry
end

function Util:GetItem(itemID)
  return getInfo(itemID)
end

-- Cheap class/subclass lookup for scan loops: instant item info only.
function Util:GetClassInfo(itemID)
  if type(itemID) ~= "number" then return 0, 0 end
  local cached = classCache[itemID]
  if cached then return cached.classID, cached.subclassID end

  local instant = getItemInfoInstant(itemID)
  local entry = { classID = instant[6] or 0, subclassID = instant[7] or 0 }
  classCache[itemID] = entry
  return entry.classID, entry.subclassID
end

function Util:ItemName(itemID)
  local entry = getInfo(itemID)
  return entry and entry.name or ("item:" .. tostring(itemID))
end

function Util:ItemIcon(itemID)
  local entry = getInfo(itemID)
  return entry and entry.icon or 134400
end

function Util:ItemClass(itemID)
  local classID = self:GetClassInfo(itemID)
  return classID
end

function Util:ItemSubclass(itemID)
  local _, subclassID = self:GetClassInfo(itemID)
  return subclassID
end

function Util:ItemQuality(itemID)
  local entry = getInfo(itemID)
  return entry and entry.quality or 1
end

function Util:ItemLevel(itemID)
  local entry = getInfo(itemID)
  return entry and entry.itemLevel or 0
end

function Util:IsTradeGood(itemID)
  return self:ItemClass(itemID) == 7
end

function Util:IsRecipe(itemID)
  return self:ItemClass(itemID) == 9
end

function Util:IsConsumable(itemID)
  return self:ItemClass(itemID) == 0
end

function Util:IsGearClass(itemID)
  local classID = self:ItemClass(itemID)
  return classID == 2 or classID == 4
end

function Util:IsFlipItem(itemID)
  local classID = self:ItemClass(itemID)
  return classID == 7 or classID == 9 or classID == 0 or classID == 2 or classID == 4
end

function Util:IsTrackedItem(itemID)
  local db = ns.db
  if db and db.selectedItem == itemID then
    return true
  end
  local classID = self:ItemClass(itemID)
  return classID == 7 or classID == 9 or classID == 0 or classID == 2 or classID == 4
end

function Util:ItemSubclassName(itemID)
  local classID = self:ItemClass(itemID)
  local subclassID = self:ItemSubclass(itemID)
  if classID == 0 then return classID, subclassID end
  local name = getItemSubClassInfo(classID, subclassID)
  return name or ("subclass:" .. tostring(subclassID))
end

-- Где брать ингредиент: профессия/источник по классу и подклассу предмета.
function Util:IngredientSource(itemID)
  local classID = self:ItemClass(itemID)
  if classID == 2 or classID == 4 then return "экипировка" end
  if classID == 9 then return "рецепт" end
  if classID == 0 then return "расходник" end
  local subclass = tostring(self:ItemSubclassName(itemID) or ""):lower()
  if subclass:find("herb") or subclass:find("трав") then return "травничество" end
  if subclass:find("metal") or subclass:find("руд") or subclass:find("металл") or subclass:find("камен") then
    return "горное дело"
  end
  if subclass:find("leather") or subclass:find("кож") then return "кожевничество" end
  if subclass:find("cloth") or subclass:find("ткан") then return "ткань" end
  if subclass:find("cooking") or subclass:find("кулин") or subclass:find("fish") or subclass:find("рыб") then
    return "кулинария/рыбалка"
  end
  if subclass:find("enchant") or subclass:find("чар") then return "наложение чар" end
  if subclass:find("jewel") or subclass:find("ювелир") then return "ювелирное дело" end
  return self:ItemSubclassName(itemID) or "аукцион/фарм"
end

local PROFESSION_RU = {
  Alchemy = "Алхимия",
  Blacksmithing = "Кузнечное дело",
  Enchanting = "Наложение чар",
  Engineering = "Инженерное дело",
  Herbalism = "Травничество",
  Leatherworking = "Кожевничество",
  Mining = "Горное дело",
  Skinning = "Снятие шкур",
  Tailoring = "Портняжное дело",
  Cooking = "Кулинария",
  ["First Aid"] = "Первая помощь",
  Fishing = "Рыбная ловля",
}

function Util:LocalizeProfession(name)
  if not name then return "—" end
  if GetLocale and GetLocale() == "ruRU" then
    return PROFESSION_RU[name] or name
  end
  return name
end

local spellNameCache = {}
function Util:SpellName(spellID, fallback)
  if not spellID then return fallback end
  local cached = spellNameCache[spellID]
  if cached ~= nil then return cached or fallback end
  local name
  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
    if ok and info then name = info.name end
  end
  spellNameCache[spellID] = name or false
  return name or fallback
end
function Util:Day()
  return math.floor(time() / 86400)
end

function Util:FromLink(link)
  if type(link) ~= "string" then return nil end
  local itemID = link:match("item:(%d+)")
  return itemID and tonumber(itemID) or nil
end

function Util:Money(copper, short)
  copper = math.floor((copper or 0) + 0.5)
  local gold = math.floor(copper / 10000)
  local silver = math.floor((copper % 10000) / 100)
  local copperRest = copper % 100
  if short then
    if gold > 0 then
      if silver > 0 then
        return string.format("%dг %dс", gold, silver)
      end
      return string.format("%dг", gold)
    elseif silver > 0 then
      if copperRest > 0 then
        return string.format("%dс %dм", silver, copperRest)
      end
      return string.format("%dс", silver)
    end
    return string.format("%dм", copperRest)
  end
  if gold > 0 then
    return string.format("%dг %dс %dм", gold, silver, copperRest)
  elseif silver > 0 then
    return string.format("%dс %dм", silver, copperRest)
  end
  return string.format("%dм", copperRest)
end

function Util:Percent(value)
  return string.format("%.1f%%", (value or 0) * 100)
end

function Util:Round(value, digits)
  local mult = 10 ^ (digits or 0)
  return math.floor(value * mult + 0.5) / mult
end

function Util:Clamp(value, low, high)
  if value < low then return low end
  if value > high then return high end
  return value
end

function Util:TableSize(tbl)
  local count = 0
  for _ in pairs(tbl or {}) do count = count + 1 end
  return count
end

function Util:FormatNumber(value)
  if value >= 1000000 then
    return string.format("%.1fM", value / 1000000)
  elseif value >= 1000 then
    return string.format("%.1fk", value / 1000)
  end
  return string.format("%d", value)
end
