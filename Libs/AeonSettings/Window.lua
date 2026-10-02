-- Settings window: chrome, category column, page tabs and list, search, bands and session memory.
local _, ns = ...
local AS = ns.AeonSettings
local L = AS.L
local tokens = AS.tokens

local CATEGORY_X = tokens.size.categoryColumnX
local CATEGORY_WIDTH = tokens.size.categoryColumn
local PAGE_X = 18 + CATEGORY_WIDTH + tokens.space.columnGap
local TOP = 76
local TOP_BAND = 28
local CLOSE_RIGHT = 16
local HEADER_HEIGHT = 50
local LIST_GAP = 4
local BOTTOM = 47
local RIGHT = 22
local SCROLLBAR_GAP = 6
local RELOAD_NOTICE_GAP = 10
local DEFAULT_CONTENT_WIDTH = 1065
local DEFAULT_ROWS = 20
local DEFAULTS_RIGHT = 36
local TITLE_X = 7
local JUMP_GAP = 8
local JUMP_WIDTH = 25
local JUMP_MIN_SECTIONS = 3
local JUMP_FLASH_DELAY = 0.15
local FIND_TOP_GAP = 40 -- a found setting's section header lands this far below the list's top
local TAB_TEMPLATE = "MinimalTabTemplate"
local TAB_GAP = 5 -- between tabs, as Blizzard's Settings panel spaces its own
local TAB_TEXT_PADDING = 40 -- MinimalTabTemplate's width beyond its text
local VERSION_COLOR = "|cff9d9d9d"

-- Options_InnerFrame nine-slice insets, in atlas pixels drawn at one UI unit each.
local INNER_ATLAS = "Options_InnerFrame"
local INNER_LEFT, INNER_RIGHT, INNER_TOP, INNER_BOTTOM = 204, 8, 8, 8
local INNER_X, INNER_Y = tokens.space.innerFrameX, tokens.space.innerFrameY
local INNER_BOTTOM_OFFSET = tokens.space.innerBottom

local RESET_POPUP = "AeonUISettings_RESET_PAGE"

-- Element kinds ---------------------------------------------------------------------------------------------

---An element kind's functions run through `AS:CallHost`: an error is reported and leaves the frame as it is.
---@class AeonSettingsElementKind
---@field template string virtual frame template the page list creates for this kind
---@field Init fun(frame: Frame, entry: AeonSettingsEntry, window: table) binds a pooled frame to an entry
---@field Reset (fun(frame: Frame))? clears a frame before it returns to the pool
---@field Search (fun(data: table): string?)? text matched by search; nil excludes the element
---@field Settings (fun(data: table): table[])? the settings an element shows, for dependency lookups
---@field Refresh (fun(frame: Frame))? re-applies the active state of the settings the frame shows
---@field Flash (fun(frame: Frame, settingID: string?))? highlights the frame after a jump to it: the part
---showing `settingID` when given, otherwise the whole element
---@field section boolean? the element starts a section; following elements belong to it

---A page-list entry: an element as the window lists it.
---@class AeonSettingsEntry
---@field kind string
---@field data table the element the page built
---@field pageID string? page the element belongs to
---@field position integer? 1-based position within its section, or within its search group
---@field last boolean? last element of its section
---@field onSurface boolean? drawn on a section surface
---@field collapsed boolean? a collapsible section that is collapsed
---@field empty boolean? a section with no elements after it

---@type table<string, AeonSettingsElementKind>
AS.elementKinds = AS.elementKinds or {}

---Registers a kind of page-list element. Every element is one row tall.
---@param kind string
---@param definition AeonSettingsElementKind
function AS:RegisterElementKind(kind, definition)
	self.elementKinds[kind] = definition
end

-- Search divider --------------------------------------------------------------------------------------------

AeonUISettings_SearchDividerMixin = {}

function AeonUISettings_SearchDividerMixin:OnClick()
	PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
	self.window:OpenSearchHit(self.data.pageID, self.data.firstHit)
end

function AeonUISettings_SearchDividerMixin:OnEnter()
	self.MouseoverOverlay:Show()
end

function AeonUISettings_SearchDividerMixin:OnLeave()
	self.MouseoverOverlay:Hide()
end

AS:RegisterElementKind("searchDivider", {
	template = "AeonUISettings_SearchDividerTemplate",
	Init = function(frame, entry, window)
		frame.window = window
		frame.data = entry.data
		frame.Title:SetText(entry.data.title)
	end,
	Reset = function(frame)
		frame.MouseoverOverlay:Hide()
		frame.window = nil
		frame.data = nil
	end,
})

-- Reset confirmation ----------------------------------------------------------------------------------------

