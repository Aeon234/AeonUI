-- Category column: collapsible category headers, each followed by its pages.
local _, ns = ...
local AS = ns.AeonSettings
local tokens = AS.tokens

local HEADER_HEIGHT = 26
local PAGE_HEIGHT = 20
local HEADER_TEXT_X = 8
local PAGE_TEXT_X = 28
local PAGE_TEXT_RIGHT = 4
local PAGE_TEXT_Y = 1
local SCROLLBAR_INSET = 10
local SCROLLBAR_GAP = 2
local COUNT_FORMAT = " |cff9d9d9d(%d)|r"

---Text start offset for an entry, leaving room for an icon when the list uses icons.
---@param baseX number
---@param usesIcons boolean
---@return number
local function TextX(baseX, usesIcons)
	if usesIcons then
		return baseX + tokens.size.listIcon + tokens.space.listIconGap
	end

	return baseX
end

---@param icon Texture
---@param path string?
local function SetIcon(icon, path)
	if path then
		icon:SetTexture(path, nil, nil, "TRILINEAR")
		icon:Show()
	else
		icon:Hide()
	end
end

---@param count number?
---@return string
local function CountSuffix(count)
	if count and count > 0 then
		return COUNT_FORMAT:format(count)
	end

	return ""
end

-- Header ---------------------------------------------------------------------------------------------------

AeonUISettings_CategoryHeaderMixin = {}

function AeonUISettings_CategoryHeaderMixin:OnLoad()
	local title = self:GetTitleRegion()
	for i = 1, title:GetNumPoints() do
		local point, _, _, _, y = title:GetPoint(i)
		if point == "LEFT" then
			self.textY = y
		end
	end
	self.textY = self.textY or 0
end

---@param data table category element data
---@param list table the owning category list
function AeonUISettings_CategoryHeaderMixin:Init(data, list)
	local category = data.category
	self.list = list
	self.category = category

	local x = TextX(HEADER_TEXT_X, list.usesIcons)
	local title = self:GetTitleRegion()
	title:SetPoint("LEFT", self, "LEFT", x, self.textY)
	self:SetHeaderText(category.title .. CountSuffix(list.counts and list.counts.categories[category.id]))

	self.Icon:ClearAllPoints()
	self.Icon:SetPoint("LEFT", self, "LEFT", x - tokens.size.listIcon - tokens.space.listIconGap, 0)
	SetIcon(self.Icon, category.icon)

	self:GetCollapseButton():UpdateCollapsedState(list:IsCollapsed(category.id))
	self:UpdateColors(self:IsMouseOver())
end

---@param hovered boolean
function AeonUISettings_CategoryHeaderMixin:UpdateColors(hovered)
	self:CheckHighlightTitle(hovered)
	self.Icon:SetVertexColor(self:GetTitleRegion():GetTextColor())
end

function AeonUISettings_CategoryHeaderMixin:OnClick()
	self.list:ToggleCollapsed(self.category.id)
end

function AeonUISettings_CategoryHeaderMixin:OnEnter()
	self:UpdateColors(true)
	self:GetCollapseButton():LockHighlight()
end

function AeonUISettings_CategoryHeaderMixin:OnLeave()
	self:UpdateColors(false)
	self:GetCollapseButton():UnlockHighlight()
end

-- Page -----------------------------------------------------------------------------------------------------

AeonUISettings_CategoryPageMixin = {}

---@param data table page element data
---@param list table the owning category list
function AeonUISettings_CategoryPageMixin:Init(data, list)
	local page = data.page
	self.list = list
	self.page = page

	local x = TextX(PAGE_TEXT_X, list.usesIcons)
	self.Label:ClearAllPoints()
	self.Label:SetPoint("LEFT", self, "LEFT", x, PAGE_TEXT_Y)
	self.Label:SetPoint("RIGHT", self, "RIGHT", -PAGE_TEXT_RIGHT, PAGE_TEXT_Y)
	self.Label:SetText(page.title .. CountSuffix(list.counts and list.counts.pages[page.id]))

	self.Icon:ClearAllPoints()
	self.Icon:SetPoint("LEFT", self, "LEFT", x - tokens.size.listIcon - tokens.space.listIconGap, 0)
	SetIcon(self.Icon, page.icon)

	self:UpdateState(self:IsMouseOver())
end

---@param hovered boolean?
function AeonUISettings_CategoryPageMixin:UpdateState(hovered)
	if hovered == nil then
		hovered = self.hovered
	end
	self.hovered = hovered
	local selected = self.list.selected == self.page.id

	if selected then
		self.Background:SetAtlas("Options_List_Active", TextureKitConstants.UseAtlasSize)
		self.Background:Show()
	elseif hovered then
		self.Background:SetAtlas("Options_List_Hover", TextureKitConstants.UseAtlasSize)
		self.Background:Show()
	else
		self.Background:Hide()
	end

	self.Label:SetFontObject((selected or hovered) and GameFontHighlight or GameFontNormal)
	self.Icon:SetVertexColor(self.Label:GetTextColor())
end

function AeonUISettings_CategoryPageMixin:OnClick()
	self.list:ReportClick(self.page.id)
end

function AeonUISettings_CategoryPageMixin:OnEnter()
	self:UpdateState(true)
end

function AeonUISettings_CategoryPageMixin:OnLeave()
	self:UpdateState(false)
