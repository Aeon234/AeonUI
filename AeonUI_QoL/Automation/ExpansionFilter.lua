local AUI = select(2, ...)

local L = AUI.L

local Options = AUI.AutomationOptions

local AUCTION_HOUSE_ADDON = "Blizzard_AuctionHouseUI"
local CRAFTING_ORDERS_ADDON = "Blizzard_ProfessionsCustomerOrders"

---Turns on Blizzard's Current Expansion Only filter each time the Auction House or the crafting orders browse page opens
---with it off, where `AUI.can.expansionFilter` holds. An Auction House text search that finds nothing runs again across
---every expansion. The windows are hooked once, when each Blizzard addon loads, and the hooks do nothing while the
---setting is off.
---@class AUIExpansionFilter
---@field hooked table<string, true> the Blizzard addons whose windows are hooked
---@field watching boolean waiting for a Blizzard addon to load
---@field listening boolean following Auction House search results
---@field retrying boolean? the next browse search is the all-expansions retry
---@field retried boolean? the current browse search is that retry, so an empty result ends there
local ExpansionFilter = {
	hooked = {},
	watching = false,
	listening = false,
}
AUI.ExpansionFilter = ExpansionFilter

---@return number filter `Enum.AuctionHouseFilter.CurrentExpansionOnly`
local function CurrentExpansionOnly()
	return Enum.AuctionHouseFilter.CurrentExpansionOnly
end

---Whether the client offers a filter in its filter menus. A filter it does not offer is never set, since the player
---could not see or clear it.
---@param groups table[]? `C_AuctionHouse.GetFilterGroups()`
---@param filter number
---@return boolean offered
function ExpansionFilter.Offered(groups, filter)
	for _, group in ipairs(groups or {}) do
		for _, candidate in ipairs(group.filters or {}) do
			if candidate == filter then
				return true
			end
		end
	end

	return false
end

---@return boolean
local function IsOffered()
	return ExpansionFilter.Offered(C_AuctionHouse.GetFilterGroups(), CurrentExpansionOnly())
end

---@param path string? one of the window settings; nil for the setting as a whole
---@return boolean
function ExpansionFilter:IsOn(path)
	return Options:Get(Options.EXPANSION_FILTER_PATH) == true and (path == nil or Options:Get(path) == true)
end

---Hooks the windows the first time the setting is on, and follows Auction House searches while it is.
function ExpansionFilter:Apply()
	if not AUI.can.expansionFilter then
		return
	end

	local on = self:IsOn()

	if on then
		self:Hook(AUCTION_HOUSE_ADDON)
		self:Hook(CRAFTING_ORDERS_ADDON)

		if not self.watching and not (self.hooked[AUCTION_HOUSE_ADDON] and self.hooked[CRAFTING_ORDERS_ADDON]) then
			self.watching = true
			AUI.Events:Register("ADDON_LOADED", self, self.OnAddOnLoaded)
		end
	end

	if on ~= self.listening then
		self.listening = on

		if on then
			AUI.Events:Register("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", self, self.OnBrowseResults)
		else
			AUI.Events:Unregister("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", self)
		end
	end
end

---@param _ string
---@param name string
function ExpansionFilter:OnAddOnLoaded(_, name)
	self:Hook(name)

	if self.hooked[AUCTION_HOUSE_ADDON] and self.hooked[CRAFTING_ORDERS_ADDON] then
		self.watching = false
		AUI.Events:Unregister("ADDON_LOADED", self)
	end
end

