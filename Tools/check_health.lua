-- Checks Frames/HealthColor.lua outside the game: health color settings and their defaults, the color points of each
-- mode and their interpolation, base color precedence, the sample colors the previews draw, and the live color
-- override painting a stand-in bar, a restricted color and a dead unit included.
-- Run from any directory with Lua 5.1: lua Tools/check_health.lua
-- Curves are stand-ins that record their points; the client's curve evaluation is not exercised here.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

Enum = { LuaCurveType = { Linear = 0, Step = 1 } }
UNKNOWN = "Unknown"
SlashCmdList = {}
C_AddOns = {
	GetAddOnMetadata = function() end,
}

-- Values the stand-in client treats as secret.
local secrets = {}

function issecretvalue(value)
	return secrets[value] == true
end

function CreateColor(r, g, b, a)
	return { r = r, g = g, b = b, a = a }
end

C_CurveUtil = {
	CreateColorCurve = function()
		local curve = { points = {} }

		function curve:SetType(kind)
			self.kind = kind
		end

		function curve:AddPoint(position, color)
			self.points[#self.points + 1] = { position, color }
		end

		return curve
	end,
}

C_ClassColor = {
	GetClassColor = function(class)
		return { r = class, g = class, b = class, fromClient = true }
	end,
}

-- The unit the stand-in client describes.
local unitState = {}

function UnitIsConnected()
	return unitState.connected ~= false
end

function UnitPlayerControlled()
	return unitState.controlled == true
end

function UnitIsTapDenied()
	return unitState.tapDenied == true
end

function UnitReaction()
	return unitState.reaction
end

function UnitIsPlayer()
	return unitState.player == true
end

function UnitInPartyIsAI()
	return false
end

function UnitClass()
	return "Class", unitState.class
end

function UnitIsDeadOrGhost()
	return unitState.dead == true
end

local AUI = {}
assert(loadfile(root .. "Core/Core.lua"))("AeonUI", AUI)
AUI.oUF = {
	colors = {
		health = { r = 0.2, g = 0.8, b = 0.1 },
		class = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } },
		reaction = {},
	},
}
for level = 1, 8 do
	AUI.oUF.colors.reaction[level] = { r = level / 10, g = 0, b = 0 }
end
assert(loadfile(root .. "Profile/Schema.lua"))("AeonUI", AUI)
assert(loadfile(root .. "Frames/HealthColor.lua"))("AeonUI", AUI)

local Schema, HealthColor = AUI.Schema, AUI.HealthColor

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		error(("FAIL: %s: expected %s, got %s"):format(name, tostring(expected), tostring(actual)), 2)
	end
end

local function Near(name, actual, expected)
	checks = checks + 1
	if math.abs(actual - expected) > 0.001 then
		error(("FAIL: %s: expected %s, got %s"):format(name, tostring(expected), tostring(actual)), 2)
	end
end

local function Settings(changes)
	local config = Schema:Defaults()

	for path, value in pairs(changes or {}) do
		Schema:Write(config, path, value)
	end

	return HealthColor:Resolve(config, "target"), config
end

local function State(fields)
	local state = { connected = true, tapDenied = false }

	for key, value in pairs(fields or {}) do
		state[key] = value
	end

	return state
end

-- Settings ------------------------------------------------------------------------------------------------

local settings = Settings()
Equal("mode defaults to class and reaction", settings.mode, "classReaction")
Equal("fill opacity defaults to full", settings.fillAlpha, 100)
Equal("gradient off", settings.gradient, false)
Equal("dark mode off", settings.dark, false)
Equal("background follows the bar background", settings.background, "custom")
Equal("half stop", settings.stops.half.r, 0.925)
Equal("tapped on", settings.tapped, true)
Equal("reaction colors unset", settings.reaction.hostile, nil)
Equal("bar background read", settings.barBackground.r, 0.067)
Equal("no health colors on the power bar", HealthColor:Resolve(Schema:Defaults(), "playerPower"), nil)
Equal("a frame follows the shared mode", (Settings({ ["health.mode"] = "classic" })).mode, "classic")
Equal("a frame's own mode wins", (Settings({ ["health.mode"] = "classic", ["frames.target.health.mode"] = "custom" })).mode,
	"custom")
Equal("a frame field inherits", Schema:Field("frames.boss.health.dark").shared, "health.dark")
Equal("state colors stay on Globals", Schema:Field("frames.target.health.tapped"), nil)

-- Points --------------------------------------------------------------------------------------------------

