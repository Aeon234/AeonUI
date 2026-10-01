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
---@field key string the frame's key under `frames` in the profile
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
---@param frame table the oUF frame
---@param unit string
---@return StatusBar bar
local function Build(frame, unit)
	Mixin(frame, UnitFrameMixin)

	frame.key = UnitFrame.keys[unit] or unit
	frame.Bar, frame.Background, frame.Border = UnitFrame:CreateBar(frame)
	AUI.Text:Create(frame, frame.Bar, Schema.textSlots[frame.key])

	return frame.Bar
end

---The style for the player and target frames: health, clicks and the unit tooltip.
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

---Places the one-pixel border inside the frame's edges at the current scale.
function UnitFrameMixin:UpdateBorder()
	UnitFrame:LayoutBorder(self.Border, self.Bar, AUI:Pixel(self))
end

---Size, position and whether the frame watches its unit. These touch a secure frame, so they run only out of combat.
---@param config table the active profile config
function UnitFrameMixin:ApplyLayout(config)
	local base = "frames." .. self.key .. "."

	self:SetSize(Schema:Read(config, base .. "width"), Schema:Read(config, base .. "height"))
	self:ClearAllPoints()
	self:SetPoint("CENTER", UIParent, "CENTER", Schema:Read(config, base .. "x"), Schema:Read(config, base .. "y"))

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
	AUI.Text:Apply(self, self.key, config)
end
