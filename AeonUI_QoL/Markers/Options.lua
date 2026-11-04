local AUI = select(2, ...)

local L = AUI.L
local Schema = AUI.Schema

---The Raid Markers settings and the frame-free rules behind them: the bar's buttons, their secure attributes and
---tooltip lines, its size, its visibility condition, the pull countdown's commands, and the world marker cycle.
---@class AUIMarkerOptions
---@field NAMES string[] the raid targets by index, Star to Skull; the cycle's values
---@field TARGET_TO_WORLD number[] the world marker matching each raid target, by raid target index
---@field ORIENTATIONS string[]
---@field VISIBILITY string[]
---@field FEEDBACK string[] the button feedback choices, in the order the page lists them
---@field BORDER_STYLES AUIBorderStyle[] the border styles the bar offers, in display order
---@field PAD number units between the bar's edge and its buttons
---@field DIMMED number the marker and Clear buttons' opacity while the player may not mark
---@field PLACED number a marker button's icon opacity while its world marker is down
---@field HOVER_SCALE number an icon's size while the cursor is over it, of the button's
---@field PRESS_SCALE number an icon's size while it is pressed, of the button's
---@field ICON_RESPONSE number seconds; the spring that sizes an icon
---@field FADE_RESPONSE number seconds; the spring that shows and hides the bar on mouseover
---@field PLACE_BUTTON string the secure button the Place Next World Marker binding clicks
---@field CLEAR_BUTTON string the secure button the Clear World Markers binding clicks
local Options = {
	NAMES = { "STAR", "CIRCLE", "DIAMOND", "TRIANGLE", "MOON", "SQUARE", "CROSS", "SKULL" },
	-- WORLD_MARKER1-8 name the icon each world marker shows.
	TARGET_TO_WORLD = { 5, 6, 3, 2, 7, 1, 4, 8 },
	ORIENTATIONS = { "HORIZONTAL", "VERTICAL" },
	VISIBILITY = { "ALWAYS", "GROUP", "GROUP_OR_TARGET" },
	BORDER_STYLES = { "FOREVER_MINIMAL", "FOREVER", "SLATE", "THIN_LINE", "NONE" },
	FEEDBACK = { "highlight", "grow", "press" },
	PAD = 3,
	DIMMED = 0.35,
	PLACED = 0.35,
	HOVER_SCALE = 1.15,
	PRESS_SCALE = 0.9,
	ICON_RESPONSE = 0.25,
	FADE_RESPONSE = 0.2,
	PLACE_BUTTON = "AeonUIWorldMarkerPlace",
	CLEAR_BUTTON = "AeonUIWorldMarkerClear",
}
AUI.MarkerOptions = Options

Schema:Choices("markerOrientation", Options.ORIENTATIONS)
Schema:Choices("markerVisibility", Options.VISIBILITY)
Schema:Choices("markerName", Options.NAMES)
Schema:Choices("markerBorderStyle", Options.BORDER_STYLES)

Schema:Boolean("markers.enabled", false)
Schema:Boolean("markers.readyCheck", true)
Schema:Boolean("markers.countdown", true)
Schema:Number("markers.seconds", 12, 1, 30, true)
Schema:Boolean("markers.tooltips", true)
Schema:Boolean("markers.feedback.highlight", false)
Schema:Boolean("markers.feedback.grow", true)
Schema:Boolean("markers.feedback.press", true)
Schema:Boolean("markers.mouseover", false)
Schema:Choice("markers.visibility", "markerVisibility", "GROUP_OR_TARGET")
Schema:Choice("markers.orientation", "markerOrientation", "HORIZONTAL")
Schema:Number("markers.size", 32, 16, 60, true)
Schema:Number("markers.spacing", 3, 0, 30, true)
Schema:Choice("markers.border.style", "markerBorderStyle", "FOREVER")
Schema:Color("markers.border.color", AUI.Border.ART_COLOR)
Schema:Number("markers.border.thickness", 100, 50, 300, true)
Schema:Boolean("markers.border.showShadow", false)
Schema:Number("markers.border.shadowSize", AUI.Border.SHADOW_SIZE, 1, 10, true)
Schema:Color("markers.border.shadowColor", AUI.Border.SHADOW_COLOR)
Schema:Position("markers.position")
Schema:Order("markers.cycle.order", "markerName", Options.NAMES)

for _, name in ipairs(Options.NAMES) do
	Schema:Boolean("markers.cycle.show." .. name, true)
end

---@param path string
---@return any value
function Options:Get(path)
	return AUI.Profile:Get(path)
end

---@param choice string a `markerVisibility` choice
---@return string condition the bar's visibility state driver; every choice hides it in pet battles
function Options:Visibility(choice)
	if choice == "ALWAYS" then
		return "[petbattle] hide; show"
	elseif choice == "GROUP" then
		return "[petbattle] hide; [group] show; hide"
	end

	return "[petbattle] hide; [group] show; [@target,exists] show; hide"
end

---@param seconds number
---@param bigWigs boolean BigWigs is loaded
---@param dbm boolean DBM is loaded
---@return string start the macro starting a pull countdown
---@return string cancel the macro cancelling it
function Options:Countdown(seconds, bigWigs, dbm)
	if bigWigs then
		return "/pull " .. seconds, "/pull 0"
	elseif dbm then
		return "/dbm pull " .. seconds, "/dbm pull 0"
	end

	local command = SLASH_COUNTDOWN1 or "/countdown"

	return command .. " " .. seconds, command .. " 0"
