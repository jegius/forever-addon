local ns = assert(dofile("tests/bootstrap.lua"))
local mock = dofile("tests/mock_wow.lua")

mock.setItem(500, "Test Bracers", 2, 14, 4, 2)
mock.setItem(2318, "Light Leather", 1, 1, 7, 6)
mock.setItem(2320, "Coarse Thread", 1, 1, 7, 5)
local function setMarket(id, price)
  ns.db.prices[id] = {
    last = { min = price, qty = 20, t = time() },
    history = { [math.floor(time() / 86400)] = { min = price, qty = 20 } },
    samples = { { min = price, qty = 100 } },
    detail = { p50 = price, resale = price, lots = 20 },
  }
end
setMarket(500, 1000)
setMarket(2318, 100)
setMarket(2320, 50)
setMarket(10940, 100)
setMarket(10938, 130)
setMarket(16204, 100)
setMarket(16203, 100)
setMarket(14344, 100)
ns.CatalogData.professions = { [165] = "Leatherworking" }
ns.CatalogData.recipes = {
  { id = 1, p = 165, n = "Test Bracers", o = 500, q = 1, s = 1, u = 1,
    c = "Leather Bracers", k = "recipe", r = { { 2318, 2 }, { 2320, 3 } } },
}

local health = ns.Advisor:MarketHealth()
assert(health and health.items >= 1, "market health")
local flips = ns.Advisor:TopFlips(3)
assert(type(flips) == "table", "top flips")
local plan = ns.Advisor:CraftPlan(100000)
assert(#plan >= 1, "craft plan")
assert(plan[1].expectedProfit, "expected profit must be present")
local report = ns.Advisor:Report()
assert(#report >= 1, "advisor report")
assert(ns.Advisor:Explain("flip"):find("resale"), "explain")

local json = ns.Export:Store()
assert(type(json) == "string" and #json > 100, "JSON export")
assert(ns.db.exportJson == json, "export stored in SavedVariables")
assert(json:find('"guardrails"'), "guardrails in JSON")

print("advisor/export tests OK")
