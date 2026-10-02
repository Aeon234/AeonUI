-- Checks Frames/ClassPower.lua outside the game: class resource settings and their defaults, segment widths, the
-- frame's height with extra mana, colors for charged and filling segments, target combo points, rune countdowns,
-- and where the frame sits.
-- Run from any directory with Lua 5.1: lua Tools/check_classpower.lua
-- oUF's elements are not loaded; the checks call the callbacks AeonUI gives them as oUF would.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

UNKNOWN = "Unknown"
SlashCmdList = {}
C_AddOns = {
	GetAddOnMetadata = function() end,
}
Enum = { PowerType = { ComboPoints = 4 } }
UIParent = {}

local secret = {}

function issecretvalue(value)
	return value == secret
end

local cvars = { comboPointLocation = "2" }

function GetCVar(name)
	return cvars[name]
end

local combo = { current = 0, maximum = 5 }

function GetComboPoints()
	return combo.current
end

function UnitPowerMax()
	return combo.maximum
end

function UnitClass()
	return "Rogue", "ROGUE"
end

local inCombat = false

function InCombatLockdown()
	return inCombat
end

function AbbreviateNumbers(value)
	return "abbr " .. tostring(value)
end

function Mixin(target, source)
	for key, value in pairs(source) do
		target[key] = value
	end

	return target
end

