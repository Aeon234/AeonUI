local AUI = select(2, ...)

local Options = AUI.UnitFrameOptions

-- The most class-resource segments any class uses, and the Death Knight's runes.
local MAX_SEGMENTS = 10
local RUNES = 6

-- Brightness of a segment still filling.
local PARTIAL = 0.6

-- Space above the extra mana bar.
local GAP = 2

-- Segments shown before the client reports the resource's maximum.
local DEFAULT_COUNT = 5

-- Seconds after a loading screen to read the resource again.
local REFRESH_DELAY = 1

-- Levels above a holder for its dividers, and above the power bar for this frame, past that bar's border and text.
local COVER_LEVEL = 2
local OVER_POWER = 10

-- The palette's rune color for each Death Knight specialization, by its index.
local RUNE_SPECS = { "RUNES_BLOOD", "RUNES_FROST", "RUNES_UNHOLY" }
-- The palette's stagger colors, in the order of oUF's stagger colors.
local STAGGER_COLORS = { "STAGGER_LIGHT", "STAGGER_MODERATE", "STAGGER_HEAVY" }

---The player's class resource frame: oUF's ClassPower, Runes and Stagger elements in one bordered holder, divided into
---segments, and its AdditionalPower bar in a holder of its own. Class Resource and Extra Mana share this frame.
---@class AUIClassPowerFrame : Button
---@field key string
---@field spec AUIFrameSpec
---@field settings table? the resolved settings from the last `ApplyAppearance`
---@field drawn boolean? its elements have run once
---@field classActive boolean? oUF's ClassPower element has a resource to show
---@field staggerActive boolean? oUF's Stagger element shows
---@field filling StatusBar? the essence segment recharging
---@field UpdateAllElements fun(self: AUIClassPowerFrame, event: string) oUF: run every element
---@field Holder AUIClassPowerHolder
---@field ExtraHolder AUIClassPowerHolder
---@field ClassPower table oUF's ClassPower segments
---@field Runes table oUF's Runes segments
---@field Stagger AUIClassPowerSegment? only where the client has Blizzard's stagger bar
---@field AdditionalPower AUIClassPowerSegment
---@field CountText FontString the resource count, when shown
---@field Ticker Frame updates the rune countdowns
---@field Filler Frame updates the recharging essence segment
---@field EnableElement fun(self: AUIClassPowerFrame, name: string) oUF: activate an element
---@field DisableElement fun(self: AUIClassPowerFrame, name: string) oUF: deactivate an element
---@field IsElementEnabled fun(self: AUIClassPowerFrame, name: string): boolean oUF: an element runs
---@field Enable fun(self: AUIClassPowerFrame) oUF: watch the unit
---@field Disable fun(self: AUIClassPowerFrame) oUF: stop watching the unit and hide the frame
---@field RegisterEvent fun(self: AUIClassPowerFrame, event: string, handler: function, unitless: boolean?) oUF's event registration
local ClassPowerMixin = {}

---A status bar with a count.
---@class AUIClassPowerSegment : StatusBar
---@field Text FontString

---A background and one border around the segments in it, with dividers between them.
---@class AUIClassPowerHolder : Frame
---@field Background Texture
---@field Border AUIBorder
---@field Cover Frame holds the dividers, above the segments
---@field Dividers Texture[]
---@field count integer? the segments its dividers separate

---@class AUIClassPower
---@field GAP number
---@field OVER_POWER number
local ClassPower = {
	GAP = GAP,
	OVER_POWER = OVER_POWER,
}
AUI.ClassPower = ClassPower

-- Settings ------------------------------------------------------------------------------------------------

