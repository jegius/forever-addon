local addonName, ns = ...
local UI = ns.UI
local L = function(key, ...) return ns.L(key, ...) end

function UI:AddPriceLines(tooltip, itemID)
  if not tooltip or not itemID then return end
  if tooltip.faPriceItem == itemID then return end
  tooltip.faPriceItem = itemID
  local recommended = ns.Market:GetRecommendedPrice(itemID)
  if not recommended then return end
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

function UI:MarkBagButton(button)
  if not button then return end
  if button.faLootMark then button.faLootMark:Hide() end
  if button.faBorder then
    for _, edge in ipairs(button.faBorder) do edge:Hide() end
  end
end

function UI:ScanContainerFrames()
  if not GetContainerNumSlots then return end
  for bag = 0, 4 do
    local ok, count = pcall(GetContainerNumSlots, bag)
    if ok and count then
      for slot = 1, count do
        local button = _G["ContainerFrame" .. bag .. "Item" .. slot]
          or _G["ContainerFrameCombinedBagsItem" .. slot]
        if button then self:MarkBagButton(button) end
      end
    end
  end
end

function UI:InitBagMarks()
  if self.bagHooked then return end
  if type(hooksecurefunc) ~= "function" then return end

  local hooked = false
  if type(ContainerFrameItemButton_OnEnter) == "function" then
    pcall(hooksecurefunc, "ContainerFrameItemButton_OnEnter", function(button)
      UI:MarkBagButton(button)
    end)
    hooked = true
  end
  if type(ContainerFrameItemButton_Update) == "function" then
    pcall(hooksecurefunc, "ContainerFrameItemButton_Update", function(button)
      UI:MarkBagButton(button)
    end)
    hooked = true
  elseif ContainerFrameItemButtonMixin and ContainerFrameItemButtonMixin.Update then
    pcall(hooksecurefunc, ContainerFrameItemButtonMixin, "Update", function(button)
      UI:MarkBagButton(button)
    end)
    hooked = true
  end
  if not self.bagScanFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("BAG_UPDATE_DELAYED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function()
      UI:ScanContainerFrames()
      UI:InitBaganator()
    end)
    self.bagScanFrame = UI.frame
  end
  if not hooked then return end
  self.bagHooked = true
  self:ScanContainerFrames()
end

function UI:InitBaganator()
  -- Метка вынесена в popup-подсказку: не создаём громоздкий corner-widget.
  self.baganatorRegistered = true
  self.baganatorError = nil
end

