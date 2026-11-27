local addonName, ns = ...
local UI = ns.UI
local frame
local L = function(key, ...) return ns.L(key, ...) end

function UI:Init()
  local created = false
  pcall(function()
    frame = CreateFrame("Frame", "ForeverAddonFrame", UIParent, "BasicFrameTemplateWithInset")
    created = frame ~= nil
  end)
  if not created or not frame then
    frame = CreateFrame("Frame", "ForeverAddonFrame", UIParent)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.03, 0.03, 0.03, 0.95)
  end
  frame:SetSize(800, 560)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:Hide()

  if type(frame.TitleText) == "table" and frame.TitleText.SetText then
    frame.TitleText:SetText(L("TITLE"))
  else
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -6)
    title:SetText(L("TITLE"))
  end

  local helpButton = UI.SafeCreateButton(frame, "?", 24)
  helpButton:SetSize(24, 24)
  helpButton:SetPoint("TOPRIGHT", -30, -4)
  helpButton:SetScript("OnClick", function() UI:ToggleGuide() end)

  local search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  search:SetSize(180, 22)
  search:SetPoint("TOPRIGHT", -60, -4)
  search:SetAutoFocus(false)
  search:SetText(UI.filterText or "")
  search:SetScript("OnTextChanged", function(_, userInput)
    if userInput then
      UI.filterText = search:GetText()
      UI:ScheduleRefresh()
    end
  end)
  search:SetScript("OnEscapePressed", function() search:ClearFocus() end)
  UI.searchBox = search

  if not frame.CloseButton then
    local close
    local okClose = pcall(function()
      close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
      close:SetPoint("TOPRIGHT", -4, -4)
    end)
    if not okClose or not close then
      close = UI.SafeCreateButton(frame, "X", 24)
      close:SetPoint("TOPRIGHT", -4, -4)
      close:SetScript("OnClick", function() frame:Hide() end)
    end
  end

  local tabDefinitions = {
    { key = "scan", label = L("TAB_SCAN") },
    { key = "flips", label = L("TAB_FLIPS") },
    { key = "chart", label = L("TAB_CHART") },
    { key = "recipes", label = L("TAB_RECIPES") },
    { key = "ingredients", label = L("TAB_INGREDIENTS") },
    { key = "chains", label = L("TAB_CHAINS") },
    { key = "professions", label = L("TAB_PROFESSIONS") },
    { key = "components", label = L("TAB_COMPONENTS") },
    { key = "farm", label = L("TAB_FARM") },
  }

  for index, definition in ipairs(tabDefinitions) do
    local button = UI.SafeCreateButton(frame, definition.label, 82)
    button:SetPoint("TOPLEFT", 12 + (index - 1) * 86, -32)
    if button.GetFontString then
      local fontString = button:GetFontString()
      if fontString and fontString.SetFontObject then fontString:SetFontObject(GameFontNormalSmall) end
    end
    button:SetScript("OnClick", function() UI:SetTab(definition.key) end)
    button:SetScript("OnEnter", function()
      if not GameTooltip then return end
      GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
      GameTooltip:AddLine(definition.label, 1, 0.82, 0.2)
      local tip = UI.TabTips[definition.key]
      if tip then GameTooltip:AddLine(tip(), 1, 1, 1, true) end
      GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
      if GameTooltip then GameTooltip:Hide() end
    end)
    UI.tabs[definition.key] = button
  end

  for _, definition in ipairs(tabDefinitions) do
    local panel = CreateFrame("Frame", nil, frame)
    panel:SetPoint("TOPLEFT", 12, -64)
    panel:SetPoint("BOTTOMRIGHT", -12, 12)
    panel:Hide()
    UI.panels[definition.key] = panel
  end

  self:BuildScanPanel(UI.panels.scan)
  self:BuildFlipsPanel(UI.panels.flips)
  self:BuildChartPanel(UI.panels.chart)
  self:BuildRecipesPanel(UI.panels.recipes)
  self:BuildIngredientsPanel(UI.panels.ingredients)
  self:BuildChainsPanel(UI.panels.chains)
  self:BuildProfessionsPanel(UI.panels.professions)
  self:BuildComponentsPanel(UI.panels.components)
  self:BuildFarmPanel(UI.panels.farm)

  self.frame = frame
  UI.frame = frame
  local function tryInit(name, fn)
    local ok, err = pcall(fn)
    if not ok then
      self.initErrors = self.initErrors or {}
      self.initErrors[name] = tostring(err)
      ns:Print("ForeverAddon init " .. name .. ": " .. tostring(err))
    end
  end
  tryInit("tooltips", function() self:InitTooltips() end)
  pcall(self.SetTab, self, "scan")
