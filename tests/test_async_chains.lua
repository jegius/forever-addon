local ns = assert(dofile("tests/bootstrap.lua"))
local mock = dofile("tests/mock_wow.lua")
mock.setItem(500, "Test Bracers", 2, 14, 4, 2)
mock.setItem(2318, "Light Leather", 1, 1, 7, 6)
mock.setItem(2320, "Coarse Thread", 1, 1, 7, 5)
local function price(id, value)
  ns.db.prices[id] = {
    last = { min = value, qty = 20, t = time() },
    history = { [math.floor(time() / 86400)] = { min = value, qty = 20 } },
    samples = { { min = value, qty = 100 } },
    detail = { p50 = value, resale = value, lots = 20 },
  }
end
price(500, 1000); price(2318, 100); price(2320, 50); price(10940, 100)
ns.CatalogData.professions = { [165] = "Leatherworking" }
ns.CatalogData.recipes = {
  { id = 1, p = 165, n = "Test Bracers", o = 500, q = 1, s = 1, u = 1,
    c = "Leather Bracers", k = "recipe", r = { { 2318, 2 }, { 2320, 3 } } },
}

ns.CatalogChains:Invalidate()
local queued = {}
C_Timer.After = function(_, fn) queued[#queued + 1] = fn end
local callbackHit = false
local partial = ns.Recipes:GetCatalogChains()
assert(#partial == 0, "first call must return partial without freezing")
assert(ns.Recipes:IsCatalogChainsBuilding(), "builder started")
ns.Recipes:RequestCatalogChains(function() callbackHit = true end)
local guard = 0
while #queued > 0 and guard < 100 do
  guard = guard + 1
  local fn = table.remove(queued, 1)
  fn()
end
assert(callbackHit, "callback fired")
assert(not ns.Recipes:IsCatalogChainsBuilding(), "builder finished")
assert(#ns.Recipes:GetCatalogChains() == 1, "cache complete")
assert(#ns.Recipes:GetCatalogChainsSync() == 1, "sync path")
print("async catalog tests OK")
