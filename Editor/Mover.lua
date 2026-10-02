local AUI = select(2, ...)

local FLAT = "Interface\\Buttons\\WHITE8X8"
-- Movers sit above their samples, so the samples never take the mouse.
local LEVEL = 50
local LEVEL_SELECTED = 60
local CONTENT_LEVEL = 1

local ACCENT = { 0.620, 0.459, 0.290 }
local SELECTED = { 1, 0.82, 0 }
local BORDER_ALPHA = 0.6
local BORDER_HOVER_ALPHA = 0.9
local WASH_ALPHA = 0.12
local LABEL_GAP = 2

---@return number x the cursor in UIParent units
---@return number y
local function Cursor()
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()

	return x / scale, y / scale
end

---@class AUIMoverDrag
---@field x number the cursor when the drag began
---@field y number
---@field left number the mover when the drag began
---@field bottom number
---@field moved boolean?

---A layout editor mover: the outline over one element's sample, which selects, drags and opens settings.
---@class AUIMover : Button
---@field element AUIEditorElement
---@field edges Texture[]
---@field wash Texture lightens the sample while selected
---@field label FontString the element's name, shown while hovered or selected
---@field content Frame holds the samples under the mover, the mover's own size
---@field samples table[] unit frame samples
---@field cast AUICastBarWidgets? the player cast bar sample
---@field resource table? the class resource sample
---@field drag AUIMoverDrag?
---@field selected boolean?
---@field hovered boolean?
local MoverMixin = {}

---@param left number
---@param bottom number
---@param width number
---@param height number
---@param pixel number one physical pixel in UIParent units
function MoverMixin:Place(left, bottom, width, height, pixel)
	local edges = self.edges

	self:ClearAllPoints()
	self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
	self:SetSize(math.max(width, pixel), math.max(height, pixel))

	edges[1]:SetHeight(pixel)
	edges[2]:SetHeight(pixel)
	edges[3]:SetWidth(pixel)
	edges[4]:SetWidth(pixel)
end

---@return number left
---@return number bottom
---@return number width
---@return number height
function MoverMixin:Rect()
	local left, bottom, width, height = self:GetRect()

	return left or 0, bottom or 0, width or 0, height or 0
end

function MoverMixin:Paint()
	local color = self.selected and SELECTED or ACCENT
	local alpha = (self.selected or self.hovered) and BORDER_HOVER_ALPHA or BORDER_ALPHA

	for _, edge in ipairs(self.edges) do
		edge:SetVertexColor(color[1], color[2], color[3], self.selected and 1 or alpha)
	end

	self.wash:SetShown(self.selected == true)
	self.label:SetShown(self.selected == true or self.hovered == true)
end

---@param selected boolean
function MoverMixin:SetSelected(selected)
	self.selected = selected

	self:SetFrameLevel(selected and LEVEL_SELECTED or LEVEL)
	self:Paint()
end

function MoverMixin:OnEnter()
	self.hovered = true

	self:Paint()
end

function MoverMixin:OnLeave()
	self.hovered = false

	self:Paint()
end

---@param button string
function MoverMixin:OnMouseDown(button)
	if button ~= "LeftButton" or not AUI.Editor:Showing() then
		return
	end

	AUI.Editor:Select(self.element.id)

	local x, y = Cursor()
	local left, bottom = self:Rect()

	self.drag = { x = x, y = y, left = left, bottom = bottom }
	self:SetScript("OnUpdate", self.OnDragUpdate)
end

function MoverMixin:OnDragUpdate()
	local drag = self.drag

	if not drag then
		return
	end

	local x, y = Cursor()

	if not drag.moved and (x ~= drag.x or y ~= drag.y) then
		drag.moved = true

		AUI.Editor:BeginDrag()
	end

	AUI.Editor:DragTo(self, drag.left + x - drag.x, drag.bottom + y - drag.y)
end

---@param button string
function MoverMixin:OnMouseUp(button)
	if button == "RightButton" and AUI.Editor:Showing() then
		AUI.Editor:Select(self.element.id)
		AUI.Editor:OpenSettings(self.element)

		return
	end

	self:StopDrag(true)
end

---@param commit boolean keep where the drag left the mover, rather than dropping the move
function MoverMixin:StopDrag(commit)
	local drag = self.drag

	if not drag then
		return
	end

	self.drag = nil
	self:SetScript("OnUpdate", nil)

	if drag.moved then
		AUI.Editor:EndDrag(self, commit)
	end
end

---Creates the layout editor's movers.
---@class AUIMoverFactory
local Mover = {}
AUI.EditorMover = Mover

---@param element AUIEditorElement
---@return AUIMover
function Mover:Create(element)
	---@type AUIMover
	local mover = CreateFrame("Button", nil, UIParent)

	Mixin(mover, MoverMixin)

	mover.element = element
	mover.samples = {}
	mover:SetFrameStrata("DIALOG")
	mover:RegisterForClicks("AnyUp")
	mover:SetScript("OnMouseDown", mover.OnMouseDown)
	mover:SetScript("OnMouseUp", mover.OnMouseUp)
	mover:SetScript("OnEnter", mover.OnEnter)
	mover:SetScript("OnLeave", mover.OnLeave)
	mover.content = CreateFrame("Frame", nil, UIParent)
	mover.content:SetFrameStrata("DIALOG")
	mover.content:SetFrameLevel(CONTENT_LEVEL)
	mover.content:SetAllPoints(mover)
	mover.content:Hide()

	mover:SetScript("OnShow", function(frame)
		frame.content:Show()
	end)
	mover:SetScript("OnHide", function(frame)
		frame:StopDrag(false)
		frame.hovered = false
		frame.content:Hide()
	end)

	mover.wash = mover:CreateTexture(nil, "OVERLAY", nil, 6)
	mover.wash:SetTexture(FLAT)
	mover.wash:SetVertexColor(1, 1, 1, WASH_ALPHA)
	mover.wash:SetAllPoints()

	local top = mover:CreateTexture(nil, "OVERLAY", nil, 7)
	local bottom = mover:CreateTexture(nil, "OVERLAY", nil, 7)
	local left = mover:CreateTexture(nil, "OVERLAY", nil, 7)
	local right = mover:CreateTexture(nil, "OVERLAY", nil, 7)

	top:SetPoint("TOPLEFT")
	top:SetPoint("TOPRIGHT")
	bottom:SetPoint("BOTTOMLEFT")
	bottom:SetPoint("BOTTOMRIGHT")
	left:SetPoint("TOPLEFT")
	left:SetPoint("BOTTOMLEFT")
	right:SetPoint("TOPRIGHT")
	right:SetPoint("BOTTOMRIGHT")

	mover.edges = { top, bottom, left, right }

	for _, edge in ipairs(mover.edges) do
		edge:SetTexture(FLAT)
		edge:SetSnapToPixelGrid(false)
		edge:SetTexelSnappingBias(0)
	end

	mover.label = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	mover.label:SetPoint("BOTTOMLEFT", mover, "TOPLEFT", 0, LABEL_GAP)
	mover.label:SetText(AUI.EditorLayout:Label(element))

	mover:SetSelected(false)
	mover:Hide()

	return mover
end
