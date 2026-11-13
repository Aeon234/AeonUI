local AUI = select(2, ...)

local L = AUI.L

---The Character page, under the Quality of Life header, on Forever: the module's switch.
---@class AUISettingsCharacter
local SettingsCharacter = {}
AUI.SettingsCharacter = SettingsCharacter

---@return boolean
function SettingsCharacter:IsAvailable()
	return AUI.can.characterPanel == true
end

---@param window table
function SettingsCharacter:Declare(window)
	local Settings, Options = AUI.Settings, AUI.CharacterOptions

	window:Page("character", {
		title = CHARACTER,
		under = "windowsHeader",
		switch = {
			path = Options.ENABLED_PATH,
			default = Settings:Default(Options.ENABLED_PATH),
			label = L["Enhance %s"]:format(CHARACTER),
		},
	})
end

AUI.Modules:Register({
	group = "windows",
	page = SettingsCharacter,
	start = function()
		AUI.Character:Start()
	end,
})
