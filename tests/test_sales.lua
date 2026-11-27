local ns = assert(dofile("tests/bootstrap.lua"))

local mails = {
  { sender = "Auction House", subject = "Auction successful", money = 10000, hasItem = false, itemCount = 0, link = "|Hitem:500|h" },
  { sender = "Auction House", subject = "Auction expired", money = 0, hasItem = true, itemCount = 1, link = "|Hitem:501|h" },
  { sender = "Auction House", subject = "Auction won", money = 0, hasItem = true, itemCount = 1, link = "|Hitem:502|h" },
}
GetInboxNumItems = function() return #mails end
GetInboxHeaderInfo = function(index)
  local mail = mails[index]
  return 1, 1, mail.sender, mail.subject, mail.money, 0, 1, mail.hasItem, mail.itemCount, false
end
GetInboxItemLink = function(index) return mails[index].link end
GetInboxText = function() return "" end

ns.SaleTracker:Init()
assert(ns.SaleTracker:ScanInbox() == 3, "first scan records all")
assert(ns.SaleTracker:GetStats(500).sold == 1, "sold mail")
assert(ns.SaleTracker:GetStats(501).returned == 1, "returned mail")
assert(ns.SaleTracker:GetStats(502).purchase == 1, "purchase mail")
assert(ns.SaleTracker:ScanInbox() == 0, "dedupe")
local totals = ns.SaleTracker:GetTotals()
assert(totals.sold == 1 and totals.returned == 1 and totals.purchase == 1, "totals")
print("sale tracker tests OK")
