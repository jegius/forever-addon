local ns = assert(dofile("tests/bootstrap.lua"))
local mock = dofile("tests/mock_wow.lua")
mock.setItem(500, "Test Item", 1, 1, 7, 6)

ns.Load("services/AuctionService.lua")
ns.Load("services/DetailService.lua")
ns.db.settings.scanCooldown = 0
AuctionHouseFrame = { IsShown = function() return true end }
C_AuctionHouse = {
  SendBrowseQuery = function() end,
  GetBrowseResults = function() return {} end,
  HasFullBrowseResults = function() return true end,
  MakeItemKey = function(itemID) return { itemID = itemID } end,
  SendSearchQuery = function() return true end,
  GetNumCommoditySearchResults = function() return 1 end,
  GetNumItemSearchResults = function() return 0 end,
  HasFullCommoditySearchResults = function() return true end,
  HasFullItemSearchResults = function() return true end,
  GetCommoditySearchResultInfo = function()
    return { unitPrice = 100, quantity = 5 }
  end,
  RequestMoreCommoditySearchResults = function() end,
}
ns.Auction:Init()
ns.Auction:OnEvent("AUCTION_HOUSE_SHOW")
ns.Detail:Init()

local called = false
assert(ns.Detail:Scan({ { itemID = 500 } }, function() called = true end, "test"), "detail scan started")
ns.Detail:OnEvent("COMMODITY_SEARCH_RESULTS_RECEIVED")
assert(ns.db.prices[500] and ns.db.prices[500].detail, "detail ladder stored")
assert(ns.db.prices[500].detail.min == 100, "detail min")
assert(called, "detail callback called")

C_AuctionHouse = {}
assert(ns.Detail:Scan({ 500 }, nil, "x") == false, "missing API blocked")
print("detail tests OK")
