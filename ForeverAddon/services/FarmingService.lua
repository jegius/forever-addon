-- ForeverAddon — лучшие зоны фарма по данным GatherMate2
local addonName, ns = ...

local Farming = {}
ns.Farming = Farming

local L = function(key, ...) return ns.L(key, ...) end

local HERB_ITEMS = {
  [401] = 2447, [402] = 765, [403] = 2449, [404] = 785, [405] = 2450,
  [407] = 3820, [408] = 2453, [409] = 3355, [410] = 3369, [411] = 3356,
  [412] = 3357, [413] = 3818, [414] = 3821, [415] = 3358, [416] = 3819,
  [417] = 4625, [418] = 8831, [420] = 8836, [421] = 8838, [422] = 8839,
  [423] = 8845, [424] = 8846, [425] = 13464, [426] = 13463, [427] = 13465,
  [428] = 13466, [429] = 13467, [431] = 13468,
}

local MINE_ITEMS = {
  [201] = 2770, [202] = 2771, [203] = 2772, [204] = 2775, [205] = 2776,
  [206] = 3858, [207] = 3858, [208] = 7911, [209] = 2775, [210] = 2776,
  [211] = 7911, [212] = 10620, [213] = 10620, [214] = 10620, [215] = 10620,
  [217] = 11370, [218] = 4278, [219] = 3340, [220] = 3341,
}

local function zoneName(zoneID)
  if C_Map and C_Map.GetMapInfo then
    local ok, info = pcall(C_Map.GetMapInfo, zoneID)
    if ok and info and info.name then return info.name end
  end
  if GetMapNameByID then
    local ok, name = pcall(GetMapNameByID, zoneID)
    if ok and name then return name end
  end
  return L("ZONE_FALLBACK", tostring(zoneID))
end

local function sourceDB(kind)
  if kind == "herbs" then
    return GatherMateData2HerbDB or GatherMate2HerbDB
  end
  return GatherMateData2MineDB or GatherMate2MineDB
end

local function rankZones(kind, itemMap)
  local source = sourceDB(kind)
  local result = {}
  if type(source) ~= "table" then return result end
  local priceCache = {}

  local function priceFor(itemID)
    local price = priceCache[itemID]
    if price == nil then
      price = ns.Market:GetMarketValue(itemID) or ns.Market:GetPrice(itemID) or 0
      priceCache[itemID] = price
    end
    return price
  end

  for zoneID, nodes in pairs(source) do
    if type(zoneID) == "number" and type(nodes) == "table" then
      local total, count = 0, 0
      local bestNode, bestValue = nil, 0
      local nodeCount = {}
      for _, nodeID in pairs(nodes) do
        if itemMap[nodeID] then
          nodeCount[nodeID] = (nodeCount[nodeID] or 0) + 1
        end
      end
      for nodeID, amount in pairs(nodeCount) do
        local itemID = itemMap[nodeID]
        local price = priceFor(itemID)
        count = count + amount
        total = total + price * amount
        if price > bestValue then bestValue = price; bestNode = nodeID end
      end
      if count > 0 then
        local settings = (ns.db and ns.db.settings) or {}
        local yield = settings.farmYield or 1.5
        local respawn = settings.farmRespawn or 45
        local travel = settings.farmTravel or 30
        local competition = settings.farmCompetition or 1
        local score = total * yield / (respawn + travel) * competition
        result[#result + 1] = {
          zoneID = zoneID,
          zone = zoneName(zoneID),
          kind = kind,
          nodes = count,
          value = total,
          score = score,
          perHour = math.floor(score * 60),
          bestNode = bestNode,
          bestItemID = bestNode and itemMap[bestNode] or nil,
          bestName = bestNode and ns.Util:ItemName(itemMap[bestNode]) or "—",
        }
      end
    end
  end
  table.sort(result, function(a, b) return a.score > b.score end)
  return result
end

