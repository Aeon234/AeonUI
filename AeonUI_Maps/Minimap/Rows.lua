local AUI = select(2, ...)

local Layout = AUI.MinimapLayout
local Elements = AUI.MinimapElements

AUI.Schema:Number("minimap.rows.height", 22, 16, 40, true)

-- A plain cell divider's height against its row's, and its opacity against the border color.
local DIVIDER_HEIGHT = 0.6
local DIVIDER_ALPHA = 0.6

---The minimap's four information rows: a frame for each, the elements placed in it and the dividers between them.
---@class AUIMinimapRows
---@field frames table<string, Frame> by row key
---@field dividers table<string, Texture[]> each row's divider pool
local Rows = {
	frames = {},
	dividers = {},
}
AUI.MinimapRows = Rows

---@param holder Frame
---@param onEnter fun(frame: Frame)
---@param onLeave fun(frame: Frame)
function Rows:Build(holder, onEnter, onLeave)
	for _, key in ipairs(Layout.ROWS) do
		local frame = CreateFrame("Frame", nil, holder)

		frame:EnableMouse(true)
		frame:SetScript("OnEnter", onEnter)
		frame:SetScript("OnLeave", onLeave)
		frame:Hide()
		self.frames[key] = frame
		self.dividers[key] = {}
	end
end

---@param level integer
function Rows:SetFrameLevel(level)
	for _, frame in pairs(self.frames) do
		frame:SetFrameLevel(level)
	end
end

---@class AUIMinimapRowLook
---@field style AUIBorderStyle
---@field color AUIColor the border color
---@field thickness number percent

---Places a row's dividers: the border style's own divider, the full height of the row, or a plain line of one pixel.
---@param key string
---@param row AUIMinimapRowLayout
---@param look AUIMinimapRowLook
function Rows:PlaceDividers(key, row, look)
	local frame, pool = self.frames[key], self.dividers[key]
	local color = look.color
	local styled = AUI.Border:CellDividerWidth(look.style, look.thickness)

	for index, x in ipairs(row.dividers) do
		local divider = pool[index]

		if not divider then
			divider = frame:CreateTexture(nil, "ARTWORK")
			divider:SetSnapToPixelGrid(false)
			divider:SetTexelSnappingBias(0)
			pool[index] = divider
		end

		divider:ClearAllPoints()
		divider:SetPoint("CENTER", frame, "LEFT", x, 0)

		if styled and AUI.Border:StyleCellDivider(divider, look.style, color) then
			divider:SetSize(styled, row.height)
		else
			divider:SetTexCoord(0, 1, 0, 1)
			divider:SetVertTile(false)
			divider:SetDesaturated(false)
			divider:SetColorTexture(1, 1, 1, 1)
			divider:SetVertexColor(color.r or 1, color.g or 1, color.b or 1, DIVIDER_ALPHA)
			divider:SetSize(AUI:Pixel(frame), row.height * DIVIDER_HEIGHT)
		end

		divider:Show()
	end

	for index = #row.dividers + 1, #pool do
		pool[index]:Hide()
	end
end

---Shows the rows the layout draws, puts each element in its cell and hides the elements with no cell.
---@param holder Frame
---@param layout AUIMinimapLayout
---@param look AUIMinimapRowLook the border's, for the dividers
function Rows:Place(holder, layout, look)
	local placed = {}
	local shown = {}

	for _, row in ipairs(layout.rows) do
		placed[row.key] = row
	end

	for _, key in ipairs(Layout.ROWS) do
		local frame, row = self.frames[key], placed[key]

		frame:SetShown(row ~= nil)

		if row then
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -row.y)
			frame:SetSize(layout.width, row.height)

			for _, cell in ipairs(row.cells) do
				local element = Elements.byKey[cell.key]
				local cellFrame = element.frame --[[@as Frame]]

				cellFrame:SetParent(frame)
				cellFrame:ClearAllPoints()
				cellFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", cell.x, 0)
				cellFrame:SetSize(math.max(cell.width, 1), row.height)
				cellFrame:SetShown(cell.width > 0)
				shown[cell.key] = cell.width > 0
			end

			self:PlaceDividers(key, row, look)
		end
	end

	for _, element in ipairs(Elements.list) do
		if not shown[element.key] and element.frame then
			element.frame:Hide()
		end
	end
end
