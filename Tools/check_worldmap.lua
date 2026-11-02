-- Checks the World Map module's arithmetic outside the game: the marker settings and their bounds, indexing the
-- marker rows by map, which markers a zone map draws, placing a zone's markers on its continent through the map
-- rectangles, the map types each category shows on, turning a category off, leaving out the other faction's and
-- other races' markers, grouping markers that meet, each category's icon, the town markers' class and capital rules,
-- exit arrows' rotation, the shape of Forever's marker and town data, and the Map Options: their settings, which
-- areas are unexplored, splitting an area into the art's tiles, the range text and Fishing colors, and their data;
-- and the dungeon maps: tile paths and layout, fitting the picture, the opening floor, pins, and their data; and that
-- every name and label the data looks up is an English locale key; and learned Skyborne spots: the same-spot rule,
-- adding them to the index, and the cast watch that saves them, with its buff checks, combat wait and pruning.
-- Run from any directory with Lua 5.1: lua Tools/check_worldmap.lua
-- Loads the real files against stubbed globals. It proves the logic, not the drawing.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

local AUI = {}
for _, file in ipairs({ "Locale/enUS.lua", "AeonUI_Maps/Locale/enUS.lua", "Profile/Schema.lua", "AeonUI_Maps/WorldMap/Markers.lua", "AeonUI_Maps/WorldMap/Data.lua",
	"AeonUI_Maps/WorldMap/TownData.lua", "AeonUI_Maps/WorldMap/Options.lua", "AeonUI_Maps/WorldMap/OptionsData.lua", "AeonUI_Maps/WorldMap/Dungeons.lua", "AeonUI_Maps/WorldMap/DungeonData.lua" }) do
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

-- Learned spots ----------------------------------------------------------------------------------------------

-- Map 10 lies on continent 1, a thousand yards across; other maps have no world position.
local function Flat(map, x, y)
	if map ~= 10 and map ~= 12 then
		return nil
	end

	return 1, x * 1000, y * 1000
end

Equal("ley lines carry their racial and buff", Markers.byKey.leyLines.racial ~= nil
	and Markers.byKey.leyLines.buff ~= nil, true)
Equal("convergences carry their racial and buff", Markers.byKey.convergences.racial ~= nil
	and Markers.byKey.convergences.buff ~= nil, true)
Equal("a spot 28 yards from a ley line is that ley line", Markers:Known("leyLines", 10, 0.32, 0.32, Flat), true)
Equal("one 50 yards away is not", Markers:Known("leyLines", 10, 0.35, 0.34, Flat), false)
Equal("another category's spot is not counted", Markers:Known("convergences", 10, 0.3, 0.3, Flat), false)
Equal("a spot without a world position is undecided", Markers:Known("leyLines", 11, 0.3, 0.3, Flat), nil)

