-- Settings window: chrome, category column, page heading, tabs, preview and list, search, bands and session memory.
local _, ns = ...
local AS = ns.AeonSettings
local L = AS.L
local tokens = AS.tokens

local CATEGORY_X = tokens.size.categoryColumnX
local CATEGORY_WIDTH = tokens.size.categoryColumn
local NATIVE_COLUMN = 192 -- the column width Options_InnerFrame's left slot is drawn for
local CATEGORY_EXTRA = CATEGORY_WIDTH - NATIVE_COLUMN
local PAGE_X = 18 + CATEGORY_WIDTH + tokens.space.columnGap
local TOP = 76
local TOP_BAND = 28
local CLOSE_RIGHT = 16
-- The window's height: TOP, then this room and the caller's rows at `size.windowRow`, then BOTTOM.
local HEADER_HEIGHT = 50
local LIST_GAP = 4
local BOTTOM = 47
local RIGHT = 22
local SCROLLBAR_GAP = 6
local RELOAD_NOTICE_GAP = 10
local DEFAULT_CONTENT_WIDTH = 1065
local DEFAULT_ROWS = 20
-- The page, on the content side of the inner frame: the heading's inset from the content side's left and right
-- edges and below the inner frame's top, the description under the title, and the gap under the description.
local HEADING_X = 14
local HEADING_TOP = 16
local DESCRIPTION_GAP = 8
local HEADING_GAP = 16
local DEFAULTS_GAP = 12 -- the title's room before the Defaults button
local SCROLLBAR_ROOM = 16 -- right of the list, for its scroll bar
local LIST_BOTTOM = 8 -- the list's bottom above the fill's bottom edge
local EMPTY_TOP = 40 -- "No settings match." below the list's top
local TAB_HEIGHT = 30
local TAB_TEMPLATE = "MinimalTabTemplate"
local INTERNAL_TAB_TEMPLATE = "AeonUISettings_InternalTabTemplate"
local INTERNAL_TAB_ATLAS = "common-internaltab" -- present on Forever, whose tabs draw the shipped tab art
-- The shipped tab art: 192x60 in the top-left of a 256x64 file, drawn at half size. Its ends keep their size
-- and its middle stretches, so a tab is as wide as its title needs.
local INTERNAL_TAB_ART_WIDTH, INTERNAL_TAB_ART_HEIGHT = 192, 60
local INTERNAL_TAB_FILE_WIDTH, INTERNAL_TAB_FILE_HEIGHT = 256, 64
local INTERNAL_TAB_CAP = 32 -- art pixels at each end, beveled corners included, that never stretch
local INTERNAL_TAB_MIN_WIDTH = 96
local INTERNAL_TAB_TEXT_PADDING = 32 -- width beyond the title: both ends, drawn 16 wide
local TAB_GAP = 5 -- between tabs, as Blizzard's Settings panel spaces its own
local TAB_TEXT_PADDING = 40 -- MinimalTabTemplate's width beyond its text
local VERSION_COLOR = "|cff9d9d9d"

-- Options_InnerFrame nine-slice insets, in atlas pixels drawn at one UI unit each. The left slot is cut at
-- INNER_SPLIT: left of it stretches by the column's width beyond Blizzard's, the strip holding the divider does not.
local INNER_ATLAS = "Options_InnerFrame"
local INNER_LEFT, INNER_RIGHT, INNER_TOP, INNER_BOTTOM = 204, 8, 8, 8
local INNER_SPLIT = 196
-- The content fill's reach: this far from the inner frame's top, right and bottom edges (its border's visible line
-- is about this deep), and FILL_LEFT left of the content side's edge, under the divider's line.
local FILL_INSET = 3
local FILL_LEFT = 2
local INNER_X, INNER_Y = tokens.space.innerFrameX, tokens.space.innerFrameY
local INNER_BOTTOM_OFFSET = tokens.space.innerBottom

