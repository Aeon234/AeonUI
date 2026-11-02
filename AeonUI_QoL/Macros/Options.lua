local AUI = select(2, ...)

---A carried item that could fill a macro line.
---@class AUIMacroCandidate
---@field id number
---@field level number its required level
---@field ready boolean off cooldown
---@field conjured boolean conjured mage food

---The macros' frame-free rules: their names and settings, which items count, which of two is better, and the text
---each macro holds.
---@class AUIMacrosOptions
---@field FOOD string the food macro's name
---@field DRINK string the drink macro's name
---@field HEALTH string the health macro's name
---@field BANDAGE string the bandage macro's name
---@field ICON number the question mark icon, so a macro shows what its `#showtooltip` line names
---@field PLACEHOLDER string a macro's text while nothing it could use is carried
---@field FOOD_SPELL number the spell every food item casts
---@field DRINK_SPELL number the spell every drink item casts
---@field RECUPERATE number the self-heal every Retail character has out of combat
---@field POTION_STEPS number the most healing potions a health sequence holds
---@field FIRST_AID number the First Aid skill line (Forever)
---@field KEYS string[] the macros' settings keys, in the order the page lists them
---@field NAMES table<string, string> each macro's name by settings key
---@field CONJURED table<number, true> conjured mage food and water, preferred over other items
---@field FOOD_AND_DRINK table<number, true> items that are both food and drink, which their spell does not show
---@field MANA_POTIONS number[] mana potions, mana gems and healing-and-mana potions, best first (Forever)
---@field HEALTHSTONES number[] healthstones of both clients, best first
---@field HEALING_POTIONS number[] healing potions, Retail's then Forever's, best first
---@field BANDAGES {id: number, rank: number}[] bandages and the First Aid rank each needs, best first (Forever)
local FOOD, DRINK, HEALTH, BANDAGE = "AeonUI Food", "AeonUI Drink", "AeonUI Health", "AeonUI Bandage"
---@type table<string, string>
local NAMES = { food = FOOD, drink = DRINK, health = HEALTH, bandage = BANDAGE }

local Options = {
	FOOD = FOOD,
	DRINK = DRINK,
	HEALTH = HEALTH,
	BANDAGE = BANDAGE,
	ICON = 134400,
	PLACEHOLDER = "#showtooltip",
	FOOD_SPELL = 433,
	DRINK_SPELL = 430,
	RECUPERATE = 1231411,
	POTION_STEPS = 8,
	FIRST_AID = 2942,
	KEYS = { "food", "drink", "health", "bandage" },
	NAMES = NAMES,
	CONJURED = {},
	FOOD_AND_DRINK = {},
	MANA_POTIONS = { 13444, 23578, 18253, 13443, 18841, 8008, 8007, 6149, 274935, 9144, 5513, 3827, 5514, 3385, 2455,
		3087, 2456, 282013 },
	HEALTHSTONES = { 9421, 19012, 19013, 5510, 19010, 19011, 5509, 19008, 19009, 5511, 19006, 19007, 5512, 19004, 19005,
		224464 },
	HEALING_POTIONS = { 271884, 271883, 245918, 245919, 241304, 241305, 241298, 241299, 241306, 241307, 13446, 23579, 3928,
		18839, 247242, 1710, 247241, 929, 268883, 247240, 858, 268882, 247239, 118, 268881, 4596, 282011 },
	BANDAGES = {
		{ id = 232433, rank = 300 }, { id = 23684, rank = 225 }, { id = 14530, rank = 225 }, { id = 14529, rank = 200 },
		{ id = 8545, rank = 175 }, { id = 8544, rank = 150 }, { id = 6451, rank = 125 }, { id = 6450, rank = 100 },
		{ id = 3531, rank = 75 }, { id = 3530, rank = 50 }, { id = 2581, rank = 20 }, { id = 1251, rank = 1 },
	},
}
AUI.MacrosOptions = Options

-- Forever's conjured food and water, then Retail's conjured mana food.
for _, id in ipairs({ 1113, 1114, 1487, 2136, 2288, 3772, 5349, 5350, 8075, 8076, 8077, 8078, 8079, 22895, 34062,
	43518, 43523, 65499, 65500, 65515, 65516, 65517, 80610, 80618, 113509 }) do
	Options.CONJURED[id] = true
end

-- Forever's items that restore both health and mana.
for _, id in ipairs({ 1401, 3448, 19301, 20031, 20388, 20389, 20390, 21071, 21153, 21215, 21537, 23172, 23176,
	262433 }) do
	Options.FOOD_AND_DRINK[id] = true
end

---@param level any an item's required level as the client returned it
---@param playerLevel any the player's level as the client returned it
---@return boolean usable the player is at or above the level; false while either is unknown
function Options.LevelAllowed(level, playerLevel)
	return type(level) == "number" and type(playerLevel) == "number" and playerLevel > 0 and level <= playerLevel
end

---Whether `candidate` beats `current`: off cooldown first, then conjured mage food, then the higher required level,
---then the lower item ID, so the choice never depends on bag order.
---@param candidate AUIMacroCandidate
---@param current AUIMacroCandidate?
---@return boolean
function Options.Better(candidate, current)
	if not current then
		return true
	end

	if candidate.ready ~= current.ready then
		return candidate.ready
	end

	if candidate.conjured ~= current.conjured then
		return candidate.conjured
	end

	if candidate.level ~= current.level then
		return candidate.level > current.level
	end

	return candidate.id < current.id
