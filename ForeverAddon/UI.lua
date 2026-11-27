-- ForeverAddon — окно аддона
local addonName, ns = ...

local UI = {}
ns.UI = UI

local L = function(key, ...) return ns.L(key, ...) end

local frame
local tabs = {}
local panels = {}
local activeTab = "scan"
local scanStatusText
local detailStatusText
local refreshPending = false
local chainsExpanded = {}

local sortStates = {
  flips = { key = "profit", dir = -1 },
  recipes = { key = "profit", dir = -1 },
  ingredients = { key = "score", dir = -1 },
  chains = { key = "profit", dir = -1 },
  professions = { key = "total", dir = -1 },
  components = { key = "profit", dir = -1 },
  farm = { key = "value", dir = -1 },
}
local SORT_ARROWS = { [1] = " ^", [-1] = " v" }

local COLUMN_TIPS = {
  flips = {
    name = function() return L("TIP_FLIP_NAME") end,
    buy = function() return L("TIP_FLIP_BUY") end,
    market = function() return L("TIP_FLIP_MARKET") end,
    profit = function() return L("TIP_FLIP_PROFIT") end,
    roi = function() return L("TIP_FLIP_ROI") end,
    qty = function() return L("TIP_FLIP_QTY") end,
    conf = function() return L("TIP_FLIP_CONF") end,
  },
  recipes = {
    name = function() return L("TIP_RECIPE_NAME") end,
    cost = function() return L("TIP_RECIPE_COST") end,
    outputPrice = function() return L("TIP_RECIPE_OUT") end,
    profit = function() return L("TIP_RECIPE_PROFIT") end,
    roi = function() return L("TIP_RECIPE_ROI") end,
    source = function() return L("TIP_RECIPE_SOURCE") end,
    learned = function() return L("TIP_RECIPE_LEARNED") end,
  },
  ingredients = {
    name = function() return L("TIP_ING_NAME") end,
    price = function() return L("TIP_ING_PRICE") end,
    uses = function() return L("TIP_ING_USES") end,
    cost = function() return L("TIP_ING_COST") end,
    source = function() return L("TIP_ING_SOURCE") end,
    profitable = function() return L("TIP_ING_PROFITABLE") end,
    score = function() return L("TIP_ING_SCORE") end,
  },
  chains = {
    name = function() return L("TIP_CHAIN_NAME") end,
    profession = function() return L("TIP_CHAIN_PROFESSION") end,
    cost = function() return L("TIP_CHAIN_COST") end,
    deValue = function() return L("TIP_CHAIN_DE") end,
    profit = function() return L("TIP_CHAIN_PROFIT") end,
    roi = function() return L("TIP_CHAIN_ROI") end,
    output = function() return L("TIP_CHAIN_OUTPUT") end,
  },
  professions = {
    name = function() return L("TIP_PROF_NAME") end,
    best = function() return L("TIP_PROF_BEST") end,
    total = function() return L("TIP_PROF_TOTAL") end,
    count = function() return L("TIP_PROF_COUNT") end,
    topName = function() return L("TIP_PROF_TOP") end,
    output = function() return L("TIP_PROF_OUTPUT") end,
    roi = function() return L("TIP_PROF_ROI") end,
  },
  components = {
    name = function() return L("TIP_COMP_NAME") end,
    profession = function() return L("TIP_COMP_PROFESSION") end,
    cost = function() return L("TIP_COMP_COST") end,
    market = function() return L("TIP_COMP_MARKET") end,
    profit = function() return L("TIP_COMP_PROFIT") end,
    roi = function() return L("TIP_COMP_ROI") end,
    usedIn = function() return L("TIP_COMP_USED") end,
  },
  farm = {
    name = function() return L("TIP_FARM_NAME") end,
    nodes = function() return L("TIP_FARM_NODES") end,
    bestName = function() return L("TIP_FARM_RESOURCE") end,
    value = function() return L("TIP_FARM_VALUE") end,
    kind = function() return L("TIP_FARM_TYPE") end,
    qty = function() return L("TIP_FARM_QTY") end,
  },
}

