local AUI = select(2, ...)

local Schema = AUI.Schema

---Behavior shared by AeonUI's oUF frames, mixed into each.
---@class AUIUnitFrame : Button
---@field unit string?
---@field __unit string? oUF's current unit, which follows vehicles
---@field Enable fun(self: AUIUnitFrame) oUF: watch the unit and show the frame while it exists
---@field Disable fun(self: AUIUnitFrame) oUF: stop watching the unit and hide the frame
---@field EnableElement fun(self: AUIUnitFrame, name: string) oUF: activate an element
---@field DisableElement fun(self: AUIUnitFrame, name: string) oUF: deactivate an element
---@field Main Frame the holder of the main bar, at the top of the frame
---@field PowerHolder Frame? the attached power bar's holder, on frames that have one
---@field PowerBackground Texture?
---@field PowerBorder Texture[]?
---@field Overlays AUIOverlayWidgets? the health overlays, on frames that have them
---@field CastBarWidgets AUICastBarWidgets? the cast bar, on frames that have one
---@field AuraDisplays table<string, AUIAuraWidgets>? the buff and debuff displays, on frames that have them
---@field PortraitWidgets AUIPortraitWidgets? the portrait, on frames that can show one
---@field portraitMode string? the portrait mode oUF's element was last enabled in
---@field key string the frame's key under `frames` in the profile
---@field slot integer? the frame's place in its group, for a group's frames
---@field Bar StatusBar the frame's one bar: oUF's Health or Power element
---@field Health StatusBar?
---@field Power StatusBar?
---@field Background Texture
---@field Border Texture[]
---@field TextSlots FontString[]
local UnitFrameMixin = {}

---Builds the oUF styles for AeonUI's frames.
---@class AUIUnitFrameFactory
---@field keys table<string, string> the next spawned frame's key, by unit
local UnitFrame = {
	keys = {},
}
AUI.UnitFrame = UnitFrame

---@param parent Frame
---@return Texture[] edges top, bottom, left and right
local function Border(parent)
	local edges = {}

	for index = 1, 4 do
		edges[index] = parent:CreateTexture(nil, "OVERLAY", nil, 7)
	end

	return edges
end

---Creates the parts every AeonUI bar has: a background, one bar filling the frame, and a border. `StyleBar` gives
---them their look. Used by the live frames and the settings previews alike.
---@param frame Frame
---@return StatusBar bar
---@return Texture background
---@return Texture[] border
function UnitFrame:CreateBar(frame)
	local background = frame:CreateTexture(nil, "BACKGROUND")

	background:SetColorTexture(1, 1, 1, 1)

	local bar = CreateFrame("StatusBar", nil, frame)

	bar:SetAllPoints()

	return bar, background, Border(bar)
end

---@class AUIBarLook
---@field texture string a bar texture choice
---@field background table the background color
---@field border number the border size in physical pixels; 0 hides it
---@field borderColor table

---A frame's bar look, its own values or the shared ones.
---@param config table
---@param key string
---@param power boolean? the look of the frame's power bar
---@return AUIBarLook look
function UnitFrame:BarLook(config, key, power)
	local base = "frames." .. key .. ".bars."

	return {
		texture = Schema:Read(config, base .. (power and "powerTexture" or "texture")),
		background = Schema:Read(config, base .. "background"),
		border = Schema:Read(config, base .. "border"),
		borderColor = Schema:Read(config, base .. "borderColor"),
	}
end

---Applies a bar look to the parts `CreateBar` made.
---@param bar StatusBar
---@param background Texture
---@param border Texture[]
---@param look AUIBarLook
---@param pixel number one physical pixel in the bar's units
function UnitFrame:StyleBar(bar, background, border, look, pixel)
	local fill, edge = look.background, look.borderColor

	AUI.Media:SetBarTexture(bar, look.texture)
	background:SetVertexColor(fill.r, fill.g, fill.b, fill.a or 1)

	for _, texture in ipairs(border) do
		texture:SetColorTexture(edge.r, edge.g, edge.b, edge.a or 1)
		texture:SetShown(look.border > 0)
	end

	self:LayoutBorder(border, bar, look.border * pixel)
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

