-- Checks Cursor/ outside the game: the textures, the swipe's size inside the ring, the dot, the cursor's place in
-- UIParent units and when the ring shows; then nothing built while off, the ring placed before it shows and moved only
-- when the cursor moves, the global cooldown and casts drawn from duration objects (secret ones too) with the ring
-- dimmed under a cast, the visibility choices and the camera turns, the colors and opacity, everything stopped when
-- turned off, and the settings page's sample with its swipes running in turn and stopping with the page.
-- Run from any directory with Lua 5.1: lua Tools/check_cursor.lua
-- Loads the real files against stubbed globals. Widgets are modeled by type and fail on a method their type lacks.
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

C_Timer = { After = function(_, callback)
	callback()
end }

local secrets = {}
function issecretvalue(value)
	return secrets[value] == true
end

---A widget of one type: calling a method its type lacks fails, as calling a nil field does.
local function Strict(object, kind)
	object.widgetType = kind

	return object
end

local log = {}

---@return table texture a Texture
local function Texture()
	local texture = { shown = true, color = { 1, 1, 1, 1 } }
	texture.SetAllPoints = function() end
	texture.SetPoint = function() end
	texture.ClearAllPoints = function() end
	texture.SetSize = function(self, width, height)
		self.width, self.height = width, height
	end
	texture.SetTexture = function(self, file)
		self.file = file
	end
	texture.SetVertexColor = function(self, r, g, b, a)
		self.color = { r, g, b, a or 1 }
	end
	texture.SetShown = function(self, shown)
		self.shown = shown
	end
	texture.IsShown = function(self)
		return self.shown
	end

	return Strict(texture, "Texture")
end

local frames = {}

