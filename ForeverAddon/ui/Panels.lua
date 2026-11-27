local addonName, ns = ...
local UI = ns.UI
local L = function(key, ...) return ns.L(key, ...) end

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

  panel.button = UI.SafeCreateButton(panel, L("SCAN_BTN"), 220)
  panel.button:SetSize(220, 30)
  panel.button:SetPoint("TOPLEFT", 4, -180)
  panel.button:SetScript("OnClick", function()
    ns.Auction:StartScan()
  end)

  panel.advice = UI.SafeCreateButton(panel, L("SCAN_BTN_ADVICE"), 180)
  panel.advice:SetSize(180, 30)
  panel.advice:SetPoint("TOPLEFT", 232, -180)
  panel.advice:SetScript("OnClick", function()
    for _, line in ipairs(ns.Advisor:Report()) do ns:Print(line) end
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
  panel.detail:SetText(UI.detailStatusText or "")
end

function UI:BuildFlipsPanel(panel)
  UI.CreateHeader(panel, {
    L("FLIP_NAME"), L("FLIP_BUY"), L("FLIP_MV"), L("FLIP_PROFIT"), L("FLIP_ROI"), L("FLIP_QTY"), L("FLIP_CONF"),
  }, { "name", "buy", "market", "profit", "roi", "qty", "conf" }, "flips", UI.ColumnTips.flips)

  panel.scroll, panel.child = UI.CreateScrollPanel(panel, 20)
  panel.rows = {}
  panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  panel.empty:SetPoint("CENTER", 0, 40)
  panel.empty:SetText(L("FLIP_EMPTY"))

  local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("BOTTOMLEFT", 4, 2)
  hint:SetText(L("FLIP_HINT"))

  panel.detail = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  panel.detail:SetPoint("BOTTOMRIGHT", -28, 2)
  panel.detail:SetText(UI.detailStatusText or "")
end

function UI:BuildChartPanel(panel)
  ns.Charts:Init(panel)
end

function UI:BuildRecipesPanel(panel)
  UI.CreateHeader(panel, {
    L("RECIPE_NAME"), L("RECIPE_COST"), L("RECIPE_OUT"), L("RECIPE_PROFIT"), L("RECIPE_ROI"), L("RECIPE_SOURCE"), L("RECIPE_LEARNED"),
  }, { "name", "cost", "outputPrice", "profit", "roi", "source", "learned" }, "recipes", UI.ColumnTips.recipes)

  panel.scroll, panel.child = UI.CreateScrollPanel(panel, 44)
  panel.rows = {}
  panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  panel.empty:SetPoint("CENTER", 0, 40)
  panel.empty:SetText(L("RECIPE_EMPTY"))

  panel.status = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  panel.status:SetPoint("BOTTOMLEFT", 4, 34)

  panel.button = UI.SafeCreateButton(panel, L("RECIPE_BTN"), 220)
  panel.button:SetSize(220, 26)
  panel.button:SetPoint("BOTTOMLEFT", 4, 2)
  panel.button:SetScript("OnClick", function()
    ns.Recipes:StartScan()
  end)

  panel.buttonAll = UI.SafeCreateButton(panel, L("RECIPE_BTN_ALL"), 190)
  panel.buttonAll:SetSize(190, 26)
  panel.buttonAll:SetPoint("BOTTOMLEFT", 232, 2)
  panel.buttonAll:SetScript("OnClick", function()
    ns.Recipes:StartScanAll()
  end)
end

function UI:BuildIngredientsPanel(panel)
  UI.CreateHeader(panel, {
    L("ING_NAME"), L("ING_PRICE"), L("ING_USES"), L("ING_COST"), L("ING_SOURCE"), L("ING_PROFITABLE"), L("ING_SCORE"),
  }, { "name", "price", "uses", "cost", "source", "profitable", "score" }, "ingredients", UI.ColumnTips.ingredients)

  panel.scroll, panel.child = UI.CreateScrollPanel(panel, 20)
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
  UI.CreateHeader(panel, {
    L("CHAIN_RECIPE"), L("CHAIN_PROFESSION"), L("CHAIN_COST"), L("CHAIN_DE"), L("CHAIN_PROFIT"), L("CHAIN_ROI"), L("CHAIN_OUTPUT"),
  }, { "name", "profession", "cost", "deValue", "profit", "roi", "output" }, "chains", UI.ColumnTips.chains)

  panel.scroll, panel.child = UI.CreateScrollPanel(panel, 44)
  panel.rows = {}
  panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  panel.empty:SetPoint("CENTER", 0, 40)
  panel.empty:SetText(L("CHAIN_EMPTY"))

  local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("BOTTOMLEFT", 4, 34)
  hint:SetWidth(700)
  hint:SetJustifyH("LEFT")
  hint:SetText(L("CHAIN_HINT"))

  panel.priceButton = UI.SafeCreateButton(panel, L("CATALOG_BTN_PRICES"), 220)
  panel.priceButton:SetSize(220, 26)
  panel.priceButton:SetPoint("BOTTOMLEFT", 4, 2)
  panel.priceButton:SetScript("OnClick", function()
    ns.Recipes:ScanCatalogPrices()
  end)

  local search = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
  search:SetSize(220, 24)
  search:SetPoint("BOTTOMRIGHT", -4, 2)
  search:SetAutoFocus(false)
  search:SetText(UI.chainSearch or "")
  search:SetScript("OnTextChanged", function(_, userInput)
    if userInput then
      UI.chainSearch = search:GetText()
      UI:ScheduleRefresh()
    end
  end)
  search:SetScript("OnEscapePressed", function() search:ClearFocus() end)
  panel.search = search
end

function UI:BuildProfessionsPanel(panel)
  UI.CreateHeader(panel, {
    L("PROF_NAME"), L("PROF_BEST"), L("PROF_TOTAL"), L("PROF_COUNT"), L("PROF_TOP"), L("PROF_OUTPUT"), L("PROF_ROI"),
  }, { "name", "best", "total", "count", "topName", "output", "roi" }, "professions", UI.ColumnTips.professions)

  panel.scroll, panel.child = UI.CreateScrollPanel(panel, 44)
  panel.rows = {}
  panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  panel.empty:SetPoint("CENTER", 0, 40)
  panel.empty:SetText(L("PROF_EMPTY"))

  local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("BOTTOMLEFT", 4, 34)
  hint:SetWidth(700)
  hint:SetJustifyH("LEFT")
  hint:SetText(L("PROF_HINT"))

  panel.priceButton = UI.SafeCreateButton(panel, L("CATALOG_BTN_PRICES"), 220)
  panel.priceButton:SetSize(220, 26)
  panel.priceButton:SetPoint("BOTTOMLEFT", 4, 2)
  panel.priceButton:SetScript("OnClick", function()
    ns.Recipes:ScanCatalogPrices()
  end)
end

function UI:BuildComponentsPanel(panel)
  UI.CreateHeader(panel, {
    L("COMP_NAME"), L("COMP_PROFESSION"), L("COMP_COST"), L("COMP_MARKET"), L("COMP_PROFIT"), L("COMP_ROI"), L("COMP_USED"),
  }, { "name", "profession", "cost", "market", "profit", "roi", "usedIn" }, "components", UI.ColumnTips.components)

  panel.scroll, panel.child = UI.CreateScrollPanel(panel, 20)
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
  UI.CreateHeader(panel, {
    L("FARM_ZONE"), L("FARM_NODES"), L("FARM_RESOURCE"), L("FARM_VALUE"), L("FARM_TYPE"), "", "",
  }, { "name", "nodes", "bestName", "value", "kind", nil, nil }, "farm", UI.ColumnTips.farm)

  panel.scroll, panel.child = UI.CreateScrollPanel(panel, 20)
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

