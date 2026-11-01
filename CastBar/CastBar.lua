local AUI = select(2, ...)

local L = AUI.L
local Options = AUI.CastBarOptions

local CAST_EVENTS = {
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_FAILED",
	"UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
	"UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
	"UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_UPDATE", "UNIT_SPELLCAST_EMPOWER_STOP",
}
local PET_BATTLE_EVENTS = { "PET_BATTLE_OPENING_START", "PET_BATTLE_CLOSE" }
-- The gap between the spell name and the time, in UI units.
local TEXT_GAP = 4
-- Each border line, outside the frame: its two corners with the direction each lies from the frame, and whether it
-- runs across.
---@type table[]
local BORDER_LINES = {
	{ "TOPLEFT", -1, 1, "TOPRIGHT", 1, 1, true },
	{ "BOTTOMLEFT", -1, -1, "BOTTOMRIGHT", 1, -1, true },
	{ "TOPLEFT", -1, 1, "BOTTOMLEFT", -1, -1, false },
	{ "TOPRIGHT", 1, 1, "BOTTOMRIGHT", 1, -1, false },
}
-- An icon's own border, cut from each edge.
local ICON_CROP = 0.08

---@class AUICastBarFrame : Frame
---@field lines Texture[] the border, `BORDER_LINES` in order
---@field icon Texture
---@field bar StatusBar
---@field background Texture
---@field locked Frame covers the fill while the cast cannot be interrupted
---@field lockedFill Texture
---@field failed Frame covers the fill while Interrupted shows
---@field over Frame the spark and text, above the covers
---@field spark Texture
---@field text FontString the spell name
---@field time FontString
---@field binding table a duration text binding; writes the time into `time`

---The player cast bar. The client's timer drives the fill from the cast's duration object and a duration text binding
---writes the time, so no Lua runs while a cast is drawn and no secret value is read: the spell name, the icon, the
---duration and the interruptible flag go straight to widgets. Each cast event reads the cast again and draws it, or
---empties or hides the bar when there is none.
---@class AUICastBar
---@field active boolean started this session
---@field following boolean the events are registered
---@field sampling boolean edit mode shows the sample
---@field petBattle boolean
---@field frame AUICastBarFrame?
---@field formatter table? seconds to one decimal
local CastBar = {
	active = false,
	following = false,
	sampling = false,
	petBattle = false,
}
AUI.CastBar = CastBar

---A cover over the fill is a frame because a boolean that may be secret sets its alpha, which a texture would not show
---reliably.
---@param parent Frame
---@return Frame cover unanchored and clear
---@return Texture fill
local function CreateCover(parent)
	local cover = CreateFrame("Frame", nil, parent)
	local fill = cover:CreateTexture(nil, "ARTWORK")

	fill:SetAllPoints()
	cover:SetAlpha(0)

	return cover, fill
end

---@return table formatter seconds to one decimal
function CastBar:Formatter()
	if not self.formatter then
		local formatter = C_StringUtil.CreateNumericRuleFormatter()

		formatter:SetBreakpoints({ { threshold = 0, step = 0.1, format = "%.1f" } })
		self.formatter = formatter
	end

	return self.formatter
end

