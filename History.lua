-- Damage of Azeroth by DinX: fight history.
-- When a fight ends, Blizzard's meter (C_DamageMeter) is read once and kept:
-- duration, everyone's damage and healing, and your own spells. During the
-- fight your damage is sampled every second for the curve, as long as the
-- client shows it (it can hide the numbers in combat; then there is no curve).
local _, ns = ...
local DoA = ns.DoA
local L = DoA.L
local Safe, Open = DoA.Safe, DoA.Open

local H = DoA:NewModule("History")

local TYPES = { damage = "DamageDone", healing = "HealingDone" }

local function api()
	return C_DamageMeter and C_DamageMeter.GetCombatSessionFromType and Enum and Enum.DamageMeterType
		and Enum.DamageMeterSessionType
end

local function current(kind)
	if not api() then return end
	local ok, s = pcall(C_DamageMeter.GetCombatSessionFromType, Enum.DamageMeterSessionType.Current,
		Enum.DamageMeterType[TYPES[kind]])
	if ok and Open(s) then return s end
end

local function groupType()
	if IsInRaid() then return "raid" end
	if IsInGroup() then return "party" end
	return "solo"
end
H.GroupType = groupType

-- your own entry in a session, or nil (also when it is hidden)
local function mine(s)
	if not (s and Open(s.combatSources)) then return end
	for _, src in ipairs(s.combatSources) do
		if Open(src) and Safe(src.isLocalPlayer, false) == true then return src end
	end
end

---------------------------------------------------------------------------
-- During the fight
---------------------------------------------------------------------------
local fight -- the running fight, or nil

local function sample()
	if not fight then return end
	local src = mine(current("damage"))
	local v = src and Safe(src.totalAmount, nil)
	if type(v) == "number" then
		fight.samples[#fight.samples + 1] = v
	else
		fight.hidden = true
		fight.samples[#fight.samples + 1] = false -- keeps the timeline
	end
end

local function start()
	local enemy = Safe(UnitName("target"), nil)
	if not (type(enemy) == "string" and Safe(UnitCanAttack("player", "target"), false)) then enemy = nil end
	fight = {
		started = time(),
		group = groupType(),
		zone = Safe(GetRealZoneText and GetRealZoneText(), nil),
		enemy = enemy,
		samples = {},
	}
	H.ticker = H.ticker or C_Timer.NewTicker(1, function() pcall(sample) end)
end

-- names, classes and amounts of one session, readable after the fight
local function sources(s)
	local out = {}
	if not (s and Open(s.combatSources)) then return out end
	for _, src in ipairs(s.combatSources) do
		if Open(src) then
			local total = Safe(src.totalAmount, nil)
			local name = Safe(src.name, nil)
			if type(total) == "number" and type(name) == "string" then
				out[#out + 1] = { name = name, class = Safe(src.classFilename, nil), total = total,
					me = Safe(src.isLocalPlayer, false) == true or nil }
			end
		end
	end
	table.sort(out, function(a, b) return a.total > b.total end)
	return out
end

local function spells(kind)
	local out = {}
	if not (api() and C_DamageMeter.GetCombatSessionSourceFromType) then return out end
	local guid = Safe(UnitGUID("player"), nil)
	if not guid then return out end
	local ok, s = pcall(C_DamageMeter.GetCombatSessionSourceFromType, Enum.DamageMeterSessionType.Current,
		Enum.DamageMeterType[TYPES[kind]], guid)
	if not (ok and Open(s) and Open(s.combatSpells)) then return out end
	for _, sp in ipairs(s.combatSpells) do
		if Open(sp) then
			local id, total = Safe(sp.spellID, nil), Safe(sp.totalAmount, nil)
			if type(id) == "number" and type(total) == "number" and total > 0 then
				out[#out + 1] = { id = id, total = total }
			end
		end
	end
	table.sort(out, function(a, b) return a.total > b.total end)
	return out
end

local function finish()
	local f = fight
	fight = nil
	if H.ticker then H.ticker:Cancel() H.ticker = nil end
	if not f then return end
	local dmg, heal = current("damage"), current("healing")
	local dur = dmg and Safe(dmg.durationSeconds, nil)
	if type(dur) ~= "number" or dur < 3 then return end -- a stray hit is not a fight
	f.duration = dur
	f.damage = sources(dmg)
	f.healing = sources(heal)
	f.spells = spells("damage")
	f.healSpells = spells("healing")
	for _, r in ipairs(f.damage) do if r.me then f.myDamage = r.total end end
	for _, r in ipairs(f.healing) do if r.me then f.myHealing = r.total end end
	if not (f.myDamage or f.myHealing) then return end
	-- the curve: drop it when the numbers were hidden all fight
	local any = false
	-- a curve needs most of the fight; this client usually hides it in combat
	local readable = 0
	for _, v in ipairs(f.samples) do if v then readable = readable + 1 end end
	if readable < math.max(5, #f.samples * 0.6) then f.samples = nil end
	local list = DoA.char.fights
	list[#list + 1] = f
	while #list > DoA.char.stats.keep do table.remove(list, 1) end
	DoA:Fire("FIGHT", f)
end

---------------------------------------------------------------------------
-- Reading the saved fights
---------------------------------------------------------------------------
function H:List(filter)
	local out = {}
	for _, f in ipairs(DoA.char.fights) do
		if filter == "all" or f.group == filter then out[#out + 1] = f end
	end
	return out
end

function H.DPS(f) return f.myDamage and f.duration and f.duration > 0 and f.myDamage / f.duration or 0 end
function H.HPS(f) return f.myHealing and f.duration and f.duration > 0 and f.myHealing / f.duration or 0 end

-- DPS per second from the cumulative samples, smoothed over `window` seconds
function H.Curve(samples, window)
	if type(samples) ~= "table" then return end
	local readable = 0 -- older saved fights can hold a hidden fight with one number
	for _, v in ipairs(samples) do if v then readable = readable + 1 end end
	if readable < math.max(5, #samples * 0.6) then return end
	window = window or 5
	local out = {}
	for i = 1, #samples do
		local a, b = samples[math.max(1, i - window)], samples[i]
		local span = i - math.max(1, i - window)
		if a and b and span > 0 then out[i] = math.max(0, (b - a) / span) else out[i] = false end
	end
	return out
end

-- /doa check: what this client gives us
function H:Probe()
	if not api() then return DoA:Print("C_DamageMeter: -") end
	local s = current("damage")
	local src = mine(s)
	DoA:Print(("meter %s, sources %s, you %s, amount %s, in combat %s"):format(
		s and "ok" or "-",
		s and (Open(s.combatSources) and #s.combatSources or "hidden") or "-",
		src and "found" or "-",
		src and (DoA.IsSecret(src.totalAmount) and "hidden" or tostring(src.totalAmount)) or "-",
		tostring(InCombatLockdown())))
end

function H:OnEnable()
	DoA:On("PLAYER_REGEN_DISABLED", function() pcall(start) end)
	-- Blizzard's meter settles a moment after the fight
	DoA:On("PLAYER_REGEN_ENABLED", function()
		C_Timer.After(1.5, function()
			local ok, err = pcall(finish)
			if not ok and DoA.debug then DoA:Print("history: " .. tostring(err)) end
		end)
	end)
end
