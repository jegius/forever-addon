-- Safe, deterministic in-game advisor. It never clicks, reads pixels or sends input.
local addonName, ns = ...

local Advisor = {}
ns.Advisor = Advisor

local L = function(key, ...) return ns.L(key, ...) end

local GUARDRAILS = {
  "ADVICE_GUARD_ESTIMATE",
  "ADVICE_GUARD_VERIFY",
  "ADVICE_GUARD_DATA",
}

local function money(value)
  return ns.Util:Money(value or 0, true)
end

local function percent(value)
  return ns.Util:Percent(value or 0)
end

function Advisor:MarketHealth()
  local db = ns.db
  if not db then return nil end
  local stats = ns.Market:GetStats()
  local freshness = db.scanLast and (time() - db.scanLast) or nil
  local professions = ns.Recipes and ns.Recipes:GetCatalogProfessions() or {}
  local priced, total = 0, 0
  for _, entry in ipairs(professions) do
    priced = priced + (entry.priced or 0)
    total = total + (entry.totalRecipes or 0)
  end
  return {
    items = stats.items or 0,
    detailItems = stats.detailItems or 0,
    rows = stats.rows or 0,
    freshnessSeconds = freshness,
    stale = freshness and freshness > 86400 or false,
    pricedRecipes = priced,
    totalRecipes = total,
    coverage = total > 0 and priced / total or 0,
    suspicious = stats.suspicious or 0,
  }
end

function Advisor:TopFlips(limit)
  local result = {}
  local flips = ns.Market:GetFlips(limit or 10)
  for _, flip in ipairs(flips) do
    local stats = ns.PriceService:GetPriceStats(flip.itemID) or {}
    result[#result + 1] = {
      itemID = flip.itemID,
      name = ns.Util:ItemName(flip.itemID),
      buy = flip.buy,
      market = flip.market,
      profit = flip.profit,
      roi = flip.roi,
      confidence = stats.confidence or 0.2,
      risk = (stats.confidence or 0) < 0.55 and "high" or "normal",
    }
  end
  return result
end

function Advisor:CraftPlan(budget)
  budget = budget or (ns.db and ns.db.settings.capital) or 100000
  local result = {}
  for _, chain in ipairs(ns.Recipes:GetCatalogChainsSync()) do
    if chain.cost <= budget and chain.expectedProfit and chain.expectedProfit > 0 then
      result[#result + 1] = {
        name = chain.name,
        output = chain.output,
        cost = chain.cost,
        profit = chain.profit,
        expectedProfit = chain.expectedProfit,
        roi = chain.roi,
        confidence = chain.saleProbability or 0,
        mode = chain.mode,
      }
      if #result >= 20 then break end
    end
  end
  return result
end

function Advisor:ProfessionAdvice(limit)
  local result = {}
  for _, entry in ipairs(ns.Recipes:GetCatalogProfessions()) do
    if (entry.total or 0) > 0 then
      result[#result + 1] = {
        profession = entry.name,
        best = entry.best,
        total = entry.total,
        priced = entry.priced,
        totalRecipes = entry.totalRecipes,
        coverage = entry.totalRecipes and entry.priced / entry.totalRecipes or 0,
      }
    end
    if limit and #result >= limit then break end
  end
  return result
end

function Advisor:FarmingPlan()
  local zones = ns.Farming and ns.Farming:GetBestZones() or { herbs = {}, mining = {} }
  local result = {}
  for _, zone in ipairs(zones.herbs or {}) do
    result[#result + 1] = {
      zone = zone.zone, kind = "herbs", nodes = zone.nodes,
      value = zone.value, perHour = zone.perHour, score = zone.score,
    }
  end
  for _, zone in ipairs(zones.mining or {}) do
    result[#result + 1] = {
      zone = zone.zone, kind = "mining", nodes = zone.nodes,
      value = zone.value, perHour = zone.perHour, score = zone.score,
    }
  end
  table.sort(result, function(a, b) return (a.score or 0) > (b.score or 0) end)
  local top = {}
  for index = 1, math.min(10, #result) do top[#top + 1] = result[index] end
  return top
end

function Advisor:Explain(kind)
  local notes = {
    flip = L("ADVICE_EXPLAIN_FLIP"),
    craft = L("ADVICE_EXPLAIN_CRAFT"),
    farm = L("ADVICE_EXPLAIN_FARM"),
    profession = L("ADVICE_EXPLAIN_PROFESSION"),
  }
  return notes[kind] or L("ADVICE_EXPLAIN_UNKNOWN")
end

function Advisor:Report()
  local lines = {}
  local health = self:MarketHealth()
  if health then
    lines[#lines + 1] = L("ADVICE_DATA", health.items, health.detailItems, (health.coverage or 0) * 100)
    if health.stale then lines[#lines + 1] = L("ADVICE_STALE") end
  end
  local flips = self:TopFlips(3)
  for _, flip in ipairs(flips) do
    lines[#lines + 1] = L("ADVICE_FLIP",
      flip.name, money(flip.buy), money(flip.market), money(flip.profit),
      percent(flip.roi), (flip.confidence or 0) * 100)
  end
  if #flips == 0 then lines[#lines + 1] = L("ADVICE_NO_FLIPS") end

  local chains = ns.Recipes:GetCatalogChains()
  if chains and chains[1] then
    local top = chains[1]
    lines[#lines + 1] = L("ADVICE_CHAIN", top.name, money(top.cost), money(top.profit))
  elseif ns.Recipes:IsCatalogChainsBuilding() then
    lines[#lines + 1] = L("ADVICE_BUILDING")
  end
  lines[#lines + 1] = L("ADVICE_SALE_NOTE")
  for _, guardrail in ipairs(GUARDRAILS) do lines[#lines + 1] = L(guardrail) end
  return lines
end
