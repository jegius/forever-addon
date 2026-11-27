-- ForeverAddon localization resolver
local addonName, ns = ...

ns.LocaleTables = ns.LocaleTables or {}
local locale = (GetLocale and GetLocale() == "ruRU") and "ruRU" or "enUS"
local strings = ns.LocaleTables[locale] or ns.LocaleTables.enUS or {}

function ns.L(key, ...)
  local text = strings[key] or key
  if select("#", ...) > 0 then
    return string.format(text, ...)
  end
  return text
end
