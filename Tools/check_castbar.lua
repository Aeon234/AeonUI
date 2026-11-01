-- Checks CastBar/ outside the game: which duration a cast is drawn from and the way its fill runs, and when the bar
-- shows; then nothing built and Blizzard's bar left alone while off, the bar's look and place, casts, channels and
-- empowered casts drawn from duration objects (secret ones too), the not-interruptible cover, other units ignored,
-- pet battles, the edit-mode sample, a saved place, Blizzard's bar parked and kept parked (after a reparent, past
-- combat and Edit Mode) and handed back when turned off, and turning it on again.
-- Run from any directory with Lua 5.1: lua Tools/check_castbar.lua
-- Loads the real files against stubbed globals; the border and media are stubbed. Widgets are modeled by type and
-- fail on a method their type lacks.
-- Exits non-zero on the first failed check.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

WOW_PROJECT_ID = 1
SlashCmdList = {}
StaticPopupDialogs = {}
C_AddOns = {
	GetAddOnMetadata = function(_, field)
		return field == "Version" and "dev" or "AeonUI"
	end,
}

local errors = {}
function CallErrorHandler(message)
	errors[#errors + 1] = message
end

-- WoW's xpcall forwards extra arguments to the function, as Lua 5.2 does; Lua 5.1's does not.
local luaXpcall = xpcall
function xpcall(fn, handler, ...)
	local count, args = select("#", ...), { ... }

	return luaXpcall(function()
		return fn(unpack(args, 1, count))
	end, handler)
end

local timers = {}
C_Timer = { After = function(_, callback)
	timers[#timers + 1] = callback
end }

local function RunTimers()
	local pending = timers

	timers = {}

	for _, callback in ipairs(pending) do
		callback()
	end
end

local secrets = {}
function issecretvalue(value)
	return secrets[value] == true
end

local function Secret(value)
	secrets[value] = true

	return value
end

function hooksecurefunc(object, method, hook)
	local original = object[method]

	object[method] = function(...)
		local results = { original(...) }

		hook(...)

		return unpack(results)
	end
end

function CreateColor(r, g, b, a)
	return { r = r, g = g, b = b, a = a }
end

PixelUtil = { GetPixelToUIUnitFactor = function()
	return 0.5
end }

Enum = {
	StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 },
	StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 },
	DurationTextBindingProperty = { RemainingDuration = 0 },
}

