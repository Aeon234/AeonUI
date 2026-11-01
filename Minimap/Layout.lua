local AUI = select(2, ...)

-- Space between a row's edges and its outer cells, and between neighboring cells unless the border's cell dividers need
-- more; a divider sits in the middle of each space before a cell that has a neighbor on its left.
local PADDING = 6
local SPACING = 10

---@alias AUIMinimapRowKey "TOP1" | "TOP2" | "BOTTOM1" | "BOTTOM2"

---@class AUIMinimapCell
---@field key string the element's key
---@field kind "text" | "button"
---@field width number? a text cell's natural width
---@field flexible boolean? a text cell that gives up width first when the row is too narrow

---@class AUIMinimapPlacedCell
---@field key string
---@field x number from the row's left edge
---@field width number 0 when the cell does not fit

---@class AUIMinimapRowLayout
---@field key AUIMinimapRowKey
---@field y number the row's top, from the assembly's top
---@field height number
---@field cells AUIMinimapPlacedCell[]
---@field dividers number[] each divider's center, from the row's left edge

---The rows on one side of the map, as the border takes them (`AUIBorderSide`): their height without the separator
---from the map, and where the divider between two rows starts.
---@class AUIMinimapSide: AUIBorderSide

---@class AUIMinimapLayoutInput
---@field width number the map's visible width, which every row shares
---@field mapHeight number the map's visible height
---@field rowHeight number
---@field separator number the space between a side's rows and the map
---@field divider number the space between two rows on one side
---@field spacing number? the space between neighboring cells; `SPACING` when nil
---@field rows table<string, AUIMinimapCell[]> each row's visible cells in order; a missing or empty row is not drawn

---@class AUIMinimapLayout
---@field width number the assembly's width
---@field height number the assembly's height
---@field mapTop number the map's top, from the assembly's top
---@field mapBottom number the space under the map
---@field top AUIMinimapSide? nil without rows above the map
---@field bottom AUIMinimapSide? nil without rows below it
---@field rows AUIMinimapRowLayout[] the drawn rows, top to bottom

---The minimap assembly's arithmetic: where the map and each information row go, and where each cell sits in its row.
---Rows run top to bottom as Top 1, Top 2, the map, Bottom 1, Bottom 2. Free of frame code.
---@class AUIMinimapLayoutCalculator
---@field ROWS AUIMinimapRowKey[] top to bottom
local Layout = {
	ROWS = { "TOP1", "TOP2", "BOTTOM1", "BOTTOM2" },
	PADDING = PADDING,
	SPACING = SPACING,
}
AUI.MinimapLayout = Layout

---Places a row's cells left to right in their order: text cells at their natural widths, button cells as squares.
---The room left over goes to the row's filler, its first flexible cell or else its first text cell: a flexible filler
---widens, any other is centered in the room. A row without text keeps its cells at the right. When the cells do not
---fit, flexible cells shrink first, then the other text cells; buttons past the room are dropped. A flexible cell's
---room separates it from the next cell, so no divider follows it.
---@param cells AUIMinimapCell[]
---@param width number
---@param height number
---@param spacing number? the space between neighbors, room for their divider; `SPACING` when nil
---@return AUIMinimapPlacedCell[] placed in the given order
---@return number[] dividers
function Layout:Row(cells, width, height, spacing)
	spacing = spacing or SPACING

	local room = width - 2 * PADDING
	local natural, total, flexible, rigid = {}, 0, 0, 0
	local filler

	for index, cell in ipairs(cells) do
		local size = cell.kind == "button" and height or (cell.width or 0)

		natural[index] = size
		total = total + size + (index > 1 and spacing or 0)

		if cell.kind ~= "button" then
			if cell.flexible then
				flexible = flexible + size
				filler = filler or index
			else
				rigid = rigid + size
			end
		end
	end

	for index, cell in ipairs(cells) do
		if not filler and cell.kind ~= "button" then
			filler = index
		end
	end

	-- Each slot is the room a cell is given; the cell's own width may be less, centered in it.
	local slots = {}
	local excess = room - total
	local flexibleShare = flexible > 0 and math.max(0, math.min(1, 1 + excess / flexible)) or 1
	local rigidShare = rigid > 0 and math.max(0, math.min(1, 1 + (excess + flexible) / rigid)) or 1

	for index, cell in ipairs(cells) do
		local size = natural[index]

		if cell.kind ~= "button" and excess < 0 then
			size = size * (cell.flexible and flexibleShare or rigidShare)
		end

		slots[index] = size
	end

	if excess > 0 and filler then
		slots[filler] = slots[filler] + excess
	end

	local x = PADDING + ((excess > 0 and not filler) and excess or 0)
	local limit = PADDING + room
	local placed, dividers = {}, {}
	local previous, previousFlexible = false, false

	for index, cell in ipairs(cells) do
		local slot = math.min(slots[index], math.max(0, limit - x))

		if cell.kind == "button" and slot < height then
			slot = 0
		end

		local cellWidth, cellX = slot, x

		if slot > 0 and index == filler and not cell.flexible and slot > natural[index] then
			cellWidth = natural[index]
			cellX = x + (slot - cellWidth) / 2
		end

		placed[index] = { key = cell.key, x = cellX, width = cellWidth }

		if slot > 0 then
			if previous and not previousFlexible then
				dividers[#dividers + 1] = x - spacing / 2
			end

			previous, previousFlexible = true, cell.flexible == true
			x = x + slot + spacing
		end
	end

	return placed, dividers
end

---@param input AUIMinimapLayoutInput
---@return AUIMinimapLayout
function Layout:Compute(input)
	local height, divider = input.rowHeight, input.divider

	local function Present(key)
		local cells = input.rows[key]

		return cells ~= nil and #cells > 0
	end

	---@return AUIMinimapSide?
	local function Side(outer, inner)
		local count = (Present(outer) and 1 or 0) + (Present(inner) and 1 or 0)

		if count == 0 then
			return nil
		end

		return { height = count * height + (count - 1) * divider, divider = count == 2 and height or nil }
	end

	local top, bottom = Side("TOP1", "TOP2"), Side("BOTTOM2", "BOTTOM1")
	local mapTop = top and top.height + input.separator or 0
	local mapBottom = bottom and bottom.height + input.separator or 0
	local rows = {}

	local function Add(key, y)
		local cells, dividers = self:Row(input.rows[key], input.width, height, input.spacing)

		rows[#rows + 1] = { key = key, y = y, height = height, cells = cells, dividers = dividers }

		return y + height + divider
	end

	local y = 0

	for _, key in ipairs({ "TOP1", "TOP2" }) do
		if Present(key) then
			y = Add(key, y)
		end
	end

	y = mapTop + input.mapHeight + input.separator

	for _, key in ipairs({ "BOTTOM1", "BOTTOM2" }) do
		if Present(key) then
			y = Add(key, y)
		end
	end

	return {
		width = input.width,
		height = mapTop + input.mapHeight + mapBottom,
		mapTop = mapTop,
		mapBottom = mapBottom,
		top = top,
		bottom = bottom,
		rows = rows,
	}
end
