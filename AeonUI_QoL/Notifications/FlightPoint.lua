local AUI = select(2, ...)

local Options = AUI.NotificationOptions

local TAXI_GOSSIP_ICON = "Interface\\GossipFrame\\TaxiGossipIcon"

local EVENTS = {
	"ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD", "PLAYER_STOPPED_MOVING",
	"GOSSIP_SHOW", "TAXIMAP_OPENED", "TAXIMAP_CLOSED", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED",
	"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
}

-- The events after which the zone's flight points are read again.
local REFRESH = {
	ZONE_CHANGED = true, ZONE_CHANGED_INDOORS = true, ZONE_CHANGED_NEW_AREA = true, PLAYER_ENTERING_WORLD = true,
	TAXIMAP_OPENED = true, TAXIMAP_CLOSED = true,
}

---A character's saved flight points, in `AeonUIDB.global.flightPoints` under its GUID.
---@class AUIFlightPointRecord
---@field nodes table<number, boolean> each node a flight map listed or a flight master was spoken to at, and whether the
---character knows it
---@field seenMaps table<number, boolean> the maps a flight map has saved the character's nodes for

---Flight Point: one line naming the nearest unlearned flight point, outside combat and off a taxi, for a while on
---entering a zone that has one and for as long as the player is in its town. Which nodes a character knows is saved
---each time a flight map opens or a flight master is spoken to. Nothing runs while the notice is off.
---@class AUIFlightPointNotice
---@field following boolean the events are registered
---@field inCombat boolean
---@field cachedZone number? the zone the cached entries belong to
---@field cachedMap number? the map they came from
---@field cachedEntries AUIFlightPointEntry[]?
---@field entryZone number? the zone the player was last in
---@field entryNotified boolean the entry reminder has run for this zone
---@field entryNode table? the node the entry reminder is about
---@field entryPlace string? its place
---@field entryTimer table? ends the entry reminder
---@field gossipIcon number|false|nil the taxi gossip option's file ID; false when the client has none
local FlightPointNotice = {
	following = false,
	inCombat = false,
	entryNotified = false,
}
AUI.FlightPointNotice = FlightPointNotice

---@param create boolean? makes the record when it is missing
---@return AUIFlightPointRecord? record nil while saved data cannot be used, or when none exists and `create` is unset
local function Record(create)
	local global = AUI.Profile:Global()

	if not global then
		return nil
	end

	local characterID = AUI.Profile.characterID
	local all = global.flightPoints
	local record = type(all) == "table" and all[characterID] or nil

	if not record and create then
		if type(all) ~= "table" then
			all = {}
			global.flightPoints = all
		end

		record = { nodes = {}, seenMaps = {} }
		all[characterID] = record
	end

	return record
end

---@param mapID number?
---@return number? mapID the map whose flight points the given map shares, or itself
local function SharedMap(mapID)
	return mapID and Options.FLIGHT_POINT_SAME_MAPS[mapID] or mapID
end

---@param mapID number?
---@param mapType number an `Enum.UIMapType`
---@return number? mapID the map's ancestor of that type, or the map itself
local function Ancestor(mapID, mapType)
	local info = mapID and C_Map.GetMapInfo(mapID)

	while info and info.mapType > mapType and info.parentMapID and info.parentMapID > 0 do
		info = C_Map.GetMapInfo(info.parentMapID)
	end

	return info and info.mapType == mapType and info.mapID or nil
end

---@param record AUIFlightPointRecord?
---@param zone number
---@return boolean seen a flight map of the zone's continent has saved the character's nodes
local function Seen(record, zone)
	if not record then
		return false
	end

	local continent = Ancestor(zone, Enum.UIMapType.Continent) or zone

	return record.seenMaps[continent] == true or record.seenMaps[Options.FLIGHT_POINT_TAXI_MAPS[continent]] == true
end