end

function UI:SetTab(key)
  UI.activeTab = key
  for panelKey, panel in pairs(UI.panels) do
    panel:SetShown(panelKey == key)
  end
  if self.guideFrame and self.guideFrame:IsShown() then
    self:UpdateGuide()
  end
  self:Refresh()
end

function UI:SetScanStatus(text)
  UI.scanStatusText = text
  if UI.panels.scan and UI.panels.scan.status then
    UI.panels.scan.status:SetText(text)
  end
end

function UI:SetRecipeStatus(text)
  if UI.panels.recipes and UI.panels.recipes.status then
    UI.panels.recipes.status:SetText(text)
  end
end

function UI:SetDetailStatus(text)
  UI.detailStatusText = text
  if UI.panels.scan and UI.panels.scan.detail then
    UI.panels.scan.detail:SetText(text or "")
  end
  if UI.panels.flips and UI.panels.flips.detail then
    UI.panels.flips.detail:SetText(text or "")
  end
end

function UI:Refresh()
  if not UI.frame or not UI.frame:IsShown() then return end
  self:UpdateHeaders()

  if UI.activeTab == "scan" then
    self:RefreshScan()
  elseif UI.activeTab == "flips" then
    self:RefreshFlips()
  elseif UI.activeTab == "chart" then
    ns.Charts:Render(ns.Market:GetSelectedItem())
  elseif UI.activeTab == "recipes" then
    self:RefreshRecipes()
  elseif UI.activeTab == "ingredients" then
    self:RefreshIngredients()
  elseif UI.activeTab == "chains" then
    self:RefreshChains()
  elseif UI.activeTab == "professions" then
    self:RefreshProfessions()
  elseif UI.activeTab == "components" then
    self:RefreshComponents()
  elseif UI.activeTab == "farm" then
    self:RefreshFarm()
  end
  self:UpdateScrollbar(UI.panels[UI.activeTab])
end

function UI:ScheduleRefresh()
  if UI.refreshPending then return end
  UI.refreshPending = true
  C_Timer.After(0.05, function()
    UI.refreshPending = false
    UI:Refresh()
  end)
end

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
    parts[#parts + 1] = L("SCAN_SECONDS", stats.duration)
  end
  if ns.catalogError then
    parts[#parts + 1] = L("CATALOG_INVALID", ns.catalogError)
  end
  panel.stats:SetText(table.concat(parts, "\n"))

  local summary = {}
  local flipOk, flips = pcall(ns.Market.GetFlips, ns.Market, 3)
  if flipOk and flips and flips[1] then
    local top = flips[1]
    summary[#summary + 1] = L("DASH_FLIP", top.name, ns.Util:Money(top.current or top.buy, true),
      ns.Util:Money(top.median or top.market, true), ns.Util:Money(top.market, true),
      ns.Util:Money(top.profit, true))
  end
  local chains = ns.Recipes:GetCatalogChains()
  if chains and chains[1] then
    local top = chains[1]
    summary[#summary + 1] = L("DASH_CHAIN", top.name, ns.Util:Money(top.cost, true),
      ns.Util:Money(top.profit, true))
  elseif ns.Recipes:IsCatalogChainsBuilding() then
    summary[#summary + 1] = L("CHAIN_BUILDING")
  end
  if #summary == 0 then summary[1] = L("DASH_NO_DATA") end
  if panel.summary then
    panel.summary:SetText(table.concat(summary, "\n") .. "\n" .. L("DASH_PRICE_NOTE"))
  end

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

function UI:PrintBagDiagnostics()
  ns:Print("bag marks disabled: inventory prices are shown in the item tooltip")
end

function UI:ShowChart(itemID)
  if not itemID then return end
  ns.Market:SetSelectedItem(itemID)
  self:SetTab("chart")
  ns.Charts:Render(itemID)
end

function UI:Toggle()
  if not frame then return end
  if UI.frame:IsShown() then
    frame:Hide()
  else
    UI.frame:Show()
    self:Refresh()
  end
end

function UI:Open()
  if UI.frame then
    UI.frame:Show()
    self:Refresh()
  end
end


