-- UI construction smoke test with broad no-op frames.
local mock = dofile("tests/mock_wow.lua")

C_Timer = { After = function(_, fn) if fn then pcall(fn) end end }
C_AuctionHouse = {}
C_TradeSkillUI = {}
C_Map = { GetMapInfo = function() return { name = "Test Zone" } end }
C_Spell = { GetSpellInfo = function() return "Test" end }
C_Container.GetContainerNumSlots = function() return 0 end
GetContainerNumSlots = function() return 0 end
GetBuildInfo = function() return "1.60.1", "70888", "2026", 16001 end
SlashCmdList = {}
hooksecurefunc = function() end
UIParent = mock.object()
GameTooltip = mock.object()
GameTooltip.GetItem = function() return nil, nil end

local ctx = mock.Load("ForeverAddon", "ForeverAddon")
for line in io.lines("ForeverAddon/ForeverAddon.toc") do
  local file = line:match("^(.-%.lua)%s*$")
  if file then ctx.load(file) end
end

ForeverAddonDB = nil
ctx.ns.DB:Init()
local ok, err = pcall(ctx.ns.UI.Init, ctx.ns.UI)
assert(ok, "UI:Init failed: " .. tostring(err))
assert(ctx.ns.UI.frame, "frame created")
print("UI smoke test OK")