local TAB_TIPS = {
  scan = function() return L("TAB_SCAN_TIP") end,
  flips = function() return L("TAB_FLIPS_TIP") end,
  chart = function() return L("TAB_CHART_TIP") end,
  recipes = function() return L("TAB_RECIPES_TIP") end,
  ingredients = function() return L("TAB_INGREDIENTS_TIP") end,
  chains = function() return L("TAB_CHAINS_TIP") end,
  professions = function() return L("TAB_PROFESSIONS_TIP") end,
  components = function() return L("TAB_COMPONENTS_TIP") end,
  farm = function() return L("TAB_FARM_TIP") end,
}

local GUIDE_TEXTS = {
  scan = function() return L("GUIDE_SCAN") end,
  flips = function() return L("GUIDE_FLIPS") end,
  chart = function() return L("GUIDE_CHART") end,
  recipes = function() return L("GUIDE_RECIPES") end,
  ingredients = function() return L("GUIDE_INGREDIENTS") end,
  chains = function() return L("GUIDE_CHAINS") end,
  professions = function() return L("GUIDE_PROFESSIONS") end,
  components = function() return L("GUIDE_COMPONENTS") end,
  farm = function() return L("GUIDE_FARM") end,
}

local function safeCreateButton(parent, text, width)
  local button
  local ok = pcall(function()
    button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  end)
  if not ok or not button then
    button = CreateFrame("Button", nil, parent)
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.2, 0.2, 0.2, 0.9)
    local fs = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER")
    button:SetFontString(fs)
  end
  button:SetSize(width or 105, 24)
  button:SetText(text)
  return button
end

local function qualityName(itemID)
  local name = ns.Util:ItemName(itemID)
  local quality = ns.Util:ItemQuality(itemID)
  local ok, _, _, _, hex = pcall(GetItemQualityColor, quality)
  if ok and hex then
    return "|c" .. hex .. name .. "|r"
  end
  return name
end

local function createRow(parent)
  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(24)
  row:RegisterForClicks("LeftButtonUp")
  row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(20, 20)
  row.icon:SetPoint("LEFT", 2, 0)

  local function label(x, width, justify)
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", x, 0)
    text:SetWidth(width)
    text:SetJustifyH(justify or "LEFT")
    text:SetWordWrap(false)
    return text
  end

  row.name = label(28, 180)
  row.c1 = label(220, 70, "RIGHT")
  row.c2 = label(300, 70, "RIGHT")
  row.c3 = label(380, 80, "RIGHT")
  row.c4 = label(470, 65, "RIGHT")
  row.c5 = label(545, 55, "RIGHT")
  row.c6 = label(610, 60, "RIGHT")

  row.expandButton = safeCreateButton(row, "+", 16)
  row.expandButton:SetSize(16, 16)
  row.expandButton:SetPoint("RIGHT", -2, 0)
  row.expandButton:Hide()
  return row
end

local function createScrollPanel(panel, bottomOffset)
  local scroll = CreateFrame("ScrollFrame", nil, panel)
  scroll:SetPoint("TOPLEFT", 0, -26)
  scroll:SetPoint("BOTTOMRIGHT", -8, bottomOffset or 0)
  scroll:EnableMouseWheel(true)

  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(740, 10)
  scroll:SetScrollChild(child)

  local bar = CreateFrame("Slider", nil, panel)
  bar:SetOrientation("VERTICAL")
  bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, 0)
  bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 0)
  bar:SetWidth(12)
  local track = bar:CreateTexture(nil, "BACKGROUND")
  track:SetAllPoints(bar)
  track:SetColorTexture(0, 0, 0, 0.45)
  bar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
  bar:SetMinMaxValues(0, 1)
  bar:SetValueStep(1)
  bar:SetScript("OnValueChanged", function(_, value)
    scroll:SetVerticalScroll(value or 0)
  end)
  panel.scrollbar = bar

  local function updateBar()
    local maxScroll = math.max(0, child:GetHeight() - scroll:GetHeight())
    bar:SetMinMaxValues(0, maxScroll)
    bar:SetValue(scroll:GetVerticalScroll())
  end

  scroll:SetScript("OnScrollRangeChanged", updateBar)
  scroll:SetScript("OnVerticalScroll", function(_, offset)
    if bar:GetValue() ~= offset then bar:SetValue(offset) end
  end)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local current = self:GetVerticalScroll()
    local maxScroll = math.max(0, child:GetHeight() - self:GetHeight())
    local nextScroll = current - delta * 30
    if nextScroll < 0 then nextScroll = 0 end
    if nextScroll > maxScroll then nextScroll = maxScroll end
    self:SetVerticalScroll(nextScroll)
    bar:SetValue(nextScroll)
  end)

  return scroll, child