StaticPopupDialogs[RESET_POPUP] = {
	text = L["Reset %s to defaults?"],
	button1 = L["Reset"],
	button2 = CANCEL,
	showAlert = true,
	OnAccept = function(_, data)
		data.window:ResetPage(data.pageID)
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

-- Window ----------------------------------------------------------------------------------------------------

---@class AeonSettingsWindow : Frame
---@field options table creation options
---@field categories table[] category definitions
---@field pages table<string, table> page definitions by id
---@field memory { page: string?, scroll: table<string, number>, sections: table<string, table<string, boolean>>, tabs: table<string, string>, initial: table<string, any>, previewHidden: boolean, previewStates: table<string, string> }
---`memory.page` is the page the window is on, kept through a search; `memory.scroll` holds each page's scroll
---position, per tab, from when it was last left; `memory.tabs` each page's chosen tab.
---@field scrollGeneration integer increments with each smooth scroll; a stale scroll's follow-up is dropped
---@field reloadPending table<string, true>
---@field shownElements AeonSettingsEntry[]? entries in the page list, in order
---@field model AeonSettingsPageModel
---@field sections AeonSettingsEntry[] section entries of the shown page
---@field listPageID string? the page the list shows; nil while it shows search results
---@field listTabID string? the tab the list shows, on a page with tabs
---@field tabButtons Button[] the tab bar's buttons, reused across pages
---@field tabsShown boolean the tab bar shows, taking one row above the list
---@field listHeight number height of the list area at the window's size, before any pinned preview
---@field initializers table<string, fun(frame: Frame, entry: AeonSettingsEntry)> cached frame initializers by kind
---@field pinnedHeight number? height of the preview panel pinned above the list
---@field searching boolean the list shows search results
AeonUISettings_WindowMixin = {}

function AeonUISettings_WindowMixin:OnLoad()
	self.categories = {}
	self.pages = {}
	self.memory = { scroll = {}, sections = {}, tabs = {}, initial = {}, previewHidden = false, previewStates = {} }
	self.scrollGeneration = 0
	self.reloadPending = {}
	self.sections = {}
	self.model = AS.CreatePageModel(self.memory, AS.elementKinds)
	self.searching = false
	self.initializers = {}
	self.tabButtons = {}
	self.tabsShown = false

	self:RegisterForDrag("LeftButton")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self.ClosePanelButton:SetScript("OnClick", function()
		self:Hide()
	end)

	self:BuildInnerFrame()
	self:InitPageList()
	self:InitTabBar()
	self:InitBands()
	self:InitHeader()

	self.Categories.onSelect = function(pageID)
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
		self:SelectPage(pageID)
	end

	self.SearchBox:HookScript("OnTextChanged", function()
		self:OnSearchTextChanged()
	end)
end

---Draws Options_InnerFrame as a nine-slice: the left column and caps keep their native size, the middle
---stretches. Draws nothing when the client lacks the atlas.
function AeonUISettings_WindowMixin:BuildInnerFrame()
	local info = C_Texture.GetAtlasInfo(INNER_ATLAS)
	if not info then
		return
	end

	local anchor = CreateFrame("Frame", nil, self)
	anchor:SetPoint("TOPLEFT", INNER_X, -INNER_Y)
	anchor:SetPoint("BOTTOMRIGHT", -INNER_X, INNER_BOTTOM_OFFSET)

	local file = info.file or info.filename
	local width, height = info.width, info.height
	local uSpan = info.rightTexCoord - info.leftTexCoord
	local vSpan = info.bottomTexCoord - info.topTexCoord

	-- Each column and row: start and end in atlas pixels, and the anchor side and offset for each edge.
	local columns = {
		{ 0, INNER_LEFT, "LEFT", 0, "LEFT", INNER_LEFT },
		{ INNER_LEFT, width - INNER_RIGHT, "LEFT", INNER_LEFT, "RIGHT", -INNER_RIGHT },
		{ width - INNER_RIGHT, width, "RIGHT", -INNER_RIGHT, "RIGHT", 0 },
	}
	local rows = {
		{ 0, INNER_TOP, "TOP", 0, "TOP", -INNER_TOP },
		{ INNER_TOP, height - INNER_BOTTOM, "TOP", -INNER_TOP, "BOTTOM", INNER_BOTTOM },
		{ height - INNER_BOTTOM, height, "BOTTOM", INNER_BOTTOM, "BOTTOM", 0 },
	}

	for _, row in ipairs(rows) do
		for _, column in ipairs(columns) do
			local texture = self:CreateTexture(nil, "OVERLAY", nil, 2)
			texture:SetTexture(file)
			texture:SetTexCoord(
				info.leftTexCoord + uSpan * column[1] / width,
				info.leftTexCoord + uSpan * column[2] / width,
				info.topTexCoord + vSpan * row[1] / height,
				info.topTexCoord + vSpan * row[2] / height
			)
			texture:SetPoint("TOPLEFT", anchor, row[3] .. column[3], column[4], row[4])
			texture:SetPoint("BOTTOMRIGHT", anchor, row[5] .. column[5], column[6], row[6])
		end
	end
end

function AeonUISettings_WindowMixin:InitPageList()
	local page = self.Page
	local view = CreateScrollBoxListLinearView()
	local kinds = AS.elementKinds

	view:SetElementFactory(function(factory, data)
		local kind = kinds[data.kind]
		factory(kind.template, self:Initializer(data.kind))
	end)
	view:SetElementExtent(tokens.size.row)
	view:SetElementResetter(function(frame, data)
		local kind = kinds[data.kind]
		if kind and kind.Reset then
			AS:CallHost(nil, kind.Reset, frame)
		end
	end)

	ScrollUtil.InitScrollBoxListWithScrollBar(page.ScrollBox, page.ScrollBar, view)
	page.ScrollBar:SetPoint("TOPLEFT", page.ScrollBox, "TOPRIGHT", SCROLLBAR_GAP, 0)
	page.ScrollBar:SetPoint("BOTTOMLEFT", page.ScrollBox, "BOTTOMRIGHT", SCROLLBAR_GAP, 0)
	ScrollUtil.AddManagedScrollBarVisibilityBehavior(page.ScrollBox, page.ScrollBar)
end

---Creates the tab bar: one row above the page list, under any pinned preview.
function AeonUISettings_WindowMixin:InitTabBar()
	local bar = CreateFrame("Frame", nil, self.Page)
	bar:SetHeight(tokens.size.row)
	bar:Hide()
	self.Page.TabBar = bar
end

---Returns the cached frame initializer for an element kind.
---@param kind string
---@return fun(frame: Frame, entry: AeonSettingsEntry)
function AeonUISettings_WindowMixin:Initializer(kind)
	local initializer = self.initializers[kind]
	if not initializer then
		initializer = function(frame, data)
			AS:CallHost(nil, AS.elementKinds[kind].Init, frame, data, self)
		end
		self.initializers[kind] = initializer
	end

	return initializer
end

function AeonUISettings_WindowMixin:InitBands()
	local buttonHeight = tokens.size.windowButton
	local bandBottom = tokens.space.bottomBand

	self.EditModeButton:SetSize(CATEGORY_WIDTH, buttonHeight)
	self.EditModeButton:SetPoint("TOPLEFT", CATEGORY_X, -TOP_BAND)
	self.ReloadButton:SetSize(CATEGORY_WIDTH, buttonHeight)
	self.ReloadButton:SetPoint("BOTTOMLEFT", CATEGORY_X, bandBottom)
	self.CloseButton:SetSize(tokens.size.closeButton, buttonHeight)
	self.CloseButton:SetPoint("BOTTOMRIGHT", -CLOSE_RIGHT, bandBottom)

	self.EditModeButton:SetText(HUD_EDIT_MODE_MENU)
	self.EditModeButton:SetScript("OnClick", function()
		AS:CallHost(nil, self.options.onEditMode, self)
	end)

	self.ReloadButton:SetText(RELOADUI)
	self.ReloadButton:SetScript("OnClick", function()
		ReloadUI()
	end)

	self.CloseButton:SetText(CLOSE)
	self.CloseButton:SetScript("OnClick", function()
		self:Hide()
	end)

	self.SearchBox:SetPoint("BOTTOMRIGHT", self.Page, "TOPRIGHT", 4, 20)

	AS:SetFont(self.ReloadNotice, "body")
	self.ReloadNotice:SetTextColor(unpack(tokens.color.notice))
	self.ReloadNotice:ClearAllPoints()
	self.ReloadNotice:SetPoint("LEFT", self.ReloadButton, "RIGHT", RELOAD_NOTICE_GAP, 0)

	local status = self.StatusFrame
	AS:SetFont(status.Text, "body")
	status.Text:SetTextColor(unpack(tokens.color.text))
	status:SetPoint("CENTER", self, "BOTTOM", 0, bandBottom + buttonHeight / 2)

	local fade = status:CreateAnimationGroup()
	local alpha = fade:CreateAnimation("Alpha")
	alpha:SetFromAlpha(1)
	alpha:SetToAlpha(0)
	alpha:SetDuration(tokens.motion.fadeOut)
	alpha:SetStartDelay(tokens.motion.statusHold)
	fade:SetScript("OnFinished", function()
		status:Hide()
	end)
	status.fade = fade
end

function AeonUISettings_WindowMixin:InitHeader()
	local header = self.Page.Header

	header.DefaultsButton:SetText(SETTINGS_DEFAULTS)
	AS:FitButtonWidth(header.DefaultsButton)
	header.DefaultsButton:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		local page = self.pages[self.memory.page]
		if page then
			StaticPopup_Show(RESET_POPUP, page.title, nil, { window = self, pageID = page.id })
		end
	end)

	local jump = header.JumpDropdown
	jump:EnableMouseWheel(false)
	jump:HookScript("OnEnter", function()
		GameTooltip:SetOwner(jump, "ANCHOR_RIGHT")
		GameTooltip:SetText(L["Jump to section"])
		GameTooltip:Show()
	end)
	jump:HookScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	jump:SetupMenu(function(_, root)
		for _, section in ipairs(self.sections) do
			local text = section.data.title
			if section.collapsed then
				text = L["%s (collapsed)"]:format(text)
			end
			root:CreateRadio(text, function()
				local current = self:CurrentSection()
				return current ~= nil and current.data.id == section.data.id
			end, function()
				self:JumpToSection(section)
			end)
		end
	end)
