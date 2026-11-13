if GetLocale() ~= "esMX" then
	return
end

local L = select(2, ...).L

-- Slots (Character)
L["Enchanted"] = "Encantado"
L["No Enchant"] = "Sin encantamiento"

-- Stats rows (Character)
L["Repair"] = "Reparación"

-- Item level (Character)
L["Equipped items average %.1f (%d of %d slots)"] = "Promedio de los objetos equipados: %.1f (%d de %d ranuras)"

-- Character page (Settings)
L["Equipment"] = "Equipo"
L["Show Character Model"] = "Mostrar modelo del personaje"
L["Quality Border"] = "Borde de calidad"
L["Durability Gauges"] = "Indicadores de durabilidad"
L["Stats"] = "Estadísticas"
L["Average Item Level"] = "Nivel de objeto promedio"
L["Gear Summary"] = "Resumen del equipo"
L["Extra Stats"] = "Estadísticas adicionales"
L["Highlight Main Stat"] = "Resaltar atributo principal"
