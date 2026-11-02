local AUI = select(2, ...)

local Options = AUI.HiddenSettingsOptions

---The Hidden Settings module: features the game has but its settings never show, turned on by holding hidden console
---variables. Quest Items holds the quest items' loot sparkle; the approached-object rows (Forever) are
---`AUI.ApproachSparkles`. Its state is account-wide, in `global.hiddenSettings`: the rows in `lootSparkles` (absent
---means off), in `saved` each holder's record of the player's values from before its hold, and in `containers` the
---object IDs of containers the account has looted, oldest first.
---@class AUIHiddenSettings
---@field questItems AUICVarHolder? created at start where the client has the loot sparkle's console variable
---@field containerLookup table<number, true>? `containers` as a lookup, rebuilt after each change
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

---@param key string a holder's save: `lootSparkles` or `softTarget`
---@return table<string, string>? saved created on first use
function HiddenSettings:Save(key)
	local state = State()

	if not state then
		return nil
	end

	if type(state.saved) ~= "table" then
		state.saved = {}
	end

	if type(state.saved[key]) ~= "table" then
		state.saved[key] = {}
	end

	return state.saved[key]
end

---@param key string
function HiddenSettings:ClearSave(key)
	local state = State()

	if state and type(state.saved) == "table" then
		state.saved[key] = nil
	end
end

---@param key string
---@return boolean
function HiddenSettings:HasSave(key)
	local state = State()
	local saved = state and type(state.saved) == "table" and state.saved[key]

	return type(saved) == "table" and next(saved) ~= nil
end

---@param key string a row: `questItems` or one of `Options.SPARKLE_TYPES`
---@return boolean
local function Row(key)
	local state = State()

	return state ~= nil and type(state.lootSparkles) == "table" and state.lootSparkles[key] == true
end

---@param key string
---@param on boolean
---@return boolean stored false while saved data cannot be used
local function SetRow(key, on)
	local state = State()

	if not state then
		return false
	end

	if type(state.lootSparkles) ~= "table" then
		state.lootSparkles = {}
	end

	state.lootSparkles[key] = on or nil

	return true
end

---Holds the loot sparkle while Quest Items is on. Otherwise gives back values a hold left saved, as when it was turned
---off in combat and the session ended before combat did. Then starts the approached objects where the client has them.
function HiddenSettings:Start()
	self.containerLookup = nil

	if AUI.can.lootSparkle then
		self.questItems = AUI.CreateCVarHolder("lootSparkle", Options.LOOT_SPARKLE, Options.LOOT_SPARKLE_TRIGGERS,
			function()
				return self:Save("lootSparkles")
			end, function()
				self:ClearSave("lootSparkles")
			end)

		if self:IsQuestItems() then
			self.questItems:Hold()
		elseif self:HasSave("lootSparkles") then
			self.questItems:Release()
		end
	end

	if AUI.can.approachSparkles then
		AUI.ApproachSparkles:Start()
	end
end

---@return boolean
function HiddenSettings:IsQuestItems()
	return Row("questItems")
end

---@param on boolean
function HiddenSettings:SetQuestItems(on)
	if not self.questItems or not SetRow("questItems", on) then
		return
	end

	if on then
		self.questItems:Hold()
	else
		self.questItems:Release()
	end
end

---@return number[]? list `containers`, created on first use
local function ContainerList()
	local state = State()

	if not state then
		return nil
	end

	if type(state.containers) ~= "table" then
		state.containers = {}
	end

	return state.containers
end

---@return table<number, true> containers the object IDs of containers the account has looted
function HiddenSettings:Containers()
	if self.containerLookup then
		return self.containerLookup
	end

	local lookup = {}

	for _, id in ipairs(ContainerList() or {}) do
		if type(id) == "number" then
			lookup[id] = true
		end
	end

	self.containerLookup = lookup

	return lookup
end

---@param id number a looted container's object ID
function HiddenSettings:LearnContainer(id)
	local list = ContainerList()

	if list and Options.Learn(list, id, Options.CONTAINER_CAP) then
		self.containerLookup = nil
	end
end

---@param kind string one of `Options.SPARKLE_TYPES`
---@return boolean
function HiddenSettings:IsSparkle(kind)
	return Row(kind)
end

---@param kind string one of `Options.SPARKLE_TYPES`
---@param on boolean
function HiddenSettings:SetSparkle(kind, on)
	if SetRow(kind, on) then
		AUI.ApproachSparkles:Refresh()
	end
end
