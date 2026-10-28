-- Checks Interface/UIScale.lua and GameMenuScale.lua outside the game: the pixel-perfect arithmetic and ranges, the
-- account-wide state, nothing applied before a value is picked, the waits for combat and for the mouse button, the
-- reload popup when turned off, the stand-down for addons that keep their own scale, and the game menu's scale.
-- Run from any directory with Lua 5.1: lua Tools/check_interface.lua
-- Loads the real files against stubbed globals. Exits non-zero on the first failed check.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

RELOADUI = "Reload UI"
UI_SCALE = "UI Scale"
StaticPopupDialogs = {}

local loaded = {}
C_AddOns = {
	IsAddOnLoaded = function(name)
		return loaded[name] == true
	end,
}

function CallErrorHandler(message)
	error(message, 0)
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
C_Timer = {
	After = function(_, callback)
		timers[#timers + 1] = callback
	end,
}

local function RunTimers()
	local due = timers
	timers = {}
	for _, callback in ipairs(due) do
		callback()
	end
end

-- The event frame Events.lua creates, modeled with only the methods it calls.
local eventFrame
function CreateFrame(kind)
	assert(kind == "Frame", "unexpected frame type " .. tostring(kind))
	local frame = { events = {} }
	function frame:RegisterEvent(event)
		self.events[event] = true
	end
	function frame:UnregisterEvent(event)
		self.events[event] = nil
	end
	function frame:SetScript(_, handler)
		self.onEvent = handler
	end
	eventFrame = frame

	return frame
end

local function Fire(event, ...)
	if eventFrame.events[event] then
		eventFrame.onEvent(eventFrame, event, ...)
	end
end

-- A Frame with a scale, as UIParent and GameMenuFrame are.
local function ScaledFrame()
	local frame = { scale = 1, sets = 0 }
	function frame:GetScale()
		return self.scale
	end
	function frame:SetScale(scale)
		self.scale, self.sets = scale, self.sets + 1
	end

	return frame
end

UIParent = ScaledFrame()
GameMenuFrame = ScaledFrame()

local combat, mouseDown = false, false
function InCombatLockdown()
	return combat
end

function IsMouseButtonDown(button)
	assert(button == "LeftButton", "unexpected button " .. tostring(button))

	return mouseDown
end

local popups = {}
function StaticPopup_Show(which, text)
	popups[#popups + 1] = { which = which, text = text }
end

local AUI = {}
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })

local global = {}
AUI.Profile = {
	Global = function()
		return global
	end,
}