---Places a border's edges inside a bar's edges.
---@param border Texture[] top, bottom, left and right
---@param bar Region
---@param pixel number the edge thickness in the bar's units
function UnitFrame:LayoutBorder(border, bar, pixel)
	local top, bottom, left, right = unpack(border)

	top:ClearAllPoints()
	top:SetPoint("TOPLEFT", bar)
	top:SetPoint("TOPRIGHT", bar)
	top:SetHeight(pixel)

	bottom:ClearAllPoints()
	bottom:SetPoint("BOTTOMLEFT", bar)
	bottom:SetPoint("BOTTOMRIGHT", bar)
	bottom:SetHeight(pixel)

	left:ClearAllPoints()
	left:SetPoint("TOPLEFT", bar)
	left:SetPoint("BOTTOMLEFT", bar)
	left:SetWidth(pixel)

	right:ClearAllPoints()
	right:SetPoint("TOPRIGHT", bar)
	right:SetPoint("BOTTOMRIGHT", bar)
	right:SetWidth(pixel)
end

---Gives an oUF frame its bar and text slots.
---The heights a frame's parts take: its health (or main) bar, and the attached power bar when one is shown.
---@param config table
---@param key string
---@return number main
---@return number power 0 when the frame shows no attached power bar
function UnitFrame:Heights(config, key)
	local base = "frames." .. key .. "."
	local main = Schema:Read(config, base .. "height")

	if Schema:Read(config, base .. "power.enabled") == true then
		return main, Schema:Read(config, base .. "power.height")
	end

	return main, 0
end

---How far a group's slot sits from the group's first slot: one frame's width or height plus the spacing per slot,
---in the growth direction; vertically, an attached cast bar's space too. Every slot keeps its place whether or not
---its unit exists.
---@param config table
---@param key string a group's key
---@param slot integer? the frame's place in the group; nil or 1 for the first
---@return number x
---@return number y
function UnitFrame:SlotOffset(config, key, slot)
	if not slot or slot <= 1 then
		return 0, 0
	end

	local base = "frames." .. key .. "."
	local growth = Schema:Read(config, base .. "growth")
	local spacing = Schema:Read(config, base .. "spacing")

	if growth == "right" or growth == "left" then
		local step = (Schema:Read(config, base .. "width") + spacing) * (slot - 1)

		return growth == "right" and step or -step, 0
	end

	local main, power = self:Heights(config, key)
	local step = (main + power + AUI.CastBar:Extent(config, key) + spacing) * (slot - 1)

	return 0, growth == "up" and step or -step
end

---Gives an oUF frame its main bar, in a holder at the top of the frame, and its text slots.
---@param frame table the oUF frame
---@param unit string
---@return StatusBar bar
local function Build(frame, unit)
	Mixin(frame, UnitFrameMixin)

	frame.key = UnitFrame.keys[unit] or unit
	frame.Main = CreateFrame("Frame", nil, frame)
	frame.Bar, frame.Background, frame.Border = UnitFrame:CreateBar(frame.Main)
	AUI.Text:Create(frame, frame.Bar, frame.key)

	return frame.Bar
end

