local ns = assert(dofile("tests/bootstrap.lua"))
local mock = dofile("tests/mock_wow.lua")

local function setMarket(id, price)
  ns.db.prices[id] = {
    last = { min = price, qty = 20, t = time() },
    history = { [math.floor(time() / 86400)] = { min = price, qty = 20 } },
    samples = { { min = price, qty = 100 } },
    detail = { p50 = price, resale = price, lots = 20 },
  }
end

mock.setItem(500, "Test Bracers", 2, 14, 4, 2)
mock.setItem(2318, "Light Leather", 1, 1, 7, 6)
mock.setItem(2320, "Coarse Thread", 1, 1, 7, 5)
setMarket(500, 1000)
setMarket(2318, 100)
setMarket(2320, 50)
setMarket(10940, 100)

ns.CatalogData.professions = { [165] = "Leatherworking" }
ns.CatalogData.recipes = {
  {
    id = 1, p = 165, n = "Test Bracers", o = 500, q = 1, s = 1, u = 1,
    c = "Leather Bracers", k = "recipe", r = { { 2318, 2 }, { 2320, 3 } },
  },
}

local chains = ns.Recipes:GetCatalogChains()
assert(#chains == 1, "one profitable chain expected, got " .. #chains)
local chain = chains[1]
assert(chain.profit > 0, "chain should be profitable")
assert(chain.cost == 350, "cost 2*100 + 3*50 = 350, got " .. tostring(chain.cost))
assert(chain.professionID == 165, "profession id")
assert(chain.mode == "direct" or chain.mode == "de", "mode")
assert(chain.saleProbability and chain.saleProbability > 0, "sale probability")
assert(chain.expectedProfit, "expected profit")

local summary = ns.Recipes:GetCatalogProfessions()
assert(#summary == 1 and summary[1].priced >= 1, "profession coverage")

-- Negative chains must be hidden.
ns.db.prices[500].last.min = 10
ns.db.prices[500].history[math.floor(time() / 86400)].min = 10
ns.db.prices[500].samples = { { min = 10, qty = 1 } }
ns.db.prices[500].detail.p50 = 10
ns.db.priceVersion = (ns.db.priceVersion or 0) + 1
ns.CatalogData.recipes[1].id = 2
chains = ns.Recipes:GetCatalogChains()
assert(#chains == 0, "negative chain must be hidden")

print("catalog/chain tests OK")