end

---Sizes the window from the content width and the number of rows.
function AeonUISettings_WindowMixin:Layout()
	local contentWidth = self.options.contentWidth or DEFAULT_CONTENT_WIDTH
	local rows = self.options.rows or DEFAULT_ROWS
	local listHeight = rows * tokens.size.row
	local pageHeight = HEADER_HEIGHT + LIST_GAP + listHeight

	self:SetSize(PAGE_X + contentWidth + RIGHT, TOP + pageHeight + BOTTOM)

	self.Categories:ClearAllPoints()
	self.Categories:SetPoint("TOPLEFT", CATEGORY_X, -TOP)
	self.Categories:SetSize(CATEGORY_WIDTH, pageHeight)

	local page = self.Page
	page:ClearAllPoints()
	page:SetPoint("TOPLEFT", PAGE_X, -TOP)
	page:SetSize(contentWidth, pageHeight)
	page.Preview:ClearAllPoints()
	page.Preview:SetPoint("TOPLEFT", 0, -(HEADER_HEIGHT + LIST_GAP))
	page.Preview:SetWidth(contentWidth)

	self.listHeight = listHeight
	self:LayoutList(0)
end

---Places the tab bar, when shown, below a pinned preview of `preview` height, and the page list below both; the
---list keeps its bottom edge.
---@param preview number
function AeonUISettings_WindowMixin:LayoutList(preview)
	local top = HEADER_HEIGHT + LIST_GAP + preview
	local bar = self.Page.TabBar
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", 0, -top)
	bar:SetPoint("TOPRIGHT", 0, -top)

	local pinned = preview + (self.tabsShown and tokens.size.row or 0)
	self.pinnedHeight = pinned
	local scrollBox = self.Page.ScrollBox
	scrollBox:ClearAllPoints()
	scrollBox:SetPoint("TOPLEFT", 0, -(HEADER_HEIGHT + LIST_GAP + pinned))
	scrollBox:SetSize(self.Page:GetWidth(), self.listHeight - pinned)