---The style for the player, target, target-of-target, focus and boss frames: health, an attached power bar where the
---frame has one, clicks and the unit tooltip.
---@param frame table the oUF frame
---@param unit string
function UnitFrame.HealthStyle(frame, unit)
	local health = Build(frame, unit)

	health.colorDisconnected = true
	health.colorTapping = true
	health.colorClass = true
	health.colorReaction = true
	health.colorHealth = true
	health.UpdateColor = AUI.HealthColor.UpdateColor
	frame.Health = health

	if Schema:Field("frames." .. frame.key .. ".overlays.absorb.enabled") then
		local overlays = AUI.Overlays:Create(health)

		health.HealingAll = overlays.healing
		health.DamageAbsorb = overlays.absorb
		health.HealAbsorb = overlays.healAbsorb
		health.OverHealIndicator = overlays.marker
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

	if Schema:Field("frames." .. frame.key .. ".power.enabled") then
		local holder = CreateFrame("Frame", nil, frame)
		local power, background, border = UnitFrame:CreateBar(holder)

		power.colorPower = true
		power.frequentUpdates = true
		power.PostUpdateColor = AUI.PowerColor.PostUpdateColor
		frame.Power = power
		frame.PowerHolder = holder
		frame.PowerBackground = background
		frame.PowerBorder = border
	end

	if Schema:Field("frames." .. frame.key .. ".castbar.enabled") then
		local widgets = AUI.CastBar:Create(frame.key == "player" and UIParent or frame)

		AUI.CastBar:Attach(frame, widgets)
		frame.CastBarWidgets = widgets
	end

	if Schema:Field("frames." .. frame.key .. ".portrait.enabled") then
		frame.PortraitWidgets = AUI.Portrait:Create(frame)
	end

	if Schema:Field("frames." .. frame.key .. ".buffs.enabled") then
		frame.AuraDisplays = {
			buffs = AUI.Auras:Create(frame, "buffs"),
			debuffs = AUI.Auras:Create(frame, "debuffs"),
		}
	end

	frame:RegisterForClicks("AnyUp")
	frame:SetScript("OnEnter", frame.OnEnter)
	frame:SetScript("OnLeave", UnitFrame_OnLeave)
	AUI.Indicators:Create(frame)
end

---The style for the central power bar: power only, and it does not take the mouse.
---@param frame table the oUF frame
---@param unit string
function UnitFrame.PowerStyle(frame, unit)
	local power = Build(frame, unit)

	power.colorPower = true
	power.frequentUpdates = true
	power.PostUpdateColor = AUI.PowerColor.PostUpdateColor
	frame.Power = power

	frame:EnableMouse(false)
end

---Shows Blizzard's unit tooltip, unless the frame's Tooltip setting is off or Hide Tooltip in Combat applies. Its
---update reads `self.unit`, which oUF does not keep; oUF's current unit (`__unit`, which follows vehicles) is copied
---there first.
function UnitFrameMixin:OnEnter()
	local config = AUI.Profile.config
	local base = "frames." .. self.key .. ".tooltip."

	if Schema:Field(base .. "enabled") then
		if not Schema:Read(config, base .. "enabled") then
			return
		end

		if Schema:Read(config, base .. "hideInCombat") and InCombatLockdown() then
			return
		end
	end

	self.unit = self.__unit
	UnitFrame_OnEnter(self)
end

---Gives the bars their look at the current scale: texture, background and border. The central power bar's one bar is
---a power bar.
---@param config table the active profile config
function UnitFrameMixin:StyleBars(config)
	local pixel = AUI:Pixel(self)
	local look = UnitFrame:BarLook(config, self.key, self.key == "playerPower")

	UnitFrame:StyleBar(self.Bar, self.Background, self.Border, look, pixel)

	local power = self.Power

	if self.PowerHolder and power and self.PowerBackground and self.PowerBorder then
		UnitFrame:StyleBar(power, self.PowerBackground, self.PowerBorder, UnitFrame:BarLook(config, self.key, true), pixel)
	end
end

---Size, position, the attached power bar and whether the frame watches its unit. These touch a secure frame, so
---they run only out of combat.
---@param config table the active profile config
function UnitFrameMixin:ApplyLayout(config)
	local base = "frames." .. self.key .. "."
	local main, power = UnitFrame:Heights(config, self.key)
	local x, y = UnitFrame:SlotOffset(config, self.key, self.slot)

	self:SetSize(Schema:Read(config, base .. "width"), main + power)
	self:ClearAllPoints()
	self:SetPoint("CENTER", UIParent, "CENTER", Schema:Read(config, base .. "x") + x, Schema:Read(config, base .. "y") + y)

	self:PlaceBars(config)

	local holder = self.PowerHolder

	if holder then
		if power > 0 then
			holder:Show()
			self:EnableElement("Power")
		else
			self:DisableElement("Power")
			holder:Hide()
		end
	end

	local cast = self.CastBarWidgets

	if cast then
		if Schema:Read(config, base .. "castbar.enabled") then
			self:EnableElement("Castbar")

			if self.key == "player" then
				AUI.CastBar:RestorePetCastBar()
				AUI.CastBar:BlockBlizzardCastBar(true)
			end
		else
			self:DisableElement("Castbar")
			cast.holder:Hide()

			if self.key == "player" then
				AUI.CastBar:BlockBlizzardCastBar(false)
			end
		end
	end

	for kind, display in pairs(self.AuraDisplays or {}) do
		AUI.Auras:Configure(display, AUI.Auras:Resolve(config, self.key, kind) --[[@as table]])
	end

	if Schema:Read(config, base .. "enabled") then
		self:Enable()
	else
		self:Disable()
	end
