-- Damage of Azeroth by DinX: translations. Code uses English strings as keys: L["Text"].
local _, ns = ...
local DoA = ns.DoA

local NL = {}
DoA.translations = { nlNL = NL }

-- Looked up at use time, so the saved language (loaded later) applies.
DoA.L = setmetatable({}, {
	__index = function(_, key)
		local lang = DoA.db and DoA.db.language or "auto"
		if lang == "auto" then -- follow Casters of Azeroth, else the client
			local c = DoA.Casters and DoA:Casters()
			lang = (c and c.db and c.db.language ~= "auto" and c.db.language) or (GetLocale() == "nlNL" and "nlNL") or "enUS"
		end
		if key == "decimal" then return lang == "nlNL" and "," or "." end
		local t = DoA.translations[lang]
		return t and t[key] or key
	end,
})

for k, v in pairs({
	-- meter
	["Damage"] = "Schade",
	["DPS"] = "DPS",
	["Healing"] = "Healing",
	["HPS"] = "HPS",
	["Current"] = "Nu",
	["Overall"] = "Totaal",
	["Reset"] = "Wissen",
	["Damage meter"] = "Damage meter",
	["No fight yet."] = "Nog geen gevecht.",
	["Not available in this client."] = "Niet beschikbaar in deze client.",
	["Click: next view (damage, DPS, healing, HPS). Right-click: previous."] = "Klik: volgende weergave (schade, DPS, healing, HPS). Rechtsklik: vorige.",
	["Click: this fight or all fights."] = "Klik: dit gevecht of alle gevechten.",
	["Clear all fights."] = "Alle gevechten wissen.",
	["Statistics"] = "Statistieken",
	["Open the statistics (/doa)."] = "Open de statistieken (/doa).",
	-- stats
	["All"] = "Alles",
	["Solo"] = "Solo",
	["Party"] = "Groep",
	["Raid"] = "Raid",
	["This fight"] = "Dit gevecht",
	["Trend"] = "Verloop",
	["Spells"] = "Spells",
	["Group"] = "Groep",
	["Fights"] = "Gevechten",
	["No fights yet. Fight something and come back."] = "Nog geen gevechten. Vecht iets en kom terug.",
	["DPS over the fight"] = "DPS tijdens het gevecht",
	["DPS of the last fights"] = "DPS van de laatste gevechten",
	["No curve for this fight: the numbers were hidden during combat."] = "Geen curve voor dit gevecht: de cijfers waren verborgen tijdens het gevecht.",
	["Total"] = "Totaal",
	["Time"] = "Tijd",
	["Best"] = "Beste",
	["Average"] = "Gemiddeld",
	["Rank"] = "Plaats",
	["%d of %d"] = "%d van %d",
	["unknown"] = "onbekend",
	["You"] = "Jij",
	["Click a fight for details."] = "Klik op een gevecht voor details.",
	["Delete fights"] = "Gevechten wissen",
	["Delete all saved fights of this character?"] = "Alle bewaarde gevechten van dit karakter wissen?",
	["Your share"] = "Jouw deel",
	["This fight compared"] = "Dit gevecht vergeleken",
	["Usual vs %s"] = "Meestal tegen %s",
	["Usual solo"] = "Meestal solo",
	["Usual party"] = "Meestal in groep",
	["Usual raid"] = "Meestal in raid",
	["Drag: make it bigger so more fits. Double-click: default size."] = "Slepen: groter maken zodat er meer in past. Dubbelklik: standaardgrootte.",
	-- probe / slash
	["/doa: statistics. /doa meter: meter on/off. /doa unlock: move the frames. /doa check: what this client allows."] = "/doa: statistieken. /doa meter: meter aan/uit. /doa unlock: frames verplaatsen. /doa check: wat deze client toelaat.",
}) do NL[k] = v end