end

---Shows the tab bar for a page with tabs, the active one selected, or hides it. Takes effect at the next
---`LayoutList`.
---@param page table? nil for search results
function AeonUISettings_WindowMixin:UpdateTabs(page)
	local tabs = page and self.model:Tabs(page.id)
	local count = tabs and #tabs or 0
	self.tabsShown = count > 0
	self.Page.TabBar:SetShown(self.tabsShown)
	self.listTabID = page and self.model:ActiveTab(page.id)

	local buttons = self.tabButtons
	for index = 1, math.max(count, #buttons) do
		local tab = tabs and tabs[index]
		local button = buttons[index] or tab and self:CreateTabButton(index)
		if tab then
			button.tabID = tab.id
			button.Text:SetText(tab.title)
			button:SetWidth(button.Text:GetStringWidth() + TAB_TEXT_PADDING)
			button:SetSelected(tab.id == self.listTabID)
			button:Show()
		elseif button then
			button:Hide()
		end
	end
end

---Creates the tab bar's button at `index`, after the one before it.
---@param index integer
---@return Button
function AeonUISettings_WindowMixin:CreateTabButton(index)
	local bar = self.Page.TabBar
	local previous = self.tabButtons[index - 1]
	local button = CreateFrame("Button", nil, bar, TAB_TEMPLATE)
	if previous then
		button:SetPoint("BOTTOMLEFT", previous, "BOTTOMRIGHT", TAB_GAP, 0)
	else
		button:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT")
	end
	button:SetScript("OnClick", function()
		self:SelectTab(button.tabID)
	end)
	self.tabButtons[index] = button

	return button
end

---Returns the key a page's selected preview state is remembered under; pages sharing a `stateKey` share it.
---@param page table a page with a `preview`
---@return string
local function PreviewStateKey(page)
	return page.preview.stateKey or page.id
end

---Shows the page's preview panel, or hides it when the page has none, and fits the list below it.
---@param page table?
function AeonUISettings_WindowMixin:LayoutPreview(page)
	local panel = self.Page.Preview
	if not page or not page.preview or self.searching then
		panel:Hide()
		self:LayoutList(0)

		return
	end

	local preview = page.preview
	local state = self.memory.previewStates[PreviewStateKey(page)] or (preview.states and preview.states[1])
	local switch = self.model:PageSwitch(page.id)
	local faded = switch ~= nil and not AS:CallHost(nil, switch.get)
	local availableRows = math.floor(self.listHeight / tokens.size.row) - 1 - (self.tabsShown and 1 or 0)
	local height = panel:Setup(self, page, self.memory.previewHidden, state, faded, availableRows)
	self:LayoutList(height)
end

---Calls the page's preview `Stop`, when it has one.
---@param page table?
function AeonUISettings_WindowMixin:StopPreview(page)
	local stop = page and page.preview and page.preview.Stop
	if stop then
		AS:CallHost(nil, stop)
	end
end

---Records the page the list shows (nil for search results). On a change it stops the previous page's
---preview, clears the chosen part and calls the host's `onPageChanged`.
---@param page table?
function AeonUISettings_WindowMixin:NoteListedPage(page)
	local id = page and page.id
	if id == self.notedPageID then
		return
	end

	self:StopPreview(self.notedPageID and self.pages[self.notedPageID])
	self.notedPageID = id
	self.Page.Preview:SetChosen(nil)
	if self.options.onPageChanged then
		AS:CallHost(nil, self.options.onPageChanged, id)
	end
end

---Keeps the preview's outline on the part with `key` (`addPart`'s key) until another is chosen; nil clears it.
---@param key any?
function AeonUISettings_WindowMixin:SetPreviewChosen(key)
	self.Page.Preview:SetChosen(key)
end

---Hides or shows the preview body on every page for the session, keeping the list's pixel scroll position.
---@param hidden boolean
function AeonUISettings_WindowMixin:SetPreviewHidden(hidden)
	if hidden then
		self:StopPreview(self:CurrentPage())
	end
	self.memory.previewHidden = hidden
	self:RedrawPreview()
end

---Redraws the preview from the page's current settings, keeping the rows where they are on screen.
function AeonUISettings_WindowMixin:RedrawPreview()
	if not self:IsShown() or self.searching then
		return
	end

	self:KeepScrollOffset(function()
		self:LayoutPreview(self:CurrentPage())
	end)
end

