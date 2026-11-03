local AUI = select(2, ...)

local Options = AUI.UnitFrameOptions

-- Settings that change a secure frame or an aura container, which wait for combat to end.
local LAYOUT = {
	width = true, height = true, position = true, text = true, buffs = true, debuffs = true, auras = true, enabled = true,
	bars = true, power = true, attach = true, attachX = true, attachY = true, extraMana = true, extraManaHeight = true, spacing = true,
}

-- The keys of the player's resources' settings.
local RESOURCES = { resources = true }

for _, spec in ipairs(Options.RESOURCES) do
	RESOURCES[spec.key] = spec
end

---Owns AeonUI's oUF frames: spawns those switched on when the session starts, applies the active profile, and holds
---back changes to secure frames until combat ends, keeping only the latest. oUF hides a unit's Blizzard frame as it
---spawns AeonUI's and cannot show it again, so switching a frame on or off takes effect at the next reload.
---@class AUIFrames
---@field objects table<string, AUIUnitFrame> frames spawned this session, by key
---@field started boolean
---@field layoutPending boolean a layout change waits for combat to end
---@field watching boolean? settings changes are followed
---@field sampled table<string, boolean>? the frames edit mode has on the player, by key
---@field samplePending boolean? a sample's change waits for combat to end
local Frames = {
	objects = {},
	started = false,
	layoutPending = false,
}
AUI.Frames = Frames

---@param key string
---@return boolean on the frame's switch is on
function Frames:IsOn(key)
	return AUI.Profile:Get(Options:Path(key, "enabled")) == true
end

---@return boolean needed a frame's switch differs from what this session spawned
function Frames:ReloadNeeded()
	for _, spec in ipairs(Options.FRAMES) do
		if self:IsOn(spec.key) ~= (self.objects[spec.key] ~= nil) then
			return true
		end
	end

	return false
end

---Spawns the frames that are on. With none on, this only listens for a resource being turned on: no style, no tags, no
---events. In combat, waits for combat to end first.
function Frames:Start()
	if self.started then
		return
	end

	if not self.watching then
		self.watching = true
		AUI.Callbacks:Register("Profile", self, self.OnProfileChanged)
	end

	local any = false

	for _, spec in ipairs(Options.FRAMES) do
		any = any or self:IsOn(spec.key)
	end

	any = any or Options:ResourcesOn()

	if not any then
		return
	end

	if InCombatLockdown() then
		AUI.Events:Register("PLAYER_REGEN_ENABLED", self, self.Start)

		return
	end

	self.started = true

	local oUF = AUI.oUF
	local UnitFrame = AUI.UnitFrame

	AUI.Tags:Register()
	AUI.Indicators:Register()
	oUF:RegisterStyle("AeonUI", UnitFrame.Style)
	oUF:RegisterStyle("AeonUIPlayerPower", AUI.PlayerPower.Style)
	oUF:RegisterStyle("AeonUIClassPower", AUI.ClassPower.Style)
	oUF:SetActiveStyle("AeonUI")

	ClickCastFrames = ClickCastFrames or {}

	for _, spec in ipairs(Options.FRAMES) do
		if self:IsOn(spec.key) then
			UnitFrame.specs[spec.unit] = spec

			local frame = oUF:Spawn(spec.unit, spec.name)

			self.objects[spec.key] = frame
			ClickCastFrames[frame] = true
		end
	end

	self:SpawnResources()
	AUI.Events:Register("PLAYER_REGEN_ENABLED", self, self.OnCombatEnded)
	AUI.Events:Register("UI_SCALE_CHANGED", self, self.OnScaleChanged)

	local media = LibStub("LibSharedMedia-3.0") --[[@as table]]

	media.RegisterCallback(self, "LibSharedMedia_Registered", "OnMediaRegistered")

	self:ApplyAll(true)
	AUI.Fading:Start()
end

---Spawns the resource frames once they are turned on; in combat, waits for combat to end. They stand beside whatever
---shows the player: oUF would hide Blizzard's player frame as it spawns another frame for the unit, so that step is
---skipped for them, and Blizzard's frame goes only with AeonUI's.
function Frames:SpawnResources()
	local oUF = AUI.oUF

	if not Options:ResourcesOn() then
		return
	end

	for _, spec in ipairs(Options.RESOURCES) do
		if not self.objects[spec.key] then
			if InCombatLockdown() then
				self.layoutPending = true

				return
			end

			local disable = oUF.DisableBlizzard

			oUF.DisableBlizzard = function() end
			oUF:SetActiveStyle(spec.style)
			self.objects[spec.key] = oUF:Spawn(spec.unit, spec.name)
			oUF.DisableBlizzard = disable
		end
	end
end

---@param key string
---@param layout boolean also apply size and position
function Frames:Apply(key, layout)
	local frame = self.objects[key]

	if not frame then
		return
	end

	if layout then
		if InCombatLockdown() then
			self.layoutPending = true
		else
			frame:ApplyLayout()
		end
	end

	frame:ApplyAppearance()
end

---@param layout boolean also apply size and position
function Frames:ApplyAll(layout)
	for key in pairs(self.objects) do
		self:Apply(key, layout)
	end
end

---@param path string? the changed setting, or nil when the whole profile may differ
function Frames:OnProfileChanged(path)
	if not self.started then
		self:Start()

		return
	end

	if not path then
		self:SpawnResources()
		self:ApplyAll(true)

		return
	end

	local key, setting = path:match("^frames%.(%a+)%.([^.]+)")

	if key and RESOURCES[key] then
		-- The class resource stands on the power bar, so a change to one can move the other.
		self:SpawnResources()
		self:ApplyAll(LAYOUT[setting] == true)
	elseif key == "all" then
		self:ApplyAll(LAYOUT[setting] == true)
	elseif key then
		self:Apply(key, LAYOUT[setting] == true)
	end
end

---Shows a frame whose unit may not exist on the player while edit mode is open, so it has a mover: the unit watch hides
---it otherwise, and its unit is a secure attribute. Out of combat only; in combat, waits for combat to end.
---@param key string
---@param shown boolean
function Frames:SampleUnit(key, shown)
	local frame = self.objects[key]

	self.sampled = self.sampled or {}
	self.sampled[key] = shown

	if not frame then
		return
	end

	if InCombatLockdown() then
		self.samplePending = true

		return
	end

	frame:SetAttribute("unit", shown and "player" or frame.spec.unit)
end

function Frames:OnCombatEnded()
	if self.samplePending then
		self.samplePending = false

		for key, shown in pairs(self.sampled) do
			self:SampleUnit(key, shown)
		end
	end

	if self.layoutPending then
		self.layoutPending = false
		self:SpawnResources()
		self:ApplyAll(true)
	end
end

---A border or bar texture another addon registers after login can be the one a frame's setting names.
---@param _ string the callback's name
---@param kind string
function Frames:OnMediaRegistered(_, kind)
	if kind == "border" or kind == "statusbar" then
		AUI.Events:Coalesce("unitFramesMedia", function()
			self:ApplyAll(false)
		end)
	end
end

function Frames:OnScaleChanged()
	self:ApplyAll(true)
end
