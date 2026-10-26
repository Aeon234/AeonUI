local AUI = select(2, ...)

---@alias AUITooltipColor { r: number, g: number, b: number }

---@param r number
---@param g number
---@param b number
---@return AUITooltipColor
local function Color(r, g, b)
	return { r = r, g = g, b = b }
end

---The frame-free text of tooltips: names, the guild line, the level and its classification mark, and the colors they
---are drawn in; an item's type, what a creature's GUID tells (its NPC ID and how long it has been spawned), and an
---inspected player's item level, averaged from their gear when the client does not say, and its grade.
---@class AUITooltipFormat
---@field GUILD AUITooltipColor another guild's line
---@field OWN_GUILD AUITooltipColor the player's own guild's line
---@field FRIENDLY_LEVEL AUITooltipColor a friendly player's level
---@field MUTED AUITooltipColor owner and corpse lines
---@field YOU AUITooltipColor the Target line's value when the unit targets the player
---@field VALUE AUITooltipColor an added line's value with no color of its own
---@field MARKS table<string, AUITooltipColor> each classification mark's color
---@field GRADES AUITooltipColor[] item-level grades, from the highest upgrade track's first level down
---@field BELOW AUITooltipColor an item level below every track
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
	GRADES = {
		Color(1, 0.82, 0),
		Color(1, 0.5, 0),
		Color(0.64, 0.21, 0.93),
		Color(0, 0.44, 0.87),
		Color(0.12, 1, 0),
	},
	BELOW = Color(0.62, 0.62, 0.62),
}
AUI.TooltipFormat = Format

-- A spawn UID's low 23 bits are the spawn time, in seconds since the epoch modulo 2^23.
local SPAWN_PERIOD = 2 ^ 23
-- Weapons that take both hands, whose item level counts for the empty off hand too.
local TWO_HANDED = { INVTYPE_2HWEAPON = true, INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true }
local MAIN_HAND, OFF_HAND = 16, 17
-- The keys `MODIFIER_STATE_CHANGED` reports for each modifier choice.
local MODIFIER_KEYS = {
	SHIFT = { LSHIFT = true, RSHIFT = true },
	CTRL = { LCTRL = true, RCTRL = true },
	ALT = { LALT = true, RALT = true },
}

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

	if not first or not last then
		return nil
	end

	return text:sub(1, first - 1) .. self:Wrap(value, color) .. (mark or "") .. text:sub(last + 1)
end

---@param itemType string? the item's category, such as Armor
---@param subType string? its type, such as Plate
---@return string? text "Armor / Plate", the category alone when the type repeats or lacks it, or nil without a category
function Format:ItemType(itemType, subType)
	if not itemType or itemType == "" then
		return nil
	end

	if subType and subType ~= "" and subType ~= itemType then
		return itemType .. " / " .. subType
	end

	return itemType
end

---@param guid string
---@return string? kind
---@return string? npcID
---@return string? spawnUID
local function CreatureParts(guid)
	local kind, npcID, spawnUID = guid:match("^(%a+)%-[^-]*%-[^-]*%-[^-]*%-[^-]*%-([^-]*)%-?([^-]*)")

	if kind == "Creature" or kind == "Vehicle" then
		return kind, npcID, spawnUID
	end

	return nil
end

---@param guid string a creature or vehicle GUID, such as "Creature-0-1-2-3-12345-00ABCDEF01"
---@return number? npcID nil for any other kind of GUID
function Format:NPCID(guid)
	local _, npcID = CreatureParts(guid)

	return npcID and tonumber(npcID) or nil
end

---@param guid string a creature or vehicle GUID
---@param now number the server time, in seconds since the epoch
---@return number? seconds how long the creature has been spawned; nil for any other kind of GUID
function Format:SpawnAge(guid, now)
	local _, _, spawnUID = CreatureParts(guid)
	local uid = spawnUID and tonumber(spawnUID, 16)

	if not uid then
		return nil
	end

	local spawned = now - now % SPAWN_PERIOD + uid % SPAWN_PERIOD

	if spawned > now then
		spawned = spawned - SPAWN_PERIOD
	end

	return now - spawned
end

---@param modifier string a `tooltipModifier` choice
---@param key string a key `MODIFIER_STATE_CHANGED` reports, such as "LSHIFT"
---@return boolean
function Format:IsModifierKey(modifier, key)
	local keys = MODIFIER_KEYS[modifier]

	return keys ~= nil and keys[key] == true
end

---@param tracks { minLevel: number }[]? the season's upgrade tracks
---@param itemLevel number
---@return AUITooltipColor? color the grade of the highest track whose first level the item level reaches, gray below
---every track; nil without tracks
function Format:Grade(tracks, itemLevel)
	if not tracks or #tracks == 0 then
		return nil
	end

	local levels = {}

	for index, track in ipairs(tracks) do
		levels[index] = track.minLevel
	end

	table.sort(levels, function(a, b)
		return a > b
	end)

	for index, level in ipairs(levels) do
		if itemLevel >= level then
			return self.GRADES[math.min(index, #self.GRADES)]
		end
	end

	return self.BELOW
end

---@param slots integer[] the equipment slots that count
---@param levels table<integer, number> each equipped slot's item level; a missing slot is empty
---@param mainHandType string? the main hand's equip location, such as "INVTYPE_2HWEAPON"
---@return number? average the slots' average, a two-handed main hand counting for the empty off hand too; nil with
---nothing equipped
function Format:GearAverage(slots, levels, mainHandType)
	local total, worn = 0, 0

	for _, slot in ipairs(slots) do
		local level = levels[slot]

		if level then
			total, worn = total + level, worn + 1
		elseif slot == OFF_HAND and levels[MAIN_HAND] and TWO_HANDED[mainHandType or ""] then
			total = total + levels[MAIN_HAND]
		end
	end

	if worn == 0 then
		return nil
	end

	return total / #slots
end

