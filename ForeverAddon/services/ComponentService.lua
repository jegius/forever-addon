local addonName, ns = ...
local Recipes = ns.Recipes
local Core = ns.RecipeCore

function Recipes:GetCraftableComponents()
  local catalog = ns.CatalogData
  if not catalog or not catalog.recipes then return {} end
  local settings = (ns.db and ns.db.settings) or {}
  local used = {}
  for _, recipe in ipairs(catalog.recipes) do
    for _, reagent in ipairs(recipe.r or {}) do
      used[reagent[1]] = (used[reagent[1]] or 0) + 1
    end
  end

  local result, seen = {}, {}
  for _, recipe in ipairs(catalog.recipes) do
    if used[recipe.o] and not seen[recipe.o] then
      seen[recipe.o] = true
      local cost, missing = 0, false
      for _, reagent in ipairs(recipe.r or {}) do
        local price, outlier = Core.catalogPrice(reagent[1], settings)
        if outlier or not price or price <= 0 then
          missing = true
        else
          cost = cost + price * (reagent[2] or 1)
        end
      end
      local market, outlier = Core.catalogPrice(recipe.o, settings)
      if market and cost > 0 and not missing and not outlier then
        local qty = recipe.q or 1
        local profit = market * qty * 0.95 - cost
        if profit > 0 then
          result[#result + 1] = {
            itemID = recipe.o,
            name = ns.Util:ItemName(recipe.o),
            profession = ns.Util:LocalizeProfession(catalog.professions[recipe.p] or tostring(recipe.p)),
            cost = cost,
            market = market * qty,
            profit = profit,
            roi = cost > 0 and profit / cost or 0,
            usedIn = used[recipe.o],
          }
        end
      end
    end
  end
  table.sort(result, function(a, b) return a.profit > b.profit end)
  return result
end