local formatters = {}
C_StringUtil = { CreateNumericRuleFormatter = function()
	local formatter = {}
	formatter.SetBreakpoints = function(self, breakpoints)
		self.breakpoints = breakpoints
	end
	formatters[#formatters + 1] = formatter

	return formatter
end }

C_DurationUtil = { CreateDurationTextBinding = function()
	local binding = { enabled = true }
	binding.SetFontString = function(self, region)
		self.region = region
	end
	binding.SetTextFormat = function(self, format, components)
		self.format, self.components = format, components
	end
	binding.SetEnabled = function(self, enabled)
		self.enabled = enabled
	end
	binding.SetDuration = function(self, duration)
		self.duration = duration
	end

	return binding
end }

---A widget of one type: calling a method its type lacks fails, as calling a nil field does.
local function Strict(object, kind)
	object.widgetType = kind

	return object
end

local function Region(kind)
	local region = { shown = true, points = {} }
	region.SetAllPoints = function(self, target)
		self.allPoints = target or true
	end
	region.ClearAllPoints = function(self)
		self.points = {}
	end
	region.SetPoint = function(self, point, relative, relativePoint, x, y)
		self.points[#self.points + 1] = { point, relative, relativePoint, x, y }
	end
	region.SetSize = function(self, width, height)
		self.width, self.height = width, height
	end
	region.Show = function(self)
		self.shown = true
	end
	region.Hide = function(self)
		self.shown = false
	end
	region.IsShown = function(self)
		return self.shown
	end

	return Strict(region, kind)
end

local function Texture()
	local texture = Region("Texture")
	texture.SetTexture = function(self, file)
		self.file = file
	end
	texture.SetColorTexture = function(self, r, g, b, a)
		self.color = { r, g, b, a }
	end
	texture.SetBlendMode = function(self, mode)
		self.blend = mode
	end
	texture.SetGradient = function(self, orientation, first, last)
		self.gradient = { orientation, first, last }
	end

	return texture
end

local function FontString()
	local text = Region("FontString")
	text.SetFont = function(self, file, size, flags)
		self.font, self.size, self.flags = file, size, flags
	end
	text.SetShadowColor = function(self, r, g, b, a)
		self.shadow = { r, g, b, a }
	end
	text.SetShadowOffset = function(self, x, y)
		self.shadowOffset = { x, y }
	end
	text.SetWordWrap = function(self, wrap)
		self.wrap = wrap
	end
	text.SetJustifyH = function(self, justify)
		self.justify = justify
	end
	text.SetText = function(self, value)
		self.text = value
	end

	return text
end

local frames = {}

local function Frame(kind, name, parent)
	local frame = Region(kind)
	frame.name, frame.parent, frame.scripts, frame.events, frame.level, frame.alpha = name, parent, {}, {}, 1, 1
	frame.IsVisible = function(self)
		local parentFrame = self.parent

		return self.shown and (parentFrame == nil or parentFrame.IsVisible == nil or parentFrame:IsVisible())
	end
	frame.GetParent = function(self)
		return self.parent
	end
	frame.SetParent = function(self, newParent)
		self.parent = newParent
	end
	frame.SetFrameStrata = function(self, strata)
		self.strata = strata
	end
	frame.SetFrameLevel = function(self, level)
		self.level = level
	end
	frame.GetFrameLevel = function(self)
		return self.level
	end
	frame.EnableMouse = function(self, enabled)
		self.mouse = enabled
	end
	frame.SetAlpha = function(self, alpha)
		self.alpha = alpha
	end
	frame.SetAlphaFromBoolean = function(self, flag, shown, hidden)
		self.alphaFlag = flag
		self.alpha = secrets[flag] and "secret" or (flag and shown or hidden)
	end
	frame.GetEffectiveScale = function()
		return 1
	end
	frame.SetScript = function(self, script, handler)
		self.scripts[script] = handler
	end
	frame.CreateTexture = function()
		return Texture()
	end
	frame.CreateFontString = function()
		return FontString()
	end
	frame.RegisterEvent = function(self, event)
		self.events[event] = true
	end
	frame.UnregisterEvent = function(self, event)
		self.events[event] = nil
	end

	if kind == "StatusBar" then
		frame.fill = Texture()
		frame.SetStatusBarTexture = function(self, file)
			self.fill.file = file
		end
		frame.GetStatusBarTexture = function(self)
			return self.fill
		end
		frame.SetMinMaxValues = function(self, low, high)
			self.min, self.max = low, high
		end
		frame.SetValue = function(self, value)
			self.value, self.timer = value, nil
		end
		frame.SetTimerDuration = function(self, duration, interpolation, direction)
			self.timer, self.interpolation, self.direction = duration, interpolation, direction
		end
	end

	frames[#frames + 1] = frame

	return frame
end

function CreateFrame(kind, name, parent)
	assert(kind == "Frame" or kind == "StatusBar", "unexpected frame " .. tostring(kind))

	return Frame(kind, name, parent)
end

UIParent = Frame("Frame", "UIParent")

local combat = false
function InCombatLockdown()
	return combat
end

local editModeCallbacks = {}
EventRegistry = { RegisterCallback = function(_, event, callback)
	editModeCallbacks[event] = callback
end }
EditModeManagerFrame = Frame("Frame", "EditModeManagerFrame", UIParent)
EditModeManagerFrame:Hide()

local playerFrame = Frame("Frame", "PlayerFrame", UIParent)
PlayerCastingBarFrame = Frame("StatusBar", "PlayerCastingBarFrame", UIParent)
PlayerCastingBarFrame.Selection = Frame("Frame", nil, PlayerCastingBarFrame)

local inPetBattle = false
C_PetBattles = { IsInBattle = function()
	return inPetBattle
end }

local cast, channel
local castDuration, channelDuration, empoweredDuration
local holdArgument
function UnitCastingInfo(unit)
	assert(unit == "player")

	if cast then
		return cast.name, cast.display, 136243, 1000, 2500, false, "Cast-1", cast.locked, 133, nil, cast.delay or 0
	end
end
function UnitChannelInfo(unit)
	assert(unit == "player")

	if channel then
		return channel.name, channel.display, 136243, 1000, 4000, false, channel.locked, 15407, channel.empowered,
			channel.empowered and 3 or 0, nil
	end
end
function UnitCastingDuration()
	return castDuration
end
function UnitChannelDuration()
	return channelDuration
end
function UnitEmpoweredChannelDuration(_, includeHold)
	holdArgument = includeHold

	return empoweredDuration
end

-- Addon table ---------------------------------------------------------------------------------------------

local AUI = {}
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
assert(loadfile(root .. "Core/Core.lua"))("AeonUI", AUI)
AUI.can = { castBar = true, petBattles = true }

for _, file in ipairs({ "Core/Callbacks.lua", "Core/Events.lua", "Profile/Schema.lua" }) do
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
	RunTimers()
end

local function Fire(event, ...)
	if eventFrame.events[event] then
		eventFrame.scripts.OnEvent(eventFrame, event, ...)
	end
end

local borders = {}
AUI.Border = { Create = function(_, owner)
	local border = { owner = owner }
	border.Apply = function(self, look)
		self.look = look
	end
	borders[#borders + 1] = border

	return border
end }
AUI.Media = {
	FLAT = "flat",
	Font = function(_, name)
		return "font:" .. name
	end,
	SetBarTexture = function(_, bar, choice)
		bar.texture = choice
	end,
}

for _, file in ipairs({ "CastBar/Options.lua", "CastBar/BlizzardBar.lua", "CastBar/CastBar.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Options, CastBar, BlizzardBar = AUI.CastBarOptions, AUI.CastBar, AUI.CastBarBlizzard

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

local function Point(region)
	local point = region.points[#region.points]

	return ("%s %s %s"):format(point[1], tostring(point[4]), tostring(point[5]))
end

-- Rules ---------------------------------------------------------------------------------------------------

local KINDS = Options.KINDS
Equal("a cast", Options:Kind(true, false, false), KINDS.CAST)
Equal("a channel", Options:Kind(false, true, false), KINDS.CHANNEL)
Equal("an empowered cast", Options:Kind(false, true, true), KINDS.EMPOWERED)
Equal("nothing cast", Options:Kind(false, false, false), nil)
Equal("a cast fills", Options:Drains(KINDS.CAST), false)
Equal("so does an empowered cast", Options:Drains(KINDS.EMPOWERED), false)
Equal("a channel drains", Options:Drains(KINDS.CHANNEL), true)
Equal("off, never shown", Options:Visible(false, true, true, false), false)
Equal("idle, hidden", Options:Visible(true, false, false, false), false)
Equal("casting, shown", Options:Visible(true, true, false, false), true)
Equal("not in a pet battle", Options:Visible(true, true, false, true), false)
Equal("the sample shows without a cast", Options:Visible(true, false, true, true), true)
Equal("off by default", AUI.Schema:Field(Options.ENABLED_PATH).default, false)
Equal("no saved place at first", AUI.Profile:Get(Options.POSITION_PATH), nil)

-- Off -----------------------------------------------------------------------------------------------------

CastBar:Start()
CastBar:Start()
Equal("nothing built while off", CastBar.frame, nil)
Equal("no cast event followed", eventFrame.events.UNIT_SPELLCAST_START, nil)
Equal("Blizzard's bar left alone", PlayerCastingBarFrame.parent, UIParent)
Equal("and its selection", PlayerCastingBarFrame.Selection.alpha, 1)
Equal("no hook installed", BlizzardBar.hooked, false)

-- On ------------------------------------------------------------------------------------------------------

PlayerCastingBarFrame:SetParent(playerFrame)
Set(Options.ENABLED_PATH, true)
local frame = CastBar.frame --[[@as table]]
Equal("the root frame is named", frame.name, "AeonUICastBar")
Equal("its size", frame.width .. "x" .. frame.height, "386x16")
Equal("at the default place", Point(frame), "CENTER 0 -254")
Equal("taking no clicks", frame.mouse, false)
Equal("hidden while nothing is cast", frame.shown, false)
Equal("a thin black line outside, white at half opacity inside", borders[1].look.style .. " "
	.. borders[1].look.color.r .. " " .. borders[1].look.background.a, "THIN_LINE 0 0.5")
Equal("one pixel out", Point(frame.edge), "BOTTOMRIGHT 0.5 -0.5")
Equal("the flat fill", frame.bar.texture, "flat")
local gradient = frame.bar.fill.gradient
Equal("a horizontal gradient", gradient[1] .. " " .. gradient[2].g .. " " .. gradient[3].g, "HORIZONTAL 0.71 0.682")
Equal("the red cover hidden", frame.locked.alpha, 0)
Equal("the spark rides the fill's edge", frame.spark.points[1][2] == frame.bar.fill and frame.spark.points[1][3],
	"RIGHT")
Equal("additive", frame.spark.blend, "ADD")
Equal("the text above the cover", frame.over.level > frame.locked.level, true)
Equal("Expressway 14, no outline", frame.text.font .. " " .. frame.text.size .. " [" .. frame.text.flags .. "]",
	"font:Expressway 14 []")
Equal("with a shadow", frame.time.shadowOffset[1] .. "," .. frame.time.shadowOffset[2], "1,-1")
Equal("the name never wraps", frame.text.wrap, false)
Equal("and stops short of the time", frame.text.points[2][2], frame.time)
Equal("the time to one decimal", formatters[1].breakpoints[1].format, "%.1f")
Equal("written by the binding", frame.binding.region, frame.time)
Equal("as the remaining time", frame.binding.components[1].property, 0)
Equal("the binding idle", frame.binding.enabled, false)
Equal("Blizzard's bar parked", PlayerCastingBarFrame.parent, BlizzardBar.hidden)
Equal("in a hidden parent", BlizzardBar.hidden.shown, false)
Equal("its selection hidden", PlayerCastingBarFrame.Selection.alpha .. " " .. tostring(
	PlayerCastingBarFrame.Selection.mouse), "0 false")
Equal("every cast event followed", eventFrame.events.UNIT_SPELLCAST_EMPOWER_UPDATE
	and eventFrame.events.UNIT_SPELLCAST_NOT_INTERRUPTIBLE and eventFrame.events.PET_BATTLE_CLOSE, true)

-- Casts ---------------------------------------------------------------------------------------------------

cast, castDuration = { name = "Fireball", display = "Fireball", locked = false }, {}
Fire("UNIT_SPELLCAST_START", "player", "Cast-1", 133)
Equal("a cast shows", frame.shown, true)
Equal("its fill runs on the cast's duration", frame.bar.timer, castDuration)
Equal("filling as it runs", frame.bar.direction, Enum.StatusBarTimerDirection.ElapsedTime)
Equal("smooth", frame.bar.interpolation, Enum.StatusBarInterpolation.Immediate)
Equal("the time from the same duration", frame.binding.duration, castDuration)
Equal("updating", frame.binding.enabled, true)
Equal("the spell's name", frame.text.text, "Fireball")
Equal("interruptible", frame.locked.alpha, 0)

cast.locked = true
Fire("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "player")
Equal("not interruptible turns it red", frame.locked.alpha, 1)

Fire("UNIT_SPELLCAST_START", "target")
cast = nil
Fire("UNIT_SPELLCAST_STOP", "target")
Equal("another unit's events are ignored", frame.shown, true)

cast = { name = Secret("Frostbolt"), display = Secret("Frostbolt"), locked = Secret(true) }
castDuration = Secret({})
Fire("UNIT_SPELLCAST_START", "player")
Equal("a secret cast still shows", frame.shown, true)
Equal("its duration passed on", frame.bar.timer, castDuration)
Equal("its name passed on", frame.text.text, cast.display)
Equal("a secret flag sets the cover through the client", frame.locked.alpha, "secret")

cast, castDuration = nil, nil
Fire("UNIT_SPELLCAST_STOP", "player")
Equal("a finished cast hides the bar", frame.shown, false)
Equal("and stops the binding", frame.binding.enabled, false)

channel, channelDuration = { name = "Mind Flay", display = "Mind Flay", empowered = false }, {}
Fire("UNIT_SPELLCAST_CHANNEL_START", "player")
Equal("a channel shows", frame.shown, true)
Equal("on the channel's duration", frame.bar.timer, channelDuration)
Equal("draining", frame.bar.direction, Enum.StatusBarTimerDirection.RemainingTime)
Equal("a nil flag hides the cover", frame.locked.alpha, 0)

channel, empoweredDuration = { name = "Fire Breath", display = "Fire Breath", empowered = true }, {}
Fire("UNIT_SPELLCAST_EMPOWER_START", "player")
Equal("an empowered cast on its own duration", frame.bar.timer, empoweredDuration)
Equal("with the hold at full charge", holdArgument, true)
Equal("filling", frame.bar.direction, Enum.StatusBarTimerDirection.ElapsedTime)

channel, channelDuration, empoweredDuration = nil, nil, nil
Fire("UNIT_SPELLCAST_EMPOWER_STOP", "player")
Equal("an ended channel hides it", frame.shown, false)

-- Pet battles ---------------------------------------------------------------------------------------------

cast, castDuration = { name = "Hearthstone", display = "Hearthstone" }, {}
Fire("PET_BATTLE_OPENING_START")
Equal("hidden in a pet battle", frame.shown, false)
Fire("PET_BATTLE_CLOSE")
Equal("shown again after it", frame.shown, true)
cast, castDuration = nil, nil
Fire("UNIT_SPELLCAST_STOP", "player")

-- Edit mode -----------------------------------------------------------------------------------------------

CastBar:Sample(true)
Equal("the sample shows without a cast", frame.shown, true)
Equal("filled to its share", frame.bar.value, Options.SAMPLE_PROGRESS)
Equal("with a sample name", frame.text.text, "Cast Bar")
Equal("and a fixed time", frame.time.text .. " " .. tostring(frame.binding.enabled), "1.2 false")
cast, castDuration = { name = "Fireball", display = "Fireball" }, {}
Fire("UNIT_SPELLCAST_START", "player")
Equal("a cast does not replace the sample", frame.text.text, "Cast Bar")
CastBar:Sample(false)
Equal("the live cast drawn again after it", frame.text.text .. " " .. tostring(frame.bar.timer == castDuration),
	"Fireball true")
cast, castDuration = nil, nil
Fire("UNIT_SPELLCAST_STOP", "player")
Equal("then idle", frame.shown, false)

Set(Options.POSITION_PATH, { point = "BOTTOM", x = 10, y = 200 })
Equal("a saved place is used", Point(frame), "BOTTOM 10 200")

-- Blizzard's bar ------------------------------------------------------------------------------------------

PlayerCastingBarFrame:SetParent(playerFrame)
Equal("a reparent is let through", PlayerCastingBarFrame.parent, playerFrame)
BlizzardBar.repark.scripts.OnUpdate(BlizzardBar.repark)
Equal("and parked again in the same frame", PlayerCastingBarFrame.parent, BlizzardBar.hidden)
Equal("the deferral runs once", BlizzardBar.repark.shown, false)

combat = true
PlayerCastingBarFrame:SetParent(playerFrame)
BlizzardBar.repark.scripts.OnUpdate(BlizzardBar.repark)
Equal("in combat it waits", PlayerCastingBarFrame.parent, playerFrame)
combat = false
Fire("PLAYER_REGEN_ENABLED")
Equal("until combat ends", PlayerCastingBarFrame.parent, BlizzardBar.hidden)
Equal("then stops waiting", eventFrame.events.PLAYER_REGEN_ENABLED, nil)

EditModeManagerFrame:Show()
PlayerCastingBarFrame:SetParent(UIParent)
BlizzardBar.repark.scripts.OnUpdate(BlizzardBar.repark)
Equal("left to Edit Mode while it is open", PlayerCastingBarFrame.parent, UIParent)
PlayerCastingBarFrame.Selection:Show()
PlayerCastingBarFrame.Selection:SetAlpha(1)
RunTimers()
Equal("its selection hidden again after Edit Mode shows it", PlayerCastingBarFrame.Selection.alpha, 0)
EditModeManagerFrame:Hide()
editModeCallbacks["EditMode.Exit"]()
Equal("parked when Edit Mode closes", PlayerCastingBarFrame.parent, BlizzardBar.hidden)

-- Off again -----------------------------------------------------------------------------------------------

PlayerCastingBarFrame:SetParent(playerFrame)
BlizzardBar.repark.scripts.OnUpdate(BlizzardBar.repark)
cast, castDuration = { name = "Fireball", display = "Fireball" }, {}
Fire("UNIT_SPELLCAST_START", "player")
Set(Options.ENABLED_PATH, false)
Equal("turned off, the bar hides", frame.shown, false)
Equal("and stops following events", eventFrame.events.UNIT_SPELLCAST_START, nil)
Equal("Blizzard's bar is handed back to the frame it came from", PlayerCastingBarFrame.parent, playerFrame)
Equal("with its selection", PlayerCastingBarFrame.Selection.alpha .. " " .. tostring(
	PlayerCastingBarFrame.Selection.mouse), "1 true")
PlayerCastingBarFrame:SetParent(playerFrame)
BlizzardBar.repark.scripts.OnUpdate(BlizzardBar.repark)
Equal("and no longer kept parked", PlayerCastingBarFrame.parent, playerFrame)

Set(Options.ENABLED_PATH, true)
Equal("on again, the same frame", CastBar.frame, frame)
Equal("drawing the cast in progress", frame.shown and frame.text.text, "Fireball")
Equal("Blizzard's bar parked again", PlayerCastingBarFrame.parent, BlizzardBar.hidden)
playerFrame:Hide()
Set(Options.ENABLED_PATH, false)
Equal("a hidden original parent gives way to UIParent", PlayerCastingBarFrame.parent, UIParent)

Equal("no errors", #errors, 0)

print(("check_castbar: %d checks passed"):format(checks))
