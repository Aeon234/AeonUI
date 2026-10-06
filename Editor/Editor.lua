local AUI = select(2, ...)

local L = AUI.L
local Layout = AUI.EditorLayout
local Guest = AUI.EditorGuest

local FLAT = "Interface\\Buttons\\WHITE8X8"
local TOOLBAR_HEIGHT = 42
local TOOLBAR_INSET = 6
local BUTTON_TEMPLATE = "MainMenuFrameButtonTemplate"
local BUTTON_WIDTH = 100
local BUTTON_HEIGHT = 32
local GAP = 8
local GROUP_GAP = 24
local PAD = 16
local TOGGLE_ON = 0.6
local TOGGLE_OFF = 0.3
local TOGGLE_HOVER = 1
local SURFACE = { 0.06, 0.06, 0.07, 0.94 }
local OUTLINE = { 0.32, 0.32, 0.34, 1 }
local GUIDE = { 1, 0.82, 0, 0.9 }
local ACCENT = { 0.620, 0.459, 0.290 }

local GRID_SPACING = 32
local GRID_ALPHA = { DIMMED = { 0.25, 0.5 }, BRIGHT = { 0.45, 0.8 } }
local GRID_NEXT = { BRIGHT = "DIMMED", DIMMED = "OFF", OFF = "BRIGHT" }

local EXIT_POPUP = "AEONUI_EDIT_EXIT"
local RECONNECT_POPUP = "AEONUI_EDIT_RECONNECT"

StaticPopupDialogs[EXIT_POPUP] = {
	text = L["Save your layout changes?"],
	button1 = SAVE,
	button2 = CONTINUE,
	button3 = L["Discard"],
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnAccept = function()
		AUI.Editor:Save()
	end,
	OnAlt = function()
		AUI.Editor:Discard()
	end,
}

StaticPopupDialogs[RECONNECT_POPUP] = {
	text = L["Reconnect %s to %s? It moves back against it."],
	button1 = L["Reconnect"],
	button2 = CANCEL,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnAccept = function(_, id)
		AUI.Editor:Reconnect(id)
	end,
}

---@return number pixel one physical pixel in UIParent units
local function Pixel()
	return AUI:Pixel(UIParent)
end

---@param value number
---@param pixel number
---@return number value on the nearest physical pixel boundary
local function ToPixel(value, pixel)
	return math.floor(value / pixel + 0.5) * pixel
end

local function Ignore() end

---@class AUIEditToggle : Button
---@field label FontString
---@field name string
---@field state fun(): string, boolean the state's name, and whether it counts as on
---@field states string[] every name the state can return, so the toggle is as wide as the widest
---@field hovered boolean?

---@class AUIEditToolbar : Frame
---@field title FontString
---@field exit Button
---@field save Button
---@field toggles AUIEditToggle[]
---@field resume Button
---@field controls table[] disabled while combat pauses the session

---@class AUIEditGrid : Frame
---@field lines Texture[]

---The layout editor: a session over the active profile, begun from settings or `/aui edit`. Movers draw samples of
---each placed element over the live frames, which keep their secure state; a dropped or typed position is saved
---through the profile owner, which applies it to the live frames out of combat. Save keeps the session's changes,
---settings changed meanwhile included; Discard puts back the profile as it was when the session began. A hosted
---addon's elements join the session through its edit participant (`AUI.EditorGuest`): their movers sit over the real
---elements, which show the guest's samples, and the guest saves and discards their positions with the session.
---@class AUIEditor
---@field active boolean
---@field paused boolean combat interrupted the session
---@field inCombat boolean
---@field hidden boolean the settings window is in front of the layout
---@field dragging boolean
---@field fromSettings boolean? the session began from settings, which Save and Exit return to
---@field snapshot AUIProfileSnapshot?
---@field selected string? the selected element's id
---@field states table<string, string> each element's sample state label, for the session
---@field movers table<string, AUIMover>
---@field toolbar AUIEditToolbar?
---@field keyboard Frame?
---@field guides { x: Texture, y: Texture }?
---@field grid AUIEditGrid?
local Editor = {
	active = false,
	paused = false,
	inCombat = false,
	hidden = false,
	dragging = false,
	movers = {},
	states = {},
}
AUI.Editor = Editor

-- Session ---------------------------------------------------------------------------------------------------------

---@return boolean showing the movers are on screen and can be worked
function Editor:Showing()
	return self.active and not self.paused and not self.hidden
end

