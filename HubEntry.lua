-- Damage of Azeroth by DinX: its line in the "Addons of Azeroth" minimap list (Hub.lua).
local ADDON, ns = ...

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	C_Timer.After(0, function()
		local hub = _G.AddonsOfAzerothHub
		if not hub then return end
		local DoA = ns.DoA
		hub:Register({
			key = "damage", addon = ADDON,
			click = function() SlashCmdList.DAMAGEOFAZEROTH("") end,
			right = function() SlashCmdList.DAMAGEOFAZEROTH("config") end,
		})
	end)
end)
