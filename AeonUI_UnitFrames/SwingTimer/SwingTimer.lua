local AUI = select(2, ...)

local L = AUI.L
local Options = AUI.SwingTimerOptions

local NO_FILL = { r = 0, g = 0, b = 0, a = 0 }
local OVER_LEVEL = 2
local SPARK_GROW = 2
local PERCENT = 100
local MILLISECONDS = 1000

---@class AUISwingTimerRow : Frame
---@field spec AUISwingTimerRowSpec
---@field background Texture
---@field bar StatusBar
---@field over Frame
---@field spark Texture
---@field window Texture shades the end of its swing
---@field tag FontString
---@field time FontString
---@field duration table the duration object the fill and the time run from
---@field binding table
---@field edge AUIBorder?
---@field speed number? its weapon's speed, as last read
---@field swing number? the running swing's length
---@field ends number? when the running swing ends
---@field endTimer table?
---@field rangeOn boolean?
---@field far boolean?
---@field shield boolean? a shield fills its slot
---@field host AUISwingTimerRow? the row it rides under Combine Hands
---@field isPreview boolean? a settings sample, which live attacks and seals leave alone
---@field sampleField string? the preview's queued color field
---@field sampleAttack string? the preview's queued attack

---The player's swing timer, on the clients that report swings: one frame with a row per weapon that can swing. The
---engine animates each row's fill and time from a duration object, so no Lua runs per frame; a timer per swing catches
---its end. Nothing is built or registered until the page's switch is on.
---@class AUISwingTimer
---@field frame Frame?
---@field rows AUISwingTimerRow[] built while on
---@field byType table<integer, AUISwingTimerRow>
---@field shown integer how many rows show
---@field following boolean? the events are registered
---@field watchingGear boolean? the off hand's slot is watched for a shield
---@field watchingQueue boolean? next-swing attacks are watched
---@field watchingSeals boolean? seals are watched
---@field watchingMoving boolean? the player's movement is watched
---@field hunter boolean? the player is a hunter
---@field moving boolean? the player is moving
---@field latency number? the world latency, in seconds, last read
---@field queueFields table<string, string> the color field of each of the class's next-swing attacks, by name
---@field sealsByName table<string, AUISwingTimerSeal> the seals, by name, for a paladin
---@field queued string|false|nil the queued attack's name
---@field seal AUISwingTimerSeal|false|nil the seal up
---@field sealTimer table? counts the seal's end
---@field sealSeconds number? how long a seal lasts, once a buff has said
---@field sampling boolean? edit mode's sample is up
---@field inCombat boolean?
---@field formatter table?
local SwingTimer = { rows = {}, byType = {}, shown = 0, queueFields = {}, sealsByName = {} }
AUI.SwingTimer = SwingTimer

---@return boolean on the page's switch is on where the client reports swings
function SwingTimer:IsOn()
	return AUI.can.swingTimer == true and AUI.Profile:Get(Options.ENABLED_PATH) == true
end

---@return table formatter seconds to one decimal, rounded up so the last moment never reads 0.0
function SwingTimer:Formatter()
	if not self.formatter then
		local formatter = C_StringUtil.CreateNumericRuleFormatter()

		formatter:SetBreakpoints({
			{ threshold = 0, step = 0.1, rounding = Enum.NumericRuleFormatRounding.Up, format = "%.1f" },
		})
		self.formatter = formatter
	end

	return self.formatter
end