---@param fromSettings boolean? begun from the settings window
function Editor:Enter(fromSettings)
	if self.active then
		return
	end

	if AUI.failed or not AUI.Profile:CanEdit() then
		AUI:Print(L["the layout can't be edited while the saved settings can't be used."])

		return
	end

	if InCombatLockdown() then
		AUI:Print(L["the layout can't be edited in combat."])

		return
	end

	self:Build()

	self.active = true
	self.paused = false
	self.inCombat = false
	self.hidden = false
	self.dragging = false
	self.selected = nil
	self.states = {}
	self.fromSettings = fromSettings == true
	self.snapshot = AUI.Profile:Snapshot()
	Guest:Begin()

	AUI.Events:Register("PLAYER_REGEN_DISABLED", self, self.Pause)
	AUI.Events:Register("PLAYER_REGEN_ENABLED", self, function()
		self.inCombat = false
		self:ShowPausedToolbar()
	end)
	AUI.Events:Register("PLAYER_LOGOUT", self, function()
		-- Logging out mid-session keeps the profile as it was when the session began.
		local snapshot = self.snapshot

		if snapshot and AUI.Profile:Changed(snapshot) then
			AUI.Profile:Restore(snapshot)
		end

		Guest:Discard()
	end)
	AUI.Events:Register("GLOBAL_MOUSE_DOWN", self, function()
		if self:Showing() and not self:IsMouseOverLayout() then
			self:Deselect()
		end
	end)

	for _, event in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
		AUI.Events:Register(event, self, self.QueueRefresh)
	end

	AUI.Callbacks:Register("Profile", self, self.QueueRefresh)

	if AUI.Settings:IsOpen() then
		AUI.Settings:Close()
	end

	self:ShowLayout()
end

---The settings window's Edit Mode button: begins a session, or returns to the open one's layout.
function Editor:FromSettings()
	if self.active then
		AUI.Settings:Close()

		return
	end

	self:Enter(true)
end

---@return boolean dirty the session changed the profile or a hosted addon's positions
function Editor:IsDirty()
	return (self.snapshot ~= nil and AUI.Profile:Changed(self.snapshot)) or (self.active and Guest:IsDirty())
end

function Editor:RequestExit()
	if not self.active then
		return
	end

	if self:IsDirty() then
		StaticPopup_Show(EXIT_POPUP)

		return
	end

	self:Exit()
end

function Editor:Save()
	self.snapshot = nil
	Guest:Save()

	self:Exit()
end

function Editor:Discard()
	local snapshot = self.snapshot

	self.snapshot = nil

	if snapshot and AUI.Profile:Changed(snapshot) then
		AUI.Profile:Restore(snapshot)
	end

	Guest:Discard()
	self:Exit()
end

---Ends the session; one begun from settings returns there.
function Editor:Exit()
	if not self.active then
		return
	end

	local reopen = self.fromSettings == true and not self.hidden and not AUI.Settings:IsOpen()

	AUI.Events:UnregisterAll(self)
	AUI.Callbacks:Unregister("Profile", self)
	AUI.Events:Cancel("editorRefresh")
	StaticPopup_Hide(EXIT_POPUP)
	StaticPopup_Hide(RECONNECT_POPUP)

	self.active = false
	self.paused = false
	self.hidden = false
	self.dragging = false
	self.snapshot = nil
	self.selected = nil
	self.fromSettings = nil

	self:HideLayout(false)
	Guest:End()

	if reopen then
		AUI.Settings:Open()
	end
end

function Editor:Pause()
	self.inCombat = true

	if not self.active or self.paused then
		self:PaintToolbar()

		return
	end

	self.paused = true

	-- Combat hides everything, the toolbar too; it returns with Resume once combat ends.
	self:HideLayout(false)
	AUI:Print(L["layout editing is paused for combat."])
end

---After combat, brings back a paused session's toolbar, which offers Resume.
function Editor:ShowPausedToolbar()
	local toolbar = self.toolbar

	if toolbar and self.active and self.paused and not self.hidden then
		toolbar:SetAlpha(1)
		toolbar:Show()
	end

	self:PaintToolbar()
end

function Editor:Resume()
	if not self.paused or self.inCombat or InCombatLockdown() then
		return
	end

	self.paused = false

	if not self.hidden then
		self:ShowLayout()
	end
end

-- Settings ---------------------------------------------------------------------------------------------------------

---Opens an element's settings page, revealing its setting when it has one; the layout waits behind the window.
---@param element AUIEditorElement
function Editor:OpenSettings(element)
	AUI.Settings:Open(element.page)

	local window = AUI.Settings.window

	if element.setting and window and AUI.Settings:IsOpen() then
		window:FindSetting(element.setting)
	end
end

---Called when the settings window opens during a session.
function Editor:OnSettingsShown()
	if not self.active then
		return
	end

	self.hidden = true

	self:HideLayout(false)

	local window = AUI.Settings.window

	if window then
		window:ShowStatus(L["Editing the layout. Close settings or press Edit Mode to return."])
	end
end

