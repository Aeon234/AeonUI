local AUI = select(2, ...)

local L = AUI.L
local Markers = AUI.WorldMapMarkers

-- The account-wide key in `AeonUIDB.global` holding the spots found in game, `{ uiMapID, x, y }` by category key.
local STORE_KEY = "worldMapSpots"
-- The racial's buff lasts minutes; an aura of that ID lasting less is not a spot's.
local MIN_BUFF = 60
-- The buff lands a moment after the cast: looked for this long after it, then again until there have been MAX_TRIES.
local FIRST_LOOK, RETRY_DELAY, MAX_TRIES = 0.2, 0.5, 4
-- A buff that began this long before the cast's recorded time still counts.
local CAST_SLACK = 1
-- Positions are kept to a thousandth of the map.
local PRECISION = 1000
local SECRET = {} --[[@as AuraData]]

---@class AUIWorldMapCast
---@field category AUIWorldMapCategory
---@field map number
---@field x number
---@field y number
---@field time number `GetTime()` at the cast, less `CAST_SLACK`
---@field tries integer

---Learns Skyborne spots: when the player casts their race's racial and its buff follows, the spot is saved account-wide
---and added to the markers. Follows the cast only while the player's race has a category whose switch is on.
---@class AUIWorldMapSpots
---@field loaded boolean the saved spots are in the marker index
---@field category AUIWorldMapCategory? the category whose racial is followed
---@field waiting AUIWorldMapCast? a cast whose buff waits for combat to end
---@field learned table<AUIWorldMapMarker, number[]> each learned marker's saved spot
local Spots = { loaded = false, learned = {} }
AUI.WorldMapSpots = Spots

---@return table<string, number[][]>? store the saved spots by category key; nil while the saved data cannot be used
function Spots:Store()
	local global = AUI.Profile:Global()

	if not global then
		return nil
	end

	if type(global[STORE_KEY]) ~= "table" then
		global[STORE_KEY] = {}
	end

	return global[STORE_KEY]
end

---@param map number
---@param x number 0 to 1 across that map
---@param y number
---@return number? continent
---@return number? worldX in yards
---@return number? worldY
local function World(map, x, y)
	local continent, position = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(x, y))

	if not (continent and position) then
		return nil
	end

	local wx, wy = position:GetXY()

	return continent, wx, wy
end

---Adds the saved spots to the marker index, once a session, dropping those the shipped markers now hold.
function Spots:Load()
	if self.loaded then
		return
	end

	self.loaded = true

	local store = self:Store()

	if not store then
		return
	end

	for _, category in ipairs(Markers.CATEGORIES) do
		local list = category.racial and store[category.key]

		if type(list) == "table" then
			for index = #list, 1, -1 do
				local spot = list[index]
				local valid = type(spot) == "table" and type(spot[1]) == "number" and type(spot[2]) == "number"
					and type(spot[3]) == "number"

				if not valid or Markers:Known(category.key, spot[1], spot[2], spot[3], World, true) then
					table.remove(list, index)
				else
					self.learned[Markers:AddLearned(category.key, spot[1], spot[2], spot[3])] = spot
				end
			end
		end
	end
end

---Follows the racial of the player's race while its category is shown, and stops otherwise.
---@param race number? the player's race ID; nil stops
---@param shown table<string, boolean> the categories turned on
function Spots:Apply(race, shown)
	local wanted

	for _, category in ipairs(Markers.CATEGORIES) do
		if race and category.racial and category.race == race and shown[category.key] then
			wanted = category
		end
	end

	if wanted == self.category then
		return
	end

	self.category = wanted

	if wanted then
		AUI.Events:Register("UNIT_SPELLCAST_SUCCEEDED", self, self.OnCast)
	else
		AUI.Events:UnregisterAll(self)
		self.waiting = nil
	end
end

