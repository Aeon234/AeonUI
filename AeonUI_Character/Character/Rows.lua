local AUI = select(2, ...)

local L = AUI.L
local Options, Gear, Slots = AUI.CharacterOptions, AUI.CharacterGear, AUI.CharacterSlots

local LOW_DURABILITY = 0.3 -- the Durability row turns red below this, the gauge's red
local FADE = 0.3 -- the undamaged slots while the Durability row is hovered
local WHITE = { r = 1, g = 1, b = 1 }
local FIRST_SCHOOL = 2 -- Holy; school 1 is physical damage

---@param text string
---@param color table r, g, b from 0 to 1
---@return string
local function Colored(text, color)
	local function Byte(value)
		return math.floor(value * 255 + 0.5)
	end

	return ("|cff%02x%02x%02x%s|r"):format(Byte(color.r), Byte(color.g), Byte(color.b), text)
end

---@param elements table[]
---@param name string a stat key
---@return integer?
local function IndexOf(elements, name)
	for index, element in ipairs(elements) do
		if not element.isHeader and element.name == name then
			return index
		end
	end
end

---Where a row appended to a category goes: after its last row.
---@param elements table[]
---@param category string? the category's header text
---@return integer?
local function CategoryEnd(elements, category)
	local found = false

	for index, element in ipairs(elements) do
		if element.isHeader then
			if found then
				return index
			end
			found = category ~= nil and element.name == category
		end
	end

	return found and #elements + 1 or nil
end

