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

setMarket(10940, 100)
setMarket(10938, 130)
setMarket(16204, 100)
setMarket(16203, 100)
setMarket(14344, 100)
mock.setItem(500, "Test Bracers", 2, 14, 4, 2)
local de = ns.Disenchant:Estimate(500)
assert(de and de.value > 0, "classic DE estimate must be positive")
assert(de.estimated == false, "known ilvl should not be fallback")
assert(#de.materials >= 1, "DE materials")

mock.setItem(501, "Custom Bracers", 2, 70, 0, 0)
local fallback = ns.Disenchant:Estimate(501, { category = "Leather Bracers" })
assert(fallback and fallback.value > 0, "custom gear must fall back to nearest row")
assert(fallback.estimated == true, "fallback must be marked estimated")

print("disenchant tests OK")
