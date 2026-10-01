local AUI = select(2, ...)

local STYLE = "AeonUI"

-- Units in creation order, and their frame names.
local UNITS = { "player", "target" }
local NAMES = { player = "AeonUIPlayer", target = "AeonUITarget" }

-- Settings that change a secure frame, which waits for combat to end.
local LAYOUT = { enabled = true, width = true, height = true, x = true, y = true }

---Owns AeonUI's oUF frames: creates them, applies the active profile, and holds back changes to secure frames until
---combat ends, keeping only the latest.
---@class AUIFrames
---@field objects table<string, table> frames by unit
---@field started boolean
---@field layoutPending boolean a layout change waits for combat to end
local Frames = {
	objects = {},
	started = false,
	layoutPending = false,
}
AUI.Frames = Frames

---Creates the frames and applies the profile. In combat, waits for combat to end first.
function Frames:Start()
	if self.started then
		return
	end

	if InCombatLockdown() then
		AUI.Events:Register("PLAYER_REGEN_ENABLED", self, self.Start)

		return
	end

	local oUF = AUI.oUF

	-- Blizzard's own frames stay: they parent the pet, class resource, cast and target-of-target frames.
	oUF.DisableBlizzard = function() end

	AUI.Tags:Register()
	oUF:RegisterStyle(STYLE, AUI.UnitFrame.Style)
	oUF:SetActiveStyle(STYLE)

	for _, unit in ipairs(UNITS) do
		self.objects[unit] = oUF:Spawn(unit, NAMES[unit])
	end

	self.started = true

	AUI.Callbacks:Register("Profile", self, self.OnProfileChanged)
	AUI.Events:Register("PLAYER_REGEN_ENABLED", self, self.OnCombatEnded)
	AUI.Events:Register("UI_SCALE_CHANGED", self, self.OnScaleChanged)

	for _, unit in ipairs(UNITS) do
		self:Apply(unit, true)
	end
end

---@param unit string
---@param layout boolean also apply size, position and enabled state
function Frames:Apply(unit, layout)
	local frame = self.objects[unit]
	local config = AUI.Profile.config

	if layout then
		if InCombatLockdown() then
			self.layoutPending = true
		else
			frame:ApplyLayout(config)
		end
	end

	frame:ApplyAppearance(config)
end

---@param path string? the changed setting, or nil when the whole profile may differ
function Frames:OnProfileChanged(path)
	if not path then
		for _, unit in ipairs(UNITS) do
			self:Apply(unit, true)
		end

		return
	end

	if path:match("^numbers%.") then
		for _, unit in ipairs(UNITS) do
			self:Apply(unit, false)
		end

		return
	end

	local unit, setting = path:match("^frames%.(%a+)%.([^.]+)")

	if unit and self.objects[unit] then
		self:Apply(unit, LAYOUT[setting] == true)
	end
end

function Frames:OnCombatEnded()
	if not self.layoutPending then
		return
	end

	self.layoutPending = false

	for _, unit in ipairs(UNITS) do
		self.objects[unit]:ApplyLayout(AUI.Profile.config)
	end
end

function Frames:OnScaleChanged()
	for _, unit in ipairs(UNITS) do
		self.objects[unit]:UpdateBorder()
	end
end
