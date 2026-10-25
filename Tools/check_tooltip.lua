-- Checks the Tooltip module outside the game: its settings and their bounds, the scaled font sizes and the health
-- bar's place in each style, the tooltip font objects taking the font settings and getting Blizzard's fonts back, the
-- health bar's showing, place, height and texture with the module on and off, the room a tooltip keeps for the strip, and which profile
-- changes re-apply the module.
-- Run from any directory with Lua 5.1: lua Tools/check_tooltip.lua
-- Loads the real files against stubbed globals. It proves the logic, not the drawing.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

UNKNOWN = "Unknown"
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

function issecretvalue()
	return false
end

local hooks = {}
function hooksecurefunc(object, method, handler)
	hooks[method] = handler
	assert(object[method], method)
end

Enum = { TooltipDataType = { Unit = 2, Object = 4 } }
local postCalls = {}
TooltipDataProcessor = {
	AddTooltipPostCall = function(kind, handler)
		postCalls[kind] = handler
	end,
}

local forbidden = false
local padding = { right = 0, bottom = 0, left = 0, top = 0 }
local scripts = {}
GameTooltip = Widget("GameTooltip", {
	IsForbidden = function()
		return forbidden
	end,
	GetPadding = function()
		return padding.right, padding.bottom, padding.left, padding.top
	end,
	SetPadding = function(_, right, bottom, left, top)
		padding.right, padding.bottom, padding.left, padding.top = right, bottom, left or 0, top or 0
	end,
	HookScript = function(_, script, handler)
		scripts[script] = handler
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
})

local AUI = {}
assert(loadfile(root .. "Core/Core.lua"))("AeonUI", AUI)
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
for _, file in ipairs({ "Profile/Schema.lua", "Media/Media.lua", "Minimap/Elements.lua", "Tooltip/Options.lua",
	"Tooltip/Appearance.lua", "Tooltip/Tooltip.lua" }) do
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
AUI.Events = {
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

local Pad = postCalls[Enum.TooltipDataType.Unit]
Equal("unit tooltips are padded", Pad ~= nil, true)
Equal("and object tooltips", postCalls[Enum.TooltipDataType.Object], Pad)
Pad(GameTooltip)
Equal("no room while the bar is hidden", padding.bottom, 0)
bar.shown = true
padding.right, padding.bottom = 5, 2
Pad(GameTooltip)
Equal("room below the last line", padding.bottom, 6)
Equal("the other sides are kept", padding.right, 5)
Pad(GameTooltip)
Equal("added once per content", padding.bottom, 6)
scripts.OnTooltipCleared(GameTooltip)
Equal("taken back when the lines clear", padding.bottom, 2)
Pad({})
Equal("other tooltips are left alone", padding.bottom, 2)
Pad(GameTooltip)
scripts.OnHide()
padding.bottom = 0
Pad(GameTooltip)
Equal("after Blizzard clears it on hide, added afresh", padding.bottom, 4)
scripts.OnTooltipCleared(GameTooltip)
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

print(("check_tooltip: %d checks passed"):format(checks))