---@param title string
---@param owner table
local function Tooltip(owner, title)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(title, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
end

---@param left string the slot, gold
---@param right string
---@param color table
local function Line(left, right, color)
	GameTooltip:AddDoubleLine(left, right, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, color.r,
		color.g, color.b)
end

---Calls `visit(slot, item)` for each worn item in the gear slots, in their order.
---@param visit fun(slot: integer, item: table)
local function EachItem(visit)
	for _, slot in ipairs(Options.GEAR_SLOTS) do
		local item = Gear:Read(slot)

		if item then
			visit(slot, item)
		end
	end
end

---The feature's rows in the mirrored stats list: Enchants, Durability and Repair at the end of General; Damage per
---Second, spell schools above Spell Power and Mana Regen; and the main stat's band. Each set follows its switch.
---@class AUICharacterRows
local Rows = {}
AUI.CharacterRows = Rows

---@param summary AUICharacterGearSummary
---@return table[]
function Rows:Gear(summary)
	local enchants = ("%d / %d"):format(summary.enchanted, summary.enchantable)
	local lowest = summary.lowest
	local durability = lowest and ("%d%%"):format(math.floor(lowest * 100 + 0.5)) or NOT_APPLICABLE
	local repair = Options:MoneyText(summary.repair)

	return {
		{
			labelText = ENCHANTS,
			valueText = summary.enchanted < summary.enchantable and Colored(enchants, RED_FONT_COLOR) or enchants,
			onEnter = function(owner)
				Tooltip(owner, ENCHANTS .. " " .. enchants)
				EachItem(function(slot, item)
					if item.enchantable then
						Line(Options:SlotName(slot), item.enchant or L["No Enchant"],
							item.enchant and GREEN_FONT_COLOR or RED_FONT_COLOR)
					end
				end)
				GameTooltip:Show()
			end,
		},
		{
			labelText = DURABILITY,
			valueText = lowest and lowest < LOW_DURABILITY and Colored(durability, RED_FONT_COLOR) or durability,
			onEnter = function(owner)
				Tooltip(owner, DURABILITY .. " " .. durability)
				EachItem(function(slot, item)
					local current, maximum = item.current, item.maximum

					if current and maximum and maximum > 0 then
						local fraction = current / maximum

						Line(Options:SlotName(slot), ("%d / %d (%d%%)"):format(current, maximum,
							math.floor(fraction * 100 + 0.5)), Options:GaugeColor(fraction))
					end
				end)
				GameTooltip:Show()
				Slots:SetFade(function(slot)
					return summary.damaged[slot] == true
				end, FADE)
			end,
		},
		{
			labelText = L["Repair"],
			valueText = repair,
			onEnter = function(owner)
				Tooltip(owner, L["Repair"] .. " " .. repair)
				EachItem(function(slot, item)
					if item.repair > 0 then
						Line(Options:SlotName(slot), Options:MoneyText(item.repair), WHITE)
					end
				end)
				GameTooltip:Show()
			end,
		},
	}
end

---Spell damage by school for each school whose bonus differs from Spell Power's, which Blizzard reads as the lowest.
---@return table[]
local function Schools()
	local bonuses, lowest = {}, nil

	for school = FIRST_SCHOOL, MAX_SPELL_SCHOOLS do
		local bonus = AUI:Readable(GetSpellBonusDamage(school), 0) --[[@as number]]

		bonuses[school] = bonus
		lowest = math.min(lowest or bonus, bonus)
	end

	local rows = {}

	for school = FIRST_SCHOOL, MAX_SPELL_SCHOOLS do
		if bonuses[school] ~= lowest then
			rows[#rows + 1] = {
				labelText = _G["SPELL_SCHOOL" .. (school - 1) .. "_CAP"],
				valueText = BreakUpLargeNumbers(bonuses[school]),
			}
		end
	end

	return rows
end

---@return table? row nil without a main hand damage figure
local function DamagePerSecond()
	local _, low, high, _, speed = PaperDollFrame_GetDamage("player", UnitDamage, INVTYPE_WEAPONMAINHAND)

	low, high, speed = AUI:Readable(low, 0), AUI:Readable(high, 0), AUI:Readable(speed, 1)
	if not speed or speed <= 0 then
		return nil
	end

	return { labelText = DAMAGE_PER_SECOND, valueText = ("%.1f"):format((low + high) / (2 * speed)) }
end

---@param elements table[]
local function AddExtraStats(elements)
	-- Forever's category names, not in Retail's annotations.
	local modifiers, weapons = _G["STAT_CATEGORY_MODIFIERS"], _G["STAT_CATEGORY_WEAPONS"]
	local mainHand = IndexOf(elements, "MAINHAND_DAMAGE")
	local dps = mainHand and DamagePerSecond()

	if dps then
		table.insert(elements, mainHand + 1, dps)
	end

	local schools = Schools()
	local mana = AUI:Readable(UnitPowerMax("player", Enum.PowerType.Mana), 0) --[[@as number]]
	local manaUser = mana > 0

	if #schools == 0 and not manaUser then
		return
	end

	if not CategoryEnd(elements, modifiers) then
		local at = CategoryEnd(elements, weapons) or #elements + 1

		table.insert(elements, at, { isHeader = true, name = modifiers })
	end

	local spellPower = IndexOf(elements, "SPELLPOWER")
	local at = spellPower and spellPower + 1 or CategoryEnd(elements, modifiers) or #elements + 1

	for offset, row in ipairs(schools) do
		table.insert(elements, at + offset - 1, row)
	end

	if manaUser then
		local healing = IndexOf(elements, "SPELLHEALING")

		table.insert(elements, healing and healing + 1 or CategoryEnd(elements, modifiers)
			or #elements + 1, { unit = "player", name = "MANAREGEN" })
	end
end

---Adds the rows the switches turn on to the mirror's copied elements, then numbers each category's rows, which picks
---Blizzard's alternate row band.
---@param elements table[]
function Rows:Add(elements)
	local Profile = AUI.Profile

	if Profile:Get(Options.GEAR_ROWS_PATH) == true then
		local at = CategoryEnd(elements, STAT_CATEGORY_GENERAL)

		if at then
			for offset, row in ipairs(self:Gear(Gear:Summary())) do
				table.insert(elements, at + offset - 1, row)
			end
		end
	end

	if Profile:Get(Options.EXTRA_STATS_PATH) == true then
		AddExtraStats(elements)
	end

	local mainStat = Profile:Get(Options.MAIN_STAT_PATH) == true and Options:MainStat(select(2, UnitClass("player")))
	local index = 0

	for _, element in ipairs(elements) do
		if element.isHeader then
			index = 0
		else
			index = index + 1
			element.statIndex = index
			if mainStat and element.name == mainStat then
				element.band = true
			end
		end
	end
end

AUI.CharacterStats:AddRows(function(elements)
	Rows:Add(elements)
end)
