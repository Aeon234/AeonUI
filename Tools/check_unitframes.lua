-- Checks AeonUI_UnitFrames/Frames/ outside the game: the shared settings and what follows them, tag strings and tag
-- methods with ordinary and secret values, status priority, slot placement and width sharing; then the owner: nothing
-- spawned or registered while every frame is off, a frame spawned at its size and place with its look, the reload
-- notice, a layout change held past combat, and the wait when the session starts in combat.
-- Run from any directory with Lua 5.1: lua Tools/check_unitframes.lua
-- Loads the real files against stubbed globals and a stubbed oUF. Widgets are modeled by type and fail on a method
-- their type lacks. These checks prove logic, not drawing or oUF's behavior in game.
-- Exits non-zero on the first failed check.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

local client = assert(loadfile(root .. "Tools/stub_client.lua"))({ project = "retail" })
local Equal, Secret = client.Equal, client.Secret

Enum = {
	LuaCurveType = { Step = 1 },
	UnitDamageAbsorbClampMode = { MaximumHealth = 2 },
	UnitHealAbsorbClampMode = { MaximumHealth = 1 },
	UnitHealAbsorbMode = { ReducedByIncomingHeals = 0 },
	UnitIncomingHealClampMode = { MissingHealth = 0 },
}

C_CurveUtil = {
	CreateCurve = function()
		return { SetType = function() end, ClearPoints = function() end, AddPoint = function() end }
	end,
}

C_Texture = {
	GetAtlasInfo = function() end,
}

function UnitCastingInfo() end

function UnitChannelInfo() end

function UnitExists() end

AnchorUtil = { FlowLayoutAxis = { Horizontal = 0 } }
AuraContainerSortMethod = { AuraInstanceIDOnly = 8 }
AuraContainerSortDirection = { Normal = 0 }

function CreateColor(r, g, b, a)
	return { r = r, g = g, b = b, a = a }
end

C_DurationUtil = {
	CreateDurationTextBinding = function()
		local binding = {}

		function binding.SetFontString() end
		function binding.SetTextFormat() end
		function binding.SetDuration() end
		function binding:SetEnabled(on)
			self.enabled = on
		end

		return binding
	end,
}
Enum.DurationTextBindingProperty = { RemainingDuration = 1, ElapsedDuration = 2, TotalDuration = 3 }
Enum.StatusBarInterpolation = Enum.StatusBarInterpolation or { Immediate = 0, ExponentialEaseOut = 1 }

-- Client globals the frame code reads.

DEAD, PLAYER_OFFLINE = "Dead", "Offline"
UnitFrame_OnEnter, UnitFrame_OnLeave = function() end, function() end
CurveConstants = { ScaleTo100 = "scale" }
C_StringUtil = {
	TruncateWhenZero = function(value)
		return value
	end,
}

function AbbreviateNumbers(value)
	return value
end

local unit = { health = 41300, percent = 82, missing = 9100, connected = true, ghost = false, dead = false }

function UnitHealth()
	return unit.health
end

function UnitHealthPercent()
	return unit.percent
end

function UnitHealthMissing()
	return unit.missing
end

function UnitIsConnected()
	return unit.connected
end

function UnitIsGhost()
	return unit.ghost
end

function UnitIsDead()
	return unit.dead
end

local mediaCallback

function LibStub()
	return {
		RegisterCallback = function(_, event, method)
			mediaCallback = event .. " " .. method
		end,
		CreateSpring = function(_, value, onUpdate)
			return {
				value = value,
				To = function(self, target)
					self.value = target
					self.moves = (self.moves or 0) + 1
					onUpdate(target)
				end,
				Jump = function(self, target)
					self.value = target
					self.jumps = (self.jumps or 0) + 1
					onUpdate(target)
				end,
				Stop = function(self)
					self.stopped = true
				end,
			}
		end,
	}
end

-- The addon table, with the real schema and a thin profile over it.

local AUI = { L = setmetatable({}, { __index = function(_, key)
	return key
end }), can = {} }

function AUI:CopyTable(source)
	if type(source) ~= "table" then
		return source
	end

	local copy = {}

	for key, value in pairs(source) do
		copy[key] = self:CopyTable(value)
	end

	return copy
end

function AUI:Readable(value, fallback)
	if issecretvalue(value) then
		return fallback
	end

	return value
end

function AUI:Pixel()
	return 1
end

local registered = {}

-- What the frames' owner follows; the idle fade has its own check.
AUI.Events = {
	Register = function(_, event, owner, handler)
		if owner == AUI.Frames then
			registered[event] = handler
		end
	end,
	UnregisterAll = function() end,
}
AUI.Callbacks = {
	Register = function(_, channel, owner, handler)
		if owner == AUI.Frames then
			registered[channel] = handler
		end
	end,
}
AUI.Border = {
	ART = {},
	ART_COLOR = { r = 0.5, g = 0.4, b = 0.3 },
	SHADOW_SIZE = 4,
	SHADOW_COLOR = { r = 0, g = 0, b = 0, a = 0.618 },
	CellDividerWidth = function() end,
	StyleCellDivider = function() end,
	Create = function()
		return {
			SetFrameLevel = function() end,
			SetShadowShown = function(self, shown)
				self.shadowShown = shown
			end,
			Layout = function(self)
				self.laidOut = (self.laidOut or 0) + 1
			end,
			Apply = function(self, look)
				self.look = look
				self.color = look.color
				self.lit = false
			end,
			SetColor = function(self, color, force)
				self.color = color
				self.forced = force
			end,
			SetLit = function(self, lit)
				self.lit = lit
			end,
		}
	end,
}
AUI.Media = {
	FLAT = "flat",
	Font = function(_, name)
		return name
	end,
	FontFlags = function(_, outline)
		return outline
	end,
	SetBarTexture = function(_, bar, texture)
		bar.texture = texture
	end,
	BorderFile = function(_, name)
		return name == "Blizzard Tooltip" and "tooltip file" or nil
	end,
}

local spawned, styles = {}, {}

-- The group method oUF adds to an aura container.
local AURA_ELEMENT = {
	AddGroup = function(element, filter)
		element.filter = filter

		return "Group1"
	end,
}

-- The methods oUF gives a frame it spawns. These record what a check reads.
local UNIT_FRAME = {
	IsElementEnabled = function(self, element)
		return self.elementsOn ~= nil and self.elementsOn[element] == true
	end,
	EnableElement = function(self, element)
		self.elementsOn = self.elementsOn or {}
		self.elementsOn[element] = true
	end,
	DisableElement = function(self, element)
		self.elementsOn = self.elementsOn or {}
		self.elementsOn[element] = false
	end,
	CreateAuras = function(self)
		self.auraElements = (self.auraElements or 0) + 1

		return Mixin(CreateFrame("AuraContainer", nil, self, "CustomAuraContainerTemplate"), AURA_ELEMENT)
	end,
	Tag = function(_, text, tag)
		text.tag = tag
		text.UpdateTag = function(self)
			self.updated = true
		end
	end,
	Untag = function(_, text)
		text.tag = nil
	end,
	UpdateAllElements = function(self, event)
		self.fullUpdates = (self.fullUpdates or 0) + 1
		self.fullUpdateEvent = event
		self.appliedAtFullUpdate = self.width ~= nil
	end,
}

