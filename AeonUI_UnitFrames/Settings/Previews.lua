local AUI = select(2, ...)

local L = AUI.L
local Options = AUI.UnitFrameOptions

local FULL, DAMAGED, HOVER, ABSORBS, OVERFLOW = L["Full"], L["Damaged"], L["Hover"], L["Absorbs"], L["Overflow"]

-- The sample's maximum health, and each state's share of it.
local MAX_HEALTH = 412000
local SHARES = { [FULL] = 1, [DAMAGED] = 0.55, [DEAD] = 0, [HOVER] = 1, [ABSORBS] = 0.6, [OVERFLOW] = 0.3 }
-- The states that show health overlays; amounts are shares of maximum health.
local OVERLAY_SAMPLES = {
	[ABSORBS] = { health = 0.6, absorb = 0.25, healAbsorb = 0, healing = 0.15 },
	[OVERFLOW] = { health = 0.3, absorb = 0.9, healAbsorb = 0.5, healing = 0 },
}
local NO_OVERLAYS = { health = 0, absorb = 0, healAbsorb = 0, healing = 0 }
local AURA_ICONS = {
	"Interface\\Icons\\Spell_Nature_Rejuvenation",
	"Interface\\Icons\\Spell_Holy_PowerWordShield",
	"Interface\\Icons\\Spell_Shadow_ShadowWordPain",
	"Interface\\Icons\\Spell_Fire_Immolation",
	"Interface\\Icons\\Spell_Frost_FrostNova",
	"Interface\\Icons\\Ability_Rogue_Rupture",
}
-- The sample debuffs' border colors.
local DISPEL_COLORS = {
	{ r = 0.2, g = 0.6, b = 1 },
	{ r = 0.6, g = 0, b = 1 },
	{ r = 0, g = 0.6, b = 0 },
	{ r = 0.6, g = 0.4, b = 0 },
}
local PARTIAL, EMPTY, CHARGED = L["Partial"], L["Empty"], L["Charged"]
-- The power bar's share of its maximum in each resource state.
local POWER_SHARES = { [FULL] = 1, [PARTIAL] = 0.55, [EMPTY] = 0, [CHARGED] = 1 }
local RESOURCE_MAX_POWER = 12400
-- The sample's segments, and the class resource each class shows where the client has its own resources; a class
-- missing here shows none.
local SAMPLE_SEGMENTS = 5
local SAMPLE_RUNES = 6
local CLASS_RESOURCES = {
	DEATHKNIGHT = "RUNES",
	DRUID = "COMBO_POINTS",
	EVOKER = "ESSENCE",
	MAGE = "ARCANE_CHARGES",
	MONK = "CHI",
	PALADIN = "HOLY_POWER",
	ROGUE = "COMBO_POINTS",
	SHAMAN = "MAELSTROM",
	WARLOCK = "SOUL_SHARDS",
}
-- The classes with a resource where the client has only combo points.
local COMBO_CLASSES = {
	DRUID = "COMBO_POINTS",
	ROGUE = "COMBO_POINTS",
}
-- Space between the sample's bars.
local RESOURCE_GAP = 2
-- What each sample indicator shows.
local INDICATOR_ART = {
	raid = { texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcons", coords = { 0.75, 1, 0.25, 0.5 } },
	combat = { atlas = "UI-HUD-UnitFrame-Player-CombatIcon" },
	leader = { atlas = "UI-HUD-UnitFrame-Player-Group-LeaderIcon" },
	pvp = { atlas = "UI-HUD-UnitFrame-Player-PVP-AllianceIcon" },
	classification = { texture = "Interface\\AddOns\\AeonUI\\Media\\Textures\\Classification\\Elite.png", coords = { 0, 1, 0, 1 } },
}
-- What the sample cast bar shows in each of a frame's states; its name says so, so one pill shows both.
local CASTING = L["Casting"]
local CAST_SAMPLES = {
	[OVERFLOW] = { state = "CHANNELING", label = L["Channeling"] },
	[HOVER] = { state = "NOT_INTERRUPTIBLE", label = L["Not Interruptible"] },
	[DEAD] = { state = "INTERRUPTED", label = INTERRUPTED },
}
-- The setting a click on the sample power bar lands on.
local POWER_SWITCH = "powerEnabled"
-- The sample power bar's share of its maximum.
local POWER_SAMPLE = 0.64
-- Where a sample icon's corner sits, as a rectangle against its own point (y up).
local CORNER_RECTS = {
	BOTTOMLEFT = { 0, 1, 0, 1 },
	TOPLEFT = { 0, 1, -1, 0 },
	TOPRIGHT = { -1, 0, -1, 0 },
	BOTTOMRIGHT = { -1, 0, 0, 1 },
}
-- Each frame point against the frame's top left (y up), as shares of its width and height.
local FRAME_POINTS = {
	TOPLEFT = { 0, 0 },
	TOPRIGHT = { 1, 0 },
	BOTTOMLEFT = { 0, -1 },
	BOTTOMRIGHT = { 1, -1 },
}
-- The reaction level a sample without a class takes.
local FRIENDLY = 5

---A still sample of a frame, styled as the live frame is, with its bar and text slots as clickable parts.
---@class AUIFramePreview
---@field spec AUIFrameSpec
---@field holder Frame
---@field bar StatusBar
---@field background Texture
---@field border AUIBorder
---@field TextSlots FontString[]
---@field overlays AUIOverlayWidgets?
---@field auraIcons table<string, table[]> the sample icons made so far, by kind
---@field portrait AUIPortraitWidgets?
---@field indicators table<string, Region> the sample indicators made so far, by name
---@field indicatorLayer Frame?
local FramePreview = {}
FramePreview.__index = FramePreview
FramePreview.STATES = { FULL, DAMAGED, DEAD, HOVER }
FramePreview.OVERLAY_STATES = { FULL, DAMAGED, DEAD, HOVER, ABSORBS, OVERFLOW }
FramePreview.CAST_STATES = { ABSORBS, OVERFLOW, HOVER, DEAD }
AUI.FramePreview = FramePreview

---@param spec AUIFrameSpec
---@return AUIFramePreview preview
function FramePreview:New(spec)
	return setmetatable({ spec = spec, auraIcons = { buffs = {}, debuffs = {} }, indicators = {} }, self)
end

---@param canvas Frame
function FramePreview:Create(canvas)
	local holder = CreateFrame("Frame", nil, canvas)

	holder:SetPoint("CENTER")
	self.holder = holder
	self.bar, self.background, self.border = AUI.UnitFrame:CreateBar(holder)
	AUI.Text:Create(self, self.bar, self.spec.slots)

	if self.spec.power then
		self.power, self.powerBackground = AUI.UnitFrame:CreatePowerBar(holder)
		self.power:SetMinMaxValues(0, 1)
	end

	if AUI.UnitCastBar:Has(self.spec) then
		self.cast = AUI.CastBar:Build(holder, nil, AUI.UnitCastBar:Owner(self.spec))
	end
	self.bar:SetMinMaxValues(0, 1)

	if self.spec.overlays then
		self.overlays = AUI.Overlays:Create(self.bar)
	end

	if self.spec.portrait then
		self.portrait = AUI.Portrait:Create(holder, self.bar)
	end

	if self.spec.indicators then
		self.indicatorLayer = CreateFrame("Frame", nil, holder)
		self.indicatorLayer:SetAllPoints()
		self.indicatorLayer:SetFrameLevel(self.bar:GetFrameLevel() + AUI.UnitFrame.TEXT_LEVEL + 1)
	end
end

---@return table? color the player's class color, unless it cannot be read
local function SampleClassColor()
	local _, class = UnitClass("player")

	class = AUI:Readable(class)

	return class and AUI.oUF.colors.class[class] or nil
end

---@param share number the sample's share of its maximum health
---@param dead boolean
---@param overlays table the state's overlay amounts
---@return AUITextSample sample
local function Sample(share, dead, overlays)
	local name = AUI:Readable(UnitName("player"), "")
	local level = AUI:Readable(UnitLevel("player"), 1)
	local _, secretClass = UnitClass("player")
	local class = AUI:Readable(secretClass)
	local health = MAX_HEALTH * share

	return {
		status = dead and DEAD or nil,
		health = health,
		percent = share * 100,
		missing = MAX_HEALTH - health,
		absorb = MAX_HEALTH * overlays.absorb,
		healAbsorb = MAX_HEALTH * overlays.healAbsorb,
		power = 8240,
		powerPercent = 64,
		name = name,
		level = level,
		classColor = class and RAID_CLASS_COLORS[class],
	}
end

---Draws the indicators that are on, where the live frame shows them.
---@param preview table the library's preview
function FramePreview:DrawIndicators(preview)
	local key = self.spec.key
	local layer = self.indicatorLayer --[[@as Frame]]

	for _, indicator in ipairs(self.spec.indicators or {}) do
		local name = indicator.name
		local region = self.indicators[name]
		local settings = AUI.Indicators:Resolve(key, name)
		local on, size = settings.enabled, settings.size

		if not region then
			local art = INDICATOR_ART[name]

			region = layer:CreateTexture(nil, "OVERLAY")

			if art and art.atlas then
				region:SetAtlas(art.atlas)
			elseif art then
				region:SetTexture(art.texture)
				region:SetTexCoord(art.coords[1], art.coords[2], art.coords[3], art.coords[4])
			end

			self.indicators[name] = region
		end

		region:SetShown(on)
		AUI.Indicators:Place(region, self.bar, settings)

		region:SetSize(size, size)

		if name == "resting" then
			local texture = region --[[@as Texture]]

			AUI.Indicators:StyleResting(texture, AUI.Profile:Get(Options:Path(key, "indicators.resting.icon")))
			AUI.Indicators:PlayResting(texture, on)
		end

		if on then
			preview:Part(region, name .. "Indicator")
		end
	end
end

---How far the frame's aura displays reach past its edges at their limits.
---@param width number
---@param height number
---@return number above
---@return number below
---@return number left
---@return number right
function FramePreview:AuraSpace(width, height)
	local above, below, left, right = 0, 0, 0, 0
	local key = self.spec.key
	local clearAbove, clearBelow = AUI.Auras:Clearance(key)

	for _, kind in ipairs({ "buffs", "debuffs" }) do
		local settings = AUI.Auras:Resolve(key, kind)

		if settings.enabled then
			local placement = AUI.Auras:Placement(settings, width, clearAbove, clearBelow)
			local frame = FRAME_POINTS[placement.relative] or FRAME_POINTS.TOPLEFT
			local corner = CORNER_RECTS[placement.point] or CORNER_RECTS.TOPLEFT
			local size = settings.size

			for _, offset in ipairs(AUI.Auras:IconOffsets(settings, placement, settings.limit)) do
				local x = frame[1] * width + placement.x + offset.x
				local y = frame[2] * height + placement.y + offset.y

				left = math.max(left, -(x + corner[1] * size))
				right = math.max(right, x + corner[2] * size - width)
				above = math.max(above, y + corner[4] * size)
				below = math.max(below, -height - (y + corner[3] * size))
			end
		end
	end

	return above, below, left, right
end

---Draws the aura displays at their limits, with the rules the client's containers follow.
---@param width number
---@param preview table the library's preview
function FramePreview:DrawAuras(width, preview)
	local key = self.spec.key
	local clearAbove, clearBelow = AUI.Auras:Clearance(key)

	for kind, icons in pairs(self.auraIcons) do
		local settings = AUI.Auras:Resolve(key, kind)
		local count = 0

		if settings.enabled then
			local placement = AUI.Auras:Placement(settings, width, clearAbove, clearBelow)
			local font = AUI.Media:Font(settings.font)
			local flags = AUI.Media:FontFlags(settings.outline)

			count = settings.limit

			for index, offset in ipairs(AUI.Auras:IconOffsets(settings, placement, count)) do
				local icon = icons[index]

				if not icon then
					local frame = CreateFrame("Frame", nil, self.holder)

					icon = {
						frame = frame,
						texture = frame:CreateTexture(nil, "ARTWORK"),
						border = frame:CreateTexture(nil, "BACKGROUND"),
						edge = frame:CreateTexture(nil, "BACKGROUND", nil, 1),
						count = frame:CreateFontString(nil, "OVERLAY"),
						time = frame:CreateFontString(nil, "OVERLAY"),
					}
					icon.edge:SetAllPoints()
					icon.edge:SetColorTexture(0, 0, 0, 1)
					icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
					-- The border is a colored backing one unit wider than the icon on each side.
					icon.border:SetPoint("TOPLEFT", -1, 1)
					icon.border:SetPoint("BOTTOMRIGHT", 1, -1)
					icons[index] = icon
				end

				local frame = icon.frame
				local dispel = DISPEL_COLORS[(index - 1) % #DISPEL_COLORS + 1]

				local pixel = AUI:Pixel(frame)

				frame:SetSize(settings.size, settings.size)
				icon.texture:ClearAllPoints()
				icon.texture:SetPoint("TOPLEFT", frame, "TOPLEFT", pixel, -pixel)
				icon.texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pixel, pixel)
				frame:ClearAllPoints()
				frame:SetPoint(placement.point, self.holder, placement.relative, placement.x + offset.x,
					placement.y + offset.y)
				icon.texture:SetTexture(AURA_ICONS[(index - 1) % #AURA_ICONS + 1])
				icon.border:SetColorTexture(dispel.r, dispel.g, dispel.b, 1)
				icon.border:SetShown(kind == "debuffs" and settings.border)
				icon.count:SetFont(font, settings.countSize, flags)
				icon.count:ClearAllPoints()
				icon.count:SetPoint(settings.countCorner, frame, settings.countCorner, settings.countX, settings.countY)
				icon.count:SetText(index % 3 == 0 and "2" or "")
				icon.time:SetFont(font, settings.durationSize, flags)
				icon.time:ClearAllPoints()
				icon.time:SetPoint("CENTER", frame, "CENTER", settings.durationX, settings.durationY)
				icon.time:SetText(settings.duration and tostring(4 * index) or "")
				frame:Show()

				if index == 1 then
					preview:Part(frame, kind == "buffs" and "buffEnabled" or "debuffEnabled")
				end
			end
		end

		for index = count + 1, #icons do
			icons[index].frame:Hide()
		end
	end
end

---@param state string? a state's label
---@param preview table the library's preview
---@return number width
---@return number height
function FramePreview:Refresh(state, preview)
	local Profile = AUI.Profile
	local UnitFrame = AUI.UnitFrame
	local key = self.spec.key
	local width = Profile:Get(Options:Path(key, "width"))
	local height = UnitFrame:FrameHeight(key)
	local reverse = Profile:Get(Options:Path(key, "reverse")) == true
	local label = state or (self.cast and ABSORBS) or FULL
	local share = SHARES[label]
	local amounts = OVERLAY_SAMPLES[label] or NO_OVERLAYS
	local sample = Sample(share, label == DEAD, amounts)
	local bar = self.bar
	local HealthColor = AUI.HealthColor
	local settings = HealthColor:Resolve(key)
	local fill, backdrop = HealthColor:Sample(settings, {
		connected = true,
		tapDenied = false,
		classColor = sample.classColor,
		reaction = FRIENDLY,
	}, share, label == DEAD)

	self.holder:SetSize(width, height)
	UnitFrame:StyleBar(bar, self.background, self.border, UnitFrame:BarLook(key))
	UnitFrame:ShowHover(self.border, key, label == HOVER)

	if self.portrait then
		AUI.Portrait:DrawSample(self.portrait, key, self.holder)

		if self.portrait.border then
			UnitFrame:ShowHover(self.portrait.border, key, label == HOVER)
		end

		if self.portrait.holder:IsShown() then
			preview:Part(self.portrait.holder, "portraitEnabled")
		end
	end

	local inLeft, inRight = AUI.Portrait:Inset(key)

	local _, powerHeight, separator = UnitFrame:Heights(key)

	UnitFrame:PlaceBar(bar, self.holder, inLeft, inRight, powerHeight + separator)
	bar:SetReverseFill(reverse)
	bar:SetValue(share)
	UnitFrame:AnchorBackground(bar, self.background, reverse)
	HealthColor:Paint(bar, self.background, settings, fill, backdrop)

	if self.power then
		local shown = UnitFrame:PlacePowerBar(self.power, self.powerBackground, self.holder, key, inLeft, inRight, reverse)

		self.power:SetShown(shown)

		if shown then
			local PowerColor = AUI.PowerColor
			local colors = PowerColor:Resolve(key)
			local powerFill = PowerColor:Fill(colors, AUI.oUF.colors.power.MANA, sample.classColor)

			PowerColor:ApplyPalette()
			self.power:SetValue(POWER_SAMPLE)
			HealthColor:Paint(self.power, self.powerBackground, colors, powerFill, PowerColor:Background(colors, powerFill))
			preview:Part(self.power, POWER_SWITCH)
		end
	end

	if self.overlays then
		local overlays = AUI.Overlays:Resolve(key)

		AUI.Overlays:Apply(self.overlays, overlays, reverse, nil)
		AUI.Overlays:ShowSample(self.overlays, amounts, overlays.healPrediction.overheal)
	end

	preview:Part(bar, "width")

	local slots, widths, contexts = AUI.Text:Layout(key, self.spec.slots)

	for index, slot in ipairs(slots) do
		local text = self.TextSlots[index]
		local shown = AUI.Tags:Sample(slot, contexts[index], sample)

		if shown then
			AUI.Text:Place(text, bar, slot, widths[index])
			text:SetText(shown)
			text:Show()
			preview:Part(text, "slot" .. index .. "Content", { text = true })
		else
			text:Hide()
		end
	end

	self:DrawIndicators(preview)

	local above, below, left, right = 0, 0, 0, 0

	if self.spec.auras then
		self:DrawAuras(width, preview)
		above, below, left, right = self:AuraSpace(width, height)
	end

	local reachAbove, reachBelow, reachLeft, reachRight = AUI.Portrait:Reach(key)

	if self.cast then
		reachBelow = math.max(reachBelow, self:DrawCast(label, preview))
	end

	above, below = math.max(above, reachAbove), math.max(below, reachBelow)
	left, right = math.max(left, reachLeft), math.max(right, reachRight)
	self.holder:ClearAllPoints()
	self.holder:SetPoint("CENTER", (left - right) / 2, (below - above) / 2)

	return width + left + right, height + above + below
end

---Draws the sample cast bar under the frame, as the state shows it, while it is on.
---@param label string the preview's state
---@param preview table the library's preview
---@return number reach how far below the frame it reaches
function FramePreview:DrawCast(label, preview)
	local Profile, CastBar = AUI.Profile, AUI.CastBar
	local view = self.cast
	local base = view.base
	local STATES = AUI.CastBarOptions.STATES
	local sample = CAST_SAMPLES[label]
	local on = Profile:Get(base .. "enabled") == true

	view:SetShown(on)

	if not on then
		return 0
	end

	CastBar:Style(view)
	view:ClearAllPoints()
	view:SetPoint("TOP", self.holder, "BOTTOM", Profile:Get(base .. "x"), Profile:Get(base .. "y"))
	CastBar:DrawSample(view, sample and STATES[sample.state] or STATES.CASTING, sample and sample.label or CASTING)
	preview:Part(view.bar, "castEnabled")

	return AUI.UnitCastBar:Extent(self.spec.key)
end

---A still sample of the player's resources, stacked as they stand on screen.
---@class AUIResourcePreview
---@field holder Frame
---@field powerHolder Frame
---@field bar StatusBar
---@field background Texture
---@field border AUIBorder
---@field TextSlots FontString[]
---@field resource AUIClassPowerHolder
---@field segments AUIClassPowerSegment[]
---@field extraHolder AUIClassPowerHolder
---@field extra AUIClassPowerSegment
local ResourcePreview = {}
ResourcePreview.__index = ResourcePreview
ResourcePreview.STATES = { FULL, PARTIAL, EMPTY, CHARGED }
AUI.ResourcePreview = ResourcePreview

---@return AUIResourcePreview preview
function ResourcePreview:New()
	return setmetatable({ segments = {} }, self)
end

---@param canvas Frame
function ResourcePreview:Create(canvas)
	local holder = CreateFrame("Frame", nil, canvas)

	holder:SetPoint("CENTER")
	self.holder = holder
	self.powerHolder = CreateFrame("Frame", nil, holder)
	self.bar, self.background, self.border = AUI.UnitFrame:CreateBar(self.powerHolder)
	AUI.Text:Create(self, self.bar, (Options:Spec("playerPower") --[[@as AUIFrameSpec]]).slots)
	self.bar:SetMinMaxValues(0, 1)

	local ClassPower = AUI.ClassPower
	local level = self.powerHolder:GetFrameLevel() + ClassPower.OVER_POWER

	self.resource = ClassPower:CreateHolder(holder, level)

	for index = 1, SAMPLE_RUNES do
		self.segments[index] = ClassPower:CreateSegment(self.resource)
	end

	self.extraHolder = ClassPower:CreateHolder(holder, level)
	self.extra = ClassPower:CreateSegment(self.extraHolder)
	self.extra:Show()
end

---@return string? token the player's class resource on this client, or nil for a class without one
local function SampleResource()
	local _, class = UnitClass("player")

	class = AUI:Readable(class)

	return class and (AUI.can.classResources and CLASS_RESOURCES or COMBO_CLASSES)[class] or nil
end

---Draws the class resource in a state.
---@param settings table
---@param token string the resource's palette token
---@param state string
---@param x number from the holder's left
---@param y number from the holder's top
---@param preview table the library's preview
function ResourcePreview:DrawSegments(settings, token, state, x, y, preview)
	local ClassPower = AUI.ClassPower
	local count = token == "RUNES" and SAMPLE_RUNES or SAMPLE_SEGMENTS
	local base = ClassPower:BaseColor(settings, token, AUI.oUF.colors.power.MANA)
	local filled = state == EMPTY and 0 or state == PARTIAL and count - 2 or count
	local holder = self.resource

	holder:ClearAllPoints()
	holder:SetPoint("TOPLEFT", self.holder, "TOPLEFT", x, -y)
	ClassPower:StyleHolder(holder, settings.look, settings.width, settings.height, self.segments)
	ClassPower:PlaceSegments(holder, self.segments, count, settings)

	for index, segment in ipairs(self.segments) do
		local partial = state == PARTIAL and index == filled + 1
		local charged = state == CHARGED and (index == 2 or index == 3)

		segment:SetShown(index <= count)
		segment:SetValue(index <= filled and 1 or partial and 0.5 or 0)
		segment:SetStatusBarColor(ClassPower:SegmentColor(settings, base, charged, partial))
		segment.Text:SetText("")
	end

	preview:Part(holder, "classWidth")
end

---Draws the power bar in a state.
---@param state string
---@param width number
---@param height number
---@param y number from the holder's top
---@param preview table the library's preview
function ResourcePreview:DrawPower(state, width, height, y, preview)
	local UnitFrame, PowerColor = AUI.UnitFrame, AUI.PowerColor
	local key = "playerPower"
	local share = POWER_SHARES[state]
	local bar = self.bar
	local reverse = AUI.Profile:Get(Options:Path(key, "reverse")) == true

	self.powerHolder:ClearAllPoints()
	self.powerHolder:SetPoint("TOPLEFT", self.holder, "TOPLEFT", (self.holder:GetWidth() - width) / 2, -y)
	self.powerHolder:SetSize(width, height)
	UnitFrame:StyleBar(bar, self.background, self.border, UnitFrame:BarLook(key))
	bar:SetReverseFill(reverse)
	bar:SetValue(share)
	UnitFrame:AnchorBackground(bar, self.background, reverse)
	PowerColor:ApplyPalette()

	local settings = PowerColor:Resolve(key)
	local fill = PowerColor:Fill(settings, AUI.oUF.colors.power.MANA, SampleClassColor())

	AUI.HealthColor:Paint(bar, self.background, settings, fill, PowerColor:Background(settings, fill))
	preview:Part(bar, "powerWidth")

	local slots, widths, contexts = AUI.Text:Layout(key, #self.TextSlots)
	local sample = Sample(1, false, NO_OVERLAYS)

	sample.power = RESOURCE_MAX_POWER * share
	sample.powerPercent = share * 100

	for index, slot in ipairs(slots) do
		local text = self.TextSlots[index]
		local shown = AUI.Tags:Sample(slot, contexts[index], sample)

		if shown then
			AUI.Text:Place(text, bar, slot, widths[index])
			text:SetText(shown)
			text:Show()
		else
			text:Hide()
		end
	end
end

---@param state string? a state's label
---@param preview table the library's preview
---@return number width
---@return number height
function ResourcePreview:Refresh(state, preview)
	local Profile = AUI.Profile
	local ClassPower = AUI.ClassPower
	local label = state or FULL
	local settings = ClassPower:Resolve()
	local powerWidth = Profile:Get(Options:Path("playerPower", "width"))
	local powerHeight = Profile:Get(Options:Path("playerPower", "height"))
	local width = math.max(powerWidth, settings.width)
	local attached = ClassPower:IsAttached()
	local x = (width - settings.width) / 2 + (attached and settings.attachX or 0)
	local token = SampleResource()
	local y = 0

	self.holder:SetWidth(width)
	self.resource:SetShown(token ~= nil)

	if token then
		self:DrawSegments(settings, token, label, x, y, preview)
		y = y + settings.height
	end

	self.extraHolder:SetShown(settings.extraMana)

	if settings.extraMana then
		local extra = self.extraHolder

		if token then
			y = y + ClassPower.GAP
		end

		extra:ClearAllPoints()
		extra:SetPoint("TOPLEFT", self.holder, "TOPLEFT", x, -y)
		ClassPower:StyleHolder(extra, settings.look, settings.width, settings.extraManaHeight, { self.extra })
		ClassPower:PlaceSegment(self.extra, extra, 0, settings.width, settings.extraManaHeight, settings)
		self.extra:SetValue(POWER_SHARES[label])
		self.extra:SetStatusBarColor(ClassPower:Shade(AUI.oUF.colors.power.MANA))
		self.extra.Text:SetText("")
		preview:Part(self.extra, "extraMana")
		y = y + settings.extraManaHeight
	end

	if y > 0 then
		y = y + (attached and settings.attachY or RESOURCE_GAP)
	end

	self:DrawPower(label, powerWidth, powerHeight, y, preview)

	local height = y + powerHeight

	self.holder:SetHeight(height)

	return width, height
end
