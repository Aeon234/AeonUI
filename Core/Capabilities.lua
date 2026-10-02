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
---@field retailSpells boolean the client has the current classes' spells, so the current buff category lists apply
AUI.can = {}

---The only place a client difference is detected. Runs once at login.
---@return AUICapabilityFlags
function Capabilities:Resolve()
	local can = AUI.can

	can.surnames = Constants ~= nil and Constants.CharacterNameSeparatorConsts ~= nil
	can.abbreviationConfig = CreateAbbreviateConfig ~= nil
		and C_StringUtil ~= nil
		and C_StringUtil.GetDefaultAbbreviationBreakpoints ~= nil

	-- Death Strike exists only where the current class roster does.
	can.retailSpells = C_Spell ~= nil and C_Spell.GetSpellInfo ~= nil and C_Spell.GetSpellInfo(49998) ~= nil

	self.resolved = true

	return can
end
