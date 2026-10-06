local AUI = select(2, ...)

---@class AUICapabilities
---@field resolved boolean
local Capabilities = {
	resolved = false,
}
AUI.Capabilities = Capabilities

---@class AUICapabilityFlags
---@field surnames boolean player names carry a surname, which `UnitName` returns second
---@field abbreviationConfig boolean number abbreviation can take custom breakpoints
---@field retailSpells boolean the client is Retail, whose classes' spells the current buff category lists hold
AUI.can = {}

---The only place a client difference is detected. Runs once at login.
---@return AUICapabilityFlags
function Capabilities:Resolve()
	local can = AUI.can

	can.surnames = Constants ~= nil and Constants.CharacterNameSeparatorConsts ~= nil
	can.abbreviationConfig = CreateAbbreviateConfig ~= nil
		and C_StringUtil ~= nil
		and C_StringUtil.GetDefaultAbbreviationBreakpoints ~= nil

	can.retailSpells = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE

	self.resolved = true

	return can
end
