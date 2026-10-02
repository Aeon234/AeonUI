-- Action button: runs something once, asking first when the action destroys or cannot be undone.
local _, ns = ...
local AS = ns.AeonSettings
local L = AS.L

local MIN_WIDTH = 120
local MAX_WIDTH = AS.tokens.size.valueControl
local TEXT_PADDING = 40
local ROW_HEIGHT = 26
local CONFIRM_POPUP = "AeonUISettings_CONFIRM_ACTION"
local CONFIRM_FAILED = {}

StaticPopupDialogs[CONFIRM_POPUP] = {
	text = "%s",
	button1 = OKAY,
	button2 = CANCEL,
	showAlert = true,
	OnAccept = function(_, data)
		local control = data.control
		if control.enabled and control.confirmToken == data.token then
			control:Run()
		end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

---@class AeonSettingsActionButton : Frame, AeonSettingsControlMixin
---@field Button Button
---@field verb string
---@field confirm (string|fun(): string?)? confirmation text, or a function returning it at the click (nil: no
---confirmation this time); the action asks first when there is text
---@field confirmToken table? identifies the confirmation this button opened
---@field confirmData table? the open confirmation's popup data
AeonUISettings_ActionButtonMixin = CreateFromMixins(AS.ControlMixin)

function AeonUISettings_ActionButtonMixin:OnLoad()
	local button = self.Button
	self.verb = ""
	button:SetMotionScriptsWhileDisabled(true)
	button:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		self:Activate()
	end)
	self:InitControl(button, button)
end

---Runs the action, or asks first when it has a confirmation.
function AeonUISettings_ActionButtonMixin:Activate()
	if not self.enabled then
		return
	end

	local text = self.confirm
	if type(text) == "function" then
		text = AS:CallHost(CONFIRM_FAILED, text)
		-- A confirmation that raised an error neither asks nor runs.
		if text == CONFIRM_FAILED then
			return
		end
	end
	if not text then
		self:Run()

		return
	end

	self.confirmToken = {}
	self.confirmData = { control = self, token = self.confirmToken }
	StaticPopupDialogs[CONFIRM_POPUP].button1 = self.verb
	StaticPopup_Show(CONFIRM_POPUP, text, nil, self.confirmData)
end

---Closes this button's confirmation if it is open.
function AeonUISettings_ActionButtonMixin:CloseConfirmation()
	if self.confirmData then
		StaticPopup_Hide(CONFIRM_POPUP, self.confirmData)
		self.confirmData = nil
	end
	self.confirmToken = nil
end

function AeonUISettings_ActionButtonMixin:Run()
	self.confirmToken = nil
	self.confirmData = nil
	self:Request(true)
end

---Fits a shared button's width to its current text: the text width plus padding, kept between the minimum
---and maximum widths.
---@param button Button
---@return number width
function AS:FitButtonWidth(button)
	local width = Clamp(button:GetTextWidth() + TEXT_PADDING, MIN_WIDTH, MAX_WIDTH)
	button:SetWidth(width)

	return width
end

---Applies the verb, confirmation text and height, and fits the width to the text.
---@param setting { verb: string, confirm: (string|fun(): string?)?, height: number? }
function AeonUISettings_ActionButtonMixin:Configure(setting)
	local button = self.Button
	self.verb = setting.verb or ""
	self.confirm = setting.confirm
	self.confirmToken = nil

	button:SetText(self.verb)
	self:SetWidth(AS:FitButtonWidth(button))
	self:SetButtonHeight(setting.height or ROW_HEIGHT)
end

---Sets the button's height; the control frame matches it.
---@param height number
function AeonUISettings_ActionButtonMixin:SetButtonHeight(height)
	self.Button:SetHeight(height)
	self:SetHeight(height)
end

---An action holds no value.
function AeonUISettings_ActionButtonMixin:SetChecked() end

---@param enabled boolean
function AeonUISettings_ActionButtonMixin:ApplyEnabled(enabled)
	self.Button:SetEnabled(enabled)
end

---Closes this button's open confirmation; runs when the action goes inactive, is released or is hidden.
function AeonUISettings_ActionButtonMixin:EndInteraction()
	self:CloseConfirmation()
end

---Refusal wording when the owner gives none: "Couldn't <verb>."
---@param _ string
---@return string
function AeonUISettings_ActionButtonMixin:DefaultRefusal(_)
	return L["Couldn't %s."]:format(self.verb:lower())
end

AS:RegisterControl("action", { frameType = "Frame", template = "AeonUISettings_ActionButtonTemplate" })
