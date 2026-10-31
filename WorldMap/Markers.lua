local AUI = select(2, ...)

local Schema = AUI.Schema

-- Markers closer than this on the shown map, as a fraction of its width and height, share one pin.
local GROUP_DISTANCE = 0.012
-- A found spot this close to a known one of its category, in yards, is that spot.
local SAME_SPOT = 40
local MARKERS = "Interface\\AddOns\\" .. (AUI.name or "AeonUI") .. "\\Media\\Textures\\Markers\\"

-- Enum.UIMapType values, held here so the arithmetic loads without the client.
local WORLD, CONTINENT, ZONE = 1, 2, 3

-- The sizes each kind of marker is drawn at on each map type it shows on.
local INSTANCE_SCALES = { [ZONE] = 1, [CONTINENT] = 0.75 }
local TRANSPORT_SCALES = { [ZONE] = 1, [CONTINENT] = 0.75, [WORLD] = 0.6 }
local NODE_SCALES = { [ZONE] = 0.8 }
local TOWN_SCALES = { [ZONE] = 0.75 }
local EXIT_SCALES = { [ZONE] = 0.9 }
local ICONS = "Interface\\Icons\\"

---@class AUIWorldMapCategory
---@field key string
---@field atlas string? the icon's atlas
---@field textures table<string, string>? the icon's file by the marker's faction, in place of an atlas
---@field texture string? the icon's file, in place of an atlas
---@field kinds table<string, AUIWorldMapIcon>? the icon by the marker's `kind`, in place of the above
---@field group string markers of categories with the same group share a pin when they meet
---@field scales table<integer, number> each `Enum.UIMapType` the category shows on, with its markers' size there
---@field race number? the race ID the category's markers are for; its switch is offered only to that race
---@field name string? the locale key that names each marker of the category
---@field label string the locale key of one marker's kind, as its tooltip names it
---@field transport boolean? its markers take the player somewhere: clicks open their destinations' maps
---@field instance boolean? its markers are instance entrances, which open in the journal
---@field capitalsOnly boolean? its markers show only on a capital's map while Vendors and Trainers in Cities Only is on
---@field class string? the class token the category is for; its switch is offered only to that class
---@field exit boolean? its markers point along the road toward the zone they lead to
---@field racial number? the spell ID of the race's racial cast on the category's spots
---@field buff number? the spell ID of the aura the racial gives on a spot

---@class AUIWorldMapIcon
---@field atlas string?
---@field file string? in place of an atlas
---@field label string the locale key naming the kind
---@field crop boolean? the file is a square icon whose edge is cut off

---@class AUIWorldMapMarker
---@field category string a category key
---@field map number the uiMapID the position is on
---@field x number 0 to 1 across that map
---@field y number 0 to 1 down that map
---@field instance number? the instance's map ID, which names it in the client's language
---@field name string? the English name, the locale key where the client has no name
---@field wing string? which wing or entrance of the instance
---@field levels number[]? the level range, `{ min, max }`
---@field players number? a raid's size
---@field faction string? "Alliance" or "Horde"; nil for neutral markers
---@field to number[][]? a transport's destinations, each `{ uiMapID, areaID? }`
---@field race number? the race ID the marker is shown to
---@field kind string? which kind of its category's service a town marker is
---@field class string? the class token a class trainer teaches
---@field learned boolean? the spot was found in game by casting the racial on it

---@class AUIWorldMapGroup
---@field x number 0 to 1 across the shown map
---@field y number
---@field scale number the markers' size on this map type
---@field category AUIWorldMapCategory the first marker's, whose icon the pin shows
---@field markers AUIWorldMapMarker[]
---@field rotation number? an exit's arrow rotation, in radians

---@class AUIWorldMapFilter
---@field mapID number? the shown map, for the capitals-only rule
---@field shown table<string, boolean> the categories turned on
---@field faction string? the player's faction; markers of the other are left out unless `otherFaction`
---@field otherFaction boolean? show the other faction's markers too
---@field race number? the player's race ID; markers for another race are left out
---@field class string? the player's class token; markers and categories for another class are left out
---@field capitalsOnly boolean? leave the capitals-only categories off maps other than a capital's

---@class AUIWorldMapQuery: AUIWorldMapFilter
---@field mapID number the shown map
---@field mapType integer its `Enum.UIMapType`
---@field rect fun(from: number): number?, number?, number?, number? where a map lies on the shown one, as minX, maxX,
---minY and maxY, or nothing when it does not lie on it

