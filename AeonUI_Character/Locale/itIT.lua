if GetLocale() ~= "itIT" then
	return
end

local L = select(2, ...).L

-- Slots (Character)
L["Enchanted"] = "Incantato"
L["No Enchant"] = "Nessun incantamento"

-- Item level (Character)
L["Equipped items average %.1f (%d of %d slots)"] = "Media degli oggetti equipaggiati: %.1f (%d di %d spazi)"
