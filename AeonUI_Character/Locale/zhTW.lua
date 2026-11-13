if GetLocale() ~= "zhTW" then
	return
end

local L = select(2, ...).L

-- Slots (Character)
L["Enchanted"] = "已附魔"
L["No Enchant"] = "未附魔"

-- Item level (Character)
L["Equipped items average %.1f (%d of %d slots)"] = "已裝備物品平均 %.1f（%d/%d 個欄位）"
