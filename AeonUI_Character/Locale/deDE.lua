if GetLocale() ~= "deDE" then
	return
end

local L = select(2, ...).L

-- Slots (Character)
L["Enchanted"] = "Verzaubert"
L["No Enchant"] = "Keine Verzauberung"

-- Stats rows (Character)
L["Repair"] = "Reparatur"

-- Item level (Character)
L["Equipped items average %.1f (%d of %d slots)"] = "Angelegte Gegenstände im Schnitt %.1f (%d von %d Plätzen)"

-- Character page (Settings)
L["Equipment"] = "Ausrüstung"
L["Show Character Model"] = "Charaktermodell anzeigen"
L["Quality Border"] = "Qualitätsrahmen"
L["Durability Gauges"] = "Haltbarkeitsanzeigen"
L["Stats"] = "Werte"
L["Average Item Level"] = "Durchschnittliche Gegenstandsstufe"
L["Gear Summary"] = "Ausrüstungsübersicht"
L["Extra Stats"] = "Zusätzliche Werte"
L["Highlight Main Stat"] = "Hauptattribut hervorheben"
