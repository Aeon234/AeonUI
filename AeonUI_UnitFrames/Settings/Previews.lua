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
local FramePreview = {}
FramePreview.__index = FramePreview
FramePreview.STATES = { FULL, DAMAGED, DEAD, HOVER }
FramePreview.OVERLAY_STATES = { FULL, DAMAGED, DEAD, HOVER, ABSORBS, OVERFLOW }
AUI.FramePreview = FramePreview

---@param spec AUIFrameSpec
---@return AUIFramePreview preview
function FramePreview:New(spec)
	return setmetatable({ spec = spec, auraIcons = { buffs = {}, debuffs = {} } }, self)
end

---@param canvas Frame
function FramePreview:Create(canvas)
	local holder = CreateFrame("Frame", nil, canvas)

	holder:SetPoint("CENTER")
	self.holder = holder
	self.bar, self.background, self.border = AUI.UnitFrame:CreateBar(holder)
	AUI.Text:Create(self, self.bar, self.spec.slots)
	self.bar:SetMinMaxValues(0, 1)

	if self.spec.overlays then
		self.overlays = AUI.Overlays:Create(self.bar)
	end
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
						count = frame:CreateFontString(nil, "OVERLAY"),
						time = frame:CreateFontString(nil, "OVERLAY"),
					}
					icon.texture:SetAllPoints()
					icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
					-- The border is a colored backing one unit wider than the icon on each side.
					icon.border:SetPoint("TOPLEFT", -1, 1)
					icon.border:SetPoint("BOTTOMRIGHT", 1, -1)
					icons[index] = icon
				end

				local frame = icon.frame
				local dispel = DISPEL_COLORS[(index - 1) % #DISPEL_COLORS + 1]

				frame:SetSize(settings.size, settings.size)
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
	local height = Profile:Get(Options:Path(key, "height"))
	local reverse = Profile:Get(Options:Path(key, "reverse")) == true
	local label = state or FULL
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
	bar:SetReverseFill(reverse)
	bar:SetValue(share)
	UnitFrame:AnchorBackground(bar, self.background, reverse)
	HealthColor:Paint(bar, self.background, settings, fill, backdrop)

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

	if not self.spec.auras then
		return width, height
	end

	self:DrawAuras(width, preview)

	local above, below, left, right = self:AuraSpace(width, height)

	self.holder:ClearAllPoints()
	self.holder:SetPoint("CENTER", (left - right) / 2, (below - above) / 2)

	return width + left + right, height + above + below
end
