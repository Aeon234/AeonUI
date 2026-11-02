local AUI = select(2, ...)

local L = AUI.L
local Schema = AUI.Schema

local UNMANAGED = "UNMANAGED"
local MARK_BUTTON = "AeonUIFocusMark"

---The Input settings and the frame-free arithmetic behind them: the value Click Down gives the game, and Focus
---Shortcut's secure attribute keys, binding key and macros, and the short key labels on action buttons.
---@class AUIInputOptions
---@field CLICK_DOWN_PATH string a `clickDown` choice
---@field FOCUS_PATH string Focus Shortcut is on
---@field FOCUS_MODIFIER_PATH string a `focusModifier` choice
---@field FOCUS_BUTTON_PATH string a `focusButton` choice, the mouse button's number
---@field FOCUS_WORLD_PATH string clicks in the world focus the unit under the cursor
---@field FOCUS_MARK_PATH string a raid marker is put on the new focus
---@field FOCUS_MARKER_PATH string a `focusMarker` choice, the marker's number
---@field HIDE_MACRO_NAMES_PATH string action buttons hide macro names
---@field KEY_LABELS_PATH string action buttons show short key labels
---@field KEY_FONT_PATH string the key labels' LibSharedMedia font
---@field KEY_SIZE_PATH string the key labels' font size
---@field KEY_OUTLINE_PATH string a `fontOutline` choice for the key labels
---@field MIN_KEY_SIZE number
---@field MAX_KEY_SIZE number
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
	HIDE_MACRO_NAMES_PATH = "input.hideMacroNames",
	KEY_LABELS_PATH = "input.keyLabels.enabled",
	KEY_FONT_PATH = "input.keyLabels.font",
	KEY_SIZE_PATH = "input.keyLabels.size",
	KEY_OUTLINE_PATH = "input.keyLabels.outline",
	MIN_KEY_SIZE = 6,
	MAX_KEY_SIZE = 24,
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
Schema:Boolean(Options.HIDE_MACRO_NAMES_PATH, false)
-- Blizzard's key labels use NumberFontNormalSmallGray: Arial Narrow at 12 on both clients.
Schema:Boolean(Options.KEY_LABELS_PATH, false)
Schema:String(Options.KEY_FONT_PATH, "Arial Narrow", 64)
Schema:Number(Options.KEY_SIZE_PATH, 12, Options.MIN_KEY_SIZE, Options.MAX_KEY_SIZE, true)
Schema:Choice(Options.KEY_OUTLINE_PATH, "fontOutline", "SLUG")

-- Binding-key modifiers, as the client writes them in front of a key, and their codes.
local KEY_MODIFIERS = {
	SHIFT = L["S"], LSHIFT = L["S"], RSHIFT = L["S"],
	CTRL = L["C"], LCTRL = L["C"], RCTRL = L["C"],
	ALT = L["A"], LALT = L["A"], RALT = L["A"],
	META = L["Cmd"], LMETA = L["Cmd"], RMETA = L["Cmd"],
}
-- The order codes are written in, matching the client's own modifier order.
local MODIFIER_ORDER = { L["A"], L["C"], L["S"], L["Cmd"] }
-- Named binding keys and their codes; any other key is shown as the client names it.
local KEY_CODES = {
	BUTTON3 = L["MM"],
	MOUSEWHEELUP = L["WU"],
	MOUSEWHEELDOWN = L["WD"],
	SPACE = L["SP"],
	PAGEUP = L["PU"],
	PAGEDOWN = L["PD"],
	BACKSPACE = L["BS"],
	INSERT = L["INS"],
	DELETE = L["DEL"],
	HOME = L["HM"],
	END = L["END"],
	TAB = L["TAB"],
}
local NUMPAD_SUFFIXES = { PLUS = "+", MINUS = "-", MULTIPLY = "*", DIVIDE = "/", DECIMAL = "." }

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

---The short label for a binding key: modifier codes, then the key's code, with no separators.
---@param key string a binding key as `GetBindingKey` returns it, such as "ALT-SHIFT-BUTTON4"
---@return string label such as "ASM4"
function Options.KeyLabel(key)
	local held, base = {}, key

	while true do
		local modifier, rest = base:match("^(%u+)%-(.+)$")
		local code = modifier and KEY_MODIFIERS[modifier]

		if not code then
			break
		end

		held[code] = true
		base = rest
	end

	local label = KEY_CODES[base]

	if not label then
		local button = base:match("^BUTTON(%d+)$")
		local numpad = base:match("^NUMPAD(.+)$")

		if button then
			label = L["M%s"]:format(button)
		elseif numpad then
			label = L["N%s"]:format(NUMPAD_SUFFIXES[numpad] or numpad)
		else
			label = base:upper()
		end
	end

	local codes = {}

	for _, code in ipairs(MODIFIER_ORDER) do
		if held[code] then
			codes[#codes + 1] = code
		end
	end

	return table.concat(codes) .. label
end
