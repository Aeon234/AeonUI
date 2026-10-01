local AUI = select(2, ...)

---@param _ table
---@param key string
---@return string
local function FallBackToKey(_, key)
	return key
end

---@class AUILocale : table<string, string>
local L = setmetatable({}, { __index = FallBackToKey })
AUI.L = L

-- Chat messages (Core)
L["the settings window is not available yet."] = "the settings window is not available yet."
