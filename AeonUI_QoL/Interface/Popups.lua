local AUI = select(2, ...)

local Options = AUI.InterfaceOptions

-- Pop-ups whose accept button waits out a countdown: the Great Vault choice and item upgrades.
local DELAYED_POPUPS = {
	CONFIRM_SELECT_WEEKLY_REWARD = true,
	ITEM_INTERACTION_CONFIRMATION_DELAYED = true,
	ITEM_INTERACTION_CONFIRMATION_DELAYED_WITH_CHARGE_INFO = true,
}

-- Destroy pop-ups that ask for the confirmation word.
local DESTROY_POPUPS = { DELETE_GOOD_ITEM = true, DELETE_GOOD_QUEST_ITEM = true }

-- Each Hold to Skip key and the function that reports it held; NONE needs no key.
local KEY_CHECKS = { SHIFT = "IsShiftKeyDown", CTRL = "IsControlKeyDown", ALT = "IsAltKeyDown" }

---Changes how four of Blizzard's pop-ups behave. Skip Accept Countdowns enables the accept button of the Great Vault
---and item upgrade pop-ups during their countdown, always or while a key is held: Blizzard disables it on every update
---of the countdown, so a post-hook on that update enables it again, and the button goes back to the countdown when the
---key is released. Auto Confirm Bind on Pickup loots such an item without asking. Easy Item Destroy types the confirmation word
---into the destroy pop-up as it is shown, so Blizzard's own text handler enables the accept button. Click-Through Toasts turns off the
---mouse on event toasts as each is shown, and turns it on again on each frame it changed when switched off. Hooks are
---installed once, the first time a feature is on.
---@class AUIBlizzardPopups
---@field hookedCountdown boolean the pop-ups' update is hooked
---@field hookedToasts boolean the toast manager's display is hooked
---@field hookedDestroy boolean `StaticPopup_Show` is hooked
---@field confirming boolean bind-on-pickup questions are answered
---@field released table<Frame, true> toast frames whose mouse this turned off
local BlizzardPopups = {
	hookedCountdown = false,
	hookedToasts = false,
	hookedDestroy = false,
	confirming = false,
	released = {},
}
AUI.BlizzardPopups = BlizzardPopups

---@param key string? a `skipKey` choice
---@return boolean held the key is held, or none is needed
function BlizzardPopups.KeyHeld(key)
	local check = key and KEY_CHECKS[key]

	if not check then
		return true
	end

	local IsKeyDown = _G[check]

	return IsKeyDown ~= nil and IsKeyDown() == true
end

---Enables a counting-down pop-up's accept button after Blizzard's update has disabled it.
---@param dialog table a static pop-up
function BlizzardPopups:Skip(dialog)
	if not dialog.acceptDelay or not DELAYED_POPUPS[dialog.which] or not Options:On(Options.SKIP_COUNTDOWN_PATH)
		or not self.KeyHeld(Options:Get(Options.SKIP_KEY_PATH)) then
		return
	end

	local info = StaticPopupDialogs[dialog.which]
	local button = dialog.GetButton1 and dialog:GetButton1()

	if info and button then
		button:Enable()
		button:SetText(info.button1)
	end
end

function BlizzardPopups:ApplyCountdown()
	if self.hookedCountdown or not AUI.can.skipCountdown or not Options:On(Options.SKIP_COUNTDOWN_PATH) then
		return
	end

	self.hookedCountdown = true
	hooksecurefunc("StaticPopup_OnUpdate", function(dialog)
		self:Skip(dialog)
	end)
end

---@param _ string
---@param slot number the loot slot that asks
function BlizzardPopups:OnLootBindConfirm(_, slot)
	ConfirmLootSlot(slot)
	-- Blizzard's own question may show after this handler.
	C_Timer.After(0, function()
		StaticPopup_Hide("LOOT_BIND", slot)
	end)
end

function BlizzardPopups:ApplyConfirmBind()
	local wanted = AUI.can.confirmBind == true and Options:On(Options.CONFIRM_BIND_PATH)

	if wanted == self.confirming then
		return
	end

	self.confirming = wanted

	if wanted then
		AUI.Events:Register("LOOT_BIND_CONFIRM", self, self.OnLootBindConfirm)
	else
		AUI.Events:Unregister("LOOT_BIND_CONFIRM", self)
	end
end

---Types the confirmation word into a destroy pop-up that was just shown.
---@param which string the pop-up shown
function BlizzardPopups:FillDestroy(which)
	if not DESTROY_POPUPS[which] or not Options:On(Options.EASY_DESTROY_PATH) then
		return
	end

	local dialog = StaticPopup_FindVisible(which)

	if dialog then
		dialog:GetEditBox():SetText(DELETE_ITEM_CONFIRM_STRING)
	end
end

function BlizzardPopups:ApplyDestroy()
	if self.hookedDestroy or not AUI.can.easyDestroy or not Options:On(Options.EASY_DESTROY_PATH) then
		return
	end

	self.hookedDestroy = true
	hooksecurefunc("StaticPopup_Show", function(which)
		self:FillDestroy(which)
	end)
end

---@param frame table?
function BlizzardPopups:Release(frame)
	if frame and frame:IsMouseEnabled() then
		frame:EnableMouse(false)
		self.released[frame] = true
	end
end

---Turns the mouse off on the toast manager and the toast it shows.
---@param manager table
function BlizzardPopups:ReleaseToasts(manager)
	if not Options:On(Options.TOAST_CLICK_THROUGH_PATH) then
		return
	end

	self:Release(manager)

	local toast = manager.currentDisplayingToast

	if toast then
		self:Release(toast)
		self:Release(toast.TitleTextMouseOverFrame)
		self:Release(toast.SubTitleMouseOverFrame)
	end
end

function BlizzardPopups:ApplyToasts()
	if not AUI.can.clickThroughToasts then
		return
	end

	if not Options:On(Options.TOAST_CLICK_THROUGH_PATH) then
		for frame in pairs(self.released) do
			frame:EnableMouse(true)
		end

		self.released = {}

		return
	end

	if not self.hookedToasts then
		self.hookedToasts = true
		hooksecurefunc(EventToastManagerFrame, "DisplayToast", function(manager)
			self:ReleaseToasts(manager)
		end)
	end

	self:ReleaseToasts(EventToastManagerFrame)
end

function BlizzardPopups:Apply()
	self:ApplyCountdown()
	self:ApplyConfirmBind()
	self:ApplyDestroy()
	self:ApplyToasts()
end
