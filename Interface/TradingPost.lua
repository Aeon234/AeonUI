local AUI = select(2, ...)

local Options = AUI.InterfaceOptions

local TRADING_POST_ADDON = "Blizzard_PerksProgram"

---Starts each Trading Post preview without its combat animation (Retail). As the Trading Post opens and as each new
---product is shown, the attack animation setting is turned off and Blizzard's Combat Animation checkbox unchecked, so
---the checkbox still turns it on for the product on display. The frame's show and the footer's update are hooked
---once the Trading Post's addon has loaded; turning the feature off leaves the current setting as it is.
---@class AUITradingPost
---@field hooked boolean the Trading Post's show and footer update are hooked
---@field waiting boolean waiting for the Trading Post's addon to load
local TradingPost = {
	hooked = false,
	waiting = false,
}
AUI.TradingPost = TradingPost

---Turns the attack animation off for the product on display.
function TradingPost:TurnOff()
	if not Options:On(Options.TRADING_POST_COMBAT_PATH) or not C_PerksProgram.IsAttackAnimToggleEnabled() then
		return
	end

	if PerksProgramFrame:GetAttackAnimationSetting() ~= false then
		PerksProgramFrame:SetAttackAnimationSetting(false)
	end

	PerksProgramFrame.FooterFrame.ToggleAttackAnimation:SetChecked(false)
end

---Hooks the Trading Post once its addon has loaded.
function TradingPost:Hook()
	if self.hooked or not PerksProgramFrame then
		return
	end

	self.hooked = true
	PerksProgramFrame:HookScript("OnShow", function()
		self:TurnOff()
	end)
	hooksecurefunc(PerksProgramFrame.FooterFrame, "UpdateTransmogControls", function(_, _, newProduct)
		if newProduct then
			self:TurnOff()
		end
	end)
end

function TradingPost:Apply()
	if not AUI.can.tradingPost or not Options:On(Options.TRADING_POST_COMBAT_PATH) then
		return
	end

	if C_AddOns.IsAddOnLoaded(TRADING_POST_ADDON) then
		self:Hook()
	elseif not self.waiting then
		self.waiting = true
		AUI.Events:Register("ADDON_LOADED", self, self.OnAddonLoaded)
	end
end

---@param _ string
---@param name string
function TradingPost:OnAddonLoaded(_, name)
	if name ~= TRADING_POST_ADDON then
		return
	end

	self.waiting = false
	AUI.Events:Unregister("ADDON_LOADED", self)
	self:Hook()
end
