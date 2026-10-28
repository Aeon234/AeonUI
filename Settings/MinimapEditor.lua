local AUI = select(2, ...)

local L = AUI.L

-- The diagram's measures, in the canvas's units: the margin around it, the row labels' column, a row's height and the
-- space between rows, the map's block, a piece's padding and the space between pieces, and the narrowest row.
local MARGIN = 14
local LABEL_WIDTH = 56
local ROW_HEIGHT = 22
local ROW_SPACE = 6
local MAP_HEIGHT = 40
local PIECE_PAD = 8
local PIECE_SPACE = 4
local MIN_ROW_WIDTH = 260
local BUTTON_SIZE = 14
local SIDE = 22
-- How far the pointer travels with the button down before a press becomes a drag, and how far outside the diagram a
-- drop cancels.
local DRAG_START = 4
local CANCEL_DISTANCE = 12
local DRAGGED_ALPHA = 0.3
local OFF_ALPHA = 0.5
local GOLD = { 1, 0.82, 0 }
local HOVER = { 1, 1, 1, 0.5 }
local ROW_FILL = { 0, 0, 0, 0.35 }
local MAP_FILL = { 1, 1, 1, 0.06 }
local PIECE_FILL = { 1, 1, 1, 0.1 }
local ROW_LABELS = { TOP1 = "Top 1", TOP2 = "Top 2", BOTTOM1 = "Bottom 1", BOTTOM2 = "Bottom 2" }

---A one-unit frame around a region.
---@class AUIEditorOutline: Frame
---@field top Texture
---@field bottom Texture
---@field left Texture
---@field right Texture

---A piece as the diagram drew it.
---@class AUIEditorPiece
---@field key string? the element's key, once drawn
---@field row string? its row
---@field frame Frame
---@field text FontString
---@field hit Button

---Where a drop puts an element: before the shown element at `index` in `row`, at `x` and `y` on the canvas.
---@class AUIEditorSlot
---@field row string
---@field index integer counted among the row's shown elements, the dragged one left out
---@field x number
---@field y number the row's middle, from the canvas's top

---The Rows page's Preview as the minimap's layout editor: the four rows as a diagram around the map, each holding its
---elements in order. Elements are dragged within and between rows, taken off with × and put back with +; every change
---is one Undo step. The real minimap shows the result.
---@class AUIMinimapEditor
---@field canvas Frame?
---@field layer Frame? the pointer's layer, above the pieces
---@field pieces AUIEditorPiece[] the drawn pieces, in drawing order
---@field rowFrames table<string, Texture>
---@field pluses table<string, Button>
---@field slots AUIEditorSlot[]
---@field hovered string? the element under the pointer
---@field press table? the pressed element and where the press began
---@field dragging boolean?
---@field target AUIEditorSlot? where a drop now lands
local Editor = {
	pieces = {},
	rowFrames = {},
	pluses = {},
	slots = {},
}
AUI.MinimapEditor = Editor

---@param parent Frame
---@param color number[]
---@return AUIEditorOutline outline
local function CreateOutline(parent, color)
	local outline = CreateFrame("Frame", nil, parent) --[[@as AUIEditorOutline]]

	for _, side in ipairs({ "top", "bottom", "left", "right" }) do
		local line = outline:CreateTexture(nil, "OVERLAY")

		line:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
		outline[side] = line
	end

	outline.top:SetPoint("TOPLEFT")
	outline.top:SetPoint("TOPRIGHT")
	outline.top:SetHeight(1)
	outline.bottom:SetPoint("BOTTOMLEFT")
	outline.bottom:SetPoint("BOTTOMRIGHT")
	outline.bottom:SetHeight(1)
	outline.left:SetPoint("TOPLEFT")
	outline.left:SetPoint("BOTTOMLEFT")
	outline.left:SetWidth(1)
	outline.right:SetPoint("TOPRIGHT")
	outline.right:SetPoint("BOTTOMRIGHT")
	outline.right:SetWidth(1)
	outline:Hide()

	return outline
end

