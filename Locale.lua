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
	["Click: damage or healing. Right-click: next view (total, per second, absorbs, dispels)."] = "Klik: schade of healing. Rechtsklik: volgende weergave (totaal, per seconde, absorbs, dispels).",
	["Absorbs"] = "Absorbs",
	["Dispels"] = "Dispels",
	["Click: this fight or all fights."] = "Klik: dit gevecht of alle gevechten.",
	["Clear all fights."] = "Alle gevechten wissen.",
	["Clear all fights in the meter?"] = "Alle gevechten in de meter wissen?",
	["Frames locked."] = "Kaders vergrendeld.",
	["Frames unlocked: drag them where you like, drag a corner to make them bigger, type /doa lock when done."] = "Kaders ontgrendeld: sleep ze waar je wil, sleep een hoek om ze groter te maken, typ /doa lock als je klaar bent.",
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
	["HPS of the last fights"] = "HPS van de laatste gevechten",
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
	["Compare"] = "Vergelijking",
	["Graph"] = "Grafiek",
	["Other"] = "Overig",
	["No healing in this fight."] = "Geen healing in dit gevecht.",
	["No healing timeline for this fight."] = "Geen healing-tijdlijn voor dit gevecht.",
	["Per spell"] = "Per spell",
	["List"] = "Lijst",
	["Click: live graph or the list."] = "Klik: live grafiek of de lijst.",
	["Your damage, live"] = "Jouw schade, live",
	["Last fight, per spell"] = "Laatste gevecht, per spell",
	["now"] = "nu",
	["Total so far, one column per second"] = "Totaal tot nu, één staafje per seconde",
	["Total so far (numbers hidden in combat: the line after the fight)"] = "Totaal tot nu (cijfers verborgen in gevecht: de lijn na het gevecht)",
	["Your healing, live"] = "Jouw healing, live",
	["The graph fills during your next fight."] = "De grafiek vult zich tijdens je volgende gevecht.",
	["DPS over the fight (estimate from your casts)"] = "DPS tijdens het gevecht (schatting uit je casts)",
	["Usual vs %s"] = "Meestal tegen %s",
	["Usual solo"] = "Meestal solo",
	["Usual party"] = "Meestal in groep",
	["Usual raid"] = "Meestal in raid",
	["Drag: make it bigger so more fits. Double-click: default size."] = "Slepen: groter maken zodat er meer in past. Dubbelklik: standaardgrootte.",
	-- probe / slash
	["/doa: statistics. /doa config: settings. /doa meter: meter on/off. /doa switch: damage or healing. /doa unlock: move the frames. /doa check: what this client allows."] = "/doa: statistieken. /doa config: instellingen. /doa meter: meter aan/uit. /doa switch: schade of healing. /doa unlock: frames verplaatsen. /doa check: wat deze client toelaat.",
	["/doa opens the statistics. Unlock the frames to move the meter and drag its corner to make it bigger."] = "/doa opent de statistieken. Ontgrendel de kaders om de meter te verplaatsen, en sleep zijn hoek om hem groter te maken.",
	["Meter on"] = "Meter aan",
	["Meter"] = "Meter",
	["Live graph instead of the list"] = "Live grafiek in plaats van de lijst",
	["Also with the Graph / List button on the meter."] = "Ook met de knop Grafiek / Lijst op de meter.",
	["Hide the meter until the first fight"] = "Meter verbergen tot het eerste gevecht",
	["Language"] = "Taal",
	["Automatic"] = "Automatisch",
	["Saved fights deleted."] = "Bewaarde gevechten gewist.",
}) do NL[k] = v end
