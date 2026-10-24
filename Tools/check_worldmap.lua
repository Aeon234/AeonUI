-- Checks the World Map module's arithmetic outside the game: the marker settings and their bounds, indexing the
-- marker rows by map, which markers a zone map draws, placing a zone's markers on its continent through the map
-- rectangles, the map types each category shows on, turning a category off, leaving out the other faction's and
-- other races' markers, grouping markers that meet, each category's icon, the town markers' class and capital rules,
-- exit arrows' rotation, the shape of Forever's marker and town data, and the Map Options: their settings, which
-- areas are unexplored, splitting an area into the art's tiles, the range text and Fishing colors, and their data.
-- Run from any directory with Lua 5.1: lua Tools/check_worldmap.lua
-- Loads the real files against stubbed globals. It proves the logic, not the drawing.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

local AUI = {}
for _, file in ipairs({ "Profile/Schema.lua", "WorldMap/Markers.lua", "WorldMap/Data.lua", "WorldMap/TownData.lua",
	"WorldMap/Options.lua", "WorldMap/OptionsData.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Schema, Markers = AUI.Schema, AUI.WorldMapMarkers
local TYPES = Markers.MAP_TYPES

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

local function Near(name, actual, expected)
	checks = checks + 1
	if type(actual) ~= "number" or math.abs(actual - expected) > 1e-9 then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

-- Settings ----------------------------------------------------------------------------------------------------

Equal("markers default on", Schema:Field(Markers.ENABLED_PATH).default, true)
Equal("size defaults to 100%", Schema:Field(Markers.SCALE_PATH).default, 100)
Equal("size refuses below 50%", (Schema:CheckValue(Markers.SCALE_PATH, 40)), false)
Equal("size refuses above 200%", (Schema:CheckValue(Markers.SCALE_PATH, 210)), false)
Equal("the other faction is hidden by default", Schema:Field(Markers.OTHER_FACTION_PATH).default, false)
for _, category in ipairs(Markers.CATEGORIES) do
	Equal(category.key .. " defaults on", Schema:Field(Markers:CategoryPath(category.key)).default, true)
	Equal(category.key .. " is listed by key", Markers.byKey[category.key], category)
end

-- Indexing ----------------------------------------------------------------------------------------------------

Equal("nothing is indexed before first use", Markers:IsIndexed(), false)
Equal("an unindexed query draws nothing", #Markers:Groups({ mapID = 1, mapType = TYPES.ZONE, shown = {},
	rect = function() end }), 0)

Markers:Index({
	dungeons = {
		[10] = { { 50, 50, instance = 101 }, { 50.5, 50.5, instance = 102 }, { 10, 90, instance = 103 } },
		[20] = { { 25, 75, instance = 201 } },
	},
	unknown = { [30] = { { 1, 1, instance = 301 } } },
})

Equal("indexed", Markers:IsIndexed(), true)
Equal("maps in ascending order", table.concat(Markers.maps, " "), "10 20")
Equal("a category without a definition is ignored", Markers.byMap[30], nil)
Near("percent becomes a fraction", Markers.byMap[10][3].x, 0.1)
Equal("the instance is kept", Markers.byMap[20][1].instance, 201)

local all = { dungeons = true }

-- Zone maps ---------------------------------------------------------------------------------------------------

local zone = Markers:Groups({ mapID = 10, mapType = TYPES.ZONE, shown = all, rect = function()
	error("a zone map never projects other maps")
end })

Equal("markers that meet share a pin", #zone, 2)
Equal("the shared pin holds both", #zone[1].markers, 2)
Equal("at the first marker's spot", zone[1].x, 0.5)
Equal("with the category's icon", zone[1].category.atlas, "Dungeon")
Equal("at the zone size", zone[1].scale, 1)
Near("the far marker keeps its own pin", zone[2].y, 0.9)
Equal("another zone's markers stay off this zone", #Markers:Groups({ mapID = 20, mapType = TYPES.ZONE, shown = all,
	rect = function() end }), 1)