end

---Places the main bar and the attached power bar under it, leaving room for an attached portrait. Not protected.
---@param config table the active profile config
function UnitFrameMixin:PlaceBars(config)
	local main, power = UnitFrame:Heights(config, self.key)
	local left, right = AUI.Portrait:Inset(config, self.key)
	local look = UnitFrame:BarLook(config, self.key)
	local pixel = AUI:Pixel(self)

	-- An attached portrait shares its border with the bars.
	if left > 0 then
		left = left - look.border * pixel
	end

	if right > 0 then
		right = right - look.border * pixel
	end

	self.Main:ClearAllPoints()
	self.Main:SetPoint("TOPLEFT", left, 0)
	self.Main:SetPoint("TOPRIGHT", -right, 0)
	self.Main:SetHeight(main)

	local holder = self.PowerHolder

	if holder and power > 0 then
		holder:ClearAllPoints()
		holder:SetPoint("TOPLEFT", self.Main, "BOTTOMLEFT")
		holder:SetPoint("TOPRIGHT", self.Main, "BOTTOMRIGHT")
		holder:SetHeight(power)
	end
end

---Bar look, fill direction, portrait, overlays, cast bar, auras, indicators and text. None is protected, so this also
---runs in combat.
---@param config table the active profile config
function UnitFrameMixin:ApplyAppearance(config)
	local reverse = Schema:Read(config, "frames." .. self.key .. ".reverse")

	self:PlaceBars(config)

	if self.PortraitWidgets then
		AUI.Portrait:Apply(self, config)
	end

	self:StyleBars(config)
	self.Bar:SetReverseFill(reverse == true)
	UnitFrame:AnchorBackground(self.Bar, self.Background, reverse == true)

	local power = self.Power

	if self.PowerHolder and power and self.PowerBackground then
		power:SetReverseFill(reverse == true)
		UnitFrame:AnchorBackground(power, self.PowerBackground, reverse == true)
	end

	local healthColors = self.Health and AUI.HealthColor:Resolve(config, self.key)

	if healthColors then
		AUI.HealthColor:Apply(self, healthColors)
	end

	local powerColors = self.Power and AUI.PowerColor:Resolve(config, self.key)

	if powerColors then
		AUI.PowerColor:Apply(self, powerColors, self.PowerHolder and self.PowerBackground or self.Background)
	end

	local overlays = self.Overlays
	local settings = overlays and AUI.Overlays:Resolve(config, self.key)

	if overlays and settings then
		-- oUF's Health element: a status bar with the element's own methods added.
		local health = self.Health --[[@as table]]

		AUI.Overlays:Apply(overlays, settings, reverse == true, health)
	end

	local cast = self.CastBarWidgets
	local castSettings = cast and AUI.CastBar:Resolve(config, self.key)

	if cast and castSettings then
		local anchor = self.key == "player" and UIParent or self

		AUI.CastBar:Apply(cast, castSettings, anchor, Schema:Read(config, "frames." .. self.key .. ".width"))
		AUI.CastBar:ApplyElement(cast, castSettings)
	end

	if self.AuraDisplays then
		local above, below = AUI.Auras:Clearance(config, self.key)
		local width = Schema:Read(config, "frames." .. self.key .. ".width")

		for kind, display in pairs(self.AuraDisplays) do
			AUI.Auras:Place(display, AUI.Auras:Resolve(config, self.key, kind) --[[@as table]], width, above, below)
		end
	end

	AUI.Indicators:Apply(self, config)
	AUI.Text:Apply(self, self.key, config)

	-- Redraws the bars and overlays with the new settings, in the colors oUF gives them.
	for _, element in pairs({ health = self.Health, power = power }) do
		local update = (element --[[@as table]]).ForceUpdate

		if update and element:IsVisible() then
			update(element)
		end
	end
end
