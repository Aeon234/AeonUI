local AUI = select(2, ...)

local L = AUI.L
local Schema = AUI.Schema

local WIDTH = 280
local PAD = 10
local ROW = 28
local LABEL_WIDTH = 56
local LABEL_GAP = 6
local BOX_WIDTH = 56
local BOX_HEIGHT = 20
local COLUMN_GAP = 12
local PICKER_HEIGHT = 26
local MENU_LABEL_WIDTH = 74
local MENU_GAP = 4
local MATCH_WIDTH = 74
local BUTTON_HEIGHT = 22
local SECTION_GAP = 8
local OFFSET = 10

local SIDES = { "LEFT", "RIGHT", "TOP", "BOTTOM" }

---@class AUIEditBox : EditBox
---@field label FontString
---@field field string the element's setting the box shows: "x", "y", "width" or "height"

---@class AUIEditMenu : DropdownButton
---@field label FontString?
---@field OverrideText fun(self: AUIEditMenu, text: string) from the dropdown template's selection-text mixin

---@class AUIEditPanelFrame : Frame
---@field picker AUIEditMenu the element picker
---@field sample AUIEditMenu the element's sample state
---@field applyAll Button shows that state on every element offering it
---@field waiting FontString why the element waits
---@field reconnect Button
---@field detach Button
---@field boxes AUIEditBox[]
---@field target AUIEditMenu
---@field side AUIEditMenu
---@field links table<string, AUIEditMenu> the width and height links
---@field matches table<string, AUIEditMenu> Match Now for width and height
---@field attachRows Region[] shown while the attach part is open
---@field waitRows Region[] shown while the element waits for a missing frame
---@field expand Button
---@field settings Button
---@field id string? the element the panel shows

---The panel beside the selected mover: an element picker for movers that overlap, its position and size, an
---expandable attach part, and a button to its settings. A hosted addon's element shows its position only, with Reset
---Position in place of the attach part. A typed number applies on Enter only; Escape, leaving the box or an invalid
---number puts back the applied value.
---@class AUIEditPanel
---@field frame AUIEditPanelFrame?
---@field expanded boolean the attach part is open, for the session
local Panel = {
	expanded = false,
}
AUI.EditorPanel = Panel

---@param box AUIEditBox
---@param value number
local function Fill(box, value)
	if not box:HasFocus() then
		box:SetText(tostring(math.floor(value + 0.5)))
	end
end

---@return AUIEditorElement? element the element the panel shows
local function Shown()
	local frame = Panel.frame

	return frame and frame.id and AUI.EditorLayout:Find(frame.id) or nil
end

---@param parent AUIEditPanelFrame
---@param field string
---@return AUIEditBox
local function NumberBox(parent, field)
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

	return box
end

---@param parent Frame
---@param label string?
---@param width number
---@param setup fun(root: table)
---@return AUIEditMenu
local function Menu(parent, label, width, setup)
	---@type AUIEditMenu
	local menu = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")

	menu:SetWidth(width)
	menu:SetupMenu(function(_, root)
		setup(root)
	end)

	if label then
		menu.label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		menu.label:SetWidth(MENU_LABEL_WIDTH)
		menu.label:SetJustifyH("RIGHT")
		menu.label:SetPoint("RIGHT", menu, "LEFT", -LABEL_GAP, 0)
		menu.label:SetText(label)
	end

	return menu
end

---@param root table
---@param element AUIEditorElement
---@param none string the entry that ends the relationship
---@param current fun(): string the related element's id, or "none"
---@param choose fun(id: string?)
local function TargetEntries(root, element, none, current, choose)
	local Layout = AUI.EditorLayout

	root:CreateRadio(none, function()
		return current() == "none"
	end, function()
		choose(nil)
	end)

	for _, target in ipairs(Layout:Eligible(AUI.Profile.config, element)) do
		root:CreateRadio(Layout:Label(target), function()
			return current() == target.id
		end, function()
			choose(target.id)
		end)
	end
end

