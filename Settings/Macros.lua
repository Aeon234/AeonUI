local AUI = select(2, ...)

local L = AUI.L

---The Macros page, under the Quality of Life header: a card per macro, headed by its switch, with Pick Up to place the
---macro on an action bar. Its settings are account-wide and take effect at once.
---@class AUISettingsMacros
local SettingsMacros = {}
AUI.SettingsMacros = SettingsMacros

---@param id string
---@param key string the macros module's settings key
---@return table spec the get and set fields of a setting stored by the macros module
local function Stored(id, key)
	return {
		id = id,
		default = false,
		get = function()
			return AUI.Macros:IsOn(key)
		end,
		set = function(value)
			AUI.Macros:Set(key, value)
		end,
	}
end

---@param card table
---@param id string
---@param key string a macro's key
---@param depends string the card's switch
local function PickUp(card, id, key, depends)
	card:Button({
		id = id,
		label = L["Place on a Bar"],
		verb = L["Pick Up"],
		depends = depends,
		run = function()
			AUI.Macros:Pickup(key)
		end,
	})
end

---@param card table
---@param id string
---@param key string `foodMana` or `drinkMana`
---@param depends string the card's switch
local function ManaPotion(card, id, key, depends)
	if not AUI.can.manaPotions then
		return
	end

	local spec = Stored(id, key)
	spec.label = L["Mana Potion in Combat"]
	spec.depends = depends
	card:Checkbox(spec)
end

---@return boolean
function SettingsMacros:IsAvailable()
	return AUI.can.macros == true
end

---@param window table
function SettingsMacros:Declare(window)
	local Options = AUI.MacrosOptions
	local page = window:Page("macros", {
		title = MACROS,
		under = "qualityOfLifeHeader",
		icon = AUI.Media.sidebar.macros,
		iconTint = true,
	})

	if not page then
		return
	end

	local food = page:Section("macrosFood", L["Food"])
	local foodSwitch = Stored("macrosFoodEnabled", "food")
	foodSwitch.label = L["Food Macro"]
	foodSwitch.description = L["Your best food and drink, kept current as %s."]:format(Options.FOOD)
	food:Toggle(foodSwitch)

	local foodOnly = Stored("macrosFoodOnly", "foodOnly")
	foodOnly.label = L["Food Only"]
	foodOnly.description = L["Leaves the drink to %s."]:format(Options.DRINK)
	foodOnly.depends = "macrosFoodEnabled"
	food:Checkbox(foodOnly)
	ManaPotion(food, "macrosFoodMana", "foodMana", "macrosFoodEnabled")
	PickUp(food, "macrosFoodPickUp", "food", "macrosFoodEnabled")

	local drink = page:Section("macrosDrink", L["Drink"])
	local drinkSwitch = Stored("macrosDrinkEnabled", "drink")
	drinkSwitch.label = L["Drink Macro"]
	drinkSwitch.description = L["Your best drink, kept current as %s."]:format(Options.DRINK)
	drink:Toggle(drinkSwitch)
	ManaPotion(drink, "macrosDrinkMana", "drinkMana", "macrosDrinkEnabled")
	PickUp(drink, "macrosDrinkPickUp", "drink", "macrosDrinkEnabled")

	local health = page:Section("macrosHealth", HEALTH)
	local healthSwitch = Stored("macrosHealthEnabled", "health")
	healthSwitch.label = L["Health Macro"]
	healthSwitch.description = L["Your best healthstone and healing potions, kept current as %s."]:format(Options.HEALTH)
	health:Toggle(healthSwitch)
	PickUp(health, "macrosHealthPickUp", "health", "macrosHealthEnabled")

	if not AUI.can.bandages then
		return
	end

	local bandage = page:Section("macrosBandage", L["Bandage"])
	local bandageSwitch = Stored("macrosBandageEnabled", "bandage")
	bandageSwitch.label = L["Bandage Macro"]
	bandageSwitch.description = L["Your best bandage, on yourself, kept current as %s."]:format(Options.BANDAGE)
	bandage:Toggle(bandageSwitch)
	PickUp(bandage, "macrosBandagePickUp", "bandage", "macrosBandageEnabled")
end

AUI.Modules:Register({
	group = "qualityOfLife",
	page = SettingsMacros,
	start = function()
		AUI.Macros:Start()
	end,
})
