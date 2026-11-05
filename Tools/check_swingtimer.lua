-- Checks AeonUI_UnitFrames/SwingTimer/ outside the game: which rows show, nothing built or registered while off, the
-- defaults, swings run from duration objects, secret values read as no information, a row's end and its grace, range
-- edges and the shared flag, a weapon swap, the visibility rules, edit mode's sample and turning off and on again.
-- Run from any directory with Lua 5.1: lua Tools/check_swingtimer.lua
-- Loads the real files against the shared stub client; media and the border are stubbed. This proves logic, never
-- drawing or in-game behavior.
-- Exits non-zero on the first failed check.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"
local client = assert(loadfile(root .. "Tools/stub_client.lua"))({ project = "forever" })
local Equal = client.Equal

-- Environment ---------------------------------------------------------------------------------------------

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

client.now = 100

---Runs what `After` has pending; what `NewTimer` started keeps running.
local function Flush()
	local pending = client.timers

	client.timers = {}

	for _, timer in ipairs(pending) do
		if timer.Cancel then
			client.timers[#client.timers + 1] = timer
		else
			timer.callback(timer)
		end
	end
end

---@return table timer the last timer `NewTimer` started that is still running
local function LastTimer()
	for index = #client.timers, 1, -1 do
		local timer = client.timers[index]

		if timer.Cancel and not timer.cancelled and not timer.fired then
			return timer
		end
	end

	error("no timer is running", 2)
end

local SECRET = client.Secret()

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

local playerClass = "WARRIOR"
function UnitClass()
	return "Warrior", playerClass
end

local moving, worldLatency = false, 80
function IsPlayerMoving()
	return moving
end

function GetNetStats()
	return 0, 0, 0, worldLatency
end

local currentSpells = {}
local SPELL_NAMES = {
	[78] = "Heroic Strike",
	[845] = "Cleave",
	[20154] = "Seal of Righteousness",
	[20375] = "Seal of Command",
	[12294] = "Mortal Strike",
}
C_Spell = {
	GetSpellName = function(id)
		return SPELL_NAMES[id]
	end,
	IsCurrentSpell = function(name)
		return currentSpells[name]
	end,
}

local aurasSecret, auras = false, {}
C_Secrets = { ShouldAurasBeSecret = function()
	return aurasSecret
end }
C_UnitAuras = { GetAuraDataByIndex = function(unit, index, filter)
	assert(unit == "player" and filter == "HELPFUL", filter)

	return auras[index]
end }

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

local eventFrame = client.frames[#client.frames]
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

AUI.Border = {
	SHADOW_SIZE = 4,
	SHADOW_COLOR = { r = 0, g = 0, b = 0, a = 0.618 },
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

local function Near(name, actual, expected)
	Equal(name, math.abs(actual - expected) < 0.001, true)
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
Equal("a running swing outlasts combat", Options:Visible(true, 1, false, "COMBAT", false, false, true), true)
Equal("under Hide When Idle too", Options:Visible(true, 1, false, "COMBAT", false, true, true), true)
Equal("an idle one does not", Options:Visible(true, 1, false, "COMBAT", false, false, false), false)
Equal("no rows hide a running swing", Options:Visible(true, 0, false, "COMBAT", false, false, true), false)
Equal("off hides a running swing", Options:Visible(false, 1, false, "COMBAT", true, false, true), false)
Equal("Always ignores it", Options:Visible(true, 1, false, "ALWAYS", false, true, false), true)
Equal("the sample ignores it", Options:Visible(true, 1, true, "COMBAT", false, true, false), true)

Equal("a queued attack colors a hand row", Options:ColorField(mainHand, "queueColor", "sealLightColor"), "queueColor")
Equal("else its seal", Options:ColorField(offHand, nil, "sealLightColor"), "sealLightColor")
Equal("else its own", Options:ColorField(mainHand, nil, nil), "mhColor")
Equal("never the ranged row", Options:ColorField(Options.ROWS[3], "queueColor", "sealLightColor"), "rColor")
Equal("Cleave has its own color", Options:QueueField(845), "cleaveColor")
Equal("the others share one", Options:QueueField(78), "queueColor")
Equal("a hand row names its attack", Options:TagText(mainHand, "MH", "Cleave"), "MH - Cleave")
Equal("the ranged row does not", Options:TagText(Options.ROWS[3], "R", "Cleave"), "R")

local rangedRow = Options.ROWS[3]

Equal("a melee row's window", Options:WindowSeconds(mainHand, true, 0.4, false, false, 0), 0.4)
Equal("off, none", Options:WindowSeconds(mainHand, false, 0.4, true, true, 0), nil)
Equal("the off hand has one", Options:WindowSeconds(offHand, true, 0.4, false, false, 0), 0.4)
Equal("the ranged row has none without Auto Shot", Options:WindowSeconds(rangedRow, true, 0.4, false, true, 0), nil)
Equal("nor for another class", Options:WindowSeconds(rangedRow, true, 0.4, true, false, 0), nil)
Equal("a hunter's is half a second", Options:WindowSeconds(rangedRow, false, 0.4, true, true, 0), 0.5)
Equal("latency widens it", Options:WindowSeconds(mainHand, true, 0.4, false, false, 0.1), 0.5)
Equal("the window's share of the row", Options:WindowWidth(0.5, 2, 200), 50)
Equal("never past the row", Options:WindowWidth(5, 2, 200), 200)
Equal("never unseen", Options:WindowWidth(0.001, 2, 200), 1)
Equal("filling up it sits right", Options:WindowSide(false), "RIGHT")
Equal("draining it sits left", Options:WindowSide(true), "LEFT")
Equal("melee's color", Options:WindowColor(mainHand, true), "swingWindowColor")
Equal("standing's", Options:WindowColor(rangedRow, false), "autoShotStandColor")
Equal("moving's", Options:WindowColor(rangedRow, true), "autoShotMovingColor")

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
Equal("the swing window off", Default("swingWindow"), false)
Equal("the Auto Shot window off", Default("autoShotWindow"), false)
Equal("Add Latency off", Default("windowLatency"), false)
Equal("a 0.4 second window", Default("swingWindowTime"), 0.4)
Equal("queued attacks on", Default("queueHighlight"), true)
Equal("seal colors on", Default("sealColors"), true)
Equal("every seal has a color", AUI.Schema:Field("swingTimer.sealFuryColor").default.r, 0.95)
Equal("the Aeon Light texture", Default("texture"), "Aeon Light")
Equal("in combat", Default("visibility"), "COMBAT")
Equal("range dim at 40%", Default("outOfRangeAlpha"), 40)
Equal("the outline starts on Slug", Default("outline"), "SLUG")

-- Off -----------------------------------------------------------------------------------------------------

local builtBefore = #client.frames

SwingTimer:Start()
Flush()
Equal("off builds nothing", #client.frames, builtBefore)
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
Equal("the main hand's color", main.bar.statusTexture.vertex[1], 0x66 / 255)
Equal("a thin line border", main.edge.look.style, "THIN_LINE")
Equal("no shadow by default", main.edge.look.shadow, nil)
Equal("range asked for the main hand", rangeFlags[MAIN], true)
Equal("not for the rows off", rangeFlags[OFF], nil)

client:Fire("PLAYER_REGEN_DISABLED")
Equal("in combat it shows", frame:IsShown(), true)

-- Swings --------------------------------------------------------------------------------------------------

client:Fire("PLAYER_SWING", 2.6, MAIN)
Equal("a swing runs the fill", main.bar.timer, main.duration)
Equal("from now", main.duration.start, 100)
Equal("for its length", main.duration.length, 2.6)
Equal("filling up", main.bar.direction, Enum.StatusBarTimerDirection.ElapsedTime)
Equal("the time runs", main.binding.enabled, true)
Equal("the spark shows", main.spark:IsShown(), true)

local timer = LastTimer()

Equal("its end waits the grace", timer.seconds, 2.6 + Options.END_GRACE)

client.now = 102.6
client:Fire("PLAYER_SWING", 2.4, MAIN)
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

client:Fire("PLAYER_SWING", SECRET, MAIN)
Equal("a secret length is no swing", main.ends, nil)
client:Fire("PLAYER_SWING", 2.6, SECRET)
Equal("nor a secret type", main.ends, nil)
client:Fire("PLAYER_SWING", 0, MAIN)
Equal("nor a length of zero", main.ends, nil)
client:Fire("PLAYER_SWING", 2.6, OFF)
Equal("a switched-off row ignores its swing", off.ends, nil)

Set("swingTimer.depleteFill", true)
client:Fire("PLAYER_SWING", 2.6, MAIN)
Equal("Deplete Fill drains", main.bar.direction, Enum.StatusBarTimerDirection.RemainingTime)
Set("swingTimer.depleteFill", false)
Equal("a setting keeps the swing running", main.bar.timer, main.duration)
Equal("and redirects it", main.bar.direction, Enum.StatusBarTimerDirection.ElapsedTime)

Set("swingTimer.spark", false)
client:Fire("PLAYER_SWING", 2.6, MAIN)
Equal("no spark when off", main.spark:IsShown(), false)
Set("swingTimer.spark", true)

-- Rows ----------------------------------------------------------------------------------------------------

Set("swingTimer.showOH", true)
Equal("an empty off hand stays hidden", off:IsShown(), false)
speeds[2] = 1.8
client:Fire("UNIT_ATTACK_SPEED", "target")
Equal("another unit's speed is ignored", off:IsShown(), false)
client:Fire("UNIT_ATTACK_SPEED", "player")
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
client:Fire("PLAYER_SWING", 3, RANGED)
Equal("a swing proves the weapon", ranged:IsShown(), true)
Equal("and runs", ranged.bar.timer, ranged.duration)
speeds[3] = 3
Set("swingTimer.showR", false)
Equal("a row switched off idles", ranged.ends, nil)

-- Always Show Rows, shields, Combine Hands, Hide When Idle ---------------------------------------------------

speeds[2] = nil
client:Fire("UNIT_ATTACK_SPEED", "player")
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
client:Fire("PLAYER_EQUIPMENT_CHANGED", 5)
Equal("another slot changes nothing", off:IsShown(), false)
client:Fire("PLAYER_EQUIPMENT_CHANGED", 17)
Equal("a shield shows the row", off:IsShown(), true)
Equal("labeled Shield", off.tag.text, "Shield")
Set("swingTimer.combineHands", true)
Equal("a shield never merges", off.host, nil)
Set("swingTimer.combineHands", false)
offHandItem = nil
client:Fire("PLAYER_EQUIPMENT_CHANGED", 17)
Equal("taken off, the row goes", off:IsShown(), false)
Equal("and its label returns", off.tag.text, "OH")
Set("swingTimer.shieldRow", false)

speeds[2] = 1.8
client:Fire("UNIT_ATTACK_SPEED", "player")
Set("swingTimer.combineHands", true)
Equal("the off hand rides the main hand", off.host, main)
Equal("its place is the main hand's", off.points[1][2], main)
Equal("the stack shrinks", frame.height, 14)
Equal("its fill is unseen", off.bar.statusTexture.alpha, 0)
Equal("its background too", off.background.color[4], 0)
Equal("it has no border", off.edge.look.style, "NONE")
Equal("and no shadow", off.edge.look.shadow, nil)
Set("swingTimer.showShadow", true)
Equal("a riding row has none with Show Shadow on", off.edge.look.shadow, nil)
Equal("its host has it", main.edge.look.shadow.size, 4)
Set("swingTimer.showShadow", false)
Equal("off takes it away", main.edge.look.shadow, nil)
Equal("nor label", off.tag:IsShown(), false)
Equal("nor time", off.time:IsShown(), false)
Equal("its spark sits above the main hand's", off.over.level > main.over.level, true)
Equal("in the off hand's color", off.spark.vertex[1], 0xc7 / 255)
Set("swingTimer.spark", false)
client:Fire("PLAYER_SWING", 1.8, OFF)
Equal("its spark ignores Show Spark", off.spark:IsShown(), true)
client:Fire("PLAYER_SWING", 2.6, MAIN)
Equal("the main hand's follows it", main.spark:IsShown(), false)
Set("swingTimer.spark", true)
client:Fire("PLAYER_DEAD")
Equal("idle, its spark hides", off.spark:IsShown(), false)
Set("swingTimer.showMH", false)
Equal("without the main hand it has its own bar", off.host, nil)
Equal("its fill back", off.bar.statusTexture.alpha, 1)
Equal("its border back", off.edge.look.style, "THIN_LINE")
Equal("its label back", off.tag:IsShown(), true)
Set("swingTimer.showMH", true)
Set("swingTimer.combineHands", false)
Equal("off again it stacks", frame.height, 30)
Equal("its spark is white", off.spark.vertex[1], 1)
Set("swingTimer.showOH", false)

Set("swingTimer.hideWhenIdle", true)
Equal("in combat with no swing it hides", frame:IsShown(), false)
client:Fire("PLAYER_SWING", 2.6, MAIN)
Equal("a swing shows it", frame:IsShown(), true)

local idling = LastTimer()

idling.fired = true
idling.callback()
Equal("past the grace it hides", frame:IsShown(), false)
client:Fire("PLAYER_SWING", 2.6, MAIN)
client:Fire("PLAYER_DEAD")
Equal("dying hides it", frame:IsShown(), false)
Set("swingTimer.visibility", "ALWAYS")
Equal("Always ignores it", frame:IsShown(), true)
Set("swingTimer.visibility", "COMBAT")
Set("swingTimer.hideWhenIdle", false)
Set("swingTimer.showOH", true)
client:Fire("UNIT_ATTACK_SPEED", "player")

-- Queued attacks ------------------------------------------------------------------------------------------

Equal("a warrior watches the action bars", eventFrame.events.ACTIONBAR_UPDATE_STATE, true)
Equal("not its seals", eventFrame.events.UNIT_AURA, nil)
currentSpells["Heroic Strike"] = true
client:Fire("ACTIONBAR_UPDATE_STATE")
Flush()
Equal("a queued attack colors the main hand", main.bar.statusTexture.vertex[1], 1)
Equal("and the off hand", off.bar.statusTexture.vertex[1], 1)
Equal("not the ranged row", ranged.bar.statusTexture.vertex[1], 0.3)
Equal("and names itself", main.tag.text, "MH - Heroic Strike")
currentSpells["Heroic Strike"] = nil
client:Fire("PLAYER_SWING", 2.6, MAIN)
Equal("the swing that lands it clears it", main.bar.statusTexture.vertex[1], 0x66 / 255)
Equal("and its name", main.tag.text, "MH")
currentSpells.Cleave = true
client:Fire("ACTIONBAR_UPDATE_STATE")
Flush()
Equal("Cleave takes its own color", main.bar.statusTexture.vertex[1], 0.97)
currentSpells.Cleave = SECRET
client:Fire("ACTIONBAR_UPDATE_STATE")
Flush()
Equal("a secret answer is no attack", main.tag.text, "MH")
currentSpells.Cleave = nil
Set("swingTimer.queueHighlight", false)
Equal("off stops watching", eventFrame.events.ACTIONBAR_UPDATE_STATE, nil)
currentSpells["Heroic Strike"] = true
client:Fire("PLAYER_SWING", 2.6, MAIN)
Equal("and colors nothing", main.tag.text, "MH")
currentSpells["Heroic Strike"] = nil
Set("swingTimer.queueHighlight", true)
Equal("on again it watches", eventFrame.events.ACTIONBAR_UPDATE_STATE, true)
Set("swingTimer.classColor", true)
currentSpells.Cleave = true
client:Fire("ACTIONBAR_UPDATE_STATE")
Flush()
Equal("a queued attack beats Class Color", main.bar.statusTexture.vertex[1], 0.97)
currentSpells.Cleave = nil
client:Fire("ACTIONBAR_UPDATE_STATE")
Flush()
Equal("Class Color returns", main.bar.statusTexture.vertex[1], 0.78)
Set("swingTimer.classColor", false)

-- Seals ---------------------------------------------------------------------------------------------------

Set("swingTimer.enabled", false)
Equal("off drops the attack watch", eventFrame.events.ACTIONBAR_UPDATE_STATE, nil)
playerClass = "PALADIN"
Set("swingTimer.enabled", true)
Equal("a paladin has no attack to watch", eventFrame.events.ACTIONBAR_UPDATE_STATE, nil)
Equal("it watches its casts", eventFrame.events.UNIT_SPELLCAST_SUCCEEDED, true)
Equal("and its buffs", eventFrame.events.UNIT_AURA, true)

inCombat = false
client:Fire("PLAYER_REGEN_ENABLED")
auras[1] = { name = "Blessing" }
auras[2] = { name = "Seal of Command", duration = 34, expirationTime = client.now + 20 }
client:Fire("UNIT_AURA", "target")
Flush()
Equal("another unit's buffs are ignored", main.bar.statusTexture.vertex[1], 0x66 / 255)
client:Fire("UNIT_AURA", "player")
Flush()
Equal("a seal up colors the hands", main.bar.statusTexture.vertex[1], 0.75)
Equal("not the ranged row", ranged.bar.statusTexture.vertex[1], 0.3)
Equal("its label stays", main.tag.text, "MH")
Equal("its buff says when it ends", LastTimer().seconds, 20)
Equal("and how long seals last", SwingTimer.sealSeconds, 34)

auras = {}
client:Fire("UNIT_AURA", "player")
Flush()
Equal("a seal gone clears it", main.bar.statusTexture.vertex[1], 0x66 / 255)

client:Fire("PLAYER_REGEN_DISABLED")
client:Fire("UNIT_SPELLCAST_SUCCEEDED", "target", "guid", 20154)
Equal("another unit's cast is ignored", main.bar.statusTexture.vertex[1], 0x66 / 255)
client:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 12294)
Equal("another spell too", main.bar.statusTexture.vertex[1], 0x66 / 255)
client:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", SECRET)
Equal("a secret spell too", main.bar.statusTexture.vertex[1], 0x66 / 255)
client:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 20154)
Equal("a seal cast in combat colors the hands", main.bar.statusTexture.vertex[1], 0.95)
Equal("for as long as seals last", LastTimer().seconds, 34)

auras[1] = { name = "Seal of Command", duration = 30, expirationTime = client.now + 30 }
client:Fire("UNIT_AURA", "player")
Flush()
Equal("buffs are not read in combat", main.bar.statusTexture.vertex[1], 0.95)
auras = {}

local sealEnd = LastTimer()

sealEnd.fired = true
sealEnd.callback()
Equal("it runs out", main.bar.statusTexture.vertex[1], 0x66 / 255)

client:Fire("PLAYER_REGEN_ENABLED")
aurasSecret = true
auras[1] = { name = "Seal of Command" }
client:Fire("UNIT_AURA", "player")
Flush()
Equal("secret auras are not read", main.bar.statusTexture.vertex[1], 0x66 / 255)
aurasSecret = false
auras[1] = { name = SECRET }
client:Fire("UNIT_AURA", "player")
Flush()
Equal("nor a secret name", main.bar.statusTexture.vertex[1], 0x66 / 255)
auras[1] = { name = "Seal of Command" }
client:Fire("UNIT_AURA", "player")
Flush()
Equal("a buff with no times still colors", main.bar.statusTexture.vertex[1], 0.75)

Set("swingTimer.sealColors", false)
Equal("off stops watching casts", eventFrame.events.UNIT_SPELLCAST_SUCCEEDED, nil)
Equal("and buffs", eventFrame.events.UNIT_AURA, nil)
Equal("and clears the color", main.bar.statusTexture.vertex[1], 0x66 / 255)
Set("swingTimer.sealColors", true)
Equal("on again it reads the seal up", main.bar.statusTexture.vertex[1], 0.75)

client:Fire("PLAYER_REGEN_DISABLED")
client:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 20154)

local sealRunning = LastTimer()

auras = {}
Set("swingTimer.enabled", false)
Equal("turning off cancels the seal's end", sealRunning.cancelled, true)
playerClass = "WARRIOR"
client:Fire("PLAYER_REGEN_ENABLED")
Set("swingTimer.enabled", true)
Equal("the seal is gone", main.bar.statusTexture.vertex[1], 0x66 / 255)
client:Fire("PLAYER_REGEN_DISABLED")

-- Windows -------------------------------------------------------------------------------------------------

Equal("a warrior watches no movement", eventFrame.events.PLAYER_STARTED_MOVING, nil)
client:Fire("PLAYER_SWING", 2, MAIN)
Equal("no window by default", main.window:IsShown(), false)
Set("swingTimer.swingWindow", true)
Equal("on, a running swing shades its end", main.window:IsShown(), true)
Near("its share of the row", main.window.width, 220 * 0.4 / 2)
Equal("at the end the swing lands on", main.window.points[1][1], "TOPRIGHT")
Equal("in its color", main.window.color[4], 0.35)
Equal("an idle row has none", off.window:IsShown(), false)
Set("swingTimer.depleteFill", true)
Equal("draining, the other end", main.window.points[1][1], "TOPLEFT")
Set("swingTimer.depleteFill", false)
Set("swingTimer.width", 110)
Near("it follows the width", main.window.width, 110 * 0.4 / 2)
Set("swingTimer.width", 220)
Set("swingTimer.windowLatency", true)
client:Fire("PLAYER_SWING", 2, MAIN)
Near("Add Latency widens it", main.window.width, 220 * 0.48 / 2)
worldLatency = SECRET
client:Fire("PLAYER_SWING", 2, MAIN)
Near("a secret latency adds nothing", main.window.width, 220 * 0.4 / 2)
worldLatency = 80
Set("swingTimer.windowLatency", false)

Set("swingTimer.combineHands", true)
client:Fire("PLAYER_SWING", 2, OFF)
Equal("a row riding another has no window", off.window:IsShown(), false)
Equal("the main hand keeps its own", main.window:IsShown(), true)
Set("swingTimer.combineHands", false)
client:Fire("PLAYER_DEAD")
Equal("idle, it hides", main.window:IsShown(), false)
Set("swingTimer.swingWindow", false)

Set("swingTimer.enabled", false)
playerClass = "HUNTER"
moving = true
Set("swingTimer.enabled", true)
Equal("a hunter watches no movement until asked", eventFrame.events.PLAYER_STARTED_MOVING, nil)
Set("swingTimer.autoShotWindow", true)
Equal("then it does", eventFrame.events.PLAYER_STARTED_MOVING, true)
moving = false
Set("swingTimer.showR", true)
client:Fire("PLAYER_SWING", 3, RANGED)
Near("Auto Shot's cast shades the end", ranged.window.width, 220 * 0.5 / 3)
client:Fire("PLAYER_STARTED_MOVING")
Equal("moving turns it red", ranged.window.color[1], 0.95)
client:Fire("PLAYER_STOPPED_MOVING")
Equal("standing turns it green", ranged.window.color[1], 0.30)
Equal("a melee row has none", main.window:IsShown(), false)
Set("swingTimer.autoShotWindow", false)
Equal("off stops watching", eventFrame.events.PLAYER_STARTED_MOVING, nil)
Equal("and hides it", ranged.window:IsShown(), false)
Set("swingTimer.showR", false)

Set("swingTimer.autoShotWindow", true)
Set("swingTimer.swingWindow", true)
client:Fire("PLAYER_REGEN_ENABLED")
SwingTimer:Sample(true)
Equal("the sample shows the swing window", main.window:IsShown(), true)
Near("at the sample's length", main.window.width, 220 * 0.4 / Options.SAMPLE_SWING)
SwingTimer:Sample(false)
Equal("and hides it after", main.window:IsShown(), false)
Set("swingTimer.autoShotWindow", false)
Set("swingTimer.swingWindow", false)
Set("swingTimer.enabled", false)
playerClass = "WARRIOR"
Set("swingTimer.enabled", true)
client:Fire("PLAYER_REGEN_DISABLED")

-- Weapon swap ---------------------------------------------------------------------------------------------

client.now = 110
client:Fire("PLAYER_SWING", 2.6, MAIN)
client.now = 111
speeds[1] = 3.4
client:Fire("WEAPON_SLOT_CHANGED")
Equal("a swap restarts the swing", main.duration.start, 111)
Equal("at the new speed", main.duration.length, 3.4)
Equal("an idle row stays idle", off.ends, nil)

client:Fire("PLAYER_DEAD")
Equal("dying idles the rows", main.ends, nil)

-- Range ---------------------------------------------------------------------------------------------------

client:Fire("PLAYER_SWING_RANGE_UPDATE", MAIN, false, true)
Equal("out of range dims", main.alpha, 0.4)
Equal("and reddens the text", main.time.textColor[1], Options.FAR_TEXT.r)
client:Fire("PLAYER_SWING_RANGE_UPDATE", MAIN, true, true)
Equal("in range is whole", main.alpha, 1)
client:Fire("PLAYER_SWING_RANGE_UPDATE", MAIN, false, false)
Equal("no check possible is whole", main.alpha, 1)
client:Fire("PLAYER_SWING_RANGE_UPDATE", MAIN, SECRET, true)
Equal("a secret answer is whole", main.alpha, 1)

rangeAnswer[MAIN] = false
client:Fire("PLAYER_TARGET_CHANGED")
Equal("a new target far away dims", main.alpha, 0.4)
rangeAnswer[MAIN] = nil
client:Fire("PLAYER_TARGET_CHANGED")
Equal("no target is whole", main.alpha, 1)

rangeFlags[MAIN] = false
client:Fire("PLAYER_SWING", 2.6, MAIN)
Equal("each swing re-asserts the shared flag", rangeFlags[MAIN], true)

Set("swingTimer.rangeCheck", false)
rangeAnswer[MAIN] = false
SwingTimer:ReadRange(main)
Equal("Range Check off ignores the answer", main.alpha, 1)
client:Fire("PLAYER_SWING_RANGE_UPDATE", MAIN, false, true)
Equal("and the events", main.alpha, 1)
Set("swingTimer.rangeCheck", true)
rangeAnswer[MAIN] = nil

-- Look ----------------------------------------------------------------------------------------------------

Set("swingTimer.classColor", true)
Equal("Class Color paints the fill", main.bar.statusTexture.vertex[1], 0.78)
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

client:Fire("PLAYER_SWING", 2.6, MAIN)
client:Fire("PLAYER_REGEN_ENABLED")
Equal("a swing still running outlasts combat", frame:IsShown(), true)

local charging = LastTimer()

charging.fired = true
charging.callback()
Equal("back out of combat it hides when the swing ends", frame:IsShown(), false)
client:Fire("PLAYER_REGEN_DISABLED")
client:Fire("PLAYER_REGEN_ENABLED")
Equal("with no swing running it hides at combat's end", frame:IsShown(), false)
client:Fire("PLAYER_SWING", 2.6, MAIN)

local parked = LastTimer()

SwingTimer:Sample(true)
Equal("the sample parks a running swing", parked.cancelled, true)
Equal("the sample shows the frame", frame:IsShown(), true)
Equal("and a still bar", main.bar.value, mainHand.sample)
Equal("with its time", main.time.text, mainHand.sampleTime)
client:Fire("PLAYER_SWING", 2.6, MAIN)
Equal("a swing does not run under the sample", main.bar.timer, nil)
SwingTimer:Sample(false)
Equal("the sample ends", frame:IsShown(), false)
Equal("the bar is empty again", main.bar.value, 0)

-- Off and on again ----------------------------------------------------------------------------------------

client:Fire("PLAYER_REGEN_DISABLED")
client:Fire("PLAYER_SWING", 2.6, MAIN)

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

local built = #client.frames

Set("swingTimer.enabled", false)
Set("swingTimer.enabled", true)
Equal("nothing is built twice", #client.frames, built)

blizzardTimer = false
Set("swingTimer.enabled", false)
Equal("with Blizzard's timer off the flags go off", rangeFlags[MAIN], false)

io.stdout:write(("check_swingtimer: %d checks passed\n"):format(client.checks))
