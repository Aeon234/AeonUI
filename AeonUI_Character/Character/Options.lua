local AUI = select(2, ...)

local Schema = AUI.Schema

---The character panel's settings fields and frame-free rules: which slots take an enchant, each class's main stat,
---the durability colors, the equipped items' average and money text.
---@class AUICharacterOptions
---@field ENABLED_PATH string the page's switch
---@field SHOW_MODEL_PATH string
---@field ITEM_LEVEL_PATH string the item level on each slot's icon
---@field ENCHANTS_PATH string the enchant line beside each slot
---@field QUALITY_BORDER_PATH string a `characterQualityBorder` choice
---@field QUALITY_BORDERS string[] the Quality Border choices, in the order the page lists them
---@field GAUGES_PATH string the durability gauge beside each slot
---@field AVERAGE_PATH string the item level block above the stats list
---@field GEAR_ROWS_PATH string the Enchants, Durability and Repair rows
---@field EXTRA_STATS_PATH string weapon DPS, spell schools and mana regeneration
---@field MAIN_STAT_PATH string the band on the class's main stat
---@field GEAR_SLOTS integer[] the equipment slots item level averages count: every slot but the shirt and tabard
---@field LEFT_SLOTS integer[] the left column, top to bottom
---@field RIGHT_SLOTS integer[] the right column, top to bottom
---@field WEAPON_SLOTS integer[] main hand, off hand, ranged
---@field AMMO_SLOT integer the ammo slot's ID
---@field SLOT_BUTTONS table<integer, string> Blizzard's slot buttons by slot ID, the ammo slot at `AMMO_SLOT`
---@field OUTLINES table<string, string> the quality outline's texture for each Quality Border choice
---@field SHADOW string the outline's soft shadow, 80 units across
---@field SHADE string the icon's inner shade
---@field EMPTY_FRAME string the frame an empty slot keeps
---@field EMPTY_COLOR number[] the empty slot's frame
---@field EMPTY_TEXT number[] the empty slot's name
---@field ICON_CROP number trimmed from each side of an item's icon, as a texture coordinate
---@field SHADOW_ALPHA number
---@field SHADE_ALPHA number
---@field WELL_ALPHA number the empty slot's darkened icon
---@field DIM number a slot the held item does not fit
local Options = {
	ENABLED_PATH = "character.enabled",
	SHOW_MODEL_PATH = "character.showModel",
	ITEM_LEVEL_PATH = "character.itemLevel",
	ENCHANTS_PATH = "character.enchants",
	QUALITY_BORDER_PATH = "character.qualityBorder",
	QUALITY_BORDERS = { "NORMAL", "THICK" },
	GAUGES_PATH = "character.durabilityGauges",
	AVERAGE_PATH = "character.averageItemLevel",
	GEAR_ROWS_PATH = "character.gearRows",
	EXTRA_STATS_PATH = "character.extraStats",
	MAIN_STAT_PATH = "character.mainStat",
	GEAR_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 },
	LEFT_SLOTS = { 1, 2, 3, 15, 5, 4, 19, 9 },
	RIGHT_SLOTS = { 10, 6, 7, 8, 11, 12, 13, 14 },
	WEAPON_SLOTS = { 16, 17, 18 },
	AMMO_SLOT = 0,
	SLOT_BUTTONS = {
		[1] = "CharacterHeadSlot",
		[2] = "CharacterNeckSlot",
		[3] = "CharacterShoulderSlot",
		[4] = "CharacterShirtSlot",
		[5] = "CharacterChestSlot",
		[6] = "CharacterWaistSlot",
		[7] = "CharacterLegsSlot",
		[8] = "CharacterFeetSlot",
		[9] = "CharacterWristSlot",
		[10] = "CharacterHandsSlot",
		[11] = "CharacterFinger0Slot",
		[12] = "CharacterFinger1Slot",
		[13] = "CharacterTrinket0Slot",
		[14] = "CharacterTrinket1Slot",
		[15] = "CharacterBackSlot",
		[16] = "CharacterMainHandSlot",
		[17] = "CharacterSecondaryHandSlot",
		[18] = "CharacterRangedSlot",
		[19] = "CharacterTabardSlot",
		[0] = "CharacterAmmoSlot",
	},
	OUTLINES = {
		NORMAL = "Interface\\AddOns\\AeonUI\\Media\\Textures\\QualityOutline2",
		THICK = "Interface\\AddOns\\AeonUI\\Media\\Textures\\QualityOutline3",
	},
	SHADOW = "Interface\\AddOns\\AeonUI\\Media\\Textures\\QualityShadow",
	SHADE = "Interface\\AddOns\\AeonUI\\Media\\Textures\\IconShade",
	EMPTY_FRAME = "Interface\\Common\\WhiteIconFrame",
	EMPTY_COLOR = { 0.23, 0.23, 0.24 },
	EMPTY_TEXT = { 0.5, 0.5, 0.5 },
	ICON_CROP = 0.08,
	SHADOW_ALPHA = 0.35,
	SHADE_ALPHA = 0.55,
	WELL_ALPHA = 0.55,
	DIM = 0.55,
}
AUI.CharacterOptions = Options