for _, file in ipairs({ "Core/Callbacks.lua", "Core/Events.lua", "Interface/UIScale.lua",
	"Interface/GameMenuScale.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local UIScale, GameMenuScale = AUI.UIScale, AUI.GameMenuScale

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
	return math.floor(value * 100 + 0.5) / 100
end

-- Arithmetic ----------------------------------------------------------------------------------------------

Equal("1080p is 768 / 1080", Round(UIScale.PixelPerfect(1080)), 71.11)
Equal("1440p", Round(UIScale.PixelPerfect(1440)), 53.33)
Equal("4K fits above the slider's lower bound", UIScale.PixelPerfect(2160) >= UIScale.MIN_PERCENT, true)
Equal("the presets in page order", UIScale.PRESETS[1].key .. UIScale.PRESETS[2].key .. UIScale.PRESETS[3].key,
	"1080p1440p4K")
Equal("a scale below the range is raised", UIScale.Clamp(10), UIScale.MIN_PERCENT)
Equal("a scale above the range is lowered", UIScale.Clamp(500), UIScale.MAX_PERCENT)
Equal("a scale that is not a number is none", UIScale.Clamp("80"), nil)
Equal("NaN is none", UIScale.Clamp(0 / 0), nil)
Equal("the game menu's default", GameMenuScale.Clamp(nil), 100)
Equal("the game menu's range", GameMenuScale.Clamp(10) .. " " .. GameMenuScale.Clamp(900), "50 150")

-- UI scale ------------------------------------------------------------------------------------------------

UIParent.scale = 0.8
UIScale:Start()
Equal("on by default", UIScale:IsEnabled(), true)
Equal("no value is saved on a fresh install", UIScale:Saved(), nil)
Equal("the slider reads the current scale", Round(UIScale:Current()), 80)
Equal("nothing is applied at login", UIParent.sets, 0)
Equal("it follows the client's scale changes", eventFrame.events.UI_SCALE_CHANGED, true)
Equal("and display changes", eventFrame.events.DISPLAY_SIZE_CHANGED, true)

UIScale:SetScale(UIScale.PixelPerfect(1440))
Equal("a picked value is saved account-wide", Round(global.uiScale.scale), 53.33)
Equal("and applied at once", Round(UIParent.scale * 100), 53.33)

UIParent.scale = 0.9
Fire("UI_SCALE_CHANGED")
Equal("a client change waits a frame", UIParent.scale, 0.9)
RunTimers()
Equal("then the saved scale is put back", Round(UIParent.scale * 100), 53.33)

local sets = UIParent.sets
Fire("DISPLAY_SIZE_CHANGED")
RunTimers()
Equal("an unchanged scale is not set again", UIParent.sets, sets)

mouseDown = true
UIScale:SetScale(70)
Equal("a drag saves at once", global.uiScale.scale, 70)
Equal("but applies nothing while the button is down", Round(UIParent.scale * 100), 53.33)
UIScale:SetScale(72)
Equal("each step of the drag is saved", global.uiScale.scale, 72)
mouseDown = false
Fire("GLOBAL_MOUSE_UP", "LeftButton")
Equal("the release applies the last step", UIParent.scale, 0.72)
Equal("and stops listening for releases", eventFrame.events.GLOBAL_MOUSE_UP, nil)

combat = true
UIScale:SetScale(80)
Equal("combat holds the change", UIParent.scale, 0.72)
Equal("until it ends", eventFrame.events.PLAYER_REGEN_ENABLED, true)
combat = false
Fire("PLAYER_REGEN_ENABLED")
Equal("then it is applied", UIParent.scale, 0.8)
Equal("and combat's end is no longer watched", eventFrame.events.PLAYER_REGEN_ENABLED, nil)

UIScale:SetEnabled(false)
Equal("turning it off is saved", global.uiScale.enabled, false)
Equal("and offers a reload", popups[#popups] and popups[#popups].which, "AEONUI_UI_SCALE_RELOAD")
Equal("naming the setting", popups[#popups].text, "UI Scale")
local popupCount = #popups
UIScale:SetScale(60)
Equal("while off a value is saved", global.uiScale.scale, 60)
Equal("but not applied", UIParent.scale, 0.8)
UIScale:SetEnabled(true)
Equal("turning it on applies the saved value", UIParent.scale, 0.6)
combat = true
UIScale:SetScale(65)
UIScale:SetEnabled(false)
Equal("turning off drops a waiting apply", eventFrame.events.PLAYER_REGEN_ENABLED, nil)
combat = false
UIScale:SetEnabled(true)
popupCount = #popups

global.uiScale = nil
UIParent.sets = 0
UIScale.applied = false
UIScale:SetEnabled(false)
Equal("turning off before a value was applied offers no reload", #popups, popupCount)
UIScale:SetEnabled(true)

loaded.ElvUI = true
Equal("ElvUI loaded blocks the controls with its name", UIScale:Blocked(), "ElvUI manages the UI scale.")
UIScale:SetScale(70)
Equal("and nothing is applied", UIParent.sets, 0)
loaded.ElvUI = nil
loaded.EllesmereUI = true
Equal("EllesmereUI too", UIScale:Blocked(), "EllesmereUI manages the UI scale.")
loaded.EllesmereUI = nil
Equal("with neither loaded nothing blocks", UIScale:Blocked(), nil)

global.uiScale = { scale = "big" }
Equal("a damaged saved value reads as none", UIScale:Saved(), nil)

-- Game menu scale -----------------------------------------------------------------------------------------

GameMenuScale:Start()
Equal("Blizzard's size is left untouched at login", GameMenuFrame.sets, 0)
GameMenuScale:Set(80)
Equal("a value is saved account-wide", global.gameMenuScale, 80)
Equal("and applied", GameMenuFrame.scale, 0.8)
GameMenuScale:Set(100)
Equal("100% puts Blizzard's size back", GameMenuFrame.scale, 1)
global.gameMenuScale = 120
GameMenuFrame.sets = 0
GameMenuScale:Start()
Equal("a saved value is applied at login", GameMenuFrame.scale, 1.2)
global.gameMenuScale = "huge"
Equal("a damaged saved value reads as the default", GameMenuScale:Get(), 100)

io.stdout:write(("check_interface: %d checks passed\n"):format(checks))
