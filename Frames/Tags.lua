local AUI = select(2, ...)

local L = AUI.L

-- Shown in place of a value the client cannot provide.
local DASH = "—"

local SEPARATORS = {
	bar = " | ",
	dash = " - ",
	slash = " / ",
	space = " ",
	bullet = " • ",
}

-- Separators that wrap the second value instead of preceding it.
local WRAPS = {
	parentheses = { " (", ")" },
	brackets = { " [", "]" },
}

local PERCENT_FORMATS = {
	["0"] = "%.0f%%",
	["1"] = "%.1f%%",
}

local HEALTH_MODES = {
	health = "cur",
	healthPercent = "pct",
	healthAndPercent = "both",
	missingHealth = "missing",
}

local POWER_MODES = {
	power = "cur",
	powerPercent = "pct",
}

local COLOR_TAGS = {
	class = "[aui:classcolor]",
	power = "[aui:powercolor]",
	difficulty = "[aui:difficultycolor]",
}

---AeonUI's text tags for oUF, and the compiler that turns a text slot's settings into a tag string. Every tag passes
---unit values that may be secret only to calls that accept them (`AbbreviateNumbers`, `UnitHealthPercent` with a
---curve, `C_StringUtil.TruncateWhenZero`, string formatting and concatenation) and never compares or tests them.
---@class AUITags
---@field abbreviations table<string, table?> `AbbreviateNumbers` options per precision choice; nil means the client's
local Tags = {
	abbreviations = {},
}
AUI.Tags = Tags

---@param color table? anything with r, g and b fields
---@return string? markup a color escape, or nil without a color
local function Hex(color)
	if not color then
		return nil
	end

	return ("|cff%02x%02x%02x"):format(color.r * 255, color.g * 255, color.b * 255)
end

---@param first any
---@param separator string a schema separator choice
---@param second any
---@return string
local function Join(first, separator, second)
	local wrap = WRAPS[separator]

	if wrap then
		return first .. wrap[1] .. second .. wrap[2]
	end

	return first .. (SEPARATORS[separator] or SEPARATORS.dash) .. second
end

---@param value any a number that may be secret
---@return boolean missing the value is known to be absent
local function Missing(value)
	return not issecretvalue(value) and value == nil
end

---@param value any
---@param precision string
---@return any text
local function Abbreviate(value, precision)
	if Missing(value) then
		return DASH
	end

	return AbbreviateNumbers(value, Tags.abbreviations[precision])
end

---@param value any a 0-100 number that may be secret
---@param decimals string "0" or "1"
---@return any text
local function Percent(value, decimals)
	if Missing(value) then
		return DASH
	end

	return (PERCENT_FORMATS[decimals] or PERCENT_FORMATS["0"]):format(value)
end

---@param unit string
---@return string? label Offline, Ghost or Dead, in that priority, or nil for a living, connected unit
local function Status(unit)
	if AUI:Readable(UnitIsConnected(unit)) == false then
		return PLAYER_OFFLINE
	end

	if AUI:Readable(UnitIsGhost(unit)) then
		return L["Ghost"]
	end

	if AUI:Readable(UnitIsDead(unit)) then
		return DEAD
	end
end

---@param name any the first return of `UnitName`, possibly secret
---@param surname any the second return, possibly secret
---@param format string "first" or "full"
---@return any name
local function NameText(name, surname, format)
	if not AUI.can.surnames then
		return name
	end

	local separator = Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR

	if format == "full" then
		if issecretvalue(surname) or (surname and surname ~= "") then
			return name .. separator .. surname
		end

		return name
	end

	-- Where regional unique names are on, the first return can hold the surname too.
	if not issecretvalue(name) and name and RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled() then
		return name:match("^(.-)" .. separator:gsub("%p", "%%%0")) or name
	end

	return name
end

---@param level any `UnitLevel`'s return, possibly secret
---@return any level the level, or "??" when the client hides it
local function LevelText(level)
	if issecretvalue(level) then
		return level
	end

	if not level or level < 1 then
		return "??"
	end

	return level
end

---@param current any health, possibly secret
---@param percent any 0-100, possibly secret
---@param missing any missing health, possibly secret
---@param mode string "cur", "pct", "both" or "missing"
---@param separator string
---@param precision string
---@param decimals string
---@return any text
local function HealthText(current, percent, missing, mode, separator, precision, decimals)
	if mode == "cur" then
		return Abbreviate(current, precision)
	end

	if mode == "pct" then
		return Percent(percent, decimals)
	end

	if mode == "missing" then
		return C_StringUtil.TruncateWhenZero(missing)
	end

	return Join(Abbreviate(current, precision), separator, Percent(percent, decimals))
end

