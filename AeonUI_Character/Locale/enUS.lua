local AUI = select(2, ...)

---@class AUILocale : table<string, string>
local L = setmetatable({}, { __index = AUI.L })
AUI.L = L
