local AUI = select(2, ...)

local Options = AUI.NotificationOptions

local LAST_EQUIPPED_SLOT = 18
local EVENTS = {
	"PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_LEVEL_UP", "TRAIT_CONFIG_UPDATED",
	"PLAYER_TALENT_UPDATE", "ACTIVE_PLAYER_SPECIALIZATION_CHANGED", "UPDATE_INVENTORY_DURABILITY",
	"PLAYER_EQUIPMENT_CHANGED",
}
local LEGACY_EVENTS = {
	"TRAIT_CONFIG_CREATED", "TRAIT_CONFIG_DELETED", "TRAIT_CONFIG_LIST_UPDATED", "TRAIT_TREE_CURRENCY_INFO_UPDATED",
	"CURRENCY_DISPLAY_UPDATE", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED",
}

---Unspent Talent Points, Unspent Legacy Points and Low Durability: reminders out of combat that stay until the points
---are spent or the gear is repaired.
---@class AUICharacterNotices
---@field following boolean the events are registered
---@field followingLegacy boolean the Legacy events are registered
---@field inCombat boolean
local CharacterNotices = {
	following = false,
	followingLegacy = false,
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

---@return number? points the unspent Legacy points, nil before the Legacy system is unlocked
local function LegacyPoints()
	local Legacy = Constants.LegacyConsts

	if C_MajorFactions.GetCurrentRenownLevel(Legacy.LEGACY_REWARD_TRACK_FACTION_ID) <= 0 then
		return nil
	end

	local tree = Legacy.LEGACY_TREE_PROFESSIONS_ID
	local config = C_Traits.GetConfigIDByTreeID(tree)

	if not config then
		return nil
	end

	for _, currency in ipairs(C_Traits.GetTreeCurrencyInfo(config, tree, false) or {}) do
		if currency.traitCurrencyID == Legacy.LEGACY_POINTS_TRAIT_CURRENCY_ID then
			return currency.quantity
		end
	end

	return nil
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

	local legacy = out and self.followingLegacy and LegacyPoints()

	if legacy and legacy > 0 then
		Notifications:Show("legacyPoints", Options:LegacyPointsText(legacy))
	else
		Notifications:Dismiss("legacyPoints")
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
	local legacy = AUI.can.legacyNotice == true and Options:On("legacyPoints")
	local wanted = (AUI.can.talentNotice == true and Options:On("talents"))
		or (AUI.can.durabilityNotice == true and Options:On("durability")) or legacy

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

	if legacy ~= self.followingLegacy then
		self.followingLegacy = legacy

		for _, event in ipairs(LEGACY_EVENTS) do
			if legacy then
				AUI.Events:Register(event, self, self.OnEvent)
			else
				AUI.Events:Unregister(event, self)
			end
		end
	end

	self:Check()
end
