-- ForeverAddon — оценка распыления (Disenchant) по ilvl/качеству
-- Таблицы Classic (см. docs: Disenchanting tables). Результат случаен; это ожидание.
local addonName, ns = ...

local Disenchant = {}
ns.Disenchant = Disenchant

local L = function(key, ...) return ns.L(key, ...) end

local MATERIALS = {
  strangeDust = { id = 10940, name = "Strange Dust" },
  soulDust = { id = 11083, name = "Soul Dust" },
  visionDust = { id = 11137, name = "Vision Dust" },
  dreamDust = { id = 11176, name = "Dream Dust" },
  illusionDust = { id = 16204, name = "Illusion Dust" },
  lesserMagic = { id = 10938, name = "Lesser Magic Essence" },
  greaterMagic = { id = 10939, name = "Greater Magic Essence" },
  lesserAstral = { id = 10998, name = "Lesser Astral Essence" },
  greaterAstral = { id = 11082, name = "Greater Astral Essence" },
  lesserMystic = { id = 11134, name = "Lesser Mystic Essence" },
  greaterMystic = { id = 11135, name = "Greater Mystic Essence" },
  lesserNether = { id = 11174, name = "Lesser Nether Essence" },
  greaterNether = { id = 11175, name = "Greater Nether Essence" },
  lesserEternal = { id = 16202, name = "Lesser Eternal Essence" },
  greaterEternal = { id = 16203, name = "Greater Eternal Essence" },
  smallGlimmer = { id = 10978, name = "Small Glimmering Shard" },
  largeGlimmer = { id = 11084, name = "Large Glimmering Shard" },
  smallGlowing = { id = 11138, name = "Small Glowing Shard" },
  largeGlowing = { id = 11139, name = "Large Glowing Shard" },
  smallRadiant = { id = 11177, name = "Small Radiant Shard" },
  largeRadiant = { id = 11178, name = "Large Radiant Shard" },
  smallBrilliant = { id = 14343, name = "Small Brilliant Shard" },
  largeBrilliant = { id = 14344, name = "Large Brilliant Shard" },
  nexus = { id = 20725, name = "Nexus Crystal" },
}

-- {min,max, dust={key,prob,qtyMin,qtyMax}, essence={...}, shard={...}}
local ARMOR = {
  {5, 15, {strangeDust, 0.80, 1, 2}, {lesserMagic, 0.20, 1, 2}},
  {16, 20, {strangeDust, 0.75, 2, 3}, {greaterMagic, 0.20, 1, 2}, {smallGlimmer, 0.05, 1, 1}},
  {21, 25, {strangeDust, 0.75, 4, 6}, {lesserAstral, 0.15, 1, 2}, {smallGlimmer, 0.10, 1, 1}},
  {26, 30, {soulDust, 0.75, 1, 2}, {greaterAstral, 0.20, 1, 2}, {largeGlimmer, 0.05, 1, 1}},
  {31, 35, {soulDust, 0.75, 2, 5}, {lesserMystic, 0.20, 1, 2}, {smallGlowing, 0.05, 1, 1}},
  {36, 40, {visionDust, 0.75, 1, 2}, {greaterMystic, 0.20, 1, 2}, {largeGlowing, 0.05, 1, 1}},
  {41, 45, {visionDust, 0.75, 2, 5}, {lesserNether, 0.20, 1, 2}, {smallRadiant, 0.05, 1, 1}},
  {46, 50, {dreamDust, 0.75, 1, 2}, {greaterNether, 0.20, 1, 2}, {largeRadiant, 0.05, 1, 1}},
  {51, 55, {dreamDust, 0.75, 2, 5}, {lesserEternal, 0.20, 1, 2}, {smallBrilliant, 0.05, 1, 1}},
  {56, 60, {illusionDust, 0.75, 1, 2}, {greaterEternal, 0.20, 1, 2}, {largeBrilliant, 0.05, 1, 1}},
  {61, 65, {illusionDust, 0.75, 2, 5}, {greaterEternal, 0.20, 2, 3}, {largeBrilliant, 0.05, 1, 1}},
}

local WEAPON = {
  {6, 15, {strangeDust, 0.20, 1, 2}, {lesserMagic, 0.80, 1, 2}},
  {16, 20, {strangeDust, 0.20, 2, 3}, {greaterMagic, 0.75, 1, 2}, {smallGlimmer, 0.05, 1, 1}},
  {21, 25, {strangeDust, 0.15, 4, 6}, {lesserAstral, 0.75, 1, 2}, {smallGlimmer, 0.10, 1, 1}},
  {26, 30, {soulDust, 0.20, 1, 2}, {greaterAstral, 0.75, 1, 2}, {largeGlimmer, 0.05, 1, 1}},
  {31, 35, {soulDust, 0.20, 2, 5}, {lesserMystic, 0.75, 1, 2}, {smallGlowing, 0.05, 1, 1}},
  {36, 40, {visionDust, 0.20, 1, 2}, {greaterMystic, 0.75, 1, 2}, {largeGlowing, 0.05, 1, 1}},
  {41, 45, {visionDust, 0.20, 2, 5}, {lesserNether, 0.75, 1, 2}, {smallRadiant, 0.05, 1, 1}},
  {46, 50, {dreamDust, 0.20, 1, 2}, {greaterNether, 0.75, 1, 2}, {largeRadiant, 0.05, 1, 1}},
  {51, 55, {dreamDust, 0.22, 2, 5}, {lesserEternal, 0.75, 1, 2}, {smallBrilliant, 0.03, 1, 1}},
  {56, 60, {illusionDust, 0.22, 1, 2}, {greaterEternal, 0.75, 1, 2}, {largeBrilliant, 0.03, 1, 1}},
  {61, 65, {illusionDust, 0.22, 2, 5}, {greaterEternal, 0.75, 2, 3}, {largeBrilliant, 0.03, 1, 1}},
}

