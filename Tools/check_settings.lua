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
PLAYER, TARGET, COLOR, DELETE, RESET, DEAD, PLAYER_OFFLINE = "Player", "Target", "Color", "Delete", "Reset", "Dead",
	"Offline"
SlashCmdList = {}
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
AUI.oUF = { colors = { class = {}, reaction = {}, power = {} } }
AUI.Media = {
	FLAT = "flat",
	STRIPED = "AeonUI Thin Stripes",
	SHIELD = "Blizzard Shield",
	files = { ["AeonUI Thin Stripes"] = "stripes", ["Blizzard Shield"] = "shield" },
}
for _, file in ipairs({
	"Core/Callbacks.lua", "Profile/Schema.lua", "Profile/Store.lua", "Profile/Codec.lua", "Profile/Profile.lua",
	"Frames/Tags.lua", "Frames/Text.lua", "Frames/Overlays.lua", "Frames/CastBar.lua", "Frames/Auras.lua", "Frames/UnitFrame.lua",
	"Settings/Note.lua", "Settings/Pages.lua", "Settings/TextSlots.lua", "Settings/Overlays.lua", "Settings/CastBar.lua", "Settings/Auras.lua",
	"Settings/Previews.lua",
	"Settings/Profiles.lua", "Settings/Recovery.lua", "Settings/Settings.lua",
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
Equal("unit frame page order", table.concat(order, ","), "globals,player,target,targettarget,focus,boss,playerPower")
Equal("Target of Target page", pages.targettarget.title, "Target of Target")
Equal("Focus page", pages.focus.title, "Focus")
Equal("preview on Focus", type(pages.focus.preview.Draw), "function")

-- Every setting on every page reads and saves ----------------------------------------------------------------

for _, id in ipairs({ "globals", "player", "target", "targettarget", "focus", "boss", "playerPower" }) do
	local elements = pages[id].Build()
	local seen = {}

	for _, setting in ipairs(SettingsOf(elements)) do
		Equal(id .. "." .. setting.id .. " is unique", seen[setting.id], nil)
		seen[setting.id] = true

		if setting.control ~= "action" and setting.id ~= "copyText" then
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

-- Number overrides.
local precision = Find(player, "precision")
Equal("override follows Globals at first", precision.get(), "__global")
Equal("global entry names the value", Options(precision)[1].text, "Global (Blizzard Default)")
precision.set("decimal")
Equal("override saved", Profile:Get("frames.player.numbers.precision"), "decimal")
precision.set("__global")
Equal("Global clears the override", Profile:Get("frames.player.numbers.precision"), nil)
local decimals = Find(player, "percentDecimals")
pages.globals.Build()
Find(pages.globals.Build(), "percentDecimals").set(1)
Equal("global entry shows the Globals value", Options(decimals)[1].text, "Global (100.0%)")

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

local power = pages.playerPower.Build()
Equal("copy menu lists the other frames", #Options(Find(power, "copyText")), 5)
Find(power, "copyText").set("target")
Equal("copied slot content", Profile:Get("frames.playerPower.text.slots.1.content"), "healthAndPercent")
Equal("copied second slot", Profile:Get("frames.playerPower.text.slots.2.content"), "levelName")
Equal("copied status", Profile:Get("frames.playerPower.text.status"), 1)
AUI.SettingsText:Choose("target", 3)
local target = pages.target.Build()
Find(target, "applyToAll").set()
Equal("slot 3 applied to the player", Profile:Get("frames.player.text.slots.3.content"), "power")
Equal("slot 3 applied to target of target", Profile:Get("frames.targettarget.text.slots.3.content"), "power")
Equal("slot 3 applied to focus", Profile:Get("frames.focus.text.slots.3.content"), "power")
Equal("frames without slot 3 untouched", Schema:Field("frames.playerPower.text.slots.3.content"), nil)
Profile:Set("frames.target.text.status", 4)
Find(pages.playerPower.Build(), "copyText").set("target")
Equal("a status the frame cannot hold is not copied", Profile:Get("frames.playerPower.text.status"), 1)

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
Settings:Open()
Equal("no word opens the last page", window.opened, "<last>")
local before = window.refreshed
Profile:Set("frames.player.width", 280)
Equal("a single setting does not rebuild the page", window.refreshed, before)
Profile:Reset()
Equal("a whole-profile change rebuilds the page", window.refreshed, before + 1)

print = luaPrint
io.stdout:write(("check_settings: %d checks passed\n"):format(checks))
