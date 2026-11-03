local AUI = select(2, ...)

local L = AUI.L
local Options = AUI.UnitFrameOptions

local FULL, DAMAGED, HOVER = L["Full"], L["Damaged"], L["Hover"]

-- The sample's maximum health, and each state's share of it.
local MAX_HEALTH = 412000
local SHARES = { [FULL] = 1, [DAMAGED] = 0.55, [DEAD] = 0, [HOVER] = 1 }

---A still sample of a frame, styled as the live frame is, with its bar and text slots as clickable parts.
---@class AUIFramePreview
---@field spec AUIFrameSpec
---@field holder Frame
---@field bar StatusBar
---@field background Texture
---@field border AUIBorder
---@field TextSlots FontString[]
local FramePreview = {}
FramePreview.__index = FramePreview
FramePreview.STATES = { FULL, DAMAGED, DEAD, HOVER }
AUI.FramePreview = FramePreview

---@param spec AUIFrameSpec
---@return AUIFramePreview preview
function FramePreview:New(spec)
	return setmetatable({ spec = spec }, self)
end

---@param canvas Frame
function FramePreview:Create(canvas)
	local holder = CreateFrame("Frame", nil, canvas)

	holder:SetPoint("CENTER")
	self.holder = holder
	self.bar, self.background, self.border = AUI.UnitFrame:CreateBar(holder)
	AUI.Text:Create(self, self.bar, self.spec.slots)
	self.bar:SetMinMaxValues(0, 1)
end

---@param share number the sample's share of its maximum health
---@param dead boolean
---@return AUITextSample sample
local function Sample(share, dead)
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
		absorb = 0,
		healAbsorb = 0,
		power = 8240,
		powerPercent = 64,
		name = name,
		level = level,
		classColor = class and RAID_CLASS_COLORS[class],
	}
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
	local sample = Sample(share, label == DEAD)
	local bar = self.bar
	local color = sample.classColor

	self.holder:SetSize(width, height)
	UnitFrame:StyleBar(bar, self.background, self.border, UnitFrame:BarLook(key))
	UnitFrame:ShowHover(self.border, key, label == HOVER)
	bar:SetReverseFill(reverse)
	bar:SetValue(share)
	UnitFrame:AnchorBackground(bar, self.background, reverse)

	if color then
		bar:SetStatusBarColor(color.r, color.g, color.b)
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

	return width, height
end
