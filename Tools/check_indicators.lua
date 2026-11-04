-- Checks AeonUI_UnitFrames/Frames/Portrait.lua, Indicators.lua and Fading.lua outside the game: their settings and
-- defaults, an attached or detached portrait's room and place, the class icon rule with a secret class, the elements
-- each setting runs, the threat colors, totem offsets, the idle rule, and events followed only while the fade is on.
-- Run from any directory with Lua 5.1: lua Tools/check_indicators.lua
-- Frames are the shared client's widgets with oUF's frame methods added; oUF's elements and drawing are not exercised here.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"
local client = assert(loadfile(root .. "Tools/stub_client.lua"))({ project = "retail" })
local Equal = client.Equal

-- Environment ---------------------------------------------------------------------------------------------

UNKNOWN = "Unknown"
SlashCmdList = {}
C_AddOns = {
	GetAddOnMetadata = function() end,
}

local unit = { player = true, class = "MAGE" }
local hasTarget, casting = false, nil
local grouped, instance = false, "none"

function UnitIsPlayer()
	return unit.player
end

function UnitClass()
	return "Class", unit.class
end

function UnitExists()
	return hasTarget
end

function UnitCastingInfo()
	return casting
end

function UnitChannelInfo()
	return nil
end

function IsInGroup()
	return grouped
end

function IsInInstance()
	return instance ~= "none", instance
end

Enum = { LuaCurveType = { Step = 1 } }

local missingAtlas = false

C_Texture = {
	GetAtlasInfo = function()
		if missingAtlas then
			return nil
		end

		return { file = "file", leftTexCoord = 0, rightTexCoord = 1, topTexCoord = 0, bottomTexCoord = 1 }
	end,
}

local curves = 0

