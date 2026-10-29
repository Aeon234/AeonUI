local AUI = select(2, ...)

local L = AUI.L
local Options = AUI.InterfaceOptions

local CONFIRM_POPUP = "AEONUI_RELEASE_SPIRIT"
local CHECK_EVENTS = { "PLAYER_DEAD", "PLAYER_ENTERING_WORLD" }
local STAND_DOWN_EVENTS = { "PLAYER_ALIVE", "PLAYER_UNGHOST" }

---Confirm Release Spirit: on death a confirmation shows, and Release Spirit on Blizzard's death dialog stays disabled
---until Yes is pressed. It rearms on the next death and stands down on resurrection or release. Blizzard's death
---dialog sets the button's state on every update, so a post-hook on that update disables it afterwards; after Yes the
---button is left to Blizzard, including Blizzard's own blocks. The hook is installed once, the first time it is on.
---@class AUIReleaseProtection
---@field hooked boolean the death dialog's update is hooked
---@field following boolean the death events are registered
---@field armed boolean the confirmation is pending: Release Spirit stays disabled
local ReleaseProtection = {
	hooked = false,
	following = false,
	armed = false,
}
AUI.ReleaseProtection = ReleaseProtection

StaticPopupDialogs[CONFIRM_POPUP] = {
	text = L["Do you want to release your spirit?"],
	button1 = YES,
	OnAccept = function()
		ReleaseProtection:Confirm()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = false,
}

---Disables Release Spirit after Blizzard's death dialog has set it, while armed.
---@param dialog table the death dialog
function ReleaseProtection:Guard(dialog)
	if not self.armed then
		return
	end

	local button = dialog.GetButton1 and dialog:GetButton1()

	if button and button:IsEnabled() then
		button:Disable()
	end
end

---Arms and asks once Blizzard's death dialog shows; released, alive or without the dialog, it stands down.
function ReleaseProtection:Check()
	if not self.following then
		return
	end

	if UnitIsDead("player") and not UnitIsGhost("player") and StaticPopup_FindVisible("DEATH") then
		self.armed = true
		StaticPopup_Show(CONFIRM_POPUP)
	else
		self:StandDown()
	end
end

---Yes on the confirmation: Release Spirit is Blizzard's again.
function ReleaseProtection:Confirm()
	self.armed = false
end

function ReleaseProtection:StandDown()
	self.armed = false
	StaticPopup_Hide(CONFIRM_POPUP)
end

function ReleaseProtection:Apply()
	local wanted = AUI.can.releaseProtection == true and Options:On(Options.RELEASE_PROTECTION_PATH)

	if wanted == self.following then
		return
	end

	self.following = wanted

	if not wanted then
		for _, event in ipairs(CHECK_EVENTS) do
			AUI.Events:Unregister(event, self)
		end

		for _, event in ipairs(STAND_DOWN_EVENTS) do
			AUI.Events:Unregister(event, self)
		end

		AUI.Events:Cancel("releaseProtection")
		self:StandDown()

		return
	end

	if not self.hooked then
		self.hooked = true
		hooksecurefunc(StaticPopupDialogs.DEATH, "OnUpdate", function(dialog)
			self:Guard(dialog)
		end)
	end

	-- Blizzard's own PLAYER_DEAD handler shows the death dialog, so the check waits for the next frame.
	for _, event in ipairs(CHECK_EVENTS) do
		AUI.Events:Register(event, self, function()
			AUI.Events:Coalesce("releaseProtection", function()
				self:Check()
			end)
		end)
	end

	for _, event in ipairs(STAND_DOWN_EVENTS) do
		AUI.Events:Register(event, self, self.StandDown)
	end

	self:Check()
end
