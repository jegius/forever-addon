local addonName, ns = ...
local Util = ns.Util or {}
ns.Util = Util

local GOLD = ns.L("MONEY_GOLD")
local SILVER = ns.L("MONEY_SILVER")
local COPPER = ns.L("MONEY_COPPER")

function Util:Money(copper, short)
  copper = math.floor((copper or 0) + 0.5)
  local gold = math.floor(copper / 10000)
  local silver = math.floor((copper % 10000) / 100)
  local copperRest = copper % 100
  if short then
    if gold > 0 then
      if silver > 0 then
        return string.format("%d%s %d%s", gold, GOLD, silver, SILVER)
      end
      return string.format("%d%s", gold, GOLD)
    elseif silver > 0 then
      if copperRest > 0 then
        return string.format("%d%s %d%s", silver, SILVER, copperRest, COPPER)
      end
      return string.format("%d%s", silver, SILVER)
    end
    return string.format("%d%s", copperRest, COPPER)
  end
  if gold > 0 then
    return string.format("%d%s %d%s %d%s", gold, GOLD, silver, SILVER, copperRest, COPPER)
  elseif silver > 0 then
    return string.format("%d%s %d%s", silver, SILVER, copperRest, COPPER)
  end
  return string.format("%d%s", copperRest, COPPER)
end

function Util:Percent(value)
  return string.format("%.1f%%", (value or 0) * 100)
end

function Util:Round(value, digits)
  local mult = 10 ^ (digits or 0)
  return math.floor(value * mult + 0.5) / mult
end

function Util:Clamp(value, low, high)
  if value < low then return low end
  if value > high then return high end
  return value
end

function Util:TableSize(tbl)
  local count = 0
  for _ in pairs(tbl or {}) do count = count + 1 end
  return count
end

function Util:FormatNumber(value)
  if value >= 1000000 then
    return string.format("%.1fM", value / 1000000)
  elseif value >= 1000 then
    return string.format("%.1fk", value / 1000)
  end
  return string.format("%d", value)
end