end

-- List -----------------------------------------------------------------------------------------------------

---@class AeonSettingsCategoryList : Frame
---@field categories table[] categories, each `{ id, title, icon?, pages = { { id, title, icon? } } }`
---@field selected string? id of the selected page
---@field collapsed table<string, boolean> collapsed category ids
---@field counts { categories: table<string, number>, pages: table<string, number> }? search hit counts
---@field usesIcons boolean
---@field onSelect fun(pageID: string)?
AeonUISettings_CategoryListMixin = {}

function AeonUISettings_CategoryListMixin:OnLoad()
	self.categories = {}
	self.collapsed = {}
	self.usesIcons = false

	local view = CreateScrollBoxListLinearView()
	local list = self

	local function InitHeader(frame, data)
		frame:Init(data, list)
	end

	local function InitPage(frame, data)
		frame:Init(data, list)
	end

	view:SetElementFactory(function(factory, data)
		if data.page then
			factory("AeonUISettings_CategoryPageTemplate", InitPage)
		else
			factory("AeonUISettings_CategoryHeaderTemplate", InitHeader)
		end
	end)
	view:SetElementExtentCalculator(function(_, data)
		return data.page and PAGE_HEIGHT or HEADER_HEIGHT
	end)

	ScrollUtil.InitScrollBoxListWithScrollBar(self.ScrollBox, self.ScrollBar, view)

	local withBar = {
		CreateAnchor("TOPLEFT", self, "TOPLEFT"),
		CreateAnchor("BOTTOMRIGHT", self, "BOTTOMRIGHT", -SCROLLBAR_INSET, 0),
	}
	local withoutBar = {
		withBar[1],
		CreateAnchor("BOTTOMRIGHT", self, "BOTTOMRIGHT"),
	}
	self.ScrollBar:SetPoint("TOPLEFT", self.ScrollBox, "TOPRIGHT", SCROLLBAR_GAP, 0)
	self.ScrollBar:SetPoint("BOTTOMLEFT", self.ScrollBox, "BOTTOMRIGHT", SCROLLBAR_GAP, 0)
	ScrollUtil.AddManagedScrollBarVisibilityBehavior(self.ScrollBox, self.ScrollBar, withBar, withoutBar)
end

---Replaces the category data and rebuilds the list.
---@param categories table[]
function AeonUISettings_CategoryListMixin:SetCategories(categories)
	self.categories = categories
	self.usesIcons = false
	for _, category in ipairs(categories) do
		if category.icon then
			self.usesIcons = true
		end
		for _, page in ipairs(category.pages) do
			if page.icon then
				self.usesIcons = true
			end
		end
	end
	self:Rebuild()
end

function AeonUISettings_CategoryListMixin:Rebuild()
	local elements = {}
	for _, category in ipairs(self.categories) do
		elements[#elements + 1] = { category = category }
		if not self.collapsed[category.id] then
			for _, page in ipairs(category.pages) do
				elements[#elements + 1] = { category = category, page = page }
			end
		end
	end
	self.ScrollBox:SetDataProvider(CreateDataProvider(elements), ScrollBoxConstants.RetainScrollPosition)
end

---@param categoryID string
---@return boolean
function AeonUISettings_CategoryListMixin:IsCollapsed(categoryID)
	return self.collapsed[categoryID] == true
end

---@param categoryID string
---@param collapsed boolean
function AeonUISettings_CategoryListMixin:SetCollapsed(categoryID, collapsed)
	if self:IsCollapsed(categoryID) == collapsed then
		return
	end

	self.collapsed[categoryID] = collapsed or nil
	self:Rebuild()
end

---@param categoryID string
function AeonUISettings_CategoryListMixin:ToggleCollapsed(categoryID)
	self:SetCollapsed(categoryID, not self:IsCollapsed(categoryID))
end

---Returns the category id that holds a page.
---@param pageID string
---@return string?
function AeonUISettings_CategoryListMixin:CategoryOf(pageID)
	for _, category in ipairs(self.categories) do
		for _, page in ipairs(category.pages) do
			if page.id == pageID then
				return category.id
			end
		end
	end
end

---Marks a page selected without notifying the owner.
---@param pageID string?
function AeonUISettings_CategoryListMixin:SetSelected(pageID)
	self.selected = pageID
	self.ScrollBox:ForEachFrame(function(frame)
		if frame.UpdateState then
			frame:UpdateState()
		end
	end)
end

---Reports a page the user clicked to the owner, which selects it with `SetSelected`.
---@param pageID string
function AeonUISettings_CategoryListMixin:ReportClick(pageID)
	if self.onSelect then
		self.onSelect(pageID)
	end
end

---Sets search hit counts; nil clears them.
---@param counts { categories: table<string, number>, pages: table<string, number> }?
function AeonUISettings_CategoryListMixin:SetCounts(counts)
	self.counts = counts
	self.ScrollBox:ReinitializeFrames()
end

---Expands a page's category and scrolls the page into view.
---@param pageID string
function AeonUISettings_CategoryListMixin:Reveal(pageID)
	local categoryID = self:CategoryOf(pageID)
	if categoryID then
		self:SetCollapsed(categoryID, false)
	end
	self.ScrollBox:ScrollToElementDataByPredicate(function(data)
		return data.page and data.page.id == pageID
	end, ScrollBoxConstants.AlignNearest)
end
