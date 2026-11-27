-- ForeverAddon — SavedVariables и миграции
local addonName, ns = ...

local DB = {}
ns.DB = DB

local DEFAULTS = {
  version = 1,
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
  },
  scanLast = 0,
  scanRows = 0,
  priceVersion = 0,
  scanItems = 0,
  scanDuration = 0,
  prices = {},
  recipes = {},
  itemNames = {},
  selectedItem = nil,
}

local function copyDefaults(source, target)
  for key, value in pairs(source) do
    if type(value) == "table" then
      if type(target[key]) ~= "table" then
        target[key] = {}
      end
      copyDefaults(value, target[key])
    elseif target[key] == nil then
      target[key] = value
    end
  end
end

function DB:Init()
  if type(ForeverAddonDB) ~= "table" then
    ForeverAddonDB = {}
  end
  copyDefaults(DEFAULTS, ForeverAddonDB)
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
        if type(day) == "number" and day < cutoff then
          history[day] = nil
        end
      end
    end
  end
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