end

function UI:UpdateScrollbar(panel)
  if not panel or not panel.scroll or not panel.scrollbar or not panel.child then return end
  local maxScroll = math.max(0, panel.child:GetHeight() - panel.scroll:GetHeight())
  panel.scrollbar:SetMinMaxValues(0, maxScroll)
  panel.scrollbar:SetValue(panel.scroll:GetVerticalScroll())
end

local function createHeader(panel, columns, keys, tabKey, tips)
  local header = CreateFrame("Frame", nil, panel)
  header:SetPoint("TOPLEFT", 0, -6)
  header:SetPoint("TOPRIGHT", -26, -6)
  header:SetHeight(18)

  panel.headerButtons = {}
  panel.headerState = tabKey and sortStates[tabKey] or nil
  panel.columnTips = tips
  local offsets = { 28, 220, 300, 380, 470, 545, 610 }
  local widths = { 180, 70, 70, 80, 65, 55, 60 }
  for index, text in ipairs(columns) do
    local key = keys and keys[index]
    local button = CreateFrame("Button", nil, header)
    button:SetPoint("LEFT", offsets[index] or 610, 0)
    button:SetSize(widths[index] or 60, 18)
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetAllPoints(button)
    label:SetJustifyH(index == 1 and "LEFT" or "RIGHT")
    label:SetText(text)
    panel.headerButtons[index] = { button = button, label = label, text = text, key = key }
    if key and tabKey then
      button:SetScript("OnClick", function()
        UI:SetSort(tabKey, key)
      end)
    end
    local tip = tips and key and tips[key]
    if tip then
      button:SetScript("OnEnter", function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:AddLine(text, 1, 0.82, 0.2)
        GameTooltip:AddLine(tip(), 1, 1, 1, true)
        GameTooltip:Show()
      end)
      button:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
      end)
    end
  end
end

function UI:SetSort(tabKey, key)
  local state = sortStates[tabKey]
  if not state then return end
  if state.key == key then
    state.dir = -state.dir
  else
    state.key = key
    state.dir = (key == "name" or key == "source") and 1 or -1
  end
  self:UpdateHeaders()
  self:Refresh()
end

function UI:UpdateHeaders()
  for _, panel in pairs(panels) do
    local state = panel.headerState
    if panel.headerButtons and state then
      for _, entry in ipairs(panel.headerButtons) do
        local arrow = ""
        if entry.key and entry.key == state.key then
          arrow = SORT_ARROWS[state.dir] or ""
        end
        entry.label:SetText(entry.text .. arrow)
      end
    end
  end
end

local function sortValue(value)
  if type(value) == "boolean" then return value and 1 or 0 end
  if type(value) == "number" then return value end
  return tostring(value or "")
end

function UI:SortData(list, tabKey)
  local state = sortStates[tabKey]
  if not state or #list < 2 then return list end
  local key, dir = state.key, state.dir
  table.sort(list, function(a, b)
    local av, bv = sortValue(a[key]), sortValue(b[key])
    if type(av) == "number" or type(bv) == "number" then
      av, bv = tonumber(av) or 0, tonumber(bv) or 0
    end
    if av == bv then
      return tostring(a.name or "") < tostring(b.name or "")
    end
    if dir >= 0 then return av < bv end
    return av > bv
  end)
  return list
end

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

