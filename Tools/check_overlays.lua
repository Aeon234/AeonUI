-- Checks AeonUI_UnitFrames/Frames/Overlays.lua outside the game: overlay settings and their defaults, attach points for each fill
-- direction, what each setting shows and hides, the calculator modes set on a live frame, the overshield flag read
-- and switched back, and the preview's sample amounts.
-- Run from any directory with Lua 5.1: lua Tools/check_overlays.lua
-- Frames are the shared client's widgets; drawing and clipping are not exercised here.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"
local client = assert(loadfile(root .. "Tools/stub_client.lua"))({ project = "retail" })
local Equal = client.Equal

-- Environment ---------------------------------------------------------------------------------------------

Enum = { UnitDamageAbsorbClampMode = { MissingHealth = 0, MissingHealthWithoutIncomingHeals = 1, MaximumHealth = 2 } }

UNKNOWN = "Unknown"
SlashCmdList = {}
C_AddOns = {
	GetAddOnMetadata = function() end,
}

local AUI = {}
assert(loadfile(root .. "AeonUI/Core/Core.lua"))("AeonUI", AUI)
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
AUI.Media = {
	FLAT = "flat",
	SetBarTexture = function(_, bar, choice)
		bar.texture = choice
	end,
}
AUI.Border = { ART_COLOR = { r = 0.5, g = 0.4, b = 0.3 } }
assert(loadfile(root .. "AeonUI/Profile/Schema.lua"))("AeonUI", AUI)
assert(loadfile(root .. "AeonUI_UnitFrames/Frames/Options.lua"))("AeonUI", AUI)
assert(loadfile(root .. "AeonUI_UnitFrames/Frames/Overlays.lua"))("AeonUI", AUI)

local Overlays, Schema, Options = AUI.Overlays, AUI.Schema, AUI.UnitFrameOptions
local ALL = Options.ALL
local config = Schema:Defaults()

AUI.Profile = {
	Get = function(_, path)
		return Schema:Read(config, path)
	end,
}

-- Helpers --------------------------------------------------------------------------------------------------

local function Near(name, actual, expected)
	Equal(name, math.abs(actual - expected) < 1e-9, true)
end

