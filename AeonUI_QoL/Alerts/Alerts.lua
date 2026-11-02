local AUI = select(2, ...)

---The Alerts module: Sound Alerts and Joined Group in Chat. Changes take effect at once, and a profile change applies the new profile's choices.
---@class AUIAlerts
---@field active boolean started this session
local Alerts = {
	active = false,
}
AUI.Alerts = Alerts

---@param path string? the changed setting; nil when the whole profile changed
function Alerts:OnProfileChanged(path)
	if path == nil or path:sub(1, 7) == "alerts." then
		AUI.SoundAlerts:Apply()
		AUI.PremadeJoined:Apply()
	end
end

function Alerts:Start()
	if self.active then
		return
	end

	self.active = true
	AUI.Callbacks:Register("Profile", self, self.OnProfileChanged)
	AUI.SoundAlerts:Apply()
	AUI.PremadeJoined:Apply()
end
