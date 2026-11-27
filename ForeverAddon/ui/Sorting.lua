local addonName, ns = ...
local UI = ns.UI
local L = function(key, ...) return ns.L(key, ...) end

function UI:OpenAuction(itemID)
  if not itemID then return end
  local open = (AuctionHouseFrame and AuctionHouseFrame:IsShown()) or (AuctionFrame and AuctionFrame:IsShown())
  if not open then
    ns:Print(L("AH_OPEN_FIRST"))
    return
  end
  local name = ns.Util:ItemName(itemID)
  local ok = pcall(C_AuctionHouse.SendBrowseQuery, {
    searchString = name,
    sorts = {},
    filters = {},
    itemClassFilters = {},
  })
  if not ok then ns:Print(L("ERR")) end
end

function UI:BindItemRow(row, itemID)
  if not itemID then
    row:SetScript("OnClick", nil)
    return
  end
  pcall(row.RegisterForClicks, row, "LeftButtonUp", "RightButtonUp")
  row:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
      UI:ShowChart(itemID)
    else
      UI:OpenAuction(itemID)
    end
  end)
end

local categoryCache = {}
local categoryVersion

function UI:GetItemCategory(itemID)
  if not itemID then return "junk", nil, 0 end
  local version = ns.db and tostring(ns.db.priceVersion or 0) or "0"
  if categoryVersion ~= version then
    categoryCache = {}
    categoryVersion = version
  end
  local cached = categoryCache[itemID]
  if cached then return cached.category, cached.median, cached.qty end
  local median = ns.Market:GetMarketValue(itemID)
    or ns.Market:GetResale(itemID)
    or ns.Market:GetPrice(itemID)
  local qty = ns.Market:GetQuantity(itemID) or 0
  local craft = ns.Recipes and ns.Recipes:GetCraftUseIndex()[itemID] or nil
  local category
  if not median then category = "unknown"
  elseif median >= 100000 then category = "very"
  elseif craft then category = "craft"
  elseif median >= 100 then category = "medium"
  else category = "junk" end
  categoryCache[itemID] = { category = category, median = median, qty = qty }
  return category, median, qty
end

function UI:CategoryColor(category)
  if category == "very" then return 0.15, 1, 0.25, 1 end
  if category == "craft" then return 0.25, 0.55, 1, 1 end
  if category == "medium" then return 1, 0.8, 0.2, 1 end
  return 0.45, 0.45, 0.45, 1
end

function UI:CategoryLabel(category)
  return L("LOOT_CAT_" .. string.upper(category))
end

function UI:MarkItem(row, itemID)
  if not itemID then
    if row.lootMark then row.lootMark:Hide() end
    return
  end
  local category = self:GetItemCategory(itemID)
  local min, recommended, deviation, suspicious = ns.Market:GetLowOutlier(itemID)
  local qty = ns.Market:GetQuantity(itemID) or 0

  row.lootMark = row.lootMark or row:CreateTexture(nil, "OVERLAY")
  row.lootMark:ClearAllPoints()
  row.lootMark:SetPoint("TOPLEFT", row.icon, "TOPLEFT", 0, 0)
  row.lootMark:SetSize(3, 20)
  row.lootMark:SetColorTexture(self:CategoryColor(category))
  row.lootMark:Show()

  row:SetScript("OnEnter", function()
    if not GameTooltip then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(UI.QualityName(itemID))
    GameTooltip:AddLine(L("LOOT_RECOMMENDED", ns.Util:Money(recommended or min or 0, true)), 0.3, 1, 0.35)
    GameTooltip:AddLine(L("LOOT_MIN", ns.Util:Money(min or 0, true)), 1, 1, 1)
    GameTooltip:AddLine(L("LOOT_VOLUME", qty), 1, 1, 1)
    if suspicious then
      GameTooltip:AddLine(L("LOOT_LOW_WARNING", math.floor(math.abs(deviation or 0) * 100)), 1, 0.4, 0.25)
    end
    GameTooltip:AddLine(self:CategoryLabel(category), 1, 1, 1)
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
  end)
end

function UI.HideRows(panel, used)
  for index = used + 1, #(panel.rows or {}) do
    panel.rows[index]:Hide()
  end
end

function UI:GetRow(panel, index)
  panel.rows = panel.rows or {}
  local row = panel.rows[index]
  if not row then
    row = UI.CreateRow(panel.child)
    panel.rows[index] = row
  end
  row:ClearAllPoints()
  row:SetPoint("TOPLEFT", panel.child, "TOPLEFT", 0, -(index - 1) * 24)
  row:SetPoint("TOPRIGHT", panel.child, "TOPRIGHT", -4, -(index - 1) * 24)
  return row
end