---Builds a row without its look; `Style` gives it that.
---@param parent Frame
---@param spec AUISwingTimerRowSpec
---@return AUISwingTimerRow row
function SwingTimer:BuildRow(parent, spec)
	local row = CreateFrame("Frame", nil, parent) --[[@as AUISwingTimerRow]]

	row.spec = spec
	row.background = row:CreateTexture(nil, "BACKGROUND")
	row.background:SetAllPoints()

	local bar = CreateFrame("StatusBar", nil, row)

	bar:SetAllPoints()
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	row.bar = bar

	local over = CreateFrame("Frame", nil, bar)

	over:SetAllPoints()
	over:SetFrameLevel(bar:GetFrameLevel() + OVER_LEVEL)
	row.over = over

	row.window = over:CreateTexture(nil, "ARTWORK")
	row.window:Hide()

	row.spark = over:CreateTexture(nil, "OVERLAY")
	row.spark:SetTexture(Options.SPARK_TEXTURE)
	row.spark:SetBlendMode("ADD")
	row.spark:Hide()

	row.tag = over:CreateFontString(nil, "OVERLAY")
	row.tag:SetPoint("LEFT", row, "LEFT", Options.TEXT_INSET, 0)
	row.tag:SetWordWrap(false)
	row.tag:SetText(L[spec.label])

	row.time = over:CreateFontString(nil, "OVERLAY")
	row.time:SetPoint("RIGHT", row, "RIGHT", -Options.TEXT_INSET, 0)
	row.time:SetWordWrap(false)
	row.time:SetText("")

	row.duration = C_DurationUtil.CreateDuration()
	row.binding = C_DurationUtil.CreateDurationTextBinding()
	row.binding:SetFontString(row.time)
	row.binding:SetDuration(row.duration)
	row.binding:SetFormatter(self:Formatter())
	row.binding:SetZeroDurationText("")
	row.binding:SetExpiredText("")
	row.binding:SetEnabled(false)

	return row
end

---@param row AUISwingTimerRow
---@return string? attack the name of the attack it shows queued
---@return string? field that attack's color field
function SwingTimer:RowAttack(row)
	if row.isPreview then
		return row.sampleAttack, row.sampleField
	end

	local queued = self.queued

	if queued and not row.shield then
		return queued, self.queueFields[queued]
	end
end

---@param row AUISwingTimerRow
---@return number r
---@return number g
---@return number b
function SwingTimer:FillColor(row)
	local Profile = AUI.Profile
	local _, queued = self:RowAttack(row)
	local seal = not row.isPreview and not row.shield and self.seal
	local field, own = Options:ColorField(row.spec, queued, seal and seal.color or nil)

	if own and Profile:Get("swingTimer.classColor") then
		local _, class = UnitClass("player")
		local color = class and C_ClassColor.GetClassColor(class)

		if color then
			return color.r, color.g, color.b
		end
	end

	local color = Profile:Get("swingTimer." .. field)

	return color.r, color.g, color.b
end

---Colors a row's fill and, on a row riding another, its spark, and writes its label.
---@param row AUISwingTimerRow
function SwingTimer:PaintRow(row)
	local r, g, b = self:FillColor(row)
	local attack = self:RowAttack(row)

	row.bar:GetStatusBarTexture():SetVertexColor(r, g, b)

	if row.host then
		row.spark:SetVertexColor(r, g, b)
	else
		row.spark:SetVertexColor(1, 1, 1)
	end

	row.tag:SetText(Options:TagText(row.spec, row.shield and SHIELDSLOT or L[row.spec.label], attack))
end

function SwingTimer:PaintHands()
	for _, row in ipairs(self.rows) do
		if row.spec.hand then
			self:PaintRow(row)
		end
	end
end

---@return number height a row's drawn height
function SwingTimer:RowHeight()
	local Profile = AUI.Profile

	return Options:DrawnHeight(Profile:Get("swingTimer.borderStyle"), Profile:Get("swingTimer.height"),
		AUI.CastBarOptions.FOREVER_MINIMAL.minHeight)
end

