local AUI = select(2, ...)

local Schema = AUI.Schema

-- The empty backing behind every segment, as on the unit frames.
local BACKGROUND = 0.067

-- The most class-resource segments any class uses, and the Death Knight's runes.
local MAX_SEGMENTS = 10
local RUNES = 6

-- Brightness of a segment still filling.
local PARTIAL = 0.6

-- Space between the resources and the player power bar they sit on, and above the extra mana bar.
local GAP = 2

-- Segments shown before the client reports the resource's maximum.
local DEFAULT_COUNT = 5

---The player's class resource frame: oUF's ClassPower, Runes and Stagger elements, and optionally its
---AdditionalPower bar, each segment a bordered status bar.
---@class AUIClassPowerFrame : Button
---@field key string
---@field settings table? the resolved settings from the last `ApplyAppearance`
---@field ClassPower table oUF's ClassPower segments
---@field Runes table oUF's Runes segments
---@field Stagger StatusBar? only where the client has Blizzard's stagger bar
---@field AdditionalPower StatusBar
---@field CountText FontString the resource count, when shown
---@field Ticker Frame updates the rune countdowns
---@field EnableElement fun(self: AUIClassPowerFrame, name: string) oUF: activate an element
---@field DisableElement fun(self: AUIClassPowerFrame, name: string) oUF: deactivate an element
---@field Enable fun(self: AUIClassPowerFrame) oUF: watch the unit
---@field Disable fun(self: AUIClassPowerFrame) oUF: stop watching the unit and hide the frame
---@field RegisterEvent fun(self: AUIClassPowerFrame, event: string, handler: function, unitless: boolean?) oUF's event registration
local ClassPowerMixin = {}

---@class AUIClassPower
---@field GAP number
local ClassPower = {
	GAP = GAP,
}
AUI.ClassPower = ClassPower

-- Settings ------------------------------------------------------------------------------------------------

