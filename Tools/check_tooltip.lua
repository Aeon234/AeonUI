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
INVSLOT_HEAD, INVSLOT_BODY, INVSLOT_MAINHAND, INVSLOT_OFFHAND, INVSLOT_RANGED = 1, 4, 16, 17, 18
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
	border = {},
	sound = {},
}
local LSM = {
	MediaType = { BORDER = "border", FONT = "font", SOUND = "sound", STATUSBAR = "statusbar" },
	-- The first file registered under a name keeps it, as in LibSharedMedia.
	Register = function(_, kind, name, file)
		LSM_FILES[kind][name] = LSM_FILES[kind][name] or file
	end,
	Fetch = function(_, kind, name)
		local files = LSM_FILES[kind]

		return files and files[name]
	end,
}

-- LibSpecialization's callbacks, as AeonUI registers them.
local libSpec = { group = {}, guild = {}, guildRequests = 0 }
local LIBSPEC = {
	RegisterGroup = function(owner, handler)
		libSpec.group[owner] = handler
	end,
	RegisterGuild = function(owner, handler)
		libSpec.guild[owner] = handler
	end,
	RequestGuildSpecialization = function()
		libSpec.guildRequests = libSpec.guildRequests + 1
	end,
}

function LibStub(name)
	return name == "LibSpecialization" and LIBSPEC or LSM
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

-- Each hooked function's handlers, run in order by `hooks[name]`.
local hooks, hookLists = {}, {}

---@param key string
---@param handler function
local function AddHook(key, handler)
	if not hookLists[key] then
		hookLists[key] = {}
		hooks[key] = function(...)
			for _, hooked in ipairs(hookLists[key]) do
				hooked(...)
			end
		end
	end

	table.insert(hookLists[key], handler)
end

function hooksecurefunc(object, method, handler)
	if type(object) == "string" then
		assert(_G[object], object)
		AddHook(object, method --[[@as function]])

		return
	end

	assert(object[method], method)
	AddHook(method, handler)
end