---Gives a row its look.
---@param row AUISwingTimerRow
function SwingTimer:Style(row)
	local Profile = AUI.Profile
	local height = self:RowHeight()
	local bar = row.bar
	local background = Profile:Get("swingTimer.background")
	local font = AUI.Media:Font(Profile:Get("swingTimer.font"))
	local flags = AUI.Media:FontFlags(Profile:Get("swingTimer.outline"))
	local size = Profile:Get("swingTimer.textSize")

	local host = row.host

	row:SetSize(Profile:Get("swingTimer.width"), height)
	AUI.Media:SetBarTexture(bar, Profile:Get("swingTimer.texture"))
	-- A row riding another shows only its spark, which stays anchored to its unseen fill.
	bar:GetStatusBarTexture():SetAlpha(host and 0 or 1)
	row.background:SetColorTexture(background.r, background.g, background.b, host and 0 or background.a or 1)
	row.over:SetFrameLevel(host and host.over:GetFrameLevel() + OVER_LEVEL or bar:GetFrameLevel() + OVER_LEVEL)
	row.spark:ClearAllPoints()
	row.spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT")

	self:PaintRow(row)
	row.spark:SetSize(Options.SPARK_WIDTH, height * SPARK_GROW)
	row.tag:SetFont(font, size, flags)
	row.time:SetFont(font, size, flags)
	row.tag:SetShown(not host and Profile:Get("swingTimer.label") == true)
	row.time:SetShown(not host and Profile:Get("swingTimer.time") == true)

	if not row.edge then
		row.edge = AUI.Border:Create(row, true)
	end

	row.edge:SetFrameLevel(row.over:GetFrameLevel() + 1)

	local minimal = Profile:Get("swingTimer.borderStyle") == "FOREVER_MINIMAL"

	row.edge:Apply({
		style = host and "NONE" or minimal and "FOREVER_MINIMAL_SHADED" or "THIN_LINE",
		color = minimal and AUI.CastBarOptions.FOREVER_MINIMAL.color or Profile:Get("swingTimer.borderColor"),
		background = NO_FILL,
	})
	self:PaintRange(row, row.far == true)
end

---Dims a row and turns its text red while its target is out of range.
---@param row AUISwingTimerRow
---@param far boolean
function SwingTimer:PaintRange(row, far)
	local color = far and Options.FAR_TEXT or Options.NEAR_TEXT

	row:SetAlpha(far and AUI.Profile:Get("swingTimer.outOfRangeAlpha") / PERCENT or 1)
	row.tag:SetTextColor(color.r, color.g, color.b)
	row.time:SetTextColor(color.r, color.g, color.b)
end

---@param row AUISwingTimerRow
---@return boolean on a row riding another is its spark alone, so it ignores Show Spark
local function SparkOn(row)
	return row.host ~= nil or AUI.Profile:Get("swingTimer.spark") == true
end

---Draws a still sample: edit mode's and the settings preview's.
---@param row AUISwingTimerRow
---@param far boolean
function SwingTimer:DrawSample(row, far)
	local Profile = AUI.Profile
	local share = row.spec.sample

	row.binding:SetEnabled(false)
	row.bar:SetMinMaxValues(0, 1)
	row.bar:SetValue(Profile:Get("swingTimer.depleteFill") and 1 - share or share)
	row.time:SetText(row.spec.sampleTime)
	row.spark:SetShown(SparkOn(row))
	self:PaintRange(row, far)
	self:UpdateWindow(row)
end

---Shades the end of a running or sample swing; a row riding another has none of its own.
---@param row AUISwingTimerRow
function SwingTimer:UpdateWindow(row)
	local Profile = AUI.Profile
	local window = row.window
	local sample = row.isPreview or self.sampling
	local seconds

	if not row.host and (row.ends or sample) then
		local _, class = UnitClass("player")

		seconds = Options:WindowSeconds(row.spec, Profile:Get("swingTimer.swingWindow") == true,
			Profile:Get("swingTimer.swingWindowTime"), Profile:Get("swingTimer.autoShotWindow") == true,
			class == "HUNTER", not sample and Profile:Get("swingTimer.windowLatency") and self.latency or 0)
	end

	if not seconds then
		window:Hide()

		return
	end

	local side = Options:WindowSide(Profile:Get("swingTimer.depleteFill") == true)
	local color = Profile:Get("swingTimer." .. Options:WindowColor(row.spec, not sample and self.moving == true))

	window:ClearAllPoints()
	window:SetPoint("TOP" .. side, row.bar, "TOP" .. side)
	window:SetPoint("BOTTOM" .. side, row.bar, "BOTTOM" .. side)
	window:SetWidth(Options:WindowWidth(seconds, row.swing or Options.SAMPLE_SWING, Profile:Get("swingTimer.width")))
	window:SetColorTexture(color.r, color.g, color.b, color.a or 1)
	window:Show()
