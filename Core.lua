-- Damage of Azeroth by DinX: damage meter, fight history and statistics.
-- Display only. The numbers come from Blizzard's own damage meter
-- (C_DamageMeter); the combat log is not used (blocked for addons here).
local ADDON, ns = ...

local DoA = CreateFrame("Frame", "DamageOfAzerothCore")
ns.DoA = DoA
_G.DamageOfAzeroth = DoA

DoA.version = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON, "Version") or "?"
DoA.modules = {}

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------
local charDefaults = {
	meter = {
		enabled = true,
		mode = "damage",     -- damage, dps, healing, hps
		session = "current", -- current, overall
		rows = 8,
		hideEmpty = false,   -- hide the meter until the first fight
	},
	stats = {
		filter = "all",  -- all, solo, party, raid
		view = "fight",  -- fight (curve), trend (last fights)
		detail = "spells", -- spells, group
		keep = 200,      -- fights kept
	},
	fights = {},        -- History.lua: one entry per fight, newest last
	bars = { locked = true }, -- "Frames locked" (same key as Casters of Azeroth)
	points = {},
}

local accountDefaults = {
	language = "auto",
	font = "roboto",
	fontOutline = false,
}

DoA.SCHEMA = 1

local function merge(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			merge(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

---------------------------------------------------------------------------
-- Printing, events, modules
---------------------------------------------------------------------------
function DoA:Print(...)
	print("|cff69ccf0Damage of Azeroth|r:", ...)
end

local handlers = {}
function DoA:On(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		local ok = pcall(self.RegisterEvent, self, event) -- unknown events on this client are skipped
		if not ok then handlers[event] = nil return end
	end
	table.insert(handlers[event], fn)
end

DoA:SetScript("OnEvent", function(self, event, ...)
	local list = handlers[event]
	if list then
		local prev = DoA.where
		DoA.where = (prev and prev .. " > " or "") .. event
		for i = 1, #list do list[i](event, ...) end
		DoA.where = prev
	end
end)

function DoA:NewModule(name)
	local m = { name = name }
	self.modules[#self.modules + 1] = m
	self[name] = m
	return m
end

local callbacks = {}
function DoA:Listen(msg, fn)
	callbacks[msg] = callbacks[msg] or {}
	table.insert(callbacks[msg], fn)
end
function DoA:Fire(msg, ...)
	for _, fn in ipairs(callbacks[msg] or {}) do fn(...) end
end

---------------------------------------------------------------------------
-- Secret values: in combat Blizzard hides some numbers from addons.
---------------------------------------------------------------------------
local issecret = issecretvalue or function() return false end
DoA.IsSecret = issecret

function DoA.Safe(v, default)
	if issecret(v) then return default end
	if v == nil then return default end
	return v
end

-- a table we may look into (the client can hand over secret tables)
function DoA.Open(t)
	return type(t) == "table" and not issecret(t) and (not canaccesstable or canaccesstable(t))
end

-- 12345 -> "12.3k". Hidden values (combat) cannot be calculated with: they
-- go through Blizzard's own abbreviation or string.format, which accept them,
-- else as they are.
function DoA.Short(v)
	if issecret(v) then
		if AbbreviateNumbers then
			local ok, s = pcall(AbbreviateNumbers, v)
			if ok and (issecret(s) or s) then return s end
		end
		local ok, s = pcall(string.format, "%.1f", v)
		if ok then return s end
		return v
	end
	if type(v) ~= "number" then return "" end
	local L = DoA.L
	local s
	if v >= 1e6 then s = ("%.1fm"):format(v / 1e6)
	elseif v >= 1e4 then s = ("%.1fk"):format(v / 1e3)
	else return ("%d"):format(math.floor(v + 0.5)) end
	return (s:gsub("%.", L["decimal"]))
end

function DoA.Clock(sec)
	sec = DoA.Safe(sec, nil)
	if type(sec) ~= "number" or sec < 0 then return "" end
	return ("%d:%02d"):format(math.floor(sec / 60), math.floor(sec % 60))
end

-- Casters of Azeroth when it is loaded, else nil.
function DoA:Casters()
	local c = _G.CastersOfAzeroth or _G.CasterKit
	if type(c) == "table" and type(c.char) == "table" then return c end
end

-- One lock for all frames: with Casters of Azeroth loaded its "Frames locked" wins.
function DoA:FramesLocked()
	local c = self:Casters()
	if c and type(c.char.bars) == "table" then return c.char.bars.locked ~= false end
	return self.char.bars.locked
end

function DoA:SetFramesLocked(locked)
	self.char.bars.locked = locked
	local c = self:Casters()
	if c and type(c.char.bars) == "table" then
		c.char.bars.locked = locked
		if c.Fire then c:Fire("SETTINGS", "bars") end
	end
	self:Fire("SETTINGS", "bars")
end

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------
DoA:On("ADDON_LOADED", function(_, name)
	if name ~= ADDON then return end
	DamageOfAzerothDB = type(DamageOfAzerothDB) == "table" and DamageOfAzerothDB or {}
	DamageOfAzerothCharDB = type(DamageOfAzerothCharDB) == "table" and DamageOfAzerothCharDB or {}
	merge(DamageOfAzerothDB, accountDefaults)
	merge(DamageOfAzerothCharDB, charDefaults)
	DoA.db = DamageOfAzerothDB
	DoA.char = DamageOfAzerothCharDB
	DoA.db.schemaVersion = DoA.SCHEMA
	DoA.char.schemaVersion = DoA.SCHEMA
	-- Casters of Azeroth's font choice wins when it is loaded
	local c = DoA:Casters()
	DoA.Style:LoadFont(c and c.db or DoA.db)
	for _, m in ipairs(DoA.modules) do
		if m.OnInit then
			local ok, err = pcall(m.OnInit, m)
			if not ok and DoA.debug then DoA:Print("init " .. m.name .. ":", tostring(err)) end
		end
	end
end)

DoA:On("PLAYER_LOGIN", function()
	for _, m in ipairs(DoA.modules) do
		if m.OnEnable then
			DoA.where = "PLAYER_LOGIN " .. m.name
			local ok, err = pcall(m.OnEnable, m)
			if not ok then DoA:Print("|cffff5555" .. m.name .. ":|r " .. tostring(err)) end
		end
	end
	DoA.where = nil
	local c = DoA:Casters()
	if c and c.Listen then
		c:Listen("SETTINGS", function(group)
			if group == "bars" and DoA.Style then DoA.Style:UpdateMovers() end
		end)
	end
	if DoA.Style then DoA.Style:UpdateMovers() end
end)

SLASH_DAMAGEOFAZEROTH1 = "/doa"
SLASH_DAMAGEOFAZEROTH2 = "/damage"
SlashCmdList.DAMAGEOFAZEROTH = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	local L = DoA.L
	if msg == "" or msg == "stats" then
		DoA.Stats:Toggle()
	elseif msg == "meter" then
		DoA.char.meter.enabled = not DoA.char.meter.enabled
		DoA:Fire("SETTINGS", "meter")
	elseif msg == "unlock" or msg == "lock" then
		DoA:SetFramesLocked(msg == "lock")
	elseif msg == "check" then
		DoA.History:Probe()
	elseif msg == "debug" then
		DoA.debug = not DoA.debug
		DoA:Print("debug " .. (DoA.debug and "on" or "off"))
	else
		DoA:Print(L["/doa: statistics. /doa meter: meter on/off. /doa unlock: move the frames. /doa check: what this client allows."])
	end
end

-- Report which function Blizzard blocked (taint), so it can be fixed.
do
	local f = CreateFrame("Frame")
	f:RegisterEvent("ADDON_ACTION_BLOCKED")
	f:RegisterEvent("ADDON_ACTION_FORBIDDEN")
	f:SetScript("OnEvent", function(_, event, addon, func)
		if addon ~= ADDON then return end
		local where = tostring(DoA.where)
		C_Timer.After(3, function() DoA:Print("|cffff5555blocked:|r " .. tostring(func) .. " (" .. where .. ")") end)
	end)
end