function UI:GetItemCategory(itemID)
  if not itemID then return "junk", nil, 0 end
  local median = ns.Market:GetMarketValue(itemID)
    or ns.Market:GetResale(itemID)
    or ns.Market:GetPrice(itemID)
  local qty = ns.Market:GetQuantity(itemID) or 0
  local craft = ns.Recipes and ns.Recipes:GetCraftUseIndex()[itemID] or nil
  if not median then return "unknown", nil, qty end
  if median >= 100000 then return "very", median, qty end
  if craft then return "craft", median, qty end
  if median >= 100 then return "medium", median, qty end
  return "junk", median, qty
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
    GameTooltip:AddLine(qualityName(itemID))
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

local function hideRows(panel, used)
  for index = used + 1, #(panel.rows or {}) do
    panel.rows[index]:Hide()
  end
end

function UI:GetRow(panel, index)
  panel.rows = panel.rows or {}
  local row = panel.rows[index]
  if not row then
    row = createRow(panel.child)
    panel.rows[index] = row
  end
  row:ClearAllPoints()
  row:SetPoint("TOPLEFT", panel.child, "TOPLEFT", 0, -(index - 1) * 24)
  row:SetPoint("TOPRIGHT", panel.child, "TOPRIGHT", -4, -(index - 1) * 24)
  return row
end

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

  if frame.TitleText then
    frame.TitleText:SetText(L("TITLE"))
  else
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -6)
    title:SetText(L("TITLE"))
  end

  local helpButton = safeCreateButton(frame, "?", 24)
  helpButton:SetSize(24, 24)
  helpButton:SetPoint("TOPRIGHT", -30, -4)
  helpButton:SetScript("OnClick", function() UI:ToggleGuide() end)

  if not frame.CloseButton then
    local close
    local okClose = pcall(function()
      close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
      close:SetPoint("TOPRIGHT", -4, -4)
    end)
    if not okClose or not close then
      close = safeCreateButton(frame, "X", 24)
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
    local button = safeCreateButton(frame, definition.label, 78)
    button:SetPoint("TOPLEFT", 12 + (index - 1) * 86, -32)
    button:SetScript("OnClick", function() UI:SetTab(definition.key) end)
    button:SetScript("OnEnter", function()
      if not GameTooltip then return end
      GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
      GameTooltip:AddLine(definition.label, 1, 0.82, 0.2)
      local tip = TAB_TIPS[definition.key]
      if tip then GameTooltip:AddLine(tip(), 1, 1, 1, true) end
      GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
      if GameTooltip then GameTooltip:Hide() end
    end)
    tabs[definition.key] = button
  end

  for _, definition in ipairs(tabDefinitions) do
    local panel = CreateFrame("Frame", nil, frame)
    panel:SetPoint("TOPLEFT", 12, -64)
    panel:SetPoint("BOTTOMRIGHT", -12, 12)
    panel:Hide()
    panels[definition.key] = panel
  end

  self:BuildScanPanel(panels.scan)
  self:BuildFlipsPanel(panels.flips)
  self:BuildChartPanel(panels.chart)
  self:BuildRecipesPanel(panels.recipes)
  self:BuildIngredientsPanel(panels.ingredients)
  self:BuildChainsPanel(panels.chains)
  self:BuildProfessionsPanel(panels.professions)
  self:BuildComponentsPanel(panels.components)
  self:BuildFarmPanel(panels.farm)

  self.frame = frame
  local function tryInit(name, fn)
    local ok, err = pcall(fn)
    if not ok then
      self.initErrors = self.initErrors or {}
      self.initErrors[name] = tostring(err)
      ns:Print("ForeverAddon init " .. name .. ": " .. tostring(err))
    end
  end
  tryInit("tooltips", function() self:InitTooltips() end)
  tryInit("bags", function() self:InitBagMarks() end)
  tryInit("baganator", function() self:InitBaganator() end)
  pcall(self.SetTab, self, "scan")
  C_Timer.After(1, function()
    UI:InitTooltips()
    UI:InitBagMarks()
    UI:InitBaganator()
  end)
  C_Timer.After(5, function()
    UI:InitBaganator()
  end)
  C_Timer.After(10, function()
    UI:InitBaganator()
    UI:InitBagMarks()
    UI:ScanContainerFrames()
  end)
end

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
    self.bagScanFrame = frame
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

