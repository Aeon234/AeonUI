local AUI = select(2, ...)

local Schema = AUI.Schema

Schema:Choices("minimapRow", { "TOP1", "TOP2", "BOTTOM1", "BOTTOM2", "HIDDEN" })

---An item shown in a minimap row. Its frame is built once and moved between rows.
---@class AUIMinimapElement
---@field key string
---@field kind "text" | "button"
---@field flexible boolean? a text element that gives up width first when its row is too narrow
---@field frame Frame?
---@field active boolean? placed in a row
---@field Build fun(self: AUIMinimapElement, parent: Frame)
---@field SetActive fun(self: AUIMinimapElement, active: boolean) placed in a row or hidden by the player
---@field Style fun(self: AUIMinimapElement)
---@field IsShown fun(self: AUIMinimapElement): boolean has something to show now
---@field Width fun(self: AUIMinimapElement): number a text element's natural width

---The registry of minimap row elements: each declares its row and order in the profile
---(`minimap.elements.<key>.row` and `.order`) and is placed by the Minimap module.
---@class AUIMinimapElements
---@field list AUIMinimapElement[] in registration order
---@field byKey table<string, AUIMinimapElement>
local Elements = {
	list = {},
	byKey = {},
}
AUI.MinimapElements = Elements

---@param key string
---@return string path the element's row setting
---@return string orderPath its order setting
function Elements:Paths(key)
	local base = "minimap.elements." .. key

	return base .. ".row", base .. ".order"
end

---Registers an element and declares its placement settings. At load only, before the profile loads.
---@param element AUIMinimapElement
---@param row string its default row, or HIDDEN
---@param order integer its default place in the row
function Elements:Register(element, row, order)
	local rowPath, orderPath = self:Paths(element.key)

	Schema:Choice(rowPath, "minimapRow", row)
	Schema:Number(orderPath, order, 1, 20, true)
	self.list[#self.list + 1] = element
	self.byKey[element.key] = element
end

---@param parent Frame
function Elements:Build(parent)
	for _, element in ipairs(self.list) do
		element:Build(parent)
	end
end

---Activates each element placed in a row and deactivates each hidden one, and applies the text settings.
function Elements:Refresh()
	for _, element in ipairs(self.list) do
		local row = AUI.Profile:Get((self:Paths(element.key)))
		local active = row ~= "HIDDEN"

		element:Style()

		if active ~= (element.active == true) then
			element.active = active
			element:SetActive(active)
		end
	end
end

---Each row's cells, in order: the elements placed in it that have something to show.
---@return table<string, AUIMinimapCell[]>
function Elements:Rows()
	local rows, orders = {}, {}

	for _, element in ipairs(self.list) do
		local rowPath, orderPath = self:Paths(element.key)
		local row = AUI.Profile:Get(rowPath)

		if row ~= "HIDDEN" and element:IsShown() then
			local cells = rows[row] or {}

			rows[row] = cells
			cells[#cells + 1] = {
				key = element.key,
				kind = element.kind,
				width = element.kind == "text" and element:Width() or nil,
				flexible = element.flexible,
			}
			orders[element.key] = AUI.Profile:Get(orderPath)
		end
	end

	for _, cells in pairs(rows) do
		table.sort(cells, function(a, b)
			if orders[a.key] ~= orders[b.key] then
				return orders[a.key] < orders[b.key]
			end

			return a.key < b.key
		end)
	end

	return rows
end

---Called by an element whose width or visibility changed; the rows are arranged again on the next frame.
function Elements:Changed()
	AUI.Events:Coalesce("minimapArrange", function()
		AUI.Minimap:Arrange()
	end)
end
