local addonName, ns = ...
local UI = ns.UI
local L = function(key, ...) return ns.L(key, ...) end

function UI.SafeCreateButton(parent, text, width)
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

function UI.QualityName(itemID)
  local name = ns.Util:ItemName(itemID)
  local quality = ns.Util:ItemQuality(itemID)
  local ok, _, _, _, hex = pcall(GetItemQualityColor, quality)
  if ok and hex then
    return "|c" .. hex .. name .. "|r"
  end
  return name
end

function UI.CreateRow(parent)
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

  row.expandButton = UI.SafeCreateButton(row, "+", 16)
  row.expandButton:SetSize(16, 16)
  row.expandButton:SetPoint("RIGHT", -2, 0)
  row.expandButton:Hide()
  return row
end

function UI:MatchesFilter(text)
  local term = string.lower(UI.filterText or "")
  if term == "" then return true end
  return string.find(string.lower(tostring(text or "")), term, 1, true) ~= nil
end

function UI.CreateScrollPanel(panel, bottomOffset)
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
    if panel.virtualLines then
      UI:RenderVirtual(panel, panel.virtualLines, panel.virtualBinder)
    end
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

function UI:RenderVirtual(panel, lines, binder)
  panel.virtualLines = lines
  panel.virtualBinder = binder
  panel.rows = panel.rows or {}
  local scroll = panel.scroll
  local offset = scroll and scroll:GetVerticalScroll() or 0
  local height = scroll and scroll:GetHeight() or 360
  local first = math.max(1, math.floor(offset / 24) + 1)
  local last = math.min(#lines, first + math.ceil(height / 24) + 2)
  local slot = 0

  for index = first, last do
    slot = slot + 1
    local row = panel.rows[slot]
    if not row then
      row = UI.CreateRow(panel.child)
      panel.rows[slot] = row
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", panel.child, "TOPLEFT", 0, -(index - 1) * 24)
    row:SetPoint("TOPRIGHT", panel.child, "TOPRIGHT", -4, -(index - 1) * 24)
    binder(row, lines[index], index)
    row:Show()
  end
  for index = slot + 1, #panel.rows do panel.rows[index]:Hide() end
  panel.child:SetHeight(math.max(1, #lines * 24))
  if panel.empty then panel.empty:SetShown(#lines == 0) end
end

function UI:UpdateScrollbar(panel)
  if not panel or not panel.scroll or not panel.scrollbar or not panel.child then return end
  local maxScroll = math.max(0, panel.child:GetHeight() - panel.scroll:GetHeight())
  panel.scrollbar:SetMinMaxValues(0, maxScroll)
  panel.scrollbar:SetValue(panel.scroll:GetVerticalScroll())
end

function UI.CreateHeader(panel, columns, keys, tabKey, tips)
  local header = CreateFrame("Frame", nil, panel)
  header:SetPoint("TOPLEFT", 0, -6)
  header:SetPoint("TOPRIGHT", -26, -6)
  header:SetHeight(18)

  panel.headerButtons = {}
  panel.headerState = tabKey and UI.SortStates[tabKey] or nil
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
  local state = UI.SortStates[tabKey]
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
  for _, panel in pairs(UI.panels) do
    local state = panel.headerState
    if panel.headerButtons and state then
      for _, entry in ipairs(panel.headerButtons) do
        local arrow = ""
        if entry.key and entry.key == state.key then
          arrow = UI.SortArrows[state.dir] or ""
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
  local state = UI.SortStates[tabKey]
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

