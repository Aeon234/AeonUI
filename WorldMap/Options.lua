local AUI = select(2, ...)

local Schema = AUI.Schema

-- The smallest texture file holding a partial tile; larger ones double from it.
local SMALLEST_FILE = 16
-- Fields of an area row before its tiles' file IDs.
local AREA_FIELDS = 4

---@class AUIWorldMapTile
---@field width number the tile's size on the map art, in art pixels
---@field height number
---@field right number how much of the file's width the tile shows, as a texture coordinate
---@field bottom number how much of the file's height
---@field x number the tile's top left corner on the map art
---@field y number
---@field file number the tile's fileDataID

---The Map Options: their settings, and the frame-free arithmetic behind them (which areas of a map are unexplored, how
---an area splits into the map art's tiles, and how the zone and fishing ranges read and are colored).
---@class AUIWorldMapOptions
---@field UNEXPLORED_PATH string draw the unexplored areas
---@field DARKNESS_PATH string how dark they are drawn, in percent
---@field ZONE_LEVELS_PATH string add a zone's level range to its hover label
---@field FISHING_LEVELS_PATH string add a zone's Fishing skill range to its hover label
---@field DUNGEON_MARKERS_PATH string a dungeon or raid marker's left click opens its dungeon map
---@field DUNGEON_INSTANCES_PATH string the world map opens on the dungeon map inside an instance
local Options = {
	UNEXPLORED_PATH = "worldMap.unexplored.enabled",
	DARKNESS_PATH = "worldMap.unexplored.darkness",
	ZONE_LEVELS_PATH = "worldMap.levels.zone",
	FISHING_LEVELS_PATH = "worldMap.levels.fishing",
	DUNGEON_MARKERS_PATH = "worldMap.dungeonMaps.markers",
	DUNGEON_INSTANCES_PATH = "worldMap.dungeonMaps.instances",
}
AUI.WorldMapOptions = Options

Schema:Boolean(Options.UNEXPLORED_PATH, true)
Schema:Number(Options.DARKNESS_PATH, 50, 10, 90, true)
Schema:Boolean(Options.ZONE_LEVELS_PATH, true)
Schema:Boolean(Options.FISHING_LEVELS_PATH, false)
Schema:Boolean(Options.DUNGEON_MARKERS_PATH, true)
Schema:Boolean(Options.DUNGEON_INSTANCES_PATH, true)

---@param areas number[][] a map art's area rows
---@param explored table<number, true> the first fileDataID of each area the player has explored
---@return number[][] unexplored the rows whose area is not explored, in order
function Options:Unexplored(areas, explored)
	local unexplored = {}

	for _, area in ipairs(areas) do
		if not explored[area[AREA_FIELDS + 1]] then
			unexplored[#unexplored + 1] = area
		end
	end

	return unexplored
end

---@param pixels number a last tile's size in one direction
---@return number file the size of the file holding it
local function FileSize(pixels)
	local file = SMALLEST_FILE

	while file < pixels do
		file = file * 2
	end

	return file
end

---Splits an area into the map art's tiles, as Blizzard draws explored areas: full tiles, then a last row and column
---holding the rest, each in the smallest power-of-two file that fits it.
---@param area number[] `{ width, height, offsetX, offsetY, fileDataID, ... }`
---@param tileWidth number the map art's tile size
---@param tileHeight number
---@return AUIWorldMapTile[] tiles
function Options:Tiles(area, tileWidth, tileHeight)
	local width, height, offsetX, offsetY = area[1], area[2], area[3], area[4]
	local columns, rows = math.ceil(width / tileWidth), math.ceil(height / tileHeight)
	local tiles = {}

	for row = 1, rows do
		local tall = row < rows and tileHeight or height - tileHeight * (rows - 1)
		local fileTall = row < rows and tileHeight or FileSize(tall)

		for column = 1, columns do
			local wide = column < columns and tileWidth or width - tileWidth * (columns - 1)
			local fileWide = column < columns and tileWidth or FileSize(wide)

			tiles[#tiles + 1] = {
				width = wide,
				height = tall,
				right = wide / fileWide,
				bottom = tall / fileTall,
				x = offsetX + tileWidth * (column - 1),
				y = offsetY + tileHeight * (row - 1),
				file = area[AREA_FIELDS + (row - 1) * columns + column],
			}
		end
	end

	return tiles
end

---@param range number[] `{ min, max }`
---@return string text the range as Blizzard's area labels write it, "(min-max)", or "(max)" for a single value
function Options:RangeText(range)
	if range[1] == range[2] then
		return ("(%d)"):format(range[2])
	end

	return ("(%d-%d)"):format(range[1], range[2])
end

---@param skill number? the player's Fishing skill with its modifiers, nil without Fishing
---@param range number[] the zone's `{ min, max }` Fishing skill
---@return string difficulty the key in `QuestDifficultyColors`: below the range red, inside it yellow, at its top
---green, gray without Fishing
function Options:FishingDifficulty(skill, range)
	if not skill then
		return "trivial"
	elseif skill < range[1] then
		return "impossible"
	elseif skill < range[2] then
		return "difficult"
	end

	return "standard"
end
