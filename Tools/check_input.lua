-- Checks Input/ outside the game: Click Down's value for each choice, in and out of combat, and the game's changes put
-- back; Focus Shortcut's attribute keys, binding and macros, the unit frames it covers, Mark Focus, combat, Blizzard's
-- compact frames, Clique, and everything removed when it is turned off; the key labels' codes, the buttons hooked only
-- once turned on, the range dot and gamepad keys left to Blizzard, the font, and Blizzard's text and font put back.
-- Run from any directory with Lua 5.1: lua Tools/check_input.lua
-- Loads the real files against the shared stub client. Exits non-zero on the first failed check.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"
local client = assert(loadfile(root .. "Tools/stub_client.lua"))({ project = "retail" })
local Equal = client.Equal

-- Environment ---------------------------------------------------------------------------------------------

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

local SECRET = client.Secret()

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

---@return table frame a frame whose attributes a check can read before any is set
local function SecureFrame()
	local frame = CreateFrame("Frame")

	frame.attributes = {}

	return frame
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
PartyFrame = Mixin(CreateFrame("Frame"), { MemberFrame1 = SecureFrame(), MemberFrame2 = SecureFrame() })
local addonFrame, forbidden = SecureFrame(), SecureFrame()
forbidden.forbidden = true
ClickCastFrames = { [addonFrame] = true, [forbidden] = true, [{}] = true }

function CompactUnitFrame_SetUnit(_, _) end

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

local GRAY = { name = "NumberFontNormalSmallGray", GetFont = function() end }

---@param button table
---@return table hotkey the hotkey font string a button holds
local function HotKey(button)
	local hotkey = button:CreateFontString()

	hotkey:SetFontObject(GRAY)

	return hotkey
end

---Blizzard's update: the binding's display text, or the range dot when nothing is bound.
local function ShowKey(hotkey, key)
	hotkey:SetText(key and blizzardText[key] or RANGE_INDICATOR)
end

local alphaWrites = 0
---@param button table
---@return table text the macro name font string a button holds, its alpha writes counted
local function MacroName(button)
	local text = button:CreateFontString()

	hooksecurefunc(text, "SetAlpha", function()
		alphaWrites = alphaWrites + 1
	end)

	return text
end

local function ActionButton(name, action)
	local button = Mixin(CreateFrame("Button", name), {
		UpdateHotkeys = function(self)
			self.bindingAction = action
			ShowKey(self.HotKey, GetBindingKey(action) or GetBindingKey("CLICK " .. name .. ":LeftButton"))
		end,
	})

	button.HotKey, button.Name = HotKey(button), MacroName(button)
	button:UpdateHotkeys()

	return button
end

local boundButton = ActionButton("ActionButton1", "ACTIONBUTTON1")
local padButton = ActionButton("ActionButton2", "ACTIONBUTTON2")
local emptyButton = ActionButton("MultiBarLeftButton1", "MULTIACTIONBAR3BUTTON1")
ActionButton("MultiBarLeftButton2", "MULTIACTIONBAR3BUTTON2")
local petButton = Mixin(CreateFrame("Button", "PetActionButton1"), {
	id = 1,
	SetHotkeys = function(self)
		ShowKey(self.HotKey, GetBindingKey("BONUSACTIONBUTTON" .. self:GetID()))
	end,
})
petButton.HotKey = HotKey(petButton)
petButton:SetHotkeys()

-- Addon table ---------------------------------------------------------------------------------------------

local AUI = {}
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
assert(loadfile(root .. "AeonUI/Core/Core.lua"))("AeonUI", AUI)
AUI.can = { clickDown = true, focusShortcut = true, keyLabels = true, macroNames = true }
AUI.Media = {
	Font = function(_, name)
		return name
	end,
	FontFlags = function(_, outline)
		return outline
	end,
}