---Called when the settings window closes.
function Editor:OnSettingsHidden()
	if not self.active or not self.hidden then
		return
	end

	self.hidden = false

	if not (self.paused and self.inCombat) then
		self:ShowLayout()
	end
end

-- Layout -----------------------------------------------------------------------------------------------------------

function Editor:ShowLayout()
	local toolbar = self.toolbar

	if not toolbar then
		return
	end

	toolbar:SetAlpha(1)
	toolbar:Show()
	self:PaintToolbar()

	if self.paused then
		return
	end

	if self.keyboard then
		self.keyboard:Show()
	end

	Guest:Show(true)
	self:RefreshMovers()
	self:RefreshGrid()
end

---@param keepToolbar boolean
function Editor:HideLayout(keepToolbar)
	for _, mover in pairs(self.movers) do
		mover:Hide()
	end

	AUI.EditorPanel:Hide()
	Guest:Show(false)

	if self.keyboard then
		self.keyboard:Hide()
	end

	self:HideGuides()

	if self.grid then
		self.grid:Hide()
	end

	if self.toolbar and not keepToolbar then
		self.toolbar:Hide()
	end
end

---Redraws the movers once after a burst of changes.
function Editor:QueueRefresh()
	AUI.Events:Coalesce("editorRefresh", function()
		if self:Showing() then
			self:RefreshMovers()
			self:RefreshGrid()
		end
	end)
end

---@param element AUIEditorElement
---@return string key the element's key for sample states: its frame key, or "cast" for the player cast bar
function Editor:StateKey(element)
	return element.base == "castbar." and "cast" or element.key
end

---@param element AUIEditorElement
---@return table state the sample state the element shows
function Editor:SampleState(element)
	return AUI.SettingsPreviews:FindState(self:StateKey(element), self.states[element.id])
end

---@param id string
---@param label string
function Editor:SetState(id, label)
	self.states[id] = label

	self:RefreshMovers()
end

---Shows a sample state on every shown element that offers it.
---@param label string
function Editor:ApplyStateToAll(label)
	for _, id in ipairs(self:ShownIDs()) do
		local element = Layout:Find(id) --[[@as AUIEditorElement]]
		local states = element.guest and {} or AUI.SettingsPreviews:States(self:StateKey(element))

		for _, state in ipairs(states) do
			if state.label == label then
				self.states[id] = label

				break
			end
		end
	end

	self:RefreshMovers()
end

---Draws a mover's samples from the profile, in the element's sample state.
---@param mover AUIMover
---@param config table
local function DrawSamples(mover, config)
	local element, content = mover.element, mover.content
	local Previews = AUI.SettingsPreviews
	local state = Editor:SampleState(element)

	if element.base == "castbar." then
		mover.cast = mover.cast or AUI.CastBar:Create(content)
		Previews:DrawEditCast(mover.cast --[[@as AUICastBarWidgets]], config, content, state)

		return
	end

	if element.key == "classPower" then
		mover.resource = mover.resource or Previews:NewClassPowerSample(content)

		local frame = mover.resource.frame

		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", content, "TOPLEFT")
		Previews:DrawClassPower(mover.resource, config, state, Ignore)

		return
	end

	local key = element.key
	local width = AUI.Schema:Read(config, "frames." .. key .. ".width")
	local main, power = AUI.UnitFrame:Heights(config, key)
	local _, _, shiftX, shiftY = Layout:Size(config, element)

	for slot = 1, element.group and Layout:GroupCount() or 1 do
		local sample = mover.samples[slot]

		if not sample then
			sample = Previews:NewSample(key, content, slot)
			mover.samples[slot] = sample
		end

		local x, y = AUI.UnitFrame:SlotOffset(config, key, element.group and slot or nil)

		sample.frame:SetSize(width, main + power)
		sample.frame:ClearAllPoints()
		sample.frame:SetPoint("CENTER", content, "CENTER", x - shiftX, y - shiftY)
		Previews:DrawEditSample(sample, key, config, state)
	end
end

function Editor:RefreshMovers()
	if not self:Showing() then
		return
	end

	local config = AUI.Profile.config
	local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
	local pixel = Pixel()

	for _, element in ipairs(Layout.ELEMENTS) do
		local mover = self.movers[element.id]

		if Layout:Shown(config, element) then
			if not mover then
				mover = AUI.EditorMover:Create(element)
				self.movers[element.id] = mover
			end

			local left, bottom, width, height = Layout:Rect(config, element, screenWidth, screenHeight)

			mover:Place(ToPixel(left, pixel), ToPixel(bottom, pixel), width, height, pixel)
			mover:Show()
			DrawSamples(mover, config)
		elseif mover then
			mover:Hide()
		end
	end

	self:RefreshGuestMovers(pixel)

	if self.selected and not self:SelectedMover() then
		self.selected = nil
	end

	self:PaintSelection()
