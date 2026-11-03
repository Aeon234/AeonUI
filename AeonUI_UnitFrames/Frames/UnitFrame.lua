local AUI = select(2, ...)

local Options = AUI.UnitFrameOptions

-- The bar's own background shows behind the empty part, so the border draws no fill of its own.
local NO_FILL = { r = 0, g = 0, b = 0, a = 0 }

---Behavior shared by AeonUI's oUF frames, mixed into each.
---@class AUIUnitFrame : Button
---@field unit string?
---@field __unit string? oUF's current unit, which follows vehicles
---@field key string the frame's key under `frames` in the profile
---@field spec AUIFrameSpec
---@field hovered boolean? the mouse is over the frame
---@field Bar StatusBar the frame's main bar: oUF's Health element
---@field Power StatusBar? oUF's Power element, under the health
---@field PowerBackground Texture?
---@field CastBarView AUICastBarFrame?
---@field Health StatusBar
---@field Background Texture
---@field Border AUIBorder
---@field TextSlots FontString[]
---@field Overlays AUIOverlayWidgets?
---@field AuraDisplays table<string, AUIAuraWidgets>? by kind
---@field PortraitWidgets AUIPortraitWidgets?
---@field idleFade AUIFrameFade?
---@field threatColor table? the color threat gives the border, over any hover
local UnitFrameMixin = {}

---Builds the oUF style for AeonUI's frames, and the bars the settings previews share with them.
---@class AUIUnitFrameFactory
---@field specs table<string, AUIFrameSpec> the next spawned frame's spec, by unit
---@field BORDER_LEVEL integer the border's level above its bar, over the health overlays
---@field TEXT_LEVEL integer the text's level above its bar, over the border
local UnitFrame = {
	specs = {},
	BORDER_LEVEL = 6,
	TEXT_LEVEL = 8,
}
AUI.UnitFrame = UnitFrame

---Creates the parts every AeonUI bar has: a background, one bar filling the frame, and a border above the bar and
---below its text. `StyleBar` gives them their look.
---@param frame Frame
---@return StatusBar bar
---@return Texture background
---@return AUIBorder border
function UnitFrame:CreateBar(frame)
	local background = frame:CreateTexture(nil, "BACKGROUND")

	background:SetColorTexture(1, 1, 1, 1)

	local bar = CreateFrame("StatusBar", nil, frame)

	bar:SetAllPoints()

	local border = AUI.Border:Create(frame, true)

	border:SetFrameLevel(bar:GetFrameLevel() + self.BORDER_LEVEL)

	return bar, background, border
end

---@param key string
---@return number height the power bar under the frame's health, 0 when it has none or it is off
function UnitFrame:PowerHeight(key)
	local Profile = AUI.Profile
	local spec = Options:Spec(key)

	if spec and spec.power and Profile:Get(Options:Path(key, "power.enabled")) == true then
		return Profile:Get(Options:Path(key, "power.height"))
	end

	return 0
end

---The heights a frame's parts take.
---@param key string
---@return number health
---@return number power 0 when it shows no power bar
---@return number separator the line between them, one screen pixel
function UnitFrame:Heights(key)
	local health = AUI.Profile:Get(Options:Path(key, "height"))
	local power = self:PowerHeight(key)

	if power == 0 then
		return health, 0, 0
	end

	return health, power, AUI:Pixel()
end

---@param key string
---@return number height the whole frame's
function UnitFrame:FrameHeight(key)
	local health, power, separator = self:Heights(key)

	return health + separator + power
end

---@class AUIBarLook
---@field texture string a bar texture choice
---@field background table the background color
---@field borderStyle AUIBorderStyle
---@field borderThickness number
---@field borderColor table the color the style draws in
---@field edgeFile string? the backdrop edge file, for the "EDGE" style
---@field hover string how hovering shows: "color" takes the Hover Color, "lighten" lightens the color, "lit" the art

