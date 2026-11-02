local AUI = select(2, ...)

local Options = AUI.InterfaceOptions

-- The events that start Blizzard's boss banner: a kill, and each item looted from it.
local BANNER_EVENTS = { "BOSS_KILL", "ENCOUNTER_LOOT_RECEIVED" }
local VAULT_ADDON = "Blizzard_WeeklyRewards"

---Hides two Blizzard frames. The boss banner, the large "defeated" banner with its loot after a boss kill, is stopped
---by unregistering the two events that start it; turning it off registers again the events it unregistered, and a
---banner already showing finishes. The Great Vault's dark cover and notice, shown while it is opened away from the
---vault with rewards waiting, are hidden by a post-hook on Blizzard's update; turning it off runs that update again.
---@class AUIHideFrames
---@field removed string[] the events this unregistered from the boss banner
---@field hooked boolean the Great Vault's update is hooked
---@field waiting boolean waiting for the Great Vault's addon to load
local HideFrames = {
	removed = {},
	hooked = false,
	waiting = false,
}
AUI.HideFrames = HideFrames

function HideFrames:ApplyBossBanner()
	if not AUI.can.bossBanner then
		return
	end

	if Options:On(Options.BOSS_BANNER_PATH) then
		for _, event in ipairs(BANNER_EVENTS) do
			if BossBanner:IsEventRegistered(event) then
				BossBanner:UnregisterEvent(event)
				self.removed[#self.removed + 1] = event
			end
		end
	else
		for _, event in ipairs(self.removed) do
			BossBanner:RegisterEvent(event)
		end

		self.removed = {}
	end
end

---@param frame table the Great Vault
function HideFrames:ClearVault(frame)
	if not Options:On(Options.VAULT_OVERLAY_PATH) then
		return
	end

	if frame.Blackout then
		frame.Blackout:Hide()
	end

	if frame.Overlay then
		frame.Overlay:Hide()
	end
end

---Hooks the Great Vault's overlay update once its addon has loaded.
function HideFrames:HookVault()
	if self.hooked or not WeeklyRewardsFrame or not WeeklyRewardsFrame.UpdateOverlay then
		return
	end

	self.hooked = true
	hooksecurefunc(WeeklyRewardsFrame, "UpdateOverlay", function(frame)
		self:ClearVault(frame)
	end)
end

function HideFrames:ApplyVault()
	if not AUI.can.vaultOverlay then
		return
	end

	if not Options:On(Options.VAULT_OVERLAY_PATH) then
		if self.hooked and WeeklyRewardsFrame:IsShown() then
			WeeklyRewardsFrame:UpdateOverlay()
		end

		return
	end

	if C_AddOns.IsAddOnLoaded(VAULT_ADDON) then
		self:HookVault()

		if WeeklyRewardsFrame then
			self:ClearVault(WeeklyRewardsFrame)
		end
	elseif not self.waiting then
		self.waiting = true
		AUI.Events:Register("ADDON_LOADED", self, self.OnAddonLoaded)
	end
end

---@param _ string
---@param name string
function HideFrames:OnAddonLoaded(_, name)
	if name ~= VAULT_ADDON then
		return
	end

	self.waiting = false
	AUI.Events:Unregister("ADDON_LOADED", self)
	self:HookVault()
end

function HideFrames:Apply()
	self:ApplyBossBanner()
	self:ApplyVault()
end
