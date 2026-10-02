local AUI = select(2, ...)

local Schema = AUI.Schema

-- Space between an attached cast bar and its frame.
local GAP = 4

local SPARK_TEXTURE = "Interface\\CastingBar\\UI-CastingBar-Spark"
local SPARK_WIDTH, SPARK_HEIGHT = 10, 30

-- Empowered stages that have their own color; later stages reuse the last.
local STAGE_COLORS = 4

-- Space reserved for the time, in multiples of its font size: "12.3", or "12.3 / 45.6".
local TIME_WIDTH, TIME_TOTAL_WIDTH = 2.5, 5.5

-- The cast target's share of the bar's width, at its right end before the time.
local TARGET_SHARE = 0.35

local GLOW_ATLAS = "ui-hud-nameplates-importantcast"

-- Pixel Lines glow: how far round the bar the lines travel per second at speed 1, as a share of its perimeter.
local GLOW_STEP = 0.05

-- Duration-text components for each time format.
local TIME_FORMATS = {
	remaining = { "{}", "RemainingDuration" },
	elapsed = { "{}", "ElapsedDuration" },
	remainingTotal = { "{} / {}", "RemainingDuration", "TotalDuration" },
	elapsedTotal = { "{} / {}", "ElapsedDuration", "TotalDuration" },
}

---The widgets of one cast bar. On live frames `bar` is oUF's Castbar and `icon`, `text`, `time`, `spark` and
---`safeZone` its sub-widgets; the rest are AeonUI's, driven from oUF's callbacks.
---@class AUICastBarWidgets
---@field holder Frame the background and border, behind the bar; shown while idle when Always Show is on
---@field background Texture
---@field border Texture[]
---@field bar StatusBar
---@field icon Texture
---@field text FontString the spell name
---@field time FontString
---@field spark Texture
---@field safeZone Texture the latency region
---@field latency FontString the latency in milliseconds
---@field locked Texture covers the fill while the cast cannot be interrupted
---@field failed Texture covers the fill while the Interrupted or Failed label shows
---@field zones Frame clips the empowered stage colors to the fill
---@field strip Frame spans the bar inside `zones`; the stage colors are placed on it
---@field stages Texture[]
---@field stageLabel FontString
---@field ticker Frame updates the stage label while the bar shows
---@field ticks Texture[] the player's channel tick marks
---@field ready Texture covers the fill while your interrupt is ready
---@field onCooldown Texture covers the fill while your interrupt is on cooldown
---@field kick Frame clips the cooldown mark and interrupt window to the bar
---@field positioner StatusBar filled to the cast's elapsed time; the marker starts at its edge
---@field marker StatusBar filled to the interrupt's remaining cooldown; the mark sits at its edge
---@field mark Texture where the interrupt comes off cooldown
---@field window Texture the part of the cast after the mark
---@field target FontString the cast's target
---@field glow Frame the important-spell glow around the bar
---@field glowArt Texture the Blizzard style
---@field glowPulse AnimationGroup
---@field glowLines Texture[] the Pixel Lines style
---@field glowPhase number
---@field unit string? the unit of the cast being shown
---@field notInterruptible boolean? the cast's flag, possibly secret
---@field settings table? the resolved settings from the last `Apply`
---@field boundaries number[]? the empowered stage boundaries of the current cast, as shares of the bar
---@field stagesPlaced boolean? stage colors were placed for the cast being started

---Cast bars: the player's own bar and the bars attached to target, focus and boss frames.
---@class AUICastBar
---@field GAP number space between an attached cast bar and its frame
---@field formatter table? the shared one-decimal time formatter, created on first use
---@field interrupt integer? the player's interrupt spell, nil when none is known
---@field blizzardBlocked boolean? Blizzard's player cast bar is blocked
---@field live AUICastBarWidgets[] the live bars that show interrupt colors or the cooldown mark
local CastBar = {
	GAP = GAP,
	live = {},
}
AUI.CastBar = CastBar

-- Settings ------------------------------------------------------------------------------------------------