---A frame or region stand-in recording the last call of each method.
local function Region()
	local region = { last = {}, shown = true, alpha = 1, value = 0, minimum = 0, maximum = 1, events = {} }

	function region:Show()
		self.shown = true
	end

	function region:Hide()
		self.shown = false
	end

	function region:SetShown(shown)
		self.shown = shown == true
	end

	function region:IsShown()
		return self.shown
	end

	function region:SetAlpha(alpha)
		self.alpha = alpha
	end

	function region:SetValue(value)
		self.value = value
	end

	function region:GetValue()
		return self.value
	end

	function region:SetMinMaxValues(minimum, maximum)
		self.minimum, self.maximum = minimum, maximum
	end

	function region:GetMinMaxValues()
		return self.minimum, self.maximum
	end

	function region:SetText(text)
		self.text = text
	end

	function region:SetFormattedText(format, ...)
		self.text = format:format(...)
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

	function region:RegisterEvent(event, handler)
		self.events[event] = handler
	end

	function region:SetScript(script, handler)
		self[script] = handler
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
	FLAT = "flat",
	SetBarTexture = function() end,
	Font = function(_, name)
		return name
	end,
	FontFlags = function(_, outline)
		return outline == "NONE" and "" or outline
	end,
}
AUI.oUF = { colors = { class = { ROGUE = { r = 1, g = 0.96, b = 0.41 } } } }
AUI.UnitFrame = { keys = {}, LayoutBorder = function() end }
local faded = {}
AUI.Fading = {
	started = true,
	Update = function(_, frame)
		faded[#faded + 1] = frame
	end,
}

function AUI:Pixel()
	return 1
end

assert(loadfile(root .. "Profile/Schema.lua"))("AeonUI", AUI)
assert(loadfile(root .. "Frames/ClassPower.lua"))("AeonUI", AUI)

local ClassPower, Schema = AUI.ClassPower, AUI.Schema
AUI.Profile = { config = Schema:Defaults() }

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

-- Settings ------------------------------------------------------------------------------------------------

local config = AUI.Profile.config
local settings = ClassPower:Resolve(config)
Equal("shown", settings.enabled, true)
Equal("attached to the power bar", settings.attach, "power")
Equal("width", settings.width, 360)
Equal("height", settings.height, 10)
Equal("spacing", settings.spacing, 2)
Equal("borders", settings.border, true)
Equal("resource colors", settings.classColor, false)
Equal("charged color", settings.chargedColor.g, 0.8)
Equal("darken partial", settings.darkenPartial, true)
Equal("no count", settings.text, false)
Equal("text size", settings.textSize, 10)
Equal("no rune countdowns", settings.runeTimers, false)
Equal("shown out of combat", settings.hideOutOfCombat, false)
Equal("extra mana on", settings.extraMana, true)
Equal("font from the power bar text", settings.font, "Expressway")

settings.extraMana = false
Equal("height without extra mana", ClassPower:Height(settings), 10)
settings.extraMana = true
Equal("height with extra mana", ClassPower:Height(settings), 16)
settings.extraMana = false

-- Segments ------------------------------------------------------------------------------------------------

local segments = ClassPower:Segments(360, 5, 2)
Equal("five segments", #segments, 5)
Near("segment width", segments[1].w, (360 - 8) / 5)
Near("second segment", segments[2].x, (360 - 8) / 5 + 2)
Near("last segment ends at the width", segments[5].x + segments[5].w, 360)
segments = ClassPower:Segments(360, 6, 0)
Near("no gaps", segments[6].x, 300)
Equal("no segments", #ClassPower:Segments(360, 0, 2), 0)

local r, g = ClassPower:Shade({ r = 1, g = 0.5, b = 0 }, true)
Near("partial darker", r, 0.6)
Near("partial green", g, 0.3)
r = ClassPower:Shade({ 0.5, 0.5, 0.5 })
Near("full color", r, 0.5)

Equal("player combo points", ClassPower:TargetComboPoints(), false)
cvars.comboPointLocation = "1"
Equal("target combo points", ClassPower:TargetComboPoints(), true)
cvars.comboPointLocation = "2"

-- Live frame ----------------------------------------------------------------------------------------------

local frame = Region()
ClassPower.Style(frame, "player")
Equal("no stagger without Blizzard's stagger bar", rawget(frame, "Stagger"), nil)

MonkStaggerBar = Region()
frame = Region()
ClassPower.Style(frame, "player")
Equal("stagger where the client has its bar", frame.Stagger ~= nil, true)
Equal("frame key", frame.key, "classPower")
Equal("no mouse", frame.last.EnableMouse[1], false)
Equal("ten segments", #frame.ClassPower, 10)
Equal("segments start hidden", frame.ClassPower[1].shown, false)
Equal("six runes", #frame.Runes, 6)
Equal("rune spec colors", frame.Runes.colorSpec, true)
Equal("no target override on this client", frame.ClassPower.Override, nil)
frame:ApplyAppearance(config)

local element = frame.ClassPower
element:PostUpdateColor({ r = 1, g = 0, b = 0 })
for index = 1, 5 do
	element[index]:SetValue(index <= 3 and 1 or 0)
end
element:PostUpdate(3, 5, true, true, "COMBO_POINTS", 2)
Equal("laid out for five", element.layoutCount, 5)
Equal("full color", element[1].last.SetStatusBarColor[1], 1)
Equal("charged color", element[2].last.SetStatusBarColor[2], 0.8)
Near("segment placed", element[2].last.SetSize[1], (360 - 8) / 5)
element[4]:SetValue(0.5)
element:PostUpdate(3.5, 5, true, false, "SOUL_SHARDS")
Near("filling segment darker", element[4].last.SetStatusBarColor[1], 0.6)
Equal("no count text", frame.CountText.text, "")

AUI.Profile.config.frames.classPower.text = true
frame:ApplyAppearance(config)
element:PostUpdate(3, 5, true, false, "COMBO_POINTS")
Equal("count text", frame.CountText.text, "3")
element:PostUpdate(secret, 5, true, false, "COMBO_POINTS")
Equal("no count from a hidden value", frame.CountText.text, "")
AUI.Profile.config.frames.classPower.text = false

AUI.Profile.config.frames.classPower.classColor = true
frame:ApplyAppearance(config)
element:PostUpdate(3, 5, true, false, "COMBO_POINTS")
Equal("class color", element[1].last.SetStatusBarColor[3], 0.41)
AUI.Profile.config.frames.classPower.classColor = false
frame:ApplyAppearance(config)

element:PostUpdate(3, 6, true, true, "COMBO_POINTS")
Equal("relaid for six", element.layoutCount, 6)

frame.Stagger:PostUpdate(12345, 50000)
Equal("stagger value", frame.Stagger.Text.text, "abbr 12345")

-- Runes.
frame.settings.runeTimers = true
frame.Runes[1]:Show()
frame.Runes[1]:SetMinMaxValues(0, 10)
frame.Runes[1]:SetValue(7.5)
frame.Runes[2]:Show()
frame.Runes[2]:SetMinMaxValues(0, 10)
frame.Runes[2]:SetValue(10)
ClassPower:UpdateRuneTimers(frame)
Equal("rune countdown", frame.Runes[1].Text.text, "3")
Equal("ready rune has no countdown", frame.Runes[2].Text.text, "")
frame.Runes[1]:SetValue(secret)
ClassPower:UpdateRuneTimers(frame)
Equal("no countdown from a hidden value", frame.Runes[1].Text.text, "")
frame.Runes:PostUpdateColor({ r = 0, g = 1, b = 0 })
frame.Runes[1]:SetValue(4)
frame.Runes:PostUpdate()
Near("recharging rune darker", frame.Runes[1].last.SetStatusBarColor[2], 0.6)
Equal("ready rune full", frame.Runes[2].last.SetStatusBarColor[2], 1)

-- Opacity belongs to fading.
local before = #faded
frame:ApplyAppearance(config)
Equal("appearance hands opacity to fading", faded[before + 1], frame)

-- Layout.
AeonUIPlayerPower = Region()
AUI.Profile.config.frames.classPower.extraMana = false
frame:ApplyLayout(config)
Equal("frame size", frame.last.SetSize[1] .. "x" .. frame.last.SetSize[2], "360x10")
Equal("on the power bar", frame.points[1][2], AeonUIPlayerPower)
Equal("above it", frame.points[1][1] .. ">" .. frame.points[1][3] .. " " .. frame.points[1][5], "BOTTOM>TOP 2")
Equal("extra mana off", frame.last.DisableElement[1], "AdditionalPower")
Equal("enabled", frame.last.Enable ~= nil, true)
AUI.Profile.config.frames.classPower.attach = "screen"
AUI.Profile.config.frames.classPower.extraMana = true
frame:ApplyLayout(config)
Equal("on the screen", frame.points[1][2], UIParent)
Equal("screen position", frame.points[1][5], -168)
Equal("extra mana on", frame.last.EnableElement[1], "AdditionalPower")
Equal("taller with extra mana", frame.last.SetSize[2], 16)
AUI.Profile.config.frames.classPower.enabled = false
frame:ApplyLayout(config)
Equal("disabled", frame.last.Disable ~= nil, true)

-- Target combo points.
cvars.comboPointLocation = "1"
frame = Region()
ClassPower.Style(frame, "player")
element = frame.ClassPower
Equal("target override", element.Override ~= nil, true)
Equal("refreshes on target change", frame.events.PLAYER_TARGET_CHANGED ~= nil, true)
frame:ApplyAppearance(config)
element:PostUpdateColor({ r = 1, g = 1, b = 0 })
combo.current, combo.maximum = 3, 5
element.Override(frame, "PLAYER_TARGET_CHANGED", "player")
Equal("target points shown", element[3].value, 1)
Equal("points beyond the target's hidden empty", element[4].value, 0)
Equal("maximum shown", element[5].shown, true)
Equal("beyond the maximum hidden", element[6].shown, false)
local forced = 0
function element:ForceUpdate()
	forced = forced + 1
end
frame.events.PLAYER_TARGET_CHANGED()
Equal("target change refreshes", forced, 1)
combo.current = secret
element.Override(frame, "UNIT_POWER_FREQUENT", "player")
Equal("hidden points hide the segments", element[1].shown, false)
combo.current = 0
element.Override(frame, "ClassPowerEnable", "player")
Equal("shown when oUF enables combo points", element[1].shown, true)
element.Override(frame, "ClassPowerDisable", "player")
Equal("cleared when oUF turns the element off", element[1].shown, false)
Equal("no segment left showing", element[5].shown, false)

print(("check_classpower: %d checks passed"):format(checks))