---Blizzard's atlas where the client has it, else the sign in gold.
---@param parent Frame
---@param atlas string
---@param sign string
---@return Button
local function CreateIconButton(parent, atlas, sign)
	local button = CreateFrame("Button", nil, parent)

	button:SetSize(BUTTON_SIZE, BUTTON_SIZE)

	if C_Texture.GetAtlasInfo(atlas) then
		button:SetNormalAtlas(atlas)
		button:SetHighlightAtlas(atlas, "ADD")
	else
		button:SetNormalFontObject("GameFontNormalLarge")
		button:SetHighlightFontObject("GameFontHighlightLarge")
		button:SetText(sign)
	end

	button:Hide()

	return button
end

---@param key string
---@return string
local function Name(key)
	return AUI.SettingsMinimap:ElementTitle(key)
end

---@param element AUIMinimapElement
---@return boolean available the client has what the element shows
local function Available(element)
	return element.Available == nil or element:Available() == true
end

-- Building ----------------------------------------------------------------------------------------------------

---Makes the editor's lasting frames in the preview's canvas; the library calls it once.
---@param canvas Frame
function Editor:Create(canvas)
	self.canvas = canvas

	for _, row in ipairs(AUI.MinimapLayout.ROWS) do
		local fill = canvas:CreateTexture(nil, "BACKGROUND")

		fill:SetColorTexture(ROW_FILL[1], ROW_FILL[2], ROW_FILL[3], ROW_FILL[4])
		fill.label = canvas:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		fill.label:SetText(L[ROW_LABELS[row]])
		fill.label:SetJustifyH("LEFT")
		self.rowFrames[row] = fill
	end

	local map = canvas:CreateTexture(nil, "BACKGROUND")

	map:SetColorTexture(MAP_FILL[1], MAP_FILL[2], MAP_FILL[3], MAP_FILL[4])
	map.label = canvas:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	map.label:SetPoint("CENTER", map)
	map.label:SetText(L["Map"])
	self.map = map

	local layer = CreateFrame("Frame", nil, canvas)

	layer:SetAllPoints()
	layer:SetFrameLevel(canvas:GetFrameLevel() + 50)
	self.layer = layer

	self.hover = CreateOutline(layer, HOVER)
	self.dropLine = layer:CreateTexture(nil, "OVERLAY")
	self.dropLine:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
	self.dropLine:SetSize(2, ROW_HEIGHT + 6)
	self.dropLine:Hide()

	self.remove = CreateIconButton(layer, "common-icon-yellowx", "×")
	self.remove:SetFrameLevel(layer:GetFrameLevel() + 20)
	self.remove:SetScript("OnClick", function()
		if Editor.hovered then
			Editor:Remove(Editor.hovered)
		end
	end)
	self.remove:SetScript("OnLeave", function()
		Editor:Leave()
	end)

	for _, row in ipairs(AUI.MinimapLayout.ROWS) do
		local plus = CreateIconButton(layer, "common-icon-plus", "+")

		plus:SetFrameLevel(layer:GetFrameLevel() + 20)
		plus:SetScript("OnClick", function(button)
			Editor:ShowAddMenu(button, row)
		end)
		self.pluses[row] = plus
	end

	-- A copy of the dragged element's name follows the pointer.
	local ghost = CreateFrame("Frame", nil, UIParent)

	ghost:SetFrameStrata("TOOLTIP")
	ghost:Hide()
	ghost.background = ghost:CreateTexture(nil, "BACKGROUND")
	ghost.background:SetAllPoints()
	ghost.background:SetColorTexture(0, 0, 0, 0.75)
	ghost.text = ghost:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	ghost.text:SetPoint("CENTER")
	self.ghost = ghost

	-- Escape cancels a drag; while none is under way, keys pass on to the game.
	layer:SetScript("OnKeyDown", function(frame, key)
		local handled = key == "ESCAPE" and Editor.dragging

		if handled then
			Editor:CancelDrag()
		end

		if not InCombatLockdown() then
			frame:SetPropagateKeyboardInput(not handled)
		end
	end)
end