---@param config table
---@param key string
---@return table? settings the frame's cast bar settings, or nil for a frame without one
function CastBar:Resolve(config, key)
	local base = "frames." .. key .. ".castbar."

	if not Schema:Field(base .. "enabled") then
		return nil
	end

	local settings = { key = key, attached = Schema:Field(base .. "side") ~= nil }

	for path in pairs(Schema.fields) do
		if path:sub(1, #base) == base then
			local name = path:sub(#base + 1)
			local value = Schema:Read(config, path)
			local group, field = name:match("^(%a+)%.(%w+)$")

			if group then
				settings[group] = settings[group] or {}
				settings[group][field] = value
			else
				settings[name] = value
			end
		end
	end

	settings.font = Schema:Read(config, "frames." .. key .. ".text.font")

	return settings
end

---@param config table
---@param key string
---@return number space how far a shown attached cast bar reaches past its frame, gap included; 0 without one
function CastBar:Extent(config, key)
	local base = "frames." .. key .. ".castbar."

	if not Schema:Field(base .. "side") or not Schema:Read(config, base .. "enabled") then
		return 0
	end

	return GAP + Schema:Read(config, base .. "height")
end

---@param settings table
---@param frameWidth number the width of the frame an attached bar belongs to
---@return number width the whole bar's width, icon included
---@return number height
function CastBar:Size(settings, frameWidth)
	local width = settings.width

	if settings.attached and settings.matchWidth then
		width = frameWidth
	end

	return width, settings.height
end

---@param settings table
---@return string point the bar's point
---@return string relative the frame's point, or the screen's for a bar that is not attached
---@return number x
---@return number y
function CastBar:Points(settings)
	if not settings.attached then
		return "CENTER", "CENTER", settings.x, settings.y
	end

	if settings.side == "above" then
		return "BOTTOM", "TOP", settings.x, settings.y + GAP
	end

	return "TOP", "BOTTOM", settings.x, settings.y - GAP
end

---@param settings table
---@return number width the space kept free for the time at the bar's right end, so a long spell name stops before it
function CastBar:TimeReserve(settings)
	if not settings.time.enabled then
		return 0
	end

	local format = settings.time.format
	local scale = (format == "remainingTotal" or format == "elapsedTotal") and TIME_TOTAL_WIDTH or TIME_WIDTH

	return settings.time.size * scale + math.abs(settings.time.x) + 4
end

---@param stages number[] each stage's share of the bar, in order
---@return number[] boundaries where each stage ends, as shares of the bar
function CastBar:Boundaries(stages)
	local boundaries, total = {}, 0

	for index, share in ipairs(stages) do
		total = total + share
		boundaries[index] = math.min(total, 1)
	end

	return boundaries
end

---@param boundaries number[]
---@param progress number how much of the bar is filled, 0 to 1
---@return integer reached the stages fully charged
function CastBar:StageReached(boundaries, progress)
	local reached = 0

	for index, boundary in ipairs(boundaries) do
		if progress >= boundary then
			reached = index
		end
	end

	return reached
end

---@param name string
---@param maxLength integer 0 for no limit
---@return string name the name cut to `maxLength` letters with an ellipsis
function CastBar:Shorten(name, maxLength)
	if maxLength <= 0 or strlenutf8(name) <= maxLength then
		return name
	end

	local count, cut = 0, #name

	for position in name:gmatch("()[^\128-\191]") do
		count = count + 1

		if count > maxLength then
			cut = (position --[[@as integer]]) - 1
			break
		end
	end

	return name:sub(1, cut) .. "…"
end

---@param settings table
---@param barWidth number the bar's width, icon excluded
---@return number width the cast target's width; 0 while it is off
function CastBar:TargetReserve(settings, barWidth)
	if not (settings.target and settings.target.enabled) then
		return 0
	end

	return math.floor(barWidth * TARGET_SHARE)
end

---Where a channel's ticks fall, as shares of the channel's time; the last tick, at the channel's end, is left out.
---@param data AUIChannelTicks
---@param duration number? the channel's length in seconds, needed for an interval
---@param talentKnown boolean? the data's talent is known
---@return number[] fractions
function CastBar:TickFractions(data, duration, talentKnown)
	local fractions = {}

	if data.interval then
		if not duration or duration <= 0 then
			return fractions
		end

		local count = math.floor(duration / data.interval + 0.001)

		for tick = 1, count do
			local fraction = tick * data.interval / duration

			if fraction < 0.999 then
				fractions[#fractions + 1] = fraction
			end
		end

		return fractions
	end

	local ticks = talentKnown and data.talentTicks or data.ticks or 0

	for tick = 1, ticks - 1 do
		fractions[tick] = tick / ticks
	end

	return fractions
end

---@param fraction number how much of the channel has passed
---@param width number
---@param reversed boolean the bar fills right to left
---@return number x the tick's distance from the bar's left edge on a draining channel
function CastBar:TickOffset(fraction, width, reversed)
	if reversed then
		return fraction * width
	end

	return (1 - fraction) * width
end

---The Pixel Lines glow: evenly spaced lines running clockwise round a rectangle, each kept to the side it starts on.
---@param width number
---@param height number
---@param count integer
---@param phase number 0 to 1, how far round the lines have travelled
---@param thickness number
---@return table[] lines `x`, `y` (down from the top left), `w` and `h`
function CastBar:GlowLines(width, height, count, phase, thickness)
	local perimeter = 2 * (width + height)
	local length = perimeter / count / 2
	local lines = {}

	for index = 1, count do
		local start = ((phase + (index - 1) / count) % 1) * perimeter
		local line

		if start < width then
			line = { x = start, y = 0, w = math.min(length, width - start), h = thickness }
		elseif start < width + height then
			local along = start - width

			line = { x = width - thickness, y = along, w = thickness, h = math.min(length, height - along) }
		elseif start < 2 * width + height then
			local along = start - width - height
			local w = math.min(length, width - along)

			line = { x = width - along - w, y = height - thickness, w = w, h = thickness }
		else
			local along = start - 2 * width - height
			local h = math.min(length, height - along)

			line = { x = 0, y = height - along - h, w = thickness, h = h }
		end

		lines[index] = line
	end

	return lines
end

-- Widgets -------------------------------------------------------------------------------------------------

---@param parent Frame
---@return Texture[] edges top, bottom, left and right
local function Border(parent)
	local edges = {}

	for index = 1, 4 do
		local edge = parent:CreateTexture(nil, "BORDER")

		edge:SetColorTexture(0, 0, 0, 1)
		edges[index] = edge
	end

	return edges
end

---@param bar StatusBar
---@param sublevel integer
---@return Texture cover a texture over the bar's fill
local function Cover(bar, sublevel)
	local cover = bar:CreateTexture(nil, "ARTWORK", nil, sublevel)

	cover:SetAllPoints(bar:GetStatusBarTexture())
	cover:SetColorTexture(1, 1, 1, 1)
	cover:Hide()

	return cover
end

---Creates a cast bar's widgets.
---@param parent Frame the frame an attached bar belongs to, or the screen for the player's bar
---@return AUICastBarWidgets widgets
function CastBar:Create(parent)
	local holder = CreateFrame("Frame", nil, parent)
	local bar = CreateFrame("StatusBar", nil, parent)

	holder:Hide()
	bar:SetFrameLevel(holder:GetFrameLevel() + 1)
	AUI.Media:SetBarTexture(bar, AUI.Media.FLAT)
	bar:Hide()

	local background = holder:CreateTexture(nil, "BACKGROUND")

	background:SetAllPoints()
	background:SetColorTexture(1, 1, 1, 1)

	local zones = CreateFrame("Frame", nil, bar)

	zones:SetAllPoints(bar:GetStatusBarTexture())
	zones:SetClipsChildren(true)

	local strip = CreateFrame("Frame", nil, zones)

	strip:SetAllPoints(bar)

	-- oUF and the client can write text before `Apply` styles it, so every font string starts from a template font.
	local text = bar:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	local time = bar:CreateFontString(nil, "OVERLAY", "NumberFontNormal")

	text:SetWordWrap(false)
	time:SetWordWrap(false)

	local widgets = {
		holder = holder,
		background = background,
		border = Border(holder),
		bar = bar,
		icon = bar:CreateTexture(nil, "ARTWORK"),
		text = text,
		time = time,
		spark = bar:CreateTexture(nil, "OVERLAY", nil, -1),
		safeZone = bar:CreateTexture(nil, "ARTWORK", nil, 3),
		latency = bar:CreateFontString(nil, "OVERLAY", "NumberFontNormal"),
		ready = Cover(bar, 1),
		onCooldown = Cover(bar, 1),
		locked = Cover(bar, 2),
		failed = Cover(bar, 3),
		ticks = {},
		target = bar:CreateFontString(nil, "OVERLAY", "NumberFontNormal"),
		glowLines = {},
		glowPhase = 0,
		zones = zones,
		strip = strip,
		stages = {},
		stageLabel = bar:CreateFontString(nil, "OVERLAY", "NumberFontNormal"),
		ticker = CreateFrame("Frame", nil, bar),
	}

	-- The cooldown mark: two invisible timed bars placed end to end, so the mark lands at elapsed plus remaining
	-- cooldown without any time handled in Lua.
	local kick = CreateFrame("Frame", nil, bar)

	kick:SetAllPoints(bar)
	kick:SetClipsChildren(true)
	kick:Hide()

	local positioner = CreateFrame("StatusBar", nil, kick)
	local marker = CreateFrame("StatusBar", nil, kick)

	for _, timed in ipairs({ positioner, marker }) do
		AUI.Media:SetBarTexture(timed, AUI.Media.FLAT)
		timed:SetStatusBarColor(1, 1, 1, 0)
	end

	positioner:SetAllPoints(bar)
	widgets.kick, widgets.positioner, widgets.marker = kick, positioner, marker
	widgets.window = kick:CreateTexture(nil, "ARTWORK")
	widgets.mark = kick:CreateTexture(nil, "OVERLAY")
	widgets.mark:SetColorTexture(1, 1, 1, 1)
	widgets.window:SetColorTexture(1, 1, 1, 1)
	widgets.target:SetWordWrap(false)
	widgets.target:SetJustifyH("RIGHT")

	local glow = CreateFrame("Frame", nil, bar)

	glow:SetPoint("TOPLEFT", holder, "TOPLEFT", -2, 2)
	glow:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 2, -2)
	glow:SetFrameLevel(bar:GetFrameLevel() + 5)
	glow:Hide()
	widgets.glow = glow
	widgets.glowArt = glow:CreateTexture(nil, "OVERLAY")
	widgets.glowArt:SetAllPoints()
	widgets.glowArt:SetBlendMode("ADD")

	local pulse = widgets.glowArt:CreateAnimationGroup()
	local rise, fall = pulse:CreateAnimation("Alpha"), pulse:CreateAnimation("Alpha")

	pulse:SetLooping("REPEAT")
	rise:SetFromAlpha(0)
	rise:SetToAlpha(1)
	rise:SetDuration(1)
	rise:SetOrder(1)
	fall:SetFromAlpha(1)
	fall:SetToAlpha(0)
	fall:SetDuration(1)
	fall:SetOrder(2)
	widgets.glowPulse = pulse

	glow:SetScript("OnUpdate", function(_, elapsed)
		CastBar:StepGlow(widgets, elapsed)
	end)

	widgets.spark:SetTexture(SPARK_TEXTURE)
	widgets.spark:SetBlendMode("ADD")
	widgets.spark:SetSize(SPARK_WIDTH, SPARK_HEIGHT)
	widgets.locked:Show()
	widgets.locked:SetAlpha(0)
	widgets.safeZone:SetColorTexture(1, 1, 1, 1)
	widgets.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	zones:Hide()

	bar:HookScript("OnShow", function()
		holder:Show()
	end)
	bar:HookScript("OnHide", function()
		local settings = widgets.settings

		holder:SetShown(settings ~= nil and settings.enabled and settings.alwaysShow)
	end)

	return widgets
end

---Places the edges of a border just outside a region.
---@param border Texture[]
---@param region Region
---@param size number thickness in the region's units
local function PlaceBorder(border, region, size)
	local top, bottom, left, right = unpack(border)

	for _, edge in ipairs(border) do
		edge:ClearAllPoints()
		edge:SetShown(size > 0)
	end

	top:SetPoint("BOTTOMLEFT", region, "TOPLEFT", -size, 0)
	top:SetPoint("BOTTOMRIGHT", region, "TOPRIGHT", size, 0)
	top:SetHeight(size)
	bottom:SetPoint("TOPLEFT", region, "BOTTOMLEFT", -size, 0)
	bottom:SetPoint("TOPRIGHT", region, "BOTTOMRIGHT", size, 0)
	bottom:SetHeight(size)
	left:SetPoint("TOPRIGHT", region, "TOPLEFT")
	left:SetPoint("BOTTOMRIGHT", region, "BOTTOMLEFT")
	left:SetWidth(size)
	right:SetPoint("TOPLEFT", region, "TOPRIGHT")
	right:SetPoint("BOTTOMLEFT", region, "BOTTOMRIGHT")
	right:SetWidth(size)
end

---@param font FontString
---@param settings table
---@param size number
---@param color table
local function StyleText(font, settings, size, color)
	font:SetFont(AUI.Media:Font(settings.font), size, AUI.Media:FontFlags(settings.outline))
	font:SetTextColor(color.r, color.g, color.b, 1)
	font:SetShadowColor(0, 0, 0, 1)
	font:SetShadowOffset(settings.shadow and 1 or 0, settings.shadow and -1 or 0)
end

---Colors the fill: one color, or a gradient from it to the second color.
---@param widgets AUICastBarWidgets
---@param color table
---@param flat boolean? one color even when the gradient is on
local function Fill(widgets, color, flat)
	local settings = widgets.settings --[[@as table]]
	local fill = widgets.bar:GetStatusBarTexture()

	if settings.gradient and not flat then
		local second = settings.gradientColor

		fill:SetGradient(settings.gradientDirection, CreateColor(color.r, color.g, color.b, 1),
			CreateColor(second.r, second.g, second.b, 1))
	else
		widgets.bar:SetStatusBarColor(color.r, color.g, color.b, 1)
	end
end

---Applies a cast bar's settings: size and position, look, text and the player's aids. Not protected.
---@param widgets AUICastBarWidgets
---@param settings table from `CastBar:Resolve`
---@param anchor Region the frame an attached bar follows, or the screen
---@param frameWidth number
function CastBar:Apply(widgets, settings, anchor, frameWidth)
	local holder, bar, icon = widgets.holder, widgets.bar, widgets.icon
	local width, height = self:Size(settings, frameWidth)
	local point, relative, x, y = self:Points(settings)
	local pixel = AUI:Pixel(holder)

	widgets.settings = settings

	holder:ClearAllPoints()
	holder:SetSize(width, height)
	holder:SetPoint(point, anchor, relative, x, y)
	if settings.strata then
		holder:SetFrameStrata(settings.strata)
		bar:SetFrameStrata(settings.strata)
	end

	bar:SetFrameLevel(holder:GetFrameLevel() + 1)
	holder:SetShown(settings.enabled and (bar:IsShown() or settings.alwaysShow))

	widgets.background:SetVertexColor(settings.background.r, settings.background.g, settings.background.b,
		settings.background.a or 1)
	PlaceBorder(widgets.border, holder, settings.border * pixel)

	-- The icon is a square at one end, inside the width.
	local iconRight = settings.iconSide == "RIGHT"
	local barWidth = width - (settings.icon and height or 0)

	bar:ClearAllPoints()
	icon:ClearAllPoints()
	icon:SetShown(settings.icon)

	if settings.icon then
		icon:SetSize(height, height)
		icon:SetPoint(iconRight and "TOPRIGHT" or "TOPLEFT", holder)
		bar:SetPoint("TOPLEFT", holder, "TOPLEFT", iconRight and 0 or height, 0)
		bar:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", iconRight and -height or 0, 0)
	else
		bar:SetAllPoints(holder)
	end

	AUI.Media:SetBarTexture(bar, settings.texture)
	bar:SetReverseFill(settings.reverse)
	Fill(widgets, settings.color)

	local locked, interrupted = settings.notInterruptible, settings.interrupted

	widgets.locked:SetAllPoints(bar:GetStatusBarTexture())
	widgets.locked:SetColorTexture(locked.r, locked.g, locked.b, 1)
	widgets.failed:SetAllPoints(bar:GetStatusBarTexture())
	widgets.failed:SetColorTexture(interrupted.r, interrupted.g, interrupted.b, 1)
	widgets.zones:SetAllPoints(bar:GetStatusBarTexture())

	local spark = widgets.spark

	spark:ClearAllPoints()
	spark:SetPoint("CENTER", bar:GetStatusBarTexture(), settings.reverse and "LEFT" or "RIGHT")
	spark:SetAlpha(settings.spark and 1 or 0)

	local name, time = widgets.text, widgets.time

	StyleText(name, settings, settings.name.size, settings.name.color)
	StyleText(time, settings, settings.time.size, settings.time.color)
	StyleText(widgets.stageLabel, settings, settings.time.size, settings.time.color)
	StyleText(widgets.latency, settings, math.max(settings.time.size - 4, 6), settings.time.color)
	name:ClearAllPoints()
	name:SetPoint("LEFT", bar, "LEFT", settings.name.x, settings.name.y)
	name:SetPoint("RIGHT", bar, "RIGHT", -(self:TimeReserve(settings) + self:TargetReserve(settings, barWidth)),
		settings.name.y)
	name:SetJustifyH("LEFT")
	name:SetShown(settings.name.enabled)
	time:ClearAllPoints()
	time:SetPoint("RIGHT", bar, "RIGHT", settings.time.x, settings.time.y)
	time:SetShown(settings.time.enabled)
	widgets.stageLabel:ClearAllPoints()
	widgets.stageLabel:SetPoint("RIGHT", bar, "RIGHT", settings.time.x, settings.time.y)
	widgets.stageLabel:Hide()

	local latency = settings.latency

	if latency then
		local color = settings.latencyColor

		widgets.safeZone:SetVertexColor(color.r, color.g, color.b, color.a or 1)
		widgets.latency:ClearAllPoints()
		widgets.latency:SetPoint("BOTTOMRIGHT", widgets.safeZone, "BOTTOMRIGHT", -1, 1)
	end

	widgets.safeZone:SetShown(latency == true)
	widgets.latency:SetShown(latency == true and settings.latencyText == true)

	for _, tick in ipairs(widgets.ticks) do
		tick:Hide()
	end

	local target = widgets.target
	local targetWidth = self:TargetReserve(settings, barWidth)

	target:Hide()

	if targetWidth > 0 then
		StyleText(target, settings, settings.target.size, { r = 1, g = 1, b = 1 })
		target:ClearAllPoints()
		target:SetPoint("RIGHT", bar, "RIGHT", settings.target.x - self:TimeReserve(settings), settings.target.y)
		target:SetWidth(targetWidth)
	end

	local ready, cooldown = settings.readyColor, settings.cooldownColor

	widgets.ready:SetAllPoints(bar:GetStatusBarTexture())
	widgets.onCooldown:SetAllPoints(bar:GetStatusBarTexture())
	widgets.ready:Hide()
	widgets.onCooldown:Hide()
	widgets.kick:Hide()

	if ready then
		widgets.ready:SetColorTexture(ready.r, ready.g, ready.b, 1)
		widgets.onCooldown:SetColorTexture(cooldown.r, cooldown.g, cooldown.b, 1)
		widgets.marker:SetSize(barWidth, height)
		widgets.mark:SetWidth(pixel)

		local window = settings.windowColor

		widgets.window:SetVertexColor(window.r, window.g, window.b, window.a or 1)
	end

	self:ApplyGlow(widgets, settings)
end

---Sets up the important-spell glow in its style; it stays hidden until a cast shows it.
---@param widgets AUICastBarWidgets
---@param settings table
function CastBar:ApplyGlow(widgets, settings)
	local glow = widgets.glow

	glow:Hide()
	widgets.glowPulse:Stop()

	if not settings.glow then
		return
	end

	local color, art = settings.glowColor, widgets.glowArt
	local pixel = settings.glowStyle == "pixel"

	art:SetShown(not pixel)

	if not pixel then
		art:SetAtlas(GLOW_ATLAS)
		art:SetVertexColor(color.r, color.g, color.b, 1)
	end

	for index = 1, math.max(settings.glowLines, #widgets.glowLines) do
		local line = widgets.glowLines[index]

		if not line and index <= settings.glowLines then
			line = glow:CreateTexture(nil, "OVERLAY")
			widgets.glowLines[index] = line
		end

		if line then
			line:SetColorTexture(color.r, color.g, color.b, 1)
			line:SetShown(pixel and index <= settings.glowLines)
		end
	end
end

---Moves the Pixel Lines glow on by one frame.
---@param widgets AUICastBarWidgets
---@param elapsed number seconds since the last frame
function CastBar:StepGlow(widgets, elapsed)
	local settings = widgets.settings

	if not settings or settings.glowStyle ~= "pixel" then
		return
	end

	local glow = widgets.glow
	local pixel = AUI:Pixel(glow)

	widgets.glowPhase = (widgets.glowPhase + elapsed * settings.glowSpeed * GLOW_STEP) % 1

	local lines = self:GlowLines(glow:GetWidth(), glow:GetHeight(), settings.glowLines, widgets.glowPhase,
		settings.glowThickness * pixel)

	for index, spot in ipairs(lines) do
		local line = widgets.glowLines[index]

		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", glow, "TOPLEFT", spot.x, -spot.y)
		line:SetSize(spot.w, spot.h)
	end
end

---@return table formatter a one-decimal seconds formatter
local function Formatter()
	local formatter = C_StringUtil.CreateNumericRuleFormatter()

	formatter:SetBreakpoints({ { threshold = 0, step = 0.1, format = "%.1f" } })

	return formatter
end

---Sets how the time reads, as a duration-text format the client fills in, so no time is handled in Lua.
---@param binding table a duration-text binding
---@param format string a time format choice
function CastBar:SetTimeFormat(binding, format)
	local spec = TIME_FORMATS[format] or TIME_FORMATS.remaining
	local formatter = self.formatter or Formatter()
	local components = {}

	self.formatter = formatter

	for index = 2, #spec do
		components[#components + 1] = {
			property = Enum.DurationTextBindingProperty[spec[index]],
			formatter = formatter,
		}
	end

	binding:SetTextFormat(spec[1], components)
end

---@param boundaries number[] where each stage ends
---@return number[] ends where each colored part ends: the stages, then the rest of the bar
function CastBar:Segments(boundaries)
	local ends = {}

	for index, boundary in ipairs(boundaries) do
		ends[index] = boundary
	end

	if (ends[#ends] or 0) < 1 then
		ends[#ends + 1] = 1
	end

	return ends
end

---Places the empowered stage colors across the bar; only the filled part shows them. Each part takes the color of
---its stage, the last color repeating.
---@param widgets AUICastBarWidgets
---@param boundaries number[]
---@param width number the bar's width
function CastBar:PlaceStages(widgets, boundaries, width)
	local settings = widgets.settings --[[@as table]]
	local side = widgets.bar:GetReverseFill() and "RIGHT" or "LEFT"
	local direction = side == "RIGHT" and -1 or 1
	local ends = self:Segments(boundaries)
	local start = 0

	for index = 1, math.max(#ends, #widgets.stages) do
		local stage, finish = widgets.stages[index], ends[index]

		if finish and not stage then
			stage = widgets.strip:CreateTexture(nil, "ARTWORK")
			stage:SetColorTexture(1, 1, 1, 1)
			widgets.stages[index] = stage
		end

		if stage then
			stage:ClearAllPoints()
			stage:SetShown(finish ~= nil and finish > start)

			if finish and finish > start then
				local color = settings.stage[tostring(math.min(index, STAGE_COLORS))]

				stage:SetVertexColor(color.r, color.g, color.b, 1)
				stage:SetPoint("TOP" .. side, widgets.strip, "TOP" .. side, direction * width * start, 0)
				stage:SetPoint("BOTTOM" .. side, widgets.strip, "BOTTOM" .. side, direction * width * start, 0)
				stage:SetWidth(width * (finish - start))
				start = finish
			end
		end
	end
end

-- Live frames ---------------------------------------------------------------------------------------------

---@param widgets AUICastBarWidgets
---@param unit string
---@return table color the fill color for a cast on the unit
local function CastColor(widgets, unit)
	local settings = widgets.settings --[[@as table]]

	if settings.classColor then
		local _, class = UnitClass(unit)

		class = AUI:Readable(class)

		local color = class and AUI.oUF.colors.class[class]

		if color then
			return color
		end
	end

	return settings.color
end

---Finds the player's interrupt: a pet's first, then the player's own; within each, the last known in the list.
function CastBar:FindInterrupt()
	local _, class = UnitClass("player")
	local spells = class and AUI.CastData.interrupts[class] or {}
	local pet, own

	for _, spellID in ipairs(spells) do
		if C_SpellBook.IsSpellKnownOrInSpellBook(spellID, Enum.SpellBookSpellBank.Pet) then
			pet = spellID
		elseif C_SpellBook.IsSpellKnownOrInSpellBook(spellID) then
			own = spellID
		end
	end

	self.interrupt = pet or own
end

---Watches what the interrupt colors and cooldown mark depend on: the spells known, and cooldowns.
function CastBar:Start()
	self:FindInterrupt()
	AUI.Events:Register("SPELLS_CHANGED", self, self.FindInterrupt)
	AUI.Events:Register("PLAYER_SPECIALIZATION_CHANGED", self, self.FindInterrupt)
	AUI.Events:Register("UNIT_PET", self, function(_, _, unit)
		if unit == "player" then
			self:FindInterrupt()
		end
	end)
	AUI.Events:Register("SPELL_UPDATE_COOLDOWN", self, self.OnCooldown)
end

function CastBar:OnCooldown()
	for _, widgets in ipairs(self.live) do
		if widgets.bar:IsShown() and widgets.unit then
			self:RefreshInterrupt(widgets)
		end
	end
end

---@param region Region
---@param flag boolean? possibly secret
---@param shown number alpha when the flag is true
---@param hidden number alpha when it is false
local function AlphaFrom(region, flag, shown, hidden)
	if not issecretvalue(flag) and flag == nil then
		region:SetAlpha(hidden)
	else
		region:SetAlphaFromBoolean(flag --[[@as boolean]], shown, hidden)
	end
end

---Places the cooldown mark: the positioner fills to the cast's elapsed time from the cast's starting edge, and the
---marker, starting at its edge, fills to the interrupt's remaining cooldown.
---@param widgets AUICastBarWidgets
---@param channel boolean the cast drains rather than fills
function CastBar:PlaceMark(widgets, channel)
	local reversed = widgets.bar:GetReverseFill()
	local fromRight = channel ~= reversed
	local near, far = fromRight and "RIGHT" or "LEFT", fromRight and "LEFT" or "RIGHT"
	local positioner, marker, mark, window = widgets.positioner, widgets.marker, widgets.mark, widgets.window

	positioner:SetReverseFill(fromRight)
	marker:SetReverseFill(fromRight)
	marker:ClearAllPoints()
	marker:SetPoint(near, positioner:GetStatusBarTexture(), far)
	mark:ClearAllPoints()
	mark:SetPoint("TOP", marker:GetStatusBarTexture(), "TOP" .. far)
	mark:SetPoint("BOTTOM", marker:GetStatusBarTexture(), "BOTTOM" .. far)
	window:ClearAllPoints()
	window:SetPoint("TOP" .. near, marker:GetStatusBarTexture(), "TOP" .. far)
	window:SetPoint("BOTTOM" .. far, widgets.bar, "BOTTOM" .. far)
end

---Shows the interrupt colors and cooldown mark for the cast on a live bar, from the interrupt's cooldown duration.
---@param widgets AUICastBarWidgets
function CastBar:RefreshInterrupt(widgets)
	local settings = widgets.settings --[[@as table]]
	local colors = settings.interruptReady or settings.interruptCooldown
	local marks = settings.kickMark or settings.kickWindow
	local cooldown = self.interrupt and (colors or marks) and C_Spell.GetSpellCooldownDuration(self.interrupt)

	if not cooldown then
		widgets.ready:Hide()
		widgets.onCooldown:Hide()
		widgets.kick:Hide()

		return
	end

	local ready = cooldown:IsZero()

	widgets.ready:SetShown(settings.interruptReady == true)
	widgets.ready:SetAlphaFromBoolean(ready, 1, 0)
	widgets.onCooldown:SetShown(settings.interruptCooldown == true)
	widgets.onCooldown:SetAlphaFromBoolean(ready, 0, 1)

	local unit = widgets.unit --[[@as string]]
	local cast, channel = UnitCastingDuration(unit), false

	if not cast then
		cast, channel = UnitChannelDuration(unit), true
	end

	if not marks or not cast then
		widgets.kick:Hide()

		return
	end

	local total = cast:GetTotalDuration()

	widgets.positioner:SetMinMaxValues(0, total)
	widgets.positioner:SetValue(cast:GetElapsedDuration())
	widgets.marker:SetMinMaxValues(0, total)
	widgets.marker:SetValue(cooldown:GetRemainingDuration())
	self:PlaceMark(widgets, channel)
	widgets.mark:SetShown(settings.kickMark == true)
	widgets.mark:SetAlphaFromBoolean(ready, 0, 1)
	widgets.window:SetShown(settings.kickWindow == true)
	widgets.kick:Show()
	AlphaFrom(widgets.kick, widgets.notInterruptible, 0, 1)
end

---Places the player's channel ticks for a channel in the tick list.
---@param widgets AUICastBarWidgets
---@param spellID number? possibly secret
function CastBar:PlaceTicks(widgets, spellID)
	local settings = widgets.settings --[[@as table]]

	for _, tick in ipairs(widgets.ticks) do
		tick:Hide()
	end

	if not settings.ticks or issecretvalue(spellID) or not spellID then
		return
	end

	local data = AUI.CastData.channels[spellID]

	if not data then
		return
	end

	local duration

	if data.interval then
		local start, finish = select(4, UnitChannelInfo("player"))

		if issecretvalue(start) or issecretvalue(finish) or not start then
			return
		end

		duration = (finish - start) / 1000
	end

	local known = data.talent ~= nil and C_SpellBook.IsSpellKnownOrInSpellBook(data.talent)

	self:ShowTicks(widgets, self:TickFractions(data, duration, known))
end

---@param widgets AUICastBarWidgets
---@param fractions number[]
function CastBar:ShowTicks(widgets, fractions)
	local settings = widgets.settings --[[@as table]]
	local bar = widgets.bar
	local width, pixel = bar:GetWidth(), AUI:Pixel(bar)
	local color = settings.tickColor

	for index, fraction in ipairs(fractions) do
		local tick = widgets.ticks[index]

		if not tick then
			tick = bar:CreateTexture(nil, "OVERLAY", nil, -2)
			widgets.ticks[index] = tick
		end

		local last = index == #fractions and settings.lastTick

		tick:SetColorTexture(last and 1 or color.r, last and 1 or color.g, last and 1 or color.b, last and 1 or color.a or 1)
		local x = self:TickOffset(fraction, width, bar:GetReverseFill())

		tick:ClearAllPoints()
		tick:SetPoint("TOPLEFT", bar, "TOPLEFT", x, 0)
		tick:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x, 0)
		tick:SetWidth(pixel)
		tick:Show()
	end
end

---Shows the cast's target, class-colored, when the client says to show it.
---@param widgets AUICastBarWidgets
---@param unit string
function CastBar:ShowTarget(widgets, unit)
	local settings, target = widgets.settings --[[@as table]], widgets.target

	if not (settings.target and settings.target.enabled and UnitShouldDisplaySpellTargetName(unit)) then
		target:Hide()

		return
	end

	local class = UnitSpellTargetClass(unit)
	local color = (issecretvalue(class) or class ~= nil) and C_ClassColor.GetClassColor(class)

	target:SetText(UnitSpellTargetName(unit))

	if color then
		target:SetTextColor(color:GetRGB())
	else
		target:SetTextColor(1, 1, 1)
	end

	target:Show()
end

---Shows the important-spell glow while the cast's spell is one the client marks important.
---@param widgets AUICastBarWidgets
---@param spellID number? possibly secret
function CastBar:ShowGlow(widgets, spellID)
	local settings = widgets.settings --[[@as table]]

	if not settings.glow or (not issecretvalue(spellID) and spellID == nil) then
		widgets.glow:Hide()

		return
	end

	widgets.glow:Show()
	widgets.glow:SetAlphaFromBoolean(C_Spell.IsSpellImportant(spellID --[[@as number]]), 1, 0)

	if settings.glowStyle == "blizzard" then
		widgets.glowPulse:Play()
	end
end

---Blocks Blizzard's player cast bar, or lifts the block. oUF stops its events, but Edit Mode still shows it to be moved,
---so while AeonUI's player cast bar is on it carries the client's `alwaysBlocked` roleset (it has none of its own).
---`SetRolesets` is protected: call this only out of combat.
---@param block boolean
function CastBar:BlockBlizzardCastBar(block)
	local blizzard = PlayerCastingBarFrame

	if not blizzard or self.blizzardBlocked == block then
		return
	end

	blizzard:SetRolesets(block and "alwaysBlocked" or nil)
	self.blizzardBlocked = block
end

---Turns Blizzard's pet cast bar back on after oUF stopped it with the player's: AeonUI shows no pet frame.
function CastBar:RestorePetCastBar()
	local pet = PetCastingBarFrame

	if not pet then
		return
	end

	-- What the bar's own OnLoad registers: its unit's cast events through SetUnit, and pet changes.
	pet:SetUnit(nil)
	pet:SetUnit("pet", false, false)
	pet:RegisterEvent("UNIT_PET")
end

---Makes a cast bar oUF's Castbar element on a frame, with AeonUI's colors, stages and feedback in its callbacks.
---@param frame table the oUF frame
---@param widgets AUICastBarWidgets
function CastBar:Attach(frame, widgets)
	local bar = widgets.bar --[[@as table]]

	bar.Icon = widgets.icon
	bar.Text = widgets.text
	bar.Time = widgets.time
	bar.Spark = widgets.spark
	bar.SafeZone = widgets.safeZone
	bar.Time.binding = C_DurationUtil.CreateDurationTextBinding()
	self:SetTimeFormat(bar.Time.binding, "remaining")

	function bar.PostCastStart(element, unit, spellID, notInterruptible, name)
		local settings = widgets.settings

		if not settings then
			return
		end

		widgets.unit = unit
		widgets.notInterruptible = notInterruptible
		widgets.failed:Hide()
		CastBar:PlaceTicks(widgets, spellID)
		CastBar:RefreshInterrupt(widgets)
		CastBar:ShowTarget(widgets, unit)
		CastBar:ShowGlow(widgets, spellID)
		widgets.locked:SetAlphaFromBoolean(notInterruptible, 1, 0)
		widgets.time:SetShown(settings.time.enabled)
		widgets.zones:SetShown(widgets.stagesPlaced == true and settings.empowerColors == true)
		widgets.stageLabel:Hide()
		widgets.stagesPlaced = nil
		Fill(widgets, CastColor(widgets, unit), settings.classColor)

		if settings.name.maxLength > 0 and not issecretvalue(name) and name then
			element.Text:SetText(CastBar:Shorten(name, settings.name.maxLength))
		end

		if widgets.latency:IsShown() then
			widgets.latency:SetFormattedText("%d ms", (select(4, GetNetStats())))
		end
	end

	function bar.PostCastInterruptible(_, _, _, notInterruptible)
		widgets.notInterruptible = notInterruptible
		widgets.locked:SetAlphaFromBoolean(notInterruptible, 1, 0)
		AlphaFrom(widgets.kick, notInterruptible, 0, 1)
	end

	local function Feedback()
		widgets.failed:Show()
		widgets.locked:SetAlpha(0)
		widgets.time:Hide()
		widgets.zones:Hide()
		widgets.stageLabel:Hide()
		widgets.ready:Hide()
		widgets.onCooldown:Hide()
		widgets.kick:Hide()
		widgets.glow:Hide()
		widgets.target:Hide()

		for _, tick in ipairs(widgets.ticks) do
			tick:Hide()
		end
	end

	bar.PostCastFail = Feedback
	bar.PostCastInterrupted = Feedback

	function bar.UpdatePips(element, stages)
		widgets.boundaries = CastBar:Boundaries(stages)
		widgets.stagesPlaced = true
		CastBar:PlaceStages(widgets, widgets.boundaries, element:GetWidth())
	end

	-- The earned stage, read from the fill while the client reports it as a plain number. oUF owns the bar's own
	-- OnUpdate, so a child frame, which runs only while the bar shows, drives the label.
	widgets.ticker:SetScript("OnUpdate", function()
		local settings, boundaries = widgets.settings, widgets.boundaries

		if not settings or not boundaries or not settings.stageLabel or not widgets.zones:IsShown() then
			return
		end

		local value, maximum = bar:GetValue(), select(2, bar:GetMinMaxValues())

		if issecretvalue(value) or issecretvalue(maximum) or maximum <= 0 then
			widgets.stageLabel:Hide()

			return
		end

		local reached = CastBar:StageReached(boundaries, value / maximum)

		widgets.time:Hide()
		widgets.stageLabel:SetText(reached >= #boundaries and AUI.L["Hold"] or AUI.L["Stage %d"]:format(reached))
		widgets.stageLabel:Show()
	end)

	frame.Castbar = bar

	if frame.key ~= "player" then
		self.live[#self.live + 1] = widgets
	end
end

---Applies the element options oUF reads: hold time, smoothing and the time format.
---@param widgets AUICastBarWidgets
---@param settings table
function CastBar:ApplyElement(widgets, settings)
	local bar = widgets.bar --[[@as table]]

	bar.timeToHold = settings.holdTime
	bar.smoothing = settings.smooth and Enum.StatusBarInterpolation.ExponentialEaseOut
		or Enum.StatusBarInterpolation.Immediate

	if bar.Time and bar.Time.binding then
		self:SetTimeFormat(bar.Time.binding, settings.time.format)
	end
end

-- Previews ------------------------------------------------------------------------------------------------

---Shows a sample cast, for the settings preview.
---@param widgets AUICastBarWidgets
---@param sample table `progress` 0 to 1, `channel`, `locked`, `failed`, `stages` (each stage's share), `name`,
---`icon`, `ticks` (a tick count), `mark` (where the interrupt comes off cooldown, 0 to 1), `important`, `target` and
---`targetColor`
function CastBar:ShowSample(widgets, sample)
	local settings = widgets.settings --[[@as table]]
	local bar = widgets.bar
	local width = bar:GetWidth()

	bar:SetMinMaxValues(0, 1)
	bar:SetValue(sample.failed and 1 or sample.progress)
	Fill(widgets, settings.color)
	widgets.icon:SetTexture(sample.icon)
	widgets.text:SetText(sample.failed or self:Shorten(sample.name, settings.name.maxLength))
	widgets.time:SetText(("%.1f"):format(sample.remaining))
	widgets.time:SetShown(settings.time.enabled and not sample.failed)
	widgets.locked:SetAlpha(sample.locked and not sample.failed and 1 or 0)
	widgets.failed:SetShown(sample.failed ~= nil)
	widgets.spark:SetShown(not sample.failed)
	widgets.stageLabel:Hide()

	local stages = sample.stages and settings.empowerColors

	widgets.zones:SetShown(stages == true)

	if stages then
		local boundaries = self:Boundaries(sample.stages)
		local reached = self:StageReached(boundaries, sample.progress)

		self:PlaceStages(widgets, boundaries, width)

		if settings.stageLabel then
			widgets.time:Hide()
			widgets.stageLabel:SetText(reached >= #boundaries and AUI.L["Hold"] or AUI.L["Stage %d"]:format(reached))
			widgets.stageLabel:Show()
		end
	end

	for _, tick in ipairs(widgets.ticks) do
		tick:Hide()
	end

	if sample.ticks and settings.ticks then
		self:ShowTicks(widgets, self:TickFractions({ ticks = sample.ticks }))
	end

	local mark = sample.mark and not sample.failed

	widgets.ready:SetShown(mark and settings.interruptReady == true)
	widgets.ready:SetAlpha(1)
	widgets.onCooldown:Hide()
	widgets.kick:SetShown(mark and (settings.kickMark or settings.kickWindow) == true)

	if mark then
		widgets.positioner:SetMinMaxValues(0, 1)
		widgets.positioner:SetValue(sample.progress)
		widgets.marker:SetMinMaxValues(0, 1)
		widgets.marker:SetValue(math.max(sample.mark - sample.progress, 0))
		self:PlaceMark(widgets, sample.channel == true)
		widgets.mark:SetShown(settings.kickMark == true)
		widgets.mark:SetAlpha(1)
		widgets.window:SetShown(settings.kickWindow == true)
		widgets.kick:SetAlpha(1)
	end

	local target = widgets.target
	local showTarget = sample.target and settings.target and settings.target.enabled and not sample.failed

	target:SetShown(showTarget == true)

	if showTarget then
		local color = sample.targetColor or { r = 1, g = 1, b = 1 }

		target:SetText(sample.target)
		target:SetTextColor(color.r, color.g, color.b)
	end

	widgets.glow:SetShown(sample.important == true and settings.glow == true)
	widgets.glow:SetAlpha(1)

	if widgets.glow:IsShown() and settings.glowStyle == "blizzard" then
		widgets.glowPulse:Play()
	end

	if widgets.safeZone:IsShown() then
		local safe = widgets.safeZone

		local side = (sample.channel ~= settings.reverse) and "LEFT" or "RIGHT"

		safe:ClearAllPoints()
		safe:SetPoint("TOP" .. side)
		safe:SetPoint("BOTTOM" .. side)
		safe:SetWidth(width * 0.08)
		widgets.latency:SetText("48 ms")
	end

	bar:Show()
end
