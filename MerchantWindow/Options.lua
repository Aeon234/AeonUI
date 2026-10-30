local AUI = select(2, ...)

local Schema = AUI.Schema

---The Merchant Window settings and the frame-free grid arithmetic behind them: how many rows and columns of items the
---merchant tab shows, the order they fill, each slot's place and the window's size.
---@class AUIMerchantWindowOptions
---@field ENABLED_PATH string the merchant tab shows AeonUI's grid
---@field ROWS_PATH string
---@field COLUMNS_PATH string
---@field ORDER_PATH string
---@field ORDERS string[] the fill orders, in the order the page lists them
local Options = {
	ENABLED_PATH = "merchantWindow.enabled",
	ROWS_PATH = "merchantWindow.rows",
	COLUMNS_PATH = "merchantWindow.columns",
	ORDER_PATH = "merchantWindow.order",
	-- ROWS: across each row, then down (Blizzard's order). COLUMNS: down each column, then across.
	ORDERS = { "ROWS", "COLUMNS" },
	MIN_ROWS = 1,
	MAX_ROWS = 10,
	MIN_COLUMNS = 2,
	MAX_COLUMNS = 8,
	-- Blizzard's merchant tab: its grid, its window and its slots (MerchantFrame.xml).
	BLIZZARD_ROWS = 5,
	BLIZZARD_COLUMNS = 2,
	WINDOW_WIDTH = 336,
	WINDOW_HEIGHT = 444,
	FIRST_X = 11,
	FIRST_Y = -69,
	SLOT_WIDTH = 153,
	SLOT_HEIGHT = 44,
	GAP_X = 12,
	GAP_Y = 8,
}
AUI.MerchantWindowOptions = Options

Schema:Choices("merchantWindowOrder", Options.ORDERS)

Schema:Boolean(Options.ENABLED_PATH, false)
Schema:Number(Options.ROWS_PATH, 5, Options.MIN_ROWS, Options.MAX_ROWS, true)
Schema:Number(Options.COLUMNS_PATH, 5, Options.MIN_COLUMNS, Options.MAX_COLUMNS, true)
Schema:Choice(Options.ORDER_PATH, "merchantWindowOrder", "ROWS")

---@param slot number a slot on the page, from 1
---@param rows number
---@param columns number
---@param order string one of `ORDERS`
---@return number row from 1
---@return number column from 1
function Options:Cell(slot, rows, columns, order)
	local offset = slot - 1

	if order == "COLUMNS" then
		return offset % rows + 1, math.floor(offset / rows) + 1
	end

	return math.floor(offset / columns) + 1, offset % columns + 1
end

---@param row number from 1
---@param column number from 1
---@return number x the slot's left edge from the window's left edge
---@return number y the slot's top edge from the window's top edge, negative downward
function Options:Offset(row, column)
	return self.FIRST_X + (column - 1) * (self.SLOT_WIDTH + self.GAP_X),
		self.FIRST_Y - (row - 1) * (self.SLOT_HEIGHT + self.GAP_Y)
end

---The window's size for a grid: Blizzard's, grown or shrunk by a slot and its gap for each row or column more or
---fewer than Blizzard's.
---@param rows number
---@param columns number
---@return number width
---@return number height
function Options:WindowSize(rows, columns)
	return self.WINDOW_WIDTH + (columns - self.BLIZZARD_COLUMNS) * (self.SLOT_WIDTH + self.GAP_X),
		self.WINDOW_HEIGHT + (rows - self.BLIZZARD_ROWS) * (self.SLOT_HEIGHT + self.GAP_Y)
end

---@param count number the merchant's items
---@param perPage number
---@return number pages at least 1
function Options:Pages(count, perPage)
	return math.max(1, math.ceil(count / perPage))
end

---@param page any the merchant window's page
---@param pages number
---@return number page within 1 to `pages`; 1 for anything but a number
function Options:ClampPage(page, pages)
	if type(page) ~= "number" or page ~= page then
		return 1
	end

	return math.min(math.max(math.floor(page), 1), pages)
end
