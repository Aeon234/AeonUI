local AUI = select(2, ...)

local Options = AUI.NotificationOptions

local EVENTS = { "PLAYER_ENTERING_WORLD", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" }
local UNIT_EVENTS = { "UNIT_HEALTH", "UNIT_MAXHEALTH" }

---Low Health, while the player is alive, in combat or out of it. Its line is drawn through a curve of the player's
---health, so the health is never read.
---@class AUIHealthNotice
---@field following boolean the events are registered
---@field curve table? the health curve for the mark it was built for
---@field curveMark number?
local HealthNotice = {
	following = false,
}
AUI.HealthNotice = HealthNotice

---@return table curve the health curve for the current mark
function HealthNotice:Curve()
	local mark = AUI.Profile:Get(Options.LOW_HEALTH_PATH)

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

---Shows Low Health's line through the curve while the player is alive, and dismisses it otherwise.
function HealthNotice:Check()
	if self.following and not UnitIsDeadOrGhost("player") then
		local alpha = UnitHealthPercent("player", true, self:Curve()) --[[@as number]]

		AUI.Notifications:Show("lowHealth", nil, { fade = false }):SetAlpha(alpha)
	else
		AUI.Notifications:Dismiss("lowHealth")
	end
end

---Redraws Low Health's line through the curve, as the player's health changes.
function HealthNotice:UpdateHealth()
	local line = AUI.Notifications:Find("health")

	if line and line.key == "lowHealth" then
		line:SetAlpha(UnitHealthPercent("player", true, self:Curve()) --[[@as number]])
	end
end

function HealthNotice:OnEvent()
	self:Check()
end

---@param _ string
---@param unit string
function HealthNotice:OnUnitEvent(_, unit)
	if unit == "player" then
		self:UpdateHealth()
	end
end

function HealthNotice:Apply()
	local wanted = AUI.can.lowHealthNotice == true and Options:On("lowHealth")

	if wanted ~= self.following then
		self.following = wanted

		if wanted then
			for _, event in ipairs(EVENTS) do
				AUI.Events:Register(event, self, self.OnEvent)
			end

			for _, event in ipairs(UNIT_EVENTS) do
				AUI.Events:Register(event, self, self.OnUnitEvent)
			end
		else
			AUI.Events:UnregisterAll(self)
		end
	end

	self:Check()
end
