local AUI = select(2, ...)

local L = AUI.L
local Options = AUI.CastBarOptions

local CAST_EVENTS = {
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_FAILED",
	"UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
	"UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
	"UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_UPDATE", "UNIT_SPELLCAST_EMPOWER_STOP",
}
local PET_BATTLE_EVENTS = { "PET_BATTLE_OPENING_START", "PET_BATTLE_CLOSE" }
-- The gap between the spell name and the time, in UI units.
local TEXT_GAP = 4
local SAMPLE_TIME = "1.2"

---@class AUICastBarFrame : Frame
---@field edge Frame one pixel larger than the bar on every side; its border and background
---@field border AUIBorder
---@field bar StatusBar
---@field locked Frame covers the fill while the cast cannot be interrupted
---@field over Frame the spark and text, above the cover
---@field spark Texture
---@field text FontString the spell name
---@field time FontString
---@field binding table a duration text binding; writes the remaining time into `time`

---The player cast bar. The client's timer drives the fill from the cast's duration object and a duration text binding
---writes the time, so no Lua runs while a cast is drawn and no secret value is read: the spell name, the duration and
---the interruptible flag go straight to widgets. Each cast event reads the cast again and draws it, or hides the bar
---when there is none.
---@class AUICastBar
---@field active boolean started this session
---@field following boolean the events are registered
---@field sampling boolean edit mode shows the sample
---@field petBattle boolean
---@field frame AUICastBarFrame?
---@field formatter NumericRuleFormatter?
local CastBar = {
	active = false,
	following = false,
	sampling = false,
	petBattle = false,
}
AUI.CastBar = CastBar

---@param region FontString
local function StyleText(region)
	local shadow = Options.SHADOW

	region:SetFont(AUI.Media:Font(Options.FONT), Options.FONT_SIZE, "")
	region:SetShadowColor(shadow.r, shadow.g, shadow.b, shadow.a)
	region:SetShadowOffset(1, -1)
	region:SetWordWrap(false)
end

---@return NumericRuleFormatter formatter seconds to one decimal
function CastBar:Formatter()
	if not self.formatter then
		local formatter = C_StringUtil.CreateNumericRuleFormatter()

		formatter:SetBreakpoints({ { threshold = 0, step = 0.1, format = "%.1f" } })
		self.formatter = formatter
	end

	return self.formatter
end

---Builds the bar at its size with its look, unplaced and hidden.
---@param parent Frame
---@param name string? a global name, for the root frame only
---@return AUICastBarFrame frame
function CastBar:Build(parent, name)
	local frame = CreateFrame("Frame", name, parent) --[[@as AUICastBarFrame]]

	frame:SetSize(Options.WIDTH, Options.HEIGHT)
	frame:Hide()

	frame.edge = CreateFrame("Frame", nil, frame)
	frame.border = AUI.Border:Create(frame.edge)
	frame.border:Apply({ style = "THIN_LINE", color = Options.BORDER, background = Options.BACKGROUND })

	local bar = CreateFrame("StatusBar", nil, frame) --[[@as StatusBar]]

	bar:SetAllPoints()
	bar:SetFrameLevel(frame.edge:GetFrameLevel() + 2)
	bar:SetMinMaxValues(0, 1)
	AUI.Media:SetBarTexture(bar, AUI.Media.FLAT)

	local fill, first, last = bar:GetStatusBarTexture(), Options.FILL, Options.FILL_END

	fill:SetGradient("HORIZONTAL", CreateColor(first.r, first.g, first.b, 1), CreateColor(last.r, last.g, last.b, 1))
	frame.bar = bar

	-- A boolean that may be secret sets the cover's alpha, which a texture would not show reliably; a frame does.
	local locked = CreateFrame("Frame", nil, bar)
	local lockedFill = locked:CreateTexture(nil, "ARTWORK")

	locked:SetAllPoints(fill)
	lockedFill:SetAllPoints()
	lockedFill:SetColorTexture(Options.LOCKED.r, Options.LOCKED.g, Options.LOCKED.b, 1)
	locked:SetAlpha(0)
	frame.locked = locked

	local over = CreateFrame("Frame", nil, bar)

	over:SetAllPoints()
	over:SetFrameLevel(locked:GetFrameLevel() + 1)
	frame.over = over

	frame.spark = over:CreateTexture(nil, "OVERLAY")
	frame.spark:SetTexture(Options.SPARK_TEXTURE)
	frame.spark:SetBlendMode("ADD")
	frame.spark:SetSize(Options.SPARK_WIDTH, Options.SPARK_HEIGHT)
	frame.spark:SetPoint("CENTER", fill, "RIGHT")

	frame.time = over:CreateFontString(nil, "OVERLAY")
	frame.time:SetPoint("RIGHT")
	frame.time:SetJustifyH("RIGHT")
	StyleText(frame.time)

	frame.text = over:CreateFontString(nil, "OVERLAY")
	frame.text:SetPoint("LEFT")
	frame.text:SetPoint("RIGHT", frame.time, "LEFT", -TEXT_GAP, 0)
	frame.text:SetJustifyH("LEFT")
	StyleText(frame.text)

	frame.binding = C_DurationUtil.CreateDurationTextBinding()
	frame.binding:SetFontString(frame.time)
	frame.binding:SetTextFormat("{}", {
		{ property = Enum.DurationTextBindingProperty.RemainingDuration, formatter = self:Formatter() },
	})
	frame.binding:SetEnabled(false)

	self:Layout(frame)

	return frame
