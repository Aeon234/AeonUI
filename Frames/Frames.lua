local AUI = select(2, ...)

---@class AUIFrameSpec
---@field key string the frame's key under `frames` in the profile
---@field unit string
---@field name string the frame's global name
---@field style string

-- Frames in creation order.
---@type AUIFrameSpec[]
local SPECS = {
	{ key = "player", unit = "player", name = "AeonUIPlayer", style = "AeonUI" },
	{ key = "target", unit = "target", name = "AeonUITarget", style = "AeonUI" },
	{ key = "playerPower", unit = "player", name = "AeonUIPlayerPower", style = "AeonUIPower" },
}

-- Settings that change a secure frame, which waits for combat to end.
local LAYOUT = { enabled = true, width = true, height = true, x = true, y = true }

---Owns AeonUI's oUF frames: creates them, applies the active profile, and holds back changes to secure frames until
---combat ends, keeping only the latest.
---@class AUIFrames
---@field objects table<string, AUIUnitFrame> frames by key
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
	local UnitFrame = AUI.UnitFrame

	-- Blizzard's own frames stay: they parent the pet, class resource, cast and target-of-target frames.
	oUF.DisableBlizzard = function() end

	AUI.Tags:Register()
	oUF:RegisterStyle("AeonUI", UnitFrame.HealthStyle)
	oUF:RegisterStyle("AeonUIPower", UnitFrame.PowerStyle)

	for _, spec in ipairs(SPECS) do
		UnitFrame.keys[spec.unit] = spec.key
		oUF:SetActiveStyle(spec.style)
		self.objects[spec.key] = oUF:Spawn(spec.unit, spec.name)
		UnitFrame.keys[spec.unit] = nil
	end

	self.started = true

	AUI.Callbacks:Register("Profile", self, self.OnProfileChanged)
	AUI.Events:Register("PLAYER_REGEN_ENABLED", self, self.OnCombatEnded)
	AUI.Events:Register("UI_SCALE_CHANGED", self, self.OnScaleChanged)

	for _, spec in ipairs(SPECS) do
		self:Apply(spec.key, true)
	end
end

---@param key string
---@param layout boolean also apply size, position and enabled state
function Frames:Apply(key, layout)
	local frame = self.objects[key]
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
		for _, spec in ipairs(SPECS) do
			self:Apply(spec.key, true)
		end

		return
	end

	if path:match("^numbers%.") then
		for _, spec in ipairs(SPECS) do
			self:Apply(spec.key, false)
		end

		return
	end

	local key, setting = path:match("^frames%.(%a+)%.([^.]+)")

	if key and self.objects[key] then
		self:Apply(key, LAYOUT[setting] == true)
	end
end

function Frames:OnCombatEnded()
	if not self.layoutPending then
		return
	end

	self.layoutPending = false

	for _, spec in ipairs(SPECS) do
		self.objects[spec.key]:ApplyLayout(AUI.Profile.config)
	end
end

function Frames:OnScaleChanged()
	for _, spec in ipairs(SPECS) do
		self.objects[spec.key]:UpdateBorder()
	end
end
