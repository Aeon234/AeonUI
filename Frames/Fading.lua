local AUI = select(2, ...)

local Schema = AUI.Schema

-- Seconds between range checks while a range-faded unit exists.
local RANGE_INTERVAL = 0.2

-- Frames with a fade setting, and the unit each measures range to.
local FADED = { "player", "pet", "playerPower", "classPower", "target", "focus" }
local RANGE_UNITS = { target = "target", focus = "focus" }

-- Player events that start or end a cast, which ends or begins idleness.
local CAST_EVENTS = {
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_EMPOWER_START",
	"UNIT_SPELLCAST_EMPOWER_STOP",
}

---Frame opacity: the idle fade (out of combat, no target, not casting), the range fade on target and focus, and the
---class resource's Hide Out of Combat. When fades meet, the stronger one wins. Opacity is not protected, so this also
---runs in combat.
---@class AUIFading
---@field inCombat boolean
---@field idle boolean
---@field harmful integer? the player's spell for measuring range to an enemy
---@field helpful integer? the player's heal for measuring range to a friend
---@field ticker table? the range ticker, while a range-faded unit exists
---@field started boolean? watching events
local Fading = {
	inCombat = false,
	idle = false,
}
AUI.Fading = Fading

---@param config table
---@param key string
---@param kind "range"|"idle"
---@return number? alpha the opacity to fade to, 0 to 1, or nil when the frame has no such fade or it is off
function Fading:Alpha(config, key, kind)
	local base = "frames." .. key .. ".fade." .. kind .. "."

	if not Schema:Field(base .. "enabled") or not Schema:Read(config, base .. "enabled") then
		return nil
	end

	return Schema:Read(config, base .. "alpha") / 100
end

---@param inCombat boolean
---@param hasTarget boolean
---@param casting boolean
---@return boolean idle
function Fading:IsIdle(inCombat, hasTarget, casting)
	return not inCombat and not hasTarget and not casting
end

---@param value any a return of `UnitCastingInfo` or `UnitChannelInfo`, possibly secret
---@return boolean present
local function Present(value)
	return issecretvalue(value) or value ~= nil
end

---@return boolean casting the player is casting, channeling or empowering
local function Casting()
	return Present(UnitCastingInfo("player")) or Present(UnitChannelInfo("player"))
end

---The opacity a frame rests at before any range fade: faded while idle, hidden out of combat for the class resource
---with Hide Out of Combat on.
---@param config table
---@param key string
---@return number alpha
function Fading:Base(config, key)
	local alpha = 1
	local idle = self.idle and self:Alpha(config, key, "idle")

	if idle then
		alpha = idle
	end

	if key == "classPower" and Schema:Read(config, "frames.classPower.hideOutOfCombat") and not self.inCombat then
		alpha = 0
	end

	return alpha
end

---Finds the first spell of each list the player knows, for measuring range.
function Fading:FindSpells()
	local _, class = UnitClass("player")
	local data = AUI.CastData

	local function First(list)
		for _, spellID in ipairs(list or {}) do
			if C_SpellBook.IsSpellKnownOrInSpellBook(spellID) then
				return spellID
			end
		end
	end

	self.harmful = First(class and data.harmful[class])
	self.helpful = First(class and data.helpful[class])
end

---@param unit string
---@return boolean? inRange possibly secret; nil when range cannot be measured
function Fading:InRange(unit)
	local canAttack = UnitCanAttack("player", unit)

	if issecretvalue(canAttack) then
		return nil
	end

	local spell = canAttack and self.harmful or self.helpful

	if not spell then
		return nil
	end

	return C_Spell.IsSpellInRange(spell, unit)
end

---Applies a frame's opacity.
---@param frame table
function Fading:Update(frame)
	local config = AUI.Profile.config
	local key = frame.key
	local alpha = self:Base(config, key)
	local unit = RANGE_UNITS[key]
	local range = unit and self:Alpha(config, key, "range")

	if range and UnitExists(unit) then
		local inRange = self:InRange(unit)

		if Present(inRange) then
			frame:SetAlphaFromBoolean(inRange, alpha, math.min(alpha, range))

			return
		end
	end

	frame:SetAlpha(alpha)
end

function Fading:UpdateAll()
	self.idle = self:IsIdle(self.inCombat, UnitExists("target"), Casting())

	for _, key in ipairs(FADED) do
		for _, frame in ipairs(AUI.Frames.objects[key] or {}) do
			self:Update(frame)
		end
	end

	self:UpdateTicker()
end

---Runs the range ticker only while target or focus exists and has its range fade on.
function Fading:UpdateTicker()
	local config = AUI.Profile.config
	local needed = false

	for key, unit in pairs(RANGE_UNITS) do
		if self:Alpha(config, key, "range") and UnitExists(unit) then
			needed = true
		end
	end

	if needed and not self.ticker then
		self.ticker = C_Timer.NewTicker(RANGE_INTERVAL, function()
			for key in pairs(RANGE_UNITS) do
				for _, frame in ipairs(AUI.Frames.objects[key] or {}) do
					self:Update(frame)
				end
			end
		end)
	elseif not needed and self.ticker then
		self.ticker:Cancel()
		self.ticker = nil
	end
end

---Watches what fading depends on: combat, target and focus, the player's casts, and the spells known.
function Fading:Start()
	self.inCombat = InCombatLockdown()
	self:FindSpells()

	AUI.Events:Register("PLAYER_REGEN_DISABLED", self, function()
		self.inCombat = true
		self:UpdateAll()
	end)
	AUI.Events:Register("PLAYER_REGEN_ENABLED", self, function()
		self.inCombat = false
		self:UpdateAll()
	end)
	AUI.Events:Register("PLAYER_TARGET_CHANGED", self, self.UpdateAll)
	AUI.Events:Register("PLAYER_FOCUS_CHANGED", self, self.UpdateAll)
	AUI.Events:Register("SPELLS_CHANGED", self, self.FindSpells)

	for _, event in ipairs(CAST_EVENTS) do
		AUI.Events:Register(event, self, function(_, _, unit)
			if unit == "player" then
				self:UpdateAll()
			end
		end)
	end

	AUI.Callbacks:Register("Profile", self, self.UpdateAll)
	self.started = true
	self:UpdateAll()
end