end

---@param row AUISwingTimerRow
function SwingTimer:IdleRow(row)
	if row.endTimer then
		row.endTimer:Cancel()
		row.endTimer = nil
	end

	row.swing, row.ends = nil, nil
	row.binding:SetEnabled(false)
	row.bar:SetMinMaxValues(0, 1)
	row.bar:SetValue(0)
	row.time:SetText("")
	row.spark:Hide()
	row.window:Hide()
end

---Runs a row's fill and time from its swing's start.
---@param row AUISwingTimerRow
function SwingTimer:RunRow(row)
	local Profile = AUI.Profile
	local direction = Profile:Get("swingTimer.depleteFill") and Enum.StatusBarTimerDirection.RemainingTime
		or Enum.StatusBarTimerDirection.ElapsedTime

	local ends, swing = row.ends --[[@as number]], row.swing --[[@as number]]

	row.duration:SetTimeFromStart(ends - swing, swing)
	row.bar:SetTimerDuration(row.duration, Enum.StatusBarInterpolation.Immediate, direction)
	row.binding:SetEnabled(true)
	row.spark:SetShown(SparkOn(row))
	self:UpdateWindow(row)
end

---@param row AUISwingTimerRow
---@param seconds any a swing's length, already readable
function SwingTimer:StartRow(row, seconds)
	if not Options:Usable(seconds) then
		return
	end

	if AUI.Profile:Get("swingTimer.windowLatency") then
		local _, _, _, world = GetNetStats()

		self.latency = (AUI:Readable(world, 0) or 0) / MILLISECONDS
	end

	row.swing, row.ends = seconds, GetTime() + seconds
	self:RunRow(row)

	if row.endTimer then
		row.endTimer:Cancel()
	end

	row.endTimer = C_Timer.NewTimer(seconds + Options.END_GRACE, function()
		row.endTimer = nil
		self:IdleRow(row)
		self:UpdateVisibility()
	end)
	self:UpdateVisibility()
end

---@return boolean aware the off hand's slot matters: a shield shows or labels its row
function SwingTimer:ShieldAware()
	local Profile = AUI.Profile

	return Profile:Get("swingTimer.shieldRow") == true or Profile:Get("swingTimer.alwaysShowRows") == true
end

---@return boolean shield the off hand's slot holds a shield
local function OffHandShield()
	local item = AUI:Readable(GetInventoryItemID("player", Options.OFF_HAND_SLOT))

	if not item then
		return false
	end

	local _, _, _, location = C_Item.GetItemInfoInstant(item)

	return Options:IsShield(AUI:Readable(location))
end

---Reads each row's weapon speed; a speed that cannot be read keeps the last one, since a haste proc can restrict it.
function SwingTimer:ReadSpeeds()
	local shield = self:ShieldAware() and OffHandShield()

	for _, row in ipairs(self.rows) do
		local value = select(row.spec.speedReturn, UnitAttackSpeed("player"))

		if not issecretvalue(value) then
			row.speed = Options:Speed(value)
		end

		local holds = row.spec.swing == "OffHand" and shield and not row.speed

		if holds ~= (row.shield == true) then
			row.shield = holds
			self:PaintRow(row)
		end
	end
end

---Lays a row over another under Combine Hands, or back on its own.
---@param row AUISwingTimerRow
---@param host AUISwingTimerRow?
function SwingTimer:SetHost(row, host)
	if row.host ~= host then
		row.host = host
		self:Style(row)
	end
end

