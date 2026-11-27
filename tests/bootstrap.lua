-- Loads the service layer without UI for unit tests.
local mock = dofile("tests/mock_wow.lua")

local function newContext()
  local ctx = mock.Load("ForeverAddon", "ForeverAddon")
  local ns = ctx.ns
  ns.Load = ctx.load
  return ns, ctx
end

local function loadServices(ns, ctx)
  ctx.load("locales/enUS.lua")
  ctx.load("locales/ruRU.lua")
  ctx.load("Locales.lua")
  ForeverAddonDB = nil
  ctx.load("config/Database.lua")
  ns.DB:Init()
  ctx.load("data/CatalogData.lua")
  for index = 1, 10 do
    ctx.load(string.format("data/CatalogChunk_%02d.lua", index))
  end
  ctx.load("data/CatalogMeta.lua")
  ctx.load("util/ItemMeta.lua")
  ctx.load("util/Formatting.lua")
  ctx.load("services/PriceService.lua")
  ctx.load("services/MarketStore.lua")
  ctx.load("services/MarketQuery.lua")
  ctx.load("services/FlipService.lua")
  ctx.load("services/DisenchantService.lua")
  ctx.load("services/RecipeCore.lua")
  ctx.load("services/RecipeListService.lua")
  ctx.load("services/RecipeService.lua")
  ctx.load("services/ChainService.lua")
  ctx.load("services/ComponentService.lua")
  ctx.load("services/FarmingService.lua")
  ctx.load("services/AdvisorService.lua")
  ctx.load("services/ExportService.lua")
end

local ns, ctx = newContext()
loadServices(ns, ctx)

return ns, mock
