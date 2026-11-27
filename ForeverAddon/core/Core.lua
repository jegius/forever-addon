-- ForeverAddon — инициализация и slash-команды
local addonName, ns = ...

function ns:Print(message)
  print("|cff33ff99ForeverAddon|r: " .. tostring(message))
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")

frame:SetScript("OnEvent", function(_, event, arg)
  if event == "ADDON_LOADED" and arg == addonName then
    ns.DB:Init()
    ns.Auction:Init()
    ns.Detail:Init()
    ns.Recipes:Init()
    ns.UI:Init()
    ns:Print(ns.L("LOADED"))

  elseif event == "PLAYER_LOGIN" then
    ns.Market:Prune()
    if ns.UI then ns.UI:ScheduleRefresh() end

  elseif event == "PLAYER_LOGOUT" then
    ns.Market:Prune()
  end
end)

local function printHelp()
  ns:Print(ns.L("HELP"))
end

local function printReport()
  local stats = ns.Market:GetStats()
  ns:Print(string.format("items=%d detail=%d history=%d rows=%d",
    stats.items, stats.detailItems or 0, stats.historyItems, stats.rows))
  if stats.lastScan > 0 then
    ns:Print("last scan: " .. date("%d.%m %H:%M", stats.lastScan))
  end

  local flips = ns.Market:GetFlips(5)
  if #flips > 0 then
    ns:Print("Лучшие лоты:")
    for _, flip in ipairs(flips) do
      ns:Print(string.format("%s: купить %s -> продать %s, прибыль %s (%s)",
        ns.Util:ItemName(flip.itemID),
        ns.Util:Money(flip.buy, true),
        ns.Util:Money(flip.market, true),
        ns.Util:Money(flip.profit, true),
        ns.Util:Percent(flip.roi)))
    end
  else
    ns:Print("Флипов нет: нужен детальный скан (аукцион открыт).")
  end

  local recipes = ns.Recipes:GetAll()
  if #recipes > 0 then
    ns:Print("Топ рецептов:")
    for index = 1, math.min(5, #recipes) do
      local recipe = recipes[index]
      if recipe.noPrice then
        ns:Print(string.format("%s: нет цены", recipe.name))
      else
        ns:Print(string.format("%s: прибыль %s (%s)",
          recipe.name, ns.Util:Money(recipe.profit, true), ns.Util:Percent(recipe.roi)))
      end
    end
  end
end

local function printTest()
  local function ok(value)
    return value and "|cff33ff99OK|r" or "|cffff5555NO|r"
  end
  local interface = select(4, GetBuildInfo())
  ns:Print("build: " .. tostring(interface))
  ns:Print("C_AuctionHouse: " .. ok(C_AuctionHouse ~= nil))
  ns:Print("SendBrowseQuery: " .. ok(C_AuctionHouse and C_AuctionHouse.SendBrowseQuery))
  ns:Print("GetBrowseResults: " .. ok(C_AuctionHouse and C_AuctionHouse.GetBrowseResults))
  ns:Print("HasFullBrowseResults: " .. ok(C_AuctionHouse and C_AuctionHouse.HasFullBrowseResults))
  ns:Print("GetAllRecipeIDs: " .. ok(C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs))
  ns:Print("GetRecipeSchematic: " .. ok(C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic))
  ns:Print("GetItemInfoInstant: " .. ok(C_Item and C_Item.GetItemInfoInstant))
  local stats = ns.Market:GetStats()
  ns:Print(string.format("items=%d history=%d detail=%d rows=%d lastScan=%s",
    stats.items, stats.historyItems, stats.detailItems or 0, stats.rows,
    stats.lastScan > 0 and date("%d.%m %H:%M", stats.lastScan) or "never"))
  ns:Print("detail scan active: " .. tostring(ns.Detail and ns.Detail:IsActive() and true or false))
  if ns.db then
    ns:Print(string.format("settings: detailItems=%d minProfit=%d minROI=%.2f cooldown=%d",
      ns.db.settings.detailItems or 0, ns.db.settings.minProfit or 0,
      ns.db.settings.minROI or 0, ns.db.settings.scanCooldown or 0))
  end
end

local function command(msg)
  local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)$")
  cmd = string.lower(cmd or "")

  if cmd == "" then
    ns.UI:Toggle()

  elseif cmd == "scan" then
    ns.UI:Open()
    ns.Auction:StartScan()

  elseif cmd == "detail" then
    ns.UI:Open()
    local ids = ns.Market:GetCandidates((ns.db and ns.db.settings.detailItems) or 60)
    if #ids == 0 then
      ns:Print(ns.L("NO_DATA"))
    else
      ns.Detail:Scan(ids, function() ns.UI:ScheduleRefresh() end, ns.L("DETAIL_LABEL"))
    end

  elseif cmd == "report" then
    printReport()

  elseif cmd == "allprof" or cmd == "allprofessions" then
    ns.UI:Open()
    ns.Recipes:StartScanAll()

  elseif cmd == "chains" then
    ns.UI:Open()
    ns.UI:SetTab("chains")

  elseif cmd == "professions" or cmd == "prof" then
    ns.UI:Open()
    ns.UI:SetTab("professions")

  elseif cmd == "components" or cmd == "comp" then
    ns.UI:Open()
    ns.UI:SetTab("components")

  elseif cmd == "zones" or cmd == "farm" then
    ns.UI:Open()
    ns.UI:SetTab("farm")

  elseif cmd == "prices" then
    ns.Recipes:ScanCatalogPrices()

  elseif cmd == "bagtest" then
    ns.UI:PrintBagDiagnostics()

  elseif cmd == "advice" or cmd == "advisor" then
    for _, line in ipairs(ns.Advisor:Report()) do ns:Print(line) end

  elseif cmd == "export" then
    local json = ns.Export:Store()
    ns:Print(string.format("JSON snapshot: %d bytes; exportAt=%s", #json,
      date("%d.%m %H:%M", ns.db.exportAt or time())))

  elseif cmd == "farmstart" then
    ns.Farming:StartSession(tonumber(rest))
    ns:Print("Farming session started")

  elseif cmd == "farmstop" then
    local session = ns.Farming:StopSession()
    if session then
      ns:Print(string.format("Farming: %s, %s/h", ns.Util:Money(session.value, true),
        ns.Util:Money(session.goldPerHour, true)))
    else
      ns:Print("No farming session")
    end

  elseif cmd == "flips" then
    ns.UI:Open()
    ns.UI:SetTab("flips")

  elseif cmd == "chart" then
    local itemID = tonumber(rest)
    if itemID then
      ns.UI:Open()
      ns.UI:ShowChart(itemID)
    else
      ns:Print("Usage: /fa chart <itemID>")
    end

  elseif cmd == "recipes" then
    ns.UI:Open()
    ns.UI:SetTab("recipes")

  elseif cmd == "roi" then
    local value = tonumber(rest)
    if value and value >= 0 then
      ns.db.settings.minROI = value
      ns:Print(string.format("min ROI: %.0f%%", value * 100))
      ns.UI:ScheduleRefresh()
    else
      ns:Print("Usage: /fa roi 0.10")
    end

  elseif cmd == "profit" then
    local value = tonumber(rest)
    if value and value >= 0 then
      ns.db.settings.minProfit = value
      ns:Print(string.format("min profit: %s", ns.Util:Money(value, false)))
      ns.UI:ScheduleRefresh()
    else
      ns:Print("Usage: /fa profit 100")
    end

  elseif cmd == "history" then
    local value = tonumber(rest)
    if value and value >= 7 and value <= 90 then
      ns.db.settings.historyDays = value
      ns.Market:Prune()
      ns:Print(string.format("history days: %d", value))
    else
      ns:Print("Usage: /fa history 30 (7..90)")
    end

  elseif cmd == "reset" then
    ns.Market:ResetPrices()
    ns:Print("price database cleared")
    ns.UI:ScheduleRefresh()

  elseif cmd == "test" then
    printTest()

  else
    printHelp()
  end
end

SLASH_FOREVERADDON1 = "/fa"
SLASH_FOREVERADDON2 = "/foreveraddon"
SlashCmdList["FOREVERADDON"] = command