---Stacks the rows that show, top to bottom; a row riding another takes no place.
---@param rows AUISwingTimerRow[] the Main Hand's first
---@param parent Frame
---@param armed fun(row: AUISwingTimerRow): boolean its slot holds a weapon that swings
---@return integer shown how many places the stack takes
function SwingTimer:Stack(rows, parent, armed)
	local Profile = AUI.Profile
	local height, spacing = self:RowHeight(), Profile:Get("swingTimer.spacing")
	local combine = Profile:Get("swingTimer.combineHands") == true
	local first = rows[1]
	local shown = 0

	for _, row in ipairs(rows) do
		if row:IsShown() then
			local merged = Options:Merged(row.spec, combine, first:IsShown(), armed(row))

			self:SetHost(row, merged and first or nil)
			row:ClearAllPoints()

			if merged then
				row:SetPoint("TOP", first, "TOP")
			else
				shown = shown + 1
				row:SetPoint("TOP", parent, "TOP", 0, Options:RowY(shown, height, spacing))
			end
		end
	end

	return shown
end

---@param row AUISwingTimerRow
function SwingTimer:ReadRange(row)
	local far = false

	if row.rangeOn then
		far = AUI:Readable(C_SwingTimer.IsTargetWithinSwingRange(Enum.PlayerSwingType[row.spec.swing])) == false
	end

	row.far = far
	self:PaintRange(row, far and not self.sampling)
end

---Asks for range edges on a row that wants them. The engine keeps one flag per swing type, shared with Blizzard's own
---timer, so this repeats on every refresh and swing and never turns the flag off while on.
---@param row AUISwingTimerRow
function SwingTimer:AskRange(row)
	row.rangeOn = AUI.Profile:Get("swingTimer.rangeCheck") == true and row:IsShown()

	if row.rangeOn then
		C_SwingTimer.EnableRangeCheck(Enum.PlayerSwingType[row.spec.swing], true)
	end

	self:ReadRange(row)
end

---Shows the rows that can swing, stacked top to bottom, and the frame around them.
function SwingTimer:Refresh()
	local Profile = AUI.Profile
	local frame = self.frame

	if not frame then
		return
	end

	local always = Profile:Get("swingTimer.alwaysShowRows") == true

	self:ReadSpeeds()

	for _, row in ipairs(self.rows) do
		local wanted = Options:Wanted(row.spec, Profile:Get("swingTimer." .. row.spec.show) == true, row.speed, always,
			row.shield)

		row:SetShown(wanted)

		if not wanted and row.ends then
			self:IdleRow(row)
		end
	end

	local shown = self:Stack(self.rows, frame, function(row)
		return row.speed ~= nil
	end)

	for _, row in ipairs(self.rows) do
		self:AskRange(row)
	end

	self.shown = shown
	frame:SetSize(Profile:Get("swingTimer.width"), Options:StackHeight(shown, self:RowHeight(),
		Profile:Get("swingTimer.spacing")))
	self:UpdateVisibility()
end

function SwingTimer:UpdateVisibility()
	local frame = self.frame --[[@as Frame]]

	local running = false

	for _, row in ipairs(self.rows) do
		running = running or row.ends ~= nil
	end

	frame:SetShown(Options:Visible(self:IsOn(), self.shown, self.sampling == true,
		AUI.Profile:Get("swingTimer.visibility"), self.inCombat == true,
		AUI.Profile:Get("swingTimer.hideWhenIdle") == true, running))
end

---Builds the frame and its rows once.
function SwingTimer:CreateFrame()
	if self.frame then
		return
	end

	local frame = CreateFrame("Frame", "AeonUISwingTimer", UIParent)

	frame:EnableMouse(false)
	self.frame = frame

	for index, spec in ipairs(Options.ROWS) do
		local row = self:BuildRow(frame, spec)

		self.rows[index] = row
		self.byType[Enum.PlayerSwingType[spec.swing]] = row
	end
end

---@return { point: string, x: number, y: number } position the saved place, or the default one
function SwingTimer:Position()
	return AUI.Profile:Get(Options.POSITION_PATH) or Options.DEFAULT_POSITION
end

function SwingTimer:Place()
	local frame = self.frame

	if not frame then
		return
	end

	local position = self:Position()

	frame:ClearAllPoints()
	frame:SetPoint(position.point, UIParent, position.point, position.x, position.y)

	for _, row in ipairs(self.rows) do
		if row.edge then
			row.edge:Layout()
		end
	end
