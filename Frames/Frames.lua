local AUI = select(2, ...)

---@class AUIFrameSpec
---@field key string the frame's key under `frames` in the profile
---@field unit string
---@field name string the frame's global name
---@field style string
---@field count integer? for a group: how many slots, each spawned for the unit and global name followed by its number

-- Frames in creation order.
---@type AUIFrameSpec[]
local SPECS = {
	{ key = "player", unit = "player", name = "AeonUIPlayer", style = "AeonUI" },
	{ key = "target", unit = "target", name = "AeonUITarget", style = "AeonUI" },
	{ key = "targettarget", unit = "targettarget", name = "AeonUITargetTarget", style = "AeonUI" },
	{ key = "focus", unit = "focus", name = "AeonUIFocus", style = "AeonUI" },
	{ key = "boss", unit = "boss", name = "AeonUIBoss", style = "AeonUI", count = MAX_BOSS_FRAMES or 5 },
	{ key = "playerPower", unit = "player", name = "AeonUIPlayerPower", style = "AeonUIPower" },
	{ key = "classPower", unit = "player", name = "AeonUIClassPower", style = "AeonUIClassPower" },
}

-- Settings that change a secure frame, which waits for combat to end.
local LAYOUT = {
	enabled = true, width = true, height = true, x = true, y = true, power = true, growth = true, spacing = true,
	castbar = true, buffs = true, debuffs = true, attach = true, extraMana = true, extraManaHeight = true,
}

---Owns AeonUI's oUF frames: creates them, applies the active profile, and holds back changes to secure frames until
---combat ends, keeping only the latest.
---@class AUIFrames
---@field objects table<string, AUIUnitFrame[]> frames by key: one, or a group's slots in order
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

	-- Blizzard's own frames stay: they parent the pet, class resource and target-of-target frames. oUF's Castbar on the
	-- player still takes over Blizzard's player cast bar.
	oUF.DisableBlizzard = function() end

	AUI.Tags:Register()
	oUF:RegisterStyle("AeonUI", UnitFrame.HealthStyle)
	oUF:RegisterStyle("AeonUIPower", UnitFrame.PowerStyle)
	oUF:RegisterStyle("AeonUIClassPower", AUI.ClassPower.Style)

	for _, spec in ipairs(SPECS) do
		local frames = {}

		oUF:SetActiveStyle(spec.style)

		for slot = 1, spec.count or 1 do
			local suffix = spec.count and slot or ""
			local unit = spec.unit .. suffix

			UnitFrame.keys[unit] = spec.key
			frames[slot] = oUF:Spawn(unit, spec.name .. suffix)
			frames[slot].slot = spec.count and slot or nil
			UnitFrame.keys[unit] = nil
		end

		self.objects[spec.key] = frames
	end

	self.started = true

	AUI.CastBar:Start()
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
	local config = AUI.Profile.config
	local defer = layout and InCombatLockdown()

	if defer then
		self.layoutPending = true
	end

	for _, frame in ipairs(self.objects[key]) do
		if layout and not defer then
			frame:ApplyLayout(config)
		end

		frame:ApplyAppearance(config)
	end
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
		self:Apply(spec.key, true)
	end
end

function Frames:OnScaleChanged()
	for _, spec in ipairs(SPECS) do
		for _, frame in ipairs(self.objects[spec.key]) do
			frame:UpdateBorder()
		end

		self:Apply(spec.key, false)
	end
end