Equal("a category turned off draws nothing", #Markers:Groups({ mapID = 10, mapType = TYPES.ZONE,
	shown = { dungeons = false }, rect = function() end }), 0)

-- Continent and world maps ------------------------------------------------------------------------------------

-- Map 10 fills the continent's left half; map 20 its bottom-right quarter.
local RECTS = { [10] = { 0, 0.5, 0, 1 }, [20] = { 0.5, 1, 0.5, 1 } }
local continent = Markers:Groups({ mapID = 1, mapType = TYPES.CONTINENT, shown = all, rect = function(from)
	local rect = RECTS[from]

	if rect then
		return rect[1], rect[2], rect[3], rect[4]
	end
end })

Equal("both zones' markers reach the continent", #continent, 3)
Near("a marker moves into its zone's rectangle", continent[1].x, 0.25)
Near("down too", continent[1].y, 0.5)
Equal("the continent draws them smaller", continent[1].scale, 0.75)
Near("the second zone's marker", continent[3].x, 0.625)
Near("down its quarter", continent[3].y, 0.875)

local outside = Markers:Groups({ mapID = 1, mapType = TYPES.CONTINENT, shown = all, rect = function(from)
	if from == 10 then
		return 1.5, 2, 0, 1
	end
end })

Equal("markers that land off the shown map are dropped", #outside, 0)
Equal("dungeons do not show on the world map", #Markers:Groups({ mapID = 0, mapType = TYPES.WORLD, shown = all,
	rect = function()
		return 0, 1, 0, 1
	end }), 0)

-- Faction, race and grouping ---------------------------------------------------------------------------------

Markers:Index({
	boats = { [10] = { { 50, 50 }, { 20, 20, faction = "Alliance" }, { 80, 80, faction = "Horde" } } },
	dungeons = { [10] = { { 50.2, 50.2, instance = 1 } } },
	leyLines = { [10] = { { 30, 30, race = 95 } } },
	battlegrounds = { [10] = { { 70, 30, faction = "Horde", instance = 2 } } },
})

local shownAll = {}
for _, category in ipairs(Markers.CATEGORIES) do
	shownAll[category.key] = true
end

local function Count(query)
	query.mapID, query.mapType, query.shown = 10, TYPES.ZONE, shownAll
	query.rect = function() end

	local markers = 0

	for _, group in ipairs(Markers:Groups(query)) do
		markers = markers + #group.markers
	end

	return markers, #Markers:Groups(query)
end

Equal("an Alliance player sees neutral and Alliance markers, not Horde ones", Count({ faction = "Alliance" }), 3)
Equal("Show Other Faction brings the Horde ones back", Count({ faction = "Alliance", otherFaction = true }), 5)
Equal("another race does not see ley lines", Count({ faction = "Horde", race = 1 }), 4)
Equal("their race does", Count({ faction = "Horde", race = 95 }), 5)
local _, pins = Count({ faction = "Alliance", otherFaction = true })
Equal("a dock and a dungeon at one spot keep their own pins", pins, 5)

local battleground
for _, group in ipairs(Markers:Groups({ mapID = 10, mapType = TYPES.ZONE, shown = shownAll, faction = "Horde",
	rect = function() end })) do
	if group.category.key == "battlegrounds" then
		battleground = group
	end
end
local atlas, file = Markers:Icon(battleground)
Equal("a battleground draws its faction's file", atlas == nil and file:match("HordeBattleground$") ~= nil, true)
Equal("a dungeon draws its atlas", (Markers:Icon({ category = Markers.byKey.dungeons, markers = {} })), "Dungeon")

-- Destinations ----------------------------------------------------------------------------------------------

