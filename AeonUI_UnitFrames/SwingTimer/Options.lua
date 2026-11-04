local AUI = select(2, ...)

local Schema = AUI.Schema

---@class AUISwingTimerRowSpec
---@field swing string the row's name in `Enum.PlayerSwingType`
---@field show string its switch's field
---@field color string its color's field
---@field label string its tag's locale key
---@field speedReturn integer which of `UnitAttackSpeed`'s returns is its weapon's speed
---@field sample number the preview's share of a swing
---@field sampleTime string the preview's time

---The swing timer's profile settings and its frame-free rules: which rows show, when the frame shows and how the rows
---stack.
---@class AUISwingTimerOptions
---@field ENABLED_PATH string the page's switch
---@field POSITION_PATH string the frame's place, set in edit mode
---@field DEFAULT_POSITION { point: string, x: number, y: number }
---@field ROWS AUISwingTimerRowSpec[] the rows, top to bottom
---@field VISIBILITIES string[] the Show choices
---@field BORDER_STYLES string[] the Border Style choices
---@field SPARK_TEXTURE string
---@field SPARK_WIDTH number
---@field END_GRACE number how long, in seconds, a row waits past its swing's end before going idle
---@field MIN_WIDTH number
---@field MAX_WIDTH number
---@field MIN_HEIGHT number
---@field MAX_HEIGHT number
---@field MAX_SPACING number
---@field MIN_TEXT number
---@field MAX_TEXT number
---@field TEXT_INSET number
---@field FAR_TEXT AUIColor the row's text while its target is out of range
---@field NEAR_TEXT AUIColor the row's text otherwise
local Options = {
	ENABLED_PATH = "swingTimer.enabled",
	POSITION_PATH = "swingTimer.position",
	DEFAULT_POSITION = { point = "CENTER", x = 0, y = -180 },
	ROWS = {
		{
			swing = "MainHand",
			show = "showMH",
			color = "mhColor",
			label = "MH",
			speedReturn = 1,
			sample = 0.55,
			sampleTime = "1.2",
		},
		{
			swing = "OffHand",
			show = "showOH",
			color = "ohColor",
			label = "OH",
			speedReturn = 2,
			sample = 0.3,
			sampleTime = "1.3",
		},
		{
			swing = "Ranged",
			show = "showR",
			color = "rColor",
			label = "R",
			speedReturn = 3,
			sample = 0.75,
			sampleTime = "0.7",
		},
	},
	VISIBILITIES = { "COMBAT", "ALWAYS" },
	BORDER_STYLES = { "THIN_LINE", "FOREVER_MINIMAL" },
	SPARK_TEXTURE = "Interface\\CastingBar\\UI-CastingBar-Spark",
	SPARK_WIDTH = 8,
	END_GRACE = 0.25,
	MIN_WIDTH = 80,
	MAX_WIDTH = 600,
	MIN_HEIGHT = 4,
	MAX_HEIGHT = 40,
	MAX_SPACING = 20,
	MIN_TEXT = 6,
	MAX_TEXT = 24,
	TEXT_INSET = 4,
	FAR_TEXT = { r = 0.97, g = 0.44, b = 0.44 },
	NEAR_TEXT = { r = 240 / 255, g = 241 / 255, b = 243 / 255 },
}
AUI.SwingTimerOptions = Options

Schema:Choices("swingTimerVisibility", Options.VISIBILITIES)
Schema:Choices("swingTimerBorderStyle", Options.BORDER_STYLES)

Schema:Boolean(Options.ENABLED_PATH, false)
Schema:Position(Options.POSITION_PATH)
Schema:Boolean("swingTimer.showMH", true)
Schema:Boolean("swingTimer.showOH", false)
Schema:Boolean("swingTimer.showR", false)
Schema:Choice("swingTimer.visibility", "swingTimerVisibility", "COMBAT")
Schema:Number("swingTimer.width", 220, Options.MIN_WIDTH, Options.MAX_WIDTH, true)
Schema:Number("swingTimer.height", 14, Options.MIN_HEIGHT, Options.MAX_HEIGHT, true)
Schema:Number("swingTimer.spacing", 2, 0, Options.MAX_SPACING, true)
Schema:Boolean("swingTimer.depleteFill", false)
Schema:Boolean("swingTimer.spark", true)
Schema:Boolean("swingTimer.time", true)
Schema:Boolean("swingTimer.label", true)
Schema:Boolean("swingTimer.rangeCheck", true)
Schema:Number("swingTimer.outOfRangeAlpha", 40, 0, 100, true)
Schema:String("swingTimer.texture", "Solid", 64)
Schema:Boolean("swingTimer.classColor", false)
Schema:Color("swingTimer.mhColor", { r = 0x66 / 255, g = 0xd9 / 255, b = 0xef / 255 })
Schema:Color("swingTimer.ohColor", { r = 0xc7 / 255, g = 0xcc / 255, b = 0xdb / 255 })
Schema:Color("swingTimer.rColor", { r = 0.3, g = 0.82, b = 0.48 })
Schema:Color("swingTimer.background", { r = 0x19 / 255, g = 0x1b / 255, b = 0x1d / 255, a = 0.6 })
Schema:Choice("swingTimer.borderStyle", "swingTimerBorderStyle", "THIN_LINE")
Schema:Color("swingTimer.borderColor", { r = 0x37 / 255, g = 0x3b / 255, b = 0x40 / 255 })
Schema:String("swingTimer.font", "Expressway", 64)
Schema:Choice("swingTimer.outline", "fontOutline", "SLUG")
Schema:Number("swingTimer.textSize", 11, Options.MIN_TEXT, Options.MAX_TEXT, true)

---A row shows while its switch is on and its slot can swing: the Main Hand always can, the others need a weapon speed.
---@param spec AUISwingTimerRowSpec
---@param on boolean its switch
---@param speed number? its weapon's speed, as last read
---@return boolean wanted
function Options:Wanted(spec, on, speed)
	if not on then
		return false
	end

	return spec.swing == "MainHand" or speed ~= nil
end

---@param value any what `UnitAttackSpeed` returned, already readable
---@return number? speed the weapon's speed, or nil when the slot has none
function Options:Speed(value)
	if type(value) == "number" and value > 0 then
		return value
	end

	return nil
end

---@param value any a swing's reported length, already readable
---@return boolean usable a finite length above zero
function Options:Usable(value)
	return type(value) == "number" and value == value and value > 0 and value ~= math.huge
end

---@param on boolean the page's switch
---@param rows integer how many rows show
---@param sampling boolean edit mode's sample is up
---@param visibility string the Show setting
---@param inCombat boolean
---@return boolean visible
function Options:Visible(on, rows, sampling, visibility, inCombat)
	if not on or rows == 0 then
		return false
	end

	return sampling or visibility == "ALWAYS" or inCombat
end

---@param rows integer
---@param height number a row's height
---@param spacing number
---@return number height the frame's height, at least one row
function Options:StackHeight(rows, height, spacing)
	if rows <= 1 then
		return height
	end

	return rows * height + (rows - 1) * spacing
end

---@param index integer the row's place in the stack, from 1
---@param height number
---@param spacing number
---@return number y the row's offset from the frame's top
function Options:RowY(index, height, spacing)
	return -(index - 1) * (height + spacing)
end

---@param style string the Border Style setting
---@param height number the Height setting
---@param minimum number the least height the Forever Minimal art draws around
---@return number height a row's drawn height
function Options:DrawnHeight(style, height, minimum)
	if style == "FOREVER_MINIMAL" then
		return math.max(height, minimum)
	end

	return height
end
