local AUI = select(2, ...)

local L = AUI.L

local Options = AUI.TravelersLogOptions

local DROPDOWN_WIDTH = 160
local DROPDOWN_GAP = 16
local DROPDOWN_LEVEL = 560 -- above the log's header and help button

local SORT_LABELS = {
	DEFAULT = DEFAULT,
	POINTS_HIGH = L["Points: High to Low"],
	POINTS_LOW = L["Points: Low to High"],
	CLOSEST = L["Closest to Complete"],
	TIME = L["Time Remaining"],
	NAME = L["Name (A-Z)"],
}

local HIDE_ROWS = {
	{ path = Options.HIDE_COMPLETED_PATH, label = L["Completed"] },
	{ path = Options.HIDE_EXPIRED_PATH, label = L["Expired"] },
	{ path = Options.HIDE_UNAVAILABLE_PATH, label = UNAVAILABLE },
}

---The Traveler's Log's list: one pass after each time Blizzard builds it, which prunes and sorts its tree, and the
---dropdown that chooses both. Sorting leaves the tree's cached row order in place, so the pass ends by invalidating it.
---@class AUITravelersLogList
---@field hooked boolean the list's build is hooked
---@field dropdown DropdownButton
---@field message FontString shown when everything in the list is hidden
local List = {
	hooked = false,
}
AUI.TravelersLogList = List

---@return table? frame the Traveler's Log's frame
local function LogFrame()
	return EncounterJournal and EncounterJournal.MonthlyActivitiesFrame
end

---@return table hide which activities the settings hide
local function HideChoices()
	local Profile = AUI.Profile

	return {
		completed = Profile:Get(Options.HIDE_COMPLETED_PATH) == true,
		expired = Profile:Get(Options.HIDE_EXPIRED_PATH) == true,
		unavailable = Profile:Get(Options.HIDE_UNAVAILABLE_PATH) == true,
	}
end

---Removes hidden activities below `node`, deepest first. A node keeps its place while a descendant survives, and one
---still playing its completion animation stays until the next build. A node left with no children stops offering to
---expand.
---@param frame table the log's frame
---@param node table a tree node
---@param hide table
---@param now number
---@return number removed
local function Prune(frame, node, hide, now)
	local children = node:GetNodes()
	local removed = 0

	for index = #children, 1, -1 do
		local child = children[index]

		removed = removed + Prune(frame, child, hide, now)

		if #child:GetNodes() == 0 then
			local activity = child:GetData()

			activity.hasChild = false

			if Options:IsHidden(activity, now, hide) and not frame:NeedsToAnimatePendingComplete(activity.ID) then
				node:Remove(child, true)
				removed = removed + 1
			end
		end
	end

	return removed
end

---Prunes and sorts the tree Blizzard just gave the scroll box.
---@param frame table the log's frame
function List:OnActivitiesSet(frame)
	self.message:Hide()

	local provider = frame.ScrollBox:GetDataProvider()

	if not AUI.TravelersLog:IsOn() or not provider then
		return
	end

	local now = GetServerTime()
	local removed = Prune(frame, provider:GetRootNode(), HideChoices(), now)
	local comparator = Options:Comparator(AUI.Profile:Get(Options.SORT_PATH), now, function(activityID)
		return frame:IsActivityPendingComplete(activityID)
	end)

	if comparator then
		provider:SetSortComparator(comparator)
	end

	if comparator or removed > 0 then
		provider:Invalidate()
	end

	self.message:SetShown(removed > 0 and provider:IsEmpty())
end

---@param root table the menu's root description
local function BuildMenu(_, root)
	local Profile = AUI.Profile

	root:CreateTitle(RAID_FRAME_SORT_LABEL)

	for _, sort in ipairs(Options.SORTS) do
		root:CreateRadio(SORT_LABELS[sort], function()
			return Profile:Get(Options.SORT_PATH) == sort
		end, function()
			Profile:Set(Options.SORT_PATH, sort)

			return MenuResponse.Refresh
		end)
	end

	root:CreateDivider()
	root:CreateTitle(HIDE)

	for _, row in ipairs(HIDE_ROWS) do
		root:CreateCheckbox(row.label, function()
			return Profile:Get(row.path) == true
		end, function()
			Profile:Set(row.path, Profile:Get(row.path) ~= true)

			return MenuResponse.Refresh
		end)
	end
end

---Hooks the list's build and makes the dropdown and message, once Blizzard's addon has loaded.
function List:Hook()
	local frame = LogFrame()

	if self.hooked or not frame then
		return
	end

	self.hooked = true

	self.dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
	self.dropdown:SetWidth(DROPDOWN_WIDTH)
	self.dropdown:SetPoint("RIGHT", frame.HeaderContainer.TimeLeft, "LEFT", -DROPDOWN_GAP, 0)
	self.dropdown:SetFrameLevel(DROPDOWN_LEVEL)
	self.dropdown:SetupMenu(BuildMenu)

	self.message = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	self.message:SetPoint("CENTER", frame.ScrollBox, "CENTER", 0, 0)
	self.message:SetText(L["Everything here is hidden."])
	self.message:Hide()

	hooksecurefunc(frame, "SetActivities", function(owner)
		self:OnActivitiesSet(owner)
	end)
end

---Follows the settings: the dropdown's look, and the list rebuilt the way Blizzard's category buttons rebuild it, while
---it is on screen. Otherwise the next time it opens builds it.
function List:Apply()
	local frame = LogFrame()

	if not frame or not self.hooked then
		return
	end

	local on = AUI.TravelersLog:IsOn()

	self.dropdown:SetShown(on)

	if on then
		self.dropdown:OverrideText(SORT_LABELS[AUI.Profile:Get(Options.SORT_PATH)])
	end

	if frame:IsVisible() and frame.ScrollBox:GetDataProvider() then
		frame:SetActivities(C_PerksActivities.GetPerksActivitiesInfo().activities, ScrollBoxConstants.RetainScrollPosition)
	end
end