AUI.oUF = {
	Tags = { Methods = {}, Events = {}, SharedEvents = {} },
	colors = { power = {}, class = {}, reaction = {} },
	AddElement = function() end,
	RegisterStyle = function(_, name, style)
		styles[name] = style
	end,
	SetActiveStyle = function(self, name)
		self.active = name
	end,
	Spawn = function(self, spawnUnit, name)
		local frame = Mixin(CreateFrame("Button", name, UIParent), UNIT_FRAME)

		spawned[#spawned + 1] = name
		styles[self.active](frame, spawnUnit)
		frame.__unit = spawnUnit

		-- oUF gives an element ForceUpdate as it enables it.
		for _, element in ipairs({ frame.Health or false, frame.Power or false }) do
			if element then
				element.ForceUpdate = element.ForceUpdate or function() end
			end
		end

		return frame
	end,
}

local function Load(path)
	assert(loadfile(root .. path))("AeonUI", AUI)
end

Load("AeonUI/Profile/Schema.lua")

local Schema = AUI.Schema
local config

Load("AeonUI_UnitFrames/Frames/Options.lua")
config = Schema:Defaults()
AUI.Profile = {
	Get = function(_, path)
		return Schema:Read(config, path)
	end,
}

Load("AeonUI_UnitFrames/Frames/Tags.lua")
Load("AeonUI_UnitFrames/Frames/Text.lua")
Load("AeonUI_UnitFrames/Frames/HealthColor.lua")
Load("AeonUI_UnitFrames/Frames/Overlays.lua")
Load("AeonUI_UnitFrames/Frames/AuraCategories.lua")
Load("AeonUI_UnitFrames/Frames/Auras.lua")
Load("AeonUI_UnitFrames/Frames/Portrait.lua")
Load("AeonUI_UnitFrames/Frames/Indicators.lua")
Load("AeonUI_UnitFrames/Frames/Fading.lua")
Load("AeonUI_UnitFrames/Frames/RangeSpells.lua")
Load("AeonUI_UnitFrames/Frames/RangeFade.lua")
Load("AeonUI_UnitFrames/Frames/PowerColor.lua")
Load("AeonUI_UnitFrames/Frames/PlayerPower.lua")
Load("AeonUI_UnitFrames/Frames/ClassPower.lua")
Load("AeonUI_UnitFrames/Frames/UnitFrame.lua")
Load("AeonUI_UnitFrames/Frames/Frames.lua")
C_StringUtil.CreateNumericRuleFormatter = function()
	return { SetBreakpoints = function() end }
end

AUI.can.castBar = true
Load("AeonUI_UnitFrames/CastBar/Options.lua")
Load("AeonUI_UnitFrames/CastBar/CastBar.lua")
Load("AeonUI_UnitFrames/CastBar/UnitCastBar.lua")

local Options, Tags, Text, Frames = AUI.UnitFrameOptions, AUI.Tags, AUI.Text, AUI.Frames

-- Settings ----------------------------------------------------------------------------------------------------------

local function Path(rest)
	return Options:Path("player", rest)
end

Equal("off by default", AUI.Profile:Get(Path("enabled")), false)
Equal("the Player's bars follow All Frames", AUI.Profile:Get(Path("bars.texture")), "Solid")
Equal("font outlines default to Slug", AUI.Profile:Get(Path("text.outline")), "SLUG")
Equal("a slot follows its frame", AUI.Profile:Get(Options:SlotPath("player", 1, "size")), 12)

Schema:Write(config, Options.ALL .. "text.size", 14)
Equal("a slot follows All Frames through its frame", AUI.Profile:Get(Options:SlotPath("player", 1, "size")), 14)
Schema:Write(config, Path("text.size"), 16)
Equal("a frame's own value wins over All Frames", AUI.Profile:Get(Options:SlotPath("player", 1, "size")), 16)
Equal("and counts as custom", Schema:IsCustom(config, Path("text.size")), true)
Schema:Write(config, Options:SlotPath("player", 1, "size"), 18)
Equal("a slot's own value wins over its frame", AUI.Profile:Get(Options:SlotPath("player", 1, "size")), 18)
config = Schema:Defaults()

-- Tags ---------------------------------------------------------------------------------------------------------------

Tags:Register()

local CONTEXT = { primary = true, precision = "default", decimals = 0, nameFormat = "first" }
local METHOD = AUI.oUF.Tags.Methods

Equal("none shows nothing", Tags:Compile({ content = "none" }, CONTEXT), nil)
Equal("health and percent", Tags:Compile({ content = "healthAndPercent", separator = "dash", colorMode = "custom" }, CONTEXT),
	"[aui:health(both,dash,default,0,1)]")
Equal("a color mode wraps the tag", Tags:Compile({ content = "name", colorMode = "class" }, CONTEXT),
	"[aui:classcolor][aui:name(first)]|r")
Equal("a plain health value", METHOD["aui:health"]("player", nil, "cur", "dash", "default", "0", "1"), 41300)
Equal("a percent", METHOD["aui:health"]("player", nil, "pct", "dash", "default", "0", "1"), "82%")

unit.health, unit.percent, unit.missing = Secret(), Secret(), Secret()
Equal("a secret health passes through", issecretvalue(METHOD["aui:health"]("player", nil, "cur", "dash", "default", "0",
	"1")), true)
Equal("a secret health and percent stay secret", issecretvalue(METHOD["aui:health"]("player", nil, "both", "dash",
	"default", "0", "1")), true)
unit.health, unit.percent, unit.missing = 41300, 82, 9100

unit.connected = false
Equal("offline in the primary slot", METHOD["aui:health"]("player", nil, "cur", "dash", "default", "0", "1"), "Offline")
Equal("nothing in the others", METHOD["aui:health"]("player", nil, "cur", "dash", "default", "0", "0"), nil)
unit.connected = true
unit.dead = Secret()
Equal("a secret dead state is not tested", METHOD["aui:health"]("player", nil, "cur", "dash", "default", "0", "1"), 41300)
unit.dead = false

-- Text ---------------------------------------------------------------------------------------------------------------

local function Points(anchor, placement)
	return table.concat({ Text:Points(anchor, placement) }, " ")
end

Equal("inside", Points("LEFT", "inside"), "LEFT LEFT LEFT")
Equal("on an edge", Points("TOPRIGHT", "edge"), "RIGHT TOPRIGHT RIGHT")
Equal("outside the top", Points("TOP", "outside"), "BOTTOM TOP CENTER")
Equal("outside the left", Points("LEFT", "outside"), "RIGHT LEFT RIGHT")

local function Slot(content, anchor, width)
	return { content = content, anchor = anchor, placement = "inside", size = 12, width = width or 100 }
end

Equal("alone in its row", Text:Widths({ Slot("name", "LEFT") }, 200)[1], 190)
Equal("an empty slot takes no room", Text:Widths({ Slot("none", "LEFT"), Slot("name", "LEFT") }, 200)[1], 0)
Equal("sharing leaves room for the other", Text:Widths({ Slot("name", "LEFT"), Slot("health", "RIGHT") }, 200)[1], 152)
Equal("Width % scales it", Text:Widths({ Slot("name", "LEFT", 50) }, 200)[1], 95)

-- The owner ----------------------------------------------------------------------------------------------------------

registered = {}
Frames:Start()
Equal("all off: nothing spawned", #spawned, 0)
Equal("all off: no style", next(styles), nil)
Equal("all off: only settings are followed", next(registered), "Profile")
Equal("all off: no events", next(registered, "Profile"), nil)
Equal("no reload needed", Frames:ReloadNeeded(), false)

Schema:Write(config, Path("enabled"), true)
Equal("turning one on asks for a reload", Frames:ReloadNeeded(), true)

client:SetCombat(true)
Frames:Start()
Equal("in combat: waits", #spawned, 0)
Equal("for combat's end", registered.PLAYER_REGEN_ENABLED, Frames.Start)
client:SetCombat(false)

Frames:Start()

local frame = Frames.objects.player

Equal("a spawned frame gets its first update", frame.fullUpdates, 1)
Equal("after its settings apply", frame.appliedAtFullUpdate, true)

Equal("spawned by its global name", spawned[1], "AeonUIPlayer")
Equal("once", #spawned, 1)
Equal("no reload needed once spawned", Frames:ReloadNeeded(), false)
Equal("late media is followed", mediaCallback, "LibSharedMedia_Registered OnMediaRegistered")
Equal("its width", frame.width, 270)
Equal("its height", frame.height, 36)
Equal("its default place", table.concat({ frame.points[1][1], frame.points[1][4], frame.points[1][5] }, " "), "CENTER -330 -200")
Equal("its texture", frame.Bar.texture, "Solid")
Equal("painted by AeonUI's color step", frame.Health.UpdateColor, AUI.HealthColor.UpdateColor)
Equal("following oUF's reaction events", frame.Health.colorReaction, true)
Equal("in class colors by default", frame.healthColors.mode, "classReaction")
Equal("building no curve for them", frame.healthCurve, nil)
Equal("its heal prediction is oUF's", frame.Health.HealingAll, frame.Overlays.healing)
Equal("its shields too", frame.Health.DamageAbsorb, frame.Overlays.absorb)
Equal("and its heal absorbs", frame.Health.HealAbsorb, frame.Overlays.healAbsorb)
Equal("each shown", frame.Overlays.absorb.shown, true)
Equal("the overlays get their settings", frame.Overlays.settings.absorb.position, "attach")
Equal("no glow made while off", frame.Overlays.glow, nil)
Equal("a display for buffs and for debuffs", frame.auraElements, 2)
Equal("its portrait made and hidden", frame.PortraitWidgets.holder.shown ~= true, true)
Equal("its bar fills the frame", frame.Bar.points[2][4], 0)
Equal("its raid marker runs", frame.elementsOn.RaidTargetIndicator, true)
Equal("combat waits for its switch", frame.elementsOn.CombatIndicator, false)
Equal("its totems run", frame.elementsOn.Totems, true)
Equal("no idle fade made by default", frame.idleFade, nil)
Equal("its debuffs hold their filter", frame.AuraDisplays.debuffs.element.filter, "HARMFUL")
Equal("disabled until shown", frame.AuraDisplays.buffs.element.enabled, false)
Equal("placed against the frame", frame.AuraDisplays.buffs.element.flowAnchor, "BOTTOMLEFT")
Equal("no backing made while off", frame.Overlays.backing, nil)
Equal("the border sits above the overlays", AUI.UnitFrame.BORDER_LEVEL > 5, true)
Equal("and the text above the border's edge", AUI.UnitFrame.TEXT_LEVEL > AUI.UnitFrame.BORDER_LEVEL + 1, true)
Equal("a thin line by default", frame.Border.look.style, "THIN_LINE")
Equal("in black", frame.Border.look.color.r, 0)
Equal("drawing no fill of its own", frame.Border.look.background.a, 0)
Equal("laid out once placed", frame.Border.laidOut, 1)
Equal("no shadow by default", frame.Border.look.shadow, nil)
Schema:Write(config, Options.ALL .. "bars.showShadow", true)
registered.Profile(Frames, Options.ALL .. "bars.showShadow")
Equal("All Frames turns the shadow on", frame.Border.look.shadow.size, 4)
Schema:Write(config, Path("bars.shadowSize"), 8)
registered.Profile(Frames, Path("bars.shadowSize"))
Equal("and the frame's own size wins", frame.Border.look.shadow.size, 8)
Schema:Write(config, Path("bars.showShadow"), false)
registered.Profile(Frames, Path("bars.showShadow"))
Equal("a frame can turn it off alone", frame.Border.look.shadow, nil)
Schema:Write(config, Path("bars.showShadow"), nil)
Schema:Write(config, Path("bars.shadowSize"), nil)
Schema:Write(config, Options.ALL .. "bars.showShadow", nil)
registered.Profile(Frames, Options.ALL .. "bars.showShadow")
Equal("back off with All Frames", frame.Border.look.shadow, nil)
Equal("its first slot is tagged", frame.TextSlots[1].tag, "[aui:health(both,dash,default,0,1)]")
Equal("its second is empty", frame.TextSlots[2].tag, nil)
Equal("listed for click-casting", ClickCastFrames[frame], true)
Equal("combat's end now applies held layout", registered.PLAYER_REGEN_ENABLED, Frames.OnCombatEnded)

Schema:Write(config, Path("reverse"), true)
registered.Profile(Frames, Path("reverse"))
Equal("an appearance change applies", frame.Bar.reverseFill, true)

Schema:Write(config, Options.ALL .. "bars.texture", "other")
registered.Profile(Frames, Options.ALL .. "bars.texture")
Equal("a shared change reaches the frame", frame.Bar.texture, "other")

Schema:Write(config, Options.ALL .. "health.dark", true)
registered.Profile(Frames, Options.ALL .. "health.dark")
Equal("a shared health color reaches the frame", frame.healthColors.dark, true)
Schema:Write(config, Path("overlays.absorb.enabled"), false)
registered.Profile(Frames, Path("overlays.absorb.enabled"))
Equal("a frame's shields turn off", frame.Overlays.absorb.shown, false)
Schema:Write(config, Path("portrait.enabled"), true)
Schema:Write(config, Path("portrait.side"), "RIGHT")
registered.Profile(Frames, Path("portrait.enabled"))
Equal("an attached portrait narrows the bar", frame.Bar.points[2][4], -36)
Equal("the portrait runs", frame.elementsOn.Portrait, true)
Schema:Write(config, Path("portrait.enabled"), false)
Schema:Write(config, Path("portrait.side"), nil)
registered.Profile(Frames, Path("portrait.enabled"))
Equal("and gives the room back", frame.Bar.points[2][4], 0)
local notInCombat = InCombatLockdown
InCombatLockdown = function()
	return true
end
Schema:Write(config, Path("buffs.enabled"), true)
registered.Profile(Frames, Path("buffs.enabled"))
Equal("a display waits for combat to end", frame.AuraDisplays.buffs.element.enabled, false)
InCombatLockdown = notInCombat
Frames:OnCombatEnded()
Equal("and then turns on", frame.AuraDisplays.buffs.element.enabled, true)
Schema:Write(config, Path("buffs.enabled"), false)
registered.Profile(Frames, Path("buffs.enabled"))
Schema:Write(config, Path("overlays.absorb.enabled"), true)
registered.Profile(Frames, Path("overlays.absorb.enabled"))
Schema:Write(config, Path("health.dark"), false)
registered.Profile(Frames, Path("health.dark"))
Equal("and the frame's own value wins", frame.healthColors.dark, false)
Schema:Write(config, Path("health.dark"), nil)
Schema:Write(config, Options.ALL .. "health.dark", nil)
registered.Profile(Frames, Options.ALL .. "health.dark")

frame.threatColor = { r = 0.3 }
frame:ShowHovered(true)
Equal("threat beats hover", frame.Border.color.r, 0.3)
Equal("on art of any color", frame.Border.forced, true)
frame.threatColor = nil
frame:ShowHovered(false)
Equal("and hands the border back", frame.Border.forced, nil)
frame:OnEnter()
Equal("hovering takes the Hover Color", frame.Border.color.r, 1)
Equal("a line is not lit", frame.Border.lit, false)
Equal("hovering shows the tooltip for oUF's unit", frame.unit, frame.__unit)
registered.Profile(Frames, Path("reverse"))
Equal("a change while hovered keeps it", frame.Border.color.r, 1)
frame:OnLeave()
Equal("leaving restores the line color", frame.Border.color.r, 0)

Schema:Write(config, Options.ALL .. "bars.hover", false)
frame:OnEnter()
Equal("with the highlight off, nothing changes", frame.Border.color.r, 0)
frame:OnLeave()
Schema:Write(config, Options.ALL .. "bars.hover", true)

Schema:Write(config, Options.ALL .. "bars.borderStyle", "FOREVER_MINIMAL")
registered.Profile(Frames, Options.ALL .. "bars.borderStyle")
Equal("Forever Minimal draws the shaded art", frame.Border.look.style, "FOREVER_MINIMAL_SHADED")
Equal("in the Border Color", frame.Border.look.color.r, 0.5)
Equal("with no edge file", frame.Border.look.edgeFile, nil)
frame:OnEnter()
Equal("hovering lightens its color", frame.Border.color.r, 0.5 + 0.5 * 0.4)
Equal("without lighting art", frame.Border.lit, false)
frame:OnLeave()
Equal("and leaving restores it", frame.Border.color.r, 0.5)

Schema:Write(config, Options.ALL .. "bars.borderStyle", "FOREVER")
registered.Profile(Frames, Options.ALL .. "bars.borderStyle")
frame:OnEnter()
Equal("Forever lights its art", frame.Border.lit, true)
frame:OnLeave()
Equal("and stops when the mouse leaves", frame.Border.lit, false)

Schema:Write(config, Options.ALL .. "bars.borderStyle", "Blizzard Tooltip")
registered.Profile(Frames, Options.ALL .. "bars.borderStyle")
Equal("a LibSharedMedia border draws as an edge", frame.Border.look.style, "EDGE")
Equal("from its file", frame.Border.look.edgeFile, "tooltip file")
Equal("in the Border Color", frame.Border.look.color.r, AUI.Border.ART_COLOR.r)
frame:OnEnter()
Equal("it takes the Hover Color", frame.Border.color.r, 1)
Equal("unlit", frame.Border.lit, false)
frame:OnLeave()

Schema:Write(config, Options.ALL .. "bars.borderStyle", "Unregistered")
registered.Profile(Frames, Options.ALL .. "bars.borderStyle")
Equal("a border no longer registered draws the default", frame.Border.look.style, "THIN_LINE")
Equal("with no edge file", frame.Border.look.edgeFile, nil)

Schema:Write(config, Options.ALL .. "bars.borderStyle", "METAL")
registered.Profile(Frames, Options.ALL .. "bars.borderStyle")
Equal("so does Metal, which frames do not offer", frame.Border.look.style, "THIN_LINE")

Schema:Write(config, Options.ALL .. "bars.borderStyle", "SLATE")
registered.Profile(Frames, Options.ALL .. "bars.borderStyle")
Equal("the frame follows All Frames' style", frame.Border.look.style, "SLATE")
Equal("a tinted style uses the Border Color", frame.Border.look.color.r, AUI.Border.ART_COLOR.r)
Schema:Write(config, Options.ALL .. "bars.borderColor", { r = 1, g = 0, b = 0 })
registered.Profile(Frames, Options.ALL .. "bars.borderColor")
Equal("which can change", frame.Border.look.color.r, 1)
Schema:Write(config, Path("bars.borderStyle"), "FOREVER")
registered.Profile(Frames, Path("bars.borderStyle"))
Equal("its own style wins", frame.Border.look.style, "FOREVER")
Equal("and Forever keeps its own colors", frame.Border.look.color.r, AUI.Border.ART_COLOR.r)
Schema:Write(config, Path("bars.borderThickness"), 150)
registered.Profile(Frames, Path("bars.borderThickness"))
Equal("its thickness", frame.Border.look.thickness, 150)

client:SetCombat(true)
Schema:Write(config, Path("width"), 300)
registered.Profile(Frames, Path("width"))
Equal("in combat a layout change waits", frame.width, 270)
Schema:Write(config, Path("reverse"), false)
registered.Profile(Frames, Path("reverse"))
Equal("while appearance still applies", frame.Bar.reverseFill, false)
client:SetCombat(false)
registered.PLAYER_REGEN_ENABLED(Frames)
Equal("combat's end applies the latest", frame.width, 300)

Schema:Write(config, Path("position"), { point = "TOPLEFT", x = 10, y = -20 })
registered.Profile(Frames, Path("position"))
Equal("a saved place", table.concat({ frame.points[1][1], frame.points[1][4], frame.points[1][5] }, " "), "TOPLEFT 10 -20")

Schema:Write(config, Path("enabled"), false)
Equal("turning it off asks for a reload", Frames:ReloadNeeded(), true)

-- The resource preview ---------------------------------------------------------------------------------------------

INTERRUPTED = "Interrupted"

Load("AeonUI_UnitFrames/Settings/Previews.lua")

function UnitClass()
	return "Mage", "MAGE"
end

function UnitName()
	return "Alex"
end

function UnitLevel()
	return 80
end

RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
AUI.oUF.colors.power.MANA = { r = 0, g = 0, b = 1 }

local Resource = AUI.ResourcePreview
local parts, resourcePreview = {}, Resource:New()
local partRegions = {}
local sampleTarget = { Part = function(_, region, id)
	parts[#parts + 1] = id
	partRegions[id] = region
end }

resourcePreview:Create(CreateFrame("Frame"))
AUI.can.classResources = true

local width, height = resourcePreview:Refresh(nil, sampleTarget)

Equal("both bars drawn with the switch off", table.concat(parts, " "), "classWidth powerWidth")
Equal("without extra mana", width .. "x" .. height, "360x22")
Equal("the whole class resource is the part", partRegions.classWidth, resourcePreview.resource)
Schema:Write(config, Options:Path("classPower", "extraMana"), true)

for _, state in ipairs(Resource.STATES) do
	parts = {}
	width, height = resourcePreview:Refresh(state, sampleTarget)
	Equal(state .. ": every part marked", table.concat(parts, " "), "classWidth extraMana powerWidth")
	Equal(state .. ": stacked", width .. "x" .. height, "360x28")
end

Schema:Write(config, Options:Path("classPower", "extraMana"), false)

local powerHeight = AUI.Profile:Get(Options:Path("playerPower", "height"))

local function ResourceSample(class)
	UnitClass = function()
		return class, class
	end
	parts = {}
	width, height = resourcePreview:Refresh(nil, sampleTarget)

	return table.concat(parts, " ")
end

Equal("a class without a resource draws only power", ResourceSample("WARRIOR"), "powerWidth")
Equal("with no gap above it", height, powerHeight)
Equal("its class resource hidden", resourcePreview.resource:IsShown(), false)
Equal("combo points for a rogue", ResourceSample("ROGUE"), "classWidth powerWidth")
Equal("shown again", resourcePreview.resource:IsShown(), true)
AUI.can.classResources = false
Equal("no holy power where the client lacks it", ResourceSample("PALADIN"), "powerWidth")
Equal("combo points there still", ResourceSample("DRUID"), "classWidth powerWidth")
Schema:Write(config, Options:Path("classPower", "extraMana"), true)
Equal("extra mana alone stands on power", ResourceSample("WARRIOR"), "extraMana powerWidth")
Schema:Write(config, Options:Path("classPower", "extraMana"), false)
AUI.can.classResources = true

function UnitClass()
	return "Mage", "MAGE"
end

-- The target frame ---------------------------------------------------------------------------------------------------

local function TargetPath(field)
	return Options:Path("target", field)
end

Equal("off by default", Schema:Read(config, TargetPath("enabled")), false)
Equal("its health fills from the right", Schema:Read(config, TargetPath("reverse")), true)
Equal("the player's from the left", Schema:Read(config, Path("reverse")), false)
Equal("buffs on", Schema:Read(config, TargetPath("buffs.enabled")), true)
Equal("the player's stay off", Schema:Read(config, Path("buffs.enabled")), false)
Equal("debuffs on", Schema:Read(config, TargetPath("debuffs.enabled")), true)
Equal("twenty debuffs", Schema:Read(config, TargetPath("debuffs.limit")), 20)
Equal("its portrait on the right", Schema:Read(config, TargetPath("portrait.side")), "RIGHT")
Equal("health at the upper left", Schema:Read(config, Options:SlotPath("target", 1, "anchor")), "TOPLEFT")
Equal("level and name at the upper right", Schema:Read(config, Options:SlotPath("target", 2, "content")), "levelName")
Equal("in its unit's color", Schema:Read(config, Options:SlotPath("target", 2, "colorMode")), "class")
Equal("power in its color", Schema:Read(config, Options:SlotPath("target", 3, "colorMode")), "power")
Equal("the player's slots stay custom", Schema:Read(config, Options:SlotPath("player", 1, "colorMode")), "custom")

local targetPreview = AUI.FramePreview:New(Options:Spec("target"))

targetPreview:Create(CreateFrame("Frame"))

for _, state in ipairs(AUI.FramePreview.OVERLAY_STATES) do
	width, height = targetPreview:Refresh(state, sampleTarget)
	Equal(state .. ": the target sample draws", width > 0 and height > 0, true)
end

-- The target's power bar and classification icon ------------------------------------------------------------------

local UnitFrame = AUI.UnitFrame

Equal("no power bar by default", UnitFrame:FrameHeight("target"), 36)
Equal("the player has none to turn on", UnitFrame:PowerHeight("player"), 0)
Equal("classification off by default", Schema:Read(config, TargetPath("indicators.classification.enabled")), false)
Schema:Write(config, TargetPath("power.enabled"), true)
Equal("the power bar's height", UnitFrame:PowerHeight("target"), 6)
Equal("the Height stays the health bar's", (UnitFrame:Heights("target")), 36)

local _, targetPower, targetSeparator = UnitFrame:Heights("target")

Equal("it adds to the frame", UnitFrame:FrameHeight("target"), 36 + targetSeparator + targetPower)
parts = {}
width, height = targetPreview:Refresh(nil, sampleTarget)
Equal("the sample is that tall", select(2, targetPreview.holder:GetSize()), UnitFrame:FrameHeight("target"))
Equal("the sample power bar is a part", partRegions.powerEnabled, targetPreview.power)
Schema:Write(config, TargetPath("power.enabled"), false)
targetPreview:Refresh(nil, sampleTarget)
Equal("off, the sample hides it", targetPreview.powerBackground:IsShown(), false)

AUI.UnitFrame.specs.target = Options:Spec("target")

local liveTarget = AUI.oUF:Spawn("target", "AeonUITarget")

liveTarget:ApplyLayout()
liveTarget:ApplyAppearance()
Equal("off, the live frame is the health's height", select(2, liveTarget:GetSize()), 36)
Equal("the power background hidden", liveTarget.PowerBackground:IsShown(), false)
Equal("and the line", liveTarget.Power.Separator:IsShown(), false)
Schema:Write(config, TargetPath("power.enabled"), true)
Schema:Write(config, TargetPath("indicators.classification.enabled"), true)
liveTarget:ApplyLayout()
liveTarget:ApplyAppearance()
Equal("on, the live frame grows", select(2, liveTarget:GetSize()), UnitFrame:FrameHeight("target"))
Equal("past the health's height", UnitFrame:FrameHeight("target") > 42, true)
Equal("a black line above the bar", liveTarget.Power.Separator:IsShown(), true)
Equal("the power background shows", liveTarget.PowerBackground:IsShown(), true)
Equal("in its colors", liveTarget.powerBackground, liveTarget.PowerBackground)
Equal("repainted by the palette's step", liveTarget.Power.PostUpdateColor, AUI.PowerColor.PostUpdateColor)
Equal("the classification icon exists", liveTarget.AeonClassification ~= nil, true)
Schema:Write(config, TargetPath("power.enabled"), false)
Schema:Write(config, TargetPath("indicators.classification.enabled"), false)

Frames.objects.target = liveTarget
Frames:SampleUnit("target", true)
Equal("edit mode shows the frame on the player", liveTarget.attributes.unit, "player")
Frames:SampleUnit("target", false)
Equal("and gives it back", liveTarget.attributes.unit, "target")
Frames:SampleUnit("target", true)
client:SetCombat(true)
Frames:SampleUnit("target", false)
Equal("in combat it waits", liveTarget.attributes.unit, "player")
client:SetCombat(false)
Frames:OnCombatEnded()
Equal("then gives it back", liveTarget.attributes.unit, "target")
Frames.objects.target = nil
Frames:SampleUnit("target", false)

-- The target's range fade ----------------------------------------------------------------------------------------------

local RangeFade = AUI.RangeFade
local rangeBase = TargetPath("fade.range.")
local targetExists, attackable, rangeResult = false, true, nil
local knownSpells = { [133] = true, [475] = true }
local rangeChecks, tickers = {}, {}
local unitExists, canAttack, spell, spellBook, timer = UnitExists, UnitCanAttack, C_Spell, C_SpellBook, C_Timer

function UnitExists()
	return targetExists
end

function UnitCanAttack()
	return attackable
end

C_Spell = {
	IsSpellInRange = function(spellID, unit)
		rangeChecks[#rangeChecks + 1] = spellID .. " " .. unit

		return rangeResult
	end,
}
C_SpellBook = {
	IsSpellKnownOrInSpellBook = function(spellID)
		return knownSpells[spellID] == true
	end,
}
C_Timer = {
	NewTicker = function(seconds, callback)
		local ticker = { seconds = seconds, callback = callback }

		function ticker.Cancel(self)
			self.cancelled = true
		end

		tickers[#tickers + 1] = ticker

		return ticker
	end,
}
Equal("Target's parts lie in the fade's layer", liveTarget.Bar:GetParent(), liveTarget.Content)
Equal("and its power bar", liveTarget.Power:GetParent(), liveTarget.Content)
Equal("and its portrait", liveTarget.PortraitWidgets.holder:GetParent(), liveTarget.Content)
Equal("and its indicators", liveTarget.IndicatorLayer:GetParent(), liveTarget.Content)
Equal("and its cast bar", liveTarget.CastBarView:GetParent(), liveTarget.Content)
Equal("and its auras", liveTarget.AuraDisplays.buffs.element.parent, liveTarget.Content)
Equal("the layer is not the frame", liveTarget.Content ~= liveTarget, true)
Equal("Player's parts stay on the frame", frame.Content, frame)
Equal("off by default", Schema:Read(config, rangeBase .. "enabled"), false)
Equal("at half", Schema:Read(config, rangeBase .. "alpha"), 50)
Equal("Player has no range fade", RangeFade:Alpha("player"), nil)
Equal("nor Target by default", RangeFade:Alpha("target"), nil)
Schema:Write(config, rangeBase .. "enabled", true)
Equal("Target has", RangeFade:Alpha("target"), 0.5)

local spawnedFrames = AUI.Frames.objects

AUI.Frames.objects = { target = liveTarget }

-- Never enabled, nothing runs.
Schema:Write(config, rangeBase .. "enabled", false)
RangeFade:UpdateAll()
Equal("off, no events", RangeFade.following, false)
Equal("off, no ticker", RangeFade.ticker, nil)
Equal("off, no spring", liveTarget.rangeFade, nil)
Equal("off, nothing measured", #rangeChecks, 0)

Schema:Write(config, rangeBase .. "enabled", true)
RangeFade:UpdateAll()
Equal("on, follows the target", RangeFade.following, true)
Equal("the first known enemy spell", RangeFade.harmful, 133)
Equal("the first known friendly spell", RangeFade.helpful, 475)
Equal("no target, no ticker", RangeFade.ticker, nil)
Equal("no target, nothing measured", #rangeChecks, 0)

targetExists = true
RangeFade:UpdateAll()
Equal("a target starts the ticker", RangeFade.ticker ~= nil, true)
Equal("every 0.2 seconds", tickers[1].seconds, 0.2)
Equal("measured with the enemy spell", rangeChecks[#rangeChecks], "133 target")
Equal("nil counts as in range", liveTarget.rangeFade, nil)

rangeResult = false
tickers[1].callback()
Equal("beyond range, faded", liveTarget.Content:GetAlpha(), 0.5)
Equal("on the spring", liveTarget.rangeFade.spring.moves, 1)
Equal("the frame itself stays", liveTarget:GetAlpha(), 1)
tickers[1].callback()
Equal("no change, no new motion", liveTarget.rangeFade.spring.moves, 1)

rangeResult = true
tickers[1].callback()
Equal("in range, back to full", liveTarget.Content:GetAlpha(), 1)
Equal("moved back", liveTarget.rangeFade.spring.moves, 2)

attackable = false
rangeResult = false
tickers[1].callback()
Equal("a friend uses the friendly spell", rangeChecks[#rangeChecks], "475 target")
Equal("and fades the same", liveTarget.Content:GetAlpha(), 0.5)
attackable = true
tickers[1].callback()

rangeResult = Secret()
tickers[1].callback()
Equal("a secret range stops the spring", liveTarget.rangeFade.spring.stopped, true)
Equal("and goes to the client", liveTarget.rangeFade.secret, true)
rangeResult = true
tickers[1].callback()
Equal("readable again, it jumps", liveTarget.rangeFade.spring.jumps, 1)
Equal("to full", liveTarget.Content:GetAlpha(), 1)

attackable = Secret()
rangeResult = false
Equal("a secret reaction cannot be measured", RangeFade:InRange("target"), nil)
attackable = true

rangeResult = false
tickers[1].callback()
targetExists = false
RangeFade:UpdateAll()
Equal("no target stops the ticker", tickers[1].cancelled, true)
Equal("and forgets it", RangeFade.ticker, nil)
Equal("and restores the frame", liveTarget.Content:GetAlpha(), 1)

targetExists = true
RangeFade:UpdateAll()
Equal("a new target starts a new ticker", #tickers, 2)
Schema:Write(config, rangeBase .. "enabled", false)
RangeFade:UpdateAll()
Equal("turned off, the ticker stops", tickers[2].cancelled, true)
Equal("the events stop", RangeFade.following, false)
Equal("full opacity", liveTarget.Content:GetAlpha(), 1)
Schema:Write(config, rangeBase .. "enabled", true)
rangeResult = false
RangeFade:UpdateAll()
Equal("turned on again, it follows", RangeFade.following, true)
Equal("and ticks", #tickers, 3)
Equal("and fades", liveTarget.Content:GetAlpha(), 0.5)
Schema:Write(config, rangeBase .. "alpha", 30)
tickers[3].callback()
Equal("a new strength applies", liveTarget.Content:GetAlpha(), 0.3)
Schema:Write(config, rangeBase .. "alpha", nil)
targetExists = false
RangeFade:UpdateAll()
RangeFade:Follow(false)

for class, list in pairs(AUI.RangeSpells.harmful) do
	Equal(class .. " has an enemy spell", #list > 0, true)
end

AUI.Frames.objects = spawnedFrames
UnitExists, UnitCanAttack, C_Spell, C_SpellBook, C_Timer = unitExists, canAttack, spell, spellBook, timer

-- The target's cast bar -----------------------------------------------------------------------------------------------

local CastBar, UnitCastBar = AUI.CastBar, AUI.UnitCastBar
local castBase = UnitCastBar:Base("target")
local view = liveTarget.CastBarView
local castBar = view.bar

AUI.can.castBar = false
Equal("none where the client cannot draw one", UnitCastBar:Has(Options:Spec("target")), false)
AUI.can.castBar = true
Equal("off by default", Schema:Read(config, castBase .. "enabled"), false)
Equal("no room taken while off", UnitCastBar:Extent("target"), 0)
Equal("the player's frame has none", UnitCastBar:Extent("player"), 0)
Equal("below the frame by four", Schema:Read(config, castBase .. "y"), -4)
Equal("its icon on", Schema:Read(config, castBase .. "icon"), true)
Equal("the standalone bar's icon stays off", Schema:Read(config, "castBar.icon"), false)
Equal("oUF's element is the view's bar", liveTarget.Castbar, castBar)
Equal("the view reads its own settings", view.base, castBase)
Equal("no aids on a frame's bar", view.aids, false)
Equal("the standalone bar's look stays its own", Schema:Read(config, "castBar.texture"),
	Schema:Read(config, Options.ALL .. "castBars.texture"))

Schema:Write(config, Options.ALL .. "castBars.name.size", 20)
Equal("the look follows All Frames", Schema:Read(config, castBase .. "name.size"), 20)
Equal("not the standalone bar", Schema:Read(config, "castBar.name.size"), 14)
Schema:Write(config, Options.ALL .. "castBars.name.size", 14)
Schema:Write(config, TargetPath("bars.borderStyle"), "THIN_LINE")
Equal("the border follows the frame's", UnitFrame:BarLook("target", "castBar.bars").borderStyle, "THIN_LINE")
Equal("so does the shadow", UnitFrame:BarLook("target", "castBar.bars").shadow, nil)
Schema:Write(config, Options:Path("target", "bars.showShadow"), true)
Equal("on with its frame", UnitFrame:BarLook("target", "castBar.bars").shadow.size, 4)
Schema:Write(config, Options:Path("target", "castBar.bars.showShadow"), false)
Equal("or off alone", UnitFrame:BarLook("target", "castBar.bars").shadow, nil)
Schema:Write(config, Options:Path("target", "castBar.bars.showShadow"), nil)
Schema:Write(config, Options:Path("target", "bars.showShadow"), nil)
Schema:Write(config, TargetPath("bars.borderStyle"), nil)

Schema:Write(config, castBase .. "enabled", true)
Equal("its reach below the frame", UnitCastBar:Extent("target"), 20)
Equal("the auras clear it", select(2, AUI.Auras:Clearance("target")) >= 20, true)
liveTarget:ApplyAppearance()
Equal("the width matches the frame", select(1, view:GetSize()), 270)
Schema:Write(config, castBase .. "matchWidth", false)
Schema:Write(config, castBase .. "width", 300)
liveTarget:ApplyAppearance()
Equal("or its own", select(1, view:GetSize()), 300)
Schema:Write(config, castBase .. "matchWidth", true)
Equal("the hold comes from the look", castBar.timeToHold, 0.6)

castBar.Show(castBar)
Equal("oUF's show shows the view", view:IsShown(), true)
castBar.PostCastStart(castBar, "target", 1, false, "Frostbolt")
Equal("the time runs", view.binding.enabled, true)
castBar.PostCastInterrupted(castBar)
Equal("feedback covers the fill", view.failed:GetAlpha(), 1)
Equal("the time hides", view.time:IsShown(), false)
castBar.Hide(castBar)
Equal("oUF's hide hides the view", view:IsShown(), false)
Equal("and stops the time", view.binding.enabled, false)
Equal("the feedback clears", view.failed:GetAlpha(), 0)

Schema:Write(config, castBase .. "alwaysShow", true)
castBar.Show(castBar)
castBar:SetScript("OnUpdate", print)
castBar.Hide(castBar)
Equal("Always Show keeps the view", view:IsShown(), true)
Equal("and stops the update script", castBar:GetScript("OnUpdate"), nil)
castBar.Show(castBar)
Equal("a cast gives it back", castBar:GetScript("OnUpdate"), print)
castBar.Hide(castBar)
Schema:Write(config, castBase .. "alwaysShow", false)

Schema:Write(config, Options.ALL .. "castBars.fade", true)
Equal("no image without Fade Out", view.buffered, false)
liveTarget:ApplyAppearance()
Equal("drawn as one image from the setting, not the fade", view.buffered, true)
castBar.Show(castBar)
castBar.Hide(castBar)
Equal("Fade Out keeps the view while fading", view:IsShown(), true)
Equal("playing", view.fade.playing, true)
castBar.Hide(castBar)
Equal("a second hide changes nothing", view.fading, true)
view.fade.scripts.OnFinished()
Equal("then it hides", view:IsShown(), false)
Equal("still one image for the next", view.buffered, true)
castBar.Show(castBar)
castBar.Hide(castBar)
castBar.Show(castBar)
Equal("a new cast stops the fade", view.fade.playing, false)
Equal("at full opacity", view:GetAlpha(), 1)
castBar.Hide(castBar)
view.fade.scripts.OnFinished()
Schema:Write(config, Options.ALL .. "castBars.fade", false)
liveTarget:ApplyAppearance()
Equal("turned off, drawn normally again", view.buffered, false)

parts = {}
targetPreview:Refresh(AUI.FramePreview.CAST_STATES[#AUI.FramePreview.CAST_STATES], sampleTarget)
Equal("the sample bar is a part", partRegions.castEnabled, targetPreview.cast.bar)
Equal("Interrupted draws its cover", targetPreview.cast.failed:GetAlpha(), 1)
Schema:Write(config, castBase .. "enabled", false)
targetPreview:Refresh(nil, sampleTarget)
Equal("off, no sample bar", targetPreview.cast:IsShown(), false)

-- The target of target -----------------------------------------------------------------------------------------------

local function TotPath(field)
	return Options:Path("targettarget", field)
end

Equal("the target of target is off by default", Schema:Read(config, TotPath("enabled")), false)
Equal("120 wide", Schema:Read(config, TotPath("width")), 120)
Equal("24 tall", Schema:Read(config, TotPath("height")), 24)
Equal("filling from the left", Schema:Read(config, TotPath("reverse")), false)
Equal("no power bar by default", Schema:Read(config, TotPath("power.enabled")), false)
Equal("three slots", Schema:Field(Options:SlotPath("targettarget", 3, "content")) ~= nil, true)
Equal("not four", Schema:Field(Options:SlotPath("targettarget", 4, "content")), nil)
Equal("its name at the left, inside", Schema:Read(config, Options:SlotPath("targettarget", 1, "content")) .. " "
	.. Schema:Read(config, Options:SlotPath("targettarget", 1, "anchor")), "name LEFT")
Equal("no slot carries the status", Schema:Read(config, TotPath("text.status")), 0)
Equal("the Status Line on", Schema:Read(config, TotPath("text.statusLine")), true)
Equal("the target has no Status Line", Schema:Field(TargetPath("text.statusLine")), nil)
Equal("a small raid marker", Schema:Read(config, TotPath("indicators.raid.size")), 14)
Equal("no portrait", Schema:Field(TotPath("portrait.enabled")), nil)
Equal("no auras", Schema:Field(TotPath("buffs.enabled")), nil)
Equal("no overlays", Schema:Field(TotPath("overlays.absorb.enabled")), nil)
local totPlace, targetPlace = Options:Spec("targettarget").position, Options:Spec("target").position

Equal("bottoms level with the target's", totPlace.y - 24 / 2, targetPlace.y - 36 / 2)
Equal("8 right of the target", totPlace.x - 120 / 2 - (targetPlace.x + 270 / 2), 8)

Equal("needs its Status Line", Text:NeedsStatusLine("targettarget"), true)
Equal("the target never does", Text:NeedsStatusLine("target"), false)
Schema:Write(config, TotPath("text.status"), 1)
Equal("a name slot cannot carry the status", Text:NeedsStatusLine("targettarget"), true)
Schema:Write(config, Options:SlotPath("targettarget", 1, "content"), "health")
Equal("a health slot can", Text:NeedsStatusLine("targettarget"), false)
Schema:Write(config, TotPath("text.status"), nil)
Schema:Write(config, Options:SlotPath("targettarget", 1, "content"), nil)
Schema:Write(config, TotPath("text.statusLine"), false)
Equal("off, never", Text:NeedsStatusLine("targettarget"), false)
Schema:Write(config, TotPath("text.statusLine"), nil)

AUI.UnitFrame.specs.targettarget = Options:Spec("targettarget")

local liveTot = AUI.oUF:Spawn("targettarget", "AeonUITargetTarget")

liveTot:ApplyLayout()
liveTot:ApplyAppearance()
Equal("the live frame's size", table.concat({ liveTot:GetSize() }, "x"), "120x24")
Equal("no cast bar", liveTot.CastBarView, nil)
Equal("no aura displays", liveTot.AuraDisplays, nil)
Equal("its raid marker runs", liveTot.elementsOn.RaidTargetIndicator, true)
Equal("its name tagged", liveTot.TextSlots[1].tag ~= nil, true)
Equal("its Status Line tagged", liveTot.StatusLine.tag, "[aui:status]")
Equal("and shown", liveTot.StatusLine:IsShown(), true)
Equal("at the bar's right", liveTot.StatusLine.points[1][1], "RIGHT")
Equal("the name slot shares its row", liveTot.middleSlots[1], true)

local nameWidth = liveTot.slotWidths[1]

liveTot.StatusLine:SetText(DEAD)
liveTot.StatusLine.stringWidth = 30
liveTot.StatusLine:UpdateTag()
Equal("a status shortens the name", liveTot.TextSlots[1].width, nameWidth - 38)
liveTot.StatusLine:SetText("")
liveTot.StatusLine:UpdateTag()
Equal("no status gives the room back", liveTot.TextSlots[1].width, nameWidth)
Schema:Write(config, TotPath("text.statusLine"), false)
liveTot:ApplyAppearance()
Equal("off, the line hides", liveTot.StatusLine:IsShown(), false)
Equal("untagged", liveTot.StatusLine.tag, nil)
Schema:Write(config, TotPath("text.statusLine"), nil)
liveTot:ApplyAppearance()

local objects = Frames.objects

Frames.objects = { targettarget = liveTot }
liveTot.fullUpdates = 0
Frames:OnTargetOfTargetChanged("UNIT_TARGET", "party1")
Equal("another unit's target is ignored", liveTot.fullUpdates, 0)
Frames:OnTargetOfTargetChanged("UNIT_TARGET", "target")
Equal("the target's new target redraws it", liveTot.fullUpdates, 1)
Frames:OnTargetOfTargetChanged("PLAYER_TARGET_CHANGED")
Equal("a new target redraws it", liveTot.fullUpdateEvent, "PLAYER_TARGET_CHANGED")
liveTot:Hide()
Frames:OnTargetOfTargetChanged("PLAYER_TARGET_CHANGED")
Equal("hidden, it waits for oUF's show", liveTot.fullUpdates, 2)
liveTot:Show()
Frames.objects = objects

local totPreview = AUI.FramePreview:New(Options:Spec("targettarget"))

parts, partRegions = {}, {}
totPreview:Create(CreateFrame("Frame"))
width, height = totPreview:Refresh(AUI.FramePreview.STATES[1], sampleTarget)
Equal("the sample draws", width > 0 and height > 0, true)
Equal("full, no Status Line", totPreview.StatusLine:IsShown(), false)
totPreview:Refresh(AUI.FramePreview.STATES[3], sampleTarget)
Equal("dead, the sample shows it", totPreview.StatusLine.text, DEAD)
Equal("as a part", partRegions.statusLine, totPreview.StatusLine)
Equal("the sample's name is you", totPreview.TextSlots[1].text, "Alex")

Equal("without it, target changes are not followed", registered.PLAYER_TARGET_CHANGED, nil)
TargetFrame = { totFrame = CreateFrame("Button", "TargetFrameToT", UIParent) }
Frames.started, Frames.objects, registered = false, {}, {}
Schema:Write(config, Path("enabled"), nil)
Schema:Write(config, TotPath("enabled"), true)
Frames:Start()
Equal("spawned by its global name", spawned[#spawned], "AeonUITargetTarget")
Equal("a new target is followed", registered.PLAYER_TARGET_CHANGED, Frames.OnTargetOfTargetChanged)
Equal("and the target's new target", registered.UNIT_TARGET, Frames.OnTargetOfTargetChanged)
Equal("no reload needed", Frames:ReloadNeeded(), false)
Equal("Blizzard's target of target is invisible", TargetFrame.totFrame.alpha, 0)
Equal("and lets clicks through", TargetFrame.totFrame.mouse, false)
Equal("but is never hidden, which its update would undo", TargetFrame.totFrame:IsShown(), true)

print(("check_unitframes: %d checks passed"):format(client.checks))
