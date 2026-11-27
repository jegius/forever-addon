-- JSON snapshot for local MCP/LLM analysis. No HTTP calls are made by the addon.
local addonName, ns = ...

local Export = {}
ns.Export = Export

local function escape(value)
  return (tostring(value):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"))
end

local function encode(value)
  local kind = type(value)
  if kind == "nil" then return "null" end
  if kind == "boolean" then return tostring(value) end
  if kind == "number" then return string.format("%.4f", value) end
  if kind == "string" then return '"' .. escape(value) .. '"' end
  if kind ~= "table" then return "null" end
  local isArray = true
  local count = 0
  for key in pairs(value) do
    count = count + 1
    if type(key) ~= "number" then isArray = false; break end
  end
  local parts = {}
  if isArray then
    for index = 1, count do parts[#parts + 1] = encode(value[index]) end
    return "[" .. table.concat(parts, ",") .. "]"
  end
  for key, item in pairs(value) do
    parts[#parts + 1] = '"' .. escape(key) .. '":' .. encode(item)
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

function Export:Build()
  local advisor = ns.Advisor
  local health = advisor and advisor:MarketHealth() or nil
  local flips = advisor and advisor:TopFlips(30) or {}
  local chains = {}
  for _, chain in ipairs(ns.Recipes:GetCatalogChains()) do
    chains[#chains + 1] = {
      name = chain.name, profession = chain.profession, output = chain.output,
      cost = chain.cost, profit = chain.profit, roi = chain.roi,
      expectedProfit = chain.expectedProfit, saleProbability = chain.saleProbability,
      deEstimated = chain.deEstimated, suspicious = chain.suspicious,
    }
    if #chains >= 100 then break end
  end
  return {
    generatedAt = time(),
    schemaVersion = ns.db and ns.db.schemaVersion or 1,
    health = health,
    flips = flips,
    chains = chains,
    professions = advisor and advisor:ProfessionAdvice(12) or {},
    farming = advisor and advisor:FarmingPlan() or {},
    guardrails = {
      "estimates only",
      "verify volume, competition and scan age",
      "no guaranteed profit",
    },
  }
end

function Export:Store()
  local snapshot = self:Build()
  local json = encode(snapshot)
  if ns.db then
    ns.db.exportJson = json
    ns.db.exportAt = time()
  end
  return json, snapshot
end

function Export:GetJSON()
  return ns.db and ns.db.exportJson or nil
end

function Export:GetSnapshot()
  local json = self:GetJSON()
  if not json then return nil end
  return { json = json, at = ns.db and ns.db.exportAt }
end
