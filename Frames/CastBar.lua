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
---@field settings table? the resolved settings from the last `Apply`
---@field boundaries number[]? the empowered stage boundaries of the current cast, as shares of the bar
---@field stagesPlaced boolean? stage colors were placed for the cast being started

---Cast bars: the player's own bar and the bars attached to target, focus and boss frames.
---@class AUICastBar
---@field GAP number space between an attached cast bar and its frame
---@field formatter table? the shared one-decimal time formatter, created on first use
local CastBar = {
	GAP = GAP,
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

	local text = bar:CreateFontString(nil, "OVERLAY")
	local time = bar:CreateFontString(nil, "OVERLAY")

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
		latency = bar:CreateFontString(nil, "OVERLAY"),
		locked = Cover(bar, 1),
		failed = Cover(bar, 2),
		zones = zones,
		strip = strip,
		stages = {},
		stageLabel = bar:CreateFontString(nil, "OVERLAY"),
		ticker = CreateFrame("Frame", nil, bar),
	}

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
	name:SetPoint("RIGHT", bar, "RIGHT", -self:TimeReserve(settings), settings.name.y)
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
				stage:SetPoint("TOP", widgets.strip)
				stage:SetPoint("BOTTOM", widgets.strip)
				stage:SetPoint(side, widgets.strip, side, direction * width * start, 0)
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

	function bar.PostCastStart(element, unit, _, notInterruptible, name)
		local settings = widgets.settings

		if not settings then
			return
		end

		widgets.failed:Hide()
		widgets.locked:SetAlphaFromBoolean(notInterruptible, 1, 0)
		widgets.time:SetShown(settings.time.enabled)
		widgets.zones:SetShown(widgets.stagesPlaced == true and settings.empowerColors == true)
		widgets.stageLabel:Hide()
		widgets.stagesPlaced = nil
		Fill(widgets, CastColor(widgets, unit), settings.classColor)

		if settings.name.maxLength > 0 and name and not issecretvalue(name) then
			element.Text:SetText(CastBar:Shorten(name, settings.name.maxLength))
		end

		if widgets.latency:IsShown() then
			widgets.latency:SetFormattedText("%d ms", (select(4, GetNetStats())))
		end
	end

	function bar.PostCastInterruptible(_, _, _, notInterruptible)
		widgets.locked:SetAlphaFromBoolean(notInterruptible, 1, 0)
	end

	local function Feedback()
		widgets.failed:Show()
		widgets.locked:SetAlpha(0)
		widgets.time:Hide()
		widgets.zones:Hide()
		widgets.stageLabel:Hide()
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
---@param sample table `progress` 0 to 1, `channel`, `locked`, `failed`, `stages` (each stage's share), `name`, `icon`
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

	if widgets.safeZone:IsShown() then
		local safe = widgets.safeZone

		safe:ClearAllPoints()
		safe:SetPoint("TOP")
		safe:SetPoint("BOTTOM")
		safe:SetPoint((sample.channel ~= settings.reverse) and "LEFT" or "RIGHT")
		safe:SetWidth(width * 0.08)
		widgets.latency:SetText("48 ms")
	end

	bar:Show()
end
