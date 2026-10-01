-- Text input: one line of typed text, saved on Enter or when focus leaves, restored on Escape.
local _, ns = ...
local AS = ns.AeonSettings
local L = AS.L

---@class AeonSettingsTextInput : Frame, AeonSettingsControlMixin
---@field saved string
---@field name string setting name used in refusal messages
---@field allowEmpty boolean
---@field maxLetters integer?
---@field validate (fun(text: string): string?)?
---@field closing boolean? focus is being cleared by Enter, Escape or code; the focus-lost save is skipped
---@field settingID string? the bound setting's id, which keys its remembered cursor position
AeonUISettings_TextInputMixin = CreateFromMixins(AS.ControlMixin)

-- Cursor position each setting's box had when it last lost focus, keyed by setting id.
local cursors = {}

---Returns where the cursor was when the setting's text box last lost focus, as the edit box reports it, or
---nil when the box has not had focus since the library loaded.
---@param settingID string
---@return integer?
function AS:TextCursor(settingID)
	return cursors[settingID]
end

---Moves the remembered cursor position, for a host that changed the setting's text itself (an insertion).
---@param settingID string
---@param position integer?
function AS:SetTextCursor(settingID, position)
	cursors[settingID] = position
end

function AeonUISettings_TextInputMixin:OnLoad()
	local box = self.Motion.Box
	self.saved = ""
	self.name = ""
	self.allowEmpty = false

	local left, right = box:GetTextInsets()
	box.Instructions:ClearAllPoints()
	box.Instructions:SetPoint("TOPLEFT", box, "TOPLEFT", left, 0)
	box.Instructions:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -right, 0)

	box:SetScript("OnEnterPressed", function()
		self:ClearFocusQuietly()
		self:Submit()
	end)
	box:SetScript("OnEscapePressed", function()
		self:DropEdit()
	end)
	box:HookScript("OnEditFocusLost", function()
		if self.settingID then
			cursors[self.settingID] = box:GetCursorPosition()
		end
		if not self.closing then
			self:Submit()
		end
	end)

	self:InitControl(self.Motion, box)
end

---Clears focus without the focus-lost save.
function AeonUISettings_TextInputMixin:ClearFocusQuietly()
	local box = self.Motion.Box
	if box:HasFocus() then
		self.closing = true
		box:ClearFocus()
		self.closing = false
	end
end

---Drops an edit in progress: focus goes and the saved text comes back.
function AeonUISettings_TextInputMixin:DropEdit()
	self:ClearFocusQuietly()
	self:ShowSaved()
end

function AeonUISettings_TextInputMixin:ShowSaved()
	local box = self.Motion.Box
	box:SetText(self.saved)
	box:SetCursorPosition(0)
end

local VALIDATE_FAILED = {}

---Applies the typed text: trimmed, checked against the setting's rules, then requested unless unchanged. A
---`validate` that raises an error refuses the text.
function AeonUISettings_TextInputMixin:Submit()
	local text = strtrim(self.Motion.Box:GetText())
	if self:IsSaved(text) then
		self:ShowSaved()

		return
	end

	local reason
	if text == "" and not self.allowEmpty then
		reason = L["it can't be empty."]
	elseif self.maxLetters and strlenutf8(text) > self.maxLetters then
		reason = L["It can be %d letters at most."]:format(self.maxLetters)
	elseif self.validate and text ~= "" then
		reason = AS:CallHost(VALIDATE_FAILED, self.validate, text)
	end

	if reason == VALIDATE_FAILED then
		self:ShowSaved()
		self:Reject(L["Couldn't save %s."]:format(self.name))

		return
	elseif reason then
		self:ShowSaved()
		self:Reject(L["Couldn't save %s: %s"]:format(self.name, reason))

		return
	end

	self:Request(text)
end

---@param value string
---@return boolean
function AeonUISettings_TextInputMixin:IsSaved(value)
	return value == self.saved
end

---@param setting { label: string?, id: string?, default: string?, allowEmpty: boolean?, maxLetters: integer?, validate: (fun(text: string): string?)? }
function AeonUISettings_TextInputMixin:Configure(setting)
	self:DropEdit()
	self.settingID = setting.id
	self.name = setting.label or setting.id or ""
	self.allowEmpty = setting.allowEmpty == true
	self.maxLetters = setting.maxLetters
	self.validate = setting.validate
	self.Motion.Box:SetMaxLetters(setting.maxLetters or 0)
	self.Motion.Box.Instructions:SetText(setting.default or "")
end

---Shows the saved text, unless the box is being typed in.
---@param value string?
---@param _ boolean? instant; the text input never animates
function AeonUISettings_TextInputMixin:SetChecked(value, _)
	self.saved = value or ""
	if not self.Motion.Box:HasFocus() then
		self:ShowSaved()
	end
end

---@param enabled boolean
function AeonUISettings_TextInputMixin:ApplyEnabled(enabled)
	self.Motion.Box:SetEnabled(enabled)
end

function AeonUISettings_TextInputMixin:EndInteraction()
	self:DropEdit()
end

AS:RegisterControl("text", { frameType = "Frame", template = "AeonUISettings_TextInputTemplate" })