local learned = Markers:AddLearned("leyLines", 10, 0.6, 0.9)
Equal("a learned spot is marked learned", learned.learned, true)
Equal("a learned spot carries its category's race", learned.race, 95)
Equal("its race sees the learned spot", Count({ faction = "Horde", race = 95 }), 6)
Equal("another race does not", Count({ faction = "Horde", race = 1 }), 4)
Equal("a learned spot is known afterward", Markers:Known("leyLines", 10, 0.61, 0.9, Flat), true)
Equal("but not among the shipped markers", Markers:Known("leyLines", 10, 0.61, 0.9, Flat, true), false)
local onNewMap = Markers:AddLearned("convergences", 12, 0.5, 0.5)
Equal("a learned spot on a new map indexes that map", Markers.byMap[12][1], onNewMap)
Equal("the maps stay in order", Markers.maps[#Markers.maps], 12)
Equal("a group with a learned spot holds one", Markers:HasLearned({ markers = { {}, learned } }), true)
Equal("one without does not", Markers:HasLearned({ markers = { {} } }), false)
Markers:RemoveLearned(learned)
Equal("a removed learned spot is no longer drawn", Count({ faction = "Horde", race = 95 }), 5)
Equal("nor known", Markers:Known("leyLines", 10, 0.61, 0.9, Flat), false)
Markers:RemoveLearned(learned)
Equal("removing it twice changes nothing", Count({ faction = "Horde", race = 95 }), 5)

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
	.. assert(io.open(root .. "AeonUI_Maps/Locale/enUS.lua", "rb")):read("*a")
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

-- Dungeon maps ------------------------------------------------------------------------------------------------

local Dungeons = AUI.WorldMapDungeons
Equal("dungeon maps open from markers by default", Schema:Field(Options.DUNGEON_MARKERS_PATH).default, true)
Equal("and inside instances", Schema:Field(Options.DUNGEON_INSTANCES_PATH).default, true)
local deadmines = { folder = "TheDeadmines", floors = { 1, 2 }, pins = {} }
Equal("a floor's tile is named by folder, floor and tile", Dungeons:TilePath(deadmines, 2, 7),
	"Interface\\WorldMap\\TheDeadmines\\TheDeadmines2_7")
Equal("a flat map's by folder and tile", Dungeons:TilePath({ folder = "ZulFarrak", flat = true }, 1, 12),
	"Interface\\WorldMap\\ZulFarrak\\ZulFarrak12")
Equal("a floor's name is Blizzard's string", Dungeons:FloorKey(deadmines, 2), "DUNGEON_FLOOR_THEDEADMINES2")
local first, last = Dungeons:Tile(1), Dungeons:Tile(12)
Equal("the first tile is whole", first.x == 0 and first.y == 0 and first.right == 1 and first.bottom == 1, true)
Equal("the last starts three across, two down", last.x == 768 and last.y == 512, true)
Equal("and is cut to the picture", last.width == 234 and last.height == 156, true)
Near("its width as a coordinate", last.right, 234 / 256)
Equal("the fourth is cut on the right only", Dungeons:Tile(4).width == 234 and Dungeons:Tile(4).height == 256, true)
local fitScale, fitLeft, fitTop = Dungeons:Fit(1002, 1000)
Equal("a tall frame fits the width", fitScale == 1 and fitLeft == 0 and fitTop == 166, true)
fitScale, fitLeft, fitTop = Dungeons:Fit(2004, 668)
Equal("a wide frame fits the height and centers", fitScale == 1 and fitLeft == 501 and fitTop == 0, true)
local monastery = { folder = "ScarletMonastery", floors = { 1, 2, 3, 4 }, wings = { library = 2, armory = 3 },
	pins = { [2] = {
		{ 0.5, 0.5, boss = "A" }, { 0.501, 0.5, boss = "B" }, { 0.2, 0.2, boss = "C" },
		{ 0.1, 0.1, floor = 1, up = true }, { 0.9, 0.9, floor = 3 }, { 0.3, 0.3, entrance = true },
	} } }
Equal("a wing opens on its floor", Dungeons:StartFloor(monastery, { 1, 2, 3, 4 }, "library"), 2)
Equal("a wing whose floor has no art opens on the first", Dungeons:StartFloor(monastery, { 1, 2, 4 }, "armory"), 1)
Equal("no wing opens on the first", Dungeons:StartFloor(monastery, { 2, 4 }), 1)
local floorPins = Dungeons:Pins(monastery, 2, { 1, 2 })
Equal("bosses at one spot share a pin; a way to a floor without art is left out", #floorPins, 4)
Equal("the shared pin lists both", #floorPins[1].bosses, 2)
Equal("a way keeps its direction", floorPins[3].floor == 1 and floorPins[3].up == true, true)
Equal("the entrance is kept", floorPins[4].entrance, true)
Equal("a floor without pins has none", #Dungeons:Pins(monastery, 1, { 1, 2 }), 0)

local dungeonData, dungeonPins, maps = AUI.WorldMapDungeonData(), 0, 0
local instances = {}
for _, list in pairs(AUI.WorldMapData()) do
	for _, rows in pairs(list) do
		for _, row in ipairs(rows) do
			if row.instance then
				instances[row.instance] = instances[row.instance] or {}
				if row.wing then
					instances[row.instance][row.wing] = true
				end
			end
		end
	end
end
for instanceID, map in pairs(dungeonData) do
	local where = "dungeon map " .. instanceID
	local floors = {}

	maps = maps + 1
	Equal(where .. " has a folder", type(map.folder), "string")
	Equal(where .. " is an instance a marker opens", instances[instanceID] ~= nil, true)
	for _, floor in ipairs(map.floors) do
		floors[floor] = true
	end
	for wing, floor in pairs(map.wings or {}) do
		Equal(where .. " wing " .. wing .. " opens on one of its floors", floors[floor], true)
		Equal(where .. " wing " .. wing .. " is a marker's", instances[instanceID][wing], true)
	end
	for floor, rows in pairs(map.pins) do
		Equal(where .. " pins floor " .. floor .. " of its own", floors[floor], true)
		for index, row in ipairs(rows) do
			local at = where .. " floor " .. floor .. " pin " .. index

			dungeonPins = dungeonPins + 1
			Equal(at .. " lies on the art", row[1] >= 0 and row[1] <= 1 and row[2] >= 0 and row[2] <= 1, true)
			Equal(at .. " is a boss, a way or the entrance", (row.boss and 1 or 0) + (row.floor and 1 or 0)
				+ (row.entrance and 1 or 0), 1)
			if row.floor then
				Equal(at .. " leads to another of its floors", floors[row.floor] == true and row.floor ~= floor, true)
			end
		end
	end
end
Equal("23 instances have a dungeon map", maps, 23)
Equal("every pin of the kept floors is here", dungeonPins, 301)

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

local L = AUI.L

-- A key lives in the maps' table or the base's, which that table falls back to.
local function Known(key)
	return rawget(L, key) or rawget(getmetatable(L).__index, key)
end

for _, category in ipairs(Markers.CATEGORIES) do
	Equal(category.key .. "'s label is a locale key", Known(category.label) ~= nil, true)
	Equal(category.key .. "'s name, if any, is a locale key", category.name == nil or Known(category.name) ~= nil,
		true)
	Equal(category.key .. "'s how-to line, if any, is a locale key",
		category.howTo == nil or Known(category.howTo) ~= nil, true)
	Equal(category.key .. " has a how-to line exactly when it has a racial", category.howTo ~= nil,
		category.racial ~= nil)
	for kind, info in pairs(category.kinds or {}) do
		Equal(category.key .. " kind " .. kind .. "'s label is a locale key", Known(info.label) ~= nil, true)
	end
end
for key, list in pairs(AUI.WorldMapData()) do
	for mapID, markers in pairs(list) do
		for index, row in ipairs(markers) do
			if row.name then
				Equal(("%s %d on %d's name is a locale key"):format(key, index, mapID), Known(row.name) ~= nil,
					true)
			end
		end
	end
end
Equal("every town marker is here", town, 1725)

-- Spot learning -----------------------------------------------------------------------------------------------

Markers:Index({
	leyLines = { [10] = { { 30, 30, race = 95 } } },
	convergences = { [10] = { { 70, 70, race = 96 } } },
})

local global = { worldMapSpots = { leyLines = { { 10, 0.31, 0.31 }, { 10, 0.8, 0.2 }, { "bad" } } } }
local printed, redraws, timers, now, combat, auras = {}, 0, {}, 100, false, {}
local handlers = {}

AUI.Profile = { Global = function() return global end }
AUI.Events = {
	Register = function(_, event, owner, handler) handlers[event] = { owner, handler } end,
	Unregister = function(_, event) handlers[event] = nil end,
	UnregisterAll = function() handlers = {} end,
}
AUI.WorldMap = { Redraw = function() redraws = redraws + 1 end }
function AUI:Print(message, ...) printed[#printed + 1] = message:format(...) end
function AUI:Readable(value, fallback) if value == "secret" then return fallback end return value end
function issecretvalue(value) return value == "secret" end
function InCombatLockdown() return combat end
function GetTime() return now end
function CreateVector2D(x, y) return { x = x, y = y } end
local playerAt = { map = 10, x = 0.55, y = 0.45 }
local function Position(x, y) return { GetXY = function() return x, y end } end
C_Map = {
	GetWorldPosFromMapPos = function(map, position)
		local continent, wx, wy = Flat(map, position.x, position.y)
		return continent, continent and Position(wx, wy)
	end,
	GetBestMapForUnit = function() return playerAt.map end,
	GetPlayerMapPosition = function() return Position(playerAt.x, playerAt.y) end,
	GetMapInfo = function(map) return { name = "Zone " .. map } end,
}
C_Timer = { After = function(delay, work) timers[#timers + 1] = { delay, work } end }
C_UnitAuras = { GetPlayerAuraBySpellID = function(id) return auras[id] end }
UNKNOWN = "Unknown"

assert(loadfile(root .. "AeonUI_Maps/WorldMap/Spots.lua"))("AeonUI", AUI)
local Spots = AUI.WorldMapSpots
local LEY = Markers.byKey.leyLines

local function RunTimers()
	local due = timers
	timers = {}
	for _, timer in ipairs(due) do
		timer[2]()
	end
end

local function RunAll()
	for _ = 1, 5 do
		RunTimers()
	end
end

local function Cast(spellID, unit)
	handlers.UNIT_SPELLCAST_SUCCEEDED[2](Spots, "UNIT_SPELLCAST_SUCCEEDED", unit or "player", "guid", spellID)
end

Spots:Load()
local saved = global.worldMapSpots.leyLines
Equal("loading drops a saved spot the shipped markers hold, and a malformed one", #saved, 1)
Equal("the far spot stays saved", saved[1][2], 0.8)
Equal("and is indexed as learned", Markers:Known("leyLines", 10, 0.8, 0.2, Flat, true), false)
Equal("so it is known", Markers:Known("leyLines", 10, 0.8, 0.2, Flat), true)
Spots:Load()
Equal("loading happens once a session", #Markers.byMap[10], 3)

local shownSkyborne = { leyLines = true, convergences = true }
Spots:Apply(1, shownSkyborne)
Equal("another race follows no cast", handlers.UNIT_SPELLCAST_SUCCEEDED, nil)
Spots:Apply(95, { leyLines = false, convergences = true })
Equal("a switched-off category follows no cast", handlers.UNIT_SPELLCAST_SUCCEEDED, nil)
Spots:Apply(95, shownSkyborne)
Equal("the race's racial is followed while its category is on", Spots.category, LEY)

Cast(12345)
Equal("another spell is ignored", #timers, 0)
Cast("secret")
Equal("a secret spell ID is ignored", #timers, 0)
Cast(LEY.racial, "party1")
Equal("another unit's cast is ignored", #timers, 0)

Cast(LEY.racial)
Equal("the racial schedules a first look", #timers, 1)
Equal("the first look comes after 0.2 s", timers[1][1], 0.2)
RunTimers()
Equal("no buff yet: it looks again", #timers, 1)
Equal("again after 0.5 s", timers[1][1], 0.5)
RunAll()
Equal("it gives up after four looks", #timers, 0)
Equal("nothing is saved without the buff", #saved, 1)

auras[LEY.buff] = { duration = 30, expirationTime = now + 30 }
Cast(LEY.racial)
RunAll()
Equal("a buff shorter than a minute is not the spot's", #saved, 1)

auras[LEY.buff] = { duration = 600, expirationTime = now - 10 + 600 }
Cast(LEY.racial)
RunAll()
Equal("a buff begun well before the cast is not the cast's", #saved, 1)

auras[LEY.buff] = { duration = 600, expirationTime = now + 600 }
Cast(LEY.racial)
RunAll()
Equal("the buff saves the spot", #saved, 2)
Equal("rounded to a thousandth", saved[2][2], 0.55)
Equal("it is indexed", Markers:Known("leyLines", 10, 0.55, 0.45, Flat), true)
Equal("the map redraws", redraws, 1)
Equal("the save is announced", printed[#printed], "Ley Line saved on your map: Zone 10 55.0, 45.0")

Cast(LEY.racial)
RunAll()
Equal("the same spot is not saved twice", #saved, 2)
playerAt.map = 11
Cast(LEY.racial)
RunAll()
Equal("a spot without a world position is not saved", #saved, 2)
playerAt.map, playerAt.x = 10, 0.2

combat = true
Cast(LEY.racial)
RunAll()
Equal("in combat it waits for combat to end", handlers.PLAYER_REGEN_ENABLED ~= nil, true)
Equal("without saving yet", #saved, 2)
combat = false
handlers.PLAYER_REGEN_ENABLED[2](Spots, "PLAYER_REGEN_ENABLED")
Equal("combat's end saves it", #saved, 3)
Equal("and stops waiting", handlers.PLAYER_REGEN_ENABLED, nil)

playerAt.x = 0.9
auras[LEY.buff] = { duration = "secret", expirationTime = "secret" }
Cast(LEY.racial)
RunAll()
Equal("a secret aura waits too", handlers.PLAYER_REGEN_ENABLED ~= nil, true)
Spots:Apply(nil, shownSkyborne)
Equal("turning off stops following casts", handlers.UNIT_SPELLCAST_SUCCEEDED, nil)
Equal("and the wait", handlers.PLAYER_REGEN_ENABLED, nil)
Equal("and drops the waiting cast", Spots.waiting, nil)

local firstSaved = saved[1]
local firstMarker
for marker, spot in pairs(Spots.learned) do
	if spot == firstSaved then
		firstMarker = marker
	end
end
Equal("each saved spot knows its marker", firstMarker ~= nil, true)
Equal("spots are found", Spots:AnyLearned(), true)
local before = #saved
Spots:Forget(firstMarker)
Equal("forgetting a spot takes it out of the saved spots", #saved, before - 1)
Equal("and out of the index", Markers:Known("leyLines", 10, firstSaved[2], firstSaved[3], Flat), false)
Equal("and out of the learned markers", Spots.learned[firstMarker], nil)
local redrawsBefore = redraws
Spots:ForgetAll()
Equal("forgetting all empties the saved spots", global.worldMapSpots.leyLines, nil)
Equal("and the learned markers", next(Spots.learned), nil)
Equal("and the index keeps only the shipped markers", #Markers.byMap[10], 2)
Equal("nothing is found afterward", Spots:AnyLearned(), false)
Equal("forgetting all redraws", redraws, redrawsBefore + 1)

io.stdout:write(("check_worldmap: %d checks passed\n"):format(checks))
