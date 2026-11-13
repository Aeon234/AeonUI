if GetLocale() ~= "deDE" then
	return
end

local L = select(2, ...).L

-- Slots (Character)
L["Enchanted"] = "Verzaubert"
L["No Enchant"] = "Keine Verzauberung"

-- Item level (Character)
L["Equipped items average %.1f (%d of %d slots)"] = "Angelegte Gegenstände im Schnitt %.1f (%d von %d Plätzen)"