---Builds a bar, unplaced, hidden and without its look; `Style` gives it that.
---@param parent Frame
---@param name string? a global name, for the root frame only
---@return AUICastBarFrame frame
function CastBar:Build(parent, name)
	local frame = CreateFrame("Frame", name, parent) --[[@as AUICastBarFrame]]
	local border = Options.BORDER_COLOR

	frame:Hide()
	frame.lines = {}

	for index in ipairs(BORDER_LINES) do
		local line = frame:CreateTexture(nil, "BORDER")

		line:SetColorTexture(border.r, border.g, border.b, border.a)
		line:SetSnapToPixelGrid(false)
		line:SetTexelSnappingBias(0)
		frame.lines[index] = line
	end

	frame.icon = frame:CreateTexture(nil, "ARTWORK")
	frame.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)

	local bar = CreateFrame("StatusBar", nil, frame) --[[@as StatusBar]]

	bar:SetMinMaxValues(0, 1)
	frame.bar = bar

	frame.background = bar:CreateTexture(nil, "BACKGROUND")
	frame.background:SetAllPoints()

	frame.locked, frame.lockedFill = CreateCover(bar)

	local failed, failedFill = CreateCover(bar)
	local interrupted = Options.INTERRUPTED_COLOR

	failedFill:SetColorTexture(interrupted.r, interrupted.g, interrupted.b, 1)
	frame.failed = failed

	local over = CreateFrame("Frame", nil, bar)

	over:SetAllPoints()
	over:SetFrameLevel(failed:GetFrameLevel() + 1)
	frame.over = over

	frame.spark = over:CreateTexture(nil, "OVERLAY")
	frame.spark:SetTexture(Options.SPARK_TEXTURE)
	frame.spark:SetBlendMode("ADD")

	frame.time = over:CreateFontString(nil, "OVERLAY")
	frame.time:SetJustifyH("RIGHT")
	frame.time:SetWordWrap(false)

	frame.text = over:CreateFontString(nil, "OVERLAY")
	frame.text:SetJustifyH("LEFT")
	frame.text:SetWordWrap(false)

	frame.binding = C_DurationUtil.CreateDurationTextBinding()
	frame.binding:SetFontString(frame.time)
	frame.binding:SetEnabled(false)

	return frame
end

---Colors the fill: the player's class color, or the fill color with its gradient.
---@param frame AUICastBarFrame
function CastBar:StyleFill(frame)
	local Profile = AUI.Profile
	local first, last = Profile:Get("castBar.color"), Profile:Get("castBar.gradientColor")
	local r, g, b = first.r, first.g, first.b
	local r2, g2, b2 = last.r, last.g, last.b

	if not Profile:Get("castBar.gradient") then
		r2, g2, b2 = r, g, b
	end

	if Profile:Get("castBar.classColor") then
		local _, class = UnitClass("player")
		local color = class and C_ClassColor.GetClassColor(class)

		if color then
			r, g, b = color:GetRGB()
			r2, g2, b2 = r, g, b
		end
	end

	frame.bar:GetStatusBarTexture():SetGradient(Profile:Get("castBar.gradientDirection"), CreateColor(r, g, b, 1),
		CreateColor(r2, g2, b2, 1))
end

---Puts the bar beside the icon, or across the whole frame, and the border outside it all.
---@param frame AUICastBarFrame
---@param height number
function CastBar:StyleLayout(frame, height)
	local Profile = AUI.Profile
	local bar, icon = frame.bar, frame.icon
	local showIcon = Profile:Get("castBar.icon") == true
	local right = Profile:Get("castBar.iconSide") == "RIGHT"
	local thickness = Profile:Get("castBar.border") * AUI:Pixel(frame)

	bar:ClearAllPoints()
	icon:ClearAllPoints()
	icon:SetShown(showIcon)

	if showIcon then
		icon:SetSize(height, height)
		icon:SetPoint(right and "TOPRIGHT" or "TOPLEFT")
		bar:SetPoint("TOPLEFT", right and 0 or height, 0)
		bar:SetPoint("BOTTOMRIGHT", right and -height or 0, 0)
	else
		bar:SetAllPoints()
	end

	for index, spec in ipairs(BORDER_LINES) do
		local line = frame.lines[index]

		line:ClearAllPoints()
		line:SetPoint(spec[1], spec[2] * thickness, spec[3] * thickness)
		line:SetPoint(spec[4], spec[5] * thickness, spec[6] * thickness)

		if spec[7] then
			line:SetHeight(thickness)
		else
			line:SetWidth(thickness)
		end

		line:SetShown(thickness > 0)
	end
