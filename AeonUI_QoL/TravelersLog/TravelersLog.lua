local AUI = select(2, ...)

local Options = AUI.TravelersLogOptions

local JOURNAL_ADDON = "Blizzard_EncounterJournal"

---Adds to Blizzard's Traveler's Log (Retail). Blizzard's addon loads on demand and is never loaded from here: the log
---is hooked once that addon has loaded with the feature on. Turning off leaves the hooks in place, doing nothing.
---@class AUITravelersLog
---@field active boolean started
---@field waiting boolean waiting for Blizzard's addon to load
local TravelersLog = {
	active = false,
	waiting = false,
}
AUI.TravelersLog = TravelersLog

---@return boolean
function TravelersLog:IsOn()
	return AUI.can.travelersLog == true and AUI.Profile:Get(Options.ENABLED_PATH) == true
end

function TravelersLog:Apply()
	local Rows = AUI.TravelersLogRows

	if self:IsOn() then
		if C_AddOns.IsAddOnLoaded(JOURNAL_ADDON) then
			Rows:Hook()
		elseif not self.waiting then
			self.waiting = true
			AUI.Events:Register("ADDON_LOADED", self, self.OnAddonLoaded)
		end
	end

	Rows:Refresh()
end

---@param _ string
---@param name string
function TravelersLog:OnAddonLoaded(_, name)
	if name ~= JOURNAL_ADDON then
		return
	end

	self.waiting = false
	AUI.Events:Unregister("ADDON_LOADED", self)
	self:Apply()
end

---@param path string? the changed setting; nil when the whole profile changed
function TravelersLog:OnProfileChanged(path)
	if path == nil or path:sub(1, 13) == "travelersLog." then
		AUI.Events:Coalesce("travelersLogApply", function()
			TravelersLog:Apply()
		end)
	end
end

function TravelersLog:Start()
	if self.active then
		return
	end

	self.active = true
	AUI.Callbacks:Register("Profile", self, self.OnProfileChanged)
	self:Apply()
end
