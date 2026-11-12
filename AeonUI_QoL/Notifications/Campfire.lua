local AUI = select(2, ...)

local Options = AUI.NotificationOptions

local EVENTS = {
	"PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "UNIT_AURA", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
}

---Camp Nearby: a line with the campfire icon while a campfire is within reach and Camp Benefits is gone or running low,
---out of combat, outside instances and while auras can be read.
---@class AUICampfireNotice
---@field following boolean the events are registered
---@field inCombat boolean
---@field timer table? the timer waiting for Camp Benefits to fall below the mark
local CampfireNotice = {
	following = false,
	inCombat = false,
}
AUI.CampfireNotice = CampfireNotice

---@param spell number
---@return AuraData? aura the player's aura, nil when absent or unreadable
local function Aura(spell)
	return AUI:Readable(C_UnitAuras.GetPlayerAuraBySpellID(spell), nil)
end

---@return boolean sitting
local function Sitting()
	for _, spell in ipairs(Options.WELCOMING_CAMPFIRE) do
		if Aura(spell) then
			return true
		end
	end

	return false
end

---@return boolean apply the notice applies here and now
local function Applies()
	local inInstance, instanceType = IsInInstance()

	return not Options:CountsAsInstance(inInstance, instanceType)
		and not (C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret())
end

---@return number? left seconds of Camp Benefits left, nil when it is gone or its time cannot be read
---@return boolean present Camp Benefits is on the player
local function BenefitsLeft()
	local aura = Aura(Options.CAMP_BENEFITS)
	local expiry = aura and AUI:Readable(aura.expirationTime, nil)

	if expiry and expiry > 0 then
		return expiry - GetTime(), true
	end

	return nil, aura ~= nil
end

function CampfireNotice:Check()
	if self.timer then
		self.timer:Cancel()
		self.timer = nil
	end

	local show, wait = false, nil

	if self.following and not self.inCombat and Applies() then
		local left, present = BenefitsLeft()

		if not (present and not left) then
			show, wait = Options:CampNearby(Aura(Options.CAMPFIRE_NEARBY) ~= nil, Sitting(), left,
				AUI.Profile:Get(Options.CAMP_UNDER_PATH))
		end
	end

	if show then
		AUI.Notifications:Show("campNearby", Options:CampNearbyText())
	else
		AUI.Notifications:Dismiss("campNearby")
	end

	if wait then
		self.timer = C_Timer.NewTimer(wait, function()
			self.timer = nil
			self:Check()
		end)
	end
end

---@param event string
---@param unit string?
function CampfireNotice:OnEvent(event, unit)
	if event == "UNIT_AURA" and unit ~= "player" then
		return
	end

	if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
		self.inCombat = event == "PLAYER_REGEN_DISABLED"
	end

	AUI.Events:Coalesce("campfireNotice", function()
		CampfireNotice:Check()
	end)
end

function CampfireNotice:Apply()
	local wanted = AUI.can.campNearbyNotice == true and Options:On("campNearby")

	if wanted ~= self.following then
		self.following = wanted

		if wanted then
			self.inCombat = InCombatLockdown() == true

			for _, event in ipairs(EVENTS) do
				AUI.Events:Register(event, self, self.OnEvent)
			end
		else
			AUI.Events:UnregisterAll(self)
			AUI.Events:Cancel("campfireNotice")
		end
	end

	self:Check()
end