end

---A running swing is parked first, or its end would empty the sample.
---@param shown boolean edit mode's sample is up
function SwingTimer:Sample(shown)
	self.sampling = shown

	for _, row in ipairs(self.rows) do
		self:IdleRow(row)

		if shown then
			self:DrawSample(row, false)
		else
			self:PaintRange(row, row.far == true)
		end
	end

	self:Refresh()
end

---@param _ string the event
---@param seconds any
---@param kind any
function SwingTimer:OnSwing(_, seconds, kind)
	seconds, kind = AUI:Readable(seconds), AUI:Readable(kind)

	local row = kind ~= nil and self.byType[kind]

	if not row or seconds == nil then
		return
	end

	-- A swing proves the slot has a weapon while its speed cannot be read.
	if not row:IsShown() and not row.speed and AUI.Profile:Get("swingTimer." .. row.spec.show) == true then
		row.speed = seconds
		self:Refresh()
	end

	if row:IsShown() and not self.sampling then
		self:StartRow(row, seconds)
	end

	self:AskRange(row)
	self:ReadQueue()
end

---@param _ string the event
---@param kind any
---@param inRange any
---@param checks any
function SwingTimer:OnSwingRange(_, kind, inRange, checks)
	kind, inRange, checks = AUI:Readable(kind), AUI:Readable(inRange), AUI:Readable(checks)

	local row = kind ~= nil and self.byType[kind]

	if row and row.rangeOn then
		row.far = checks == true and inRange == false
		self:PaintRange(row, row.far and not self.sampling)
	end
end

function SwingTimer:OnTargetChanged()
	for _, row in ipairs(self.rows) do
		self:ReadRange(row)
	end
end

---A weapon swap restarts the swing at the new weapon's speed, with no swing event.
function SwingTimer:OnWeaponChanged()
	self:Refresh()

	for _, row in ipairs(self.rows) do
		if row.ends and row.speed and not self.sampling then
			self:StartRow(row, row.speed)
		end
	end
end

---@param _ string the event
---@param unit string
function SwingTimer:OnAttackSpeed(_, unit)
	if unit == "player" then
		self:Refresh()
	end
end

function SwingTimer:OnDead()
	for _, row in ipairs(self.rows) do
		if row.ends then
			self:IdleRow(row)
		end
	end

	self:UpdateVisibility()
end

---@param _ string the event
---@param slot number
function SwingTimer:OnEquipment(_, slot)
	if slot == Options.OFF_HAND_SLOT then
		self:Refresh()
	end
end

---Watches the off hand's slot only while a shield matters.
function SwingTimer:WatchGear()
	local aware = self:ShieldAware()

	if aware ~= (self.watchingGear == true) then
		self.watchingGear = aware

		if aware then
			AUI.Events:Register("PLAYER_EQUIPMENT_CHANGED", self, self.OnEquipment)
		else
			AUI.Events:Unregister("PLAYER_EQUIPMENT_CHANGED", self)
		end
	end
end

---@param event string
function SwingTimer:OnCombat(event)
	self.inCombat = event == "PLAYER_REGEN_DISABLED"
	self:UpdateVisibility()

	if not self.inCombat then
		self:ReadSeal()
	end
end

---Learns the names of the class's next-swing attacks and, for a paladin, its seals.
function SwingTimer:LearnSpells()
	local _, class = UnitClass("player")

	self.queueFields, self.sealsByName = {}, {}

	for _, id in ipairs(Options.NEXT_SWING[class] or {}) do
		local name = AUI:Readable(C_Spell.GetSpellName(id))

		if name then
			self.queueFields[name] = Options:QueueField(id)
		end
	end

	if class == "PALADIN" then
		for _, seal in ipairs(Options.SEALS) do
			local name = AUI:Readable(C_Spell.GetSpellName(seal.id))

			if name then
				self.sealsByName[name] = seal
			end
		end
	end
end

