local AUI = select(2, ...)

local Schema = AUI.Schema

-- The layout's lists: the four rows, top to bottom, and the elements taken off the minimap.
local LISTS = { "TOP1", "TOP2", "BOTTOM1", "BOTTOM2", "HIDDEN" }
local LAYOUT_PATH = "minimap.layout"

Schema:Lists(LAYOUT_PATH, LISTS, 32)
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
---@field defaultRow string? the list it starts in, set on registration
---@field defaultOrder integer? its place there, against the other elements' defaults
---@field flexible boolean? a text element that gives up width first when its row is too narrow
---@field frame Frame?
---@field active boolean? placed in a row
---@field Build fun(self: AUIMinimapElement, parent: Frame)
---@field SetActive fun(self: AUIMinimapElement, active: boolean) placed in a row or hidden by the player
---@field Style fun(self: AUIMinimapElement)
---@field IsShown fun(self: AUIMinimapElement): boolean has something to show now
---@field Width fun(self: AUIMinimapElement): number a text element's natural width
---@field Update fun(self: AUIMinimapElement)? shows the element's current state, a sample in the preview
---@field Available fun(self: AUIMinimapElement): boolean? whether the client has what it shows; always when absent

---The registry of minimap row elements and their layout: which row each sits in, in what order, or whether it is off
---the minimap, kept as one setting (`minimap.layout`) so that one change to it is one Undo step. Each element also has
---its own on/off switch (`minimap.elements.<key>.enabled`).
---@class AUIMinimapElements
---@field LISTS string[] the rows top to bottom, then HIDDEN
---@field LAYOUT_PATH string
---@field list AUIMinimapElement[] in registration order
---@field byKey table<string, AUIMinimapElement>
---@field preview boolean elements with nothing to show now show a sample instead
---@field previewers table<string, true> what has the preview on: the settings window, the development command
local Elements = {
	LISTS = LISTS,
	LAYOUT_PATH = LAYOUT_PATH,
	list = {},
	byKey = {},
	preview = false,
	previewers = {},
}
AUI.MinimapElements = Elements

---@param key string
---@return string path the element's on/off setting
function Elements:EnabledPath(key)
	return "minimap.elements." .. key .. ".enabled"
end

---Registers an element with its default place and declares its on/off setting, on by default. At load only, before
---the profile loads.
---@param element AUIMinimapElement
---@param row string its default row, or HIDDEN
---@param order integer its default place in the row
function Elements:Register(element, row, order)
	Schema:Boolean(self:EnabledPath(element.key), true)
	element.defaultRow, element.defaultOrder = row, order
	self.list[#self.list + 1] = element
	self.byKey[element.key] = element
end

---The layout every element starts in: each default row's elements by their default order. Free of frame code.
---@return table<string, string[]>
function Elements:DefaultLayout()
	local layout = {}

	for _, name in ipairs(LISTS) do
		layout[name] = {}
	end

	local sorted = {}

	for index, element in ipairs(self.list) do
		sorted[index] = element
	end

	table.sort(sorted, function(a, b)
		if a.defaultOrder ~= b.defaultOrder then
			return a.defaultOrder < b.defaultOrder
		end

		return a.key < b.key
	end)

	for _, element in ipairs(sorted) do
		local list = layout[element.defaultRow or "HIDDEN"] or layout.HIDDEN

		list[#list + 1] = element.key
	end

	return layout
end

---@param list string[]
---@param value string
---@return integer? index
local function IndexOf(list, value)
	for index, other in ipairs(list) do
		if other == value then
			return index
		end
	end
end

---The whole layout from a saved one: its lists without keys no element has, then each element the saved layout lacks
---(one added since) in its default row, after the nearest element before it there by default, or first. Free of frame
---code.
---@param saved table<string, string[]>? nil for the default layout
---@return table<string, string[]> layout a new table, every element in exactly one list
function Elements:FullLayout(saved)
	local default = self:DefaultLayout()

	if type(saved) ~= "table" then
		return default
	end

	local layout, placed = {}, {}

	for _, name in ipairs(LISTS) do
		local list = {}

		for _, key in ipairs(saved[name] or {}) do
			if self.byKey[key] and not placed[key] then
				placed[key] = true
				list[#list + 1] = key
			end
		end

		layout[name] = list
	end

	for _, name in ipairs(LISTS) do
		for index, key in ipairs(default[name]) do
			if not placed[key] then
				local list, at = layout[name], 1

				for before = index - 1, 1, -1 do
					local found = IndexOf(list, default[name][before])

					if found then
						at = found + 1

						break
					end
				end

				table.insert(list, at, key)
				placed[key] = true
			end
		end
	end

	return layout
end

---Moves an element to a place in a list, as a new layout. Free of frame code.
---@param layout table<string, string[]> a whole layout
---@param key string
---@param name string the list it goes to, HIDDEN to take it off the minimap
---@param index integer? its place there, counted after it leaves its own list; the end when nil
---@return table<string, string[]> moved
function Elements:Move(layout, key, name, index)
	local moved = {}

	for _, listName in ipairs(LISTS) do
		local list = {}

		for _, other in ipairs(layout[listName] or {}) do
			if other ~= key then
				list[#list + 1] = other
			end
		end

		moved[listName] = list
	end

	local list = moved[name]

	table.insert(list, math.max(1, math.min(index or #list + 1, #list + 1)), key)

	return moved
end

---The active profile's layout.
---@return table<string, string[]>
function Elements:Layout()
	return self:FullLayout(AUI.Profile:Get(LAYOUT_PATH))
end

---@param layout table<string, string[]>
---@return table<string, string> rows each element's list
local function RowsByKey(layout)
	local rows = {}

	for _, name in ipairs(LISTS) do
		for _, key in ipairs(layout[name]) do
			rows[key] = name
		end
	end

	return rows
end

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

---Builds each element's frame. An element that takes the mouse, for a tooltip or a click, also reports the mouse to
---the Minimap module, so the minimap stays hovered while the mouse is over it.
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
	local rows = RowsByKey(self:Layout())

	for _, element in ipairs(self.list) do
		local active = AUI.Profile:Get(self:EnabledPath(element.key)) == true and rows[element.key] ~= "HIDDEN"

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
	local layout, rows = self:Layout(), {}

	for _, name in ipairs(LISTS) do
		if name ~= "HIDDEN" then
			for _, key in ipairs(layout[name]) do
				local element = self.byKey[key]

				if element:IsShown() then
					local cells = rows[name] or {}

					rows[name] = cells
					cells[#cells + 1] = {
						key = key,
						kind = element.kind,
						width = element.kind == "text" and element:Width() or nil,
						flexible = element.flexible,
					}
				end
			end
		end
	end

	return rows
end

---Turns the preview on or off for one source: while any source has it on, each placed element with nothing to show,
---such as the difficulty badge outside an instance, shows a sample, so every element can be seen in its row.
---@param on boolean
---@param source string who asks, so one source turning it off leaves another's on
function Elements:SetPreview(on, source)
	self.previewers[source] = on or nil

	local preview = next(self.previewers) ~= nil

	if preview == self.preview then
		return
	end

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