end

---Picks the item for each line. An item that is both food and drink fills both, since food and drink share a cooldown.
---@param food AUIMacroCandidate? the best food
---@param drink AUIMacroCandidate? the best drink
---@param foodAndDrink table<number, true> the items that are both
---@return AUIMacroCandidate? food
---@return AUIMacroCandidate? drink
function Options.Pair(food, drink, foodAndDrink)
	if drink and foodAndDrink[drink.id] then
		return drink, drink
	end

	if food and foodAndDrink[food.id] then
		return food, food
	end

	return food, drink
end

---@param lines string[]
---@return string? body the lines under `#showtooltip`, or nil when there are none
local function Body(lines)
	if #lines == 0 then
		return nil
	end

	return Options.PLACEHOLDER .. "\n" .. table.concat(lines, "\n")
end

---The food macro's text: the best food and drink out of combat, or the food alone with Food Only, after a mana
---potion in combat when one is given.
---@param food number? the food's item ID
---@param drink number? the drink's item ID; nil without mana or with Food Only
---@param mana number? the mana potion's item ID; nil while the macro's setting is off
---@return string? body nil when nothing usable is carried
function Options.FoodBody(food, drink, mana)
	local lines = {}

	if mana then
		lines[#lines + 1] = "/use [combat] item:" .. mana
	end

	if food then
		lines[#lines + 1] = "/use [nocombat] item:" .. food
	end

	if drink and drink ~= food then
		lines[#lines + 1] = "/use [nocombat] item:" .. drink
	end

	return Body(lines)
end

---The drink macro's text: the best drink out of combat, after a mana potion in combat when one is given.
---@param drink number? the drink's item ID; nil without mana
---@param mana number? the mana potion's item ID; nil while the macro's setting is off
---@return string? body nil when nothing usable is carried
function Options.DrinkBody(drink, mana)
	local lines = {}

	if mana then
		lines[#lines + 1] = "/use [combat] item:" .. mana
	end

	if drink then
		lines[#lines + 1] = "/use [nocombat] item:" .. drink
	end

	return Body(lines)
end

---The health macro's steps: the best healthstone, then each healing potion as many times as it is carried, best
---first, up to `POTION_STEPS` potions.
---@param stone number? the best healthstone carried
---@param potions {id: number, count: number}[] the healing potions carried and usable, best first
---@return number[] steps item IDs in the order a sequence uses them
function Options.HealthSteps(stone, potions)
	local steps = {}

	if stone then
		steps[1] = stone
	end

	local added = 0

	for _, potion in ipairs(potions) do
		for _ = 1, math.min(potion.count, Options.POTION_STEPS - added) do
			steps[#steps + 1] = potion.id
			added = added + 1
		end
	end

	return steps
end

---The health macro's text: the steps in a sequence that starts again when combat ends, under Recuperate out of combat
---when a spell name is given, in which case the items wait for combat.
---@param steps number[] item IDs from `HealthSteps`
---@param recuperate string? Recuperate's name (Retail)
---@return string? body nil when there is nothing to use
function Options.HealthBody(steps, recuperate)
	local lines = {}
	local condition = recuperate and "[combat] " or ""

	if recuperate then
		lines[1] = "/cast [nocombat] " .. recuperate
	end

	if #steps == 1 then
		lines[#lines + 1] = "/use " .. condition .. "item:" .. steps[1]
	elseif #steps > 1 then
		lines[#lines + 1] = "/castsequence " .. condition .. "reset=combat item:" .. table.concat(steps, ", item:")
	end

	return Body(lines)
end

---The bandage macro's text: the bandage on the player, not while channeling, so a second press does not cut one
---short.
---@param bandage number? the bandage's item ID
---@return string? body nil when there is none
function Options.BandageBody(bandage)
	if not bandage then
		return nil
	end

	return Body({ "/use [@player,nochanneling] item:" .. bandage })
end

---@param body string? a macro's current text
---@return number[] ids the item IDs it names, in order
function Options.ItemsIn(body)
	local ids = {}

	for id in (body or ""):gmatch("item:(%d+)") do
		ids[#ids + 1] = tonumber(id)
	end

	return ids
end

---What a macro should hold. A fresh text replaces the old one. With nothing usable carried, the placeholder replaces a
---macro that is missing, names no item, names an item the player can no longer use, or must be rewritten for a
---changed setting; otherwise the macro keeps the item it names, so the button stays where the last one was used.
---@param fresh string? the text from what is carried
---@param current string? the macro's text, nil while it does not exist
---@param refresh boolean a setting that changes the text has just changed
---@param usable fun(id: number): boolean whether the player can use an item
---@return string? body the text to write, or nil to leave the macro as it is
function Options.Wanted(fresh, current, refresh, usable)
	if fresh then
		return fresh
	end

	if current == nil or refresh then
		return Options.PLACEHOLDER
	end

	local ids = Options.ItemsIn(current)

	if #ids == 0 then
		return Options.PLACEHOLDER
	end

	for _, id in ipairs(ids) do
		if not usable(id) then
			return Options.PLACEHOLDER
		end
	end

	return nil
end