end

---Places a mover over each element the hosted addon lists, measured from the element itself.
---@param pixel number
function Editor:RefreshGuestMovers(pixel)
	local seen = {}

	for _, element in ipairs(Guest:Refresh()) do
		local left, bottom, width, height = Guest:Rect(element)

		if left and bottom and width and height then
			local mover = self.movers[element.id]

			if not mover then
				mover = AUI.EditorMover:Create(element)
				self.movers[element.id] = mover
			end

			mover:Place(ToPixel(left, pixel), ToPixel(bottom, pixel), width, height, pixel)
			mover:Show()
			seen[element.id] = true
		end
	end

	for id, mover in pairs(self.movers) do
		if mover.element.guest and not seen[id] then
			mover:Hide()
		end
	end
end

---@return string[] ids the shown elements, in the picker's order: AeonUI's, then the hosted addon's
function Editor:ShownIDs()
	local ids = {}

	for _, list in ipairs({ Layout.ELEMENTS, Guest.elements }) do
		for _, element in ipairs(list) do
			local mover = self.movers[element.id]

			if mover and mover:IsShown() then
				ids[#ids + 1] = element.id
			end
		end
	end

	return ids
end

---@return AUIMover?
function Editor:SelectedMover()
	local mover = self.selected and self.movers[self.selected]

	if mover and mover:IsShown() then
		return mover
	end
end

function Editor:PaintSelection()
	for id, mover in pairs(self.movers) do
		mover:SetSelected(id == self.selected)
	end

	AUI.EditorPanel:Refresh()
end

---@param id string
function Editor:Select(id)
	if not self.movers[id] then
		return
	end

	self.selected = id

	self:PaintSelection()
end

function Editor:Deselect()
	if not self.selected then
		return
	end

	self.selected = nil

	self:PaintSelection()
end

---@return boolean over the cursor is on a mover, the panel, the toolbar or an open menu
function Editor:IsMouseOverLayout()
	for _, mover in pairs(self.movers) do
		if mover:IsShown() and mover:IsMouseOver() then
			return true
		end
	end

	local panel, toolbar = AUI.EditorPanel.frame, self.toolbar

	return (panel ~= nil and panel:IsShown() and panel:IsMouseOver())
		or (toolbar ~= nil and toolbar:IsShown() and toolbar:IsMouseOver())
		or Menu.GetManager():IsAnyMenuOpen()
end

-- Moving -----------------------------------------------------------------------------------------------------------

---Fades the toolbar out and hides the panel while a mover is dragged.
function Editor:BeginDrag()
	self.dragging = true

	if self.toolbar then
		self.toolbar:SetAlpha(0)
	end

	AUI.EditorPanel:Hide()
end

---@param mover AUIMover
---@param commit boolean save where the drag left the mover
function Editor:EndDrag(mover, commit)
	self.dragging = false

	self:HideGuides()

	if self.toolbar then
		self.toolbar:SetAlpha(1)
	end

	-- A hosted addon's element moved with the drag, so a drop is saved and anything else puts it back, even when
	-- combat ended the drag.
	if mover.element.guest then
		if commit and self:Showing() then
			local left, bottom = mover:Rect()

			Guest:Move(mover.element, left, bottom)
		else
			Guest:Revert(mover.element)
		end

		self:RefreshMovers()

		return
	end

	if not self:Showing() then
		return
	end

	if commit then
		local config = AUI.Profile.config
		local left, bottom = Layout:Rect(config, mover.element, UIParent:GetWidth(), UIParent:GetHeight())
		local newLeft, newBottom = mover:Rect()

		if AUI.Profile:SetPaths(Layout:Moved(config, mover.element, newLeft - left, newBottom - bottom)) then
			return
		end
	end

	self:RefreshMovers()
end

---@param mover AUIMover
---@return AUISnapLines
function Editor:SnapLines(mover)
	local rects = {}
	local config = AUI.Profile.config

	-- An element that relies on the dragged one moves with it, so its lines would chase the drag.
	for id, other in pairs(self.movers) do
		if other ~= mover and other:IsShown() and not AUI.Schema:DependsOn(config, id, mover.element.id) then
			rects[#rects + 1] = { other:Rect() }
		end
	end

	local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()

	for _, element in ipairs(Layout.EXTERNAL) do
		if Layout:Available(element) then
			rects[#rects + 1] = { Layout:Rect(config, element, screenWidth, screenHeight) }
		end
	end

	return Layout:Lines(rects, screenWidth, screenHeight)
end

---Moves a dragged mover: snapped unless Alt is held or snapping is off, kept on screen, on whole pixels.
---@param mover AUIMover
---@param left number
---@param bottom number
function Editor:DragTo(mover, left, bottom)
	local _, _, width, height = mover:Rect()
	local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
	local guideX, guideY = nil, nil

	if AUI.Profile:EditorPreference("snap", true) and not IsAltKeyDown() then
		left, bottom, guideX, guideY = Layout:Snap(left, bottom, width, height, self:SnapLines(mover),
			Layout.SNAP_DISTANCE)
	end

	local pixel = Pixel()

	left = ToPixel(Layout:Clamp(left, 0, math.max(screenWidth - width, 0)), pixel)
	bottom = ToPixel(Layout:Clamp(bottom, 0, math.max(screenHeight - height, 0)), pixel)

	self:ShowGuides(guideX, guideY)
	mover:Place(left, bottom, width, height, pixel)

	if mover.element.guest then
		Guest:Drag(mover.element, left, bottom)
	end
end

---Moves the selected element by UI units.
---@param dx number
---@param dy number
---@return boolean moved
function Editor:Nudge(dx, dy)
	local mover = self:SelectedMover()

	if not mover then
		return false
	end

	if mover.element.guest then
		local left, bottom = mover:Rect()

		Guest:Move(mover.element, left + dx, bottom + dy)
		self:RefreshMovers()

		return true
	end

	AUI.Profile:SetPaths(Layout:Moved(AUI.Profile.config, mover.element, dx, dy))

	return true
end

---Saves a typed position or size; a value the setting refuses changes nothing.
---@param id string
---@param field string "x", "y", "width" or "height"
---@param value number
---@return boolean ok
function Editor:SetField(id, field, value)
	local element = Layout:Find(id)

	if not element then
		return false
	end

	if element.guest then
		return self:SetGuestCenter(element, field, value)
	end

	return (AUI.Profile:Set(Layout:FieldPath(AUI.Profile.config, element, field), value))
end

---Moves a hosted addon's element so its center sits at a typed offset from the screen's center; it has no typed size.
---@param element AUIEditorElement
---@param field string
---@param value number
---@return boolean ok
function Editor:SetGuestCenter(element, field, value)
	if field ~= "x" and field ~= "y" then
		return false
	end

	local left, bottom, width, height = Guest:Rect(element)

	if not left or not bottom or not width or not height then
		return false
	end

	local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
	local x, y = Guest:Center(element, screenWidth, screenHeight)

	if field == "x" then
		x = value
	else
		y = value
	end

	left = Layout:Clamp(screenWidth / 2 + x - width / 2, 0, math.max(screenWidth - width, 0))
	bottom = Layout:Clamp(screenHeight / 2 + y - height / 2, 0, math.max(screenHeight - height, 0))

	Guest:Move(element, left, bottom)
	self:RefreshMovers()

	return true
end

---Returns a hosted addon's element to its default position.
---@param id string
function Editor:ResetGuest(id)
	local element = Layout:Find(id)

	if element and element.guest then
		Guest:Reset(element)
		self:RefreshMovers()
	end
end

---Attaches an element to another's side, keeping it where it is, or detaches it with `targetID` nil.
---@param id string
---@param targetID string?
---@param side string?
---@return boolean ok
function Editor:Attach(id, targetID, side)
	local element = Layout:Find(id)

	if not element then
		return false
	end

	local target = targetID and Layout:Find(targetID) or nil

	return (AUI.Profile:SetPaths(Layout:Attach(AUI.Profile.config, element, target, side)))
end

---Asks before ending an element's wait for a missing frame that came back, since reconnecting may move it.
---@param id string
function Editor:RequestReconnect(id)
	local element = Layout:Find(id)
	local target = element and Layout:AttachTarget(AUI.Profile.config, element)

	if element and target then
		StaticPopup_Show(RECONNECT_POPUP, Layout:Label(element), Layout:Label(target), id)
	end
end

---Ends an element's wait, so its stored offsets apply again.
---@param id string
---@return boolean ok
function Editor:Reconnect(id)
	local element = Layout:Find(id)

	if not element then
		return false
	end

	return (AUI.Profile:SetPaths(Layout:Reconnect(element)))
end

---Keeps an element's width or height matched to another's, or ends the link with `targetID` nil.
---@param id string
---@param dimension "width"|"height"
---@param targetID string?
---@return boolean ok
function Editor:Link(id, dimension, targetID)
	local element = Layout:Find(id)

	if not element then
		return false
	end

	return (AUI.Profile:SetPaths({ [Layout:Path(element, "layout." .. dimension)] = targetID or "none" }))
end

---Copies another element's width or height once.
---@param id string
---@param dimension "width"|"height"
---@param targetID string
---@return boolean ok
function Editor:MatchNow(id, dimension, targetID)
	local element, target = Layout:Find(id), Layout:Find(targetID)

	if not element or not target then
		return false
	end

	return (AUI.Profile:SetPaths(Layout:MatchNow(AUI.Profile.config, element, dimension, target)))
end

---@param key string
---@return boolean handled
function Editor:OnKey(key)
	if not self:Showing() then
		return false
	end

	if key == "ESCAPE" then
		if Menu.GetManager():IsAnyMenuOpen() or StaticPopup_Visible(EXIT_POPUP) then
			return false
		end

		self:RequestExit()

		return true
	end

	local step = IsShiftKeyDown() and 10 or 1

	if key == "LEFT" then
		return self:Nudge(-step, 0)
	elseif key == "RIGHT" then
		return self:Nudge(step, 0)
	elseif key == "UP" then
		return self:Nudge(0, step)
	elseif key == "DOWN" then
		return self:Nudge(0, -step)
	end

	return false
end

-- Guides and grid --------------------------------------------------------------------------------------------------

---@param x number? the vertical line a drag snapped to
---@param y number? the horizontal line
function Editor:ShowGuides(x, y)
	local guides = self.guides

	if not guides then
		return
	end

	local pixel = Pixel()

	if x then
		guides.x:ClearAllPoints()
		guides.x:SetPoint("TOPLEFT", UIParent, "TOPLEFT", ToPixel(x, pixel), 0)
		guides.x:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", ToPixel(x, pixel), 0)
		guides.x:SetWidth(pixel)
		guides.x:Show()
	else
		guides.x:Hide()
	end

	if y then
		guides.y:ClearAllPoints()
		guides.y:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, ToPixel(y, pixel))
		guides.y:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, ToPixel(y, pixel))
		guides.y:SetHeight(pixel)
		guides.y:Show()
	else
		guides.y:Hide()
	end
end

function Editor:HideGuides()
	self:ShowGuides(nil, nil)
end

---@param grid AUIEditGrid
---@param index integer
---@return Texture
local function GridLine(grid, index)
	local line = grid.lines[index]

	if not line then
		line = grid:CreateTexture(nil, "BACKGROUND")
		line:SetTexture(FLAT)
		line:SetSnapToPixelGrid(false)
		line:SetTexelSnappingBias(0)
		grid.lines[index] = line
	end

	return line
end

---Lines one physical pixel wide, GRID_SPACING pixels apart, counted out from a brighter center cross.
function Editor:RefreshGrid()
	local grid = self.grid

	if not grid then
		return
	end

	local alphas = GRID_ALPHA[AUI.Profile:EditorPreference("grid", "BRIGHT")]

	if not self:Showing() or not alphas then
		grid:Hide()

		return
	end

	local pixel = Pixel()
	local spacing = GRID_SPACING * pixel
	local width, height = UIParent:GetWidth(), UIParent:GetHeight()
	local centerX, centerY = ToPixel(width / 2, pixel), ToPixel(height / 2, pixel)
	local count = 0

	---@param vertical boolean
	---@param at number
	---@param alpha number
	local function Line(vertical, at, alpha)
		count = count + 1

		local line = GridLine(grid, count)

		line:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], alpha)
		line:ClearAllPoints()

		if vertical then
			line:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", at, 0)
			line:SetSize(pixel, height)
		else
			line:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, at)
			line:SetSize(width, pixel)
		end

		line:Show()
	end

	for offset = spacing, math.max(width, height), spacing do
		if centerX - offset > 0 then
			Line(true, ToPixel(centerX - offset, pixel), alphas[1])
		end

		if centerX + offset < width then
			Line(true, ToPixel(centerX + offset, pixel), alphas[1])
		end

		if centerY - offset > 0 then
			Line(false, ToPixel(centerY - offset, pixel), alphas[1])
		end

		if centerY + offset < height then
			Line(false, ToPixel(centerY + offset, pixel), alphas[1])
		end
	end

	Line(true, centerX, alphas[2])
	Line(false, centerY, alphas[2])

	for index = count + 1, #grid.lines do
		grid.lines[index]:Hide()
	end

	grid:Show()
