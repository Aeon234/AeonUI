if GetLocale() ~= "ruRU" then
	return
end

local L = select(2, ...).L

-- Slots (Character)
L["Enchanted"] = "Зачаровано"
L["No Enchant"] = "Нет чар"

-- Stats rows (Character)
L["Repair"] = "Ремонт"

-- Item level (Character)
L["Equipped items average %.1f (%d of %d slots)"] = "Средний уровень надетых предметов: %.1f (%d из %d ячеек)"

-- Character page (Settings)
L["Equipment"] = "Экипировка"
L["Show Character Model"] = "Показывать модель персонажа"
L["Quality Border"] = "Рамка качества"
L["Durability Gauges"] = "Шкалы прочности"
L["Stats"] = "Характеристики"
L["Average Item Level"] = "Средний уровень предметов"
L["Gear Summary"] = "Сводка экипировки"
L["Extra Stats"] = "Дополнительные характеристики"
L["Highlight Main Stat"] = "Выделять основную характеристику"