end

---Gives a font string its size and color, and the text's shared outline and shadow.
---@param region FontString
---@param size number
---@param color AUIColor
function CastBar:StyleText(region, size, color)
	local Profile = AUI.Profile
	local shadow = Options.SHADOW

	region:SetFont(AUI.Media:Font(Options.FONT), size, AUI.Media:FontFlags(Profile:Get("castBar.outline")))
	region:SetTextColor(color.r, color.g, color.b)
	region:SetShadowColor(shadow.r, shadow.g, shadow.b, Profile:Get("castBar.shadow") and shadow.a or 0)
	region:SetShadowOffset(1, -1)
end

---Sizes, places and colors the text and sets the time's format; the spell name stops short of the time while the time
---shows.
---@param frame AUICastBarFrame
function CastBar:StyleTexts(frame)
	local Profile = AUI.Profile
	local text, time, over = frame.text, frame.time, frame.over
	local timeShown = Profile:Get("castBar.time.enabled") == true

	self:StyleText(text, Profile:Get("castBar.name.size"), Profile:Get("castBar.name.color"))
	self:StyleText(time, Profile:Get("castBar.time.size"), Profile:Get("castBar.time.color"))
	text:SetShown(Profile:Get("castBar.name.enabled") == true)
	time:SetShown(timeShown)

	time:ClearAllPoints()
	time:SetPoint("RIGHT", over, "RIGHT", Profile:Get("castBar.time.x"), Profile:Get("castBar.time.y"))

	text:ClearAllPoints()
	text:SetPoint("LEFT", over, "LEFT", Profile:Get("castBar.name.x"), Profile:Get("castBar.name.y"))

	if timeShown then
		text:SetPoint("RIGHT", time, "LEFT", -TEXT_GAP, 0)
	else
		text:SetPoint("RIGHT", over, "RIGHT")
	end

	local format, properties = Options:TimeSpec(Profile:Get("castBar.time.format"))
	local components = {}

	for index, property in ipairs(properties) do
		components[index] = { property = Enum.DurationTextBindingProperty[property], formatter = self:Formatter() }
	end

	frame.binding:SetTextFormat(format, components)
end

---Gives a bar its look from the settings; the settings page's preview styles its own the same way.
---@param frame AUICastBarFrame
function CastBar:Style(frame)
	local Profile = AUI.Profile
	local height = Profile:Get("castBar.height")
	local reverse = Profile:Get("castBar.reverse") == true
	local bar = frame.bar

	frame:SetSize(Profile:Get("castBar.width"), height)
	AUI.Media:SetBarTexture(bar, Profile:Get("castBar.texture"))
	bar:SetReverseFill(reverse)
	self:StyleFill(frame)
	self:StyleLayout(frame, height)

	local fill = bar:GetStatusBarTexture()
	local background, locked = Profile:Get("castBar.background"), Profile:Get("castBar.notInterruptible")

	frame.background:SetColorTexture(background.r, background.g, background.b, background.a or 1)
	frame.locked:ClearAllPoints()
	frame.locked:SetAllPoints(fill)
	frame.lockedFill:SetColorTexture(locked.r, locked.g, locked.b, 1)
	frame.failed:ClearAllPoints()
	frame.failed:SetAllPoints(fill)

	frame.spark:ClearAllPoints()
	frame.spark:SetPoint("CENTER", fill, reverse and "LEFT" or "RIGHT")
	frame.spark:SetSize(Options.SPARK_WIDTH, Options:SparkHeight(height))

	self:StyleTexts(frame)
end

function CastBar:CreateFrame()
	if self.frame then
		return
	end

	local frame = self:Build(UIParent, "AeonUICastBar")

	frame:EnableMouse(false)
	self.frame = frame
end

---@return { point: string, x: number, y: number } position the saved place, or the default one
function CastBar:Position()
	return AUI.Profile:Get(Options.POSITION_PATH) or Options.DEFAULT_POSITION