local RESET_POPUP = "AeonUISettings_RESET_PAGE"

-- Element kinds ---------------------------------------------------------------------------------------------

---An element kind's functions run through `AS:CallHost`: an error is reported and leaves the frame as it is.
---@class AeonSettingsElementKind
---@field template string virtual frame template the page list creates for this kind
---@field extent number? the element's height in the page list; `size.row` when nil
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
---@field collapsed boolean? a collapsible section that is collapsed
---@field picked string? a picker's picked option
---@field settings table[]? the settings the element shows, from the build
---@field indent boolean? the row sits one level in, under the setting it depends on

---@type table<string, AeonSettingsElementKind>
AS.elementKinds = AS.elementKinds or {}

---Registers a kind of page-list element, `size.row` tall unless it gives its own `extent`.
---@param kind string
---@param definition AeonSettingsElementKind
function AS:RegisterElementKind(kind, definition)
	self.elementKinds[kind] = definition
end

-- Search divider --------------------------------------------------------------------------------------------

---A search-result page divider, drawn as a section header: the page's name in capitals over the header line. A
---click opens the page at its first hit.
AeonUISettings_SearchDividerMixin = {}

function AeonUISettings_SearchDividerMixin:OnLoad()
	local gap = tokens.space.sectionGap
	local titleCenter = AS:HeaderLayout()
	AS:StyleHeaderTitle(self.Title)
	-- Regions declared without anchors fill their parent; clear that before placing them.
	self.Title:ClearAllPoints()
	self.Title:SetPoint("LEFT", self, "TOPLEFT", 0, -titleCenter)
	self.Title:SetPoint("RIGHT", self, "TOPRIGHT", 0, -titleCenter)
	AS:CreateHeaderLine(self)
	self.MouseoverOverlay:SetPoint("TOPLEFT", 0, -gap)
	self.MouseoverOverlay:SetPoint("BOTTOMRIGHT")
	-- The section gap above the header takes no clicks.
	self:SetHitRectInsets(0, 0, gap, 0)
end

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
	extent = AS:HeaderExtent(),
	Init = function(frame, entry, window)
		frame.window = window
		frame.data = entry.data
		frame.Title:SetText(entry.data.title:upper())
	end,
	Reset = function(frame)
		frame.MouseoverOverlay:Hide()
		frame.window = nil
		frame.data = nil
	end,
})

-- Internal tab -------------------------------------------------------------------------------------------

---A page tab drawn with the shipped tab art (`Media\Tab`): the base, with the selected art over it while selected
---and the hover art in the highlight layer. Each look is a three-slice whose middle stretches with the tab's
---width. It offers what the window uses of `MinimalTabTemplate`, `Text` and `SetSelected`, plus `textPadding`
---and `minWidth`, which the window sizes it by. Its title is white in every state; only the art marks hover and
---selection.
AeonUISettings_InternalTabMixin = {}

---Creates one look of the tab art as a left end, a stretching middle and a right end in `layer`.
---@param layer DrawLayer
---@param file string the file name in `Media\Tab`, without extension
---@return Texture[] slices left, middle, right
function AeonUISettings_InternalTabMixin:CreateArt(layer, file)
	local edges = { 0, INTERNAL_TAB_CAP, INTERNAL_TAB_ART_WIDTH - INTERNAL_TAB_CAP, INTERNAL_TAB_ART_WIDTH }
	local bottom = INTERNAL_TAB_ART_HEIGHT / INTERNAL_TAB_FILE_HEIGHT
	local slices = {}
	for index = 1, 3 do
		local texture = self:CreateTexture(nil, layer)
		texture:SetTexture(AS.MEDIA .. "Tab\\" .. file .. ".png")
		texture:SetTexCoord(edges[index] / INTERNAL_TAB_FILE_WIDTH, edges[index + 1] / INTERNAL_TAB_FILE_WIDTH, 0, bottom)
		slices[index] = texture
	end

	local left, middle, right = slices[1], slices[2], slices[3]
	left:SetPoint("TOPLEFT")
	left:SetPoint("BOTTOMLEFT")
	left:SetWidth(INTERNAL_TAB_CAP / 2)
	right:SetPoint("TOPRIGHT")
	right:SetPoint("BOTTOMRIGHT")
	right:SetWidth(INTERNAL_TAB_CAP / 2)
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
	middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")

	return slices