---Runs `rebuild` and keeps the rows where they are on screen: the list's scroll offset moves by however much
---the preview panel's height changed. Cancels a running smooth scroll first.
---@param rebuild fun()
function AeonUISettings_WindowMixin:KeepScrollOffset(rebuild)
	local scrollBox = self.Page.ScrollBox
	self:CancelSmoothScroll()
	local offset = scrollBox:GetDerivedScrollOffset()
	local before = self.pinnedHeight or 0
	rebuild()
	scrollBox:ScrollToOffset(offset + (self.pinnedHeight or 0) - before, ScrollBoxConstants.NoScrollInterpolation)
end

---Selects a sample state for the page's preview kind, for the session.
---@param state string
function AeonUISettings_WindowMixin:SetPreviewState(state)
	local page = self:CurrentPage()
	if not page or not page.preview then
		return
	end

	self:StopPreview(page)
	self.memory.previewStates[PreviewStateKey(page)] = state
	self:RedrawPreview()
end

-- Public interface ------------------------------------------------------------------------------------------

---Creates a settings window.
---`onPageChanged(pageID)` runs when the list shows another page, or search results (nil); `onClose()` runs when
---the window hides.
---@param options { name: string, title: string, version: string?, contentWidth: number?, rows: number?, onEditMode: fun(window: table)?, onPageChanged: fun(pageID: string?)?, onClose: fun()? }
---@return AeonSettingsWindow
function AS:CreateWindow(options)
	assert(type(options.name) == "string", "CreateWindow: options.name must be a global frame name")

	local window = CreateFrame("Frame", options.name, UIParent, "AeonUISettings_WindowTemplate")
	window.options = options
	window:SetPoint("CENTER")
	window:Layout()

	local title = options.title
	if options.version then
		title = title .. "  " .. VERSION_COLOR .. options.version .. "|r"
	end
	window.NineSlice.Text:SetText(title)
	window.EditModeButton:SetShown(options.onEditMode ~= nil)

	tinsert(UISpecialFrames, options.name)

	return window
end

---Replaces the category and page definitions.
---Each category is `{ id, title, icon?, pages }`; each page is `{ id, title, icon?, Build, Reset?, preview?, tabs? }`,
---where `Build()` returns the page's element list, `Reset()`, when present, restores the page's defaults,
---`preview` is an `AeonSettingsPreview`, and `tabs`, `{ { id, title } }`, splits the page's sections across tabs:
---each section names its tab in `tab`, and a tab that holds nothing is not shown.
---@param categories table[]
function AeonUISettings_WindowMixin:SetCategories(categories)
	self.categories = categories
	self.model:SetCategories(categories)
	wipe(self.pages)
	for _, category in ipairs(categories) do
		for _, page in ipairs(category.pages) do
			self.pages[page.id] = page
		end
	end
	self.Categories:SetCategories(categories)

	if not self:IsShown() then
		return
	end

	if self.searching then
		self:RunSearch(strtrim(self.SearchBox:GetText()))
	elseif self.listPageID and self.listPageID == self.memory.page and self.pages[self.listPageID] then
		self:RefreshPage()
	else
		self:ShowPage(self:CurrentPage())
	end
end

---Opens the window, optionally on a page, whose category then expands in the category list. Refused in
---combat.
---@param pageID string?
function AeonUISettings_WindowMixin:Open(pageID)
	if InCombatLockdown() then
		UIErrorsFrame:AddExternalErrorMessage(L["Unavailable in combat."])
		return
	end

	local known = pageID ~= nil and self.pages[pageID] ~= nil
	if self:IsShown() then
		if known then
			self:SelectPage(pageID)
		end
	else
		if known then
			self:SaveScroll()
			self.memory.page = pageID
		end
		self:Show()
	end
	if known then
		self.Categories:Reveal(pageID)
	end
end

function AeonUISettings_WindowMixin:Close()
	self:Hide()
end

function AeonUISettings_WindowMixin:Toggle()
	if self:IsShown() then
		self:Close()
	else
		self:Open()
	end
end

---Shows a page. `hitIndex`, an index into the full element list of the page's latest build, shows that build
---and scrolls to the element.
---@param pageID string
---@param hitIndex number?
function AeonUISettings_WindowMixin:SelectPage(pageID, hitIndex)
	if not self.pages[pageID] then
		return
	end

	if self.searching then
		self:ClearSearch()
	end

	self:SaveScroll()
	self.memory.page = pageID
	self:ShowPage(self.pages[pageID], hitIndex)
end

---Rebuilds the shown page, or runs the shown search again, keeping the rows where they are on screen.
function AeonUISettings_WindowMixin:RefreshPage()
	if not self:IsShown() then
		return
	end

	self:KeepScrollOffset(function()
		if self.searching then
			self:RunSearch(strtrim(self.SearchBox:GetText()))
		else
			self:BuildList(self:CurrentPage())
		end
	end)
end

---Collapses or expands a collapsible section on a page, for the session.
---@param pageID string
---@param sectionID string
---@param collapsed boolean
function AeonUISettings_WindowMixin:SetSectionCollapsed(pageID, sectionID, collapsed)
	self.model:SetCollapsed(pageID, sectionID, collapsed)
	if pageID == self.memory.page then
		self:RefreshPage()
	end
end

