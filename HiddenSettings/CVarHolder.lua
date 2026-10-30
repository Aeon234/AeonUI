local AUI = select(2, ...)

local Options = AUI.HiddenSettingsOptions

---Keeps a group of console variables at held values. Holding saves the player's values first; releasing writes them
---back and drops the save. Only values that differ are written, since every write fires `CVAR_UPDATE` synchronously
---through Blizzard's handlers. While holding, a change to a held or trigger console variable is put back, coalesced.
---Writes asked for in combat wait for `PLAYER_REGEN_ENABLED`, and only the latest wanted state is applied then. A
---restore the client refuses stays saved, and is tried again at the next release.
---@class AUICVarHolder
---@field key string the coalesced work's key
---@field held AUIHeldCVar[] the held values whose console variables the client has and lets addons write
---@field watched string[] the held console variables and the triggers
---@field saved fun(): table<string, string>? the account-wide save, created on first use; nil while unusable
---@field clear fun() removes the save
---@field wanted boolean holding, or releasing
---@field following boolean `CVAR_UPDATE` is registered
---@field waiting boolean `PLAYER_REGEN_ENABLED` is registered
local CVarHolderMixin = {}
AUI.CVarHolderMixin = CVarHolderMixin

---@param key string
---@param held AUIHeldCVar[]
---@param triggers string[] console variables whose change resets the held ones
---@param saved fun(): table<string, string>?
---@param clear fun()
---@return AUICVarHolder
function AUI.CreateCVarHolder(key, held, triggers, saved, clear)
	local available, watched = {}, {}

	for _, entry in ipairs(held) do
		local value, _, _, _, _, isSecure, isReadOnly = C_CVar.GetCVarInfo(entry.name)

		if value ~= nil and not isSecure and not isReadOnly then
			available[#available + 1] = entry
			watched[#watched + 1] = entry.name
		end
	end

	for _, name in ipairs(triggers) do
		watched[#watched + 1] = name
	end

	return Mixin({
		key = key,
		held = available,
		watched = watched,
		saved = saved,
		clear = clear,
		wanted = false,
		following = false,
		waiting = false,
	}, CVarHolderMixin)
end

---@param writes AUIHeldCVar[]
---@return table<string, true> refused the console variables the client did not write
local function Write(writes)
	local refused = {}

	for _, entry in ipairs(writes) do
		if not C_CVar.SetCVar(entry.name, entry.value) then
			refused[entry.name] = true
		end
	end

	return refused
end

---@param following boolean
function CVarHolderMixin:Follow(following)
	if following == self.following then
		return
	end

	self.following = following

	if following then
		AUI.Events:Register("CVAR_UPDATE", self, self.OnCVarUpdate)
	else
		AUI.Events:Cancel(self.key)
		AUI.Events:Unregister("CVAR_UPDATE", self)
	end
end

---Saves the player's values not yet saved, then holds. Does nothing while saved data is unusable.
function CVarHolderMixin:Hold()
	local saved = self.saved()

	if not saved then
		return
	end

	Options.Save(self.held, C_CVar.GetCVar, saved)
	self.wanted = true
	self:Follow(true)
	self:Apply()
end

function CVarHolderMixin:Release()
	self.wanted = false
	self:Follow(false)
	self:Apply()
end

---Writes the wanted state, or waits for the end of combat to.
function CVarHolderMixin:Apply()
	if InCombatLockdown() then
		if not self.waiting then
			self.waiting = true
			AUI.Events:Register("PLAYER_REGEN_ENABLED", self, self.OnCombatEnded)
		end

		return
	end

	if self.wanted then
		Write(Options.Pending(self.held, C_CVar.GetCVar))

		return
	end

	local saved = self.saved()

	if not saved then
		return
	end

	local refused = Write(Options.Restore(self.held, saved, C_CVar.GetCVar))

	for name in pairs(saved) do
		if not refused[name] then
			saved[name] = nil
		end
	end

	if next(saved) == nil then
		self.clear()
	end
end

function CVarHolderMixin:OnCombatEnded()
	self.waiting = false
	AUI.Events:Unregister("PLAYER_REGEN_ENABLED", self)
	self:Apply()
end

---@param _ string
---@param cvar string
function CVarHolderMixin:OnCVarUpdate(_, cvar)
	if not Options.Watches(self.watched, cvar) then
		return
	end

	AUI.Events:Coalesce(self.key, function()
		self:Apply()
	end)
end
