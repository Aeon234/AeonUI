if GetLocale() ~= "koKR" then
	return
end

local L = select(2, ...).L

-- Slots (Character)
L["Enchanted"] = "마법부여됨"
L["No Enchant"] = "마법부여 없음"

-- Stats rows (Character)
L["Repair"] = "수리"

-- Item level (Character)
L["Equipped items average %.1f (%d of %d slots)"] = "착용 아이템 평균 %.1f (%d/%d 칸)"

-- Character page (Settings)
L["Equipment"] = "장비"
L["Show Character Model"] = "캐릭터 모델 표시"
L["Quality Border"] = "품질 테두리"
L["Durability Gauges"] = "내구도 게이지"
L["Stats"] = "능력치"
L["Average Item Level"] = "평균 아이템 레벨"
L["Gear Summary"] = "장비 요약"
L["Extra Stats"] = "추가 능력치"
L["Highlight Main Stat"] = "주 능력치 강조"
