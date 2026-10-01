-- Sound checkbox: a checkbox for a setting that makes a sound, with a speaker button that plays the sound
-- whatever the checkbox's value.
local _, ns = ...
local AS = ns.AeonSettings
local L = AS.L
local tokens = AS.tokens

local ICON_GRAY = tokens.color.speakerIcon

---@class AeonSettingsSoundCheckbox : Frame, AeonSettingsControlMixin
---@field Motion Frame holds the checkbox; the shake moves it and leaves the speaker in place
---@field Speaker Button
---@field sound { kit: number?, file: string? }?
AeonUISettings_SoundCheckboxMixin = CreateFromMixins(AS.ControlMixin)

function AeonUISettings_SoundCheckboxMixin:OnLoad()
	local box = self.Motion.Box
	box:SetMotionScriptsWhileDisabled(true)
	box:SetScript("OnClick", function()
		local value = box:GetChecked() == true
		PlaySound(value and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		self:Request(value)
	end)

	local speaker = self.Speaker
	speaker.Icon:SetVertexColor(unpack(ICON_GRAY))
	speaker:SetMotionScriptsWhileDisabled(true)
	speaker:SetScript("OnEnter", function()
		if self.enabled then
			speaker.Icon:SetVertexColor(1, 1, 1)
			AS.Tooltip:Show(speaker, AS.Tooltip:Lines(nil, L["Play sound"]))
		end
	end)
	speaker:SetScript("OnLeave", function()
		speaker.Icon:SetVertexColor(unpack(ICON_GRAY))
		if not self:ShowsReason() then
			AS.Tooltip:Hide(speaker)
		end
	end)
	speaker:SetScript("OnMouseDown", function()
		if self.enabled then
			speaker.Icon:SetPoint("CENTER", 1, -1)
		end
	end)
	speaker:SetScript("OnMouseUp", function()
		speaker.Icon:SetPoint("CENTER", 0, 0)
	end)
	speaker:SetScript("OnClick", function()
		self:PlaySound()
	end)

	self:InitControl(self.Motion, box, speaker)
end

---Plays the setting's sound on the SFX channel; the checkbox's value does not matter.
function AeonUISettings_SoundCheckboxMixin:PlaySound()
	local sound = self.sound
	if not self.enabled or not sound then
		return
	end

	if sound.kit then
		PlaySound(sound.kit, "SFX")
	elseif sound.file then
		PlaySoundFile(sound.file, "SFX")
	end
end

---@param setting { sound: { kit: number?, file: string? }? }
function AeonUISettings_SoundCheckboxMixin:Configure(setting)
	self.sound = setting.sound
end

---Shows a value at once; the checkbox never animates.
---@param value any
---@param _ boolean? instant
function AeonUISettings_SoundCheckboxMixin:SetChecked(value, _)
	self.Motion.Box:SetChecked(value and true or false)
end

---@param enabled boolean
function AeonUISettings_SoundCheckboxMixin:ApplyEnabled(enabled)
	self.Motion.Box:SetEnabled(enabled)
	self.Speaker:SetEnabled(enabled)
	if not enabled then
		self.Speaker.Icon:SetVertexColor(unpack(ICON_GRAY))
	end
end

---Puts the pressed speaker icon back and hides its tooltip.
function AeonUISettings_SoundCheckboxMixin:EndInteraction()
	self.Speaker.Icon:SetPoint("CENTER", 0, 0)
	if not self:ShowsReason() then
		AS.Tooltip:Hide(self.Speaker)
	end
end

AS:RegisterControl("soundCheckbox", { frameType = "Frame", template = "AeonUISettings_SoundCheckboxTemplate" })
