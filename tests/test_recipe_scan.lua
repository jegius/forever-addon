local ns = assert(dofile("tests/bootstrap.lua"))
local mock = dofile("tests/mock_wow.lua")

mock.setItem(500, "Test Bracers", 2, 14, 4, 2)
mock.setItem(2318, "Light Leather", 1, 1, 7, 6)
mock.setItem(2320, "Coarse Thread", 1, 1, 7, 5)
ns.db.prices[2318] = {
  last = { min = 100, qty = 20, t = time() },
  history = { [math.floor(time() / 86400)] = { min = 100, qty = 20 } },
  samples = { { min = 100, qty = 100 } },
}
ns.db.prices[2320] = {
  last = { min = 50, qty = 20, t = time() },
  history = { [math.floor(time() / 86400)] = { min = 50, qty = 20 } },
  samples = { { min = 50, qty = 100 } },
}
ns.CatalogData.professions = { [165] = "Leatherworking" }
ns.CatalogData.recipes = {
  { id = 1, p = 165, n = "Test Bracers", o = 500, q = 1, s = 1, u = 1,
    c = "Leather Bracers", k = "recipe", r = { { 2318, 2 }, { 2320, 3 } } },
}

assert(ns.Recipes:ScanCatalog(), "ScanCatalog")
local all = ns.Recipes:GetAll()
assert(#all >= 1, "GetAll")
local ingredients = ns.Recipes:GetIngredients()
assert(#ingredients >= 2, "GetIngredients")
local summary = ns.Recipes:GetProfessionSummary()
assert(#summary >= 1, "GetProfessionSummary")
print("recipe scan tests OK")