end

function AeonUISettings_InternalTabMixin:OnLoad()
	AS:SetFont(self.Text, "body", tokens.font.tabSize)
	self.Text:SetTextColor(unpack(tokens.color.text))
	self:CreateArt("BACKGROUND", "Base")
	self.selectedArt = self:CreateArt("OVERLAY", "Selected")
	self:CreateArt("HIGHLIGHT", "Hover")
	self.textPadding = INTERNAL_TAB_TEXT_PADDING
	self.minWidth = INTERNAL_TAB_MIN_WIDTH
	self:SetSelected(false)
end

---@param selected boolean
function AeonUISettings_InternalTabMixin:SetSelected(selected)
	self.selected = selected
	for _, slice in ipairs(self.selectedArt) do
		slice:SetShown(selected)
	end
end

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
---@field memory { page: string?, scroll: table<string, number>, sections: table<string, table<string, boolean>>, tabs: table<string, string>, picks: table<string, table<string, string>>, initial: table<string, any> }
---`memory.page` is the page the window is on, kept through a search; `memory.scroll` holds each page's scroll
---position, per tab, from when it was last left; `memory.tabs` each page's chosen tab.
---@field scrollGeneration integer increments with each find; a stale find's glide and flash are dropped
---@field reloadPending table<string, true>
---@field shownElements AeonSettingsEntry[]? entries in the page list, in order
---@field model AeonSettingsPageModel
---@field sections AeonSettingsEntry[] section entries of the shown page
---@field listPageID string? the page the list shows; nil while it shows search results
---@field listTabID string? the tab the list shows, on a page with tabs
---@field tabButtons Button[] the tab bar's buttons, reused across pages
---@field tabsShown boolean the tab bar shows, under the heading
---@field initializers table<string, fun(frame: Frame, entry: AeonSettingsEntry)> cached frame initializers by kind
---@field pinnedHeight number? the list's top below the page's: what the heading, tabs and preview take
---@field glide Frame drives a find's scroll
---@field searching boolean the list shows search results
AeonUISettings_WindowMixin = {}

function AeonUISettings_WindowMixin:OnLoad()
	self.categories = {}
	self.pages = {}
	self.memory = { scroll = {}, sections = {}, tabs = {}, picks = {}, initial = {} }
	self.scrollGeneration = 0
	self.reloadPending = {}
	self.sections = {}
	self.model = AS.CreatePageModel(self.memory, AS.elementKinds)
	self.searching = false
	self.initializers = {}
	self.tabButtons = {}
	self.tabsShown = false
	self.glide = CreateFrame("Frame", nil, self)

	self:RegisterForDrag("LeftButton")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self.ClosePanelButton:SetScript("OnClick", function()
		self:Hide()
	end)

	self:BuildInnerFrame()
	self:InitPageList()
	self:InitTabBar()
	self:InitBands()
	self:InitHeading()

	self.Categories.onSelect = function(pageID)
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
		self:SelectPage(pageID)
	end

	self.SearchBox:HookScript("OnTextChanged", function()
		self:OnSearchTextChanged()
	end)
end