---A frame's bar look, its own values or the shared ones.
---@param key string
---@param section string? where under the frame's settings, when not its bars
---@return AUIBarLook look
function UnitFrame:BarLook(key, section)
	local Profile = AUI.Profile
	local bars = (section or "bars") .. "."
	local style = Profile:Get(Options:Path(key, bars .. "borderStyle"))
	local color = AUI.Border.ART_COLOR
	local edgeFile
	local hover = "color"

	-- A border that is no longer registered, or a style frames do not offer, draws the default.
	if not Options:IsOwnBorderStyle(style) then
		edgeFile = AUI.Media:BorderFile(style)
		style = edgeFile and "EDGE" or "THIN_LINE"
	end

	if style == "FOREVER_MINIMAL" then
		style, hover = "FOREVER_MINIMAL_SHADED", "lighten"
	elseif style == "FOREVER" then
		hover = "lit"
	end

	if style == "THIN_LINE" then
		color = Profile:Get(Options:Path(key, bars .. "lineColor"))
	elseif style ~= "FOREVER" then
		color = Profile:Get(Options:Path(key, bars .. "borderColor"))
	end

	return {
		texture = Profile:Get(Options:Path(key, bars .. "texture")),
		background = Profile:Get(Options:Path(key, bars .. "background")),
		borderStyle = style,
		borderThickness = Profile:Get(Options:Path(key, bars .. "borderThickness")),
		borderColor = color,
		edgeFile = edgeFile,
		hover = hover,
	}
end

---Applies a bar look to the parts `CreateBar` made.
---@param bar StatusBar
---@param background Texture
---@param border AUIBorder
---@param look AUIBarLook
function UnitFrame:StyleBar(bar, background, border, look)
	local fill = look.background

	AUI.Media:SetBarTexture(bar, look.texture)
	background:SetVertexColor(fill.r, fill.g, fill.b, fill.a or 1)
	border:Apply({
		style = look.borderStyle,
		color = look.borderColor,
		thickness = look.borderThickness,
		edgeFile = look.edgeFile,
		background = NO_FILL,
	})
end

---Shows a border as hovered or not: lightened or in the Hover Color by its style, or as it normally is.
---@param border AUIBorder
---@param key string
---@param hovered boolean
function UnitFrame:ShowHover(border, key, hovered)
	local Profile = AUI.Profile
	local look = self:BarLook(key)

	if not hovered or Profile:Get(Options:Path(key, "bars.hover")) ~= true then
		border:SetColor(look.borderColor)
		border:SetLit(false)
	elseif look.hover == "lit" then
		border:SetColor(look.borderColor)
		border:SetLit(true)
	elseif look.hover == "lighten" then
		local color, share = look.borderColor, Options.LIGHTEN

		border:SetColor({
			r = color.r + (1 - color.r) * share,
			g = color.g + (1 - color.g) * share,
			b = color.b + (1 - color.b) * share,
			a = color.a,
		})
		border:SetLit(false)
	else
		border:SetColor(Profile:Get(Options:Path(key, "bars.hoverColor")))
		border:SetLit(false)
	end
end

---Places a bar in its frame, leaving room at each side for an attached portrait.
---@param bar StatusBar
---@param parent Region
---@param left number
---@param right number
function UnitFrame:PlaceBar(bar, parent, left, right, bottom)
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", parent, "TOPLEFT", left, 0)
	bar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -right, bottom or 0)
end

---Creates the power bar a frame can show under its health.
---@param parent Frame
---@return StatusBar power
---@return Texture background
function UnitFrame:CreatePowerBar(parent)
	local background = parent:CreateTexture(nil, "BACKGROUND")

	background:SetColorTexture(1, 1, 1, 1)

	local power = CreateFrame("StatusBar", nil, parent)

	power.Separator = parent:CreateTexture(nil, "ARTWORK")
	power.Separator:SetColorTexture(0, 0, 0, 1)

	return power, background
end

---Places the power bar along the frame's bottom with its line above it, both beside an attached portrait, or hides
---them, and gives the bar the frame's texture and fill direction.
---@param power StatusBar
---@param background Texture
---@param parent Frame
---@param key string
---@param left number
---@param right number
---@param reverse boolean
---@return boolean shown
function UnitFrame:PlacePowerBar(power, background, parent, key, left, right, reverse)
	local height = self:PowerHeight(key)
	local shown = height > 0

	background:SetShown(shown)
	power.Separator:SetShown(shown)

	if not shown then
		return false
	end

	power.Separator:ClearAllPoints()
	power.Separator:SetPoint("BOTTOMLEFT", power, "TOPLEFT")
	power.Separator:SetPoint("BOTTOMRIGHT", power, "TOPRIGHT")
	power.Separator:SetHeight(AUI:Pixel())
	power:ClearAllPoints()
	power:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", left, 0)
	power:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -right, 0)
	power:SetHeight(height)
	AUI.Media:SetBarTexture(power, self:BarLook(key).texture)
	power:SetReverseFill(reverse)
	self:AnchorBackground(power, background, reverse)

	return true