Schema:Choices("characterQualityBorder", Options.QUALITY_BORDERS)

Schema:Boolean(Options.ENABLED_PATH, true)
Schema:Boolean(Options.SHOW_MODEL_PATH, true)
Schema:Boolean(Options.ITEM_LEVEL_PATH, true)
Schema:Boolean(Options.ENCHANTS_PATH, true)
Schema:Choice(Options.QUALITY_BORDER_PATH, "characterQualityBorder", "NORMAL")
Schema:Boolean(Options.GAUGES_PATH, false)
Schema:Boolean(Options.AVERAGE_PATH, true)
Schema:Boolean(Options.GEAR_ROWS_PATH, true)
Schema:Boolean(Options.EXTRA_STATS_PATH, true)
Schema:Boolean(Options.MAIN_STAT_PATH, true)

-- Slots the enchanting profession can target on Forever; the off hand only for these equip locations.
local ENCHANTABLE = { [2] = true, [5] = true, [8] = true, [9] = true, [10] = true, [15] = true, [16] = true }
local OFF_HAND, OFF_HAND_ENCHANTABLE = 17, {
	INVTYPE_WEAPON = true,
	INVTYPE_WEAPONOFFHAND = true,
	INVTYPE_SHIELD = true,
	INVTYPE_HOLDABLE = true,
}

local MAIN_STATS = {
	WARRIOR = "STRENGTH",
	ROGUE = "AGILITY",
	HUNTER = "AGILITY",
	MAGE = "INTELLECT",
	WARLOCK = "INTELLECT",
	PRIEST = "INTELLECT",
}

local GAUGE_GREEN, GAUGE_YELLOW = 0.6, 0.3
local COPPER_PER_SILVER, COPPER_PER_GOLD = 100, 10000

---@param slot integer an equipment slot ID
---@param equipLoc string? the equipped item's equip location
---@return boolean
function Options:IsEnchantable(slot, equipLoc)
	if slot == OFF_HAND then
		return equipLoc ~= nil and OFF_HAND_ENCHANTABLE[equipLoc] == true
	end

	return ENCHANTABLE[slot] == true
end

---The class's main stat, or nil for a class whose stat depends on its specialization.
---@param classFile string?
---@return "STRENGTH"|"AGILITY"|"INTELLECT"|nil
function Options:MainStat(classFile)
	return classFile and MAIN_STATS[classFile] or nil
end

---Blizzard's name for a slot ("Head", "Finger"), from its button's global string.
---@param slot integer
---@return string
function Options:SlotName(slot)
	return _G[self.SLOT_BUTTONS[slot]:sub(10):upper()]
end

---@param fraction number durability left, 0 to 1
---@return table color
function Options:GaugeColor(fraction)
	if fraction >= GAUGE_GREEN then
		return GREEN_FONT_COLOR
	elseif fraction >= GAUGE_YELLOW then
		return YELLOW_FONT_COLOR
	end

	return RED_FONT_COLOR
end

---The average item level of the items worn in the gear slots.
---@param levels table<integer, number> item level by slot ID
---@return number? average nil when nothing is worn
---@return integer counted items counted
---@return integer slots gear slots
function Options:EquippedAverage(levels)
	local total, counted = 0, 0

	for _, slot in ipairs(self.GEAR_SLOTS) do
		local level = levels[slot]

		if level then
			total, counted = total + level, counted + 1
		end
	end

	return counted > 0 and total / counted or nil, counted, #self.GEAR_SLOTS
end

---Money as gold, silver and copper, each in its coin's color; parts above the first nonzero one are left out.
---@param copper integer
---@return string
function Options:MoneyText(copper)
	local gold = math.floor(copper / COPPER_PER_GOLD)
	local silver = math.floor(copper % COPPER_PER_GOLD / COPPER_PER_SILVER)
	local parts = {}

	if gold > 0 then
		parts[#parts + 1] = ("|cffffd700%dg|r"):format(gold)
	end
	if gold > 0 or silver > 0 then
		parts[#parts + 1] = ("|cffc7c7cf%ds|r"):format(silver)
	end
	parts[#parts + 1] = ("|cffeda55f%dc|r"):format(copper % COPPER_PER_SILVER)

	return table.concat(parts, " ")
end
