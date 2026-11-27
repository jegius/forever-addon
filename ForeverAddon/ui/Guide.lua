local addonName, ns = ...
local UI = ns.UI
local L = function(key, ...) return ns.L(key, ...) end

function UI:ToggleGuide()
  if not self.guideFrame then
    local parent = UI.frame or UIParent
    local guide
    local ok = pcall(function()
      guide = CreateFrame("Frame", "ForeverAddonGuide", parent, "BasicFrameTemplateWithInset")
    end)
    if not ok or not guide then
      guide = CreateFrame("Frame", "ForeverAddonGuide", parent)
      local bg = guide:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints()
      bg:SetColorTexture(0.03, 0.03, 0.03, 0.97)
    end
    guide:SetSize(560, 300)
    guide:SetPoint("CENTER", parent, "CENTER", 0, 0)
    guide:SetFrameStrata("FULLSCREEN_DIALOG")
    if UI.frame and type(UI.frame.GetFrameLevel) == "function" then local level = UI.frame:GetFrameLevel(); if type(level) == "number" then guide:SetFrameLevel(level + 20) end end
    guide:SetClampedToScreen(true)
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
    guide.body:SetPoint("BOTTOMRIGHT", -16, 16)
    guide.body:SetJustifyH("LEFT")
    guide.body:SetJustifyV("TOP")
    guide.body:SetWordWrap(true)

    -- Close is in the title bar (BasicFrameTemplateWithInset); only add a
    -- top-right fallback for a plain frame.
    if not guide.CloseButton then
      local close = UI.SafeCreateButton(guide, "X", 24)
      close:SetPoint("TOPRIGHT", -8, -8)
      close:SetScript("OnClick", function() guide:Hide() end)
    end
    self.guideFrame = guide
  end

  if self.guideFrame:IsShown() then
    self.guideFrame:Hide()
  else
    self.guideFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    if UI.frame and type(UI.frame.GetFrameLevel) == "function" then
      local level = UI.frame:GetFrameLevel()
      if type(level) == "number" then self.guideFrame:SetFrameLevel(level + 20) end
    end
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

function UI:ShowAdvice()
  local parent = UI.frame or UIParent
  if not self.adviceFrame then
    local frame
    local ok = pcall(function()
      frame = CreateFrame("Frame", "ForeverAddonAdvice", parent, "BasicFrameTemplateWithInset")
    end)
    if not ok or not frame then
      frame = CreateFrame("Frame", "ForeverAddonAdvice", parent)
      local bg = frame:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints()
      bg:SetColorTexture(0.03, 0.03, 0.03, 0.97)
    end
    frame:SetSize(640, 400)
    frame:SetPoint("CENTER", parent, "CENTER", 0, 0)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    if UI.frame and type(UI.frame.GetFrameLevel) == "function" then local level = UI.frame:GetFrameLevel(); if type(level) == "number" then frame:SetFrameLevel(level + 20) end end
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 16, -14)
    frame.title:SetText(L("ADVICE_TITLE"))
    frame.body = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.body:SetPoint("TOPLEFT", 16, -44)
    frame.body:SetPoint("BOTTOMRIGHT", -16, 16)
    frame.body:SetJustifyH("LEFT")
    frame.body:SetJustifyV("TOP")
    frame.body:SetWordWrap(true)
    if not frame.CloseButton then
      local close = UI.SafeCreateButton(frame, "X", 24)
      close:SetPoint("TOPRIGHT", -8, -8)
      close:SetScript("OnClick", function() frame:Hide() end)
    end
    self.adviceFrame = frame
  end

  local ok, lines = pcall(function()
    return ns.Advisor:Report()
  end)
  local body
  if not ok then
    body = "Advisor error: " .. tostring(lines)
  else
    body = table.concat(lines or {}, "\n\n")
    if body == "" then body = L("ADVICE_EMPTY") end
  end
  self.adviceFrame.body:SetText(body)
  self.adviceFrame:SetFrameStrata("FULLSCREEN_DIALOG")
  if UI.frame and type(UI.frame.GetFrameLevel) == "function" then local level = UI.frame:GetFrameLevel(); if type(level) == "number" then self.adviceFrame:SetFrameLevel(level + 20) end end
  self.adviceFrame:Show()
end