---@param index integer
---@return AUIEditorPiece
function Editor:Piece(index)
	local piece = self.pieces[index]

	if piece then
		return piece
	end

	local canvas = self.canvas --[[@as Frame]]
	local frame = CreateFrame("Frame", nil, canvas)
	local fill = frame:CreateTexture(nil, "BACKGROUND")
	local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	local hit = CreateFrame("Button", nil, self.layer)

	fill:SetAllPoints()
	fill:SetColorTexture(PIECE_FILL[1], PIECE_FILL[2], PIECE_FILL[3], PIECE_FILL[4])
	text:SetPoint("CENTER")
	hit:SetAllPoints(frame)
	hit:SetFrameLevel((self.layer --[[@as Frame]]):GetFrameLevel() + 10)
	hit:SetScript("OnEnter", function(button)
		Editor:Enter(button.key)
	end)
	hit:SetScript("OnLeave", function()
		Editor:Leave()
	end)
	hit:SetScript("OnMouseDown", function(button, mouse)
		if mouse == "LeftButton" then
			local x, y = GetCursorPosition()

			Editor.press = { key = button.key, x = x, y = y }
			Editor:SetTracking(true)
		end
	end)

	piece = { frame = frame, text = text, hit = hit }
	self.pieces[index] = piece

	return piece
end

-- Drawing -----------------------------------------------------------------------------------------------------

