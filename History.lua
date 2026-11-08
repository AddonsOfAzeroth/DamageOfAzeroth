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

-- Your own casts are not hidden: they give the timeline its moments.
-- { t = seconds into the fight, id = spellID, d = channel seconds }
local lastCast -- the cast just before combat (the pull) belongs to the fight
local function onCast(id, channel)
	id = Safe(id, nil)
	if type(id) ~= "number" then return end
	local now = GetTime()
	if not fight then
		lastCast = { at = now, id = id }
		return
	end
	local casts = fight.casts
	if #casts >= 400 then return end
	local t = now - fight.t0
	local prev = casts[#casts]
	-- a channel also reports a normal cast: keep one entry
	if channel and prev and prev.id == id and t - prev.t < 0.3 then
		prev.channel = now
		return
	end
	casts[#casts + 1] = { t = math.floor(t * 10 + 0.5) / 10, id = id, channel = channel and now or nil }
end

local function channelStop()
	local c = fight and fight.casts[#fight.casts]
	if c and c.channel then
		c.d = math.floor((GetTime() - c.channel) * 10 + 0.5) / 10
		c.channel = nil
	end
end

local function start()
	local enemy = Safe(UnitName("target"), nil)
	if not (type(enemy) == "string" and Safe(UnitCanAttack("player", "target"), false)) then enemy = nil end
	local now = GetTime()
	fight = {
		started = time(),
		t0 = now,
		group = groupType(),
		zone = Safe(GetRealZoneText and GetRealZoneText(), nil),
		enemy = enemy,
		samples = {},
		casts = {},
	}
	if lastCast and now - lastCast.at < 2.5 then fight.casts[1] = { t = 0, id = lastCast.id } end
	lastCast = nil
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
	for _, c in ipairs(f.casts) do c.channel = nil end
	f.timeline, f.stack = H.Timeline(f)
	f.t0 = nil
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
	-- the per-spell timeline is big: keep it for the last 30 fights
	for i = 1, #list - 30 do list[i].stack = nil end
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

---------------------------------------------------------------------------
-- Timeline (an estimate): each spell's total after the fight, shared over its
-- casts; a DoT spread over its duration, a channel over the channel time;
-- damage without casts (melee, procs) spread over the whole fight.
---------------------------------------------------------------------------
local overCache = {}
local function overTime(id) -- "... over 18 sec" in the spell's tooltip
	if overCache[id] == nil then
		local sec = false
		if C_TooltipInfo and C_TooltipInfo.GetSpellByID then
			local ok, data = pcall(C_TooltipInfo.GetSpellByID, id)
			if ok and Open(data) and Open(data.lines) then
				for _, line in ipairs(data.lines) do
					local t = Open(line) and Safe(line.leftText, nil)
					local n = type(t) == "string" and t:lower():match("over (%d+%.?%d*) sec")
					if n then sec = tonumber(n) break end
				end
			end
		end
		overCache[id] = sec
	end
	return overCache[id] or nil
end
H.OverTime = overTime

local function name(id)
	return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or (GetSpellInfo and GetSpellInfo(id)) or id
end

-- returns the total per second, and per spell: { { id = spellID, s = {...} }, ...,
-- { other = true, s = {...} } } for the 5 biggest spells and the rest
local STACKED = 5
function H.Timeline(f)
	local dur = math.min(600, math.ceil(f.duration or 0))
	if dur < 1 then return end
	local out, stack = {}, {}
	for i = 1, dur do out[i] = 0 end
	local cur -- the series the current spell adds to
	local function add(from, len, amount)
		from = math.max(0, math.min(dur - 1, from))
		len = math.min(len, dur - from)
		local first, last, per
		if len < 1 then
			first, last, per = math.floor(from), math.floor(from), amount
		else
			first, last, per = math.floor(from), math.floor(from + len - 0.001), amount / len
		end
		for s = first, last do
			out[s + 1] = out[s + 1] + per
			cur[s + 1] = cur[s + 1] + per
		end
	end
	for i, sp in ipairs(f.spells or {}) do -- biggest first
		if i <= STACKED or not stack[STACKED + 1] then
			local entry = i <= STACKED and { id = sp.id, s = {} } or { other = true, s = {} }
			for k = 1, dur do entry.s[k] = 0 end
			stack[#stack + 1] = entry
		end
		cur = stack[math.min(i, STACKED + 1)].s
		local mine = {}
		local spName = name(sp.id)
		for _, c in ipairs(f.casts or {}) do
			if c.id == sp.id or name(c.id) == spName then mine[#mine + 1] = c end
		end
		if #mine > 0 then
			local per = sp.total / #mine
			for _, c in ipairs(mine) do add(c.t, c.d or overTime(c.id) or 0, per) end
		else
			add(0, dur, sp.total)
		end
	end
	for i = 1, dur do out[i] = math.floor(out[i] + 0.5) end
	for _, e in ipairs(stack) do
		for i = 1, dur do e.s[i] = math.floor(e.s[i] + 0.5) end
	end
	return out, stack
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
	DoA:On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, id) if unit == "player" then pcall(onCast, id) end end)
	DoA:On("UNIT_SPELLCAST_CHANNEL_START", function(_, unit, _, id) if unit == "player" then pcall(onCast, id, true) end end)
	DoA:On("UNIT_SPELLCAST_CHANNEL_STOP", function(_, unit) if unit == "player" then pcall(channelStop) end end)
	-- Blizzard's meter settles a moment after the fight
	DoA:On("PLAYER_REGEN_ENABLED", function()
		C_Timer.After(1.5, function()
			local ok, err = pcall(finish)
			if not ok and DoA.debug then DoA:Print("history: " .. tostring(err)) end
		end)
	end)
end