end

-- Toolbar ----------------------------------------------------------------------------------------------------------

---@param frame Frame
---@param from FramePoint
---@param to FramePoint
---@param horizontal boolean
local function Edge(frame, from, to, horizontal)
	local line = frame:CreateTexture(nil, "BORDER")

	line:SetTexture(FLAT)
	line:SetVertexColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], OUTLINE[4])
	line:SetPoint(from)
	line:SetPoint(to)
	line:SetSnapToPixelGrid(false)
	line:SetTexelSnappingBias(0)

	if horizontal then
		line:SetHeight(Pixel())
	else
		line:SetWidth(Pixel())
	end
end

---Gives an editor surface its dark background and one-pixel outline.
---@param frame Frame
function Editor:Skin(frame)
	local background = frame:CreateTexture(nil, "BACKGROUND")

	background:SetTexture(FLAT)
	background:SetVertexColor(SURFACE[1], SURFACE[2], SURFACE[3], SURFACE[4])
	background:SetAllPoints()

	Edge(frame, "TOPLEFT", "TOPRIGHT", true)
	Edge(frame, "BOTTOMLEFT", "BOTTOMRIGHT", true)
	Edge(frame, "TOPLEFT", "BOTTOMLEFT", false)
	Edge(frame, "TOPRIGHT", "BOTTOMRIGHT", false)