---@param mode string "cur" or "pct"
---@param current any
---@param percent any
---@param precision string
---@param decimals string
---@return any text
local function PowerText(mode, current, percent, precision, decimals)
	if mode == "pct" then
		return Percent(percent, decimals)
	end

	return Abbreviate(current, precision)
end

---@param unit string
---@param mode string
---@param separator string
---@param precision string
---@param decimals string
---@return any text
local function UnitHealthText(unit, mode, separator, precision, decimals)
	return HealthText(
		UnitHealth(unit),
		UnitHealthPercent(unit, true, CurveConstants.ScaleTo100),
		UnitHealthMissing(unit),
		mode,
		separator,
		precision,
		decimals
	)
end

local Methods = {}

---@param unit string
---@param format string
Methods["aui:name"] = function(unit, _, format)
	local name, surname = UnitName(unit)

	return NameText(name, surname, format)
end

---@param unit string
Methods["aui:level"] = function(unit)
	return LevelText(UnitLevel(unit))
end

---@param unit string
---@param separator string
---@param format string
Methods["aui:levelname"] = function(unit, _, separator, format)
	local name, surname = UnitName(unit)

	return Join(LevelText(UnitLevel(unit)), separator, NameText(name, surname, format))
end

---Health in one of four modes. A dead, ghost or offline unit shows its status in the primary slot and nothing in
---the others.
---@param unit string
---@param mode string "cur", "pct", "both" or "missing"
---@param separator string
---@param precision string
---@param decimals string
---@param primary string "1" for the slot that shows status
Methods["aui:health"] = function(unit, _, mode, separator, precision, decimals, primary)
	local status = Status(unit)

	if status then
		return primary == "1" and status or nil
	end

	return UnitHealthText(unit, mode, separator, precision, decimals)
end

---@param unit string
Methods["aui:absorb"] = function(unit)
	if Status(unit) then
		return nil
	end

	return C_StringUtil.TruncateWhenZero(UnitGetTotalAbsorbs(unit))
end

---@param unit string
Methods["aui:healabsorb"] = function(unit)
	if Status(unit) then
		return nil
	end

	return C_StringUtil.TruncateWhenZero(UnitGetTotalHealAbsorbs(unit))
end

---@param unit string
---@param mode string "cur" or "pct"
---@param precision string
---@param decimals string
Methods["aui:power"] = function(unit, _, mode, precision, decimals)
	if mode == "pct" then
		return PowerText(mode, nil, UnitPowerPercent(unit, nil, false, CurveConstants.ScaleTo100), precision, decimals)
	end

	return PowerText(mode, UnitPower(unit), nil, precision, decimals)
end

---Class color for players, reaction color for everything else; nothing while either is secret.
---@param unit string
Methods["aui:classcolor"] = function(unit)
	local colors = AUI.oUF.colors

	if AUI:Readable(UnitIsPlayer(unit)) then
		local _, class = UnitClass(unit)

		return Hex(AUI:Readable(class) and colors.class[class])
	end

	local reaction = AUI:Readable(UnitReaction(unit, "player"))

	return Hex(reaction and colors.reaction[reaction])
end

---@param unit string
Methods["aui:powercolor"] = function(unit)
	local powerType, token = UnitPowerType(unit)
	local colors = AUI.oUF.colors.power

	powerType, token = AUI:Readable(powerType), AUI:Readable(token)

	return Hex((token and colors[token]) or (powerType and colors[powerType]))
end

---@param unit string
Methods["aui:difficultycolor"] = function(unit)
	local level = AUI:Readable(UnitLevel(unit))

	if level and level > 0 then
		return Hex(GetCreatureDifficultyColor(level))
	end
end