---Paints the hand rows when the queued attack changes; a swing or an action bar update can change it.
function SwingTimer:ReadQueue()
	local found = false

	if self.watchingQueue then
		for name in pairs(self.queueFields) do
			if AUI:Readable(C_Spell.IsCurrentSpell(name)) == true then
				found = name

				break
			end
		end
	end

	if found ~= (self.queued or false) then
		self.queued = found
		self:PaintHands()
	end
end

function SwingTimer:OnActionBarState()
	AUI.Events:Coalesce("swingTimerQueue", function()
		SwingTimer:ReadQueue()
	end)
end

function SwingTimer:StopSealTimer()
	if self.sealTimer then
		self.sealTimer:Cancel()
		self.sealTimer = nil
	end
end

---@param seal AUISwingTimerSeal|false
function SwingTimer:SetSeal(seal)
	if not seal then
		self:StopSealTimer()
	end

	if seal ~= (self.seal or false) then
		self.seal = seal
		self:PaintHands()
	end
end

---Nothing in combat says a seal has run out, so its end is counted.
---@param seconds number
function SwingTimer:CountSeal(seconds)
	self:StopSealTimer()
	self.sealTimer = C_Timer.NewTimer(seconds, function()
		self.sealTimer = nil
		self:SetSeal(false)
	end)
end

---Reads the seal up from the player's buffs, which the client keeps from addons in combat.
function SwingTimer:ReadSeal()
	if not self.watchingSeals or self.inCombat or C_Secrets.ShouldAurasBeSecret() then
		return
	end

	local found = false

	for index = 1, Options.MAX_AURAS do
		local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")

		if not aura then
			break
		end

		local seal = self.sealsByName[AUI:Readable(aura.name, "") --[[@as string]]]

		if seal then
			local length, ends = AUI:Readable(aura.duration), AUI:Readable(aura.expirationTime)

			if type(length) == "number" and length > 0 then
				self.sealSeconds = length
			end

			if type(ends) == "number" and ends > 0 then
				self:CountSeal(math.max(ends - GetTime(), 0))
			end

			found = seal

			break
		end
	end

	self:SetSeal(found)
end

---A seal cast in combat is the seal up until it runs out.
---@param _event string
---@param unit string
---@param _guid string
---@param spellID any
function SwingTimer:OnSpellCast(_event, unit, _guid, spellID)
	if unit ~= "player" then
		return
	end

	spellID = AUI:Readable(spellID)

	local name = spellID and AUI:Readable(C_Spell.GetSpellName(spellID))
	local seal = name and self.sealsByName[name]

	if seal then
		self:SetSeal(seal)
		self:CountSeal(self.sealSeconds or Options.SEAL_SECONDS)
	end
end

---@param _ string the event
---@param unit string
function SwingTimer:OnAura(_, unit)
	if unit == "player" then
		AUI.Events:Coalesce("swingTimerSeal", function()
			SwingTimer:ReadSeal()
		end)
	end
end

---@param event string
function SwingTimer:OnMoving(event)
	self.moving = event == "PLAYER_STARTED_MOVING"

	local row = self.byType[Enum.PlayerSwingType.Ranged]

	if row.ends then
		self:UpdateWindow(row)
	end
end

---Follows the player's movement only while Auto Shot's window can show it.
function SwingTimer:WatchMoving()
	local _, class = UnitClass("player")
	local watch = class == "HUNTER" and AUI.Profile:Get("swingTimer.autoShotWindow") == true

	if watch ~= (self.watchingMoving == true) then
		self.watchingMoving = watch

		if watch then
			AUI.Events:Register("PLAYER_STARTED_MOVING", self, self.OnMoving)
			AUI.Events:Register("PLAYER_STOPPED_MOVING", self, self.OnMoving)
			self.moving = AUI:Readable(IsPlayerMoving()) == true
		else
			AUI.Events:Unregister("PLAYER_STARTED_MOVING", self)
			AUI.Events:Unregister("PLAYER_STOPPED_MOVING", self)
			self.moving = false
		end
	end
end

