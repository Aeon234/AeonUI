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
---@field ICON number the question mark icon, so a macro shows what its `#showtooltip` line names
---@field PLACEHOLDER string a macro's text while nothing it could use is carried
---@field FOOD_SPELL number the spell every food item casts
---@field DRINK_SPELL number the spell every drink item casts
---@field KEYS string[] the macros' settings keys, in the order the page lists them
---@field NAMES table<string, string> each macro's name by settings key
---@field CONJURED table<number, true> conjured mage food and water, preferred over other items
---@field FOOD_AND_DRINK table<number, true> items that are both food and drink, which their spell does not show
---@field MANA_POTIONS number[] mana potions, mana gems and healing-and-mana potions, best first (Forever)
local FOOD, DRINK = "AeonUI Food", "AeonUI Drink"
---@type table<string, string>
local NAMES = { food = FOOD, drink = DRINK }

local Options = {
	FOOD = FOOD,
	DRINK = DRINK,
	ICON = 134400,
	PLACEHOLDER = "#showtooltip",
	FOOD_SPELL = 433,
	DRINK_SPELL = 430,
	KEYS = { "food", "drink" },
	NAMES = NAMES,
	CONJURED = {},
	FOOD_AND_DRINK = {},
	MANA_POTIONS = { 13444, 23578, 18253, 13443, 18841, 8008, 8007, 6149, 274935, 9144, 5513, 3827, 5514, 3385, 2455,
		3087, 2456, 282013 },
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
