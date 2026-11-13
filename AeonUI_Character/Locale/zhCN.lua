if GetLocale() ~= "zhCN" then
	return
end

local L = select(2, ...).L

-- Slots (Character)
L["Enchanted"] = "已附魔"
L["No Enchant"] = "未附魔"

-- Item level (Character)
L["Equipped items average %.1f (%d of %d slots)"] = "已装备物品平均 %.1f（%d/%d 个栏位）"
