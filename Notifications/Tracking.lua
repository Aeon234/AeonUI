local AUI = select(2, ...)

local Options = AUI.NotificationOptions

local EVENTS = {
	"PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "MINIMAP_UPDATE_TRACKING", "SPELLS_CHANGED",
	"UPDATE_SHAPESHIFT_FORM", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "PLAYER_DEAD", "PLAYER_ALIVE",
	"PLAYER_UNGHOST",
}

---Tracking: one line naming the trackings in the minimap's list that are off and that it reminds about, outside
---instances while the player is alive and not on a taxi.
---@class AUITrackingNotice
---@field following boolean the events are registered
local TrackingNotice = {
	following = false,
}
AUI.TrackingNotice = TrackingNotice

---@return table<number, boolean> tracked each tracking spell in the minimap's list, and whether it is on
local function Tracked()
	local tracked = {}

	for index = 1, C_Minimap.GetNumTrackingTypes() do
		local info = C_Minimap.GetTrackingInfo(index)

		if info and info.spellID then
			tracked[info.spellID] = info.active == true
		end
	end

	return tracked
end

---@param key string a tracking
---@return boolean
local function Remind(key)
	return AUI.Profile:Get(Options.TRACKING_PATH .. "." .. key) == true
end

---@return boolean apply the reminder applies here and now
local function Applies()
	local inInstance, instanceType = IsInInstance()

	return not Options:CountsAsInstance(inInstance, instanceType) and not UnitIsDeadOrGhost("player")
		and not UnitOnTaxi("player")
end

function TrackingNotice:Check()
	local labels = self.following and Applies() and Options:MissingTrackings(Tracked(), GetShapeshiftFormID(), Remind)

	if labels and #labels > 0 then
		AUI.Notifications:Show("tracking", Options:TrackingText(labels))
	else
		AUI.Notifications:Dismiss("tracking")
	end
end

function TrackingNotice:OnEvent()
	AUI.Events:Coalesce("trackingNotice", function()
		TrackingNotice:Check()
	end)
end

function TrackingNotice:Apply()
	local wanted = AUI.can.trackingNotice == true and Options:On("tracking")

	if wanted ~= self.following then
		self.following = wanted

		if wanted then
			for _, event in ipairs(EVENTS) do
				AUI.Events:Register(event, self, self.OnEvent)
			end
		else
			AUI.Events:UnregisterAll(self)
			AUI.Events:Cancel("trackingNotice")
		end
	end

	self:Check()
end
