-- Smoke test for virtualized list rendering with data.
local mock = dofile("tests/mock_wow.lua")

C_Timer = { After = function(_, fn) if fn then pcall(fn) end end,
  NewTimer = function(_, fn) if fn then pcall(fn) end; return { Cancel = function() end } end }
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
GameTooltip.GetItem = function() return nil, nil end

local ctx = mock.Load("ForeverAddon", "ForeverAddon")
for line in io.lines("ForeverAddon/ForeverAddon.toc") do
  local file = line:match("^(.-%.lua)%s*$")
  if file then ctx.load(file) end
end
ForeverAddonDB = nil
ctx.ns.DB:Init()
mock.setItem(500, "Test Bracers", 2, 14, 4, 2)
mock.setItem(2318, "Light Leather", 1, 1, 7, 6)
mock.setItem(2320, "Coarse Thread", 1, 1, 7, 5)
local day = math.floor(time() / 86400)
local function price(id, value)
  ctx.ns.db.prices[id] = {
    last = { min = value, qty = 20, t = time() },
    history = { [day] = { min = value, qty = 20 } },
    samples = { { min = value, qty = 100 } },
    detail = { p50 = value, resale = value, lots = 20 },
  }
end
price(500, 1000); price(2318, 100); price(2320, 50); price(10940, 100)
ctx.ns.CatalogData.professions = { [165] = "Leatherworking" }
ctx.ns.CatalogData.recipes = {
  { id = 1, p = 165, n = "Test Bracers", o = 500, q = 1, s = 1, u = 1,
    c = "Leather Bracers", k = "recipe", r = { { 2318, 2 }, { 2320, 3 } } },
}
ctx.ns.CatalogChains:Invalidate()
ctx.ns.db.recipes = {
  Leatherworking = {
    name = "Leatherworking", updated = time(),
    list = { { recipeID = 1, name = "Test Bracers", outputItemID = 500, cost = 350, profit = 600, roi = 1.7, learned = true, source = "test" } },
  },
}

assert(ctx.ns.UI.Init, "UI init")
local ok, err = pcall(ctx.ns.UI.Init, ctx.ns.UI)
assert(ok, "UI.Init: " .. tostring(err))
ctx.ns.UI:RefreshChains()
assert(ctx.ns.UI.panels.chains.rows and #ctx.ns.UI.panels.chains.rows > 0, "chains rows")
ctx.ns.UI:RefreshRecipes()
assert(ctx.ns.UI.panels.recipes.rows and #ctx.ns.UI.panels.recipes.rows > 0, "recipe rows")
print("virtualized UI data test OK")