for _, file in ipairs({ "AeonUI/Core/Callbacks.lua", "AeonUI/Core/Events.lua", "AeonUI/Profile/Schema.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

-- Events.lua's frame, the last one made before the feature's files load.
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


for _, file in ipairs({ "AeonUI_QoL/Input/Options.lua", "AeonUI_QoL/Input/ClickDown.lua", "AeonUI_QoL/Input/FocusShortcut.lua", "AeonUI_QoL/Input/KeyLabels.lua",
	"AeonUI_QoL/Input/MacroNames.lua", "AeonUI_QoL/Input/Input.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Options = AUI.InputOptions

---Delivers an event, then lets the update it put off for the next frame run.
---@param event string
---@param ... any
local function Fire(event, ...)
	client:Fire(event, ...)
	client:RunTimers()
end

---@return integer count the secure action buttons made so far
local function SecureButtons()
	local count = 0

	for _, frame in ipairs(client.frames) do
		if frame.template == "SecureActionButtonTemplate" then
			count = count + 1
		end
	end

	return count
end

---@param fontString table
---@return string font the font string's file, size and flags, joined
local function FontOf(fontString)
	return table.concat(fontString.font, " ")
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
Equal("nor makes its buttons", SecureButtons(), 0)

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
client:SetCombat(true)
Fire("PLAYER_REGEN_DISABLED")
Equal("on as combat starts", cvars.ActionButtonUseKeyDown, "1")
Fire("CVAR_UPDATE", "ActionButtonUseKeyDown")
Equal("and kept on in combat", cvars.ActionButtonUseKeyDown, "1")
client:SetCombat(false)
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
Equal("two secure buttons", SecureButtons(), 2)
local focusButton, markButton = AeonUIFocusButton, AeonUIFocusMark
Equal("the world button acts on down", focusButton.clicks[1] .. " " .. tostring(focusButton.attributes.useOnKeyDown),
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

client:SetCombat(true)
Set(Options.FOCUS_MODIFIER_PATH, "alt")
Equal("in combat nothing changes", tostring(Bound("ALT-BUTTON1")) .. " " .. PlayerFrame.attributes["ctrl-shift-type1"],
	"nil macro")
local compact, nameplate = SecureFrame(), SecureFrame()
CompactUnitFrame_SetUnit(compact, "raid1")
CompactUnitFrame_SetUnit(nameplate, "nameplate1")
Equal("a compact frame set up in combat waits", compact.attributes["alt-type1"], nil)
client:SetCombat(false)
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
Equal("the buttons are made once", SecureButtons(), 2)

-- Key labels ----------------------------------------------------------------------------------------------

local baseHooks = client.hooks
Equal("never turned on: no button is hooked", client.hooks, baseHooks)
Equal("and Blizzard's text stays", boundButton.HotKey.text, "s-Mouse Button 4")

Set(Options.KEY_LABELS_PATH, true)
Equal("on: each button's update is hooked once", client.hooks - baseHooks, 5)
Equal("a bound key is shortened", boundButton.HotKey.text, "SM4")
Equal("in the chosen font", FontOf(boundButton.HotKey), "Arial Narrow 12 SLUG")
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
Equal("a font change restyles at once", FontOf(boundButton.HotKey), "Arial Narrow 16 OUTLINE")
Equal("and keeps the label", boundButton.HotKey.text, "AWU")

Set(Options.KEY_LABELS_PATH, false)
Equal("off: Blizzard's text is back", boundButton.HotKey.text .. " | " .. petButton.HotKey.text,
	"a-Mouse Wheel Up | c-3")
Equal("with its font object", tostring(boundButton.HotKey.font[1]) .. " " .. boundButton.HotKey.fontObject.name,
	"nil NumberFontNormalSmallGray")
Equal("the range dot untouched", padButton.HotKey.text, "LB")
keyBindings.ACTIONBUTTON1 = "SHIFT-BUTTON4"
boundButton:UpdateHotkeys()
Equal("Blizzard's updates are left alone", boundButton.HotKey.text, "s-Mouse Button 4")

Set(Options.KEY_LABELS_PATH, true)
Equal("on again: no second hook", client.hooks - baseHooks, 5)
Equal("labels shortened again", boundButton.HotKey.text .. " " .. emptyButton.HotKey.text, "SM4 SM4")

-- Macro names ---------------------------------------------------------------------------------------------

Equal("off by default", Options:Get(Options.HIDE_MACRO_NAMES_PATH), false)
Equal("never turned on: no button is touched", alphaWrites, 0)

Set(Options.HIDE_MACRO_NAMES_PATH, true)
Equal("on: every main bar button's name is hidden", alphaWrites, 4)
Equal("on the first bar and the others", boundButton.Name.alpha .. " " .. emptyButton.Name.alpha, "0 0")
Equal("the key label stays", boundButton.HotKey.text, "SM4")
Set(Options.KEY_SIZE_PATH, 14)
Equal("another Input setting writes nothing", alphaWrites, 4)

Set(Options.HIDE_MACRO_NAMES_PATH, false)
Equal("off: the names are back", boundButton.Name.alpha .. " " .. emptyButton.Name.alpha, "1 1")
Set(Options.HIDE_MACRO_NAMES_PATH, true)
Equal("on again: hidden again", boundButton.Name.alpha .. " " .. emptyButton.Name.alpha, "0 0")
Set(Options.HIDE_MACRO_NAMES_PATH, false)

AUI.can.macroNames = nil
values[Options.HIDE_MACRO_NAMES_PATH] = true
alphaWrites = 0
AUI.MacroNames:Apply()
Equal("a client without the buttons is left alone", alphaWrites, 0)
AUI.can.macroNames = true
values[Options.HIDE_MACRO_NAMES_PATH] = nil

io.stdout:write(("check_input: %d checks passed\n"):format(client.checks))
