local AUI = select(2, ...)

local L = AUI.L
local lib = LibStub("LibAeonSettings-1.0")

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
-- Seconds a piece's spring takes to reach its place: the others making room, and a dropped piece settling.
local MAKE_ROOM = 0.18
local SETTLE = 0.3
local OFF_ALPHA = 0.5
local HOVER = { 1, 1, 1, 0.5 }
local ROW_FILL = { 0, 0, 0, 0.35 }
local MAP_FILL = { 1, 1, 1, 0.06 }
-- A piece's fill at rest, and while pressed or carried.
local PIECE_FILL = { 1, 1, 1, 0.1 }
local PIECE_HELD = 0.22
local ROW_LABELS = { TOP1 = "Top 1", TOP2 = "Top 2", BOTTOM1 = "Bottom 1", BOTTOM2 = "Bottom 2" }

---A one-unit frame around a region.
---@class AUIEditorOutline: Frame
---@field top Texture
---@field bottom Texture
---@field left Texture
---@field right Texture

---An element's piece. It sits where its two springs are, in canvas units from the canvas's top left.
---@class AUIEditorPiece
---@field key string the element's key
---@field frame Frame
---@field fill Texture
---@field text FontString
---@field hit Button
---@field x table the left edge's spring
---@field y table the top edge's spring, downward
---@field placed boolean? it has a place, so moving there animates

---Where the diagram's rows are, from the last draw.
---@class AUIEditorGeometry
---@field left number the rows' left edge
---@field top table<string, number> each row's top, from the canvas's top

---Where a drop puts an element: before the shown element at `index` in `row`, at `x` and `y` on the canvas.
---@class AUIEditorSlot
---@field row string
---@field index integer counted among the row's shown elements, the dragged one left out
---@field x number
---@field y number the row's middle, from the canvas's top

