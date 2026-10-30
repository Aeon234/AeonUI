local AUI = select(2, ...)

local Options = AUI.HiddenSettingsOptions

---The Hidden Settings module: features the game has but its settings never show, turned on by holding hidden console
---variables. Quest Items holds the quest items' loot sparkle. Its state is account-wide, in `global.hiddenSettings`:
---`lootSparkles.questItems` (absent means off) and `saved.lootSparkles`, the player's values from before the hold.
---@class AUIHiddenSettings
---@field questItems AUICVarHolder? created at start where the client has the loot sparkle's console variable
local HiddenSettings = {}
AUI.HiddenSettings = HiddenSettings

---@return table? state `global.hiddenSettings`, created on first use; nil while saved data cannot be used
local function State()
	local global = AUI.Profile:Global()

	if not global then
		return nil
	end

	if type(global.hiddenSettings) ~= "table" then
		global.hiddenSettings = {}
	end

	return global.hiddenSettings
end

---@return table<string, string>? saved the loot sparkle's save, created on first use
local function LootSparkleSave()
	local state = State()

	if not state then
		return nil
	end

	if type(state.saved) ~= "table" then
		state.saved = {}
	end

	if type(state.saved.lootSparkles) ~= "table" then
		state.saved.lootSparkles = {}
	end

	return state.saved.lootSparkles
end

local function ClearLootSparkleSave()
	local state = State()

	if state and type(state.saved) == "table" then
		state.saved.lootSparkles = nil
	end
end

---@return boolean
local function HasLootSparkleSave()
	local state = State()
	local saved = state and type(state.saved) == "table" and state.saved.lootSparkles

	return type(saved) == "table" and next(saved) ~= nil
end

---Holds the loot sparkle while Quest Items is on. Otherwise gives back values a hold left saved, as when it was turned
---off in combat and the session ended before combat did.
function HiddenSettings:Start()
	if not AUI.can.lootSparkle then
		return
	end

	self.questItems = AUI.CreateCVarHolder("lootSparkle", Options.LOOT_SPARKLE, Options.LOOT_SPARKLE_TRIGGERS,
		LootSparkleSave, ClearLootSparkleSave)

	if self:IsQuestItems() then
		self.questItems:Hold()
	elseif HasLootSparkleSave() then
		self.questItems:Release()
	end
end

---@return boolean
function HiddenSettings:IsQuestItems()
	local state = State()

	return state ~= nil and type(state.lootSparkles) == "table" and state.lootSparkles.questItems == true
end

---@param on boolean
function HiddenSettings:SetQuestItems(on)
	local state = State()

	if not state or not self.questItems then
		return
	end

	if type(state.lootSparkles) ~= "table" then
		state.lootSparkles = {}
	end

	state.lootSparkles.questItems = on or nil

	if on then
		self.questItems:Hold()
	else
		self.questItems:Release()
	end
end