end

---Puts the bar at its saved place, or its default one; edit mode places it too once it is registered.
function CastBar:Place()
	local frame = self.frame

	if not frame then
		return
	end

	local position = self:Position()

	frame:ClearAllPoints()
	frame:SetPoint(position.point, UIParent, position.point, position.x, position.y)
end

---@return boolean on the page's switch is on where the client can draw the bar
function CastBar:IsOn()
	return AUI.can.castBar == true and AUI.Profile:Get(Options.ENABLED_PATH) == true
end

---The player's cast, empowered cast or channel.
---@return AUICastKind? kind nil when the player is not casting
---@return LuaDurationObject? duration
---@return string? name the spell's display name, possibly secret
---@return boolean? notInterruptible possibly secret
---@return number? icon the spell's icon, possibly secret
function CastBar:Current()
	local name, displayName, icon, _, _, _, _, notInterruptible = UnitCastingInfo("player")
	local casting = issecretvalue(name) or name ~= nil
	local duration, empowered

	if casting then
		duration = UnitCastingDuration("player")
	else
		name, displayName, icon, _, _, _, notInterruptible, _, empowered = UnitChannelInfo("player")
		empowered = empowered == true and UnitEmpoweredChannelDuration ~= nil

		if issecretvalue(name) or name ~= nil then
			duration = empowered and UnitEmpoweredChannelDuration("player", true) or UnitChannelDuration("player")
		end
	end

	if not (issecretvalue(duration) or duration) then
		return nil
	end

	return Options:Kind(casting, not casting, empowered), duration, displayName, notInterruptible, icon
end

---@param name string? possibly secret, which keeps it whole
---@return string? name as the bar shows it
function CastBar:SpellName(name)
	if issecretvalue(name) or name == nil then
		return name
	end

	return Options:Shorten(name, AUI.Profile:Get("castBar.name.maxLength"))
end

---Starts the fill and the time from a cast's duration object.
---@param frame AUICastBarFrame
---@param kind AUICastKind
---@param duration LuaDurationObject
---@param name string?
---@param notInterruptible boolean?
---@param icon number?
function CastBar:Draw(frame, kind, duration, name, notInterruptible, icon)
	local Profile = AUI.Profile
	local bar = frame.bar
	local direction = Options:Drains(kind) and Enum.StatusBarTimerDirection.RemainingTime
		or Enum.StatusBarTimerDirection.ElapsedTime
	local interpolation = Profile:Get("castBar.smooth") and Enum.StatusBarInterpolation.ExponentialEaseOut
		or Enum.StatusBarInterpolation.Immediate

	bar:SetTimerDuration(duration, interpolation, direction)
	-- The easing follows the cast from its own place, not from where the last cast left the bar.
	bar:SetToTargetValue()
	frame.binding:SetDuration(duration)
	frame.binding:SetEnabled(true)
	frame.text:SetText(self:SpellName(name))
	frame.icon:SetTexture(icon)
	frame.spark:SetShown(Profile:Get("castBar.spark") == true)

	if not issecretvalue(notInterruptible) and notInterruptible == nil then
		frame.locked:SetAlpha(0)
	else
		frame.locked:SetAlphaFromBoolean(notInterruptible --[[@as boolean]], 1, 0)
	end
end

---Empties the bar for Always Show between casts.
---@param frame AUICastBarFrame
function CastBar:DrawEmpty(frame)
	frame.binding:SetEnabled(false)
	frame.bar:SetValue(0)
	frame.text:SetText("")
	frame.time:SetText("")
	frame.icon:SetTexture(nil)
	frame.spark:Hide()
	frame.locked:SetAlpha(0)
end

