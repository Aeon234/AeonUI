local AUI = select(2, ...)

local Options = AUI.CharacterOptions

---Additions to Blizzard's character panel (Forever).
---@class AUICharacter
---@field active boolean started
local Character = {
	active = false,
}
AUI.Character = Character

---On where the client has the panel and the feature is on, and stood down under the Gamepad style, whose secure
---navigation the hooks would taint.
---@return boolean
function Character:IsOn()
	return AUI.can.characterPanel == true and AUI.Profile:Get(Options.ENABLED_PATH) == true
		and not InputUtil.IsGamepadUIEnabled()
end

function Character:Apply()
	if AUI.can.characterPanel ~= true then
		return
	end

	AUI.CharacterFrame:Apply()
	AUI.CharacterStats:Apply()
end

---@param path string? the changed setting; nil when the whole profile changed
function Character:OnProfileChanged(path)
	if path == nil or path:sub(1, 10) == "character." then
		AUI.Events:Coalesce("characterApply", function()
			Character:Apply()
		end)
	end
end

function Character:Start()
	if self.active then
		return
	end

	self.active = true
	AUI.Callbacks:Register("Profile", self, self.OnProfileChanged)
	self:Apply()
end
