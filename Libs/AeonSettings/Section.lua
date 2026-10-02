-- Section header: a section's title with its bar and divider and, on a collapsible group, a plus/minus.
local _, ns = ...
local AS = ns.AeonSettings
local tokens = AS.tokens

local TITLE_TO_RIGHT = 12
local ACTION_HEIGHT = 24
local ACTION_TO_TOGGLE = 10

---A section header element: `{ kind = "section", id, title, collapsible?, action?, menu? }`, where `action` is an
---action setting (`verb`, `confirm?`, `set`, `depends?`, `blocked?`) shown as a button in the header, and `menu` a
---dropdown setting shown left of it.
AeonUISettings_SectionHeaderMixin = {}

function AeonUISettings_SectionHeaderMixin:OnLoad()
	AS:SetFont(self.Title, "header")
	self.Title:SetTextColor(unpack(tokens.color.sectionTitle))

	-- The section gap above the header takes no clicks.
	self:SetHitRectInsets(0, 0, tokens.space.sectionGap, 0)

	self.titleCenter, self.toggleLift = AS:HeaderLayout()
	local inset = tokens.space.rowInset
	-- Regions declared without anchors fill their parent; clear that before placing them.
	self.Title:ClearAllPoints()
	self.Title:SetPoint("LEFT", self, "TOPLEFT", inset, -self.titleCenter)
	self.bar = AS:CreateHeaderBar(self, self.Title)
	self.divider = AS:CreateHeaderDivider(self)
	self.Toggle:ClearAllPoints()
	self.Toggle:SetPoint("RIGHT", self, "TOPRIGHT", -inset, -self.titleCenter + self.toggleLift)

	local action = CreateFrame("Frame", nil, self, "AeonUISettings_ActionButtonTemplate")
	action:SetFrameLevel(self:GetFrameLevel() + 2)
	action:Hide()
	self.action = action
	self.actionSlot = AS:CreateSettingSlot()
	self.menuSlot = AS:CreateSettingSlot()

	self.outline = AS:CreateOutline(self, tokens.color.flash)
	self.outline:SetPoint("TOPLEFT", 0, -tokens.space.sectionGap)
	self.outline:SetPoint("BOTTOMRIGHT")
end

---@param entry AeonSettingsEntry
---@param window table
function AeonUISettings_SectionHeaderMixin:Init(entry, window)
	local data = entry.data
	self.window = window
	self.entry = entry

	self.Title:SetText(data.title)

	local collapsible = data.collapsible == true
	self:EnableMouse(collapsible)
	self.Toggle:SetShown(collapsible)
	if collapsible then
		self.Toggle:SetAtlas(entry.collapsed and "common-button-list-plus" or "common-button-list-minus",
			TextureKitConstants.UseAtlasSize)
	end

	-- Right-side controls, right to left: plus/minus, action, menu. The action and menu sit on the title's center
	-- line; the plus/minus is lifted above it.
	local right = collapsible and self.Toggle or nil

	local function Place(frame)
		frame:ClearAllPoints()
		if right then
			frame:SetPoint("RIGHT", right, "LEFT", -ACTION_TO_TOGGLE, right == self.Toggle and -self.toggleLift or 0)
		else
			frame:SetPoint("RIGHT", self, "TOPRIGHT", -tokens.space.rowInset, -self.titleCenter)
		end
		right = frame
	end

	local action = self.action
	action:SetShown(data.action ~= nil)
	if data.action then
		Place(action)
		self.actionSlot:Bind(data.action, entry.pageID, window, action)
		action:SetButtonHeight(ACTION_HEIGHT)
	end

	if data.menu then
		local menu = self:Menu()
		menu:Show()
		Place(menu)
		self.menuSlot:Bind(data.menu, entry.pageID, window, menu)
	elseif self.menu then
		self.menu:Hide()
	end

	if right then
		self.Title:SetPoint("RIGHT", right, "LEFT", -TITLE_TO_RIGHT, right == self.Toggle and -self.toggleLift or 0)
	else
		self.Title:SetPoint("RIGHT", self, "TOPRIGHT", -tokens.space.rowInset, -self.titleCenter)
	end
end

---Returns the header's dropdown, creating it on first use.
---@return Frame
function AeonUISettings_SectionHeaderMixin:Menu()
	if not self.menu then
		self.menu = CreateFrame("Frame", nil, self, "AeonUISettings_DropdownTemplate")
		self.menu:SetFrameLevel(self:GetFrameLevel() + 2)
	end

	return self.menu
end

---Re-applies the header action's active state and reason.
function AeonUISettings_SectionHeaderMixin:RefreshState()
	self.actionSlot:RefreshState()
	self.menuSlot:RefreshState()
end

function AeonUISettings_SectionHeaderMixin:OnClick()
	local entry = self.entry
	if entry and entry.data.collapsible then
		self.window:SetSectionCollapsed(entry.pageID, entry.data.id, not entry.collapsed)
	end
end

function AeonUISettings_SectionHeaderMixin:Release()
	AS:HideOutline(self.outline)
	self.actionSlot:Release()
	self.action:Hide()
	self.menuSlot:Release()
	if self.menu then
		self.menu:Hide()
	end
	self.entry = nil
end

AS:RegisterElementKind("section", {
	template = "AeonUISettings_SectionHeaderTemplate",
	section = true,
	Init = function(frame, entry, window)
		frame:Init(entry, window)
	end,
	Reset = function(frame)
		frame:Release()
	end,
	Refresh = function(frame)
		frame:RefreshState()
	end,
	-- A header shows no findable setting, so it always flashes whole.
	Flash = function(frame)
		AS:FlashOutline(frame.outline)
	end,
})
