local AUI = select(2, ...)

local Options = AUI.InputOptions

---Hides the macro names on Blizzard's main action bars through each name's alpha. Blizzard's button update only sets
---the name's text, so the alpha holds without a hook, and no button is touched while the feature was never on.
---@class AUIMacroNames
---@field hidden boolean the names are hidden
local MacroNames = {
	hidden = false,
}
AUI.MacroNames = MacroNames

---Brings every button in line with the settings.
function MacroNames:Apply()
	local hidden = AUI.can.macroNames == true and Options:Get(Options.HIDE_MACRO_NAMES_PATH) == true

	if hidden == self.hidden then
		return
	end

	self.hidden = hidden

	for _, prefix in ipairs(ActionButtonUtil.ActionBarButtonNames) do
		for index = 1, NUM_ACTIONBAR_BUTTONS or 12 do
			local button = _G[prefix .. index]

			if button and button.Name then
				button.Name:SetAlpha(hidden and 0 or 1)
			end
		end
	end
end
