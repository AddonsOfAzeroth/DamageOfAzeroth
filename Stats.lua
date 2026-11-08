-- Damage of Azeroth by DinX: statistics window (/doa).
-- Left: your fights (filter solo / party / raid) with average and best.
-- Right: a graph (the DPS curve of one fight, or the trend of your last
-- fights) and below it your spells or the group's share for that fight.
-- Everything here comes from the saved fights (History.lua): plain numbers.
local _, ns = ...
local DoA = ns.DoA
local L = DoA.L
local S = DoA.Style
local H = DoA.History
local Short, Clock = DoA.Short, DoA.Clock

local ST = DoA:NewModule("Stats")

local W, HGT, HEAD, PAD = 580, 400, 26, 8 -- default size; the corner grip makes it bigger
local LEFT_W = 210
local LIST_ROW, LIST_MAX = 20, 40     -- rows made; how many show depends on the height
local GRAPH_H = 150
local DETAIL_ROW, DETAIL_MAX = 18, 20

local GROUP_COLORS = {
	solo = S.colors.accent,
	party = { 0.35, 0.85, 0.45 },
	raid = { 1.00, 0.60, 0.20 },
}
local FILTERS = { "all", "solo", "party", "raid" }
local FILTER_LABEL = { all = "All", solo = "Solo", party = "Party", raid = "Raid" }

local function cfg() return DoA.char.stats end

