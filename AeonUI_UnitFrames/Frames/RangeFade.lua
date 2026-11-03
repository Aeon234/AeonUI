local AUI = select(2, ...)

local lib = LibStub("LibAeonSettings-1.0")
local Options = AUI.UnitFrameOptions

-- Seconds between range checks while a faded frame's unit exists.
local INTERVAL = 0.2

---A frame's fade while its unit is beyond a spell the player knows. It fades `frame.Content`, the layer holding the
---frame's parts, so it never meets the idle fade on the frame itself. A readable range moves the opacity on the settings
---library's spring; a secret one goes through `SetAlphaFromBoolean`, so Lua never reads it and it snaps. An unmeasurable
---range counts as in range. Opacity is not protected, so this also runs in combat. Follows events only while a spawned
---frame has the fade on, and runs its ticker only while such a frame's unit exists.
---@class AUIRangeFade
---@field following boolean the events are registered
---@field harmful integer? the spell measuring range to an enemy
---@field helpful integer? the spell measuring range to a friend
---@field ticker table? repeats the range check
local RangeFade = {
	following = false,
}
AUI.RangeFade = RangeFade

---@param key string
---@return number? alpha the opacity beyond range, 0 to 1, or nil when the frame has no such fade or it is off
function RangeFade:Alpha(key)
	local spec = Options:Spec(key)

	if not spec or not spec.rangeFade or not AUI.Profile:Get(Options:Path(key, "fade.range.enabled")) then
		return nil
	end

	return AUI.Profile:Get(Options:Path(key, "fade.range.alpha")) / 100
end

---@param list integer[]?
---@return integer? spellID the first spell in the list the player knows
local function FirstKnown(list)
	for _, spellID in ipairs(list or {}) do
		if C_SpellBook.IsSpellKnownOrInSpellBook(spellID) then
			return spellID
		end
	end
end

function RangeFade:FindSpells()
	local spells = AUI.RangeSpells
	local _, class = UnitClass("player")

	self.harmful = FirstKnown(spells.harmful[class])
	self.helpful = FirstKnown(spells.helpful[class])
end

---@param unit string
---@return boolean? inRange possibly secret; nil when it cannot be measured
function RangeFade:InRange(unit)
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

---@param frame table
---@return table fade the frame's spring and the state of its opacity, made the first time it fades
local function Fade(frame)
	local fade = frame.rangeFade

	if not fade then
		local content = frame.Content

		fade = { goal = 1 }
		fade.spring = lib:CreateSpring(1, function(value)
			content:SetAlpha(value)
		end, { damping = 1 })
		frame.rangeFade = fade
	end

	return fade
end

---Moves a frame's parts toward a readable opacity. After a secret range the opacity is unknown, so it jumps instead.
---@param frame table
---@param target number
local function Move(frame, target)
	if target == 1 and not frame.rangeFade then
		return
	end

	local fade = Fade(frame)
	local spring = fade.spring

	if fade.secret then
		fade.secret = false
		fade.goal = target
		spring:Jump(target)
	elseif fade.goal ~= target then
		fade.goal = target
		spring.response = AUI.Fading:Response(target, spring.value)
		spring:To(target)
	end
end

---@param frame table
function RangeFade:Update(frame)
	local alpha = self:Alpha(frame.key)
	local unit = frame.spec.unit

	if not alpha or not UnitExists(unit) then
		Move(frame, 1)

		return
	end

	local inRange = self:InRange(unit)

	if issecretvalue(inRange) then
		local fade = Fade(frame)

		fade.spring:Stop()
		fade.secret = true
		frame.Content:SetAlphaFromBoolean(inRange, 1, alpha)

		return
	end

	Move(frame, inRange == false and alpha or 1)
end

function RangeFade:UpdateFrames()
	for _, frame in pairs(AUI.Frames.objects) do
		if frame.spec.rangeFade then
			self:Update(frame)
		end
	end
end

---Registers or drops the events the fade depends on.
---@param needed boolean
function RangeFade:Follow(needed)
	if needed == self.following then
		return
	end

	self.following = needed

	if not needed then
		AUI.Events:UnregisterAll(self)

		return
	end

	self:FindSpells()
	AUI.Events:Register("PLAYER_TARGET_CHANGED", self, self.UpdateAll)
	AUI.Events:Register("SPELLS_CHANGED", self, self.OnSpellsChanged)
end

function RangeFade:OnSpellsChanged()
	self:FindSpells()
	self:UpdateAll()
end

---Starts or stops the ticker.
---@param needed boolean
function RangeFade:Tick(needed)
	if needed and not self.ticker then
		self.ticker = C_Timer.NewTicker(INTERVAL, function()
			self:UpdateFrames()
		end)
	elseif not needed and self.ticker then
		self.ticker:Cancel()
		self.ticker = nil
	end
end

function RangeFade:UpdateAll()
	local following, ticking = false, false

	for key, frame in pairs(AUI.Frames.objects) do
		if self:Alpha(key) then
			following = true
			ticking = ticking or UnitExists(frame.spec.unit)
		end
	end

	self:Follow(following)
	self:Tick(ticking)
	self:UpdateFrames()
end

function RangeFade:Start()
	AUI.Callbacks:Register("Profile", self, self.UpdateAll)
	self:UpdateAll()
end
