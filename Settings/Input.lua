local AUI = select(2, ...)

local L = AUI.L
local lib = LibStub("LibAeonSettings-1.0")

local CLICK_DOWN_LABELS = {
	UNMANAGED = L["Not Managed"],
	ON = L["Always On"],
	COMBAT = L["In Combat Only"],
	OFF = L["Always Off"],
}
local MODIFIER_LABELS = {
	shift = L["Shift"],
	ctrl = L["Ctrl"],
	alt = L["Alt"],
	["ctrl-shift"] = L["Ctrl + Shift"],
	["alt-shift"] = L["Alt + Shift"],
	["alt-ctrl"] = L["Alt + Ctrl"],
}
local BUTTON_LABELS = {
	["1"] = L["Left Button"],
	["2"] = L["Right Button"],
	["3"] = L["Middle Button"],
	["4"] = L["Button 4"],
	["5"] = L["Button 5"],
}

---The Input page, under the Quality of Life header: the Action Bars card's Click Down and key labels, and the Focus
---Keybind card, headed by Focus Shortcut's switch. Changes take effect at once; Focus Shortcut's wait for combat to
---end.
---@class AUISettingsInput
local SettingsInput = {}
AUI.SettingsInput = SettingsInput

---@return boolean
function SettingsInput:IsAvailable()
	return AUI.can.clickDown == true or AUI.can.keyLabels == true or AUI.can.focusShortcut == true
end

---@param values string[]
---@param labels table<string, string>
---@return table[] options
local function DropdownOptions(values, labels)
	local options = {}

	for index, value in ipairs(values) do
		options[index] = { value = value, text = labels[value] }
	end

	return options
end

---@param page table
function SettingsInput:DeclareActionBars(page)
	local Options = AUI.InputOptions
	local Settings = AUI.Settings
	local card = page:Section("inputClickDown", ACTIONBARS_LABEL)

	if AUI.can.clickDown then
		card:Dropdown({
			id = "clickDown",
			label = L["Cast on Key Down"],
			path = Options.CLICK_DOWN_PATH,
			default = Settings:Default(Options.CLICK_DOWN_PATH),
			options = DropdownOptions(Options.CLICK_DOWN, CLICK_DOWN_LABELS),
		})
	end

	if not AUI.can.keyLabels then
		return
	end

	card:Checkbox({
		id = "keyLabels",
		label = L["Short Key Labels"],
		description = L["Shows Shift + Mouse Button 4 as %s."]:format(Options.KeyLabel("SHIFT-BUTTON4")),
		path = Options.KEY_LABELS_PATH,
		default = Settings:Default(Options.KEY_LABELS_PATH),
	})
	card:Dropdown({
		id = "keyLabelsFont",
		label = L["Font"],
		path = Options.KEY_FONT_PATH,
		default = Settings:Default(Options.KEY_FONT_PATH),
		depends = "keyLabels",
		picker = "font",
	})
	card:Slider({
		id = "keyLabelsSize",
		label = L["Size"],
		path = Options.KEY_SIZE_PATH,
		default = Settings:Default(Options.KEY_SIZE_PATH),
		depends = "keyLabels",
		min = Options.MIN_KEY_SIZE,
		max = Options.MAX_KEY_SIZE,
		step = 1,
	})
	card:Dropdown({
		id = "keyLabelsOutline",
		label = L["Outline"],
		path = Options.KEY_OUTLINE_PATH,
		default = Settings:Default(Options.KEY_OUTLINE_PATH),
		depends = "keyLabels",
		options = lib.OUTLINES,
	})
end

---@param page table
function SettingsInput:DeclareFocusShortcut(page)
	local Options = AUI.InputOptions
	local Settings = AUI.Settings
	local markers = {}

	for index, value in ipairs(Options.MARKERS) do
		markers[index] = { value = value, text = _G["RAID_TARGET_" .. value] or value }
	end

	local card = page:Section("inputFocusShortcut", L["Focus Keybind"])

	card:Toggle({
		id = "focusShortcut",
		label = L["Focus on Click"],
		description = AUI.FocusShortcut.CliqueLoaded() and L["Clique handles unit frames; bind Focus there."] or nil,
		path = Options.FOCUS_PATH,
		default = Settings:Default(Options.FOCUS_PATH),
	})
	card:Dropdown({
		id = "focusModifier",
		label = L["Modifier"],
		path = Options.FOCUS_MODIFIER_PATH,
		default = Settings:Default(Options.FOCUS_MODIFIER_PATH),
		depends = "focusShortcut",
		options = DropdownOptions(Options.MODIFIERS, MODIFIER_LABELS),
	})
	card:Dropdown({
		id = "focusButton",
		label = L["Mouse Button"],
		path = Options.FOCUS_BUTTON_PATH,
		default = Settings:Default(Options.FOCUS_BUTTON_PATH),
		depends = "focusShortcut",
		options = DropdownOptions(Options.BUTTONS, BUTTON_LABELS),
	})
	card:Checkbox({
		id = "focusWorld",
		label = L["World Clicks"],
		description = L["Empty ground clears focus."],
		path = Options.FOCUS_WORLD_PATH,
		default = Settings:Default(Options.FOCUS_WORLD_PATH),
		depends = "focusShortcut",
	})
	card:Checkbox({
		id = "focusMark",
		label = L["Mark Focus"],
		description = L["Never replaces an existing marker."],
		path = Options.FOCUS_MARK_PATH,
		default = Settings:Default(Options.FOCUS_MARK_PATH),
		depends = "focusShortcut",
	})
	card:Dropdown({
		id = "focusMarker",
		label = L["Marker"],
		path = Options.FOCUS_MARKER_PATH,
		default = Settings:Default(Options.FOCUS_MARKER_PATH),
		depends = "focusMark",
		options = markers,
	})
end

---@param window table
function SettingsInput:Declare(window)
	local page = window:Page("input", {
		title = L["Input"],
		under = "qualityOfLifeHeader",
		icon = AUI.Media.sidebar.input,
		iconTint = true,
	})

	if not page then
		return
	end

	if AUI.can.clickDown or AUI.can.keyLabels then
		self:DeclareActionBars(page)
	end

	if AUI.can.focusShortcut then
		self:DeclareFocusShortcut(page)
	end
end

AUI.Modules:Register({
	group = "qualityOfLife",
	page = SettingsInput,
	start = function()
		AUI.Input:Start()
	end,
})
