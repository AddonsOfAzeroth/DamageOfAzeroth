-- Damage of Azeroth by DinX: shared flat look
local ADDON, ns = ...
local DoA = ns.DoA

local S = {}
DoA.Style = S

S.flat = "Interface\\Buttons\\WHITE8x8"
-- Roboto (Apache License 2.0, see media\LICENSE-Roboto.txt) reads better than the
-- game font at small sizes; "wow" in the settings brings the game font back.
S.ROBOTO = "Interface\\AddOns\\" .. ADDON .. "\\media\\Roboto-Regular.ttf"

-- A font file added while the game runs is only found after a restart; until
-- then (or if it is missing) fall back to the game font so no text disappears.
local probe
local function usable(path)
	probe = probe or UIParent:CreateFontString(nil, "OVERLAY")
	local ok = pcall(probe.SetFont, probe, path, 12, "")
	return ok and probe:GetFont() ~= nil and (probe:GetFont()):lower():find("roboto", 1, true) ~= nil
end
S.font = usable(S.ROBOTO) and S.ROBOTO or STANDARD_TEXT_FONT
S.flags = "" -- "" = clean text with a soft shadow, "OUTLINE" = thick black outline

function S:LoadFont(db)
	self.font = (db and db.font == "wow" or not usable(self.ROBOTO)) and STANDARD_TEXT_FONT or self.ROBOTO
	self.flags = (db and db.fontOutline) and "OUTLINE" or ""
end

-- Font, flags and a soft shadow in one go (flags: nil = the chosen style).
function S:ApplyFont(fs, size, flags)
	fs:SetFont(self.font, size or 12, flags or self.flags)
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetShadowOffset(1, -1)
end
S.colors = {
	bg = { 0.04, 0.05, 0.08, 0.85 },
	border = { 0, 0, 0, 1 },
	edge = { 0.16, 0.19, 0.25, 1 },
	accent = { 0.41, 0.80, 0.94 },    -- mage blue
	text = { 0.91, 0.93, 0.95 },
	muted = { 0.60, 0.65, 0.71 },
	warn = { 0.95, 0.30, 0.30 },
	hint = { 1.00, 0.82, 0.25 },
	proc = { 0.85, 0.45, 1.00 },
	xp = { 0.58, 0.36, 0.86 },
	rested = { 0.25, 0.55, 0.95 },
}

-- 1px black border plus dark fill, the classic "ElvUI" panel.
function S:Backdrop(frame, alpha)
	if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
	frame:SetBackdrop({ bgFile = self.flat, edgeFile = self.flat, edgeSize = 1 })
	local c = self.colors.bg
	frame:SetBackdropColor(c[1], c[2], c[3], alpha or c[4])
	frame:SetBackdropBorderColor(0, 0, 0, 1)
end

function S:Font(parent, size, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	self:ApplyFont(fs, size)
	fs:SetTextColor(unpack(self.colors.text))
	return fs
end

function S:StatusBar(parent, color)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetStatusBarTexture(self.flat)
	if color then bar:SetStatusBarColor(unpack(color)) end
	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.1, 0.1, 0.12, 0.9)
	bar.bg = bg
	return bar
end

-- Square icon with border (spell icons).
function S:Icon(parent, size)
	local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	f:SetSize(size, size)
	self:Backdrop(f, 1)
	local tex = f:CreateTexture(nil, "ARTWORK")
	tex:SetPoint("TOPLEFT", 1, -1)
	tex:SetPoint("BOTTOMRIGHT", -1, 1)
	tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.icon = tex
	return f
end

---------------------------------------------------------------------------
-- Movers: any frame can be dragged while the frames are unlocked.
-- Position is saved in DoA.char.points[key]; defaultFn(frame) places it otherwise.
---------------------------------------------------------------------------
S.movers = {}

function S:ApplyPoint(frame, key)
	local m = self.movers[key]
	if InCombatLockdown() and frame:IsProtected() then return end
	frame:ClearAllPoints()
	local pt = DoA.char.points[key]
	if pt then
		frame:SetPoint(pt[1], UIParent, pt[3], pt[4], pt[5])
	elseif m and m.defaultFn then
		m.defaultFn(frame)
	end
end

-- Re-anchor a frame by its top edge (TOPLEFT or TOPRIGHT of the screen,
-- whichever side is nearer), so a change in height grows it downward.
function S:AnchorTop(frame, key)
	local left, right, top = frame:GetLeft(), frame:GetRight(), frame:GetTop()
	if not (left and right and top) then return end
	local fs, us = frame:GetEffectiveScale(), UIParent:GetEffectiveScale()
	left, right, top = left * fs / us, right * fs / us, top * fs / us
	local w, h = UIParent:GetWidth(), UIParent:GetHeight()
	local pt
	if (left + right) / 2 > w / 2 then
		pt = { "TOPRIGHT", "UIParent", "TOPRIGHT", math.floor(right - w + 0.5), math.floor(top - h + 0.5) }
	else
		pt = { "TOPLEFT", "UIParent", "TOPLEFT", math.floor(left + 0.5), math.floor(top - h + 0.5) }
	end
	DoA.char.points[key] = pt
	frame:ClearAllPoints()
	frame:SetPoint(pt[1], UIParent, pt[3], pt[4] * us / fs, pt[5] * us / fs)
end

function S:RegisterMover(frame, key, label, defaultFn, anchorTop)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	local o = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	o:SetAllPoints()
	o:SetFrameStrata("DIALOG")
	o:EnableMouse(true)
	o:RegisterForDrag("LeftButton")
	o:SetBackdrop({ bgFile = self.flat, edgeFile = self.flat, edgeSize = 1 })
	o:SetBackdropColor(0.41, 0.80, 0.94, 0.25)
	o:SetBackdropBorderColor(0.41, 0.80, 0.94, 1)
	local t = self:Font(o, 11)
	t:SetPoint("CENTER")
	t:SetText(label)
	o:SetScript("OnDragStart", function()
		if InCombatLockdown() then return end
		frame:StartMoving()
	end)
	o:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		if anchorTop then
			S:AnchorTop(frame, key)
			return
		end
		local p, _, rp, x, y = frame:GetPoint()
		DoA.char.points[key] = { p, "UIParent", rp, math.floor(x + 0.5), math.floor(y + 0.5) }
	end)
	o:Hide()
	self.movers[key] = { frame = frame, overlay = o, defaultFn = defaultFn }
	self:ApplyPoint(frame, key)
end

function S:UpdateMovers()
	local show = not DoA:FramesLocked() and not InCombatLockdown()
	for _, m in pairs(self.movers) do m.overlay:SetShown(show) end
end

function S:ResetMovers()
	for key, m in pairs(self.movers) do
		DoA.char.points[key] = nil
		self:ApplyPoint(m.frame, key)
	end
end

DoA:Listen("SETTINGS", function(group) if group == "bars" then S:UpdateMovers() end end)
DoA:On("PLAYER_REGEN_DISABLED", function() for _, m in pairs(S.movers) do m.overlay:Hide() end end)
DoA:On("PLAYER_REGEN_ENABLED", function() S:UpdateMovers() end)
