local AUI = select(2, ...)

local L = AUI.L

local Options = AUI.TravelersLogOptions

local DROPDOWN_WIDTH = 150
local DROPDOWN_GAP = 16
local CONTROL_LEVEL = 560 -- above the log's header and help button
local SEARCH_HEIGHT = 20
local SEARCH_GAP = 8
local MONTH_GAP = 16
local SEARCH_ADDON = "TravelersLogSearcher" -- replaces the list's build method with its own search

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

---The Traveler's Log's list: one pass after each time Blizzard builds it, which prunes and sorts its tree, the dropdown
---that chooses how, and the search box. Sorting leaves the tree's cached row order in place, so the pass ends by
---invalidating it.
---@class AUITravelersLogList
---@field hooked boolean the list's build is hooked
---@field dropdown DropdownButton
---@field searchBox EditBox? absent while another addon searches the list
---@field query string the search, empty for none; it lasts until the log closes
---@field message FontString shown when nothing in the list is left to show
local List = {
	hooked = false,
	query = "",
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

---Removes activities below `node` that are hidden or that the search leaves out, deepest first. A node keeps its place
---while a descendant survives, a match keeps the activities nested under it, and one still playing its completion
---animation stays until the next build. A node left with no children stops offering to expand.
---@param frame table the log's frame
---@param node table a tree node
---@param hide table
---@param now number
---@param query string
---@param parentMatched boolean an ancestor matches the search
---@return number removed
local function Prune(frame, node, hide, now, query, parentMatched)
	local children = node:GetNodes()
	local removed = 0

	for index = #children, 1, -1 do
		local child = children[index]
		local activity = child:GetData()
		local matched = parentMatched or Options:Matches(activity, query)

		removed = removed + Prune(frame, child, hide, now, query, matched)

		if #child:GetNodes() == 0 then
			activity.hasChild = false

			if (not matched or Options:IsHidden(activity, now, hide))
				and not frame:NeedsToAnimatePendingComplete(activity.ID) then
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
	local removed = Prune(frame, provider:GetRootNode(), HideChoices(), now, self.query, false)
	local comparator = Options:Comparator(AUI.Profile:Get(Options.SORT_PATH), now, function(activityID)
		return frame:IsActivityPendingComplete(activityID)
	end)

	if comparator then
		provider:SetSortComparator(comparator)
	end

	if comparator or removed > 0 then
		provider:Invalidate()
	end

	self.message:SetText(self.query ~= "" and QUEST_LOG_NO_RESULTS or L["Everything here is hidden."])
	self.message:SetShown(removed > 0 and provider:IsEmpty())
end

---Rebuilds the list the way Blizzard's category buttons do, while it is on screen. Otherwise the next time it opens
---builds it.
---@param retainScroll boolean
function List:Rebuild(retainScroll)
	local frame = LogFrame()

	if frame and frame:IsVisible() and frame.ScrollBox:GetDataProvider() then
		frame:SetActivities(C_PerksActivities.GetPerksActivitiesInfo().activities, retainScroll)
	end
end

---@param text string the search box's
function List:OnSearchChanged(text)
	local query = Options:NormalizeQuery(text)

	if query == self.query then
		return
	end

	self.query = query
	AUI.Events:Coalesce("travelersLogSearch", function()
		List:Rebuild(ScrollBoxConstants.DiscardScrollPosition)
	end)
end

---Empties the search without rebuilding the list.
function List:ClearSearch()
	AUI.Events:Cancel("travelersLogSearch")
	self.query = ""

	if self.searchBox then
		self.searchBox:SetText("")
	end
end

---After Blizzard looks for an activity to scroll to, as the objective tracker's links do: when the search left it out,
---the search goes and the scroll runs again.
---@param frame table the log's frame
---@param activityID number
function List:OnScrolledTo(frame, activityID)
	if self.query == "" then
		return
	end

	local found = frame.ScrollBox:GetDataProvider():FindElementDataByPredicate(function(node)
		return node:GetData().ID == activityID
	end, TreeDataProviderConstants.IncludeCollapsed)

	if not found then
		self:ClearSearch()
		self:Rebuild(ScrollBoxConstants.RetainScrollPosition)
		frame:ScrollToPerksActivityID(activityID)
	end
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

---Makes the search box between the month's name and the dropdown, so a long name narrows it.
---@param frame table the log's frame
function List:BuildSearchBox(frame)
	self.searchBox = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
	self.searchBox:SetHeight(SEARCH_HEIGHT)
	self.searchBox:SetPoint("LEFT", frame.HeaderContainer.Month, "RIGHT", MONTH_GAP, 0)
	self.searchBox:SetPoint("RIGHT", self.dropdown, "LEFT", -SEARCH_GAP, 0)
	self.searchBox:SetFrameLevel(CONTROL_LEVEL)
	self.searchBox:SetAutoFocus(false)
	self.searchBox:HookScript("OnTextChanged", function(box)
		self:OnSearchChanged(box:GetText())
	end)
end

---Hooks the list's build and makes the dropdown, search box and message, once Blizzard's addon has loaded.
function List:Hook()
	local frame = LogFrame()

	if self.hooked or not frame then
		return
	end

	self.hooked = true

	self.dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
	self.dropdown:SetWidth(DROPDOWN_WIDTH)
	self.dropdown:SetPoint("RIGHT", frame.HeaderContainer.TimeLeft, "LEFT", -DROPDOWN_GAP, 0)
	self.dropdown:SetFrameLevel(CONTROL_LEVEL)
	self.dropdown:SetupMenu(BuildMenu)

	self.message = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	self.message:SetPoint("CENTER", frame.ScrollBox, "CENTER", 0, 0)
	self.message:Hide()

	if not C_AddOns.IsAddOnLoaded(SEARCH_ADDON) then
		self:BuildSearchBox(frame)
		frame:HookScript("OnHide", function()
			self:ClearSearch()
		end)
		hooksecurefunc(frame, "ScrollToPerksActivityID", function(owner, activityID)
			self:OnScrolledTo(owner, activityID)
		end)
	end

	hooksecurefunc(frame, "SetActivities", function(owner)
		self:OnActivitiesSet(owner)
	end)
end

---Follows the settings: the controls, and the list rebuilt.
function List:Apply()
	local frame = LogFrame()

	if not frame or not self.hooked then
		return
	end

	local on = AUI.TravelersLog:IsOn()

	self.dropdown:SetShown(on)

	if self.searchBox then
		self.searchBox:SetShown(on)
	end

	if on then
		self.dropdown:OverrideText(SORT_LABELS[AUI.Profile:Get(Options.SORT_PATH)])
	else
		self:ClearSearch()
	end

	self:Rebuild(ScrollBoxConstants.RetainScrollPosition)
end