---@param config table
---@return table settings
function ClassPower:Resolve(config)
	local base = "frames.classPower."
	local settings = {}

	for path in pairs(Schema.fields) do
		if path:sub(1, #base) == base then
			settings[path:sub(#base + 1)] = Schema:Read(config, path)
		end
	end

	settings.font = Schema:Read(config, "frames.playerPower.text.font")
	settings.outline = Schema:Read(config, "frames.playerPower.text.outline")

	return settings
end

---@param settings table
---@return number height the frame's height, the extra mana bar included when shown
function ClassPower:Height(settings)
	if settings.extraMana then
		return settings.height + GAP + settings.extraManaHeight
	end

	return settings.height
end

---Splits a width into equal segments with gaps between them.
---@param width number
---@param count integer
---@param spacing number
---@return table[] segments `x` from the left and `w`
function ClassPower:Segments(width, count, spacing)
	local segments = {}

	if count < 1 then
		return segments
	end

	local segment = (width - spacing * (count - 1)) / count

	for index = 1, count do
		segments[index] = { x = (index - 1) * (segment + spacing), w = segment }
	end

	return segments
end

---@return boolean target combo points belong to the target, as Blizzard's own combo display reads them on this client
function ClassPower:TargetComboPoints()
	return GetCVar("comboPointLocation") == "1"
end

---@param color table
---@param partial boolean? the segment is still filling
---@return number r
---@return number g
---@return number b
function ClassPower:Shade(color, partial)
	local scale = partial and PARTIAL or 1
	local r, g, b = color.r or color[1], color.g or color[2], color.b or color[3]

	return r * scale, g * scale, b * scale
end

-- Segments ------------------------------------------------------------------------------------------------

---Creates one bordered segment, hidden until an oUF element shows it for a resource the player has.
---@param parent Frame
---@return StatusBar segment
function ClassPower:CreateSegment(parent)
	local segment = CreateFrame("StatusBar", nil, parent)

	segment:Hide()

	AUI.Media:SetBarTexture(segment, AUI.Media.FLAT)
	segment:SetMinMaxValues(0, 1)

	local background = segment:CreateTexture(nil, "BACKGROUND")

	background:SetAllPoints()
	background:SetColorTexture(BACKGROUND, BACKGROUND, BACKGROUND, 1)

	local border = {}

	for index = 1, 4 do
		border[index] = segment:CreateTexture(nil, "OVERLAY", nil, 7)
		border[index]:SetColorTexture(0, 0, 0, 1)
	end

	segment.Border = border
	segment.Text = segment:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	segment.Text:SetPoint("CENTER")

	return segment
end

---Places a segment and gives it the frame's border and text style.
---@param segment StatusBar
---@param anchor Region
---@param x number
---@param y number from the anchor's top
---@param width number
---@param height number
---@param settings table
---@param pixel number
function ClassPower:PlaceSegment(segment, anchor, x, y, width, height, settings, pixel)
	segment:ClearAllPoints()
	segment:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, -y)
	segment:SetSize(width, height)
	AUI.UnitFrame:LayoutBorder(segment.Border, segment, pixel)

	for _, edge in ipairs(segment.Border) do
		edge:SetShown(settings.border)
	end

	segment.Text:SetFont(AUI.Media:Font(settings.font), settings.textSize, AUI.Media:FontFlags(settings.outline))
end

---@param frame AUIClassPowerFrame
---@param element table segments
---@param count integer
function ClassPower:LayoutSegments(frame, element, count)
	local settings = frame.settings

	if not settings then
		return
	end

	local pixel = AUI:Pixel(frame)

	for index, spot in ipairs(self:Segments(settings.width, count, settings.spacing)) do
		self:PlaceSegment(element[index], frame, spot.x, 0, spot.w, settings.height, settings, pixel)
	end

	element.layoutCount = count
end

---@return table? color the player's class color, unless it cannot be read
local function ClassColor()
	local _, class = UnitClass("player")

	class = AUI:Readable(class)

	return class and AUI.oUF.colors.class[class]
end

---Colors segments: the element's color (or the class color), charged points in the charged color, and segments still
---filling darker.
---@param frame AUIClassPowerFrame
---@param element table segments
---@param count integer segments in use
---@param charged table<integer, boolean>? charged segments
function ClassPower:Recolor(frame, element, count, charged)
	local settings = frame.settings
	local base = element.baseColor

	if not settings or not base then
		return
	end

	if settings.classColor then
		base = ClassColor() or base
	end

	for index = 1, count do
		local segment = element[index]
		local value, _, maximum = segment:GetValue(), segment:GetMinMaxValues()
		local partial = false

		if settings.darkenPartial and not issecretvalue(value) and not issecretvalue(maximum) then
			partial = value > 0 and value < maximum
		end

		local color = charged and charged[index] and settings.chargedColor or base

		segment:SetStatusBarColor(self:Shade(color, partial))
	end
end

---oUF's ClassPower update where combo points belong to the target. oUF also runs it once as it turns the element off
---for a class without the resource; that clears the segments.
---@param frame AUIClassPowerFrame
---@param event string
local function TargetComboPoints(frame, event)
	local element = frame.ClassPower
	local current = GetComboPoints("player", "target")
	local maximum = UnitPowerMax("player", Enum.PowerType.ComboPoints)

	if event == "ClassPowerDisable" or issecretvalue(current) or issecretvalue(maximum) then
		for _, segment in ipairs(element) do
			segment:Hide()
		end

		return
	end

	for index, segment in ipairs(element) do
		segment:SetShown(index <= maximum)
		segment:SetValue(index <= current and 1 or 0)
	end

	element:PostUpdate(current, maximum, true, true, "COMBO_POINTS")
end

-- Live frame ----------------------------------------------------------------------------------------------

---The style for the class resource frame.
---@param frame table the oUF frame
---@param unit string
function ClassPower.Style(frame, unit)
	frame = Mixin(frame, ClassPowerMixin) --[[@as AUIClassPowerFrame]]

	frame.key = AUI.UnitFrame.keys[unit] or "classPower"
	frame:EnableMouse(false)

	local segments = {}

	for index = 1, MAX_SEGMENTS do
		segments[index] = ClassPower:CreateSegment(frame)
	end

	function segments.PostUpdateColor(element, color)
		element.baseColor = color
		ClassPower:Recolor(frame, element, element.layoutCount or 0)
	end

	function segments.PostUpdate(element, current, maximum, _, maximumChanged, _, ...)
		if issecretvalue(maximum) then
			return
		end

		if maximumChanged or element.layoutCount ~= maximum then
			ClassPower:LayoutSegments(frame, element, maximum)
		end

		local charged = {}

		for index = 1, select("#", ...) do
			charged[select(index, ...)] = true
		end

		ClassPower:Recolor(frame, element, maximum, charged)

		if frame.settings and frame.settings.text and not issecretvalue(current) then
			frame.CountText:SetFormattedText("%d", current)
		else
			frame.CountText:SetText("")
		end
	end

	if ClassPower:TargetComboPoints() then
		segments.Override = TargetComboPoints
		frame:RegisterEvent("PLAYER_TARGET_CHANGED", function()
			if segments.ForceUpdate then
				segments:ForceUpdate()
			end
		end, true)
	end

	frame.ClassPower = segments

	local runes = {}

	for index = 1, RUNES do
		runes[index] = ClassPower:CreateSegment(frame)
	end

	runes.colorSpec = true

	function runes.PostUpdateColor(element, color)
		element.baseColor = color
	end

	function runes.PostUpdate(element)
		ClassPower:Recolor(frame, element, RUNES)
	end

	frame.Runes = runes

	-- oUF's Stagger element re-registers Blizzard's MonkStaggerBar whenever it disables, which it does for every class
	-- but the Monk, so the element can only exist where that bar does.
	if _G.MonkStaggerBar then
		local stagger = ClassPower:CreateSegment(frame)

		function stagger.PostUpdate(element, current)
			element.Text:SetText(AbbreviateNumbers(current))
		end

		frame.Stagger = stagger
	end

	local extra = ClassPower:CreateSegment(frame)

	extra.colorPower = true
	frame.AdditionalPower = extra

	frame.CountText = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")

	-- Rune countdowns, read from each rune's fill while the client reports it as a plain number.
	frame.Ticker = CreateFrame("Frame", nil, frame)
	frame.Ticker:SetScript("OnUpdate", function()
		ClassPower:UpdateRuneTimers(frame)
	end)

end

---@param frame AUIClassPowerFrame
function ClassPower:UpdateRuneTimers(frame)
	local settings = frame.settings
	local show = settings and settings.runeTimers

	for _, rune in ipairs(frame.Runes) do
		local text = ""

		if show and rune:IsShown() then
			local value, _, maximum = rune:GetValue(), rune:GetMinMaxValues()

			if not issecretvalue(value) and not issecretvalue(maximum) and value < maximum then
				text = ("%d"):format(math.ceil(maximum - value))
			end
		end

		rune.Text:SetText(text)
	end
end


---Size, position, the extra mana bar and whether the frame shows. These touch a secure frame, so they run only out of
---combat.
---@param config table
function ClassPowerMixin:ApplyLayout(config)
	local settings = ClassPower:Resolve(config)

	self:SetSize(settings.width, ClassPower:Height(settings))
	self:ClearAllPoints()

	local power = _G.AeonUIPlayerPower

	if settings.attach == "power" and power then
		self:SetPoint("BOTTOM", power, "TOP", 0, GAP)
	else
		self:SetPoint("CENTER", UIParent, "CENTER", settings.x, settings.y)
	end

	if settings.extraMana then
		self:EnableElement("AdditionalPower")
	else
		self:DisableElement("AdditionalPower")
	end

	if settings.enabled then
		self:Enable()
	else
		self:Disable()
	end
end

---Segment geometry, borders, colors and text. Not protected, so this also runs in combat.
---@param config table
function ClassPowerMixin:ApplyAppearance(config)
	local settings = ClassPower:Resolve(config)
	local pixel = AUI:Pixel(self)

	self.settings = settings

	ClassPower:LayoutSegments(self, self.ClassPower, self.ClassPower.layoutCount or DEFAULT_COUNT)
	ClassPower:LayoutSegments(self, self.Runes, RUNES)
	if self.Stagger then
		ClassPower:PlaceSegment(self.Stagger, self, 0, 0, settings.width, settings.height, settings, pixel)
	end

	ClassPower:PlaceSegment(self.AdditionalPower, self, 0, settings.height + GAP, settings.width,
		settings.extraManaHeight, settings, pixel)
	ClassPower:Recolor(self, self.ClassPower, self.ClassPower.layoutCount or 0)
	ClassPower:Recolor(self, self.Runes, RUNES)
	self.CountText:SetFont(AUI.Media:Font(settings.font), settings.textSize, AUI.Media:FontFlags(settings.outline))
	self.CountText:ClearAllPoints()
	self.CountText:SetPoint("CENTER", self, "TOPLEFT", settings.width / 2, -settings.height / 2)
	self.CountText:SetShown(settings.text)
	self.Ticker:SetShown(settings.runeTimers)

	-- Hide Out of Combat is part of the frame's opacity, which fading owns.
	if AUI.Fading.started then
		AUI.Fading:Update(self)
	end
end
