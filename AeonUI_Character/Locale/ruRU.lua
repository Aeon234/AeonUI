if GetLocale() ~= "ruRU" then
	return
end

local L = select(2, ...).L

-- Slots (Character)
L["Enchanted"] = "Зачаровано"
L["No Enchant"] = "Нет чар"

-- Item level (Character)
L["Equipped items average %.1f (%d of %d slots)"] = "Средний уровень надетых предметов: %.1f (%d из %d ячеек)"
