local AUI = select(2, ...)

---@class AUILocale : table<string, string>
local L = setmetatable({}, { __index = AUI.L })
AUI.L = L

-- Slots (Character)
L["Enchanted"] = "Enchanted"
L["No Enchant"] = "No Enchant"

-- Stats rows (Character)
L["Repair"] = "Repair"

-- Item level (Character)
L["Equipped items average %.1f (%d of %d slots)"] = "Equipped items average %.1f (%d of %d slots)"

-- Character page (Settings)
L["Equipment"] = "Equipment"
L["Show Character Model"] = "Show Character Model"
L["Quality Border"] = "Quality Border"
L["Durability Gauges"] = "Durability Gauges"
L["Stats"] = "Stats"
L["Average Item Level"] = "Average Item Level"
L["Gear Summary"] = "Gear Summary"
L["Extra Stats"] = "Extra Stats"
L["Highlight Main Stat"] = "Highlight Main Stat"
