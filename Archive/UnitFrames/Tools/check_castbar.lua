-- Checks Frames/CastBar.lua outside the game: cast bar settings and their defaults, size and position for the
-- player's bar and attached bars, the space kept for the time, empowered stage parts, spell name shortening, what
-- each setting shows and hides, the time formats handed to the client, oUF's callbacks, channel ticks, the
-- interrupt lookup, colors and cooldown mark, the cast target and the important-spell glow.
-- Run from any directory with Lua 5.1: lua Tools/check_castbar.lua
-- Frames are stand-ins that record the last call of each method; drawing is not exercised here.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

UNKNOWN = "Unknown"
SlashCmdList = {}
C_AddOns = {
	GetAddOnMetadata = function() end,
}
Enum = {
	DurationTextBindingProperty = { RemainingDuration = 0, ElapsedDuration = 2, TotalDuration = 4 },
	StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 },
	SpellBookSpellBank = { Player = 0, Pet = 1 },
}
UIParent = {}

local secret = {}

function issecretvalue(value)
	return value == secret
end

function strlenutf8(text)
	local _, count = text:gsub("[^\128-\191]", "")

	return count
end

function CreateColor(r, g, b, a)
	return { r = r, g = g, b = b, a = a }
end

function GetNetStats()
	return 0, 0, 0, 48
end

local playerClass = "MAGE"

function UnitClass()
	return "Mage", playerClass
end

-- Spells the character knows, by bank.
local known = { [0] = {}, [1] = {} }
C_SpellBook = {
	IsSpellKnownOrInSpellBook = function(spellID, bank)
		return known[bank or 0][spellID] == true
	end,
}

---A duration object stand-in.
local function Duration(total, elapsed)
	return {
		GetTotalDuration = function()
			return total
		end,
		GetElapsedDuration = function()
			return elapsed
		end,
		GetRemainingDuration = function()
			return total - elapsed
		end,
		IsZero = function()
			return total == elapsed
		end,
	}
end

local cooldown, castDuration, channelDuration = nil, nil, nil
local important = false
C_Spell = {
	GetSpellCooldownDuration = function()
		return cooldown
	end,
	IsSpellImportant = function()
		return important
	end,
}

function UnitCastingDuration()
	return castDuration
end

function UnitChannelDuration()
	return channelDuration
end

local channelInfo = {}

function UnitChannelInfo()
	return unpack(channelInfo)
end

local spellTarget = {}

function UnitShouldDisplaySpellTargetName()
	return spellTarget.shown == true
end

function UnitSpellTargetName()
	return spellTarget.name
end

function UnitSpellTargetClass()
	return spellTarget.class
end

C_ClassColor = {
	GetClassColor = function(class)
		if class == "PRIEST" then
			return {
				GetRGB = function()
					return 1, 1, 1
				end,
			}
		end
	end,
}

local formatters = 0
C_StringUtil = {
	CreateNumericRuleFormatter = function()
		formatters = formatters + 1

		return {
			SetBreakpoints = function(self, breakpoints)
				self.breakpoints = breakpoints
			end,
		}
	end,
}

local function Binding()
	return {
		SetTextFormat = function(self, format, components)
			self.format, self.components = format, components
		end,
	}
end

C_DurationUtil = { CreateDurationTextBinding = Binding }

---A frame, bar, texture or font string stand-in: every method records its arguments under `last`, with the getters
---the cast bar code reads.
local function Region()
	local region = { last = {}, shown = true, level = 1, minimum = 0, maximum = 1, value = 0, width = 100,
		alpha = 1, hooks = {}, scripts = {} }

	function region:SetShown(shown)
		self.shown = shown == true
	end

	function region:Show()
		self.shown = true
	end

	function region:Hide()
		self.shown = false
	end

	function region:IsShown()
		return self.shown
	end

	function region:SetAlpha(alpha)
		self.alpha = alpha
	end

	function region:SetFrameLevel(level)
		self.level = level
	end

	function region:GetFrameLevel()
		return self.level
	end

	function region:SetMinMaxValues(minimum, maximum)
		self.minimum, self.maximum = minimum, maximum
	end

	function region:GetMinMaxValues()
		return self.minimum, self.maximum
	end

	function region:SetValue(value)
		self.value = value
	end

	function region:GetValue()
		return self.value
	end

	function region:GetWidth()
		return self.width
	end

	function region:SetWidth(width)
		self.width = width
	end

	function region:SetReverseFill(reverse)
		self.reverse = reverse
	end

	function region:GetReverseFill()
		return self.reverse == true
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

	function region:GetStatusBarTexture()
		self.fill = rawget(self, "fill") or Region()

		return self.fill
	end

	function region:CreateTexture()
		local texture = Region()

		texture.parent = self

		return texture
	end

	function region:CreateFontString()
		return Region()
	end

	function region:CreateAnimationGroup()
		local group = Region()

		function group:CreateAnimation()
			return Region()
		end

		function group:Play()
			self.playing = true
		end

		function group:Stop()
			self.playing = false
		end

		return group
	end

	function region:SetAlphaFromBoolean(flag, shown, hidden)
		self.last.SetAlphaFromBoolean = { flag, shown, hidden }
		self.alpha = flag and shown or hidden
	end

	function region:GetHeight()
		return 16
	end

	function region:GetParent()
		return self.parent
	end

	function region:HookScript(script, handler)
		self.hooks[script] = handler
	end

	function region:SetScript(script, handler)
		self.scripts[script] = handler
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
assert(loadfile(root .. "Core/Core.lua"))("AeonUI", AUI)
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
AUI.oUF = { colors = { class = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } } } }
AUI.Media = {
	FLAT = "flat",
	SetBarTexture = function(_, bar, choice)
		bar.texture = choice
	end,
	Font = function(_, name)
		return name
	end,
	FontFlags = function(_, outline)
		return outline == "NONE" and "" or outline
	end,
}

