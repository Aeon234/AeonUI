if GetLocale() ~= "zhTW" then
	return
end

local L = select(2, ...).L

-- Slots (Character)
L["Enchanted"] = "已附魔"
L["No Enchant"] = "未附魔"

-- Stats rows (Character)
L["Repair"] = "修理"

-- Item level (Character)
L["Equipped items average %.1f (%d of %d slots)"] = "已裝備物品平均 %.1f（%d/%d 個欄位）"

-- Character page (Settings)
L["Equipment"] = "裝備"
L["Show Character Model"] = "顯示角色模型"
L["Quality Border"] = "品質邊框"
L["Durability Gauges"] = "耐久度指示條"
L["Stats"] = "屬性"
L["Average Item Level"] = "平均物品等級"
L["Gear Summary"] = "裝備概要"
L["Extra Stats"] = "額外屬性"
L["Highlight Main Stat"] = "突顯主屬性"