end

---@param readyCheck boolean
---@param countdown boolean
---@return string[] kinds the buttons shown, in order: eight markers, Clear, then Ready Check and Countdown when on
function Options:Kinds(readyCheck, countdown)
	local kinds = {}

	for _ = 1, #self.NAMES do
		kinds[#kinds + 1] = "marker"
	end

	kinds[#kinds + 1] = "clear"

	if readyCheck then
		kinds[#kinds + 1] = "readyCheck"
	end

	if countdown then
		kinds[#kinds + 1] = "countdown"
	end

	return kinds
end

---A button's secure attributes. A marker's click toggles its raid target on the target and its right-click toggles
---the matching world marker; Clear clears every raid target, or with a right-click every world marker. Ready Check's
---click starts a ready check and a Shift-click turns combat logging on or off; its right-click, a role check, is not
---a secure action. Without world markers a right-click clears the target's raid target, or every one.
---@param kind string
---@param index number? a marker button's raid target index
---@param worldMarkers boolean the client has world markers
---@param countdown { start: string, cancel: string }
---@return table<string, any> attributes
function Options:Attributes(kind, index, worldMarkers, countdown)
	if kind == "marker" and index then
		local attributes = { type1 = "raidtarget", action1 = "toggle", marker1 = index, type2 = "raidtarget",
			action2 = "clear" }

		if worldMarkers then
			attributes.type2, attributes.action2, attributes.marker2 = "worldmarker", "toggle", self.TARGET_TO_WORLD[index]
		end

		return attributes
	elseif kind == "clear" then
		return {
			type1 = "raidtarget",
			action1 = "clear-all",
			type2 = worldMarkers and "worldmarker" or "raidtarget",
			action2 = worldMarkers and "clear" or "clear-all",
		}
	elseif kind == "readyCheck" then
		local combatLog = SLASH_COMBATLOG1 or "/combatlog"

		return {
			type1 = "macro",
			macrotext1 = SLASH_READYCHECK1 or "/readycheck",
			["shift-type*"] = "macro",
			["shift-macrotext*"] = combatLog,
		}
	end

	return {
		["*type*"] = "macro",
		["*macrotext1"] = countdown.start,
		["*macrotext2"] = countdown.cancel,
	}
end

---@param count number buttons shown
---@param size number
---@param spacing number
---@param vertical boolean
---@return number width the bar's
---@return number height
function Options:BarSize(count, size, spacing, vertical)
	local length = count * size + math.max(count - 1, 0) * spacing + self.PAD * 2
	local across = size + self.PAD * 2

	if vertical then
		return across, length
	end

	return length, across
end

---@param slot number the button's place on the bar, first 1
---@param size number
---@param spacing number
---@return number offset from the bar's leading edge to the button's
function Options:Offset(slot, size, spacing)
	return self.PAD + (slot - 1) * (size + spacing)
end

---@param hovered boolean
---@param pressed boolean
---@param grow boolean Grow on Hover is on
---@param press boolean Shrink on Press is on
---@return number scale the icon's size, of the button's
function Options:IconScale(hovered, pressed, grow, press)
	if pressed and press then
		return self.PRESS_SCALE
	elseif hovered and grow then
		return self.HOVER_SCALE
	end

	return 1
end

---A button's tooltip lines: each click with what it does.
---@param kind string
---@param worldMarkers boolean
---@param seconds number the countdown's
---@return { click: string, action: string }[] lines
function Options:ClickLines(kind, worldMarkers, seconds)
	local click, right = L["Click"], L["Right-Click"]

	if kind == "marker" then
		return {
			{ click = click, action = L["Mark or unmark your target"] },
			{ click = right, action = worldMarkers and L["Place or remove the world marker"]
				or L["Clear your target's marker"] },
		}
	elseif kind == "clear" then
		return {
			{ click = click, action = L["Clear every raid target"] },
			{ click = right, action = worldMarkers and L["Clear every world marker"] or L["Clear every raid target"] },
		}
	elseif kind == "readyCheck" then
		return {
			{ click = click, action = L["Start a ready check"] },
			{ click = right, action = L["Start a role check"] },
			{ click = L["Shift-Click"], action = L["Turn combat logging on or off"] },
		}
	end

	return {
		{ click = click, action = L["Start a %d-second pull countdown"]:format(seconds) },
		{ click = right, action = L["Cancel the countdown"] },
	}
end

---@param order string[]? the saved order, missing values taking their default places after it
---@param shown fun(name: string): boolean whether a marker is in the cycle
---@return number[] markers the world markers the cycle places, in order
function Options:Cycle(order, shown)
	local markers, seen = {}, {}
	local index = {}

	for position, name in ipairs(self.NAMES) do
		index[name] = position
	end

	local function Add(name)
		if index[name] and not seen[name] then
			seen[name] = true

			if shown(name) then
				markers[#markers + 1] = self.TARGET_TO_WORLD[index[name]]
			end
		end
	end

	for _, name in ipairs(order or {}) do
		Add(name)
	end

	for _, name in ipairs(self.NAMES) do
		Add(name)
	end

	return markers
end

---@param marker number a world marker
---@return string macro placing it at the cursor
function Options:CycleMacro(marker)
	return ("%s [@cursor] %d"):format(SLASH_WORLD_MARKER1 or "/wm", marker)
end

---@param index number the step last placed, 0 before the first
---@param count number steps in the cycle
---@return number next the step to place next, back to 1 after the last
function Options:NextStep(index, count)
	return index % count + 1
end