---------------------------------------------------------------------------
-- Small widgets
---------------------------------------------------------------------------
-- a text button that lights up when active
local function tab(parent, label, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(18)
	b.text = S:Font(b, 11)
	b.text:SetPoint("CENTER")
	b.text:SetText(label)
	b:SetWidth(b.text:GetStringWidth() + 14)
	b.line = b:CreateTexture(nil, "ARTWORK")
	b.line:SetColorTexture(unpack(S.colors.accent))
	b.line:SetHeight(2)
	b.line:SetPoint("BOTTOMLEFT", 4, 0)
	b.line:SetPoint("BOTTOMRIGHT", -4, 0)
	b:SetScript("OnClick", onClick)
	b:SetScript("OnEnter", function(self) if not self.active then self.text:SetTextColor(1, 1, 1) end end)
	b:SetScript("OnLeave", function(self) ST.Paint(self) end)
	function b:SetActive(on) self.active = on ST.Paint(self) end
	return b
end

function ST.Paint(b)
	if b.active then
		b.text:SetTextColor(unpack(S.colors.accent))
		b.line:Show()
	else
		b.text:SetTextColor(unpack(S.colors.muted))
		b.line:Hide()
	end
end

local function panel(parent)
	local p = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	p:SetBackdrop({ bgFile = S.flat, edgeFile = S.flat, edgeSize = 1 })
	p:SetBackdropColor(0, 0, 0, 0.25)
	p:SetBackdropBorderColor(unpack(S.colors.edge))
	return p
end

-- a stat tile: big number, small label
local function tile(parent, label)
	local t = panel(parent)
	t:SetSize((LEFT_W - 8) / 3, 40)
	t.value = S:Font(t, 14)
	t.value:SetPoint("TOP", 0, -6)
	t.label = S:Font(t, 9)
	t.label:SetPoint("BOTTOM", 0, 5)
	t.label:SetTextColor(unpack(S.colors.muted))
	t.label:SetText(label)
	return t
end

---------------------------------------------------------------------------
-- Graph: lines for a curve, bars for a trend, a few grid lines
---------------------------------------------------------------------------
local function newGraph(parent)
	local g = panel(parent)
	g.lines, g.bars, g.grid, g.labels, g.icons = {}, {}, {}, {}, {}
	g.msg = S:Font(g, 11)
	g.msg:SetPoint("CENTER")
	g.msg:SetTextColor(unpack(S.colors.muted))
	g.msg:SetWidth(300)
	g.title = S:Font(g, 10)
	g.title:SetPoint("TOPLEFT", 6, -4)
	g.title:SetTextColor(unpack(S.colors.muted))
	return g
end

local function clearGraph(g)
	for _, l in ipairs(g.lines) do l:Hide() end
	for _, b in ipairs(g.bars) do b:Hide() end
	for _, l in ipairs(g.grid) do l:Hide() end
	for _, t in ipairs(g.labels) do t:Hide() end
	for _, b in ipairs(g.icons) do b:Hide() end
	for _, t in ipairs(g.segs or {}) do t:Hide() end
	for _, e in ipairs(g.legend or {}) do e:Hide() end
	for _, l in ipairs(g.dl or {}) do l:Hide() end
	for _, t in ipairs(g.cl or {}) do t:Hide() end
	if g.sep then g.sep:Hide() end
	g.msg:Hide()
end

local INSET_L, INSET_R, INSET_T, INSET_B = 34, 8, 18, 14

local function area(g)
	return g:GetWidth() - INSET_L - INSET_R, g:GetHeight() - INSET_T - INSET_B
end

local function label(g, i, text, x, y, justify)
	local t = g.labels[i]
	if not t then
		t = S:Font(g, 9)
		t:SetTextColor(unpack(S.colors.muted))
		g.labels[i] = t
	end
	t:ClearAllPoints()
	t:SetPoint(justify or "RIGHT", g, "BOTTOMLEFT", x, y)
	t:SetText(text)
	t:Show()
end

-- three grid lines with their values; returns the next free label index
local function grid(g, max)
	local w, h = area(g)
	for i = 1, 3 do
		local l = g.grid[i]
		if not l then
			l = g:CreateTexture(nil, "BORDER")
			l:SetColorTexture(1, 1, 1, 0.06)
			l:SetHeight(1)
			g.grid[i] = l
		end
		local y = INSET_B + h * i / 3
		l:ClearAllPoints()
		l:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", INSET_L, y)
		l:SetWidth(w)
		l:Show()
		label(g, i, Short(max * i / 3), INSET_L - 4, y)
	end
	return 4
end

local function line(g, i, x1, y1, x2, y2, c)
	local l = g.lines[i]
	if not l then
		l = g:CreateLine(nil, "ARTWORK")
		l:SetThickness(2)
		g.lines[i] = l
	end
	l:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
	l:SetStartPoint("BOTTOMLEFT", g, INSET_L + x1, INSET_B + y1)
	l:SetEndPoint("BOTTOMLEFT", g, INSET_L + x2, INSET_B + y2)
	l:Show()
end

-- this fight next to your usual: same enemy, same kind of group, your best
local function drawCompare(g, f, fights)
	clearGraph(g)
	g.title:SetText(L["This fight compared"])
	local function avg(test)
		local sum, n = 0, 0
		for _, o in ipairs(fights) do
			if test(o) then sum, n = sum + H.DPS(o), n + 1 end
		end
		return n > 0 and sum / n or nil, n
	end
	local best = 0
	for _, o in ipairs(fights) do best = math.max(best, H.DPS(o)) end
	local bars = { { L["This fight"], H.DPS(f), S.colors.accent } }
	local enemyAvg, en = avg(function(o) return f.enemy and o.enemy == f.enemy end)
	if enemyAvg and en > 1 then bars[#bars + 1] = { L["Usual vs %s"]:format(f.enemy), enemyAvg, { 0.6, 0.65, 0.71 } } end
	local groupAvg = avg(function(o) return o.group == f.group end)
	if groupAvg then bars[#bars + 1] = { L["Usual " .. (f.group or "solo")], groupAvg, GROUP_COLORS[f.group] or S.colors.accent } end
	bars[#bars + 1] = { L["Best"], best, { 1, 0.82, 0.25 } }
	local max = 1
	for _, b in ipairs(bars) do max = math.max(max, b[2]) end
	max = max * 1.15
	local nextLabel = grid(g, max)
	local w, h = area(g)
	local slot = w / #bars
	for i, b in ipairs(bars) do
		local bar = g.bars[i]
		if not bar then
			bar = CreateFrame("Button", nil, g)
			bar.tex = bar:CreateTexture(nil, "ARTWORK")
			bar.tex:SetAllPoints()
			g.bars[i] = bar
		end
		bar.fight = nil
		bar:SetScript("OnEnter", nil)
		bar:SetScript("OnClick", nil)
		bar:ClearAllPoints()
		local bw = math.min(60, slot * 0.6)
		bar:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", INSET_L + (i - 0.5) * slot - bw / 2, INSET_B)
		bar:SetSize(bw, math.max(1, b[2] / max * h))
		bar.tex:SetColorTexture(b[3][1], b[3][2], b[3][3], i == 1 and 1 or 0.7)
		bar:Show()
		-- value above, name below
		label(g, nextLabel, Short(b[2]), INSET_L + (i - 0.5) * slot, INSET_B + b[2] / max * h + 2, "BOTTOM")
		label(g, nextLabel + 1, b[1], INSET_L + (i - 0.5) * slot, INSET_B - 2, "TOP")
		nextLabel = nextLabel + 2
	end
end

-- moving average over `w` seconds around each point
local function smooth(t, w)
	local out = {}
	for i = 1, #t do
		local sum, n = 0, 0
		for j = math.max(1, i - w), math.min(#t, i + w) do sum, n = sum + t[j], n + 1 end
		out[i] = sum / n
	end
	return out
end

local function spellName(id)
	return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or (GetSpellInfo and GetSpellInfo(id)) or ("#" .. id)
end

-- your casts as small icons on the time axis (hover: spell and time)
local function castIcons(g, f, w)
	local dur = f.duration or 0
	if dur <= 0 then return end
	local lastX = -99
	local n = 0
	for _, c in ipairs(f.casts or {}) do
		local x = c.t / dur * w
		if x - lastX >= 11 and x <= w then
			n = n + 1
			local b = g.icons[n]
			if not b then
				b = CreateFrame("Button", nil, g)
				b:SetSize(10, 10)
				b.tex = b:CreateTexture(nil, "OVERLAY")
				b.tex:SetAllPoints()
				b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
				b:SetScript("OnEnter", function(self)
					GameTooltip:SetOwner(self, "ANCHOR_TOP")
					GameTooltip:AddLine(spellName(self.cast.id), 1, 1, 1)
					GameTooltip:AddLine(Clock(self.cast.t), 0.7, 0.7, 0.7)
					GameTooltip:Show()
				end)
				b:SetScript("OnLeave", function() GameTooltip:Hide() end)
				g.icons[n] = b
			end
			b.cast = c
			local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(c.id)
			b.tex:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
			b:ClearAllPoints()
			b:SetPoint("BOTTOM", g, "BOTTOMLEFT", INSET_L + x, INSET_B + 1)
			b:Show()
			lastX = x
		end
	end
end

-- Stacked DPS per spell over the fight (an estimate, see History.Timeline).
-- Draws in `g` inside the box x0, y0, w, h (from its bottom-left); a legend
-- (colour, icon, name) at lx, ly from its top-left. Returns the scale top, or nil.
local PALETTE = {
	{ 0.41, 0.80, 0.94 }, { 0.95, 0.55, 0.25 }, { 0.62, 0.45, 0.95 },
	{ 0.35, 0.85, 0.45 }, { 0.95, 0.80, 0.25 }, { 0.55, 0.58, 0.62 },
}
function ST.DrawStack(g, f, x0, y0, w, h, lx, ly)
	g.segs, g.legend = g.segs or {}, g.legend or {}
	for _, t in ipairs(g.segs) do t:Hide() end
	for _, e in ipairs(g.legend) do e:Hide() end
	local stack = f.stack
	if not (stack and stack[1] and #stack[1].s > 0) then return end
	local dur = #stack[1].s
	local nb = math.max(1, math.min(dur, math.floor(w / 4)))
	local per = dur / nb
	local function range(b)
		local from = math.floor((b - 1) * per) + 1
		return from, math.max(from, math.floor(b * per))
	end
	local top = 1
	for b = 1, nb do
		local from, to = range(b)
		local sum = 0
		for _, e in ipairs(stack) do for i = from, to do sum = sum + (e.s[i] or 0) end end
		top = math.max(top, sum / (to - from + 1))
	end
	top = top * 1.1
	local bw, k = w / nb, 0
	for b = 1, nb do
		local from, to = range(b)
		local y = 0
		for si, e in ipairs(stack) do
			local v = 0
			for i = from, to do v = v + (e.s[i] or 0) end
			v = v / (to - from + 1)
			if v > 0 then
				k = k + 1
				local t = g.segs[k]
				if not t then
					t = g:CreateTexture(nil, "ARTWORK")
					g.segs[k] = t
				end
				local c = PALETTE[si] or PALETTE[#PALETTE]
				t:SetColorTexture(c[1], c[2], c[3], 0.85)
				t:ClearAllPoints()
				t:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", x0 + (b - 1) * bw, y0 + y / top * h)
				t:SetSize(math.max(1, bw - 1), math.max(1, v / top * h))
				t:Show()
				y = y + v
			end
		end
	end
	-- legend: which colour is which spell
	local x = lx
	for si, e in ipairs(stack) do
		local item = g.legend[si]
		if not item then
			item = CreateFrame("Frame", nil, g)
			item:SetSize(10, 10)
			item.box = item:CreateTexture(nil, "ARTWORK")
			item.box:SetAllPoints()
			item.text = S:Font(item, 10)
			item.text:SetPoint("LEFT", item, "RIGHT", 3, 0)
			g.legend[si] = item
		end
		local c = PALETTE[si] or PALETTE[#PALETTE]
		item.box:SetColorTexture(c[1], c[2], c[3], 1)
		item.text:SetText(e.other and L["Other"] or spellName(e.id))
		item:ClearAllPoints()
		item:SetPoint("TOPLEFT", g, "TOPLEFT", x, -ly)
		local wide = 14 + item.text:GetStringWidth() + 10
		item:SetShown(x + wide - lx <= w)
		x = x + wide
	end
	return top
end

-- Above: a line chart of your DPS (white, scale on the left) and your total so
-- far (gold, scale on the right). Below: your spells stacked per second.
local DPS_COLOR, TOTAL_COLOR = { 0.95, 0.95, 0.95 }, { 1, 0.82, 0.25 }
function ST.DrawCombo(g, f, x0, y0, w, h, lx, ly)
	g.dl, g.cl = g.dl or {}, g.cl or {}
	for _, l in ipairs(g.dl) do l:Hide() end
	for _, t in ipairs(g.cl) do t:Hide() end
	if g.sep then g.sep:Hide() end
	if not (f.timeline and #f.timeline >= 2) then return end
	local hs = math.floor(h * 0.45)
	local stackTop = ST.DrawStack(g, f, x0, y0, w, hs, lx, ly)
	local y1 = y0 + hs + 10
	local hl = h - hs - 10 - 12
	if hl < 10 then return stackTop end

	local dps = smooth(f.timeline, 2)
	local total, run = {}, 0
	for i, v in ipairs(f.timeline) do run = run + v total[i] = run end
	local maxD, maxT = 1, math.max(1, run)
	for _, v in ipairs(dps) do maxD = math.max(maxD, v) end
	maxD = maxD * 1.1
	local n = #dps
	local step = math.max(1, math.ceil(n / math.max(2, w / 3)))
	local k = 0
	local function seg(xa, ya, xb, yb, c)
		k = k + 1
		local l = g.dl[k]
		if not l then
			l = g:CreateLine(nil, "OVERLAY")
			g.dl[k] = l
		end
		l:SetThickness(2)
		l:SetColorTexture(c[1], c[2], c[3], 1)
		l:SetStartPoint("BOTTOMLEFT", g, x0 + xa, y1 + ya)
		l:SetEndPoint("BOTTOMLEFT", g, x0 + xb, y1 + yb)
		l:Show()
	end
	local px, pd, pt
	for i = 1, n, step do
		local x = (i - 1) / math.max(1, n - 1) * w
		local d, t = dps[i] / maxD * hl, total[i] / maxT * hl
		if px then
			seg(px, pt, x, t, TOTAL_COLOR)
			seg(px, pd, x, d, DPS_COLOR)
		end
		px, pd, pt = x, d, t
	end
	-- the last point
	if px and px < w then
		seg(px, pt, w, hl, TOTAL_COLOR)
		seg(px, pd, w, dps[n] / maxD * hl, DPS_COLOR)
	end

	local function text(i, s, c, point, x, y)
		local t = g.cl[i]
		if not t then
			t = S:Font(g, 9)
			g.cl[i] = t
		end
		t:SetTextColor(c[1], c[2], c[3])
		t:ClearAllPoints()
		t:SetPoint(point, g, "BOTTOMLEFT", x, y)
		t:SetText(s)
		t:Show()
	end
	text(1, ("%s  ·  max %s"):format(L["DPS"], Short(maxD / 1.1)), DPS_COLOR, "BOTTOMLEFT", x0, y1 + hl + 1)
	text(2, ("%s  %s"):format(L["Total"], Short(run)), TOTAL_COLOR, "BOTTOMRIGHT", x0 + w, y1 + hl + 1)
	if stackTop then
		text(3, ("%s  ·  max %s %s"):format(L["Per spell"], Short(stackTop / 1.1), L["DPS"]), S.colors.muted,
			"BOTTOMLEFT", x0, y0 + hs + 1)
	end
	if not g.sep then
		g.sep = g:CreateTexture(nil, "BORDER")
		g.sep:SetColorTexture(1, 1, 1, 0.08)
		g.sep:SetHeight(1)
	end
	g.sep:ClearAllPoints()
	g.sep:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", x0, y1 - 4)
	g.sep:SetWidth(w)
	g.sep:Show()
	return stackTop
end

-- the DPS of one fight over time: measured when the client showed the
-- numbers in combat, else estimated from your casts (History.Timeline)
local function drawCurve(g, f, fights)
	-- stacked per spell when we have it (fights from now on)
	if f.stack then
		clearGraph(g)
		g.title:SetText("")
		local w, h = area(g)
		local top = ST.DrawCombo(g, f, INSET_L, INSET_B, w, h - 4, 6, 4)
		if top then
			local n = #g.grid + 1
			label(g, n, "0:00", INSET_L, INSET_B - 2, "TOPLEFT")
			label(g, n + 1, Clock(f.duration), INSET_L + w, INSET_B - 2, "TOPRIGHT")
			castIcons(g, f, w)
			return
		end
	end
	local curve, estimate = H.Curve(f.samples, 5), false
	if not curve and f.timeline and #f.timeline >= 3 then curve, estimate = smooth(f.timeline, 2), true end
	if not curve or #curve < 3 then return drawCompare(g, f, fights) end
	clearGraph(g)
	g.title:SetText(estimate and L["DPS over the fight (estimate from your casts)"] or L["DPS over the fight"])
	local max = 1
	for _, v in ipairs(curve) do if v and v > max then max = v end end
	max = max * 1.1
	local nextLabel = grid(g, max)
	local w, h = area(g)
	local n = #curve
	local px, py
	local li = 0
	for i, v in ipairs(curve) do
		if v then
			local x, y = (i - 1) / (n - 1) * w, v / max * h
			if px then
				li = li + 1
				line(g, li, px, py, x, y, S.colors.accent)
			end
			px, py = x, y
		else
			px, py = nil, nil
		end
	end
	-- average as a thin dashed-looking line
	local avg = H.DPS(f)
	if avg > 0 then
		li = li + 1
		line(g, li, 0, avg / max * h, w, avg / max * h, { 1, 0.82, 0.25, 0.6 })
		g.lines[li]:SetThickness(1)
	end
	label(g, nextLabel, "0:00", INSET_L, INSET_B - 2, "TOPLEFT")
	label(g, nextLabel + 1, Clock(f.duration), INSET_L + w, INSET_B - 2, "TOPRIGHT")
	castIcons(g, f, w)
end

-- bars: DPS of the last fights, coloured by solo / party / raid
local function drawTrend(g, fights, selected)
	clearGraph(g)
	g.title:SetText(L["DPS of the last fights"])
	local last = {}
	for i = math.max(1, #fights - 29), #fights do last[#last + 1] = fights[i] end
	if #last == 0 then
		g.msg:SetText(L["No fights yet. Fight something and come back."])
		return g.msg:Show()
	end
	local max = 1
	for _, f in ipairs(last) do max = math.max(max, H.DPS(f)) end
	max = max * 1.1
	grid(g, max)
	local w, h = area(g)
	local slot = w / 30
	local sum = 0
	for i, f in ipairs(last) do
		local b = g.bars[i]
		if not b then
			b = CreateFrame("Button", nil, g)
			b.tex = b:CreateTexture(nil, "ARTWORK")
			b.tex:SetAllPoints()
			g.bars[i] = b
		end
		-- the comparison chart shares these bars: set the trend's scripts every time
		b:SetScript("OnEnter", function(self)
			local fi = self.fight
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine(fi.enemy or fi.zone or L["unknown"], 1, 1, 1)
			GameTooltip:AddLine(("%s DPS  ·  %s"):format(Short(H.DPS(fi)), Clock(fi.duration)), 0.8, 0.8, 0.8)
			GameTooltip:AddLine(date("%d/%m %H:%M", fi.started), 0.6, 0.6, 0.6)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		b:SetScript("OnClick", function(self) ST.selected = self.fight ST:Refresh() end)
		local dps = H.DPS(f)
		sum = sum + dps
		b.fight = f
		b:ClearAllPoints()
		b:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", INSET_L + (i - 1) * slot + 1, INSET_B)
		b:SetSize(math.max(2, slot - 2), math.max(1, dps / max * h))
		local c = GROUP_COLORS[f.group] or S.colors.accent
		b.tex:SetColorTexture(c[1], c[2], c[3], f == selected and 1 or 0.65)
		b:Show()
	end
	local avg = sum / #last
	line(g, 1, 0, avg / max * h, w, avg / max * h, { 1, 0.82, 0.25, 0.6 })
	g.lines[1]:SetThickness(1)
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
function ST:Build()
	local f = CreateFrame("Frame", "DamageOfAzerothStats", UIParent, "BackdropTemplate")
	S:Backdrop(f, 0.95)
	f:SetSize(W, HGT)
	local pt = DoA.char.points.stats -- where you left it
	if type(pt) == "table" and pt[1] then f:SetPoint(pt[1], UIParent, pt[3], pt[4], pt[5]) else f:SetPoint("CENTER") end
	f:SetFrameStrata("HIGH")
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
		local l, t = f:GetLeft(), f:GetTop()
		if l and t then DoA.char.points.stats = { "TOPLEFT", "UIParent", "BOTTOMLEFT", math.floor(l + 0.5), math.floor(t + 0.5) } end
	end)
	f:Hide()
	tinsert(UISpecialFrames, "DamageOfAzerothStats") -- Esc closes it
	self.frame = f

	local title = S:Font(f, 13)
	title:SetPoint("TOPLEFT", PAD, -7)
	title:SetText("Damage of Azeroth")
	local sub = S:Font(f, 11)
	sub:SetPoint("LEFT", title, "RIGHT", 6, 0)
	sub:SetTextColor(unpack(S.colors.muted))
	sub:SetText(L["Statistics"])

	local close = CreateFrame("Button", nil, f)
	close:SetSize(20, 20)
	close:SetPoint("TOPRIGHT", -4, -3)
	close.text = S:Font(close, 14)
	close.text:SetPoint("CENTER")
	close.text:SetText("×")
	close.text:SetTextColor(unpack(S.colors.muted))
	close:SetScript("OnClick", function() f:Hide() end)
	close:SetScript("OnEnter", function() close.text:SetTextColor(1, 1, 1) end)
	close:SetScript("OnLeave", function() close.text:SetTextColor(unpack(S.colors.muted)) end)

	-- filters: all / solo / party / raid
	self.filters = {}
	local prev
	for i = #FILTERS, 1, -1 do
		local key = FILTERS[i]
		local b = tab(f, L[FILTER_LABEL[key]], function()
			cfg().filter = key
			ST.selected = nil
			ST:Refresh()
		end)
		if prev then b:SetPoint("RIGHT", prev, "LEFT", 0, 0) else b:SetPoint("TOPRIGHT", close, "TOPLEFT", -6, 0) end
		prev = b
		self.filters[key] = b
	end

	local sep = f:CreateTexture(nil, "ARTWORK")
	sep:SetColorTexture(unpack(S.colors.edge))
	sep:SetHeight(1)
	sep:SetPoint("TOPLEFT", 1, -HEAD)
	sep:SetPoint("TOPRIGHT", -1, -HEAD)

	-- left: tiles + fight list
	self.tiles = {
		count = tile(f, L["Fights"]),
		avg = tile(f, L["Average"] .. " DPS"),
		best = tile(f, L["Best"] .. " DPS"),
	}
	self.tiles.count:SetPoint("TOPLEFT", PAD, -HEAD - PAD)
	self.tiles.avg:SetPoint("LEFT", self.tiles.count, "RIGHT", 4, 0)
	self.tiles.best:SetPoint("LEFT", self.tiles.avg, "RIGHT", 4, 0)

	self.list = {}
	for i = 1, LIST_MAX do
		local r = CreateFrame("Button", nil, f)
		r:SetSize(LEFT_W, LIST_ROW)
		r:SetPoint("TOPLEFT", PAD, -HEAD - PAD - 48 - (i - 1) * LIST_ROW)
		r.hl = r:CreateTexture(nil, "BACKGROUND")
		r.hl:SetAllPoints()
		r.hl:SetColorTexture(1, 1, 1, 0.06)
		r.hl:Hide()
		r.stripe = r:CreateTexture(nil, "ARTWORK")
		r.stripe:SetSize(3, LIST_ROW - 6)
		r.stripe:SetPoint("LEFT", 2, 0)
		r.name = S:Font(r, 11)
		r.name:SetPoint("LEFT", 10, 0)
		r.name:SetPoint("RIGHT", -60, 0)
		r.name:SetJustifyH("LEFT")
		r.name:SetWordWrap(false)
		r.value = S:Font(r, 11)
		r.value:SetPoint("RIGHT", -4, 0)
		r:SetScript("OnClick", function(self) ST.selected = self.fight ST:Refresh() end)
		r:SetScript("OnEnter", function(self) self.hl:Show() end)
		r:SetScript("OnLeave", function(self) if ST.selected ~= self.fight then self.hl:Hide() end end)
		self.list[i] = r
	end
	self.listEmpty = S:Font(f, 11)
	self.listEmpty:SetPoint("TOPLEFT", PAD + 4, -HEAD - PAD - 56)
	self.listEmpty:SetWidth(LEFT_W - 8)
	self.listEmpty:SetJustifyH("LEFT")
	self.listEmpty:SetTextColor(unpack(S.colors.muted))

	-- right: summary, graph, details
	local x = PAD + LEFT_W + PAD
	local rw = W - x - PAD
	self.summary = S:Font(f, 12)
	self.summary:SetPoint("TOPLEFT", x, -HEAD - PAD - 2)
	self.summary:SetWidth(rw - 150)
	self.summary:SetJustifyH("LEFT")
	self.summary:SetWordWrap(false)

	self.viewTabs = {
		fight = tab(f, L["This fight"], function() cfg().view = "fight" ST:Refresh() end),
		compare = tab(f, L["Compare"], function() cfg().view = "compare" ST:Refresh() end),
		trend = tab(f, L["Trend"], function() cfg().view = "trend" ST:Refresh() end),
	}
	self.viewTabs.trend:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -HEAD - PAD + 2)
	self.viewTabs.compare:SetPoint("RIGHT", self.viewTabs.trend, "LEFT", 0, 0)
	self.viewTabs.fight:SetPoint("RIGHT", self.viewTabs.compare, "LEFT", 0, 0)

	self.graph = newGraph(f)
	self.graph:SetPoint("TOPLEFT", x, -HEAD - PAD - 24)
	self.graph:SetSize(rw, GRAPH_H)

	self.detailTabs = {
		spells = tab(f, L["Spells"], function() cfg().detail = "spells" ST:Refresh() end),
		group = tab(f, L["Group"], function() cfg().detail = "group" ST:Refresh() end),
	}
	self.detailTabs.spells:SetPoint("TOPLEFT", self.graph, "BOTTOMLEFT", -4, -6)
	self.detailTabs.group:SetPoint("LEFT", self.detailTabs.spells, "RIGHT", 0, 0)

	self.details = {}
	for i = 1, DETAIL_MAX do
		local r = S:StatusBar(f, S.colors.accent)
		r:SetSize(rw - DETAIL_ROW - 2, DETAIL_ROW)
		r:SetPoint("TOPLEFT", self.graph, "BOTTOMLEFT", DETAIL_ROW + 2, -28 - (i - 1) * (DETAIL_ROW + 2))
		r.icon = r:CreateTexture(nil, "ARTWORK")
		r.icon:SetSize(DETAIL_ROW, DETAIL_ROW)
		r.icon:SetPoint("RIGHT", r, "LEFT", -2, 0)
		r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		r.name = S:Font(r, 11)
		r.name:SetPoint("LEFT", 4, 0)
		r.name:SetPoint("RIGHT", -100, 0)
		r.name:SetJustifyH("LEFT")
		r.name:SetWordWrap(false)
		r.value = S:Font(r, 11)
		r.value:SetPoint("RIGHT", -4, 0)
		self.details[i] = r
	end
	self.detailEmpty = S:Font(f, 11)
	self.detailEmpty:SetPoint("TOPLEFT", self.graph, "BOTTOMLEFT", 0, -32)
	self.detailEmpty:SetTextColor(unpack(S.colors.muted))

	-- resize: more fights, a wider graph, more spells; text keeps its size
	S:AddSizeGrip(f, S:Sizing(f, "stats", { min = { 480, 320 }, max = { 1400, 1000 }, apply = function(w, h)
		ST:Layout(w or W, h or HGT)
		ST:Refresh()
	end }))
	if not S:SavedSize("stats") then self:Layout(W, HGT) end
end

-- sizes and counts for a window of w x h
function ST:Layout(w, h)
	local f = self.frame
	f:SetSize(w, h)
	local x = PAD + LEFT_W + PAD
	local rw = w - x - PAD
	self.summary:SetWidth(rw - 210)
	local top = HEAD + PAD + 24
	local gh = math.max(GRAPH_H - 30, math.floor((h - top - PAD) * 0.45))
	self.graph:SetSize(rw, gh)
	local rest = h - top - gh - 28 - PAD
	self.detailMax = math.max(1, math.min(DETAIL_MAX, math.floor(rest / (DETAIL_ROW + 2))))
	for _, r in ipairs(self.details) do r:SetWidth(rw - DETAIL_ROW - 2) end
	self.listMax = math.max(3, math.min(LIST_MAX, math.floor((h - HEAD - PAD - 48 - PAD) / LIST_ROW)))
end

local function spellInfo(id)
	local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or (GetSpellInfo and GetSpellInfo(id))
	local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id) or (GetSpellTexture and GetSpellTexture(id))
	return name or ("#" .. id), icon
end

local function fightName(f)
	return f.enemy or f.zone or L["unknown"]
end

function ST:RefreshDetails(f)
	local mode = cfg().detail
	for k, b in pairs(self.detailTabs) do b:SetActive(k == mode) end
	local rows = {}
	if f and mode == "spells" then
		local total = f.myDamage or 0
		for _, sp in ipairs(f.spells or {}) do
			local name, icon = spellInfo(sp.id)
			rows[#rows + 1] = { name = name, icon = icon, value = sp.total, share = total > 0 and sp.total / total or 0,
				color = S.colors.accent }
		end
	elseif f then
		local total = 0
		for _, r in ipairs(f.damage or {}) do total = total + r.total end
		for _, r in ipairs(f.damage or {}) do
			local cr, cg, cb = DoA.Meter.ClassColor(r.class)
			rows[#rows + 1] = { name = r.me and (r.name .. " (" .. L["You"] .. ")") or r.name, value = r.total,
				share = total > 0 and r.total / total or 0, color = { cr, cg, cb } }
		end
	end
	local top = rows[1] and rows[1].value or 1
	for i, r in ipairs(self.details) do
		local d = i <= (self.detailMax or 6) and rows[i]
		if d then
			r:SetMinMaxValues(0, top)
			r:SetValue(d.value)
			r:SetStatusBarColor(d.color[1], d.color[2], d.color[3], 0.75)
			r.name:SetText(d.name)
			r.value:SetText(("%s  %d%%"):format(Short(d.value), math.floor(d.share * 100 + 0.5)))
			r.icon:SetTexture(d.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
			r.icon:SetShown(mode == "spells")
			r:Show()
		else
			r:Hide()
		end
	end
	self.detailEmpty:SetShown(#rows == 0)
	self.detailEmpty:SetText(f and "" or L["Click a fight for details."])
end

function ST:Refresh()
	local f = self.frame
	if not (f and f:IsShown()) then return end
	local c = cfg()
	for k, b in pairs(self.filters) do b:SetActive(k == c.filter) end
	for k, b in pairs(self.viewTabs) do b:SetActive(k == c.view) end

	local fights = H:List(c.filter)
	-- tiles
	local sum, best = 0, 0
	for _, fi in ipairs(fights) do
		local d = H.DPS(fi)
		sum = sum + d
		if d > best then best = d end
	end
	self.tiles.count.value:SetText(#fights)
	self.tiles.avg.value:SetText(#fights > 0 and Short(sum / #fights) or "-")
	self.tiles.best.value:SetText(#fights > 0 and Short(best) or "-")

	-- list: newest first
	if not self.selected or not tContains(fights, self.selected) then self.selected = fights[#fights] end
	for i, r in ipairs(self.list) do
		local fi = i <= (self.listMax or 11) and fights[#fights - i + 1]
		if fi then
			r.fight = fi
			r.name:SetText(fightName(fi))
			local dps = H.DPS(fi)
			r.value:SetText(dps > 0 and (Short(dps) .. " DPS") or (Short(H.HPS(fi)) .. " HPS"))
			local gc = GROUP_COLORS[fi.group] or S.colors.accent
			r.stripe:SetColorTexture(gc[1], gc[2], gc[3], 1)
			r.hl:SetShown(fi == self.selected)
			r:Show()
		else
			r:Hide()
		end
	end
	self.listEmpty:SetShown(#fights == 0)
	self.listEmpty:SetText(L["No fights yet. Fight something and come back."])

	-- summary of the selected fight
	local sel = self.selected
	if sel then
		local rank, of = nil, #(sel.damage or {})
		for i, r in ipairs(sel.damage or {}) do if r.me then rank = i end end
		local parts = { fightName(sel), Clock(sel.duration), Short(H.DPS(sel)) .. " DPS", Short(sel.myDamage or 0) }
		if (sel.myHealing or 0) > 0 then parts[#parts + 1] = Short(sel.myHealing) .. " " .. L["Healing"] end
		if rank and of > 1 then parts[#parts + 1] = L["Rank"] .. " " .. L["%d of %d"]:format(rank, of) end
		self.summary:SetText(table.concat(parts, "  ·  "))
	else
		self.summary:SetText("")
	end

	if c.view == "trend" then drawTrend(self.graph, fights, sel)
	elseif sel and c.view == "compare" then drawCompare(self.graph, sel, fights)
	elseif sel then drawCurve(self.graph, sel, fights)
	else drawTrend(self.graph, fights, sel) end
	self:RefreshDetails(sel)
end

function ST:Toggle()
	if not self.frame then self:Build() end
	if self.frame:IsShown() then return self.frame:Hide() end
	self.frame:Show()
	self:Refresh()
end

function ST:OnEnable()
	DoA:Listen("FIGHT", function() pcall(ST.Refresh, ST) end)
end
