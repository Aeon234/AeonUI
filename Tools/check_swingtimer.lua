-- Checks AeonUI_UnitFrames/SwingTimer/ outside the game: which rows show, nothing built or registered while off, the
-- defaults, swings run from duration objects, secret values read as no information, a row's end and its grace, range
-- edges and the shared flag, a weapon swap, the visibility rules, edit mode's sample and turning off and on again.
-- Run from any directory with Lua 5.1: lua Tools/check_swingtimer.lua
-- Loads the real files against stubbed globals; media and the border are stubbed. Widgets are modeled by type and fail
-- on a method their type lacks. This proves logic, never drawing or in-game behavior.
-- Exits non-zero on the first failed check.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

WOW_PROJECT_ID = 18
WOW_PROJECT_CAMELOT = 18
SlashCmdList = {}
StaticPopupDialogs = {}
C_AddOns = {
	GetAddOnMetadata = function(_, field)
		return field == "Version" and "dev" or "AeonUI"
	end,
}

function CallErrorHandler(message)
	error(message, 0)
end

local luaXpcall = xpcall
function xpcall(fn, handler, ...)
	local count, args = select("#", ...), { ... }

	return luaXpcall(function()
		return fn(unpack(args, 1, count))
	end, handler)
end

local now = 100
function GetTime()
	return now
end