---Follows queued attacks and seals only while their settings are on and the class has any.
function SwingTimer:WatchAttacks()
	local Events, Profile = AUI.Events, AUI.Profile
	local queue = Profile:Get("swingTimer.queueHighlight") == true and next(self.queueFields) ~= nil
	local seals = Profile:Get("swingTimer.sealColors") == true and next(self.sealsByName) ~= nil

	if queue ~= (self.watchingQueue == true) then
		self.watchingQueue = queue

		if queue then
			Events:Register("ACTIONBAR_UPDATE_STATE", self, self.OnActionBarState)
		else
			Events:Unregister("ACTIONBAR_UPDATE_STATE", self)
		end
	end

	if seals ~= (self.watchingSeals == true) then
		self.watchingSeals = seals

		if seals then
			Events:Register("UNIT_SPELLCAST_SUCCEEDED", self, self.OnSpellCast)
			Events:Register("UNIT_AURA", self, self.OnAura)
		else
			Events:Unregister("UNIT_SPELLCAST_SUCCEEDED", self)
			Events:Unregister("UNIT_AURA", self)
			self:SetSeal(false)
		end
	end
end

---Stops following the swings and hides the frame. The range flags go off only while Blizzard's own timer is off, since
---it re-sends its flag only when its own state changes.
function SwingTimer:Stop()
	AUI.Events:UnregisterAll(self)
	self.watchingGear, self.watchingQueue, self.watchingSeals, self.watchingMoving = nil, nil, nil, nil
	self.moving = false
	self:StopSealTimer()
	self.queued, self.seal = false, false

	if not C_CVar.GetCVarBool("showSwingTimer") then
		for _, spec in ipairs(Options.ROWS) do
			C_SwingTimer.EnableRangeCheck(Enum.PlayerSwingType[spec.swing], false)
		end
	end

	for _, row in ipairs(self.rows) do
		self:IdleRow(row)
		row.far, row.rangeOn = false, false
	end
end

---Follows the swings while the switch is on; hides the frame and stops following them while it is off.
function SwingTimer:Apply()
	local on = self:IsOn()

	if on ~= (self.following == true) then
		self.following = on

		if on then
			self:CreateFrame()
			self:LearnSpells()
			self.inCombat = AUI:Readable(UnitAffectingCombat("player")) == true

			local Events = AUI.Events

			Events:Register("PLAYER_SWING", self, self.OnSwing)
			Events:Register("PLAYER_SWING_RANGE_UPDATE", self, self.OnSwingRange)
			Events:Register("PLAYER_TARGET_CHANGED", self, self.OnTargetChanged)
			Events:Register("WEAPON_SLOT_CHANGED", self, self.OnWeaponChanged)
			Events:Register("UNIT_ATTACK_SPEED", self, self.OnAttackSpeed)
			Events:Register("PLAYER_ENTERING_WORLD", self, self.Refresh)
			Events:Register("PLAYER_DEAD", self, self.OnDead)
			Events:Register("PLAYER_REGEN_DISABLED", self, self.OnCombat)
			Events:Register("PLAYER_REGEN_ENABLED", self, self.OnCombat)
			Events:Register("UI_SCALE_CHANGED", self, self.Place)
		else
			self:Stop()
		end
	end

	if not self.frame then
		return
	end

	if not on then
		self.frame:Hide()

		return
	end

	self:WatchGear()
	self:WatchAttacks()
	self:WatchMoving()
	self:ReadQueue()
	self:ReadSeal()

	for _, row in ipairs(self.rows) do
		self:Style(row)

		if row.ends and not self.sampling then
			self:RunRow(row)
		end

		self:UpdateWindow(row)
	end

	self:Place()
	self:Refresh()
end

---@param path string? the changed setting; nil when the whole profile changed
function SwingTimer:OnProfileChanged(path)
	if path == nil or path:sub(1, 11) == "swingTimer." then
		AUI.Events:Coalesce("swingTimerApply", function()
			SwingTimer:Apply()
		end)
	end
end

function SwingTimer:Start()
	if self.active then
		return
	end

	self.active = true
	AUI.Callbacks:Register("Profile", self, self.OnProfileChanged)
	self:Apply()
end
