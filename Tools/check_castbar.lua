-- Checks AeonUI_UnitFrames/CastBar/ outside the game: which duration a cast is drawn from and the way its fill runs, when the bar shows,
-- the spell name's length and the time's formats; then nothing built and Blizzard's bar left alone while off, the
-- default look and place, casts, channels and empowered casts drawn from duration objects (secret ones too), the
-- not-interruptible cover, other units ignored, pet battles, the samples, every look setting, Always Show, a saved
-- place, Interrupted and Failed, Fade Out, latency, pushback, empowered stages and their label, the tick lists and
-- marks, the cast target, Blizzard's bar parked
-- and kept parked (after a reparent, past combat and Edit Mode) and handed back when turned off, and turning it on
-- again.
-- Run from any directory with Lua 5.1: lua Tools/check_castbar.lua
-- Loads the real files against stubbed globals; media is stubbed. Widgets are modeled by type and fail on a method
-- their type lacks.
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
local namedTimers = {}
C_Timer = {
	After = function(_, callback)
		timers[#timers + 1] = callback
	end,
	NewTimer = function(seconds, callback)
		local timer = { seconds = seconds, callback = callback }
		timer.Cancel = function(self)
			self.cancelled = true
		end
		namedTimers[#namedTimers + 1] = timer

		return timer
	end,
}

local function RunNamedTimer()
	local timer = table.remove(namedTimers)

	while timer and timer.cancelled do
		timer = table.remove(namedTimers)
	end

	if timer then
		namedTimers = {}
		timer.callback()
	end

	return timer
end

local now = 100
function GetTime()
	return now
end

local latencyMs = 150
function GetNetStats()
	return 0, 0, 40, latencyMs
end
FAILED = "Failed"
TARGET = "Target"
function nop() end

local knownSpells = {}
C_SpellBook = { IsSpellKnownOrInSpellBook = function(spellID)
	return knownSpells[spellID] == true
end }

local targetShown, targetName, targetClass = false, "Thrall", "SHAMAN"
function UnitShouldDisplaySpellTargetName()
	return targetShown
end
function UnitSpellTargetName()
	return targetName
end
function UnitSpellTargetClass()
	return targetClass
end
function GetClassColor(class)
	if class == "SHAMAN" then
		return 0, 0.44, 0.87
	end

	return issecretvalue(class) and "secretR" or 1, 1, 1
end
INTERRUPTED = "Interrupted"

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
	DurationTextBindingProperty = { RemainingDuration = 0, ElapsedDuration = 2, TotalDuration = 4 },
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
	region.GetSize = function(self)
		return self.width, self.height
	end
	region.GetWidth = function(self)
		return self.width or (self.parent and self.parent:GetWidth()) or 0
	end
	region.SetWidth = function(self, width)
		self.width = width
	end
	region.SetHeight = function(self, height)
		self.height = height
	end
	region.Show = function(self)
		self.shown = true
	end
	region.Hide = function(self)
		self.shown = false
	end
	region.SetShown = function(self, shown)
		self.shown = shown
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
	texture.SetTexCoord = function(self, ...)
		self.coords = { ... }
	end
	texture.SetSnapToPixelGrid = function() end
	texture.SetTexelSnappingBias = function() end

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
	text.SetTextColor = function(self, r, g, b)
		self.color = { r, g, b }
	end
	text.SetFormattedText = function(self, format, ...)
		self.text = format:format(...)
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
	frame.SetIsFrameBuffer = function(self, buffered)
		self.buffered = buffered
		self.bufferCalls = (self.bufferCalls or 0) + 1
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
	frame.SetClipsChildren = function(self, clips)
		self.clips = clips
	end
	frame.CreateAnimationGroup = function()
		local group = { playing = false, scripts = {} }
		group.CreateAnimation = function(_, kind)
			assert(kind == "Alpha")
			local animation = {}
			animation.SetFromAlpha = function(self, alpha)
				self.from = alpha
			end
			animation.SetToAlpha = function(self, alpha)
				self.to = alpha
			end
			animation.SetDuration = function(self, seconds)
				self.seconds = seconds
			end
			group.animation = animation

			return animation
		end
		group.SetScript = function(self, script, handler)
			self.scripts[script] = handler
		end
		group.Play = function(self)
			self.playing = true
		end
		group.Stop = function(self)
			self.playing = false
		end

		return group
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
			self.min, self.max, self.timer = low, high, nil
		end
		frame.SetValue = function(self, value)
			self.value = value
		end
		frame.SetTimerDuration = function(self, duration, interpolation, direction)
			self.timer, self.interpolation, self.direction, self.snapped = duration, interpolation, direction, false
		end
		frame.SetToTargetValue = function(self)
			self.snapped = true
		end
		frame.SetReverseFill = function(self, reverse)
			self.reverse = reverse
		end
	end

	frames[#frames + 1] = frame

	return frame
end

function CreateFrame(kind, name, parent, template)
	assert(kind == "Frame" or kind == "StatusBar", "unexpected frame " .. tostring(kind))

	local frame = Frame(kind, name, parent)

	if template then
		assert(template == "BackdropTemplate", "unexpected template " .. tostring(template))
		frame.SetBackdrop = function(self, info)
			self.backdrop = info
		end
		frame.SetBackdropBorderColor = function(self, r, g, b, a)
			self.borderColor = { r, g, b, a }
		end
	end

	return frame
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

function UnitClass()
	return "Mage", "MAGE"
end
C_ClassColor = { GetClassColor = function(class)
	assert(class == "MAGE")

	return { GetRGB = function()
		return 0.25, 0.78, 0.92
	end }
end }

local inPetBattle = false
C_PetBattles = { IsInBattle = function()
	return inPetBattle
end }

local cast, channel, channelEndTime
local castDuration, channelDuration, empoweredDuration
local holdArgument
function UnitCastingInfo(unit)
	assert(unit == "player")

	if cast then
		return cast.name, cast.display, cast.icon or 136243, 1000, 2500, false, "Cast-1", cast.locked, 133, nil,
			cast.delay or 0
	end
end
function UnitChannelInfo(unit)
	assert(unit == "player")

	if channel then
		return channel.name, channel.display, 136243, 1000, channelEndTime or 4000, false, channel.locked,
			channel.spell or 15407,
			channel.empowered,
			channel.empowered and 3 or 0, nil
	end
end
function UnitCastingDuration()
	return castDuration
end
function UnitChannelDuration()
	return channelDuration
end
local stageShares = { 0.2, 0.2, 0.2, 0.4 }
function UnitEmpoweredStagePercentages()
	return stageShares
end
function GetUnitEmpowerHoldAtMaxTime()
	return 500
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
assert(loadfile(root .. "AeonUI/Core/Core.lua"))("AeonUI", AUI)
AUI.can = { castBar = true, petBattles = true, castTarget = true, empoweredCasts = true }

for _, file in ipairs({ "AeonUI/Core/Callbacks.lua", "AeonUI/Core/Events.lua", "AeonUI/Core/Modules.lua", "AeonUI/Profile/Schema.lua" }) do
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

AUI.Border = {
	SHADOW_SIZE = 4,
	SHADOW_COLOR = { r = 0, g = 0, b = 0, a = 0.618 },
	Create = function(_, owner, overContent)
		return {
			owner = owner,
			overContent = overContent,
			laidOut = 0,
			SetFrameLevel = function(self, level)
				self.level = level
			end,
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
	FLAT = "flat",
	Font = function(_, name)
		return "font:" .. name
	end,
	FontFlags = function(_, outline)
		return outline == "NONE" and "" or outline
	end,
	SetBarTexture = function(_, bar, choice)
		bar.texture = choice
	end,
}

AUI.UnitFrameOptions = { ALL = "frames.all." }

for _, file in ipairs({ "AeonUI_UnitFrames/CastBar/Options.lua", "AeonUI_UnitFrames/CastBar/TickData.lua",
	"AeonUI_UnitFrames/CastBar/BlizzardBar.lua", "AeonUI_UnitFrames/CastBar/CastBar.lua" }) do
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
Equal("off, never shown", Options:Visible(false, true, true, false, true), false)
Equal("idle, hidden", Options:Visible(true, false, false, false, false), false)
Equal("casting, shown", Options:Visible(true, true, false, false, false), true)
Equal("not in a pet battle", Options:Visible(true, true, false, true, false), false)
Equal("the sample shows without a cast", Options:Visible(true, false, true, true, false), true)
Equal("Always Show keeps it between casts", Options:Visible(true, false, false, false, true), true)
Equal("but not in a pet battle", Options:Visible(true, false, false, true, true), false)
Equal("the spark at the default height", Options:SparkHeight(16), 30)
Equal("a taller bar's reaches past it", Options:SparkHeight(40), 54)
Equal("Pixel keeps any height", Options:DrawnHeight("PIXEL", 6), 6)
Equal("Forever Minimal holds a short bar", Options:DrawnHeight("FOREVER_MINIMAL", 6), 16)
Equal("and keeps a taller one", Options:DrawnHeight("FOREVER_MINIMAL", 40), 40)
Equal("0 keeps a name whole", Options:Shorten("Pyroblast", 0), "Pyroblast")
Equal("a short name stays whole", Options:Shorten("Pyroblast", 9), "Pyroblast")
Equal("a long one is cut", Options:Shorten("Pyroblast", 4), "Pyro\226\128\166")
Equal("counting letters, not bytes", Options:Shorten("\195\137clair", 2), "\195\137c\226\128\166")
local timeText, timeProps = Options:TimeSpec("ELAPSED_TOTAL")
Equal("a format's text and properties", timeText .. " " .. table.concat(timeProps, ","),
	"{} / {} ElapsedDuration,TotalDuration")
Equal("an unknown format reads Remaining", (select(2, Options:TimeSpec("OTHER")))[1], "RemainingDuration")
Equal("the sample's remaining time", Options:SampleTime("REMAINING"), "1.0")
Equal("its elapsed time", Options:SampleTime("ELAPSED"), "1.5")
Equal("remaining of total", Options:SampleTime("REMAINING_TOTAL"), "1.0 / 2.5")
Equal("elapsed of total", Options:SampleTime("ELAPSED_TOTAL"), "1.5 / 2.5")
Equal("latency's share of a cast", Options:LatencyShare(150, 1000, 2500), 0.1)
Equal("never past the bar", Options:LatencyShare(5000, 1000, 2500), 1)
Equal("unknown without its times", Options:LatencyShare(150, nil, 2500), nil)
Equal("a cast's pushback", Options:PushbackText(400, "+"), "+0.4")
Equal("a channel's", Options:PushbackText(400, "-"), "-0.4")
Equal("nothing pushed", Options:PushbackText(0, "+"), "")
local function Known(id)
	return knownSpells[id] == true
end
local function Fractions(data, seconds)
	local texts = {}
	for index, fraction in ipairs(Options:TickFractions(data, seconds, Known)) do
		texts[index] = ("%.2f"):format(fraction)
	end

	return table.concat(texts, " ")
end
Equal("ticks leave out the channel's end", Fractions({ ticks = 4 }), "0.25 0.50 0.75")
Equal("missiles land at both ends", Fractions({ missiles = 5 }), "0.25 0.50 0.75")
Equal("an interval needs the length", Fractions({ interval = 0.2 }), "")
Equal("an interval's ticks", Fractions({ interval = 0.5 }, 2), "0.25 0.50 0.75")
Equal("a talent's count only while known", Fractions({ ticks = 2, talent = 193134, talentTicks = 3 }), "0.50")
knownSpells[193134] = true
Equal("then its count", Fractions({ ticks = 2, talent = 193134, talentTicks = 3 }), "0.33 0.67")
Equal("known spells add missiles", Fractions({ missiles = 3, addMissiles = { [193134] = 2 } }),
	"0.25 0.50 0.75")
knownSpells[193134] = nil
Equal("a draining channel's tick", Options:TickOffset(0.25, 100, false), 75)
Equal("a reversed one's", Options:TickOffset(0.25, 100, true), 25)
local TickData = AUI.CastBarTickData
Equal("Retail's Mind Flay", TickData.RETAIL[15407].ticks, 6)
Equal("Forever's own", TickData.FOREVER[15407].ticks, 3)
Equal("Forever's Penance rank", TickData.FOREVER[1316995].ticks, 2)
Equal("Eye Beam by interval", TickData.RETAIL[198013].interval, 0.2)
Equal("this client's table", TickData.spells, TickData.RETAIL)
for _, spells in ipairs({ TickData.RETAIL, TickData.FOREVER }) do
	for id, data in pairs(spells) do
		Equal("spell " .. id .. " has one model", (data.ticks and 1 or 0) + (data.missiles and 1 or 0)
			+ (data.interval and 1 or 0), 1)
	end
end
local stageEnds = Options:Boundaries({ 0.25, 0.25, 0.5 })
Equal("where stages end", stageEnds[1] .. " " .. stageEnds[2] .. " " .. stageEnds[3], "0.25 0.5 1")
Equal("no stage yet", Options:StageReached(stageEnds, 0.1), 0)
Equal("the next one's end", select(2, Options:StageReached(stageEnds, 0.3)), 0.5)
Equal("every stage reached", Options:StageReached(stageEnds, 1), 3)
Equal("off by default", AUI.Schema:Field(Options.ENABLED_PATH).default, false)
Equal("no saved place at first", AUI.Profile:Get(Options.POSITION_PATH), nil)

-- Off -----------------------------------------------------------------------------------------------------

CastBar:Start()
CastBar:Start()
Equal("nothing built while off", CastBar.frame, nil)
Equal("no cast event followed", eventFrame.events.UNIT_SPELLCAST_START, nil)
Equal("no scale event followed", eventFrame.events.UI_SCALE_CHANGED, nil)
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
Equal("a black border", frame.lines[1].color[1] .. " " .. frame.lines[1].color[4], "0 1")
Equal("one pixel outside the frame", frame.lines[1].points[1][1] .. " " .. frame.lines[1].points[1][2] .. " "
	.. frame.lines[1].points[1][3] .. " " .. frame.lines[1].height, "TOPLEFT -0.5 0.5 0.5")
Equal("on every side", frame.lines[4].points[2][1] .. " " .. frame.lines[4].points[2][2] .. " "
	.. frame.lines[4].points[2][3] .. " " .. frame.lines[4].width, "BOTTOMRIGHT 0.5 -0.5 0.5")
Equal("white at half opacity behind the fill", frame.background.color[1] .. " " .. frame.background.color[4], "1 0.5")
Equal("the Solid fill", frame.bar.texture, "Solid")
Equal("no icon", frame.icon.shown, false)
Equal("the bar fills the frame", frame.bar.allPoints, true)
Equal("the medium strata", frame.strata, "MEDIUM")
local gradient = frame.bar.fill.gradient
Equal("a horizontal gradient", gradient[1] .. " " .. gradient[2].g .. " " .. gradient[3].g, "HORIZONTAL 0.71 0.682")
Equal("the red cover hidden", frame.locked.alpha, 0)
Equal("the spark rides the fill's edge", frame.spark.points[1][2] == frame.bar.fill and frame.spark.points[1][3],
	"RIGHT")
Equal("additive", frame.spark.blend, "ADD")
Equal("the text above the cover", frame.over.level > frame.locked.level, true)
Equal("Expressway 14 on the Slug renderer, no outline", frame.text.font .. " " .. frame.text.size .. " "
	.. frame.text.flags, "font:Expressway 14 SLUG")
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
Equal("smooth", frame.bar.interpolation, Enum.StatusBarInterpolation.ExponentialEaseOut)
Equal("easing from the cast's own place", frame.bar.snapped, true)
Equal("its icon set", frame.icon.file, 136243)
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
Equal("and a fixed time", frame.time.text .. " " .. tostring(frame.binding.enabled), "1.0 false")
Equal("and a sample icon", frame.icon.file, Options.SAMPLE_ICON)
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

-- Samples -------------------------------------------------------------------------------------------------

local STATES = Options.STATES
CastBar:DrawSample(frame, STATES.NOT_INTERRUPTIBLE, "Not Interruptible")
Equal("Not Interruptible's sample is covered", frame.locked.alpha .. " " .. frame.failed.alpha, "1 0")
CastBar:DrawSample(frame, STATES.INTERRUPTED, "Interrupted")
Equal("Interrupted's fills the bar in its own color", frame.bar.value .. " " .. frame.failed.alpha .. " "
	.. frame.locked.alpha, "1 1 0")
Equal("without the time or spark", tostring(frame.time.shown) .. " " .. tostring(frame.spark.shown), "false false")
CastBar:DrawSample(frame, STATES.CHANNELING, "Channeling")
Equal("the next state clears it", frame.bar.value .. " " .. frame.failed.alpha .. " " .. tostring(frame.time.shown)
	.. " " .. tostring(frame.spark.shown), "0.6 0 true true")
CastBar:Update()

-- Look settings -------------------------------------------------------------------------------------------

Set("castBar.width", 300)
Set("castBar.height", 40)
Equal("its size", frame.width .. "x" .. frame.height, "300x40")
Equal("the spark grows with it", frame.spark.height, 54)
Set("castBar.height", 16)
Set("castBar.width", 386)
Set("castBar.strata", "HIGH")
Equal("its strata", frame.strata, "HIGH")
Set("castBar.texture", "AeonUI Thin Stripes")
Equal("its texture", frame.bar.texture, "AeonUI Thin Stripes")
Set("castBar.gradient", false)
Equal("one color without the gradient", frame.bar.fill.gradient[3].g, 0.71)
Set("castBar.gradient", true)
Set("castBar.gradientDirection", "VERTICAL")
Equal("the gradient's direction", frame.bar.fill.gradient[1], "VERTICAL")
Set("castBar.color", { r = 0, g = 1, b = 0 })
Equal("the fill color", frame.bar.fill.gradient[2].g, 1)
Set("castBar.classColor", true)
Equal("the class color, without the gradient", frame.bar.fill.gradient[2].r .. " " .. frame.bar.fill.gradient[3].b,
	"0.25 0.92")
Set("castBar.classColor", false)
Set("castBar.background", { r = 0, g = 0, b = 0, a = 0.25 })
Equal("the background", frame.background.color[1] .. " " .. frame.background.color[4], "0 0.25")
Set("castBar.notInterruptible", { r = 0.5, g = 0.5, b = 0.5 })
Equal("the not-interruptible color", frame.lockedFill.color[1], 0.5)
Set("castBar.border", 3)
Equal("a thicker border", frame.lines[1].height .. " " .. frame.lines[1].points[1][2], "1.5 -1.5")
Set("castBar.border", 0)
Equal("no border at 0", frame.lines[1].shown, false)
Set("castBar.border", 1)
Equal("no Forever Minimal frame until it is chosen", frame.edge, nil)
Set("castBar.height", 10)
Equal("Pixel draws a short bar", frame.height, 10)
Set("castBar.borderStyle", "FOREVER_MINIMAL")
local edge = frame.edge --[[@as table]]
Equal("Forever Minimal draws the shaded art", edge.look.style, "FOREVER_MINIMAL_SHADED")
Equal("over the bar", edge.owner == frame and edge.overContent, true)
Equal("in the art's own color", edge.look.color.r, 110 / 255)
Equal("with no fill of its own", edge.look.background.a, 0)
Equal("above the text", edge.level, frame.over.level + 1)
Equal("no Pixel lines beside it", frame.lines[1].shown, false)
Equal("it shows", edge.look.style, "FOREVER_MINIMAL_SHADED")
Equal("the short bar is held", frame.height, 16)
Set("castBar.icon", true)
Equal("and its icon with it", frame.icon.width, 16)
Set("castBar.icon", false)
Set("castBar.borderStyle", "PIXEL")
Equal("Pixel hides it", edge.look.style, "NONE")
Equal("and draws its lines again", frame.lines[1].shown, true)
Equal("at the Height setting", frame.height, 10)
Set("castBar.borderStyle", "FOREVER_MINIMAL")
Equal("choosing it again reuses it", frame.edge == edge and edge.look.style, "FOREVER_MINIMAL_SHADED")
edge.laidOut = 0
CastBar:Place()
Equal("placing the bar puts it back on whole pixels", edge.laidOut, 1)
Fire("UI_SCALE_CHANGED")
Equal("and so does a change of UI scale", edge.laidOut, 2)
Equal("no shadow by default", edge.look.shadow, nil)
Set("castBar.showShadow", true)
Equal("Show Shadow gives the art one", edge.look.shadow.size, 4)
Set("castBar.borderStyle", "PIXEL")
Equal("and Pixel one beyond its lines", edge.look.shadow.size, 4 + frame.lines[1].height)
Equal("with no art", edge.look.style, "NONE")
frame.edge = nil
Set("castBar.shadowSize", 5)
Equal("Pixel makes a border for the shadow alone", frame.edge.look.style, "NONE")
frame.edge = edge
Set("castBar.shadowSize", 4)
Set("castBar.showShadow", false)
Equal("off takes it away", edge.look.shadow, nil)
Set("castBar.borderStyle", "PIXEL")
Set("castBar.height", 16)
Set("castBar.reverse", true)
Equal("a reversed fill", tostring(frame.bar.reverse) .. " " .. frame.spark.points[1][3], "true LEFT")
Set("castBar.reverse", false)
Set("castBar.icon", true)
Equal("the icon shows, square", tostring(frame.icon.shown) .. " " .. frame.icon.width .. "x" .. frame.icon.height,
	"true 16x16")
Equal("on the left, the bar beside it", frame.icon.points[1][1] .. " " .. frame.bar.points[1][2], "TOPLEFT 16")
Set("castBar.iconSide", "RIGHT")
Equal("or on the right", frame.icon.points[1][1] .. " " .. frame.bar.points[2][2], "TOPRIGHT -16")
Set("castBar.icon", false)
Equal("the bar back across the frame", #frame.bar.points, 0)
Set("castBar.font", "Arial Narrow")
Equal("the font, on every text", frame.text.font .. " " .. frame.time.font .. " " .. frame.pushback.font .. " "
	.. frame.target.font, "font:Arial Narrow font:Arial Narrow font:Arial Narrow font:Arial Narrow")
Set("castBar.font", "Expressway")
Set("castBar.outline", "OUTLINE")
Equal("the outline", frame.time.flags, "OUTLINE")
Set("castBar.shadow", false)
Equal("no shadow", frame.text.shadow[4], 0)
Equal("the text sits in from both edges", frame.text.points[1][4] .. " " .. frame.time.points[1][4], "4 -4")
Set("castBar.name.size", 20)
Set("castBar.name.color", { r = 1, g = 0, b = 0 })
Set("castBar.name.x", 5)
Set("castBar.name.y", -2)
Equal("the name's size, color and place", frame.text.size .. " " .. frame.text.color[2] .. " "
	.. frame.text.points[1][4] .. " " .. frame.text.points[1][5], "20 0 9 -2")
Set("castBar.name.enabled", false)
Equal("no name", frame.text.shown, false)
Set("castBar.name.enabled", true)
Set("castBar.time.size", 10)
Set("castBar.time.x", -3)
Equal("the time's size and place", frame.time.size .. " " .. frame.time.points[1][4], "10 -7")
Set("castBar.time.format", "ELAPSED_TOTAL")
Equal("the time's format", frame.binding.format .. " " .. frame.binding.components[1].property .. " "
	.. frame.binding.components[2].property, "{} / {} 2 4")
Set("castBar.time.enabled", false)
Equal("no time", frame.time.shown, false)
Equal("the name then reaches the bar's edge", frame.text.points[2][2], frame.over)
Equal("short of its padding", frame.text.points[2][4], -4)
Set("castBar.time.enabled", true)
Equal("and stops short of the time again", frame.text.points[2][2], frame.time)
Set("castBar.name.maxLength", 4)
cast, castDuration = { name = "Pyroblast", display = "Pyroblast" }, {}
Fire("UNIT_SPELLCAST_START", "player")
Equal("a long name cut", frame.text.text, "Pyro\226\128\166")
cast.display = Secret("Pyroblast!")
Fire("UNIT_SPELLCAST_DELAYED", "player")
Equal("a secret one kept whole", frame.text.text, cast.display)
Set("castBar.name.maxLength", 0)
Set("castBar.smooth", false)
Equal("no easing", frame.bar.interpolation, Enum.StatusBarInterpolation.Immediate)
Set("castBar.spark", false)
Equal("no spark", frame.spark.shown, false)
Set("castBar.spark", true)
cast, castDuration = nil, nil
Fire("UNIT_SPELLCAST_STOP", "player")
Equal("hidden while nothing is cast", frame.shown, false)
Set("castBar.alwaysShow", true)
Equal("Always Show keeps it", frame.shown, true)
Equal("empty", frame.bar.value .. " [" .. frame.text.text .. "] [" .. frame.time.text .. "] "
	.. tostring(frame.spark.shown) .. " " .. tostring(frame.binding.enabled), "0 [] [] false false")
Fire("PET_BATTLE_OPENING_START")
Equal("not in a pet battle", frame.shown, false)
Fire("PET_BATTLE_CLOSE")
Set("castBar.alwaysShow", false)

-- Interrupted and Failed --------------------------------------------------------------------------------------

local function StartCast()
	cast, castDuration = { name = "Fireball", display = "Fireball" }, {}
	Fire("UNIT_SPELLCAST_START", "player", "Cast-1", 133)
end

local function EndCast()
	cast, castDuration, channel, channelDuration, empoweredDuration = nil, nil, nil, nil, nil
end

StartCast()
Fire("UNIT_SPELLCAST_FAILED", "player", "Cast-2", 116)
Equal("another spell's failure changes nothing", frame.text.text .. " " .. frame.failed.alpha, "Fireball 0")
EndCast()
Fire("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-1", 133)
Equal("Interrupted fills the bar in its color", frame.text.text .. " " .. frame.failed.alpha .. " " .. frame.bar.value,
	"Interrupted 1 1")
Equal("and stops the cast's timer", frame.bar.timer, nil)
Equal("without the time, spark or latency", tostring(frame.time.shown) .. " " .. tostring(frame.spark.shown) .. " "
	.. tostring(frame.latency.shown), "false false false")
Equal("held for its time", namedTimers[#namedTimers].seconds, 0.6)
Fire("UNIT_SPELLCAST_STOP", "player", "Cast-1", 133)
Equal("the stop after it does not end it", tostring(frame.shown) .. " " .. frame.text.text, "true Interrupted")
RunNamedTimer()
Equal("then the bar goes", tostring(frame.shown) .. " " .. frame.failed.alpha, "false 0")

StartCast()
EndCast()
Fire("UNIT_SPELLCAST_FAILED", "player", "Cast-1", 133)
Equal("Failed the same way", frame.text.text, "Failed")
StartCast()
Equal("a new cast replaces it", frame.text.text .. " " .. frame.failed.alpha .. " " .. tostring(frame.time.shown),
	"Fireball 0 true")
Equal("and its timer", namedTimers[#namedTimers].cancelled, true)
EndCast()
Fire("UNIT_SPELLCAST_STOP", "player", "Cast-1", 133)
Equal("a plain stop is no feedback", frame.shown, false)
Fire("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-1", 133)
Equal("nor a late event with nothing drawn", frame.shown, false)

channel, channelDuration = { name = "Mind Flay", display = "Mind Flay" }, {}
Fire("UNIT_SPELLCAST_CHANNEL_START", "player")
channel, channelDuration = nil, nil
Fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-3", 15407, "Creature-1")
Equal("an interrupted channel says so", frame.text.text, "Interrupted")
RunNamedTimer()
channel, channelDuration = { name = "Mind Flay", display = "Mind Flay" }, {}
Fire("UNIT_SPELLCAST_CHANNEL_START", "player")
channel, channelDuration = nil, nil
Fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-3", 15407, nil)
Equal("a finished one just goes", frame.shown, false)

channel, empoweredDuration = { name = "Fire Breath", display = "Fire Breath", empowered = true }, {}
Fire("UNIT_SPELLCAST_EMPOWER_START", "player")
channel, empoweredDuration = nil, nil
Fire("UNIT_SPELLCAST_EMPOWER_STOP", "player", "Cast-4", 357208, false, nil)
Equal("an uncompleted empowered cast too", frame.text.text, "Interrupted")
RunNamedTimer()
channel, empoweredDuration = { name = "Fire Breath", display = "Fire Breath", empowered = true }, {}
Fire("UNIT_SPELLCAST_EMPOWER_START", "player")
channel, empoweredDuration = nil, nil
Fire("UNIT_SPELLCAST_EMPOWER_STOP", "player", "Cast-4", 357208, true, nil)
Equal("a completed one goes", frame.shown, false)

Set("castBar.interrupted", { r = 0.5, g = 0, b = 0 })
Equal("its color", frame.failedFill.color[1], 0.5)
Set("castBar.holdTime", 0)
StartCast()
EndCast()
Fire("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-1", 133)
Equal("no hold at 0", frame.shown, false)
Set("castBar.holdTime", 0.6)

Equal("Show Interrupted and Failed is on by default", AUI.Schema:Field("castBar.feedback").default, true)
Set("castBar.feedback", false)
local timersBefore = #namedTimers
StartCast()
EndCast()
Fire("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-1", 133)
Equal("off, an interrupted cast goes at once, with no hold", tostring(frame.shown) .. " " .. frame.failed.alpha .. " "
	.. tostring(frame.binding.enabled) .. " " .. (#namedTimers - timersBefore), "false 0 false 0")
StartCast()
Fire("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-1", 133)
Equal("even while the client still reports the cast", frame.shown, false)
EndCast()
Fire("UNIT_SPELLCAST_STOP", "player", "Cast-1", 133)
Equal("and the stop after it changes nothing", frame.shown, false)
channel, channelDuration = { name = "Mind Flay", display = "Mind Flay" }, {}
Fire("UNIT_SPELLCAST_CHANNEL_START", "player")
channel, channelDuration = nil, nil
Fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-3", 15407, "Creature-1")
Equal("an interrupted channel too", frame.shown, false)
channel, empoweredDuration = { name = "Fire Breath", display = "Fire Breath", empowered = true }, {}
Fire("UNIT_SPELLCAST_EMPOWER_START", "player")
channel, empoweredDuration = nil, nil
Fire("UNIT_SPELLCAST_EMPOWER_STOP", "player", "Cast-4", 357208, false, nil)
Equal("an uncompleted empowered cast too", frame.shown, false)
Set("castBar.fade", true)
StartCast()
EndCast()
Fire("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-1", 133)
Equal("without Fade Out", tostring(frame.shown) .. " " .. tostring(frame.fade.playing), "false false")
Fire("UNIT_SPELLCAST_STOP", "player", "Cast-1", 133)
Equal("the stop does not fade it either", tostring(frame.shown) .. " " .. tostring(frame.fade.playing), "false false")
Set("castBar.fade", false)
Set("castBar.alwaysShow", true)
StartCast()
Fire("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-1", 133)
Equal("Always Show empties at once", tostring(frame.shown) .. " " .. frame.bar.value .. " " .. frame.text.text .. " "
	.. tostring(frame.bar.timer) .. " " .. frame.failed.alpha, "true 0  nil 0")
EndCast()
Fire("UNIT_SPELLCAST_STOP", "player", "Cast-1", 133)
Set("castBar.alwaysShow", false)
StartCast()
CastBar:Sample(true)
Fire("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-1", 133)
Equal("the sample stays", tostring(frame.shown) .. " " .. frame.text.text, "true Cast Bar")
EndCast()
CastBar:Sample(false)
StartCast()
EndCast()
Fire("UNIT_SPELLCAST_FAILED", "player", "Cast-1", 133)
Equal("Failed goes at once too", tostring(frame.shown) .. " " .. frame.failed.alpha .. " "
	.. (#namedTimers - timersBefore), "false 0 0")
Set("castBar.feedback", true)

-- Fade Out ------------------------------------------------------------------------------------------------

Equal("fades over 0.2 seconds, off by default", frame.fade.animation.seconds .. " "
	.. tostring(AUI.Schema:Field("castBar.fade").default), "0.2 false")
Equal("no image without Fade Out", frame.buffered, false)
Set("castBar.fade", true)
Equal("drawn as one image from the setting", frame.buffered, true)
frame.bufferCalls = 0
StartCast()
EndCast()
Fire("UNIT_SPELLCAST_STOP", "player", "Cast-1", 133)
Equal("a finished cast fades as it stands", tostring(frame.shown) .. " " .. tostring(frame.fade.playing) .. " "
	.. frame.text.text .. " " .. tostring(frame.binding.enabled), "true true Fireball false")
Fire("UNIT_SPELLCAST_STOP", "player", "Cast-1", 133)
Equal("the fade runs on", frame.fade.playing, true)
frame.fade.scripts.OnFinished(frame.fade)
Equal("then the bar goes", tostring(frame.shown) .. " " .. tostring(frame.fade.playing), "false false")
StartCast()
EndCast()
Fire("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-1", 133)
Equal("Interrupted holds first", frame.fade.playing, false)
RunNamedTimer()
Equal("then fades, still red", tostring(frame.fade.playing) .. " " .. frame.failed.alpha, "true 1")
StartCast()
Equal("a new cast stops the fade", tostring(frame.fade.playing) .. " " .. frame.alpha .. " " .. frame.failed.alpha,
	"false 1 0")
EndCast()
Fire("UNIT_SPELLCAST_STOP", "player", "Cast-1", 133)
CastBar:Sample(true)
Equal("the sample stops it too", tostring(frame.fade.playing) .. " " .. tostring(frame.shown), "false true")
CastBar:Sample(false)
Set("castBar.alwaysShow", true)
StartCast()
EndCast()
Fire("UNIT_SPELLCAST_STOP", "player", "Cast-1", 133)
Equal("Always Show empties instead", tostring(frame.fade.playing) .. " " .. frame.bar.value, "false 0")
Equal("and stops the cast's timer", frame.bar.timer, nil)
StartCast()
EndCast()
Fire("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-1", 133)
Equal("Interrupted under Always Show stops the timer", frame.bar.timer, nil)
RunNamedTimer()
Equal("and then empties", tostring(frame.shown) .. " " .. frame.bar.value .. " " .. tostring(frame.bar.timer),
	"true 0 nil")
StartCast()
CastBar:Sample(true)
Equal("the sample stops the timer too", frame.bar.timer, nil)
CastBar:Sample(false)
EndCast()
Fire("UNIT_SPELLCAST_STOP", "player", "Cast-1", 133)
Set("castBar.alwaysShow", false)
Set("castBar.fade", false)

-- Latency -------------------------------------------------------------------------------------------------

StartCast()
Equal("latency shades the cast's end", tostring(frame.latency.shown) .. " " .. frame.latency.points[1][1] .. " "
	.. frame.latency.width, "true TOPRIGHT 38.6")
Equal("no text by default", frame.latencyText.shown, false)
Set("castBar.latencyText", true)
Fire("UNIT_SPELLCAST_DELAYED", "player")
Equal("its text, above it", tostring(frame.latencyText.shown) .. " " .. frame.latencyText.text .. " "
	.. frame.latencyText.points[1][3], "true 150 ms TOPRIGHT")
Set("castBar.reverse", true)
Fire("UNIT_SPELLCAST_DELAYED", "player")
Equal("a reversed bar's at the left", frame.latency.points[1][1], "TOPLEFT")
Set("castBar.reverse", false)
Set("castBar.latencyColor", { r = 0, g = 1, b = 0, a = 0.2 })
Equal("its color", frame.latency.color[2] .. " " .. frame.latency.color[4], "1 0.2")
Set("castBar.latency", false)
Fire("UNIT_SPELLCAST_DELAYED", "player")
Equal("off, nothing shades", tostring(frame.latency.shown) .. " " .. tostring(frame.latencyText.shown), "false false")
Set("castBar.latency", true)
Set("castBar.latencyText", false)
EndCast()
Fire("UNIT_SPELLCAST_STOP", "player", "Cast-1", 133)

channel, channelDuration = { name = "Mind Flay", display = "Mind Flay" }, {}
Fire("UNIT_SPELLCAST_CHANNEL_START", "player")
Equal("a channel finishes at the bar's start", frame.latency.points[1][1] .. " " .. frame.latency.width,
	"TOPLEFT 19.3")
channel, channelDuration = nil, nil
Fire("UNIT_SPELLCAST_CHANNEL_STOP", "player")

-- Pushback ------------------------------------------------------------------------------------------------

Set("castBar.pushback", true)
StartCast()
Equal("nothing while nothing is pushed", frame.pushback.text, "")
cast.delay = 400
Fire("UNIT_SPELLCAST_DELAYED", "player")
Equal("a delayed cast reads later", frame.pushback.text, "+0.4")
Equal("the name stops short of it", frame.text.points[2][2], frame.pushback)
Equal("and it short of the time", frame.pushback.points[1][2], frame.time)
Set("castBar.pushbackColor", { r = 0, g = 0, b = 1 })
Equal("its color", frame.pushback.color[3], 1)
EndCast()
Fire("UNIT_SPELLCAST_STOP", "player", "Cast-1", 133)
Equal("cleared once hidden", frame.shown, false)

channel, channelDuration = { name = "Mind Flay", display = "Mind Flay" }, {}
Fire("UNIT_SPELLCAST_CHANNEL_START", "player")
Equal("a channel starts clean", frame.pushback.text, "")
channelEndTime = 3600
Fire("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
Equal("a shortened channel reads sooner", frame.pushback.text, "-0.4")
channelEndTime = nil
channel, channelDuration = nil, nil
Fire("UNIT_SPELLCAST_CHANNEL_STOP", "player")
channel, channelDuration = { name = "Mind Flay", display = "Mind Flay" }, {}
Fire("UNIT_SPELLCAST_CHANNEL_START", "player")
Equal("the next channel measures from its own end", frame.pushback.text, "")
channel, channelDuration = nil, nil
Fire("UNIT_SPELLCAST_CHANNEL_STOP", "player")
Set("castBar.pushback", false)
Equal("the name back against the time", frame.text.points[2][2], frame.time)

-- Empowered casts -----------------------------------------------------------------------------------------

now = 1
channel, empoweredDuration = { name = "Fire Breath", display = "Fire Breath", empowered = true }, {}
Fire("UNIT_SPELLCAST_EMPOWER_START", "player")
Equal("the stage colors show", frame.zones.shown, true)
Equal("clipped to the fill", tostring(frame.zones.clips) .. " " .. tostring(frame.zones.allPoints == frame.bar.fill),
	"true true")
Equal("one per stage", #frame.stages, 4)
Equal("each in its color", frame.stages[2].color[1], 0.62)
Equal("at its place", frame.stages[2].points[1][1] .. " " .. frame.stages[2].points[1][4], "TOPLEFT 77.2")
Equal("its share of the bar", tostring(frame.stages[4].width), "154.4")
Equal("the time unlabeled", frame.binding.enabled, true)
Set("castBar.stage.2", { r = 0, g = 0, b = 1 })
Fire("UNIT_SPELLCAST_EMPOWER_UPDATE", "player")
Equal("a stage's color follows its setting", frame.stages[2].color[3], 1)
Set("castBar.empowerColors", false)
Fire("UNIT_SPELLCAST_EMPOWER_UPDATE", "player")
Equal("off, no stage colors", frame.zones.shown, false)
Set("castBar.empowerColors", true)

Set("castBar.stageLabel", true)
Fire("UNIT_SPELLCAST_EMPOWER_UPDATE", "player")
Equal("the label replaces the time", frame.time.text .. " " .. tostring(frame.binding.enabled), "Stage 0 false")
Equal("until the next stage", tostring(namedTimers[#namedTimers].seconds), "0.7")
now = 1.8
RunNamedTimer()
Equal("then the stage reached", frame.time.text, "Stage 1")
now = 3.2
RunNamedTimer()
Equal("and Hold at full charge", frame.time.text, "Hold")
now = 100
Set("castBar.stageLabel", false)
channel, empoweredDuration = nil, nil
Fire("UNIT_SPELLCAST_EMPOWER_STOP", "player", "Cast-4", 357208, true, nil)
Equal("the stage colors go with the cast", frame.shown, false)
StartCast()
Equal("the next cast shows none", tostring(frame.zones.shown) .. " " .. tostring(frame.binding.enabled), "false true")
EndCast()
Fire("UNIT_SPELLCAST_STOP", "player", "Cast-1", 133)

CastBar:DrawSample(frame, Options.STATES.EMPOWERED, "Empowered")
Equal("Empowered's sample shows its stages", frame.zones.shown, true)
Set("castBar.stageLabel", true)
CastBar:DrawSample(frame, Options.STATES.EMPOWERED, "Empowered")
Equal("and its label", frame.time.text, "Stage 2")
Set("castBar.stageLabel", false)
Set("castBar.pushback", true)
CastBar:DrawSample(frame, Options.STATES.CHANNELING, "Channeling")
Equal("the other samples none", tostring(frame.zones.shown) .. " " .. frame.pushback.text, "false -0.4")
Set("castBar.pushback", false)
CastBar:Update()

-- Channel ticks -------------------------------------------------------------------------------------------

Equal("ticks on by default, Last Tick off", tostring(AUI.Schema:Field("castBar.ticks").default) .. " "
	.. tostring(AUI.Schema:Field("castBar.lastTick").default), "true false")
channel, channelDuration = { name = "Mind Flay", display = "Mind Flay" }, {}
Fire("UNIT_SPELLCAST_CHANNEL_START", "player")
Equal("six ticks, five marks", #frame.ticks, 5)
Equal("from the draining end", tostring(frame.ticks[1].points[1][4]), tostring(386 * 5 / 6))
Equal("one pixel, black at 70%", frame.ticks[1].width .. " " .. frame.ticks[1].color[1] .. " "
	.. frame.ticks[1].color[4], "0.5 0 0.7")
Equal("full height", frame.ticks[1].points[2][1], "BOTTOMLEFT")
Set("castBar.lastTick", true)
Fire("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
Equal("Last Tick marks the last", frame.ticks[5].color[1] .. " " .. frame.ticks[4].color[1], "1 0")
Set("castBar.lastTick", false)
Set("castBar.tickColor", { r = 0, g = 1, b = 0, a = 0.5 })
Fire("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
Equal("the tick color", frame.ticks[1].color[2], 1)
Set("castBar.ticks", false)
Fire("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
Equal("off, none", frame.ticks[1].shown, false)
Set("castBar.ticks", true)
channel.spell = 99999
Fire("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
Equal("an unlisted spell has none", frame.ticks[1].shown, false)
channel.spell = Secret(15408)
Fire("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
Equal("nor a secret one", frame.ticks[1].shown, false)
channel.spell = 198013
Fire("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
Equal("an interval from the channel's length", frame.ticks[14].shown, true)
channel, channelDuration = nil, nil
Fire("UNIT_SPELLCAST_CHANNEL_STOP", "player")
StartCast()
Equal("a cast has none", frame.ticks[1].shown, false)
EndCast()
Fire("UNIT_SPELLCAST_STOP", "player")
channel, channelDuration = { name = "Mind Flay", display = "Mind Flay" }, {}
Fire("UNIT_SPELLCAST_CHANNEL_START", "player")
channel, channelDuration = nil, nil
Fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-3", 15407, "Creature-1")
Equal("nor the feedback", frame.ticks[1].shown, false)
RunNamedTimer()
CastBar:DrawSample(frame, Options.STATES.CHANNELING, "Channeling")
Equal("the Channeling sample shows ticks", frame.ticks[4].shown, true)
CastBar:DrawSample(frame, Options.STATES.CASTING, "Casting")
Equal("Casting's does not", frame.ticks[1].shown, false)
CastBar:Update()

-- Cast target ---------------------------------------------------------------------------------------------

Equal("off by default", AUI.Schema:Field("castBar.target.enabled").default, false)
targetShown = true
StartCast()
Equal("no target while off", frame.target.shown, false)
Set("castBar.target.enabled", true)
Fire("UNIT_SPELLCAST_DELAYED", "player")
Equal("the target's name", tostring(frame.target.shown) .. " " .. frame.target.text, "true Thrall")
Equal("in its class color", frame.target.color[3], 0.87)
Equal("before the time", frame.target.points[1][2], frame.time)
Equal("the spell name stops at it", frame.text.points[2][2], frame.target)
Equal("within its share of the bar", tostring(frame.target.width), tostring(386 * 0.35))
targetShown = false
Fire("UNIT_SPELLCAST_DELAYED", "player")
Equal("hidden when the client says not to", frame.target.shown, false)
Equal("the name back against the time", frame.text.points[2][2], frame.time)
targetShown = true
targetName, targetClass = Secret("Hidden"), Secret("PRIEST")
Fire("UNIT_SPELLCAST_DELAYED", "player")
Equal("a secret name and class go straight through", frame.target.text .. " " .. frame.target.color[1],
	"Hidden secretR")
targetName, targetClass = "Thrall", "SHAMAN"
Set("castBar.target.classColor", false)
Set("castBar.target.color", { r = 0, g = 1, b = 0 })
Fire("UNIT_SPELLCAST_DELAYED", "player")
Equal("its own color", frame.target.color[2], 1)
Set("castBar.target.size", 10)
Set("castBar.target.x", -8)
Set("castBar.target.y", 3)
Equal("its size and place", frame.target.size .. " " .. frame.target.points[1][4] .. " " .. frame.target.points[1][5],
	"10 -12 3")
EndCast()
Fire("UNIT_SPELLCAST_STOP", "player")
Equal("gone with the cast", frame.shown, false)
CastBar:DrawSample(frame, Options.STATES.CASTING, "Casting")
Equal("the sample names one", frame.target.text, "Target")
CastBar:DrawSample(frame, Options.STATES.INTERRUPTED, "Interrupted")
Equal("Interrupted's does not", frame.target.shown, false)
targetShown = false
Set("castBar.target.enabled", false)
CastBar:Update()

-- The settings page's preview ------------------------------------------------------------------------------

COLOR = "Color"
AUI.Media.sidebar = {}
LibStub = function()
	return { OUTLINES = {} }
end
AUI.Settings = { Default = function(_, path)
	return AUI.Schema:Field(path).default
end }
assert(loadfile(root .. "AeonUI_UnitFrames/Settings/CastBar.lua"))("AeonUI", AUI)

local declaredPreview
local noCard = setmetatable({}, { __index = function()
	return function() end
end })
AUI.SettingsCastBar:Declare({
	Header = function() end,
	Page = function()
		return {
			Preview = function(_, info)
				declaredPreview = info
			end,
			Section = function()
				return noCard
			end,
		}
	end,
})
Equal("five states", table.concat(declaredPreview.states, ","),
	"Casting,Channeling,Empowered,Not Interruptible,Interrupted")
local canvas = Frame("Frame", nil, UIParent)
declaredPreview.create(canvas)
local parts = {}
local previewStub = { Part = function(_, region, target)
	parts[#parts + 1] = target
	return region
end }
local width, height = declaredPreview.refresh(canvas, "Interrupted", previewStub)
Equal("the sample's size", width .. "x" .. height, "386x16")
Equal("its parts land on their settings", table.concat(parts, " "), "color nameEnabled")
parts = {}
declaredPreview.refresh(canvas, nil, previewStub)
Equal("Casting at first, its time shown", table.concat(parts, " "), "color latency nameEnabled timeEnabled")
Equal("the live bar stays as it was", frame.shown, false)

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
