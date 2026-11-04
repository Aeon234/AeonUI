-- Checks Macros/ outside the game: which items count and which wins, the text each macro holds, and the module against
-- stubbed macro, bag and item APIs (login, combat, a full General tab, deleting, picking up).
-- Run from any directory with Lua 5.1: lua Tools/check_macros.lua
-- Loads the real files against the shared stub client. Exits non-zero on the first failed check.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"
local client = assert(loadfile(root .. "Tools/stub_client.lua"))({ project = "retail" })
local Equal = client.Equal

-- Environment ---------------------------------------------------------------------------------------------

SlashCmdList = {}
C_AddOns = {
	GetAddOnMetadata = function(_, field)
		return field == "Version" and "dev" or "AeonUI"
	end,
}

function CallErrorHandler(message)
	error(message, 0)
end

function wipe(t)
	for key in pairs(t) do
		t[key] = nil
	end

	return t
end

local SECRET = client.Secret()

client.now = 1000

-- Chat lines from `AUI:Warn`.
local printed = {}
function print(message)
	printed[#printed + 1] = message
end

-- The player.
local player = { level = 30, mana = 1000 }
function UnitLevel(unit)
	assert(unit == "player")
	return player.level
end
function UnitPowerMax(unit, power)
	assert(unit == "player" and power == 0)
	return player.mana
end
Enum = { PowerType = { Mana = 0 } }

-- First Aid: its rank, or nil while the character lacks the skill.
local firstAid
C_SkillInfo = {
	GetSkillLineInfoByID = function(id)
		assert(id == 2942)
		return firstAid and { skillID = id, rank = firstAid }
	end,
}

-- Items: each one's use spell, required level (nil while loading) and cooldown.
local FOOD, DRINK = "Food", "Drink"
local items = {}
local requests = {}
local function Item(id, spell, level, cooldown)
	items[id] = { spell = spell, level = level, cooldown = cooldown }
end
C_Spell = {
	GetSpellName = function(id)
		return ({ [433] = FOOD, [430] = DRINK, [1231411] = "Recuperate" })[id]
	end,
}

-- Bags: a list of item IDs per bag; a slot holds one item.
NUM_BAG_SLOTS = 4
local bags = {}
C_Container = {
	GetContainerNumSlots = function(bag)
		return #(bags[bag] or {})
	end,
	GetContainerItemID = function(bag, slot)
		return (bags[bag] or {})[slot]
	end,
}

local function Count(id)
	local count = 0
	for bag = 0, NUM_BAG_SLOTS do
		for _, held in ipairs(bags[bag] or {}) do
			if held == id then
				count = count + 1
			end
		end
	end

	return count
end

C_Item = {
	GetItemSpell = function(id)
		return items[id] and items[id].spell
	end,
	GetItemInfo = function(id)
		local item = items[id]
		if not item or item.level == nil then
			return nil
		end

		return "Item " .. id, "link", 1, 1, item.level
	end,
	GetItemCooldown = function(id)
		local cooldown = items[id] and items[id].cooldown
		if cooldown == "secret" then
			return SECRET, SECRET, SECRET
		end
		if cooldown then
			return cooldown.start, cooldown.duration, cooldown.enabled ~= false
		end

		return 0, 0, true
	end,
	GetItemCount = Count,
	RequestLoadItemDataByID = function(id)
		requests[#requests + 1] = id
	end,
}

-- Macros: the account's macros by index, and every call that changes them.
Constants = { MacroConsts = { MAX_ACCOUNT_MACROS = 120 } }
local macros = {}
local calls = {}
local createFails = false
local function Index(name)
	for index, macro in ipairs(macros) do
		if macro.name == name then
			return index
		end
	end

	return 0
end
function GetMacroInfo(name)
	local macro = macros[Index(name)]
	if macro then
		return macro.name, macro.icon, macro.body
	end
end
function GetMacroIndexByName(name)
	return Index(name)
end
function GetNumMacros()
	return #macros, 0
end
function CreateMacro(name, icon, body, perCharacter)
	assert(not client.combat, "a macro made in combat")
	assert(perCharacter == false, "a character macro")
	calls[#calls + 1] = "create " .. name
	if not createFails then
		macros[#macros + 1] = { name = name, icon = icon, body = body }
	end
end
function EditMacro(name, newName, icon, body)
	assert(not client.combat, "a macro edited in combat")
	assert(newName == name and icon == nil)
	calls[#calls + 1] = "edit " .. name
	macros[Index(name)].body = body
end
function DeleteMacro(index)
	assert(not client.combat, "a macro deleted in combat")
	calls[#calls + 1] = "delete " .. macros[index].name
	table.remove(macros, index)
end
local pickedUp
function PickupMacro(index)
	pickedUp = macros[index].name
end

-- Addon table ---------------------------------------------------------------------------------------------

local AUI = {}
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
assert(loadfile(root .. "AeonUI/Core/Core.lua"))("AeonUI", AUI)
AUI.can = { macros = true, manaPotions = false }
local global = {}
AUI.Profile = {
	Global = function()
		return global
	end,
}

for _, file in ipairs({ "AeonUI/Core/Callbacks.lua", "AeonUI/Core/Events.lua", "AeonUI_QoL/Macros/Options.lua", "AeonUI_QoL/Macros/Macros.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Macros = AUI.Macros
local Options = AUI.MacrosOptions

-- Events.lua's frame, the only one these files create.
local eventFrame = client.frames[#client.frames]

---Delivers an event, then lets the update it put off for the next frame run.
---@param event string
---@param ... any
local function Fire(event, ...)
	client:Fire(event, ...)
	client:RunTimers()
end

---Changes a macro's setting, then lets the update it put off for the next frame run.
---@param key string
---@param value boolean
local function Set(key, value)
	Macros:Set(key, value)
	client:RunTimers()
end

local function True(name, value)
	Equal(name, value and true or false, true)
end

local function Body(name)
	local _, _, body = GetMacroInfo(name)

	return body
end

local function Lines(...)
	return table.concat({ "#showtooltip", ... }, "\n")
end

local function Candidate(id, level, ready, conjured)
	return { id = id, level = level, ready = ready, conjured = conjured == true }
end

-- Options -------------------------------------------------------------------------------------------------

True("level at the player's", Options.LevelAllowed(30, 30))
Equal("level above the player's", Options.LevelAllowed(31, 30), false)
Equal("level unknown", Options.LevelAllowed(nil, 30), false)
Equal("player level unknown", Options.LevelAllowed(1, 0), false)

True("anything beats nothing", Options.Better(Candidate(1, 1, true), nil))
True("off cooldown first", Options.Better(Candidate(1, 1, true), Candidate(2, 50, false, true)))
True("conjured next", Options.Better(Candidate(1, 1, true, true), Candidate(2, 50, true)))
True("higher level next", Options.Better(Candidate(1, 20, true), Candidate(2, 10, true)))
True("lower ID last", Options.Better(Candidate(1, 20, true), Candidate(2, 20, true)))
Equal("higher ID loses a tie", Options.Better(Candidate(2, 20, true), Candidate(1, 20, true)), false)

local both = { [9] = true }
local food, drink = Options.Pair(Candidate(1, 1, true), Candidate(9, 1, true), both)
Equal("a food-and-drink drink fills the food line", food.id, 9)
Equal("and the drink line", drink.id, 9)
food, drink = Options.Pair(Candidate(9, 1, true), Candidate(2, 1, true), both)
Equal("a food-and-drink food fills the drink line", drink.id, 9)
food, drink = Options.Pair(Candidate(1, 1, true), Candidate(2, 1, true), both)
Equal("separate food", food.id, 1)
Equal("separate drink", drink.id, 2)

Equal("food body", Options.FoodBody(1, 2), Lines("/use [nocombat] item:1", "/use [nocombat] item:2"))
Equal("one item fills both lines once", Options.FoodBody(9, 9), Lines("/use [nocombat] item:9"))
Equal("food body with mana", Options.FoodBody(1, nil, 7), Lines("/use [combat] item:7", "/use [nocombat] item:1"))
Equal("food body empty", Options.FoodBody(nil, nil), nil)
Equal("drink body", Options.DrinkBody(2, 7), Lines("/use [combat] item:7", "/use [nocombat] item:2"))
Equal("drink body empty", Options.DrinkBody(nil, nil), nil)

local function Usable(id)
	return id ~= 99
end
Equal("fresh text wins", Options.Wanted("new", "old", false, Usable), "new")
Equal("a missing macro gets the placeholder", Options.Wanted(nil, nil, false, Usable), "#showtooltip")
Equal("a refresh gets the placeholder", Options.Wanted(nil, Lines("/use item:1"), true, Usable), "#showtooltip")
Equal("an itemless macro gets the placeholder", Options.Wanted(nil, "#showtooltip", false, Usable), "#showtooltip")
Equal("an unusable item gets the placeholder", Options.Wanted(nil, Lines("/use item:99"), false, Usable),
	"#showtooltip")
Equal("a used-up item stays", Options.Wanted(nil, Lines("/use item:1"), false, Usable), nil)

local steps = Options.HealthSteps(5, { { id = 7, count = 2 }, { id = 8, count = 9 } })
Equal("the stone, then each potion as often as carried, capped", table.concat(steps, " "),
	"5 7 7 8 8 8 8 8 8")
Equal("no stone", table.concat(Options.HealthSteps(nil, { { id = 7, count = 1 } }), " "), "7")
Equal("health sequence", Options.HealthBody({ 5, 7, 7 }), Lines("/castsequence reset=combat item:5, item:7, item:7"))
Equal("one health item used plainly", Options.HealthBody({ 5 }), Lines("/use item:5"))
Equal("health with Recuperate", Options.HealthBody({ 5, 7 }, "Recuperate"),
	Lines("/cast [nocombat] Recuperate", "/castsequence [combat] reset=combat item:5, item:7"))
Equal("one item with Recuperate", Options.HealthBody({ 5 }, "Recuperate"),
	Lines("/cast [nocombat] Recuperate", "/use [combat] item:5"))
Equal("Recuperate alone", Options.HealthBody({}, "Recuperate"), Lines("/cast [nocombat] Recuperate"))
Equal("nothing to heal with", Options.HealthBody({}), nil)
Equal("bandage on the player, not while channeling", Options.BandageBody(1251),
	Lines("/use [@player,nochanneling] item:1251"))
Equal("no bandage", Options.BandageBody(nil), nil)

-- Module: login ---------------------------------------------------------------------------------------------

Item(101, FOOD, 25)
Item(102, FOOD, 5)
Item(201, DRINK, 25)
Item(301, FOOD, 35)
Item(500, "Bandage", 1)
bags[0] = { 101, 102, 201, 500, 301 }

Macros:Start()
Set("food", true)
Equal("nothing written before entering the world", #calls, 0)
Equal("no bag events before entering the world", eventFrame.events.BAG_UPDATE_DELAYED, nil)

Fire("PLAYER_ENTERING_WORLD")
Equal("entering the world is followed once", eventFrame.events.PLAYER_ENTERING_WORLD, nil)
Equal("the food macro made", calls[1], "create AeonUI Food")
Equal("best usable food and the drink", Body("AeonUI Food"),
	Lines("/use [nocombat] item:101", "/use [nocombat] item:201"))
Equal("made with the question mark", macros[1].icon, Options.ICON)
True("bags followed while on", eventFrame.events.BAG_UPDATE_DELAYED)
True("macros followed while on", eventFrame.events.UPDATE_MACROS)
Equal("the drink macro not made while off", Index("AeonUI Drink"), 0)

-- Levels and loading --------------------------------------------------------------------------------------

player.level = 40
Fire("UNIT_LEVEL", "party1")
Equal("another unit's level ignored", Body("AeonUI Food"), Lines("/use [nocombat] item:101", "/use [nocombat] item:201"))
Fire("UNIT_LEVEL", "player")
Equal("a level makes a better food usable", Body("AeonUI Food"),
	Lines("/use [nocombat] item:301", "/use [nocombat] item:201"))

Item(302, FOOD, nil)
table.insert(bags[0], 302)
Fire("BAG_UPDATE_DELAYED")
Equal("an item's data asked for", requests[#requests], 302)
True("its arrival followed", eventFrame.events.ITEM_DATA_LOAD_RESULT)
items[302].level = 33
Fire("ITEM_DATA_LOAD_RESULT", 999, true)
Equal("another item's arrival ignored", Body("AeonUI Food"), Lines("/use [nocombat] item:301", "/use [nocombat] item:201"))
Fire("ITEM_DATA_LOAD_RESULT", 302, true)
Equal("arrivals no longer followed", eventFrame.events.ITEM_DATA_LOAD_RESULT, nil)
Equal("the loaded item kept below a better one", Body("AeonUI Food"),
	Lines("/use [nocombat] item:301", "/use [nocombat] item:201"))

-- Ranking -------------------------------------------------------------------------------------------------

Item(110, FOOD, 5)
table.insert(bags[1] or {}, 110)
bags[1] = { 110 }
Options.CONJURED[110] = true
Fire("BAG_UPDATE_DELAYED")
Equal("conjured food preferred", Body("AeonUI Food"), Lines("/use [nocombat] item:110", "/use [nocombat] item:201"))

items[110].cooldown = { start = client.now - 10, duration = 30 }
Fire("BAG_UPDATE_COOLDOWN")
Equal("food on cooldown loses", Body("AeonUI Food"), Lines("/use [nocombat] item:301", "/use [nocombat] item:201"))
client:Advance(30)
Fire("BAG_UPDATE_COOLDOWN")
Equal("back once the cooldown ends", Body("AeonUI Food"), Lines("/use [nocombat] item:110", "/use [nocombat] item:201"))
items[110].cooldown = "secret"
Fire("BAG_UPDATE_COOLDOWN")
Equal("a secret cooldown excludes the item", Body("AeonUI Food"),
	Lines("/use [nocombat] item:301", "/use [nocombat] item:201"))
bags[1] = {}
items[110].cooldown = nil

-- Settings that change the text ---------------------------------------------------------------------------

Set("foodOnly", true)
Equal("Food Only drops the drink", Body("AeonUI Food"), Lines("/use [nocombat] item:301"))
Set("foodOnly", false)

Item(400, DRINK, 30)
Options.FOOD_AND_DRINK[400] = true
items[201].level = 1
table.insert(bags[0], 400)
Fire("BAG_UPDATE_DELAYED")
Equal("a food-and-drink item fills both lines once", Body("AeonUI Food"), Lines("/use [nocombat] item:400"))
Options.FOOD_AND_DRINK[400] = nil
bags[0][#bags[0]] = nil
items[201].level = 25

player.mana = 0
Fire("BAG_UPDATE_DELAYED")
Equal("no mana, no drink", Body("AeonUI Food"), Lines("/use [nocombat] item:301"))
player.mana = SECRET
Fire("BAG_UPDATE_DELAYED")
Equal("unreadable mana treated as none", Body("AeonUI Food"), Lines("/use [nocombat] item:301"))
player.mana = 1000

-- What stays when items run out ---------------------------------------------------------------------------

Fire("BAG_UPDATE_DELAYED")
local kept = Body("AeonUI Food")
bags[0] = { 500 }
Fire("BAG_UPDATE_DELAYED")
Equal("a used-up item stays on the macro", Body("AeonUI Food"), kept)
player.level = 20
Fire("UNIT_LEVEL", "player")
Equal("an item the player can no longer use leaves", Body("AeonUI Food"), "#showtooltip")
player.level = 40

-- Combat --------------------------------------------------------------------------------------------------

bags[0] = { 301, 201 }
client:SetCombat(true)
Fire("BAG_UPDATE_DELAYED")
Equal("nothing written in combat", Body("AeonUI Food"), "#showtooltip")
True("combat's end followed", eventFrame.events.PLAYER_REGEN_ENABLED)
client:SetCombat(false)
Fire("PLAYER_REGEN_ENABLED")
Equal("written when combat ends", Body("AeonUI Food"), Lines("/use [nocombat] item:301", "/use [nocombat] item:201"))
Equal("combat's end no longer followed", eventFrame.events.PLAYER_REGEN_ENABLED, nil)

-- The player's edits --------------------------------------------------------------------------------------

macros[Index("AeonUI Food")].body = "/say hi"
Fire("BAG_UPDATE_DELAYED")
Equal("an edited macro put right", Body("AeonUI Food"), Lines("/use [nocombat] item:301", "/use [nocombat] item:201"))
local before = #calls
Fire("BAG_UPDATE_DELAYED")
Equal("an unchanged macro not written", #calls, before)

-- A full General tab, and a macro the game cannot find ----------------------------------------------------

for index = 1, 119 do
	macros[#macros + 1] = { name = "Other " .. index, body = "" }
end
Set("drink", true)
Equal("not made while General is full", Index("AeonUI Drink"), 0)
Equal("the player told", printed[#printed]:find("General macros are full", 1, true) ~= nil, true)
local warnings = #printed
Fire("BAG_UPDATE_DELAYED")
Equal("told once", #printed, warnings)
DeleteMacro(Index("Other 1"))
Fire("UPDATE_MACROS")
Equal("made once there is room", Body("AeonUI Drink"), Lines("/use [nocombat] item:201"))
for index = #macros, 1, -1 do
	if macros[index].name:find("^Other") then
		table.remove(macros, index)
	end
end

-- Mana potions (Forever) ----------------------------------------------------------------------------------

AUI.can.manaPotions = true
Item(3827, "Restore Mana", 22)
table.insert(bags[0], 3827)
Set("drinkMana", true)
Equal("a mana potion in combat on the drink macro", Body("AeonUI Drink"),
	Lines("/use [combat] item:3827", "/use [nocombat] item:201"))
Equal("not on the food macro", Body("AeonUI Food"), Lines("/use [nocombat] item:301", "/use [nocombat] item:201"))
Item(6149, "Restore Mana", 31)
table.insert(bags[0], 6149)
Fire("BAG_UPDATE_DELAYED")
Equal("the better potion first", Body("AeonUI Drink"), Lines("/use [combat] item:6149", "/use [nocombat] item:201"))
player.level = 25
Fire("UNIT_LEVEL", "player")
Equal("a potion above the player's level skipped", Body("AeonUI Drink"),
	Lines("/use [combat] item:3827", "/use [nocombat] item:201"))
player.level = 40
Set("drinkMana", false)
Equal("the potion line goes when off", Body("AeonUI Drink"), Lines("/use [nocombat] item:201"))
AUI.can.manaPotions = false

-- Picking up ----------------------------------------------------------------------------------------------

client:SetCombat(true)
Macros:Pickup("food")
Equal("nothing picked up in combat", pickedUp, nil)
Equal("the player told", printed[#printed]:find("in combat", 1, true) ~= nil, true)
client:SetCombat(false)
Macros:Pickup("food")
Equal("picked up", pickedUp, "AeonUI Food")

-- Health ------------------------------------------------------------------------------------------------

Item(5509, "Healthstone", 24)
Item(19013, "Healthstone", 48)
Item(1710, "Healing Potion", 21)
Item(929, "Healing Potion", 12)
bags[2] = { 5509, 19013, 1710, 929, 929 }
Set("health", true)
Equal("the usable stone, then potions as often as carried", Body("AeonUI Health"),
	Lines("/castsequence reset=combat item:5509, item:1710, item:929, item:929"))
bags[2] = { 929 }
Fire("BAG_UPDATE_DELAYED")
Equal("one potion used plainly", Body("AeonUI Health"), Lines("/use item:929"))
bags[2] = {}
Fire("BAG_UPDATE_DELAYED")
Equal("the last potion stays on the macro", Body("AeonUI Health"), Lines("/use item:929"))
AUI.can.recuperate = true
bags[2] = { 5509 }
Fire("BAG_UPDATE_DELAYED")
Equal("Recuperate out of combat on Retail", Body("AeonUI Health"),
	Lines("/cast [nocombat] Recuperate", "/use [combat] item:5509"))
bags[2] = {}
Fire("BAG_UPDATE_DELAYED")
Equal("Recuperate alone without items", Body("AeonUI Health"), Lines("/cast [nocombat] Recuperate"))
AUI.can.recuperate = nil
Macros:Pickup("health")
Equal("the health macro picked up", pickedUp, "AeonUI Health")
Set("health", false)
Equal("the health macro deleted when off", Index("AeonUI Health"), 0)

-- Bandage (Forever) --------------------------------------------------------------------------------------

AUI.can.bandages = true
Item(3531, "First Aid", 0)
Item(8544, "First Aid", 0)
bags[3] = { 3531, 8544 }
firstAid = 100
Set("bandage", true)
True("skill changes followed while on", eventFrame.events.SKILL_LINES_CHANGED)
Equal("the best bandage the First Aid rank allows", Body("AeonUI Bandage"),
	Lines("/use [@player,nochanneling] item:3531"))
firstAid = 150
Fire("SKILL_LINES_CHANGED")
Equal("a higher rank allows a better one", Body("AeonUI Bandage"), Lines("/use [@player,nochanneling] item:8544"))
firstAid = nil
bags[3] = {}
Fire("BAG_UPDATE_DELAYED")
Equal("without First Aid, the last bandage stays", Body("AeonUI Bandage"),
	Lines("/use [@player,nochanneling] item:8544"))
Set("bandage", false)
Equal("the bandage macro deleted when off", Index("AeonUI Bandage"), 0)
Equal("skill changes no longer followed", eventFrame.events.SKILL_LINES_CHANGED, nil)
AUI.can.bandages = nil

-- Switching off -------------------------------------------------------------------------------------------

Set("drink", false)
Equal("switched off, deleted", Index("AeonUI Drink"), 0)
True("still followed while one is on", eventFrame.events.BAG_UPDATE_DELAYED)
client:SetCombat(true)
Set("food", false)
Equal("not deleted in combat", Index("AeonUI Food") > 0, true)
client:SetCombat(false)
Fire("PLAYER_REGEN_ENABLED")
Equal("deleted when combat ends", Index("AeonUI Food"), 0)
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "UNIT_LEVEL", "UPDATE_MACROS" }) do
	Equal(event .. " not followed while off", eventFrame.events[event], nil)
end
before = #calls
Fire("BAG_UPDATE_DELAYED")
Equal("nothing written while off", #calls, before)
Equal("settings saved account-wide", global.macros.food, nil)

-- A macro the game cannot find ----------------------------------------------------------------------------

createFails = true
Set("food", true)
Equal("the player told it was lost", printed[#printed]:find("could not find it", 1, true) ~= nil, true)
before = #calls
Fire("BAG_UPDATE_DELAYED")
Equal("a lost macro not made again", #calls, before)

print = _G.print
io.write(("check_macros: %d checks passed\n"):format(client.checks))
