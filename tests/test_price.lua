local ns = assert(dofile("tests/bootstrap.lua"))

local function near(a, b, eps)
  return math.abs((a or 0) - (b or 0)) <= (eps or 0.001)
end

local Price = ns.PriceService
local today = math.floor(time() / 86400)
ns.db.prices[1] = {
  last = { min = 50, qty = 20, t = time() },
  history = {
    [today] = { min = 100, qty = 1 },
    [today - 1] = { min = 200, qty = 100 },
  },
  samples = {},
  detail = { p50 = 200, resale = 210, lots = 8 },
}

assert(near(Price:GetMarketValue(1), 200), "weighted median should prefer volume")
local stats = Price:GetPriceStats(1)
assert(stats and stats.p25 and stats.p75 and stats.mad, "stats fields")
assert(stats.confidence > 0 and stats.confidence <= 1, "confidence range")
local min, rec, deviation, suspicious = Price:GetLowOutlier(1)
assert(min == 50 and rec == 200, "outlier inputs")
assert(suspicious == true, "50 vs 200 must be suspicious")
assert(deviation < -0.5, "deviation sign")

ns.db.prices[2] = {
  last = { min = 1000, qty = 1, t = time() },
  history = { [today] = { min = 1000, qty = 1 } },
  samples = { { min = 1000, qty = 1 } },
}
stats = Price:GetPriceStats(2)
assert(stats.confidence < 0.7, "thin market confidence must be low")

print("price tests OK")
