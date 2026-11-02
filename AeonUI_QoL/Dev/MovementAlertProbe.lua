-- Development probe for Movement Alerts. Not packaged.
local AUI = select(2, ...)

---Prints each of the class's abilities as the client answers for them and each tracked spell's cooldown state, and
---turns the feature on or off.
---@class AUIMovementAlertProbe
local Probe = {}
AUI.Dev.MovementAlertProbe = Probe

---Prints a value that may be secret.
---@param value any
---@return string
local function Show(value)
	if issecretvalue(value) then
		return "<secret>"
	end

	return tostring(value)
end

function Probe:PrintAbilities()
	local Options = AUI.MovementAlertOptions
	local _, class = UnitClass("player")
	local index = C_SpecializationInfo.GetSpecialization()
	local specID = index and C_SpecializationInfo.GetSpecializationInfo(index)

	AUI:Print("movealert: %s, spec %s", class, tostring(specID))

	for _, spell in ipairs(Options:ClassSpells(class)) do
		for _, id in ipairs(spell.ids) do
			AUI:Print("  %d %s: known %s, override %s, for this spec %s, checked %s", id,
				tostring(C_Spell.GetSpellName(id)), tostring(C_SpellBook.IsSpellKnown(id)),
				tostring(C_Spell.GetOverrideSpell(id)), tostring(not spell.specs or (specID ~= nil and spell.specs[specID] == true)),
				tostring(AUI.Profile:Get(Options:SpellPath(spell))))
		end
	end
end

function Probe:PrintState()
	local Alert = AUI.MovementAlert

	AUI:Print("movealert: on %s, %d tracked, cooldowns secret %s", tostring(Alert:IsOn()), #Alert.entries,
		Show(C_Secrets.ShouldCooldownsBeSecret()))

	for _, entry in ipairs(Alert.entries) do
		local cooldown = C_Spell.GetSpellCooldown(entry.id)
		local charges = C_Spell.GetSpellCharges(entry.id)

		AUI:Print("  %d %s: active %s, on GCD %s, duration %s, max charges %s, charges %s", entry.id, entry.name,
			Show(cooldown and cooldown.isActive), Show(cooldown and cooldown.isOnGCD),
			Show(cooldown and cooldown.duration), Show(charges and charges.maxCharges),
			Show(charges and charges.currentCharges))
	end
end

---@param rest string "on", "off", or empty for the abilities and state
function Probe:Command(rest)
	if rest == "on" or rest == "off" then
		AUI.MovementAlert:Start()
		AUI.Profile:Set(AUI.MovementAlertOptions.ENABLED_PATH, rest == "on")
		AUI:Print("movealert: %s", rest)

		return
	end

	self:PrintAbilities()
	self:PrintState()
end