---Draws a still sample of a state, with a label as the spell's name: edit mode's, and the settings preview's.
---@param frame AUICastBarFrame
---@param state AUICastBarState
---@param label string
function CastBar:DrawSample(frame, state, label)
	local Profile = AUI.Profile
	local STATES = Options.STATES
	local interrupted = state == STATES.INTERRUPTED

	frame.binding:SetEnabled(false)
	frame.bar:SetValue(interrupted and 1 or Options.SAMPLE_PROGRESS)
	frame.text:SetText(self:SpellName(label))
	frame.time:SetText(Options:SampleTime(Profile:Get("castBar.time.format")))
	frame.time:SetShown(Profile:Get("castBar.time.enabled") == true and not interrupted)
	frame.icon:SetTexture(Options.SAMPLE_ICON)
	frame.spark:SetShown(Profile:Get("castBar.spark") == true and not interrupted)
	frame.locked:SetAlpha(state == STATES.NOT_INTERRUPTIBLE and 1 or 0)
	frame.failed:SetAlpha(interrupted and 1 or 0)
end

---Draws the player's cast, or the sample, or the empty bar, or hides it.
function CastBar:Update()
	local frame = self.frame

	if not frame then
		return
	end

	local on = self:IsOn()
	local kind, duration, name, notInterruptible, icon

	if on and not self.sampling then
		kind, duration, name, notInterruptible, icon = self:Current()
	end

	if not Options:Visible(on, kind ~= nil, self.sampling, self.petBattle,
		AUI.Profile:Get("castBar.alwaysShow") == true) then
		frame.binding:SetEnabled(false)
		frame:Hide()

		return
	end

	if self.sampling then
		self:DrawSample(frame, Options.STATES.CASTING, L["Cast Bar"])
	elseif kind then
		self:Draw(frame, kind, duration --[[@as LuaDurationObject]], name, notInterruptible, icon)
	else
		self:DrawEmpty(frame)
	end

	frame:Show()
end

---@param _ string
---@param unit string
function CastBar:OnCastEvent(_, unit)
	if unit == "player" then
		self:Update()
	end
end

---@param event string
function CastBar:OnPetBattleEvent(event)
	self.petBattle = event == "PET_BATTLE_OPENING_START"
	self:Update()
end

---Shows the sample whatever is being cast while edit mode is open, and draws the live cast again when it closes.
---@param shown boolean
function CastBar:Sample(shown)
	self.sampling = shown
	self:Update()
end

---Follows the events and parks Blizzard's bar while the switch is on; hides the bar, stops following them and hands
---Blizzard's bar back while it is off.
function CastBar:Apply()
	local on = self:IsOn()

	if on ~= self.following then
		self.following = on

		if on then
			self:CreateFrame()
			self.petBattle = AUI.can.petBattles == true and C_PetBattles.IsInBattle() == true

			for _, event in ipairs(CAST_EVENTS) do
				AUI.Events:Register(event, self, self.OnCastEvent)
			end

			if AUI.can.petBattles then
				for _, event in ipairs(PET_BATTLE_EVENTS) do
					AUI.Events:Register(event, self, self.OnPetBattleEvent)
				end
			end

			AUI.Events:Register("PLAYER_ENTERING_WORLD", self, self.Update)
		else
			AUI.Events:UnregisterAll(self)
		end

		AUI.CastBarBlizzard:SetParked(on)
	end

	if self.frame then
		self.frame:SetFrameStrata(AUI.Profile:Get("castBar.strata"))
		self:Style(self.frame)
	end

	self:Place()
	self:Update()
end

---@param path string? the changed setting; nil when the whole profile changed
function CastBar:OnProfileChanged(path)
	if path == nil or path:sub(1, 8) == "castBar." then
		AUI.Events:Coalesce("castBarApply", function()
			CastBar:Apply()
		end)
	end
end

function CastBar:Start()
	if self.active then
		return
	end

	self.active = true
	AUI.Callbacks:Register("Profile", self, self.OnProfileChanged)
	self:Apply()
end
