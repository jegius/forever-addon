-- Loads every file in TOC order with a broad WoW API mock.
local mock = dofile("tests/mock_wow.lua")

C_Timer = { After = function(_, fn) if fn then pcall(fn) end end }
C_AuctionHouse = {}
C_TradeSkillUI = {}
C_Map = { GetMapInfo = function() return { name = "Test Zone" } end }
C_Spell = { GetSpellInfo = function() return "Test" end }
C_Container.GetContainerNumSlots = function() return 0 end
GetContainerNumSlots = function() return 0 end
GetBuildInfo = function() return "1.60.1", "70888", "2026", 16001 end
SlashCmdList = {}
hooksecurefunc = function() end
UIParent = mock.object()
GameTooltip = mock.object()

local ctx = mock.Load("ForeverAddon", "ForeverAddon")
local loaded = 0
for line in io.lines("ForeverAddon/ForeverAddon.toc") do
  local file = line:match("^(.-%.lua)%s*$")
  if file then
    ctx.load(file)
    loaded = loaded + 1
  end
end

assert(loaded > 20, "TOC must load modules")
assert(ctx.ns.UI and ctx.ns.Advisor and ctx.ns.Export, "public modules")
assert(ctx.ns.CatalogMeta and ctx.ns.CatalogMeta.valid, "catalog integrity")
assert(type(ctx.ns.UI.Init) == "function", "UI.Init")
assert(type(ctx.ns.Recipes.GetCatalogChains) == "function", "Recipes API")
assert(type(ctx.ns.PriceService.GetPriceStats) == "function", "Price API")
print("load-all test OK, files=" .. loaded)
