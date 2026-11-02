local AUI = select(2, ...)

local Options = AUI.MovementAlertOptions

local COOLDOWN_EVENTS = { "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES" }
local LIST_EVENTS = { "SPELLS_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "UPDATE_SHAPESHIFT_FORM", "PLAYER_ENTERING_WORLD" }
-- Seconds between the cooldown ends a line acts on, which bounds the checks a client reporting expired cooldowns causes.
local DONE_GAP = 0.25

---@class AUIMovementAlertEntry
---@field id number the spell the character knows, whose cooldown is read
---@field name string its name, or its override's
---@field charges boolean? it has charges, as last read

---@class AUIMovementAlertLine : Frame
---@field text FontString
---@field binding table a duration text binding that writes `text`
---@field ending Cooldown draws nothing; reports when the cooldown ends
---@field format string? the binding's format
---@field boundAt number? when `ending` was last given a duration
---@field doneAt number? when `ending` last reported an end that was acted on

---A line per tracked spell on its own cooldown, stacked upward. The time is written by a duration text binding, each
---line's opacity comes from a curve and each end from a Cooldown frame, so no cooldown value is read and nothing runs
---between events.
---@class AUIMovementAlert
---@field active boolean started this session
---@field following boolean the events are registered
---@field frame Frame?
---@field lines AUIMovementAlertLine[]
---@field entries AUIMovementAlertEntry[]
---@field inCombat boolean
---@field sampling boolean edit mode shows a sample line in place of the real ones
---@field curve table? the curve that clears a short cooldown's line
---@field formatter table? the time's numeric formatter
---@field formatterDecimal boolean? the Show Decimal state `formatter` was made for
local MovementAlert = {
	active = false,
	following = false,
	lines = {},
	entries = {},
	inCombat = false,
	sampling = false,
}
AUI.MovementAlert = MovementAlert

---@return boolean on the page's switch is on where the client can draw the lines
function MovementAlert:IsOn()
	return AUI.can.movementAlert == true and AUI.Profile:Get(Options.ENABLED_PATH) == true
end

---@return table curve
function MovementAlert:Curve()
	if not self.curve then
		local curve = C_CurveUtil.CreateCurve()

		curve:SetType(Enum.LuaCurveType.Step)

		for _, point in ipairs(Options:VisibilityCurve()) do
			curve:AddPoint(point[1], point[2])
		end

		self.curve = curve
	end

	return self.curve --[[@as table]]
end

---@return table formatter the time's formatter for the current Show Decimal state
function MovementAlert:Formatter()
	local decimal = AUI.Profile:Get(Options.DECIMAL_PATH) == true

	if not self.formatter or self.formatterDecimal ~= decimal then
		local formatter = C_StringUtil.CreateNumericRuleFormatter()

		formatter:SetBreakpoints(Options:TimeBreakpoints(decimal))
		self.formatter, self.formatterDecimal = formatter, decimal

		for _, line in ipairs(self.lines) do
			line.format = nil
		end
	end

	return self.formatter --[[@as table]]
end

---@return number r
---@return number g
---@return number b
function MovementAlert:Color()
	local Profile = AUI.Profile

	if Profile:Get(Options.CLASS_COLOR_PATH) then
		local _, class = UnitClass("player")
		local color = class and C_ClassColor.GetClassColor(class)

		if color then
			return color:GetRGB()
		end
	end

	local color = Profile:Get(Options.COLOR_PATH)

	return color.r, color.g, color.b
end

---@param text FontString
function MovementAlert:Style(text)
	local Profile, Media = AUI.Profile, AUI.Media

	text:SetFont(Media:Font(Profile:Get(Options.FONT_PATH)), Profile:Get(Options.SIZE_PATH),
		Media:FontFlags(Profile:Get(Options.OUTLINE_PATH)))
	text:SetTextColor(self:Color())
end

---Runs a check when a shown line's cooldown has ended, unless the report is for a cooldown already over as it was given.
---@param line AUIMovementAlertLine
function MovementAlert:OnLineDone(line)
	local now = GetTime()

	if not line:IsVisible() or now == line.boundAt or now - (line.doneAt or 0) < DONE_GAP then
		return
	end

	line.doneAt = now
	self:RequestCheck()
end

---@param line AUIMovementAlertLine
---@param index number the line's place in the stack, the bottom's being 1
function MovementAlert:LayoutLine(line, index)
	local size = AUI.Profile:Get(Options.SIZE_PATH)

	line:SetSize(Options.WIDTH, Options:LineHeight(size))
	line:ClearAllPoints()
	line:SetPoint("BOTTOM", self.frame, "BOTTOM", 0, Options:LineOffset(index, size))
end

---@param index number the line's place in the stack, the bottom's being 1
---@return AUIMovementAlertLine line
function MovementAlert:Line(index)
	local line = self.lines[index]

	if line then
		return line
	end

	line = CreateFrame("Frame", nil, self.frame) --[[@as AUIMovementAlertLine]]
	self:LayoutLine(line, index)
	line:Hide()

	line.text = line:CreateFontString(nil, "OVERLAY")
	line.text:SetPoint("CENTER")
	self:Style(line.text)

	line.binding = C_DurationUtil.CreateDurationTextBinding()
	line.binding:SetFontString(line.text)
	line.binding:SetEnabled(false)

	line.ending = CreateFrame("Cooldown", nil, line, "CooldownFrameTemplate") --[[@as Cooldown]]
	line.ending:ClearAllPoints()
	line.ending:SetAllPoints()
	line.ending:SetDrawSwipe(false)
	line.ending:SetDrawEdge(false)
	line.ending:SetDrawBling(false)
	line.ending:SetHideCountdownNumbers(true)
	line.ending:SetScript("OnCooldownDone", function()
		self:OnLineDone(line)
	end)

	self.lines[index] = line

	return line
end

---@param line AUIMovementAlertLine
local function HideLine(line)
	line:Hide()
	line.binding:SetEnabled(false)
	line.ending:Clear()
end

---Shows a line running a spell's cooldown.
---@param index number
---@param entry AUIMovementAlertEntry
---@param duration table the cooldown's duration object
---@param shape table the duration object whose total decides the line's opacity
function MovementAlert:ShowLine(index, entry, duration, shape)
	local line = self:Line(index)
	local formatter = self:Formatter()
	local format = Options:TextFormat(AUI.Profile:Get(Options.ARRANGEMENT_PATH), entry.name)

	if line.format ~= format then
		line.format = format
		line.binding:SetTextFormat(format,
			{ { property = Enum.DurationTextBindingProperty.RemainingDuration, formatter = formatter } })
	end

	line:Show()
	line.binding:SetDuration(duration)
	line.binding:SetEnabled(true)
	line.ending:SetCooldownFromDurationObject(duration)
	line.boundAt = GetTime()
	line:SetAlpha(shape:EvaluateTotalDuration(self:Curve()))
end

---@param entry AUIMovementAlertEntry
---@return boolean charges the spell has charges; the last reading while its maximum cannot be read
local function HasCharges(entry)
	local info = C_Spell.GetSpellCharges(entry.id)
	local maximum = info and AUI:Readable(info.maxCharges)

	if maximum then
		entry.charges = maximum > 1
	end

	return entry.charges == true
end

---@param spellID number
---@param charges boolean
---@return table? duration the spell's recharge or its cooldown without the global cooldown, whichever it runs on
local function TimeDuration(spellID, charges)
	if charges then
		return C_Spell.GetSpellChargeDuration(spellID) or C_Spell.GetSpellCooldownDuration(spellID, true)
	end

	return C_Spell.GetSpellCooldownDuration(spellID, true) or C_Spell.GetSpellChargeDuration(spellID)
end

---Shows the bottom line with a sample of the first tracked spell's text.
function MovementAlert:ShowSample()
	local Profile = AUI.Profile
	local line = self:Line(1)

	line.binding:SetEnabled(false)
	line.ending:Clear()
	line.text:SetText(Options:SampleText(Profile:Get(Options.ARRANGEMENT_PATH), Profile:Get(Options.DECIMAL_PATH) == true,
		self:SampleNames()[1]))
	line:SetAlpha(1)
	line:Show()
end

---Brings the lines up to date with the tracked spells' cooldowns.
function MovementAlert:Check()
	if not self.frame then
		return
	end

	local count = 0

	if self.sampling then
		self:ShowSample()
		count = 1
	elseif self:IsOn() and Options:LinesAllowed(AUI.Profile:Get(Options.COMBAT_ONLY_PATH) == true, self.inCombat) then
		for _, entry in ipairs(self.entries) do
			local charges = HasCharges(entry)

			if Options:OnOwnCooldown(C_Spell.GetSpellCooldown(entry.id), charges) then
				local duration = TimeDuration(entry.id, charges)

				if duration then
					-- A banked charge shows as a cooldown as long as the global cooldown, seen only without `ignoreGCD`.
					local shape = charges and C_Spell.GetSpellCooldownDuration(entry.id) or duration

					count = count + 1
					self:ShowLine(count, entry, duration, shape)
				end
			end
		end
	end

	for index = count + 1, #self.lines do
		HideLine(self.lines[index])
	end
end

function MovementAlert:RequestCheck()
	AUI.Events:Coalesce("movementAlertCheck", function()
		MovementAlert:Check()
	end)
end

---@return number? specID the character's specialization, once known
local function CurrentSpec()
	local index = C_SpecializationInfo.GetSpecialization()

	return index and C_SpecializationInfo.GetSpecializationInfo(index) or nil
end

---@return number[] spellIDs the spells the character tracks now
local function TrackedIDs()
	local _, class = UnitClass("player")

	return Options:TrackedSpells(class, CurrentSpec(), function(spellID)
		return C_SpellBook.IsSpellKnown(spellID)
	end, function(spell)
		return AUI.Profile:Get(Options:SpellPath(spell)) == true
	end)
end

---@param spellID number
---@return string? name its name, or its override's
local function SpellName(spellID)
	return C_Spell.GetSpellName(C_Spell.GetOverrideSpell(spellID))
end

---@param spell AUIMovementSpell
---@return string? name the ability's name as the character knows it, or its first ID's the client can name
function MovementAlert:AbilityName(spell)
	for _, spellID in ipairs(spell.ids) do
		if C_SpellBook.IsSpellKnown(spellID) then
			return SpellName(spellID)
		end
	end

	for _, spellID in ipairs(spell.ids) do
		local name = C_Spell.GetSpellName(spellID)

		if name then
			return name
		end
	end
end

---@return string[] names each tracked spell's name for samples; the class's first ability's when none is tracked
function MovementAlert:SampleNames()
	local names = {}

	for _, spellID in ipairs(TrackedIDs()) do
		names[#names + 1] = SpellName(spellID)
	end

	if #names == 0 then
		local _, class = UnitClass("player")
		local spell = Options:ClassSpells(class)[1]

		names[1] = spell and self:AbilityName(spell) or ""
	end

	return names
end

---Shows or takes away the sample line while edit mode is open.
---@param shown boolean
function MovementAlert:Sample(shown)
	self.sampling = shown
	self:Check()
end

---Rebuilds the tracked spells, keeping what is known of a spell still tracked.
function MovementAlert:RebuildEntries()
	local spellIDs = TrackedIDs()
	local known, entries = {}, {}

	for _, entry in ipairs(self.entries) do
		known[entry.id] = entry
	end

	for _, spellID in ipairs(spellIDs) do
		local name = SpellName(spellID)

		if name then
			entries[#entries + 1] = { id = spellID, name = name, charges = known[spellID] and known[spellID].charges }
		end
	end

	self.entries = entries
end

function MovementAlert:OnListEvent()
	AUI.Events:Coalesce("movementAlertList", function()
		MovementAlert:RebuildEntries()
		MovementAlert:Check()
	end)
end

function MovementAlert:OnCooldownEvent()
	self:RequestCheck()
end

---@param event string
function MovementAlert:OnCombatEvent(event)
	self.inCombat = event == "PLAYER_REGEN_DISABLED"
	self:RequestCheck()
end

function MovementAlert:CreateFrame()
	if self.frame then
		return
	end

	local frame = CreateFrame("Frame", "AeonUIMovementAlert", UIParent)

	frame:SetFrameStrata("HIGH")
	frame:EnableMouse(false)
	self.frame = frame
end

---Puts the stack at its saved place, or its default one.
function MovementAlert:Place()
	local frame = self.frame

	if not frame then
		return
	end

	local Profile = AUI.Profile
	local position = Profile:Get(Options.POSITION_PATH) or Options:DefaultPosition(UIParent:GetHeight())

	frame:SetSize(Options.WIDTH, Options:LineHeight(Profile:Get(Options.SIZE_PATH)))
	frame:ClearAllPoints()
	frame:SetPoint(position.point, UIParent, position.point, position.x, position.y)
end

---Follows the events while the switch is on, and hides the lines and stops following them while it is off.
function MovementAlert:Apply()
	local on = self:IsOn()

	if on ~= self.following then
		self.following = on

		if on then
			self:CreateFrame()
			self.inCombat = InCombatLockdown()

			for _, event in ipairs(COOLDOWN_EVENTS) do
				AUI.Events:Register(event, self, self.OnCooldownEvent)
			end

			for _, event in ipairs(LIST_EVENTS) do
				AUI.Events:Register(event, self, self.OnListEvent)
			end

			AUI.Events:Register("PLAYER_REGEN_DISABLED", self, self.OnCombatEvent)
			AUI.Events:Register("PLAYER_REGEN_ENABLED", self, self.OnCombatEvent)
		else
			self.sampling = false
			AUI.Events:UnregisterAll(self)
			AUI.Events:Cancel("movementAlertCheck")
			AUI.Events:Cancel("movementAlertList")
		end
	end

	self:Place()

	for index, line in ipairs(self.lines) do
		self:Style(line.text)
		self:LayoutLine(line, index)
	end

	if on then
		self:RebuildEntries()
	end

	self:Check()
end

---@param path string? the changed setting; nil when the whole profile changed
function MovementAlert:OnProfileChanged(path)
	if path == nil or path:sub(1, 14) == "movementAlert." then
		AUI.Events:Coalesce("movementAlertApply", function()
			MovementAlert:Apply()
		end)
	end
end

function MovementAlert:Start()
	if self.active then
		return
	end

	self.active = true
	AUI.Callbacks:Register("Profile", self, self.OnProfileChanged)
	self:Apply()
end