---@param frame AUIEditPanelFrame
---@param dimension "width"|"height"
---@param label string
local function LinkMenus(frame, dimension, label)
	local Layout = AUI.EditorLayout

	frame.links[dimension] = Menu(frame, label, WIDTH - PAD * 2 - MENU_LABEL_WIDTH - LABEL_GAP - MENU_GAP - MATCH_WIDTH,
		function(root)
			local element = Shown()

			if not element then
				return
			end

			TargetEntries(root, element, L["Own"], function()
				return AUI.Profile:Get(Layout:Path(element, "layout." .. dimension))
			end, function(id)
				AUI.Editor:Link(element.id, dimension, id)
				Panel:Refresh()
			end)
		end)

	frame.matches[dimension] = Menu(frame, nil, MATCH_WIDTH, function(root)
		local element = Shown()

		if not element then
			return
		end

		for _, target in ipairs(Layout.ELEMENTS) do
			if target ~= element then
				root:CreateButton(Layout:Label(target), function()
					AUI.Editor:MatchNow(element.id, dimension, target.id)
					Panel:Refresh()
				end)
			end
		end
	end)
	frame.matches[dimension]:SetPoint("LEFT", frame.links[dimension], "RIGHT", MENU_GAP, 0)
end

function Panel:Build()
	if self.frame then
		return
	end

	local Layout = AUI.EditorLayout

	---@type AUIEditPanelFrame
	local frame = CreateFrame("Frame", "AeonUIEditPanel", UIParent)

	frame:SetWidth(WIDTH)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:Hide()

	AUI.Editor:Skin(frame)

	frame.picker = Menu(frame, nil, WIDTH - PAD * 2, function(root)
		for _, id in ipairs(AUI.Editor:ShownIDs()) do
			root:CreateRadio(Layout:Label(Layout:Find(id) --[[@as AUIEditorElement]]), function()
				return AUI.Editor.selected == id
			end, function()
				AUI.Editor:Select(id)
			end)
		end
	end)
	frame.picker:SetPoint("TOPLEFT", PAD, -PAD)

	local sampleWidth = WIDTH - PAD * 2 - MENU_GAP - MATCH_WIDTH

	frame.sample = Menu(frame, nil, sampleWidth, function(root)
		local element = Shown()

		if not element then
			return
		end

		local Editor = AUI.Editor
		local current = Editor:SampleState(element)

		for _, state in ipairs(AUI.SettingsPreviews:States(Editor:StateKey(element))) do
			root:CreateRadio(state.label, function()
				return current.label == state.label
			end, function()
				Editor:SetState(element.id, state.label)
				Panel:Refresh()
			end)
		end
	end)
	frame.sample:SetPoint("TOPLEFT", PAD, -PAD - PICKER_HEIGHT - MENU_GAP)

	frame.applyAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.applyAll:SetText(L["Apply to All"])
	frame.applyAll:SetSize(MATCH_WIDTH, BUTTON_HEIGHT)
	frame.applyAll:SetPoint("LEFT", frame.sample, "RIGHT", MENU_GAP, 0)
	frame.applyAll:SetScript("OnEnter", function(button)
		GameTooltip:SetOwner(button, "ANCHOR_TOP")
		GameTooltip:SetText(L["Show this sample state on every element that has it."], 1, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	frame.applyAll:SetScript("OnLeave", GameTooltip_Hide)
	frame.applyAll:SetScript("OnClick", function()
		local element = Shown()

		if element then
			AUI.Editor:ApplyStateToAll(AUI.Editor:SampleState(element).label)
			Panel:Refresh()
		end
	end)

	local top = -PAD - PICKER_HEIGHT * 2 - MENU_GAP - SECTION_GAP

	frame.boxes = {
		NumberBox(frame, "x"),
		NumberBox(frame, "y"),
		NumberBox(frame, "width"),
		NumberBox(frame, "height"),
	}

	self:PlaceBoxes(frame, top)
	frame.boxes[3].label:SetText(L["Width"])
	frame.boxes[4].label:SetText(L["Height"])

	local menuLeft = PAD + MENU_LABEL_WIDTH + LABEL_GAP
	local menuTop = top - ROW * 2 - SECTION_GAP

	frame.target = Menu(frame, L["Attach To"], WIDTH - PAD - menuLeft, function(root)
		local element = Shown()

		if not element then
			return
		end

		TargetEntries(root, element, NONE, function()
			return AUI.Profile:Get(Layout:Path(element, "layout.attach.target"))
		end, function(id)
			AUI.Editor:Attach(element.id, id)
			Panel:Refresh()
		end)
	end)
	frame.target:SetPoint("TOPLEFT", menuLeft, menuTop)

	frame.side = Menu(frame, L["Side"], WIDTH - PAD - menuLeft, function(root)
		local element = Shown()

		if not element then
			return
		end

		local labels = { LEFT = L["Left"], RIGHT = L["Right"], TOP = L["Top"], BOTTOM = L["Bottom"] }

		for _, side in ipairs(SIDES) do
			root:CreateRadio(labels[side], function()
				return AUI.Profile:Get(Layout:Path(element, "layout.attach.side")) == side
			end, function()
				local target = Layout:AttachTarget(AUI.Profile.config, element)

				AUI.Editor:Attach(element.id, target and target.id or nil, side)
				Panel:Refresh()
			end)
		end
	end)
	frame.side:SetPoint("TOPLEFT", menuLeft, menuTop - ROW)

	frame.links, frame.matches = {}, {}
	LinkMenus(frame, "width", L["Match Width"])
	LinkMenus(frame, "height", L["Match Height"])
	frame.links.width:SetPoint("TOPLEFT", menuLeft, menuTop - ROW * 2)
	frame.links.height:SetPoint("TOPLEFT", menuLeft, menuTop - ROW * 3)

	frame.waiting = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.waiting:SetPoint("TOPLEFT", PAD, menuTop - ROW * 4 - 4)
	frame.waiting:SetPoint("TOPRIGHT", -PAD, menuTop - ROW * 4 - 4)
	frame.waiting:SetJustifyH("LEFT")
	frame.waiting:SetTextColor(1, 0.82, 0)

	local waitHalf = (WIDTH - PAD * 2 - MENU_GAP) / 2

	frame.reconnect = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.reconnect:SetText(L["Reconnect"])
	frame.reconnect:SetSize(waitHalf, BUTTON_HEIGHT)
	frame.reconnect:SetPoint("TOPLEFT", PAD, menuTop - ROW * 5)
	frame.reconnect:SetScript("OnClick", function()
		local element = Shown()

		if element then
			AUI.Editor:RequestReconnect(element.id)
		end
	end)

	frame.detach = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.detach:SetText(L["Detach"])
	frame.detach:SetSize(waitHalf, BUTTON_HEIGHT)
	frame.detach:SetPoint("TOPRIGHT", -PAD, menuTop - ROW * 5)
	frame.detach:SetScript("OnClick", function()
		local element = Shown()

		if element then
			AUI.Editor:Attach(element.id)
			Panel:Refresh()
		end
	end)

	frame.waitRows = { frame.waiting, frame.reconnect, frame.detach }
	frame.attachRows = { frame.target, frame.side }

	for _, menu in ipairs({ frame.target, frame.side, frame.links.width, frame.links.height }) do
		frame.attachRows[#frame.attachRows + 1] = menu.label
	end

	for _, dimension in ipairs({ "width", "height" }) do
		frame.attachRows[#frame.attachRows + 1] = frame.links[dimension]
		frame.attachRows[#frame.attachRows + 1] = frame.matches[dimension]
	end

	local half = (WIDTH - PAD * 2 - MENU_GAP) / 2

	frame.expand = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.expand:SetSize(half, BUTTON_HEIGHT)
	frame.expand:SetPoint("BOTTOMLEFT", PAD, PAD)
	frame.expand:SetScript("OnClick", function()
		local element = Shown()

		if element and element.guest then
			AUI.Editor:ResetGuest(element.id)
		else
			self.expanded = not self.expanded
		end

		self:Refresh()
	end)

	frame.settings = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.settings:SetText(SETTINGS)
	frame.settings:SetSize(half, BUTTON_HEIGHT)
	frame.settings:SetPoint("BOTTOMRIGHT", -PAD, PAD)
	frame.settings:SetScript("OnClick", function()
		local element = Shown()

		if element then
			AUI.Editor:OpenSettings(element)
		end
	end)

	self.frame = frame
end

---Places the position and size boxes in two rows from `top`.
---@param frame AUIEditPanelFrame
---@param top number
function Panel:PlaceBoxes(frame, top)
	local column = PAD + LABEL_WIDTH + LABEL_GAP
	local second = column + BOX_WIDTH + COLUMN_GAP + LABEL_WIDTH + LABEL_GAP
	local boxes = frame.boxes

	for index, box in ipairs(boxes) do
		box:ClearAllPoints()
		box:SetPoint("TOPLEFT", index % 2 == 1 and column or second, top - (index > 2 and ROW or 0))
	end
end

---@param waiting boolean the element waits for a missing frame, which adds a row with Reconnect and Detach
---@param guest boolean? a hosted addon's element: the picker, its position and the buttons
---@return number height the panel's height with the attach part open or closed
function Panel:Height(waiting, guest)
	if guest then
		return PAD * 2 + PICKER_HEIGHT + SECTION_GAP + ROW + BUTTON_HEIGHT
	end

	local rows = self.expanded and (waiting and 8 or 6) or 2

	return PAD * 2 + PICKER_HEIGHT * 2 + MENU_GAP + SECTION_GAP + ROW * rows + (self.expanded and SECTION_GAP or 0)
		+ BUTTON_HEIGHT
end

---Places the panel under the selected mover, or above it near the bottom of the screen.
---@param mover AUIMover
function Panel:Place(mover)
	local frame = self.frame --[[@as AUIEditPanelFrame]]
	local _, bottom = mover:Rect()

	frame:ClearAllPoints()

	if bottom - frame:GetHeight() - OFFSET > 0 then
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

	local Layout = AUI.EditorLayout
	local frame = self.frame --[[@as AUIEditPanelFrame]]
	local element = mover.element

	if element.guest then
		self:RefreshGuest(frame, mover)

		return
	end

	local config = AUI.Profile.config
	local target = Layout:AttachTarget(config, element)
	local attached = target ~= nil
	local waiting = attached and Layout:Waiting(config, element)

	-- An element waiting for a missing frame opens the attach part, where Reconnect and Detach are.
	if waiting then
		self.expanded = true
	end

	frame.id = element.id
	frame:SetHeight(self:Height(waiting))
	self:PlaceBoxes(frame, -PAD - PICKER_HEIGHT * 2 - MENU_GAP - SECTION_GAP)
	frame.sample:Show()
	frame.applyAll:Show()
	frame.boxes[3]:Show()
	frame.boxes[3].label:Show()
	frame.boxes[4]:Show()
	frame.boxes[4].label:Show()
	frame.expand:SetEnabled(true)
	frame.picker:GenerateMenu()
	frame.picker:OverrideText(Layout:Label(element))
	frame.sample:GenerateMenu()
	frame.sample:OverrideText(AUI.Editor:SampleState(element).label)

	frame.boxes[1].label:SetText(attached and L["X Offset"] or L["X"])
	frame.boxes[2].label:SetText(attached and L["Y Offset"] or L["Y"])

	for _, box in ipairs(frame.boxes) do
		local linked = (box.field == "width" or box.field == "height") and Layout:SizeTarget(config, element, box.field)

		Fill(box, Schema:Read(config, Layout:FieldPath(config, element, box.field)))
		box:SetEnabled(not linked)
		box:SetAlpha(linked and 0.5 or 1)
		box.label:SetAlpha(linked and 0.5 or 1)
	end

	for _, region in ipairs(frame.attachRows) do
		region:SetShown(self.expanded)
	end

	for _, region in ipairs(frame.waitRows) do
		region:SetShown(self.expanded and waiting)
	end

	if waiting and target then
		frame.waiting:SetText(L["Waiting for %s."]:format(Layout:Label(target)))
		frame.reconnect:SetEnabled(Layout:Available(target))
	end

	if self.expanded then
		frame.target:GenerateMenu()
		frame.side:GenerateMenu()
		frame.side:SetEnabled(attached)

		for _, dimension in ipairs({ "width", "height" }) do
			frame.links[dimension]:GenerateMenu()
			frame.matches[dimension]:GenerateMenu()
			frame.matches[dimension]:OverrideText(L["Match Now"])
		end
	end

	frame.expand:SetText(self.expanded and L["Hide Attach"] or L["Attach"])

	self:Place(mover)
	frame:Show()
end

---Shows a hosted addon's element: the picker, its center's offset from the screen's center, Reset Position and its
---settings.
---@param frame AUIEditPanelFrame
---@param mover AUIMover
function Panel:RefreshGuest(frame, mover)
	local Layout, Guest = AUI.EditorLayout, AUI.EditorGuest
	local element = mover.element
	local x, y = Guest:Center(element, UIParent:GetWidth(), UIParent:GetHeight())

	frame.id = element.id
	frame:SetHeight(self:Height(false, true))
	frame.picker:GenerateMenu()
	frame.picker:OverrideText(Layout:Label(element))
	frame.sample:Hide()
	frame.applyAll:Hide()

	self:PlaceBoxes(frame, -PAD - PICKER_HEIGHT - SECTION_GAP)

	for index, box in ipairs(frame.boxes) do
		local shown = index <= 2

		box:SetShown(shown)
		box.label:SetShown(shown)
		box:SetEnabled(true)
		box:SetAlpha(1)
		box.label:SetAlpha(1)
	end

	frame.boxes[1].label:SetText(L["X"])
	frame.boxes[2].label:SetText(L["Y"])
	Fill(frame.boxes[1], x)
	Fill(frame.boxes[2], y)

	for _, region in ipairs(frame.attachRows) do
		region:Hide()
	end

	for _, region in ipairs(frame.waitRows) do
		region:Hide()
	end

	frame.expand:SetText(RESET_POSITION)
	frame.expand:SetEnabled(not Guest:IsDefault(element))

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
