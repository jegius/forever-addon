local addonName, ns = ...
local Recipes = ns.Recipes

function Recipes:GetAll()
  local result = {}
  local db = ns.db
  if not db then return result end

  for professionName, profession in pairs(db.recipes or {}) do
    for _, recipe in ipairs(profession.list or {}) do
      result[#result + 1] = {
        professionName = professionName,
        recipeID = recipe.recipeID,
        name = recipe.name,
        icon = recipe.icon,
        outputItemID = recipe.outputItemID,
        cost = recipe.cost,
        outputPrice = recipe.outputPrice,
        outputQty = recipe.outputQty,
        quantity = recipe.outputQty,
        profit = recipe.profit,
        roi = recipe.roi,
        noPrice = recipe.noPrice,
        missing = recipe.missing,
        learned = recipe.learned ~= false,
        source = recipe.source or "—",
        sourceType = recipe.sourceType,
        catalog = recipe.catalog or false,
      }
    end
  end

  table.sort(result, function(a, b)
    if a.noPrice ~= b.noPrice then return not a.noPrice end
    return a.profit > b.profit
  end)
  return result
end

function Recipes:GetIngredients()
  local rows = {}
  local db = ns.db
  if not db then return {} end

  for _, profession in pairs(db.recipes or {}) do
    for _, recipe in ipairs(profession.list or {}) do
      for _, reagent in ipairs(recipe.reagents or {}) do
        if reagent.required ~= false then
          local bestID, bestPrice = nil, nil
          for _, choice in ipairs(reagent.choices or {}) do
            local price = ns.PriceService:GetRecommendedPrice(choice) or ns.Market:GetPrice(choice)
            if price and (not bestPrice or price < bestPrice) then
              bestID, bestPrice = choice, price
            end
          end
          if bestID and bestPrice then
            local row = rows[bestID]
            if not row then
              row = { itemID = bestID, price = bestPrice, uses = 0, qty = 0, cost = 0, profitable = 0 }
              rows[bestID] = row
            end
            row.price = math.max(row.price or 0, bestPrice)
            row.uses = row.uses + 1
            row.qty = row.qty + (reagent.qty or 1)
            row.cost = row.cost + bestPrice * (reagent.qty or 1)
            if (recipe.profit or 0) > 0 then row.profitable = row.profitable + 1 end
          end
        end
      end
    end
  end

  local result = {}
  for _, row in pairs(rows) do
    row.name = ns.Util:ItemName(row.itemID)
    row.source = ns.Util:IngredientSource(row.itemID)
    row.score = row.cost * (1 + row.profitable)
    result[#result + 1] = row
  end
  table.sort(result, function(a, b) return a.score > b.score end)
  return result
end

function Recipes:GetProfessionSummary()
  local summary = {}
  local db = ns.db
  if not db then return summary end

  for professionName, profession in pairs(db.recipes or {}) do
    local best = 0
    local total = 0
    local count = 0
    for _, recipe in ipairs(profession.list or {}) do
      if not recipe.noPrice then
        if recipe.profit > best then best = recipe.profit end
        if recipe.profit > 0 then total = total + recipe.profit end
      end
      count = count + 1
    end
    summary[#summary + 1] = {
      name = professionName,
      best = best,
      total = total,
      count = count,
      updated = profession.updated,
    }
  end

  table.sort(summary, function(a, b) return a.total > b.total end)
  return summary
end
