-- Checks the World Map module's arithmetic outside the game: the marker settings and their bounds, indexing the
-- marker rows by map, which markers a zone map draws, placing a zone's markers on its continent through the map
-- rectangles, the map types each category shows on, turning a category off, and grouping markers that meet.
-- Run from any directory with Lua 5.1: lua Tools/check_worldmap.lua
-- Loads the real files against stubbed globals. It proves the logic, not the drawing.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

local AUI = {}
for _, file in ipairs({ "Profile/Schema.lua", "WorldMap/Markers.lua", "WorldMap/Data.lua" }) do
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
		[10] = { { 50, 50, 101 }, { 50.5, 50.5, 102 }, { 10, 90, 103 } },
		[20] = { { 25, 75, 201 } },
	},
	unknown = { [30] = { { 1, 1, 301 } } },
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

-- Forever's data ----------------------------------------------------------------------------------------------

local rows = AUI.WorldMapData()

for key in pairs(rows) do
	Equal("data category " .. key .. " is defined", Markers.byKey[key] ~= nil, true)
end

for mapID, list in pairs(rows.dungeons) do
	for index, row in ipairs(list) do
		local where = ("dungeon %d on %d"):format(index, mapID)

		Equal(where .. " lies on its map", row[1] >= 0 and row[1] <= 100 and row[2] >= 0 and row[2] <= 100, true)
		Equal(where .. " names its instance", type(row[3]), "number")
	end
end

io.stdout:write(("check_worldmap: %d checks passed\n"):format(checks))
