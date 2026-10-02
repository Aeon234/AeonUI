-- Checks the settings window outside the game: page lists per profile mode, every page's settings reading and saving
-- through the profile owner, number overrides, the text slot editor and its copy actions, the Profiles adapter,
-- damaged profiles, the Recovery page and page resets.
-- Run from any directory with Lua 5.1: lua Tools/check_settings.lua
-- AeonSettings is a stand-in that records what AeonUI hands it; drawing, the library's own controls and dialogs
-- are not exercised here.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

UNKNOWN, NONE, NAME, LEVEL, HEALTH, CUSTOM = "Unknown", "None", "Name", "Level", "Health", "Custom"
INTERRUPTED = "Interrupted"
PET = "Pet"
PLAYER, TARGET, COLOR, DELETE, RESET, DEAD, PLAYER_OFFLINE = "Player", "Target", "Color", "Delete", "Reset", "Dead",
	"Offline"
SlashCmdList = {}
StaticPopupDialogs = {}
SAVE, CONTINUE, OFF, SETTINGS, HUD_EDIT_MODE_MENU = "Save", "Continue", "Off", "Settings", "Edit Mode"
C_AddOns = {
	GetAddOnMetadata = function() end,
}
UIParent = {
	GetWidth = function()
		return 1920
	end,
	GetHeight = function()
		return 1080
	end,
}

function CallErrorHandler(message)
	error(message, 0)
end

local luaXpcall = xpcall
function xpcall(fn, handler, ...)
	local count, args = select("#", ...), { ... }

	return luaXpcall(function()
		return fn(unpack(args, 1, count))
	end, handler)
end

function issecretvalue()
	return false
end

function strcmputf8i(a, b)
	a, b = a:lower(), b:lower()

	return a == b and 0 or (a < b and -1 or 1)
end

function strlenutf8(text)
	local _, count = text:gsub("[^\128-\191]", "")

	return count
end

