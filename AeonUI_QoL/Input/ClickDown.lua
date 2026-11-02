local AUI = select(2, ...)

local Options = AUI.InputOptions

local CVAR = "ActionButtonUseKeyDown"

---Keeps `ActionButtonUseKeyDown` on the Click Down choice on every character using the profile: always on, on in
---combat only, or always off. Applied at login, on every change, as combat starts and ends, and again whenever the game
---changes it. Not Managed leaves it to the game.
---@class AUIClickDown
---@field managed boolean following combat and the game's changes
local ClickDown = {
	managed = false,
}
AUI.ClickDown = ClickDown

---@return string choice
local function Choice()
	return Options:Get(Options.CLICK_DOWN_PATH) or Options.UNMANAGED
end

---@param inCombat boolean
function ClickDown:Set(inCombat)
	local wanted = Options.ClickDownValue(Choice(), inCombat)

	if wanted and C_CVar.GetCVar(CVAR) ~= wanted then
		C_CVar.SetCVar(CVAR, wanted)
	end
end

---Sets the value the choice wants, and follows combat and the game's changes while the setting is managed.
function ClickDown:Apply()
	if not AUI.can.clickDown then
		return
	end

	local managed = Choice() ~= Options.UNMANAGED

	self:Set(InCombatLockdown())

	if managed == self.managed then
		return
	end

	self.managed = managed

	if managed then
		AUI.Events:Register("PLAYER_REGEN_DISABLED", self, self.OnCombatStarted)
		AUI.Events:Register("PLAYER_REGEN_ENABLED", self, self.OnCombatEnded)
		AUI.Events:Register("CVAR_UPDATE", self, self.OnCVarUpdate)
	else
		AUI.Events:Cancel("clickDown")
		AUI.Events:Unregister("PLAYER_REGEN_DISABLED", self)
		AUI.Events:Unregister("PLAYER_REGEN_ENABLED", self)
		AUI.Events:Unregister("CVAR_UPDATE", self)
	end
end

function ClickDown:OnCombatStarted()
	self:Set(true)
end

function ClickDown:OnCombatEnded()
	self:Set(false)
end

---@param _ string
---@param cvar string
function ClickDown:OnCVarUpdate(_, cvar)
	if cvar ~= CVAR then
		return
	end

	AUI.Events:Coalesce("clickDown", function()
		ClickDown:Set(InCombatLockdown())
	end)
end
