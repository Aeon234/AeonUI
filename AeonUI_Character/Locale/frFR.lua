if GetLocale() ~= "frFR" then
	return
end

local L = select(2, ...).L

-- Slots (Character)
L["Enchanted"] = "Enchanté"
L["No Enchant"] = "Aucun enchantement"

-- Stats rows (Character)
L["Repair"] = "Réparation"

-- Item level (Character)
L["Equipped items average %.1f (%d of %d slots)"] = "Moyenne des objets équipés : %.1f (%d emplacements sur %d)"

-- Character page (Settings)
L["Equipment"] = "Équipement"
L["Show Character Model"] = "Afficher le modèle du personnage"
L["Quality Border"] = "Bordure de qualité"
L["Durability Gauges"] = "Jauges de durabilité"
L["Stats"] = "Caractéristiques"
L["Average Item Level"] = "Niveau d'objet moyen"
L["Gear Summary"] = "Résumé de l'équipement"
L["Extra Stats"] = "Caractéristiques supplémentaires"
L["Highlight Main Stat"] = "Mettre en évidence la caractéristique principale"
