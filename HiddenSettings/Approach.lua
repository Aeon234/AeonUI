local AUI = select(2, ...)

local Options = AUI.HiddenSettingsOptions
local Target = AUI.SparkleTarget
local Glints = AUI.LootSparkleGlints

local EVENTS = { "PLAYER_SOFT_INTERACT_CHANGED", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "QUEST_LOG_UPDATE",
	"PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }

---Glints on approached ore, herbs, quest objects and corpses with loot, each its own row (Forever). While any row is on,
---interaction soft targeting is held all around and far (`softTarget` holder), and the game's nameplate on the target,
---the gate, is open only while the target should sparkle, so NPCs and mailboxes get none. Target changes come from
---events; a ticker follows range while a soft target exists, out of combat. Nothing runs while every row is off. The
---gate closes as combat starts, since console variables wait out combat.
---@class AUIApproachSparkles
---@field holder AUICVarHolder? created at start, before any row can turn on
---@field active boolean a row is on: the soft target is held and events registered
---@field gateOpen boolean? the gate asked for; nil to write it again
---@field retarget boolean the soft target moved to another object, so the glints start over even on the same plate
---@field ticker table? the range check while a soft target exists
---@field state string? the state the glints show, for the probe and the offline checks
local ApproachSparkles = {
	active = false,
	retarget = false,
}
AUI.ApproachSparkles = ApproachSparkles

---@return boolean
local function AnyRow()
	for _, kind in ipairs(Options.SPARKLE_TYPES) do
		if AUI.HiddenSettings:IsSparkle(kind) then
			return true
		end
	end

	return false
end

---Creates the holder, and gives back values a hold left saved while every row is off.
function ApproachSparkles:Start()
	local HiddenSettings = AUI.HiddenSettings

	self.holder = AUI.CreateCVarHolder("softTarget", Options.SOFT_TARGET, {}, function()
		return HiddenSettings:Save("softTarget")
	end, function()
		HiddenSettings:ClearSave("softTarget")
	end)

	if not AnyRow() and HiddenSettings:HasSave("softTarget") then
		self.holder:Release()
	end

	self:Refresh()
end

---Follows the rows: holds and listens while any is on, otherwise stops everything and gives the values back.
function ApproachSparkles:Refresh()
	if not self.holder then
		return
	end

	local active = AUI.can.approachSparkles == true and AnyRow()

	if active == self.active then
		if active then
			self:Evaluate()
		end

		return
	end

	self.active = active

	if active then
		self.gateOpen = nil
		self.holder:Hold()

		for _, event in ipairs(EVENTS) do
			AUI.Events:Register(event, self, self.OnEvent)
		end

		self:Evaluate()

		return
	end

	for _, event in ipairs(EVENTS) do
		AUI.Events:Unregister(event, self)
	end

	self:StopTicker()
	Glints:Release()
	self.state = nil
	self.gateOpen = nil
	self.holder:Release()
	self.holder:Change(Options.GATE, "0")
end

---@param open boolean
function ApproachSparkles:SetGate(open)
	if open == self.gateOpen then
		return
	end

	local holder = self.holder --[[@as AUICVarHolder]]

	self.gateOpen = open
	holder:Change(Options.GATE, open and "1" or "0")
end

function ApproachSparkles:StartTicker()
	if self.ticker then
		return
	end

	self.ticker = C_Timer.NewTicker(Options.POLL_INTERVAL, function()
		ApproachSparkles:Evaluate()
	end)
end

function ApproachSparkles:StopTicker()
	if self.ticker then
		self.ticker:Cancel()
		self.ticker = nil
	end
end

function ApproachSparkles:Hide()
	Glints:Release()
	self.state = nil
end

---Finds the soft target and brings the gate, the ticker and the glints in line with it.
function ApproachSparkles:Evaluate()
	if not self.active then
		return
	end

	local unit, plate = Target:Resolve()

	if not unit then
		self:StopTicker()
		self:SetGate(false)
		self:Hide()

		return
	end

	if InCombatLockdown() then
		self:SetGate(false)
		self:Hide()

		return
	end

	self:StartTicker()

	local HiddenSettings = AUI.HiddenSettings
	local kind, unable = Target:Classify(unit, HiddenSettings:IsSparkle("questObjects"))

	if not kind or not HiddenSettings:IsSparkle(kind) then
		self:SetGate(false)
		self:Hide()

		return
	end

	self:SetGate(true)

	if not plate then
		self:Hide()

		return
	end

	local state = Options.State(Target.InRange(unit), unable)

	if Glints:Anchor() ~= plate or self.retarget then
		self.retarget = false
		Glints:Attach(plate, state)
	else
		Glints:Propose(state, GetTime())
	end

	self.state = Glints.shown
end

---@param event string
function ApproachSparkles:OnEvent(event, ...)
	if event == "PLAYER_SOFT_INTERACT_CHANGED" then
		local old, new = AUI:Readable((...)), AUI:Readable((select(2, ...)))

		if type(old) == "string" and type(new) == "string" and old ~= new then
			self.retarget = Glints:Anchor() ~= nil
		end

		self:Evaluate()
	elseif event == "NAME_PLATE_UNIT_ADDED" then
		Target:AddPlate((...))
		self:Evaluate()
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		local unit = ...
		local plate = Target.Plate(unit)

		Target:RemovePlate(unit)

		if plate and plate == Glints:Anchor() then
			self:Hide()
		end
	elseif event == "QUEST_LOG_UPDATE" then
		Target:MarkQuestsDirty()
	elseif event == "PLAYER_ENTERING_WORLD" then
		local holder = self.holder --[[@as AUICVarHolder]]

		holder:Apply()
	elseif event == "PLAYER_REGEN_DISABLED" then
		self:StopTicker()
		self:SetGate(false)
		self:Hide()
	elseif event == "PLAYER_REGEN_ENABLED" then
		self:Evaluate()
	end
end