---The Minimap page's Preview as the minimap's layout editor: the four rows as a diagram around the map, each holding
---its elements in order. A piece is carried by the pointer where it was grabbed while the others make room for it on
---springs; a drop settles it into its place, and a cancelled drag returns it. Elements are taken off with × and put
---back with +; every change is one Undo step. The real minimap shows the result.
---@class AUIMinimapEditor
---@field canvas Frame?
---@field layer Frame? the pointer's layer, above the pieces
---@field pieces table<string, AUIEditorPiece> each element's piece, made on first draw
---@field rows table<string, string[]> each row's shown elements, from the last draw
---@field widths table<string, number> each shown element's piece width
---@field geometry AUIEditorGeometry?
---@field rowFrames table<string, Texture>
---@field pluses table<string, Button>
---@field slots AUIEditorSlot[]
---@field hovered string? the element under the pointer
---@field press table? the pressed element, where the press began, and where on the piece it was grabbed
---@field dragging boolean?
---@field target AUIEditorSlot? where a drop now lands
---@field released string? the element last dropped or returned, which settles on the slower spring
local Editor = {
	pieces = {},
	rows = {},
	widths = {},
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

---@param key string
---@return AUIEditorPiece
function Editor:Piece(key)
	local piece = self.pieces[key]

	if piece then
		return piece
	end

	local canvas = self.canvas --[[@as Frame]]
	local frame = CreateFrame("Frame", nil, canvas)
	local fill = frame:CreateTexture(nil, "BACKGROUND")
	local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	local hit = CreateFrame("Button", nil, self.layer)

	fill:SetAllPoints()
	fill:SetColorTexture(1, 1, 1, 1)
	fill:SetAlpha(PIECE_FILL[4])
	fill:SetVertexColor(PIECE_FILL[1], PIECE_FILL[2], PIECE_FILL[3])
	text:SetPoint("CENTER")
	text:SetText(Name(key))
	hit:SetAllPoints(frame)
	hit:SetFrameLevel((self.layer --[[@as Frame]]):GetFrameLevel() + 10)
	hit.key = key
	hit:SetScript("OnEnter", function(button)
		Editor:Enter(button.key)
	end)
	hit:SetScript("OnLeave", function()
		Editor:Leave()
	end)
	hit:SetScript("OnMouseDown", function(button, mouse)
		if mouse == "LeftButton" then
			Editor:Press(button.key)
		end
	end)

	piece = { key = key, frame = frame, fill = fill, text = text, hit = hit }

	local function Place()
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", canvas, "TOPLEFT", piece.x.value, -piece.y.value)
	end

	piece.x = lib:CreateSpring(0, Place, { damping = 1 })
	piece.y = lib:CreateSpring(0, Place, { damping = 1 })
	self.pieces[key] = piece

	return piece
end

-- Drawing -----------------------------------------------------------------------------------------------------

---Each shown element's place in the rows, in canvas units: rows in order, pieces left to right with PIECE_SPACE
---around them. While a drag has a target, the carried element leaves its row and the target row opens a gap for it at
---the target's place; without a target everything keeps its own place. Free of frame code.
---@param rows table<string, string[]> each row's shown elements
---@param widths table<string, number>
---@param geometry AUIEditorGeometry
---@param drag { key: string, target: AUIEditorSlot? }?
---@return table<string, { x: number, y: number }> places each element's top left
function Editor:Positions(rows, widths, geometry, drag)
	local places = {}

	for _, row in ipairs(AUI.MinimapLayout.ROWS) do
		local list = {}

		for _, key in ipairs(rows[row] or {}) do
			if not (drag and drag.target and key == drag.key) then
				list[#list + 1] = key
			end
		end

		if drag and drag.target and drag.target.row == row then
			table.insert(list, math.min(drag.target.index, #list + 1), drag.key)
		end

		local x = geometry.left + PIECE_SPACE

		for _, key in ipairs(list) do
			places[key] = { x = x, y = geometry.top[row] + 2 }
			x = x + widths[key] + PIECE_SPACE
		end
	end

	return places
end

---The places a carried element can be dropped: before each other element of each row, and at each row's end, as the
---rows stand without it. Free of frame code.
---@param rows table<string, string[]>
---@param widths table<string, number>
---@param geometry AUIEditorGeometry
---@param key string? the carried element
---@return AUIEditorSlot[]
function Editor:Slots(rows, widths, geometry, key)
	local slots = {}

	for _, row in ipairs(AUI.MinimapLayout.ROWS) do
		local x, shown = geometry.left + PIECE_SPACE, 0
		local middle = geometry.top[row] + ROW_HEIGHT / 2

		for _, other in ipairs(rows[row] or {}) do
			if other ~= key then
				shown = shown + 1
				slots[#slots + 1] = { row = row, index = shown, x = x - PIECE_SPACE / 2, y = middle }
				x = x + widths[other] + PIECE_SPACE
			end
		end

		slots[#slots + 1] = { row = row, index = shown + 1, x = x - PIECE_SPACE / 2, y = middle }
	end

	return slots
end

---Draws the rows around the map, then puts each shown element's piece in its place.
---@return number width the diagram's natural size, which the library shrinks to fit the stage
---@return number height
function Editor:Draw()
	local canvas = self.canvas --[[@as Frame]]
	local layout = AUI.MinimapElements:Layout()
	local shown = {}

	wipe(self.rows)
	wipe(self.widths)

	-- Each row as wide as its pieces, all as wide as the widest, at least MIN_ROW_WIDTH.
	local rowWidth = MIN_ROW_WIDTH

	for _, row in ipairs(AUI.MinimapLayout.ROWS) do
		local list, width = {}, PIECE_SPACE

		for _, key in ipairs(layout[row]) do
			local element = AUI.MinimapElements.byKey[key]

			if Available(element) then
				local piece = self:Piece(key)

				list[#list + 1] = key
				shown[key] = true
				self.widths[key] = math.ceil(piece.text:GetUnboundedStringWidth()) + 2 * PIECE_PAD
				width = width + self.widths[key] + PIECE_SPACE
			end
		end

		self.rows[row] = list
		rowWidth = math.max(rowWidth, width)
	end

	local left = MARGIN + LABEL_WIDTH
	local geometry = { left = left, top = {} }
	local y = MARGIN

	local function DrawRow(row)
		local fill = self.rowFrames[row]

		geometry.top[row] = y
		fill:ClearAllPoints()
		fill:SetPoint("TOPLEFT", canvas, "TOPLEFT", left, -y)
		fill:SetSize(rowWidth, ROW_HEIGHT)
		fill.label:ClearAllPoints()
		fill.label:SetPoint("LEFT", canvas, "TOPLEFT", MARGIN, -(y + ROW_HEIGHT / 2))

		local plus = self.pluses[row]

		plus:ClearAllPoints()
		plus:SetPoint("LEFT", canvas, "TOPLEFT", left + rowWidth + 4, -(y + ROW_HEIGHT / 2))
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
	self.geometry = geometry

	for key, piece in pairs(self.pieces) do
		local on = shown[key] == true
		local enabled = AUI.Profile:Get(AUI.MinimapElements:EnabledPath(key)) == true

		piece.frame:SetShown(on)
		piece.hit:SetShown(on)
		piece.frame:SetSize(self.widths[key] or 0, ROW_HEIGHT - 4)
		piece.frame:SetAlpha(enabled and 1 or OFF_ALPHA)

		if not on then
			piece.placed = false
		end
	end

	self.slots = self:Slots(self.rows, self.widths, geometry, self.dragging and self.press and self.press.key or nil)
	self:Arrange()
	self:PlaceMarks()

	return left + rowWidth + SIDE + MARGIN, y - ROW_SPACE + MARGIN
end

---Sends each piece to its place: on its spring once it has had a place, at once the first time. The carried piece
---stays with the pointer.
function Editor:Arrange()
	local geometry = self.geometry

	if not geometry then
		return
	end

	local carried = self.dragging and self.press and self.press.key or nil
	local drag = carried and { key = carried, target = self.target } or nil

	for key, place in pairs(self:Positions(self.rows, self.widths, geometry, drag)) do
		local piece = self.pieces[key]

		if key ~= carried then
			if piece.placed then
				local response = key == self.released and SETTLE or MAKE_ROOM

				piece.x.response, piece.y.response = response, response
				piece.x:To(place.x)
				piece.y:To(place.y)
			else
				piece.placed = true
				piece.x:Jump(place.x)
				piece.y:Jump(place.y)
			end
		end
	end
end

---The diagram's height: margins, the four rows and the map between them. Free of frame code.
---@return number height
function Editor:Height()
	local rows = #AUI.MinimapLayout.ROWS

	return 2 * MARGIN + rows * ROW_HEIGHT + (rows - 1) * ROW_SPACE + MAP_HEIGHT + ROW_SPACE
end

---@return string caption the line under the diagram
function Editor:Caption()
	return L["Drag to move. × removes, + adds."]
end

---Places the hover outline and the × on the hovered element.
function Editor:PlaceMarks()
	local hover, remove = self.hover, self.remove
	local piece

	if self.hovered then
		piece = self.pieces[self.hovered]
	end

	if not piece or self.dragging or not piece.frame:IsShown() then
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

	local piece = self.hovered and self.pieces[self.hovered]

	if piece and piece.hit:IsShown() and piece.hit:IsMouseOver() then
		return
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

---Lights the pressed piece at once and starts following the pointer, keeping where on the piece it was grabbed.
---@param key string
function Editor:Press(key)
	local piece = self.pieces[key]
	local x, y = GetCursorPosition()
	local canvasX, canvasY = self:Cursor()

	self.press = { key = key, x = x, y = y, grabX = canvasX - piece.x.value, grabY = canvasY - piece.y.value }
	self.released = nil
	piece.fill:SetAlpha(PIECE_HELD)
	self:SetTracking(true)
end

---Ends a press that did not become a drag.
function Editor:Release()
	local piece = self.press and self.pieces[self.press.key]

	if piece then
		piece.fill:SetAlpha(PIECE_FILL[4])
	end

	self.press = nil
	self:SetTracking(false)
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
			self:Release()
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

	local canvasX, canvasY = self:Cursor()
	local piece = self.pieces[press.key]

	piece.x:Jump(canvasX - press.grabX)
	piece.y:Jump(canvasY - press.grabY)

	local width, height = (self.canvas --[[@as Frame]]):GetSize()
	local outside = canvasX < -CANCEL_DISTANCE or canvasY < -CANCEL_DISTANCE or canvasX > width + CANCEL_DISTANCE
		or canvasY > height + CANCEL_DISTANCE
	local target = not outside and self:NearestSlot(self.slots, canvasX, canvasY) or nil

	if (target and target.row .. target.index) ~= (self.target and self.target.row .. self.target.index) then
		self.target = target
		self:Arrange()
	end
end

---The pressed piece lifts above the others and the rest make room for it as it moves.
function Editor:StartDrag()
	local press = self.press --[[@as table]]
	local piece = self.pieces[press.key]

	self.dragging = true
	self.hovered = nil
	self.slots = self:Slots(self.rows, self.widths, self.geometry --[[@as AUIEditorGeometry]], press.key)
	piece.frame:SetFrameLevel((self.canvas --[[@as Frame]]):GetFrameLevel() + 40)

	for _, plus in pairs(self.pluses) do
		plus:Hide()
	end

	self:PlaceMarks()
end

---Ends a drag without moving anything: the carried piece returns to its place.
function Editor:CancelDrag()
	local press = self.press
	local piece = press and self.pieces[press.key]

	self.dragging = false
	self.target = nil
	self.released = press and press.key or nil

	if piece then
		piece.frame:SetFrameLevel((self.canvas --[[@as Frame]]):GetFrameLevel() + 1)
	end

	self:Release()
	self.slots = self:Slots(self.rows, self.widths, self.geometry --[[@as AUIEditorGeometry]])

	for _, plus in pairs(self.pluses) do
		plus:Show()
	end

	self:Arrange()
end

---Settles the carried piece into the target's place, or back into its own.
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
		window:RecordChange({ path = Elements.LAYOUT_PATH, before = before, text = text, page = "minimap" })
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