local timers, afters = {}, {}
C_Timer = {
	After = function(_, callback)
		afters[#afters + 1] = callback
	end,
	NewTimer = function(seconds, callback)
		local timer = { seconds = seconds, callback = callback }

		function timer.Cancel(self)
			self.cancelled = true
		end

		timers[#timers + 1] = timer

		return timer
	end,
}

local function Flush()
	local pending = afters

	afters = {}

	for _, callback in ipairs(pending) do
		callback()
	end
end

---@return table timer the last timer still running
local function LastTimer()
	for index = #timers, 1, -1 do
		if not timers[index].cancelled and not timers[index].fired then
			return timers[index]
		end
	end

	error("no timer is running", 2)
end

local SECRET = setmetatable({}, { __tostring = function()
	return "secret"
end })

function issecretvalue(value)
	return value == SECRET
end

Enum = {
	PlayerSwingType = { MainHand = 0, OffHand = 1, Ranged = 2 },
	StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 },
	StatusBarInterpolation = { Immediate = 0 },
	NumericRuleFormatRounding = { Nearest = 0, Up = 1, Down = 2 },
}

C_StringUtil = { CreateNumericRuleFormatter = function()
	return { SetBreakpoints = function(self, points)
		self.points = points
	end }
end }

C_DurationUtil = {
	CreateDuration = function()
		return { SetTimeFromStart = function(self, start, length)
			self.start, self.length = start, length
		end }
	end,
	CreateDurationTextBinding = function()
		local binding = {}

		for _, method in ipairs({ "SetFontString", "SetDuration", "SetFormatter", "SetZeroDurationText", "SetExpiredText" }) do
			binding[method] = function() end
		end

		function binding.SetEnabled(self, enabled)
			self.enabled = enabled
		end

		return binding
	end,
}

local rangeFlags, rangeAnswer, rangeCalls = {}, {}, 0
C_SwingTimer = {
	EnableRangeCheck = function(kind, on)
		rangeFlags[kind] = on
		rangeCalls = rangeCalls + 1
	end,
	IsTargetWithinSwingRange = function(kind)
		return rangeAnswer[kind]
	end,
}

local blizzardTimer = false
C_CVar = {
	GetCVarBool = function(name)
		assert(name == "showSwingTimer", name)

		return blizzardTimer
	end,
}

local speeds = { 2.6, nil, nil }
function UnitAttackSpeed(unit)
	assert(unit == "player", unit)

	return speeds[1], speeds[2], speeds[3]
end

local inCombat = false
function UnitAffectingCombat()
	return inCombat
end

function UnitClass()
	return "Warrior", "WARRIOR"
end

SHIELDSLOT = "Shield"

local offHandItem
function GetInventoryItemID(unit, slot)
	assert(unit == "player" and slot == 17, slot)

	return offHandItem
end

C_Item = { GetItemInfoInstant = function(item)
	return item, "Armor", "Shields", item == "shield" and "INVTYPE_SHIELD" or "INVTYPE_WEAPON"
end }

C_ClassColor = { GetClassColor = function()
	return { r = 0.78, g = 0.61, b = 0.43 }
end }

-- Widgets, modeled by type: a method a type lacks is an error.
local frames = {}

local function Strict(object, kind)
	return setmetatable(object, { __index = function(_, key)
		error(("%s has no %s"):format(kind, tostring(key)), 2)
	end })
end

local REGION = {
	SetPoint = function(self, ...)
		self.points[#self.points + 1] = { ... }
	end,
	ClearAllPoints = function(self)
		self.points = {}
	end,
	SetAllPoints = function(self)
		self.all = true
	end,
	SetSize = function(self, width, height)
		self.width, self.height = width, height
	end,
	GetSize = function(self)
		return self.width, self.height
	end,
	Show = function(self)
		self.visible = true
	end,
	Hide = function(self)
		self.visible = false
	end,
	SetShown = function(self, shown)
		self.visible = shown and true or false
	end,
	IsShown = function(self)
		return self.visible
	end,
	SetAlpha = function(self, alpha)
		self.alpha = alpha
	end,
}

local function Region(kind, methods)
	local region = { kind = kind, points = {}, visible = true, alpha = 1 }

	for name, method in pairs(REGION) do
		region[name] = method
	end

	for name, method in pairs(methods or {}) do
		region[name] = method
	end

	return Strict(region, kind)
end

local function Texture()
	return Region("Texture", {
		SetTexture = function(self, file)
			self.file = file
		end,
		SetBlendMode = function() end,
		SetColorTexture = function(self, r, g, b, a)
			self.color = { r, g, b, a }
		end,
		SetVertexColor = function(self, r, g, b)
			self.vertex = { r, g, b }
		end,
	})
end

local function FontString()
	return Region("FontString", {
		SetWordWrap = function() end,
		SetText = function(self, text)
			self.text = text
		end,
		SetFont = function(self, file, size, flags)
			self.file, self.size, self.flags = file, size, flags
		end,
		SetTextColor = function(self, r, g, b)
			self.textColor = { r, g, b }
		end,
	})
end

local FRAME = {
	CreateTexture = function()
		return Texture()
	end,
	CreateFontString = function()
		return FontString()
	end,
	GetFrameLevel = function(self)
		return self.level
	end,
	SetFrameLevel = function(self, level)
		self.level = level
	end,
	EnableMouse = function() end,
	SetScript = function(self, name, script)
		self.scripts[name] = script
	end,
	RegisterEvent = function(self, event)
		self.events[event] = true
	end,
	UnregisterEvent = function(self, event)
		self.events[event] = nil
	end,
}

local STATUS_BAR = {
	SetMinMaxValues = function() end,
	SetValue = function(self, value)
		self.value, self.timer = value, nil
	end,
	GetStatusBarTexture = function(self)
		return self.fill
	end,
	SetTimerDuration = function(self, duration, _, direction)
		self.timer, self.direction = duration, direction
	end,
}

function CreateFrame(kind, name, parent)
	local methods = {}

	for key, method in pairs(FRAME) do
		methods[key] = method
	end

	if kind == "StatusBar" then
		for key, method in pairs(STATUS_BAR) do
			methods[key] = method
		end
	end

	local frame = Region(kind, methods)

	rawset(frame, "name", name)
	rawset(frame, "parent", parent)
	rawset(frame, "level", 1)
	rawset(frame, "scripts", {})
	rawset(frame, "events", {})

	if kind == "StatusBar" then
		rawset(frame, "fill", Texture())
	end

	frames[#frames + 1] = frame

	-- A module sets fields of its own on its widgets.
	return setmetatable(frame, { __index = function(_, key)
		if key == "SetSize" then
			return nil
		end

		if rawget(frame, "kind") and FRAME[key] == nil and REGION[key] == nil and STATUS_BAR[key] ~= nil then
			error(("%s has no %s"):format(kind, key), 2)
		end
	end })
end

UIParent = CreateFrame("Frame", "UIParent")

-- Addon ---------------------------------------------------------------------------------------------------

local AUI = {}

AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
assert(loadfile(root .. "AeonUI/Core/Core.lua"))("AeonUI", AUI)
AUI.can = { swingTimer = true }

for _, file in ipairs({ "AeonUI/Core/Callbacks.lua", "AeonUI/Core/Events.lua", "AeonUI/Core/Modules.lua",
	"AeonUI/Profile/Schema.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local eventFrame = frames[#frames]
local values = {}

AUI.Profile = {
	Get = function(_, path)
		local value = values[path]

		if value == nil then
			local field = AUI.Schema:Field(path)

			value = field and field.default
		end

		return value
	end,
}

local function Set(path, value)
	values[path] = value
	AUI.Callbacks:Fire("Profile", path)
	Flush()
end

local function Fire(event, ...)
	if eventFrame.events[event] then
		eventFrame.scripts.OnEvent(eventFrame, event, ...)
	end
end

AUI.Border = {
	Create = function()
		return {
			laidOut = 0,
			SetFrameLevel = function() end,
			Apply = function(self, look)
				self.look = look
			end,
			Layout = function(self)
				self.laidOut = self.laidOut + 1
			end,
		}
	end,
}
AUI.Media = {
	Font = function(_, name)
		return "font:" .. name
	end,
	FontFlags = function(_, outline)
		return outline
	end,
	SetBarTexture = function(_, bar, choice)
		rawset(bar, "texture", choice)
	end,
}
AUI.CastBarOptions = { FOREVER_MINIMAL = { minHeight = 16, color = { r = 0.4, g = 0.3, b = 0.2 } } }

for _, file in ipairs({ "AeonUI_UnitFrames/SwingTimer/Options.lua", "AeonUI_UnitFrames/SwingTimer/SwingTimer.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Options, SwingTimer = AUI.SwingTimerOptions, AUI.SwingTimer
local MAIN, OFF, RANGED = 0, 1, 2

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1

	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(name, tostring(expected), tostring(actual)), 2)
	end
end

local function Default(field)
	return AUI.Schema:Field("swingTimer." .. field).default
end

-- Rules ---------------------------------------------------------------------------------------------------

local mainHand, offHand = Options.ROWS[1], Options.ROWS[2]

Equal("the main hand always can swing", Options:Wanted(mainHand, true, nil), true)
Equal("its switch still rules", Options:Wanted(mainHand, false, 2), false)
Equal("an empty off hand shows no row", Options:Wanted(offHand, true, nil), false)
Equal("a weapon does", Options:Wanted(offHand, true, 1.5), true)
Equal("a speed of zero is no weapon", Options:Speed(0), nil)
Equal("a real speed stays", Options:Speed(2.5), 2.5)
Equal("a swing of zero is unusable", Options:Usable(0), false)
Equal("nor infinity", Options:Usable(math.huge), false)
Equal("nor nan", Options:Usable(0 / 0), false)
Equal("nor a non-number", Options:Usable("2"), false)
Equal("a real one is", Options:Usable(2.6), true)
Equal("In Combat hides out of combat", Options:Visible(true, 1, false, "COMBAT", false), false)
Equal("and shows in it", Options:Visible(true, 1, false, "COMBAT", true), true)
Equal("Always shows", Options:Visible(true, 1, false, "ALWAYS", false), true)
Equal("the sample shows", Options:Visible(true, 1, true, "COMBAT", false), true)
Equal("no rows, no frame", Options:Visible(true, 0, true, "ALWAYS", true), false)
Equal("off, no frame", Options:Visible(false, 1, true, "ALWAYS", true), false)
Equal("one row's stack", Options:StackHeight(1, 14, 2), 14)
Equal("no rows still have a size", Options:StackHeight(0, 14, 2), 14)
Equal("three rows' stack", Options:StackHeight(3, 14, 2), 46)
Equal("the second row's place", Options:RowY(2, 14, 2), -16)
Equal("Forever Minimal keeps its least height", Options:DrawnHeight("FOREVER_MINIMAL", 14, 16), 16)
Equal("Thin Line does not", Options:DrawnHeight("THIN_LINE", 14, 16), 14)

Equal("Always Show Rows shows an empty slot", Options:Wanted(offHand, true, nil, true), true)
Equal("not one switched off", Options:Wanted(offHand, false, nil, true), false)
Equal("a shield shows its row", Options:Wanted(offHand, true, nil, false, true), true)
Equal("the off hand merges", Options:Merged(offHand, true, true, true), true)
Equal("not without the main hand", Options:Merged(offHand, true, false, true), false)
Equal("not without a weapon", Options:Merged(offHand, true, true, false), false)
Equal("not with Combine Hands off", Options:Merged(offHand, false, true, true), false)
Equal("the main hand never does", Options:Merged(mainHand, true, true, true), false)
Equal("a shield is one", Options:IsShield("INVTYPE_SHIELD"), true)
Equal("a sword is not", Options:IsShield("INVTYPE_WEAPON"), false)
Equal("Hide When Idle hides between swings", Options:Visible(true, 1, false, "COMBAT", true, true, false), false)
Equal("and shows during one", Options:Visible(true, 1, false, "COMBAT", true, true, true), true)
Equal("Always ignores it", Options:Visible(true, 1, false, "ALWAYS", false, true, false), true)
Equal("the sample ignores it", Options:Visible(true, 1, true, "COMBAT", false, true, false), true)

-- Defaults ------------------------------------------------------------------------------------------------

Equal("off by default", Default("enabled"), false)
Equal("220 wide", Default("width"), 220)
Equal("14 tall", Default("height"), 14)
Equal("spacing 2", Default("spacing"), 2)
Equal("main hand on", Default("showMH"), true)
Equal("off hand opt-in", Default("showOH"), false)
Equal("ranged opt-in", Default("showR"), false)
Equal("fills up", Default("depleteFill"), false)
Equal("spark on", Default("spark"), true)
Equal("Always Show Rows off", Default("alwaysShowRows"), false)
Equal("Show Shield off", Default("shieldRow"), false)
Equal("Combine Hands off", Default("combineHands"), false)
Equal("Hide When Idle off", Default("hideWhenIdle"), false)
Equal("the Aeon Light texture", Default("texture"), "Aeon Light")
Equal("in combat", Default("visibility"), "COMBAT")
Equal("range dim at 40%", Default("outOfRangeAlpha"), 40)
Equal("the outline starts on Slug", Default("outline"), "SLUG")

-- Off -----------------------------------------------------------------------------------------------------

local builtBefore = #frames

SwingTimer:Start()
Flush()
Equal("off builds nothing", #frames, builtBefore)
Equal("off follows no swing", eventFrame.events.PLAYER_SWING, nil)
Equal("off asks for no range", rangeCalls, 0)

AUI.can.swingTimer = false
values["swingTimer.enabled"] = true
SwingTimer:Apply()
Equal("a client without swings stays off", eventFrame.events.PLAYER_SWING, nil)
AUI.can.swingTimer = true
values["swingTimer.enabled"] = nil

-- On ------------------------------------------------------------------------------------------------------

Set("swingTimer.enabled", true)

local frame = SwingTimer.frame
local main, off, ranged = SwingTimer.byType[MAIN], SwingTimer.byType[OFF], SwingTimer.byType[RANGED]

Equal("the root frame is named", frame.name, "AeonUISwingTimer")
Equal("on follows the swings", eventFrame.events.PLAYER_SWING, true)
Equal("a row per swing type", #SwingTimer.rows, 3)
Equal("only the main hand shows", tostring(main:IsShown()) .. tostring(off:IsShown()) .. tostring(ranged:IsShown()),
	"truefalsefalse")
Equal("the frame has a width", frame.width, 220)
Equal("and a height", frame.height, 14)
Equal("out of combat it hides", frame:IsShown(), false)
Equal("placed at the default", frame.points[1][5], -180)
Equal("the main hand's color", main.bar.fill.vertex[1], 0x66 / 255)
Equal("a thin line border", main.edge.look.style, "THIN_LINE")
Equal("range asked for the main hand", rangeFlags[MAIN], true)
Equal("not for the rows off", rangeFlags[OFF], nil)

Fire("PLAYER_REGEN_DISABLED")
Equal("in combat it shows", frame:IsShown(), true)

-- Swings --------------------------------------------------------------------------------------------------

Fire("PLAYER_SWING", 2.6, MAIN)
Equal("a swing runs the fill", main.bar.timer, main.duration)
Equal("from now", main.duration.start, 100)
Equal("for its length", main.duration.length, 2.6)
Equal("filling up", main.bar.direction, Enum.StatusBarTimerDirection.ElapsedTime)
Equal("the time runs", main.binding.enabled, true)
Equal("the spark shows", main.spark:IsShown(), true)

local timer = LastTimer()

Equal("its end waits the grace", timer.seconds, 2.6 + Options.END_GRACE)

now = 102.6
Fire("PLAYER_SWING", 2.4, MAIN)
Equal("the next swing replaces the end", timer.cancelled, true)
Equal("and takes its own length", main.duration.length, 2.4)
timer = LastTimer()
timer.fired = true
timer.callback()
Equal("past the grace the row idles", main.bar.value, 0)
Equal("its timer stops", main.bar.timer, nil)
Equal("its time clears", main.time.text, "")
Equal("its spark hides", main.spark:IsShown(), false)
Equal("and it holds no swing", main.ends, nil)

Fire("PLAYER_SWING", SECRET, MAIN)
Equal("a secret length is no swing", main.ends, nil)
Fire("PLAYER_SWING", 2.6, SECRET)
Equal("nor a secret type", main.ends, nil)
Fire("PLAYER_SWING", 0, MAIN)
Equal("nor a length of zero", main.ends, nil)
Fire("PLAYER_SWING", 2.6, OFF)
Equal("a switched-off row ignores its swing", off.ends, nil)

Set("swingTimer.depleteFill", true)
Fire("PLAYER_SWING", 2.6, MAIN)
Equal("Deplete Fill drains", main.bar.direction, Enum.StatusBarTimerDirection.RemainingTime)
Set("swingTimer.depleteFill", false)
Equal("a setting keeps the swing running", main.bar.timer, main.duration)
Equal("and redirects it", main.bar.direction, Enum.StatusBarTimerDirection.ElapsedTime)

Set("swingTimer.spark", false)
Fire("PLAYER_SWING", 2.6, MAIN)
Equal("no spark when off", main.spark:IsShown(), false)
Set("swingTimer.spark", true)

-- Rows ----------------------------------------------------------------------------------------------------

Set("swingTimer.showOH", true)
Equal("an empty off hand stays hidden", off:IsShown(), false)
speeds[2] = 1.8
Fire("UNIT_ATTACK_SPEED", "target")
Equal("another unit's speed is ignored", off:IsShown(), false)
Fire("UNIT_ATTACK_SPEED", "player")
Equal("a weapon shows the row", off:IsShown(), true)
Equal("the frame grows", frame.height, 30)
Equal("the row sits below", off.points[1][5], -16)

speeds[2] = SECRET
SwingTimer:Refresh()
Equal("a restricted speed keeps the last one", off.speed, 1.8)
Equal("and the row", off:IsShown(), true)
speeds[2] = 1.8

speeds[3] = nil
Set("swingTimer.showR", true)
speeds[3] = SECRET
Equal("no ranged speed, no row", ranged:IsShown(), false)
Fire("PLAYER_SWING", 3, RANGED)
Equal("a swing proves the weapon", ranged:IsShown(), true)
Equal("and runs", ranged.bar.timer, ranged.duration)
speeds[3] = 3
Set("swingTimer.showR", false)
Equal("a row switched off idles", ranged.ends, nil)

-- Always Show Rows, shields, Combine Hands, Hide When Idle ---------------------------------------------------

speeds[2] = nil
Fire("UNIT_ATTACK_SPEED", "player")
Equal("no off hand, no row", off:IsShown(), false)
Equal("no gear watch by default", eventFrame.events.PLAYER_EQUIPMENT_CHANGED, nil)

Set("swingTimer.alwaysShowRows", true)
Equal("Always Show Rows shows it", off:IsShown(), true)
Equal("and takes its place", frame.height, 30)
Equal("and watches the slot", eventFrame.events.PLAYER_EQUIPMENT_CHANGED, true)
Set("swingTimer.alwaysShowRows", false)
Equal("off again it goes", off:IsShown(), false)
Equal("and stops watching", eventFrame.events.PLAYER_EQUIPMENT_CHANGED, nil)

Set("swingTimer.shieldRow", true)
Equal("no shield, no row", off:IsShown(), false)
offHandItem = "shield"
Fire("PLAYER_EQUIPMENT_CHANGED", 5)
Equal("another slot changes nothing", off:IsShown(), false)
Fire("PLAYER_EQUIPMENT_CHANGED", 17)
Equal("a shield shows the row", off:IsShown(), true)
Equal("labeled Shield", off.tag.text, "Shield")
Set("swingTimer.combineHands", true)
Equal("a shield never merges", off.host, nil)
Set("swingTimer.combineHands", false)
offHandItem = nil
Fire("PLAYER_EQUIPMENT_CHANGED", 17)
Equal("taken off, the row goes", off:IsShown(), false)
Equal("and its label returns", off.tag.text, "OH")
Set("swingTimer.shieldRow", false)

speeds[2] = 1.8
Fire("UNIT_ATTACK_SPEED", "player")
Set("swingTimer.combineHands", true)
Equal("the off hand rides the main hand", off.host, main)
Equal("its place is the main hand's", off.points[1][2], main)
Equal("the stack shrinks", frame.height, 14)
Equal("its fill is unseen", off.bar.fill.alpha, 0)
Equal("its background too", off.background.color[4], 0)
Equal("it has no border", off.edge.look.style, "NONE")
Equal("nor label", off.tag:IsShown(), false)
Equal("nor time", off.time:IsShown(), false)
Equal("its spark sits above the main hand's", off.over.level > main.over.level, true)
Equal("in the off hand's color", off.spark.vertex[1], 0xc7 / 255)
Set("swingTimer.spark", false)
Fire("PLAYER_SWING", 1.8, OFF)
Equal("its spark ignores Show Spark", off.spark:IsShown(), true)
Fire("PLAYER_SWING", 2.6, MAIN)
Equal("the main hand's follows it", main.spark:IsShown(), false)
Set("swingTimer.spark", true)
Fire("PLAYER_DEAD")
Equal("idle, its spark hides", off.spark:IsShown(), false)
Set("swingTimer.showMH", false)
Equal("without the main hand it has its own bar", off.host, nil)
Equal("its fill back", off.bar.fill.alpha, 1)
Equal("its border back", off.edge.look.style, "THIN_LINE")
Equal("its label back", off.tag:IsShown(), true)
Set("swingTimer.showMH", true)
Set("swingTimer.combineHands", false)
Equal("off again it stacks", frame.height, 30)
Equal("its spark is white", off.spark.vertex[1], 1)
Set("swingTimer.showOH", false)

Set("swingTimer.hideWhenIdle", true)
Equal("in combat with no swing it hides", frame:IsShown(), false)
Fire("PLAYER_SWING", 2.6, MAIN)
Equal("a swing shows it", frame:IsShown(), true)

local idling = LastTimer()

idling.fired = true
idling.callback()
Equal("past the grace it hides", frame:IsShown(), false)
Fire("PLAYER_SWING", 2.6, MAIN)
Fire("PLAYER_DEAD")
Equal("dying hides it", frame:IsShown(), false)
Set("swingTimer.visibility", "ALWAYS")
Equal("Always ignores it", frame:IsShown(), true)
Set("swingTimer.visibility", "COMBAT")
Set("swingTimer.hideWhenIdle", false)
Set("swingTimer.showOH", true)
Fire("UNIT_ATTACK_SPEED", "player")

-- Weapon swap ---------------------------------------------------------------------------------------------

now = 110
Fire("PLAYER_SWING", 2.6, MAIN)
now = 111
speeds[1] = 3.4
Fire("WEAPON_SLOT_CHANGED")
Equal("a swap restarts the swing", main.duration.start, 111)
Equal("at the new speed", main.duration.length, 3.4)
Equal("an idle row stays idle", off.ends, nil)

Fire("PLAYER_DEAD")
Equal("dying idles the rows", main.ends, nil)

-- Range ---------------------------------------------------------------------------------------------------

Fire("PLAYER_SWING_RANGE_UPDATE", MAIN, false, true)
Equal("out of range dims", main.alpha, 0.4)
Equal("and reddens the text", main.time.textColor[1], Options.FAR_TEXT.r)
Fire("PLAYER_SWING_RANGE_UPDATE", MAIN, true, true)
Equal("in range is whole", main.alpha, 1)
Fire("PLAYER_SWING_RANGE_UPDATE", MAIN, false, false)
Equal("no check possible is whole", main.alpha, 1)
Fire("PLAYER_SWING_RANGE_UPDATE", MAIN, SECRET, true)
Equal("a secret answer is whole", main.alpha, 1)

rangeAnswer[MAIN] = false
Fire("PLAYER_TARGET_CHANGED")
Equal("a new target far away dims", main.alpha, 0.4)
rangeAnswer[MAIN] = nil
Fire("PLAYER_TARGET_CHANGED")
Equal("no target is whole", main.alpha, 1)

rangeFlags[MAIN] = false
Fire("PLAYER_SWING", 2.6, MAIN)
Equal("each swing re-asserts the shared flag", rangeFlags[MAIN], true)

Set("swingTimer.rangeCheck", false)
rangeAnswer[MAIN] = false
SwingTimer:ReadRange(main)
Equal("Range Check off ignores the answer", main.alpha, 1)
Fire("PLAYER_SWING_RANGE_UPDATE", MAIN, false, true)
Equal("and the events", main.alpha, 1)
Set("swingTimer.rangeCheck", true)
rangeAnswer[MAIN] = nil

-- Look ----------------------------------------------------------------------------------------------------

Set("swingTimer.classColor", true)
Equal("Class Color paints the fill", main.bar.fill.vertex[1], 0.78)
Set("swingTimer.classColor", false)
Set("swingTimer.label", false)
Equal("the label hides", main.tag:IsShown(), false)
Set("swingTimer.label", true)
Set("swingTimer.time", false)
Equal("the time hides", main.time:IsShown(), false)
Set("swingTimer.time", true)
Set("swingTimer.borderStyle", "FOREVER_MINIMAL")
Equal("Forever Minimal draws its shaded art", main.edge.look.style, "FOREVER_MINIMAL_SHADED")
Equal("at its least height", main.height, 16)
Equal("the frame follows", frame.height, 32 + 2)
Set("swingTimer.borderStyle", "THIN_LINE")
Set("swingTimer.position", { point = "TOP", x = 5, y = -6 })
Equal("a saved place holds", frame.points[1][1], "TOP")
Equal("its border lays out again", main.edge.laidOut > 0, true)
Set("swingTimer.position", nil)

-- Edit mode -----------------------------------------------------------------------------------------------

Fire("PLAYER_REGEN_ENABLED")
Equal("back out of combat it hides", frame:IsShown(), false)
Fire("PLAYER_SWING", 2.6, MAIN)

local parked = LastTimer()

SwingTimer:Sample(true)
Equal("the sample parks a running swing", parked.cancelled, true)
Equal("the sample shows the frame", frame:IsShown(), true)
Equal("and a still bar", main.bar.value, mainHand.sample)
Equal("with its time", main.time.text, mainHand.sampleTime)
Fire("PLAYER_SWING", 2.6, MAIN)
Equal("a swing does not run under the sample", main.bar.timer, nil)
SwingTimer:Sample(false)
Equal("the sample ends", frame:IsShown(), false)
Equal("the bar is empty again", main.bar.value, 0)

-- Off and on again ----------------------------------------------------------------------------------------

Fire("PLAYER_REGEN_DISABLED")
Fire("PLAYER_SWING", 2.6, MAIN)

local running = LastTimer()

blizzardTimer = true
rangeFlags[MAIN] = true
Set("swingTimer.enabled", false)
Equal("off stops following", eventFrame.events.PLAYER_SWING, nil)
Equal("hides the frame", frame:IsShown(), false)
Equal("cancels the running end", running.cancelled, true)
Equal("and idles the row", main.ends, nil)
Equal("Blizzard's timer keeps its range flag", rangeFlags[MAIN], true)

Set("swingTimer.enabled", true)
Equal("on again follows", eventFrame.events.PLAYER_SWING, true)
Equal("shows in combat", frame:IsShown(), inCombat or frame:IsShown())

local built = #frames

Set("swingTimer.enabled", false)
Set("swingTimer.enabled", true)
Equal("nothing is built twice", #frames, built)

blizzardTimer = false
Set("swingTimer.enabled", false)
Equal("with Blizzard's timer off the flags go off", rangeFlags[MAIN], false)

io.stdout:write(("check_swingtimer: %d checks passed\n"):format(checks))