end

---@param parent Frame
---@param text string
---@param onClick fun()
---@return Button
local function ToolbarButton(parent, text, onClick)
	local button = CreateFrame("Button", nil, parent, BUTTON_TEMPLATE)

	button:SetText(text)
	button:SetSize(math.max(button:GetTextWidth() + 40, BUTTON_WIDTH), BUTTON_HEIGHT)
	button:SetScript("OnClick", onClick)

	return button
end

---@param fontString FontString
---@param texts string[]
---@return number width the widest of the texts; the font string keeps what it showed
local function Widest(fontString, texts)
	local shown = fontString:GetText()
	local widest = 0

	for _, text in ipairs(texts) do
		fontString:SetText(text)
		widest = math.max(widest, fontString:GetStringWidth())
	end

	fontString:SetText(shown)

	return widest
end

---@param parent Frame
---@param name string
---@param state fun(): string, boolean
---@param onClick fun()
---@param states string[]
---@return AUIEditToggle
local function Toggle(parent, name, state, onClick, states)
	---@type AUIEditToggle
	local toggle = CreateFrame("Button", nil, parent)

	toggle.name = name
	toggle.state = state
	toggle.states = states
	toggle.label = toggle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	toggle.label:SetPoint("LEFT")
	toggle.label:SetJustifyH("LEFT")

	toggle:SetScript("OnClick", function()
		onClick()
		Editor:PaintToolbar()
	end)
	toggle:SetScript("OnEnter", function(self)
		self.hovered = true
		Editor:PaintToolbar()
	end)
	toggle:SetScript("OnLeave", function(self)
		self.hovered = false
		Editor:PaintToolbar()
	end)

	return toggle
