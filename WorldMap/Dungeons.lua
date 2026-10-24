local AUI = select(2, ...)

-- The client's dungeon map art: twelve 256-pixel tiles, four across and three down, of which the picture fills the
-- top left 1002 by 668.
local COLUMNS, ROWS = 4, 3
local TILE = 256
local WIDTH, HEIGHT = 1002, 668
-- How near two bosses must be, as fractions of the art, to share one pin.
local SAME_SPOT = 0.002

---@class AUIDungeonMap
---@field folder string the art's folder under `Interface\WorldMap`
---@field floors number[] the art's floor numbers in order
---@field flat boolean? the tiles are named without the floor
---@field wings table<string, number>? the floor each wing's marker opens on
---@field pins table<number, table[]> each floor's pin rows

---@class AUIDungeonPin
---@field x number where the pin lies, as fractions of the art
---@field y number
---@field bosses table[]? the boss rows sharing the spot
---@field floor number? the floor a way leads to
---@field up boolean? the way leads up
---@field entrance boolean? the instance's entrance

---@class AUIDungeonTile
---@field x number the tile's top left corner on the art, in art pixels
---@field y number
---@field width number the part of the tile the picture covers
---@field height number
---@field right number that part as texture coordinates of the tile
---@field bottom number

---The dungeon maps' frame-free arithmetic: where the client keeps each floor's art, how its tiles fill a frame, which
---floor a marker opens on, and the pins of a floor.
---@class AUIWorldMapDungeons
---@field WIDTH number the picture's size in art pixels
---@field HEIGHT number
---@field TILES integer the tiles of one floor
local Dungeons = {
	WIDTH = WIDTH,
	HEIGHT = HEIGHT,
	TILES = COLUMNS * ROWS,
}
AUI.WorldMapDungeons = Dungeons

---@param map AUIDungeonMap
---@param floor number one of the map's floor numbers
---@param tile integer 1 to `TILES`, row by row
---@return string path the tile's file in the client
function Dungeons:TilePath(map, floor, tile)
	local base = "Interface\\WorldMap\\" .. map.folder .. "\\" .. map.folder

	if map.flat then
		return base .. tile
	end

	return base .. floor .. "_" .. tile
end

---@param map AUIDungeonMap
---@param floor number
---@return string key the global string naming the floor in the client's language
function Dungeons:FloorKey(map, floor)
	return "DUNGEON_FLOOR_" .. map.folder:upper() .. floor
end

---@param index integer 1 to `TILES`, row by row
---@return AUIDungeonTile tile where the tile lies on the art, cut to the picture
function Dungeons:Tile(index)
	local column, row = (index - 1) % COLUMNS, math.floor((index - 1) / COLUMNS)
	local width = column == COLUMNS - 1 and WIDTH - TILE * (COLUMNS - 1) or TILE
	local height = row == ROWS - 1 and HEIGHT - TILE * (ROWS - 1) or TILE

	return {
		x = TILE * column,
		y = TILE * row,
		width = width,
		height = height,
		right = width / TILE,
		bottom = height / TILE,
	}
end

---@param width number the frame the picture fills
---@param height number
---@return number scale frame units per art pixel, keeping the picture's shape
---@return number left the picture's offset in the frame
---@return number top
function Dungeons:Fit(width, height)
	local scale = math.min(width / WIDTH, height / HEIGHT)

	return scale, (width - WIDTH * scale) / 2, (height - HEIGHT * scale) / 2
end

---@param floors number[] the floors available, in order
---@param floor number?
---@return integer? index the floor's place in the list
function Dungeons:FloorIndex(floors, floor)
	for index, number in ipairs(floors) do
		if number == floor then
			return index
		end
	end
end

---@param map AUIDungeonMap
---@param floors number[] the floors whose art the client has, in order
---@param wing string? the wing of the marker it opens from
---@return integer index the floor it opens on: the wing's where it has one, otherwise the first
function Dungeons:StartFloor(map, floors, wing)
	local floor = wing and map.wings and map.wings[wing]

	return self:FloorIndex(floors, floor) or 1
end

---The pins of one floor: bosses at one spot share a pin, and ways to floors without art are left out.
---@param map AUIDungeonMap
---@param floor number
---@param floors number[] the floors whose art the client has
---@return AUIDungeonPin[] pins
function Dungeons:Pins(map, floor, floors)
	local pins = {}

	for _, row in ipairs(map.pins[floor] or {}) do
		local x, y = row[1], row[2]

		if row.boss then
			local shared

			for _, pin in ipairs(pins) do
				if pin.bosses and math.abs(pin.x - x) <= SAME_SPOT and math.abs(pin.y - y) <= SAME_SPOT then
					shared = pin

					break
				end
			end

			if shared then
				shared.bosses[#shared.bosses + 1] = row
			else
				pins[#pins + 1] = { x = x, y = y, bosses = { row } }
			end
		elseif row.floor then
			if self:FloorIndex(floors, row.floor) then
				pins[#pins + 1] = { x = x, y = y, floor = row.floor, up = row.up }
			end
		elseif row.entrance then
			pins[#pins + 1] = { x = x, y = y, entrance = true }
		end
	end

	return pins
end