local function Points(region)
	local list = {}
	for _, point in ipairs(region.points) do
		list[#list + 1] = point[1] .. ">" .. tostring(point[3])
	end

	return table.concat(list, ",")
end

-- Settings ------------------------------------------------------------------------------------------------

local settings = Overlays:Resolve("player")

for _, kind in ipairs({ "absorb", "healAbsorb", "healPrediction" }) do
	local option = settings[kind]

	Equal(kind .. " shown by default", option.enabled, true)
	Equal(kind .. " attached by default", option.position, "attach")
	Equal(kind .. " matches height", option.matchHeight, true)
	Equal(kind .. " height", option.height, 4)
	Equal(kind .. " Solid texture", option.texture, "Solid")
	Equal(kind .. " shared color", option.color, Schema:Read(config, ALL .. "overlays.colors." .. kind))
end

Equal("overshield", settings.absorb.overshield, "always")
Equal("glow off", settings.absorb.glow, false)
Equal("no backing", settings.healAbsorb.backing, 0)
Equal("no overheal", settings.healPrediction.overheal, 0)

Schema:Write(config, ALL .. "overlays.textures.absorb", "other")
Equal("a frame's texture follows All Frames", Overlays:Resolve("player").absorb.texture, "other")
config = Schema:Defaults()

local colors = Schema:Read(config, ALL .. "overlays.colors.absorb")
Equal("absorb color has opacity", colors.a, 0.8)
Equal("heal prediction color", Schema:Read(config, ALL .. "overlays.colors.healPrediction").g, 1)
Equal("colors stay shared", Schema:Field("frames.player.overlays.colors.absorb"), nil)
Equal("height minimum", Schema:Field("frames.player.overlays.absorb.height").min, 1)
Equal("height maximum", Schema:Field("frames.player.overlays.absorb.height").max, 40)
Equal("an unknown position is refused", Schema:CheckValue("frames.player.overlays.absorb.position", "CENTER"), false)
Equal("an unknown overshield is refused", Schema:CheckValue("frames.player.overlays.absorb.overshield", "sometimes"),
	false)
Equal("overheal past 50 is refused", Schema:CheckValue("frames.player.overlays.healPrediction.overheal", 51), false)

-- Attach points -------------------------------------------------------------------------------------------

local function Attach(backward, reversed)
	local point, relative, reverseFill = Overlays:AttachPoints(backward, reversed)

	return point .. ">" .. relative .. (reverseFill and " reversed" or "")
end

Equal("forward, left to right", Attach(false, false), "LEFT>RIGHT")
Equal("forward, right to left", Attach(false, true), "RIGHT>LEFT reversed")
Equal("backward, left to right", Attach(true, false), "RIGHT>RIGHT reversed")
Equal("backward, right to left", Attach(true, true), "LEFT>LEFT")

-- Apply ---------------------------------------------------------------------------------------------------

local function Fresh()
	local bar = CreateFrame("StatusBar")

	bar:SetSize(200, 20)

	local widgets = Overlays:Create(bar)

	config = Schema:Defaults()

	return widgets, bar, Overlays:Resolve("player")
end

local widgets, bar
widgets, bar, settings = Fresh()
local fill = bar:GetStatusBarTexture()
local calculator = {}
function calculator:SetIncomingHealOverflowPercent(value)
	self.overflow = value
end
local health = { values = calculator }

Equal("clip covers the bar", widgets.clip.points[1][2], bar)
Equal("clip clips", widgets.clip.clipsChildren, true)
Equal("overshield clip clips", widgets.overshieldClip.clipsChildren, true)
Equal("heal prediction is not clipped, so Overheal can pass the bar", widgets.healing.parent, bar)
Equal("shields are clipped", widgets.absorb.parent, widgets.clip)
Equal("overshield inside its clip", widgets.overshield.parent, widgets.overshieldClip)

Overlays:Apply(widgets, settings, false, health)
Equal("absorb texture", widgets.absorb.texture, "Solid")
Equal("absorb color alpha", widgets.absorb.statusColor[4], 0.8)
Equal("heal prediction starts at the health edge", widgets.healing.points[1][2], fill)
Equal("shields start where heal prediction ends", widgets.absorb.points[1][2], widgets.healing:GetStatusBarTexture())
Equal("shield grows right", Points(widgets.absorb), "TOPLEFT>TOPRIGHT")
Equal("attached bars are as wide as health", widgets.absorb.width, 200)
Equal("matching health height", widgets.absorb.height, 20)
Equal("heal absorb grows back over health", Points(widgets.healAbsorb), "TOPRIGHT>TOPRIGHT")
Equal("no backing made at 0", widgets.backing, nil)
Equal("overshield shown", widgets.overshieldClip.shown, true)
Equal("overshield fills from the shield's edge", widgets.overshield.reverseFill, true)
Equal("overshield clip ends at the health edge", widgets.overshieldClip.points[2][2], fill)
Equal("no glow made by default", widgets.glow, nil)
Equal("overflow on the element", health.incomingHealOverflow, 1)
Equal("overflow on the calculator", calculator.overflow, 1)

settings.healPrediction.overheal = 20
settings.healAbsorb.backing = 40
settings.absorb.glow = true
settings.absorb.overshield = "fromLeft"
Overlays:Apply(widgets, settings, false, health)
Equal("overheal raises the overflow", calculator.overflow, 1.2)
local backing, glow = widgets.backing, widgets.glow
Equal("backing inside the clip", backing.parent, widgets.clip)
Equal("the glow is additive", glow:GetStatusBarTexture().blend, "ADD")
Equal("a glow's range is 0 to 1", glow.max, 1)
settings.healAbsorb.backing = 0
Overlays:Apply(widgets, settings, false, health)
Equal("backing hidden back at 0", backing.shown, false)
Equal("and kept", widgets.backing, backing)
settings.healAbsorb.backing = 40
Overlays:Apply(widgets, settings, false, health)
Equal("backing shown above 0", widgets.backing.shown, true)
Equal("backing opacity", widgets.backing.statusColor[4], 0.4)
Equal("glow on", widgets.glow.shown, true)
Equal("glow on the health edge", widgets.glow.points[1][2], fill)
Equal("glow centered on the edge", widgets.glow.points[1][1] .. ">" .. widgets.glow.points[1][3], "TOP>TOPRIGHT")
Equal("overshield from the left", widgets.overshield.reverseFill, false)

Overlays:Apply(widgets, settings, true, health)
Equal("reversed: overshield from the left of a right-to-left bar", widgets.overshield.reverseFill, true)
Equal("reversed: shield grows left", Points(widgets.absorb), "TOPRIGHT>TOPLEFT")
Equal("reversed: glow on the fill's left edge", widgets.glow.points[1][3], "TOPLEFT")

settings.healPrediction.enabled = false
Overlays:Apply(widgets, settings, false, health)
Equal("hidden heal prediction", widgets.healing.shown, false)
Equal("shields start at the health edge without heal prediction", widgets.absorb.points[1][2], fill)

settings.absorb.overshield = "never"
Overlays:Apply(widgets, settings, false, health)
Equal("overshield Never", widgets.overshieldClip.shown, false)

settings.absorb.overshield = "always"
settings.absorb.position = "BOTTOMRIGHT"
settings.absorb.matchHeight = false
settings.absorb.height = 6
Overlays:Apply(widgets, settings, false, health)
Equal("corner strip spans the bottom", Points(widgets.absorb), "BOTTOMLEFT>BOTTOMLEFT,BOTTOMRIGHT>BOTTOMRIGHT")
Equal("corner strip height", widgets.absorb.height, 6)
Equal("corner strip fills from its side", widgets.absorb.reverseFill, true)
Equal("no overshield while detached", widgets.overshieldClip.shown, false)
Equal("no glow while detached", widgets.glow.shown, false)

settings.absorb.position = "LEFT"
settings.absorb.matchHeight = true
Overlays:Apply(widgets, settings, false, health)
Equal("side strip matching height covers the bar", widgets.absorb.points[1][2], bar)
settings.absorb.matchHeight = false
Overlays:Apply(widgets, settings, false, health)
Equal("middle strip spans the bar", Points(widgets.absorb), "LEFT>LEFT,RIGHT>RIGHT")
settings.absorb.matchHeight = true
Equal("left strip fills right", widgets.absorb.reverseFill, false)

settings.absorb.position = "attach"
settings.absorb.matchHeight = false
settings.absorb.height = 5
Overlays:Apply(widgets, settings, false, nil)
Equal("attached strip at the top", Points(widgets.absorb), "TOPLEFT>TOPRIGHT")
Equal("attached strip height", widgets.absorb.height, 5)

-- Update --------------------------------------------------------------------------------------------------

widgets, bar, settings = Fresh()
local modes = {}
local live = {}
function live:SetDamageAbsorbClampMode(mode)
	modes[#modes + 1] = mode
end
function live:GetDamageAbsorbs()
	return "amount", modes[#modes] == Enum.UnitDamageAbsorbClampMode.MissingHealthWithoutIncomingHeals and "flag"
end
function live:SetIncomingHealOverflowPercent() end

Overlays:Update(widgets, live)
Equal("nothing before Apply", #modes, 0)

settings.absorb.glow = true
settings.healAbsorb.backing = 50
Overlays:Apply(widgets, settings, false, { values = live })
widgets.absorb:SetMinMaxValues(0, 588000)
widgets.absorb:SetValue(120000)
widgets.healAbsorb:SetMinMaxValues(0, 588000)
widgets.healAbsorb:SetValue(30000)
Overlays:Update(widgets, live)
Equal("overshield range", widgets.overshield.max, 588000)
Equal("overshield amount", widgets.overshield.value, 120000)
Equal("flag read in the missing-health mode", modes[1], Enum.UnitDamageAbsorbClampMode.MissingHealthWithoutIncomingHeals)
Equal("mode switched back", modes[2], Enum.UnitDamageAbsorbClampMode.MaximumHealth)
Equal("overshield alpha from the flag", widgets.overshieldClip.alphaBoolean[1], "flag")
Equal("glow full while any shield exists", widgets.glow.value, 120000)
Equal("glow range stays 0 to 1", widgets.glow.max, 1)
Equal("backing follows heal absorbs", widgets.backing.value, 30000)

-- Sample amounts ------------------------------------------------------------------------------------------

local healing, healAbsorb, absorb, absorbExceeds = Overlays:SampleAmounts({
	health = 0.6, absorb = 0.25, healAbsorb = 0, healing = 0.15,
}, 0)
Near("absorbs: healing", healing, 0.15)
Equal("absorbs: no heal absorb", healAbsorb, 0)
Near("absorbs: shield", absorb, 0.25)
Equal("absorbs: shield fits", absorbExceeds, false)

healing, healAbsorb, absorb, absorbExceeds = Overlays:SampleAmounts({
	health = 0.3, absorb = 0.9, healAbsorb = 0.5, healing = 0,
}, 0)
Equal("overflow: no healing", healing, 0)
Near("overflow: heal absorb", healAbsorb, 0.5)
Near("overflow: shield", absorb, 0.9)
Equal("overflow: shield exceeds the empty space", absorbExceeds, true)

healing, healAbsorb = Overlays:SampleAmounts({ health = 0.5, absorb = 0, healAbsorb = 0.2, healing = 0.3 }, 0)
Near("heal absorbs cancel incoming heals", healing, 0.1)
Equal("and are used up by them", healAbsorb, 0)

healing = Overlays:SampleAmounts({ health = 0.9, absorb = 0, healAbsorb = 0, healing = 0.3 }, 10)
Near("heals stop at the empty space plus Overheal", healing, 0.2)

_, _, absorb = Overlays:SampleAmounts({ health = 0, absorb = 1.5, healAbsorb = 0, healing = 0 }, 0)
Equal("shields stop at maximum health", absorb, 1)

widgets, bar, settings = Fresh()
Overlays:ShowSample(widgets, { health = 0.3, absorb = 0.9, healAbsorb = 0.5, healing = 0 }, 0)
Equal("a sample without backing shows", widgets.absorb.value, 0.9)
settings.healAbsorb.backing = 50
Overlays:Apply(widgets, settings, false, nil)
Overlays:ShowSample(widgets, { health = 0.3, absorb = 0.9, healAbsorb = 0.5, healing = 0 }, 0)
Equal("sample overshield shown", widgets.overshieldClip.alpha, 1)
Near("sample backing follows heal absorbs", widgets.backing.value, 0.5)

io.stdout:write(("check_overlays: %d checks passed\n"):format(client.checks))