---@param mapID number?
---@param position table? a map position
---@return table? world the position in the world; nil when unknown
---@return boolean blocked the position is secret
---@return number? continent
local function WorldPosition(mapID, position)
	if not mapID or not position then
		return nil, false
	end

	if not AUI:Readable(position.x) or not AUI:Readable(position.y) then
		return nil, true
	end

	local continent, world = C_Map.GetWorldPosFromMapPos(mapID, position)

	if not world then
		return nil, false
	end

	if not AUI:Readable(world.x) or not AUI:Readable(world.y) then
		return nil, true
	end

	return world, false, continent
end

---@param zone number
---@param world table?
---@param continent number?
---@return boolean inZone the world position lies on the zone's map
local function InZone(zone, world, continent)
	if not world or not continent then
		return false
	end

	local _, position = C_Map.GetMapPosFromWorldPos(continent, world, zone)

	if not position or not AUI:Readable(position.x) or not AUI:Readable(position.y) then
		return false
	end

	return position.x >= 0 and position.x <= 1 and position.y >= 0 and position.y <= 1
end

function FlightPointNotice:Forget()
	self.cachedZone, self.cachedMap, self.cachedEntries = nil, nil, nil
end

---The zone's flight points, or its nearest ancestor map's when its own map lists none.
---@param zone number
---@return number? map the map they came from
---@return AUIFlightPointEntry[]? entries nil while a position is secret
function FlightPointNotice:Entries(zone)
	if self.cachedZone == zone and self.cachedEntries then
		return self.cachedMap, self.cachedEntries
	end

	local map, nodes = zone, C_TaxiMap.GetTaxiNodesForMap(zone)

	if not nodes[1] then
		local info = C_Map.GetMapInfo(zone)

		map, nodes = nil, nil

		while info and info.parentMapID and info.parentMapID > 0 do
			local parent = info.parentMapID
			local list = C_TaxiMap.GetTaxiNodesForMap(parent)

			info = C_Map.GetMapInfo(parent)

			if list[1] then
				map, nodes = parent, list
				break
			end

			if not info or info.mapType <= Enum.UIMapType.Continent then
				break
			end
		end
	end

	local entries = {}

	for index, node in ipairs(nodes or entries) do
		local world, blocked, continent = WorldPosition(map, node.position)

		if blocked then
			return nil, nil
		end

		entries[index] = { node = node, world = world, inZone = InZone(zone, world, continent) }
	end

	self.cachedZone, self.cachedMap, self.cachedEntries = zone, map, entries

	return map, entries
end

---@param zoneWide boolean every flight point on the zone's map counts, near or not
---@return string? place the nearest flight point to learn
---@return boolean ask a flight point here is unsettled
---@return table? node the node the answer is about
function FlightPointNotice:Nearest(zoneWide)
	if self.inCombat or UnitOnTaxi("player") then
		return nil, false
	end

	local here = C_Map.GetBestMapForUnit("player")
	local zone = Ancestor(SharedMap(here), Enum.UIMapType.Zone)

	if not zone then
		return nil, false
	end

	local player, secret = WorldPosition(here, here and C_Map.GetPlayerMapPosition(here, "player"))

	if secret then
		return nil, false
	end

	local map, entries = self:Entries(zone)

	if not map or not entries then
		return nil, false
	end

	local info = C_Map.GetMapInfo(zone)
	local record = Record()

	return Options:FlightPointNearest(entries, {
		zone = zone,
		map = map,
		zoneName = info and info.name or "",
		player = player,
		subzone = AUI:Readable(GetSubZoneText(), "") or "",
		side = UnitFactionGroup("player"),
		known = record and record.nodes,
		seen = Seen(record, zone),
		zoneWide = zoneWide,
	})
end

function FlightPointNotice:CancelEntry()
	if self.entryTimer then
		self.entryTimer:Cancel()
	end

	self.entryTimer, self.entryNode, self.entryPlace = nil, nil, nil
end

---Starts the entry reminder the first time a zone has a flight point to learn or settle.
function FlightPointNotice:CheckEntry()
	local zone = Ancestor(C_Map.GetBestMapForUnit("player"), Enum.UIMapType.Zone)

	if zone ~= self.entryZone then
		self:CancelEntry()
		self.entryZone, self.entryNotified = zone, false
	end

	if zone and not self.entryNotified then
		local place, ask, node = self:Nearest(true)

		if place or ask then
			self.entryNotified, self.entryNode, self.entryPlace = true, node, place
			self.entryTimer = C_Timer.NewTimer(Options.FLIGHT_POINT_HOLD, function()
				self.entryTimer, self.entryNode, self.entryPlace = nil, nil, nil
				self:Check()
			end)
		end
	end