local EVENTS = {
	["aui:name"] = "UNIT_NAME_UPDATE",
	["aui:level"] = "UNIT_LEVEL PLAYER_LEVEL_UP",
	["aui:levelname"] = "UNIT_NAME_UPDATE UNIT_LEVEL PLAYER_LEVEL_UP",
	["aui:health"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION UNIT_FLAGS",
	["aui:absorb"] = "UNIT_ABSORB_AMOUNT_CHANGED UNIT_HEALTH UNIT_CONNECTION",
	["aui:healabsorb"] = "UNIT_HEAL_ABSORB_AMOUNT_CHANGED UNIT_HEALTH UNIT_CONNECTION",
	["aui:power"] = "UNIT_POWER_FREQUENT UNIT_MAXPOWER UNIT_DISPLAYPOWER",
	["aui:classcolor"] = "UNIT_NAME_UPDATE UNIT_FACTION",
	["aui:powercolor"] = "UNIT_DISPLAYPOWER",
	["aui:difficultycolor"] = "UNIT_LEVEL PLAYER_LEVEL_UP",
}

---Builds the one-decimal abbreviation from the client's own breakpoints: every breakpoint that drops the fraction
---keeps one decimal instead.
---@return table? options `AbbreviateNumbers` options, or nil when the client cannot take custom breakpoints
local function DecimalAbbreviation()
	if not AUI.can.abbreviationConfig then
		return nil
	end

	local ok, config = pcall(function()
		local breakpoints = {}

		for index, breakpoint in ipairs(C_StringUtil.GetDefaultAbbreviationBreakpoints()) do
			local copy = AUI:CopyTable(breakpoint)

			if copy.fractionDivisor == 1 then
				copy.significandDivisor = copy.significandDivisor / 10
				copy.fractionDivisor = 10
			end

			breakpoints[index] = copy
		end

		return CreateAbbreviateConfig(breakpoints)
	end)

	return ok and config and { config = config } or nil
end

---Registers the tags with the private oUF instance. Runs once, after capabilities are resolved.
function Tags:Register()
	local tags = AUI.oUF.Tags

	for name, method in pairs(Methods) do
		tags.Methods[name] = method
		tags.Events[name] = EVENTS[name]
	end

	tags.SharedEvents.PLAYER_LEVEL_UP = true

	self.abbreviations.decimal = DecimalAbbreviation()
end

---@class AUITextContext
---@field primary boolean the slot shows the frame's status
---@field precision string
---@field decimals integer
---@field nameFormat string

---Turns a text slot's settings into an oUF tag string.
---@param slot table the slot's resolved settings: content, separator, colorMode
---@param context AUITextContext
---@return string? tags nil when the slot shows nothing
function Tags:Compile(slot, context)
	local content = slot.content
	local tag

	if HEALTH_MODES[content] then
		tag = ("[aui:health(%s,%s,%s,%d,%d)]"):format(
			HEALTH_MODES[content],
			slot.separator,
			context.precision,
			context.decimals,
			context.primary and 1 or 0
		)
	elseif POWER_MODES[content] then
		tag = ("[aui:power(%s,%s,%d)]"):format(POWER_MODES[content], context.precision, context.decimals)
	elseif content == "name" then
		tag = ("[aui:name(%s)]"):format(context.nameFormat)
	elseif content == "level" then
		tag = "[aui:level]"
	elseif content == "levelName" then
		tag = ("[aui:levelname(%s,%s)]"):format(slot.separator, context.nameFormat)
	elseif content == "absorb" then
		tag = "[aui:absorb]"
	elseif content == "healAbsorb" then
		tag = "[aui:healabsorb]"
	else
		return nil
	end

	local color = COLOR_TAGS[slot.colorMode]

	if color then
		return color .. tag .. "|r"
	end

	return tag
end

---Sample values for a settings preview: plain numbers and strings in place of a unit's.
---@class AUITextSample
---@field status string? a status label, when the sample shows one
---@field health number
---@field percent number
---@field missing number
---@field absorb number
---@field healAbsorb number
---@field power number
---@field powerPercent number
---@field name string
---@field level number
---@field classColor table?
---@field powerColor table?
---@field difficultyColor table?

---The text a slot shows for sample values, formatted exactly as its tag formats a unit's.
---@param slot table the slot's resolved settings: content, separator, colorMode
---@param context AUITextContext
---@param sample AUITextSample
---@return string? text nil when the slot shows nothing
function Tags:Sample(slot, context, sample)
	local content = slot.content
	local precision, decimals = context.precision, tostring(context.decimals)
	local text

	if HEALTH_MODES[content] then
		if sample.status then
			text = context.primary and sample.status or ""
		else
			text = HealthText(sample.health, sample.percent, sample.missing, HEALTH_MODES[content], slot.separator,
				precision, decimals)
		end
	elseif POWER_MODES[content] then
		text = PowerText(POWER_MODES[content], sample.power, sample.powerPercent, precision, decimals)
	elseif content == "name" then
		text = NameText(sample.name, nil, context.nameFormat)
	elseif content == "level" then
		text = LevelText(sample.level)
	elseif content == "levelName" then
		text = Join(LevelText(sample.level), slot.separator, NameText(sample.name, nil, context.nameFormat))
	elseif content == "absorb" then
		text = sample.status and "" or C_StringUtil.TruncateWhenZero(sample.absorb)
	elseif content == "healAbsorb" then
		text = sample.status and "" or C_StringUtil.TruncateWhenZero(sample.healAbsorb)
	else
		return nil
	end

	local color = (slot.colorMode == "class" and sample.classColor)
		or (slot.colorMode == "power" and sample.powerColor)
		or (slot.colorMode == "difficulty" and sample.difficultyColor)

	if color and text ~= "" then
		return (Hex(color) or "") .. tostring(text) .. "|r"
	end

	return tostring(text)
end
