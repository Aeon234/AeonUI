local AUI = select(2, ...)

local Options = AUI.NotificationOptions

local KEYS = { "petMissing", "petPassive", "petHealth" }
local EVENTS = {
	"PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PET_BAR_UPDATE", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED",
	"PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "SPELLS_CHANGED", "PLAYER_SPECIALIZATION_CHANGED",
}
-- Unit events and the unit each is followed for.
local UNIT_EVENTS = {
	UNIT_PET = "player",
	UNIT_ENTERED_VEHICLE = "player",
	UNIT_EXITED_VEHICLE = "player",
	UNIT_AURA = "player",
	UNIT_HEALTH = "pet",
	UNIT_MAXHEALTH = "pet",
}
local SECRET = {} --[[@as AuraData]]

---Pet Missing, Pet Passive and Pet Low Health, for a character that should have its permanent pet out, while in combat
---or in an instance and not mounted (or just dismounted), in a vehicle, on a taxi or dead. Pet Low Health's line is
---drawn through a curve of the pet's health, so the health is never read.
---@class AUIPetNotices
---@field following boolean the events are registered
---@field inCombat boolean
---@field mounted boolean
---@field graceUntil number? while dismounting's grace runs, when it ends
---@field sacrificed boolean? the last readable answer to whether Grimoire of Sacrifice is active
---@field curve table? the health curve for the mark it was built for
---@field curveMark number?
local PetNotices = {
	following = false,
	inCombat = false,
	mounted = false,
}
AUI.PetNotices = PetNotices

---@return boolean secret whether the Grimoire of Sacrifice aura may be secret now
local function SacrificeAuraSecret()
	if not (C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret()) then
		return false
	end

	local never = Enum.SecrecyLevel and Enum.SecrecyLevel.NeverSecret

	return not (never and C_Secrets.GetSpellAuraSecrecy
		and C_Secrets.GetSpellAuraSecrecy(Options.SACRIFICE_AURA) == never)
end

---@param spell number
---@return boolean
local function Known(spell)
	return C_SpellBook.IsSpellKnown(spell) == true
end

---@return boolean sacrificed Grimoire of Sacrifice is active; while its aura cannot be read, the last answer stands
function PetNotices:Sacrificed()
	if not Known(Options.SACRIFICE_TALENT) then
		self.sacrificed = false

		return false
	end

	if SacrificeAuraSecret() then
		return self.sacrificed == true
	end

	local aura = AUI:Readable(C_UnitAuras.GetPlayerAuraBySpellID(Options.SACRIFICE_AURA), SECRET)

	if aura == SECRET then
		return self.sacrificed == true
	end

	self.sacrificed = aura ~= nil

	return self.sacrificed
end

---@return number? specID the character's specialization, where the client has them
local function SpecID()
	if not AUI.can.specializations then
		return nil
	end

	local index = C_SpecializationInfo.GetSpecialization()

	return index and C_SpecializationInfo.GetSpecializationInfo(index) or nil
end

---@return boolean passive the pet's stance is Passive
local function Passive()
	for slot = 1, NUM_PET_ACTION_SLOTS or 10 do
		local name, _, isToken, isActive = GetPetActionInfo(slot)

		if AUI:Readable(isToken, false) and AUI:Readable(name, nil) == "PET_MODE_PASSIVE" then
			return AUI:Readable(isActive, false) == true
		end
	end

	return false
end

---@return table curve the pet health curve for the current mark
function PetNotices:Curve()
	local mark = AUI.Profile:Get(Options.PET_HEALTH_PATH)

	if not self.curve or self.curveMark ~= mark then
		local curve = C_CurveUtil.CreateCurve()

		curve:SetType(Enum.LuaCurveType.Step)

		for _, point in ipairs(Options:HealthCurve(mark)) do
			curve:AddPoint(point[1], point[2])
		end

		self.curve, self.curveMark = curve, mark
	end

	return self.curve --[[@as table]]
end

---@return boolean apply pet reminders apply now
function PetNotices:Applies()
	local inInstance, instanceType = IsInInstance()

	return Options:PetRemindersApply({
		inCombat = self.inCombat,
		inInstance = Options:CountsAsInstance(inInstance, instanceType),
		mounted = self.mounted or (self.graceUntil ~= nil and GetTime() < self.graceUntil),
		vehicle = UnitInVehicle("player") == true,
		taxi = UnitOnTaxi("player") == true,
		dead = UnitIsDeadOrGhost("player") == true,
	})
end

---Shows or dismisses each pet notice to match the pet.
function PetNotices:Check()
	local Notifications = AUI.Notifications
	local applies = self.following and Options:PetEligible(Known, SpecID(), self:Sacrificed()) and self:Applies()
	local missing = applies and (not AUI:Readable(UnitExists("pet"), true) or AUI:Readable(UnitIsDead("pet"), false))
	local shown = {
		petMissing = missing and Options:On("petMissing"),
		petPassive = applies and not missing and Options:On("petPassive") and Passive(),
		petHealth = applies and not missing and AUI.can.petHealthNotice and Options:On("petHealth"),
	}

	for _, key in ipairs(KEYS) do
		if shown[key] then
			if key == "petHealth" then
				local alpha = UnitHealthPercent("pet", true, self:Curve()) --[[@as number]]

				Notifications:Show(key, nil, { fade = false }):SetAlpha(alpha)
			else
				Notifications:Show(key)
			end
		else
			Notifications:Dismiss(key)
		end
	end
end

function PetNotices:Queue()
	AUI.Events:Coalesce("petNotices", function()
		PetNotices:Check()
	end)
end

---Redraws Pet Low Health's line through the curve, as the pet's health changes.
function PetNotices:UpdateHealth()
	local line = AUI.Notifications:Find("petHealth")

	if line and line.key == "petHealth" then
		line:SetAlpha(UnitHealthPercent("pet", true, self:Curve()) --[[@as number]])
	end
end

---@param event string
function PetNotices:OnEvent(event)
	if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
		self.inCombat = event == "PLAYER_REGEN_DISABLED"
	elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
		local mounted = IsMounted() == true

		if self.mounted and not mounted then
			self.graceUntil = GetTime() + Options.DISMOUNT_GRACE
			C_Timer.After(Options.DISMOUNT_GRACE, function()
				PetNotices:Queue()
			end)
		end

		self.mounted = mounted
	end

	self:Queue()
end

---@param event string
---@param unit string
function PetNotices:OnUnitEvent(event, unit)
	if unit ~= UNIT_EVENTS[event] then
		return
	end

	if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
		self:UpdateHealth()
	else
		self:Queue()
	end
end

function PetNotices:Apply()
	local wanted = AUI.can.petNotices == true
		and (Options:On("petMissing") or Options:On("petPassive") or Options:On("petHealth"))

	if wanted ~= self.following then
		self.following = wanted

		if wanted then
			self.inCombat = InCombatLockdown() == true
			self.mounted = IsMounted() == true

			for _, event in ipairs(EVENTS) do
				AUI.Events:Register(event, self, self.OnEvent)
			end

			for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_MOUNT_DISPLAY_CHANGED" }) do
				AUI.Events:Register(event, self, self.OnEvent)
			end

			for event in pairs(UNIT_EVENTS) do
				AUI.Events:Register(event, self, self.OnUnitEvent)
			end
		else
			AUI.Events:UnregisterAll(self)
			AUI.Events:Cancel("petNotices")
		end
	end

	self:Check()
end