---Shows a message in the status line: held, then faded out.
---@param text string
function AeonUISettings_WindowMixin:ShowStatus(text)
	if not self:IsShown() then
		return
	end

	local status = self.StatusFrame
	status.fade:Stop()
	status.Text:SetText(text)
	status:SetAlpha(1)
	status:Show()
	status.fade:Play()
end

---Marks a setting as needing a reload, or clears it. `key` identifies the setting.
---@param key string
---@param pending boolean
function AeonUISettings_WindowMixin:SetReloadPending(key, pending)
	self.reloadPending[key] = pending or nil

	local count = 0
	for _ in pairs(self.reloadPending) do
		count = count + 1
	end

	if count == 0 then
		self.ReloadNotice:Hide()
	else
		self.ReloadNotice:SetText(count == 1 and L["1 change needs a reload"] or L["%d changes need a reload"]:format(count))
		self.ReloadNotice:Show()
	end
end

-- Pages -----------------------------------------------------------------------------------------------------

---@return table? page the remembered page, or the first page
function AeonUISettings_WindowMixin:CurrentPage()
	local page = self.pages[self.memory.page]
	if page then
		return page
	end

	local first = self.categories[1] and self.categories[1].pages[1]
	self.memory.page = first and first.id

	return first
end

---Fills the page list from a page. With `reuse`, lists the page's latest build instead of building it again.
---@param page table
---@param reuse boolean?
---@return table<number, number> map full-list index to shown index
function AeonUISettings_WindowMixin:BuildList(page, reuse)
	local shown, sections, map = self.model:Build(page, reuse)
	self:ShowList(shown, sections, page, page.title)

	return map
end