---Draws the rows around the map with each row's shown elements in order, and keeps the drop slots for a drag.
---@return number width the diagram's natural size, which the library shrinks to fit the stage
---@return number height
function Editor:Draw()
	local canvas = self.canvas --[[@as Frame]]
	local layout = AUI.MinimapElements:Layout()
	local dragged = self.dragging and self.press and self.press.key
	local used, widths = 0, {}

	-- Each row as wide as its pieces, all as wide as the widest, at least MIN_ROW_WIDTH.
	local rowWidth = MIN_ROW_WIDTH

	for _, row in ipairs(AUI.MinimapLayout.ROWS) do
		local width = PIECE_SPACE

		for _, key in ipairs(layout[row]) do
			local element = AUI.MinimapElements.byKey[key]

			if Available(element) then
				local piece = self:Piece(used + 1)

				used = used + 1
				piece.text:SetText(Name(key))
				widths[used] = math.ceil(piece.text:GetUnboundedStringWidth()) + 2 * PIECE_PAD
				width = width + widths[used] + PIECE_SPACE
			end
		end

		rowWidth = math.max(rowWidth, width)
	end

	wipe(self.slots)

	local y, index = MARGIN, 0
	local left = MARGIN + LABEL_WIDTH

	local function DrawRow(row)
		local fill = self.rowFrames[row]

		fill:ClearAllPoints()
		fill:SetPoint("TOPLEFT", canvas, "TOPLEFT", left, -y)
		fill:SetSize(rowWidth, ROW_HEIGHT)
		fill.label:ClearAllPoints()
		fill.label:SetPoint("LEFT", canvas, "TOPLEFT", MARGIN, -(y + ROW_HEIGHT / 2))

		local x, shown = left + PIECE_SPACE, 0
		local middle = y + ROW_HEIGHT / 2

		for _, key in ipairs(layout[row]) do
			local element = AUI.MinimapElements.byKey[key]

			if Available(element) then
				index = index + 1

				local piece = self.pieces[index]
				local width = widths[index]
				local enabled = AUI.Profile:Get(AUI.MinimapElements:EnabledPath(key)) == true

				if key ~= dragged then
					shown = shown + 1
					self.slots[#self.slots + 1] = { row = row, index = shown, x = x - PIECE_SPACE / 2, y = middle }
				end

				piece.key, piece.row, piece.hit.key = key, row, key
				piece.frame:ClearAllPoints()
				piece.frame:SetPoint("TOPLEFT", canvas, "TOPLEFT", x, -(y + 2))
				piece.frame:SetSize(width, ROW_HEIGHT - 4)
				piece.frame:SetAlpha(key == dragged and DRAGGED_ALPHA or (enabled and 1 or OFF_ALPHA))
				piece.frame:Show()
				piece.hit:Show()
				x = x + width + PIECE_SPACE
			end
		end

		self.slots[#self.slots + 1] = { row = row, index = shown + 1, x = x - PIECE_SPACE / 2, y = middle }

		local plus = self.pluses[row]

		plus:ClearAllPoints()
		plus:SetPoint("LEFT", canvas, "TOPLEFT", left + rowWidth + 4, -middle)
		plus:SetShown(not self.dragging)
		y = y + ROW_HEIGHT + ROW_SPACE
	end

	DrawRow("TOP1")
	DrawRow("TOP2")

	local map = self.map --[[@as Texture]]

	map:ClearAllPoints()
	map:SetPoint("TOPLEFT", canvas, "TOPLEFT", left, -y)
	map:SetSize(rowWidth, MAP_HEIGHT)
	y = y + MAP_HEIGHT + ROW_SPACE

	DrawRow("BOTTOM1")
	DrawRow("BOTTOM2")

	for spare = used + 1, #self.pieces do
		self.pieces[spare].frame:Hide()
		self.pieces[spare].hit:Hide()
	end

	self:PlaceMarks()

	return left + rowWidth + SIDE + MARGIN, y - ROW_SPACE + MARGIN
end

---@return string caption the line under the diagram
function Editor:Caption()
	return L["Drag to move. × removes, + adds."]
end

---Places the hover outline and the × on the hovered element.
function Editor:PlaceMarks()
	local hover, remove = self.hover, self.remove
	local piece

	for _, candidate in ipairs(self.pieces) do
		if candidate.frame:IsShown() and candidate.key == self.hovered then
			piece = candidate
		end
	end

	if not piece or self.dragging then
		hover:Hide()
		remove:Hide()

		return
	end

	hover:ClearAllPoints()
	hover:SetPoint("TOPLEFT", piece.frame, "TOPLEFT", -1, 1)
	hover:SetPoint("BOTTOMRIGHT", piece.frame, "BOTTOMRIGHT", 1, -1)
	hover:Show()
	remove:ClearAllPoints()
	remove:SetPoint("CENTER", piece.frame, "TOPRIGHT")
	remove:Show()
end

---Draws the diagram again, for a change the page does not make.
function Editor:Redraw()
	local window = AUI.Settings.window

	if window and window:IsShown() then
		window:RefreshFixedArea()
	end
end

-- Pointer -----------------------------------------------------------------------------------------------------

---@param key string
function Editor:Enter(key)
	if self.dragging then
		return
	end

	self.hovered = key
	self:PlaceMarks()
end

function Editor:Leave()
	if self.remove:IsMouseOver() then
		return
	end

	for _, piece in ipairs(self.pieces) do
		if piece.key == self.hovered and piece.hit:IsShown() and piece.hit:IsMouseOver() then
			return
		end
	end

	self.hovered = nil
	self:PlaceMarks()
end

---Follows the pointer every frame while a press or drag is under way, and not otherwise.
---@param on boolean
function Editor:SetTracking(on)
	local layer = self.layer --[[@as Frame]]

	layer:SetScript("OnUpdate", on and function()
		Editor:Track()
	end or nil)

	if not InCombatLockdown() then
		layer:EnableKeyboard(on)
	end
end

---@return number x the pointer on the canvas
---@return number y the pointer on the canvas, from its top
function Editor:Cursor()
	local canvas = self.canvas --[[@as Frame]]
	local scale = canvas:GetEffectiveScale()
	local x, y = GetCursorPosition()

	return x / scale - (canvas:GetLeft() or 0), (canvas:GetTop() or 0) - y / scale
end

---The nearest slot to a point on the canvas: the nearest row's, then the nearest place in it. Free of frame code.
---@param slots AUIEditorSlot[]
---@param x number
---@param y number
---@return AUIEditorSlot?
function Editor:NearestSlot(slots, x, y)
	local rowDistance, target, distance = math.huge, nil, math.huge

	for _, slot in ipairs(slots) do
		rowDistance = math.min(rowDistance, math.abs(slot.y - y))
	end

	for _, slot in ipairs(slots) do
		if math.abs(slot.y - y) == rowDistance and math.abs(slot.x - x) < distance then
			target, distance = slot, math.abs(slot.x - x)
		end
	end

	return target
end

function Editor:Track()
	local press = self.press

	if not press then
		return
	end

	if not IsMouseButtonDown("LeftButton") then
		if self.dragging then
			self:Drop()
		else
			self.press = nil
			self:SetTracking(false)
		end

		return
	end

	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()

	if not self.dragging then
		if math.abs(x - press.x) + math.abs(y - press.y) < DRAG_START * scale then
			return
		end

		self:StartDrag()
	end

	self.ghost:ClearAllPoints()
	self.ghost:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale + 12, y / scale - 8)

	local canvasX, canvasY = self:Cursor()
	local width, height = (self.canvas --[[@as Frame]]):GetSize()
	local outside = canvasX < -CANCEL_DISTANCE or canvasY < -CANCEL_DISTANCE or canvasX > width + CANCEL_DISTANCE
		or canvasY > height + CANCEL_DISTANCE
	local target = not outside and self:NearestSlot(self.slots, canvasX, canvasY) or nil

	self.target = target
	self.dropLine:ClearAllPoints()

	if target then
		self.dropLine:SetPoint("CENTER", self.canvas, "TOPLEFT", target.x, -target.y)
		self.dropLine:Show()
	else
		self.dropLine:Hide()
	end
end

function Editor:StartDrag()
	local press = self.press --[[@as table]]

	self.dragging = true
	self.hovered = nil
	self.ghost.text:SetText(Name(press.key))
	self.ghost:SetSize(self.ghost.text:GetStringWidth() + 12, self.ghost.text:GetStringHeight() + 8)
	self.ghost:Show()
	self:Redraw()
end

---Ends a drag without moving anything.
function Editor:CancelDrag()
	self.dragging = false
	self.press = nil
	self.target = nil
	self:SetTracking(false)
	self.ghost:Hide()
	self.dropLine:Hide()
	self:Redraw()
end

function Editor:Drop()
	local key, target = self.press and self.press.key, self.target

	self:CancelDrag()

	if key and target then
		self:Move(key, target.row, target.index)
	end
end

-- Changes -----------------------------------------------------------------------------------------------------

---The place in a row's whole list for a place among its shown elements, the moved one left out. Elements the client
---cannot show keep their places. Free of frame code.
---@param list string[] the row's whole list
---@param key string the element being moved
---@param shownIndex integer before the shown element at this place; past the last when beyond them
---@param isShown fun(key: string): boolean
---@return integer index the place in the list once `key` has left it
function Editor:ListIndex(list, key, shownIndex, isShown)
	local remaining, shown = {}, 0

	for _, other in ipairs(list) do
		if other ~= key then
			remaining[#remaining + 1] = other
		end
	end

	for index, other in ipairs(remaining) do
		if isShown(other) then
			shown = shown + 1

			if shown == shownIndex then
				return index
			end
		end
	end

	return #remaining + 1
end

---@param layout table<string, string[]>
---@return string joined the lists in one string, to tell whether a change changed anything
local function Joined(layout)
	local parts = {}

	for _, name in ipairs(AUI.MinimapElements.LISTS) do
		parts[#parts + 1] = table.concat(layout[name] or {}, ",")
	end

	return table.concat(parts, "|")
end

---Saves a new layout as one Undo step.
---@param layout table<string, string[]>
---@param text string what Undo puts back
function Editor:Commit(layout, text)
	local Elements = AUI.MinimapElements
	local before = AUI.Profile:Get(Elements.LAYOUT_PATH)

	if Joined(layout) == Joined(Elements:FullLayout(before)) then
		return
	end

	if not AUI.Profile:Set(Elements.LAYOUT_PATH, layout) then
		return
	end

	local window = AUI.Settings.window

	if window then
		window:RecordChange({ path = Elements.LAYOUT_PATH, before = before, text = text, page = "minimapRows" })
	end

	AUI.Settings:Refresh()
end

---@param key string
---@param row string
---@param shownIndex integer
function Editor:Move(key, row, shownIndex)
	local Elements = AUI.MinimapElements
	local layout = Elements:Layout()
	local index = self:ListIndex(layout[row], key, shownIndex, function(other)
		return Available(Elements.byKey[other])
	end)

	self:Commit(Elements:Move(layout, key, row, index), L["%s back to its place."]:format(Name(key)))
end

---@param key string
function Editor:Remove(key)
	local Elements = AUI.MinimapElements

	self.hovered = nil
	self:Commit(Elements:Move(Elements:Layout(), key, "HIDDEN"), L["%s back on the minimap."]:format(Name(key)))
end

---Opens the + menu: the elements off the minimap, each put at the end of `row`.
---@param owner Region
---@param row string
function Editor:ShowAddMenu(owner, row)
	local Elements = AUI.MinimapElements

	MenuUtil.CreateContextMenu(owner, function(_, root)
		local offered = 0

		for _, key in ipairs(Elements:Layout().HIDDEN) do
			if Available(Elements.byKey[key]) then
				offered = offered + 1
				root:CreateButton(Name(key), function()
					Editor:Commit(Elements:Move(Elements:Layout(), key, row),
						L["%s off the minimap again."]:format(Name(key)))
				end)
			end
		end

		if offered == 0 then
			root:CreateTitle(L["Every element is on the minimap."])
		end
	end)
end
