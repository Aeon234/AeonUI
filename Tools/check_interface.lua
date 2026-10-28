-- Checks Interface/ outside the game: the UI scale's pixel-perfect arithmetic and ranges, the account-wide state,
-- nothing applied before a value is picked, the waits for combat and for the mouse button, the reload popup when
-- turned off, the stand-down for addons that keep their own scale, and the game menu's scale; then the extra action
-- button's click-through and art, out of combat, put back when off; help tips marked seen; the boss banner's events
-- taken and given back; and the Great Vault's cover hidden once its addon loads, and shown again when off.
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

-- Interface page -----------------------------------------------------------------------------------------

---A frame that catches the mouse, as the extra action, zone ability and alternate power bar frames do.
local function MouseFrame(enabled)
	local frame = { mouse = enabled }
	function frame:EnableMouse(value)
		self.mouse = value
	end
	function frame:IsMouseEnabled()
		return self.mouse
	end

	return frame
end

---A texture with an alpha.
local function Art()
	local art = { alpha = 1 }
	function art:SetAlpha(alpha)
		self.alpha = alpha
	end

	return art
end

---A frame that hides, as the Great Vault's cover and notice do.
local function Shown()
	local frame = { shown = true }
	function frame:Hide()
		self.shown = false
	end

	return frame
end

ExtraActionBarFrame = MouseFrame(true)
ExtraAbilityContainer = MouseFrame(true)
ZoneAbilityFrame = MouseFrame(false)
ZoneAbilityFrame.Style = Art()
PlayerPowerBarAlt = MouseFrame(true)
ExtraActionButton1 = { style = Art() }

local bits = {}
C_CVar = {
	GetCVarInfo = function(name)
		return (name == "closedInfoFrames" or name == "closedInfoFramesAccountWide") and "0" or nil
	end,
	SetCVarBitfield = function(name, flag, value)
		bits[name .. ":" .. flag] = value
	end,
}
Enum = { FrameTutorialAccount = { First = 1, Second = 4, Bad = 0 } }
NUM_LE_FRAME_TUTORIALS = 3

local bannerEvents = { BOSS_KILL = true, ENCOUNTER_LOOT_RECEIVED = true, PLAYER_ENTERING_WORLD = true }
BossBanner = {}
function BossBanner:IsEventRegistered(event)
	return bannerEvents[event] == true
end
function BossBanner:RegisterEvent(event)
	bannerEvents[event] = true
end
function BossBanner:UnregisterEvent(event)
	bannerEvents[event] = nil
end

function hooksecurefunc(target, name, hook)
	local original = target[name]
	target[name] = function(...)
		original(...)
		hook(...)
	end
end

local function Vault()
	local frame = { Blackout = Shown(), Overlay = Shown(), updates = 0 }
	function frame:UpdateOverlay()
		self.updates = self.updates + 1
		self.Blackout.shown, self.Overlay.shown = true, true
	end
	function frame:IsShown()
		return true
	end

	return frame
end

AUI.can = { extraActionButton = true, helpTips = true, bossBanner = true, vaultOverlay = true }
local values = {}
AUI.Profile.Get = function(_, path)
	local value = values[path]
	if value == nil then
		local field = AUI.Schema:Field(path)
		value = field and field.default
	end

	return value
end

local function Set(path, value)
	values[path] = value
	AUI.Callbacks:Fire("Profile", path)
	RunTimers()
end