end

---Puts the border one physical pixel outside the bar, at the bar's current scale.
---@param frame AUICastBarFrame
function CastBar:Layout(frame)
	local pixel = AUI:Pixel(frame)

	frame.edge:ClearAllPoints()
	frame.edge:SetPoint("TOPLEFT", frame, "TOPLEFT", -pixel, pixel)
	frame.edge:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", pixel, -pixel)
end

function CastBar:CreateFrame()
	if self.frame then
		return
	end

	local frame = self:Build(UIParent, "AeonUICastBar")

	frame:SetFrameStrata("MEDIUM")
	frame:EnableMouse(false)
	self.frame = frame
	self:Place()
end

---@return { point: string, x: number, y: number } position the saved place, or the default one
function CastBar:Position()
	return AUI.Profile:Get(Options.POSITION_PATH) or Options.DEFAULT_POSITION
end

---Puts the bar at its saved place, or its default one; edit mode places it too once it is registered.
function CastBar:Place()
	local frame = self.frame

	if not frame then
		return
	end

	local position = self:Position()

	frame:ClearAllPoints()
	frame:SetPoint(position.point, UIParent, position.point, position.x, position.y)
	self:Layout(frame)
end

---@return boolean on the page's switch is on where the client can draw the bar
function CastBar:IsOn()
	return AUI.can.castBar == true and AUI.Profile:Get(Options.ENABLED_PATH) == true
end

---The player's cast, empowered cast or channel.
---@return AUICastKind? kind nil when the player is not casting
---@return LuaDurationObject? duration
---@return string? name the spell's display name, possibly secret
---@return boolean? notInterruptible possibly secret
function CastBar:Current()
	local name, displayName, _, _, _, _, _, notInterruptible = UnitCastingInfo("player")
	local casting = issecretvalue(name) or name ~= nil
	local duration, empowered

	if casting then
		duration = UnitCastingDuration("player")
	else
		name, displayName, _, _, _, _, notInterruptible, _, empowered = UnitChannelInfo("player")
		empowered = empowered == true and UnitEmpoweredChannelDuration ~= nil

		if issecretvalue(name) or name ~= nil then
			duration = empowered and UnitEmpoweredChannelDuration("player", true) or UnitChannelDuration("player")
		end
	end

	if not (issecretvalue(duration) or duration) then
		return nil
	end

	return Options:Kind(casting, not casting, empowered), duration, displayName, notInterruptible
