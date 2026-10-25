-- Checks the Tooltip module outside the game: its settings and their bounds, the scaled font sizes and the health
-- bar's place in each style, the tooltip font objects taking the font settings and getting Blizzard's fonts back, the
-- health bar's showing, place, height and texture with the module on and off, the room a tooltip keeps for the strip, and which profile
-- changes re-apply the module; the unit text (names, guild, level and marks) and the unit tooltips' edited and added
-- lines, the health bar's color, secret values left alone, and the aura caster names CVar.
-- Run from any directory with Lua 5.1: lua Tools/check_tooltip.lua
-- Loads the real files against stubbed globals. It proves the logic, not the drawing.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

UNKNOWN = "Unknown"
local questCallbacks = {}
EventRegistry = {
	RegisterCallback = function(_, event, handler, owner)
		questCallbacks[event] = function(...)
			handler(owner, ...)
		end
	end,
}
TOOLTIP_UNIT_LEVEL = "Level %s"
SlashCmdList = {}
C_AddOns = {
	GetAddOnMetadata = function() end,
}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"

local LSM_FILES = {
	font = { ["Friz Quadrata TT"] = "Fonts\\FRIZQT__.TTF", ["Expressway"] = "Fonts\\Expressway.ttf" },
	statusbar = {},
}
local LSM = {
	MediaType = { FONT = "font", STATUSBAR = "statusbar" },
	Register = function(_, kind, name, file)
		LSM_FILES[kind][name] = file
	end,
	Fetch = function(_, kind, name)
		local files = LSM_FILES[kind]

		return files and files[name]
	end,
}

function LibStub()
	return LSM
end

-- A widget stub: calling a method its widget type lacks is an error.
local function Widget(kind, methods)
	return setmetatable(methods, {
		__index = function(_, name)
			error(("%s has no method %s"):format(kind, tostring(name)), 2)
		end,
	})
end

---@param file string
---@param size number
local function FontObject(file, size)
	local font = { file = file, size = size, flags = "", sets = 0 }

	return Widget("Font", {
		GetFont = function()
			return font.file, font.size, font.flags
		end,
		SetFont = function(_, newFile, newSize, newFlags)
			font.file, font.size, font.flags = newFile, newSize, newFlags
			font.sets = font.sets + 1
		end,
		state = font,
	})
end

GameTooltipHeaderText = FontObject("Fonts\\FRIZQT__.TTF", 14)
GameTooltipText = FontObject("Fonts\\FRIZQT__.TTF", 12)
GameTooltipTextSmall = FontObject("Fonts\\FRIZQT__.TTF", 10)

-- Stands in for a secret value; `issecretvalue` knows it.
local SECRET = setmetatable({}, { __tostring = function()
	return "secret"
end })

function issecretvalue(value)
	return value == SECRET
end

local hooks = {}
function hooksecurefunc(object, method, handler)
	hooks[method] = handler
	assert(object[method], method)
end

Enum = {
	TooltipDataType = { Item = 0, Spell = 1, Unit = 2, Corpse = 3, Object = 4, Currency = 5, UnitAura = 7, Mount = 10,
		PetAction = 11, Toy = 19, Quest = 23, Macro = 25 },
	TooltipDataLineType = { None = 0, UnitName = 2, UnitOwner = 16, UnitLevel = 47 },
}
local postCalls = {}
TooltipDataProcessor = {
	AddTooltipPostCall = function(kind, handler)
		postCalls[kind] = postCalls[kind] or {}
		table.insert(postCalls[kind], handler)
	end,
}

local forbidden = false
local padding = { right = 0, bottom = 0, left = 0, top = 0 }
local scripts = {}
local added = {}

local function HookScript(_, script, handler)
	scripts[script] = scripts[script] or {}
	table.insert(scripts[script], handler)
end

---Runs every handler hooked to a script.
local function Fire(script, ...)
	for _, handler in ipairs(scripts[script]) do
		handler(...)
	end
end

-- What GameTooltip shows and what was asked of it, for the checks to set and read.
local shown = { visible = true, quest = false, refreshes = 0, shows = 0 }