function UI:BuildScanPanel(panel)
  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 4, -4)
  title:SetText(L("SCAN_TITLE"))

  panel.status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  panel.status:SetPoint("TOPLEFT", 4, -36)
  panel.status:SetWidth(700)
  panel.status:SetJustifyH("LEFT")

  panel.stats = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  panel.stats:SetPoint("TOPLEFT", 4, -80)
  panel.stats:SetWidth(700)
  panel.stats:SetJustifyH("LEFT")

  panel.last = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  panel.last:SetPoint("TOPLEFT", 4, -140)
  panel.last:SetText(L("NO_DATA"))

  panel.button = safeCreateButton(panel, L("SCAN_BTN"), 220)
  panel.button:SetSize(220, 30)
  panel.button:SetPoint("TOPLEFT", 4, -180)
  panel.button:SetScript("OnClick", function()
    ns.Auction:StartScan()
  end)

  panel.hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  panel.hint:SetPoint("TOPLEFT", 4, -228)
  panel.hint:SetWidth(700)
  panel.hint:SetJustifyH("LEFT")
  panel.hint:SetText(L("SCAN_NEED_AH"))

  panel.detail = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  panel.detail:SetPoint("TOPLEFT", 4, -206)
  panel.detail:SetWidth(700)
  panel.detail:SetJustifyH("LEFT")
  panel.detail:SetText(detailStatusText or "")
end

function UI:BuildFlipsPanel(panel)
  createHeader(panel, {
    L("FLIP_NAME"), L("FLIP_BUY"), L("FLIP_MV"), L("FLIP_PROFIT"), L("FLIP_ROI"), L("FLIP_QTY"), L("FLIP_CONF"),
  }, { "name", "buy", "market", "profit", "roi", "qty", "conf" }, "flips", COLUMN_TIPS.flips)

  panel.scroll, panel.child = createScrollPanel(panel, 20)
  panel.rows = {}
  panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  panel.empty:SetPoint("CENTER", 0, 40)
  panel.empty:SetText(L("FLIP_EMPTY"))

  local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("BOTTOMLEFT", 4, 2)
  hint:SetText(L("FLIP_HINT"))

  panel.detail = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  panel.detail:SetPoint("BOTTOMRIGHT", -28, 2)
  panel.detail:SetText(detailStatusText or "")
end

function UI:BuildChartPanel(panel)
  ns.Charts:Init(panel)
end

function UI:BuildRecipesPanel(panel)
  createHeader(panel, {
    L("RECIPE_NAME"), L("RECIPE_COST"), L("RECIPE_OUT"), L("RECIPE_PROFIT"), L("RECIPE_ROI"), L("RECIPE_SOURCE"), L("RECIPE_LEARNED"),
  }, { "name", "cost", "outputPrice", "profit", "roi", "source", "learned" }, "recipes", COLUMN_TIPS.recipes)

  panel.scroll, panel.child = createScrollPanel(panel, 44)
  panel.rows = {}
  panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  panel.empty:SetPoint("CENTER", 0, 40)
  panel.empty:SetText(L("RECIPE_EMPTY"))

  panel.status = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  panel.status:SetPoint("BOTTOMLEFT", 4, 34)

  panel.button = safeCreateButton(panel, L("RECIPE_BTN"), 220)
  panel.button:SetSize(220, 26)
  panel.button:SetPoint("BOTTOMLEFT", 4, 2)
  panel.button:SetScript("OnClick", function()
    ns.Recipes:StartScan()
  end)

  panel.buttonAll = safeCreateButton(panel, L("RECIPE_BTN_ALL"), 190)
  panel.buttonAll:SetSize(190, 26)
  panel.buttonAll:SetPoint("BOTTOMLEFT", 232, 2)
  panel.buttonAll:SetScript("OnClick", function()
    ns.Recipes:StartScanAll()
  end)
end

