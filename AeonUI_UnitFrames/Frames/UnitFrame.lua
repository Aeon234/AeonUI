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
---@field Health StatusBar
---@field Background Texture
---@field Border AUIBorder
---@field TextSlots FontString[]
---@field Overlays AUIOverlayWidgets?
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
---@return AUIBarLook look
function UnitFrame:BarLook(key)
	local Profile = AUI.Profile
	local style = Profile:Get(Options:Path(key, "bars.borderStyle"))
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
		color = Profile:Get(Options:Path(key, "bars.lineColor"))
	elseif style ~= "FOREVER" then
		color = Profile:Get(Options:Path(key, "bars.borderColor"))
	end

	return {
		texture = Profile:Get(Options:Path(key, "bars.texture")),
		background = Profile:Get(Options:Path(key, "bars.background")),
		borderStyle = style,
		borderThickness = Profile:Get(Options:Path(key, "bars.borderThickness")),
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

	frame:RegisterForClicks("AnyUp")
	frame:SetScript("OnEnter", frame.OnEnter)
	frame:SetScript("OnLeave", frame.OnLeave)
end

---Shows the border as hovered and Blizzard's unit tooltip. The tooltip's update reads `self.unit`, which oUF does not
---keep; oUF's current unit (`__unit`, which follows vehicles) is copied there first.
function UnitFrameMixin:OnEnter()
	self.hovered = true
	UnitFrame:ShowHover(self.Border, self.key, true)
	self.unit = self.__unit
	UnitFrame_OnEnter(self)
end

function UnitFrameMixin:OnLeave()
	self.hovered = false
	UnitFrame:ShowHover(self.Border, self.key, false)
	UnitFrame_OnLeave(self)
end

---@return { point: string, x: number, y: number } position the saved place, or the frame's default
function UnitFrameMixin:Position()
	return AUI.Profile:Get(Options:Path(self.key, "position")) or self.spec.position
end

---Size and position. These touch a secure frame, so they run only out of combat.
function UnitFrameMixin:ApplyLayout()
	local Profile = AUI.Profile
	local position = self:Position()

	self:SetSize(Profile:Get(Options:Path(self.key, "width")), Profile:Get(Options:Path(self.key, "height")))
	self:ClearAllPoints()
	self:SetPoint(position.point, UIParent, position.point, position.x, position.y)
	self.Border:Layout()
end

---Bar look, health colors, fill direction and text. None is protected, so this also runs in combat.
function UnitFrameMixin:ApplyAppearance()
	local reverse = AUI.Profile:Get(Options:Path(self.key, "reverse")) == true

	UnitFrame:StyleBar(self.Bar, self.Background, self.Border, UnitFrame:BarLook(self.key))

	if self.hovered then
		UnitFrame:ShowHover(self.Border, self.key, true)
	end

	self.Bar:SetReverseFill(reverse)
	UnitFrame:AnchorBackground(self.Bar, self.Background, reverse)
	AUI.Text:Apply(self, self.key)
	AUI.HealthColor:Apply(self, AUI.HealthColor:Resolve(self.key))

	if self.Overlays then
		AUI.Overlays:Apply(self.Overlays, AUI.Overlays:Resolve(self.key), reverse, self.Health)
	end

	-- Redraws the bar with the new settings.
	if self.Health:IsVisible() then
		(self.Health --[[@as table]]):ForceUpdate()
	end
end
