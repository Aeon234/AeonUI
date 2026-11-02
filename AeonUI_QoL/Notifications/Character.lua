local AUI = select(2, ...)

local Options = AUI.NotificationOptions

local LAST_EQUIPPED_SLOT = 18
local EVENTS = {
	"PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_LEVEL_UP", "TRAIT_CONFIG_UPDATED",
	"PLAYER_TALENT_UPDATE", "ACTIVE_PLAYER_SPECIALIZATION_CHANGED", "UPDATE_INVENTORY_DURABILITY",
	"PLAYER_EQUIPMENT_CHANGED",
}

---Unspent Talent Points and Low Durability: reminders out of combat that stay until the points are spent or the gear
---is repaired.
---@class AUICharacterNotices
---@field following boolean the events are registered
---@field inCombat boolean
local CharacterNotices = {
	following = false,
	inCombat = false,
}
AUI.CharacterNotices = CharacterNotices

---@return boolean unspent the character has talent points to spend
local function UnspentTalents()
	local Talents = C_ClassTalents

	if C_SpecializationInfo and C_SpecializationInfo.CanPlayerUseTalentUI
		and not C_SpecializationInfo.CanPlayerUseTalentUI() then
		return false
	end

	if AUI:Readable((Talents.HasUnspentTalentPoints()), false) == true then
		return true
	end

	return Talents.HasUnspentHeroTalentPoints ~= nil
		and AUI:Readable((Talents.HasUnspentHeroTalentPoints()), false) == true
end

---@return number? percent the lowest durability among the equipped items, nil when none has durability
local function LowestDurability()
	local pieces = {}

	for slot = 1, LAST_EQUIPPED_SLOT do
		local current, maximum = GetInventoryItemDurability(slot)

		if current and maximum then
			pieces[#pieces + 1] = { current = current, maximum = maximum }
		end
	end

	return Options:LowestDurability(pieces)
end

function CharacterNotices:Check()
	local Notifications = AUI.Notifications
	local out = self.following and not self.inCombat

	if out and AUI.can.talentNotice and Options:On("talents") and UnspentTalents() then
		Notifications:Show("talents")
	else
		Notifications:Dismiss("talents")
	end

	local lowest = out and AUI.can.durabilityNotice and Options:On("durability") and LowestDurability()

	if lowest and lowest < AUI.Profile:Get(Options.DURABILITY_PATH) then
		Notifications:Show("durability", Options:DurabilityText("durability", lowest))
	else
		Notifications:Dismiss("durability")
	end
end

---@param event string
function CharacterNotices:OnEvent(event)
	if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
		self.inCombat = event == "PLAYER_REGEN_DISABLED"
	end

	AUI.Events:Coalesce("characterNotices", function()
		CharacterNotices:Check()
	end)
end

function CharacterNotices:Apply()
	local wanted = (AUI.can.talentNotice == true and Options:On("talents"))
		or (AUI.can.durabilityNotice == true and Options:On("durability"))

	if wanted ~= self.following then
		self.following = wanted

		if wanted then
			self.inCombat = InCombatLockdown() == true

			for _, event in ipairs(EVENTS) do
				AUI.Events:Register(event, self, self.OnEvent)
			end
		else
			AUI.Events:UnregisterAll(self)
			AUI.Events:Cancel("characterNotices")
		end
	end

	self:Check()
end
