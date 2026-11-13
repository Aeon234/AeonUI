local AUI = select(2, ...)

---@class AUILocale : table<string, string>
local L = setmetatable({}, { __index = AUI.L })
AUI.L = L

-- Slots (Character)
L["Enchanted"] = "Enchanted"
L["No Enchant"] = "No Enchant"

-- Item level (Character)
L["Equipped items average %.1f (%d of %d slots)"] = "Equipped items average %.1f (%d of %d slots)"
