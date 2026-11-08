-- Damage of Azeroth by DinX: the live meter.
-- Reads Blizzard's meter (C_DamageMeter). In combat names and amounts can be
-- secret: they then go straight to the bars and text (allowed for hidden
-- values) and are never compared or calculated.
local _, ns = ...
local DoA = ns.DoA
local L = DoA.L
local S = DoA.Style
local Safe, IsSecret, Open, Short = DoA.Safe, DoA.IsSecret, DoA.Open, DoA.Short

local M = DoA:NewModule("Meter")

local WIDTH, ROW_H, HEADER, PAD = 220, 16, 20, 2

local MODES = {
	{ key = "damage", label = "Damage", enum = "DamageDone", perSecond = false },
	{ key = "dps", label = "DPS", enum = "DamageDone", perSecond = true },
	{ key = "healing", label = "Healing", enum = "HealingDone", perSecond = false },
	{ key = "hps", label = "HPS", enum = "HealingDone", perSecond = true },
}
local SESSIONS = { current = "Current", overall = "Overall" }

local function cfg() return DoA.char.meter end

local function modeOf(key)
	for i, m in ipairs(MODES) do if m.key == key then return m, i end end
	return MODES[1], 1
end

-- v as it is when hidden (for widgets), else v or default (no test on hidden values)
local function val(v, default)
	if IsSecret(v) then return v end
	if v == nil then return default end
	return v
end

local function session()
	if not (C_DamageMeter and C_DamageMeter.GetCombatSessionFromType and Enum and Enum.DamageMeterType
		and Enum.DamageMeterSessionType) then return end
	local c = cfg()
	local m = modeOf(c.mode)
	local st = c.session == "overall" and Enum.DamageMeterSessionType.Overall or Enum.DamageMeterSessionType.Current
	local ok, s = pcall(C_DamageMeter.GetCombatSessionFromType, st, Enum.DamageMeterType[m.enum])
	if ok and Open(s) then return s end
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local function headerButton(parent, tip, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(HEADER)
	b.text = S:Font(b, 11)
	b.text:SetPoint("CENTER")
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", onClick)
	b:SetScript("OnEnter", function(self)
		self.text:SetTextColor(unpack(S.colors.accent))
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(L[tip], 1, 1, 1, 1, true)
		GameTooltip:Show()
		M:ShowTools(true)
	end)
	b:SetScript("OnLeave", function(self)
		self.text:SetTextColor(unpack(self.color or S.colors.text))
		GameTooltip:Hide()
		M:ShowTools(false)
	end)
	return b
end

local function fit(b, text)
	b.text:SetText(text)
	b:SetWidth(b.text:GetStringWidth() + 10)
end

function M:Build()
	local f = CreateFrame("Frame", "DamageOfAzerothMeter", UIParent, "BackdropTemplate")
	S:Backdrop(f)
	f:SetWidth(WIDTH)
	f:SetFrameStrata("LOW")
	f:EnableMouse(true)
	f:SetScript("OnEnter", function() M:ShowTools(true) end)
	f:SetScript("OnLeave", function() if not f:IsMouseOver() then M:ShowTools(false) end end)
	self.frame = f

	self.title = headerButton(f, "Click: next view (damage, DPS, healing, HPS). Right-click: previous.", function(_, btn)
		local _, i = modeOf(cfg().mode)
		i = btn == "RightButton" and (i - 2) % #MODES + 1 or i % #MODES + 1
		cfg().mode = MODES[i].key
		M:Refresh()
	end)
	self.title:SetPoint("TOPLEFT", 2, 0)

	self.when = headerButton(f, "Click: this fight or all fights.", function()
		cfg().session = cfg().session == "overall" and "current" or "overall"
		M:Refresh()
	end)
	self.when:SetPoint("TOPRIGHT", -2, 0)
	self.when.color = S.colors.muted
	self.when.text:SetTextColor(unpack(S.colors.muted))

	-- only while the mouse is on the meter: statistics and reset
	self.stats = headerButton(f, "Open the statistics (/doa).", function() DoA.Stats:Toggle() end)
	fit(self.stats, L["Statistics"])
	self.stats.color = S.colors.accent
	self.stats.text:SetTextColor(unpack(S.colors.accent))
	self.reset = headerButton(f, "Clear all fights.", function()
		if C_DamageMeter and C_DamageMeter.ResetAllCombatSessions then pcall(C_DamageMeter.ResetAllCombatSessions) end
		M:Refresh()
	end)
	fit(self.reset, L["Reset"])
	self.reset.color = S.colors.muted
	self.reset.text:SetTextColor(unpack(S.colors.muted))
	self.reset:SetPoint("RIGHT", self.when, "LEFT", 0, 0)
	self.stats:SetPoint("RIGHT", self.reset, "LEFT", 0, 0)
	self:ShowTools(false)

	local line = f:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(unpack(S.colors.edge))
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", 1, -HEADER)
	line:SetPoint("TOPRIGHT", -1, -HEADER)

	self.empty = S:Font(f, 11)
	self.empty:SetPoint("TOP", 0, -HEADER - 6)
	self.empty:SetTextColor(unpack(S.colors.muted))

	self.rows = {}
	S:RegisterMover(f, "meter", L["Damage meter"], function(fr)
		fr:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -320, 220)
	end)