---Puts entries in the page list and brings everything that depends on the list up to date: reload changes,
---the header's title, Defaults button and jump menu, the empty-list message, the listed page and its
---preview. `page` is nil for search results.
---@param entries AeonSettingsEntry[]
---@param sections AeonSettingsEntry[]
---@param page table?
---@param title string
---@param emptyText string? shown when there are no entries
function AeonUISettings_WindowMixin:ShowList(entries, sections, page, title, emptyText)
	self.shownElements = entries
	self.sections = sections
	self:ApplyReloadChanges()

	local header = self.Page.Header
	local hasDefaults = page ~= nil and page.Reset ~= nil
	local showJump = #sections >= JUMP_MIN_SECTIONS
	header.DefaultsButton:SetShown(hasDefaults)
	header.JumpDropdown:SetShown(showJump)
	self:SetHeaderTitle(title, hasDefaults, showJump)

	local empty = self.Page.Empty
	empty:SetText(emptyText or "")
	empty:SetShown(emptyText ~= nil and #entries == 0)

	self.listPageID = page and page.id
	self:NoteListedPage(page)
	self:UpdateTabs(page)
	self:LayoutPreview(page)
	self.Page.ScrollBox:SetDataProvider(CreateDataProvider(entries), ScrollBoxConstants.DiscardScrollPosition)
end

---Shows a page, building it. With `hitIndex`, an index into the full element list of the page's latest build,
---lists that build without building again, expands the element's section and scrolls to the element.
---@param page table?
---@param hitIndex number?
function AeonUISettings_WindowMixin:ShowPage(page, hitIndex)
	if not page then
		return
	end

	self.Categories:SetSelected(page.id)
	self:CancelSmoothScroll()

	if hitIndex then
		self.model:Reveal(page.id, hitIndex)
		local tab = self.model:TabOf(page.id, hitIndex)
		if tab then
			self.model:SetTab(page.id, tab)
		end
	end

	local map = self:BuildList(page, hitIndex ~= nil)
	local scrollBox = self.Page.ScrollBox
	if hitIndex and map[hitIndex] then
		scrollBox:ScrollToElementDataIndex(map[hitIndex], ScrollBoxConstants.AlignBegin, 0,
			ScrollBoxConstants.NoScrollInterpolation)
	else
		scrollBox:SetScrollPercentage(self.memory.scroll[self:ScrollKey()] or 0, ScrollBoxConstants.NoScrollInterpolation)
	end
end

---@return string key the listed page's scroll memory key, which names its tab on a page with tabs
function AeonUISettings_WindowMixin:ScrollKey()
	if self.listTabID then
		return self.listPageID .. "/" .. self.listTabID
	end

	return self.listPageID
end

---Remembers the scroll position of the page and tab the list is showing.
function AeonUISettings_WindowMixin:SaveScroll()
	if self.searching or not self.listPageID then
		return
	end

	self.memory.scroll[self:ScrollKey()] = self.Page.ScrollBox:GetScrollPercentage()
end

---Shows another tab of the shown page, for the session, at the scroll position it was last left at.
---@param tabID string
function AeonUISettings_WindowMixin:SelectTab(tabID)
	local page = self:CurrentPage()
	if not page or self.searching or tabID == self.listTabID then
		return
	end

	PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
	self:SaveScroll()
	self.model:SetTab(page.id, tabID)
	self:ShowPage(page)
end

---Sets the page header title, truncated so it stays clear of the jump menu and the Defaults button.
---@param text string
---@param hasDefaults boolean
---@param hasJump boolean
function AeonUISettings_WindowMixin:SetHeaderTitle(text, hasDefaults, hasJump)
	local header = self.Page.Header
	local title = header.Title
	local available = self.Page:GetWidth() - TITLE_X - DEFAULTS_RIGHT
	if hasDefaults then
		available = available - header.DefaultsButton:GetWidth() - JUMP_GAP
	end
	if hasJump then
		available = available - JUMP_GAP - JUMP_WIDTH
	end

	title:SetWidth(0)
	title:SetText(text)
	if title:GetStringWidth() > available then
		title:SetWidth(available)
	end
end

local RESET_FAILED = {}

---Resets a page to its defaults after confirmation. The page is rebuilt either way; the status line reports
---the reset only when `Reset()` raised no error.
---@param pageID string
function AeonUISettings_WindowMixin:ResetPage(pageID)
	local page = self.pages[pageID]
	if not page or not page.Reset then
		return
	end

	local failed = AS:CallHost(RESET_FAILED, page.Reset) == RESET_FAILED
	if pageID == self.memory.page then
		self:RefreshPage()
	end
	if not failed then
		self:ShowStatus(L["%s reset to defaults."]:format(page.title))
	end
end

-- Settings ------------------------------------------------------------------------------------------------

---Returns whether a setting is active and, when not, the reason (`AeonSettingsPageModel:State`).
---@param pageID string
---@param setting table
---@return boolean enabled
---@return string? reason
function AeonUISettings_WindowMixin:SettingState(pageID, setting)
	return self.model:State(pageID, setting)
end

---Updates the page after a setting slot saved a value (`AeonSettingsSettingSlot:Request`): reload tracking,
---then the rows' active states and the preview. An action (a setting without `get`) or a setting marked
---`rebuild` that did not refuse rebuilds the page instead, since it may have changed other settings. `ok` is `set`'s first result, false
---when it refused or raised an error.
---A rebuild asked for during a slider drag waits for the drag to end, since rebuilding would take the slider away.
---@param pageID string
---@param setting AeonSettingsSetting
---@param ok boolean?
---@param control table? the control that saved
function AeonUISettings_WindowMixin:SettingSaved(pageID, setting, ok, control)
	if setting.reload then
		self.model:TrackReload(pageID, setting)
		self:ApplyReloadChanges()
	end
	if (not setting.get or setting.rebuild) and ok ~= false and pageID == self.listPageID then
		if control and control:IsInteracting() then
			control:AfterInteraction(function()
				if self.listPageID == pageID then
					self:RefreshPage()
				end
			end)
		else
			self:RefreshPage()

			return
		end
	end
	self:RefreshRows()
	if pageID == self.listPageID then
		self:RedrawPreview()
	end
end

---Applies the reload-pending changes the page model has recorded since the last call.
function AeonUISettings_WindowMixin:ApplyReloadChanges()
	for key, pending in pairs(self.model:TakeReloadChanges()) do
		self:SetReloadPending(key, pending)
	end
end

---Re-applies the active state of the elements in view through their kinds' `Refresh`.
function AeonUISettings_WindowMixin:RefreshRows()
	self.Page.ScrollBox:ForEachFrame(function(frame, entry)
		local kind = entry and AS.elementKinds[entry.kind]
		if kind and kind.Refresh then
			AS:CallHost(nil, kind.Refresh, frame)
		end
		-- ForEachFrame stops at the first callback that returns a true value.
	end)
end

-- Jump to section -------------------------------------------------------------------------------------------

---@return table? section the section whose header is at, or was last passed at, the top of the list
function AeonUISettings_WindowMixin:CurrentSection()
	local offset = self.Page.ScrollBox:GetDerivedScrollOffset()
	local rowHeight = tokens.size.row
	local current = self.sections[1]

	for index, entry in ipairs(self.shownElements or {}) do
		if (index - 1) * rowHeight > offset + 0.5 then
			break
		end
		if AS.elementKinds[entry.kind].section then
			current = entry
		end
	end

	return current
end

---Scrolls a section's header to the top of the list, expanding it first when collapsed, then flashes it.
---@param section table
function AeonUISettings_WindowMixin:JumpToSection(section)
	local page = self:CurrentPage()
	if not page then
		return
	end

	if section.collapsed then
		self:SetSectionCollapsed(page.id, section.data.id, false)
	end

	local scrollBox = self.Page.ScrollBox
	local index = scrollBox:FindElementDataIndexByPredicate(function(entry)
		return entry.kind == section.kind and entry.data.id == section.data.id
	end)
	if not index then
		return
	end

	self:SmoothScrollTo(index, function()
		local entry = scrollBox:FindElementData(index)
		local kind = entry and AS.elementKinds[entry.kind]
		local frame = entry and scrollBox:FindFrame(entry)
		if frame and kind.Flash then
			AS:CallHost(nil, kind.Flash, frame)
		end
	end)
end

---Stops a running smooth scroll and drops its pending follow-up.
function AeonUISettings_WindowMixin:CancelSmoothScroll()
	local scrollBox = self.Page.ScrollBox
	self.scrollGeneration = self.scrollGeneration + 1
	scrollBox:GetScrollInterpolator():Cancel()
	scrollBox:SetInterpolateScroll(false)
	self.Page.ScrollBar:SetInterpolateScroll(false)
end

---Scrolls smoothly until the entry at `index` is `gap` below the list's top, then calls `onArrive` after the
---flash delay, unless another smooth scroll, a page change or a search has happened since.
---@param index integer
---@param onArrive fun()
---@param gap number? distance from the list's top; 0 when nil
function AeonUISettings_WindowMixin:SmoothScrollTo(index, onArrive, gap)
	local scrollBox = self.Page.ScrollBox
	local scrollBar = self.Page.ScrollBar
	self.scrollGeneration = self.scrollGeneration + 1
	local generation = self.scrollGeneration
	local pageID = self.memory.page

	scrollBox:SetInterpolateScroll(true)
	scrollBar:SetInterpolateScroll(true)
	scrollBox:ScrollToElementDataIndex(index, ScrollBoxConstants.AlignBegin, gap)

	C_Timer.After(JUMP_FLASH_DELAY, function()
		if generation ~= self.scrollGeneration then
			return
		end

		scrollBox:SetInterpolateScroll(false)
		scrollBar:SetInterpolateScroll(false)
		if self:IsShown() and not self.searching and self.memory.page == pageID then
			onArrive()
		end
	end)
end

---Finds a setting from the preview: shows its tab, opens its collapsed group, scrolls its section header to just
---below the list's top, then flashes its row, or its half of a split row, if the row is on screen.
---@param settingID string
function AeonUISettings_WindowMixin:FindSetting(settingID)
	local page = self:CurrentPage()
	if not page or self.searching then
		return
	end

	local index = self.model:Locate(page.id, settingID)
	if not index then
		return
	end

	local tab = self.model:TabOf(page.id, index)
	local revealed = self.model:Reveal(page.id, index)
	if tab and tab ~= self.listTabID then
		self:SaveScroll()
		self.model:SetTab(page.id, tab)
		self:ShowPage(page)
	elseif revealed then
		self:RefreshPage()
	end

	local _, shownIndex, anchor = self.model:Locate(page.id, settingID)
	local target = shownIndex and self.shownElements and self.shownElements[shownIndex]
	if not target then
		return
	end

	local scrollBox = self.Page.ScrollBox
	self:SmoothScrollTo(anchor, function()
		local frame = scrollBox:FindFrame(target)
		local kind = AS.elementKinds[target.kind]
		if frame and kind and kind.Flash then
			AS:CallHost(nil, kind.Flash, frame, settingID)
		end
	end, FIND_TOP_GAP)
end

-- Search ----------------------------------------------------------------------------------------------------

function AeonUISettings_WindowMixin:OnSearchTextChanged()
	local text = strtrim(self.SearchBox:GetText())
	if text == "" then
		if self.searching then
			self:EndSearch(true)
		end

		return
	end

	self:RunSearch(text)
end

---Replaces the page list with matching elements from every page, grouped under page dividers.
---@param text string
function AeonUISettings_WindowMixin:RunSearch(text)
	if not self.searching then
		self:SaveScroll()
		self.searching = true
	end

	local groups, counts = self.model:Search(text)
	local elements = {}
	for _, group in ipairs(groups) do
		local page = group.page
		elements[#elements + 1] = {
			kind = "searchDivider",
			data = { title = page.title, pageID = page.id, firstHit = group.hits[1].index },
		}
		for position, hit in ipairs(group.hits) do
			elements[#elements + 1] = { kind = hit.data.kind, data = hit.data, pageID = page.id, position = position }
		end
	end

	self:ShowList(elements, {}, nil, L['Search results for "%s"']:format(text), L["No settings match."])
	self.Categories:SetCounts(counts)
end

---Leaves search mode; `restore` shows the page that was shown before the search.
---@param restore boolean
function AeonUISettings_WindowMixin:EndSearch(restore)
	self.searching = false
	self.Categories:SetCounts(nil)
	if restore then
		self:ShowPage(self:CurrentPage())
	end
end

---Clears the search box without restoring the previous page. Search mode ends before the text is cleared, so
---the text-changed handler that `SetText` runs finds nothing to end.
function AeonUISettings_WindowMixin:ClearSearch()
	if self.searching then
		self:EndSearch(false)
	end
	self.SearchBox:SetText("")
	self.SearchBox:ClearFocus()
end

---Opens a page from a search result divider and scrolls to its first hit.
---@param pageID string
---@param hitIndex number
function AeonUISettings_WindowMixin:OpenSearchHit(pageID, hitIndex)
	self:ClearSearch()
	self.Categories:Reveal(pageID)
	self:SelectPage(pageID, hitIndex)
end

-- Scripts ---------------------------------------------------------------------------------------------------

function AeonUISettings_WindowMixin:OnShow()
	self:ShowPage(self:CurrentPage())
end

function AeonUISettings_WindowMixin:OnHide()
	self:StopMovingOrSizing()
	self:SetUserPlaced(false)
	StaticPopup_Hide(RESET_POPUP)
	if self.searching then
		self:ClearSearch()
	else
		self:SaveScroll()
	end

	local status = self.StatusFrame
	status.fade:Stop()
	status:Hide()

	if AS.ProfileDialog then
		AS.ProfileDialog:Close()
	end
	self:StopPreview(self.notedPageID and self.pages[self.notedPageID])
	self.notedPageID = nil
	if self.options.onClose then
		AS:CallHost(nil, self.options.onClose)
	end
end

function AeonUISettings_WindowMixin:OnEvent(event)
	if event == "PLAYER_REGEN_DISABLED" and self:IsShown() then
		self:Hide()
	end
end

function AeonUISettings_WindowMixin:OnDragStart()
	self:StartMoving()
end

function AeonUISettings_WindowMixin:OnDragStop()
	self:StopMovingOrSizing()
	-- Keeps the client's layout cache from restoring the position after a reload.
	self:SetUserPlaced(false)
end
