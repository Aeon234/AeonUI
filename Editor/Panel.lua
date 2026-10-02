local AUI = select(2, ...)

local L = AUI.L

local PAD = 10
local ROW = 28
local LABEL_WIDTH = 44
local LABEL_GAP = 6
local BOX_WIDTH = 56
local BOX_HEIGHT = 20
local COLUMN_GAP = 12
local PICKER_HEIGHT = 26
local BUTTON_HEIGHT = 22
local OFFSET = 10

local WIDTH = PAD * 2 + (LABEL_WIDTH + LABEL_GAP + BOX_WIDTH) * 2 + COLUMN_GAP
local HEIGHT = PAD * 2 + PICKER_HEIGHT + ROW * 2 + BUTTON_HEIGHT + 8

---@class AUIEditBox : EditBox
---@field label FontString
---@field field string the element's setting the box shows: "x", "y", "width" or "height"

---@class AUIEditPanelFrame : Frame
---@field picker table the element picker dropdown
---@field boxes AUIEditBox[]
---@field settings Button
---@field id string? the element the panel shows

---The panel beside the selected mover: an element picker for movers that overlap, its position and size, and a
---button to its settings. A typed number applies on Enter only; Escape, leaving the box or an invalid number puts
---back the applied value.
---@class AUIEditPanel
---@field frame AUIEditPanelFrame?
local Panel = {}
AUI.EditorPanel = Panel

---@param box AUIEditBox
---@param value number
local function Fill(box, value)
	if not box:HasFocus() then
		box:SetText(tostring(math.floor(value + 0.5)))
	end
end

---@param parent AUIEditPanelFrame
---@param label string
---@param field string
---@return AUIEditBox
local function NumberBox(parent, label, field)
	---@type AUIEditBox
	local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")

	box.field = field
	box:SetSize(BOX_WIDTH, BOX_HEIGHT)
	box:SetAutoFocus(false)
	box:SetScript("OnEnterPressed", function(self)
		local value = tonumber(self:GetText())
		local id = parent.id

		self:ClearFocus()

		if value and id then
			AUI.Editor:SetField(id, field, value)
		end

		Panel:Refresh()
	end)
	box:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	box:HookScript("OnEditFocusLost", function()
		Panel:Refresh()
	end)

	box.label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	box.label:SetWidth(LABEL_WIDTH)
	box.label:SetJustifyH("RIGHT")
	box.label:SetPoint("RIGHT", box, "LEFT", -LABEL_GAP, 0)
	box.label:SetText(label)

	return box
end

function Panel:Build()
	if self.frame then
		return
	end

	---@type AUIEditPanelFrame
	local frame = CreateFrame("Frame", "AeonUIEditPanel", UIParent)

	frame:SetSize(WIDTH, HEIGHT)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:Hide()

	AUI.Editor:Skin(frame)

	frame.picker = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
	frame.picker:SetPoint("TOPLEFT", PAD, -PAD)
	frame.picker:SetPoint("TOPRIGHT", -PAD, -PAD)
	frame.picker:SetupMenu(function(_, root)
		for _, id in ipairs(AUI.Editor:ShownIDs()) do
			root:CreateRadio(AUI.EditorLayout:Label(AUI.EditorLayout:Find(id) --[[@as AUIEditorElement]]), function()
				return AUI.Editor.selected == id
			end, function()
				AUI.Editor:Select(id)
			end)
		end
	end)

	local column = PAD + LABEL_WIDTH + LABEL_GAP
	local second = column + BOX_WIDTH + COLUMN_GAP + LABEL_WIDTH + LABEL_GAP
	local top = -PAD - PICKER_HEIGHT - 8

	frame.boxes = {
		NumberBox(frame, L["X"], "x"),
		NumberBox(frame, L["Y"], "y"),
		NumberBox(frame, L["Width"], "width"),
		NumberBox(frame, L["Height"], "height"),
	}

	frame.boxes[1]:SetPoint("TOPLEFT", column, top)
	frame.boxes[2]:SetPoint("TOPLEFT", second, top)
	frame.boxes[3]:SetPoint("TOPLEFT", column, top - ROW)
	frame.boxes[4]:SetPoint("TOPLEFT", second, top - ROW)

	frame.settings = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.settings:SetText(SETTINGS)
	frame.settings:SetSize(WIDTH - PAD * 2, BUTTON_HEIGHT)
	frame.settings:SetPoint("BOTTOM", 0, PAD)
	frame.settings:SetScript("OnClick", function()
		local element = frame.id and AUI.EditorLayout:Find(frame.id)

		if element then
			AUI.Editor:OpenSettings(element)
		end
	end)

	self.frame = frame
end

---Places the panel under the selected mover, or above it near the bottom of the screen.
---@param mover AUIMover
function Panel:Place(mover)
	local frame = self.frame --[[@as AUIEditPanelFrame]]
	local _, bottom = mover:Rect()

	frame:ClearAllPoints()

	if bottom - HEIGHT - OFFSET > 0 then
		frame:SetPoint("TOP", mover, "BOTTOM", 0, -OFFSET)
	else
		frame:SetPoint("BOTTOM", mover, "TOP", 0, OFFSET)
	end
end

function Panel:Refresh()
	local mover = AUI.Editor:Showing() and AUI.Editor:SelectedMover() or nil

	if not mover then
		self:Hide()

		return
	end

	self:Build()

	local frame = self.frame --[[@as AUIEditPanelFrame]]
	local element = mover.element

	frame.id = element.id
	frame.picker:GenerateMenu()
	frame.picker:OverrideText(AUI.EditorLayout:Label(element))

	for _, box in ipairs(frame.boxes) do
		Fill(box, AUI.Profile:Get(AUI.EditorLayout:Path(element, box.field)))
	end

	self:Place(mover)
	frame:Show()
end

function Panel:Hide()
	local frame = self.frame

	if not frame then
		return
	end

	for _, box in ipairs(frame.boxes) do
		box:ClearFocus()
	end

	frame:Hide()
end
