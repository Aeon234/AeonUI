-- Checks Frames/Indicators.lua and Frames/Fading.lua outside the game: indicator settings and their defaults, the
-- widgets each frame gets, placement and switching elements on and off, the classification icon, the threat border,
-- totems, the mouseover border, and frame opacity from the idle fade, the range fade and Hide Out of Combat.
-- Run from any directory with Lua 5.1: lua Tools/check_indicators.lua
-- oUF's elements are not loaded; the checks call what AeonUI hands them as oUF would.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

UNKNOWN = "Unknown"
SlashCmdList = {}
C_AddOns = {
	GetAddOnMetadata = function() end,
}
MAX_TOTEMS = 4

local secret = {}

function issecretvalue(value)
	return value == secret
end

local world = {
	classification = "normal",
	grouped = true,
	instance = "party",
	inCombat = false,
	target = false,
	focus = false,
	casting = nil,
	canAttack = true,
	inRange = true,
	known = {},
}

function UnitClassification()
	return world.classification
end

function IsInGroup()
	return world.grouped
end

function IsInInstance()
	return world.instance ~= "none", world.instance
end

function InCombatLockdown()
	return world.inCombat
end

function UnitExists(unit)
	return world[unit] == true
end

function UnitCastingInfo()
	return world.casting
end

function UnitChannelInfo() end

function UnitCanAttack()
	return world.canAttack
end

function UnitClass()
	return "Mage", "MAGE"
end

C_SpellBook = {
	IsSpellKnownOrInSpellBook = function(spellID)
		return world.known[spellID] == true
	end,
}

local rangeAsked
C_Spell = {
	IsSpellInRange = function(spell)
		rangeAsked = spell

		return world.inRange
	end,
}

local tickers = 0
C_Timer = {
	NewTicker = function(_, callback)
		tickers = tickers + 1

		return {
			callback = callback,
			Cancel = function(self)
				self.cancelled = true
				tickers = tickers - 1
			end,
		}
	end,
}

