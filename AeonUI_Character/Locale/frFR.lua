if GetLocale() ~= "frFR" then
	return
end

local L = select(2, ...).L

-- Slots (Character)
L["Enchanted"] = "Enchanté"
L["No Enchant"] = "Aucun enchantement"

-- Item level (Character)
L["Equipped items average %.1f (%d of %d slots)"] = "Moyenne des objets équipés : %.1f (%d emplacements sur %d)"