end

function M:ShowTools(on)
	if not self.stats then return end
	on = on and self.frame:IsMouseOver()
	self.stats:SetShown(on)
	self.reset:SetShown(on)
end

local function row(i)
	local r = M.rows[i]
	if r then return r end
	r = S:StatusBar(M.frame)
	r:SetHeight(ROW_H)
	r:SetPoint("TOPLEFT", PAD, -HEADER - PAD - (i - 1) * (ROW_H + 1))
	r:SetPoint("TOPRIGHT", -PAD, -HEADER - PAD - (i - 1) * (ROW_H + 1))
	r.name = S:Font(r, 11)
	r.name:SetPoint("LEFT", 4, 0)
	r.name:SetPoint("RIGHT", -64, 0)
	r.name:SetJustifyH("LEFT")
	r.name:SetWordWrap(false)
	r.value = S:Font(r, 11)
	r.value:SetPoint("RIGHT", -4, 0)
	M.rows[i] = r
	return r
end

local function classColor(class)
	class = Safe(class, nil)
	local c = type(class) == "string" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then return c.r, c.g, c.b end
	return S.colors.accent[1], S.colors.accent[2], S.colors.accent[3]
end
M.ClassColor = classColor

function M:Refresh()
	local f = self.frame
	if not f then return end
	local c = cfg()
	if not c.enabled then return f:Hide() end
	local s = session()
	local mode = modeOf(c.mode)
	fit(self.title, L[mode.label])
	local time = s and DoA.Clock(s.durationSeconds) or ""
	fit(self.when, L[SESSIONS[c.session] or "Current"] .. (time ~= "" and ("  " .. time) or ""))

	local list = s and Open(s.combatSources) and s.combatSources or nil
	local n = 0
	if list then
		local max = val(s.maxAmount, 1)
		for _, src in ipairs(list) do
			if n >= c.rows then break end
			if Open(src) then
				n = n + 1
				local r = row(n)
				r:SetStatusBarColor(classColor(src.classFilename))
				pcall(r.SetMinMaxValues, r, 0, max)
				pcall(r.SetValue, r, val(src.totalAmount, 0))
				pcall(r.name.SetText, r.name, val(src.name, "?"))
				local shown
				if mode.perSecond then shown = src.amountPerSecond else shown = src.totalAmount end
				pcall(r.value.SetText, r.value, Short(shown))
				r:Show()
			end
		end
	end
	for i = n + 1, #self.rows do self.rows[i]:Hide() end

	local none = n == 0
	self.empty:SetShown(none)
	if none then self.empty:SetText(C_DamageMeter and L["No fight yet."] or L["Not available in this client."]) end
	f:SetHeight(HEADER + PAD * 2 + (none and 20 or n * (ROW_H + 1)))
	f:SetShown(not (none and c.hideEmpty and not InCombatLockdown()))
end

function M:OnEnable()
	self:Build()
	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED",
		"DAMAGE_METER_RESET", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }) do
		pcall(ev.RegisterEvent, ev, e)
	end
	-- updates come in bursts during a fight: redraw at most twice a second
	local pending = false
	ev:SetScript("OnEvent", function()
		if pending then return end
		pending = true
		C_Timer.After(0.5, function()
			pending = false
			local ok, err = pcall(M.Refresh, M)
			if not ok and DoA.debug then DoA:Print("meter: " .. tostring(err)) end
		end)
	end)
	-- the fight clock keeps running between updates
	C_Timer.NewTicker(1, function()
		if InCombatLockdown() and M.frame:IsShown() then pcall(M.Refresh, M) end
	end)
	DoA:Listen("SETTINGS", function(group) if group == "meter" then pcall(M.Refresh, M) end end)
	pcall(M.Refresh, M)
end
