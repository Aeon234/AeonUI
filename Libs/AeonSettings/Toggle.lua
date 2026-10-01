-- Toggle: a two-state switch whose pin slides between off (left) and on (right).
local _, ns = ...
local AS = ns.AeonSettings
local tokens = AS.tokens

local PIN_SCALE = 0.9 -- pin diameter relative to the track height, less PIN_INSET
local PIN_INSET = 2
local PIN_MIN = 4
local TRACK_CAP_U = 0.125 -- cap width in the track texture's coordinates

---@param from number
---@param to number
---@param t number
---@return number
local function Lerp(from, to, t)
	return from + (to - from) * t
end

---@class AeonSettingsToggle : Button, AeonSettingsControlMixin
---@field position number pin position, 0 off to 1 on
---@field value boolean the value the pin is at or moving to
---@field slide { from: number, to: number, elapsed: number, duration: number }?
---@field shakeElapsed number? time into a running shake
---@field shakeOffset number
---@field pressed boolean
AeonUISettings_ToggleMixin = CreateFromMixins(AS.ControlMixin)

function AeonUISettings_ToggleMixin:OnLoad()
	local file = AS.MEDIA .. "Toggle\\Track.tga"
	local capWidth = self:GetHeight() / 2
	self.TrackLeft:SetTexture(file)
	self.TrackLeft:SetTexCoord(0, TRACK_CAP_U, 0, 1)
	self.TrackLeft:SetWidth(capWidth)
	self.TrackMiddle:SetTexture(file)
	self.TrackMiddle:SetTexCoord(TRACK_CAP_U, 1 - TRACK_CAP_U, 0, 1)
	self.TrackRight:SetTexture(file)
	self.TrackRight:SetTexCoord(1 - TRACK_CAP_U, 1, 0, 1)
	self.TrackRight:SetWidth(capWidth)

	self.Pin.Dot:SetDesaturated(true)
	self.Pin.Highlight:SetAlpha(tokens.alpha.hover)
	self:SetMotionScriptsWhileDisabled(true)

	self.position = 0
	self.value = false
	self.shakeOffset = 0
	self.pressed = false
	self:InitControl(self.Pin, self)
	self:Draw()
end

---Positions and sizes the pin and colors its dot for the current position, press and shake.
function AeonUISettings_ToggleMixin:Draw()
	local width, height = self:GetSize()
	local p = self.position
	local diameter = math.max(PIN_MIN, PIN_SCALE * height - PIN_INSET)
	if self.pressed then
		diameter = diameter * tokens.motion.press
	end

	local pin = self.Pin
	pin:SetSize(diameter, diameter)
	pin:ClearAllPoints()
	pin:SetPoint("CENTER", self, "LEFT", height / 2 + (width - height) * p + self.shakeOffset, 0)

	local t = Clamp(p, 0, 1)
	local off, on = tokens.color.neutral, tokens.color.accent
	pin.Dot:SetVertexColor(Lerp(off[1], on[1], t), Lerp(off[2], on[2], t), Lerp(off[3], on[3], t))
	pin.Dot:SetAlpha(Lerp(tokens.alpha.off, 1, t))
end

---Runs while the pin slides or shakes; removes itself once both have finished.
---@param delta number
function AeonUISettings_ToggleMixin:Step(delta)
	local slide = self.slide
	if slide then
		slide.elapsed = slide.elapsed + delta
		local t = math.min(1, slide.elapsed / slide.duration)
		self.position = Lerp(slide.from, slide.to, 1 - (1 - t) ^ 3)
		if t >= 1 then
			self.slide = nil
		end
	end

	if self.shakeElapsed then
		local reject = tokens.motion.reject
		self.shakeElapsed = self.shakeElapsed + delta
		local t = self.shakeElapsed / reject.duration
		if t >= 1 then
			self.shakeElapsed = nil
			self.shakeOffset = 0
		else
			self.shakeOffset = reject.amplitude * math.sin(t * reject.cycles * 2 * math.pi) * (1 - t)
		end
	end

	self:Draw()
	if not self.slide and not self.shakeElapsed then
		self:SetScript("OnUpdate", nil)
	end
