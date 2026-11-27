-- ForeverAddon — инициализация
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

