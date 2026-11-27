-- ForeverAddon — линейный график цен: дневная история или сэмплы сканов
local addonName, ns = ...

local Charts = {}
ns.Charts = Charts

local L = function(key, ...) return ns.L(key, ...) end

local DAYS = 30
local WIDTH = 700
local HEIGHT = 230
local PAD_LEFT = 10
local PAD_RIGHT = 10
local PAD_TOP = 14
local PAD_BOTTOM = 22

function Charts:Init(parent)
  self.parent = parent
  self.lines = {}
  self.dots = {}
  self.records = {}

  self.title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  self.title:SetPoint("TOPLEFT", 12, -12)
  self.title:SetText(L("CHART_TITLE"))

  self.subtitle = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  self.subtitle:SetPoint("TOPLEFT", 12, -32)
  self.subtitle:SetText("мин. цена, медь")

  self.canvas = CreateFrame("Frame", nil, parent)
  self.canvas:SetPoint("TOPLEFT", 12, -52)
  self.canvas:SetSize(WIDTH, HEIGHT)

  self.canvas.bg = self.canvas:CreateTexture(nil, "BACKGROUND")
  self.canvas.bg:SetAllPoints()
  self.canvas.bg:SetColorTexture(0, 0, 0, 0.35)

  for index = 1, 4 do
    local line = self.canvas:CreateTexture(nil, "BACKGROUND")
    line:SetColorTexture(1, 1, 1, 0.08)
    line:SetSize(WIDTH, 1)
    line:SetPoint("BOTTOMLEFT", 0, (HEIGHT / 4) * index)
  end

  for index = 1, 4 do
    local line = self.canvas:CreateTexture(nil, "BACKGROUND")
    line:SetColorTexture(1, 1, 1, 0.04)
    line:SetSize(1, HEIGHT)
    line:SetPoint("BOTTOMLEFT", (WIDTH / 4) * index, 0)
  end

  self.maxLabel = self.canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  self.maxLabel:SetPoint("TOPLEFT", 4, -2)

  self.minLabel = self.canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  self.minLabel:SetPoint("BOTTOMLEFT", 4, 2)

  self.dateLabel = self.canvas:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  self.dateLabel:SetPoint("BOTTOMRIGHT", -4, 2)

  self.noData = self.canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  self.noData:SetPoint("CENTER")
  self.noData:SetText(L("CHART_NO_HISTORY"))
  self.noData:Hide()

  self:RegisterHover()
end

function Charts:RegisterHover()
  self.hover = CreateFrame("Frame", nil, self.canvas)
  self.hover:SetAllPoints()
  self.hover:SetScript("OnEnter", function()
    if self.hoverText then self.hoverText:Show() end
  end)
  self.hover:SetScript("OnLeave", function()
    if self.hoverText then self.hoverText:Hide() end
  end)

  self.hoverText = self.canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  self.hoverText:SetPoint("TOPRIGHT", -4, -2)
  self.hoverText:Hide()
end

local function acquireLine(canvas, pool, index)
  local line = pool[index]
  if line then return line end
  local created
  local ok = pcall(function()
    created = canvas:CreateLine(nil, "ARTWORK")
  end)
  if not ok or not created then return nil end
  pool[index] = created
  return created
end

function Charts:AcquireDot(index)
  local dot = self.dots[index]
  if not dot then
    dot = self.canvas:CreateTexture(nil, "ARTWORK")
    dot:SetSize(5, 5)
    self.dots[index] = dot
  end
  return dot
end

function Charts:Clear()
  for _, line in ipairs(self.lines) do
    line:Hide()
  end
  for _, dot in ipairs(self.dots) do
    dot:Hide()
  end
  for index in pairs(self.records) do
    self.records[index] = nil
  end
end

function Charts:Render(itemID)
  itemID = itemID or ns.Market:GetSelectedItem()
  if not itemID then
    self:Clear()
    self.title:SetText(L("CHART_TITLE"))
    self.noData:SetText(L("CHART_EMPTY"))
    self.noData:Show()
    return
  end

  local series = ns.Market:GetChartSeries(itemID, DAYS)
  self.title:SetText(ns.Util:ItemName(itemID) .. "  —  " .. L("CHART_DAYS", DAYS))

  if #series == 0 then
    self:Clear()
    self.noData:SetText(L("CHART_NO_HISTORY"))
    self.noData:Show()
    return
  end

  self.noData:Hide()
  self:Clear()

  local maxPrice, minPrice = 0, nil
  for _, entry in ipairs(series) do
    if entry.min and entry.min > maxPrice then maxPrice = entry.min end
    if entry.min and (not minPrice or entry.min < minPrice) then minPrice = entry.min end
  end
  if maxPrice <= 0 then maxPrice = 1 end
  if not minPrice then minPrice = 0 end
  if maxPrice <= minPrice then maxPrice = minPrice + 1 end

  local plotWidth = WIDTH - PAD_LEFT - PAD_RIGHT
  local plotHeight = HEIGHT - PAD_TOP - PAD_BOTTOM
  local count = #series

  local function xAt(index)
    if count <= 1 then
      return PAD_LEFT + plotWidth / 2
    end
    return PAD_LEFT + ((index - 1) / (count - 1)) * plotWidth
  end

  local function yAt(value)
    local ratio = (value - minPrice) / (maxPrice - minPrice)
    if ratio < 0 then ratio = 0 end
    if ratio > 1 then ratio = 1 end
    return PAD_BOTTOM + ratio * plotHeight
  end

  -- линия между точками
  for index = 1, count - 1 do
    local line = acquireLine(self.canvas, self.lines, index)
    if line then
      local x1, y1 = xAt(index), yAt(series[index].min or minPrice)
      local x2, y2 = xAt(index + 1), yAt(series[index + 1].min or minPrice)
      pcall(function()
        line:SetStartPoint("BOTTOMLEFT", self.canvas, x1, y1)
        line:SetEndPoint("BOTTOMLEFT", self.canvas, x2, y2)
        line:SetThickness(2)
        line:SetColorTexture(0.25, 0.85, 0.45, 0.95)
      end)
      line:Show()
    end
  end

  -- точки
  for index = 1, count do
    local dot = self:AcquireDot(index)
    dot:ClearAllPoints()
    dot:SetPoint("CENTER", self.canvas, "BOTTOMLEFT", xAt(index), yAt(series[index].min or minPrice))
    dot:SetColorTexture(1, 0.82, 0.2, 1)
    dot:Show()
  end

  for index = count + 1, #self.lines do
    self.lines[index]:Hide()
  end
  for index = count + 1, #self.dots do
    self.dots[index]:Hide()
  end

  self.maxLabel:SetText(ns.Util:Money(maxPrice, true))
  self.minLabel:SetText(ns.Util:Money(minPrice, true))

  local first, last = series[1], series[count]
  if count == 1 then
    self.dateLabel:SetText(L("CHART_ONE_POINT"))
  elseif first.kind == "day" then
    self.dateLabel:SetText(date("%d.%m", first.t) .. " — " .. date("%d.%m", last.t))
  else
    self.dateLabel:SetText(L("CHART_SAMPLES", count))
  end
end

function Charts:UpdateTooltip(index)
  local record = self.records and self.records[index]
  if record and self.hoverText then
    if record.kind == "day" then
      self.hoverText:SetText(date("%d.%m", record.t) .. ": " .. ns.Util:Money(record.min, true))
    else
      self.hoverText:SetText(date("%H:%M", record.t) .. ": " .. ns.Util:Money(record.min, true))
    end
  end
end