end

---Starts the fill and the time from a cast's duration object.
---@param frame AUICastBarFrame
---@param kind AUICastKind
---@param duration LuaDurationObject
---@param name string?
---@param notInterruptible boolean?
function CastBar:Draw(frame, kind, duration, name, notInterruptible)
	local direction = Options:Drains(kind) and Enum.StatusBarTimerDirection.RemainingTime
		or Enum.StatusBarTimerDirection.ElapsedTime

	frame.bar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, direction)
	frame.binding:SetDuration(duration)
	frame.binding:SetEnabled(true)
	frame.text:SetText(name)

	if not issecretvalue(notInterruptible) and notInterruptible == nil then
		frame.locked:SetAlpha(0)
	else
		frame.locked:SetAlphaFromBoolean(notInterruptible --[[@as boolean]], 1, 0)
	end
end

---Fills the bar to the sample's share with a sample name and time, for edit mode.
---@param frame AUICastBarFrame
function CastBar:DrawSample(frame)
	frame.binding:SetEnabled(false)
	frame.bar:SetMinMaxValues(0, 1)
	frame.bar:SetValue(Options.SAMPLE_PROGRESS)
	frame.text:SetText(L["Cast Bar"])
	frame.time:SetText(SAMPLE_TIME)
	frame.locked:SetAlpha(0)
end

---Draws the player's cast, or the sample, or hides the bar.
function CastBar:Update()
	local frame = self.frame

	if not frame then
		return
	end

	local on = self:IsOn()
	local kind, duration, name, notInterruptible

	if on and not self.sampling then
		kind, duration, name, notInterruptible = self:Current()
	end

	if not Options:Visible(on, kind ~= nil, self.sampling, self.petBattle) then
		frame.binding:SetEnabled(false)
		frame:Hide()

		return
	end

	if self.sampling then
		self:DrawSample(frame)
	else
		self:Draw(frame, kind --[[@as AUICastKind]], duration --[[@as LuaDurationObject]], name, notInterruptible)
	end

	frame:Show()
end

---@param _ string
---@param unit string
function CastBar:OnCastEvent(_, unit)
	if unit == "player" then
		self:Update()
	end
end

---@param event string
function CastBar:OnPetBattleEvent(event)
	self.petBattle = event == "PET_BATTLE_OPENING_START"
	self:Update()
end

---Shows the sample whatever is being cast while edit mode is open, and draws the live cast again when it closes.
---@param shown boolean
function CastBar:Sample(shown)
	self.sampling = shown
	self:Update()
end

---Follows the events and parks Blizzard's bar while the switch is on; hides the bar, stops following them and hands
---Blizzard's bar back while it is off.
function CastBar:Apply()
	local on = self:IsOn()

	if on ~= self.following then
		self.following = on

		if on then
			self:CreateFrame()
			self.petBattle = AUI.can.petBattles == true and C_PetBattles.IsInBattle() == true

			for _, event in ipairs(CAST_EVENTS) do
				AUI.Events:Register(event, self, self.OnCastEvent)
			end

			if AUI.can.petBattles then
				for _, event in ipairs(PET_BATTLE_EVENTS) do
					AUI.Events:Register(event, self, self.OnPetBattleEvent)
				end
			end

			AUI.Events:Register("PLAYER_ENTERING_WORLD", self, self.Update)
		else
			AUI.Events:UnregisterAll(self)
		end

		AUI.CastBarBlizzard:SetParked(on)
	end

	self:Place()
	self:Update()
end

---@param path string? the changed setting; nil when the whole profile changed
function CastBar:OnProfileChanged(path)
	if path == nil or path:sub(1, 8) == "castBar." then
		AUI.Events:Coalesce("castBarApply", function()
			CastBar:Apply()
		end)
	end
end

function CastBar:Start()
	if self.active then
		return
	end

	self.active = true
	AUI.Callbacks:Register("Profile", self, self.OnProfileChanged)
	self:Apply()
end
