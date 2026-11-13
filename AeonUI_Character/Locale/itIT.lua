if GetLocale() ~= "itIT" then
	return
end

local L = select(2, ...).L

-- Slots (Character)
L["Enchanted"] = "Incantato"
L["No Enchant"] = "Nessun incantamento"

-- Stats rows (Character)
L["Repair"] = "Riparazione"

-- Item level (Character)
L["Equipped items average %.1f (%d of %d slots)"] = "Media degli oggetti equipaggiati: %.1f (%d di %d spazi)"

-- Character page (Settings)
L["Equipment"] = "Equipaggiamento"
L["Show Character Model"] = "Mostra modello del personaggio"
L["Quality Border"] = "Bordo di qualità"
L["Durability Gauges"] = "Indicatori di integrità"
L["Stats"] = "Statistiche"
L["Average Item Level"] = "Livello oggetto medio"
L["Gear Summary"] = "Riepilogo equipaggiamento"
L["Extra Stats"] = "Statistiche aggiuntive"
L["Highlight Main Stat"] = "Evidenzia statistica principale"