function Farming:GetBestZones()
  return {
    herbs = rankZones("herbs", HERB_ITEMS),
    mining = rankZones("mining", MINE_ITEMS),
  }
end

local function leatherName(name)
  local lower = tostring(name or ""):lower()
  return lower:find("leather") or lower:find("кож") or lower:find("hide")
    or lower:find("scale") or lower:find("чешу") or lower:find("шкур")
end

function Farming:GetLeatherRanking(limit)
  local result = {}
  local db = ns.db
  if not db then return result end
  for itemID, entry in pairs(db.prices or {}) do
    local classID = ns.Util:ItemClass(itemID)
    local subtype = tostring(ns.Util:ItemSubclassName(itemID) or "")
    local name = ns.Util:ItemName(itemID)
    if classID == 7 and leatherName(subtype) or leatherName(name) then
      local price = ns.Market:GetMarketValue(itemID) or ns.Market:GetPrice(itemID)
      if price and price > 0 then
        result[#result + 1] = {
          itemID = itemID,
          name = name,
          price = price,
          qty = ns.Market:GetQuantity(itemID) or 0,
          score = price * math.max(1, ns.Market:GetQuantity(itemID) or 1),
        }
      end
    end
  end
  table.sort(result, function(a, b) return a.score > b.score end)
  local max = limit or 20
  while #result > max do table.remove(result) end
  return result
end

function Farming:GetSources()
  return {
    herbs = sourceDB("herbs") ~= nil,
    mining = sourceDB("mining") ~= nil,
    gathermateData = GatherMateData2HerbDB ~= nil or GatherMateData2MineDB ~= nil,
    leatherZones = type(Farming.leatherZones) == "table",
  }
end

function Farming:SetLeatherZones(dataset)
  self.leatherZones = dataset
end

function Farming:GetLeatherZones(limit)
  local result = {}
  for _, entry in ipairs(self.leatherZones or {}) do
    local price = ns.Market:GetMarketValue(entry.itemID) or ns.Market:GetPrice(entry.itemID) or 0
    result[#result + 1] = {
      zone = entry.zone,
      itemID = entry.itemID,
      name = ns.Util:ItemName(entry.itemID),
      price = price,
      score = price * (entry.weight or 1),
    }
  end
  table.sort(result, function(a, b) return a.score > b.score end)
  local max = limit or 20
  while #result > max do table.remove(result) end
  return result
end

function Farming:StartSession(zoneID)
  local db = ns.db
  if not db then return nil end
  db.farmingSession = {
    zoneID = zoneID,
    zone = zoneID and zoneName(zoneID) or "—",
    startedAt = time(),
    casts = 0,
    loot = {},
    value = 0,
  }
  return db.farmingSession
end

function Farming:AddLoot(itemID, qty)
  local db = ns.db
  local session = db and db.farmingSession
  if not session then return end
  qty = qty or 1
  session.casts = (session.casts or 0) + 1
  session.loot[itemID] = (session.loot[itemID] or 0) + qty
  session.value = (session.value or 0) + (ns.Market:GetMarketValue(itemID) or 0) * qty
end

function Farming:StopSession()
  local db = ns.db
  local session = db and db.farmingSession
  if not session then return nil end
  session.endedAt = time()
  session.duration = math.max(1, session.endedAt - session.startedAt)
  session.goldPerHour = session.value / session.duration * 3600
  db.farmingSessions = db.farmingSessions or {}
  db.farmingSessions[#db.farmingSessions + 1] = session
  while #db.farmingSessions > 50 do table.remove(db.farmingSessions, 1) end
  db.farmingSession = nil
  return session
end

function Farming:GetSessions(limit)
  local sessions = (ns.db and ns.db.farmingSessions) or {}
  local result = {}
  for index = #sessions, 1, -1 do
    result[#result + 1] = sessions[index]
    if limit and #result >= limit then break end
  end
  return result
end

