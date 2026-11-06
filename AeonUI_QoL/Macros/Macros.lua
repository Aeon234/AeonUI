local AUI = select(2, ...)

local L = AUI.L
local Options = AUI.MacrosOptions

local UPDATE_KEY = "macros"

-- Events followed while a macro is on: bags and cooldowns change the best item, a level makes items usable, and a
-- deleted macro frees a slot in General.
local EVENTS = { "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "UNIT_LEVEL", "UPDATE_MACROS" }

---What a bag scan found: the best food and drink, the best mana potion when a macro wants one, whether the player
---has mana, and the health and bandage macros' items while they are on.
---@class AUIMacroScan
---@field food AUIMacroCandidate?
---@field drink AUIMacroCandidate?
---@field mana number?
---@field hasMana boolean
---@field health number[]?
---@field bandage number?

---The macros module: account macros kept on the best item the character carries, rewritten out of combat. Its
---settings are account-wide, in `global.macros` (absent means off): `food`, `drink`, `health`, `bandage`, `foodOnly`, and `foodMana` and `drinkMana` for a mana potion in
---combat in each.
---Nothing is written before the first `PLAYER_ENTERING_WORLD`, when the game's macros are loaded. Only switching a
---macro off deletes it.
---@class AUIMacros
---@field ready boolean the game's macros are loaded
---@field pending boolean an update waits for combat to end
---@field following boolean the bag, level and macro events are registered
---@field followingSkills boolean skill changes are registered, for the bandage macro
---@field warnedFull boolean the player was told General is full
---@field lost table<string, true> macros made that the game could not find by name; left alone until a reload
---@field refresh table<string, true> macros to rewrite even when they would keep their item, by settings key
---@field toDelete table<string, true> macros switched off and not yet deleted, by settings key
---@field requested table<number, true> items whose data was asked for and has not arrived
local Macros = {
	ready = false,
	pending = false,
	following = false,
	followingSkills = false,
	warnedFull = false,
	lost = {},
	refresh = {},
	toDelete = {},
	requested = {},
}
AUI.Macros = Macros

---@return table? state `global.macros`, created on first use; nil while saved data cannot be used
local function State()
	local global = AUI.Profile:Global()

	if not global then
		return nil
	end

	if type(global.macros) ~= "table" then
		global.macros = {}
	end

	return global.macros
end

---@param key string a macro's key, `foodOnly`, `foodMana` or `drinkMana`
---@return boolean
function Macros:IsOn(key)
	local state = State()

	return state ~= nil and state[key] == true
end

---@return boolean
function Macros:AnyOn()
	for _, key in ipairs(Options.KEYS) do
		if self:IsOn(key) then
			return true
		end
	end

	return false
end

---@param key string a macro's key, `foodOnly`, `foodMana` or `drinkMana`
---@param on boolean
function Macros:Set(key, on)
	local state = State()

	if not state then
		return
	end

	state[key] = on or nil

	if Options.NAMES[key] and not on then
		self.toDelete[key] = true
	elseif key == "foodOnly" or key == "foodMana" then
		self.refresh.food = true
	elseif key == "drinkMana" then
		self.refresh.drink = true
	end

	self:Follow()
	self:Update()
end

function Macros:Start()
	if not AUI.can.macros then
		return
	end

	AUI.Events:Register("PLAYER_ENTERING_WORLD", self, self.OnEnteringWorld)
end

function Macros:OnEnteringWorld()
	AUI.Events:Unregister("PLAYER_ENTERING_WORLD", self)
	self.ready = true
	self:Follow()
	self:Update()
end

---Registers the events while a macro is on and unregisters them once none is.
function Macros:Follow()
	local wanted = self.ready and self:AnyOn()
	local skills = wanted and AUI.can.bandages == true and self:IsOn("bandage")

	if skills ~= self.followingSkills then
		self.followingSkills = skills

		if skills then
			AUI.Events:Register("SKILL_LINES_CHANGED", self, self.OnEvent)
		else
			AUI.Events:Unregister("SKILL_LINES_CHANGED", self)
		end
	end

	if wanted == self.following then
		return
	end

	self.following = wanted

	for _, event in ipairs(EVENTS) do
		if wanted then
			AUI.Events:Register(event, self, self.OnEvent)
		else
			AUI.Events:Unregister(event, self)
		end
	end

	if not wanted then
		AUI.Events:Unregister("ITEM_DATA_LOAD_RESULT", self)
		AUI.Events:Cancel(UPDATE_KEY)
		wipe(self.requested)
	end
end

---@param event string
---@param arg1 any
---@param arg2 any
function Macros:OnEvent(event, arg1, arg2)
	if event == "UNIT_LEVEL" and arg1 ~= "player" then
		return
	end

	if event == "ITEM_DATA_LOAD_RESULT" then
		if not self.requested[arg1] then
			return
		end

		self.requested[arg1] = nil

		if next(self.requested) == nil then
			AUI.Events:Unregister("ITEM_DATA_LOAD_RESULT", self)
		end

		-- A failed load would be asked for again by the update; the next bag change retries it instead.
		if not arg2 then
			return
		end
	end

	AUI.Events:Coalesce(UPDATE_KEY, function()
		self:Update()
	end)
end

---Asks for an item's data once; its arrival brings another update.
---@param id number
function Macros:Request(id)
	if self.requested[id] then
		return
	end

	self.requested[id] = true
	AUI.Events:Register("ITEM_DATA_LOAD_RESULT", self, self.OnEvent)
	C_Item.RequestLoadItemDataByID(id)
end

---@param id number
---@return number? level the item's required level, nil while its data is loading
function Macros:RequiredLevel(id)
	local _, _, _, _, minLevel = C_Item.GetItemInfo(id)
	local level = AUI:Readable(minLevel)

	if level == nil then
		self:Request(id)
	end

	return level
end

---@param id number
---@param playerLevel number?
---@return AUIMacroCandidate? candidate nil while the item is loading, above the player's level or its cooldown unreadable
function Macros:Candidate(id, playerLevel)
	local level = self:RequiredLevel(id)

	if not Options.LevelAllowed(level, playerLevel) then
		return nil
	end

	local start, duration, enabled = C_Item.GetItemCooldown(id)
	start, duration, enabled = AUI:Readable(start), AUI:Readable(duration), AUI:Readable(enabled)

	if start == nil or duration == nil or not enabled then
		return nil
	end

	return {
		id = id,
		level = level,
		ready = start == 0 or duration == 0 or start + duration <= GetTime(),
		conjured = Options.CONJURED[id] == true,
	}
end

---@return AUIMacroScan
function Macros:Scan()
	local playerLevel = AUI:Readable(UnitLevel("player"))
	local maxMana = AUI:Readable(UnitPowerMax("player", Enum.PowerType.Mana), 0)
	local foodName, drinkName = C_Spell.GetSpellName(Options.FOOD_SPELL), C_Spell.GetSpellName(Options.DRINK_SPELL)
	local scan = { hasMana = type(maxMana) == "number" and maxMana > 0 }
	local seen = {}

	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local id = C_Container.GetContainerItemID(bag, slot)

			if id and not seen[id] then
				seen[id] = true
				local spellName, spellID = C_Item.GetItemSpell(id)

				if spellName == nil and not C_Item.IsItemDataCachedByID(id) then
					self:Request(id)
				end

				local isFood, isDrink = Options.Kind(id, spellName, spellID, foodName, drinkName)
				local candidate = (isFood or isDrink) and self:Candidate(id, playerLevel) or nil

				if candidate and isFood and Options.Better(candidate, scan.food) then
					scan.food = candidate
				end

				if candidate and isDrink and Options.Better(candidate, scan.drink) then
					scan.drink = candidate
				end
			end
		end
	end

	if scan.hasMana and AUI.can.manaPotions and (self:IsOn("foodMana") or self:IsOn("drinkMana")) then
		for _, id in ipairs(Options.MANA_POTIONS) do
			if C_Item.GetItemCount(id) > 0 and self:Usable(id, playerLevel) then
				scan.mana = id

				break
			end
		end
	end

	if self:IsOn("health") then
		scan.health = self:HealthSteps(playerLevel)
	end

	if AUI.can.bandages and self:IsOn("bandage") then
		scan.bandage = self:Bandage(playerLevel)
	end

	return scan
end

---@param id number
---@param playerLevel number?
---@return boolean
function Macros:Usable(id, playerLevel)
	return Options.LevelAllowed(self:RequiredLevel(id), playerLevel)
end

---@param playerLevel number?
---@return number? bandage the best bandage carried that the player's level and First Aid rank allow
function Macros:Bandage(playerLevel)
	local info = C_SkillInfo.GetSkillLineInfoByID(Options.FIRST_AID)
	local rank = AUI:Readable(info and info.rank)

	if type(rank) ~= "number" then
		return nil
	end

	for _, bandage in ipairs(Options.BANDAGES) do
		if rank >= bandage.rank and C_Item.GetItemCount(bandage.id) > 0 and self:Usable(bandage.id, playerLevel) then
			return bandage.id
		end
	end

	return nil
end

---@param playerLevel number?
---@return number[] steps the best healthstone carried, then the healing potions carried, best first
function Macros:HealthSteps(playerLevel)
	local stone
	local potions = {}

	for _, id in ipairs(Options.HEALTHSTONES) do
		if C_Item.GetItemCount(id) > 0 and self:Usable(id, playerLevel) then
			stone = id

			break
		end
	end

	for _, id in ipairs(Options.HEALING_POTIONS) do
		local count = C_Item.GetItemCount(id)

		if count > 0 and self:Usable(id, playerLevel) then
			potions[#potions + 1] = { id = id, count = count }
		end
	end

	return Options.HealthSteps(stone, potions)
end

---@param key string
---@param scan AUIMacroScan
---@return string? body the text from what is carried
local function Fresh(key, scan)
	local drink = scan.hasMana and scan.drink or nil
	local mana = Macros:IsOn(key .. "Mana") and scan.mana or nil

	if key == "bandage" then
		return Options.BandageBody(scan.bandage)
	end

	if key == "health" then
		local recuperate = AUI.can.recuperate and C_Spell.GetSpellName(Options.RECUPERATE) or nil

		return Options.HealthBody(scan.health or {}, recuperate)
	end

	if key == "drink" then
		return Options.DrinkBody(drink and drink.id, mana)
	end

	if Macros:IsOn("foodOnly") then
		return Options.FoodBody(scan.food and scan.food.id, nil, mana)
	end

	local food, pairedDrink = Options.Pair(scan.food, drink, Options.FOOD_AND_DRINK)

	return Options.FoodBody(food and food.id, pairedDrink and pairedDrink.id, mana)
end

---@param name string
---@param body string
---@param exists boolean
function Macros:Write(name, body, exists)
	if exists then
		EditMacro(name, name, nil, body)

		return
	end

	if self.lost[name] then
		return
	end

	if GetNumMacros() >= Constants.MacroConsts.MAX_ACCOUNT_MACROS then
		if not self.warnedFull then
			self.warnedFull = true
			AUI:Warn(L["General macros are full, so %s could not be made. Delete one and it will be added."], name)
		end

		return
	end

	CreateMacro(name, Options.ICON, body, false)

	if GetMacroInfo(name) == nil then
		self.lost[name] = true
		AUI:Warn(L["%s was made, but the game could not find it by name, so it won't be made again until you reload."],
			name)
	end
end

---@param key string
---@param scan AUIMacroScan
function Macros:Keep(key, scan)
	local name = Options.NAMES[key]
	local _, _, current = GetMacroInfo(name)
	local refresh = self.refresh[key] == true

	self.toDelete[key] = nil
	self.refresh[key] = nil

	local body = Options.Wanted(Fresh(key, scan), current, refresh, function(id)
		local level = self:RequiredLevel(id)

		return level == nil or Options.LevelAllowed(level, AUI:Readable(UnitLevel("player")))
	end)

	if body and body ~= current then
		self:Write(name, body, current ~= nil)
	end
end

---Writes each macro that is on and deletes each switched off, or waits for combat to end.
function Macros:Update()
	if not self.ready then
		return
	end

	if InCombatLockdown() then
		if not self.pending then
			self.pending = true
			AUI.Events:Register("PLAYER_REGEN_ENABLED", self, self.OnCombatEnded)
		end

		return
	end

	local scan = self:AnyOn() and self:Scan() or nil

	for _, key in ipairs(Options.KEYS) do
		if scan and self:IsOn(key) then
			self:Keep(key, scan)
		elseif self.toDelete[key] then
			self.toDelete[key] = nil
			local index = GetMacroIndexByName(Options.NAMES[key])

			if index > 0 then
				DeleteMacro(index)
			end
		end
	end
end

function Macros:OnCombatEnded()
	AUI.Events:Unregister("PLAYER_REGEN_ENABLED", self)
	self.pending = false
	self:Update()
end

---Puts a macro on the cursor to place on an action bar, writing it first.
---@param key string a macro's key
function Macros:Pickup(key)
	if InCombatLockdown() then
		AUI:Warn(L["Macros can't be picked up in combat."])

		return
	end

	self:Update()
	local index = GetMacroIndexByName(Options.NAMES[key])

	if index > 0 then
		PickupMacro(index)
	else
		AUI:Warn(L["Make room in General macros first."])
	end
end
