if GetLocale() ~= "zhCN" then
	return
end

local L = select(2, ...).L

-- Slots (Character)
L["Enchanted"] = "已附魔"
L["No Enchant"] = "未附魔"

-- Stats rows (Character)
L["Repair"] = "修理"

-- Item level (Character)
L["Equipped items average %.1f (%d of %d slots)"] = "已装备物品平均 %.1f（%d/%d 个栏位）"

-- Character page (Settings)
L["Equipment"] = "装备"
L["Show Character Model"] = "显示角色模型"
L["Quality Border"] = "品质边框"
L["Durability Gauges"] = "耐久度指示条"
L["Stats"] = "属性"
L["Average Item Level"] = "平均物品等级"
L["Gear Summary"] = "装备概要"
L["Extra Stats"] = "额外属性"
L["Highlight Main Stat"] = "突出主属性"
