local AUI = select(2, ...)

local Schema = AUI.Schema

-- Markers closer than this on the shown map, as a fraction of its width and height, share one pin.
local GROUP_DISTANCE = 0.012

---@class AUIWorldMapCategory
---@field key string
---@field atlas string
---@field group string markers of categories with the same group share a pin when they meet
---@field scales table<integer, number> each `Enum.UIMapType` the category shows on, with its markers' size there

---@class AUIWorldMapMarker
---@field category string a category key
---@field map number the uiMapID the position is on
---@field x number 0 to 1 across that map
---@field y number 0 to 1 down that map
---@field instance number? the instance's map ID, which names it in the client's language

---@class AUIWorldMapGroup
---@field x number 0 to 1 across the shown map
---@field y number
---@field scale number the markers' size on this map type
---@field category AUIWorldMapCategory the first marker's, whose icon the pin shows
---@field markers AUIWorldMapMarker[]

---@class AUIWorldMapQuery
---@field mapID number the shown map
---@field mapType integer its `Enum.UIMapType`
---@field shown table<string, boolean> the categories turned on
---@field rect fun(from: number): number?, number?, number?, number? where a map lies on the shown one, as minX, maxX,
---minY and maxY, or nothing when it does not lie on it

-- Enum.UIMapType values, held here so the arithmetic loads without the client.
local WORLD, CONTINENT, ZONE = 1, 2, 3

---The world map's markers: the categories, every marker indexed by the map it is placed on, and which markers a shown
---map draws, where, and grouped by spot. Free of frame code; the client's map geometry comes in through the query.
---@class AUIWorldMapMarkers
---@field CATEGORIES AUIWorldMapCategory[] in the order their switches are listed
---@field byKey table<string, AUIWorldMapCategory>
---@field ENABLED_PATH string the markers' switch
---@field SCALE_PATH string the markers' size, in percent
---@field byMap table<number, AUIWorldMapMarker[]>? every marker by the map it is placed on, built on first use
---@field maps number[]? those maps in ascending order, so every query walks them alike
local Markers = {
	CATEGORIES = {
		{ key = "dungeons", atlas = "Dungeon", group = "instance", scales = { [ZONE] = 1, [CONTINENT] = 0.75 } },
	},
	byKey = {},
	ENABLED_PATH = "worldMap.markers.enabled",
	SCALE_PATH = "worldMap.markers.scale",
	GROUP_DISTANCE = GROUP_DISTANCE,
	MAP_TYPES = { WORLD = WORLD, CONTINENT = CONTINENT, ZONE = ZONE },
}
AUI.WorldMapMarkers = Markers

for _, category in ipairs(Markers.CATEGORIES) do
	Markers.byKey[category.key] = category
end

---@param key string a category key
---@return string path the category's switch
function Markers:CategoryPath(key)
	return "worldMap.markers." .. key
end

Schema:Boolean(Markers.ENABLED_PATH, true)
Schema:Number(Markers.SCALE_PATH, 100, 50, 200, true)

for _, category in ipairs(Markers.CATEGORIES) do
	Schema:Boolean(Markers:CategoryPath(category.key), true)
end

---Indexes marker rows by map. Rows hold each category's markers by the map they are placed on, in percent of that
---map: `{ [category] = { [uiMapID] = { { x, y, instance }, ... } } }`.
---@param rows table<string, table<number, table[]>>
function Markers:Index(rows)
	local byMap, maps = {}, {}

	for _, category in ipairs(self.CATEGORIES) do
		for mapID, list in pairs(rows[category.key] or {}) do
			local markers = byMap[mapID]

			if not markers then
				markers = {}
				byMap[mapID] = markers
				maps[#maps + 1] = mapID
			end

			for _, row in ipairs(list) do
				markers[#markers + 1] = {
					category = category.key,
					map = mapID,
					x = row[1] / 100,
					y = row[2] / 100,
					instance = row[3],
				}
			end
		end
	end

	table.sort(maps)

	self.byMap = byMap
	self.maps = maps
end

---@return boolean indexed the markers have been indexed
function Markers:IsIndexed()
	return self.byMap ~= nil
end

---Adds a marker to the group it meets on the shown map, or starts a group.
---@param groups AUIWorldMapGroup[]
---@param marker AUIWorldMapMarker
---@param category AUIWorldMapCategory
---@param x number
---@param y number
---@param scale number
local function Place(groups, marker, category, x, y, scale)
	for _, group in ipairs(groups) do
		if group.category.group == category.group and math.abs(group.x - x) <= GROUP_DISTANCE
			and math.abs(group.y - y) <= GROUP_DISTANCE then
			group.markers[#group.markers + 1] = marker

			return
		end
	end

	groups[#groups + 1] = { x = x, y = y, scale = scale, category = category, markers = { marker } }
end

---The pins a shown map draws: its own markers on a zone map, and on a continent or the world map those of every map
---lying on it, each category only on the map types it shows on.
---@param query AUIWorldMapQuery
---@return AUIWorldMapGroup[]
function Markers:Groups(query)
	local groups = {}
	local byMap = self.byMap

	if not byMap then
		return groups
	end

	local wide = query.mapType == WORLD or query.mapType == CONTINENT

	for _, mapID in ipairs(self.maps --[[@as number[] ]]) do
		-- Where the marker's map lies on the shown one; the shown map itself spans it.
		local minX, maxX, minY, maxY = 0, 1, 0, 1
		local onMap = mapID == query.mapID

		if not onMap and wide then
			local left, right, top, bottom = query.rect(mapID)

			if left and right and top and bottom and right > left and bottom > top then
				minX, maxX, minY, maxY = left, right, top, bottom
				onMap = true
			end
		end

		if onMap then
			for _, marker in ipairs(byMap[mapID]) do
				local category = self.byKey[marker.category]
				local scale = category.scales[query.mapType]

				if scale and query.shown[marker.category] then
					local x = minX + marker.x * (maxX - minX)
					local y = minY + marker.y * (maxY - minY)

					if x >= 0 and x <= 1 and y >= 0 and y <= 1 then
						Place(groups, marker, category, x, y, scale)
					end
				end
			end
		end
	end

	return groups
end
