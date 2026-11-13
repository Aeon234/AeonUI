local AUI = select(2, ...)

local Options = AUI.CharacterOptions

---One equipped item, as the slots and the stats rows show it.
---@class AUICharacterItem
---@field link string
---@field name string from the link, so it is known before the item's data is cached
---@field quality integer?
---@field itemLevel number? nil until the item's data is cached
---@field equipLoc string?
---@field enchantable boolean the slot and item can take an enchant
---@field enchant string? the enchant's effect, or "Enchanted" when only the link knows of one
---@field current number? durability left; nil without durability or when secret
---@field maximum number?
---@field repair integer copper

---@class AUICharacterGearSummary
---@field enchanted integer enchantable items that have an enchant
---@field enchantable integer enchantable items worn
---@field lowest number? the lowest durability fraction, 0 to 1
---@field repair integer copper
---@field damaged table<integer, true> slots whose item has lost durability
---@field levels table<integer, number> item level by gear slot, for items whose data is cached

---Reads each equipment slot's item: its name, item level, enchant, durability and repair cost.
---@class AUICharacterGear
local Gear = {}
AUI.CharacterGear = Gear

-- The client's "Enchanted: %s" as a pattern capturing the effect.
local ENCHANT_PATTERN = "^" .. ENCHANTED_TOOLTIP_LINE:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%0"):gsub("%%%%s", "(.+)") .. "$"

---The enchant's effect from the item's tooltip data, or nil.
---@param tooltip table?
---@return string?
local function TooltipEnchant(tooltip)
	for _, line in ipairs(tooltip and tooltip.lines or {}) do
		if line.type == Enum.TooltipDataLineType.ItemEnchantmentPermanent then
			local text = AUI:Readable(line.leftText)

			if type(text) == "string" then
				return text:match(ENCHANT_PATTERN) or text
			end
		end
	end
end

---@param link string
---@return boolean
local function LinkHasEnchant(link)
	local enchant = link:match("item:%-?%d+:(%d*)")

	return enchant ~= nil and enchant ~= "" and enchant ~= "0"
end

---@param slot integer an equipment slot ID
---@return AUICharacterItem? item nil for an empty slot
function Gear:Read(slot)
	local link = AUI:Readable(GetInventoryItemLink("player", slot))

	if type(link) ~= "string" then
		return nil
	end

	local tooltip = C_TooltipInfo.GetInventoryItem("player", slot)
	local equipLoc = select(4, C_Item.GetItemInfoInstant(link))
	local enchantable = Options:IsEnchantable(slot, AUI:Readable(equipLoc))
	local enchant = TooltipEnchant(tooltip)

	if not enchant and LinkHasEnchant(link) then
		enchant = AUI.L["Enchanted"]
	end

	local current, maximum = GetInventoryItemDurability(slot)
	current, maximum = AUI:Readable(current), AUI:Readable(maximum)

	if current == nil or maximum == nil then
		current, maximum = nil, nil
	end

	return {
		link = link,
		name = link:match("|h%[(.-)%]|h") or link,
		quality = AUI:Readable(GetInventoryItemQuality("player", slot)),
		itemLevel = AUI:Readable(C_Item.GetDetailedItemLevelInfo(link)),
		equipLoc = AUI:Readable(equipLoc),
		enchantable = enchantable,
		enchant = enchant,
		current = current,
		maximum = maximum,
		repair = tooltip and AUI:Readable(tooltip.repairCost, 0) or 0,
	}
end

---@return AUICharacterGearSummary
function Gear:Summary()
	local summary = { enchanted = 0, enchantable = 0, repair = 0, damaged = {}, levels = {} }

	for _, slot in ipairs(Options.GEAR_SLOTS) do
		local item = self:Read(slot)

		if item then
			if item.enchantable then
				summary.enchantable = summary.enchantable + 1
				summary.enchanted = summary.enchanted + (item.enchant and 1 or 0)
			end
			local current, maximum = item.current, item.maximum

			if current and maximum and maximum > 0 then
				local fraction = current / maximum

				summary.lowest = math.min(summary.lowest or fraction, fraction)
				summary.damaged[slot] = current < maximum or nil
			end
			summary.levels[slot] = item.itemLevel
			summary.repair = summary.repair + item.repair
		end
	end

	return summary
end