---@return table frame a Frame, or a Cooldown with the template's methods
local function Frame(kind, name, parent)
	local frame = { kind = kind, name = name, parent = parent, shown = true, scripts = {}, events = {}, points = 0 }
	frame.SetSize = function(self, width, height)
		self.width, self.height = width, height
	end
	frame.ClearAllPoints = function() end
	frame.SetAllPoints = function() end
	frame.SetPoint = function(self, _, _, _, x, y)
		self.points = self.points + 1
		self.x, self.y = x, y
		log[#log + 1] = "point"
	end
	frame.Show = function(self)
		self.shown = true
		log[#log + 1] = "show"
	end
	frame.Hide = function(self)
		self.shown = false
	end
	frame.IsShown = function(self)
		return self.shown
	end
	frame.SetFrameStrata = function(self, strata)
		self.strata = strata
	end
	frame.EnableMouse = function(self, enabled)
		self.mouse = enabled
	end
	frame.SetScript = function(self, script, handler)
		self.scripts[script] = handler
	end
	frame.CreateTexture = function()
		return Texture()
	end
	frame.RegisterEvent = function(self, event)
		self.events[event] = true
	end
	frame.UnregisterEvent = function(self, event)
		self.events[event] = nil
	end

	if kind == "Cooldown" then
		for _, method in ipairs({ "SetDrawSwipe", "SetDrawEdge", "SetDrawBling", "SetHideCountdownNumbers",
			"SetUseCircularEdge" }) do
			frame[method] = function() end
		end
		frame.SetReverse = function(self, reverse)
			self.reverse = reverse
		end
		frame.SetSwipeTexture = function(self, file, r, g, b, a)
			self.swipe, self.swipeColor = file, { r, g, b, a }
		end
		frame.SetCooldownFromDurationObject = function(self, duration)
			self.duration = duration
		end
		frame.SetCooldown = function(self, _, seconds)
			self.duration = seconds
		end
		frame.Clear = function(self)
			self.duration = nil
		end
	end

	frames[#frames + 1] = frame

	return Strict(frame, kind)
end

function CreateFrame(kind, name, parent, template)
	assert(kind == "Frame" or (kind == "Cooldown" and template == "CooldownFrameTemplate"),
		"unexpected frame " .. tostring(kind))

	return Frame(kind, name, parent)
end

local cursorX, cursorY = 300, 200
function GetCursorPosition()
	return cursorX, cursorY
end

UIParent = { GetEffectiveScale = function()
	return 0.5
end }

local combat, instance = false, false
function InCombatLockdown()
	return combat
end
function IsInInstance()
	return instance, instance and "party" or "none"
end

function UnitClass()
	return "Mage", "MAGE"
end
C_ClassColor = { GetClassColor = function(class)
	assert(class == "MAGE")

	return { GetRGB = function()
		return 0.25, 0.78, 0.92
	end }
end }

local gcd, casting, empowered, channel
C_Spell = { GetSpellCooldownDuration = function(spell)
	assert(spell == 61304, "the global cooldown's spell")

	return gcd
end }
function UnitCastingDuration(unit)
	assert(unit == "player")

	return casting
end
function UnitEmpoweredChannelDuration()
	return empowered
end
function UnitChannelDuration()
	return channel
end

-- Addon table ---------------------------------------------------------------------------------------------

local AUI = {}
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
assert(loadfile(root .. "Core/Core.lua"))("AeonUI", AUI)
AUI.can = { cursorRing = true, castSwipe = true }

for _, file in ipairs({ "Core/Callbacks.lua", "Core/Events.lua", "Core/Modules.lua", "Profile/Schema.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local eventFrame = frames[1]

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
end

local function Fire(event, ...)
	if eventFrame.events[event] then
		eventFrame.scripts.OnEvent(eventFrame, event, ...)
	end
end

for _, file in ipairs({ "Cursor/Options.lua", "Cursor/CursorRing.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Options, CursorRing = AUI.CursorOptions, AUI.CursorRing

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

local function Round(value)
	return math.floor(value * 1000 + 0.5) / 1000
end

local function Color(texture)
	local color = texture.color

	return ("%s %s %s %s"):format(Round(color[1]), Round(color[2]), Round(color[3]), Round(color[4]))
end

-- Arithmetic ----------------------------------------------------------------------------------------------

Equal("Normal's texture", Options:RingTexture("NORMAL"), "Interface\\AddOns\\AeonUI\\Media\\Textures\\CursorRingNormal.tga")
Equal("an unknown thickness draws Normal", Options:RingTexture("WIDE"), Options:RingTexture("NORMAL"))
Equal("Thin's swipe sits inside its band", Round(Options:SwipeScale("THIN")), 0.805)
Equal("Normal's", Round(Options:SwipeScale("NORMAL")), 0.677)
Equal("Thick's", Round(Options:SwipeScale("THICK")), 0.524)
Equal("the dot at the default size", Options:DotSize(56), 6)
Equal("the dot never below 4", Options:DotSize(16), 4)
local x, y = Options:Position(301, 151, 0.5)
Equal("the cursor in UIParent units, rounded", x .. "," .. y, "602,302")
Equal("Always", Options:Visible("ALWAYS", false, false, false, true), true)
Equal("In Combat, out of combat", Options:Visible("COMBAT", false, true, false, true), false)
Equal("In Combat, in combat", Options:Visible("COMBAT", true, false, false, true), true)
Equal("In Instances, outside", Options:Visible("INSTANCES", true, false, false, true), false)
Equal("In Instances, inside", Options:Visible("INSTANCES", false, true, false, true), true)
Equal("turning the camera hides it", Options:Visible("ALWAYS", true, true, true, true), false)
Equal("unless asked not to", Options:Visible("ALWAYS", true, true, true, false), true)

local defaults = {}
for _, path in ipairs({ Options.ENABLED_PATH, Options.SIZE_PATH, Options.THICKNESS_PATH, Options.CLASS_COLOR_PATH,
	Options.OPACITY_PATH, Options.DOT_PATH, Options.GCD_PATH, Options.CASTS_PATH, Options.SHOW_PATH,
	Options.HIDE_TURNING_PATH }) do
	defaults[#defaults + 1] = tostring(AUI.Schema:Field(path).default)
end
Equal("the defaults", table.concat(defaults, " "), "false 56 NORMAL false 100 true true true ALWAYS true")

-- Off -----------------------------------------------------------------------------------------------------

CursorRing:Start()
CursorRing:Start()
Equal("nothing built while off", CursorRing.frame, nil)
Equal("and no event followed", eventFrame.events.PLAYER_REGEN_DISABLED, nil)

-- On ------------------------------------------------------------------------------------------------------

gcd = {}
log = {}
Set(Options.ENABLED_PATH, true)
local ring = CursorRing.frame --[[@as table]]
Equal("the root frame is named", ring.name, "AeonUICursorRing")
Equal("above everything, taking no clicks", ring.strata .. " " .. tostring(ring.mouse), "TOOLTIP false")
Equal("placed at the cursor before it shows", log[#log - 1] .. " " .. log[#log], "point show")
Equal("at the cursor", ring.x .. "," .. ring.y, "600,400")
Equal("its size", ring.width .. "x" .. ring.height, "56x56")
Equal("Normal's ring", ring.ring.file, Options:RingTexture("NORMAL"))
Equal("the dot", ring.dot.width .. " " .. tostring(ring.dot.shown), "6 true")
Equal("white", Color(ring.ring), "1 1 1 1")
Equal("the global cooldown at once", ring.gcd.duration, gcd)
Equal("the swipe inside the ring", Round(ring.gcd.width), Round(56 * Options:SwipeScale("NORMAL")))

local points = ring.points
ring.scripts.OnUpdate(ring)
Equal("a still cursor does not move it", ring.points, points)
cursorX = 310
ring.scripts.OnUpdate(ring)
Equal("a moved cursor does", ring.points .. " " .. ring.x, points + 1 .. " 620")

-- Swipes --------------------------------------------------------------------------------------------------

gcd = {}
Fire("SPELL_UPDATE_COOLDOWN")
Equal("each cooldown update draws the global cooldown", ring.gcd.duration, gcd)
local secret = {}
secrets[secret] = true
gcd = secret
Fire("SPELL_UPDATE_COOLDOWN")
Equal("a secret duration is passed on, never read", ring.gcd.duration, secret)
gcd = nil
local last = ring.gcd.duration
Fire("SPELL_UPDATE_COOLDOWN")
Equal("no duration leaves the swipe to end", ring.gcd.duration, last)

casting = {}
Fire("UNIT_SPELLCAST_START", "target")
Equal("another unit's cast is ignored", ring.cast.duration, nil)
Fire("UNIT_SPELLCAST_START", "player")
Equal("the player's cast sweeps the ring", ring.cast.duration, casting)
Equal("filling it", ring.cast.reverse, true)
Equal("the ring dims under it", Color(ring.ring), "1 1 1 0.35")
Equal("the dot does not", Color(ring.dot), "1 1 1 1")
casting = nil
Fire("UNIT_SPELLCAST_STOP", "player")
Equal("a stopped cast clears its sweep", ring.cast.duration, nil)
Equal("and the ring is whole again", Color(ring.ring), "1 1 1 1")
channel = secret
Fire("UNIT_SPELLCAST_CHANNEL_START", "player")
Equal("a channel, secret or not, sweeps it", ring.cast.duration, secret)
Equal("emptying it", ring.cast.reverse, false)
channel = nil
empowered = {}
Fire("UNIT_SPELLCAST_EMPOWER_START", "player")
Equal("an empowered cast fills it", tostring(ring.cast.duration == empowered) .. " " .. tostring(ring.cast.reverse),
	"true true")
ring.cast.scripts.OnCooldownDone()
Equal("a sweep that ends gives the ring its opacity back", Color(ring.ring), "1 1 1 1")
empowered = nil
casting = {}
Set(Options.CASTS_PATH, false)
Equal("Casts off: no sweep", ring.cast.duration, nil)
Fire("UNIT_SPELLCAST_START", "player")
Equal("and none started", ring.cast.duration, nil)
casting = nil
Set(Options.CASTS_PATH, true)
Set(Options.GCD_PATH, false)
Equal("Global Cooldown off clears its swipe", ring.gcd.duration, nil)
gcd = {}
Fire("SPELL_UPDATE_COOLDOWN")
Equal("and starts none", ring.gcd.duration, nil)
Set(Options.GCD_PATH, true)

-- Visibility ----------------------------------------------------------------------------------------------

Fire("PLAYER_STARTED_LOOKING")
Equal("turning the camera with the right button hides it", ring.shown, false)
Fire("PLAYER_STOPPED_LOOKING")
Equal("and it shows again", ring.shown, true)
Fire("PLAYER_STARTED_TURNING")
Equal("with the left button too", ring.shown, false)
Set(Options.HIDE_TURNING_PATH, false)
Equal("unless asked not to", ring.shown, true)
Fire("PLAYER_STOPPED_TURNING")
Set(Options.HIDE_TURNING_PATH, true)

Set(Options.SHOW_PATH, "COMBAT")
Equal("In Combat: hidden out of combat", ring.shown, false)
cursorX, cursorY = 100, 50
log = {}
Fire("PLAYER_REGEN_DISABLED")
Equal("shown in combat, placed at the cursor first", table.concat(log, " ") .. " " .. ring.x .. "," .. ring.y,
	"point show 200,100")
Fire("PLAYER_REGEN_ENABLED")
Equal("hidden again after", ring.shown, false)
Set(Options.SHOW_PATH, "INSTANCES")
instance = true
Fire("PLAYER_ENTERING_WORLD")
Equal("In Instances: shown inside one", ring.shown, true)
instance = false
Fire("ZONE_CHANGED_NEW_AREA")
Equal("hidden outside", ring.shown, false)
Set(Options.SHOW_PATH, "ALWAYS")

-- Style ---------------------------------------------------------------------------------------------------

Set(Options.CLASS_COLOR_PATH, true)
Equal("Class Color", Color(ring.ring), "0.25 0.78 0.92 1")
Equal("the swipes take it too", table.concat(ring.gcd.swipeColor, " "), "0.25 0.78 0.92 1")
Set(Options.CLASS_COLOR_PATH, false)
Set(Options.COLOR_PATH, { r = 1, g = 0, b = 0 })
Set(Options.OPACITY_PATH, 50)
Equal("its color and opacity", Color(ring.ring), "1 0 0 0.5")
Equal("the dot's too", Color(ring.dot), "1 0 0 0.5")
Equal("the swipes stay opaque", ring.gcd.swipeColor[4], 1)
Set(Options.THICKNESS_PATH, "THICK")
Set(Options.SIZE_PATH, 100)
Equal("Thick's ring and swipes", ring.ring.file .. " " .. ring.cast.swipe, Options:RingTexture("THICK") .. " "
	.. Options:RingTexture("THICK"))
Equal("the size and the swipe inside it", ring.width .. " " .. Round(ring.gcd.width), "100 52.381")
Set(Options.DOT_PATH, false)
Equal("no dot", ring.dot.shown, false)

-- Off again -----------------------------------------------------------------------------------------------

casting = {}
Fire("UNIT_SPELLCAST_START", "player")
Set(Options.ENABLED_PATH, false)
Equal("off: hidden", ring.shown, false)
Equal("its swipes cleared", tostring(ring.gcd.duration) .. " " .. tostring(ring.cast.duration), "nil nil")
Equal("and no event followed", tostring(eventFrame.events.PLAYER_REGEN_DISABLED) .. " "
	.. tostring(eventFrame.events.UNIT_SPELLCAST_START) .. " " .. tostring(eventFrame.events.SPELL_UPDATE_COOLDOWN),
	"nil nil nil")
Set(Options.ENABLED_PATH, true)
Equal("on again: one frame", CursorRing.frame, ring)
Equal("shown, with the cast that is running", tostring(ring.shown) .. " " .. tostring(ring.cast.duration == casting),
	"true true")
AUI.can.cursorRing = nil
Set(Options.SIZE_PATH, 60)
Equal("a client without it hides the ring", ring.shown, false)

-- Preview -----------------------------------------------------------------------------------------------

AUI.can.cursorRing = true
values = {}
ALWAYS, COLOR, OPACITY = "Always", "Color", "Opacity"
function GetTime()
	return 100
end
AUI.Media = { sidebar = { cursor = "SidebarCursor.tga" } }
AUI.Settings = { Default = function(_, path)
	return AUI.Schema:Field(path).default
end }
local preview
local function Section()
	return setmetatable({}, { __index = function()
		return function() end
	end })
end
local window = { Page = function()
	return { Preview = function(_, info)
		preview = info
	end, Section = Section }
end }
assert(loadfile(root .. "Settings/Cursor.lua"))("AeonUI", AUI)
AUI.SettingsCursor:Declare(window)
local canvas = Frame("Frame")
local parts = {}
local previewParts = { Part = function(_, _, target)
	parts[#parts + 1] = target
end }
preview.create(canvas)
local sample = frames[#frames - 2]
local width, height = preview.refresh(canvas, "Idle", previewParts)
Equal("the sample at the ring's size", width .. "x" .. height, "56x56")
Equal("idle: no swipe", tostring(sample.gcd.duration) .. " " .. tostring(sample.cast.duration), "nil nil")
Equal("the ring and dot find their rows", table.concat(parts, " "), "size dot")
parts = {}
preview.refresh(canvas, "Global Cooldown", previewParts)
Equal("the global cooldown sweeps the sample", sample.gcd.duration, 1.5)
Equal("and finds its row", parts[#parts], "gcd")
sample.gcd.duration = 0.2
preview.refresh(canvas, "Global Cooldown", previewParts)
Equal("a setting change does not restart it", sample.gcd.duration, 0.2)
sample.gcd.scripts.OnCooldownDone()
Equal("it starts again when it ends", sample.gcd.duration, 1.5)
parts = {}
preview.refresh(canvas, "Casting", previewParts)
Equal("a cast sweeps the sample, the ring dimmed", tostring(sample.cast.duration) .. " " .. Color(sample.ring),
	"2.5 1 1 1 0.35")
Equal("and finds its row", parts[#parts], "casts")
Set(Options.CASTS_PATH, false)
preview.refresh(canvas, "Casting", previewParts)
Equal("Casts off: no sweep, the ring whole", tostring(sample.cast.duration) .. " " .. Color(sample.ring), "nil 1 1 1 1")
preview.stop()
sample.gcd.scripts.OnCooldownDone()
Equal("stopped: nothing runs or starts again", tostring(sample.gcd.duration) .. " " .. tostring(sample.cast.duration),
	"nil nil")

Equal("no Lua error in the run", errors[1], nil)

io.stdout:write(("check_cursor: %d checks passed\n"):format(checks))
