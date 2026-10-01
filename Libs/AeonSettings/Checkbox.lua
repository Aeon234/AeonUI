-- Checkbox: Blizzard's minimal checkbox as a controlled on/off control.
local _, ns = ...
local AS = ns.AeonSettings

---@class AeonSettingsCheckbox : Frame, AeonSettingsControlMixin
---@field Box CheckButton
AeonUISettings_CheckboxMixin = CreateFromMixins(AS.ControlMixin)

function AeonUISettings_CheckboxMixin:OnLoad()
	self.Box:SetMotionScriptsWhileDisabled(true)
	self.Box:SetScript("OnClick", function(box)
		local value = box:GetChecked() == true
		PlaySound(value and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		self:Request(value)
	end)
	self:InitControl(self.Box, self.Box)
end

---A checkbox takes no setting fields.
---@param _ table
function AeonUISettings_CheckboxMixin:Configure(_) end

---Shows a value at once; the checkbox never animates.
---@param value any
---@param _ boolean? instant
function AeonUISettings_CheckboxMixin:SetChecked(value, _)
	self.Box:SetChecked(value and true or false)
end

---@param enabled boolean
function AeonUISettings_CheckboxMixin:ApplyEnabled(enabled)
	self.Box:SetEnabled(enabled)
end

AS:RegisterControl("checkbox", { frameType = "Frame", template = "AeonUISettings_CheckboxTemplate" })
