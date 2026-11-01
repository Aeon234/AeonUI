local AUI = select(2, ...)

local L = AUI.L

---The Cast Bar page, under the Unit Frames header: the module's switch.
---@class AUISettingsCastBar
local SettingsCastBar = {}
AUI.SettingsCastBar = SettingsCastBar

---@param window table
function SettingsCastBar:Declare(window)
	local Options = AUI.CastBarOptions

	window:Header("unitFramesHeader", L["Unit Frames"])
	window:Page("castBar", {
		title = L["Cast Bar"],
		under = "unitFramesHeader",
		icon = AUI.Media.sidebar.castBar,
		iconTint = true,
		switch = {
			path = Options.ENABLED_PATH,
			default = AUI.Settings:Default(Options.ENABLED_PATH),
			label = L["Show Cast Bar"],
		},
	})
end
