local AUI = select(2, ...)

local lib = LibStub("LibAeonSettings-1.0")
local Options = AUI.UnitFrameOptions

-- Seconds a fade's spring takes to reach its target: coming in answers at once, going out is a little slower.
local RESPONSE_IN = 0.15
local RESPONSE_OUT = 0.2
-- An opacity this close to full is full.
local FULL = 0.999

-- Player events that start or end a cast, which ends or begins idleness.
local CAST_EVENTS = {
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_EMPOWER_START",
	"UNIT_SPELLCAST_EMPOWER_STOP",
}

---A frame's fade, made the first time it fades.
---@class AUIFrameFade
---@field spring table the opacity at full health, on the settings library's spring
---@field curve table full health to that opacity, anything less to full opacity
---@field value number? the opacity the curve holds

---Frame opacity: the idle fade, while the player is out of combat, has no target and is not casting, at full health and
---with the mouse away. Health can be secret, so the client applies that rule: the opacity goes through a step curve
---into `SetAlpha`, and Lua never reads it. The opacity moves on the settings library's spring, from wherever it is, and
---jumps with Reduce Motion; a change of health alone has no motion, since Lua cannot tell it happened. Opacity is not
---protected, so this also runs in combat. Follows events only while a spawned frame has the fade on.
---@class AUIFading
---@field inCombat boolean
---@field idle boolean
---@field following boolean the events are registered
local Fading = {
	inCombat = false,
	idle = false,
	following = false,
}
AUI.Fading = Fading

---@param key string
---@return number? alpha the opacity to fade to, 0 to 1, or nil when the frame has no such fade or it is off
function Fading:IdleAlpha(key)
	local spec = Options:Spec(key)

	if not spec or not spec.idleFade or not AUI.Profile:Get(Options:Path(key, "fade.idle.enabled")) then
		return nil
	end

	return AUI.Profile:Get(Options:Path(key, "fade.idle.alpha")) / 100
end

---@param inCombat boolean
---@param hasTarget boolean
---@param casting boolean
---@return boolean idle
function Fading:IsIdle(inCombat, hasTarget, casting)
	return not inCombat and not hasTarget and not casting
end

---@param idle boolean
---@param hovered boolean?
---@param alpha number? the frame's idle opacity, nil when its fade is off
---@return number target the opacity the frame moves to at full health
function Fading:Target(idle, hovered, alpha)
	if idle and not hovered and alpha then
		return alpha
	end

	return 1
end

---@param target number
---@param current number
---@return number response the spring's response toward the target
function Fading:Response(target, current)
	return target >= current and RESPONSE_IN or RESPONSE_OUT
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

---Sets a frame's opacity from the spring's: that opacity at full health, full opacity below it.
---@param frame table
---@param fade AUIFrameFade
---@param value number
local function Paint(frame, fade, value)
	if value >= FULL then
		frame:SetAlpha(1)

		return
	end

	if fade.value ~= value then
		fade.value = value
		fade.curve:ClearPoints()
		fade.curve:AddPoint(0, 1)
		fade.curve:AddPoint(1, value)
	end

	frame:SetAlpha(UnitHealthPercent(frame.spec.unit, true, fade.curve) --[[@as number]])
end

---@param frame table
---@return AUIFrameFade fade
local function Fade(frame)
	local fade = frame.idleFade

	if not fade then
		local curve = C_CurveUtil.CreateCurve()

		curve:SetType(Enum.LuaCurveType.Step)
		fade = { curve = curve }
		fade.spring = lib:CreateSpring(1, function(value)
			Paint(frame, fade, value)
		end, { damping = 1 })
		frame.idleFade = fade
	end

	return fade
end

---Moves a frame toward the opacity it should have now.
---@param frame table
function Fading:Update(frame)
	local target = self:Target(self.idle, frame.hovered, self:IdleAlpha(frame.key))

	if target >= FULL and not frame.idleFade then
		frame:SetAlpha(1)

		return
	end

	local spring = Fade(frame).spring

	spring.response = self:Response(target, spring.value)
	spring:To(target)
end

function Fading:OnCombatStart()
	self.inCombat = true
	self:UpdateAll()
end

function Fading:OnCombatEnd()
	self.inCombat = false
	self:UpdateAll()
end

---@param _ string the event
---@param unit string
function Fading:OnCastEvent(_, unit)
	if unit == "player" then
		self:UpdateAll()
	end
end

---The client works out the opacity again for the unit's new health.
---@param _ string the event
---@param unit string
function Fading:OnHealth(_, unit)
	for _, frame in pairs(AUI.Frames.objects) do
		local fade = frame.idleFade

		if fade and frame.spec.unit == unit then
			Paint(frame, fade, fade.spring.value)
		end
	end
end

---Registers or drops the events the fade depends on.
---@param needed boolean
function Fading:Follow(needed)
	if needed == self.following then
		return
	end

	self.following = needed

	if not needed then
		AUI.Events:UnregisterAll(self)

		return
	end

	self.inCombat = InCombatLockdown()
	AUI.Events:Register("PLAYER_REGEN_DISABLED", self, self.OnCombatStart)
	AUI.Events:Register("PLAYER_REGEN_ENABLED", self, self.OnCombatEnd)
	AUI.Events:Register("PLAYER_TARGET_CHANGED", self, self.UpdateAll)
	AUI.Events:Register("UNIT_HEALTH", self, self.OnHealth)
	AUI.Events:Register("UNIT_MAXHEALTH", self, self.OnHealth)

	for _, event in ipairs(CAST_EVENTS) do
		AUI.Events:Register(event, self, self.OnCastEvent)
	end
end

function Fading:UpdateAll()
	local needed = false

	for key in pairs(AUI.Frames.objects) do
		needed = needed or self:IdleAlpha(key) ~= nil
	end

	self:Follow(needed)
	self.idle = needed and self:IsIdle(self.inCombat, UnitExists("target"), Casting())

	for _, frame in pairs(AUI.Frames.objects) do
		self:Update(frame)
	end
end

function Fading:Start()
	AUI.Callbacks:Register("Profile", self, self.UpdateAll)
	self:UpdateAll()
end
