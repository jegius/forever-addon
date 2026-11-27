local addonName, ns = ...
local UI = ns.UI
local L = function(key, ...) return ns.L(key, ...) end

function UI:ShowChainTooltip(row, chain)
  if not GameTooltip then return end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:AddLine(chain.name, 1, 0.82, 0.2)
  GameTooltip:AddLine(chain.profession or "—", 0.8, 0.8, 1)
  GameTooltip:AddLine(L("CHAIN_TIP_BUY"), 1, 1, 1)
  for _, ingredient in ipairs(chain.ingredients or {}) do
    GameTooltip:AddLine(string.format("  • %s ×%d = %s",
      ingredient.name, ingredient.qty, ns.Util:Money(ingredient.cost, true)), 0.85, 0.85, 0.85)
  end
  GameTooltip:AddLine(L("CHAIN_TIP_CRAFT", chain.output or "—", ns.Util:Money(chain.cost, true)), 1, 1, 1)
  if chain.mode == "de" and chain.de then
    GameTooltip:AddLine(L("CHAIN_TIP_DE"), 0.8, 0.9, 1)
    for _, material in ipairs(chain.de.materials or {}) do
      GameTooltip:AddLine(string.format("  • %s ≈%.2f = %s",
        material.name, material.qty, ns.Util:Money(material.value, true)), 0.85, 0.85, 0.85)
    end
    if chain.deEstimated then
      GameTooltip:AddLine(L("CHAIN_TIP_DE_EST"), 0.8, 0.8, 0.5)
    end
  else
    GameTooltip:AddLine(L("CHAIN_TIP_SELL", chain.output or "—", ns.Util:Money(chain.deValue > 0 and chain.deValue or (chain.cost + chain.profit), true)), 1, 1, 1)
  end
  GameTooltip:AddLine(L("CHAIN_TIP_RESULT", ns.Util:Money(chain.profit, true), ns.Util:Percent(chain.roi)), 0.3, 1, 0.35)
  if chain.expectedProfit then
    GameTooltip:AddLine(L("CHAIN_TIP_EXPECTED", ns.Util:Money(chain.expectedProfit, true),
      math.floor((chain.saleProbability or 0) * 100)), 0.6, 0.9, 1)
  end
  GameTooltip:AddLine(L("CHAIN_TIP_EXPLAIN"), 0.7, 0.7, 0.7)
  if chain.suspicious then
    GameTooltip:AddLine(L("CHAIN_TIP_RISK"), 1, 0.4, 0.25)
  end
  GameTooltip:Show()
end

function UI:RefreshChains()
  local panel = UI.panels.chains
  local list = self:SortData(ns.Recipes:GetCatalogChains(), "chains")
  local term = string.lower(UI.chainSearch or "")
  local filtered = {}
  for _, chain in ipairs(list) do
    local haystack = string.lower((chain.name or "") .. " " .. (chain.profession or "") .. " " .. (chain.output or ""))
    if term == "" or string.find(haystack, term, 1, true) then
      filtered[#filtered + 1] = chain
    end
  end
  local lines = {}
  for _, chain in ipairs(filtered) do
    lines[#lines + 1] = { kind = "chain", chain = chain }
    if UI.chainsExpanded[chain.recipeID] then
      for _, ingredient in ipairs(chain.ingredients or {}) do
        lines[#lines + 1] = { kind = "ingredient", chain = chain, ingredient = ingredient }
      end
    end
  end

  panel.empty:SetShown(#lines == 0)
  panel.child:SetHeight(math.max(1, #lines * 24))

  for index, line in ipairs(lines) do
    local row = self:GetRow(panel, index)
    if line.kind == "chain" then
      local chain = line.chain
      row.icon:ClearAllPoints()
      row.icon:SetPoint("LEFT", 2, 0)
      row.name:ClearAllPoints()
      row.name:SetPoint("LEFT", 28, 0)
      row.icon:SetTexture(ns.Util:ItemIcon(chain.outputItemID))
      row.name:SetText((chain.suspicious and "|cffff5555!|r " or "") .. chain.name)
      row.c1:SetText(chain.profession or "—")
      row.c2:SetText(ns.Util:Money(chain.cost, true))
      if chain.deValue and chain.deValue > 0 then
        row.c3:SetText(ns.Util:Money(chain.deValue, true))
      else
        row.c3:SetText("—")
      end
      row.c4:SetText(ns.Util:Money(chain.profit, true))
      row.c5:SetText(ns.Util:Percent(chain.roi))
      row.c6:SetText(chain.output or "—")
      self:BindItemRow(row, chain.outputItemID)
      self:MarkItem(row, chain.outputItemID)
      row:SetScript("OnEnter", function() UI:ShowChainTooltip(row, chain) end)
      row:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
      end)

      row.expandButton:Show()
      row.expandButton:SetText(UI.chainsExpanded[chain.recipeID] and "-" or "+")
      row.expandButton:SetScript("OnClick", function()
        UI.chainsExpanded[chain.recipeID] = not UI.chainsExpanded[chain.recipeID] or nil
        UI:RefreshChains()
        UI:UpdateScrollbar(panel)
      end)
    else
      local ingredient = line.ingredient
      row.icon:ClearAllPoints()
      row.icon:SetPoint("LEFT", 22, 0)
      row.name:ClearAllPoints()
      row.name:SetPoint("LEFT", 48, 0)
      row.icon:SetTexture(ns.Util:ItemIcon(ingredient.itemID))
      row.name:SetText("|cff808080>|r " .. ingredient.name)
      row.c1:SetText("x" .. tostring(ingredient.qty))
      row.c2:SetText(ns.Util:Money(ingredient.price, true))
      row.c3:SetText(ns.Util:Money(ingredient.cost, true))
      row.c4:SetText("")
      row.c5:SetText("")
      row.c6:SetText("")
      self:BindItemRow(row, ingredient.itemID)
      self:MarkItem(row, ingredient.itemID)
      row.expandButton:Hide()
    end
    row:Show()
  end
  UI.HideRows(panel, #lines)
end

