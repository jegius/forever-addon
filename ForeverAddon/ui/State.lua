-- ForeverAddon — окно аддона
local addonName, ns = ...

local UI = {}
ns.UI = UI

local L = function(key, ...) return ns.L(key, ...) end

UI.tabs = {}
UI.panels = {}
UI.activeTab = "scan"
UI.scanStatusText = nil
UI.detailStatusText = nil
UI.refreshPending = false
UI.chainsExpanded = {}
UI.chainSearch = ""
UI.filterText = ""

UI.SortStates = {
  flips = { key = "profit", dir = -1 },
  recipes = { key = "profit", dir = -1 },
  ingredients = { key = "score", dir = -1 },
  chains = { key = "profit", dir = -1 },
  professions = { key = "total", dir = -1 },
  components = { key = "profit", dir = -1 },
  farm = { key = "value", dir = -1 },
}
UI.SortArrows = { [1] = " ^", [-1] = " v" }

UI.ColumnTips = {
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

UI.TabTips = {
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

UI.GuideTexts = {
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

