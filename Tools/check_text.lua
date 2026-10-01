-- Checks Frames/Tags.lua and Frames/Text.lua outside the game: tag strings compiled from slot settings, every tag
-- method with ordinary and secret values, status priority, placement, width sharing and slot style inheritance.
-- Run from any directory with Lua 5.1: lua Tools/check_text.lua
-- Secret values are opaque objects that raise an error on comparison or arithmetic and stay secret through
-- concatenation and string formatting, as the client's do. Lua cannot intercept a boolean test or an equality
-- test against nil, so those are not caught here.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Secret values ---------------------------------------------------------------------------------------------

local SECRET = {}
local function Forbidden()
	error("operation on a secret value", 2)
end
SECRET.__lt, SECRET.__le, SECRET.__add, SECRET.__sub = Forbidden, Forbidden, Forbidden, Forbidden
SECRET.__mul, SECRET.__div, SECRET.__unm, SECRET.__len, SECRET.__index = Forbidden, Forbidden, Forbidden, Forbidden,
	Forbidden
SECRET.__concat = function()
	return setmetatable({}, SECRET)
end

local function Secret()
	return setmetatable({}, SECRET)
end

local function IsSecret(value)
	return type(value) == "table" and getmetatable(value) == SECRET
end

function issecretvalue(value)
	return IsSecret(value)
end

local luaFormat = string.format
string.format = function(pattern, ...)
	for index = 1, select("#", ...) do
		if IsSecret((select(index, ...))) then
			return Secret()
		end
	end

	return luaFormat(pattern, ...)
end

-- Environment ---------------------------------------------------------------------------------------------

UNKNOWN = "Unknown"
SlashCmdList = {}
PLAYER_OFFLINE = "Offline"
DEAD = "Dead"
C_AddOns = {
	GetAddOnMetadata = function() end,
}
CurveConstants = { ScaleTo100 = "curve" }

-- One unit's state, which every unit API below reads.
local state

local function Reset()
	state = {
		connected = true,
		ghost = false,
		dead = false,
		health = 588000,
		percent = 100,
		missing = 0,
		absorb = 0,
		healAbsorb = 0,
		power = 1200,
		powerPercent = 80,
		powerType = 0,
		powerToken = "MANA",
		name = "Thrall",
		surname = nil,
		level = 60,
		player = true,
		class = "SHAMAN",
		reaction = 5,
	}
end
Reset()

function UnitIsConnected()
	return state.connected
end
function UnitIsGhost()
	return state.ghost
end
function UnitIsDead()
	return state.dead
end
function UnitHealth()
	return state.health
end
function UnitHealthPercent(_, predicted, curve)
	assert(predicted == true and curve == "curve", "UnitHealthPercent needs the predicted flag and the curve")

	return state.percent
end
function UnitHealthMissing()
	return state.missing
end
function UnitGetTotalAbsorbs()
	return state.absorb
end
function UnitGetTotalHealAbsorbs()
	return state.healAbsorb
end
function UnitPower()
	return state.power
end
function UnitPowerPercent(_, powerType, unmodified, curve)
	assert(powerType == nil and unmodified == false and curve == "curve", "UnitPowerPercent arguments")

	return state.powerPercent
end
function UnitPowerType()
	return state.powerType, state.powerToken
end
function UnitName()
	return state.name, state.surname
end
function UnitLevel()
	return state.level
end
function UnitIsPlayer()
	return state.player
end
function UnitClass()
	return "Shaman", state.class
end
function UnitReaction()
	return state.reaction
end
function GetCreatureDifficultyColor(level)
	assert(not IsSecret(level))

	return { r = 1, g = 0, b = 0 }
end

function AbbreviateNumbers(value, options)
	if IsSecret(value) then
		return Secret()
	end

	local text = value >= 1000 and luaFormat("%dK", value / 1000) or tostring(value)

	return options and (text .. "*") or text
end

C_StringUtil = {
	TruncateWhenZero = function(value)
		if IsSecret(value) then
			return Secret()
		end

		return value == 0 and "" or tostring(value)
	end,
}

