local addonName, ns = ...
local UI = ns.UI
local L = function(key, ...) return ns.L(key, ...) end

function UI:RefreshProfessions()
  local panel = UI.panels.professions
  local list = self:SortData(ns.Recipes:GetCatalogProfessions(), "professions")
  panel.empty:SetShown(#list == 0)
  panel.child:SetHeight(math.max(1, #list * 24))

  for index, profession in ipairs(list) do
    local row = self:GetRow(panel, index)
    row.icon:SetTexture(ns.Util:ItemIcon(profession.outputItemID))
    row.name:SetText(profession.name)
    row.c1:SetText(ns.Util:Money(profession.best, true))
    row.c2:SetText(ns.Util:Money(profession.total, true))
    row.c3:SetText(tostring(profession.count) .. "/" .. tostring(profession.totalRecipes or 0))
    row.c4:SetText(profession.topName or "—")
    row.c5:SetText(profession.output or "—")
    row.c6:SetText(ns.Util:Percent(profession.roi or 0))
    self:BindItemRow(row, profession.outputItemID)
    self:MarkItem(row, profession.outputItemID)
    row:Show()
  end
  UI.HideRows(panel, #list)
end

function UI:RefreshComponents()
  local panel = UI.panels.components
  local list = self:SortData(ns.Recipes:GetCraftableComponents(), "components")
  panel.empty:SetShown(#list == 0)
  panel.child:SetHeight(math.max(1, #list * 24))

  for index, component in ipairs(list) do
    local row = self:GetRow(panel, index)
    row.icon:SetTexture(ns.Util:ItemIcon(component.itemID))
    row.name:SetText(component.name)
    row.c1:SetText(component.profession or "—")
    row.c2:SetText(ns.Util:Money(component.cost, true))
    row.c3:SetText(ns.Util:Money(component.market, true))
    row.c4:SetText(ns.Util:Money(component.profit, true))
    row.c5:SetText(ns.Util:Percent(component.roi))
    row.c6:SetText(tostring(component.usedIn or 0))
    self:BindItemRow(row, component.itemID)
    self:MarkItem(row, component.itemID)
    row:Show()
  end
  UI.HideRows(panel, #list)
end

function UI:RefreshFarm()
  local panel = UI.panels.farm
  local lines = {}
  local data = ns.Farming and ns.Farming:GetBestZones() or { herbs = {}, mining = {} }
  self:SortData(data.herbs or {}, "farm")
  self:SortData(data.mining or {}, "farm")

  local function addSection(label, zones, kindLabel)
    lines[#lines + 1] = { header = true, name = label }
    for index = 1, math.min(8, #zones) do
      lines[#lines + 1] = { zone = zones[index], kindLabel = kindLabel }
    end
  end

  addSection(L("FARM_BEST_HERBS"), data.herbs or {}, L("FARM_HERBS"))
  addSection(L("FARM_BEST_MINING"), data.mining or {}, L("FARM_MINING"))
  local leather = ns.Farming and ns.Farming:GetLeatherRanking(12) or {}
  lines[#lines + 1] = { header = true, name = L("FARM_BEST_LEATHER") }
  for _, item in ipairs(leather) do
    lines[#lines + 1] = { leather = item, kindLabel = L("FARM_LEATHER") }
  end

  panel.empty:SetShown(#lines == 0)
  panel.child:SetHeight(math.max(1, #lines * 24))

  for index, line in ipairs(lines) do
    local row = self:GetRow(panel, index)
    row.expandButton:Hide()
    if line.header then
      row.icon:SetTexture(nil)
      row.name:SetText("|cffffd100" .. line.name .. "|r")
      row.c1:SetText("")
      row.c2:SetText("")
      row.c3:SetText("")
      row.c4:SetText("")
      row.c5:SetText("")
      row.c6:SetText("")
      row:SetScript("OnClick", nil)
      row:SetScript("OnEnter", nil)
      row:SetScript("OnLeave", nil)
    elseif line.zone then
      local zone = line.zone
      row.icon:SetTexture(ns.Util:ItemIcon(zone.bestItemID))
      row.name:SetText(zone.zone)
      row.c1:SetText(tostring(zone.nodes))
      row.c2:SetText(zone.bestName or "—")
      row.c3:SetText(ns.Util:Money(zone.value, true))
      row.c4:SetText(line.kindLabel or "")
      row.c5:SetText("")
      row.c6:SetText("")
      pcall(row.RegisterForClicks, row, "LeftButtonUp", "RightButtonUp")
      row:SetScript("OnClick", function(_, button)
        if button == "RightButton" and zone.bestItemID then
          UI:ShowChart(zone.bestItemID)
        elseif C_Map and C_Map.OpenMap then
          pcall(C_Map.OpenMap, zone.zoneID)
        end
      end)
      self:MarkItem(row, zone.bestItemID)
    elseif line.leather then
      local item = line.leather
      row.icon:SetTexture(ns.Util:ItemIcon(item.itemID))
      row.name:SetText(UI.QualityName(item.itemID))
      row.c1:SetText(tostring(item.qty))
      row.c2:SetText(ns.Util:Money(item.price, true))
      row.c3:SetText(ns.Util:FormatNumber(math.floor(item.score or 0)))
      row.c4:SetText(line.kindLabel or "")
      row.c5:SetText("")
      row.c6:SetText("")
      self:BindItemRow(row, item.itemID)
      self:MarkItem(row, item.itemID)
    end
    row:Show()
  end
  UI.HideRows(panel, #lines)
end