end

function FlightPointNotice:Check()
	if not self.following then
		AUI.Notifications:Dismiss("flightPoint")

		return
	end

	self:CheckEntry()

	local place, ask = self:Nearest(false)

	if place or ask then
		AUI.Notifications:Show("flightPoint", Options:FlightPointText(place))
	elseif self.entryTimer and self.entryNode and not self.inCombat and not UnitOnTaxi("player")
		and Options:FlightPointKind(self.entryNode, UnitFactionGroup("player"), (Record() or {}).nodes, false) then
		AUI.Notifications:Show("flightPoint", Options:FlightPointText(self.entryPlace))
	else
		AUI.Notifications:Dismiss("flightPoint")
	end
end

---Saves every node the open flight map lists and whether the character knows it.
function FlightPointNotice:SaveFlightMap()
	local record = Record(true)
	local taxiMap = record and GetTaxiMapID()

	if not taxiMap then
		return
	end

	local here = C_Map.GetBestMapForUnit("player")
	local taxiContinent = Ancestor(taxiMap, Enum.UIMapType.Continent)
	local continent = Ancestor(here, Enum.UIMapType.Continent)
		or Ancestor(SharedMap(here), Enum.UIMapType.Zone)

	record.seenMaps[taxiMap] = true

	if taxiContinent then
		record.seenMaps[taxiContinent] = true
	end

	if continent then
		record.seenMaps[continent] = true
	end

	for _, node in ipairs(C_TaxiMap.GetAllTaxiNodes(taxiMap)) do
		record.nodes[node.nodeID] = node.state ~= Enum.FlightPathState.Unreachable
	end
end

---@return boolean offered the open gossip offers a flight
function FlightPointNotice:GossipOffersFlight()
	if self.gossipIcon == nil then
		local fileID = GetFileIDFromPath(TAXI_GOSSIP_ICON)

		self.gossipIcon = fileID and fileID ~= 0 and fileID or false
	end

	if not self.gossipIcon then
		return false
	end

	for _, option in ipairs(C_GossipInfo.GetOptions()) do
		if option.icon == self.gossipIcon then
			return true
		end
	end

	return false
end

---Speaking to a flight master teaches its flight point, so the node the reminder is about is saved as known.
function FlightPointNotice:SaveSpokenTo()
	if not self:GossipOffersFlight() then
		return
	end

	local _, _, node = self:Nearest(false)
	local record = node and Record(true)

	if record then
		record.nodes[node.nodeID] = true
	end
end

---@param event string
function FlightPointNotice:OnEvent(event)
	if REFRESH[event] then
		self:Forget()
	end

	if event == "PLAYER_REGEN_DISABLED" then
		self.inCombat = true
	elseif event == "PLAYER_REGEN_ENABLED" then
		self.inCombat = false
	elseif event == "TAXIMAP_OPENED" then
		self:SaveFlightMap()
	elseif event == "GOSSIP_SHOW" then
		self:SaveSpokenTo()
	end

	AUI.Events:Coalesce("flightPointNotice", function()
		FlightPointNotice:Check()
	end)
end

function FlightPointNotice:Apply()
	local wanted = AUI.can.flightPointNotice == true and Options:On("flightPoint")

	if wanted ~= self.following then
		self.following = wanted

		if wanted then
			self.inCombat = UnitAffectingCombat("player") == true

			for _, event in ipairs(EVENTS) do
				AUI.Events:Register(event, self, self.OnEvent)
			end
		else
			AUI.Events:UnregisterAll(self)
			AUI.Events:Cancel("flightPointNotice")
			self:CancelEntry()
			self.entryZone, self.entryNotified = nil, false
		end
	end

	self:Forget()
	self:Check()
end