---@param name string
local function NewTooltip(name)
	return Widget("GameTooltip", {
		IsForbidden = function()
			return forbidden
		end,
		GetName = function()
			return name
		end,
		AddLine = function(_, text)
			added[#added + 1] = { left = text }
		end,
		AddDoubleLine = function(_, left, right, lr, lg, lb, rr, rg, rb)
			added[#added + 1] = { left = left, right = right, label = { lr, lg, lb }, color = { rr, rg, rb } }
		end,
	})
end

GameTooltip = Widget("GameTooltip", {
	IsForbidden = function()
		return forbidden
	end,
	GetName = function()
		return "GameTooltip"
	end,
	IsShown = function()
		return shown.visible
	end,
	IsTooltipType = function(_, kind)
		return shown.quest and kind == Enum.TooltipDataType.Quest
	end,
	GetPrimaryTooltipData = function()
		return shown.data
	end,
	RefreshData = function()
		shown.refreshes = shown.refreshes + 1
	end,
	Show = function()
		shown.shows = shown.shows + 1
	end,
	AddLine = function(_, text)
		added[#added + 1] = { left = text }
	end,
	GetPadding = function()
		return padding.right, padding.bottom, padding.left, padding.top
	end,
	SetPadding = function(_, right, bottom, left, top)
		padding.right, padding.bottom, padding.left, padding.top = right, bottom, left or 0, top or 0
	end,
	HookScript = HookScript,
	AddDoubleLine = function(_, left, right, lr, lg, lb, rr, rg, rb)
		added[#added + 1] = { left = left, right = right, label = { lr, lg, lb }, color = { rr, rg, rb } }
	end,
})

local bar = { points = {}, calls = 0, shown = false }
local barTexture = Widget("Texture", {
	SetColorTexture = function()
		bar.colored = true
	end,
})
GameTooltipStatusBar = Widget("StatusBar", {
	ClearAllPoints = function()
		bar.points = {}
		bar.calls = bar.calls + 1
	end,
	SetPoint = function(_, point, relative, relativePoint, x, y)
		bar.points[#bar.points + 1] = { point = point, relative = relative, relativePoint = relativePoint, x = x, y = y }
	end,
	SetHeight = function(_, height)
		bar.height = height
	end,
	SetStatusBarTexture = function(_, file)
		bar.texture, bar.colored = file, false
	end,
	GetStatusBarTexture = function()
		return barTexture
	end,
	IsShown = function()
		return bar.shown
	end,
	Show = function()
		bar.shown = true
	end,
	SetAlpha = function(_, alpha)
		bar.alpha = alpha
	end,
	SetStatusBarColor = function(_, r, g, b)
		bar.color = { r, g, b }
	end,
	HookScript = HookScript,
})

local AUI = {}
assert(loadfile(root .. "Core/Core.lua"))("AeonUI", AUI)
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
AUI.can = {}
for _, file in ipairs({ "Profile/Schema.lua", "Media/Media.lua", "Minimap/Elements.lua", "Tooltip/Options.lua",
	"Tooltip/Format.lua", "Tooltip/Appearance.lua", "Tooltip/Units.lua", "Tooltip/Details.lua", "Tooltip/Tooltip.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Schema, Options, Tooltip = AUI.Schema, AUI.TooltipOptions, AUI.Tooltip

-- The profile owner, holding the settings' defaults until a check sets one.
local values = {}
AUI.Profile = {
	Get = function(_, path)
		if values[path] ~= nil then
			return values[path]
		end

		return Schema:Field(path).default
	end,
}
AUI.Settings = {
	Default = function(_, path)
		return Schema:Field(path).default
	end,
}

local coalesced = {}
local events = {}
AUI.Events = {
	Register = function(_, event, owner, handler)
		events[event] = function(...)
			handler(owner, event, ...)
		end
	end,
	Coalesce = function(_, key, handler)
		coalesced[#coalesced + 1] = key
		handler()
	end,
}
AUI.Callbacks = {
	Register = function() end,
}

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

local function BarAt(name, point, relativePoint, x, y)
	local found

	for _, set in ipairs(bar.points) do
		if set.point == point then
			found = set
		end
	end

	Equal(name .. ": set", found ~= nil, true)
	Equal(name .. ": on the tooltip", found.relative, GameTooltip)
	Equal(name .. ": its point", found.relativePoint, relativePoint)
	Equal(name .. ": x", found.x, x)
	Equal(name .. ": y", found.y, y)
end

-- Settings ----------------------------------------------------------------------------------------------------

Equal("the module defaults on", Schema:Field(Options.ENABLED_PATH).default, true)
Equal("Blizzard's fonts by default", Schema:Field(Options.FONT_CUSTOM_PATH).default, false)
Equal("the font defaults to Blizzard's face", Schema:Field(Options.FONT_FACE_PATH).default, "Friz Quadrata TT")
Equal("the font scale defaults to Blizzard's sizes", Schema:Field(Options.FONT_SCALE_PATH).default, 100)
Equal("the health bar defaults off", Schema:Field(Options.BAR_SHOWN_PATH).default, false)
Equal("the Slug outline by default", Schema:Field(Options.FONT_OUTLINE_PATH).default, "SLUG")
Equal("the bar defaults to Blizzard's place", Schema:Field(Options.BAR_STYLE_PATH).default, "BLIZZARD")
Equal("and Blizzard's fill", Schema:Field(Options.BAR_TEXTURE_PATH).default, AUI.Media.TOOLTIP_BAR)
Equal("and Blizzard's height", Schema:Field(Options.BAR_HEIGHT_PATH).default, 8)
Equal("an unknown style is refused", (Schema:CheckValue(Options.BAR_STYLE_PATH, "SIDE")), false)
Equal("a scale above 150% is refused", (Schema:CheckValue(Options.FONT_SCALE_PATH, 155)), false)
Equal("a scale below 70% is refused", (Schema:CheckValue(Options.FONT_SCALE_PATH, 65)), false)
Equal("a bar above 16 is refused", (Schema:CheckValue(Options.BAR_HEIGHT_PATH, 17)), false)
Equal("a bar of 1 is accepted", (Schema:CheckValue(Options.BAR_HEIGHT_PATH, 1)), true)
Equal("Blizzard's tooltip fill is registered", LSM_FILES.statusbar[AUI.Media.TOOLTIP_BAR],
	"Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")

-- Arithmetic ----------------------------------------------------------------------------------------------------

Equal("the title is 14 at 100%", Options:FontSize("header", 100), 14)
Equal("the text is 12 at 100%", Options:FontSize("body", 100), 12)
Equal("small text is 10 at 100%", Options:FontSize("small", 100), 10)
Equal("a scaled title rounds to the nearest size", Options:FontSize("header", 125), 18)
Equal("halves round up", Options:FontSize("body", 125), 15)
Equal("small text scales too", Options:FontSize("small", 70), 7)

local left, right = Options:BarPlace("BLIZZARD")
Equal("Blizzard's place hangs under the bottom left", left.from .. ">" .. left.to, "TOPLEFT>BOTTOMLEFT")
Equal("2 in and 1 below", left.x .. " " .. left.y, "2 -1")
Equal("and under the bottom right", right.from .. ">" .. right.to, "TOPRIGHT>BOTTOMRIGHT")
Equal("2 in from the right", right.x .. " " .. right.y, "-2 -1")
left, right = Options:BarPlace("STRIP")
Equal("the strip sits inside the bottom edge", left.from .. ">" .. left.to, "BOTTOMLEFT>BOTTOMLEFT")
Equal("inside the border", left.x .. " " .. left.y, "3 3")
Equal("on both sides", right.x .. " " .. right.y, "-3 3")
Equal("an unknown style is Blizzard's place", (Options:BarPlace("SIDE")).to, "BOTTOMLEFT")
Equal("a strip keeps its height and a pixel", Options:StripPadding(3), 4)

-- Fonts ---------------------------------------------------------------------------------------------------------

Tooltip:Start()
Equal("starting applies at once", coalesced[1], nil)
Equal("Blizzard's fonts are left alone by default", GameTooltipText.state.sets, 0)
Equal("the bar goes to Blizzard's place", #bar.points, 2)
BarAt("default bar left", "TOPLEFT", "BOTTOMLEFT", 2, -1)
Equal("at Blizzard's height", bar.height, 8)
Equal("with Blizzard's fill", bar.texture, "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
Equal("hidden by default", bar.alpha, 0)
bar.shown = false
GameTooltipStatusBar:Show()
hooks.Show(GameTooltipStatusBar)
Equal("Blizzard showing it keeps it hidden", bar.alpha, 0)
bar.shown = false

values[Options.FONT_SCALE_PATH] = 125
Tooltip:Apply()
Equal("the scale keeps Blizzard's face", GameTooltipHeaderText.state.file, "Fonts\\FRIZQT__.TTF")
Equal("and scales the title", GameTooltipHeaderText.state.size, 18)
Equal("and the text", GameTooltipText.state.size, 15)
Equal("and the small text", GameTooltipTextSmall.state.size, 13)
Equal("with Blizzard's flags", GameTooltipText.state.flags, "")
values[Options.FONT_SCALE_PATH] = 100
Tooltip:Apply()
Equal("100% gives Blizzard's sizes back", GameTooltipText.state.size, 12)

values[Options.FONT_CUSTOM_PATH] = true
values[Options.FONT_FACE_PATH] = "Expressway"
values[Options.FONT_OUTLINE_PATH] = "OUTLINE"
Tooltip:OnProfileChanged(Options.FONT_CUSTOM_PATH)
Equal("a tooltip setting re-applies", coalesced[#coalesced], "tooltipApply")
Equal("the title takes the face", GameTooltipHeaderText.state.file, "Fonts\\Expressway.ttf")
Equal("at Blizzard's title size", GameTooltipHeaderText.state.size, 14)
Equal("the text at Blizzard's size", GameTooltipText.state.size, 12)
Equal("with the outline", GameTooltipText.state.flags, "OUTLINE")
values[Options.FONT_SCALE_PATH] = 70
Tooltip:Apply()
Equal("the face takes the scale", GameTooltipText.state.size, 8)
values[Options.FONT_SCALE_PATH] = nil
values[Options.FONT_OUTLINE_PATH] = nil
Tooltip:Apply()
Equal("the default outline is Slug", GameTooltipText.state.flags, "SLUG")

values[Options.FONT_FACE_PATH] = "Missing"
Tooltip:Apply()
Equal("an unknown face falls back to the standard font", GameTooltipText.state.file, STANDARD_TEXT_FONT)

values[Options.FONT_CUSTOM_PATH] = false
Tooltip:Apply()
Equal("Blizzard's title comes back", GameTooltipHeaderText.state.size, 14)
Equal("Blizzard's body comes back", GameTooltipText.state.size, 12)
Equal("Blizzard's small text comes back", GameTooltipTextSmall.state.size, 10)
Equal("without an outline", GameTooltipText.state.flags, "")
local sets = GameTooltipText.state.sets
Tooltip:Apply()
Equal("fonts already Blizzard's are not set again", GameTooltipText.state.sets, sets)

local before = #coalesced
Tooltip:OnProfileChanged("minimap.width")
Equal("other features' settings are ignored", #coalesced, before)
Tooltip:OnProfileChanged(nil)
Equal("a whole-profile change re-applies", #coalesced, before + 1)

-- Health bar ----------------------------------------------------------------------------------------------------

values[Options.BAR_SHOWN_PATH] = true
Tooltip:Apply()
Equal("shown when turned on", bar.alpha, 1)
hooks.Show(GameTooltipStatusBar)
Equal("and stays shown when Blizzard shows it", bar.alpha, 1)
values[Options.BAR_STYLE_PATH] = "STRIP"
values[Options.BAR_TEXTURE_PATH] = AUI.Media.STRIPED
LSM_FILES.statusbar[AUI.Media.STRIPED] = "Interface\\AddOns\\AeonUI\\Media\\Textures\\ThinStripes.png"
values[Options.BAR_HEIGHT_PATH] = 3
Tooltip:Apply()
BarAt("strip left", "BOTTOMLEFT", "BOTTOMLEFT", 3, 3)
BarAt("strip right", "BOTTOMRIGHT", "BOTTOMRIGHT", -3, 3)
Equal("the strip takes the height", bar.height, 3)
Equal("and the texture", bar.texture, "Interface\\AddOns\\AeonUI\\Media\\Textures\\ThinStripes.png")

values[Options.BAR_TEXTURE_PATH] = AUI.Media.FLAT
Tooltip:Apply()
Equal("the flat fill is a plain color", bar.colored, true)

-- Room for the strip ------------------------------------------------------------------------------------------

local Pad = postCalls[Enum.TooltipDataType.Unit][1]
Equal("unit tooltips are padded", Pad ~= nil, true)
Equal("and object tooltips", postCalls[Enum.TooltipDataType.Object][1], Pad)
Pad(GameTooltip)
Equal("no room while the bar is hidden", padding.bottom, 0)
bar.shown = true
padding.right, padding.bottom = 5, 2
Pad(GameTooltip)
Equal("room below the last line", padding.bottom, 6)
Equal("the other sides are kept", padding.right, 5)
Pad(GameTooltip)
Equal("added once per content", padding.bottom, 6)
Fire("OnTooltipCleared", GameTooltip)
Equal("taken back when the lines clear", padding.bottom, 2)
Pad({})
Equal("other tooltips are left alone", padding.bottom, 2)
Pad(GameTooltip)
Fire("OnHide", GameTooltip)
padding.bottom = 0
Pad(GameTooltip)
Equal("after Blizzard clears it on hide, added afresh", padding.bottom, 4)
Fire("OnTooltipCleared", GameTooltip)
values[Options.BAR_STYLE_PATH] = "BLIZZARD"
Tooltip:Apply()
Pad(GameTooltip)
Equal("no room in Blizzard's place", padding.bottom, 0)
values[Options.BAR_STYLE_PATH] = "STRIP"
values[Options.BAR_SHOWN_PATH] = false
Tooltip:Apply()
Pad(GameTooltip)
Equal("no room while the bar is turned off", padding.bottom, 0)
values[Options.BAR_SHOWN_PATH] = true
Tooltip:Apply()
bar.shown = false

values[Options.FONT_CUSTOM_PATH] = true
Tooltip:Apply()
values[Options.ENABLED_PATH] = false
Tooltip:Apply()
BarAt("off: Blizzard's place", "TOPLEFT", "BOTTOMLEFT", 2, -1)
Equal("off: Blizzard's height", bar.height, 8)
Equal("off: Blizzard's fill", bar.texture, "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
Equal("off: Blizzard's fonts", GameTooltipText.state.file, "Fonts\\FRIZQT__.TTF")
values[Options.BAR_SHOWN_PATH] = false
Tooltip:Apply()
Equal("off: Blizzard's bar shows, whatever the setting", bar.alpha, 1)
local calls = bar.calls
Tooltip:Apply()
Equal("an unchanged bar is left alone while off", bar.calls, calls)

values[Options.ENABLED_PATH] = true
forbidden = true
Tooltip:Apply()
Equal("a forbidden tooltip is not touched", bar.calls, calls)
forbidden = false

-- Unit text ----------------------------------------------------------------------------------------------------

local Format = AUI.TooltipFormat

Equal("colors become escape sequences", Format:Wrap("x", Format.FRIENDLY_LEVEL), "|cffffd000x|r")
Equal("a name alone", Format:FullName("Aeon", nil), "Aeon")
Equal("an empty realm is no realm", Format:FullName("Aeon", ""), "Aeon")
Equal("Name-Realm", Format:FullName("Aeon", "Argent Dawn"), "Aeon-Argent Dawn")
Equal("a surname takes the separator", Format:FullName("Aeon", "Storm", " "), "Aeon Storm")
Equal("the guild in brackets", Format:Guild("Aeon Guild"), "<Aeon Guild>")
Equal("brackets are not doubled", Format:Guild("<Aeon Guild>", "Officer"), "<Aeon Guild> [Officer]")
Equal("an empty rank is left out", Format:Guild("Aeon Guild", ""), "<Aeon Guild>")
Equal("the level pattern is the text before the level", Format:LevelPattern("Level %s"), "^Level ")
Equal("its magic characters are escaped", Format:LevelPattern("Niv. %s"), "^Niv%. ")
Equal("a normal unit has no mark", Format:Mark("normal", "Rare", "Boss"), "")
Equal("an elite is +", Format:Mark("elite", "Rare", "Boss"), Format:Wrap("+", Format.MARKS.elite))
Equal("a rare elite is + Rare", Format:Mark("rareelite", "Rare", "Boss"),
	Format:Wrap("+", Format.MARKS.elite) .. Format:Wrap(" Rare", Format.MARKS.rare))
Equal("a world boss is Boss", Format:Mark("worldboss", "Rare", "Boss"), Format:Wrap(" Boss", Format.MARKS.boss))
local white = { r = 1, g = 1, b = 1 }
Equal("the level is colored in place", Format:Level("Level 80 Human", 80, white, "+"),
	"Level " .. Format:Wrap("80", white) .. "+ Human")
Equal("an unknown level is ??", Format:Level("Level ?? Elite", -1, white), "Level " .. Format:Wrap("??", white) .. " Elite")
Equal("a level inside a longer number is not taken", Format:Level("Level 80", 8, white), nil)

-- Unit tooltips ------------------------------------------------------------------------------------------------

local LineType = Enum.TooltipDataLineType
local CLASS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 }, PALADIN = { r = 0.96, g = 0.55, b = 0.73 } }
local DIFFICULTY = { [1] = { r = 0.25, g = 0.75, b = 0.25 }, [3] = { r = 1, g = 0.5, b = 0.25 } }
local REACTION = { [2] = { r = 1, g = 0, b = 0 }, [4] = { r = 1, g = 1, b = 0 }, [5] = { r = 0, g = 1, b = 0 } }
local units, auras, cvars = {}, {}, {}
local now, combat, aurasSecret, identitySecret, collected = 100, false, false, false, true

local function Unit(token)
	return units[token] or {}
end

function UnitTokenFromGUID(guid)
	for token, unit in pairs(units) do
		if unit.guid == guid and token ~= "mouseover" then
			return unit.secretToken and SECRET or token
		end
	end
end
function UnitGUID(token) return Unit(token).guid end
function GetPlayerInfoByGUID(guid)
	for _, unit in pairs(units) do
		if unit.guid == guid and unit.player then
			return "Class", unit.class
		end
	end
end
function UnitNameFromGUID(guid)
	for _, unit in pairs(units) do
		if unit.guid == guid then
			return unit.name, unit.realm
		end
	end
end
C_ClassColor = { GetClassColor = function(class) return CLASS[class] end }
function UnitTreatAsPlayerForDisplay(token) return Unit(token).treatAsPlayer == true end
function UnitClass(token) return "Class", Unit(token).class end
function UnitIsBattlePet(token) return Unit(token).pet == true end
function UnitIsMinion(token) return Unit(token).minion == true end
function UnitSelectionColor() return 0.3, 0.6, 0.9, 1 end
function UnitReaction(token) return Unit(token).reaction end
FACTION_BAR_COLORS = REACTION
function UnitEffectiveLevel(token) return Unit(token).level end
function UnitIsFriend(token) return Unit(token).friend == true end
C_PlayerInfo = {
	GetContentDifficultyCreatureForPlayer = function(token) return Unit(token).difficulty end,
	GetPlayerMythicPlusRatingSummary = function(token) return { currentSeasonScore = Unit(token).score or 0 } end,
}
function GetDifficultyColor(difficulty) return DIFFICULTY[difficulty] or DIFFICULTY[3] end
function UnitClassification(token) return Unit(token).classification or "normal" end
function GetGuildInfo(token) return Unit(token).guild, Unit(token).rank end
function UnitIsInMyGuild(token) return Unit(token).myGuild == true end
function UnitName(token) return Unit(token).name end
function UnitExists(token) return units[token] ~= nil end
function UnitIsUnit(a, b) return a == b or (units[a] ~= nil and units[a] == units[b]) end
function UnitIsPlayer(token) return Unit(token).player == true end
C_Secrets = {
	ShouldUnitIdentityBeSecret = function() return identitySecret end,
	ShouldAurasBeSecret = function() return aurasSecret end,
}
C_ChallengeMode = { GetDungeonScoreRarityColor = function() return { r = 1, g = 0.5, b = 0 } end }
function InCombatLockdown() return combat end
C_UnitAuras = { GetAuraDataByIndex = function(_, index) return auras[index] end }
C_MountJournal = {
	GetMountFromSpell = function(spellID) return spellID == 999 and 42 or nil end,
	GetMountInfoByID = function()
		return "Swift Gryphon", 999, 0, false, true, 0, false, false, nil, false, collected
	end,
}
function CreateAtlasMarkup(atlas) return "|A:" .. atlas .. "|a" end
function GetTime() return now end
C_CVar = {
	GetCVar = function(name) return cvars[name] end,
	SetCVar = function(name, value) cvars[name] = value end,
}
YOU, TARGET, MOUNT, DUNGEON_SCORE, BOSS, CORPSE = "You", "Target", "Mount", "Mythic+ Rating", "Boss", "Corpse"
NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
Constants = { CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = " " } }

---@param count number
local function FontStrings(count)
	local strings = {}

	for index = 1, count do
		local line = { color = { 1, 1, 1 } }

		strings[index] = line
		_G["GameTooltipTextLeft" .. index] = Widget("FontString", {
			SetText = function(_, text)
				line.text = text
			end,
			SetTextColor = function(_, r, g, b)
				line.color = { r, g, b }
			end,
			GetTextColor = function()
				return line.color[1], line.color[2], line.color[3]
			end,
		})
	end

	return strings
end

---Builds the tooltip data for the lines given as { type, text }, each drawn at its own index, and runs the unit
---post-calls on it.
local function Show(guid, lines, tooltip)
	local data = { guid = guid, lines = {} }
	local strings = FontStrings(#lines)

	for index, line in ipairs(lines) do
		data.lines[index] = { type = line[1], leftText = line[2], lineIndex = index }
		strings[index].text = line[2]
	end

	for index = #added, 1, -1 do
		added[index] = nil
	end

	Fire("OnTooltipCleared", GameTooltip)

	for _, handler in ipairs(postCalls[Enum.TooltipDataType.Unit]) do
		handler(tooltip or GameTooltip, data)
	end

	return strings
end

local function Find(label)
	for _, line in ipairs(added) do
		if line.left == label then
			return line
		end
	end

	return nil
end

local function Added(label)
	return Find(label) or error("no " .. label .. " line", 2)
end

local function Rgb(color)
	return ("%.2f %.2f %.2f"):format(color[1] or color.r, color[2] or color.g, color[3] or color.b)
end

units.mouseover = { guid = "Player-1", name = "Aeon", realm = "", player = true, class = "MAGE", level = 80,
	friend = true, guild = "Aeon Guild", rank = "Officer", score = 2500 }
units.mouseovertarget = units.mouseover
units.player = units.mouseover
auras[1] = { spellId = 1 }
auras[2] = { spellId = 999 }
units.mouseover.secretToken = true

local playerLines = {
	{ LineType.UnitName, "Archmage Aeon" },
	{ LineType.None, "Aeon Guild" },
	{ LineType.UnitLevel, "Level 80 Human Mage (Player)" },
}
local lines = Show("Player-1", playerLines)
Equal("titles are hidden by default", lines[1].text, "Aeon")
Equal("a player's name in its class color", Rgb(lines[1].color), Rgb(CLASS.MAGE))
Equal("the guild in brackets with its rank", lines[2].text, "<Aeon Guild> [Officer]")
Equal("another guild in green", Rgb(lines[2].color), Rgb(Format.GUILD))
Equal("a friendly player's level in gold", lines[3].text,
	"Level " .. Format:Wrap("80", Format.FRIENDLY_LEVEL) .. " Human Mage (Player)")
Equal("the bar takes the name's color", Rgb(bar.color), Rgb(CLASS.MAGE))
Equal("a unit targeting the player shows You", Added("Target").right, "You")
Equal("in green", Rgb(Added("Target").color), Rgb(Format.YOU))
Equal("labels in gold", Rgb(Added("Target").label), Rgb(NORMAL_FONT_COLOR))
Equal("no rating outside Retail", Find("Mythic+ Rating"), nil)
Equal("the mount, marked as yours", Added("Mount").right, "Swift Gryphon |A:common-icon-checkmark|a")

GameTooltipStatusBar:SetStatusBarColor(0, 1, 0)
Fire("OnValueChanged", GameTooltipStatusBar)
Equal("a health change keeps the name's color", Rgb(bar.color), Rgb(CLASS.MAGE))
Fire("OnTooltipCleared", GameTooltip)
GameTooltipStatusBar:SetStatusBarColor(0, 1, 0)
Fire("OnValueChanged", GameTooltipStatusBar)
Equal("cleared lines give Blizzard's color back", Rgb(bar.color), "0.00 1.00 0.00")

units.mouseover.myGuild = true
units.mouseover.realm = "Argent Dawn"
AUI.can.mythicPlus = true
collected = false
now = now + 5
lines = Show("Player-1", playerLines)
Equal("your own guild in blue", Rgb(lines[2].color), Rgb(Format.OWN_GUILD))
Equal("another realm is Name-Realm", lines[1].text, "Aeon-Argent Dawn")
Equal("the rating on Retail", Added("Mythic+ Rating").right, "2500")
Equal("in its rarity color", Rgb(Added("Mythic+ Rating").color), "1.00 0.50 0.00")
Equal("a mount you lack is marked", Added("Mount").right, "Swift Gryphon |A:common-icon-redx|a")

values[Options.TITLES_PATH] = true
lines = Show("Player-1", playerLines)
Equal("titles shown keep Blizzard's line, with the realm", lines[1].text, "Archmage Aeon-Argent Dawn")
lines = Show("Player-1", { { LineType.UnitName, "Archmage Aeon-Argent Dawn" } })
Equal("a realm already there is not added again", lines[1].text, "Archmage Aeon-Argent Dawn")
AUI.can.surnames = true
units.mouseover.realm = "Storm"
lines = Show("Player-1", playerLines)
Equal("titles shown keep Forever's line as it is", lines[1].text, "Archmage Aeon")
values[Options.TITLES_PATH] = nil
lines = Show("Player-1", playerLines)
Equal("Forever's name and surname", lines[1].text, "Aeon Storm")
AUI.can.surnames = nil
units.mouseover.realm = ""

values[Options.GUILD_RANK_PATH] = false
values[Options.LEVEL_COLOR_PATH] = false
values[Options.TARGET_PATH] = false
values[Options.RATING_PATH] = false
values[Options.MOUNT_PATH] = false
lines = Show("Player-1", playerLines)
Equal("the rank can be left out", lines[2].text, "<Aeon Guild>")
Equal("the level can stay Blizzard's", lines[3].text, "Level 80 Human Mage (Player)")
Equal("no added lines while they are off", #added, 0)
for _, path in ipairs({ Options.GUILD_RANK_PATH, Options.LEVEL_COLOR_PATH, Options.TARGET_PATH, Options.RATING_PATH,
	Options.MOUNT_PATH }) do
	values[path] = nil
end

now = now + 5
combat = true
Show("Player-1", playerLines)
Equal("auras are not read in combat", Find("Mount"), nil)
combat = false
now = now + 5
aurasSecret = true
Show("Player-1", playerLines)
Equal("or while they are secret", Find("Mount"), nil)
aurasSecret = false
Show("Player-1", playerLines)
Equal("the mount is kept for a moment", Find("Mount"), nil)
now = now + 5
Show("Player-1", playerLines)
Equal("then read again", Find("Mount") ~= nil, true)

identitySecret = true
Show("Player-1", playerLines)
Equal("no Target line when its identity is secret", Find("Target"), nil)
identitySecret = false

units.mouseover = { guid = "Creature-1", name = "Old Murk-Eye", level = 62, difficulty = 1,
	classification = "rareelite", reaction = 2 }
units.mouseovertarget = { guid = "Creature-2", name = "Gnoll", reaction = 4 }
lines = Show("Creature-1", {
	{ LineType.UnitName, "Old Murk-Eye" },
	{ LineType.None, "Level 62 Murloc" },
	{ LineType.UnitOwner, "Aeon's Minion" },
	{ LineType.None, "Corpse" },
})
Equal("an NPC keeps Blizzard's name color", Rgb(lines[1].color), "1.00 1.00 1.00")
Equal("an untagged level line is found by its text", lines[2].text, "Level " .. Format:Wrap("62", DIFFICULTY[1])
	.. Format:Mark("rareelite", "Rare", "Boss") .. " Murloc")
Equal("owner lines are gray", Rgb(lines[3].color), Rgb(Format.MUTED))
Equal("corpse lines are gray", Rgb(lines[4].color), Rgb(Format.MUTED))
Equal("an NPC target in its reaction color", Rgb(Added("Target").color), Rgb(REACTION[4]))
Equal("no player lines on an NPC", Find("Mount"), nil)
Equal("the bar takes Blizzard's name color", Rgb(bar.color), "1.00 1.00 1.00")

units.mouseover.level = -1
units.mouseover.classification = "worldboss"
lines = Show("Creature-1", { { LineType.UnitLevel, "Level ?? Elite" } })
Equal("a boss of unknown level", lines[1].text, "Level " .. Format:Wrap("??", DIFFICULTY[1]) .. Format:Wrap(" Boss",
	Format.MARKS.boss) .. " Elite")

values[Options.MUTED_LINES_PATH] = false
lines = Show("Creature-1", { { LineType.UnitOwner, "Aeon's Minion" } })
Equal("owner lines can stay Blizzard's", Rgb(lines[1].color), "1.00 1.00 1.00")
values[Options.MUTED_LINES_PATH] = nil

units.mouseover = { guid = "Pet-1", name = "Fuzzy", pet = true, reaction = 5 }
lines = Show("Pet-1", { { LineType.UnitName, "Fuzzy" }, { LineType.None, "Fuzzy" } })
Equal("a battle pet's name in its reaction color", Rgb(lines[1].color), Rgb(REACTION[5]))
Equal("on each line that names it", Rgb(lines[2].color), Rgb(REACTION[5]))

units.mouseover = { guid = "Pet-2", name = "Water Elemental", minion = true }
lines = Show("Pet-2", { { LineType.UnitName, "Water Elemental" } })
Equal("a minion in its selection color", Rgb(lines[1].color), "0.30 0.60 0.90")

units.mouseover = { guid = "Player-2", name = "Kael", realm = "", player = false, treatAsPlayer = true,
	class = "PALADIN" }
lines = Show("Player-2", { { LineType.UnitName, "Kael" } })
Equal("an NPC shown as a player takes its class color", Rgb(lines[1].color), Rgb(CLASS.PALADIN))

units.mouseover = { guid = "Player-1", name = "Aeon", realm = "", player = true, class = "MAGE", level = 80 }
units.mouseovertarget = nil
lines = Show("Player-1", { { LineType.UnitName, SECRET }, { LineType.UnitLevel, "Level 80 Human" } })
Equal("a secret line is left as it is", lines[1].text, SECRET)
Equal("the other lines are still edited", lines[2].text ~= "Level 80 Human", true)
lines = Show(SECRET, playerLines)
Equal("a secret GUID leaves every line", lines[1].text, "Archmage Aeon")
units.mouseover.level = SECRET
lines = Show("Player-1", playerLines)
Equal("a secret level leaves the level line", lines[3].text, "Level 80 Human Mage (Player)")
units.mouseover.level = 80
lines = Show("Player-1", playerLines, NewTooltip("ShoppingTooltip1"))
Equal("other tooltips are left alone", lines[1].text, "Archmage Aeon")
forbidden = true
lines = Show("Player-1", playerLines)
Equal("a forbidden tooltip is left alone", lines[1].text, "Archmage Aeon")
forbidden = false

Equal("the aura caster names default on", Schema:Field(Options.AURA_CASTERS_PATH).default, true)
Tooltip:Apply()
Equal("no CVar is written where the client lacks it", next(cvars), nil)
AUI.can.auraCasterNames = true
cvars.tooltipShowAuraCasterNames = "0"
Tooltip:Apply()
Equal("the CVar takes the setting", cvars.tooltipShowAuraCasterNames, "1")
values[Options.AURA_CASTERS_PATH] = false
Tooltip:Apply()
Equal("and is turned off with it", cvars.tooltipShowAuraCasterNames, "0")

values[Options.ENABLED_PATH] = false
values[Options.AURA_CASTERS_PATH] = nil
Tooltip:Apply()
Equal("the module off leaves the CVar", cvars.tooltipShowAuraCasterNames, "0")
lines = Show("Player-1", playerLines)
Equal("the module off leaves unit lines", lines[1].text, "Archmage Aeon")
Equal("and adds none", #added, 0)
values[Options.ENABLED_PATH] = true

-- Detail text ---------------------------------------------------------------------------------------------------

local PERIOD = 2 ^ 23
local CREATURE = "Creature-0-3061-0-14-12345-0000000190"

Equal("category and type", Format:ItemType("Armor", "Plate"), "Armor / Plate")
Equal("a type repeating its category is left out", Format:ItemType("Quest", "Quest"), "Quest")
Equal("no category, no line", Format:ItemType("", "Plate"), nil)
Equal("a creature's NPC ID", Format:NPCID(CREATURE), 12345)
Equal("a vehicle's too", Format:NPCID("Vehicle-0-3061-0-14-678-0000000190"), 678)
Equal("a player has none", Format:NPCID("Player-3061-0ABCDEF0"), nil)
Equal("a pet has none", Format:NPCID("Pet-0-3061-0-14-416-0100000190"), nil)
Equal("the spawn age from the spawn UID's low bits", Format:SpawnAge(CREATURE, PERIOD * 100 + 1000), 600)
Equal("across the period's turn", Format:SpawnAge("Creature-0-1-0-1-1-00000007D0", PERIOD * 100 + 1000),
	PERIOD - 1000)
Equal("a player has no spawn age", Format:SpawnAge("Player-3061-0ABCDEF0", 1000), nil)
Equal("Shift is either Shift key", Format:IsModifierKey("SHIFT", "RSHIFT"), true)
Equal("Ctrl is not Shift", Format:IsModifierKey("SHIFT", "LCTRL"), false)
Equal("None has no key", Format:IsModifierKey("NONE", "LSHIFT"), false)

-- Tooltip details ---------------------------------------------------------------------------------------------

local Details = AUI.TooltipDetails
local types = Enum.TooltipDataType
local items = {
	[6948] = { "Hearthstone", "Miscellaneous", "Junk", 1, 0, 134414 },
	[2589] = { "Linen Cloth", "Tradeskill", "Cloth", 200, 1, 132889 },
}
local keys = { shift = false }
local serverTime = PERIOD * 100 + 1000

C_Item = {
	GetItemInfo = function(id)
		local item = items[id]

		if item then
			return item[1], nil, nil, nil, nil, item[2], item[3], item[4], nil, nil, nil, nil, nil, nil, item[5]
		end
	end,
	GetItemIconByID = function(id) return items[id] and items[id][6] end,
	GetItemIDForItemInfo = function(link) return link == "item:2589" and 2589 or nil end,
}
C_Spell = { GetSpellTexture = function(id) return id == 8690 and 136243 or nil end }
C_ActionBar = { GetActionText = function(action) return action == 7 and "Cloth" or nil end }
function GetMacroItem(name) return name == "Cloth" and "Linen Cloth" or nil, name == "Cloth" and "item:2589" or nil end
function GetServerTime() return serverTime end
function SecondsToTime(seconds) return seconds .. " s" end
function IsShiftKeyDown() return keys.shift end
function IsControlKeyDown() return false end
function IsAltKeyDown() return false end
EXPANSION_FILTER_TEXT, TYPE, EXPANSION_NAME0, EXPANSION_NAME1 = "Expansion", "Type", "Classic", "The Burning Crusade"
HIGHLIGHT_FONT_COLOR = { r = 1, g = 1, b = 1 }
AUI.can.expansions = true

---Runs the post-calls for a tooltip type on `tooltip` (GameTooltip by default), returning the lines they added.
local function Post(kind, data, tooltip)
	for index = #added, 1, -1 do
		added[index] = nil
	end

	for _, handler in ipairs(postCalls[assert(types[kind])]) do
		handler(tooltip or GameTooltip, data)
	end

	return added
end

local function Labels()
	local labels = {}

	for _, line in ipairs(added) do
		labels[#labels + 1] = line.right and (line.left .. "=" .. line.right) or ("[" .. line.left .. "]")
	end

	return table.concat(labels, " ")
end

Post("Item", { id = 6948 })
Equal("an item's lines after a blank line", Labels(),
	"[ ] Expansion=Classic Type=Miscellaneous / Junk Item ID=6948 Icon ID=134414")
Equal("labels in gold", Rgb(added[2].label), Rgb(NORMAL_FONT_COLOR))
Equal("values in white", Rgb(added[2].color), Rgb(HIGHLIGHT_FONT_COLOR))
Post("Item", { id = 2589 })
Equal("a stack of more than one is shown", Added("Max Stack").right, "200")
Post("Toy", { id = 6948 })
Equal("toys are items", Added("Item ID").right, "6948")
AUI.can.expansions = nil
Post("Item", { id = 6948 })
Equal("no expansion where the client has none", Find("Expansion"), nil)
AUI.can.expansions = true
values[Options.BLANK_LINE_PATH] = false
values[Options.ID_PATHS.item] = false
values[Options.EXPANSION_PATH] = false
Post("Item", { id = 6948 })
Equal("each line can be turned off", Labels(), "Type=Miscellaneous / Junk Icon ID=134414")
values[Options.BLANK_LINE_PATH] = nil
values[Options.ID_PATHS.item] = nil
values[Options.EXPANSION_PATH] = nil
Post("Item", { id = 99 })
Equal("an uncached item still shows its IDs", Labels(), "[ ] Item ID=99")
Post("Item", { id = SECRET })
Equal("a secret ID adds nothing", #added, 0)

values[Options.ID_MODIFIER_PATH] = "SHIFT"
Post("Item", { id = 6948 })
Equal("IDs wait for the modifier", Find("Item ID"), nil)
Equal("the item's details do not", Find("Type") ~= nil, true)
keys.shift = true
Post("Item", { id = 6948 })
Equal("and show while it is held", Added("Item ID").right, "6948")
keys.shift = false
Post("Spell", { id = 8690 })
Equal("a spell without the modifier adds nothing", #added, 0)

local preview = NewTooltip("AeonUITooltipPreviewItem")
Details.previews = { preview }
values[Options.ENABLED_PATH] = false
Post("Item", { id = 6948 }, preview)
Equal("the preview shows every chosen line, module off and modifier up", Added("Item ID").right, "6948")
Post("Item", { id = 6948 })
Equal("other tooltips get nothing with the module off", #added, 0)
values[Options.ENABLED_PATH] = nil
values[Options.ID_MODIFIER_PATH] = nil

Post("Item", { id = 6948 }, NewTooltip("ItemSocketingDescription"))
Equal("the socketing window's text is left alone", #added, 0)
Post("Item", { id = 6948 }, NewTooltip("ShoppingTooltip1"))
Equal("comparison tooltips get the lines", Added("Item ID").right, "6948")

Post("Spell", { id = 8690 })
Equal("a spell's ID and icon", Labels(), "[ ] Spell ID=8690 Icon ID=136243")
Post("UnitAura", { id = 8690 })
Equal("an aura's too", Added("Spell ID").right, "8690")
Post("PetAction", { lines = { { tooltipID = 8690 } } })
Equal("a pet action's spell from its first line", Added("Spell ID").right, "8690")
Post("Currency", { id = 3008 })
Equal("a currency's ID", Labels(), "[ ] Currency ID=3008")
Post("Mount", { id = 42 })
Equal("a mount's ID and its spell", Labels(), "[ ] Mount ID=42 Spell ID=999")
Post("Quest", { id = 86 })
Equal("a quest's ID", Labels(), "[ ] Quest ID=86")
Post("Macro", { lines = { { tooltipID = 8690 } } })
Equal("a macro's spell", Labels(), "[ ] Spell ID=8690")
GameTooltip.processingInfo = { getterName = "GetAction", getterArgs = { 7 } }
AUI.can.macroItems = true
Post("Macro", { lines = { {} } })
Equal("a macro's item, from its name", Labels(), "[ ] Item ID=2589")
AUI.can.macroItems = nil
Post("Macro", { lines = { {} } })
Equal("no item where the client cannot read it", #added, 0)
GameTooltip.processingInfo = nil

units.mouseover = nil
Post("Unit", { guid = CREATURE, lines = {} })
Equal("an NPC's ID and spawn age", Labels(), "[ ] NPC ID=12345 Spawned=600 s ago")
Post("Corpse", { guid = CREATURE })
Equal("a corpse's too", Added("NPC ID").right, "12345")
values[Options.ID_PATHS.age] = false
Post("Corpse", { guid = CREATURE })
Equal("the spawn age can be turned off", Find("Spawned"), nil)
values[Options.ID_PATHS.age] = nil
Post("Unit", { guid = "Player-3061-0ABCDEF0", lines = {} })
Equal("a player gets no NPC lines", Find("NPC ID"), nil)

for index = #added, 1, -1 do
	added[index] = nil
end
questCallbacks["QuestMapLogTitleButton.OnEnter"](nil, 86)
Equal("quest log entries get the quest's ID", Added("Quest ID").right, "86")
Equal("and the tooltip is shown again to fit it", shown.shows, 1)
for index = #added, 1, -1 do
	added[index] = nil
end
shown.quest = true
questCallbacks["MapCanvas.QuestPin.OnEnter"](nil, 86)
Equal("not twice on a quest data tooltip", #added, 0)
shown.quest = false
shown.visible = false
questCallbacks["TaskPOI.TooltipShown"](nil, 86)
Equal("nor on a hidden tooltip", #added, 0)
shown.visible = true

shown.data = { guid = "Player-1" }
events.MODIFIER_STATE_CHANGED("LSHIFT", 1)
Equal("no rebuild while no modifier is chosen", shown.refreshes, 0)
values[Options.ID_MODIFIER_PATH] = "SHIFT"
events.MODIFIER_STATE_CHANGED("LCTRL", 1)
Equal("nor for another key", shown.refreshes, 0)
events.MODIFIER_STATE_CHANGED("LSHIFT", 1)
Equal("the chosen key rebuilds the tooltip", shown.refreshes, 1)
combat = true
events.MODIFIER_STATE_CHANGED("LSHIFT", 0)
Equal("but never in combat", shown.refreshes, 1)
combat = false
shown.data = { guid = SECRET }
events.MODIFIER_STATE_CHANGED("LSHIFT", 0)
Equal("nor for a secret unit", shown.refreshes, 1)
shown.data = nil

cvars.tooltipShowAuraSpellIDs = "0"
Tooltip:Apply()
Equal("the aura ID CVar is untouched where the client lacks it", cvars.tooltipShowAuraSpellIDs, "0")
AUI.can.auraSpellIDs = true
Tooltip:Apply()
Equal("a modifier keeps the client's aura IDs off", cvars.tooltipShowAuraSpellIDs, "0")
values[Options.ID_MODIFIER_PATH] = nil
Tooltip:Apply()
Equal("no modifier lets the client draw aura IDs", cvars.tooltipShowAuraSpellIDs, "1")
Post("UnitAura", { id = 8690 })
Equal("so the aura gets no ID line of its own", Find("Spell ID"), nil)
Equal("but keeps its icon", Added("Icon ID").right, "136243")
values[Options.ENABLED_PATH] = false
Tooltip:Apply()
Equal("the module off turns them off again", cvars.tooltipShowAuraSpellIDs, "0")
cvars.tooltipShowAuraSpellIDs = "1"
Tooltip:Apply()
Equal("a CVar AeonUI did not set is left alone", cvars.tooltipShowAuraSpellIDs, "1")
values[Options.ENABLED_PATH] = nil

print(("check_tooltip: %d checks passed"):format(checks))
