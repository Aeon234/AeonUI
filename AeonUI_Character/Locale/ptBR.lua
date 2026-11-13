if GetLocale() ~= "ptBR" then
	return
end

local L = select(2, ...).L

-- Slots (Character)
L["Enchanted"] = "Encantado"
L["No Enchant"] = "Sem encantamento"

-- Stats rows (Character)
L["Repair"] = "Reparo"

-- Item level (Character)
L["Equipped items average %.1f (%d of %d slots)"] = "Média dos itens equipados: %.1f (%d de %d espaços)"

-- Character page (Settings)
L["Equipment"] = "Equipamento"
L["Show Character Model"] = "Mostrar modelo do personagem"
L["Quality Border"] = "Borda de qualidade"
L["Durability Gauges"] = "Medidores de durabilidade"
L["Stats"] = "Atributos"
L["Average Item Level"] = "Nível médio de item"
L["Gear Summary"] = "Resumo do equipamento"
L["Extra Stats"] = "Atributos extras"
L["Highlight Main Stat"] = "Destacar atributo principal"
