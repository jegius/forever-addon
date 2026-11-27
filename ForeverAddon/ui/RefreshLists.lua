local addonName, ns = ...
local UI = ns.UI
local L = function(key, ...) return ns.L(key, ...) end

function UI:RefreshScan()
  local panel = UI.panels.scan
  if not panel then return end

  panel.button:SetText(ns.Auction:IsScanning() and L("SCAN_BTN_BUSY") or L("SCAN_BTN"))

  local stats = ns.Market:GetStats()
  local parts = {}
  parts[#parts + 1] = L("SCAN_ROWS", stats.rows)
  parts[#parts + 1] = L("SCAN_ITEMS", stats.items)
  parts[#parts + 1] = L("SCAN_DETAIL", stats.detailItems or 0)
  if stats.duration > 0 then
    parts[#parts + 1] = string.format("%.2f с", stats.duration)
  end
  panel.stats:SetText(table.concat(parts, "\n"))

  if stats.lastScan > 0 then
    panel.last:SetText(L("LAST_SCAN", date("%d.%m.%Y %H:%M", stats.lastScan)))
  else
    panel.last:SetText(L("LAST_SCAN", L("NEVER")))
  end

  if UI.scanStatusText then
    panel.status:SetText(UI.scanStatusText)
  elseif ns.Auction:IsScanning() then
    panel.status:SetText(L("SCAN_BTN_BUSY"))
  else
    panel.status:SetText("")
  end

  if panel.detail then
    panel.detail:SetText(UI.detailStatusText or "")
  end
end

function UI:RefreshFlips()
  local panel = UI.panels.flips
  local flips = ns.Market:GetFlips(100)
  for _, flip in ipairs(flips) do
    flip.name = UI.QualityName(flip.itemID)
  end
  local filtered = {}
  for _, flip in ipairs(flips) do
    if UI:MatchesFilter(flip.name) then filtered[#filtered + 1] = flip end
  end
  flips = filtered
  flips = self:SortData(flips, "flips")
  panel.empty:SetShown(#flips == 0)
  panel.child:SetHeight(math.max(1, #flips * 24))

  for index, flip in ipairs(flips) do
    local row = self:GetRow(panel, index)
    local itemID = flip.itemID
    row.icon:SetTexture(ns.Util:ItemIcon(itemID))
    row.name:SetText(UI.QualityName(itemID))
    row.c1:SetText(ns.Util:Money(flip.buy, true))
    row.c2:SetText(ns.Util:Money(flip.market, true))
    row.c3:SetText(ns.Util:Money(flip.profit, true))
    row.c4:SetText(ns.Util:Percent(flip.roi))
    row.c5:SetText(tostring(flip.qty))
    row.c6:SetText(string.format("%d%%", math.floor(flip.confidence * 100)))
    self:BindItemRow(row, itemID)
    self:MarkItem(row, itemID)
    row:Show()
  end
  UI.HideRows(panel, #flips)
end

function UI:RefreshRecipes()
  local panel = UI.panels.recipes
  local list = self:SortData(ns.Recipes:GetAll(), "recipes")
  local filtered = {}
  for _, recipe in ipairs(list) do
    if UI:MatchesFilter((recipe.name or "") .. " " .. (recipe.source or "")) then
      filtered[#filtered + 1] = recipe
    end
  end
  list = filtered

  local function bind(row, recipe)
    row.icon:SetTexture(recipe.icon or 134400)
    row.name:SetText(recipe.name)
    row.c1:SetText(ns.Util:Money(recipe.cost, true))
    if recipe.outputPrice then
      row.c2:SetText(ns.Util:Money(recipe.outputPrice * (recipe.quantity or 1), true))
    else
      row.c2:SetText("—")
    end
    if recipe.noPrice then
      row.c3:SetText(L("RECIPE_NO_PRICE"))
    else
      row.c3:SetText(ns.Util:Money(recipe.profit, true))
    end
    row.c4:SetText(ns.Util:Percent(recipe.roi))
    row.c5:SetText(recipe.source or "—")
    row.c6:SetText(recipe.catalog and "—" or (recipe.learned and L("RECIPE_YES") or L("RECIPE_NO")))
    self:BindItemRow(row, recipe.outputItemID)
    self:MarkItem(row, recipe.outputItemID)
  end
  self:RenderVirtual(panel, list, bind)

  local summary = ns.Recipes:GetProfessionSummary()
  if #summary > 0 then
    panel.status:SetText(L("BEST_PROF", summary[1].name, ns.Util:Money(summary[1].total, true)))
  elseif #list > 0 then
    panel.status:SetText(L("RECIPE_HINT"))
  else
    panel.status:SetText("")
  end
end

function UI:RefreshIngredients()
  local panel = UI.panels.ingredients
  local list = ns.Recipes:GetIngredients()
  for _, ingredient in ipairs(list) do
    ingredient.name = UI.QualityName(ingredient.itemID)
  end
  list = self:SortData(list, "ingredients")
  local filtered = {}
  for _, ingredient in ipairs(list) do
    if UI:MatchesFilter((ingredient.name or "") .. " " .. (ingredient.source or "")) then
      filtered[#filtered + 1] = ingredient
    end
  end
  list = filtered

  local function bind(row, ingredient)
    row.icon:SetTexture(ns.Util:ItemIcon(ingredient.itemID))
    row.name:SetText(UI.QualityName(ingredient.itemID))
    row.c1:SetText(ns.Util:Money(ingredient.price, true))
    row.c2:SetText(tostring(ingredient.uses))
    row.c3:SetText(ns.Util:Money(ingredient.cost, true))
    row.c4:SetText(ingredient.source or "—")
    row.c5:SetText(tostring(ingredient.profitable))
    row.c6:SetText(ns.Util:FormatNumber(math.floor(ingredient.score or 0)))
    self:BindItemRow(row, ingredient.itemID)
    self:MarkItem(row, ingredient.itemID)
  end
  self:RenderVirtual(panel, list, bind)
end

