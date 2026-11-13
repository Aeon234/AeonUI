if GetLocale() ~= "ptBR" then
	return
end

local L = select(2, ...).L

-- Slots (Character)
L["Enchanted"] = "Encantado"
L["No Enchant"] = "Sem encantamento"

-- Item level (Character)
L["Equipped items average %.1f (%d of %d slots)"] = "Média dos itens equipados: %.1f (%d de %d espaços)"
