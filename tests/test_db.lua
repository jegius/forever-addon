local ns = assert(dofile("tests/bootstrap.lua"))

ForeverAddonDB = {
  schemaVersion = 1,
  settings = { historyDays = 30, maxPriceEntries = 3 },
  prices = {
    [1] = { last = { min = 10, t = 1 }, history = { [1] = { min = 10 } } },
    [2] = { last = { min = 20, t = 2 }, history = {} },
    [3] = { last = { min = 30, t = 3 }, history = {} },
    [4] = { last = { min = 40, t = 4 }, history = {} },
  },
}
ns.DB:Init()
assert(ns.db.schemaVersion == 2, "migration to schema 2")
assert(ns.db.addonVersion == "1.2.6", "addon version marker")
assert(ns.db.loadCount and ns.db.loadCount >= 1, "load counter")
assert(ns.DB:GetSizeApprox() <= 3, "price entries must be trimmed")
assert(ns.DB:GetItemMeta(4) == nil, "meta starts empty")

ns.DB:SetItemMeta(4, { itemLevel = 60, quality = 2, classID = 4 })
local meta = ns.DB:GetItemMeta(4)
assert(meta.itemLevel == 60 and meta.quality == 2, "meta roundtrip")

ns.db.settings.maxMetaEntries = 2
for index = 1, 3 do ns.DB:SetItemMeta(100 + index, { itemLevel = index, t = index }) end
ns.DB:Prune()
local metaCount = 0
for _ in pairs(ns.db.itemMeta) do metaCount = metaCount + 1 end
assert(metaCount <= 2, "item meta capped")

local old = math.floor(time() / 86400) - 100
ns.db.prices[4].history[old] = { min = 1 }
ns.DB:Prune()
assert(ns.db.prices[4].history[old] == nil, "old history must be pruned")

print("database tests OK")

