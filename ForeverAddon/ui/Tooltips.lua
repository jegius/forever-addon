local addonName, ns = ...
local UI = ns.UI
local L = function(key, ...) return ns.L(key, ...) end

function UI:AddPriceLines(tooltip, itemID)
  if not tooltip or not itemID then return end
  if tooltip.faPriceItem == itemID then return end
  local recommended = ns.Market:GetRecommendedPrice(itemID)
  if not recommended then return end
  tooltip.faPriceItem = itemID
  local min, recommendedPrice, deviation, suspicious = ns.Market:GetLowOutlier(itemID)
  local qty = ns.Market:GetQuantity(itemID) or 0
  tooltip:AddLine(L("LOOT_RECOMMENDED", ns.Util:Money(recommendedPrice or recommended, true)), 0.3, 1, 0.35)
  tooltip:AddLine(L("LOOT_MIN", ns.Util:Money(min or 0, true)), 1, 1, 1)
  tooltip:AddLine(L("LOOT_VOLUME", qty), 1, 1, 1)
  if suspicious then
    tooltip:AddLine(L("LOOT_LOW_WARNING", math.floor(math.abs(deviation or 0) * 100)), 1, 0.4, 0.25)
  end
  tooltip:AddLine(UI:CategoryLabel(UI:GetItemCategory(itemID)), 1, 1, 1)
  tooltip:Show()
end

local function itemIDFromLink(link)
  return link and tonumber(link:match("item:(%d+)"))
end

function UI:InitTooltips()
  if self.tooltipHooked then return end
  if not GameTooltip then return end
  self.tooltipHooked = true

  if GameTooltip.HookScript then
    GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
      local _, link = tooltip:GetItem()
      UI:AddPriceLines(tooltip, itemIDFromLink(link))
    end)
    GameTooltip:HookScript("OnHide", function(tooltip)
      tooltip.faPriceItem = nil
    end)
  end

  if type(hooksecurefunc) == "function" then
    if GameTooltip.SetBagItem then
      pcall(hooksecurefunc, GameTooltip, "SetBagItem", function(tooltip, bag, slot)
        local link
        if C_Container and C_Container.GetContainerItemLink then
          link = C_Container.GetContainerItemLink(bag, slot)
        elseif GetContainerItemLink then
          link = GetContainerItemLink(bag, slot)
        end
        UI:AddPriceLines(tooltip, itemIDFromLink(link))
      end)
    end
    if GameTooltip.SetInventoryItem then
      pcall(hooksecurefunc, GameTooltip, "SetInventoryItem", function(tooltip, unit, slot)
        local link = GetInventoryItemLink and GetInventoryItemLink(unit, slot)
        UI:AddPriceLines(tooltip, itemIDFromLink(link))
      end)
    end
    if GameTooltip.SetHyperlink then
      pcall(hooksecurefunc, GameTooltip, "SetHyperlink", function(tooltip, link)
        UI:AddPriceLines(tooltip, itemIDFromLink(link))
      end)
    end
  end
end

