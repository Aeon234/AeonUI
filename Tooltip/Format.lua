local AUI = select(2, ...)

---@alias AUITooltipColor { r: number, g: number, b: number }

---@param r number
---@param g number
---@param b number
---@return AUITooltipColor
local function Color(r, g, b)
	return { r = r, g = g, b = b }
end

---The frame-free text of unit tooltips: names, the guild line, the level and its classification mark, and the colors
---they are drawn in.
---@class AUITooltipFormat
---@field GUILD AUITooltipColor another guild's line
---@field OWN_GUILD AUITooltipColor the player's own guild's line
---@field FRIENDLY_LEVEL AUITooltipColor a friendly player's level
---@field MUTED AUITooltipColor owner and corpse lines
---@field YOU AUITooltipColor the Target line's value when the unit targets the player
---@field VALUE AUITooltipColor an added line's value with no color of its own
---@field MARKS table<string, AUITooltipColor> each classification mark's color
local Format = {
	GUILD = Color(0, 1, 0.1),
	OWN_GUILD = Color(0, 0.565, 1),
	FRIENDLY_LEVEL = Color(1, 0.816, 0),
	MUTED = Color(0.5, 0.5, 0.5),
	YOU = Color(0.1, 1, 0.1),
	VALUE = Color(1, 1, 1),
	MARKS = {
		elite = Color(0.992, 0.859, 0),
		rare = Color(0, 0.565, 1),
		boss = Color(0.941, 0.098, 0.098),
	},
}
AUI.TooltipFormat = Format

---@param channel number 0 to 1
---@return string
local function Hex(channel)
	return ("%02x"):format(math.floor(math.min(math.max(channel, 0), 1) * 255 + 0.5))
end

---@param text string
---@param color AUITooltipColor
---@return string text the text in the color's escape sequence
function Format:Wrap(text, color)
	return "|cff" .. Hex(color.r) .. Hex(color.g) .. Hex(color.b) .. text .. "|r"
end

---@param name string
---@param second string? the realm, or Forever's surname; nil or empty for neither
---@param separator string? the surname separator on clients with surnames; nil where the second part is a realm
---@return string
function Format:FullName(name, second, separator)
	if not second or second == "" then
		return name
	end

	return name .. (separator or "-") .. second
end

---@param text string Blizzard's guild line
---@param rank string? the rank to add after it
---@return string
function Format:Guild(text, rank)
	local guild = text:match("^<(.*)>$") or text
	local line = "<" .. guild .. ">"

	if rank and rank ~= "" then
		line = line .. " [" .. rank .. "]"
	end

	return line
end

---@param template string a level format string such as `TOOLTIP_UNIT_LEVEL`, with one `%s` for the level
---@return string pattern matching the start of a line built from the template
function Format:LevelPattern(template)
	local before = template:match("^(.-)%%s") or template

	return "^" .. before:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
end

---@param classification string? a `UnitClassification` result
---@param rare string the word for a rare unit
---@param boss string the word for a boss
---@return string mark the colored mark that follows the level; empty for a normal unit
function Format:Mark(classification, rare, boss)
	local marks = self.MARKS

	if classification == "worldboss" then
		return self:Wrap(" " .. boss, marks.boss)
	elseif classification == "rareelite" then
		return self:Wrap("+", marks.elite) .. self:Wrap(" " .. rare, marks.rare)
	elseif classification == "rare" then
		return self:Wrap(" " .. rare, marks.rare)
	elseif classification == "elite" then
		return self:Wrap("+", marks.elite)
	end

	return ""
end

---Colors the level inside Blizzard's level line and puts the classification mark after it.
---@param text string Blizzard's level line
---@param level number the unit's level; 0 or less for an unknown level, shown as "??"
---@param color AUITooltipColor
---@param mark string? from `Format:Mark`
---@return string? text nil when the level is not in the line
function Format:Level(text, level, color, mark)
	local value = level > 0 and tostring(math.floor(level)) or "??"
	local pattern = level > 0 and ("%f[%d]" .. value .. "%f[%D]") or "%?%?"
	local first, last = text:find(pattern)

	if not first then
		return nil
	end

	return text:sub(1, first - 1) .. self:Wrap(value, color) .. (mark or "") .. text:sub(last + 1)
end
