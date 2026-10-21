local AUI = select(2, ...)

local Schema = AUI.Schema

Schema:Choices("minimapRow", { "TOP1", "TOP2", "BOTTOM1", "BOTTOM2", "HIDDEN" })
-- The suite's outline choices (LibAeonSettings' `OUTLINES`), turned into `SetFont` flags by `AUI.Media:FontFlags`.
Schema:Choices("fontOutline", { "NONE", "OUTLINE", "THICKOUTLINE", "SLUG", "SLUG_OUTLINE", "SLUG_THICKOUTLINE" })
-- The text of every row, which each text element follows until it is changed on the element's page.
Schema:String("minimap.text.font", "Friz Quadrata TT", 64)
Schema:Number("minimap.text.size", 12, 8, 24, true)
Schema:Choice("minimap.text.outline", "fontOutline", "NONE")
Schema:Number("minimap.text.offsetY", 0, -10, 10, true)
Schema:Color("minimap.text.color", { r = 1, g = 1, b = 1 })

local TEXT_FIELDS = { "font", "size", "outline", "offsetY" }

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
---@field Update fun(self: AUIMinimapElement)? shows the element's current state, a sample in the preview

---The registry of minimap row elements: each declares its row and order in the profile
---(`minimap.elements.<key>.row` and `.order`) and is placed by the Minimap module.
---@class AUIMinimapElements
---@field list AUIMinimapElement[] in registration order
---@field byKey table<string, AUIMinimapElement>
---@field preview boolean elements with nothing to show now show a sample instead
local Elements = {
	list = {},
	byKey = {},
	preview = false,
}
AUI.MinimapElements = Elements

---@param key string
---@return string path the element's row setting
---@return string orderPath its order setting
---@return string enabledPath its on/off setting
function Elements:Paths(key)
	local base = "minimap.elements." .. key

	return base .. ".row", base .. ".order", base .. ".enabled"
end

---Registers an element and declares its settings: on or off (on by default) and its placement. At load only, before
---the profile loads.
---@param element AUIMinimapElement
---@param row string its default row, or HIDDEN
---@param order integer its default place in the row
function Elements:Register(element, row, order)
	local rowPath, orderPath, enabledPath = self:Paths(element.key)

	Schema:Boolean(enabledPath, true)
	Schema:Choice(rowPath, "minimapRow", row)
	Schema:Number(orderPath, order, 1, 20, true)
	self.list[#self.list + 1] = element
	self.byKey[element.key] = element
end

---Builds each element's frame. An element that takes the mouse, for a tooltip or a click, also reports the mouse to
---the Minimap module, so the minimap stays hovered while the mouse is over it.
---Declares an element's own text settings (`minimap.<key>.text.*`), each following the rows' text until set. At load
---only.
---@param key string
---@param colored boolean? the element also takes the text color; one with colors of its own does not
function Elements:DeclareText(key, colored)
	for _, field in ipairs(TEXT_FIELDS) do
		Schema:Inherit("minimap." .. key .. ".text." .. field, "minimap.text." .. field)
	end

	if colored then
		Schema:Inherit("minimap." .. key .. ".text.color", "minimap.text.color")
	end
end

---Gives a font string an element's font, size and outline, and its text color when it takes one.
---@param key string
---@param text FontString
---@param colored boolean?
---@return number offsetY how far to raise the text from the row's middle, lowered below 0
function Elements:StyleText(key, text, colored)
	local Profile, base = AUI.Profile, "minimap." .. key .. ".text."

	text:SetFont(AUI.Media:Font(Profile:Get(base .. "font")), Profile:Get(base .. "size"),
		AUI.Media:FontFlags(Profile:Get(base .. "outline")))

	if colored then
		local color = Profile:Get(base .. "color")

		text:SetTextColor(color.r or 1, color.g or 1, color.b or 1)
	end

	return Profile:Get(base .. "offsetY")
end

---@param parent Frame
function Elements:Build(parent)
	for _, element in ipairs(self.list) do
		element:Build(parent)

		local frame = element.frame --[[@as Frame]]

		if frame:IsMouseEnabled() then
			frame:HookScript("OnEnter", function()
				AUI.Minimap:OnEnter()
			end)
			frame:HookScript("OnLeave", function()
				AUI.Minimap:OnLeave()
			end)
		end
	end
end

---Activates each element that is on and placed in a row, deactivates the rest, and applies the text settings. An
---inactive element registers no events and runs no timers.
function Elements:Refresh()
	for _, element in ipairs(self.list) do
		local rowPath, _, enabledPath = self:Paths(element.key)
		local active = AUI.Profile:Get(enabledPath) == true and AUI.Profile:Get(rowPath) ~= "HIDDEN"

		element:Style()

		if active ~= (element.active == true) then
			element.active = active
			element:SetActive(active)
		end
	end
end

---Each row's cells, in order: the active elements placed in it that have something to show.
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

---Turns the preview on or off: while it is on, each placed element with nothing to show, such as the difficulty badge
---outside an instance, shows a sample, so every element can be seen in its row.
---@param preview boolean
function Elements:SetPreview(preview)
	self.preview = preview

	for _, element in ipairs(self.list) do
		if element.active and element.Update then
			element:Update()
		end
	end
end

---Called by an element whose width or visibility changed; the rows are arranged again on the next frame.
function Elements:Changed()
	AUI.Events:Coalesce("minimapArrange", function()
		AUI.Minimap:Arrange()
	end)
end
