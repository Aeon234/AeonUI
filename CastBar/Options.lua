local AUI = select(2, ...)

local Schema = AUI.Schema

local ELLIPSIS = "\226\128\166"

---The player cast bar's profile settings and its frame-free rules: which duration a cast is drawn from, the direction
---its fill runs, when the bar shows, the spell name's length, the time's formats and the sample's values.
---@class AUICastBarOptions
---@field ENABLED_PATH string the page's switch
---@field POSITION_PATH string the bar's place, set in edit mode
---@field DEFAULT_POSITION { point: string, x: number, y: number }
---@field STRATAS string[] the Frame Strata choices, in the order the page lists them
---@field ORIENTATIONS string[] the Gradient Direction choices
---@field SIDES string[] the Icon Side choices
---@field TIME_FORMATS string[] the Time Format choices
---@field BORDER_COLOR AUIColor
---@field SPARK_TEXTURE string
---@field SPARK_WIDTH number
---@field FONT string a LibSharedMedia font name
---@field SHADOW AUIColor
---@field SAMPLE_PROGRESS number how far a sample is filled, 0 to 1
---@field SAMPLE_TOTAL number a sample cast's length, in seconds
---@field SAMPLE_ICON number a sample cast's icon, a file ID
---@field SAMPLE_LATENCY number a sample cast's latency, in milliseconds
---@field SAMPLE_PUSHBACK number a sample cast's pushback, in milliseconds
---@field SAMPLE_STAGES number[] each stage's share of a sample empowered cast
---@field STAGE_COLORS number how many stage colors there are; later stages repeat the last
---@field MAX_HOLD number the longest Interrupted or Failed stays, in seconds
---@field FADE_SECONDS number
---@field SAMPLE_TICKS number how many ticks a sample channel has
---@field TARGET_SHARE number how much of the bar the cast target's name may take
---@field MIN_WIDTH number
---@field MAX_WIDTH number
---@field MIN_HEIGHT number
---@field MAX_HEIGHT number
---@field MAX_BORDER number
---@field MIN_TEXT number
---@field MAX_TEXT number
---@field MAX_OFFSET number how far a text moves from its place, either way
---@field MAX_LENGTH number
local Options = {
	ENABLED_PATH = "castBar.enabled",
	POSITION_PATH = "castBar.position",
	DEFAULT_POSITION = { point = "CENTER", x = 0, y = -254 },
	STRATAS = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG" },
	ORIENTATIONS = { "HORIZONTAL", "VERTICAL" },
	SIDES = { "LEFT", "RIGHT" },
	TIME_FORMATS = { "REMAINING", "ELAPSED", "REMAINING_TOTAL", "ELAPSED_TOTAL" },
	BORDER_COLOR = { r = 0, g = 0, b = 0, a = 1 },
	SPARK_TEXTURE = "Interface\\CastingBar\\UI-CastingBar-Spark",
	SPARK_WIDTH = 10,
	FONT = "Expressway",
	SHADOW = { r = 0, g = 0, b = 0, a = 1 },
	SAMPLE_PROGRESS = 0.6,
	SAMPLE_TOTAL = 2.5,
	SAMPLE_ICON = 134400,
	SAMPLE_LATENCY = 100,
	SAMPLE_PUSHBACK = 400,
	SAMPLE_STAGES = { 0.25, 0.25, 0.25, 0.25 },
	STAGE_COLORS = 4,
	MAX_HOLD = 3,
	FADE_SECONDS = 0.2,
	SAMPLE_TICKS = 5,
	TARGET_SHARE = 0.35,
	MIN_WIDTH = 100,
	MAX_WIDTH = 800,
	MIN_HEIGHT = 6,
	MAX_HEIGHT = 60,
	MAX_BORDER = 4,
	MIN_TEXT = 6,
	MAX_TEXT = 48,
	MAX_OFFSET = 200,
	MAX_LENGTH = 60,
}
AUI.CastBarOptions = Options

