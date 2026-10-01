-- Library strings. Keys are the English text; a missing translation falls back to the key.
local _, ns = ...
local AS = ns.AeonSettings

local L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
AS.L = L

-- Each client language has its own file in Locale/, loaded right after this one.
