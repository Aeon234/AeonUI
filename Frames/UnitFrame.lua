local AUI = select(2, ...)

local Schema = AUI.Schema

-- The frame's background behind the health fill.
local BACKGROUND = 0.067

---Behavior shared by the player and target frames, mixed into each oUF frame.
---@class AUIUnitFrame : Button
---@field unit string?
---@field __unit string? oUF's current unit, which follows vehicles
---@field Enable fun(self: AUIUnitFrame) oUF: watch the unit and show the frame while it exists
---@field Disable fun(self: AUIUnitFrame) oUF: stop watching the unit and hide the frame
---@field configUnit string the unit whose settings the frame uses
---@field Health StatusBar
---@field Background Texture
---@field Border Texture[]
local UnitFrameMixin = {}

---Builds the oUF style for AeonUI's unit frames.
---@class AUIUnitFrameFactory
local UnitFrame = {}
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

---The oUF style function: builds the frame's regions once. Settings are applied afterwards by `ApplyLayout` and
---`ApplyAppearance`.
---@param frame table the oUF frame
---@param unit string
function UnitFrame.Style(frame, unit)
	Mixin(frame, UnitFrameMixin)

	frame.configUnit = unit
	frame:RegisterForClicks("AnyUp")
	frame:SetScript("OnEnter", frame.OnEnter)
	frame:SetScript("OnLeave", UnitFrame_OnLeave)

	local background = frame:CreateTexture(nil, "BACKGROUND")

	background:SetAllPoints()
	background:SetColorTexture(BACKGROUND, BACKGROUND, BACKGROUND, 1)
	frame.Background = background

	local health = CreateFrame("StatusBar", nil, frame)

	health:SetAllPoints()
	health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	health:GetStatusBarTexture():SetColorTexture(1, 1, 1, 1)
	health.colorDisconnected = true
	health.colorTapping = true
	health.colorClass = true
	health.colorReaction = true
	health.colorHealth = true
	frame.Health = health

	frame.Border = Border(health)
	AUI.Text:Create(frame, health)
end

---Shows Blizzard's unit tooltip. Its update reads `self.unit`, which oUF does not keep; oUF's current unit
---(`__unit`, which follows vehicles) is copied there first.
function UnitFrameMixin:OnEnter()
	self.unit = self.__unit
	UnitFrame_OnEnter(self)
end

---Places the one-pixel border inside the frame's edges at the current scale.
function UnitFrameMixin:UpdateBorder()
	local pixel = AUI:Pixel(self)
	local top, bottom, left, right = unpack(self.Border)
	local bar = self.Health

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

---Size, position and whether the frame watches its unit. These touch a secure frame, so they run only out of combat.
---@param config table the active profile config
function UnitFrameMixin:ApplyLayout(config)
	local base = "frames." .. self.configUnit .. "."

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
	self.Health:SetReverseFill(Schema:Read(config, "frames." .. self.configUnit .. ".reverse"))
	AUI.Text:Apply(self, self.configUnit, config)
end