---@param _ string the event
---@param unit string
function Spots:OnCast(_, unit, ...)
	local _, spellID = ...
	local category = self.category

	if unit ~= "player" or issecretvalue(spellID) or not category or spellID ~= category.racial then
		return
	end

	local map = C_Map.GetBestMapForUnit("player")
	local position = map and C_Map.GetPlayerMapPosition(map, "player")

	if not position then
		return
	end

	local x, y = position:GetXY()
	local cast = {
		category = category,
		map = map,
		x = math.floor(x * PRECISION + 0.5) / PRECISION,
		y = math.floor(y * PRECISION + 0.5) / PRECISION,
		time = GetTime() - CAST_SLACK,
		tries = 0,
	}

	C_Timer.After(FIRST_LOOK, function()
		Spots:Check(cast)
	end)
end

---@return boolean readable the player's auras can be read now
local function AurasReadable()
	return not (InCombatLockdown() or (C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret()))
end

---@param cast AUIWorldMapCast
---@return boolean? found the cast's buff is on the player, begun with the cast; nil when it cannot be read
local function HasBuff(cast)
	local aura = AUI:Readable(C_UnitAuras.GetPlayerAuraBySpellID(cast.category.buff --[[@as number]]), SECRET)

	if aura == SECRET then
		return nil
	end

	if not aura then
		return false
	end

	local duration = AUI:Readable(aura.duration)
	local expiration = AUI:Readable(aura.expirationTime)

	if not (duration and expiration) then
		return nil
	end

	return duration >= MIN_BUFF and expiration - duration >= cast.time
end

---Looks for the cast's buff: saves the spot once it is on, looks again while it may still land, and waits for combat
---to end while auras cannot be read.
---@param cast AUIWorldMapCast
function Spots:Check(cast)
	if self.category ~= cast.category then
		return
	end

	cast.tries = cast.tries + 1

	local found

	if AurasReadable() then
		found = HasBuff(cast)
	end

	if found then
		self:Save(cast)
	elseif found == nil then
		self.waiting = cast
		AUI.Events:Register("PLAYER_REGEN_ENABLED", self, self.OnCombatEnded)
	elseif cast.tries < MAX_TRIES then
		C_Timer.After(RETRY_DELAY, function()
			Spots:Check(cast)
		end)
	end
end

function Spots:OnCombatEnded()
	AUI.Events:Unregister("PLAYER_REGEN_ENABLED", self)

	local cast = self.waiting

	self.waiting = nil

	if cast and self.category == cast.category and AurasReadable() and HasBuff(cast) then
		self:Save(cast)
	end
end

---Saves a cast's spot and puts it on the map, unless its category already knows it.
---@param cast AUIWorldMapCast
function Spots:Save(cast)
	local store = self:Store()
	local key = cast.category.key

	if not store or Markers:Known(key, cast.map, cast.x, cast.y, World) ~= false then
		return
	end

	if type(store[key]) ~= "table" then
		store[key] = {}
	end

	local list = store[key]
	local spot = { cast.map, cast.x, cast.y }

	list[#list + 1] = spot
	self.learned[Markers:AddLearned(key, cast.map, cast.x, cast.y)] = spot

	local info = C_Map.GetMapInfo(cast.map)

	AUI:Print(L["%s saved on your map: %s %.1f, %.1f"], L[cast.category.label], info and info.name or UNKNOWN,
		cast.x * 100, cast.y * 100)
	AUI.WorldMap:Redraw()
end

---@return boolean any this account has saved a spot
function Spots:AnyLearned()
	for _, list in pairs(self:Store() or {}) do
		if type(list) == "table" and #list > 0 then
			return true
		end
	end

	return false
end

---Forgets one learned spot: takes it out of the saved spots and the index. The caller redraws.
---@param marker AUIWorldMapMarker
function Spots:Forget(marker)
	local spot = self.learned[marker]
	local store = self:Store()
	local list = store and store[marker.category]

	if type(list) == "table" then
		for index = #list, 1, -1 do
			if list[index] == spot then
				table.remove(list, index)
			end
		end
	end

	self.learned[marker] = nil
	Markers:RemoveLearned(marker)
end

---Forgets every spot this account saved, and redraws.
function Spots:ForgetAll()
	local store = self:Store()

	for _, category in ipairs(Markers.CATEGORIES) do
		if store and category.racial then
			store[category.key] = nil
		end
	end

	for marker in pairs(self.learned) do
		Markers:RemoveLearned(marker)
	end

	self.learned = {}
	AUI.WorldMap:Redraw()
end
