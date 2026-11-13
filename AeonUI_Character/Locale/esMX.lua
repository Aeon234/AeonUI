if GetLocale() ~= "esMX" then
	return
end

local L = select(2, ...).L

-- Slots (Character)
L["Enchanted"] = "Encantado"
L["No Enchant"] = "Sin encantamiento"

-- Item level (Character)
L["Equipped items average %.1f (%d of %d slots)"] = "Promedio de los objetos equipados: %.1f (%d de %d ranuras)"