---Draws Options_InnerFrame as a nine-slice, its left slot cut at the divider: the column's background stretches
---with the column, the divider, the caps and the right edge keep their native size, and the content middle
---stretches. The content fill is drawn even when the client lacks the atlas; the art is not.
function AeonUISettings_WindowMixin:BuildInnerFrame()
	local anchor = CreateFrame("Frame", nil, self)
	anchor:SetPoint("TOPLEFT", INNER_X, -INNER_Y)
	anchor:SetPoint("BOTTOMRIGHT", -INNER_X, INNER_BOTTOM_OFFSET)
	self.InnerFrame = anchor

	local left = INNER_LEFT + CATEGORY_EXTRA
	local split = INNER_SPLIT + CATEGORY_EXTRA

	-- The content side's fill, under the frame's art: up to the border's line, and under the divider's.
	local fill = self:CreateTexture(nil, "OVERLAY", nil, 1)
	fill:SetColorTexture(unpack(tokens.color.contentFill))
	fill:SetPoint("TOPLEFT", anchor, "TOPLEFT", left - FILL_LEFT, -FILL_INSET)
	fill:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -FILL_INSET, FILL_INSET)

	local info = C_Texture.GetAtlasInfo(INNER_ATLAS)
	if not info then
		return
	end

	local file = info.file or info.filename
	local width, height = info.width, info.height
	local uSpan = info.rightTexCoord - info.leftTexCoord
	local vSpan = info.bottomTexCoord - info.topTexCoord

	-- Each column and row: start and end in atlas pixels, and the anchor side and offset for each edge.
	local columns = {
		{ 0, INNER_SPLIT, "LEFT", 0, "LEFT", split },
		{ INNER_SPLIT, INNER_LEFT, "LEFT", split, "LEFT", left },
		{ INNER_LEFT, width - INNER_RIGHT, "LEFT", left, "RIGHT", -INNER_RIGHT },
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
	view:SetElementExtentCalculator(function(_, data)
		local kind = kinds[data.kind]

		return kind and kind.extent or tokens.size.row
	end)
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

---Creates the tab bar under the heading, with the content side's divider line under it.
function AeonUISettings_WindowMixin:InitTabBar()
	local bar = CreateFrame("Frame", nil, self.Page)
	bar:SetHeight(TAB_HEIGHT)
	bar:Hide()
	bar.dividerHeight = AS:CreateContentDivider(bar, HEADING_X, HEADING_X)
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

	-- The page starts at the inner frame's top and right edge; the box keeps its place above the old page.
	self.SearchBox:SetPoint("BOTTOMRIGHT", self.Page, "TOPRIGHT", -1, 8)

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

---Sets up the page heading: the title, the description under it and Defaults at the title line's right end; and
---the preview's divider line.
function AeonUISettings_WindowMixin:InitHeading()
	local page = self.Page
	local heading = page.Heading
	local font = tokens.font

	heading:SetPoint("TOPLEFT", HEADING_X, -HEADING_TOP)
	heading:SetPoint("TOPRIGHT", -HEADING_X, -HEADING_TOP)

	-- Regions declared without anchors fill their parent; clear that before placing them.
	local title = heading.Title
	AS:SetFont(title, "header", font.titleSize)
	title:SetTextColor(unpack(tokens.color.text))
	title:ClearAllPoints()
	title:SetPoint("TOPLEFT")

	local description = heading.Description
	AS:SetFont(description, "header", font.descriptionSize)
	description:SetTextColor(1, 1, 1, tokens.alpha.description)
	description:ClearAllPoints()
	description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -DESCRIPTION_GAP)
	description:SetPoint("RIGHT", heading, "RIGHT")

	local defaults = heading.DefaultsButton
	defaults:SetPoint("RIGHT", heading, "TOPRIGHT", 0, -font.titleSize / 2)
	defaults:SetText(SETTINGS_DEFAULTS)
	AS:FitButtonWidth(defaults)
	defaults:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		local shown = self.pages[self.memory.page]
		if shown then
			StaticPopup_Show(RESET_POPUP, shown.title, nil, { window = self, pageID = shown.id })
		end
	end)

	page.Preview.dividerHeight = AS:CreateContentDivider(page.Preview, HEADING_X, HEADING_X)
end

