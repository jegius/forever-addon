local ns = assert(dofile("tests/bootstrap.lua"))
local mock = dofile("tests/mock_wow.lua")
mock.setItem(500, "Test Item", 1, 1, 7, 6)

ns.Load("services/AuctionService.lua")
ns.db.settings.scanCooldown = 0
AuctionHouseFrame = { IsShown = function() return true end }
C_AuctionHouse = {
  SendBrowseQuery = function(query) assert(query.searchString == "") end,
  GetBrowseResults = function()
    return { { itemKey = { itemID = 500, itemLevel = 0 }, minPrice = 100, totalQuantity = 10 } }
  end,
  HasFullBrowseResults = function() return true end,
  RequestMoreBrowseResults = function() end,
}

ns.Auction:Init()
ns.Auction:OnEvent("AUCTION_HOUSE_SHOW")
assert(ns.Auction:HasAPI(), "API detected")
assert(ns.Auction:CanStart(), "scan can start")
assert(ns.Auction:StartScan(), "scan started")
ns.Auction:OnEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
assert(ns.db.prices[500] and ns.db.prices[500].last.min == 100, "browse result stored")
assert(ns.db.scanLast > 0, "scan timestamp")

-- Missing API must not crash and must be reported as unavailable.
C_AuctionHouse = {}
ns.Auction:OnEvent("AUCTION_HOUSE_SHOW")
local ok, reason = ns.Auction:CanStart()
assert(ok == false and reason, "missing API blocked")
print("auction tests OK")