---A frame, texture or font string stand-in recording the last call of each method.
local function Region()
	local region = { last = {}, shown = true, alpha = 1, level = 1, scripts = {}, enabled = {}, events = {} }

	function region:Show()
		self.shown = true
	end

	function region:Hide()
		self.shown = false
	end

	function region:SetShown(shown)
		self.shown = shown == true
	end

	function region:SetAlpha(alpha)
		self.alpha = alpha
	end

	function region:SetAlphaFromBoolean(flag, shown, hidden)
		self.last.SetAlphaFromBoolean = { flag, shown, hidden }
	end

	function region:GetFrameLevel()
		return self.level
	end

	function region:CreateTexture()
		return Region()
	end

	function region:CreateFontString()
		return Region()
	end

	function region:SetText(text)
		self.text = text
	end

	function region:SetPoint(...)
		self.points = rawget(self, "points") or {}
		self.points[#self.points + 1] = { ... }
	end

	function region:ClearAllPoints()
		self.points = {}
	end

	function region:HookScript(script, handler)
		self.scripts[script] = handler
	end

	function region:EnableElement(name)
		self.enabled[name] = true
	end

	function region:DisableElement(name)
		self.enabled[name] = false
	end

	function region:RegisterEvent(event, handler)
		self.events[event] = handler
	end

	function region:UnregisterEvent(event)
		self.events[event] = nil
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

function CreateFrame()
	return Region()
end

local AUI = {}
assert(loadfile(root .. "Core/Core.lua"))("AeonUI", AUI)
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
AUI.Media = {
	Font = function(_, name)
		return name
	end,
	FontFlags = function(_, outline)
		return outline
	end,
}

function AUI:Pixel()
	return 1
end

local elements = {}
AUI.oUF = {
	AddElement = function(_, name, update, enable, disable)
		elements[name] = { update = update, enable = enable, disable = disable }
	end,
}

local registered = {}
AUI.Events = {
	Register = function(_, event, owner, handler)
		registered[event] = function(...)
			handler(owner, event, ...)
		end
	end,
}
AUI.Callbacks = {
	Register = function(_, channel, owner, handler)
		registered[channel] = function(...)
			handler(owner, ...)
		end
	end,
}

assert(loadfile(root .. "Profile/Schema.lua"))("AeonUI", AUI)
assert(loadfile(root .. "Frames/Text.lua"))("AeonUI", AUI)
assert(loadfile(root .. "Frames/CastData.lua"))("AeonUI", AUI)
assert(loadfile(root .. "Frames/Indicators.lua"))("AeonUI", AUI)
assert(loadfile(root .. "Frames/Fading.lua"))("AeonUI", AUI)

local Indicators, Fading, Schema = AUI.Indicators, AUI.Fading, AUI.Schema
AUI.Profile = { config = Schema:Defaults() }
local config = AUI.Profile.config
AUI.Frames = { objects = {} }

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

-- Settings ------------------------------------------------------------------------------------------------

local function Indicator(key, name)
	return Indicators:Resolve(config, key, name)
end

Equal("player raid marker on", Indicator("player", "raid").enabled, true)
Equal("raid marker size", Indicator("player", "raid").size, 18)
Equal("raid marker centered", Indicator("player", "raid").anchor .. " " .. Indicator("player", "raid").placement,
	"CENTER inside")
Equal("resting on", Indicator("player", "resting").enabled, true)
Equal("resting size", Indicator("player", "resting").size, 9)
Equal("resting offset", Indicator("player", "resting").x .. "," .. Indicator("player", "resting").y, "3,-2")
Equal("combat off", Indicator("player", "combat").enabled, false)
Equal("combat size", Indicator("player", "combat").size, 16)
Equal("leader on", Indicator("player", "leader").enabled, true)
Equal("pvp off", Indicator("player", "pvp").enabled, false)
Equal("pvp size", Indicator("player", "pvp").size, 24)
Equal("no classification on the player", Indicator("player", "classification"), nil)
Equal("target classification off", Indicator("target", "classification").enabled, false)
Equal("classification size", Indicator("target", "classification").size, 20)
Equal("focus marker outside right", Indicator("focus", "raid").anchor .. " " .. Indicator("focus", "raid").placement,
	"RIGHT outside")
Equal("focus marker size", Indicator("focus", "raid").size, 14)
Equal("focus marker clearance", Indicator("focus", "raid").x, 2)
Equal("target of target marker", Indicator("targettarget", "raid").size, 14)
Equal("pet marker", Indicator("pet", "raid").placement, "outside")
Equal("boss marker centered", Indicator("boss", "raid").anchor, "CENTER")
Equal("no leader on focus", Indicator("focus", "leader"), nil)
Equal("threat on", Schema:Read(config, "frames.player.indicators.threat.enabled"), true)
Equal("threat size", Schema:Read(config, "frames.player.indicators.threat.size"), 2)
Equal("totems on", Schema:Read(config, "frames.player.totems.enabled"), true)
Equal("totem size", Schema:Read(config, "frames.player.totems.size"), 22)
Equal("target highlight", Schema:Read(config, "frames.target.highlight"), true)
Equal("no highlight on the player", Schema:Field("frames.player.highlight"), nil)

Equal("no threat", Indicators:ThreatColor(0), nil)
Equal("near aggro gold", Indicators:ThreatColor(1).g, 0.82)
Equal("aggro orange", Indicators:ThreatColor(3).g, 0.5)
Equal("first totem at the edge", Indicators:TotemOffset(22, 2, 1), 0)
Equal("totems grow left", Indicators:TotemOffset(22, 2, 3), -48)

-- Widgets -------------------------------------------------------------------------------------------------

Indicators:Register()
Equal("classification element", elements.AeonClassification ~= nil, true)

local player = Region()
player.key = "player"
player.Main = Region()
player.Border = { Region(), Region(), Region(), Region() }
Indicators:Create(player)
Equal("raid marker", rawget(player, "RaidTargetIndicator") ~= nil, true)
Equal("resting is text", player.RestingIndicator.text, "ZZZ")
Equal("assistant beside leader", rawget(player, "AssistantIndicator") ~= nil, true)
Equal("no classification", rawget(player, "AeonClassification"), nil)
Equal("threat border", rawget(player, "ThreatIndicator") ~= nil, true)
Equal("four totems", #player.Totems, 4)
Equal("no highlight hook on the player", player.scripts.OnEnter, nil)

Indicators:Apply(player, config)
Equal("raid marker on", player.enabled.RaidTargetIndicator, true)
Equal("combat off", player.enabled.CombatIndicator, false)
Equal("combat hidden", player.CombatIndicator.shown, false)
Equal("raid marker centered on the bar", player.RaidTargetIndicator.points[1][1], "CENTER")
Equal("on the main bar", player.RaidTargetIndicator.points[1][2], player.Main)
Equal("resting font size", player.RestingIndicator.last.SetFont[2], 9)
Equal("leader straddles the top", player.LeaderIndicator.points[1][1] .. ">" .. player.LeaderIndicator.points[1][3],
	"LEFT>TOPLEFT")
Equal("assistant follows leader", player.enabled.AssistantIndicator, true)
Equal("pvp above the corner", player.PvPIndicator.points[1][1] .. ">" .. player.PvPIndicator.points[1][3],
	"BOTTOMRIGHT>TOPRIGHT")
Equal("threat on", player.enabled.ThreatIndicator, true)
Equal("totems on", player.enabled.Totems, true)
Equal("second totem left of the first", player.Totems[2].points[1][4], -24)
Equal("totems under the frame", player.Totems[1].points[1][5], -4)

config.frames.player.indicators.leader.enabled = false
config.frames.player.totems.enabled = false
Indicators:Apply(player, config)
Equal("assistant off with leader", player.enabled.AssistantIndicator, false)
Equal("totems off", player.enabled.Totems, false)
Equal("totems hidden", player.Totems[1].shown, false)
config.frames.player.indicators.leader.enabled = true
config.frames.player.totems.enabled = true

-- Threat.
local threat = player.ThreatIndicator
threat:Show()
threat:PostUpdate("player", 3)
Equal("aggro border", threat.Edges[1].last.SetVertexColor[2], 0.5)
Equal("shown in a group instance", threat.shown, true)
world.instance = "none"
threat:PostUpdate("player", 3)
Equal("hidden in the open world", threat.shown, false)
world.instance = "party"
threat:Show()
threat:PostUpdate("player", secret)
Equal("hidden for a hidden status", threat.shown, false)

-- Target: classification and highlight.
local target = Region()
target.key = "target"
target.Main = Region()
target.__unit = "target"
target.Border = { Region(), Region(), Region(), Region() }
Indicators:Create(target)
Equal("classification icon", rawget(target, "AeonClassification") ~= nil, true)
Equal("no totems off the player", rawget(target, "Totems"), nil)
Equal("no resting off the player", rawget(target, "RestingIndicator"), nil)

local classification = elements.AeonClassification
Equal("enables with the icon", classification.enable(target), true)
world.classification = "rareelite"
classification.update(target, "UNIT_CLASSIFICATION_CHANGED", "target")
Equal("rare elite icon", target.AeonClassification.last.SetTexture[1]:find("RareElite") ~= nil, true)
world.classification = "worldboss"
classification.update(target, "ForceUpdate")
Equal("world boss shows elite", target.AeonClassification.last.SetTexture[1]:find("Elite.png") ~= nil, true)
world.classification = "normal"
classification.update(target, "ForceUpdate")
Equal("normal hides", target.AeonClassification.shown, false)
world.classification = secret
target.AeonClassification:Show()
classification.update(target, "ForceUpdate")
Equal("hidden classification hides", target.AeonClassification.shown, false)

target.scripts.OnEnter()
Equal("white border on hover", target.Border[1].last.SetColorTexture[1], 1)
target.scripts.OnLeave()
Equal("black border after", target.Border[1].last.SetColorTexture[1], 0)
config.frames.target.highlight = false
target.scripts.OnEnter()
Equal("no highlight when off", target.Border[1].last.SetColorTexture[1], 0)
config.frames.target.highlight = true

-- Fading --------------------------------------------------------------------------------------------------

Equal("idle fade on the player", Fading:Alpha(config, "player", "idle"), 0.5)
Equal("no range fade on the player", Fading:Alpha(config, "player", "range"), nil)
Equal("range fade on target", Fading:Alpha(config, "target", "range"), 0.5)
Equal("no idle fade on target", Fading:Alpha(config, "target", "idle"), nil)
Equal("focus has both", Fading:Alpha(config, "focus", "range") and Fading:Alpha(config, "focus", "idle"), 0.5)
Equal("bosses never fade", Fading:Alpha(config, "boss", "idle"), nil)
config.frames.player.fade.idle.enabled = false
Equal("idle fade off", Fading:Alpha(config, "player", "idle"), nil)
config.frames.player.fade.idle.enabled = true

Equal("idle", Fading:IsIdle(false, false, false), true)
Equal("in combat", Fading:IsIdle(true, false, false), false)
Equal("with a target", Fading:IsIdle(false, true, false), false)
Equal("casting", Fading:IsIdle(false, false, true), false)

local frames = {}
for _, key in ipairs({ "player", "pet", "playerPower", "classPower", "target", "focus" }) do
	local frame = Region()
	frame.key = key
	frames[key] = frame
	AUI.Frames.objects[key] = { frame }
end

world.known[116] = true
Fading:Start()
Equal("started", Fading.started, true)
Equal("harmful range spell", Fading.harmful, 116)
Equal("no healing spell for a mage", Fading.helpful, nil)
Equal("idle player faded", frames.player.alpha, 0.5)
Equal("idle power bar faded", frames.playerPower.alpha, 0.5)
Equal("no ticker without a target", tickers, 0)

world.casting = secret
registered.UNIT_SPELLCAST_START("player")
Equal("casting ends idleness, even with a hidden cast", frames.player.alpha, 1)
world.casting = nil
registered.UNIT_SPELLCAST_STOP("player")
Equal("idle again", frames.player.alpha, 0.5)
registered.UNIT_SPELLCAST_START("target")
Equal("other units' casts ignored", frames.player.alpha, 0.5)

world.inCombat = true
registered.PLAYER_REGEN_DISABLED()
Equal("full in combat", frames.player.alpha, 1)
Equal("class resource full in combat", frames.classPower.alpha, 1)
world.inCombat = false
registered.PLAYER_REGEN_ENABLED()

config.frames.classPower.hideOutOfCombat = true
registered.Profile()
Equal("class resource hidden out of combat", frames.classPower.alpha, 0)
config.frames.classPower.hideOutOfCombat = false

world.target = true
registered.PLAYER_TARGET_CHANGED()
Equal("a target ends idleness", frames.player.alpha, 1)
Equal("ticker while a target exists", tickers, 1)
Equal("range from the harmful spell", rangeAsked, 116)
Equal("range applied as a flag", frames.target.last.SetAlphaFromBoolean[1], true)
Equal("in range at full", frames.target.last.SetAlphaFromBoolean[2], 1)
Equal("out of range faded", frames.target.last.SetAlphaFromBoolean[3], 0.5)

world.inRange = secret
Fading.ticker.callback()
Equal("hidden range passed on", frames.target.last.SetAlphaFromBoolean[1], secret)
world.inRange = nil
frames.target:SetAlpha(0.3)
Fading.ticker.callback()
Equal("unknown range never fades", frames.target.alpha, 1)
world.inRange = true

world.canAttack = false
Fading:Update(frames.target)
Equal("no heal, no range", frames.target.alpha, 1)
world.canAttack = secret
Fading:Update(frames.target)
Equal("hidden attackability, no range", frames.target.alpha, 1)
world.canAttack = true

world.focus = true
world.target = false
registered.PLAYER_TARGET_CHANGED()
Equal("ticker kept for the focus", tickers, 1)
Fading:Update(frames.focus)
Equal("idle focus fades the stronger way", frames.focus.last.SetAlphaFromBoolean[3], 0.5)
Equal("idle focus in range at the idle fade", frames.focus.last.SetAlphaFromBoolean[2], 0.5)

world.focus = false
registered.PLAYER_FOCUS_CHANGED()
Equal("ticker stopped", tickers, 0)

print(("check_indicators: %d checks passed"):format(checks))
