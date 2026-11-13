local AUI = select(2, ...)

local Options = AUI.CharacterOptions

---Additions to Blizzard's character panel (Forever).
---@class AUICharacter
---@field active boolean started
local Character = {
	active = false,
}
AUI.Character = Character

---@return boolean
function Character:IsOn()
	return AUI.can.characterPanel == true and AUI.Profile:Get(Options.ENABLED_PATH) == true
end

function Character:Start()
	if self.active then
		return
	end

	self.active = true
end