local inspects = { asked = {}, cleared = 0 }
function NotifyInspect(unit)
	inspects.asked[#inspects.asked + 1] = unit
	hooks.NotifyInspect()
end
function InspectUnit() end
function ClearInspectPlayer()
	inspects.cleared = inspects.cleared + 1
end

Enum = {
	TooltipDataType = { Item = 0, Spell = 1, Unit = 2, Corpse = 3, Object = 4, Currency = 5, UnitAura = 7, Mount = 10,
		PetAction = 11, Toy = 19, Quest = 23, Macro = 25 },
	TooltipDataLineType = { None = 0, UnitName = 2, UnitOwner = 16, ItemUpgradeLevel = 32, UnitLevel = 47 },
	ItemBind = { None = 0, OnAcquire = 1, OnEquip = 2, OnUse = 3, Quest = 4, ToWoWAccount = 7, ToBnetAccount = 8,
		ToBnetAccountUntilEquipped = 9 },
}
local postCalls = {}
local preCalls = {}
TooltipDataProcessor = {
	AddTooltipPostCall = function(kind, handler)
		postCalls[kind] = postCalls[kind] or {}
		table.insert(postCalls[kind], handler)
	end,
	AddTooltipPreCall = function(kind, handler)
		preCalls[kind] = preCalls[kind] or {}
		table.insert(preCalls[kind], handler)
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

-- GameTooltip's points, owner, parent and strata, as the anchoring and visibility checks set and read them.
local anchoring = { points = {}, parent = nil, strata = "TOOLTIP", owner = nil, hides = 0 }
UIParent = { GetEffectiveScale = function() return 1 end, GetWidth = function() return 1920 end,
	GetHeight = function() return 1080 end }
anchoring.parent = UIParent

GameTooltip = Widget("GameTooltip", {
	IsForbidden = function()
		return forbidden
	end,
	SetOwner = function(_, owner)
		anchoring.owner = owner
	end,
	ClearAllPoints = function()
		anchoring.points = {}
	end,
	SetPoint = function(_, point, relativeTo, relativePoint, x, y)
		table.insert(anchoring.points, { point, relativeTo, relativePoint, x, y })
	end,
	GetPoint = function(_, index)
		local point = anchoring.points[index]

		if point then
			return point[1], point[2], point[3], point[4], point[5]
		end
	end,
	GetNumPoints = function()
		return #anchoring.points
	end,
	GetParent = function()
		return anchoring.parent
	end,
	SetParent = function(_, parent)
		anchoring.parent = parent
	end,
	SetFrameStrata = function(_, strata)
		anchoring.strata = strata
	end,
	FadeOut = function() end,
	Hide = function()
		anchoring.hides = anchoring.hides + 1
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
for _, file in ipairs({ "Profile/Schema.lua", "Media/Media.lua", "Core/AuctionPrices.lua",
	"AeonUI_Tooltip/Tooltip/Options.lua", "AeonUI_Tooltip/Tooltip/Format.lua", "AeonUI_Tooltip/Tooltip/Appearance.lua", "AeonUI_Tooltip/Tooltip/Units.lua",
	"AeonUI_Tooltip/Tooltip/Details.lua", "AeonUI_Tooltip/Tooltip/UpgradeSeasons.lua", "AeonUI_Tooltip/Tooltip/Upgrades.lua", "AeonUI_Tooltip/Tooltip/Inspect.lua",
	"AeonUI_Tooltip/Tooltip/Anchor.lua", "AeonUI_Tooltip/Tooltip/Visibility.lua", "AeonUI_Tooltip/Tooltip/Tooltip.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Schema, Options, Tooltip = AUI.Schema, AUI.TooltipOptions, AUI.Tooltip

-- The profile owner, holding the settings' defaults until a check sets one. Setting one empties the Tooltip settings
-- cache, as the owner's change callback does in the game.
local stored = {}
local values = setmetatable({}, {
	__index = stored,
	__newindex = function(_, path, value)
		stored[path] = value
		Options:Forget()
	end,
})
AUI.Profile = {
	Get = function(_, path)
		if values[path] ~= nil then
			return values[path]
		end

		return Schema:Field(path).default
	end,
}
-- Item level and specialization lines stay off until their own checks, so the unit checks see only their lines.
values[Options.ITEM_LEVEL_PATH] = false
values[Options.SPECIALIZATION_PATH] = false
AUI.Settings = {
	Default = function(_, path)
		return Schema:Field(path).default
	end,
}

local coalesced = {}
local events, eventHandlers = {}, {}
AUI.Events = {
	Register = function(_, event, owner, handler)
		eventHandlers[event] = eventHandlers[event] or {}
		eventHandlers[event][owner] = handler
		events[event] = function(...)
			for registered, registeredHandler in pairs(eventHandlers[event]) do
				registeredHandler(registered, event, ...)
			end
		end
	end,
	Unregister = function(_, event, owner)
		if eventHandlers[event] then
			eventHandlers[event][owner] = nil
		end
	end,
	Merge = function(_, _, _, handler)
		handler()
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

-- Blizzard's container for default-anchored tooltips, at the bottom right of a 1920 by 1080 screen.
GameTooltipDefaultContainer = {
	GetLeft = function() return 1500 end,
	GetBottom = function() return 100 end,
	GetWidth = function() return 300 end,
	GetHeight = function() return 150 end,
	GetEffectiveScale = function() return 1 end,
}

---As Blizzard's: owns the tooltip, then pins its corner to the container's; hooks run after it, as the client's do.
function GameTooltip_SetDefaultAnchor(tooltip, owner)
	tooltip:SetOwner(owner, "ANCHOR_NONE")
	hooks.SetOwner(tooltip)
	tooltip:ClearAllPoints()
	tooltip:SetPoint("BOTTOMRIGHT", GameTooltipDefaultContainer, "BOTTOMRIGHT", 0, 0)
	hooks.SetPoint(tooltip)
	hooks.GameTooltip_SetDefaultAnchor(tooltip, owner)
end

local shopping = {}
for index = 1, 2 do
	_G["ShoppingTooltip" .. index] = Widget("GameTooltip", {
		HookScript = function(_, script, handler)
			shopping[script] = shopping[script] or {}
			table.insert(shopping[script], handler)
		end,
	})
end

AUI.can.specializations = true
Tooltip:Start()
AUI.can.specializations = nil
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
-- Each item's bind type (GetItemInfo's 14th return).
local binds = { [6948] = 1, [19019] = 2 }
local keys = { shift = false }
local serverTime = PERIOD * 100 + 1000

C_Item = {
	GetItemInfo = function(id)
		local item = items[id]

		if item then
			return item[1], nil, nil, nil, nil, item[2], item[3], item[4], nil, nil, nil, nil, nil, binds[id], item[5]
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

-- Auction prices ------------------------------------------------------------------------------------------

function GetMoneyString(copper, separate)
	assert(separate == true, "thousands separated")

	return copper .. "c"
end
function GetNormalizedRealmName() return "Silvermoon" end
function GetCurrentRegionName() return "US" end
items[19019] = { "Thunderfury", "Weapon", "Sword", 1, 0, 135349 }
values[Options.EXPANSION_PATH] = false
values[Options.ITEM_TYPE_PATH] = false
values[Options.MAX_STACK_PATH] = false
values[Options.BLANK_LINE_PATH] = false
values[Options.ID_PATHS.item] = false
values[Options.ID_PATHS.icon] = false
Equal("Auction Prices on by default", Schema:Field(Options.AUCTION_PRICE_PATH).default, true)
Post("Item", { id = 19019 })
Equal("no auction addon, no price", #added, 0)
Post("Item", { id = 19019 }, preview)
Equal("the preview shows sample prices", Labels(), "Silvermoon=1234c US Region=1150c")

local quotes = { auctionator = {}, age = {}, tsm = {}, oribos = {} }
_G.Auctionator = { API = { v1 = {
	GetAuctionPriceByItemLink = function(caller, link)
		assert(caller == "AeonUI", "the caller name")
		if link == "item:6" then
			error("Auctionator failed")
		end

		return quotes.auctionator[link]
	end,
	GetAuctionAgeByItemLink = function(_, link) return quotes.age[link] end,
} } }
quotes.auctionator["item:19019"], quotes.age["item:19019"] = 500000, 3
Post("Item", { id = 19019 })
Equal("Auctionator: the realm's price, by the item's link", Labels(), "Silvermoon=500000c")
Post("Item", { id = 19019, hyperlink = "item:19019:bonus" })
Equal("the tooltip's own link is asked", #added, 0)

_G.TSM_API = {
	ToItemString = function(link) return "i:" .. link:match("%d+") end,
	GetCustomPriceValue = function(source, itemString)
		return (quotes.tsm[source] or {})[itemString]
	end,
}
quotes.tsm.DBMinBuyout = { ["i:19019"] = 480000 }
quotes.tsm.DBRegionMarketAvg = { ["i:19019"] = 450000 }
Post("Item", { id = 19019 })
Equal("TSM's data counts as today's, newer than Auctionator's three days", Labels(),
	"Silvermoon=480000c US Region=450000c")
quotes.age["item:19019"] = 0
Post("Item", { id = 19019 })
Equal("a tie in age goes to Auctionator", Added("Silvermoon").right, "500000c")
quotes.age["item:19019"] = nil
Post("Item", { id = 19019 })
Equal("Auctionator without an age (over 21 days) counts as today's", Added("Silvermoon").right, "500000c")

_G.TSM_API = nil
_G.OEMarketInfo = function(item, info)
	assert(item == 19019, "Oribos Exchange is asked by item ID")
	local quote = quotes.oribos[item]

	if quote then
		info.market, info.region, info.age = quote.market, quote.region, quote.age
	end
end
quotes.oribos[19019] = { market = 470000, region = 440000, age = 3600 }
quotes.age["item:19019"] = 1
Post("Item", { id = 19019 })
Equal("Oribos Exchange's hour-old prices beat Auctionator's day-old one", Labels(),
	"Silvermoon=470000c US Region=440000c")
quotes.oribos[19019] = { region = 440000, age = 2 * 86400 }
Post("Item", { id = 19019 })
Equal("each line takes the newest price it has", Labels(), "Silvermoon=500000c US Region=440000c")
_G.OEMarketInfo = function() error("Oribos Exchange failed") end
Post("Item", { id = 19019 })
Equal("an addon's error is no price", Labels(), "Silvermoon=500000c")
_G.OEMarketInfo = nil

AUI.can.commodities = true
quotes.auctionator["item:2589"] = 25
Post("Item", { id = 2589 })
Equal("a commodity's realm price is its region's", Labels(), "US Region=25c")
AUI.can.commodities = nil
Post("Item", { id = 2589 })
Equal("without commodities, a stack is priced by realm", Labels(), "Silvermoon=25c")

quotes.auctionator["item:6948"] = 100
Post("Item", { id = 6948 })
Equal("a soulbound item has no price", #added, 0)
binds[6948] = 9
Post("Item", { id = 6948 })
Equal("nor a Warband-bound one", #added, 0)
binds[6948] = 1
Post("Item", { id = 99 })
Equal("an uncached item waits for its data", #added, 0)

AUI.can.surnames = true
Post("Item", { id = 19019 })
Equal("a client without realms names the line Auction", Labels(), "Auction=500000c")
AUI.can.surnames = nil
values[Options.AUCTION_PRICE_PATH] = false
Post("Item", { id = 19019 })
Equal("turned off", #added, 0)
values[Options.AUCTION_PRICE_PATH] = nil
_G.Auctionator = nil
values[Options.EXPANSION_PATH] = nil
values[Options.ITEM_TYPE_PATH] = nil
values[Options.MAX_STACK_PATH] = nil
values[Options.BLANK_LINE_PATH] = nil
values[Options.ID_PATHS.item] = nil
values[Options.ID_PATHS.icon] = nil
items[19019] = nil

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

local SAMPLE_KEYS = { "npc", "age", "currency", "mount", "quest", "macro" }

for index = #added, 1, -1 do
	added[index] = nil
end
Equal("the preview's sample tooltip is filled", Details:Sample(NewTooltip("AeonUITooltipPreviewOther")), true)
Equal("with the lines of the tooltips the preview cannot build", Labels(),
	"[Other Tooltips] [ ] NPC ID=3100 Spawned=754 s ago Currency ID=3008 Mount ID=6 Quest ID=86 Spell ID=8690")
for index = #added, 1, -1 do
	added[index] = nil
end
values[Options.ID_PATHS.age] = false
Details:Sample(NewTooltip("AeonUITooltipPreviewOther"))
Equal("each follows its checkbox", Find("Spawned"), nil)
for _, key in ipairs(SAMPLE_KEYS) do
	values[Options.ID_PATHS[key]] = false
end
for index = #added, 1, -1 do
	added[index] = nil
end
Equal("with none chosen it is not filled", Details:Sample(NewTooltip("AeonUITooltipPreviewOther")), false)
Equal("and gets no lines", #added, 0)
for _, key in ipairs(SAMPLE_KEYS) do
	values[Options.ID_PATHS[key]] = nil
end

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

-- Upgrade line ----------------------------------------------------------------------------------------------------

local Upgrades = AUI.TooltipUpgrades
local seasons = AUI.TooltipUpgradeSeasons
local QUALITY = { [1] = { 1, 1, 1 }, [3] = { 0, 0.44, 0.87 }, [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 } }
local upgradeItem = { level = 311, quality = 4, character = 315, account = 0 }
local crests = { [3445] = { name = "Hero Mistcrest", iconFileID = 5000 } }

ITEM_UPGRADE_TOOLTIP_FORMAT_STRING = "Upgrade Level: %s %d/%d"
function GetBuildInfo() return "12.1.5", "70575", "", 120105 end
C_Item.GetItemQualityColor = function(quality)
	local color = QUALITY[quality] or QUALITY[1]

	return color[1], color[2], color[3], "ff"
end
C_Item.GetDetailedItemLevelInfo = function(link) return link == "item:1" and upgradeItem.level or nil end
C_Item.GetItemLinkByGUID = function(guid) return guid == "Item-1" and "item:1" or nil end
local itemInfo = C_Item.GetItemInfo
C_Item.GetItemInfo = function(id)
	if id == "item:1" then
		return "Sword", "item:1", upgradeItem.quality
	end

	return itemInfo(id)
end
C_ItemUpgrade = {
	GetHighWatermarkForItem = function() return upgradeItem.character, upgradeItem.account end,
}
C_CurrencyInfo = { GetCurrencyInfo = function(id) return crests[id] end }

local function InQuality(quality, text)
	local color = QUALITY[quality]

	return Format:Wrap(text, { r = color[1], g = color[2], b = color[3] })
end

Equal("the running season is the newest not above the client", Upgrades.SeasonFor(seasons, 120105), seasons[120100])
Equal("an earlier client takes the earlier season", Upgrades.SeasonFor(seasons, 120050), seasons[120001])
Equal("a client before every season has none", Upgrades.SeasonFor(seasons, 16001), nil)
local season2 = seasons[120100]
Equal("a Hero item by its level and rank", Upgrades.FindTrack(season2, 311, 3, 6), season2[2])
Equal("overlapping tracks: the closest expected level wins", Upgrades.FindTrack(season2, 305, 5, 6), season2[1])
Equal("the same level at rank 1 is Hero", Upgrades.FindTrack(season2, 305, 1, 6), season2[2])
Equal("another number of ranks matches no track", Upgrades.FindTrack(season2, 311, 3, 8), nil)
Equal("a level no track has matches none", Upgrades.FindTrack(season2, 250, 3, 6), nil)
local capture = Upgrades.CapturePattern(ITEM_UPGRADE_TOOLTIP_FORMAT_STRING)
local label, track, rank, ranks = ("Upgrade Level: Hero 3/6"):match(capture)
Equal("the line's label, track, rank and ranks", table.concat({ label, track, rank, ranks }, "|"),
	"Upgrade Level: |Hero|3|6")

AUI.can.upgrades = true
Upgrades:Hook()
Equal("the post-call is installed where the client has tracks", Upgrades.capture, capture)

local rightText = {}
GameTooltipTextRight2 = Widget("FontString", {
	SetText = function(_, text)
		rightText.text = text
	end,
	Show = function()
		rightText.shown = true
	end,
})

---Shows an item tooltip whose second line is the upgrade line, returning the left and right texts after the post-calls.
local function Upgrade(text, data)
	local strings = FontStrings(2)

	strings[2].text = text
	rightText.text, rightText.shown = nil, nil
	data = data or { guid = "Item-1" }
	data.lines = { { type = Enum.TooltipDataLineType.None, leftText = "Sword", lineIndex = 1 },
		{ type = Enum.TooltipDataLineType.ItemUpgradeLevel, leftText = text, lineIndex = 2 } }
	Post("Item", data)

	return strings[2].text, rightText.text
end

Equal("the next crest is off by default", Schema:Field(Options.UPGRADE_CREST_PATH).default, false)
values[Options.UPGRADE_CREST_PATH] = true
left, right = Upgrade("Upgrade Level: Hero 3/6")
Equal("the rank in its track's color, then the range", left,
	"Upgrade Level: " .. InQuality(4, "Hero 3/6") .. " " .. Format:Wrap("(305-321)", white))
Equal("the next crest on the right, discounted below the watermark", right,
	"|T5000:0|t " .. InQuality(4, "Hero Mistcrest") .. " (discounted)")
Equal("the right text is shown", rightText.shown, true)
upgradeItem.character = 300
left, right = Upgrade("Upgrade Level: Hero 3/6")
Equal("no discount at or above the watermark", right, "|T5000:0|t " .. InQuality(4, "Hero Mistcrest"))
upgradeItem.level = 321
left, right = Upgrade("Upgrade Level: Hero 6/6")
Equal("nothing to pay at the last rank", right, nil)
upgradeItem.level = 311
crests[3445] = nil
left, right = Upgrade("Upgrade Level: Hero 3/6")
Equal("without the currency the crest is named from the track", right, InQuality(4, "Hero Crest"))
upgradeItem.level, upgradeItem.quality = 240, 3
left, right = Upgrade("Upgrade Level: Veteran 3/6")
Equal("a track the season lacks takes the item's quality", left, "Upgrade Level: " .. InQuality(3, "Veteran 3/6"))
Equal("with no range or crest", right, nil)
upgradeItem.level, upgradeItem.quality = 311, 4

values[Options.UPGRADE_RANGE_COLOR_PATH] = { r = 1, g = 0.5, b = 0 }
values[Options.UPGRADE_CREST_PATH] = false
left, right = Upgrade("Upgrade Level: Hero 3/6")
Equal("the range in its color", left:sub(-#Format:Wrap("(305-321)", values[Options.UPGRADE_RANGE_COLOR_PATH])),
	Format:Wrap("(305-321)", values[Options.UPGRADE_RANGE_COLOR_PATH]))
Equal("the crest can be left out", right, nil)
values[Options.UPGRADE_RANK_PATH] = false
values[Options.UPGRADE_RANGE_PATH] = false
left = Upgrade("Upgrade Level: Hero 3/6")
Equal("the rank and range can stay Blizzard's", left, "Upgrade Level: Hero 3/6")
for _, path in ipairs({ Options.UPGRADE_RANGE_COLOR_PATH, Options.UPGRADE_CREST_PATH, Options.UPGRADE_RANK_PATH,
	Options.UPGRADE_RANGE_PATH }) do
	values[path] = nil
end

left = Upgrade("Upgrade Level: Hero 3/6", { hyperlink = "item:1" })
Equal("a linked item is read from its link", left ~= "Upgrade Level: Hero 3/6", true)
left = Upgrade("Upgrade Level: Hero 3/6", { hyperlink = "item:2" })
Equal("an item with no level is left alone", left, "Upgrade Level: Hero 3/6")
left = Upgrade(SECRET)
Equal("a secret line is left alone", left, SECRET)
values[Options.ENABLED_PATH] = false
left = Upgrade("Upgrade Level: Hero 3/6")
Equal("the module off leaves the line", left, "Upgrade Level: Hero 3/6")
values[Options.ENABLED_PATH] = nil

-- Item level text -------------------------------------------------------------------------------------------------

local SLOTS16 = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 }
local full = {}
for _, slot in ipairs(SLOTS16) do
	full[slot] = 300
end
Equal("no tracks, no grade", Format:Grade(nil, 300), nil)
Equal("the highest track reached", Format:Grade(season2, 320), Format.GRADES[1])
Equal("the next track down", Format:Grade(season2, 312), Format.GRADES[2])
Equal("below every track", Format:Grade(season2, 250), Format.BELOW)
Equal("a full set's average", Format:GearAverage(SLOTS16, full), 300)
full[17] = nil
Equal("an empty off hand counts as nothing", Format:GearAverage(SLOTS16, full, "INVTYPE_WEAPON"), 300 * 15 / 16)
Equal("a two-handed weapon counts for it", Format:GearAverage(SLOTS16, full, "INVTYPE_2HWEAPON"), 300)
Equal("nothing worn, no average", Format:GearAverage(SLOTS16, {}), nil)

-- Inspected players ---------------------------------------------------------------------------------------------

local Inspect = AUI.TooltipInspect
local inspected, gear, itemLevels, equipLocs = {}, {}, {}, {}
local timers = {}
local reach, party, guilded = true, {}, true
local SPECS = { [257] = { "Holy", "HEALER" }, [62] = { "Arcane", "DAMAGER" }, [65] = { "Holy", "HEALER" } }
local rights = {}

C_Timer = { After = function(delay, handler) timers[#timers + 1] = { delay, handler } end }
local function RunTimers()
	local due = timers

	timers = {}

	for _, timer in ipairs(due) do
		timer[2]()
	end

	return #due
end
C_PaperDollInfo = {
	GetInspectItemLevel = function(unit) return (inspected[UnitGUID(unit)] or {}).level end,
}
C_SpecializationInfo = {
	GetInspectSpecialization = function(unit) return (inspected[UnitGUID(unit)] or {}).spec end,
	GetSpecialization = function() return 2 end,
	GetSpecializationInfo = function(index) return index == 2 and 62 or nil end,
}
function GetSpecializationInfoByID(id)
	local spec = SPECS[id]

	if spec then
		return id, spec[1], "", 0, spec[2]
	end
end
function GetAverageItemLevel() return 280.4, 280.6 end
function GetInventoryItemLink(unit, slot) return (gear[UnitGUID(unit)] or {})[slot] end
local detailed, info = C_Item.GetDetailedItemLevelInfo, C_Item.GetItemInfo
C_Item.GetDetailedItemLevelInfo = function(link) return itemLevels[link] or detailed(link) end
C_Item.GetItemInfo = function(id)
	if equipLocs[id] then
		return "Weapon", id, 4, nil, nil, nil, nil, nil, equipLocs[id]
	end

	return info(id)
end
function CanInspect() return true end
function CheckInteractDistance() return reach end
function UnitInParty(unit) return party[UnitGUID(unit)] == true end
function UnitInRaid() return nil end
function IsInGuild() return guilded end
STAT_AVERAGE_ITEM_LEVEL, SPECIALIZATION = "Item Level", "Specialization"
GameTooltip.NumLines = function() return #added end
for index = 1, 12 do
	local line = {}

	rights[index] = line
	_G["GameTooltipTextRight" .. index] = Widget("FontString", {
		SetText = function(_, text)
			line.text = text
		end,
		SetTextColor = function(_, r, g, b)
			line.color = { r, g, b }
		end,
	})
end

values[Options.ITEM_LEVEL_PATH], values[Options.SPECIALIZATION_PATH] = nil, nil
values[Options.MOUNT_PATH], values[Options.TARGET_PATH] = false, false
AUI.can.specializations = true

---Hovers a player: GUID `guid`, the unit "mouseover".
local function Hover(guid, name)
	units.mouseover = { guid = guid, name = name or "Kael", realm = "", player = true, class = "MAGE", level = 80 }
	units.mouseovertarget = nil
	Post("Unit", { guid = guid, lines = {} })
end

now = 1000
Hover("Player-9")
Equal("an unknown player waits with ...", Added("Item Level").right, "...")
Equal("and so does the specialization", Added("Specialization").right, "...")
Equal("labels in gold", Rgb(Added("Item Level").label), Rgb(NORMAL_FONT_COLOR))
Equal("nothing is asked before the cursor rests", #inspects.asked, 0)
now = now + 1
RunTimers()
Equal("then the player is inspected", inspects.asked[1], "mouseover")
inspected["Player-9"] = { level = 312.4, spec = 257 }
local showsBefore = shown.shows
events.INSPECT_READY("Player-9")
Equal("the answer fills the item level in place", rights[Inspect.shown.itemLevel].text, "312")
Equal("in its grade", Rgb(rights[Inspect.shown.itemLevel].color), Rgb(Format.GRADES[2]))
Equal("and the specialization, with its role", rights[Inspect.shown.spec].text, "|A:roleicon-tiny-healer|a Holy")
values[Options.ROLE_ICONS_PATH] = "WHITE"
Equal("the role icon in the chosen style", Inspect:SpecText(257),
	"|TInterface\\AddOns\\AeonUI\\Media\\Textures\\Roles\\White\\Healer.png:14:14|t Holy")
values[Options.ROLE_ICONS_PATH] = nil
Equal("the tooltip is resized", shown.shows, showsBefore + 1)
Equal("AeonUI's own inspect is cleared", inspects.cleared, 1)
Hover("Player-9")
Equal("a known player shows at once", Added("Item Level").right, "312")
RunTimers()
Equal("without asking again", #inspects.asked, 1)

now = now + 3
Hover("Player-10")
inspected["Player-10"] = { level = 0, spec = 62 }
gear["Player-10"] = { [1] = "item:head" }
itemLevels["item:head"] = 320
now = now + 1
RunTimers()
events.INSPECT_READY("Player-10")
Equal("an item level the client lacks is averaged from the gear", rights[Inspect.shown.itemLevel].text, "20")

now = now + 3
Hover("Player-11")
inspected["Player-11"] = { level = 0 }
gear["Player-11"] = { [1] = "item:late" }
now = now + 1
RunTimers()
events.INSPECT_READY("Player-11")
Equal("gear still loading keeps waiting", rights[Inspect.shown.itemLevel].text, "...")
itemLevels["item:late"] = 320
events.GET_ITEM_INFO_RECEIVED(1, true)
Equal("and is averaged once it arrives", rights[Inspect.shown.itemLevel].text, "20")

RunTimers()
combat = true
now = now + 3
Hover("Player-12")
Equal("in combat an unknown player gets no lines", Find("Item Level"), nil)
Equal("and nothing is asked", #timers, 0)
combat = false

local asked = #inspects.asked
now = now + 3
party["Player-13"] = true
hooks.NotifyInspect()
Hover("Player-13")
now = now + 1
RunTimers()
Equal("a group member waits while another addon polls the group", #inspects.asked, asked)
now = now + 10
RunTimers()
Equal("then is inspected", #inspects.asked, asked + 1)
inspected["Player-13"] = { level = 300 }
events.INSPECT_READY("Player-13")

now = now + 3
Hover("Player-14")
inspected["Player-14"] = { level = 290 }
local cleared = inspects.cleared
events.INSPECT_READY("Player-14")
Equal("another addon's answer is kept", rights[Inspect.shown.itemLevel].text, "290")
Equal("and its inspect is left to it", inspects.cleared, cleared)
RunTimers()
Equal("so the player needs no request", #inspects.asked, asked + 1)

now = now + 3
reach = false
Hover("Player-15")
now = now + 1
RunTimers()
Equal("a player out of reach is not asked", #inspects.asked, asked + 1)
Equal("but tried again", #timers, 1)
reach = true
Post("Unit", { guid = "Player-0", lines = {} })
units.mouseover = nil
RunTimers()
Equal("not once the tooltip shows someone else", #inspects.asked, asked + 1)

units.mouseover = units.player
Post("Unit", { guid = "Player-1", lines = {} })
Equal("the player's own item level needs no inspect", Added("Item Level").right, "281")
Equal("nor their specialization", Added("Specialization").right, "|A:roleicon-tiny-dps|a Arcane")

libSpec.group[Inspect](65, "HEALER", "RANGED", "Lor")
now = now + 3
Hover("Player-16", "Lor")
Equal("a shared specialization shows at once", Added("Specialization").right, "|A:roleicon-tiny-healer|a Holy")
Equal("while the item level waits", Added("Item Level").right, "...")
events.PLAYER_ENTERING_WORLD()
events.PLAYER_ENTERING_WORLD()
Equal("guild members are asked to share once", libSpec.guildRequests, 1)

AUI.can.specializations = nil
Hover("Player-9")
Equal("no specialization line where the client has none", Find("Specialization"), nil)
values[Options.ITEM_LEVEL_PATH] = false
Hover("Player-9")
Equal("the item level can be turned off", Find("Item Level"), nil)
values[Options.ITEM_LEVEL_PATH] = nil
now = now + 3
Hover("Player-20")
inspected["Player-20"] = { level = 0 }
gear["Player-20"] = { [1] = "item:never" }
now = now + 1
RunTimers()
events.INSPECT_READY("Player-20")
Equal("gear that has not loaded keeps listening", eventHandlers.GET_ITEM_INFO_RECEIVED[Inspect] ~= nil, true)
now = now + 301
events.GET_ITEM_INFO_RECEIVED(2, true)
Equal("and is given up on after the answer's lifetime", eventHandlers.GET_ITEM_INFO_RECEIVED[Inspect], nil)
Fire("OnHide", GameTooltip)
Equal("a hidden tooltip shows nobody", Inspect.shown.guid, nil)
RunTimers()
values[Options.MOUNT_PATH], values[Options.TARGET_PATH] = nil, nil

-- Anchor arithmetic ---------------------------------------------------------------------------------------------

Equal("above the cursor, the tooltip's bottom touches it", Options:CursorPoint("TOP"), "BOTTOM")
Equal("below right, its top left", Options:CursorPoint("BOTTOMRIGHT"), "TOPLEFT")
Equal("an unknown place sits above", Options:CursorPoint("SIDE"), "BOTTOM")
Equal("growing down pins the top", Options:GrowthPoint("BOTTOMRIGHT", "DOWN"), "TOPRIGHT")
Equal("growing up pins the bottom", Options:GrowthPoint("TOPLEFT", "UP"), "BOTTOMLEFT")
Equal("a side-less point keeps no side", Options:GrowthPoint("TOP", "UP"), "BOTTOM")
Equal("Default keeps Blizzard's corner", Options:GrowthPoint("TOPLEFT", "DEFAULT"), "TOPLEFT")
Equal("a box low left grows from its bottom left", Options:FixedCorner(-100, -50, "DEFAULT"), "BOTTOMLEFT")
Equal("high right from its top right", Options:FixedCorner(100, 50, "DEFAULT"), "TOPRIGHT")
Equal("a growth direction sets the top or bottom", Options:FixedCorner(100, 50, "UP"), "BOTTOMRIGHT")
local container = Options:ContainerPosition(1500, 100, 300, 150, 1920, 1080)
Equal("Blizzard's container at the bottom right", container.point, "BOTTOMRIGHT")
Equal("its offsets from that corner", container.x .. " " .. container.y, "-120 100")
Equal("a container high left", Options:ContainerPosition(20, 900, 300, 150, 1920, 1080).point, "TOPLEFT")

-- Anchoring ---------------------------------------------------------------------------------------------------

local Anchor = AUI.TooltipAnchor
local cursorAt = { x = 500, y = 400 }
local frames = {}

---@param point string
---@return number h the point's place across a rectangle, 0 to 1
---@return number v its place up it
local function Fractions(point)
	local v = point:match("TOP") and 1 or point:match("BOTTOM") and 0 or 0.5
	local h = point:match("LEFT") and 0 or point:match("RIGHT") and 1 or 0.5

	return h, v
end

---A frame stub that works out its left and bottom from one point set on UIParent.
function CreateFrame(_, name)
	local frame = { width = 0, height = 0, shown = true }
	local widget = Widget("Frame", {
		SetSize = function(_, width, height)
			frame.width, frame.height = width, height
		end,
		EnableMouse = function() end,
		ClearAllPoints = function()
			frame.point = nil
		end,
		SetPoint = function(_, point, relativeTo, relativePoint, x, y)
			frame.point = { point, relativeTo, relativePoint, x or 0, y or 0 }
		end,
		GetLeft = function()
			local point = frame.point

			if not point then
				return nil
			end

			local h = Fractions(point[1])
			local rh = Fractions(point[3])

			return rh * 1920 + point[4] - h * frame.width
		end,
		GetBottom = function()
			local point = frame.point

			if not point then
				return nil
			end

			local _, v = Fractions(point[1])
			local _, rv = Fractions(point[3])

			return rv * 1080 + point[5] - v * frame.height
		end,
		SetFrameStrata = function() end,
		SetScript = function(_, script, handler)
			frame[script] = handler
		end,
		Show = function()
			frame.shown = true
		end,
		Hide = function()
			frame.shown = false
		end,
		IsShown = function()
			return frame.shown
		end,
		state = frame,
	})

	if name then
		_G[name] = widget
	end

	frames[#frames + 1] = widget

	return widget
end
function GetCursorPosition() return cursorAt.x, cursorAt.y end
C_CVar.GetCVarBool = function(name) return cvars[name] == "1" end
C_InstanceEncounter = { IsEncounterInProgress = function() return combat end }
local comparisons = { cleared = 0 }
TooltipComparisonManager = {
	Clear = function()
		comparisons.cleared = comparisons.cleared + 1
	end,
}
function GameTooltip_SuppressAutomaticCompareItem(tooltip)
	tooltip.suppressAutomaticCompareItem = true
end
local OWNER = { IsForbidden = function() return false end }

local function Corner()
	local point = anchoring.points[1]

	return point and (tostring(point[1]) .. ">" .. (point[2] == GameTooltipDefaultContainer and "container"
		or point[2] == Anchor.box and "box" or point[2] == Anchor.cursor and "cursor" or "other")) or "none"
end

GameTooltip_SetDefaultAnchor(GameTooltip, OWNER)
Equal("Blizzard's place by default", Corner(), "BOTTOMRIGHT>container")
Equal("and its one point", #anchoring.points, 1)
values[Options.GROWTH_PATH] = "DOWN"
GameTooltip_SetDefaultAnchor(GameTooltip, OWNER)
Equal("growing down pins Blizzard's corner by its top", Corner(), "TOPRIGHT>container")
GameTooltip:SetPoint("BOTTOMRIGHT", GameTooltipDefaultContainer, "BOTTOMRIGHT", 0, 0)
hooks.SetPoint(GameTooltip)
Equal("a later anchor from Blizzard is turned back", Corner(), "TOPRIGHT>container")
Equal("leaving one point", #anchoring.points, 1)
GameTooltip:SetOwner(OWNER, "ANCHOR_RIGHT")
hooks.SetOwner(GameTooltip)
GameTooltip:ClearAllPoints()
GameTooltip:SetPoint("BOTTOMLEFT", OWNER, "TOPRIGHT", 0, 0)
hooks.SetPoint(GameTooltip)
Equal("a tooltip its owner anchors is left alone", Corner(), "BOTTOMLEFT>other")
values[Options.GROWTH_PATH] = nil

values[Options.POSITION_PATH] = { point = "CENTER", x = -400, y = -200 }
Tooltip:Apply()
Anchor:Box()
GameTooltip_SetDefaultAnchor(GameTooltip, OWNER)
Equal("a saved place pins the tooltip in AeonUI's box", Corner(), "BOTTOMLEFT>box")
Equal("by the corner facing the screen's", anchoring.points[1][3], "BOTTOMLEFT")
values[Options.GROWTH_PATH] = "DOWN"
GameTooltip_SetDefaultAnchor(GameTooltip, OWNER)
Equal("growing down from the box's top", Corner(), "TOPLEFT>box")
values[Options.GROWTH_PATH] = nil
anchoring.points = { { SECRET, SECRET, SECRET, 0, 0 } }
Anchor:Enforce(GameTooltip)
Equal("a secret point is replaced in the box", Corner(), "BOTTOMLEFT>box")
anchoring.points = {}
Anchor:OnDefaultAnchor(GameTooltip, { IsForbidden = function() return true end })
Equal("a forbidden owner is left to Blizzard", #anchoring.points, 0)
Equal("and its points are not kept", Anchor.armed, false)
values[Options.POSITION_PATH] = nil
Tooltip:Apply()
local position = Anchor.box.state.point
Equal("without a saved place the box sits where Blizzard's container is", position[1] .. " " .. position[4] .. " "
	.. position[5], "BOTTOMRIGHT -120 100")

values[Options.CURSOR_PATH] = true
values[Options.CURSOR_POINT_PATH] = "TOPRIGHT"
values[Options.CURSOR_X_PATH], values[Options.CURSOR_Y_PATH] = 10, -5
values[Options.POSITION_PATH] = { point = "CENTER", x = 0, y = 0 }
GameTooltip_SetDefaultAnchor(GameTooltip, OWNER)
Equal("riding the cursor wins over a saved place", Corner(), "BOTTOMLEFT>cursor")
Equal("with its offsets", tostring(anchoring.points[1][4]) .. " " .. tostring(anchoring.points[1][5]), "10 -5")
Equal("the cursor point is at the cursor", Anchor.cursor.state.point[4] .. " " .. Anchor.cursor.state.point[5],
	"500 400")
cursorAt.x = 640
Anchor.cursor.state.OnUpdate(Anchor.cursor)
Equal("and follows it", Anchor.cursor.state.point[4], 640)
local hides = anchoring.hides
hooks.FadeOut(GameTooltip)
Equal("a fading unit tooltip hides at once while riding the cursor", anchoring.hides, hides + 1)
Fire("OnHide", GameTooltip)
Equal("the cursor point stops with the tooltip", Anchor.cursor.state.shown, false)
values[Options.CURSOR_PATH], values[Options.CURSOR_POINT_PATH] = nil, nil
values[Options.CURSOR_X_PATH], values[Options.CURSOR_Y_PATH] = nil, nil
values[Options.POSITION_PATH] = nil

values[Options.ENABLED_PATH] = false
values[Options.GROWTH_PATH] = "DOWN"
GameTooltip_SetDefaultAnchor(GameTooltip, OWNER)
Equal("the module off leaves Blizzard's anchor", Corner(), "BOTTOMRIGHT>container")
values[Options.ENABLED_PATH], values[Options.GROWTH_PATH] = nil, nil

cvars.UberTooltips = "0"
Equal("Enhanced Tooltips reads the game's setting", Anchor:Enhanced(), false)
Anchor:SetEnhanced(true)
Equal("and writes it", cvars.UberTooltips, "1")

for _, file in ipairs({ "Core/Modules.lua", "AeonUI_Tooltip/Settings/Tooltip.lua", "Settings/EditTargets.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end
local targets = AUI.EditTargets:Targets()
Equal("the tooltip has a mover", targets[1] and targets[1].key, "tooltip")
Equal("around AeonUI's box", targets[1].frame, Anchor.box)
Equal("whose default is Blizzard's place", targets[1].default.point, "BOTTOMRIGHT")
Equal("linked to its settings", targets[1].settings.section, "tooltipPlace")
targets[1].place({ point = "TOPLEFT", x = 30, y = -40 })
Equal("which AeonUI places itself", Anchor.box.state.point[1] .. " " .. Anchor.box.state.point[4], "TOPLEFT 30")
values[Options.CURSOR_PATH] = true
Equal("no mover while riding the cursor", #AUI.EditTargets:Targets(), 0)
values[Options.CURSOR_PATH] = nil

-- Visibility --------------------------------------------------------------------------------------------------

local Visibility = AUI.TooltipVisibility

GameTooltip_SetDefaultAnchor(GameTooltip, OWNER)
Equal("Always never hides the tooltip", anchoring.parent, UIParent)
values[Options.SHOW_MODE_PATH] = "NEVER"
Tooltip:Apply()
GameTooltip_SetDefaultAnchor(GameTooltip, OWNER)
Equal("Never keeps it in the hidden frame", anchoring.parent, Visibility.host)
Equal("which is hidden", Visibility.host.state.shown, false)
Equal("with comparisons turned off", GameTooltip.suppressAutomaticCompareItem, true)
RunTimers()
Equal("and cleared on the next frame", comparisons.cleared, 1)
GameTooltip.suppressAutomaticCompareItem = false
preCalls[Enum.TooltipDataType.Item][1](GameTooltip)
Equal("an item's rebuild turns them off again", GameTooltip.suppressAutomaticCompareItem, true)
shopping.OnShow[1]()
RunTimers()
Equal("a comparison shown while kept is cleared", comparisons.cleared, 2)

values[Options.PEEK_PATH] = "SHIFT"
keys.shift = true
events.MODIFIER_STATE_CHANGED("LSHIFT", 1)
Equal("the show key takes it out", anchoring.parent, UIParent)
Equal("on top again", anchoring.strata, "TOOLTIP")
keys.shift = false
events.MODIFIER_STATE_CHANGED("LSHIFT", 0)
Equal("and letting go puts it back", anchoring.parent, Visibility.host)
events.MODIFIER_STATE_CHANGED("LCTRL", 1)
Equal("another key does nothing", anchoring.parent, Visibility.host)
GameTooltip:SetOwner(OWNER, "ANCHOR_RIGHT")
keys.shift = true
hooks.SetOwner(GameTooltip)
Equal("a tooltip built while the key is held shows", anchoring.parent, UIParent)
keys.shift = false
values[Options.PEEK_PATH] = nil

values[Options.SHOW_MODE_PATH] = "OUT_OF_COMBAT"
Tooltip:Apply()
GameTooltip_SetDefaultAnchor(GameTooltip, OWNER)
Equal("Out of Combat shows it out of combat", anchoring.parent, UIParent)
combat = true
events.PLAYER_REGEN_DISABLED()
Equal("and keeps a shown one hidden when combat starts", anchoring.parent, Visibility.host)
combat = false
events.PLAYER_REGEN_ENABLED()
Equal("until its owner shows it again", anchoring.parent, Visibility.host)
Fire("OnShow", GameTooltip)
Equal("which it then does", anchoring.parent, UIParent)
values[Options.SHOW_MODE_PATH] = "OUT_OF_BOSS_COMBAT"
Tooltip:Apply()
Equal("a mode watches only its own events", eventHandlers.PLAYER_REGEN_DISABLED[Visibility], nil)
combat = true
GameTooltip_SetDefaultAnchor(GameTooltip, OWNER)
Equal("Out of Boss Combat hides it in an encounter", anchoring.parent, Visibility.host)
combat = false
values[Options.ENABLED_PATH] = false
Tooltip:Apply()
Equal("the module off shows it again", anchoring.parent, UIParent)
values[Options.ENABLED_PATH], values[Options.SHOW_MODE_PATH] = nil, nil
Tooltip:Apply()

-- The settings cache --------------------------------------------------------------------------------------------

values[Options.TITLES_PATH] = true
Equal("a setting is read through the cache", Options:Get(Options.TITLES_PATH), true)
stored[Options.TITLES_PATH] = false
Equal("and kept until a Tooltip setting changes", Options:Get(Options.TITLES_PATH), true)
Tooltip:OnProfileChanged("minimap.width")
Equal("another feature's change keeps it", Options:Get(Options.TITLES_PATH), true)
Tooltip:OnProfileChanged(Options.TITLES_PATH)
Equal("a Tooltip change reads it again", Options:Get(Options.TITLES_PATH), false)
stored[Options.TITLES_PATH] = true
Tooltip:OnProfileChanged(nil)
Equal("so does a whole-profile change", Options:Get(Options.TITLES_PATH), true)
values[Options.TITLES_PATH] = nil

-- The Units preview's samples ----------------------------------------------------------------------------------

function UnitRace() return "Human" end
function UnitLevel(token) return Unit(token).level end
function GetCreatureDifficultyColor(level) return level > 80 and DIFFICULTY[3] or DIFFICULTY[1] end
GREEN_FONT_COLOR = { r = 0.1, g = 1, b = 0.1 }
OFFICER, ELITE, UNITNAME_TITLE_PET = "Officer", "Elite", "%s's Pet"

-- A sample tooltip that keeps its lines' text and colors.
local function SampleTooltip()
	local lines = {}

	return Widget("GameTooltip", {
		lines = lines,
		ClearLines = function()
			for index = #lines, 1, -1 do
				lines[index] = nil
			end
		end,
		AddLine = function(_, text, r, g, b)
			lines[#lines + 1] = { left = text, color = { r, g, b } }
		end,
		AddDoubleLine = function(_, left, right, _, _, _, r, g, b)
			lines[#lines + 1] = { left = left, right = right, color = { r, g, b } }
		end,
		NumLines = function()
			return #lines
		end,
	})
end

---@return string text each line as "left" or "left=right"
local function SampleText(tooltip)
	local parts = {}

	for index, line in ipairs(tooltip.lines) do
		parts[index] = line.right and (line.left .. "=" .. line.right) or line.left
	end

	return table.concat(parts, " | ")
end

local samplePlayer, sampleCreature, samplePet = SampleTooltip(), SampleTooltip(), SampleTooltip()
local Units = AUI.TooltipUnits
local sampleCan = { mythicPlus = AUI.can.mythicPlus, specializations = AUI.can.specializations }

units.player = { name = "Aeon", class = "MAGE", level = 80 }
AUI.can.mythicPlus, AUI.can.specializations = true, true
collected = true

for _, path in ipairs({ Options.TITLES_PATH, Options.GUILD_RANK_PATH, Options.LEVEL_COLOR_PATH, Options.MUTED_LINES_PATH,
	Options.TARGET_PATH, Options.RATING_PATH, Options.MOUNT_PATH, Options.ITEM_LEVEL_PATH,
	Options.SPECIALIZATION_PATH }) do
	values[path] = true
end

Units:Sample(samplePlayer, sampleCreature, samplePet)
Equal("the sample player has every line", SampleText(samplePlayer), "Aeon the Patient | <AeonUI> [Officer] | Level "
	.. Format:Wrap("80", Format.FRIENDLY_LEVEL) .. " Human Class | Mythic+ Rating=2500"
	.. " | Mount=Swift Gryphon |A:common-icon-checkmark|a | Item Level=281 | Specialization=|A:roleicon-tiny-dps|a Arcane")
Equal("in the character's class color", samplePlayer.lines[1].color[1], CLASS.MAGE.r)
Equal("the creature is elite, a level above and targeting the player", SampleText(sampleCreature), "Gnoll Brute | Level "
	.. Format:Wrap("82", DIFFICULTY[3]) .. Format:Wrap("+", Format.MARKS.elite) .. " (Elite) | Target=You")
Equal("the pet's owner line is grayed", SampleText(samplePet) .. " " .. samplePet.lines[2].color[1],
	"Wolf | Aeon's Pet | Level " .. Format:Wrap("80", DIFFICULTY[1]) .. " " .. Format.MUTED.r)

for _, path in ipairs({ Options.TITLES_PATH, Options.GUILD_RANK_PATH, Options.LEVEL_COLOR_PATH, Options.MUTED_LINES_PATH,
	Options.TARGET_PATH, Options.RATING_PATH, Options.MOUNT_PATH, Options.ITEM_LEVEL_PATH,
	Options.SPECIALIZATION_PATH }) do
	values[path] = false
end

Units:Sample(samplePlayer, sampleCreature, samplePet)
Equal("with every line off the player keeps Blizzard's", SampleText(samplePlayer),
	"Aeon | <AeonUI> | Level 80 Human Class")
Equal("as do the creature", SampleText(sampleCreature), "Gnoll Brute | Level 82 (Elite)")
Equal("and the pet", SampleText(samplePet) .. " " .. samplePet.lines[2].color[1], "Wolf | Aeon's Pet | Level 80 1")
AUI.can.mythicPlus = nil
values[Options.RATING_PATH] = true
Units:Sample(samplePlayer, sampleCreature, samplePet)
Equal("no rating where players have none", SampleText(samplePlayer):find("Mythic", 1, true), nil)

for _, path in ipairs({ Options.TITLES_PATH, Options.GUILD_RANK_PATH, Options.LEVEL_COLOR_PATH, Options.MUTED_LINES_PATH,
	Options.TARGET_PATH, Options.RATING_PATH, Options.MOUNT_PATH, Options.ITEM_LEVEL_PATH,
	Options.SPECIALIZATION_PATH }) do
	values[path] = nil
end

units.player = nil
AUI.can.mythicPlus, AUI.can.specializations = sampleCan.mythicPlus, sampleCan.specializations

print(("check_tooltip: %d checks passed"):format(checks))
