local ns = assert(dofile("tests/bootstrap.lua"))
local mock = dofile("tests/mock_wow.lua")
mock.setItem(500, "Test Item", 1, 1, 7, 6)

ns.db.prices[500] = {}
ns.Market:RecordSample(500, 100, 10)
assert(ns.db.prices[500].samples and #ns.db.prices[500].samples == 1, "sample recorded")
assert(ns.db.prices[500].history, "history created")

ns.Market:ApplyScan({ [500] = { min = 90, qty = 20 } }, 1, 1.5)
assert(ns.db.prices[500].last.min == 90, "last scan applied")
assert(ns.db.scanLast > 0, "scan timestamp")

local ok = ns.Market:ApplyDetail(500, { { p = 100, q = 5 }, { p = 120, q = 10 } }, 15)
assert(ok, "detail applied")
local detail = ns.Market:GetDetail(500)
assert(detail and detail.min == 100 and detail.p50 and detail.resale, "detail ladder")
local series = ns.Market:GetChartSeries(500, 30)
assert(#series >= 1, "chart series")

print("market tests OK")
