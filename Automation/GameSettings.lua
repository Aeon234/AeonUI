local AUI = select(2, ...)

local Options = AUI.AutomationOptions

local UNMANAGED = Options.UNMANAGED
local DUEL_POPUPS = { "DUEL_REQUESTED", "DUEL_TO_THE_DEATH_REQUESTED" }

---Keeps the chosen game settings on every character using the profile: auto loot, weather, the camera's largest
---distance, and blocking trades, guild invites, channel invites and duels. Each is applied at login, on every change,
---and again whenever the game or its own option changes it. Not Managed leaves a setting to the game.
---@class AUIGameSettings
---@field active boolean following the game's changes
---@field hooked boolean the guild-invite setter is hooked
local GameSettings = {
	active = false,
	hooked = false,
}
AUI.GameSettings = GameSettings

---@param setting AUIManagedSetting
---@return boolean
function GameSettings.IsAvailable(setting)
	if setting.guild then
		return AUI.can.autoDeclineGuildInvites == true
	elseif setting.cvar then
		return C_CVar.GetCVarInfo(setting.cvar) ~= nil
	end

	return true
end

---@param setting AUIManagedSetting
---@return string choice
local function Choice(setting)
	return Options:Get(setting.path) or UNMANAGED
end

---@param setting AUIManagedSetting
function GameSettings:ApplySetting(setting)
	local choice = Choice(setting)

	if choice == UNMANAGED or setting.duel or not self.IsAvailable(setting) then
		return
	end

	if setting.guild then
		local decline = choice == "ON"

		if GetAutoDeclineGuildInvites() ~= decline then
			SetAutoDeclineGuildInvites(decline)
		end
	elseif setting.cvar then
		local wanted = Options.Wanted(choice)

		if wanted and not Options.Holds(C_CVar.GetCVar(setting.cvar), wanted) then
			C_CVar.SetCVar(setting.cvar, wanted)
		end
	end
end

---Sets every managed setting that differs from its choice, and follows the game's changes while any is managed.
function GameSettings:Apply()
	local managed = false

	for _, key in ipairs(Options.MANAGED_KEYS) do
		local setting = Options.MANAGED[key]

		self:ApplySetting(setting)
		managed = managed or Choice(setting) ~= UNMANAGED
	end

	if managed == self.active then
		return
	end

	self.active = managed

	if managed then
		AUI.Events:Register("CVAR_UPDATE", self, self.OnCVarUpdate)
		AUI.Events:Register("DUEL_REQUESTED", self, self.OnDuelRequested)
		AUI.Events:Register("DUEL_TO_THE_DEATH_REQUESTED", self, self.OnDuelRequested)
		self:HookGuildInvites()
	else
		AUI.Events:Cancel("gameSettings")
		AUI.Events:Unregister("CVAR_UPDATE", self)
		AUI.Events:Unregister("DUEL_REQUESTED", self)
		AUI.Events:Unregister("DUEL_TO_THE_DEATH_REQUESTED", self)
	end
end

function GameSettings:ApplySoon()
	AUI.Events:Coalesce("gameSettings", function()
		GameSettings:Apply()
	end)
end

---Puts the guild-invite decline back when Blizzard's own option changes it. Hooked once.
function GameSettings:HookGuildInvites()
	if self.hooked or not AUI.can.autoDeclineGuildInvites then
		return
	end

	self.hooked = true
	hooksecurefunc("SetAutoDeclineGuildInvites", function()
		if self.active then
			self:ApplySoon()
		end
	end)
end

---@param _ string
---@param cvar string
function GameSettings:OnCVarUpdate(_, cvar)
	for _, key in ipairs(Options.MANAGED_KEYS) do
		local setting = Options.MANAGED[key]

		if setting.cvar == cvar and Choice(setting) ~= UNMANAGED then
			self:ApplySoon()

			return
		end
	end
end

---Declines the request. Blizzard's prompt is hidden a frame later as well, since it may be shown after this handler.
function GameSettings:OnDuelRequested()
	if Choice(Options.MANAGED.duels) ~= "BLOCKED" then
		return
	end

	CancelDuel()
	C_Timer.After(0, function()
		for _, popup in ipairs(DUEL_POPUPS) do
			StaticPopup_Hide(popup)
		end
	end)
end