function UI:BuildIngredientsPanel(panel)
  createHeader(panel, {
    L("ING_NAME"), L("ING_PRICE"), L("ING_USES"), L("ING_COST"), L("ING_SOURCE"), L("ING_PROFITABLE"), L("ING_SCORE"),
  }, { "name", "price", "uses", "cost", "source", "profitable", "score" }, "ingredients", COLUMN_TIPS.ingredients)

  panel.scroll, panel.child = createScrollPanel(panel, 20)
  panel.rows = {}
  panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  panel.empty:SetPoint("CENTER", 0, 40)
  panel.empty:SetText(L("ING_EMPTY"))

  local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("BOTTOMLEFT", 4, 2)
  hint:SetWidth(700)
  hint:SetJustifyH("LEFT")
  hint:SetText(L("ING_NOTE"))
end

function UI:BuildChainsPanel(panel)
  createHeader(panel, {
    L("CHAIN_RECIPE"), L("CHAIN_PROFESSION"), L("CHAIN_COST"), L("CHAIN_DE"), L("CHAIN_PROFIT"), L("CHAIN_ROI"), L("CHAIN_OUTPUT"),
  }, { "name", "profession", "cost", "deValue", "profit", "roi", "output" }, "chains", COLUMN_TIPS.chains)

  panel.scroll, panel.child = createScrollPanel(panel, 44)
  panel.rows = {}
  panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  panel.empty:SetPoint("CENTER", 0, 40)
  panel.empty:SetText(L("CHAIN_EMPTY"))

  local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("BOTTOMLEFT", 4, 34)
  hint:SetWidth(700)
  hint:SetJustifyH("LEFT")
  hint:SetText(L("CHAIN_HINT"))

  panel.priceButton = safeCreateButton(panel, L("CATALOG_BTN_PRICES"), 220)
  panel.priceButton:SetSize(220, 26)
  panel.priceButton:SetPoint("BOTTOMLEFT", 4, 2)
  panel.priceButton:SetScript("OnClick", function()
    ns.Recipes:ScanCatalogPrices()
  end)
end

function UI:BuildProfessionsPanel(panel)
  createHeader(panel, {
    L("PROF_NAME"), L("PROF_BEST"), L("PROF_TOTAL"), L("PROF_COUNT"), L("PROF_TOP"), L("PROF_OUTPUT"), L("PROF_ROI"),
  }, { "name", "best", "total", "count", "topName", "output", "roi" }, "professions", COLUMN_TIPS.professions)

  panel.scroll, panel.child = createScrollPanel(panel, 44)
  panel.rows = {}
  panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  panel.empty:SetPoint("CENTER", 0, 40)
  panel.empty:SetText(L("PROF_EMPTY"))

  local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("BOTTOMLEFT", 4, 34)
  hint:SetWidth(700)
  hint:SetJustifyH("LEFT")
  hint:SetText(L("PROF_HINT"))

  panel.priceButton = safeCreateButton(panel, L("CATALOG_BTN_PRICES"), 220)
  panel.priceButton:SetSize(220, 26)
  panel.priceButton:SetPoint("BOTTOMLEFT", 4, 2)
  panel.priceButton:SetScript("OnClick", function()
    ns.Recipes:ScanCatalogPrices()
  end)
end

function UI:BuildComponentsPanel(panel)
  createHeader(panel, {
    L("COMP_NAME"), L("COMP_PROFESSION"), L("COMP_COST"), L("COMP_MARKET"), L("COMP_PROFIT"), L("COMP_ROI"), L("COMP_USED"),
  }, { "name", "profession", "cost", "market", "profit", "roi", "usedIn" }, "components", COLUMN_TIPS.components)

  panel.scroll, panel.child = createScrollPanel(panel, 20)
  panel.rows = {}
  panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  panel.empty:SetPoint("CENTER", 0, 40)
  panel.empty:SetText(L("COMP_EMPTY"))

  local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("BOTTOMLEFT", 4, 2)
  hint:SetWidth(700)
  hint:SetJustifyH("LEFT")
  hint:SetText(L("COMP_HINT"))
end