local regional = false
function RegionalUniqueNamesEnabled()
	return regional
end

local AUI = {}
assert(loadfile(root .. "Core/Core.lua"))("AeonUI", AUI)
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
AUI.can = { surnames = false, abbreviationConfig = false }
AUI.oUF = {
	Tags = { Methods = {}, Events = {}, SharedEvents = {} },
	colors = {
		class = { SHAMAN = { r = 0, g = 0.44, b = 0.87 } },
		reaction = { [5] = { r = 0, g = 1, b = 0 } },
		power = { MANA = { r = 0, g = 0, b = 1 } },
	},
}
AUI.Media = {
	Font = function(_, name)
		return "font:" .. name
	end,
	FontFlags = function(_, outline)
		return outline == "NONE" and "" or outline
	end,
}
for _, file in ipairs({ "Profile/Schema.lua", "Frames/Tags.lua", "Frames/Text.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Schema, Tags, Text = AUI.Schema, AUI.Tags, AUI.Text
Tags:Register()
local Methods = AUI.oUF.Tags.Methods

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

local function Ok(name, fn)
	local ok, problem = pcall(fn)
	Equal(name .. " runs on secret values", ok, true)
	if not ok then
		io.stderr:write(tostring(problem) .. "\n")
	end
end

-- Registration --------------------------------------------------------------------------------------------

for name in pairs(Methods) do
	Equal(name .. " has events", type(AUI.oUF.Tags.Events[name]), "string")
	Equal(name .. " is namespaced", name:sub(1, 4), "aui:")
end
Equal("level-up is unitless", AUI.oUF.Tags.SharedEvents.PLAYER_LEVEL_UP, true)
Equal("no decimal abbreviation without the capability", Tags.abbreviations.decimal, nil)

-- Compile -------------------------------------------------------------------------------------------------

local context = { primary = true, precision = "default", decimals = 0, nameFormat = "first" }
local function Compile(content, extra, ctx)
	local slot = { content = content, separator = "dash", colorMode = "custom" }
	for key, value in pairs(extra or {}) do
		slot[key] = value
	end

	return Tags:Compile(slot, ctx or context)
end

Equal("none compiles to nothing", Compile("none"), nil)
Equal("health and percent", Compile("healthAndPercent"), "[aui:health(both,dash,default,0,1)]")
Equal("secondary health", Compile("health", nil, { primary = false, precision = "decimal", decimals = 1,
	nameFormat = "first" }), "[aui:health(cur,dash,decimal,1,0)]")
Equal("missing health", Compile("missingHealth"), "[aui:health(missing,dash,default,0,1)]")
Equal("power percent", Compile("powerPercent"), "[aui:power(pct,default,0)]")
Equal("level and name", Compile("levelName", { separator = "space" }), "[aui:levelname(space,first)]")
Equal("class color wraps", Compile("name", { colorMode = "class" }), "[aui:classcolor][aui:name(first)]|r")
Equal("power color wraps", Compile("power", { colorMode = "power" }), "[aui:powercolor][aui:power(cur,default,0)]|r")
Equal("absorb", Compile("absorb"), "[aui:absorb]")
for _, content in ipairs(Schema.choices.content) do
	local tags = Compile(content)
	if content ~= "none" then
		Equal(content .. " compiles", type(tags), "string")
		Equal(content .. " tag has no nested bracket", tags:find("%[[^%]]*%[") == nil, true)
	end
end

-- Tag methods with ordinary values ------------------------------------------------------------------------

Reset()
Equal("health both", Methods["aui:health"]("target", nil, "both", "dash", "default", "0", "1"), "588K - 100%")
Equal("health bar separator", Methods["aui:health"]("target", nil, "both", "bar", "default", "0", "1"), "588K | 100%")
Equal("health parentheses", Methods["aui:health"]("target", nil, "both", "parentheses", "default", "0", "1"),
	"588K (100%)")
Equal("health brackets", Methods["aui:health"]("target", nil, "both", "brackets", "default", "0", "1"), "588K [100%]")
state.percent = 37.25
Equal("one decimal percent", Methods["aui:health"]("target", nil, "pct", "dash", "default", "1", "1"), "37.3%")
Equal("whole percent", Methods["aui:health"]("target", nil, "pct", "dash", "default", "0", "1"), "37%")
Equal("missing at zero is empty", Methods["aui:health"]("target", nil, "missing", "dash", "default", "0", "1"), "")
state.health = nil
Equal("an absent value is a dash", Methods["aui:health"]("target", nil, "cur", "dash", "default", "0", "1"), "—")
Reset()

state.dead = true
Equal("dead in the primary slot", Methods["aui:health"]("target", nil, "both", "dash", "default", "0", "1"), "Dead")
Equal("dead hides other health slots", Methods["aui:health"]("target", nil, "cur", "dash", "default", "0", "0"), nil)
Equal("dead hides absorbs", Methods["aui:absorb"]("target"), nil)
state.ghost = true
Equal("ghost before dead", Methods["aui:health"]("target", nil, "both", "dash", "default", "0", "1"), "Ghost")
state.connected = false
Equal("offline before ghost", Methods["aui:health"]("target", nil, "both", "dash", "default", "0", "1"), "Offline")
Reset()

Equal("power", Methods["aui:power"]("target", nil, "cur", "default", "0"), "1K")
Equal("power percent", Methods["aui:power"]("target", nil, "pct", "default", "0"), "80%")
Equal("absorb at zero is empty", Methods["aui:absorb"]("target"), "")
state.absorb = 5000
Equal("absorb", Methods["aui:absorb"]("target"), "5000")
Equal("level", Methods["aui:level"]("target"), 60)
state.level = -1
Equal("hidden level", Methods["aui:level"]("target"), "??")
Equal("level and name", Methods["aui:levelname"]("target", nil, "space", "first"), "?? Thrall")
Reset()

Equal("class color", Methods["aui:classcolor"]("target"), "|cff0070dd")
state.player = false
Equal("reaction color", Methods["aui:classcolor"]("target"), "|cff00ff00")
state.reaction = nil
Equal("no reaction, no color", Methods["aui:classcolor"]("target"), nil)
Equal("power color", Methods["aui:powercolor"]("target"), "|cff0000ff")
Equal("difficulty color", Methods["aui:difficultycolor"]("target"), "|cffff0000")
Reset()

-- Names on a client with surnames.
Constants = { CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = "-" } }
AUI.can.surnames = true
state.surname = "Durotan"
Equal("first name", Methods["aui:name"]("target", nil, "first"), "Thrall")
Equal("full name", Methods["aui:name"]("target", nil, "full"), "Thrall-Durotan")
state.surname = ""
Equal("full name without a surname", Methods["aui:name"]("target", nil, "full"), "Thrall")
regional = true
state.name = "Thrall-Durotan"
Equal("first name split from a joined name", Methods["aui:name"]("target", nil, "first"), "Thrall")
regional = false
AUI.can.surnames = false
Reset()

-- Tag methods with secret values ----------------------------------------------------------------------------

state.health, state.percent, state.missing = Secret(), Secret(), Secret()
state.absorb, state.healAbsorb, state.power, state.powerPercent = Secret(), Secret(), Secret(), Secret()
state.name, state.level, state.class, state.reaction = Secret(), Secret(), Secret(), Secret()
state.powerType, state.powerToken = Secret(), Secret()

Ok("health both", function()
	Equal("secret health both stays secret",
		IsSecret(Methods["aui:health"]("target", nil, "both", "dash", "default", "0", "1")), true)
end)
Ok("missing health", function()
	Methods["aui:health"]("target", nil, "missing", "dash", "default", "0", "1")
end)
Ok("absorbs", function()
	Methods["aui:absorb"]("target")
	Methods["aui:healabsorb"]("target")
end)
Ok("power", function()
	Methods["aui:power"]("target", nil, "cur", "default", "0")
	Methods["aui:power"]("target", nil, "pct", "default", "1")
end)
Ok("level and name", function()
	Equal("secret level passes through", IsSecret(Methods["aui:level"]("target")), true)
	Methods["aui:levelname"]("target", nil, "space", "first")
end)
Ok("colors", function()
	Equal("secret class gives no color", Methods["aui:classcolor"]("target"), nil)
	Equal("secret power type gives no color", Methods["aui:powercolor"]("target"), nil)
	Equal("secret level gives no difficulty color", Methods["aui:difficultycolor"]("target"), nil)
end)
state.player = false
Ok("secret reaction", function()
	Equal("secret reaction gives no color", Methods["aui:classcolor"]("target"), nil)
end)
Reset()

-- Placement -----------------------------------------------------------------------------------------------

local function Points(anchor, placement)
	local point, relative, justify = Text:Points(anchor, placement)

	return point .. " " .. relative .. " " .. justify
end

Equal("inside top right", Points("TOPRIGHT", "inside"), "TOPRIGHT TOPRIGHT RIGHT")
Equal("edge top right", Points("TOPRIGHT", "edge"), "RIGHT TOPRIGHT RIGHT")
Equal("edge top", Points("TOP", "edge"), "CENTER TOP CENTER")
Equal("outside top left", Points("TOPLEFT", "outside"), "BOTTOMLEFT TOPLEFT LEFT")
Equal("outside bottom", Points("BOTTOM", "outside"), "TOP BOTTOM CENTER")
Equal("outside left", Points("LEFT", "outside"), "RIGHT LEFT RIGHT")
Equal("outside right", Points("RIGHT", "outside"), "LEFT RIGHT LEFT")
Equal("outside center stays inside", Points("CENTER", "outside"), "CENTER CENTER CENTER")
Equal("edge on a middle anchor stays inside", Points("LEFT", "edge"), "LEFT LEFT LEFT")

-- Widths --------------------------------------------------------------------------------------------------

local function Slot(content, anchor, placement, width, size)
	return { content = content, anchor = anchor, placement = placement or "edge", width = width or 100, size = size or 12 }
end

local widths = Text:Widths({ Slot("healthAndPercent", "TOPRIGHT") }, 200)
Equal("alone in a row", widths[1], 190)
widths = Text:Widths({ Slot("healthAndPercent", "TOPLEFT"), Slot("levelName", "TOPRIGHT") }, 270)
Equal("shares with a name", widths[1], 270 - 130 - 8)
Equal("name shares with health", widths[2], 270 - 80 - 8)
widths = Text:Widths({ Slot("healthAndPercent", "TOPLEFT"), Slot("power", "BOTTOMLEFT", "inside") }, 270)
Equal("different rows do not share", widths[1], 270 * 0.95)
widths = Text:Widths({ Slot("name", "CENTER", "inside", 50) }, 200)
Equal("center with width percent", widths[1], 200 * 0.9 * 0.5)
widths = Text:Widths({ Slot("none", "TOPLEFT"), Slot("health", "TOPLEFT") }, 100)
Equal("an empty slot takes no space", widths[1], 0)
Equal("an empty slot leaves the row", widths[2], 95)
widths = Text:Widths({ Slot("levelName", "TOPLEFT"), Slot("levelName", "TOPRIGHT") }, 100)
Equal("a crowded row keeps the estimate", widths[1], 130)
widths = Text:Widths({ Slot("health", "TOPRIGHT", nil, 100, 24) }, 300)
Equal("size does not change a lone slot", widths[1], 285)

-- Resolution and application --------------------------------------------------------------------------------

local config = Schema:Defaults()
local slot = Text:Resolve(config, "target", 2)
Equal("default target name slot", slot.content, "levelName")
Equal("slot follows the frame font", slot.font, "Expressway")
Equal("slot follows the frame size", slot.size, 12)
Schema:Write(config, "frames.target.text.slots.2.size", 16)
Schema:Write(config, "frames.target.text.size", 10)
slot = Text:Resolve(config, "target", 2)
Equal("slot override wins", slot.size, 16)
Equal("other slots follow the frame", Text:Resolve(config, "target", 1).size, 10)

-- A frame holding font strings, modeled with only the FontString methods Text:Apply calls.
local function FontString()
	local text = { shown = false }
	for _, method in ipairs({ "SetFont", "SetTextColor", "SetJustifyH", "SetWidth", "ClearAllPoints" }) do
		text[method] = function(self, ...)
			self[method .. "Args"] = { ... }
		end
	end
	function text:SetPoint(...)
		self.point = { ... }
	end
	function text:Show()
		self.shown = true
	end
	function text:Hide()
		self.shown = false
	end
	function text:SetText(value)
		self.text = value
	end

	return text
end

local frame = { Bar = {}, TextSlots = {}, tags = {} }
for index = 1, Schema.textSlots.target do
	frame.TextSlots[index] = FontString()
end
function frame:Tag(text, tags)
	self.tags[text] = tags
end
function frame:Untag(text)
	self.tags[text] = nil
end
function frame:IsVisible()
	return false
end

config = Schema:Defaults()
Text:Apply(frame, "target", config)
local first, second, third, fourth = unpack(frame.TextSlots)
Equal("primary slot tag", frame.tags[first], "[aui:health(both,dash,default,0,1)]")
Equal("name slot tag", frame.tags[second], "[aui:classcolor][aui:levelname(space,first)]|r")
Equal("power slot tag", frame.tags[third], "[aui:powercolor][aui:power(cur,default,0)]|r")
Equal("empty slot has no tag", frame.tags[fourth], nil)
Equal("empty slot is hidden", fourth.shown, false)
Equal("used slot is shown", first.shown, true)
Equal("primary placed on the top edge", first.point[1] .. " " .. first.point[3], "LEFT TOPLEFT")
Equal("primary inset", first.point[4], 4)
Equal("font comes from the media lookup", first.SetFontArgs[1], "font:Expressway")
Equal("outline flag", first.SetFontArgs[3], "OUTLINE")

Schema:Write(config, "numbers.precision", "decimal")
Schema:Write(config, "frames.target.numbers.percentDecimals", 1)
Schema:Write(config, "frames.target.text.status", 0)
Text:Apply(frame, "target", config)
Equal("shared precision and frame decimals", frame.tags[first], "[aui:health(both,dash,decimal,1,0)]")
Schema:Write(config, "frames.target.text.slots.1.content", "none")
Text:Apply(frame, "target", config)
Equal("a slot set to none loses its tag", frame.tags[first], nil)
Equal("a slot set to none hides", first.shown, false)

-- The central power bar: two slots, power in the middle, no status slot.
Equal("power bar has two slots", Schema.textSlots.playerPower, 2)
Equal("power bar status slot", Schema:Read(Schema:Defaults(), "frames.playerPower.text.status"), 0)
Equal("power bar status cannot name a third slot", (Schema:CheckValue("frames.playerPower.text.status", 3)), false)
Equal("power bar is thin", Schema:Read(Schema:Defaults(), "frames.playerPower.height"), 12)
Equal("power bar may be 4 high", (Schema:CheckValue("frames.playerPower.height", 4)), true)
Equal("health frames stay at least 16 high", (Schema:CheckValue("frames.player.height", 4)), false)
Equal("no third power slot setting", Schema:Field("frames.playerPower.text.slots.3.content"), nil)

local power = { Bar = {}, TextSlots = { FontString(), FontString() }, tags = {} }
power.Tag, power.Untag, power.IsVisible = frame.Tag, frame.Untag, frame.IsVisible
config = Schema:Defaults()
Text:Apply(power, "playerPower", config)
local center, spare = unpack(power.TextSlots)
Equal("power bar value tag", power.tags[center], "[aui:power(cur,default,0)]")
Equal("power bar value centered", center.point[1] .. " " .. center.point[3], "CENTER CENTER")
Equal("second power slot empty", power.tags[spare], nil)
Equal("power bar text width", center.SetWidthArgs[1], 360 * 0.9)
Equal("power text follows frequent power updates", AUI.oUF.Tags.Events["aui:power"]:match("UNIT_POWER_FREQUENT") ~= nil,
	true)

string.format = luaFormat
io.stdout:write(("check_text: %d checks passed\n"):format(checks))