-- The spark's height at the default bar height; a taller bar keeps the same reach past its edges.
local SPARK_HEIGHT, SPARK_REACH = 30, 14
-- Each time format's text and the duration properties it shows, as `Enum.DurationTextBindingProperty` names.
local TIME_SPECS = {
	REMAINING = { "{}", "RemainingDuration" },
	ELAPSED = { "{}", "ElapsedDuration" },
	REMAINING_TOTAL = { "{} / {}", "RemainingDuration", "TotalDuration" },
	ELAPSED_TOTAL = { "{} / {}", "ElapsedDuration", "TotalDuration" },
}

Schema:Choices("castBarStrata", Options.STRATAS)
Schema:Choices("castBarOrientation", Options.ORIENTATIONS)
Schema:Choices("castBarSide", Options.SIDES)
Schema:Choices("castBarTimeFormat", Options.TIME_FORMATS)

Schema:Boolean(Options.ENABLED_PATH, false)
Schema:Position(Options.POSITION_PATH)
Schema:Boolean("castBar.alwaysShow", false)
Schema:Number("castBar.width", 386, Options.MIN_WIDTH, Options.MAX_WIDTH, true)
Schema:Number("castBar.height", 16, Options.MIN_HEIGHT, Options.MAX_HEIGHT, true)
Schema:Choice("castBar.strata", "castBarStrata", "MEDIUM")
Schema:String("castBar.texture", "flat", 64)
Schema:Color("castBar.color", { r = 1, g = 0.71, b = 0.19 })
Schema:Boolean("castBar.classColor", false)
Schema:Boolean("castBar.gradient", true)
Schema:Color("castBar.gradientColor", { r = 1, g = 0.682, b = 0.224 })
Schema:Choice("castBar.gradientDirection", "castBarOrientation", "HORIZONTAL")
Schema:Color("castBar.background", { r = 1, g = 1, b = 1, a = 0.5 })
Schema:Number("castBar.border", 1, 0, Options.MAX_BORDER, true)
Schema:Color("castBar.notInterruptible", { r = 0.8, g = 0.1, b = 0.1 })
Schema:Boolean("castBar.spark", true)
Schema:Boolean("castBar.reverse", false)
Schema:Boolean("castBar.smooth", true)
Schema:Boolean("castBar.icon", false)
Schema:Choice("castBar.iconSide", "castBarSide", "LEFT")
Schema:Choice("castBar.outline", "fontOutline", "SLUG")
Schema:Boolean("castBar.shadow", true)
Schema:Boolean("castBar.name.enabled", true)
Schema:Number("castBar.name.size", 14, Options.MIN_TEXT, Options.MAX_TEXT, true)
Schema:Color("castBar.name.color", { r = 1, g = 1, b = 1 })
Schema:Number("castBar.name.x", 0, -Options.MAX_OFFSET, Options.MAX_OFFSET, true)
Schema:Number("castBar.name.y", 0, -Options.MAX_OFFSET, Options.MAX_OFFSET, true)
Schema:Number("castBar.name.maxLength", 0, 0, Options.MAX_LENGTH, true)
Schema:Boolean("castBar.time.enabled", true)
Schema:Number("castBar.time.size", 14, Options.MIN_TEXT, Options.MAX_TEXT, true)
Schema:Color("castBar.time.color", { r = 1, g = 1, b = 1 })
Schema:Number("castBar.time.x", 0, -Options.MAX_OFFSET, Options.MAX_OFFSET, true)
Schema:Number("castBar.time.y", 0, -Options.MAX_OFFSET, Options.MAX_OFFSET, true)
Schema:Choice("castBar.time.format", "castBarTimeFormat", "REMAINING")
Schema:Color("castBar.interrupted", { r = 0.8, g = 0.1, b = 0.1 })
Schema:Number("castBar.holdTime", 0.6, 0, Options.MAX_HOLD)
Schema:Boolean("castBar.fade", false)
Schema:Boolean("castBar.latency", true)
Schema:Color("castBar.latencyColor", { r = 1, g = 0.25, b = 0.25, a = 0.4 })
Schema:Boolean("castBar.latencyText", false)
Schema:Boolean("castBar.pushback", false)
Schema:Color("castBar.pushbackColor", { r = 1, g = 0.2, b = 0.2 })
Schema:Boolean("castBar.empowerColors", true)
Schema:Color("castBar.stage.1", { r = 0.51, g = 0.53, b = 0.52 })
Schema:Color("castBar.stage.2", { r = 0.62, g = 0.12, b = 0.16 })
Schema:Color("castBar.stage.3", { r = 1, g = 0.45, b = 0.11 })
Schema:Color("castBar.stage.4", { r = 1, g = 0.71, b = 0.19 })
Schema:Boolean("castBar.stageLabel", false)
Schema:Boolean("castBar.ticks", true)
Schema:Color("castBar.tickColor", { r = 0, g = 0, b = 0, a = 0.7 })
Schema:Boolean("castBar.lastTick", false)
Schema:Color("castBar.lastTickColor", { r = 1, g = 1, b = 1 })
Schema:Boolean("castBar.target.enabled", false)
Schema:Boolean("castBar.target.classColor", true)
Schema:Color("castBar.target.color", { r = 1, g = 1, b = 1 })
Schema:Number("castBar.target.size", 14, Options.MIN_TEXT, Options.MAX_TEXT, true)
Schema:Number("castBar.target.x", 0, -Options.MAX_OFFSET, Options.MAX_OFFSET, true)
Schema:Number("castBar.target.y", 0, -Options.MAX_OFFSET, Options.MAX_OFFSET, true)

