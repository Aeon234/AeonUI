local AUI = select(2, ...)

local Schema = AUI.Schema

---@class AUISwingTimerSeal
---@field id integer
---@field color string its color's field
---@field label string its name where the client cannot give one

---@class AUISwingTimerRowSpec
---@field hand boolean? it swings in melee, so queued attacks and seals color it
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
---@field OFF_HAND_SLOT integer the off hand's inventory slot
---@field NEXT_SWING table<string, integer[]> each class's next-swing attacks, by spell ID, the first naming the preview's
---@field QUEUE_OWN_COLOR table<integer, string> the attacks with a color field of their own
---@field SEALS AUISwingTimerSeal[] the paladin's seals, by their first rank: every rank shares the name that is matched
---@field SEAL_SECONDS number how long a seal lasts until a readable buff says otherwise
---@field MAX_AURAS integer
---@field QUEUE_SEPARATOR string between a row's label and its queued attack
---@field AUTO_SHOT_CAST number Auto Shot's cast, in seconds, at the end of the ranged cycle
---@field SAMPLE_SWING number a sample swing's length, in seconds
---@field MIN_WINDOW number
---@field MAX_WINDOW number
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
			hand = true,
			show = "showMH",
			color = "mhColor",
			label = "MH",
			speedReturn = 1,
			sample = 0.55,
			sampleTime = "1.2",
		},
		{
			swing = "OffHand",
			hand = true,
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
	OFF_HAND_SLOT = 17,
	NEXT_SWING = {
		WARRIOR = { 78, 845 },
		DRUID = { 6807 },
		HUNTER = { 2973 },
	},
	QUEUE_OWN_COLOR = { [845] = "cleaveColor" },
	SEALS = {
		{ id = 20154, color = "sealRighteousColor", label = "Seal of Righteousness" },
		{ id = 21082, color = "sealCrusaderColor", label = "Seal of the Crusader" },
		{ id = 20375, color = "sealCommandColor", label = "Seal of Command" },
		{ id = 20164, color = "sealJusticeColor", label = "Seal of Justice" },
		{ id = 20165, color = "sealLightColor", label = "Seal of Light" },
		{ id = 20166, color = "sealWisdomColor", label = "Seal of Wisdom" },
		{ id = 1311649, color = "sealFuryColor", label = "Seal of Fury" },
		{ id = 407798, color = "sealMartyrdomColor", label = "Seal of Martyrdom" },
	},
	SEAL_SECONDS = 30,
	MAX_AURAS = 40,
	QUEUE_SEPARATOR = " - ",
	AUTO_SHOT_CAST = 0.5,
	SAMPLE_SWING = 2.6,
	MIN_WINDOW = 0.1,
	MAX_WINDOW = 2,
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

-- The seals' colors, by field.
local SEAL_COLORS = {
	sealRighteousColor = { r = 0.95, g = 0.85, b = 0.40 },
	sealCrusaderColor = { r = 0.95, g = 0.55, b = 0.20 },
	sealCommandColor = { r = 0.75, g = 0.35, b = 0.95 },
	sealJusticeColor = { r = 0.60, g = 0.65, b = 0.75 },
	sealLightColor = { r = 1, g = 0.95, b = 0.70 },
	sealWisdomColor = { r = 0.35, g = 0.65, b = 1 },
	sealFuryColor = { r = 0.95, g = 0.25, b = 0.20 },
	sealMartyrdomColor = { r = 0.90, g = 0.40, b = 0.70 },
}

Schema:Choices("swingTimerVisibility", Options.VISIBILITIES)
Schema:Choices("swingTimerBorderStyle", Options.BORDER_STYLES)

Schema:Boolean(Options.ENABLED_PATH, false)
Schema:Position(Options.POSITION_PATH)
Schema:Boolean("swingTimer.showMH", true)
Schema:Boolean("swingTimer.showOH", false)
Schema:Boolean("swingTimer.showR", false)
Schema:Boolean("swingTimer.alwaysShowRows", false)
Schema:Boolean("swingTimer.shieldRow", false)
Schema:Boolean("swingTimer.combineHands", false)
Schema:Boolean("swingTimer.hideWhenIdle", false)
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
Schema:String("swingTimer.texture", "Aeon Light", 64)
Schema:Boolean("swingTimer.classColor", false)
Schema:Color("swingTimer.mhColor", { r = 0x66 / 255, g = 0xd9 / 255, b = 0xef / 255 })
Schema:Color("swingTimer.ohColor", { r = 0xc7 / 255, g = 0xcc / 255, b = 0xdb / 255 })
Schema:Color("swingTimer.rColor", { r = 0.3, g = 0.82, b = 0.48 })
Schema:Color("swingTimer.background", { r = 0x19 / 255, g = 0x1b / 255, b = 0x1d / 255, a = 0.6 })
Schema:Boolean("swingTimer.queueHighlight", true)
Schema:Color("swingTimer.queueColor", { r = 1, g = 0.70, b = 0.20 })
Schema:Color("swingTimer.cleaveColor", { r = 0.97, g = 0.44, b = 0.44 })
Schema:Boolean("swingTimer.sealColors", true)

for _, seal in ipairs(Options.SEALS) do
	Schema:Color("swingTimer." .. seal.color, SEAL_COLORS[seal.color])
end

Schema:Boolean("swingTimer.swingWindow", false)
Schema:Number("swingTimer.swingWindowTime", 0.4, Options.MIN_WINDOW, Options.MAX_WINDOW)
Schema:Color("swingTimer.swingWindowColor", { r = 1, g = 1, b = 1, a = 0.35 })
Schema:Boolean("swingTimer.windowLatency", false)
Schema:Boolean("swingTimer.autoShotWindow", false)
Schema:Color("swingTimer.autoShotStandColor", { r = 0.30, g = 0.85, b = 0.35, a = 0.6 })
Schema:Color("swingTimer.autoShotMovingColor", { r = 0.95, g = 0.20, b = 0.20, a = 0.6 })
Schema:Choice("swingTimer.borderStyle", "swingTimerBorderStyle", "THIN_LINE")
Schema:Color("swingTimer.borderColor", { r = 0x37 / 255, g = 0x3b / 255, b = 0x40 / 255 })
Schema:Boolean("swingTimer.showShadow", false)
Schema:Number("swingTimer.shadowSize", AUI.Border.SHADOW_SIZE, 1, 10, true)
Schema:Color("swingTimer.shadowColor", AUI.Border.SHADOW_COLOR)
Schema:String("swingTimer.font", "Expressway", 64)
Schema:Choice("swingTimer.outline", "fontOutline", "SLUG")
Schema:Number("swingTimer.textSize", 11, Options.MIN_TEXT, Options.MAX_TEXT, true)

---A row shows while its switch is on and its slot can swing: the Main Hand always can, the others need a weapon speed.
---Always Show Rows shows every row switched on, and a shield shows the Off Hand row.
---@param spec AUISwingTimerRowSpec
---@param on boolean its switch
---@param speed number? its weapon's speed, as last read
---@param always boolean? Always Show Rows
---@param shield boolean? a shield fills its slot and counts
---@return boolean wanted
function Options:Wanted(spec, on, speed, always, shield)
	if not on then
		return false
	end

	return always == true or shield == true or spec.swing == "MainHand" or speed ~= nil
end

---Combine Hands lays the Off Hand row over the Main Hand row, as only a spark, while both show and it has a weapon.
---@param spec AUISwingTimerRowSpec
---@param combine boolean Combine Hands
---@param hostShown boolean the Main Hand row shows
---@param armed boolean the row's slot holds a weapon that swings
---@return boolean merged
function Options:Merged(spec, combine, hostShown, armed)
	return combine and hostShown and armed and spec.swing == "OffHand"
end

---A hand row takes its queued attack's color, else its seal's, else its own.
---@param spec AUISwingTimerRowSpec
---@param queued string? the queued attack's color field
---@param seal string? the seal's color field
---@return string field
---@return boolean own it is the row's own color
function Options:ColorField(spec, queued, seal)
	local field = spec.hand and (queued or seal)

	if field then
		return field, false
	end

	return spec.color, true
end

---@param id integer the attack's spell ID
---@return string field its color's field
function Options:QueueField(id)
	return self.QUEUE_OWN_COLOR[id] or "queueColor"
end

---@param spec AUISwingTimerRowSpec
---@param label string the row's own label
---@param attack string? the queued attack's name
---@return string text
function Options:TagText(spec, label, attack)
	if spec.hand and attack then
		return label .. self.QUEUE_SEPARATOR .. attack
	end

	return label
end

---How much of a row's end its window shades: a melee swing's last part, or Auto Shot's cast on a hunter's Ranged row.
---@param spec AUISwingTimerRowSpec
---@param swingOn boolean Swing End Window
---@param swingTime number Window Length
---@param shotOn boolean Auto Shot Window
---@param hunter boolean
---@param latency number seconds added, Add Latency's
---@return number? seconds none on a row without a window
function Options:WindowSeconds(spec, swingOn, swingTime, shotOn, hunter, latency)
	local seconds

	if spec.hand then
		seconds = swingOn and swingTime or nil
	elseif shotOn and hunter then
		seconds = self.AUTO_SHOT_CAST
	end

	return seconds and seconds + latency or nil
end

---@param seconds number
---@param swing number the swing's length
---@param width number the row's width
---@return number width the window's width, at least one unit and at most the row's
function Options:WindowWidth(seconds, swing, width)
	return math.max(width * math.min(seconds / swing, 1), 1)
end

---@param deplete boolean Deplete Fill
---@return string side the end a swing lands on
function Options:WindowSide(deplete)
	return deplete and "LEFT" or "RIGHT"
end

---@param spec AUISwingTimerRowSpec
---@param moving boolean
---@return string field its window's color field
function Options:WindowColor(spec, moving)
	if spec.hand then
		return "swingWindowColor"
	end

	return moving and "autoShotMovingColor" or "autoShotStandColor"
end

---@param location any the item's equip location, already readable
---@return boolean shield
function Options:IsShield(location)
	return location == "INVTYPE_SHIELD"
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
---@param hideIdle boolean? Hide When Idle, which only In Combat honors
---@param running boolean? a swing is running
---@return boolean visible
function Options:Visible(on, rows, sampling, visibility, inCombat, hideIdle, running)
	if not on or rows == 0 then
		return false
	end

	if sampling or visibility == "ALWAYS" then
		return true
	end

	return inCombat and (not hideIdle or running == true)
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