end

---@param toggle AUIEditToggle
local function PaintToggle(toggle)
	local text, on = toggle.state()
	local alpha = (toggle.hovered and toggle:IsEnabled()) and TOGGLE_HOVER or (on and TOGGLE_ON or TOGGLE_OFF)
	local texts = {}

	toggle.label:SetText(toggle.name .. "\n" .. text)
	toggle.label:SetTextColor(1, 1, 1, alpha)

	for index, name in ipairs(toggle.states) do
		texts[index] = toggle.name .. "\n" .. name
	end

	toggle:SetSize(Widest(toggle.label, texts), BUTTON_HEIGHT)
end

-- Grid preference names.
local GRID_NAMES = { BRIGHT = L["Bright"], DIMMED = L["Dimmed"], OFF = OFF }

---@return AUIEditToolbar
function Editor:BuildToolbar()
	---@type AUIEditToolbar
	local toolbar = CreateFrame("Frame", "AeonUIEditToolbar", UIParent)

	toolbar:SetFrameStrata("FULLSCREEN_DIALOG")
	toolbar:SetHeight(TOOLBAR_HEIGHT)
	toolbar:SetPoint("TOP", UIParent, "TOP", 0, -TOOLBAR_INSET)
	toolbar:EnableMouse(true)
	toolbar:Hide()

	self:Skin(toolbar)

	toolbar.title = toolbar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	toolbar.title:SetPoint("CENTER")
	toolbar.title:SetJustifyH("CENTER")

	toolbar.exit = ToolbarButton(toolbar, L["Exit"], function()
		self:RequestExit()
	end)
	toolbar.save = ToolbarButton(toolbar, SAVE, function()
		self:Save()
	end)

	toolbar.toggles = {
		Toggle(toolbar, L["Snap"], function()
			local on = AUI.Profile:EditorPreference("snap", true) == true

			return on and L["On"] or OFF, on
		end, function()
			AUI.Profile:SetEditorPreference("snap", not AUI.Profile:EditorPreference("snap", true))
		end, { L["On"], OFF }),
		Toggle(toolbar, L["Grid Lines"], function()
			local grid = AUI.Profile:EditorPreference("grid", "BRIGHT")

			return GRID_NAMES[grid] or GRID_NAMES.BRIGHT, grid ~= "OFF"
		end, function()
			AUI.Profile:SetEditorPreference("grid", GRID_NEXT[AUI.Profile:EditorPreference("grid", "BRIGHT")] or "BRIGHT")
			self:RefreshGrid()
		end, { GRID_NAMES.BRIGHT, GRID_NAMES.DIMMED, GRID_NAMES.OFF }),
	}

	toolbar.resume = ToolbarButton(toolbar, L["Resume Editing"], function()
		self:Resume()
	end)
	toolbar.resume:SetPoint("TOP", toolbar, "BOTTOM", 0, -GAP)
	toolbar.resume:Hide()

	toolbar.controls = { toolbar.exit, toolbar.save }

	for _, toggle in ipairs(toolbar.toggles) do
		toolbar.controls[#toolbar.controls + 1] = toggle
	end

	return toolbar
end

---Exit sits at the left, the toggles and Save at the right of the centered title; the bar is as wide as its busier
---side needs so the title stays in the middle.
function Editor:LayoutToolbar()
	local toolbar = self.toolbar --[[@as AUIEditToolbar]]
	local toggles = 0

	for index, toggle in ipairs(toolbar.toggles) do
		PaintToggle(toggle)
		toggle:ClearAllPoints()

		if index == 1 then
			toggle:SetPoint("LEFT", toolbar.title, "RIGHT", GROUP_GAP, 0)
		else
			toggle:SetPoint("LEFT", toolbar.toggles[index - 1], "RIGHT", GAP * 2, 0)
		end

		toggles = toggles + toggle:GetWidth() + (index > 1 and GAP * 2 or 0)
	end

	toolbar.exit:ClearAllPoints()
	toolbar.exit:SetPoint("LEFT", PAD, 0)
	toolbar.save:ClearAllPoints()
	toolbar.save:SetPoint("RIGHT", -PAD, 0)

	local titleWidth = Widest(toolbar.title, {
		AUI.title .. "\n" .. HUD_EDIT_MODE_MENU,
		AUI.title .. "\n" .. L["Paused"],
		AUI.title .. "\n" .. L["Paused for combat"],
	})
	local left = PAD + toolbar.exit:GetWidth() + GROUP_GAP
	local right = GROUP_GAP + toggles + GROUP_GAP + toolbar.save:GetWidth() + PAD

	toolbar:SetWidth(math.max(left, right) * 2 + titleWidth)
end

function Editor:PaintToolbar()
	local toolbar = self.toolbar

	if not toolbar then
		return
	end

	local locked = self.paused and self.inCombat
	local second = HUD_EDIT_MODE_MENU

	if self.paused then
		second = RED_FONT_COLOR:WrapTextInColorCode(self.inCombat and L["Paused for combat"] or L["Paused"])
	end

	toolbar.title:SetText(AUI.title .. "\n" .. second)
	toolbar.resume:SetShown(self.paused and not self.inCombat)

	for _, control in ipairs(toolbar.controls) do
		control:SetEnabled(not locked)
	end

	self:LayoutToolbar()
end

-- Construction -----------------------------------------------------------------------------------------------------

---@return Frame
function Editor:BuildKeyboard()
	local keyboard = CreateFrame("Frame", nil, UIParent)

	keyboard:SetSize(1, 1)
	keyboard:SetPoint("CENTER")
	keyboard:EnableKeyboard(true)
	keyboard:SetPropagateKeyboardInput(true)
	keyboard:SetScript("OnKeyDown", function(frame, key)
		-- Keyboard propagation cannot change in combat; the session pauses then anyway.
		if InCombatLockdown() then
			return
		end

		frame:SetPropagateKeyboardInput(not self:OnKey(key))
	end)
	keyboard:Hide()

	return keyboard
end

---@param parent Frame
---@return Texture
local function Guide(parent)
	local line = parent:CreateTexture(nil, "OVERLAY")

	line:SetTexture(FLAT)
	line:SetVertexColor(GUIDE[1], GUIDE[2], GUIDE[3], GUIDE[4])
	line:SetSnapToPixelGrid(false)
	line:SetTexelSnappingBias(0)
	line:Hide()

	return line
end

function Editor:Build()
	if self.toolbar then
		return
	end

	local overlay = CreateFrame("Frame", nil, UIParent)

	overlay:SetAllPoints(UIParent)
	overlay:SetFrameStrata("FULLSCREEN")

	---@type AUIEditGrid
	local grid = CreateFrame("Frame", nil, UIParent)

	grid:SetAllPoints(UIParent)
	grid:SetFrameStrata("BACKGROUND")
	grid:SetFrameLevel(1)
	grid:Hide()
	grid.lines = {}

	self.grid = grid
	self.guides = { x = Guide(overlay), y = Guide(overlay) }
	self.keyboard = self:BuildKeyboard()
	self.toolbar = self:BuildToolbar()
end
