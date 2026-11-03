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
AUI.Border = { ART_COLOR = { r = 0.5, g = 0.4, b = 0.3 } }
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
AUI.Events = { Register = function() end }
AUI.Indicators = {
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
	return { RegisterCallback = function() end }
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

settings = { enabled = true, extraMana = false, height = 10, extraManaHeight = 4 }
Equal("the resource alone", ClassPower:Height(settings), 10)
settings.extraMana = true
Equal("with extra mana", ClassPower:Height(settings), 16)
settings.enabled = false
Equal("extra mana alone", ClassPower:Height(settings), 4)

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

Set(Options:Path("playerPower", "enabled"), true)
handlers.Profile(Frames, Options:Path("playerPower", "enabled"))
Equal("turning on starts", Frames.started, true)
Equal("the power bar spawns", spawned[1], "AeonUIPlayerPower")
Equal("the class resource does not", #spawned, 1)
Equal("Blizzard's player frame stays", disabledBlizzard, 0)
Equal("the step is restored", type(AUI.oUF.DisableBlizzard), "function")
AUI.oUF:DisableBlizzard()
Equal("for what comes after", disabledBlizzard, 1)
disabledBlizzard = 0

local power = Frames.objects.playerPower

Equal("its size", power.last.SetSize[1], 360)
Equal("its place", power.points[1][5], -184)
Equal("it shows", power.last.Enable ~= nil, true)
Equal("oUF's power element on its bar", power.Power, power.Bar)
Equal("in power colors", power.Power.colorPower, true)
Equal("repainted by the palette's step", power.Power.PostUpdateColor, PowerColor.PostUpdateColor)
Equal("no reload for a resource", Frames:ReloadNeeded(), false)

combat = true
Set(Options:Path("classPower", "enabled"), true)
handlers.Profile(Frames, Options:Path("classPower", "enabled"))
Equal("in combat it waits", #spawned, 1)
combat = false
Frames:OnCombatEnded()
Equal("then spawns", spawned[2], "AeonUIClassPower")

local resource = Frames.objects.classPower

Equal("stands on the power bar", resource.points[1][2], power)
Equal("its top", resource.points[1][3], "TOP")
Equal("the resource runs", resource.elements.ClassPower, true)
Equal("runes too", resource.elements.Runes, true)
Equal("extra mana does not", resource.elements.AdditionalPower, false)
Equal("no mover while attached", ClassPower:IsAttached(), true)

Set(Options:Path("classPower", "extraMana"), true)
handlers.Profile(Frames, Options:Path("classPower", "extraMana"))
Equal("extra mana turns on", resource.elements.AdditionalPower, true)
Equal("the frame grows", resource.last.SetSize[2], 16)
Equal("extra mana under the resource", resource.AdditionalPower.points[1][4], 0)
Equal("past its height", resource.AdditionalPower.points[1][5], -12)

Set(Options:Path("classPower", "enabled"), false)
resource.ClassPower[1]:Show()
handlers.Profile(Frames, Options:Path("classPower", "enabled"))
Equal("extra mana keeps the frame", resource.last.Disable, nil)
Equal("the resource stops", resource.elements.ClassPower, false)
Equal("and its segments hide", resource.ClassPower[1].shown, false)
Equal("extra mana moves up", resource.AdditionalPower.points[1][5], -0)

Set(Options:Path("classPower", "extraMana"), false)
handlers.Profile(Frames, Options:Path("classPower", "extraMana"))
Equal("both off stops the frame", resource.last.Disable ~= nil, true)

Set(Options:Path("playerPower", "enabled"), false)
Set(Options:Path("classPower", "enabled"), true)
handlers.Profile(Frames, Options:Path("playerPower", "enabled"))
Equal("no power bar, its own place", resource.points[1][2], UIParent)
Equal("a mover then", ClassPower:IsAttached(), false)
Equal("the power bar stops", power.last.Disable ~= nil, true)
Set(Options:Path("playerPower", "enabled"), true)
Set(Options:Path("classPower", "attach"), "screen")
handlers.Profile(Frames, Options:Path("classPower", "attach"))
Equal("Screen keeps its own place", resource.points[1][2], UIParent)

io.stdout:write(("check_resources: %d checks passed\n"):format(checks))