---The world map's markers: the categories, every marker indexed by the map it is placed on, and which markers a shown
---map draws, where, and grouped by spot. Free of frame code; the client's map geometry and the player come in through
---the query.
---@class AUIWorldMapMarkers
---@field CATEGORIES AUIWorldMapCategory[] in the order their switches are listed
---@field byKey table<string, AUIWorldMapCategory>
---@field ENABLED_PATH string the markers' switch
---@field SCALE_PATH string the markers' size, in percent
---@field OTHER_FACTION_PATH string show the other faction's markers
---@field CAPITALS_PATH string vendors and trainers on capitals' maps only
---@field CAPITALS table<number, true> the capitals' uiMapIDs
---@field byMap table<number, AUIWorldMapMarker[]>? every marker by the map it is placed on, built on first use
---@field maps number[]? those maps in ascending order, so every query walks them alike
local Markers = {
	CATEGORIES = {
		{
			key = "dungeons",
			label = "Dungeon",
			atlas = "Dungeon",
			group = "instance",
			scales = INSTANCE_SCALES,
			instance = true,
		},
		{
			key = "raids",
			label = "Raid",
			atlas = "Raid",
			group = "instance",
			scales = INSTANCE_SCALES,
			instance = true,
		},
		{
			key = "worldBosses",
			label = "World Boss",
			atlas = "vignettekillboss",
			group = "boss",
			scales = INSTANCE_SCALES,
		},
		{
			key = "battlegrounds",
			label = "Battleground",
			textures = { Alliance = MARKERS .. "AllianceBattleground", Horde = MARKERS .. "HordeBattleground" },
			group = "battleground",
			scales = INSTANCE_SCALES,
		},
		{
			key = "boats",
			label = "Boat",
			atlas = "flightmasterferry",
			group = "transport",
			scales = TRANSPORT_SCALES,
			transport = true,
		},
		{
			key = "zeppelins",
			label = "Zeppelin",
			atlas = "vehicle-air-horde",
			group = "transport",
			scales = TRANSPORT_SCALES,
			transport = true,
		},
		{
			key = "skyships",
			label = "Skyship",
			atlas = "vehicle-air-alliance",
			group = "transport",
			scales = TRANSPORT_SCALES,
			transport = true,
		},
		{
			key = "trams",
			label = "Tram",
			atlas = "vehicle-alliancecart",
			group = "transport",
			scales = TRANSPORT_SCALES,
			transport = true,
		},
		{
			key = "portals",
			label = "Portal",
			atlas = "mageportalalliance",
			group = "transport",
			scales = TRANSPORT_SCALES,
			transport = true,
			race = 95,
		},
		{
			key = "leyLines",
			label = "Ley Line",
			texture = MARKERS .. "LeyLine",
			group = "leyLine",
			scales = NODE_SCALES,
			race = 95,
			racial = 1259705,
			buff = 1259691,
			name = "Ley Line",
		},
		{
			key = "convergences",
			label = "Elemental Convergence",
			texture = MARKERS .. "Convergence",
			group = "convergence",
			scales = NODE_SCALES,
			race = 96,
			racial = 1259686,
			buff = 1270893,
			name = "Elemental Convergence",
		},
		{
			key = "innkeepers",
			label = "Innkeeper",
			atlas = "Innkeeper",
			group = "innkeepers",
			scales = TOWN_SCALES,
		},
		{
			key = "mailboxes",
			label = "Mailbox",
			atlas = "Mailbox",
			group = "mailboxes",
			scales = TOWN_SCALES,
		},
		{
			key = "spiritHealers",
			label = "Spirit Healer",
			atlas = "poi-soulspiritghost",
			group = "spiritHealers",
			scales = TOWN_SCALES,
		},
		{
			key = "classTrainers",
			label = "Class Trainer",
			atlas = "Class",
			group = "classTrainers",
			scales = TOWN_SCALES,
			capitalsOnly = true,
		},
		{
			key = "professionTrainers",
			label = "Profession Trainer",
			atlas = "Profession",
			group = "professionTrainers",
			scales = TOWN_SCALES,
			capitalsOnly = true,
		},
		{
			key = "banks",
			label = "Banker",
			kinds = {
				bank = { atlas = "Banker", label = "Banker" },
				auction = { atlas = "Auctioneer", label = "Auctioneer" },
			},
			group = "banks",
			scales = TOWN_SCALES,
			capitalsOnly = true,
		},
		{
			key = "repairs",
			label = "Repairs",
			atlas = "Repair",
			group = "repairs",
			scales = TOWN_SCALES,
			capitalsOnly = true,
		},
		{
			key = "supplies",
			label = "Reagents",
			kinds = {
				reagents = { atlas = "Reagents", label = "Reagents" },
				ammo = { atlas = "Ammunition", label = "Ammunition" },
				food = { atlas = "Food", label = "Food & Drink" },
			},
			group = "supplies",
			scales = TOWN_SCALES,
			capitalsOnly = true,
		},
		{
			key = "stableMasters",
			label = "Stable Master",
			atlas = "StableMaster",
			group = "stableMasters",
			scales = TOWN_SCALES,
			class = "HUNTER",
		},
		{
			key = "vendors",
			label = "Vendor",
			kinds = {
				trade = { file = ICONS .. "INV_Fabric_Linen_01", label = "Trade Goods", crop = true },
				vendor = { file = ICONS .. "INV_Misc_Bag_07", label = "Vendor", crop = true },
			},
			group = "vendors",
			scales = TOWN_SCALES,
			capitalsOnly = true,
		},
		{
			key = "zoneExits",
			label = "Zone Exit",
			atlas = "poi-traveldirections-arrow",
			group = "exit",
			scales = EXIT_SCALES,
			transport = true,
			exit = true,
		},
	},
	byKey = {},
	ENABLED_PATH = "worldMap.markers.enabled",
	SCALE_PATH = "worldMap.markers.scale",
	OTHER_FACTION_PATH = "worldMap.markers.otherFaction",
	CAPITALS_PATH = "worldMap.markers.capitalsOnly",
	CAPITALS = { [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true, [1458] = true,
		[2482] = true, [2521] = true },
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
Schema:Boolean(Markers.OTHER_FACTION_PATH, false)
Schema:Boolean(Markers.CAPITALS_PATH, true)

for _, category in ipairs(Markers.CATEGORIES) do
	Schema:Boolean(Markers:CategoryPath(category.key), true)
end

---Indexes marker rows by map. Rows hold each category's markers by the map they are placed on: `x` and `y` in percent
---of that map, then the marker's named fields (`AUIWorldMapMarker`).
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
				local marker = { category = category.key, map = mapID, x = row[1] / 100, y = row[2] / 100 }

				for field, value in pairs(row) do
					if type(field) == "string" then
						marker[field] = value
					end
				end

				markers[#markers + 1] = marker
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

---@param marker AUIWorldMapMarker
---@param query AUIWorldMapFilter
---@return boolean shown the marker's category is on and the marker is for the player's faction and race
function Markers:IsShown(marker, query)
	if not query.shown[marker.category] then
		return false
	end

	if marker.race and marker.race ~= query.race then
		return false
	end

	local category = self.byKey[marker.category]

	if (category.class and category.class ~= query.class) or (marker.class and marker.class ~= query.class) then
		return false
	end

	if category.capitalsOnly and query.capitalsOnly and not self.CAPITALS[query.mapID or 0] then
		return false
	end

	if marker.faction and query.faction and marker.faction ~= query.faction and not query.otherFaction then
		return false
	end

	return true
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

				if scale and self:IsShown(marker, query) then
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

---Whether a spot is one already known in its category: within `SAME_SPOT` yards of one of its markers on the same
---continent.
---@param key string the category key
---@param map number the spot's uiMapID
---@param x number 0 to 1 across that map
---@param y number
---@param world fun(map: number, x: number, y: number): number?, number?, number? a map position's continent and world
---position in yards, or nothing where the map has none
---@param shippedOnly boolean? compare with the shipped markers only, not the learned ones
---@return boolean? known nil when the spot has no world position
function Markers:Known(key, map, x, y, world, shippedOnly)
	local continent, wx, wy = world(map, x, y)

	if not continent or not wx or not wy then
		return nil
	end

	for _, markers in pairs(self.byMap or {}) do
		for _, marker in ipairs(markers) do
			if marker.category == key and not (shippedOnly and marker.learned) then
				local c, mx, my = world(marker.map, marker.x, marker.y)

				if c == continent and mx and my and (mx - wx) ^ 2 + (my - wy) ^ 2 <= SAME_SPOT * SAME_SPOT then
					return true
				end
			end
		end
	end

	return false
end

---Adds a spot found in game to the index as a learned marker of its category.
---@param key string the category key
---@param map number
---@param x number 0 to 1 across that map
---@param y number
---@return AUIWorldMapMarker marker
function Markers:AddLearned(key, map, x, y)
	local byMap = self.byMap --[[@as table<number, AUIWorldMapMarker[]> ]]
	local maps = self.maps --[[@as number[] ]]
	local marker = { category = key, map = map, x = x, y = y, race = self.byKey[key].race, learned = true }
	local markers = byMap[map]

	if not markers then
		markers = {}
		byMap[map] = markers
		maps[#maps + 1] = map
		table.sort(maps)
	end

	markers[#markers + 1] = marker

	return marker
end

---@param group AUIWorldMapGroup
---@return string? atlas
---@return string? file the icon's file, when the category draws one in place of an atlas
---@return boolean? crop the file is a square icon whose edge is cut off
function Markers:Icon(group)
	return self:MarkerIcon(group.category, group.markers[1])
end

---@param category AUIWorldMapCategory
---@param marker AUIWorldMapMarker
---@return string? atlas
---@return string? file the icon's file, when the category draws one in place of an atlas
---@return boolean? crop the file is a square icon whose edge is cut off
function Markers:MarkerIcon(category, marker)
	local kind = category.kinds and category.kinds[marker.kind or ""]

	if kind then
		return kind.atlas, kind.file, kind.crop
	end

	if category.textures then
		local faction = marker.faction

		return nil, category.textures[faction or "Alliance"]
	end

	return category.atlas, category.texture
end

---Every destination of a group's markers, each once, in the markers' order.
---@param group AUIWorldMapGroup
---@return number[][] stops each `{ uiMapID, areaID? }`
function Markers:Destinations(group)
	local stops, seen = {}, {}

	for _, marker in ipairs(group.markers) do
		for _, stop in ipairs(marker.to or {}) do
			local key = stop[1] .. ":" .. tostring(stop[2])

			if not seen[key] then
				seen[key] = true
				stops[#stops + 1] = stop
			end
		end
	end

	return stops
end

---@param group AUIWorldMapGroup
---@param mapID number
---@return boolean leads whether one of the group's markers takes the player to the map
function Markers:LeadsTo(group, mapID)
	for _, marker in ipairs(group.markers) do
		for _, stop in ipairs(marker.to or {}) do
			if stop[1] == mapID then
				return true
			end
		end
	end

	return false
end

---@param marker AUIWorldMapMarker
---@return string label the locale key naming the marker's kind
function Markers:Label(marker)
	local category = self.byKey[marker.category]
	local kind = category.kinds and category.kinds[marker.kind or ""]

	return kind and kind.label or category.label
end

---The rotation of an exit's arrow, which points up unrotated: toward the middle of the zone it leads to, both zones
---placed on their continent.
---@param x number the exit on its zone, 0 to 1
---@param y number
---@param zone number[] the exit's zone on the continent: `{ minX, maxX, minY, maxY }`
---@param destination number[] the zone it leads to on the continent
---@return number radians counterclockwise
function Markers:ExitRotation(x, y, zone, destination)
	local fromX = zone[1] + x * (zone[2] - zone[1])
	local fromY = zone[3] + y * (zone[4] - zone[3])
	local dx = (destination[1] + destination[2]) / 2 - fromX
	local dy = (destination[3] + destination[4]) / 2 - fromY

	return math.atan2(-dx, -dy)
end

---The minimap's marker groups, each with its switch and the categories it shows.
Markers.MINIMAP = {
	{ key = "mailboxes", categories = { "mailboxes" } },
	{ key = "spiritHealers", categories = { "spiritHealers" } },
	{ key = "docks", categories = { "boats", "zeppelins", "skyships" } },
}

---@param key string a minimap group's key
---@return string path its switch
function Markers:MinimapPath(key)
	return "worldMap.minimap." .. key
end

for _, entry in ipairs(Markers.MINIMAP) do
	Schema:Boolean(Markers:MinimapPath(entry.key), true)
end

---Where a marker sits on the minimap against the player, in yards: right and up from the player. A rotating minimap
---turns with the player's facing, so the direction faced points up.
---@param north number how far north of the player the marker is
---@param west number how far west
---@param facing number? the player's facing in radians, counterclockwise from north, when the minimap rotates
---@return number right
---@return number up
function Markers:MinimapOffset(north, west, facing)
	local right, up = -west, north

	if facing then
		local cos, sin = math.cos(facing), math.sin(facing)

		right, up = right * cos + up * sin, up * cos - right * sin
	end

	return right, up
end

---@class AUIMinimapShape
---@field radius number? a round minimap's radius
---@field halfWidth number? a rectangular minimap's half width, in place of a radius
---@field halfHeight number?

---@param x number right of the minimap's middle
---@param y number up from it
---@param shape AUIMinimapShape the visible area, already shrunk by the pin's half size
---@return boolean inside the point lies on the visible minimap
function Markers:OnMinimap(x, y, shape)
	local radius = shape.radius

	if radius then
		return x * x + y * y <= radius * radius
	end

	return math.abs(x) <= (shape.halfWidth or 0) and math.abs(y) <= (shape.halfHeight or 0)
end