function UI:BuildFarmPanel(panel)
  createHeader(panel, {
    L("FARM_ZONE"), L("FARM_NODES"), L("FARM_RESOURCE"), L("FARM_VALUE"), L("FARM_TYPE"), "", "",
  }, { "name", "nodes", "bestName", "value", "kind", nil, nil }, "farm", COLUMN_TIPS.farm)

  panel.scroll, panel.child = createScrollPanel(panel, 20)
  panel.rows = {}
  panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  panel.empty:SetPoint("CENTER", 0, 40)
  panel.empty:SetText(L("FARM_EMPTY"))

  local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("BOTTOMLEFT", 4, 2)
  hint:SetWidth(700)
  hint:SetJustifyH("LEFT")
  hint:SetText(L("FARM_NOTE"))
end

function UI:SetTab(key)
  activeTab = key
  for panelKey, panel in pairs(panels) do
    panel:SetShown(panelKey == key)
  end
  if self.guideFrame and self.guideFrame:IsShown() then
    self:UpdateGuide()
  end
  self:Refresh()
end

function UI:SetScanStatus(text)
  scanStatusText = text
  if panels.scan and panels.scan.status then
    panels.scan.status:SetText(text)
  end
end

function UI:SetRecipeStatus(text)
  if panels.recipes and panels.recipes.status then
    panels.recipes.status:SetText(text)
  end
end

function UI:SetDetailStatus(text)
  detailStatusText = text
  if panels.scan and panels.scan.detail then
    panels.scan.detail:SetText(text or "")
  end
  if panels.flips and panels.flips.detail then
    panels.flips.detail:SetText(text or "")
  end
end

function UI:Refresh()
  if not frame or not frame:IsShown() then return end
  self:UpdateHeaders()

  if activeTab == "scan" then
    self:RefreshScan()
  elseif activeTab == "flips" then
    self:RefreshFlips()
  elseif activeTab == "chart" then
    ns.Charts:Render(ns.Market:GetSelectedItem())
  elseif activeTab == "recipes" then
    self:RefreshRecipes()
  elseif activeTab == "ingredients" then
    self:RefreshIngredients()
  elseif activeTab == "chains" then
    self:RefreshChains()
  elseif activeTab == "professions" then
    self:RefreshProfessions()
  elseif activeTab == "components" then
    self:RefreshComponents()
  elseif activeTab == "farm" then
    self:RefreshFarm()
  end
  self:UpdateScrollbar(panels[activeTab])
end

function UI:ScheduleRefresh()
  if refreshPending then return end
  refreshPending = true
  C_Timer.After(0.05, function()
    refreshPending = false
    UI:Refresh()
  end)
end

function UI:RefreshScan()
  local panel = panels.scan
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

  if scanStatusText then
    panel.status:SetText(scanStatusText)
  elseif ns.Auction:IsScanning() then
    panel.status:SetText(L("SCAN_BTN_BUSY"))
  else
    panel.status:SetText("")
  end

  if panel.detail then
    panel.detail:SetText(detailStatusText or "")
  end
end