end

---Places a bar's background over the part its fill leaves empty, so a translucent fill shows its own color.
---@param bar StatusBar
---@param background Texture
---@param reverse boolean the bar fills from right to left
function UnitFrame:AnchorBackground(bar, background, reverse)
	local fill = bar:GetStatusBarTexture()

	background:ClearAllPoints()

	if reverse then
		background:SetPoint("TOPLEFT", bar, "TOPLEFT")
		background:SetPoint("BOTTOMRIGHT", fill, "BOTTOMLEFT")
	else
		background:SetPoint("TOPLEFT", fill, "TOPRIGHT")
		background:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
	end
end

---The oUF style: health, text slots, clicks and the unit tooltip.
---@param frame table the oUF frame
---@param unit string
function UnitFrame.Style(frame, unit)
	Mixin(frame, UnitFrameMixin)

	local spec = UnitFrame.specs[unit]

	frame.spec = spec
	frame.key = spec.key
	frame.Bar, frame.Background, frame.Border = UnitFrame:CreateBar(frame)
	AUI.Text:Create(frame, frame.Bar, spec.slots)

	local health = frame.Bar

	-- `UpdateColor` paints the bar; these switch on the events oUF repaints it for.
	health.colorDisconnected = true
	health.colorTapping = true
	health.colorClass = true
	health.colorReaction = true
	health.colorHealth = true
	health.UpdateColor = AUI.HealthColor.UpdateColor
	frame.Health = health

	if spec.power then
		local power, background = UnitFrame:CreatePowerBar(frame)

		power.colorPower = true
		power.frequentUpdates = true
		power.PostUpdateColor = AUI.PowerColor.PostUpdateColor
		frame.Power = power
		frame.PowerBackground = background
	end

	if AUI.UnitCastBar:Has(spec) then
		frame.CastBarView = AUI.UnitCastBar:Attach(frame)
	end

	if spec.overlays then
		local overlays = AUI.Overlays:Create(health)

		health.HealingAll = overlays.healing
		health.DamageAbsorb = overlays.absorb
		health.HealAbsorb = overlays.healAbsorb
		health.damageAbsorbClampMode = Enum.UnitDamageAbsorbClampMode.MaximumHealth
		health.healAbsorbClampMode = Enum.UnitHealAbsorbClampMode.MaximumHealth
		health.healAbsorbMode = Enum.UnitHealAbsorbMode.ReducedByIncomingHeals
		health.incomingHealClampMode = Enum.UnitIncomingHealClampMode.MissingHealth
		health.incomingHealOverflow = 1
		health.PostUpdate = function(element)
			AUI.Overlays:Update(overlays, element.values)
		end
		frame.Overlays = overlays
	end

	if spec.auras then
		frame.AuraDisplays = {
			buffs = AUI.Auras:Create(frame, "buffs"),
			debuffs = AUI.Auras:Create(frame, "debuffs"),
		}
	end

	if spec.portrait then
		frame.PortraitWidgets = AUI.Portrait:Create(frame, health)
	end

	AUI.Indicators:Create(frame)

	frame:RegisterForClicks("AnyUp")
	frame:SetScript("OnEnter", frame.OnEnter)
	frame:SetScript("OnLeave", frame.OnLeave)
end

---@param hovered boolean
function UnitFrameMixin:ShowHovered(hovered)
	self:ShowBorder(self.Border, hovered)

	if self.PortraitWidgets and self.PortraitWidgets.border then
		self:ShowBorder(self.PortraitWidgets.border, hovered)
	end
end

---Shows one of the frame's borders as hovered or not, in the threat color while there is one.
---@param border AUIBorder
---@param hovered boolean
function UnitFrameMixin:ShowBorder(border, hovered)
	UnitFrame:ShowHover(border, self.key, hovered)

	if self.threatColor then
		border:SetColor(self.threatColor, true)
		border:SetLit(false)
	end
end

