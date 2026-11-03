local AUI = select(2, ...)

local Options = AUI.UnitFrameOptions

---The player's power bar, a frame of its own: oUF's Power element on the bar every AeonUI frame has, with text slots.
---It takes no mouse.
---@class AUIPlayerPowerFrame : Button
---@field key string
---@field spec AUIFrameSpec
---@field Bar StatusBar
---@field Power StatusBar
---@field Background Texture
---@field Border AUIBorder
---@field TextSlots FontString[]
local PlayerPowerMixin = {}

---@class AUIPlayerPower
local PlayerPower = {}
AUI.PlayerPower = PlayerPower

---The style for the power bar.
---@param frame table the oUF frame
function PlayerPower.Style(frame)
	Mixin(frame, PlayerPowerMixin)

	local spec = Options:Spec("playerPower") --[[@as AUIFrameSpec]]

	frame.key, frame.spec = spec.key, spec
	frame.Bar, frame.Background, frame.Border = AUI.UnitFrame:CreateBar(frame)
	AUI.Text:Create(frame, frame.Bar, spec.slots)

	local power = frame.Bar

	power.colorPower = true
	power.frequentUpdates = true
	power.PostUpdateColor = AUI.PowerColor.PostUpdateColor
	frame.Power = power
	frame:EnableMouse(false)
end

---Size, position and whether it shows. These touch a secure frame, so they run only out of combat.
function PlayerPowerMixin:ApplyLayout()
	local Profile = AUI.Profile
	local position = Profile:Get(Options:Path(self.key, "position")) or self.spec.position

	self:SetSize(Profile:Get(Options:Path(self.key, "width")), Profile:Get(Options:Path(self.key, "height")))
	self:ClearAllPoints()
	self:SetPoint(position.point, UIParent, position.point, position.x, position.y)
	self.Border:Layout()

	if Profile:Get(Options:Path(self.key, "enabled")) then
		self:Enable()
	else
		self:Disable()
	end
end

---Bar look, power colors, fill direction and text. None is protected, so this also runs in combat.
function PlayerPowerMixin:ApplyAppearance()
	local UnitFrame = AUI.UnitFrame
	local reverse = AUI.Profile:Get(Options:Path(self.key, "reverse")) == true

	UnitFrame:StyleBar(self.Bar, self.Background, self.Border, UnitFrame:BarLook(self.key))
	self.Bar:SetReverseFill(reverse)
	UnitFrame:AnchorBackground(self.Bar, self.Background, reverse)
	AUI.PowerColor:ApplyPalette()
	AUI.PowerColor:Apply(self, AUI.PowerColor:Resolve(self.key), self.Background)
	AUI.Text:Apply(self, self.key)

	-- Redraws the bar with the new settings.
	if self.Power:IsVisible() then
		(self.Power --[[@as table]]):ForceUpdate()
	end
end