---Hooks the window of a loaded Blizzard addon, once.
---@param name string
function ExpansionFilter:Hook(name)
	if self.hooked[name] or not C_AddOns.IsAddOnLoaded(name) then
		return
	end

	if name == AUCTION_HOUSE_ADDON and AuctionHouseFrame then
		AuctionHouseFrame:HookScript("OnShow", function()
			self:OnAuctionHouseShown()
		end)

		if AuctionHouseFrame.RegisterCallback and AuctionHouseFrameMixin and AuctionHouseFrameMixin.Event then
			AuctionHouseFrame:RegisterCallback(AuctionHouseFrameMixin.Event.BrowseSearchStarted, function()
				self:OnBrowseSearchStarted()
			end, self)
		end

		self.hooked[name] = true
	elseif name == CRAFTING_ORDERS_ADDON and ProfessionsCustomerOrdersFrame then
		ProfessionsCustomerOrdersFrame:HookScript("OnShow", function()
			self:OnCraftingOrdersShown()
		end)
		self.hooked[name] = true
	end
end

---The Auction House keeps its filters per character; this turns the filter on through the filter button's own toggle.
function ExpansionFilter:OnAuctionHouseShown()
	if not self:IsOn(Options.EXPANSION_AUCTION_HOUSE_PATH) then
		return
	end

	local searchBar = AuctionHouseFrame.SearchBar
	local button = searchBar and searchBar.FilterButton
	local filter = CurrentExpansionOnly()

	if not (button and button.GetFilters and button.ToggleFilter) then
		return
	end

	local filters = button:GetFilters()

	if filters and not filters[filter] and IsOffered() then
		button:ToggleFilter(filter)
	end
end

---Marks whether the search that just started is the all-expansions retry, or a search of the player's own.
function ExpansionFilter:OnBrowseSearchStarted()
	self.retried = self.retrying == true
	self.retrying = false
end

---@return boolean retry a finished, empty text search with Current Expansion Only on runs again across every
---expansion: once per search of the player's, never for the retry itself
function ExpansionFilter:ShouldRetry()
	if not self:IsOn(Options.EXPANSION_AUCTION_HOUSE_PATH) or self.retried then
		return false
	end

	local searchBar = AuctionHouseFrame and AuctionHouseFrame.SearchBar
	local button = searchBar and searchBar.FilterButton
	local box = searchBar and searchBar.SearchBox
	local filters = button and button.GetFilters and button:GetFilters()
	local text = box and box.GetSearchString and box:GetSearchString()

	return filters ~= nil and filters[CurrentExpansionOnly()] == true
		and type(text) == "string" and text ~= ""
		and C_AuctionHouse.HasFullBrowseResults() and #C_AuctionHouse.GetBrowseResults() == 0
end

---Runs the search again with Current Expansion Only off, then turns the filter back on: the search bar reads the
---filters when the search starts, so the next search of the player's is current-expansion again.
function ExpansionFilter:OnBrowseResults()
	if not self:ShouldRetry() then
		return
	end

	local searchBar = AuctionHouseFrame.SearchBar
	local filter = CurrentExpansionOnly()

	self.retrying = true
	searchBar.FilterButton:ToggleFilter(filter)
	searchBar:StartSearch()
	searchBar.FilterButton:ToggleFilter(filter)
	AUI:Print(L["Nothing in the current expansion, so all expansions were searched."])
end

---The browse page resets its filters each time the window opens, before this runs.
function ExpansionFilter:OnCraftingOrdersShown()
	if not self:IsOn(Options.EXPANSION_CRAFTING_ORDERS_PATH) then
		return
	end

	local browse = ProfessionsCustomerOrdersFrame.BrowseOrders
	local dropdown = browse and browse.SearchBar and browse.SearchBar.FilterDropdown --[[@as table?]]
	local filters = dropdown and dropdown.filters
	local filter = CurrentExpansionOnly()

	if filters and not filters[filter] and IsOffered() then
		-- Blizzard's own setter run securely writes the entry without tainting the dropdown's table.
		if securecallfunction and TextureLoadingGroupMixin and TextureLoadingGroupMixin.AddTexture then
			securecallfunction(TextureLoadingGroupMixin.AddTexture, { textures = filters }, filter)
		else
			filters[filter] = true
		end

		if dropdown.ValidateResetState then
			dropdown:ValidateResetState()
		end
	end
end