for _, file in ipairs({ "Profile/Schema.lua", "Interface/Options.lua", "Interface/ExtraActionButton.lua",
	"Interface/HelpTips.lua", "Interface/HideFrames.lua", "Interface/Interface.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Options = AUI.InterfaceOptions
for _, path in ipairs({ Options.CLICK_THROUGH_PATH, Options.HIDE_ART_PATH, Options.HELP_TIPS_PATH,
	Options.BOSS_BANNER_PATH, Options.VAULT_OVERLAY_PATH }) do
	Equal(path .. " is off by default", AUI.Profile:Get(path), false)
end

combat = false
AUI.Interface:Start()
AUI.Interface:Start()
RunTimers()
Equal("everything off touches nothing", tostring(ExtraActionBarFrame.mouse) .. " " .. ZoneAbilityFrame.Style.alpha
	.. " " .. tostring(next(bits)) .. " " .. tostring(bannerEvents.BOSS_KILL), "true 1 nil true")
Equal("and follows nothing", eventFrame.events.PLAYER_ENTERING_WORLD, nil)

Set(Options.CLICK_THROUGH_PATH, true)
Equal("Click-Through Art: the frames let clicks pass", tostring(ExtraActionBarFrame.mouse)
	.. tostring(ExtraAbilityContainer.mouse) .. tostring(ZoneAbilityFrame.mouse) .. tostring(PlayerPowerBarAlt.mouse),
	"falsefalsefalsefalse")
Equal("re-applied on entering the world", eventFrame.events.PLAYER_ENTERING_WORLD, true)
Set(Options.HIDE_ART_PATH, true)
Equal("Hide Art", ExtraActionButton1.style.alpha .. " " .. ZoneAbilityFrame.Style.alpha, "0 0")
combat = true
Set(Options.CLICK_THROUGH_PATH, false)
Equal("in combat nothing changes", ExtraActionBarFrame.mouse, false)
combat = false
Fire("PLAYER_REGEN_ENABLED")
Equal("after combat each frame's own handling is back", tostring(ExtraActionBarFrame.mouse) .. " "
	.. tostring(ZoneAbilityFrame.mouse), "true false")
Set(Options.HIDE_ART_PATH, false)
Equal("the art is back", ExtraActionButton1.style.alpha .. " " .. ZoneAbilityFrame.Style.alpha, "1 1")
Equal("and entering the world is no longer followed", eventFrame.events.PLAYER_ENTERING_WORLD, nil)

Set(Options.HELP_TIPS_PATH, true)
Equal("account-wide help tips marked seen", tostring(bits["closedInfoFramesAccountWide:1"])
	.. tostring(bits["closedInfoFramesAccountWide:4"]) .. tostring(bits["closedInfoFramesAccountWide:0"]), "truetruenil")
Equal("and the character's", tostring(bits["closedInfoFrames:1"]) .. tostring(bits["closedInfoFrames:3"])
	.. tostring(bits["closedInfoFrames:4"]), "truetruenil")
Set(Options.HELP_TIPS_PATH, false)
Equal("turning it off leaves them seen", bits["closedInfoFrames:1"], true)

Set(Options.BOSS_BANNER_PATH, true)
Equal("the boss banner's two events are taken", tostring(bannerEvents.BOSS_KILL) .. " "
	.. tostring(bannerEvents.ENCOUNTER_LOOT_RECEIVED) .. " " .. tostring(bannerEvents.PLAYER_ENTERING_WORLD),
	"nil nil true")
Set(Options.BOSS_BANNER_PATH, false)
Equal("and given back", tostring(bannerEvents.BOSS_KILL) .. " " .. tostring(bannerEvents.ENCOUNTER_LOOT_RECEIVED),
	"true true")

Set(Options.VAULT_OVERLAY_PATH, true)
Equal("waits for the Great Vault to load", eventFrame.events.ADDON_LOADED, true)
WeeklyRewardsFrame = Vault()
loaded.Blizzard_WeeklyRewards = true
Fire("ADDON_LOADED", "Blizzard_WeeklyRewards")
Equal("then stops waiting", eventFrame.events.ADDON_LOADED, nil)
WeeklyRewardsFrame:UpdateOverlay()
Equal("its cover and notice are hidden after each update", tostring(WeeklyRewardsFrame.Blackout.shown) .. " "
	.. tostring(WeeklyRewardsFrame.Overlay.shown), "false false")
local updates = WeeklyRewardsFrame.updates
Set(Options.VAULT_OVERLAY_PATH, false)
Equal("off: Blizzard's update runs again", WeeklyRewardsFrame.updates - updates .. " "
	.. tostring(WeeklyRewardsFrame.Blackout.shown), "1 true")
Set(Options.VAULT_OVERLAY_PATH, true)
Equal("on again with the vault loaded: hidden at once", WeeklyRewardsFrame.Blackout.shown, false)

AUI.can.vaultOverlay, AUI.can.bossBanner = nil, nil
Set(Options.BOSS_BANNER_PATH, true)
Equal("a client without the banner is left alone", bannerEvents.BOSS_KILL, true)

io.stdout:write(("check_interface: %d checks passed\n"):format(checks))