---Sizes the window from the content width and the number of rows, and places the page on the content side of
---the inner frame. The content width and the rows (at `size.windowRow`) give the window's size, as before the page
---scrolled freely; the list takes what the heading, tabs and preview leave.
function AeonUISettings_WindowMixin:Layout()
	local contentWidth = self.options.contentWidth or DEFAULT_CONTENT_WIDTH
	local rows = self.options.rows or DEFAULT_ROWS
	local pageHeight = HEADER_HEIGHT + LIST_GAP + rows * tokens.size.windowRow

	self:SetSize(PAGE_X + contentWidth + RIGHT, TOP + pageHeight + BOTTOM)

	self.Categories:ClearAllPoints()
	self.Categories:SetPoint("TOPLEFT", CATEGORY_X, -TOP)
	self.Categories:SetSize(CATEGORY_WIDTH, pageHeight)

	local page = self.Page
	page:ClearAllPoints()
	page:SetPoint("TOPLEFT", self.InnerFrame, "TOPLEFT", INNER_LEFT + CATEGORY_EXTRA, 0)
	page:SetPoint("BOTTOMRIGHT", self.InnerFrame, "BOTTOMRIGHT")

	self:LayoutList()
end

---Places the tab bar under the description, the preview under the tabs' line (or the description), and the page
---list under the last of them, down to just above the fill's bottom edge.
function AeonUISettings_WindowMixin:LayoutList()
	local page = self.Page
	local description = page.Heading.Description
	local bar = page.TabBar
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -HEADING_GAP)
	bar:SetPoint("TOPRIGHT", description, "BOTTOMRIGHT", 0, -HEADING_GAP)

	local above, gap = description, HEADING_GAP
	if self.tabsShown then
		above, gap = bar, bar.dividerHeight
	end

	local preview = page.Preview
	preview:ClearAllPoints()
	preview:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -gap)
	preview:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", 0, -gap)
	if preview:IsShown() then
		above, gap = preview, preview.dividerHeight
	end

	local scrollBox = page.ScrollBox
	scrollBox:ClearAllPoints()
	scrollBox:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -gap)
	scrollBox:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -(HEADING_X + SCROLLBAR_ROOM), FILL_INSET + LIST_BOTTOM)

	page.Empty:ClearAllPoints()
	page.Empty:SetPoint("TOP", scrollBox, "TOP", 0, -EMPTY_TOP)

	self.pinnedHeight = (page:GetTop() or 0) - (scrollBox:GetTop() or 0)
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
			local padding = button.textPadding or TAB_TEXT_PADDING
			button:SetWidth(math.max(button.minWidth or 0, math.ceil(button.Text:GetStringWidth()) + padding))
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
	local template = C_Texture.GetAtlasInfo(INTERNAL_TAB_ATLAS) and INTERNAL_TAB_TEMPLATE or TAB_TEMPLATE
	local button = CreateFrame("Button", nil, bar, template)
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

---Shows the page's preview panel, or hides it when the page has none, and fits the list below it.
---@param page table?
function AeonUISettings_WindowMixin:LayoutPreview(page)
	local panel = self.Page.Preview
	if not page or not page.preview or self.searching then
		panel:Hide()
		self:LayoutList()

		return
	end

	-- Placed first, so the panel knows its width when it fits the sample.
	panel:Show()
	self:LayoutList()
	local switch = self.model:PageSwitch(page.id)
	local faded = switch ~= nil and not AS:CallHost(nil, switch.get)
	panel:Setup(self, page, faded)
	self:LayoutList()
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
---Each category is `{ id, title, icon?, pages }`; each page is
---`{ id, title, description?, icon?, Build, Reset?, preview?, tabs? }`, where `description` is the line under the
---page's title, `Build()` returns the page's element list, `Reset()`, when present, restores the page's defaults,
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

