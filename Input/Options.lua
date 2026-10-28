local AUI = select(2, ...)

local Schema = AUI.Schema

local UNMANAGED = "UNMANAGED"
local MARK_BUTTON = "AeonUIFocusMark"

---The Input settings and the frame-free arithmetic behind them: the value Click Down gives the game, and Focus
---Shortcut's secure attribute keys, binding key and macros.
---@class AUIInputOptions
---@field CLICK_DOWN_PATH string a `clickDown` choice
---@field FOCUS_PATH string Focus Shortcut is on
---@field FOCUS_MODIFIER_PATH string a `focusModifier` choice
---@field FOCUS_BUTTON_PATH string a `focusButton` choice, the mouse button's number
---@field FOCUS_WORLD_PATH string clicks in the world focus the unit under the cursor
---@field FOCUS_MARK_PATH string a raid marker is put on the new focus
---@field FOCUS_MARKER_PATH string a `focusMarker` choice, the marker's number
---@field CLICK_DOWN string[] the Click Down choices, in the order the page lists them
---@field MODIFIERS string[] the modifiers as secure attribute prefixes, in the order the page lists them
---@field BUTTONS string[] the mouse buttons' numbers
---@field MARKERS string[] the raid markers' numbers
---@field UNMANAGED string the choice that leaves Click Down to the game
---@field MARK_BUTTON string the name of the secure button that marks the focus
---@field FRAME_MACRO string the unit frames' macro while Mark Focus is on
local Options = {
	CLICK_DOWN_PATH = "input.clickDown",
	FOCUS_PATH = "input.focus.enabled",
	FOCUS_MODIFIER_PATH = "input.focus.modifier",
	FOCUS_BUTTON_PATH = "input.focus.button",
	FOCUS_WORLD_PATH = "input.focus.world",
	FOCUS_MARK_PATH = "input.focus.mark",
	FOCUS_MARKER_PATH = "input.focus.marker",
	CLICK_DOWN = { UNMANAGED, "ON", "COMBAT", "OFF" },
	-- Blizzard builds the prefix shift, then ctrl, then alt in front, so `alt-ctrl-shift` order.
	MODIFIERS = { "shift", "ctrl", "alt", "ctrl-shift", "alt-shift", "alt-ctrl" },
	BUTTONS = { "1", "2", "3", "4", "5" },
	MARKERS = { "1", "2", "3", "4", "5", "6", "7", "8" },
	UNMANAGED = UNMANAGED,
	MARK_BUTTON = MARK_BUTTON,
	FRAME_MACRO = "/focus [@mouseover,exists]\n/click [@focus,exists] " .. MARK_BUTTON,
}
AUI.InputOptions = Options

Schema:Choices("clickDown", Options.CLICK_DOWN)
Schema:Choices("focusModifier", Options.MODIFIERS)
Schema:Choices("focusButton", Options.BUTTONS)
Schema:Choices("focusMarker", Options.MARKERS)

Schema:Choice(Options.CLICK_DOWN_PATH, "clickDown", UNMANAGED)
Schema:Boolean(Options.FOCUS_PATH, false)
Schema:Choice(Options.FOCUS_MODIFIER_PATH, "focusModifier", "shift")
Schema:Choice(Options.FOCUS_BUTTON_PATH, "focusButton", "1")
Schema:Boolean(Options.FOCUS_WORLD_PATH, true)
Schema:Boolean(Options.FOCUS_MARK_PATH, false)
Schema:Choice(Options.FOCUS_MARKER_PATH, "focusMarker", "8")

---@param path string one of the paths above
---@return any value
function Options:Get(path)
	return AUI.Profile:Get(path)
end

---The value `ActionButtonUseKeyDown` should hold.
---@param choice string? a `clickDown` choice
---@param inCombat boolean
---@return string? value nil while the setting is left to the game
function Options.ClickDownValue(choice, inCombat)
	if choice == "ON" then
		return "1"
	elseif choice == "OFF" then
		return "0"
	elseif choice == "COMBAT" then
		return inCombat and "1" or "0"
	end

	return nil
end

---@param modifier string an attribute prefix such as "ctrl-shift"
---@param button string "1" to "5"
---@return string typeKey
---@return string macroKey
function Options.AttributeKeys(modifier, button)
	return modifier .. "-type" .. button, modifier .. "-macrotext" .. button
end

---@param modifier string
---@param button string
---@return string key the binding key, such as "CTRL-SHIFT-BUTTON1"
function Options.BindingKey(modifier, button)
	return modifier:upper() .. "-BUTTON" .. button
end

---The world button's macro: empty ground clears focus, a unit is focused, and the focus is marked when asked.
---@param mark boolean
---@return string text
function Options.WorldMacro(mark)
	local text = "/clearfocus [@mouseover,noexists]\n/focus [@mouseover,exists]"

	if mark then
		text = text .. "\n/click [@focus,exists] " .. MARK_BUTTON
	end

	return text
end