C_CurveUtil = {
	CreateCurve = function()
		curves = curves + 1

		return {
			points = {},
			SetType = function(self, kind)
				self.kind = kind
			end,
			ClearPoints = function(self)
				self.points = {}
			end,
			AddPoint = function(self, x, y)
				self.points[#self.points + 1] = { x, y }
			end,
		}
	end,
}

-- The client's step curve at the stand-in's health: the last point at or below it.
local healthShare = 1

function UnitHealthPercent(_, _, curve)
	local value = 1

	for _, point in ipairs(curve.points) do
		if point[1] <= healthShare then
			value = point[2]
		end
	end

	return value
end

function SetPortraitTexture(texture, portraitUnit)
	texture.portraitUnit = portraitUnit
end

local created = {}
local MakeFrame = CreateFrame

function CreateFrame(kind, ...)
	created[kind] = (created[kind] or 0) + 1

	return MakeFrame(kind, ...)
end

local AUI = {}

assert(loadfile(root .. "AeonUI/Core/Core.lua"))("AeonUI", AUI)
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
AUI.can = {}
AUI.Pixel = function()
	return 0.5
end
AUI.Media = {
	Font = function(_, name)
		return name
	end,
	FontFlags = function(_, outline)
		return outline
	end,
}

local dividers, styled = 2, true

AUI.Border = {
	ART_COLOR = { r = 0.5, g = 0.4, b = 0.3 },
	CellDividerWidth = function()
		return dividers
	end,
	StyleCellDivider = function()
		return styled
	end,
	Create = function(_, owner, overContent)
		return {
			owner = owner,
			overContent = overContent,
			SetFrameLevel = function(self, level)
				self.level = level
			end,
			Apply = function(self, look)
				self.look = look
			end,
		}
	end,
}

local look = {
	background = { r = 0.1, g = 0.1, b = 0.1, a = 1 },
	borderStyle = "THIN_LINE",
	borderColor = { r = 0, g = 0, b = 0, a = 1 },
	borderThickness = 100,
}

AUI.UnitFrame = {
	FrameHeight = function(_, key)
		return AUI.Profile:Get(AUI.UnitFrameOptions:Path(key, "height"))
	end,
	BarLook = function()
		return look
	end,
}

local handlers, unregistered = {}, 0

AUI.Events = {
	Register = function(_, event, _, handler)
		handlers[event] = handler
	end,
	UnregisterAll = function()
		handlers = {}
		unregistered = unregistered + 1
	end,
}
AUI.Callbacks = {
	Register = function(self, channel, _, handler)
		self[channel] = handler
	end,
}
AUI.Frames = { objects = {} }

local settingsLibrary = {}
local springs = assert(loadfile(root .. "Tools/springs.lua"))(settingsLibrary)

function LibStub()
	return settingsLibrary
end

assert(loadfile(root .. "AeonUI/Profile/Schema.lua"))("AeonUI", AUI)
assert(loadfile(root .. "AeonUI_UnitFrames/Frames/Options.lua"))("AeonUI", AUI)
assert(loadfile(root .. "AeonUI_UnitFrames/Frames/Text.lua"))("AeonUI", AUI)
assert(loadfile(root .. "AeonUI_UnitFrames/Frames/Portrait.lua"))("AeonUI", AUI)
assert(loadfile(root .. "AeonUI_UnitFrames/Frames/Indicators.lua"))("AeonUI", AUI)
assert(loadfile(root .. "AeonUI_UnitFrames/Frames/Fading.lua"))("AeonUI", AUI)

local Schema, Options, Portrait, Indicators, Fading = AUI.Schema, AUI.UnitFrameOptions, AUI.Portrait, AUI.Indicators,
	AUI.Fading
local config = Schema:Defaults()

AUI.Profile = {
	Get = function(_, path)
		return Schema:Read(config, path)
	end,
}

local function Set(field, value)
	Schema:Write(config, Options:Path("player", field), value)
end

-- Defaults ------------------------------------------------------------------------------------------------

local settings = Portrait:Resolve("player")
Equal("portrait off", settings.enabled, false)
Equal("2D", settings.mode, "2d")
Equal("attached", settings.style, "attached")
Equal("on the player's left", settings.side, "LEFT")
Equal("no portrait is no room", select(2, Portrait:Inset("player")), 0)
Equal("a frame without a portrait", Portrait:Resolve("nothing"), nil)
Equal("raid marker on", AUI.Profile:Get(Options:Path("player", "indicators.raid.enabled")), true)
Equal("resting on", AUI.Profile:Get(Options:Path("player", "indicators.resting.enabled")), true)
Equal("combat off", AUI.Profile:Get(Options:Path("player", "indicators.combat.enabled")), false)
Equal("leader on", AUI.Profile:Get(Options:Path("player", "indicators.leader.enabled")), true)
Equal("PvP off", AUI.Profile:Get(Options:Path("player", "indicators.pvp.enabled")), false)
Equal("threat on", AUI.Profile:Get(Options:Path("player", "indicators.threat.enabled")), true)
Equal("totems on", AUI.Profile:Get(Options:Path("player", "totems.enabled")), true)
Equal("idle fade off", AUI.Profile:Get(Options:Path("player", "fade.idle.enabled")), false)
Equal("at half", AUI.Profile:Get(Options:Path("player", "fade.idle.alpha")), 50)
Equal("tooltip on", AUI.Profile:Get(Options:Path("player", "tooltip.enabled")), true)
Equal("in combat too", AUI.Profile:Get(Options:Path("player", "tooltip.hideInCombat")), false)

-- Portrait room -------------------------------------------------------------------------------------------

Set("portrait.enabled", true)
Equal("attached left takes the frame's height", (Portrait:Inset("player")), 36)
Equal("and nothing at the right", select(2, Portrait:Inset("player")), 0)
Set("portrait.side", "RIGHT")
Equal("attached right", select(2, Portrait:Inset("player")), 36)
Equal("the square is the frame's height", Portrait:Size("player", Portrait:Resolve("player")), 36)
Equal("attached reaches nowhere", select(4, Portrait:Reach("player")), 0)
Set("portrait.style", "detached")
Set("portrait.size", 50)
Set("portrait.x", 3)
Set("portrait.y", 5)
Equal("detached takes no room", select(2, Portrait:Inset("player")), 0)
Equal("detached has its own size", Portrait:Size("player", Portrait:Resolve("player")), 50)
Equal("reaches right", select(4, Portrait:Reach("player")), 50 + 4 + 3)
Equal("and above", (Portrait:Reach("player")), 5)
Equal("and below", select(2, Portrait:Reach("player")), 50 - 5 - 36)
Set("portrait.side", "LEFT")
Equal("reaches left", select(3, Portrait:Reach("player")), 50 + 4 - 3)

-- Class icon ----------------------------------------------------------------------------------------------

Equal("a player's class icon", Portrait:ClassAtlas("player"), "classicon-MAGE")
unit.class = client.Secret()
Equal("no atlas from a secret class", Portrait:ClassAtlas("player"), nil)
unit.player, unit.class = false, "MAGE"
Equal("no class icon for an NPC", Portrait:ClassAtlas("target"), nil)
unit.player = true

-- Live portrait -------------------------------------------------------------------------------------------

local function NewFrame()
	local frame = CreateFrame("Button", nil, UIParent)
	frame.Border = {
		SetShadowShown = function(self, shown)
			self.shadowShown = shown
		end,
	}

	frame.key, frame.spec = "player", Options:Spec("player")
	frame.Content = frame
	frame.Bar = CreateFrame("StatusBar", nil, frame)
	frame.enabled, frame.disabled = {}, {}

	frame.running = {}

	function frame:IsElementEnabled(element)
		return self.running[element] == true
	end

	function frame:EnableElement(element)
		self.enabled[element] = (self.enabled[element] or 0) + 1
		self.disabled[element] = nil
		self.running[element] = true
	end

	function frame:DisableElement(element)
		self.disabled[element] = true
		self.running[element] = nil
	end

	return frame
end

config = Schema:Defaults()
Set("portrait.enabled", false)

local frame = NewFrame()

frame.PortraitWidgets = Portrait:Create(frame, frame.Bar)
Equal("hidden until shown", frame.PortraitWidgets.holder.shown, false)
Equal("no model yet", frame.PortraitWidgets.model, nil)
Equal("no border yet", frame.PortraitWidgets.border, nil)
Portrait:Apply(frame)
Equal("off runs no element", frame.enabled.Portrait, nil)

Set("portrait.enabled", true)
Portrait:Apply(frame)
Equal("on shows", frame.PortraitWidgets.holder.shown, true)
Equal("the texture is the element", frame.Portrait, frame.PortraitWidgets.texture)
Equal("the element runs", frame.enabled.Portrait, 1)
Equal("the square fits the frame", frame.PortraitWidgets.holder.width, 36)
Equal("at the top left", frame.PortraitWidgets.holder.points[1][1], "TOPLEFT")
Equal("attached has no border of its own", frame.PortraitWidgets.border, nil)
Equal("the style's divider beside the bar", frame.PortraitWidgets.divider.shown, true)
Equal("at the bar's side", frame.PortraitWidgets.divider.points[1][1], "TOPRIGHT")
Equal("as wide as the style's band", frame.PortraitWidgets.divider.width, 2)
Portrait:Apply(frame)
Equal("the same mode does not restart the element", frame.enabled.Portrait, 1)

styled = false
Portrait:Apply(frame)
Equal("a plain line is one pixel", frame.PortraitWidgets.divider.width, 0.5)
Equal("in the border's color", frame.PortraitWidgets.divider.color[1], 0)
styled = true
look.borderStyle = "NONE"
Portrait:Apply(frame)
Equal("no border, no divider", frame.PortraitWidgets.divider.shown, false)
look.borderStyle = "THIN_LINE"

Set("portrait.mode", "3d")
Portrait:Apply(frame)
Equal("3D makes the model", frame.Portrait, frame.PortraitWidgets.model)
Equal("a model widget", frame.PortraitWidgets.model.kind, "PlayerModel")
Equal("the element restarts", frame.enabled.Portrait, 2)
Equal("the texture hides", frame.PortraitWidgets.texture.shown, false)

Set("portrait.mode", "class")
Portrait:Apply(frame)
Equal("class icon uses the texture", frame.Portrait, frame.PortraitWidgets.texture)
Equal("through the override", type(frame.Portrait.Override), "function")
frame.__unit = "player"
frame.Portrait.Override(frame, "ev", "player")
Equal("a player shows the class", frame.Portrait.atlas, "classicon-MAGE")
unit.player = false
frame.Portrait.Override(frame, "ev", "player")
Equal("anything else the 2D portrait", frame.Portrait.portraitUnit, "player")
unit.player = true

Set("portrait.style", "detached")
Portrait:Apply(frame)
Equal("detached has its own border", frame.PortraitWidgets.border.look.style, "THIN_LINE")
Equal("above its content", frame.PortraitWidgets.border.overContent, true)
Equal("no divider detached", frame.PortraitWidgets.divider.shown, false)
Equal("outside the frame", frame.PortraitWidgets.holder.points[1][3], "TOPLEFT")
Set("portrait.style", "attached")
Portrait:Apply(frame)
Equal("attached again drops the border", frame.PortraitWidgets.border.look.style, "NONE")

Set("portrait.enabled", false)
Portrait:Apply(frame)
Equal("off stops the element", frame.disabled.Portrait, true)
Equal("and hides", frame.PortraitWidgets.holder.shown, false)
Equal("and forgets the mode", frame.portraitMode, nil)

-- Indicators ----------------------------------------------------------------------------------------------

config = Schema:Defaults()
frame = NewFrame()
frame:SetFrameLevel(1)
created = {}
Indicators:Create(frame)
Equal("a layer", frame.IndicatorLayer ~= nil, true)
Equal("over the bar, border and text", frame.IndicatorLayer.level, 11)
Equal("raid marker", frame.RaidTargetIndicator ~= nil, true)
Equal("resting follows its animation", type(frame.RestingIndicator.PostUpdate), "function")
Equal("assistant beside leader", frame.AssistantIndicator ~= nil, true)
Equal("threat holds its edges", #frame.ThreatIndicator.Edges, 4)
Equal("four totems", #frame.Totems, 4)
Equal("each a button", created.Button, 4)
Equal("each with a cooldown", frame.Totems[1].Cooldown.kind, "Cooldown")

Indicators:Apply(frame)
Equal("raid marker runs", frame.enabled.RaidTargetIndicator, 1)
Equal("at its size", frame.RaidTargetIndicator.width, 18)
Equal("on the bar", frame.RaidTargetIndicator.points[1][2], frame.Bar)
Equal("resting at its size", frame.RestingIndicator.width, 18)
Equal("Blizzard's animated art by default", frame.RestingIndicator.atlas, "UI-HUD-UnitFrame-Player-Rest-Flipbook")
Equal("a whole flipbook", frame.RestingIndicator.restingAnimation ~= nil, true)
frame.RestingIndicator:PostUpdate(false)
Equal("the animation stops with the icon", frame.RestingIndicator.restingAnimation.playing, false)
frame.RestingIndicator.restingAnimation.plays = 0
frame.RestingIndicator:PostUpdate(true)
Equal("and plays with it", frame.RestingIndicator.restingAnimation.plays, 1)
local animated = frame.RestingIndicator.restingAnimation
animated.plays = 0
Indicators:Apply(frame)
Equal("a redraw does not restart it", animated.plays, 0)
Set("indicators.resting.icon", "resting3")
Indicators:Apply(frame)
Equal("an icon of AeonUI's", frame.RestingIndicator.file, "Interface\\AddOns\\AeonUI\\Media\\Textures\\Resting\\Resting3.tga")
animated.plays = 0
frame.RestingIndicator:PostUpdate(true)
Equal("does not animate", animated.plays, 0)
Set("indicators.resting.icon", "classic")
Indicators:Apply(frame)
Equal("the classic icon", frame.RestingIndicator.file, "Interface\\CharacterFrame\\UI-StateIcon")
Equal("cut from its sheet", frame.RestingIndicator.coords[2], 0.5)
Set("indicators.resting.icon", "still")
Indicators:Apply(frame)
Equal("the still art", frame.RestingIndicator.file, "file")
Equal("the frame with all three Zs: its column", ("%.3f"):format(frame.RestingIndicator.coords[1]), "0.500")
Equal("and its row", ("%.3f"):format(frame.RestingIndicator.coords[3]), "0.571")
Set("indicators.resting.icon", "portrait")
Indicators:Apply(frame)
Equal("the portrait art", frame.RestingIndicator.atlas, "UI-HUD-UnitFrame-PlayerPortrait-Rest")
missingAtlas = true
Equal("art the client lacks is not offered", Indicators:HasRestingIcon("portrait"), false)
Equal("files always are", Indicators:HasRestingIcon("resting0"), true)
Set("indicators.resting.icon", "still")
Indicators:Apply(frame)
Equal("a saved icon the client lacks draws the classic one", frame.RestingIndicator.file, "Interface\\CharacterFrame\\UI-StateIcon")
missingAtlas = false
Set("indicators.resting.icon", "animated")
Equal("combat stopped", frame.disabled.CombatIndicator, true)
Equal("and hidden", frame.CombatIndicator.shown, false)
Equal("PvP stopped", frame.disabled.PvPIndicator, true)
Equal("assistant follows leader", frame.enabled.AssistantIndicator, 1)
Equal("threat runs", frame.enabled.ThreatIndicator, 1)
Equal("totems run", frame.enabled.Totems, 1)
Equal("first totem at the frame's right", frame.Totems[1].points[1][4], 0)
Equal("next to its left", frame.Totems[2].points[1][4], -24)
Equal("under the frame", frame.Totems[1].points[1][5], -4)

Set("indicators.raid.size", 30)
Set("indicators.leader.enabled", false)
Set("totems.enabled", false)
Indicators:Apply(frame)
Equal("a size change applies", frame.RaidTargetIndicator.width, 30)
Equal("leader stopped", frame.disabled.LeaderIndicator, true)
Equal("assistant too", frame.disabled.AssistantIndicator, true)
Equal("totems stopped", frame.disabled.Totems, true)
Equal("and hidden", frame.Totems[1].shown, false)

Equal("no threat, no border", Indicators:ThreatColor(0), nil)
Equal("near aggro is gold", Indicators:ThreatColor(1).g, 0.82)
Equal("with aggro is orange", Indicators:ThreatColor(3).g, 0.5)
Equal("second totem offset", Indicators:TotemOffset(22, 2, 2, "left"), -24)
Equal("growing right", Indicators:TotemOffset(22, 2, 2, "right"), 24)

config = Schema:Defaults()
frame = NewFrame()
Indicators:Create(frame)
Indicators:Apply(frame)

local raid = frame.RaidTargetIndicator

raid.updates = 0

function raid:ForceUpdate()
	self.updates = self.updates + 1
end

Indicators:Apply(frame)
Equal("a running element is not updated again", raid.updates, 0)
Set("indicators.raid.enabled", false)
Indicators:Apply(frame)
Equal("off hides it", raid.shown, false)
Set("indicators.raid.enabled", true)
Indicators:Apply(frame)
Equal("on again updates it, so it comes back", raid.updates, 1)
Equal("once", frame.enabled.RaidTargetIndicator, 2)

Equal("marker's default anchor", frame.RaidTargetIndicator.points[1][1], "CENTER")
Set("indicators.raid.anchor", "TOPRIGHT")
Set("indicators.raid.placement", "outside")
Set("indicators.raid.x", 3)
Set("indicators.raid.y", -2)
Indicators:Apply(frame)
Equal("a new anchor applies", frame.RaidTargetIndicator.points[1][3], "TOPRIGHT")
Equal("with its placement", frame.RaidTargetIndicator.points[1][1], "BOTTOMRIGHT")
Equal("and offsets", frame.RaidTargetIndicator.points[1][4] .. "," .. frame.RaidTargetIndicator.points[1][5], "3,-2")
Set("indicators.leader.x", 5)
Indicators:Apply(frame)
Equal("the assistant shares the leader's place", frame.AssistantIndicator.points[1][4], 5)
Equal("totems' default corner", frame.Totems[1].points[1][1] .. " " .. frame.Totems[1].points[1][3], "TOPRIGHT BOTTOMRIGHT")
Set("totems.anchor", "TOPLEFT")
Set("totems.growth", "right")
Set("totems.x", 2)
Indicators:Apply(frame)
Equal("totems move", frame.Totems[1].points[1][3], "TOPLEFT")
Equal("from the new corner", frame.Totems[1].points[1][4], 2)
Equal("and grow its way", frame.Totems[2].points[1][4], 2 + 24)
config = Schema:Defaults()
frame = NewFrame()
Indicators:Create(frame)

local threat = frame.ThreatIndicator

threat:Show()
threat:PostUpdate("player", 3)
Equal("solo, no threat border", threat.shown, false)
grouped, instance = true, "party"
threat:Show()
threat:PostUpdate("player", 3)
Equal("in a group instance, shown", threat.shown, true)
Equal("in its color", threat.Edges[1].vertex[2], 0.5)
threat:PostUpdate("player", client.Secret())
Equal("a secret status shows nothing", threat.shown, false)

threat:PostUpdate("player", 3)
Equal("a line keeps the ring", threat.shown, true)
Equal("and its border's own color", frame.threatColor, nil)
look.borderStyle = "NONE"
Equal("no border keeps the ring too", Indicators:UsesThreatRing("player"), true)

local hovers = 0

function frame:ShowHovered()
	hovers = hovers + 1
end

look.borderStyle = "FOREVER_MINIMAL_SHADED"
Equal("a band has no ring", Indicators:UsesThreatRing("player"), false)
threat:PostUpdate("player", 3)
Equal("the ring hides", threat.shown, false)
Equal("the border takes the color", frame.threatColor.g, 0.5)
Equal("once", hovers, 1)
threat:PostUpdate("player", 3)
Equal("the same color repaints nothing", hovers, 1)
threat:PostUpdate("player", 1)
Equal("near aggro changes it", frame.threatColor.g, 0.82)
threat:PostUpdate("player", 0)
Equal("no threat gives the border back", frame.threatColor, nil)
threat:PostUpdate("player", 3)
grouped = false
threat:PostUpdate("player", 3)
Equal("out of a group too", frame.threatColor, nil)
grouped = true
threat:PostUpdate("player", 3)
Indicators:Apply(frame)
Equal("a redraw keeps it", frame.threatColor.g, 0.5)
Set("indicators.threat.enabled", false)
Indicators:Apply(frame)
Equal("off gives the border back", frame.threatColor, nil)
Equal("threat in the border keeps the shadow", frame.Border.shadowShown, true)
Set("indicators.threat.enabled", true)
threat.threatColor = { r = 1, g = 0.5, b = 0 }
look.borderStyle = "THIN_LINE"
Indicators:Apply(frame)
Equal("a style with a ring moves it there", frame.threatColor, nil)
Equal("and shows it", threat.shown, true)
Equal("the ring takes the shadow's place", frame.Border.shadowShown, false)
threat.threatColor = nil
Indicators:Apply(frame)
Equal("no threat brings the shadow back", frame.Border.shadowShown, true)

-- Fading --------------------------------------------------------------------------------------------------

config = Schema:Defaults()
Schema:Write(config, Options:Path("player", "fade.idle.enabled"), true)
Equal("idle alone", Fading:IsIdle(false, false, false), true)
Equal("not in combat", Fading:IsIdle(true, false, false), false)
Equal("not with a target", Fading:IsIdle(false, true, false), false)
Equal("not while casting", Fading:IsIdle(false, false, true), false)
Equal("no fade on an unknown frame", Fading:IdleAlpha("nothing"), nil)

Equal("only while idle", Fading:Target(false, false, 0.5), 1)
Equal("not while hovered", Fading:Target(true, true, 0.5), 1)
Equal("not with the fade off", Fading:Target(true, false, nil), 1)
Equal("else the fade's", Fading:Target(true, false, 0.5), 0.5)
Equal("quicker in", Fading:Response(1, 0.5) < Fading:Response(0.5, 1), true)

local function Settle()
	springs.Frames(1)
end

frame = NewFrame()
AUI.Frames.objects.player = frame
curves = 0
Fading:Start()
Equal("follows combat", handlers.PLAYER_REGEN_DISABLED ~= nil, true)
Equal("follows the target", handlers.PLAYER_TARGET_CHANGED ~= nil, true)
Equal("follows casts", handlers.UNIT_SPELLCAST_START ~= nil, true)
Equal("follows health", handlers.UNIT_HEALTH ~= nil and handlers.UNIT_MAXHEALTH ~= nil, true)
Equal("makes one curve", curves, 1)
Equal("a step curve", frame.idleFade.curve.kind, 1)
Equal("it starts opaque", frame.alpha == nil or frame.alpha > 0.5, true)
springs.Frames(0.02)
Equal("then moves, not jumps", frame.alpha > 0.5 and frame.alpha < 1, true)
Settle()
Equal("idle fades to half", frame.alpha, 0.5)

healthShare = 0.9
handlers.UNIT_HEALTH(Fading, "UNIT_HEALTH", "player")
Equal("below full health it stays opaque", frame.alpha, 1)
handlers.UNIT_HEALTH(Fading, "UNIT_HEALTH", "target")
Equal("another unit changes nothing", frame.alpha, 1)
healthShare = 1
handlers.UNIT_HEALTH(Fading, "UNIT_HEALTH", "player")
Equal("full again fades", frame.alpha, 0.5)

frame.hovered = true
Fading:Update(frame)
springs.Frames(0.02)
Equal("hovering moves it back", frame.alpha > 0.5, true)
Equal("not all at once", frame.alpha < 1, true)
local midway = frame.alpha
frame.hovered = false
Fading:Update(frame)
springs.Frames(0.02)
Equal("a turn starts from where it is", math.abs(frame.alpha - midway) < 0.3, true)
frame.hovered = true
Fading:Update(frame)
Settle()
Equal("hovered is opaque", frame.alpha, 1)
frame.hovered = false
Fading:Update(frame)
Settle()
Equal("leaving fades", frame.alpha, 0.5)

handlers.PLAYER_REGEN_DISABLED(Fading)
Settle()
Equal("combat brings it back", frame.alpha, 1)
handlers.PLAYER_REGEN_ENABLED(Fading)
Settle()
Equal("out of combat fades", frame.alpha, 0.5)

hasTarget = true
handlers.PLAYER_TARGET_CHANGED(Fading)
Settle()
Equal("a target brings it back", frame.alpha, 1)
hasTarget = false
handlers.PLAYER_TARGET_CHANGED(Fading)
Settle()

casting = "Fireball"
handlers.UNIT_SPELLCAST_START(Fading, "UNIT_SPELLCAST_START", "target")
Settle()
Equal("another unit's cast changes nothing", frame.alpha, 0.5)
handlers.UNIT_SPELLCAST_START(Fading, "UNIT_SPELLCAST_START", "player")
Settle()
Equal("casting brings it back", frame.alpha, 1)
casting = client.Secret()
Fading:UpdateAll()
Settle()
Equal("a secret cast counts as casting", frame.alpha, 1)
casting = nil
Fading:UpdateAll()
Settle()
Equal("then it fades again", frame.alpha, 0.5)

Set("fade.idle.alpha", 20)
AUI.Callbacks.Profile(Fading)
Settle()
Equal("the strength applies", frame.alpha, 0.2)

Set("fade.idle.enabled", false)
AUI.Callbacks.Profile(Fading)
Settle()
Equal("off stays opaque", frame.alpha, 1)
Equal("and follows nothing", next(handlers), nil)
Equal("through one unregister", unregistered, 1)
AUI.Callbacks.Profile(Fading)
Equal("still off, no second unregister", unregistered, 1)
Set("fade.idle.enabled", true)
AUI.Callbacks.Profile(Fading)
Settle()
Equal("on again fades", frame.alpha, 0.2)
Equal("and follows again", handlers.PLAYER_REGEN_DISABLED ~= nil, true)
Equal("no second curve", curves, 1)

springs.reduce = true
frame.hovered = true
Fading:Update(frame)
Equal("Reduce Motion jumps", frame.alpha, 1)
frame.hovered = false

io.stdout:write(("check_indicators: %d checks passed\n"):format(client.checks))
