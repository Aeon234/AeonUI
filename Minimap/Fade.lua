local AUI = select(2, ...)

local Schema = AUI.Schema

-- Seconds a fade takes from fully shown to fully faded.
local DURATION = 0.2
local GROUPS = { "rows", "map" }

for _, group in ipairs(GROUPS) do
	local base = "minimap.fade." .. group

	Schema:Boolean(base .. ".mouseover", false)
	Schema:Number(base .. ".mouseoverOpacity", 30, 0, 100, true)
	Schema:Boolean(base .. ".combat", false)
	Schema:Number(base .. ".combatOpacity", 50, 0, 100, true)
end

---@class AUIMinimapFadeSettings
---@field mouseover boolean
---@field mouseoverOpacity number percent
---@field combat boolean
---@field combatOpacity number percent

---@class AUIMinimapFadeGroup
---@field regions Region[]
---@field alpha number
---@field target number

---Fades the minimap's rows and its map, separately, while the mouse is away or in combat. Fading only: nothing is
---hidden, so the map stays clickable. Runs an OnUpdate only while a fade is in progress.
---@class AUIMinimapFade
---@field groups table<string, AUIMinimapFadeGroup>
---@field hovered boolean the mouse is over the assembly
---@field inCombat boolean
---@field driver Frame?
---@field OnUpdate fun(frame: Frame, elapsed: number)?
local Fade = {
	groups = {},
	hovered = false,
	inCombat = false,
}
AUI.MinimapFade = Fade

---@param settings AUIMinimapFadeSettings
---@param hovered boolean
---@param inCombat boolean
---@return number alpha the group's opacity, 0 to 1
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

---@param group string
---@return AUIMinimapFadeSettings
function Fade:Settings(group)
	local Profile, base = AUI.Profile, "minimap.fade." .. group .. "."

	return {
		mouseover = Profile:Get(base .. "mouseover"),
		mouseoverOpacity = Profile:Get(base .. "mouseoverOpacity"),
		combat = Profile:Get(base .. "combat"),
		combatOpacity = Profile:Get(base .. "combatOpacity"),
	}
end

---@param regions table<string, Region[]> each group's regions: `rows` and `map`
function Fade:Start(regions)
	for _, group in ipairs(GROUPS) do
		self.groups[group] = { regions = regions[group], alpha = 1, target = 1 }
	end

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

---Sets each group's target opacity from its settings and starts the fade toward it.
function Fade:Refresh()
	local driver = self.driver

	if not driver then
		return
	end

	local moving = false

	for name, group in pairs(self.groups) do
		group.target = self:Target(self:Settings(name), self.hovered, self.inCombat)
		moving = moving or group.alpha ~= group.target
	end

	if moving then
		driver:SetScript("OnUpdate", self.OnUpdate)
	end
end

---@param elapsed number
function Fade:Step(elapsed)
	local step, moving = elapsed / DURATION, false

	for _, group in pairs(self.groups) do
		if group.alpha ~= group.target then
			if group.alpha < group.target then
				group.alpha = math.min(group.target, group.alpha + step)
			else
				group.alpha = math.max(group.target, group.alpha - step)
			end

			for _, region in ipairs(group.regions) do
				region:SetAlpha(group.alpha)
			end

			moving = moving or group.alpha ~= group.target
		end
	end

	if not moving then
		(self.driver --[[@as Frame]]):SetScript("OnUpdate", nil)
	end
end