function AUI:Pixel()
	return 1
end

local registered = {}
AUI.Events = {
	Register = function(_, event, owner, handler)
		registered[event] = function(...)
			handler(owner, event, ...)
		end
	end,
}

assert(loadfile(root .. "Profile/Schema.lua"))("AeonUI", AUI)
assert(loadfile(root .. "Frames/CastData.lua"))("AeonUI", AUI)
assert(loadfile(root .. "Frames/CastBar.lua"))("AeonUI", AUI)

local CastBar, Schema = AUI.CastBar, AUI.Schema

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

local function Near(name, actual, expected)
	Equal(name, math.abs(actual - expected) < 1e-9, true)
end

local function Points(region)
	local list = {}
	for _, point in ipairs(rawget(region, "points") or {}) do
		list[#list + 1] = table.concat({ tostring(point[1]), tostring(point[3]), tostring(point[4]), tostring(point[5]) },
			" ")
	end

	return table.concat(list, ",")
end

-- Settings ------------------------------------------------------------------------------------------------

local config = Schema:Defaults()
Equal("no cast bar on target of target", CastBar:Resolve(config, "targettarget"), nil)
Equal("no cast bar on the power bar", CastBar:Resolve(config, "playerPower"), nil)

local player = CastBar:Resolve(config, "player")
Equal("player bar stands alone", player.attached, false)
Equal("player width", player.width, 386)
Equal("player height", player.height, 16)
Equal("player position", player.x .. "," .. player.y, "0,-254")
Equal("flat texture", player.texture, "flat")
Equal("fill color", player.color.g, 0.71)
Equal("gradient on", player.gradient, true)
Equal("gradient end", player.gradientColor.b, 0.224)
Equal("gradient direction", player.gradientDirection, "HORIZONTAL")
Equal("background white", player.background.r, 1)
Equal("background half opaque", player.background.a, 0.5)
Equal("one-pixel border", player.border, 1)
Equal("spark on", player.spark, true)
Equal("smooth on", player.smooth, true)
Equal("no player icon", player.icon, false)
Equal("name size", player.name.size, 14)
Equal("time size", player.time.size, 14)
Equal("time remaining", player.time.format, "remaining")
Equal("Slug without an outline", player.outline, "SLUG")
Equal("shadow on", player.shadow, true)
Equal("not interruptible red", player.notInterruptible.r, 0.8)
Equal("interrupted red", player.interrupted.g, 0.1)
Equal("hold time", player.holdTime, 0.6)
Equal("latency on", player.latency, true)
Equal("latency text off", player.latencyText, false)
Equal("stage colors on", player.empowerColors, true)
Equal("first stage gray", player.stage["1"].r, 0.506)
Equal("last stage gold", player.stage["4"].g, 0.71)
Equal("stage label off", player.stageLabel, false)
Equal("font follows the frame text", player.font, "Expressway")

