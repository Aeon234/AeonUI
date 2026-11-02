local AUI = select(2, ...)

local Options = AUI.NotificationOptions

---Entering Combat and Leaving Combat. Leaving waits a moment: entering combat again within it shows neither, so a
---brief drop out of combat stays quiet.
---@class AUICombatNotices
---@field following boolean the combat events are registered
---@field leaving table? the timer that shows Leaving Combat
local CombatNotices = {
	following = false,
}
AUI.CombatNotices = CombatNotices

function CombatNotices:OnEnter()
	if self.leaving then
		self.leaving:Cancel()
		self.leaving = nil

		return
	end

	if Options:On("enter") then
		AUI.Notifications:Show("enter")
	end
end

function CombatNotices:OnLeave()
	if self.leaving then
		self.leaving:Cancel()
	end

	self.leaving = C_Timer.NewTimer(Options.COMBAT_GRACE, function()
		self.leaving = nil

		if Options:On("leave") then
			AUI.Notifications:Show("leave")
		end
	end)
end

function CombatNotices:Apply()
	local wanted = Options:On("enter") or Options:On("leave")

	if not Options:On("enter") then
		AUI.Notifications:Dismiss("enter")
	end

	if not Options:On("leave") then
		AUI.Notifications:Dismiss("leave")
	end

	if wanted == self.following then
		return
	end

	self.following = wanted

	if wanted then
		AUI.Events:Register("PLAYER_REGEN_DISABLED", self, self.OnEnter)
		AUI.Events:Register("PLAYER_REGEN_ENABLED", self, self.OnLeave)
	else
		AUI.Events:UnregisterAll(self)

		if self.leaving then
			self.leaving:Cancel()
			self.leaving = nil
		end
	end
end
