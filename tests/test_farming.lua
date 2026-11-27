local ns = assert(dofile("tests/bootstrap.lua"))
local mock = dofile("tests/mock_wow.lua")

mock.setItem(2318, "Light Leather", 1, 1, 7, 6)
ns.db.prices[2318] = {
  last = { min = 100, qty = 20, t = time() },
  history = { [math.floor(time() / 86400)] = { min = 100, qty = 20 } },
  samples = { { min = 100, qty = 100 } },
  detail = { p50 = 100, resale = 100, lots = 20 },
}

local session = ns.Farming:StartSession(1)
assert(session and session.zoneID == 1, "session started")
ns.Farming:AddLoot(2318, 2)
session = ns.Farming:StopSession()
assert(session and session.value == 200, "session value")
assert(session.goldPerHour and session.goldPerHour > 0, "gold per hour")
assert(#ns.Farming:GetSessions(5) == 1, "session history")
assert(ns.Farming:GetSources().leatherZones == false, "no leather dataset by default")
ns.Farming:SetLeatherZones({ { zone = "Test", itemID = 2318, weight = 2 } })
local zones = ns.Farming:GetLeatherZones(5)
assert(#zones == 1 and zones[1].score == 200, "leather zones")
print("farming tests OK")