local target = CastBar:Resolve(config, "target")
Equal("target attached", target.attached, true)
Equal("target below", target.side, "below")
Equal("target icon", target.icon, true)
Equal("target matches width", target.matchWidth, true)
Equal("no latency off the player", target.latency, nil)
Equal("focus above", CastBar:Resolve(config, "focus").side, "above")
Equal("focus without icon", CastBar:Resolve(config, "focus").icon, false)
Equal("boss below", CastBar:Resolve(config, "boss").side, "below")
Equal("boss icon", CastBar:Resolve(config, "boss").icon, true)
Equal("time format choices", #Schema.choices.timeFormat, 4)
Equal("an unknown side is refused", Schema:CheckValue("frames.target.castbar.side", "left"), false)

-- Geometry ------------------------------------------------------------------------------------------------

Equal("player takes no frame space", CastBar:Extent(config, "player"), 0)
Equal("attached bar takes its gap and height", CastBar:Extent(config, "target"), 20)
Schema:Write(config, "frames.target.castbar.enabled", false)
Equal("a hidden bar takes none", CastBar:Extent(config, "target"), 0)
Schema:Write(config, "frames.target.castbar.enabled", true)

local width, height = CastBar:Size(target, 300)
Equal("matching the frame", width .. "x" .. height, "300x16")
target.matchWidth = false
Equal("own width", (CastBar:Size(target, 300)), 270)
target.matchWidth = true
Equal("player ignores the frame", (CastBar:Size(player, 300)), 386)

local function Point(settings)
	return table.concat({ CastBar:Points(settings) }, " ")
end

Equal("player on the screen", Point(player), "CENTER CENTER 0 -254")
Equal("below the frame", Point(target), "TOP BOTTOM 0 -4")
target.side, target.x, target.y = "above", 5, 2
Equal("above the frame with offsets", Point(target), "BOTTOM TOP 5 6")
target.side, target.x, target.y = "below", 0, 0

Equal("time space", CastBar:TimeReserve(player), 14 * 2.5 + 4)
player.time.format = "elapsedTotal"
Equal("time space for two values", CastBar:TimeReserve(player), 14 * 5.5 + 4)
player.time.format = "remaining"
player.time.enabled = false
Equal("no space without the time", CastBar:TimeReserve(player), 0)
player.time.enabled = true

-- Stages and names ----------------------------------------------------------------------------------------

local boundaries = CastBar:Boundaries({ 0.3, 0.25, 0.25 })
Near("first boundary", boundaries[1], 0.3)
Near("second boundary", boundaries[2], 0.55)
Near("third boundary", boundaries[3], 0.8)
Equal("parts add the rest of the bar", #CastBar:Segments(boundaries), 4)
Equal("no extra part at the end", #CastBar:Segments({ 0.5, 1 }), 2)
Equal("boundaries never pass the bar", CastBar:Boundaries({ 0.7, 0.7 })[2], 1)
Equal("no stage yet", CastBar:StageReached(boundaries, 0.1), 0)
Equal("two stages", CastBar:StageReached(boundaries, 0.6), 2)
Equal("all stages", CastBar:StageReached(boundaries, 0.95), 3)

Equal("short names stay", CastBar:Shorten("Frostbolt", 20), "Frostbolt")
Equal("no limit", CastBar:Shorten("Frostbolt", 0), "Frostbolt")
Equal("long names are cut", CastBar:Shorten("Pyroblast", 4), "Pyro…")
Equal("letters, not bytes", CastBar:Shorten("Ölstrahl", 3), "Öls…")

-- Apply ---------------------------------------------------------------------------------------------------

local anchor = Region()
local widgets = CastBar:Create(Region())

Equal("starts hidden", widgets.bar.shown, false)
Equal("holder starts hidden", widgets.holder.shown, false)
Equal("stage colors clip to the fill", widgets.zones.last.SetClipsChildren[1], true)

player = CastBar:Resolve(config, "player")
CastBar:Apply(widgets, player, UIParent, 270)
Equal("holder size", widgets.holder.last.SetSize[1] .. "x" .. widgets.holder.last.SetSize[2], "386x16")
Equal("holder on the screen", Points(widgets.holder), "CENTER CENTER 0 -254")
Equal("strata", widgets.holder.last.SetFrameStrata[1], "MEDIUM")
Equal("idle holder stays hidden", widgets.holder.shown, false)
Equal("no icon", widgets.icon.shown, false)
Equal("bar fills the holder", widgets.bar.last.SetAllPoints[1], widgets.holder)
Equal("gradient fill", widgets.bar:GetStatusBarTexture().last.SetGradient[1], "HORIZONTAL")
Equal("gradient end color", widgets.bar:GetStatusBarTexture().last.SetGradient[3].b, 0.224)
Equal("background opacity", widgets.background.last.SetVertexColor[4], 0.5)
Equal("border outside the bar", Points(widgets.border[1]), "BOTTOMLEFT TOPLEFT -1 0,BOTTOMRIGHT TOPRIGHT 1 0")
Equal("border shown", widgets.border[1].shown, true)
Equal("spark shown", widgets.spark.alpha, 1)
Equal("spark on the fill's edge", widgets.spark.points[1][3], "RIGHT")
Equal("name font", widgets.text.last.SetFont[1] .. " " .. widgets.text.last.SetFont[2], "Expressway 14")
Equal("Slug flag", widgets.text.last.SetFont[3], "SLUG")
Equal("text shadow", widgets.text.last.SetShadowOffset[1] .. "," .. widgets.text.last.SetShadowOffset[2], "1,-1")
Equal("name stops before the time", widgets.text.points[2][4], -(14 * 2.5 + 4))
Equal("latency shown", widgets.safeZone.shown, true)
Equal("latency color opacity", widgets.safeZone.last.SetVertexColor[4], 0.4)
Equal("latency text off", widgets.latency.shown, false)
Equal("red while not interruptible", widgets.locked.last.SetColorTexture[1], 0.8)

player.alwaysShow = true
CastBar:Apply(widgets, player, UIParent, 270)
Equal("always show keeps the holder", widgets.holder.shown, true)
widgets.bar.hooks.OnHide()
Equal("holder stays after a cast", widgets.holder.shown, true)
player.alwaysShow = false
widgets.bar.hooks.OnHide()
Equal("holder hides after a cast", widgets.holder.shown, false)
widgets.bar.hooks.OnShow()
Equal("holder shows with a cast", widgets.holder.shown, true)
player.enabled = false
CastBar:Apply(widgets, player, UIParent, 270)
Equal("a hidden bar hides its holder", widgets.holder.shown, false)
player.enabled = true

player.gradient, player.spark, player.border = false, false, 0
player.outline, player.shadow, player.reverse = "OUTLINE", false, true
CastBar:Apply(widgets, player, UIParent, 270)
Equal("one fill color", widgets.bar.last.SetStatusBarColor[2], 0.71)
Equal("spark hidden", widgets.spark.alpha, 0)
Equal("no border", widgets.border[1].shown, false)
Equal("outline", widgets.text.last.SetFont[3], "OUTLINE")
Equal("no shadow", widgets.text.last.SetShadowOffset[1], 0)
Equal("reversed fill", widgets.bar.reverse, true)
Equal("spark follows a reversed fill", widgets.spark.points[1][3], "LEFT")

target = CastBar:Resolve(config, "target")
widgets = CastBar:Create(anchor)
CastBar:Apply(widgets, target, anchor, 270)
Equal("attached under the frame", Points(widgets.holder), "TOP BOTTOM 0 -4")
Equal("as wide as the frame", widgets.holder.last.SetSize[1], 270)
Equal("icon shown", widgets.icon.shown, true)
Equal("square icon", widgets.icon.last.SetSize[1] .. "x" .. widgets.icon.last.SetSize[2], "16x16")
Equal("icon on the left", Points(widgets.icon), "TOPLEFT nil nil nil")
Equal("bar starts after the icon", Points(widgets.bar), "TOPLEFT TOPLEFT 16 0,BOTTOMRIGHT BOTTOMRIGHT 0 0")
Equal("no latency on target", widgets.safeZone.shown, false)
target.iconSide = "RIGHT"
CastBar:Apply(widgets, target, anchor, 270)
Equal("icon on the right", Points(widgets.bar), "TOPLEFT TOPLEFT 0 0,BOTTOMRIGHT BOTTOMRIGHT -16 0")
target.name.enabled, target.time.enabled = false, false
CastBar:Apply(widgets, target, anchor, 270)
Equal("name hidden", widgets.text.shown, false)
Equal("time hidden", widgets.time.shown, false)

-- Stages --------------------------------------------------------------------------------------------------

widgets = CastBar:Create(Region())
CastBar:Apply(widgets, player, UIParent, 270)
CastBar:PlaceStages(widgets, CastBar:Boundaries({ 0.3, 0.25, 0.25 }), 100)
Equal("four parts", #widgets.stages, 4)
Near("first part", widgets.stages[1].width, 30)
Near("last part runs to the end", widgets.stages[4].width, 20)
Equal("first part gray", widgets.stages[1].last.SetVertexColor[1], 0.506)
Equal("third part orange", widgets.stages[3].last.SetVertexColor[3], 0.11)
Equal("reversed parts start from the right", widgets.stages[2].points[1][1], "TOPRIGHT")
Near("second part starts after the first", widgets.stages[2].points[1][4], -30)
CastBar:PlaceStages(widgets, CastBar:Boundaries({ 0.2, 0.2, 0.2, 0.2, 0.1 }), 100)
Equal("parts are added as needed", #widgets.stages, 6)
Equal("later parts take the last color", widgets.stages[6].last.SetVertexColor[1], 1)
CastBar:PlaceStages(widgets, CastBar:Boundaries({ 0.5 }), 100)
Equal("unused parts hide", widgets.stages[3].shown, false)

-- Time formats --------------------------------------------------------------------------------------------

local binding = Binding()
CastBar:SetTimeFormat(binding, "remaining")
Equal("remaining", binding.format, "{}")
Equal("remaining component", binding.components[1].property, 0)
Equal("one decimal", binding.components[1].formatter.breakpoints[1].format, "%.1f")
CastBar:SetTimeFormat(binding, "elapsedTotal")
Equal("elapsed of total", binding.format, "{} / {}")
Equal("elapsed first", binding.components[1].property, 2)
Equal("total second", binding.components[2].property, 4)
CastBar:SetTimeFormat(binding, "remainingTotal")
Equal("remaining first", binding.components[1].property, 0)
Equal("one shared formatter", formatters, 1)

-- oUF callbacks -------------------------------------------------------------------------------------------

local frame = {}
widgets = CastBar:Create(Region())
CastBar:Attach(frame, widgets)
player = CastBar:Resolve(config, "player")
player.latencyText = true
CastBar:Apply(widgets, player, UIParent, 270)
CastBar:ApplyElement(widgets, player)

local bar = frame.Castbar
Equal("element is the bar", bar, widgets.bar)
Equal("time sub-widget", bar.Time, widgets.time)
Equal("hold time", bar.timeToHold, 0.6)
Equal("smooth", bar.smoothing, 1)
Equal("time binding format", bar.Time.binding.format, "{}")
Equal("no shield: the fill turns red instead", rawget(bar, "Shield"), nil)

bar.UpdatePips(bar, { 0.3, 0.25, 0.25 })
bar:PostCastStart("player", 1, secret, "Pyroblast")
Equal("red from the secret flag", widgets.locked.last.SetAlphaFromBoolean[1], secret)
Equal("stage colors for an empowered cast", widgets.zones.shown, true)
Equal("latency text", widgets.latency.last.SetFormattedText[2], 48)
Equal("feedback cleared", widgets.failed.shown, false)
bar:PostCastStart("player", 1, false, "Pyroblast")
Equal("no stage colors for an ordinary cast", widgets.zones.shown, false)

player.name.maxLength = 4
bar.Text:SetText("Pyroblast")
bar:PostCastStart("player", 1, false, "Pyroblast")
Equal("name cut", bar.Text.text, "Pyro…")
bar.Text:SetText(secret)
bar:PostCastStart("player", 1, false, secret)
Equal("a hidden name is left to the client", bar.Text.text, secret)

player.classColor = true
bar:PostCastStart("player", 1, false, "Pyroblast")
Equal("class color", widgets.bar.last.SetStatusBarColor[1], 0.25)

bar:PostCastFail("player", 1)
Equal("interrupted color shown", widgets.failed.shown, true)
Equal("time hidden during feedback", widgets.time.shown, false)
Equal("not-interruptible red cleared", widgets.locked.alpha, 0)
bar:PostCastStart("player", 1, false, "Pyroblast")
Equal("a new cast clears feedback", widgets.failed.shown, false)
Equal("time back", widgets.time.shown, true)
bar:PostCastInterruptible("player", 1, true)
Equal("interruptible change", widgets.locked.last.SetAlphaFromBoolean[1], true)

-- Stage label: hidden values leave it off.
player.stageLabel = true
bar.UpdatePips(bar, { 0.3, 0.25, 0.25 })
bar:PostCastStart("player", 1, false, "Fire Breath")
bar:SetMinMaxValues(0, 2)
bar:SetValue(1.2)
widgets.ticker.scripts.OnUpdate()
Equal("stage label", widgets.stageLabel.text, "Stage 2")
Equal("label in place of the time", widgets.time.shown, false)
bar:SetValue(1.9)
widgets.ticker.scripts.OnUpdate()
Equal("hold label", widgets.stageLabel.text, "Hold")
bar:SetValue(secret)
widgets.ticker.scripts.OnUpdate()
Equal("no label from a hidden value", widgets.stageLabel.shown, false)

-- Pet cast bar --------------------------------------------------------------------------------------------

local calls = {}
PetCastingBarFrame = {
	SetUnit = function(_, unit)
		calls[#calls + 1] = tostring(unit)
	end,
	RegisterEvent = function(_, event)
		calls[#calls + 1] = event
	end,
}
CastBar:RestorePetCastBar()
Equal("pet cast bar restored", table.concat(calls, ","), "nil,pet,UNIT_PET")

-- Blizzard's player cast bar ------------------------------------------------------------------------------

local rolesets = {}
PlayerCastingBarFrame = {
	SetRolesets = function(_, value)
		rolesets[#rolesets + 1] = tostring(value)
	end,
}
CastBar:BlockBlizzardCastBar(true)
Equal("blocked in Edit Mode too", rolesets[1], "alwaysBlocked")
CastBar:BlockBlizzardCastBar(true)
Equal("blocked once", #rolesets, 1)
CastBar:BlockBlizzardCastBar(false)
Equal("block lifted", rolesets[2], "nil")
PlayerCastingBarFrame = nil
CastBar.blizzardBlocked = nil
CastBar:BlockBlizzardCastBar(true)
Equal("no Blizzard cast bar, nothing to block", CastBar.blizzardBlocked, nil)

-- Preview sample ------------------------------------------------------------------------------------------

widgets = CastBar:Create(Region())
player = CastBar:Resolve(config, "player")
CastBar:Apply(widgets, player, UIParent, 270)
CastBar:ShowSample(widgets, { name = "Sample Spell", icon = "icon", progress = 0.6, remaining = 1.2 })
Equal("sample shown", widgets.bar.shown, true)
Equal("sample progress", widgets.bar.value, 0.6)
Equal("sample time", widgets.time.text, "1.2")
Equal("sample latency", widgets.latency.text, "48 ms")
CastBar:ShowSample(widgets, { name = "Sample Spell", progress = 1, remaining = 0, failed = "Interrupted" })
Equal("sample feedback label", widgets.text.text, "Interrupted")
Equal("sample feedback hides the time", widgets.time.shown, false)
Equal("sample feedback color", widgets.failed.shown, true)
CastBar:ShowSample(widgets, { name = "Sample Spell", progress = 0.6, remaining = 1, locked = true })
Equal("sample not interruptible", widgets.locked.alpha, 1)
CastBar:ShowSample(widgets, { name = "Sample Spell", progress = 0.6, remaining = 1, stages = { 0.3, 0.25, 0.25 } })
Equal("sample stage colors", widgets.zones.shown, true)

-- Channel ticks ------------------------------------------------------------------------------------------

local function Fractions(data, duration, talent)
	local list = {}
	for index, fraction in ipairs(CastBar:TickFractions(data, duration, talent)) do
		list[index] = ("%.2f"):format(fraction)
	end

	return table.concat(list, ",")
end

Equal("tick count", Fractions({ ticks = 4 }), "0.25,0.50,0.75")
Equal("one tick has no marks", Fractions({ ticks = 1 }), "")
Equal("talent count", Fractions({ ticks = 3, talent = 1, talentTicks = 4 }, nil, true), "0.25,0.50,0.75")
Equal("talent unknown", Fractions({ ticks = 3, talent = 1, talentTicks = 4 }, nil, false), "0.33,0.67")
Equal("interval", Fractions({ interval = 1 }, 4), "0.25,0.50,0.75")
Equal("interval with a partial tick", Fractions({ interval = 1 }, 3.5), "0.29,0.57,0.86")
Equal("interval without a length", Fractions({ interval = 1 }), "")
Equal("draining channel: first tick from the right", CastBar:TickOffset(0.25, 100, false), 75)
Equal("reversed channel: from the left", CastBar:TickOffset(0.25, 100, true), 25)
Equal("tick data loaded", AUI.CastData.channels[15407].ticks, 6)

frame = {}
widgets = CastBar:Create(Region())
CastBar:Attach(frame, widgets)
player = CastBar:Resolve(config, "player")
Equal("ticks on by default", player.ticks, true)
Equal("tick color", player.tickColor.a, 0.7)
Equal("last tick off", player.lastTick, false)
CastBar:Apply(widgets, player, UIParent, 270)
widgets.bar.width = 200
widgets.bar:PostCastStart("player", 15407, false, "Mind Flay")
Equal("five marks for six ticks", #widgets.ticks, 5)
Near("first mark", widgets.ticks[1].points[1][4], (1 - 1 / 6) * 200)
Equal("marks span the height", widgets.ticks[1].points[2][1], "BOTTOMLEFT")
Equal("tick color applied", widgets.ticks[1].last.SetColorTexture[4], 0.7)
player.lastTick = true
widgets.bar:PostCastStart("player", 15407, false, "Mind Flay")
Equal("last tick white", widgets.ticks[5].last.SetColorTexture[1], 1)
widgets.bar:PostCastStart("player", 133, false, "Fireball")
Equal("no ticks for an unlisted spell", widgets.ticks[1].shown, false)
widgets.bar:PostCastStart("player", secret, false, "Mind Flay")
Equal("no ticks for a hidden spell", widgets.ticks[1].shown, false)
channelInfo = { "Soothing Mist", "", 0, 1000, 5000 }
widgets.bar:PostCastStart("player", 115175, false, "Soothing Mist")
Equal("interval ticks from the channel's length", widgets.ticks[3].shown, true)
Equal("interval ticks stop before the end", widgets.ticks[4].shown, false)
channelInfo = { "Soothing Mist", "", 0, secret, secret }
widgets.bar:PostCastStart("player", 115175, false, "Soothing Mist")
Equal("no interval ticks from a hidden length", widgets.ticks[1].shown, false)
widgets.bar:PostCastStart("player", 15407, false, "Mind Flay")
widgets.bar:PostCastFail("player", 1)
Equal("feedback hides ticks", widgets.ticks[1].shown, false)

-- Interrupt -----------------------------------------------------------------------------------------------

CastBar:FindInterrupt()
Equal("no interrupt known", CastBar.interrupt, nil)
known[0][2139] = true
CastBar:Start()
Equal("player's interrupt", CastBar.interrupt, 2139)
playerClass = "WARLOCK"
known[0][19647] = true
known[1][89766] = true
registered.SPELLS_CHANGED()
Equal("a pet's interrupt first", CastBar.interrupt, 89766)
known[1][89766] = nil
registered.UNIT_PET("player")
Equal("pet change", CastBar.interrupt, 19647)
playerClass = "MAGE"
registered.PLAYER_SPECIALIZATION_CHANGED()
Equal("back to the mage", CastBar.interrupt, 2139)

local targetFrame = { key = "target" }
widgets = CastBar:Create(anchor)
CastBar:Attach(targetFrame, widgets)
Equal("attached bars are watched", CastBar.live[#CastBar.live], widgets)
target = CastBar:Resolve(config, "target")
Equal("ready on", target.interruptReady, true)
Equal("ready color", target.readyColor.r, 0.92)
Equal("cooldown color off", target.interruptCooldown, false)
Equal("mark on", target.kickMark, true)
Equal("window off", target.kickWindow, false)
Equal("window color", target.windowColor.g, 0.82)
Equal("no ticks off the player", target.ticks, nil)
CastBar:Apply(widgets, target, anchor, 270)

cooldown, castDuration = Duration(0, 0), Duration(2, 0.5)
widgets.bar.shown = true
widgets.bar:PostCastStart("target", 1, false, "Shadow Bolt")
Equal("ready color shown", widgets.ready.shown, true)
Equal("ready while off cooldown", widgets.ready.alpha, 1)
Equal("cooldown color hidden", widgets.onCooldown.shown, false)
Equal("mark hidden while ready", widgets.mark.alpha, 0)
Equal("kick frame shown", widgets.kick.shown, true)
Equal("positioner at the elapsed time", widgets.positioner.value, 0.5)
Equal("positioner range", widgets.positioner.maximum, 2)

cooldown = Duration(8, 7.2)
registered.SPELL_UPDATE_COOLDOWN()
Equal("ready hidden on cooldown", widgets.ready.alpha, 0)
Near("marker at the remaining cooldown", widgets.marker.value, 0.8)
Equal("mark shown on cooldown", widgets.mark.alpha, 1)
Equal("marker starts at the positioner's edge",
	widgets.marker.points[1][1] .. ">" .. widgets.marker.points[1][3], "LEFT>RIGHT")
Equal("mark at the marker's edge", widgets.mark.points[1][3], "TOPRIGHT")
Equal("window runs to the end", widgets.window.points[2][1], "BOTTOMRIGHT")

castDuration, channelDuration = nil, Duration(3, 1)
widgets.bar:PostCastStart("target", 1, false, "Drain Life")
Equal("channel: from the right", widgets.positioner.reverse, true)
Equal("channel: marker grows left", widgets.marker.points[1][1] .. ">" .. widgets.marker.points[1][3], "RIGHT>LEFT")

widgets.bar:PostCastStart("target", 1, secret, "Shadow Bolt")
Equal("mark follows the hidden interruptible flag", widgets.kick.last.SetAlphaFromBoolean[1], secret)
widgets.bar:PostCastInterruptible("target", 1, true)
Equal("mark hidden once not interruptible", widgets.kick.alpha, 0)

target.interruptCooldown, target.interruptReady = true, false
widgets.bar:PostCastStart("target", 1, false, "Shadow Bolt")
Equal("cooldown color shown", widgets.onCooldown.shown, true)
Equal("cooldown color while on cooldown", widgets.onCooldown.alpha, 1)
Equal("ready color off", widgets.ready.shown, false)

cooldown = nil
widgets.bar:PostCastStart("target", 1, false, "Shadow Bolt")
Equal("no colors without a cooldown", widgets.onCooldown.shown, false)
Equal("no mark without a cooldown", widgets.kick.shown, false)
CastBar.interrupt = nil
cooldown = Duration(8, 7)
widgets.bar:PostCastStart("target", 1, false, "Shadow Bolt")
Equal("no colors without an interrupt", widgets.onCooldown.shown, false)
CastBar.interrupt = 2139

-- Cast target ---------------------------------------------------------------------------------------------

Equal("target shown on target", target.target.enabled, true)
Equal("not on the player", CastBar:Resolve(config, "player").target.enabled, false)
Equal("not on bosses", CastBar:Resolve(config, "boss").target.enabled, false)
Equal("focus shows it", CastBar:Resolve(config, "focus").target.enabled, true)
Equal("target space", CastBar:TargetReserve(target, 200), 70)
target.name.enabled, target.time.enabled = true, true
CastBar:Apply(widgets, target, anchor, 270)
Equal("name stops before the target", widgets.text.points[2][4], -(39 + math.floor(254 * 0.35)))
spellTarget = { shown = true, name = "Alex", class = "PRIEST" }
widgets.bar:PostCastStart("target", 1, false, "Shadow Bolt")
Equal("target name", widgets.target.text, "Alex")
Equal("target class color", widgets.target.last.SetTextColor[1], 1)
Equal("target shown", widgets.target.shown, true)
spellTarget = { shown = true, name = secret, class = secret }
widgets.bar:PostCastStart("target", 1, false, "Shadow Bolt")
Equal("hidden target name passed on", widgets.target.text, secret)
spellTarget = { shown = false }
widgets.bar:PostCastStart("target", 1, false, "Shadow Bolt")
Equal("target hidden when the game says so", widgets.target.shown, false)

-- Important glow ------------------------------------------------------------------------------------------

Equal("glow off", target.glow, false)
Equal("pixel style", target.glowStyle, "pixel")
Equal("glow lines", target.glowLines, 8)
widgets.bar:PostCastStart("target", 1, false, "Shadow Bolt")
Equal("no glow while off", widgets.glow.shown, false)
target.glow = true
CastBar:Apply(widgets, target, anchor, 270)
Equal("pixel lines made", #widgets.glowLines, 8)
Equal("blizzard art hidden", widgets.glowArt.shown, false)
important = secret
widgets.bar:PostCastStart("target", 1, false, "Shadow Bolt")
Equal("glow shown", widgets.glow.shown, true)
Equal("glow follows the important flag", widgets.glow.last.SetAlphaFromBoolean[1], secret)
widgets.glow.width = 104
CastBar:StepGlow(widgets, 1)
Near("lines travel", widgets.glowPhase, 0.2)
Equal("lines placed", widgets.glowLines[1].last.SetSize ~= nil, true)
target.glowStyle = "blizzard"
CastBar:Apply(widgets, target, anchor, 270)
Equal("blizzard art", widgets.glowArt.last.SetAtlas[1], "ui-hud-nameplates-importantcast")
Equal("lines hidden for the blizzard style", widgets.glowLines[1].shown, false)
widgets.bar:PostCastStart("target", 1, false, "Shadow Bolt")
Equal("pulse plays", widgets.glowPulse.playing, true)
widgets.bar:PostCastFail("target", 1)
Equal("feedback hides the glow", widgets.glow.shown, false)

local lines = CastBar:GlowLines(100, 100, 4, 0, 2)
Equal("first line on top", lines[1].x .. "," .. lines[1].y .. "," .. lines[1].w .. "," .. lines[1].h, "0,0,50,2")
Equal("second line on the right", lines[2].x .. "," .. lines[2].y .. "," .. lines[2].w .. "," .. lines[2].h, "98,0,2,50")
Equal("third line on the bottom", lines[3].x .. "," .. lines[3].y .. "," .. lines[3].w .. "," .. lines[3].h, "50,98,50,2")
Equal("fourth line on the left", lines[4].x .. "," .. lines[4].y .. "," .. lines[4].w .. "," .. lines[4].h, "0,50,2,50")
lines = CastBar:GlowLines(100, 100, 4, 0.5, 2)
Equal("half way round: first line on the bottom", lines[1].y, 98)
lines = CastBar:GlowLines(100, 100, 4, 0.9, 2)
Equal("a line stops at its corner", lines[1].h, 40)

-- Samples -------------------------------------------------------------------------------------------------

target.glow = false
target.interruptReady = false
CastBar:Apply(widgets, target, anchor, 270)
CastBar:ShowSample(widgets, { name = "Sample Spell", progress = 0.25, remaining = 1.5, mark = 0.4, target = "Alex" })
Equal("sample ready color off", widgets.ready.shown, false)
Equal("sample mark", widgets.kick.shown, true)
Near("sample marker", widgets.marker.value, 0.15)
Equal("sample target", widgets.target.text, "Alex")
target.interruptReady = true
CastBar:Apply(widgets, target, anchor, 270)
CastBar:ShowSample(widgets, { name = "Sample Spell", progress = 0.25, remaining = 1.5, mark = 0.4 })
Equal("sample ready color shown", widgets.ready.shown, true)
target.glow = true
CastBar:Apply(widgets, target, anchor, 270)
CastBar:ShowSample(widgets, { name = "Sample Spell", progress = 0.6, remaining = 1, important = true })
Equal("sample glow", widgets.glow.shown, true)
Equal("sample without a mark", widgets.kick.shown, false)

widgets = CastBar:Create(Region())
player = CastBar:Resolve(config, "player")
CastBar:Apply(widgets, player, UIParent, 270)
widgets.bar.width = 100
CastBar:ShowSample(widgets, { name = "Sample Spell", progress = 0.6, remaining = 1.8, channel = true, ticks = 5 })
Equal("sample ticks", #widgets.ticks, 4)

print(("check_castbar: %d checks passed"):format(checks))
