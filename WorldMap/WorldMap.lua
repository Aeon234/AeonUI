local AUI = select(2, ...)

local Markers = AUI.WorldMapMarkers

---The World Map module: puts the markers on Blizzard's world map through a data provider, and takes the provider off
---again while the markers are switched off. Nothing of Blizzard's map is hooked or changed.
---@class AUIWorldMap
---@field active boolean the module started this session
---@field attached boolean the provider is on the world map
---@field revision integer counts the applied marker settings; the provider redraws when it changes
---@field size number the markers' size setting as a factor
---@field shown table<string, boolean> the categories turned on
---@field mapTypes table<number, integer|false> each map's `Enum.UIMapType`, false when the map is unknown
---@field rects table<string, number[]|false> where one map lies on another, false when it does not
---@field groups table<number, AUIWorldMapGroup[]> each map's pins for the current revision
---@field groupsRevision integer the revision `groups` was built for
---@field passthroughPending boolean pins made in combat wait for it to end to pass the right button through
local WorldMap = {
	active = false,
	attached = false,
	revision = 0,
	size = 1,
	shown = {},
	mapTypes = {},
	rects = {},
	groups = {},
	groupsRevision = -1,
	passthroughPending = false,
}
AUI.WorldMap = WorldMap

---@return boolean
function WorldMap:IsEnabled()
	return AUI.Profile:Get(Markers.ENABLED_PATH) == true
end

---@param mapID number
---@return integer? mapType
function WorldMap:MapType(mapID)
	local mapType = self.mapTypes[mapID]

	if mapType == nil then
		local info = C_Map.GetMapInfo(mapID)

		mapType = info and info.mapType or false
		self.mapTypes[mapID] = mapType
	end

	return mapType or nil
end

---@param from number
---@param to number
---@return number? minX
---@return number? maxX
---@return number? minY
---@return number? maxY
function WorldMap:Rect(from, to)
	local key = from .. ":" .. to
	local rect = self.rects[key]

	if rect == nil then
		local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(from, to)

		rect = (minX and maxX > minX and maxY > minY) and { minX, maxX, minY, maxY } or false
		self.rects[key] = rect
	end

	if rect then
		return rect[1], rect[2], rect[3], rect[4]
	end
end

---@param mapID number
---@return AUIWorldMapGroup[] groups the map's pins, worked out once per map and settings revision
function WorldMap:Groups(mapID)
	if self.groupsRevision ~= self.revision then
		self.groups = {}
		self.groupsRevision = self.revision
	end

	local groups = self.groups[mapID]

	if groups then
		return groups
	end

	local mapType = self:MapType(mapID)

	groups = mapType and Markers:Groups({
		mapID = mapID,
		mapType = mapType,
		shown = self.shown,
		rect = function(from)
			return WorldMap:Rect(from, mapID)
		end,
	}) or {}
	self.groups[mapID] = groups

	return groups
end

---@param marker AUIWorldMapMarker
---@return string name the place's name in the client's language
function WorldMap:MarkerName(marker)
	local name = marker.instance and GetRealZoneText(marker.instance)

	if not name or name == "" then
		return UNKNOWN
	end

	return name
end

---Gives pins made in combat their right-button passthrough once combat ends.
function WorldMap:DeferPassthrough()
	if self.passthroughPending then
		return
	end

	self.passthroughPending = true
	AUI.Events:Register("PLAYER_REGEN_ENABLED", self, self.OnCombatEnded)
end

function WorldMap:OnCombatEnded()
	AUI.Events:Unregister("PLAYER_REGEN_ENABLED", self)
	self.passthroughPending = false

	for pin in WorldMapFrame:EnumeratePinsByTemplate(AUI.WorldMapProvider.TEMPLATE) do
		pin:SetPassthrough()
	end
end

---Applies marker changes once per frame, however many arrive.
---@param path string?
function WorldMap:OnProfileChanged(path)
	if path ~= nil and path:sub(1, 9) ~= "worldMap." then
		return
	end

	AUI.Events:Coalesce("worldMapApply", function()
		WorldMap:Apply()
	end)
end

---Reads the marker settings, then puts the provider on the map and redraws, or takes it off.
function WorldMap:Apply()
	local Profile = AUI.Profile
	local provider = AUI.WorldMapProvider

	if not self:IsEnabled() then
		if self.attached then
			self.attached = false
			WorldMapFrame:RemoveDataProvider(provider)
		end

		return
	end

	if not Markers:IsIndexed() then
		Markers:Index(AUI.WorldMapData())
	end

	self.size = Profile:Get(Markers.SCALE_PATH) / 100

	for _, category in ipairs(Markers.CATEGORIES) do
		self.shown[category.key] = Profile:Get(Markers:CategoryPath(category.key)) == true
	end

	self.revision = self.revision + 1

	if not self.attached then
		self.attached = true
		WorldMapFrame:AddDataProvider(provider)
	end

	if WorldMapFrame:IsShown() then
		provider:RefreshAllData()
	end
end

---Starts the module at login on a client with marker data.
function WorldMap:Start()
	if self.active or not AUI.can.worldMapMarkers then
		return
	end

	self.active = true
	AUI.Callbacks:Register("Profile", self, self.OnProfileChanged)
	self:Apply()
end
