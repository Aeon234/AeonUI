-- Slider: Blizzard's stepped slider with a typed number box, for a number within a range.
local _, ns = ...
local AS = ns.AeonSettings

local ROUNDING_EPSILON = 1e-9 -- absorbs binary error so exact halves round up

local FORMATS = {
	integer = function(value)
		return ("%d"):format(math.floor(value + 0.5))
	end,
	decimal = function(value)
		return ("%.1f"):format(value)
	end,
	percent = function(value)
		return ("%d%%"):format(math.floor(value + 0.5))
	end,
}

---@class AeonSettingsSlider : Frame, AeonSettingsControlMixin
---@field min number
---@field max number
---@field step number
---@field format "integer" | "decimal" | "percent"
---@field saved number the owner's saved value
---@field updating boolean? the slider is being set from code
---@field dragging boolean? the thumb is held
---@field dragRefused boolean? a save was refused during the current drag
AeonUISettings_SliderMixin = CreateFromMixins(AS.ControlMixin)

function AeonUISettings_SliderMixin:OnLoad()
	local steppers = self.Motion.Steppers
	local slider = steppers.Slider
	local box = self.Motion.Box

	self.min, self.max, self.step, self.format = 0, 1, 1, "integer"
	self.saved = 0

	steppers:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
		self:OnSliderChanged(value)
	end, self)

	-- A drag ends on mouse release over the bar, whether or not the cursor has left it.
	slider:HookScript("OnMouseDown", function(_, button)
		if button == "LeftButton" and self.enabled then
			self.dragging = true
		end
	end)
	slider:HookScript("OnMouseUp", function()
		self:EndDrag()
	end)

	box:SetFontObject(GameFontHighlight)
	box:SetJustifyH("CENTER")
	box:HookScript("OnEnterPressed", function()
		self:SubmitText()
	end)
	box:HookScript("OnEditFocusLost", function()
		self:ShowSaved()
	end)

	self:InitControl(self.Motion, slider, box, steppers.Back, steppers.Forward)
end

---Rounds to the nearest step from `min`; halves round up.
---@param value number
---@return number
function AeonUISettings_SliderMixin:Round(value)
	local steps = math.floor((value - self.min) / self.step + 0.5 + ROUNDING_EPSILON)
	local rounded = self.min + steps * self.step

	return tonumber(("%.6f"):format(rounded)) or rounded
end

---Moves the thumb without asking the owner.
---@param value number
function AeonUISettings_SliderMixin:SetThumb(value)
	self.updating = true
	self.Motion.Steppers:SetValue(value)
	self.updating = false
end

---Shows the saved value in the box, unless the box is being typed in.
function AeonUISettings_SliderMixin:ShowSaved()
	local box = self.Motion.Box
	if not box:HasFocus() then
		box:SetText(FORMATS[self.format](self.saved))
		box:SetCursorPosition(0)
	end
end

---Applies the setting's range, step and format.
---@param setting { min: number, max: number, step: number?, format: string? }
function AeonUISettings_SliderMixin:Configure(setting)
	self.min, self.max = setting.min, setting.max
	self.step = setting.step or 1
	self.format = FORMATS[setting.format] and setting.format or "integer"

	self.updating = true
	self.Motion.Steppers:Init(self.saved, self.min, self.max, (self.max - self.min) / self.step)
	self.updating = false
end

---Shows the saved value. During a drag only the box follows; the thumb stays with the cursor.
---@param value number
---@param _ boolean? instant; the slider never animates
function AeonUISettings_SliderMixin:SetChecked(value, _)
	self.saved = value or self.min
	if not self.dragging then
		self:SetThumb(self.saved)
	end
	self:ShowSaved()
end

---@param enabled boolean
function AeonUISettings_SliderMixin:ApplyEnabled(enabled)
	self.Motion.Steppers:SetEnabled(enabled)
	self.Motion.Box:SetEnabled(enabled)
end

---Leaves the number box and ends a drag.
function AeonUISettings_SliderMixin:EndInteraction()
	self.Motion.Box:ClearFocus()
	self:EndDrag()
end

---@param value number
---@return boolean
function AeonUISettings_SliderMixin:IsSaved(value)
	return value == self.saved
end

---@return boolean
function AeonUISettings_SliderMixin:IsInteracting()
	return self.dragging == true
end

---Asks the owner for each new step the thumb or a step button reaches.
---@param value number
function AeonUISettings_SliderMixin:OnSliderChanged(value)
	if self.updating or self.dragRefused then
		return
	end

	self:Request(self:Round(value))
end

---Ends a drag: the thumb returns to the saved value.
function AeonUISettings_SliderMixin:EndDrag()
	if not self.dragging then
		return
	end

	self.dragging = false
	self.dragRefused = false
	self:SetThumb(self.saved)
	self:InteractionEnded()
end

---Applies typed text: a number within the range, rounded to a step, is requested; anything else restores the
---saved value.
function AeonUISettings_SliderMixin:SubmitText()
	local box = self.Motion.Box
	local text = strtrim(box:GetText()):gsub("%%$", "")
	local value = tonumber(text)
	box:ClearFocus()

	if not value or value < self.min or value > self.max then
		self:ShowSaved()

		return
	end

	self:Request(self:Round(value))
	self:ShowSaved()
end

---Signals a refused save; during a drag, the rest of the drag asks for nothing.
---@param message string?
function AeonUISettings_SliderMixin:Reject(message)
	if self.dragging then
		self.dragRefused = true
	end
	AS.ControlMixin.Reject(self, message)
end

AS:RegisterControl("slider", { frameType = "Frame", template = "AeonUISettings_SliderTemplate" })
