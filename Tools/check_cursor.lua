-- Checks Cursor/ outside the game: the textures, the swipe's size inside the ring, the dot, the cursor's place in
-- UIParent units and when the ring shows; then nothing built while off, the ring placed before it shows and moved only
-- when the cursor moves, the global cooldown and casts drawn from duration objects (secret ones too) with the ring
-- dimmed under a cast, the visibility choices and the camera turns, the colors and opacity, everything stopped when
-- turned off, and the settings page's sample with its swipes running in turn and stopping with the page.
-- Run from any directory with Lua 5.1: lua Tools/check_cursor.lua
-- Loads the real files against the shared stub client.
-- Exits non-zero on the first failed check.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"
local client = assert(loadfile(root .. "Tools/stub_client.lua"))({ project = "retail" })
local Equal = client.Equal

-- Environment ---------------------------------------------------------------------------------------------

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

local cursorX, cursorY = 300, 200
function GetCursorPosition()
	return cursorX, cursorY
end

UIParent.effectiveScale = 0.5

local instance = false
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
assert(loadfile(root .. "AeonUI/Core/Core.lua"))("AeonUI", AUI)
AUI.can = { cursorRing = true, castSwipe = true }

for _, file in ipairs({ "AeonUI/Core/Callbacks.lua", "AeonUI/Core/Events.lua", "AeonUI/Core/Modules.lua", "AeonUI/Profile/Schema.lua" }) do
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
	client:RunTimers()
end

for _, file in ipairs({ "AeonUI_QoL/Cursor/Options.lua", "AeonUI_QoL/Cursor/CursorRing.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Options, CursorRing = AUI.CursorOptions, AUI.CursorRing

-- Harness -------------------------------------------------------------------------------------------------

local function Round(value)
	return math.floor(value * 1000 + 0.5) / 1000
end

local function Color(texture)
	local color = texture.vertex

	return ("%s %s %s %s"):format(Round(color[1]), Round(color[2]), Round(color[3]), Round(color[4]))
end

---@param frame table
---@return string place the offsets of its one anchor
local function Place(frame)
	local point = frame.points[1]

	return point[4] .. "," .. point[5]
end

-- The order frames are anchored and shown in, which their state does not hold.
local log = {}
local frameType = getmetatable(UIParent)

hooksecurefunc(frameType, "SetPoint", function()
	log[#log + 1] = "point"
end)
hooksecurefunc(frameType, "Show", function()
	log[#log + 1] = "show"
end)

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
Equal("at the cursor", Place(ring), "600,400")
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
Equal("a moved cursor does", tostring(ring.points ~= points) .. " " .. ring.points[1][4], "true 620")

-- Swipes --------------------------------------------------------------------------------------------------

gcd = {}
client:Fire("SPELL_UPDATE_COOLDOWN")
Equal("each cooldown update draws the global cooldown", ring.gcd.duration, gcd)
local secret = client.Secret()
gcd = secret
client:Fire("SPELL_UPDATE_COOLDOWN")
Equal("a secret duration is passed on, never read", ring.gcd.duration, secret)
gcd = nil
local last = ring.gcd.duration
client:Fire("SPELL_UPDATE_COOLDOWN")
Equal("no duration leaves the swipe to end", ring.gcd.duration, last)

casting = {}
client:Fire("UNIT_SPELLCAST_START", "target")
Equal("another unit's cast is ignored", ring.cast.duration, nil)
client:Fire("UNIT_SPELLCAST_START", "player")
Equal("the player's cast sweeps the ring", ring.cast.duration, casting)
Equal("filling it", ring.cast.reverse, true)
Equal("the ring dims under it", Color(ring.ring), "1 1 1 0.35")
Equal("the dot does not", Color(ring.dot), "1 1 1 1")
casting = nil
client:Fire("UNIT_SPELLCAST_STOP", "player")
Equal("a stopped cast clears its sweep", ring.cast.duration, nil)
Equal("and the ring is whole again", Color(ring.ring), "1 1 1 1")
channel = secret
client:Fire("UNIT_SPELLCAST_CHANNEL_START", "player")
Equal("a channel, secret or not, sweeps it", ring.cast.duration, secret)
Equal("emptying it", ring.cast.reverse, false)
channel = nil
empowered = {}
client:Fire("UNIT_SPELLCAST_EMPOWER_START", "player")
Equal("an empowered cast fills it", tostring(ring.cast.duration == empowered) .. " " .. tostring(ring.cast.reverse),
	"true true")
ring.cast.scripts.OnCooldownDone()
Equal("a sweep that ends gives the ring its opacity back", Color(ring.ring), "1 1 1 1")
empowered = nil
casting = {}
Set(Options.CASTS_PATH, false)
Equal("Casts off: no sweep", ring.cast.duration, nil)
client:Fire("UNIT_SPELLCAST_START", "player")
Equal("and none started", ring.cast.duration, nil)
casting = nil
Set(Options.CASTS_PATH, true)
Set(Options.GCD_PATH, false)
Equal("Global Cooldown off clears its swipe", ring.gcd.duration, nil)
gcd = {}
client:Fire("SPELL_UPDATE_COOLDOWN")
Equal("and starts none", ring.gcd.duration, nil)
Set(Options.GCD_PATH, true)

-- Visibility ----------------------------------------------------------------------------------------------

client:Fire("PLAYER_STARTED_LOOKING")
Equal("turning the camera with the right button hides it", ring.shown, false)
client:Fire("PLAYER_STOPPED_LOOKING")
Equal("and it shows again", ring.shown, true)
client:Fire("PLAYER_STARTED_TURNING")
Equal("with the left button too", ring.shown, false)
Set(Options.HIDE_TURNING_PATH, false)
Equal("unless asked not to", ring.shown, true)
client:Fire("PLAYER_STOPPED_TURNING")
Set(Options.HIDE_TURNING_PATH, true)

Set(Options.SHOW_PATH, "COMBAT")
Equal("In Combat: hidden out of combat", ring.shown, false)
cursorX, cursorY = 100, 50
log = {}
client:Fire("PLAYER_REGEN_DISABLED")
Equal("shown in combat, placed at the cursor first", table.concat(log, " ") .. " " .. Place(ring),
	"point show 200,100")
client:Fire("PLAYER_REGEN_ENABLED")
Equal("hidden again after", ring.shown, false)
Set(Options.SHOW_PATH, "INSTANCES")
instance = true
client:Fire("PLAYER_ENTERING_WORLD")
Equal("In Instances: shown inside one", ring.shown, true)
instance = false
client:Fire("ZONE_CHANGED_NEW_AREA")
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
client:Fire("UNIT_SPELLCAST_START", "player")
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
assert(loadfile(root .. "AeonUI_QoL/Settings/Cursor.lua"))("AeonUI", AUI)
AUI.SettingsCursor:Declare(window)
local canvas = CreateFrame("Frame")
local parts = {}
local previewParts = { Part = function(_, _, target)
	parts[#parts + 1] = target
end }
preview.create(canvas)
local sample = client.frames[#client.frames - 2]
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

io.stdout:write(("check_cursor: %d checks passed\n"):format(client.checks))