---Picks a picker's option on a page, for the session, keeping the rows where they are on screen.
---@param pageID string
---@param pickerID string
---@param optionID string
function AeonUISettings_WindowMixin:SetPick(pageID, pickerID, optionID)
	self.model:SetPick(pageID, pickerID, optionID)
	if pageID == self.listPageID then
		self:RefreshPage()
	end
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
---the heading's title, description and Defaults button, the empty-list message, the listed page, its tabs and its
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

	local heading = self.Page.Heading
	local hasDefaults = page ~= nil and page.Reset ~= nil
	heading.DefaultsButton:SetShown(hasDefaults)
	heading.Description:SetText(page and page.description or "")
	self:SetHeadingTitle(title, hasDefaults)

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
		self.model:Choose(page.id, hitIndex)
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

---Sets the page title, truncated so it stays clear of the Defaults button.
---@param text string
---@param hasDefaults boolean
function AeonUISettings_WindowMixin:SetHeadingTitle(text, hasDefaults)
	local heading = self.Page.Heading
	local title = heading.Title
	local available = heading:GetWidth()
	if hasDefaults then
		available = available - heading.DefaultsButton:GetWidth() - DEFAULTS_GAP
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

-- Find ----------------------------------------------------------------------------------------------------

---Stops a running find: its glide and its pending flash.
function AeonUISettings_WindowMixin:CancelSmoothScroll()
	self.scrollGeneration = self.scrollGeneration + 1
	self.glide:SetScript("OnUpdate", nil)
end

---Finds a setting from the preview: shows its tab and picks its option, opens its collapsed group, then glides the
---list until its row is centered, as EllesmereUI's panel scrolls: each frame covers `motion.find.speed` times the
---frame's seconds of the distance left and stops within `motion.find.snap`. Once the row is within
---`motion.find.flashAt` of its place, its half of the row is outlined, held `motion.find.hold` seconds and faded.
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
	local otherTab = tab ~= nil and tab ~= self.listTabID
	if otherTab then
		self:SaveScroll()
	end
	local revealed = self.model:Reveal(page.id, index)
	local chosen = self.model:Choose(page.id, index)
	if otherTab then
		self:ShowPage(page)
	elseif revealed or chosen then
		self:RefreshPage()
	end

	local _, shownIndex = self.model:Locate(page.id, settingID)
	local target = shownIndex and self.shownElements and self.shownElements[shownIndex]
	if not target then
		return
	end

	-- Where the row centers: scroll there and back at once (nothing draws in between), then glide over.
	local scrollBox = self.Page.ScrollBox
	local noInterpolation = ScrollBoxConstants.NoScrollInterpolation
	self:CancelSmoothScroll()
	local offset = scrollBox:GetDerivedScrollOffset()
	scrollBox:ScrollToElementDataIndex(shownIndex, ScrollBoxConstants.AlignCenter, nil, noInterpolation)
	local goal = scrollBox:GetDerivedScrollOffset()
	scrollBox:ScrollToOffset(offset, noInterpolation)

	local find = tokens.motion.find
	local generation = self.scrollGeneration
	local flashed = false

	local function Flash()
		flashed = true
		local frame = scrollBox:FindFrame(target)
		local kind = AS.elementKinds[target.kind]
		if frame and kind and kind.Flash then
			AS:CallHost(nil, kind.Flash, frame, settingID, find.hold, find.fade)
		end
	end

	self.glide:SetScript("OnUpdate", function(glide, elapsed)
		if generation ~= self.scrollGeneration then
			glide:SetScript("OnUpdate", nil)

			return
		end

		local left = goal - offset
		if math.abs(left) < find.snap then
			glide:SetScript("OnUpdate", nil)
			scrollBox:ScrollToOffset(goal, noInterpolation)
			if not flashed then
				Flash()
			end

			return
		end

		offset = offset + left * math.min(1, find.speed * elapsed)
		scrollBox:ScrollToOffset(offset, noInterpolation)
		if not flashed and math.abs(goal - offset) < find.flashAt then
			Flash()
		end
	end)
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