local RARE = {
  {1, 25, {smallGlimmer, 1.0, 1, 1}},
  {26, 30, {largeGlimmer, 1.0, 1, 1}},
  {31, 35, {smallGlowing, 1.0, 1, 1}},
  {36, 40, {largeGlowing, 1.0, 1, 1}},
  {41, 45, {smallRadiant, 1.0, 1, 1}},
  {46, 50, {largeRadiant, 1.0, 1, 1}},
  {51, 55, {smallBrilliant, 1.0, 1, 1}},
  {56, 65, {largeBrilliant, 1.0, 1, 1}},
}

local EPIC = {
  {40, 45, {smallRadiant, 1.0, 2, 4}},
  {46, 50, {largeRadiant, 1.0, 2, 4}},
  {51, 55, {smallBrilliant, 1.0, 2, 4}},
  {56, 60, {nexus, 1.0, 1, 1}},
  {61, 88, {nexus, 1.0, 1, 2}},
}

local function findRow(rows, itemLevel)
  for _, row in ipairs(rows) do
    if itemLevel >= row[1] and itemLevel <= row[2] then
      return row, false
    end
  end
  if #rows > 0 then
    if itemLevel > rows[#rows][2] then return rows[#rows], true end
    if itemLevel < rows[1][1] then return rows[1], true end
  end
  return nil, false
end

local function isGearCategory(category)
  local text = tostring(category or ""):lower()
  return text:find("bracer") or text:find("boot") or text:find("glove")
    or text:find("chest") or text:find("leg") or text:find("belt")
    or text:find("shoulder") or text:find("helm") or text:find("cloak")
    or text:find("armor") or text:find("weapon") or text:find("sword")
    or text:find("axe") or text:find("mace") or text:find("dagger")
    or text:find("staff")
end

local function materialPrice(material)
  local itemID = material.id
  local resale = ns.Market:GetResale(itemID)
  local min = ns.Market:GetPrice(itemID)
  return resale or min or 0
end

function Disenchant:GetMaterialName(key)
  local material = MATERIALS[key]
  return material and ns.Util:ItemName(material.id) or key
end

function Disenchant:Estimate(itemID, options)
  if not itemID then return nil end
  options = options or {}
  local item = ns.Util:GetItem(itemID)
  if not item then return nil end
  local classID = item.classID
  local quality = item.quality or 1
  local itemLevel = item.itemLevel or 0
  if classID ~= 2 and classID ~= 4 then
    if isGearCategory(options.category) then
      classID = 4
    else
      return nil
    end
  end
  if quality < 2 and isGearCategory(options.category) then quality = 2 end
  if itemLevel <= 0 or quality < 2 then return nil end

  local row, estimated
  if quality == 2 then
    row, estimated = findRow(classID == 4 and ARMOR or WEAPON, itemLevel)
  elseif quality == 3 then
    row, estimated = findRow(RARE, itemLevel)
  elseif quality == 4 then
    row, estimated = findRow(EPIC, itemLevel)
  end
  if not row then return nil end

  local materials = {}
  local total = 0
  local missing = false
  for index = 3, #row do
    local spec = row[index]
    if spec then
      local key, probability, qtyMin, qtyMax = spec[1], spec[2], spec[3], spec[4]
      local expected = probability * ((qtyMin + qtyMax) / 2)
      if expected > 0 then
        local material = MATERIALS[key]
        local price = material and materialPrice(material) or 0
        if price <= 0 then missing = true end
        local value = price * expected
        materials[#materials + 1] = {
          key = key,
          itemID = material and material.id,
          name = material and ns.Util:ItemName(material.id) or key,
          qty = expected,
          qtyMin = qtyMin,
          qtyMax = qtyMax,
          probability = probability,
          price = price,
          value = value,
        }
        total = total + value
      end
    end
  end
  if #materials == 0 then return nil end

  return {
    itemID = itemID,
    quality = quality,
    itemLevel = itemLevel,
    kind = classID == 4 and "armor" or "weapon",
    materials = materials,
    value = total,
    missingPrice = missing,
    estimated = estimated,
  }
end

return Disenchant