---The kinds of cast the bar draws, each with the duration it is drawn from and the way its fill runs: casts and
---empowered casts fill as they run; channels start full and drain.
---@enum AUICastKind
Options.KINDS = {
	CAST = "CAST",
	EMPOWERED = "EMPOWERED",
	CHANNEL = "CHANNEL",
}

---The preview's states.
---@enum AUICastBarState
Options.STATES = {
	CASTING = "CASTING",
	CHANNELING = "CHANNELING",
	EMPOWERED = "EMPOWERED",
	NOT_INTERRUPTIBLE = "NOT_INTERRUPTIBLE",
	INTERRUPTED = "INTERRUPTED",
}

---@param kind AUICastKind
---@return boolean drains the fill shows the remaining time rather than the elapsed time
function Options:Drains(kind)
	return kind == self.KINDS.CHANNEL
end

---Which kind of cast `UnitCastingInfo` and `UnitChannelInfo` describe.
---@param casting boolean `UnitCastingInfo` returned a cast
---@param channeling boolean `UnitChannelInfo` returned a channel
---@param empowered boolean the channel is empowered (its `isEmpowered`, never secret)
---@return AUICastKind? kind nil when the player is not casting
function Options:Kind(casting, channeling, empowered)
	if casting then
		return self.KINDS.CAST
	elseif channeling then
		return empowered and self.KINDS.EMPOWERED or self.KINDS.CHANNEL
	end
end

---@param on boolean the page's switch is on
---@param casting boolean a cast is drawn
---@param sampling boolean edit mode shows the sample
---@param petBattle boolean a pet battle is in progress
---@param alwaysShow boolean the empty bar stays between casts
---@return boolean shown
function Options:Visible(on, casting, sampling, petBattle, alwaysShow)
	if not on then
		return false
	end

	return sampling or ((casting or alwaysShow) and not petBattle)
end

---@param height number the bar's height
---@return number height the spark's
function Options:SparkHeight(height)
	return math.max(SPARK_HEIGHT, height + SPARK_REACH)
end

---Cuts a spell name to a number of letters, counting UTF-8 characters, and marks the cut with an ellipsis.
---@param name string
---@param maxLength number 0 leaves every name whole
---@return string
function Options:Shorten(name, maxLength)
	if maxLength <= 0 then
		return name
	end

	local count = 0

	for position in name:gmatch("()[^\128-\191]") do
		count = count + 1

		if count > maxLength then
			return name:sub(1, (position --[[@as integer]]) - 1) .. ELLIPSIS
		end
	end

	return name
