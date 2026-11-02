-- Checks Input/ outside the game: Click Down's value for each choice, in and out of combat, and the game's changes put
-- back; Focus Shortcut's attribute keys, binding and macros, the unit frames it covers, Mark Focus, combat, Blizzard's
-- compact frames, Clique, and everything removed when it is turned off; the key labels' codes, the buttons hooked only
-- once turned on, the range dot and gamepad keys left to Blizzard, the font, and Blizzard's text and font put back.
-- Run from any directory with Lua 5.1: lua Tools/check_input.lua
-- Loads the real files against stubbed globals. Exits non-zero on the first failed check.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

WOW_PROJECT_ID = 1
MAX_BOSS_FRAMES = 2
MAX_PARTY_MEMBERS = 2
SlashCmdList = {}
StaticPopupDialogs = {}

local cliqueLoaded = false
C_AddOns = {
	GetAddOnMetadata = function(_, field)
		return field == "Version" and "dev" or "AeonUI"
	end,
	IsAddOnLoaded = function(name)
		return name == "Clique" and cliqueLoaded
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

C_Timer = { After = function(_, callback)
	callback()
end }

local inCombat = false
function InCombatLockdown()
	return inCombat
end

-- Stands in for a secret value; `issecretvalue` knows it.
local SECRET = {}
function issecretvalue(value)
	return value == SECRET
end

-- Console variables.
local cvars = { ActionButtonUseKeyDown = "0" }
local cvarWrites = 0
C_CVar = {
	GetCVar = function(name)
		return cvars[name]
	end,
	SetCVar = function(name, value)
		cvars[name] = value
		cvarWrites = cvarWrites + 1
	end,
}

-- A secure frame keeps its attributes; a frame with a name is published under it.
local function SecureFrame(name)
	local frame = { attributes = {} }
	function frame:SetAttribute(key, value)
		self.attributes[key] = value
	end
	function frame:GetAttribute(key)
		return self.attributes[key]
	end
	function frame:IsForbidden()
		return self.forbidden == true
	end
	if name then
		_G[name] = frame
	end

	return frame
end

local eventFrame
local buttons = {}
function CreateFrame(kind, name, _, template)
	if kind == "Frame" then
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

	assert(kind == "Button" and template == "SecureActionButtonTemplate", "only secure action buttons are made")
	local button = SecureFrame(name)
	function button:RegisterForClicks(clicks)
		self.clicks = clicks
	end
	buttons[#buttons + 1] = button

	return button
end
UIParent = {}

local function Fire(event, ...)
	if eventFrame.events[event] then
		eventFrame.onEvent(eventFrame, event, ...)
	end
end

-- Override bindings: key to the button name it clicks, by owner.
local bindings = {}
function SetOverrideBindingClick(owner, _, key, name)
	bindings[owner] = bindings[owner] or {}
	bindings[owner][key] = name
end
function ClearOverrideBindings(owner)
	bindings[owner] = nil
end

local function Bound(key)
	for _, keys in pairs(bindings) do
		if keys[key] then
			return keys[key]
		end
	end

	return nil
end

-- The group: in a raid, and whether the player leads or assists it.
local group = { raid = false, leader = false, assistant = false }
function IsInRaid()
	return group.raid
end
function UnitIsGroupLeader()
	return group.leader
end
function UnitIsGroupAssistant()
	return group.assistant
end

-- Blizzard's unit frames and those another addon registers.
PlayerFrame = SecureFrame()
TargetFrame = SecureFrame()
TargetFrame.totFrame = SecureFrame()
Boss1TargetFrame = SecureFrame()
PartyFrame = { MemberFrame1 = SecureFrame(), MemberFrame2 = SecureFrame() }
local addonFrame, forbidden = SecureFrame(), SecureFrame()
forbidden.forbidden = true
ClickCastFrames = { [addonFrame] = true, [forbidden] = true, [{}] = true }

function CompactUnitFrame_SetUnit(_, _) end
local hooks = 0
function hooksecurefunc(target, name, hook)
	if type(target) == "string" then
		target, name, hook = _G, target, name
	end
	local original = target[name]
	target[name] = function(...)
		original(...)
		hook(...)
	end
	hooks = hooks + 1
end

-- Action buttons: bindings by action, Blizzard's display text by key, and the hotkey font string each button holds.
RANGE_INDICATOR = "ic"
NUM_ACTIONBAR_BUTTONS = 2
NUM_PET_ACTION_SLOTS = 1
ActionButtonUtil = { ActionBarButtonNames = { "ActionButton", "MultiBarLeftButton" } }
local keyBindings = { ACTIONBUTTON1 = "SHIFT-BUTTON4", ACTIONBUTTON2 = "PADLSHOULDER", BONUSACTIONBUTTON1 = "CTRL-3" }
local blizzardText = { ["SHIFT-BUTTON4"] = "s-Mouse Button 4", PADLSHOULDER = "LB", ["CTRL-3"] = "c-3",
	["ALT-MOUSEWHEELUP"] = "a-Mouse Wheel Up" }
function GetBindingKey(action)
	return keyBindings[action]
end
function IsBindingForGamePad(key)
	return key:sub(1, 3) == "PAD"
end

local GRAY = { name = "NumberFontNormalSmallGray" }
local function HotKey()
	local hotkey = { fontObject = GRAY }
	function hotkey:GetText()
		return self.text
	end
	function hotkey:SetText(text)
		self.text = text
	end
	function hotkey:GetFontObject()
		return self.fontObject
	end
	function hotkey:SetFontObject(font)
		self.fontObject, self.font = font, nil
	end
	function hotkey:SetFont(file, size, flags)
		self.font = file .. " " .. size .. " " .. flags
	end

	return hotkey
end

---Blizzard's update: the binding's display text, or the range dot when nothing is bound.
local function ShowKey(hotkey, key)
	hotkey:SetText(key and blizzardText[key] or RANGE_INDICATOR)
end

local function ActionButton(name, action)
	local button = { HotKey = HotKey() }
	function button:GetName()
		return name
	end
	function button:UpdateHotkeys()
		self.bindingAction = action
		ShowKey(self.HotKey, GetBindingKey(action) or GetBindingKey("CLICK " .. name .. ":LeftButton"))
	end
	button:UpdateHotkeys()
	_G[name] = button

	return button
end

local boundButton = ActionButton("ActionButton1", "ACTIONBUTTON1")
local padButton = ActionButton("ActionButton2", "ACTIONBUTTON2")
local emptyButton = ActionButton("MultiBarLeftButton1", "MULTIACTIONBAR3BUTTON1")
ActionButton("MultiBarLeftButton2", "MULTIACTIONBAR3BUTTON2")
local petButton = { HotKey = HotKey() }
function petButton:GetID()
	return 1
end
function petButton:SetHotkeys()
	ShowKey(self.HotKey, GetBindingKey("BONUSACTIONBUTTON" .. self:GetID()))
end
petButton:SetHotkeys()
PetActionButton1 = petButton

-- Addon table ---------------------------------------------------------------------------------------------

local AUI = {}
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
assert(loadfile(root .. "Core/Core.lua"))("AeonUI", AUI)
AUI.can = { clickDown = true, focusShortcut = true, keyLabels = true }
AUI.Media = {
	Font = function(_, name)
		return name
	end,
	FontFlags = function(_, outline)
		return outline
	end,
}

for _, file in ipairs({ "Core/Callbacks.lua", "Core/Events.lua", "Profile/Schema.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

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


for _, file in ipairs({ "Input/Options.lua", "Input/ClickDown.lua", "Input/FocusShortcut.lua", "Input/KeyLabels.lua",
	"Input/Input.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Options = AUI.InputOptions

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

-- Arithmetic ----------------------------------------------------------------------------------------------

Equal("Always On", Options.ClickDownValue("ON", false), "1")
Equal("Always Off", Options.ClickDownValue("OFF", true), "0")
Equal("In Combat Only, in combat", Options.ClickDownValue("COMBAT", true), "1")
Equal("In Combat Only, out of combat", Options.ClickDownValue("COMBAT", false), "0")
Equal("Not Managed leaves it", Options.ClickDownValue("UNMANAGED", true), nil)
local typeKey, macroKey = Options.AttributeKeys("ctrl-shift", "2")
Equal("lowercase attribute keys", typeKey .. " " .. macroKey, "ctrl-shift-type2 ctrl-shift-macrotext2")
Equal("the binding key", Options.BindingKey("alt-ctrl", "4"), "ALT-CTRL-BUTTON4")
Equal("the world macro", Options.WorldMacro(false), "/clearfocus [@mouseover,noexists]\n/focus [@mouseover,exists]")
Equal("marks the focus when asked", Options.WorldMacro(true), "/clearfocus [@mouseover,noexists]\n"
	.. "/focus [@mouseover,exists]\n/click [@focus,exists] AeonUIFocusMark")
Equal("the frames' macro", Options.FRAME_MACRO, "/focus [@mouseover,exists]\n/click [@focus,exists] AeonUIFocusMark")
Equal("defaults", table.concat({ Options:Get(Options.CLICK_DOWN_PATH), tostring(Options:Get(Options.FOCUS_PATH)),
	Options:Get(Options.FOCUS_MODIFIER_PATH), Options:Get(Options.FOCUS_BUTTON_PATH),
	tostring(Options:Get(Options.FOCUS_WORLD_PATH)), tostring(Options:Get(Options.FOCUS_MARK_PATH)),
	Options:Get(Options.FOCUS_MARKER_PATH) }, " "), "UNMANAGED false shift 1 true false 8")
Equal("key label defaults", table.concat({ tostring(Options:Get(Options.KEY_LABELS_PATH)),
	Options:Get(Options.KEY_FONT_PATH), Options:Get(Options.KEY_SIZE_PATH), Options:Get(Options.KEY_OUTLINE_PATH) }, " "),
	"false Arial Narrow 12 SLUG")

for key, label in pairs({
	["SHIFT-BUTTON4"] = "SM4",
	["ALT-CTRL-SHIFT-1"] = "ACS1",
	["RSHIFT-LALT-Q"] = "AS" .. "Q",
	["META-SPACE"] = "CmdSP",
	BUTTON3 = "MM",
	BUTTON12 = "M12",
	MOUSEWHEELUP = "WU",
	["CTRL-MOUSEWHEELDOWN"] = "CWD",
	NUMPAD5 = "N5",
	["ALT-NUMPADPLUS"] = "AN+",
	NUMPADDECIMAL = "N.",
	["SHIFT--"] = "S-",
	["-"] = "-",
	PAGEUP = "PU",
	PAGEDOWN = "PD",
	BACKSPACE = "BS",
	INSERT = "INS",
	DELETE = "DEL",
	HOME = "HM",
	END = "END",
	TAB = "TAB",
	F5 = "F5",
	ESCAPE = "ESCAPE",
}) do
	Equal("the label for " .. key, Options.KeyLabel(key), label)
end

-- Click Down ----------------------------------------------------------------------------------------------

AUI.Input:Start()
AUI.Input:Start()
Equal("Not Managed changes nothing", cvarWrites, 0)
Equal("and follows nothing", eventFrame.events.CVAR_UPDATE, nil)
Equal("Focus Shortcut off binds nothing", next(bindings), nil)
Equal("nor makes its buttons", #buttons, 0)

Set(Options.CLICK_DOWN_PATH, "ON")
Equal("Always On", cvars.ActionButtonUseKeyDown, "1")
cvars.ActionButtonUseKeyDown = "0"
Fire("CVAR_UPDATE", "ActionButtonUseKeyDown")
Equal("the game's change is put back", cvars.ActionButtonUseKeyDown, "1")
local writes = cvarWrites
Fire("CVAR_UPDATE", "autoLootDefault")
Equal("another setting's change is ignored", cvarWrites, writes)

Set(Options.CLICK_DOWN_PATH, "COMBAT")
Equal("In Combat Only, out of combat", cvars.ActionButtonUseKeyDown, "0")
inCombat = true
Fire("PLAYER_REGEN_DISABLED")
Equal("on as combat starts", cvars.ActionButtonUseKeyDown, "1")
Fire("CVAR_UPDATE", "ActionButtonUseKeyDown")
Equal("and kept on in combat", cvars.ActionButtonUseKeyDown, "1")
inCombat = false
Fire("PLAYER_REGEN_ENABLED")
Equal("off as it ends", cvars.ActionButtonUseKeyDown, "0")

Set(Options.CLICK_DOWN_PATH, "OFF")
Equal("Always Off", cvars.ActionButtonUseKeyDown, "0")
Set(Options.CLICK_DOWN_PATH, "UNMANAGED")
Equal("Not Managed again: the value stays", cvars.ActionButtonUseKeyDown, "0")
Equal("and the game's changes are not followed", eventFrame.events.CVAR_UPDATE, nil)
Equal("nor combat", eventFrame.events.PLAYER_REGEN_DISABLED, nil)
AUI.can.clickDown = nil
values[Options.CLICK_DOWN_PATH] = "ON"
AUI.ClickDown:Apply()
Equal("a client without the setting is left alone", cvars.ActionButtonUseKeyDown, "0")
AUI.can.clickDown = true
values[Options.CLICK_DOWN_PATH] = nil

-- Focus Shortcut ------------------------------------------------------------------------------------------

Set(Options.FOCUS_PATH, true)
Equal("two secure buttons", #buttons, 2)
local focusButton, markButton = AeonUIFocusButton, AeonUIFocusMark
Equal("the world button acts on down", focusButton.clicks .. " " .. tostring(focusButton.attributes.useOnKeyDown),
	"AnyDown true")
Equal("the marker button marks only an unmarked focus", markButton.attributes.type .. " " .. markButton.attributes.action
	.. " " .. markButton.attributes.unit, "raidtarget set-unmarked focus")
Equal("with Skull", markButton.attributes.marker, 8)
Equal("Shift-left in the world", Bound("SHIFT-BUTTON1"), "AeonUIFocusButton")
Equal("clears or focuses", focusButton.attributes.macrotext, Options.WorldMacro(false))
for name, frame in pairs({ player = PlayerFrame, target = TargetFrame, targetOfTarget = TargetFrame.totFrame,
	boss = Boss1TargetFrame, party = PartyFrame.MemberFrame2, addon = addonFrame }) do
	Equal("focus on the " .. name .. " frame", frame.attributes["shift-type1"], "focus")
end
Equal("a forbidden frame is skipped", forbidden.attributes["shift-type1"], nil)
Equal("the group and the world are followed", tostring(eventFrame.events.GROUP_ROSTER_UPDATE)
	.. tostring(eventFrame.events.PARTY_LEADER_CHANGED) .. tostring(eventFrame.events.PLAYER_ENTERING_WORLD),
	"truetruetrue")

Set(Options.FOCUS_MODIFIER_PATH, "ctrl-shift")
Set(Options.FOCUS_BUTTON_PATH, "2")
Equal("a new binding replaces the old", tostring(Bound("SHIFT-BUTTON1")) .. " " .. Bound("CTRL-SHIFT-BUTTON2"),
	"nil AeonUIFocusButton")
Equal("as do the frames' attributes", tostring(PlayerFrame.attributes["shift-type1"]) .. " "
	.. PlayerFrame.attributes["ctrl-shift-type2"], "nil focus")
PlayerFrame.attributes["ctrl-shift-type2"] = "target"
Set(Options.FOCUS_BUTTON_PATH, "1")
Equal("another addon's later change is kept", PlayerFrame.attributes["ctrl-shift-type2"], "target")
PlayerFrame.attributes["ctrl-shift-type2"] = nil

Set(Options.FOCUS_MARK_PATH, true)
Set(Options.FOCUS_MARKER_PATH, "3")
Equal("Mark Focus: frames run the macro", PlayerFrame.attributes["ctrl-shift-type1"] .. " "
	.. PlayerFrame.attributes["ctrl-shift-macrotext1"], "macro " .. Options.FRAME_MACRO)
Equal("the world macro marks", focusButton.attributes.macrotext, Options.WorldMacro(true))
Equal("with the chosen marker", markButton.attributes.marker, 3)
group.raid = true
Fire("GROUP_ROSTER_UPDATE")
Equal("in a raid without lead or assist: no marking", PlayerFrame.attributes["ctrl-shift-type1"] .. " "
	.. tostring(PlayerFrame.attributes["ctrl-shift-macrotext1"]) .. " " .. focusButton.attributes.macrotext,
	"focus nil " .. Options.WorldMacro(false))
group.assistant = SECRET
Fire("PARTY_LEADER_CHANGED")
Equal("a secret answer counts as no", focusButton.attributes.macrotext, Options.WorldMacro(false))
group.assistant = true
Fire("PARTY_LEADER_CHANGED")
Equal("assisting marks again", focusButton.attributes.macrotext, Options.WorldMacro(true))
group.raid, group.assistant = false, false

Set(Options.FOCUS_WORLD_PATH, false)
Equal("World Clicks off: no binding", Bound("CTRL-SHIFT-BUTTON1"), nil)
Equal("frames keep theirs", PlayerFrame.attributes["ctrl-shift-type1"], "macro")
Set(Options.FOCUS_WORLD_PATH, true)

inCombat = true
Set(Options.FOCUS_MODIFIER_PATH, "alt")
Equal("in combat nothing changes", tostring(Bound("ALT-BUTTON1")) .. " " .. PlayerFrame.attributes["ctrl-shift-type1"],
	"nil macro")
local compact, nameplate = SecureFrame(), SecureFrame()
CompactUnitFrame_SetUnit(compact, "raid1")
CompactUnitFrame_SetUnit(nameplate, "nameplate1")
Equal("a compact frame set up in combat waits", compact.attributes["alt-type1"], nil)
inCombat = false
Fire("PLAYER_REGEN_ENABLED")
Equal("after combat, the new binding", Bound("ALT-BUTTON1"), "AeonUIFocusButton")
Equal("and the compact frame", compact.attributes["alt-type1"], "macro")
Equal("nameplates are skipped", nameplate.attributes["alt-type1"], nil)
Equal("combat's end is no longer followed", eventFrame.events.PLAYER_REGEN_ENABLED, nil)
local later = SecureFrame()
CompactUnitFrame_SetUnit(later, "party1")
Equal("a compact frame set up out of combat at once", later.attributes["alt-type1"], "macro")

cliqueLoaded = true
Set(Options.FOCUS_MARK_PATH, false)
Equal("with Clique, unit frames are left to it", tostring(PlayerFrame.attributes["alt-type1"]) .. " "
	.. tostring(compact.attributes["alt-type1"]), "nil nil")
Equal("world clicks still work", Bound("ALT-BUTTON1"), "AeonUIFocusButton")
CompactUnitFrame_SetUnit(SecureFrame(), "raid2")
Equal("nor are new compact frames touched", next(AUI.FocusShortcut.frames), nil)
cliqueLoaded = false

Set(Options.FOCUS_PATH, true)
Set(Options.FOCUS_PATH, false)
Equal("off: no binding", next(bindings), nil)
for name, frame in pairs({ player = PlayerFrame, party = PartyFrame.MemberFrame1, compact = later }) do
	Equal("off: the " .. name .. " frame is clear", frame.attributes["alt-type1"], nil)
end
Equal("off: the group is no longer followed", eventFrame.events.GROUP_ROSTER_UPDATE, nil)
Equal("the buttons are made once", #buttons, 2)

-- Key labels ----------------------------------------------------------------------------------------------

local baseHooks = hooks
Equal("never turned on: no button is hooked", hooks, baseHooks)
Equal("and Blizzard's text stays", boundButton.HotKey.text, "s-Mouse Button 4")

Set(Options.KEY_LABELS_PATH, true)
Equal("on: each button's update is hooked once", hooks - baseHooks, 5)
Equal("a bound key is shortened", boundButton.HotKey.text, "SM4")
Equal("in the chosen font", boundButton.HotKey.font, "Arial Narrow 12 SLUG")
Equal("a pet button's key too", petButton.HotKey.text, "C3")
Equal("a gamepad key keeps Blizzard's text", padButton.HotKey.text, "LB")
Equal("an unbound button keeps the range dot", emptyButton.HotKey.text, RANGE_INDICATOR)

keyBindings.ACTIONBUTTON1 = "ALT-MOUSEWHEELUP"
boundButton:UpdateHotkeys()
Equal("a new binding is shortened as Blizzard shows it", boundButton.HotKey.text, "AWU")
keyBindings.MULTIACTIONBAR3BUTTON1 = "SHIFT-BUTTON4"
emptyButton:UpdateHotkeys()
Equal("as is a key bound to an empty button", emptyButton.HotKey.text, "SM4")

Set(Options.KEY_SIZE_PATH, 16)
Set(Options.KEY_OUTLINE_PATH, "OUTLINE")
Equal("a font change restyles at once", boundButton.HotKey.font, "Arial Narrow 16 OUTLINE")
Equal("and keeps the label", boundButton.HotKey.text, "AWU")

Set(Options.KEY_LABELS_PATH, false)
Equal("off: Blizzard's text is back", boundButton.HotKey.text .. " | " .. petButton.HotKey.text,
	"a-Mouse Wheel Up | c-3")
Equal("with its font object", tostring(boundButton.HotKey.font) .. " " .. boundButton.HotKey.fontObject.name,
	"nil NumberFontNormalSmallGray")
Equal("the range dot untouched", padButton.HotKey.text, "LB")
keyBindings.ACTIONBUTTON1 = "SHIFT-BUTTON4"
boundButton:UpdateHotkeys()
Equal("Blizzard's updates are left alone", boundButton.HotKey.text, "s-Mouse Button 4")

Set(Options.KEY_LABELS_PATH, true)
Equal("on again: no second hook", hooks - baseHooks, 5)
Equal("labels shortened again", boundButton.HotKey.text .. " " .. emptyButton.HotKey.text, "SM4 SM4")

io.stdout:write(("check_input: %d checks passed\n"):format(checks))
