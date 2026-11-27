-- ForeverAddon — SavedVariables, схема и миграции
local addonName, ns = ...

local DB = {}
ns.DB = DB

local SCHEMA_VERSION = 2

local DEFAULTS = {
  version = 1,
  schemaVersion = SCHEMA_VERSION,
  settings = {
    historyDays = 30,
    scanCooldown = 300,
    minROI = 0.10,
    minProfit = 100,
    maxFlips = 100,
    maxDeviation = 0.5,
    minHistoryDays = 2,
    maxChartDays = 30,
    detailItems = 60,
    detailGearItems = 20,
    gearMinPrice = 5000,
    maxPriceEntries = 8000,
    capital = 100000,
    farmYield = 1.5,
    farmRespawn = 45,
    farmTravel = 30,
    farmCompetition = 1,
  },
  scanLast = 0,
  scanRows = 0,
  priceVersion = 0,
  scanItems = 0,
  scanDuration = 0,
  prices = {},
  recipes = {},
  itemNames = {},
  itemMeta = {},
  selectedItem = nil,
}

local function copyDefaults(source, target)
  for key, value in pairs(source) do
    if type(value) == "table" then
      if type(target[key]) ~= "table" then target[key] = {} end
      copyDefaults(value, target[key])
    elseif target[key] == nil then
      target[key] = value
    end
  end
end

local function migrate(db)
  db.schemaVersion = db.schemaVersion or 0
  if db.schemaVersion < 2 then
    db.itemMeta = db.itemMeta or {}
    db.settings.maxPriceEntries = db.settings.maxPriceEntries or 8000
    db.schemaVersion = 2
  end
end

local function trimPrices(db)
  local limit = db.settings.maxPriceEntries or 8000
  local ids = {}
  for itemID in pairs(db.prices) do ids[#ids + 1] = itemID end
  if #ids <= limit then return end
  table.sort(ids, function(a, b)
    local ea, eb = db.prices[a], db.prices[b]
    return (ea.last and ea.last.t or 0) < (eb.last and eb.last.t or 0)
  end)
  for index = 1, #ids - limit do
    db.prices[ids[index]] = nil
  end
end

function DB:Init()
  if type(ForeverAddonDB) ~= "table" then ForeverAddonDB = {} end
  copyDefaults(DEFAULTS, ForeverAddonDB)
  migrate(ForeverAddonDB)
  ns.db = ForeverAddonDB
  self:Prune()
end

function DB:Prune()
  local db = ns.db
  if not db then return end
  local days = db.settings.historyDays or 30
  local cutoff = math.floor(time() / 86400) - days
  for _, entry in pairs(db.prices) do
    local history = entry.history
    if history then
      for day in pairs(history) do
        if type(day) == "number" and day < cutoff then history[day] = nil end
      end
    end
  end
  trimPrices(db)
end

function DB:GetItem(itemID)
  local db = ns.db
  if not db then return nil end
  local entry = db.prices[itemID]
  if not entry then
    entry = {}
    db.prices[itemID] = entry
  end
  return entry
end

function DB:GetSettings()
  return ns.db and ns.db.settings or DEFAULTS.settings
end

function DB:GetItemMeta(itemID)
  local db = ns.db
  if not db then return nil end
  return db.itemMeta and db.itemMeta[itemID] or nil
end

function DB:SetItemMeta(itemID, meta)
  local db = ns.db
  if not db or not itemID or not meta then return end
  db.itemMeta = db.itemMeta or {}
  db.itemMeta[itemID] = meta
end

function DB:GetSizeApprox()
  local db = ns.db
  if not db then return 0 end
  local count = 0
  for _ in pairs(db.prices or {}) do count = count + 1 end
  return count
end