end

---@param format string a `castBarTimeFormat` choice
---@return string text the binding's format
---@return string[] properties the `Enum.DurationTextBindingProperty` names it fills in; Remaining's for an unknown choice
function Options:TimeSpec(format)
	local spec = TIME_SPECS[format] or TIME_SPECS.REMAINING

	return spec[1], { unpack(spec, 2) }
end

---How much of the bar the player's latency covers.
---@param latency number in milliseconds
---@param startTime number? the cast's start, in milliseconds; nil when it cannot be read
---@param endTime number? its end
---@return number? share 0 to 1; nil when the cast's length is unknown
function Options:LatencyShare(latency, startTime, endTime)
	if not startTime or not endTime or endTime <= startTime then
		return nil
	end

	return math.min(math.max(latency, 0) / (endTime - startTime), 1)
end

---@param delay number? how far the cast was pushed, in milliseconds
---@param sign string `+` for a cast, which ends later, or `-` for a channel, which ends sooner
---@return string text empty while nothing was pushed
function Options:PushbackText(delay, sign)
	if not delay or delay <= 0 then
		return ""
	end

	return ("%s%.1f"):format(sign, delay / 1000)
end

---@param shares number[] each stage's share of the bar, in order
---@return number[] boundaries where each stage ends, as shares of the bar
function Options:Boundaries(shares)
	local boundaries, total = {}, 0

	for index, share in ipairs(shares) do
		total = total + share
		boundaries[index] = math.min(total, 1)
	end

	return boundaries
end

---@param boundaries number[]
---@param progress number how much of the cast has passed, 0 to 1
---@return integer reached the stages fully charged
---@return number? nextBoundary where the next stage ends
function Options:StageReached(boundaries, progress)
	for index, boundary in ipairs(boundaries) do
		if progress < boundary then
			return index - 1, boundary
		end
	end

	return #boundaries, nil
end

---Where a channel's marks fall, as shares of its time. A tick at the channel's start or end needs no mark.
---@param data AUICastBarTicks
---@param seconds number? the channel's length, needed for an interval
---@param isKnown fun(spellID: integer): boolean whether the player knows a spell
---@return number[] fractions in order
function Options:TickFractions(data, seconds, isKnown)
	local fractions = {}

	if data.interval then
		if seconds and seconds > 0 then
			for tick = 1, math.floor(seconds / data.interval + 0.001) do
				local fraction = tick * data.interval / seconds

				if fraction < 0.999 then
					fractions[#fractions + 1] = fraction
				end
			end
		end

		return fractions
	end

	local spans

	if data.missiles then
		spans = data.missiles - 1

		for spellID, extra in pairs(data.addMissiles or {}) do
			if isKnown(spellID) then
				spans = spans + extra
			end
		end
	else
		spans = data.talent and data.talentTicks and isKnown(data.talent) and data.talentTicks or data.ticks or 0
	end

	for tick = 1, spans - 1 do
		fractions[tick] = tick / spans
	end

	return fractions
end

---@param fraction number how much of the channel has passed
---@param width number the bar's
---@param reversed boolean the fill runs out to the right
---@return number x the tick's distance from the bar's left edge on a draining channel
function Options:TickOffset(fraction, width, reversed)
	return (reversed and fraction or 1 - fraction) * width
end

---What the time reads on a sample cast, in a time format.
---@param format string a `castBarTimeFormat` choice
---@return string
function Options:SampleTime(format)
	local total = self.SAMPLE_TOTAL
	local elapsed = total * self.SAMPLE_PROGRESS
	local shown = (format == "ELAPSED" or format == "ELAPSED_TOTAL") and elapsed or total - elapsed

	if format == "REMAINING_TOTAL" or format == "ELAPSED_TOTAL" then
		return ("%.1f / %.1f"):format(shown, total)
	end

	return ("%.1f"):format(shown)
end
