if GetLocale() ~= "esES" then
	return
end

local L = select(2, ...).L

-- Slots (Character)
L["Enchanted"] = "Encantado"
L["No Enchant"] = "Sin encantamiento"

-- Item level (Character)
L["Equipped items average %.1f (%d of %d slots)"] = "Media de los objetos equipados: %.1f (%d de %d huecos)"
