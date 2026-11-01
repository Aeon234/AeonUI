local AUI = select(2, ...)

local Schema = AUI.Schema
local lib = LibStub("LibAeonSettings-1.0")

-- Seconds a spring takes to reach its target: coming in answers the mouse at once, going out is slower.
local RESPONSE_IN = 0.15
local RESPONSE_OUT = 0.35
-- Seconds the mouse must stay away before the minimap fades, so passing over it does not flicker.
local HOLD = 0.3

Schema:Boolean("minimap.fade.mouseover", false)
Schema:Number("minimap.fade.mouseoverOpacity", 30, 0, 100, true)
Schema:Boolean("minimap.fade.combat", false)
Schema:Number("minimap.fade.combatOpacity", 50, 0, 100, true)

---@class AUIMinimapFadeSettings
---@field mouseover boolean
---@field mouseoverOpacity number percent
---@field combat boolean
---@field combatOpacity number percent

---Fades the whole minimap, map, rows and border together, while the mouse is away or in combat. Fading only: nothing
---is hidden, so the map stays clickable. The opacity moves on the settings library's critically damped spring, from
---wherever it is, and jumps with Reduce Motion.
---@class AUIMinimapFade
---@field spring table? the opacity's spring, made by Start
---@field hovered boolean the mouse is over the minimap
---@field inCombat boolean
---@field timer table? the hold before fading out
local Fade = {
	hovered = false,
	inCombat = false,
}
AUI.MinimapFade = Fade

---@param settings AUIMinimapFadeSettings
---@param hovered boolean
---@param inCombat boolean
---@return number alpha the minimap's opacity, 0 to 1
function Fade:Target(settings, hovered, inCombat)
	if hovered then
		return 1
	end

	local alpha = 1

	if settings.mouseover then
		alpha = math.min(alpha, settings.mouseoverOpacity / 100)
	end

	if settings.combat and inCombat then
		alpha = math.min(alpha, settings.combatOpacity / 100)
	end

	return alpha
end

---@param target number
---@param current number
---@return number response the spring's response toward the target: quicker coming in than going out
function Fade:Response(target, current)
	return target >= current and RESPONSE_IN or RESPONSE_OUT
end

---@return AUIMinimapFadeSettings
function Fade:Settings()
	local Profile = AUI.Profile

	return {
		mouseover = Profile:Get("minimap.fade.mouseover"),
		mouseoverOpacity = Profile:Get("minimap.fade.mouseoverOpacity"),
		combat = Profile:Get("minimap.fade.combat"),
		combatOpacity = Profile:Get("minimap.fade.combatOpacity"),
	}
end

---@param frame Frame the minimap's root frame
function Fade:Start(frame)
	self.spring = lib:CreateSpring(1, function(alpha)
		frame:SetAlpha(alpha)
	end, { damping = 1 })
	self.inCombat = InCombatLockdown()

	AUI.Events:Register("PLAYER_REGEN_DISABLED", self, function()
		self.inCombat = true
		self:Refresh()
	end)
	AUI.Events:Register("PLAYER_REGEN_ENABLED", self, function()
		self.inCombat = false
		self:Refresh()
	end)
end

---@param hovered boolean
function Fade:SetHovered(hovered)
	if hovered ~= self.hovered then
		self.hovered = hovered
		self:Refresh(not hovered)
	end
end

---Sets the target opacity from the settings and moves toward it.
---@param hold boolean? the mouse just left: wait HOLD seconds before fading out
function Fade:Refresh(hold)
	local spring = self.spring

	if not spring then
		return
	end

	if self.timer then
		self.timer:Cancel()
		self.timer = nil
	end

	local target = self:Target(self:Settings(), self.hovered, self.inCombat)

	if hold and target < spring.value then
		self.timer = C_Timer.NewTimer(HOLD, function()
			self.timer = nil
			self:Move(target)
		end)

		return
	end

	self:Move(target)
end

---@param target number
function Fade:Move(target)
	local spring = self.spring --[[@as table]]

	spring.response = self:Response(target, spring.value)
	spring:To(target)
end