Equal("class and reaction does not follow health", HealthColor:Points(settings), nil)
Equal("custom does not follow health", HealthColor:Points(Settings({ ["health.mode"] = "custom" })), nil)
local classic = HealthColor:Points(Settings({ ["health.mode"] = "classic" }))
Equal("classic has three points", #classic, 3)
Equal("classic starts red", classic[1][2].r, 1)
local stops = HealthColor:Points(Settings({ ["health.mode"] = "stops" }))
Equal("stops end at full", stops[3][2].g, 1)
Near("stops start at empty", stops[1][2].r, 0.89)
local fadeSettings = Settings({ ["health.mode"] = "classFade" })
Equal("class fade needs a full color", HealthColor:Points(fadeSettings), nil)
local fade = HealthColor:Points(fadeSettings, { r = 1, g = 0, b = 0 })
Equal("class fade has four points", #fade, 4)
Equal("class fade is the half color at 40%", fade[2][1], 0.4)
Near("class fade is three quarters back at 75%", fade[3][2].r, 0.925 + (1 - 0.925) * 0.75)
Equal("class fade ends at the full color", fade[4][2].r, 1)

-- Evaluate ------------------------------------------------------------------------------------------------

Equal("evaluate at empty", HealthColor:Evaluate(classic, 0).g, 0)
Equal("evaluate at half", HealthColor:Evaluate(classic, 0.5).g, 1)
Near("evaluate between points", HealthColor:Evaluate(classic, 0.25).g, 0.5)
Equal("evaluate clamps above", HealthColor:Evaluate(classic, 2).r, 0)
Equal("evaluate clamps below", HealthColor:Evaluate(classic, -1).g, 0)

-- Base ----------------------------------------------------------------------------------------------------

local class = { r = 0.3, g = 0.3, b = 0.3 }
Equal("disconnected first", HealthColor:Base(settings, State({ connected = false, classColor = class })),
	settings.disconnectedColor)
Equal("tapped next", HealthColor:Base(settings, State({ tapDenied = true, reaction = 2 })), settings.tappedColor)
Equal("then class", HealthColor:Base(settings, State({ classColor = class, reaction = 2 })), class)
Equal("then Blizzard's reaction", HealthColor:Base(settings, State({ reaction = 4 })), AUI.oUF.colors.reaction[4])
Equal("then the health default", HealthColor:Base(settings, State()), AUI.oUF.colors.health)
local tappedOff = Settings({ ["health.tapped"] = false })
Equal("tapped off falls through", HealthColor:Base(tappedOff, State({ tapDenied = true, reaction = 4 })),
	AUI.oUF.colors.reaction[4])
local hostile = { r = 1, g = 0.5, b = 0 }
local custom = Settings({ ["health.reaction.hostile"] = hostile })
Equal("a set hostile color covers level 1", HealthColor:Base(custom, State({ reaction = 1 })).r, 1)
Equal("and level 3", HealthColor:Base(custom, State({ reaction = 3 })).g, 0.5)
Equal("an unset neutral color stays Blizzard's", HealthColor:Base(custom, State({ reaction = 4 })),
	AUI.oUF.colors.reaction[4])

-- Samples -------------------------------------------------------------------------------------------------

local fill, backdrop = HealthColor:Sample(settings, State({ classColor = class }), 0.5)
Equal("sample: class color", fill, class)
Equal("sample: bar background", backdrop.r, 0.067)
fill = HealthColor:Sample(Settings({ ["health.mode"] = "custom" }), State({ classColor = class }), 0.5)
Equal("sample: custom", fill.g, 0.812)
fill = HealthColor:Sample(Settings({ ["health.mode"] = "classic" }), State(), 0.5)
Equal("sample: classic at half is yellow", fill.r .. "," .. fill.g .. "," .. fill.b, "1,1,0")
fill = HealthColor:Sample(Settings({ ["health.mode"] = "classFade" }), State({ classColor = class }), 1)
Equal("sample: class fade at full is the class color", fill.r, 0.3)
fill, backdrop = HealthColor:Sample(Settings({ ["health.dark"] = true, ["health.mode"] = "classic" }), State(), 0.5)
Equal("sample: dark fill wins", fill.r, 0.067)
Equal("sample: dark background", backdrop.r, 0.31)
_, backdrop = HealthColor:Sample(Settings({ ["health.deadBackground"] = true, ["health.dark"] = true }), State(), 0, true)
Equal("sample: dead background wins", backdrop.r, 0.35)
_, backdrop = HealthColor:Sample(Settings({ ["health.background"] = "classReaction",
	["bars.background"] = { r = 0, g = 0, b = 0, a = 0.4 } }), State({ classColor = class }), 1)
Equal("sample: class background", backdrop.r, 0.3)
Equal("sample: at the bar background's opacity", backdrop.a, 0.4)
Equal("alpha follows fill opacity", HealthColor:Alpha(Settings({ ["health.fillAlpha"] = 40 })), 0.4)
Equal("alpha follows the dark fill", HealthColor:Alpha(Settings({ ["health.dark"] = true })), 0.9)

-- Live color ----------------------------------------------------------------------------------------------

---A health bar stand-in: records the color, gradient and alpha it is given.
local function Bar()
	local texture = {}

	function texture:SetGradient(direction, from, to)
		self.gradient = { direction, from, to }
	end

	function texture:SetAlpha(alpha)
		self.alpha = alpha
	end

	local bar = { texture = texture, values = {} }

	function bar:GetStatusBarTexture()
		return self.texture
	end

	function bar:SetStatusBarColor(r, g, b)
		self.color = { r, g, b }
		self.texture.gradient = nil
	end

	function bar.values:EvaluateCurrentHealthPercent(curve)
		bar.evaluated = curve

		return { r = 0.5, g = 0.5, b = 0.5 }
	end

	return bar
end

local function Frame(changes)
	local background = {}

	function background:SetVertexColor(r, g, b, a)
		self.color = { r, g, b, a }
	end

	local frame = { __unit = "target", Health = Bar(), Background = background }

	HealthColor:Apply(frame, (Settings(changes)))

	return frame
end

unitState = { reaction = 2 }
local frame = Frame()
HealthColor.UpdateColor(frame, "UNIT_HEALTH", "target")
Equal("live: reaction color", frame.Health.color[1], 0.2)
Equal("live: full opacity", frame.Health.texture.alpha, 1)
Equal("live: background tinted", frame.Background.color[1], 0.067)
HealthColor.UpdateColor(frame, "UNIT_HEALTH", "focus")
Equal("live: another unit is ignored", frame.Health.color[1], 0.2)

frame = Frame({ ["health.mode"] = "classic" })
Equal("live: the classic curve is built", #frame.healthCurve.points, 3)
Equal("live: linear", frame.healthCurve.kind, 0)
HealthColor.UpdateColor(frame, "UNIT_HEALTH", "target")
Equal("live: the client evaluates the curve", frame.Health.evaluated, frame.healthCurve)
Equal("live: the curve color is painted", frame.Health.color[1], 0.5)

frame = Frame({ ["health.mode"] = "classFade" })
unitState = { player = true, class = "MAGE" }
HealthColor.UpdateColor(frame, "UNIT_HEALTH", "target")
Equal("live: class fade builds a curve for the class", #frame.Health.evaluated.points, 4)
local cached = frame.Health.evaluated
HealthColor.UpdateColor(frame, "UNIT_HEALTH", "target")
Equal("live: the class curve is reused", frame.Health.evaluated, cached)

local secretClass = "SECRET"
secrets[secretClass] = true
unitState = { player = true, class = secretClass }
frame.Health.evaluated = nil
HealthColor.UpdateColor(frame, "UNIT_HEALTH", "target")
Equal("live: a restricted class takes the client's class color", frame.Health.color[1], secretClass)
Equal("live: class fade declines a restricted color", frame.Health.evaluated, nil)

frame = Frame({ ["health.gradient"] = true })
unitState = { reaction = 5 }
HealthColor.UpdateColor(frame, "UNIT_HEALTH", "target")
Equal("live: gradient from the fill", frame.Health.texture.gradient[2].r, 0.5)
Equal("live: gradient to the end color", frame.Health.texture.gradient[3].r, 0.1)
unitState = { player = true, class = secretClass }
HealthColor.UpdateColor(frame, "UNIT_HEALTH", "target")
Equal("live: a restricted fill stays solid", frame.Health.texture.gradient, nil)

frame = Frame({ ["health.deadBackground"] = true })
unitState = { reaction = 2, dead = true }
HealthColor.UpdateColor(frame, "UNIT_HEALTH", "target")
Equal("live: dead background", frame.Background.color[1], 0.35)

frame = Frame()
frame.healthColors = nil
HealthColor.UpdateColor(frame, "UNIT_HEALTH", "target")
Equal("live: nothing painted before settings", frame.Health.color, nil)

print(("check_health: %d checks passed"):format(checks))
