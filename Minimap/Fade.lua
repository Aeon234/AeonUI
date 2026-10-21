local AUI = select(2, ...)

local Schema = AUI.Schema

-- Seconds a fade takes from fully shown to fully faded.
local DURATION = 0.2

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
---is hidden, so the map stays clickable. Runs an OnUpdate only while a fade is in progress.
---@class AUIMinimapFade
---@field frame Frame? the faded frame
---@field alpha number
---@field target number
---@field hovered boolean the mouse is over the minimap
---@field inCombat boolean
---@field driver Frame?
---@field OnUpdate fun(frame: Frame, elapsed: number)?
local Fade = {
	alpha = 1,
	target = 1,
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
	self.frame = frame
	self.driver = CreateFrame("Frame")
	self.OnUpdate = function(_, elapsed)
		self:Step(elapsed)
	end
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
		self:Refresh()
	end
end

---Sets the target opacity from the settings and starts the fade toward it.
function Fade:Refresh()
	local driver = self.driver

	if not driver then
		return
	end

	self.target = self:Target(self:Settings(), self.hovered, self.inCombat)

	if self.alpha ~= self.target then
		driver:SetScript("OnUpdate", self.OnUpdate)
	end
end

---@param elapsed number
function Fade:Step(elapsed)
	local step = elapsed / DURATION

	if self.alpha < self.target then
		self.alpha = math.min(self.target, self.alpha + step)
	else
		self.alpha = math.max(self.target, self.alpha - step)
	end

	(self.frame --[[@as Frame]]):SetAlpha(self.alpha)

	if self.alpha == self.target then
		(self.driver --[[@as Frame]]):SetScript("OnUpdate", nil)
	end
end
