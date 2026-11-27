-- Catalog integrity guard: catches partially loaded/edited chunks.
local addonName, ns = ...

local catalog = ns.CatalogData
local count = catalog and catalog.recipes and #catalog.recipes or 0
local expected = catalog and catalog.count or 0
ns.CatalogMeta = {
  build = catalog and catalog.build or nil,
  date = catalog and catalog.date or nil,
  schemaVersion = catalog and catalog.schemaVersion or nil,
  count = count,
  expected = expected,
  valid = count == expected and count > 0,
}
if not ns.CatalogMeta.valid then
  ns.catalogError = string.format("catalog count %d/%d", count, expected)
end
