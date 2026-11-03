-- Checks AeonUI_UnitFrames/Frames/PowerColor.lua and ClassPower.lua and the resource frames in Frames.lua outside the
-- game: power colors and their palette, segment arithmetic and colors, heights with extra mana, each switch's elements,
-- attaching to the power bar, frames spawned only when turned on and past combat, and Blizzard's frame left alone.
-- Run from any directory with Lua 5.1: lua Tools/check_resources.lua
-- Frames are stand-ins that record the last call of each method; oUF's elements and drawing are not exercised here.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

UNKNOWN = "Unknown"
SlashCmdList = {}
C_AddOns = {
	GetAddOnMetadata = function() end,
}
UIParent = {}
Enum = { StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 }, PowerType = { Essence = 19 } }
C_SpecializationInfo = {
	GetSpecialization = function()
		return 2
	end,
}

function issecretvalue()
	return false
end

local combat = false

function InCombatLockdown()
	return combat
end

function UnitClass()
	return "Mage", "MAGE"
end

function UnitIsPlayer()
	return true
end

function UnitInPartyIsAI()
	return false
end

function GetCVar()
	return "0"
end

function Mixin(object, source)
	for key, value in pairs(source) do
		object[key] = value
	end

	return object
end

---A frame or region stand-in recording the last call of each method.
local function Region()
	local region = { last = {}, shown = true, level = 1, Stagger = false }

	function region:SetShown(shown)
		self.shown = shown == true
	end

	function region:Show()
		self.shown = true
	end

	function region:Hide()
		self.shown = false
	end

	function region:CreateTexture()
		return Region()
	end

	function region:CreateFontString()
		return Region()
	end

	function region:SetPoint(...)
		self.points = rawget(self, "points") or {}
		self.points[#self.points + 1] = { ... }
	end

	function region:ClearAllPoints()
		self.points = {}
	end

	function region:GetMinMaxValues()
		return 0, 1
	end

	function region:IsElementEnabled(element)
		return self.elements ~= nil and self.elements[element] == true
	end

	function region:GetFrameLevel()
		return 1
	end

	function region:GetWidth()
		return self.width or 0
	end

	function region:GetHeight()
		return self.height or 0
	end

	function region:SetSize(width, height)
		self.last.SetSize = { width, height }
		self.width, self.height = width, height
	end

	function region:GetValue()
		return self.value or 0
	end

	function region:SetValue(value)
		self.value = value
	end

	return setmetatable(region, {
		__index = function(_, method)
			if not method:find("^%u") then
				return nil
			end

			return function(self, ...)
				self.last[method] = { ... }
			end
		end,
	})
end

function CreateFrame(_, _, parent)
	local frame = Region()

	frame.parent = parent

	return frame
end

local AUI = {}

assert(loadfile(root .. "AeonUI/Core/Core.lua"))("AeonUI", AUI)
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
AUI.Pixel = function()
	return 0.5
end
AUI.Border = {
	ART_COLOR = { r = 0.5, g = 0.4, b = 0.3 },
	Create = function()
		return Region()
	end,
	CellDividerWidth = function()
		return nil
	end,
	StyleCellDivider = function()
		return false
	end,
}
AUI.Media = {
	FLAT = "flat",
	SetBarTexture = function() end,
	Font = function(_, name)
		return name
	end,
	FontFlags = function(_, outline)
		return outline
	end,
}
AUI.Tags = { Register = function() end }
AUI.UnitFrame = {
	specs = {},
	BORDER_LEVEL = 6,
	Style = function() end,
	CreateBar = function()
		local border = Region()

		function border.Layout() end

		return Region(), Region(), border
	end,
	BarLook = function()
		return {}
	end,
	StyleBar = function() end,
	AnchorBackground = function() end,
}
AUI.Text = {
	Create = function() end,
	Apply = function() end,
}
AUI.HealthColor = { Paint = function() end }
AUI.Fading = { Start = function() end }
AUI.RangeFade = { Start = function() end }
AUI.Events = { Register = function() end }
AUI.Indicators = {
	Register = function() end,
	SetElement = function(_, frame, element, on)
		frame.elements = frame.elements or {}
		frame.elements[element] = on
	end,
}

local handlers = {}

AUI.Callbacks = {
	Register = function(_, channel, _, handler)
		handlers[channel] = handler
	end,
}

function LibStub()
	return {
		RegisterCallback = function() end,
		ReduceMotion = function()
			return false
		end,
	}
end

local spawned, disabledBlizzard = {}, 0

AUI.oUF = {
	colors = {
		power = {
			MANA = { r = 0, g = 0, b = 1 },
			RAGE = {
				r = 1, g = 0, b = 0,
				SetRGB = function(self, r, g, b)
					self.r, self.g, self.b = r, g, b
				end,
			},
		},
		class = { MAGE = { r = 0.2, g = 0.7, b = 0.9 } },
	},
	RegisterStyle = function(self, name, style)
		self.styles = self.styles or {}
		self.styles[name] = style
	end,
	SetActiveStyle = function(self, name)
		self.active = name
	end,
	DisableBlizzard = function()
		disabledBlizzard = disabledBlizzard + 1
	end,
	Spawn = function(self, unit, name)
		local frame = Region()

		self:DisableBlizzard(unit)
		frame.name = name
		spawned[#spawned + 1] = name
		self.styles[self.active](frame, unit)

		return frame
	end,
}

assert(loadfile(root .. "AeonUI/Profile/Schema.lua"))("AeonUI", AUI)
assert(loadfile(root .. "AeonUI_UnitFrames/Frames/Options.lua"))("AeonUI", AUI)
assert(loadfile(root .. "AeonUI_UnitFrames/Frames/PowerColor.lua"))("AeonUI", AUI)
assert(loadfile(root .. "AeonUI_UnitFrames/Frames/PlayerPower.lua"))("AeonUI", AUI)
assert(loadfile(root .. "AeonUI_UnitFrames/Frames/ClassPower.lua"))("AeonUI", AUI)
assert(loadfile(root .. "AeonUI_UnitFrames/Frames/Frames.lua"))("AeonUI", AUI)

local Schema, Options, PowerColor, ClassPower, Frames = AUI.Schema, AUI.UnitFrameOptions, AUI.PowerColor, AUI.ClassPower,
	AUI.Frames
local ALL = Options.ALL
local config = Schema:Defaults()

AUI.Profile = {
	Get = function(_, path)
		return Schema:Read(config, path)
	end,
}

local function Set(path, value)
	Schema:Write(config, path, value)
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

-- Power colors --------------------------------------------------------------------------------------------

local settings = PowerColor:Resolve("playerPower")
Equal("power type by default", settings.mode, "type")
Equal("full opacity", settings.fillAlpha, 100)
Equal("the bar's background", settings.background, "custom")
Equal("reads the bar background", settings.barBackground.r, 0.067)

local base, class = { r = 1, g = 0, b = 0 }, { r = 0, g = 1, b = 0 }

Equal("power type keeps oUF's color", PowerColor:Fill(settings, base, class), base)
settings.mode = "class"
Equal("class takes the class color", PowerColor:Fill(settings, base, class), class)
Equal("no class color keeps the type", PowerColor:Fill(settings, base, nil), base)
settings.mode = "custom"
Equal("custom", PowerColor:Fill(settings, base, class), settings.color)
Equal("background is the bar's", PowerColor:Background(settings, base), settings.barBackground)
settings.background = "power"
Equal("or the power color", PowerColor:Background(settings, base).r, 1)
Equal("at the bar background's opacity", PowerColor:Background(settings, base).a, 1)

Set(ALL .. "powerColors.mode", "class")
Equal("a bar follows All Frames", PowerColor:Resolve("playerPower").mode, "class")
Set(Options:Path("playerPower", "powerColors.mode"), "custom")
Equal("until it holds its own", PowerColor:Resolve("playerPower").mode, "custom")
config = Schema:Defaults()

PowerColor:ApplyPalette()
Equal("no palette keeps Blizzard's", AUI.oUF.colors.power.MANA.b, 1)
Set(ALL .. "powerColors.palette.MANA", { r = 0.5, g = 0.5, b = 0.5 })
Set(ALL .. "powerColors.palette.RAGE", { r = 0.1, g = 0.2, b = 0.3 })
PowerColor:ApplyPalette()
Equal("a set color replaces the entry", AUI.oUF.colors.power.MANA.r, 0.5)
Equal("through its own setter", AUI.oUF.colors.power.RAGE.g, 0.2)
config = Schema:Defaults()
PowerColor:ApplyPalette()
Equal("a cleared one gives Blizzard's back", AUI.oUF.colors.power.MANA.b, 1)
Equal("kept from before", PowerColor:Blizzard("RAGE").r, 1)
Equal("a type the client lacks has none", PowerColor:Blizzard("PAIN"), nil)

-- Arithmetic ----------------------------------------------------------------------------------------------

local spots = ClassPower:Segments(100, 5, 5)
Equal("five segments", #spots, 5)
Equal("equal widths", spots[1].w, 16)
Equal("spaced", spots[2].x, 21)
Equal("ending at the width", spots[5].x + spots[5].w, 100)
Equal("no count, no segments", #ClassPower:Segments(100, 0, 5), 0)

settings = { extraMana = false, height = 10, extraManaHeight = 4 }
Equal("the resource alone", ClassPower:Height(settings), 10)
settings.extraMana = true
Equal("with extra mana", ClassPower:Height(settings), 16)

local r = ClassPower:Shade({ r = 1, g = 1, b = 1 }, true)
Equal("a partial segment is darker", r, 0.6)
r = ClassPower:Shade({ 0.5, 0.5, 0.5 })
Equal("a list color works", r, 0.5)

-- Frames --------------------------------------------------------------------------------------------------

Frames:Start()
Equal("nothing spawned with all off", #spawned, 0)
Equal("nothing started", Frames.started, false)
Equal("settings are followed", handlers.Profile ~= nil, true)
Equal("no reload needed", Frames:ReloadNeeded(), false)

combat = true
Set(Options.RESOURCES_PATH, true)
handlers.Profile(Frames, Options.RESOURCES_PATH)
Equal("in combat it waits", #spawned, 0)
combat = false
Frames:Start()
Equal("then both spawn", table.concat(spawned, " "), "AeonUIPlayerPower AeonUIClassPower")
Equal("Blizzard's player frame stays", disabledBlizzard, 0)
AUI.oUF:DisableBlizzard()
Equal("the step is restored for what comes after", disabledBlizzard, 1)
disabledBlizzard = 0

local power, resource = Frames.objects.playerPower, Frames.objects.classPower

Equal("its size", power.last.SetSize[1], 360)
Equal("its place", power.points[1][5], -184)
Equal("it shows", power.last.Enable ~= nil, true)
Equal("the power element runs", power.elements.Power, true)
Equal("oUF's power element on its bar", power.Power, power.Bar)
Equal("in power colors", power.Power.colorPower, true)
Equal("repainted by the palette's step", power.Power.PostUpdateColor, PowerColor.PostUpdateColor)
Equal("no reload for the resources", Frames:ReloadNeeded(), false)
Equal("the power bar does not fade by default", AUI.Profile:Get(Options:Path("playerPower", "fade.idle.enabled")), false)
Equal("nor the class resource", AUI.Profile:Get(Options:Path("classPower", "fade.idle.enabled")), false)
Equal("no hover on a bar with no mouse", Schema.fields[Options:Path("playerPower", "bars.hover")], nil)
Equal("stands on the power bar", resource.points[1][2], power)
Equal("its top", resource.points[1][3], "TOP")
Equal("touching it by default", resource.points[1][5], 0)
Equal("no class resource, no empty border", resource.Holder.shown, resource.elements.Runes == true)
resource.ClassPower.PostVisibility(resource.ClassPower, true)
Equal("a resource shows the holder", resource.Holder.shown, true)
Equal("the rest of the segments in the holder", resource.ClassPower[1].parent, resource.Holder)
Equal("attached", ClassPower:IsAttached(), true)
Equal("the resource runs", resource.elements.ClassPower, true)
Equal("runes too", resource.elements.Runes, true)
Equal("filled runes stand on the left", resource.Runes.sortOrder, "asc")
Equal("drawn as it spawns", resource.last.UpdateAllElements ~= nil, true)
Equal("the power bar too", power.last.UpdateAllElements ~= nil, true)
Equal("read again once the client knows the specialization", resource.last.RegisterEvent ~= nil, true)
Equal("extra mana does not", resource.elements.AdditionalPower, false)

Set(Options:Path("classPower", "extraMana"), true)
handlers.Profile(Frames, Options:Path("classPower", "extraMana"))
Equal("extra mana turns on", resource.elements.AdditionalPower, true)
Equal("the frame grows", resource.last.SetSize[2], 16)
Equal("extra mana under the resource", resource.ExtraHolder.points[1][4], 0)
Equal("past its height", resource.ExtraHolder.points[1][5], -12)

Set(Options:Path("classPower", "attachY"), -3)
handlers.Profile(Frames, Options:Path("classPower", "attachY"))
Equal("it can overlap the power bar", resource.points[1][5], -3)

-- Colors, dividers and smooth fill on the live frame.
settings = ClassPower:Resolve()
Equal("Spec by default", settings.colorMode, "spec")
Equal("a specialization's rune color", ClassPower:BaseColor(settings, "RUNES", base), settings["palette.RUNES_FROST"])
Equal("Spec without its own color is the type's", ClassPower:BaseColor(settings, "CHI", base), settings["palette.CHI"])
Equal("oUF's for a resource with none", ClassPower:BaseColor(settings, "ICICLES", base), base)
settings.colorMode = "type"
Equal("Power Type's rune color", ClassPower:BaseColor(settings, "RUNES", base), settings["palette.RUNES"])
settings.colorMode = "class"
Equal("Class", ClassPower:BaseColor(settings, "RUNES", base), AUI.oUF.colors.class.MAGE)
settings.colorMode = "custom"
Equal("Custom", ClassPower:BaseColor(settings, "RUNES", base), settings.color)
settings.recharge = true
Equal("the recharge color for a filling segment", ClassPower:SegmentColor(settings, base, false, true), 0.5)
settings.recharge = false
Equal("or darker", ClassPower:SegmentColor(settings, { r = 1, g = 1, b = 1 }, false, true), 0.6)
Equal("charged", ClassPower:SegmentColor(settings, base, true, false), settings.chargedColor.r)
Equal("dividers between the segments", resource.Holder.Dividers[1] ~= nil, true)
Equal("Spacing is the divider's width", resource.Holder.Dividers[1].width, 1)
Equal("the dividers of what runs last", resource.Holder.count, 6)
resource.ClassPower.PostUpdate(resource.ClassPower, nil, nil)
Equal("a resource turned off clears without an error", resource.Holder.count, 6)
Equal("smooth fill off by default", power.Power.smoothing, 0)
Set(Options.RESOURCES_SMOOTH, true)
handlers.Profile(Frames, Options.RESOURCES_SMOOTH)
Equal("smooth fill on", power.Power.smoothing, 1)
Equal("extra mana too", resource.AdditionalPower.smoothing, 1)
Set(Options.RESOURCES_SMOOTH, false)

Set(Options:Path("classPower", "attach"), "screen")
handlers.Profile(Frames, Options:Path("classPower", "attach"))
Equal("Screen keeps its own place", resource.points[1][2], UIParent)
Equal("a mover then", ClassPower:IsAttached(), false)

Set(Options.RESOURCES_PATH, false)
resource.ClassPower[1]:Show()
handlers.Profile(Frames, Options.RESOURCES_PATH)
Equal("off stops the power bar", power.last.Disable ~= nil, true)
Equal("its element", power.elements.Power, false)
Equal("off stops the class resource", resource.last.Disable ~= nil, true)
Equal("its elements", resource.elements.ClassPower, false)
Equal("and extra mana", resource.elements.AdditionalPower, false)
Equal("and its segments hide", resource.ClassPower[1].shown, false)

Set(Options.RESOURCES_PATH, true)
handlers.Profile(Frames, Options.RESOURCES_PATH)
Equal("on again runs them", resource.elements.ClassPower, true)
Equal("no second spawn", #spawned, 2)

io.stdout:write(("check_resources: %d checks passed\n"):format(checks))
