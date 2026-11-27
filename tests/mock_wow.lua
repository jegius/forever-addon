-- Minimal WoW API mock for Lua 5.1 unit tests.
local ns = {}

local function object()
  local o = {}
  o.CreateTexture = function() return object() end
  o.CreateFontString = function() return object() end
  o.CreateAnimationGroup = function() return object() end
  setmetatable(o, {
    __index = function(_, key)
      local f = function() return nil end
      rawset(o, key, f)
      return f
    end,
  })
  return o
end

_G.UIParent = object()
function _G.CreateFrame() return object() end
function _G.GetLocale() return "enUS" end
function _G.time() return os.time() end
function _G.GetTime() return os.clock() end
function _G.date(fmt, t) return os.date(fmt, t) end
function _G.wipe(t) for k in pairs(t) do t[k] = nil end return t end
function _G.tinsert(t, v) t[#t + 1] = v return v end
function _G.tremove(t, i) return table.remove(t, i) end
_G.GetItemQualityColor = function() return 1, 1, 1, "ffffffff" end

local itemInfo = {}
local function setItem(id, name, quality, itemLevel, classID, subclassID)
  itemInfo[id] = { name = name, quality = quality, itemLevel = itemLevel, classID = classID, subclassID = subclassID }
end

_G.C_Item = {
  GetItemInfo = function(id)
    local it = itemInfo[id]
    if not it then return nil end
    return it.name, "|Hitem:" .. id .. "|h", it.quality, it.itemLevel, 1, "Armor", "Misc", 1, "", 0, 0,
      it.classID, it.subclassID, 0, 0, 0, false, ""
  end,
  GetItemInfoInstant = function(id)
    local it = itemInfo[id]
    if not it then return id end
    return id, "Armor", "Misc", "", 134400, it.classID, it.subclassID
  end,
  GetItemSubClassInfo = function() return "Leather" end,
  RequestLoadItemDataByID = function() end,
}
_G.C_Container = {
  GetContainerItemLink = function() return nil end,
  GetContainerItemInfo = function() return nil end,
}
_G.GetInventoryItemLink = function() return nil end
_G.GameTooltip = object()
_G.C_Timer = {
  After = function(_, fn) if fn then pcall(fn) end end,
  NewTimer = function(delay, fn)
    if delay and delay <= 1 and fn then pcall(fn) end
    return { Cancel = function() end }
  end,
}
_G.C_AuctionHouse = {}

function ns.Load(root, addonName)
  local self = { root = root, addonName = addonName, api = {} }
  self.ns = { Print = function() end }
  function self.load(rel, ...)
    local path = root .. "/" .. rel
    local chunk = assert(loadfile(path))
    chunk(addonName, self.ns, ...)
  end
  return self
end

ns.setItem = setItem
ns.object = object
return ns