---@return table settings
function ClassPower:Resolve()
	local Profile = AUI.Profile
	local base = Options:Path("classPower", "")
	local settings = {}

	for path in pairs(AUI.Schema.fields) do
		if path:sub(1, #base) == base then
			settings[path:sub(#base + 1)] = Profile:Get(path)
		end
	end

	settings.font = Profile:Get(Options:Path("playerPower", "text.font"))
	settings.outline = Profile:Get(Options:Path("playerPower", "text.outline"))
	settings.look = AUI.UnitFrame:BarLook("classPower")

	return settings
end

---@return boolean attached it stands on the player power bar
function ClassPower:IsAttached()
	return AUI.Profile:Get(Options:Path("classPower", "attach")) == "power"
end

---@param settings table
---@return number height the frame's height: the resource, and the extra mana bar under it when that is on
function ClassPower:Height(settings)
	if settings.extraMana then
		return settings.height + GAP + settings.extraManaHeight
	end

	return settings.height
end

---@return number smoothing how the power bars move to a new value
function ClassPower:Smoothing()
	local interpolation = Enum.StatusBarInterpolation
	local on = AUI.Profile:Get(Options.RESOURCES_SMOOTH) == true

	return on and not LibStub("LibAeonSettings-1.0"):ReduceMotion() and interpolation.ExponentialEaseOut
		or interpolation.Immediate
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

---@return table? color the player's class color, unless it cannot be read
local function ClassColor()
	local _, class = UnitClass("player")

	class = AUI:Readable(class)

	return class and AUI.oUF.colors.class[class]
end

---The resource's color in its mode.
---@param settings table
---@param powerType string? the resource's token
---@param fallback table oUF's color, for a resource with no palette color
---@return table color
function ClassPower:BaseColor(settings, powerType, fallback)
	if settings.colorMode == "custom" then
		return settings.color
	end

	if settings.colorMode == "class" then
		return ClassColor() or fallback
	end

	if settings.colorMode == "spec" and powerType == "RUNES" then
		local token = RUNE_SPECS[C_SpecializationInfo.GetSpecialization() or 0]

		if token then
			return settings["palette." .. token]
		end
	end

	return powerType and settings["palette." .. powerType] or fallback
end

---@param settings table
---@param color table the resource's color
---@param charged boolean? the segment is charged
---@param partial boolean? the segment is still filling
---@return number r
---@return number g
---@return number b
function ClassPower:SegmentColor(settings, color, charged, partial)
	if partial and settings.recharge then
		return self:Shade(settings.rechargeColor)
	end

	return self:Shade(charged and settings.chargedColor or color, partial and settings.darkenPartial)
end

-- Holders and segments ------------------------------------------------------------------------------------

---@param parent Frame
---@param level number? its frame level
---@return AUIClassPowerHolder holder
function ClassPower:CreateHolder(parent, level)
	local holder = CreateFrame("Frame", nil, parent)

	if level then
		holder:SetFrameLevel(level)
	end

	holder.Background = holder:CreateTexture(nil, "BACKGROUND")
	holder.Background:SetAllPoints()
	holder.Background:SetColorTexture(1, 1, 1, 1)
	holder.Cover = CreateFrame("Frame", nil, holder)
	holder.Cover:SetAllPoints()
	holder.Cover:SetFrameLevel(holder:GetFrameLevel() + COVER_LEVEL)
	holder.Border = AUI.Border:Create(holder, true)
	holder.Border:SetFrameLevel(holder:GetFrameLevel() + AUI.UnitFrame.BORDER_LEVEL)
	holder.Dividers = {}

	return holder --[[@as AUIClassPowerHolder]]
end

---Creates one segment, hidden until an oUF element shows it for a resource the player has.
---@param parent Frame
---@return AUIClassPowerSegment segment
function ClassPower:CreateSegment(parent)
	local segment = CreateFrame("StatusBar", nil, parent)

	segment:Hide()
	segment:SetMinMaxValues(0, 1)
	segment.Text = segment:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	segment.Text:SetPoint("CENTER")

	return segment --[[@as AUIClassPowerSegment]]
end

---Sizes a holder and gives it and its segments the bar look.
---@param holder AUIClassPowerHolder
---@param look AUIBarLook
---@param width number
---@param height number
---@param segments table its status bars
function ClassPower:StyleHolder(holder, look, width, height, segments)
	holder:SetSize(width, height)
	AUI.UnitFrame:StyleBar(segments[1], holder.Background, holder.Border, look)
	holder.Border:Layout()

	for index = 2, #segments do
		AUI.Media:SetBarTexture(segments[index], look.texture)
	end
end

---@param settings table
---@return number width the space between segments: the border style's own divider, or the Spacing
function ClassPower:DividerWidth(settings)
	local look = settings.look

	return AUI.Border:CellDividerWidth(look.borderStyle, look.borderThickness) or settings.spacing
end

---Lays a holder's dividers between its segments: the border style's own, or plain lines in the Divider Color.
---@param holder AUIClassPowerHolder
---@param count integer
---@param settings table
function ClassPower:PlaceDividers(holder, count, settings)
	local look = settings.look
	local width = self:DividerWidth(settings)
	local spots = self:Segments(holder:GetWidth(), count, width)
	local color = settings.dividerColor

	holder.count = count

	for index = 1, count - 1 do
		local divider = holder.Dividers[index]

		if not divider then
			divider = holder.Cover:CreateTexture(nil, "ARTWORK")
			divider:SetSnapToPixelGrid(false)
			divider:SetTexelSnappingBias(0)
			holder.Dividers[index] = divider
		end

		if not AUI.Border:StyleCellDivider(divider, look.borderStyle, look.borderColor) then
			divider:SetDesaturated(false)
			divider:SetVertexColor(1, 1, 1, 1)
			divider:SetTexCoord(0, 1, 0, 1)
			divider:SetColorTexture(color.r, color.g, color.b, color.a or 1)
		end

		divider:ClearAllPoints()
		divider:SetPoint("TOPLEFT", holder, "TOPLEFT", spots[index].x + spots[index].w, 0)
		divider:SetSize(math.max(width, 0.001), holder:GetHeight())
		divider:SetShown(width > 0)
	end

	for index = math.max(count, 1), #holder.Dividers do
		holder.Dividers[index]:Hide()
	end
end

---Places a segment in its holder and gives it the text style.
---@param segment AUIClassPowerSegment
---@param holder Region
---@param x number
---@param width number
---@param height number
---@param settings table
function ClassPower:PlaceSegment(segment, holder, x, width, height, settings)
	segment:ClearAllPoints()
	segment:SetPoint("TOPLEFT", holder, "TOPLEFT", x, 0)
	segment:SetSize(width, height)
	segment.Text:SetFont(AUI.Media:Font(settings.font), settings.textSize, AUI.Media:FontFlags(settings.outline))
end

---Places segments and the dividers between them across a holder.
---@param holder AUIClassPowerHolder
---@param segments table
---@param count integer
---@param settings table
function ClassPower:PlaceSegments(holder, segments, count, settings)
	for index, spot in ipairs(self:Segments(settings.width, count, self:DividerWidth(settings))) do
		self:PlaceSegment(segments[index], holder, spot.x, spot.w, settings.height, settings)
	end

	self:PlaceDividers(holder, count, settings)
end

---@param frame AUIClassPowerFrame
---@param element table segments
---@param count integer
function ClassPower:LayoutSegments(frame, element, count)
	local settings = frame.settings

	if not settings then
		return
	end

	self:PlaceSegments(frame.Holder, element, count, settings)
	element.layoutCount = count
end

---Colors segments in the resource's color, charged points in the charged color, and segments still filling in the
---recharge color or darker.
---@param frame AUIClassPowerFrame
---@param element table segments
---@param count integer segments in use
---@param charged table<integer, boolean>? charged segments
function ClassPower:Recolor(frame, element, count, charged)
	local settings = frame.settings
	local fallback = element.baseColor

	if not settings or not fallback then
		return
	end

	local base = self:BaseColor(settings, element.powerType, fallback)

	for index = 1, count do
		local segment = element[index]
		local value, _, maximum = segment:GetValue(), segment:GetMinMaxValues()
		local partial = not issecretvalue(value) and not issecretvalue(maximum) and value < maximum

		segment:SetStatusBarColor(self:SegmentColor(settings, base, charged and charged[index], partial))
	end
end

---Shows the holder while an element has something in it, so a class or specialization without a resource draws no
---empty border.
---@param frame AUIClassPowerFrame
function ClassPower:UpdateHolder(frame)
	frame.Holder:SetShown((frame.classActive or frame.staggerActive or frame:IsElementEnabled("Runes")) == true)
end

---Replaces oUF's stagger colors with the palette's.
---@param settings table
function ClassPower:ApplyStaggerColors(settings)
	local colors = AUI.oUF.colors.power.STAGGER

	if not colors then
		return
	end

	for index, token in ipairs(STAGGER_COLORS) do
		local entry, color = colors[index], settings["palette." .. token]

		if entry and entry.SetRGB then
			entry:SetRGB(color.r, color.g, color.b)
		end
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

---Reads the resource again. Early in a login the client can report no specialization, and no start for a rune on
---cooldown; oUF then draws nothing, and the events it waits on come only once the resource is spent.
---@param frame AUIClassPowerFrame
local function Refresh(frame)
	for _, element in ipairs({ "ClassPower", "Runes" }) do
		if frame:IsElementEnabled(element) then
			frame[element]:ForceUpdate()
		end
	end
end

---Fills the essence segment recharging, which oUF leaves empty until it is whole.
---@param frame AUIClassPowerFrame
local function FillEssence(frame)
	local partial = UnitPartialPower("player", Enum.PowerType.Essence)
	local display = UnitPowerDisplayMod(Enum.PowerType.Essence)

	if frame.filling and not issecretvalue(partial) and not issecretvalue(display) and display > 0 then
		frame.filling:SetValue(partial / display)
	end
end

-- Live frame ----------------------------------------------------------------------------------------------

---The style for the class resource frame.
---@param frame table the oUF frame
function ClassPower.Style(frame)
	frame = Mixin(frame, ClassPowerMixin) --[[@as AUIClassPowerFrame]]

	frame.key = "classPower"
	frame.spec = Options:Spec("classPower") --[[@as AUIFrameSpec]]
	frame:EnableMouse(false)
	frame:SetFrameLevel(AUI.Frames.objects.playerPower:GetFrameLevel() + OVER_POWER)
	frame.Holder = ClassPower:CreateHolder(frame)
	frame.Holder:SetPoint("TOPLEFT")

	local segments = {}

	for index = 1, MAX_SEGMENTS do
		segments[index] = ClassPower:CreateSegment(frame.Holder)
	end

	function segments.PostUpdateColor(element, color)
		element.baseColor = color
		ClassPower:Recolor(frame, element, element.layoutCount or 0)
	end

	function segments.PostVisibility(_, on)
		frame.classActive = on
		ClassPower:UpdateHolder(frame)
	end

	function segments.PostUpdate(element, current, maximum, _, maximumChanged, powerType, ...)
		if not maximum or issecretvalue(maximum) then
			return
		end

		element.powerType = powerType

		if maximumChanged or element.layoutCount ~= maximum then
			ClassPower:LayoutSegments(frame, element, maximum)
		end

		local charged = {}

		for index = 1, select("#", ...) do
			charged[select(index, ...)] = true
		end

		local secret = issecretvalue(current)

		frame.filling = powerType == "ESSENCE" and not secret and current < maximum and element[current + 1] or nil
		frame.Filler:SetShown(frame.filling ~= nil)
		ClassPower:Recolor(frame, element, maximum, charged)

		if frame.settings and frame.settings.text and not secret then
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
		runes[index] = ClassPower:CreateSegment(frame.Holder)
	end

	runes.powerType = "RUNES"
	runes.sortOrder = "asc"

	function runes.PostUpdateColor(element, color)
		element.baseColor = color
		ClassPower:Recolor(frame, element, RUNES)
	end

	function runes.PostUpdate(element)
		if frame.Holder.count ~= RUNES then
			ClassPower:LayoutSegments(frame, element, RUNES)
		end

		ClassPower:Recolor(frame, element, RUNES)
	end

	frame.Runes = runes

	-- oUF's Stagger element re-registers Blizzard's MonkStaggerBar whenever it disables, which it does for every class
	-- but the Monk, so the element can only exist where that bar does.
	if _G.MonkStaggerBar then
		local stagger = ClassPower:CreateSegment(frame.Holder)

		function stagger.PostUpdate(element, current)
			element.Text:SetText(AbbreviateNumbers(current))
		end

		function stagger.PostVisibility(_, on)
			frame.staggerActive = on

			if on and frame.settings then
				ClassPower:PlaceDividers(frame.Holder, 1, frame.settings)
			end

			ClassPower:UpdateHolder(frame)
		end

		frame.Stagger = stagger
	end

	frame.ExtraHolder = ClassPower:CreateHolder(frame)
	frame.ExtraHolder:Hide()

	local extra = ClassPower:CreateSegment(frame.ExtraHolder)

	extra.colorPower = true

	function extra.PostVisibility(_, on)
		frame.ExtraHolder:SetShown(on)
	end

	frame.AdditionalPower = extra

	frame.CountText = frame.Holder.Cover:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	frame.CountText:SetPoint("CENTER", frame.Holder)
	frame:RegisterEvent("SPELLS_CHANGED", Refresh, true)
	frame:RegisterEvent("PLAYER_ENTERING_WORLD", function()
		C_Timer.After(REFRESH_DELAY, function()
			Refresh(frame)
		end)
	end, true)

	-- Rune countdowns, read from each rune's fill while the client reports it as a plain number.
	frame.Ticker = CreateFrame("Frame", nil, frame)
	frame.Ticker:SetScript("OnUpdate", function()
		ClassPower:UpdateRuneTimers(frame)
	end)
	frame.Ticker:Hide()

	frame.Filler = CreateFrame("Frame", nil, frame)
	frame.Filler:SetScript("OnUpdate", function()
		FillEssence(frame)
	end)
	frame.Filler:Hide()
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


---Runs or stops the class resource's elements, each hidden when stopped.
---@param on boolean
function ClassPowerMixin:SetResource(on)
	AUI.Indicators:SetElement(self, "ClassPower", on, self.ClassPower)
	AUI.Indicators:SetElement(self, "Runes", on, self.Runes)

	if self.Stagger then
		AUI.Indicators:SetElement(self, "Stagger", on, self.Stagger)
	end

	if not on then
		for _, element in ipairs({ self.ClassPower, self.Runes }) do
			for _, segment in ipairs(element) do
				segment:Hide()
			end
		end

		self.filling = nil
		self.Filler:Hide()
	end
end

---Size, position, which bars run and whether the frame shows. These touch a secure frame, so they run only out of
---combat. Attached, it stands on the player power bar.
function ClassPowerMixin:ApplyLayout()
	local settings = ClassPower:Resolve()
	local on = Options:ResourcesOn()
	local extra = on and settings.extraMana

	self:SetSize(settings.width, ClassPower:Height(settings))
	self:ClearAllPoints()

	if ClassPower:IsAttached() then
		self:SetPoint("BOTTOM", AUI.Frames.objects.playerPower, "TOP", settings.attachX, settings.attachY)
	else
		local position = settings.position or self.spec.position

		self:SetPoint(position.point, UIParent, position.point, position.x, position.y)
	end

	self:SetResource(on)
	ClassPower:UpdateHolder(self)
	AUI.Indicators:SetElement(self, "AdditionalPower", extra, self.AdditionalPower)

	if not extra then
		self.ExtraHolder:Hide()
	end

	if on then
		self:Enable()
	else
		self:Disable()
	end
end

---Holder looks, segment geometry, colors and text. Not protected, so this also runs in combat.
function ClassPowerMixin:ApplyAppearance()
	local settings = ClassPower:Resolve()
	local look = settings.look
	local holder, extra = self.Holder, self.ExtraHolder
	local stagger = self.Stagger
	local bars = {}

	self.settings = settings

	for _, element in ipairs({ self.ClassPower, self.Runes }) do
		for _, segment in ipairs(element) do
			bars[#bars + 1] = segment
		end
	end

	bars[#bars + 1] = stagger

	ClassPower:StyleHolder(holder, look, settings.width, settings.height, bars)
	ClassPower:LayoutSegments(self, self.ClassPower, self.ClassPower.layoutCount or DEFAULT_COUNT)

	if self:IsElementEnabled("Runes") then
		ClassPower:LayoutSegments(self, self.Runes, RUNES)
	end

	if stagger then
		ClassPower:PlaceSegment(stagger, holder, 0, settings.width, settings.height, settings)

		if self.staggerActive then
			ClassPower:PlaceDividers(holder, 1, settings)
		end
	end

	extra:ClearAllPoints()
	extra:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(settings.height + GAP))
	ClassPower:StyleHolder(extra, look, settings.width, settings.extraManaHeight, { self.AdditionalPower })
	ClassPower:PlaceSegment(self.AdditionalPower, extra, 0, settings.width, settings.extraManaHeight, settings)
	self.AdditionalPower.smoothing = ClassPower:Smoothing()

	if stagger then
		stagger.smoothing = self.AdditionalPower.smoothing
	end

	ClassPower:ApplyStaggerColors(settings)
	ClassPower:Recolor(self, self.ClassPower, self.ClassPower.layoutCount or 0)
	ClassPower:Recolor(self, self.Runes, RUNES)
	self.CountText:SetFont(AUI.Media:Font(settings.font), settings.textSize, AUI.Media:FontFlags(settings.outline))
	self.CountText:SetShown(settings.text)
	self.Ticker:SetShown(settings.runeTimers)

	-- A frame spawned after the login shows no change and sees no loading screen, so nothing else draws it first. This
	-- runs after the settings are in place, so the segments it shows are laid out.
	if not self.drawn and Options:ResourcesOn() then
		self.drawn = true
		self:UpdateAllElements("ApplyAppearance")
	end

	if stagger and self.staggerActive then
		(stagger --[[@as table]]):ForceUpdate()
	end
end