function UI:RefreshFlips()
  local panel = panels.flips
  local flips = ns.Market:GetFlips(100)
  for _, flip in ipairs(flips) do
    flip.name = qualityName(flip.itemID)
  end
  flips = self:SortData(flips, "flips")
  panel.empty:SetShown(#flips == 0)
  panel.child:SetHeight(math.max(1, #flips * 24))

  for index, flip in ipairs(flips) do
    local row = self:GetRow(panel, index)
    local itemID = flip.itemID
    row.icon:SetTexture(ns.Util:ItemIcon(itemID))
    row.name:SetText(qualityName(itemID))
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
  hideRows(panel, #flips)
end

function UI:RefreshRecipes()
  local panel = panels.recipes
  local list = self:SortData(ns.Recipes:GetAll(), "recipes")
  panel.empty:SetShown(#list == 0)
  panel.child:SetHeight(math.max(1, #list * 24))

  for index, recipe in ipairs(list) do
    local row = self:GetRow(panel, index)
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
    row:Show()
  end
  hideRows(panel, #list)

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
  local panel = panels.ingredients
  local list = ns.Recipes:GetIngredients()
  for _, ingredient in ipairs(list) do
    ingredient.name = qualityName(ingredient.itemID)
  end
  list = self:SortData(list, "ingredients")
  panel.empty:SetShown(#list == 0)
  panel.child:SetHeight(math.max(1, #list * 24))

  for index, ingredient in ipairs(list) do
    local row = self:GetRow(panel, index)
    row.icon:SetTexture(ns.Util:ItemIcon(ingredient.itemID))
    row.name:SetText(qualityName(ingredient.itemID))
    row.c1:SetText(ns.Util:Money(ingredient.price, true))
    row.c2:SetText(tostring(ingredient.uses))
    row.c3:SetText(ns.Util:Money(ingredient.cost, true))
    row.c4:SetText(ingredient.source or "—")
    row.c5:SetText(tostring(ingredient.profitable))
    row.c6:SetText(ns.Util:FormatNumber(math.floor(ingredient.score or 0)))
    self:BindItemRow(row, ingredient.itemID)
    self:MarkItem(row, ingredient.itemID)
    row:Show()
  end
  hideRows(panel, #list)
end

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
  if chain.suspicious then
    GameTooltip:AddLine(L("CHAIN_TIP_RISK"), 1, 0.4, 0.25)
  end
  GameTooltip:Show()
end

function UI:RefreshChains()
  local panel = panels.chains
  local list = self:SortData(ns.Recipes:GetCatalogChains(), "chains")
  local lines = {}
  for _, chain in ipairs(list) do
    lines[#lines + 1] = { kind = "chain", chain = chain }
    if chainsExpanded[chain.recipeID] then
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
      row.expandButton:SetText(chainsExpanded[chain.recipeID] and "-" or "+")
      row.expandButton:SetScript("OnClick", function()
        chainsExpanded[chain.recipeID] = not chainsExpanded[chain.recipeID] or nil
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
  hideRows(panel, #lines)
end

function UI:RefreshProfessions()
  local panel = panels.professions
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
  hideRows(panel, #list)
end

function UI:RefreshComponents()
  local panel = panels.components
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
  hideRows(panel, #list)
end

function UI:RefreshFarm()
  local panel = panels.farm
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
      row.name:SetText(qualityName(item.itemID))
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
  hideRows(panel, #lines)
end

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

    local close = safeCreateButton(guide, "X", 28)
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
  local label = tabs[activeTab] and tabs[activeTab]:GetText() or L("GUIDE_TITLE")
  guide.title:SetText(label)
  local text = GUIDE_TEXTS[activeTab]
  guide.body:SetText(text and text() or "")
end

function UI:PrintBagDiagnostics()
  if not self.bagHooked then pcall(function() self:InitBagMarks() end) end
  if not self.baganatorRegistered then pcall(function() self:InitBaganator() end) end
  pcall(function() self:ScanContainerFrames() end)
  ns:Print("Baganator: " .. tostring(Baganator ~= nil))
  ns:Print("Baganator API: " .. tostring(Baganator and Baganator.API ~= nil))
  if Baganator and Baganator.API then
    if Baganator.API.IsCornerWidgetActive then
      ns:Print("forever_value active: " .. tostring(Baganator.API.IsCornerWidgetActive("forever_value")))
    end
    if Baganator.API.GetCurrentCornerForWidget then
      ns:Print("forever_value corner: " .. tostring(Baganator.API.GetCurrentCornerForWidget("forever_value")))
    end
  end
  ns:Print("bagHooked: " .. tostring(self.bagHooked))
  ns:Print("baganatorRegistered: " .. tostring(self.baganatorRegistered))
  ns:Print("tooltipHooked: " .. tostring(self.tooltipHooked))
  local sample = ns.Market:GetRecommendedPrice(10940)
  ns:Print("sample 10940 recommended: " .. tostring(sample))
  if self.baganatorError then
    ns:Print("baganatorError: " .. tostring(self.baganatorError))
  end
end

function UI:ShowChart(itemID)
  if not itemID then return end
  ns.Market:SetSelectedItem(itemID)
  self:SetTab("chart")
  ns.Charts:Render(itemID)
end

function UI:Toggle()
  if not frame then return end
  if frame:IsShown() then
    frame:Hide()
  else
    frame:Show()
    self:Refresh()
  end
end

function UI:Open()
  if frame then
    frame:Show()
    self:Refresh()
  end
end