local dock = { category = Markers.byKey.boats, markers = {
	{ to = { { 1, 11 }, { 2 } } },
	{ to = { { 2 }, { 3, 33 } } },
} }
local stops = Markers:Destinations(dock)
Equal("each destination once, in order", #stops, 3)
Equal("the first stop keeps its area", stops[1][2], 11)
Equal("the shared stop comes once", stops[2][1], 2)
Equal("then the second marker's own", stops[3][1], 3)
Equal("the dock leads to a destination", Markers:LeadsTo(dock, 3), true)
Equal("and not elsewhere", Markers:LeadsTo(dock, 4), false)
Equal("a dungeon leads nowhere", Markers:LeadsTo({ markers = { {} } }, 1), false)

-- Every category's kind and name are in the English locale file.
local english = assert(io.open(root .. "Locale/enUS.lua", "rb")):read("*a")
for _, category in ipairs(Markers.CATEGORIES) do
	Equal(category.key .. " names its kind in English", english:find('L["' .. category.label .. '"]', 1, true) ~= nil,
		true)
	if category.name then
		Equal(category.key .. " names its markers in English", english:find('L["' .. category.name .. '"]', 1, true)
			~= nil, true)
	end
	for kind, icon in pairs(category.kinds or {}) do
		Equal(category.key .. " names its kind " .. kind .. " in English",
			english:find('L["' .. icon.label .. '"]', 1, true) ~= nil, true)
	end
end
for _, list in pairs(AUI.WorldMapData()) do
	for _, rows in pairs(list) do
		for _, row in ipairs(rows) do
			if row.name then
				Equal(row.name .. " is in English", english:find('L["' .. row.name .. '"]', 1, true) ~= nil, true)
			end
		end
	end
end

-- Towns and exits --------------------------------------------------------------------------------------------

Markers:Index({
	classTrainers = { [1454] = { { 10, 10, class = "WARRIOR" }, { 20, 20, class = "MAGE" } },
		[1411] = { { 30, 30, class = "WARRIOR" } } },
	innkeepers = { [1411] = { { 40, 40 } } },
	stableMasters = { [1411] = { { 50, 50 } } },
	banks = { [1454] = { { 60, 60, kind = "auction" } } },
	vendors = { [1454] = { { 70, 70, kind = "vendor" } } },
})

local function Town(mapID, query)
	query.mapID, query.mapType, query.shown = mapID, TYPES.ZONE, shownAll
	query.rect = function() end

	local keys = {}

	for _, group in ipairs(Markers:Groups(query)) do
		keys[#keys + 1] = group.category.key
	end

	table.sort(keys)

	return table.concat(keys, " ")
end

Equal("a warrior sees the warrior trainer and the city's services", Town(1454, { class = "WARRIOR",
	capitalsOnly = true }), "banks classTrainers vendors")
Equal("trainers stay off a zone outside the capitals", Town(1411, { class = "WARRIOR", capitalsOnly = true }),
	"innkeepers")
Equal("unless the cities-only switch is off", Town(1411, { class = "WARRIOR", capitalsOnly = false }),
	"classTrainers innkeepers")
Equal("a hunter sees the stable master", Town(1411, { class = "HUNTER", capitalsOnly = true }),
	"innkeepers stableMasters")
local auction = Markers:Groups({ mapID = 1454, mapType = TYPES.ZONE, shown = { banks = true }, rect = function() end })
Equal("an auctioneer draws its own atlas", (Markers:Icon(auction[1])), "Auctioneer")
Equal("and names its own kind", Markers:Label(auction[1].markers[1]), "Auctioneer")
local vendor = Markers:Groups({ mapID = 1454, mapType = TYPES.ZONE, shown = { vendors = true }, rect = function() end })
local _, vendorFile, crop = Markers:Icon(vendor[1])
Equal("a vendor draws a cropped icon file", vendorFile:match("INV_Misc_Bag_07$") ~= nil and crop, true)
Equal("a dungeon names its category's kind", Markers:Label({ category = "dungeons" }), "Dungeon")

-- An exit at the middle of the zone's left half, toward a zone straight above, points up; to the right, a quarter
-- turn clockwise.
local zone, above, right = { 0, 0.5, 0.5, 1 }, { 0, 0.5, 0, 0.5 }, { 0.5, 1, 0.5, 1 }
Near("an exit toward a zone above points up", Markers:ExitRotation(0.5, 0.5, zone, above), 0)
Near("toward a zone to the right it turns clockwise", Markers:ExitRotation(0.5, 0.5, zone, right), -math.pi / 2)

-- Minimap pins ------------------------------------------------------------------------------------------------

for _, entry in ipairs(Markers.MINIMAP) do
	Equal(entry.key .. " on the minimap defaults on", Schema:Field(Markers:MinimapPath(entry.key)).default, true)
	for _, key in ipairs(entry.categories) do
		Equal(entry.key .. " shows a known category", Markers.byKey[key] ~= nil, true)
	end
end
local right, up = Markers:MinimapOffset(10, 0)
Equal("a marker to the north is straight up", right == 0 and up == 10, true)
right, up = Markers:MinimapOffset(0, 10)
Equal("a marker to the west is to the left", right == -10 and up == 0, true)
right, up = Markers:MinimapOffset(0, 10, math.pi / 2)
Near("facing west turns it straight up", up, 10)
Near("with nothing to the side", right, 0)
right, up = Markers:MinimapOffset(10, 0, math.pi / 2)
Near("facing west puts the north to the right", right, 10)
Equal("a round minimap holds a point inside its radius", Markers:OnMinimap(30, 40, { radius = 50 }), true)
Equal("and not one past it", Markers:OnMinimap(40, 40, { radius = 50 }), false)
Equal("a rectangular minimap holds its corner", Markers:OnMinimap(90, 60, { halfWidth = 100, halfHeight = 70 }), true)
Equal("and not a point past its height", Markers:OnMinimap(10, 71, { halfWidth = 100, halfHeight = 70 }), false)

-- Map Options -------------------------------------------------------------------------------------------------

local Options = AUI.WorldMapOptions
Equal("unexplored areas default on", Schema:Field(Options.UNEXPLORED_PATH).default, true)
Equal("at half darkness", Schema:Field(Options.DARKNESS_PATH).default, 50)
Equal("darkness refuses below 10%", (Schema:CheckValue(Options.DARKNESS_PATH, 5)), false)
Equal("darkness refuses above 90%", (Schema:CheckValue(Options.DARKNESS_PATH, 95)), false)
Equal("zone levels default on", Schema:Field(Options.ZONE_LEVELS_PATH).default, true)
Equal("fishing levels default off", Schema:Field(Options.FISHING_LEVELS_PATH).default, false)

local areas = { { 100, 100, 0, 0, 11 }, { 300, 200, 10, 20, 21, 22, 23, 24 }, { 50, 50, 5, 5, 31 } }
local unexplored = Options:Unexplored(areas, { [21] = true })
Equal("an explored area is left out", #unexplored, 2)
Equal("the rest keep their order", unexplored[1][5] == 11 and unexplored[2][5] == 31, true)
Equal("nothing explored leaves every area", #Options:Unexplored(areas, {}), 3)

local tiles = Options:Tiles(areas[2], 256, 256)
Equal("a 300 by 200 area takes two tiles across, one down", #tiles, 2)
Equal("the first is a full tile", tiles[1].width == 256 and tiles[1].height == 200 and tiles[1].right == 1, true)
Equal("in its own file", tiles[1].file, 21)
Near("its height fills 200 of a 256 file", tiles[1].bottom, 200 / 256)
Equal("the last column holds the rest", tiles[2].width, 44)
Near("in a 64-wide file", tiles[2].right, 44 / 64)
Equal("beside the first", tiles[2].x == 266 and tiles[2].y == 20, true)
Equal("in the next file", tiles[2].file, 22)
tiles = Options:Tiles({ 512, 300, 0, 0, 1, 2, 3, 4 }, 256, 256)
Equal("a 512 by 300 area takes two rows of two", #tiles, 4)
Equal("the second row starts with the third file", tiles[3].file == 3 and tiles[3].y == 256, true)
Equal("and holds the rest of the height", tiles[3].height, 44)
Equal("a whole last tile keeps its full file", tiles[2].right, 1)
tiles = Options:Tiles({ 10, 10, 0, 0, 7 }, 256, 256)
Near("the smallest file is 16", tiles[1].right, 10 / 16)

Equal("a range reads as Blizzard's labels write it", Options:RangeText({ 10, 25 }), "(10-25)")
Equal("a single level stands alone", Options:RangeText({ 60, 60 }), "(60)")
Equal("no Fishing is gray", Options:FishingDifficulty(nil, { 55, 150 }), "trivial")
Equal("below the range is red", Options:FishingDifficulty(40, { 55, 150 }), "impossible")
Equal("inside it is yellow", Options:FishingDifficulty(55, { 55, 150 }), "difficult")
Equal("at its top is green", Options:FishingDifficulty(150, { 55, 150 }), "standard")

local exploration, areaCount = AUI.WorldMapExplorationData(), 0
for art, list in pairs(exploration) do
	for index, area in ipairs(list) do
		local where = ("unexplored area %d of art %d"):format(index, art)
		local files = math.ceil(area[1] / 256) * math.ceil(area[2] / 256)

		areaCount = areaCount + 1
		Equal(where .. " has a size and offset", area[1] > 0 and area[2] > 0 and area[3] >= 0 and area[4] >= 0, true)
		Equal(where .. " names a file for each 256 tile", #area, 4 + files)
	end
end
Equal("every unexplored area of the sources is here", areaCount, 572)
local levelData, ranges = AUI.WorldMapLevelData(), 0
for kind, list in pairs(levelData) do
	for mapID, range in pairs(list) do
		ranges = ranges + 1
		Equal(kind .. " range on " .. mapID .. " runs low to high", range[1] <= range[2] and range[1] > 0, true)
	end
end
Equal("41 zone and 43 fishing ranges", ranges, 84)

-- Forever's data ----------------------------------------------------------------------------------------------

local rows = AUI.WorldMapData()
for key, list in pairs(AUI.WorldMapTownData()) do
	Equal("town category " .. key .. " is new", rows[key], nil)
	rows[key] = list
end
local FIELDS = { instance = "number", name = "string", wing = "string", levels = "table", players = "number",
	faction = "string", to = "table", race = "number", kind = "string", class = "string" }
local total, town = 0, 0
local TOWN = { innkeepers = true, mailboxes = true, spiritHealers = true, classTrainers = true,
	professionTrainers = true, banks = true, repairs = true, supplies = true, stableMasters = true, vendors = true }

for key in pairs(rows) do
	Equal("data category " .. key .. " is defined", Markers.byKey[key] ~= nil, true)
end

for _, category in ipairs(Markers.CATEGORIES) do
	Equal(category.key .. " has data", rows[category.key] ~= nil, true)

	for mapID, list in pairs(rows[category.key]) do
		for index, row in ipairs(list) do
			local where = ("%s %d on %d"):format(category.key, index, mapID)

			if TOWN[category.key] then
				town = town + 1
			else
				total = total + 1
			end
			Equal(where .. " lies on its map", row[1] >= 0 and row[1] <= 100 and row[2] >= 0 and row[2] <= 100, true)

			for field, value in pairs(row) do
				if type(field) == "string" then
					Equal(where .. " field " .. field .. " is known", FIELDS[field], type(value))
				end
			end

			if row.faction then
				Equal(where .. " names a faction", row.faction == "Alliance" or row.faction == "Horde", true)
			end

			if category.key == "dungeons" or category.key == "raids" or category.key == "worldBosses"
				or category.key == "battlegrounds" then
				Equal(where .. " can be named", row.instance ~= nil or row.name ~= nil, true)
			end

			if category.transport then
				Equal(where .. " has a destination", #row.to > 0, true)
			end

			if category.kinds then
				Equal(where .. " names a kind of its category", category.kinds[row.kind or ""] ~= nil, true)
			end

			if category.key == "classTrainers" then
				Equal(where .. " names its class", type(row.class), "string")
			end

			if row.levels then
				Equal(where .. " has a level range", row.levels[1] <= row.levels[2], true)
			end
		end
	end
end

Equal("every marker and exit of the merged sources is here", total, 392)
Equal("every town marker is here", town, 1725)

io.stdout:write(("check_worldmap: %d checks passed\n"):format(checks))
