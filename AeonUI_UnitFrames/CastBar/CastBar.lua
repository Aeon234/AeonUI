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
-- The inset of the text from the bar's left and right edges, in UI units.
local TEXT_PADDING = 4
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
local LATENCY_TEXT_SIZE = 10

---@class AUICastBarFrame : Frame
---@field lines Texture[] the border, `BORDER_LINES` in order
---@field icon Texture
---@field bar StatusBar
---@field background Texture
---@field locked Frame covers the fill while the cast cannot be interrupted
---@field lockedFill Texture
---@field failed Frame covers the fill while Interrupted or Failed shows
---@field failedFill Texture
---@field zones Frame clips the empowered stage colors to the fill
---@field strip Frame spans the bar inside `zones`; the stage colors are placed on it
---@field stages Texture[] the stage colors, created as needed
---@field over Frame the spark, latency and text, above the covers
---@field latency Texture the part of the cast within the player's latency
---@field latencyText FontString
---@field pushback FontString
---@field target FontString the cast's target
---@field ticks Texture[] the channel's marks, created as needed
---@field spark Texture
---@field text FontString the spell name
---@field time FontString
---@field binding table a duration text binding; writes the time into `time`
---@field fade AnimationGroup? the live bar's Fade Out

---The cast being drawn, reused from one read to the next. Times are nil when they cannot be read.
---@class AUICastBarCast
---@field kind AUICastKind
---@field duration LuaDurationObject
---@field name string? possibly secret
---@field notInterruptible boolean? possibly secret
---@field icon number? possibly secret
---@field id string? its cast GUID
---@field startTime number? in milliseconds
---@field endTime number? in milliseconds; an empowered cast's includes its hold at full charge
---@field delay number? a cast's pushback, in milliseconds
---@field spellID number? a channel's spell, when it can be read