Enum = { CompressionMethod = { Deflate = 0 } }
local stored = {}
C_EncodingUtil = {
	SerializeCBOR = function(value)
		stored[#stored + 1] = value

		return "cbor:" .. #stored
	end,
	DeserializeCBOR = function(text)
		local function Copy(value)
			if type(value) ~= "table" then
				return value
			end
			local copy = {}
			for key, child in pairs(value) do
				copy[key] = Copy(child)
			end

			return copy
		end

		return Copy(stored[tonumber(text:match("^cbor:(%d+)$"))])
	end,
	CompressString = function(text)
		return text
	end,
	DecompressString = function(text)
		return text
	end,
	EncodeBase64 = function(text)
		return (text:gsub(".", function(char)
			return ("%02x"):format(char:byte())
		end))
	end,
	DecodeBase64 = function(text)
		return (text:gsub("%x%x", function(pair)
			return string.char(tonumber(pair, 16))
		end))
	end,
}

function GetBuildInfo()
	return "1.60.1", "70124"
end

local warnings = {}
local luaPrint = print
function print(text)
	warnings[#warnings + 1] = text
end

-- AeonSettings stand-in -----------------------------------------------------------------------------------

local kinds = {}
local dialog = {}
local window = { shown = false, refreshed = 0 }
function window:SetCategories(categories)
	self.categories = categories
end
function window:Open(page)
	self.opened = page or "<last>"
	self.shown = true
end
function window:Close()
	self.shown = false
end
function window:IsShown()
	return self.shown
end
function window:RefreshPage()
	self.refreshed = self.refreshed + 1
end
function window:SetPreviewChosen(key)
	self.chosen = key
end

local AS = {
	RegisterElementKind = function(_, kind, definition)
		kinds[kind] = definition
	end,
	CreateProfilesPage = function(_, options)
		return { id = options.id, title = options.title, adapter = options.adapter }
	end,
	ProfileDialogFrame = function()
		return {
			Open = function(_, kind, options)
				dialog.kind, dialog.options = kind, options
			end,
		}
	end,
	CreateWindow = function(_, options)
		window.options = options

		return window
	end,
}

local AUI = { AeonSettings = AS }
assert(loadfile(root .. "Core/Core.lua"))("AeonUI", AUI)
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
AUI.can = { surnames = false }
AUI.oUF = { colors = { class = {}, reaction = {}, power = {}, health = { r = 0.2, g = 0.8, b = 0.1 } } }
for level = 1, 8 do
	AUI.oUF.colors.reaction[level] = level <= 3 and { r = 0.8, g = 0.3, b = 0.2 } or level == 4 and { r = 0.9, g = 0.7, b = 0 }
		or { r = 0, g = 0.6, b = 0.1 }
end
AUI.Media = {
	FLAT = "flat",
	STRIPED = "AeonUI Thin Stripes",
	SHIELD = "Blizzard Shield",
	files = { ["AeonUI Thin Stripes"] = "stripes", ["Blizzard Shield"] = "shield" },
}
for _, file in ipairs({
	"Core/Callbacks.lua", "Profile/Schema.lua", "Profile/Store.lua", "Profile/Codec.lua", "Profile/Profile.lua",
	"Frames/Tags.lua", "Frames/Text.lua", "Frames/Overlays.lua", "Frames/HealthColor.lua", "Frames/CastBar.lua", "Frames/Auras.lua", "Frames/ClassPower.lua", "Frames/Indicators.lua", "Frames/Fading.lua", "Frames/UnitFrame.lua", "Frames/Frames.lua",
	"Settings/Note.lua", "Settings/Pages.lua", "Settings/Shared.lua", "Settings/TextSlots.lua", "Settings/Overlays.lua", "Settings/CastBar.lua", "Settings/Auras.lua", "Settings/ClassPower.lua", "Settings/Indicators.lua",
	"Settings/Previews.lua",
	"Settings/Profiles.lua", "Settings/Recovery.lua", "Settings/Settings.lua",
	"Editor/Layout.lua", "Editor/External.lua", "Editor/Mover.lua", "Editor/Panel.lua", "Editor/Editor.lua",
}) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Profile, Settings, Store, Schema = AUI.Profile, AUI.Settings, AUI.Store, AUI.Schema

function Profile:Save(data)
	AeonUIDB = data
end

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

local function Load(data)
	AeonUIDB = data
	Profile.root, Profile.quarantined = nil, {}
	Profile:Initialize(data, "Player-1")
end

---@return table<string, table> pages by id
local function Pages()
	local pages = {}
	for _, category in ipairs(Settings:Categories()) do
		for _, page in ipairs(category.pages) do
			pages[page.id] = page
		end
	end

	return pages
end

---@return table[] settings every setting the page built, in order, with section actions and menus
local function SettingsOf(elements)
	local list = {}
	for _, element in ipairs(elements) do
		if element.kind == "setting" then
			for _, setting in ipairs(element.settings or { element.setting }) do
				list[#list + 1] = setting
			end
		elseif element.kind == "section" then
			list[#list + 1] = element.action
			list[#list + 1] = element.menu
		end
	end

	return list
end

local function Find(elements, id)
	for _, setting in ipairs(SettingsOf(elements)) do
		if setting.id == id then
			return setting
		end
	end
end

local function Options(setting)
	return type(setting.options) == "function" and setting.options() or setting.options
end

-- Note element ------------------------------------------------------------------------------------------------

Equal("note kind registered", kinds.note.template, "AeonUINoteTemplate")
Equal("note search", kinds.note.Search({ text = "words" }), "words")

-- Categories ----------------------------------------------------------------------------------------------

Load(nil)
local pages = Pages()
Equal("Globals page", pages.globals.title, "Globals")
Equal("Player page", pages.player.title, "Player")
Equal("Player Power page", pages.playerPower.title, "Player Power")
Equal("Profiles page", pages.profiles.title, "Profiles")
Equal("no Recovery page in normal mode", pages.recovery, nil)
Equal("no preview on Globals", pages.globals.preview, nil)
Equal("preview on Player", type(pages.player.preview.Draw), "function")
Equal("target and focus share their sample state", pages.target.preview.stateKey, pages.focus.preview.stateKey)
Equal("player keeps its own sample state", pages.player.preview.stateKey ~= pages.target.preview.stateKey, true)
Equal("preview states", table.concat(pages.target.preview.states, ","), "Full,Damaged,Dead,Offline,Absorbs,Overflow,Casting,Channeling,Not Interruptible,Interrupted,Interrupt Ready,Important")
Equal("player preview adds empowered casts", pages.player.preview.states[#pages.player.preview.states], "Empowered")
Equal("target of target has no overlay states", table.concat(pages.targettarget.preview.states, ","),
	"Full,Damaged,Dead,Offline")
Equal("target of target keeps its own sample state", pages.targettarget.preview.stateKey ~= pages.target.preview.stateKey,
	true)
local order = {}
for _, page in ipairs(Settings:Categories()[1].pages) do
	order[#order + 1] = page.id
end
Equal("unit frame page order", table.concat(order, ","), "globals,player,pet,target,targettarget,focus,boss,playerPower,classPower")
Equal("Target of Target page", pages.targettarget.title, "Target of Target")
Equal("Focus page", pages.focus.title, "Focus")
Equal("preview on Focus", type(pages.focus.preview.Draw), "function")

-- Every setting on every page reads and saves ----------------------------------------------------------------

for _, id in ipairs({ "globals", "player", "pet", "target", "targettarget", "focus", "boss", "playerPower", "classPower" }) do
	local elements = pages[id].Build()
	local seen = {}

	for _, setting in ipairs(SettingsOf(elements)) do
		Equal(id .. "." .. setting.id .. " is unique", seen[setting.id], nil)
		seen[setting.id] = true

		if setting.control ~= "action" and not setting.id:match("CopyFrom$") then
			local value = setting.get()
			local result = setting.set(value)
			Equal(id .. "." .. setting.id .. " saves its own value", result ~= false, true)
		end
	end
end

local player = pages.player.Build()
Equal("page switch", Find(player, "enabled").pageSwitch, true)
Equal("switch label", Find(player, "enabled").label, "Show Player Frame")
Equal("x range follows the screen", Find(player, "x").max, 960)
Equal("y range follows the screen", Find(player, "y").min, -540)
Equal("width range follows the schema", Find(player, "width").max, 600)
Find(player, "width").set(300)
Equal("width saved", Profile:Get("frames.player.width"), 300)
Equal("an out-of-range value is refused", Find(player, "width").set(9000), false)

-- Settings that follow the shared ones: Shared until the frame holds its own value; Use Shared clears it.
Profile:Reset("frames.player")
player = pages.player.Build()
local precision = Find(player, "precision")
Equal("number setting shows the Globals value", precision.get(), "default")
Equal("number setting inherits", type(precision.inherit), "table")
Equal("Shared at first", precision.inherit.custom(), false)
precision.set("decimal")
Equal("own value saved", Profile:Get("frames.player.numbers.precision"), "decimal")
Equal("Custom after a change", precision.inherit.custom(), true)
precision.inherit.clear()
Equal("Use Shared clears the own value", Profile:IsCustom("frames.player.numbers.precision"), false)
Find(pages.globals.Build(), "percentDecimals").set(1)
Equal("a Shared setting shows the Globals value", Find(player, "percentDecimals").get(), 1)
Equal("a frame-only setting does not inherit", Find(player, "width").inherit, nil)
Equal("a Globals setting does not inherit", Find(pages.globals.Build(), "percentDecimals").inherit, nil)
Equal("bar texture inherits", type(Find(player, "bartexture").inherit), "table")
Equal("player has no power texture", Find(player, "barpowerTexture"), nil)
Equal("target has a power texture", type(Find(pages.target.Build(), "barpowerTexture").inherit), "table")
Equal("cast bar look inherits", type(Find(player, "castColor").inherit), "table")
Equal("cast bar position does not", Find(player, "castX").inherit, nil)
Find(pages.globals.Build(), "castColor").set({ r = 0, g = 1, b = 0 })
Equal("a frame follows a shared change", Find(player, "castColor").get().g, 1)

-- Text slots.
Equal("slot width is a percentage", Find(player, "slotWidth").format, "percent")
Equal("slot width steps by 5", Find(player, "slotWidth").step, 5)
Equal("slot width range", Find(player, "slotWidth").min .. "-" .. Find(player, "slotWidth").max, "20-200")
Equal("first slot chosen", AUI.SettingsText:Chosen("player"), 1)
Equal("combined content shows a separator", Find(player, "separator") ~= nil, true)
Equal("custom color shows a color", Find(player, "slotcolor") ~= nil, true)
Find(player, "slot").set(2)
player = pages.player.Build()
Equal("slot choice is kept", Find(player, "slot").get(), 2)
Equal("empty slot has no separator", Find(player, "separator"), nil)
Equal("slot labels show content", Options(Find(player, "slot"))[1].text, "Text 1: Health + %")
Find(player, "colorMode").set("class")
player = pages.player.Build()
Equal("class color hides the color swatch", Find(player, "slotcolor"), nil)

local useStyle = Find(player, "useTextStyle")
Equal("no own style, nothing to use", type(useStyle.blocked()), "string")
Find(player, "slotsize").set(20)
Equal("slot size saved as its own", Profile:Get("frames.player.text.slots.2.size"), 20)
Equal("frame size unchanged", Profile:Get("frames.player.text.size"), 12)
player = pages.player.Build()
Equal("own style marked", Find(player, "slotsize").description, "Custom for this slot.")
Equal("own style can be dropped", useStyle.blocked(), nil)
useStyle.set()
Equal("Use Text Style clears the slot's size", Profile:Get("frames.player.text.slots.2.size"), nil)
Find(player, "size").set(14)
Equal("slot follows the frame size again", Find(pages.player.Build(), "slotsize").get(), 14)

-- Copy Text From and Apply to All Frames.
-- Target of Target and Focus.
local focus = pages.focus.Build()
Equal("focus switch", Find(focus, "enabled").label, "Show Focus Frame")
Equal("focus status line", Find(focus, "statusLine").get(), true)
Equal("focus power bar off", Find(focus, "power").get(), false)
Equal("power bar height depends on the power bar", Find(focus, "powerHeight").depends, "power")
Find(focus, "power").set(true)
Equal("power bar saved", Profile:Get("frames.focus.power.enabled"), true)
local tot = pages.targettarget.Build()
Equal("target of target has three slots", #Options(Find(tot, "slot")), 3)
Equal("target of target starts with the name", Options(Find(tot, "slot"))[1].text, "Text 1: Name")
Equal("player status line starts off", Find(player, "statusLine").get(), false)
Equal("player has no attached power bar", Find(pages.player.Build(), "power"), nil)
Equal("target has an attached power bar", Find(pages.target.Build(), "power") ~= nil, true)
Equal("power page has no attached power bar", Find(pages.playerPower.Build(), "power"), nil)

-- Absorbs and Heals.
Equal("no overlays on target of target", Find(tot, "absorb"), nil)
Equal("no overlays on the power page", Find(pages.playerPower.Build(), "absorb"), nil)
for _, id in ipairs({ "player", "target", "focus" }) do
	local built = pages[id].Build()
	for _, kind in ipairs({ "absorb", "healAbsorb", "healPrediction" }) do
		Equal(id .. " " .. kind .. " shown", Find(built, kind).get(), true)
		Equal(id .. " " .. kind .. " position depends on it", Find(built, kind .. "Position").depends, kind)
		Equal(id .. " " .. kind .. " texture picker", Find(built, kind .. "Texture").picker, "texture")
		Equal(id .. " " .. kind .. " flat first", Options(Find(built, kind .. "Texture"))[1].value, "flat")
	end
end
local overlays = pages.player.Build()
Equal("texture order", Options(Find(overlays, "absorbTexture"))[2].value .. "," .. Options(Find(overlays, "absorbTexture"))[3].value,
	"AeonUI Thin Stripes,Blizzard Shield")
Equal("striped texture preview", Options(Find(overlays, "absorbTexture"))[2].texture, "stripes")
Equal("position choices", #Options(Find(overlays, "absorbPosition")), 7)
Equal("attach first", Options(Find(overlays, "absorbPosition"))[1].value, "attach")
Equal("height blocked while matching", Find(overlays, "absorbHeight").blocked() ~= nil, true)
Find(overlays, "absorbMatch").set(false)
Equal("height free after matching is off", Find(overlays, "absorbHeight").blocked(), nil)
Find(overlays, "absorbHeight").set(8)
Equal("height saved", Profile:Get("frames.player.overlays.absorb.height"), 8)
Equal("overshield allowed while attached", Find(overlays, "overshield").blocked(), nil)
Equal("glow allowed while attached", Find(overlays, "glow").blocked(), nil)
Find(overlays, "absorbPosition").set("TOPLEFT")
Equal("overshield blocked while detached", Find(overlays, "overshield").blocked() ~= nil, true)
Equal("glow blocked while detached", Find(overlays, "glow").blocked() ~= nil, true)
Equal("overshield choices", #Options(Find(overlays, "overshield")), 3)
Find(overlays, "absorbTexture").set("AeonUI Thin Stripes")
Equal("texture saved", Profile:Get("frames.player.overlays.absorb.texture"), "AeonUI Thin Stripes")
Find(overlays, "backing").set(35)
Equal("backing saved", Profile:Get("frames.player.overlays.healAbsorb.backing"), 35)
Equal("overheal stops at 50", Find(overlays, "overheal").max, 50)
Equal("overheal refused past 50", Find(overlays, "overheal").set(60), false)

local globals = pages.globals.Build()
Equal("absorb color has opacity", Find(globals, "absorbColor").hasOpacity, true)
Find(globals, "absorbColor").set({ r = 1, g = 0.5, b = 0, a = 0.25 })
Equal("color opacity saved", Profile:Get("overlays.colors.absorb").a, 0.25)
Equal("color saved", Profile:Get("overlays.colors.absorb").g, 0.5)
pages.globals.Reset()
Equal("globals reset restores colors", Profile:Get("overlays.colors.absorb").a, 0.8)
pages.player.Reset()
Equal("player reset restores overlays", Profile:Get("frames.player.overlays.absorb.position"), "attach")

-- Copy From and Use Shared on section headers.
local power = pages.playerPower.Build()
Equal("text copy menu lists the other frames", #Options(Find(power, "textCopyFrom")), 6)
Find(power, "textCopyFrom").set("target")
Equal("copied slot content", Profile:Get("frames.playerPower.text.slots.1.content"), "healthAndPercent")
Equal("copied second slot", Profile:Get("frames.playerPower.text.slots.2.content"), "levelName")
Equal("copied status", Profile:Get("frames.playerPower.text.status"), 1)
Equal("a copy is reported", warnings[#warnings - 1]:find("Copied Text from Target.", 1, true) ~= nil, true)
Equal("slots the frame lacks are named", warnings[#warnings]:find("Text 3", 1, true) ~= nil, true)
Profile:Set("frames.target.text.status", 4)
Find(pages.playerPower.Build(), "textCopyFrom").set("target")
Equal("a status the frame cannot hold is not copied", Profile:Get("frames.playerPower.text.status"), 1)
Equal("the status is named", warnings[#warnings]:find("Status Text In", 1, true) ~= nil, true)

Profile:Reset({ "frames.player.castbar", "frames.target.castbar" })
Profile:Set("frames.target.castbar.border", 3)
Profile:Set("frames.player.castbar.color", { r = 0, g = 0, b = 1 })
Profile:Set("frames.target.castbar.x", 40)
Find(pages.player.Build(), "castBarCopyFrom").set("target")
Equal("copy: a Custom value", Profile:Get("frames.player.castbar.border"), 3)
Equal("copy: a Shared state", Profile:IsCustom("frames.player.castbar.color"), false)
Equal("copy: position stays", Profile:Get("frames.player.castbar.x"), 0)
Equal("copy: what the player lacks is named", warnings[#warnings]:find("Interrupt Ready", 1, true) ~= nil, true)
Equal("copy menu lists only frames with the section", #Options(Find(pages.player.Build(), "castBarCopyFrom")), 3)
local useShared = Find(pages.player.Build(), "castBarUseShared")
Equal("Use Shared active while Custom", useShared.blocked(), nil)
Equal("Use Shared runs", useShared.set(), true)
Equal("Use Shared clears the section", Profile:IsCustom("frames.player.castbar.border"), false)
Equal("Use Shared keeps settings outside the shared look", Profile:Get("frames.target.castbar.x"), 40)
Equal("Use Shared is blocked once Shared", useShared.blocked() ~= nil, true)
Equal("indicators copy but hold nothing shared", Find(pages.player.Build(), "indicatorsUseShared"), nil)
Equal("indicators copy", type(Find(pages.player.Build(), "indicatorsCopyFrom")), "table")
Equal("overlays only return to Shared", Find(pages.player.Build(), "absorbsAndHealsCopyFrom"), nil)
Profile:Reset({ "frames.player", "frames.target.castbar", "frames.playerPower" })

-- Bosses.
local bosses = pages.boss.Build()
Equal("Bosses page", pages.boss.title, "Bosses")
Equal("boss switch", Find(bosses, "enabled").label, "Show Boss Frames")
Equal("growth starts down", Find(bosses, "growth").get(), "down")
Equal("growth choices", #Options(Find(bosses, "growth")), 4)
Equal("spacing starts at 14", Find(bosses, "spacing").get(), 14)
Equal("spacing range", Find(bosses, "spacing").max, 100)
Equal("no growth on single frames", Find(pages.focus.Build(), "growth"), nil)
Equal("boss power bar off", Find(bosses, "power").get(), false)
Equal("boss overlays", Find(bosses, "absorb").get(), true)
Equal("no Status Line on bosses", Find(bosses, "statusLine"), nil)
Equal("boss slots", #Options(Find(bosses, "slot")), 4)
Equal("boss status in the percentage slot", Profile:Get("frames.boss.text.status"), 2)
Equal("boss preview states", table.concat(pages.boss.preview.states, ","),
	"Full,Damaged,Dead,Offline,Absorbs,Overflow,Casting,Channeling,Not Interruptible,Interrupted,Interrupt Ready,Important,Slot Lost")
Equal("boss preview keeps its own state", pages.boss.preview.stateKey ~= pages.target.preview.stateKey, true)

local UnitFrame = AUI.UnitFrame
local function Offset(slot)
	local x, y = UnitFrame:SlotOffset(Profile.config, "boss", slot)

	return x .. "," .. y
end
Equal("first slot at the group position", Offset(1), "0,0")
Equal("a single frame has no offset", Offset(nil), "0,0")
Equal("down by height, cast bar and spacing", Offset(2), "0,-66")
Equal("down, third slot", Offset(3), "0,-132")
Profile:Set("frames.boss.castbar.enabled", false)
Equal("no cast bar space while it is off", Offset(2), "0,-46")
Profile:Set("frames.boss.castbar.enabled", true)
Find(bosses, "power").set(true)
Equal("the power bar adds to each step", Offset(2), "0,-72")
Find(bosses, "growth").set("up")
Equal("up", Offset(2), "0,72")
Find(bosses, "growth").set("right")
Find(bosses, "spacing").set(10)
Equal("right by width and spacing", Offset(3), "420,0")
Find(bosses, "growth").set("left")
Equal("left", Offset(2), "-210,0")
pages.boss.Reset()
Equal("boss reset", Profile:Get("frames.boss.growth"), "down")

-- Cast bar extras.
local playerCast, targetCast = pages.player.Build(), pages.target.Build()
Equal("ticks on the player", Find(playerCast, "castTicks").get(), true)
Equal("tick color has opacity", Find(playerCast, "castTickColor").hasOpacity, true)
Equal("last tick depends on ticks", Find(playerCast, "castLastTick").depends, "castTicks")
Equal("no interrupt colors on the player", Find(playerCast, "castReady"), nil)
Equal("player cast target off", Find(playerCast, "castTarget").get(), false)
Equal("no ticks on target", Find(targetCast, "castTicks"), nil)
Equal("interrupt ready on target", Find(targetCast, "castReady").get(), true)
Equal("cooldown mark", Find(targetCast, "castKickMark").get(), true)
Equal("window color depends on the window", Find(targetCast, "castWindowColor").depends, "castKickWindow")
Equal("target cast target on", Find(targetCast, "castTarget").get(), true)
Equal("glow off", Find(targetCast, "castGlow").get(), false)
Equal("glow styles", #Options(Find(targetCast, "castGlowStyle")), 2)
Find(targetCast, "castGlowStyle").set("blizzard")
Equal("glow style saved", Profile:Get("frames.target.castbar.glowStyle"), "blizzard")
Equal("glow speed range", Find(targetCast, "castGlowSpeed").max, 10)
Equal("bosses get interrupt colors", Find(pages.boss.Build(), "castReady") ~= nil, true)
Equal("boss cast target off", Find(pages.boss.Build(), "castTarget").get(), false)

-- Auras.
local targetAuras = pages.target.Build()
Equal("buffs section", Find(targetAuras, "buffEnabled").get(), true)
Equal("debuffs section", Find(targetAuras, "debuffEnabled").get(), true)
Equal("buff filters", #Options(Find(targetAuras, "buffFilter")), 13)
Equal("debuff filters", #Options(Find(targetAuras, "debuffFilter")), 17)
Equal("filter labels", Options(Find(targetAuras, "debuffFilter"))[6].text, "Crowd Control")
Equal("hide checkbox", Find(targetAuras, "debuffHidecrowdControl").label, "Hide Crowd Control")
Equal("buff hide categories", Find(targetAuras, "buffHidecrowdControl"), nil)
Find(targetAuras, "debuffHideboss").set(true)
Equal("hide saved", Profile:Get("frames.target.debuffs.hide.boss"), true)
local include = Find(targetAuras, "debuffInclude")
Equal("spell list control", include.control, "text")
Equal("spell list may be empty", include.get(), "")
Equal("spell list validated", include.validate("123, 456") , nil)
Equal("spell list refuses words", include.validate("Moonfire") ~= nil, true)
include.set("8921, 93402")
Equal("spell list saved", Profile:Get("frames.target.debuffs.include"), "8921, 93402")
include.set("")
Equal("spell list emptied", Profile:Get("frames.target.debuffs.include"), "")
Equal("caster choices", #Options(Find(targetAuras, "debuffListCaster")), 2)
Equal("never show list", Find(targetAuras, "debuffExclude").control, "text")
Equal("sorts", #Options(Find(targetAuras, "debuffSort")), 6)
Equal("anchors", #Options(Find(targetAuras, "debuffAnchor")), 6)
Equal("limit range", Find(targetAuras, "debuffLimit").max, 40)
Equal("per row explained", Find(targetAuras, "debuffPerRow").description ~= nil, true)
Equal("duration size depends on duration", Find(targetAuras, "debuffDurationSize").depends, "debuffDuration")
Equal("rows depend on the switch", Find(targetAuras, "debuffSort").depends, "debuffEnabled")
Equal("debuff border label", Find(targetAuras, "debuffBorder").label, "Dispel Type Border")
Equal("buff border label", Find(targetAuras, "buffBorder").label, "Stealable Glow")
Find(targetAuras, "debuffLimit").set(12)
Equal("limit saved", Profile:Get("frames.target.debuffs.limit"), 12)
Equal("no auras on target of target", Find(pages.targettarget.Build(), "buffEnabled"), nil)
Equal("no auras on the power bar", Find(pages.playerPower.Build(), "debuffEnabled"), nil)
Equal("boss debuffs on the left", Find(pages.boss.Build(), "debuffAnchor").get(), "left")
Equal("player buff clicks cancel", Find(pages.player.Build(), "buffClicks").description:find("cancels") ~= nil, true)
Equal("other clicks pass through", Find(targetAuras, "buffClicks").description:find("cancels"), nil)

-- Class Resource.
local resource = pages.classPower.Build()
Equal("Class Resource page", pages.classPower.title, "Class Resource")
Equal("page switch", Find(resource, "enabled").pageSwitch, true)
Equal("attached by default", Find(resource, "attach").get(), "power")
Equal("position follows the power bar", Find(resource, "x").blocked() ~= nil, true)
Find(resource, "attach").set("screen")
Equal("position free on the screen", Find(resource, "x").blocked(), nil)
Equal("extra mana height depends on it", Find(resource, "extraManaHeight").depends, "extraMana")
Equal("rune countdowns off", Find(resource, "runeTimers").get(), false)
Equal("class resource preview states", table.concat(pages.classPower.preview.states, ","), "Full,Partial,Empty,Charged")
pages.classPower.Reset()
Equal("class resource reset", Profile:Get("frames.classPower.attach"), "power")

-- Outline choices, with the Slug variants.
local outlines = Options(Find(pages.player.Build(), "outline"))
Equal("six outline choices", #outlines, 6)
Equal("Slug Outline label", outlines[5].text, "Slug Outline")
Equal("frame text starts with Slug Outline", Profile:Get("frames.player.text.outline"), "SLUG_OUTLINE")
Equal("cast bar text starts with Slug", Profile:Get("frames.player.castbar.outline"), "SLUG")

-- Pet frame and Blizzard's frames.
local pet = pages.pet.Build()
Equal("Pet page", pages.pet.title, "Pet")
Equal("pet switch", Find(pet, "enabled").label, "Show Pet Frame")
Equal("pet text slots", #Options(Find(pet, "slot")), 3)
Equal("pet name text", Options(Find(pet, "slot"))[1].text, "Text 1: Name")
Equal("pet status line", Find(pet, "statusLine").get(), true)
Equal("pet power bar off", Find(pet, "power").get(), false)
Equal("pet preview shares the unit states", pages.pet.preview.stateKey, pages.targettarget.preview.stateKey)
Equal("no auras on the pet", Find(pet, "buffEnabled"), nil)
Equal("pet size", Profile:Get("frames.pet.width") .. "x" .. Profile:Get("frames.pet.height"), "120x24")
for _, id in ipairs({ "player", "pet", "target", "focus", "boss" }) do
	local built = pages[id].Build()
	Equal(id .. " hides Blizzard's frame", Find(built, "hideBlizzard").get(), true)
	Equal(id .. " hide asks for a reload", Find(built, "hideBlizzard").reload, true)
	Equal(id .. " switch asks for a reload", Find(built, "enabled").reload, true)
end
Equal("no Blizzard switch on target of target", Find(pages.targettarget.Build(), "hideBlizzard"), nil)
Equal("no reload on the power bar switch", Find(pages.playerPower.Build(), "enabled").reload, nil)

local Frames = AUI.Frames
Equal("player replaces Blizzard's", Frames:HidesBlizzard(Profile.config, "player"), true)
Equal("boss replaces Blizzard's", Frames:HidesBlizzard(Profile.config, "boss"), true)
Equal("power bar leaves Blizzard's alone", Frames:HidesBlizzard(Profile.config, "playerPower"), false)
Equal("class resource leaves Blizzard's alone", Frames:HidesBlizzard(Profile.config, "classPower"), false)
Equal("no key, no hiding", Frames:HidesBlizzard(Profile.config, nil), false)
Profile:Set("frames.target.hideBlizzard", false)
Equal("switch off keeps Blizzard's", Frames:HidesBlizzard(Profile.config, "target"), false)
Profile:Set("frames.target.hideBlizzard", true)
Profile:Set("frames.focus.enabled", false)
Equal("hidden AeonUI frame keeps Blizzard's", Frames:HidesBlizzard(Profile.config, "focus"), false)
Profile:Set("frames.focus.enabled", true)
Equal("extra mana on by default", Profile:Get("frames.classPower.extraMana"), true)

-- Indicators and fading.
local playerPage = pages.player.Build()
Equal("raid marker row", Find(playerPage, "raid").get(), true)
Equal("raid size depends on it", Find(playerPage, "raidSize").depends, "raid")
Equal("indicator anchors", #Options(Find(playerPage, "raidAnchor")), 9)
Equal("resting row", Find(playerPage, "resting").get(), true)
Equal("combat off", Find(playerPage, "combat").get(), false)
Equal("threat row", Find(playerPage, "threat").get(), true)
Equal("totems row", Find(playerPage, "totems").get(), true)
Equal("player idle fade", Find(playerPage, "idleFade").get(), true)
Equal("no range fade on the player", Find(playerPage, "rangeFade"), nil)
local targetPage = pages.target.Build()
Equal("classification row", Find(targetPage, "classification").get(), false)
Equal("highlight row", Find(targetPage, "highlight").get(), true)
Equal("target range fade", Find(targetPage, "rangeFade").get(), true)
Equal("range fade amount", Find(targetPage, "rangeAlpha").get(), 50)
Equal("no totems on target", Find(targetPage, "totems"), nil)
Equal("focus has both fades", Find(pages.focus.Build(), "idleFade") ~= nil and Find(pages.focus.Build(), "rangeFade") ~= nil, true)
Equal("bosses have no fade", Find(pages.boss.Build(), "idleFade"), nil)
Equal("power bar idle fade", Find(pages.playerPower.Build(), "idleFade").get(), true)
Equal("class resource idle fade", Find(pages.classPower.Build(), "idleFade").get(), true)

-- Tooltips and click-casting.
for _, id in ipairs({ "player", "pet", "target", "targettarget", "focus", "boss" }) do
	local built = pages[id].Build()
	Equal(id .. " tooltip on", Find(built, "tooltip").get(), true)
	Equal(id .. " tooltip in combat", Find(built, "tooltipCombat").get(), false)
end
Equal("no tooltip on the power bar", Find(pages.playerPower.Build(), "tooltip"), nil)
ClickCastFrames = nil
local clickFrames = { {}, {} }
AUI.Frames:RegisterClickCasting(clickFrames)
Equal("click-cast table created", ClickCastFrames[clickFrames[2]], true)
local existing = { kept = true }
ClickCastFrames = existing
AUI.Frames:RegisterClickCasting({ clickFrames[1] })
Equal("another addon's table kept", ClickCastFrames, existing)
Equal("added to it", existing[clickFrames[1]], true)

-- Page resets.
pages.player.Reset()
Equal("player reset", Profile:Get("frames.player.width"), 270)
Equal("player reset restores slots", Profile:Get("frames.player.text.slots.3.content"), "none")
Equal("player reset leaves the target", Profile:Get("frames.target.text.status"), 4)
pages.globals.Reset()
Equal("globals reset", Profile:Get("numbers.percentDecimals"), 0)

-- Profiles adapter ------------------------------------------------------------------------------------------

Load(nil)
local adapter = Pages().profiles.adapter
Equal("built-in profile", adapter.builtin, "Default")
Equal("active profile", adapter.Active(), "Default")
adapter.New("Raid")
Equal("new profile active", adapter.Active(), "Raid")
adapter.Copy("Raid Copy")
Equal("copy active", adapter.Active(), "Raid Copy")
adapter.Rename("Raid Two")
Equal("renamed", adapter.Active(), "Raid Two")
adapter.Switch("Default")
Equal("switched", adapter.Active(), "Default")
Equal("list", table.concat(adapter.List(), ","), "Default,Raid,Raid Two")
adapter.Switch("Raid")
adapter.Delete("Raid", "Default")
Equal("deleted and replaced", adapter.Active(), "Default")
Profile.root.profilesByID[Store.DEFAULT_ID].config.future = 1
local text = adapter.Export()
local info, reason = adapter.Decode(text)
Equal("decode", reason, nil)
Equal("decode summary", info.summary, "AeonUI profile \"Default\". It holds 1 settings this version doesn't use; they are kept.")
adapter.Import(info, "Imported")
Equal("imported", adapter.Active(), "Imported")
local _, refused = adapter.Decode("LB!1!abc")
Equal("foreign string refused", refused, "This is not an AeonUI profile string, or it was cut short.")
adapter.New("raid two")
Equal("a refused name warns", warnings[#warnings]:find("already exists", 1, true) ~= nil, true)
Equal("no damaged section", #adapter.Sections(), 0)

-- Damaged profiles.
local damaged = Store:NewRoot("Player-1")
damaged.profilesByID.p00000002 = { name = "Broken", schemaVersion = 9, config = {} }
damaged.charactersByID["Player-1"].activeProfileID = "p00000002"
damaged.nextID = 3
Load(damaged)
Equal("fallback mode", Profile.mode, "fallback")
local sections = adapter.Sections()
Equal("damaged section", sections[1].title, "Damaged Profiles")
Equal("fallback note", sections[2].text:find("active profile", 1, true) ~= nil, true)
local delete = sections[3].setting
Equal("delete action names the profile", delete.label, "Broken")
Equal("delete allowed with a replacement", delete.blocked(), nil)
Equal("the active damaged profile is listed", table.concat(adapter.List(), ","), "Broken,Default")
delete.set()
Equal("damaged profile deleted", Profile.root.profilesByID.p00000002, nil)
Equal("back to normal", Profile.mode, "normal")

local lonely = Store:NewRoot("Player-1")
lonely.profilesByID[Store.DEFAULT_ID].schemaVersion = 9
Load(lonely)
Equal("no replacement blocks the delete", type(adapter.Sections()[3].setting.blocked()), "string")

-- Recovery ------------------------------------------------------------------------------------------------

Load({})
Equal("recovery mode", Profile.mode, "recovery")
local categories = Settings:Categories()
Equal("recovery shows one category", #categories, 1)
Equal("recovery page", categories[1].pages[1].id, "recovery")
local recovery = categories[1].pages[1].Build()
Equal("recovery explains", recovery[2].kind, "note")
Equal("recovery shows the problem", recovery[3].small, true)
local exportAction, resetAction = recovery[4].setting, recovery[5].setting
exportAction.set()
Equal("export opens the export dialog", dialog.kind, "export")
Equal("an empty table encodes completely", dialog.options.title, "Diagnostic Export")
Equal("reset asks first", type(resetAction.confirm), "string")
resetAction.set()
Equal("reset opens the typed confirmation", dialog.kind, "name")
Equal("the wrong word is refused", dialog.options.validate("reset"), "")
Equal("the word is accepted", dialog.options.validate("RESET"), nil)

Settings:Create()
Equal("window title", window.options.title, AUI.title)
Equal("window starts on Recovery", window.categories[1].id, "recovery")
dialog.options.accept()
Equal("reset store", Profile.mode, "normal")
Equal("window switches to the normal pages", window.categories[1].id, "unitFrames")

-- Opening.
Settings:Open("power")
Equal("alias opens the page", window.opened, "playerPower")
Settings:Open("tot")
Equal("tot opens Target of Target", window.opened, "targettarget")
Settings:Open("boss")
Equal("boss opens Bosses", window.opened, "boss")
Settings:Open("pet")
Equal("pet opens Pet", window.opened, "pet")
Settings:Open("resource")
Equal("resource opens Class Resource", window.opened, "classPower")
Settings:Open()
Equal("no word opens the last page", window.opened, "<last>")
local before = window.refreshed
Profile:Set("frames.player.width", 280)
Equal("a single setting does not rebuild the page", window.refreshed, before)
Profile:Reset()
Equal("a whole-profile change rebuilds the page", window.refreshed, before + 1)

-- Layout editor geometry ------------------------------------------------------------------------------------------

local Layout = AUI.EditorLayout
Profile:Reset()
local config = Profile.config
local player = Layout:Find("unit.player") --[[@as table]]
Equal("element found", player.key, "player")
Equal("unknown element", Layout:Find("unit.nothing"), nil)
Equal("player label", Layout:Label(player), "Player")
Equal("cast label", Layout:Label(Layout:Find("cast.player") --[[@as table]]), "Player Cast Bar")
Equal("position path", Layout:Path(player, "x"), "frames.player.x")
Equal("cast path", Layout:Path(Layout:Find("cast.player") --[[@as table]], "y"), "frames.player.castbar.y")
local left, bottom, width, height = Layout:Rect(config, player, 1920, 1080)
Equal("player rect left", left, 960 - 330 - 135)
Equal("player rect bottom", bottom, 540 - 200 - 18)
Equal("player rect size", width .. "x" .. height, "270x36")
Profile:Set("frames.target.power.enabled", true)
local _, _, _, targetHeight = Layout:Rect(Profile.config, Layout:Find("unit.target") --[[@as table]], 1920, 1080)
Equal("an attached power bar adds to the height", targetHeight, 36 + 6)
Profile:Set("frames.target.power.enabled", false)
local boss = Layout:Find("boss.group") --[[@as table]]
local bossWidth, bossHeight, shiftX, shiftY = Layout:Size(Profile.config, boss)
local castExtent = AUI.CastBar:Extent(Profile.config, "boss")
Equal("boss group spans every slot", bossHeight, 32 * 5 + (castExtent + 14) * 4)
Equal("boss group width", bossWidth, 200)
Equal("boss group centered below the first slot", shiftY, -(bossHeight - 32) / 2)
Equal("boss group no sideways shift", shiftX, 0)
Equal("class resource placed on the power bar is not a mover",
	Layout:Shown(Profile.config, Layout:Find("resource.player") --[[@as table]]), false)
Profile:Set("frames.classPower.attach", "screen")
Equal("class resource on the screen is a mover",
	Layout:Shown(Profile.config, Layout:Find("resource.player") --[[@as table]]), true)
Profile:Set("frames.player.castbar.enabled", false)
Equal("a cast bar that is off is not a mover", Layout:Shown(Profile.config, Layout:Find("cast.player") --[[@as table]]),
	false)
Profile:Set("frames.focus.enabled", false)
Equal("a frame that is off is not a mover", Layout:Shown(Profile.config, Layout:Find("unit.focus") --[[@as table]]), false)
local moved = Layout:Moved(Profile.config, player, 10.5, -4)
Equal("moved x", moved["frames.player.x"], -330 + 10.5)
Equal("moved y", moved["frames.player.y"], -204)
local lines = Layout:Lines({ { 100, 200, 50, 20 } }, 1920, 1080)
Equal("lines: screen center first", lines.x[1], 960)
Equal("lines: edges and centers", #lines.x .. "," .. #lines.y, "4,4")
local snappedLeft, snappedBottom, guideX, guideY = Layout:Snap(146, 300, 40, 10, lines, 8)
Equal("snap: left edge meets the right edge", snappedLeft, 150)
Equal("snap: guide", guideX, 150)
Equal("snap: nothing near vertically", snappedBottom .. "," .. tostring(guideY), "300,nil")
snappedLeft = Layout:Snap(940, 0, 40, 10, lines, 8)
Equal("snap: center to the screen center", snappedLeft, 940)
snappedLeft = Layout:Snap(500, 0, 40, 10, lines, 8)
Equal("snap: too far does not move", snappedLeft, 500)
Equal("clamp", Layout:Clamp(-5, 0, 10) .. "," .. Layout:Clamp(15, 0, 10), "0,10")
Profile:Reset()

-- Editor session --------------------------------------------------------------------------------------------------

local Editor = AUI.Editor
Equal("editor starts inactive", Editor.active, false)
Editor:OnSettingsShown()
Equal("settings outside a session leave the editor alone", Editor.hidden, false)
Equal("snap preference defaults on", Profile:EditorPreference("snap", true), true)
Equal("a preference saves", Profile:SetEditorPreference("grid", "DIMMED"), true)
Equal("a preference reads back", Profile:EditorPreference("grid", "BRIGHT"), "DIMMED")
Equal("a preference stays out of the profile", Profile.config.grid, nil)

-- Attachments and size links -------------------------------------------------------------------------------------

Profile:Reset()
local pet = Layout:Find("unit.pet") --[[@as table]]
local focus = Layout:Find("unit.focus") --[[@as table]]
Equal("attach keeps the position", Editor:Attach("unit.pet", "unit.player", "BOTTOM"), true)
Equal("attached", Profile:Get("frames.pet.layout.attach.target"), "unit.player")
Equal("position kept x", Profile:Get("frames.pet.x"), -405)
Equal("position kept y", Profile:Get("frames.pet.y"), -234)
Equal("offset x from the bottom center", Profile:Get("frames.pet.layout.attach.x"), -75)
Equal("offset y below the edge", Profile:Get("frames.pet.layout.attach.y"), -4)
local fired
AUI.Callbacks:Register("Profile", {}, function(_, path)
	fired = path or "*"
end)
Profile:Set("frames.player.x", -320)
Equal("the attached frame follows", Profile:Get("frames.pet.x"), -395)
Equal("a change that moves others announces the whole profile", fired, "*")
Profile:Set("frames.player.height", 46)
Equal("a taller target moves the frame below it", Profile:Get("frames.pet.y"), -239)
Profile:Set("frames.player.reverse", true)
Equal("an unrelated change announces itself", fired, "frames.player.reverse")
local moves = Layout:Moved(Profile.config, pet, 5, 0)
Equal("dragging an attached frame changes its offset", moves["frames.pet.layout.attach.x"], -70)
Profile:SetPaths(moves)
Equal("the offset moves it", Profile:Get("frames.pet.x"), -390)
Equal("its X reads the offset", Layout:FieldPath(Profile.config, pet, "x"), "frames.pet.layout.attach.x")
Equal("loop: the target is not offered", (function()
	for _, element in ipairs(Layout:Eligible(Profile.config, player)) do
		if element.id == "unit.pet" then
			return true
		end
	end

	return false
end)(), false)
Equal("loop: refused", (Profile:Set("frames.player.layout.attach.target", "unit.pet")), false)
Equal("loop: nothing changed", Profile:Get("frames.player.layout.attach.target"), "none")
Equal("loop: refused across link kinds", (Profile:Set("frames.player.layout.width", "unit.pet")), false)
local looped = AUI:CopyTable(Profile.config)
Schema:Write(looped, "frames.player.layout.height", "unit.pet")
Equal("loop: a config with one is invalid", (Schema:ValidateConfig(looped)), false)
local playerX = Find(pages.player.Build(), "x")
local petPage = pages.pet.Build()
Equal("player X stays free", playerX.blocked(), nil)
Equal("attached X is disabled with a reason", Find(petPage, "x").blocked(), "Attached to Player. Move it in Edit Mode.")
Equal("detach", Editor:Attach("unit.pet"), true)
Equal("detached", Profile:Get("frames.pet.layout.attach.target"), "none")
Equal("detaching keeps the position", Profile:Get("frames.pet.x"), -390)
Profile:Set("frames.player.x", -300)
Equal("a detached frame stays", Profile:Get("frames.pet.x"), -390)

Equal("link width", Editor:Link("unit.pet", "width", "unit.focus"), true)
Equal("linked width matches", Profile:Get("frames.pet.width"), 200)
Profile:Set("frames.focus.width", 220)
Equal("linked width follows", Profile:Get("frames.pet.width"), 220)
Equal("linked width slider is disabled", Find(pages.pet.Build(), "width").blocked(), "Matches Focus.")
Editor:Link("unit.pet", "height", "power.player")
Equal("a linked size stays in range", Profile:Get("frames.pet.height"), 16)
Editor:Link("unit.pet", "width")
Profile:Set("frames.focus.width", 240)
Equal("an unlinked width stays", Profile:Get("frames.pet.width"), 220)
Equal("match once", Editor:MatchNow("unit.pet", "width", "unit.focus"), true)
Equal("matched once", Profile:Get("frames.pet.width"), 240)
Equal("match once leaves no link", Profile:Get("frames.pet.layout.width"), "none")
Profile:Set("frames.focus.width", 250)
Equal("a one-time match does not follow", Profile:Get("frames.pet.width"), 240)

local bossGroup = Layout:Find("boss.group") --[[@as table]]
Editor:Attach("unit.focus", "boss.group", "LEFT")
local groupLeft, groupBottom, groupWidth, groupHeight = Layout:Rect(Profile.config, bossGroup, 0, 0)
local focusLeft, focusBottom, focusWidth, focusHeight = Layout:Rect(Profile.config, focus, 0, 0)
Equal("attached to a group keeps the position", focusLeft .. "," .. focusBottom, (-330 - 125) .. "," .. (-140 - 12))
Editor:SetField("unit.focus", "x", 0)
Editor:SetField("unit.focus", "y", 0)
focusLeft, focusBottom, focusWidth, focusHeight = Layout:Rect(Profile.config, focus, 0, 0)
Equal("zero offsets touch the group's left edge", focusLeft + focusWidth, groupLeft)
Equal("zero offsets center on the group", focusBottom + focusHeight / 2, groupBottom + groupHeight / 2)
Equal("copying the cast bar leaves out its attachment", (function()
	for _, path in ipairs(AUI.SettingsShared:Paths("player", AUI.SettingsShared.SCOPES.castBar)) do
		if path:find("castbar.layout.", 1, true) then
			return true
		end
	end

	return false
end)(), false)
pages.pet.Reset()
Equal("page defaults unlink", Profile:Get("frames.pet.layout.width"), "none")
Profile:Reset()

for _, element in ipairs(Layout.ELEMENTS) do
	Equal("element paths agree: " .. element.id, Schema.LAYOUT_ELEMENTS[element.id],
		"frames." .. element.key .. "." .. element.base)
end

-- External targets ------------------------------------------------------------------------------------------------

local function Offered(element, id)
	for _, other in ipairs(Layout:Eligible(Profile.config, element)) do
		if other.id == id then
			return true
		end
	end

	return false
end

Profile:Reset()
local bars = Layout:Find("levelbound.bars") --[[@as table]]
Equal("external found", bars.external, true)
Equal("external label", Layout:Label(bars), "Levelbound Bars")
Equal("an external target not yet found is not offered", Offered(pet, "levelbound.bars"), false)
Layout.external["levelbound.bars"] = { x = 0, y = -300, width = 400, height = 20 }
Equal("a found external target is offered", Offered(pet, "levelbound.bars"), true)
Editor:Attach("unit.pet", "levelbound.bars", "TOP")
Equal("attaching to it keeps the position", Profile:Get("frames.pet.x"), -405)
Layout.external["levelbound.bars"] = { x = 10, y = -300, width = 400, height = 20 }
Profile:Recalculate()
Equal("the attached frame follows the external frame", Profile:Get("frames.pet.x"), -395)
Editor:Link("power.player", "width", "levelbound.bars")
Equal("a size linked to the external frame matches it", Profile:Get("frames.playerPower.width"), 400)
Layout.external["levelbound.bars"] = false
Profile:Recalculate()
Equal("a missing external frame marks the element waiting", Profile:Get("frames.pet.layout.attach.waiting"), true)
Equal("a waiting element keeps its position", Profile:Get("frames.pet.x"), -395)
Equal("a linked size keeps its last value", Profile:Get("frames.playerPower.width"), 400)
Equal("waiting X reason", Find(pages.pet.Build(), "x").blocked(), "Waiting to reconnect to Levelbound Bars.")
Layout.external["levelbound.bars"] = { x = 50, y = -300, width = 380, height = 20 }
Profile:Recalculate()
Equal("a returned frame does not move a waiting element", Profile:Get("frames.pet.x"), -395)
Equal("a linked size follows again", Profile:Get("frames.playerPower.width"), 380)
Equal("reconnect", Editor:Reconnect("unit.pet"), true)
Equal("reconnected", Profile:Get("frames.pet.layout.attach.waiting"), false)
Equal("reconnecting applies the stored offsets", Profile:Get("frames.pet.x"), -355)
Layout.external["levelbound.bars"] = nil
Profile:Recalculate()
Equal("a frame not yet looked for does not mark waiting", Profile:Get("frames.pet.layout.attach.waiting"), false)
Layout.external["levelbound.bars"] = false
Profile:Recalculate()
Editor:Attach("unit.pet")
Equal("detaching ends the wait", Profile:Get("frames.pet.layout.attach.waiting"), false)
Equal("detached", Profile:Get("frames.pet.layout.attach.target"), "none")

-- Measuring the external frame.
local External = AUI.EditorExternal
AUI.Events = AUI.Events or { Merge = function() end, Register = function() end }
local loaded = false
C_AddOns.IsAddOnLoaded = function()
	return loaded
end
function GetTime()
	return 100
end
function hooksecurefunc() end
UIParent.GetEffectiveScale = function()
	return 1
end
LevelboundBarGroup = {
	GetRect = function()
		return 760, 100, 400, 20
	end,
	GetEffectiveScale = function()
		return 0.5
	end,
	HookScript = function() end,
}
External.started = 0
External:Update()
Equal("not loaded: missing", Layout.external["levelbound.bars"], false)
loaded = true
External:Update()
local rect = Layout.external["levelbound.bars"] --[[@as table]]
Equal("loaded: measured in UIParent units", rect.width .. "x" .. rect.height, "200x10")
Equal("measured center", rect.x .. "," .. rect.y, (380 + 100 - 960) .. "," .. (50 + 5 - 540))
LevelboundBarGroup.GetRect = function() end
External.started = 99
External:Update()
Equal("no position just after login: not yet known", Layout.external["levelbound.bars"], nil)
External.started = 0
External:Update()
Equal("no position later: missing", Layout.external["levelbound.bars"], false)
Layout.external["levelbound.bars"] = nil
LevelboundBarGroup = nil

-- Sample states.
local Previews = AUI.SettingsPreviews
local function HasState(key, label)
	for _, state in ipairs(Previews:States(key)) do
		if state.label == label then
			return true
		end
	end

	return false
end
Equal("target of target has no cast state", HasState("targettarget", "Casting"), false)
Equal("target has cast states", HasState("target", "Casting"), true)
Equal("bosses can lose a slot", HasState("boss", "Slot Lost"), true)
Equal("the player cast bar has the empowered state", HasState("cast", "Empowered"), true)
Equal("cast bar state key", Editor:StateKey(Layout:Find("cast.player") --[[@as table]]), "cast")
Editor.states = {}
Equal("default state is full", Editor:SampleState(player).label, "Full")
Editor.states["unit.player"] = "Damaged"
Equal("a chosen state", Editor:SampleState(player).label, "Damaged")
Editor.states["unit.player"] = "Nothing"
Equal("an unknown state falls back to the default", Editor:SampleState(player).label, "Full")
Editor.states = {}
Profile:Reset()

print = luaPrint
io.stdout:write(("check_settings: %d checks passed\n"):format(checks))