end

function AeonUISettings_ToggleMixin:RunMotion()
	self:SetScript("OnUpdate", self.Step)
end

---Slides the pin from where it is toward `target`, at the full-slide duration scaled by the distance left.
---@param target number
function AeonUISettings_ToggleMixin:SlideTo(target)
	local distance = math.abs(target - self.position)
	if distance == 0 then
		self.slide = nil
		self:Draw()

		return
	end

	self.slide = { from = self.position, to = target, elapsed = 0, duration = tokens.motion.slide * distance }
	self:RunMotion()
end

---Stops every motion and draws the pin at its value.
function AeonUISettings_ToggleMixin:Snap()
	self.slide = nil
	self.shakeElapsed = nil
	self.shakeOffset = 0
	self:SetScript("OnUpdate", nil)
	self.position = self.value and 1 or 0
	self:Draw()
end

---A toggle takes no setting fields.
---@param _ table
function AeonUISettings_ToggleMixin:Configure(_) end

---Shows a value: at once when `instant` or hidden, otherwise by sliding from the pin's current position.
---@param value any
---@param instant boolean?
function AeonUISettings_ToggleMixin:SetChecked(value, instant)
	self.value = value and true or false
	if instant or not self:IsVisible() then
		self:Snap()
	else
		self:SlideTo(self.value and 1 or 0)
	end
end

---@param enabled boolean
function AeonUISettings_ToggleMixin:ApplyEnabled(enabled)
	-- The mixin's SetEnabled replaces Button:SetEnabled on this frame, so the button is switched directly.
	if enabled then
		self:Enable()
	else
		self:Disable()
	end
	if enabled and self:IsMouseOver() then
		self.Pin.Highlight:Show()
	end
	self.TrackLeft:SetDesaturated(not enabled)
	self.TrackMiddle:SetDesaturated(not enabled)
	self.TrackRight:SetDesaturated(not enabled)
	self.Pin.Circle:SetDesaturated(not enabled)
	self:Draw()
end

---Releases a press and hides the hover highlight.
function AeonUISettings_ToggleMixin:EndInteraction()
	self.pressed = false
	self.Pin.Highlight:Hide()
	self:Draw()
end

---Stops the slide and shake and draws the pin at its value.
function AeonUISettings_ToggleMixin:StopMotion()
	self:Snap()
end

function AeonUISettings_ToggleMixin:StartShake()
	self.shakeElapsed = 0
	self:RunMotion()
end

function AeonUISettings_ToggleMixin:StopShake()
	self.shakeElapsed = nil
	self.shakeOffset = 0
	if not self.slide then
		self:SetScript("OnUpdate", nil)
	end
	self:Draw()
end

function AeonUISettings_ToggleMixin:OnClick()
	self.value = not self.value
	PlaySound(self.value and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
	self:SlideTo(self.value and 1 or 0)
	self:Request(self.value)
end

function AeonUISettings_ToggleMixin:OnEnter()
	if self.enabled then
		self.Pin.Highlight:Show()
	end
end

function AeonUISettings_ToggleMixin:OnLeave()
	self.Pin.Highlight:Hide()
	if self.pressed then
		self.pressed = false
		self:Draw()
	end
end

---@param button string
function AeonUISettings_ToggleMixin:OnMouseDown(button)
	if button == "LeftButton" and self.enabled then
		self.pressed = true
		self:Draw()
	end
end

function AeonUISettings_ToggleMixin:OnMouseUp()
	if self.pressed then
		self.pressed = false
		self:Draw()
	end
end

AS:RegisterControl("toggle", { frameType = "Button", template = "AeonUISettings_ToggleTemplate" })