---The player cast bar. The client's timer drives the fill from the cast's duration object and a duration text binding
---writes the time, so no Lua runs while a cast is drawn and no secret value is read: the spell name, the icon, the
---duration and the interruptible flag go straight to widgets. Each cast event reads the cast again and draws it, or
---empties or hides the bar when there is none. An interrupted or failed cast holds its feedback on a timer, and Fade
---Out is an animation; Stage Label alone runs a timer per stage, while it is on. Times read for latency, pushback and
---the stage label are used only when they are not secret.
---@class AUICastBar
---@field active boolean started this session
---@field following boolean the events are registered
---@field sampling boolean edit mode shows the sample
---@field petBattle boolean
---@field frame AUICastBarFrame?
---@field formatter table? seconds to one decimal
---@field cast AUICastBarCast the last cast read
---@field drawn AUICastKind? the kind of cast on the bar
---@field drawnID string? its cast GUID, when it can be read
---@field channelEnd number? the first end time of the channel on the bar, for its pushback
---@field feedback boolean Interrupted or Failed is holding
---@field fading boolean Fade Out is running
---@field holdTimer table? ends the feedback
---@field stageTimer table? moves the stage label on
local CastBar = {
	active = false,
	following = false,
	sampling = false,
	petBattle = false,
	cast = {} --[[@as AUICastBarCast]],
	feedback = false,
	fading = false,
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

	local zones = CreateFrame("Frame", nil, bar)

	zones:SetClipsChildren(true)
	zones:Hide()
	frame.zones = zones
	frame.strip = CreateFrame("Frame", nil, zones)
	frame.strip:SetAllPoints(bar)
	frame.stages = {}

	frame.locked, frame.lockedFill = CreateCover(bar)
	frame.failed, frame.failedFill = CreateCover(bar)
	frame.locked:SetFrameLevel(zones:GetFrameLevel() + 2)
	frame.failed:SetFrameLevel(zones:GetFrameLevel() + 3)

	local over = CreateFrame("Frame", nil, bar)

	over:SetAllPoints()
	over:SetFrameLevel(zones:GetFrameLevel() + 4)
	frame.over = over

	frame.latency = over:CreateTexture(nil, "BACKGROUND")
	frame.latency:Hide()

	frame.spark = over:CreateTexture(nil, "OVERLAY")
	frame.spark:SetTexture(Options.SPARK_TEXTURE)
	frame.spark:SetBlendMode("ADD")

	frame.latencyText = over:CreateFontString(nil, "OVERLAY")
	frame.latencyText:SetWordWrap(false)
	frame.latencyText:Hide()

	frame.pushback = over:CreateFontString(nil, "OVERLAY")
	frame.pushback:SetWordWrap(false)

	frame.target = over:CreateFontString(nil, "OVERLAY")
	frame.target:SetJustifyH("RIGHT")
	frame.target:SetWordWrap(false)
	frame.target:Hide()

	frame.ticks = {}

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

	region:SetFont(AUI.Media:Font(Profile:Get("castBar.font")), size, AUI.Media:FontFlags(Profile:Get("castBar.outline")))
	region:SetTextColor(color.r, color.g, color.b)
	region:SetShadowColor(shadow.r, shadow.g, shadow.b, Profile:Get("castBar.shadow") and shadow.a or 0)
	region:SetShadowOffset(1, -1)
end

---The spell name stops short of whatever shows after it: the cast target, then the pushback, then the time.
---@param frame AUICastBarFrame
function CastBar:AnchorName(frame)
	local Profile = AUI.Profile
	local text, over = frame.text, frame.over

	text:ClearAllPoints()
	text:SetPoint("LEFT", over, "LEFT", TEXT_PADDING + Profile:Get("castBar.name.x"), Profile:Get("castBar.name.y"))

	if frame.target:IsShown() then
		text:SetPoint("RIGHT", frame.target, "LEFT", -TEXT_GAP, 0)
	elseif Profile:Get("castBar.pushback") then
		text:SetPoint("RIGHT", frame.pushback, "LEFT", -TEXT_GAP, 0)
	elseif Profile:Get("castBar.time.enabled") then
		text:SetPoint("RIGHT", frame.time, "LEFT", -TEXT_GAP, 0)
	else
		text:SetPoint("RIGHT", over, "RIGHT", -TEXT_PADDING, 0)
	end
end

---Sizes, places and colors the text and sets the time's format.
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
	time:SetPoint("RIGHT", over, "RIGHT", Profile:Get("castBar.time.x") - TEXT_PADDING, Profile:Get("castBar.time.y"))

	local pushback = frame.pushback
	local pushbackShown = Profile:Get("castBar.pushback") == true

	self:StyleText(pushback, Profile:Get("castBar.time.size"), Profile:Get("castBar.pushbackColor"))
	self:StyleText(frame.latencyText, LATENCY_TEXT_SIZE, { r = 1, g = 1, b = 1 })
	pushback:SetShown(pushbackShown)
	pushback:ClearAllPoints()

	if timeShown then
		pushback:SetPoint("RIGHT", time, "LEFT", -TEXT_GAP, 0)
	else
		pushback:SetPoint("RIGHT", over, "RIGHT", -TEXT_PADDING, 0)
	end

	local target = frame.target
	local targetX, targetY = Profile:Get("castBar.target.x"), Profile:Get("castBar.target.y")

	self:StyleText(target, Profile:Get("castBar.target.size"), Profile:Get("castBar.target.color"))
	target:ClearAllPoints()

	if pushbackShown then
		target:SetPoint("RIGHT", pushback, "LEFT", targetX - TEXT_GAP, targetY)
	elseif timeShown then
		target:SetPoint("RIGHT", time, "LEFT", targetX - TEXT_GAP, targetY)
	else
		target:SetPoint("RIGHT", over, "RIGHT", targetX - TEXT_PADDING, targetY)
	end

	self:AnchorName(frame)

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
	local interrupted, latency = Profile:Get("castBar.interrupted"), Profile:Get("castBar.latencyColor")

	frame.background:SetColorTexture(background.r, background.g, background.b, background.a or 1)
	frame.locked:ClearAllPoints()
	frame.locked:SetAllPoints(fill)
	frame.lockedFill:SetColorTexture(locked.r, locked.g, locked.b, 1)
	frame.failed:ClearAllPoints()
	frame.failed:SetAllPoints(fill)
	frame.failedFill:SetColorTexture(interrupted.r, interrupted.g, interrupted.b, 1)
	frame.zones:ClearAllPoints()
	frame.zones:SetAllPoints(fill)
	frame.latency:SetColorTexture(latency.r, latency.g, latency.b, latency.a or 1)

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
	local fade = frame:CreateAnimationGroup()
	local alpha = fade:CreateAnimation("Alpha")

	alpha:SetFromAlpha(1)
	alpha:SetToAlpha(0)
	alpha:SetDuration(Options.FADE_SECONDS)
	fade:SetScript("OnFinished", function()
		self:OnFaded()
	end)

	frame.fade = fade
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

---Reads the player's cast, empowered cast or channel into `self.cast`.
---@return AUICastBarCast? cast nil when the player is not casting
function CastBar:Current()
	local cast = self.cast
	local name, displayName, icon, startTime, endTime, _, castID, notInterruptible, _, _, delay = UnitCastingInfo("player")
	local casting = issecretvalue(name) or name ~= nil
	local duration, empowered, channelSpell

	if casting then
		duration = UnitCastingDuration("player")
	else
		local isEmpowered

		castID, delay = nil, nil
		name, displayName, icon, startTime, endTime, _, notInterruptible, channelSpell, isEmpowered =
			UnitChannelInfo("player")
		empowered = isEmpowered == true and UnitEmpoweredChannelDuration ~= nil

		if issecretvalue(name) or name ~= nil then
			duration = empowered and UnitEmpoweredChannelDuration("player", true) or UnitChannelDuration("player")
		end
	end

	if not (issecretvalue(duration) or duration) then
		return nil
	end

	startTime, endTime = AUI:Readable(startTime), AUI:Readable(endTime)

	if empowered and endTime and GetUnitEmpowerHoldAtMaxTime then
		endTime = endTime + (AUI:Readable(GetUnitEmpowerHoldAtMaxTime("player")) or 0)
	end

	cast.kind = Options:Kind(casting, not casting, empowered) --[[@as AUICastKind]]
	cast.duration, cast.name, cast.notInterruptible, cast.icon = duration, displayName, notInterruptible, icon
	cast.id, cast.startTime, cast.endTime, cast.delay = AUI:Readable(castID), startTime, endTime, delay
	cast.spellID = AUI:Readable(channelSpell)

	return cast
end

---@param name string? possibly secret, which keeps it whole
---@return string? name as the bar shows it
function CastBar:SpellName(name)
	if issecretvalue(name) or name == nil then
		return name
	end

	return Options:Shorten(name, AUI.Profile:Get("castBar.name.maxLength"))
end

---Shades the end of the bar a cast of that kind finishes at, with the latency's text above it while that is on.
---@param frame AUICastBarFrame
---@param share number? how much of the bar; nil hides it
---@param drains boolean the fill runs out toward the bar's start
---@param latency number in milliseconds
function CastBar:PlaceLatency(frame, share, drains, latency)
	local Profile = AUI.Profile
	local shown = share ~= nil and share > 0 and Profile:Get("castBar.latency") == true
	local zone, label = frame.latency, frame.latencyText

	zone:SetShown(shown)
	label:SetShown(shown and Profile:Get("castBar.latencyText") == true)

	if not shown then
		return
	end

	local atRight = drains == (Profile:Get("castBar.reverse") == true)
	local side = atRight and "RIGHT" or "LEFT"

	zone:ClearAllPoints()
	zone:SetPoint("TOP" .. side)
	zone:SetPoint("BOTTOM" .. side)
	zone:SetWidth(frame.bar:GetWidth() * share --[[@as number]])
	label:ClearAllPoints()
	label:SetPoint("BOTTOM" .. side, frame.over, "TOP" .. side, 0, 1)
	label:SetFormattedText("%d ms", latency)
end

---Places each stage's color across the bar; only the filled part shows them, the last color repeating.
---@param frame AUICastBarFrame
---@param boundaries number[]
function CastBar:PlaceStages(frame, boundaries)
	local width = frame.bar:GetWidth()
	local side = AUI.Profile:Get("castBar.reverse") and "RIGHT" or "LEFT"
	local direction = side == "RIGHT" and -1 or 1
	local start = 0

	for index = 1, math.max(#boundaries, #frame.stages) do
		local stage, finish = frame.stages[index], boundaries[index]

		if finish and not stage then
			stage = frame.strip:CreateTexture(nil, "ARTWORK")
			frame.stages[index] = stage
		end

		if stage then
			stage:SetShown(finish ~= nil and finish > start)
		end

		if finish and finish > start then
			local color = AUI.Profile:Get("castBar.stage." .. math.min(index, Options.STAGE_COLORS))

			stage:SetColorTexture(color.r, color.g, color.b, 1)
			stage:ClearAllPoints()
			stage:SetPoint("TOP" .. side, frame.strip, "TOP" .. side, direction * width * start, 0)
			stage:SetPoint("BOTTOM" .. side, frame.strip, "BOTTOM" .. side, direction * width * start, 0)
			stage:SetWidth(width * (finish - start))
			start = finish
		end
	end

	frame.zones:Show()
end

---@param reached integer the stages fully charged
---@param total integer the stages, the hold at full charge being the last
---@return string text
local function StageText(reached, total)
	return reached >= total - 1 and L["Hold"] or L["Stage %d"]:format(reached)
end

function CastBar:CancelStageTimer()
	if self.stageTimer then
		self.stageTimer:Cancel()
		self.stageTimer = nil
	end
end

---Writes the stage reached in the time's place, and comes back when the next one is reached.
---@param frame AUICastBarFrame
---@param boundaries number[]
---@param startTime number in milliseconds
---@param endTime number
function CastBar:UpdateStageLabel(frame, boundaries, startTime, endTime)
	local total = endTime - startTime
	local reached, nextBoundary = Options:StageReached(boundaries, (GetTime() * 1000 - startTime) / total)

	frame.time:SetText(StageText(reached, #boundaries))
	self:CancelStageTimer()

	if nextBoundary then
		local delay = math.max((startTime + total * nextBoundary) / 1000 - GetTime(), 0)

		self.stageTimer = C_Timer.NewTimer(delay, function()
			self.stageTimer = nil
			self:UpdateStageLabel(frame, boundaries, startTime, endTime)
		end)
	end
end

---Colors an empowered cast's stages and labels the one reached, from the client's stage shares, when they can be read.
---@param frame AUICastBarFrame
---@param cast AUICastBarCast
function CastBar:DrawStages(frame, cast)
	local Profile = AUI.Profile
	local shares = UnitEmpoweredStagePercentages and UnitEmpoweredStagePercentages("player", true)

	if issecretvalue(shares) or type(shares) ~= "table" or #shares == 0 or issecretvalue(shares[1]) then
		return
	end

	local boundaries = Options:Boundaries(shares)

	if Profile:Get("castBar.empowerColors") then
		self:PlaceStages(frame, boundaries)
	end

	if Profile:Get("castBar.stageLabel") and cast.startTime and cast.endTime and cast.endTime > cast.startTime then
		frame.binding:SetEnabled(false)
		frame.time:Show()
		self:UpdateStageLabel(frame, boundaries, cast.startTime, cast.endTime)
	end
end

---The channel's pushback is how much sooner it now ends than when it was first drawn.
---@param frame AUICastBarFrame
---@param cast AUICastBarCast
function CastBar:DrawPushback(frame, cast)
	local kinds = Options.KINDS
	local text = ""

	if cast.kind == kinds.CAST then
		text = Options:PushbackText(cast.delay, "+")
	elseif cast.kind == kinds.CHANNEL and cast.endTime then
		self.channelEnd = self.channelEnd or cast.endTime
		text = Options:PushbackText(self.channelEnd - cast.endTime, "-")
	end

	frame.pushback:SetText(text)
end

---Marks a draining channel's ticks, the last in its own color while Last Tick is on.
---@param frame AUICastBarFrame
---@param fractions number[]
function CastBar:ShowTicks(frame, fractions)
	local Profile = AUI.Profile
	local width, pixel = frame.bar:GetWidth(), AUI:Pixel(frame)
	local reversed = Profile:Get("castBar.reverse") == true
	local color, lastColor = Profile:Get("castBar.tickColor"), Profile:Get("castBar.lastTickColor")
	local markLast = Profile:Get("castBar.lastTick") == true

	for index, fraction in ipairs(fractions) do
		local tick = frame.ticks[index]

		if not tick then
			tick = frame.over:CreateTexture(nil, "BACKGROUND", nil, 1)
			tick:SetSnapToPixelGrid(false)
			tick:SetTexelSnappingBias(0)
			frame.ticks[index] = tick
		end

		local chosen = markLast and index == #fractions and lastColor or color
		local x = Options:TickOffset(fraction, width, reversed)

		tick:SetColorTexture(chosen.r, chosen.g, chosen.b, chosen.a or 1)
		tick:ClearAllPoints()
		tick:SetPoint("TOPLEFT", frame.over, "TOPLEFT", x, 0)
		tick:SetPoint("BOTTOMLEFT", frame.over, "BOTTOMLEFT", x, 0)
		tick:SetWidth(pixel)
		tick:Show()
	end
end

---Marks the ticks of the channel, when its spell is listed and can be read.
---@param frame AUICastBarFrame
---@param cast AUICastBarCast
function CastBar:DrawTicks(frame, cast)
	local data = cast.spellID and AUI.CastBarTickData.spells[cast.spellID]

	if not data then
		return
	end

	local seconds = cast.startTime and cast.endTime and (cast.endTime - cast.startTime) / 1000

	self:ShowTicks(frame, Options:TickFractions(data, seconds, C_SpellBook.IsSpellKnownOrInSpellBook))
end

---Sizes the cast target's name and colors it: the class color may be secret, and goes straight to the font string.
---@param frame AUICastBarFrame
---@param name string possibly secret
---@param class string possibly secret
function CastBar:ShowTarget(frame, name, class)
	local Profile = AUI.Profile
	local target = frame.target

	target:SetWidth(frame.bar:GetWidth() * Options.TARGET_SHARE)
	target:SetText(name)

	if Profile:Get("castBar.target.classColor") then
		local r, g, b = GetClassColor(class)

		target:SetTextColor(r, g, b)
	else
		local color = Profile:Get("castBar.target.color")

		target:SetTextColor(color.r, color.g, color.b)
	end

	target:Show()
	self:AnchorName(frame)
end

---Names the cast's target when the client says to show it.
---@param frame AUICastBarFrame
function CastBar:DrawTarget(frame)
	if AUI.can.castTarget and AUI.Profile:Get("castBar.target.enabled") and UnitShouldDisplaySpellTargetName("player") then
		self:ShowTarget(frame, UnitSpellTargetName("player"), UnitSpellTargetClass("player"))
	end
end

---Clears what only some casts show: the stage colors and label, the latency, the pushback, the ticks and the target.
---@param frame AUICastBarFrame
function CastBar:ClearAids(frame)
	self:CancelStageTimer()
	frame.zones:Hide()
	frame.latency:Hide()
	frame.latencyText:Hide()
	frame.pushback:SetText("")

	for _, tick in ipairs(frame.ticks) do
		tick:Hide()
	end

	if frame.target:IsShown() then
		frame.target:Hide()
		self:AnchorName(frame)
	end
end

---Starts the fill and the time from a cast's duration object.
---@param frame AUICastBarFrame
---@param cast AUICastBarCast
function CastBar:Draw(frame, cast)
	local Profile = AUI.Profile
	local bar = frame.bar
	local drains = Options:Drains(cast.kind)
	local direction = drains and Enum.StatusBarTimerDirection.RemainingTime
		or Enum.StatusBarTimerDirection.ElapsedTime
	local interpolation = Profile:Get("castBar.smooth") and Enum.StatusBarInterpolation.ExponentialEaseOut
		or Enum.StatusBarInterpolation.Immediate

	self:ClearAids(frame)
	bar:SetTimerDuration(cast.duration, interpolation, direction)
	-- The easing follows the cast from its own place, not from where the last cast left the bar.
	bar:SetToTargetValue()
	frame.binding:SetDuration(cast.duration)
	frame.binding:SetEnabled(true)
	frame.time:SetShown(Profile:Get("castBar.time.enabled") == true)
	frame.text:SetText(self:SpellName(cast.name))
	frame.icon:SetTexture(cast.icon)
	frame.spark:SetShown(Profile:Get("castBar.spark") == true)

	if not issecretvalue(cast.notInterruptible) and cast.notInterruptible == nil then
		frame.locked:SetAlpha(0)
	else
		frame.locked:SetAlphaFromBoolean(cast.notInterruptible --[[@as boolean]], 1, 0)
	end

	if Profile:Get("castBar.latency") then
		local _, _, _, latency = GetNetStats()

		self:PlaceLatency(frame, Options:LatencyShare(latency, cast.startTime, cast.endTime), drains, latency)
	end

	if Profile:Get("castBar.pushback") then
		self:DrawPushback(frame, cast)
	end

	if cast.kind == Options.KINDS.EMPOWERED then
		self:DrawStages(frame, cast)
	end

	if cast.kind == Options.KINDS.CHANNEL and Profile:Get("castBar.ticks") then
		self:DrawTicks(frame, cast)
	end

	self:DrawTarget(frame)
end

---Empties the bar for Always Show between casts.
---@param frame AUICastBarFrame
function CastBar:DrawEmpty(frame)
	self:ClearAids(frame)
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
	local channeling = state == STATES.CHANNELING
	local empowered = state == STATES.EMPOWERED
	local timeText = Options:SampleTime(Profile:Get("castBar.time.format"))
	local timeShown = Profile:Get("castBar.time.enabled") == true and not interrupted

	self:ClearAids(frame)
	frame.binding:SetEnabled(false)
	frame.bar:SetValue(interrupted and 1 or Options.SAMPLE_PROGRESS)
	frame.text:SetText(self:SpellName(label))
	frame.icon:SetTexture(Options.SAMPLE_ICON)
	frame.spark:SetShown(Profile:Get("castBar.spark") == true and not interrupted)
	frame.locked:SetAlpha(state == STATES.NOT_INTERRUPTIBLE and 1 or 0)
	frame.failed:SetAlpha(interrupted and 1 or 0)

	if not interrupted then
		if Profile:Get("castBar.target.enabled") then
			local _, class = UnitClass("player")

			self:ShowTarget(frame, TARGET, class)
		end

		local latency = Options.SAMPLE_LATENCY

		self:PlaceLatency(frame, Options:LatencyShare(latency, 0, Options.SAMPLE_TOTAL * 1000), channeling, latency)

		if not empowered and Profile:Get("castBar.pushback") then
			frame.pushback:SetText(Options:PushbackText(Options.SAMPLE_PUSHBACK, channeling and "-" or "+"))
		end
	end

	if channeling and Profile:Get("castBar.ticks") then
		self:ShowTicks(frame, Options:TickFractions({ ticks = Options.SAMPLE_TICKS }, nil, nop))
	end

	if empowered then
		local boundaries = Options:Boundaries(Options.SAMPLE_STAGES)

		if Profile:Get("castBar.empowerColors") then
			self:PlaceStages(frame, boundaries)
		end

		if Profile:Get("castBar.stageLabel") then
			timeText = StageText(Options:StageReached(boundaries, Options.SAMPLE_PROGRESS), #boundaries)
			timeShown = true
		end
	end

	frame.time:SetText(timeText)
	frame.time:SetShown(timeShown)
end

---Ends Interrupted, Failed or Fade Out at once and clears what they showed.
function CastBar:CancelEnding()
	local frame = self.frame

	if self.holdTimer then
		self.holdTimer:Cancel()
		self.holdTimer = nil
	end

	self.feedback, self.fading = false, false

	if frame then
		local fade = frame.fade --[[@as AnimationGroup]]

		fade:Stop()
		frame:SetAlpha(1)
		frame.failed:SetAlpha(0)
	end
end

---Fades the bar out as it stands.
function CastBar:StartFade()
	local frame = self.frame --[[@as AUICastBarFrame]]

	self.fading = true
	self.drawn, self.drawnID = nil, nil
	frame.binding:SetEnabled(false)
	frame.spark:Hide()
	local fade = frame.fade --[[@as AnimationGroup]]

	fade:Play()
end

function CastBar:OnFaded()
	self:CancelEnding()
	self:Update()
end

---Holds Interrupted or Failed on the full bar, in its color with the timer hidden, then fades or goes.
---@param text string
function CastBar:ShowFeedback(text)
	local frame = self.frame --[[@as AUICastBarFrame]]
	local hold = AUI.Profile:Get("castBar.holdTime")

	self:ClearAids(frame)
	self.drawn, self.drawnID, self.channelEnd = nil, nil, nil
	frame.binding:SetEnabled(false)
	frame.bar:SetValue(1)
	frame.text:SetText(text)
	frame.time:Hide()
	frame.spark:Hide()
	frame.locked:SetAlpha(0)
	frame.failed:SetAlpha(1)
	self.feedback = true

	if hold > 0 then
		self.holdTimer = C_Timer.NewTimer(hold, function()
			self.holdTimer = nil
			self:EndFeedback()
		end)
	else
		self:EndFeedback()
	end
end

function CastBar:EndFeedback()
	self.feedback = false

	if AUI.Profile:Get("castBar.fade") and not AUI.Profile:Get("castBar.alwaysShow") then
		self:StartFade()
	else
		self:CancelEnding()
		self:Update()
	end
end

---Draws the player's cast, or the sample, or the empty bar, or hides it; Interrupted, Failed and Fade Out stay until
---they end or a new cast replaces them. A finished cast fades while Fade Out is on.
function CastBar:Update()
	local frame = self.frame

	if not frame then
		return
	end

	local Profile = AUI.Profile
	local on = self:IsOn()
	local alwaysShow = Profile:Get("castBar.alwaysShow") == true
	local cast

	if on and not self.sampling then
		cast = self:Current()
	end

	if cast or not on or self.sampling then
		self:CancelEnding()
	end

	local ending = self.feedback or self.fading
	local startFade = cast == nil and self.drawn ~= nil and not alwaysShow and Profile:Get("castBar.fade") == true

	if not Options:Visible(on, cast ~= nil or ending or startFade, self.sampling, self.petBattle, alwaysShow) then
		self:CancelEnding()
		self:CancelStageTimer()
		self.drawn, self.drawnID, self.channelEnd = nil, nil, nil
		frame.binding:SetEnabled(false)
		frame:Hide()

		return
	end

	if self.sampling then
		self:DrawSample(frame, Options.STATES.CASTING, L["Cast Bar"])
	elseif cast then
		self:Draw(frame, cast)
		self.drawn, self.drawnID = cast.kind, cast.id
	elseif ending then
		return
	elseif startFade then
		self.channelEnd = nil
		self:CancelStageTimer()
		self:StartFade()

		return
	else
		self.drawn, self.drawnID, self.channelEnd = nil, nil, nil

		if alwaysShow then
			self:DrawEmpty(frame)
		else
			self:CancelStageTimer()
			frame.binding:SetEnabled(false)
			frame:Hide()

			return
		end
	end

	frame:Show()
end

---@param castGUID string the event's, possibly secret
---@return boolean drawn the bar is drawing that cast; a cast GUID that cannot be compared counts
function CastBar:IsDrawnCast(castGUID)
	if self.drawn ~= Options.KINDS.CAST then
		return false
	end

	return self.drawnID == nil or issecretvalue(castGUID) or castGUID == self.drawnID
end

---Interrupted and Failed come before the cast's stop: a stopped channel says so itself, by who interrupted it, and an
---empowered cast by whether it completed. Failed for a spell other than the drawn cast changes nothing.
---@param event string
---@param unit string
---@param castGUID string?
---@param _ number? the spell ID
---@param detail any `interruptedBy` on a channel's stop, `complete` on an empowered cast's
function CastBar:OnCastEvent(event, unit, castGUID, _, detail)
	if unit ~= "player" then
		return
	end

	if event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
		if self:IsDrawnCast(castGUID --[[@as string]]) then
			self:ShowFeedback(event == "UNIT_SPELLCAST_FAILED" and FAILED or INTERRUPTED)
		end

		return
	end

	if self.drawn and ((event == "UNIT_SPELLCAST_CHANNEL_STOP" and AUI:Readable(detail) ~= nil)
		or (event == "UNIT_SPELLCAST_EMPOWER_STOP" and AUI:Readable(detail) == false)) then
		self:ShowFeedback(INTERRUPTED)

		return
	end

	if event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_EMPOWER_START" then
		self.channelEnd = nil
	end

	self:Update()
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
