-- Damage of Azeroth by DinX: settings. One page, built with the same calls
-- (Header, Note, Check, Choice, Button) inside the Casters of Azeroth window
-- when that is loaded, else in Blizzard's own settings (AddOns tab).
local _, ns = ...
local DoA = ns.DoA
local L = DoA.L
local S = DoA.Style

local C = DoA:NewModule("Config")

local function meter(key)
	return function() return DoA.char.meter[key] end, function(v)
		DoA.char.meter[key] = v
		DoA:Fire("SETTINGS", "meter")
	end
end

local function confirm(key, text, onYes)
	StaticPopupDialogs[key] = StaticPopupDialogs[key] or { button1 = YES, button2 = NO, timeout = 0,
		whileDead = true, hideOnEscape = true, preferredIndex = 3 }
	StaticPopupDialogs[key].text = text
	StaticPopupDialogs[key].OnAccept = onYes
	StaticPopup_Show(key)
end

-- the page itself: p offers Header, Note, Check, Choice, Button, Gap
function C.Build(p)
	p:Header("Damage of Azeroth")
	p:Note(L["/doa opens the statistics. Unlock the frames to move the meter and drag its corner to make it bigger."])
	p:Check(L["Meter on"], nil, meter("enabled"))
	p:Check(L["Live graph instead of the list"], L["Also with the Graph / List button on the meter."], meter("graph"))
	p:Check(L["Hide the meter until the first fight"], nil, meter("hideEmpty"))
	p:Gap()
	p:Choice(L["Language"], { { "auto", L["Automatic"] }, { "enUS", "English" }, { "nlNL", "Nederlands" } },
		function() return DoA.db.language end,
		function(v) DoA.db.language = v DoA:Fire("SETTINGS", "meter") end)
	p:Gap()
	p:Button(L["Delete saved fights"], function()
		confirm("DAMAGEOFAZEROTH_DELETE", L["Delete all saved fights of this character?"], function()
			wipe(DoA.char.fights)
			DoA:Fire("FIGHT")
			DoA:Print(L["Saved fights deleted."])
		end)
	end, 180)
end

---------------------------------------------------------------------------
-- Standalone: a small page with the same calls, in Blizzard's settings
---------------------------------------------------------------------------
local Page = {}
Page.__index = Page

function Page:Header(text)
	local t = S:Font(self.frame, 14)
	t:SetPoint("TOPLEFT", 16, self.y)
	t:SetText(text)
	t:SetTextColor(unpack(S.colors.accent))
	self.y = self.y - 26
end

function Page:Note(text)
	local t = S:Font(self.frame, 11)
	t:SetPoint("TOPLEFT", 16, self.y)
	t:SetWidth(520)
	t:SetJustifyH("LEFT")
	t:SetTextColor(unpack(S.colors.muted))
	t:SetText(text)
	self.y = self.y - math.max(18, t:GetStringHeight() + 8)
end

function Page:Gap(h) self.y = self.y - (h or 8) end

function Page:Check(label, tip, get, set)
	local b = CreateFrame("CheckButton", nil, self.frame, "UICheckButtonTemplate")
	b:SetPoint("TOPLEFT", 12, self.y)
	b:SetChecked(get() and true or false)
	b:SetScript("OnClick", function(btn) set(btn:GetChecked() and true or false) end)
	local t = S:Font(self.frame, 12)
	t:SetPoint("LEFT", b, "RIGHT", 4, 0)
	t:SetText(label)
	if tip then
		b:SetScript("OnEnter", function(btn)
			GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
			GameTooltip:SetText(tip, 1, 1, 1, 1, true)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end
	self.y = self.y - 28
end

-- a button that steps through the options
function Page:Choice(label, opts, get, set)
	local t = S:Font(self.frame, 12)
	t:SetPoint("TOPLEFT", 16, self.y - 4)
	t:SetText(label)
	local b
	local function paint()
		local cur = get()
		for _, o in ipairs(opts) do if o[1] == cur then b.text:SetText(o[2] .. "  >") end end
	end
	b = self:Button("", function()
		local cur, i = get(), 1
		for k, o in ipairs(opts) do if o[1] == cur then i = k end end
		set(opts[i % #opts + 1][1])
		paint()
	end, 160, 180)
	paint()
end

function Page:Button(label, onClick, width, x)
	local b = CreateFrame("Button", nil, self.frame, "BackdropTemplate")
	b:SetSize(width or 160, 22)
	b:SetPoint("TOPLEFT", x or 16, self.y)
	S:Backdrop(b, 1)
	b.text = S:Font(b, 12)
	b.text:SetPoint("CENTER")
	b.text:SetText(label)
	b:SetScript("OnEnter", function() b:SetBackdropBorderColor(unpack(S.colors.accent)) end)
	b:SetScript("OnLeave", function() b:SetBackdropBorderColor(0, 0, 0, 1) end)
	b:SetScript("OnClick", onClick)
	self.y = self.y - 30
	return b
end

local category
local function standalone()
	if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
	local panel = CreateFrame("Frame")
	panel:Hide()
	local page = setmetatable({ frame = panel, y = -16 }, Page)
	C.Build(page)
	category = Settings.RegisterCanvasLayoutCategory(panel, "Damage of Azeroth")
	Settings.RegisterAddOnCategory(category)
end

function DoA:ToggleConfig()
	local c = DoA:Casters()
	if c and c.ToggleConfig and type(c.Config) == "table" and c.Config.Show then
		pcall(c.ToggleConfig, c, true)
		if c.Config.pages and c.Config.pages.doa then pcall(c.Config.Show, c.Config, "doa") end
		return
	end
	if category and Settings.OpenToCategory then Settings.OpenToCategory(category:GetID()) end
end

function C:OnInit()
	local c = DoA:Casters()
	if c then
		c.configPages = type(c.configPages) == "table" and c.configPages or {}
		for _, d in ipairs(c.configPages) do if d.key == "doa" then return end end
		table.insert(c.configPages, { key = "doa", label = L["Meter"], group = "Damage of Azeroth", build = C.Build })
	else
		standalone()
	end
end
