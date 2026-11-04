-- Checks Markers/ outside the game: the paths and defaults; the frame-free rules (visibility conditions, the pull
-- countdown's commands, the buttons shown, each button's secure attributes, the bar's size, icon sizes, tooltip lines,
-- the world marker cycle); the Raid Markers Bar (built only when on, its secure attributes, its visibility driver and
-- place, everything protected waiting for combat to end, permission dimming, placed world markers through a secret
-- value, the icons' hover and press springs and Animate Buttons, Reduce Motion, Show On Mouseover's fade, the role
-- check, edit mode's sample, turned off); and the world marker cycle with and without secure snippets.
-- Run from any directory with Lua 5.1: lua Tools/check_markers.lua
-- Loads the real files against the shared stub client; protected frames refuse changes in combat.
-- Exits non-zero on the first failed check.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"
local client = assert(loadfile(root .. "Tools/stub_client.lua"))({ project = "retail" })
local Equal = client.Equal

-- Environment ---------------------------------------------------------------------------------------------

SlashCmdList = {}
StaticPopupDialogs = {}
READY_CHECK, PLAYER_COUNTDOWN_BUTTON, CLEAR_ALL = "Ready Check", "Countdown", "Clear All"
RAID_TARGET_1, RAID_TARGET_8 = "Star", "Skull"
SLASH_WORLD_MARKER1, SLASH_CLEAR_WORLD_MARKER1 = "/wm", "/cwm"
SLASH_READYCHECK1, SLASH_COMBATLOG1, SLASH_COUNTDOWN1 = "/readycheck", "/combatlog", "/countdown"

local loaded = {}
C_AddOns = {
	GetAddOnMetadata = function(_, field)
		return field == "Version" and "dev" or "AeonUI"
	end,
	IsAddOnLoaded = function(name)
		return loaded[name] == true
	end,
}

local errors = {}
function CallErrorHandler(message)
	errors[#errors + 1] = message
end

local SECRET = client.Secret()

local raid, leader, assistant, everyoneAssistant = false, false, false, false
function IsInRaid()
	return raid
end
function UnitIsGroupLeader()
	return leader
end
function UnitIsGroupAssistant()
	return assistant
end
function IsEveryoneAssistant()
	return everyoneAssistant
end

local active = {}
function IsRaidMarkerActive(marker)
	return active[marker]
end

local rolePolls = 0
function InitiateRolePoll()
	rolePolls = rolePolls + 1
end

local shift = false
function IsShiftKeyDown()
	return shift
end

local bindings = {}
function GetBindingKey(action)
	return bindings[action]
end

-- Protected frames ---------------------------------------------------------------------------------------

local SECURE = "SecureActionButtonTemplate"

---@param frame table
---@return boolean locked the frame is secure or holds a secure child, which combat locks
local function Protected(frame)
	if frame.template == SECURE then
		return true
	end

	for _, child in ipairs(client.frames) do
		if child.parent == frame and child.template == SECURE then
			return true
		end
	end

	return false
end

local function Blocked(frame, what)
	if client.combat and Protected(frame) then
		error(("blocked in combat: %s on %s"):format(what, tostring(frame.name)), 3)
	end
end

-- Every frame type derives from the type of UIParent, so this reaches the secure buttons too.
local FrameType = getmetatable(UIParent)

for _, method in ipairs({ "SetSize", "SetPoint", "ClearAllPoints", "Show", "Hide", "EnableMouse", "SetAttribute" }) do
	local original = FrameType[method]

	FrameType[method] = function(self, ...)
		Blocked(self, method)

		return original(self, ...)
	end
end

local tooltip = { lines = {}, owners = 0 }
GameTooltip = tooltip
function tooltip:SetOwner(owner)
	self.owner, self.lines, self.shown = owner, {}, false
	self.owners = self.owners + 1
end
function tooltip:SetText(text)
	self.title = text
end
function tooltip:AddDoubleLine(left, right)
	self.lines[#self.lines + 1] = left .. "=" .. right
end
function tooltip:Show()
	self.shown = true
end
function tooltip:Hide()
	self.shown = false
end

local drivers = {}
function RegisterStateDriver(frame, state, condition)
	Blocked(frame, "RegisterStateDriver")
	drivers[frame] = state .. ":" .. condition
end
function UnregisterStateDriver(frame, state)
	Blocked(frame, "UnregisterStateDriver")
	if drivers[frame] and drivers[frame]:sub(1, #state + 1) == state .. ":" then
		drivers[frame] = nil
	end
end

-- The restricted environment: a wrapped script's body runs as a function of (self, button, down); a false return
-- stops the click.
local wraps = {}
function SecureHandlerWrapScript(frame, script, header, body)
	assert(header.template == SECURE, "the header must be protected")
	wraps[frame] = wraps[frame] or {}
	wraps[frame][script] = assert(loadstring("local self, button, down = ...\n" .. body))
end
function SecureHandlerSetFrameRef(frame, label, reference)
	frame.refs = frame.refs or {}
	frame.refs[label] = reference
	frame.GetFrameRef = function(self, name)
		return self.refs[name]
	end
end

---Runs a frame's script, as the client does when the frame gets that input.
local function Script(frame, script, ...)
	if frame.scripts[script] then
		frame.scripts[script](frame, ...)
	end
end

-- Clicks a secure button: its PreClick (wrapped or plain), the macro it runs, then its PostClick.
---@return string? macro the macro text the click ran, nil when the click was stopped
local function Click(button, mouseButton)
	mouseButton = mouseButton or "LeftButton"

	local wrapped = wraps[button] and wraps[button].PreClick

	if wrapped then
		local wasCombat = client.combat
		client:SetCombat(false) -- the restricted environment may change attributes in combat
		local result = wrapped(button, mouseButton, true)
		client:SetCombat(wasCombat)

		if result == false then
			return nil
		end
	end

	if button.scripts.PreClick then
		button.scripts.PreClick(button, mouseButton, true)
	end

	local macro = button.attributes.macrotext

	Script(button, "PostClick", mouseButton, false)

	return macro
end

-- Addon table ---------------------------------------------------------------------------------------------

local AUI = {}
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
assert(loadfile(root .. "AeonUI/Core/Core.lua"))("AeonUI", AUI)
AUI.can = { raidMarkers = true, worldMarkers = true, secureSnippets = false }

for _, file in ipairs({ "AeonUI/Core/Callbacks.lua", "AeonUI/Core/Events.lua", "AeonUI/Profile/Schema.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

-- UI/Border.lua draws with many texture calls; its own checks are elsewhere, so a stand-in records the look.
AUI.Border = {
	STYLES = { "METAL", "FOREVER_MINIMAL", "FOREVER", "THIN_LINE", "NONE" },
	ART_COLOR = { r = 0.5, g = 0.4, b = 0.3 },
	Create = function(_, owner)
		return {
			owner = owner,
			Apply = function(self, look)
				self.look = look
			end,
		}
	end,
}

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

local settingsLibrary = {}
local springs = assert(loadfile(root .. "Tools/springs.lua"))(settingsLibrary)
function LibStub(name)
	assert(name == "LibAeonSettings-1.0", name)

	return settingsLibrary
end

for _, file in ipairs({ "AeonUI_QoL/Markers/Options.lua", "AeonUI_QoL/Markers/Bar.lua", "AeonUI_QoL/Markers/Cycler.lua", "AeonUI_QoL/Markers/Markers.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Options, Bar, Cycler, Markers = AUI.MarkerOptions, AUI.MarkerBar, AUI.MarkerCycler, AUI.Markers

-- Helpers -------------------------------------------------------------------------------------------------

local function Fire(event, ...)
	client:Fire(event, ...)
	client:RunTimers()
end

---@return string place the frame's only anchor: its point and offsets
local function Point(frame)
	local anchor = frame.points[1]

	return ("%s %s %s"):format(tostring(anchor[1]), tostring(anchor[4]), tostring(anchor[5]))
end

local function Attributes(button)
	local keys = {}

	for key, value in pairs(button.attributes or {}) do
		if key ~= "useOnKeyDown" then
			keys[#keys + 1] = key .. "=" .. tostring(value)
		end
	end

	table.sort(keys)

	return table.concat(keys, " ")
end

-- Rules ---------------------------------------------------------------------------------------------------

Equal("off by default", Options:Get("markers.enabled"), false)
Equal("the defaults", table.concat({ tostring(Options:Get("markers.readyCheck")), tostring(Options:Get("markers.countdown")),
	Options:Get("markers.seconds"), Options:Get("markers.visibility"), Options:Get("markers.orientation"),
	Options:Get("markers.size"), Options:Get("markers.spacing"), Options:Get("markers.border.style"),
	tostring(Options:Get("markers.feedback.highlight")), tostring(Options:Get("markers.feedback.grow")),
	tostring(Options:Get("markers.feedback.press")), tostring(Options:Get("markers.tooltips")),
	tostring(Options:Get("markers.mouseover")) }, " "),
	"true true 12 GROUP_OR_TARGET HORIZONTAL 32 3 FOREVER false true true true false")
Equal("the cycle's default order, every marker in it", table.concat(Options:Get("markers.cycle.order"), " ") .. " "
	.. tostring(Options:Get("markers.cycle.show.SKULL")), "STAR CIRCLE DIAMOND TRIANGLE MOON SQUARE CROSS SKULL true")
Equal("always, but not in pet battles", Options:Visibility("ALWAYS"), "[petbattle] hide; show")
Equal("in a group", Options:Visibility("GROUP"), "[petbattle] hide; [group] show; hide")
Equal("in a group or with a target", Options:Visibility("GROUP_OR_TARGET"),
	"[petbattle] hide; [group] show; [@target,exists] show; hide")
Equal("the countdown through BigWigs", table.concat({ Options:Countdown(10, true, true) }, "|"), "/pull 10|/pull 0")
Equal("through DBM", table.concat({ Options:Countdown(10, false, true) }, "|"), "/dbm pull 10|/dbm pull 0")
Equal("through Blizzard", table.concat({ Options:Countdown(10, false, false) }, "|"), "/countdown 10|/countdown 0")
Equal("every button", #Options:Kinds(true, true), 11)
Equal("without Ready Check", table.concat(Options:Kinds(false, true), " ", 9), "clear countdown")
local countdown = { start = "/pull 12", cancel = "/pull 0" }
local star = Options:Attributes("marker", 1, true, countdown)
Equal("a marker's click toggles its raid target, its right-click its world marker", table.concat({ star.type1,
	star.action1, star.marker1, star.type2, star.action2, star.marker2 }, " "), "raidtarget toggle 1 worldmarker toggle 5")
local starOnly = Options:Attributes("marker", 1, false, countdown)
Equal("without world markers, the right-click clears the target's", starOnly.type2 .. " " .. starOnly.action2 .. " "
	.. tostring(starOnly.marker2), "raidtarget clear nil")
local clear = Options:Attributes("clear", nil, true, countdown)
Equal("Clear: raid targets, then world markers", clear.action1 .. " " .. clear.type2 .. " " .. clear.action2,
	"clear-all worldmarker clear")
local ready = Options:Attributes("readyCheck", nil, true, countdown)
Equal("Ready Check: a ready check, combat logging on Shift, no right-click action", ready.macrotext1 .. " "
	.. ready["shift-macrotext*"] .. " " .. tostring(ready.type2), "/readycheck /combatlog nil")
local pull = Options:Attributes("countdown", nil, true, countdown)
Equal("Countdown: start and cancel", pull["*macrotext1"] .. " " .. pull["*macrotext2"], "/pull 12 /pull 0")
Equal("the bar's size", table.concat({ Options:BarSize(11, 32, 3, false) }, "x"), "388x38")
Equal("upright", table.concat({ Options:BarSize(11, 32, 3, true) }, "x"), "38x388")
Equal("a button's offset", Options:Offset(3, 32, 3), 73)
Equal("an icon at rest, hovered, pressed", Options:IconScale(false, false, true, true) .. " "
	.. Options:IconScale(true, false, true, true) .. " " .. Options:IconScale(true, true, true, true), "1 1.15 0.9")
Equal("pressed without Shrink on Press: still grown", Options:IconScale(true, true, true, false), 1.15)
Equal("hovered without Grow on Hover", Options:IconScale(true, false, false, true), 1)
Equal("Ready Check's tooltip lines", #Options:ClickLines("readyCheck", true, 12), 3)
Equal("the countdown's length in its line", Options:ClickLines("countdown", true, 8)[1].action,
	"Start a 8-second pull countdown")
Equal("the cycle in order, world marker numbers", table.concat(Options:Cycle(nil, function()
	return true
end), ","), "5,6,3,2,7,1,4,8")
Equal("a saved order, a marker left out, the missing ones after", table.concat(Options:Cycle({ "SKULL", "STAR" },
	function(name)
		return name ~= "CIRCLE"
	end), ","), "8,5,3,2,7,1,4")
Equal("the macro", Options:CycleMacro(8), "/wm [@cursor] 8")
Equal("steps wrap", Options:NextStep(3, 3) .. " " .. Options:NextStep(0, 3), "1 1")

-- The bar -------------------------------------------------------------------------------------------------

Markers:Start()
Markers:Start()
Equal("nothing built while off", Bar.bar, nil)
Set("markers.enabled", true)
local bar = Bar.bar
Equal("the named bar", bar and bar.name, "AeonUIRaidMarkers")
Equal("eleven secure buttons", #bar.buttons .. " " .. tostring(bar.buttons[11].template == SECURE), "11 true")
Equal("icons resize off the pixel grid", tostring(bar.buttons[1].icon.snap) .. " " .. bar.buttons[1].icon.bias, "false 0")
Equal("sized and placed at the top", bar.width .. "x" .. bar.height .. " " .. Point(bar), "388x38 TOP 0 -20")
Equal("its visibility driver", drivers[bar], "visibility:" .. Options:Visibility("GROUP_OR_TARGET"))
Equal("Skull's attributes", Attributes(bar.buttons[8]),
	"action1=toggle action2=toggle marker1=8 marker2=8 type1=raidtarget type2=worldmarker")
Equal("clicked on release", bar.buttons[1].clicks[1] .. " " .. tostring(bar.buttons[1].attributes.useOnKeyDown),
	"AnyUp false")
Equal("the border in its style", bar.border.look.style .. " " .. bar.border.look.thickness, "FOREVER 100")
Equal("no shadow by default", bar.border.look.shadow, nil)
Equal("Star's icon at full size", bar.buttons[1].icon.width, 32)

client:SetCombat(true)
Set("markers.readyCheck", false)
Equal("in combat, the layout waits", #bar.buttons .. " " .. tostring(bar.buttons[10].shown), "11 true")
Set("markers.size", 30)
client:SetCombat(false)
Fire("PLAYER_REGEN_ENABLED")
Equal("then follows the latest settings", tostring(bar.buttons[11].shown) .. " " .. bar.buttons[10].kind .. " "
	.. bar.width, "false countdown 333")
Equal("the hidden button loses its actions", Attributes(bar.buttons[11]), "")
Set("markers.readyCheck", true)
Set("markers.size", 32)
loaded.BigWigs = true
Set("markers.seconds", 8)
Equal("the countdown through the boss mod loaded", bar.buttons[11].attributes["*macrotext1"], "/pull 8")
loaded.BigWigs = nil

raid = true
Fire("GROUP_ROSTER_UPDATE")
Equal("in a raid without lead or assist: markers and Clear dim", bar.buttons[1].alpha .. " " .. bar.buttons[9].alpha
	.. " " .. bar.buttons[10].alpha, "0.35 0.35 1")
assistant = SECRET
Fire("GROUP_ROSTER_UPDATE")
Equal("a secret answer counts as no", bar.buttons[1].alpha, 0.35)
assistant = true
client:SetCombat(true)
Fire("PARTY_LEADER_CHANGED")
Equal("an assist marks, in combat too", bar.buttons[1].alpha, 1)
client:SetCombat(false)
raid, assistant = false, false

active[5] = true
Fire("RAID_TARGET_UPDATE")
Equal("Star's world marker is down", bar.buttons[1].icon.alpha .. " " .. bar.buttons[2].icon.alpha, "0.35 1")
active[5] = SECRET
Fire("RAID_TARGET_UPDATE")
Equal("a secret answer goes to the icon untested", issecretvalue(bar.buttons[1].icon.alphaBoolean[1]), true)
active[5] = nil
active[6] = true
Script(bar.buttons[2], "PostClick", "RightButton")
Equal("read again after a click", bar.buttons[2].icon.alpha, 0.35)
active[6] = nil

local skull = bar.buttons[8]
Script(skull, "OnEnter")
Equal("hovered: the edge stays dark without Highlight Border", skull.edges[1].vertex[1], 0)
Script(skull, "OnLeave")
springs.Frames(1)
Set("markers.feedback.highlight", true)
Script(skull, "OnEnter")
Equal("hovered: the edge lights and the tooltip shows its clicks", skull.edges[1].vertex[1] .. " " .. tostring(tooltip.title)
	.. " " .. table.concat(tooltip.lines, "; "),
	"0.7 Skull Click=Mark or unmark your target; Right-Click=Place or remove the world marker")
Equal("the icon grows from where it is", springs.Moving(), true)
springs.Frames(1)
Equal("to its hovered size", skull.icon.width, 32 * Options.HOVER_SCALE)
Script(skull, "OnMouseDown")
springs.Frames(0.05)
Equal("pressed, it shrinks at once", skull.icon.width < 32 * Options.HOVER_SCALE, true)
springs.Frames(1)
Equal("to its pressed size", skull.icon.width, 32 * Options.PRESS_SCALE)
Script(skull, "OnMouseUp")
Script(skull, "OnLeave")
springs.Frames(1)
Equal("left: back to rest, edge and tooltip too", skull.icon.width .. " " .. skull.edges[1].vertex[1] .. " "
	.. tostring(tooltip.shown), "32 0 false")
Set("markers.feedback.grow", false)
Set("markers.feedback.press", false)
Script(skull, "OnEnter")
Script(skull, "OnMouseDown")
Equal("without Grow on Hover or Shrink on Press the icon keeps its size", tostring(springs.Moving()) .. " "
	.. skull.icon.width, "false 32")
Script(skull, "OnMouseUp")
Script(skull, "OnLeave")
Set("markers.feedback.grow", true)
Set("markers.feedback.press", true)
Set("markers.feedback.highlight", false)
springs.reduce = true
Script(skull, "OnEnter")
Equal("Reduce Motion: the size jumps", tostring(springs.Moving()) .. " " .. skull.icon.width, "false " .. 32
	* Options.HOVER_SCALE)
Script(skull, "OnLeave")
springs.reduce = false
Set("markers.tooltips", false)
tooltip.title = nil
Script(skull, "OnEnter")
Equal("Tooltips off", tooltip.title, nil)
Script(skull, "OnLeave")
Set("markers.tooltips", true)

local readyButton = bar.buttons[10]
Script(readyButton, "PostClick", "RightButton")
shift = true
Script(readyButton, "PostClick", "RightButton")
shift = false
Script(readyButton, "PostClick", "LeftButton")
Equal("a right-click starts one role check; Shift-right-click logs instead", rolePolls, 1)

Set("markers.mouseover", true)
Equal("Show On Mouseover: the bar takes the mouse and fades out", tostring(bar.mouse) .. " "
	.. tostring(springs.Moving()), "true true")
springs.Frames(1)
Equal("faded out", bar.alpha, 0)
bar.mouseOver = true
Script(bar, "OnEnter")
springs.Frames(0.05)
Equal("fading in under the cursor, from where it was", bar.alpha > 0 and bar.alpha < 1, true)
springs.Frames(1)
Equal("shown", bar.alpha, 1)
bar.mouseOver = false
Script(bar, "OnLeave")
springs.Frames(1)
Bar:Sample(true)
springs.Frames(1)
Equal("edit mode shows it whatever its visibility", tostring(drivers[bar]) .. " " .. tostring(bar.shown) .. " "
	.. bar.alpha, "nil true 1")
Bar:Sample(false)
Equal("and hands it back", drivers[bar], "visibility:" .. Options:Visibility("GROUP_OR_TARGET"))
Set("markers.mouseover", false)
springs.Frames(1)

client:SetCombat(true)
Bar:Place({ point = "CENTER", x = 10, y = 20 })
Equal("placing waits for combat", Point(bar), "TOP 0 -20")
client:SetCombat(false)
Fire("PLAYER_REGEN_ENABLED")
Equal("then takes the saved place", Point(bar), "TOP 0 -20")
Set("markers.position", { point = "CENTER", x = 10, y = 20 })
Equal("a saved place", Point(bar), "CENTER 10 20")

Set("markers.enabled", false)
Bar:Sample(true)
Bar:Sample(false)
Equal("edit mode leaves a bar turned off hidden", tostring(bar.shown) .. " " .. tostring(drivers[bar]), "false nil")
Set("markers.enabled", true)
Set("markers.visibility", "ALWAYS")
Equal("a new visibility", drivers[bar], "visibility:[petbattle] hide; show")
Set("markers.enabled", false)
Equal("off: hidden, without a driver or actions", tostring(bar.shown) .. " " .. tostring(drivers[bar]) .. " "
	.. Attributes(bar.buttons[1]), "false nil ")
Equal("its events dropped", AUI.Events.registered.RAID_TARGET_UPDATE, nil)
Set("markers.enabled", true)
tooltip.owners = 0
Script(bar.buttons[1], "OnEnter")
Script(bar.buttons[1], "OnLeave")
Equal("on again: one bar, its actions back, each button hooked once", tostring(Bar.bar == bar) .. " "
	.. bar.buttons[1].attributes.type1 .. " " .. tooltip.owners, "true raidtarget 1")

-- The world marker cycle ----------------------------------------------------------------------------------

local place, clearButton = Cycler.place, Cycler.clear
Equal("the bindings' buttons, made at the start", tostring(place ~= nil) .. " " .. tostring(clearButton ~= nil),
	"true true")
Equal("their names", place.name .. " " .. clearButton.name, "AeonUIWorldMarkerPlace AeonUIWorldMarkerClear")
Equal("acting on key down", place.clicks[1] .. " " .. tostring(place.attributes.useOnKeyDown), "AnyDown true")
Equal("Clear removes every world marker", clearButton.attributes.macrotext, "/cwm all")
Equal("without snippets: the first press places Star", Click(place), "/wm [@cursor] 5")
Equal("then Circle", Click(place), "/wm [@cursor] 6")
client:SetCombat(true)
Equal("in combat the key places the marker it reached again", Click(place), "/wm [@cursor] 6")
client:SetCombat(false)
Click(clearButton)
Equal("Clear starts the cycle over", Click(place), "/wm [@cursor] 5")
Set("markers.cycle.order", { "SKULL" })
Set("markers.cycle.show.STAR", false)
Equal("a new order starts over, Star left out", tostring(Click(place)) .. " " .. tostring(Click(place)), "/wm [@cursor] 8 /wm [@cursor] 6")
client:SetCombat(true)
Set("markers.cycle.show.CIRCLE", false)
Equal("the cycle's markers change after combat", place.attributes.count, 7)
client:SetCombat(false)
Fire("PLAYER_REGEN_ENABLED")
Equal("then follow the settings", place.attributes.count, 6)
for _, name in ipairs(Options.NAMES) do
	values["markers.cycle.show." .. name] = false
end
Set("markers.cycle.order", nil)
Equal("no markers: the key does nothing", tostring(Click(place)), "nil")
for _, name in ipairs(Options.NAMES) do
	values["markers.cycle.show." .. name] = nil
end
Set("markers.cycle.order", nil)

-- With secure snippets the cycle steps in the restricted environment, in combat too.
Cycler.place, Cycler.clear = nil, nil
AUI.can.secureSnippets = true
Cycler:Apply()
place, clearButton = Cycler.place, Cycler.clear
Equal("snippets: Star first", Click(place), "/wm [@cursor] 5")
client:SetCombat(true)
Equal("stepping in combat", Click(place), "/wm [@cursor] 6")
Click(clearButton)
Equal("Clear starts over in combat", Click(place), "/wm [@cursor] 5")
client:SetCombat(false)
values["markers.cycle.show.STAR"], values["markers.cycle.show.CIRCLE"] = false, false
Cycler:Apply()
Equal("only the markers in the cycle", tostring(Click(place)) .. " " .. place.attributes.count, "/wm [@cursor] 3 6")
values["markers.cycle.show.STAR"], values["markers.cycle.show.CIRCLE"] = nil, nil

bindings["CLICK AeonUIWorldMarkerPlace:LeftButton"] = "F1"
Equal("the keys bound", table.concat({ Cycler:Keys() and tostring((Cycler:Keys())) or "nil", tostring(select(2,
	Cycler:Keys())) }, " "), "F1 nil")
Equal("the bindings' names", _G["BINDING_NAME_CLICK AeonUIWorldMarkerPlace:LeftButton"] .. " | "
	.. _G["BINDING_NAME_CLICK AeonUIWorldMarkerClear:LeftButton"], "Place Next World Marker | Clear World Markers")

Equal("no errors reported", #errors, 0)

print(("check_markers: %d checks passed"):format(client.checks))
