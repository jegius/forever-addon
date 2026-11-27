local addonName, ns = ...
local UI = ns.UI
local L = function(key, ...) return ns.L(key, ...) end

function UI:ToggleGuide()
  if not self.guideFrame then
    local guide
    local ok = pcall(function()
      guide = CreateFrame("Frame", "ForeverAddonGuide", UIParent, "BasicFrameTemplateWithInset")
    end)
    if not ok or not guide then
      guide = CreateFrame("Frame", "ForeverAddonGuide", UIParent)
      local bg = guide:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints()
      bg:SetColorTexture(0.03, 0.03, 0.03, 0.97)
    end
    guide:SetSize(560, 300)
    guide:SetPoint("CENTER")
    guide:SetFrameStrata("DIALOG")
    guide:SetMovable(true)
    guide:EnableMouse(true)
    guide:RegisterForDrag("LeftButton")
    guide:SetScript("OnDragStart", guide.StartMoving)
    guide:SetScript("OnDragStop", guide.StopMovingOrSizing)

    guide.title = guide:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    guide.title:SetPoint("TOPLEFT", 16, -14)
    guide.title:SetText(L("GUIDE_TITLE"))
    guide.body = guide:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    guide.body:SetPoint("TOPLEFT", 16, -44)
    guide.body:SetPoint("BOTTOMRIGHT", -16, 42)
    guide.body:SetJustifyH("LEFT")
    guide.body:SetJustifyV("TOP")
    guide.body:SetWordWrap(true)

    local close = UI.SafeCreateButton(guide, "X", 28)
    close:SetPoint("BOTTOMRIGHT", -12, 10)
    close:SetScript("OnClick", function() guide:Hide() end)
    self.guideFrame = guide
  end

  if self.guideFrame:IsShown() then
    self.guideFrame:Hide()
  else
    self:UpdateGuide()
    self.guideFrame:Show()
  end
end

function UI:UpdateGuide()
  local guide = self.guideFrame
  if not guide then return end
  local label = UI.tabs[UI.activeTab] and UI.tabs[UI.activeTab]:GetText() or L("GUIDE_TITLE")
  guide.title:SetText(label)
  local text = UI.GuideTexts[UI.activeTab]
  guide.body:SetText(text and text() or "")
end

