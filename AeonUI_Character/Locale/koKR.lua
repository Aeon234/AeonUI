if GetLocale() ~= "koKR" then
	return
end

local L = select(2, ...).L

-- Slots (Character)
L["Enchanted"] = "마법부여됨"
L["No Enchant"] = "마법부여 없음"

-- Item level (Character)
L["Equipped items average %.1f (%d of %d slots)"] = "착용 아이템 평균 %.1f (%d/%d 칸)"