---Shows the border as hovered, brings the frame back from any fade and, unless Tooltip or Hide Tooltip in Combat keeps it away, Blizzard's unit tooltip. The
---tooltip's update reads `self.unit`, which oUF does not keep; oUF's current unit (`__unit`, which follows vehicles) is
---copied there first.
function UnitFrameMixin:OnEnter()
	local Profile = AUI.Profile

	self.hovered = true
	self:ShowHovered(true)
	AUI.Fading:Update(self)

	if not Profile:Get(Options:Path(self.key, "tooltip.enabled")) then
		return
	end

	if Profile:Get(Options:Path(self.key, "tooltip.hideInCombat")) and InCombatLockdown() then
		return
	end

	self.unit = self.__unit
	UnitFrame_OnEnter(self)
end

function UnitFrameMixin:OnLeave()
	self.hovered = false
	self:ShowHovered(false)
	AUI.Fading:Update(self)
	UnitFrame_OnLeave(self)
end

---@return { point: string, x: number, y: number } position the saved place, or the frame's default
function UnitFrameMixin:Position()
	return AUI.Profile:Get(Options:Path(self.key, "position")) or self.spec.position
end

---Size, position and what the aura containers hold. These run only out of combat: the first two touch a secure frame,
---and aura access can be restricted in it.
function UnitFrameMixin:ApplyLayout()
	local Profile = AUI.Profile
	local position = self:Position()

	self:SetSize(Profile:Get(Options:Path(self.key, "width")), UnitFrame:FrameHeight(self.key))
	self:ClearAllPoints()
	self:SetPoint(position.point, UIParent, position.point, position.x, position.y)
	self.Border:Layout()

	if self.spec.power then
		AUI.Indicators:SetElement(self, "Power", UnitFrame:PowerHeight(self.key) > 0, self.Power --[[@as table]])
	end

	for kind, display in pairs(self.AuraDisplays or {}) do
		AUI.Auras:Configure(display, AUI.Auras:Resolve(self.key, kind))
	end
end

---Bar look, health colors, fill direction and text. None is protected, so this also runs in combat.
function UnitFrameMixin:ApplyAppearance()
	local reverse = AUI.Profile:Get(Options:Path(self.key, "reverse")) == true

	UnitFrame:StyleBar(self.Bar, self.Background, self.Border, UnitFrame:BarLook(self.key))

	if self.PortraitWidgets then
		AUI.Portrait:Apply(self)
	end

	if self.hovered or self.threatColor then
		self:ShowHovered(self.hovered == true)
	end

	local left, right = AUI.Portrait:Inset(self.key)

	local _, power, separator = UnitFrame:Heights(self.key)

	UnitFrame:PlaceBar(self.Bar, self, left, right, power + separator)
	self.Bar:SetReverseFill(reverse)
	UnitFrame:AnchorBackground(self.Bar, self.Background, reverse)

	if self.spec.power then
		local bar, background = self.Power --[[@as StatusBar]], self.PowerBackground --[[@as Texture]]

		if UnitFrame:PlacePowerBar(bar, background, self, self.key, left, right, reverse) then
			AUI.PowerColor:ApplyPalette()
			AUI.PowerColor:Apply(self, AUI.PowerColor:Resolve(self.key), background)

			if bar:IsVisible() then
				(bar --[[@as table]]):ForceUpdate()
			end
		end
	end

	if AUI.UnitCastBar:Has(self.spec) then
		AUI.UnitCastBar:Apply(self)
	end

	AUI.Text:Apply(self, self.key)
	AUI.HealthColor:Apply(self, AUI.HealthColor:Resolve(self.key))

	if self.Overlays then
		AUI.Overlays:Apply(self.Overlays, AUI.Overlays:Resolve(self.key), reverse, self.Health)
	end

	if self.AuraDisplays then
		local above, below = AUI.Auras:Clearance(self.key)
		local width = AUI.Profile:Get(Options:Path(self.key, "width"))

		for kind, display in pairs(self.AuraDisplays) do
			AUI.Auras:Place(display, AUI.Auras:Resolve(self.key, kind), width, above, below)
		end
	end

	AUI.Indicators:Apply(self)

	-- Redraws the bar with the new settings.
	if self.Health:IsVisible() then
		(self.Health --[[@as table]]):ForceUpdate()
	end
end
