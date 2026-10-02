local AUI = select(2, ...)

local Schema = AUI.Schema

-- The frame's background behind the bar's fill.
local BACKGROUND = 0.067

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
---@field PowerBorder Texture[]?
---@field Overlays AUIOverlayWidgets? the health overlays, on frames that have them
---@field CastBarWidgets AUICastBarWidgets? the cast bar, on frames that have one
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
---@return Texture[] edges top, bottom, left and right, each one physical pixel
local function Border(parent)
	local edges = {}

	for index = 1, 4 do
		local edge = parent:CreateTexture(nil, "OVERLAY", nil, 7)

		edge:SetColorTexture(0, 0, 0, 1)
		edges[index] = edge
	end

	return edges
end

---Gives a frame the look every AeonUI bar shares: a background, one flat bar filling the frame, and a border.
---Used by the live frames and the settings previews alike.
---@param frame Frame
---@return StatusBar bar
---@return Texture background
---@return Texture[] border
function UnitFrame:CreateBar(frame)
	local background = frame:CreateTexture(nil, "BACKGROUND")

	background:SetAllPoints()
	background:SetColorTexture(BACKGROUND, BACKGROUND, BACKGROUND, 1)

	local bar = CreateFrame("StatusBar", nil, frame)

	bar:SetAllPoints()
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:GetStatusBarTexture():SetColorTexture(1, 1, 1, 1)

	return bar, background, Border(bar)
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
		local power, _, border = UnitFrame:CreateBar(holder)

		power.colorPower = true
		power.frequentUpdates = true
		frame.Power = power
		frame.PowerHolder = holder
		frame.PowerBorder = border
	end

	if Schema:Field("frames." .. frame.key .. ".castbar.enabled") then
		local widgets = AUI.CastBar:Create(frame.key == "player" and UIParent or frame)

		AUI.CastBar:Attach(frame, widgets)
		frame.CastBarWidgets = widgets
	end

	frame:RegisterForClicks("AnyUp")
	frame:SetScript("OnEnter", frame.OnEnter)
	frame:SetScript("OnLeave", UnitFrame_OnLeave)
end

---The style for the central power bar: power only, and it does not take the mouse.
---@param frame table the oUF frame
---@param unit string
function UnitFrame.PowerStyle(frame, unit)
	local power = Build(frame, unit)

	power.colorPower = true
	power.frequentUpdates = true
	frame.Power = power

	frame:EnableMouse(false)
end

---Shows Blizzard's unit tooltip. Its update reads `self.unit`, which oUF does not keep; oUF's current unit
---(`__unit`, which follows vehicles) is copied there first.
function UnitFrameMixin:OnEnter()
	self.unit = self.__unit
	UnitFrame_OnEnter(self)
end

---Places the one-pixel borders inside the bars' edges at the current scale.
function UnitFrameMixin:UpdateBorder()
	local pixel = AUI:Pixel(self)

	UnitFrame:LayoutBorder(self.Border, self.Bar, pixel)

	local power, border = self.Power, self.PowerBorder

	if power and border then
		UnitFrame:LayoutBorder(border, power, pixel)
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

	self.Main:ClearAllPoints()
	self.Main:SetPoint("TOPLEFT")
	self.Main:SetPoint("TOPRIGHT")
	self.Main:SetHeight(main)

	local holder = self.PowerHolder

	if holder then
		if power > 0 then
			holder:ClearAllPoints()
			holder:SetPoint("TOPLEFT", self.Main, "BOTTOMLEFT")
			holder:SetPoint("TOPRIGHT", self.Main, "BOTTOMRIGHT")
			holder:SetHeight(power)
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
			end
		else
			self:DisableElement("Castbar")
			cast.holder:Hide()
		end
	end

	if Schema:Read(config, base .. "enabled") then
		self:Enable()
	else
		self:Disable()
	end

	self:UpdateBorder()
end

---Fill direction and text. Neither is protected, so this also runs in combat.
---@param config table the active profile config
function UnitFrameMixin:ApplyAppearance(config)
	local reverse = Schema:Read(config, "frames." .. self.key .. ".reverse")

	self.Bar:SetReverseFill(reverse == true)

	local power = self.Power

	if self.PowerHolder and power then
		power:SetReverseFill(reverse == true)
	end

	local overlays = self.Overlays
	local settings = overlays and AUI.Overlays:Resolve(config, self.key)

	if overlays and settings then
		-- oUF's Health element: a status bar with the element's own methods added.
		local health = self.Health --[[@as table]]

		AUI.Overlays:Apply(overlays, settings, reverse == true, health)

		if self:IsVisible() then
			health:ForceUpdate()
		end
	end

	local cast = self.CastBarWidgets
	local castSettings = cast and AUI.CastBar:Resolve(config, self.key)

	if cast and castSettings then
		local anchor = self.key == "player" and UIParent or self

		AUI.CastBar:Apply(cast, castSettings, anchor, Schema:Read(config, "frames." .. self.key .. ".width"))
		AUI.CastBar:ApplyElement(cast, castSettings)
	end

	AUI.Text:Apply(self, self.key, config)
end
