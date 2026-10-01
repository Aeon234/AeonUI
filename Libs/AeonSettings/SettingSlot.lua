-- Setting slot: binds one setting to a control and an optional label, and runs the control's save requests.
-- Frame-free; the owner creates, places and caches the controls.
local _, ns = ...
local AS = ns.AeonSettings

---@class AeonSettingsSettingSlot
---@field label AeonSettingsLabel? linked to the control while the setting has a label
---@field control table? the control last bound; kept after `Release` so a rebind can tell it changed
---@field setting AeonSettingsSetting?
---@field pageID string?
---@field window table?
local Slot = {}
Slot.__index = Slot

---Creates a slot.
---@param label AeonSettingsLabel? the label that describes the control, when the owner has one
---@return AeonSettingsSettingSlot
function AS:CreateSettingSlot(label)
	return setmetatable({ label = label }, Slot)
end

---Binds a setting to a control: releases the previous control when it differs, links the label, configures
---the control, draws the saved value at once, applies the active state, then listens for requests.
---@param setting AeonSettingsSetting
---@param pageID string
---@param window table
---@param control table a control built on `AS.ControlMixin`
function Slot:Bind(setting, pageID, window, control)
	if self.control and self.control ~= control then
		self.control:Release()
	end
	self.setting, self.pageID, self.window, self.control = setting, pageID, window, control

	if self.label then
		self.label:SetControl(setting.label and control or nil)
	end
	control:Configure(setting)
	if setting.get then
		control:SetChecked(AS:CallHost(nil, setting.get), true)
	end
	self:RefreshState()
	control.onRequest = function(value)
		self:Request(value)
	end
end

---Re-applies the setting's active state and reason.
function Slot:RefreshState()
	local setting, control = self.setting, self.control
	if not setting or not control then
		return
	end

	control:SetEnabled(self.window:SettingState(self.pageID, setting))
end

---Saves a value the control asked for. The control then shows the saved value or, when the setting refuses
---or `set` raises an error, the old value and the refusal. Nothing is drawn if the slot was rebound while
---saving. The window is told in every case.
---@param value any
function Slot:Request(value)
	local setting, control, window, pageID = self.setting, self.control, self.window, self.pageID
	if not setting or not control or not window or not pageID then
		return
	end

	local ok, message = AS:CallHost(false, setting.set, value, window)

	if self.setting == setting and self.control == control then
		if setting.get then
			control:SetChecked(AS:CallHost(nil, setting.get))
		end
		if ok == false then
			control:Reject(message or control:DefaultRefusal(setting.label or setting.id))
		end
	end

	window:SettingSaved(pageID, setting, ok, control)
end

---Releases the control and forgets the setting.
function Slot:Release()
	if self.control then
		self.control:Release()
	end
	self.setting, self.pageID, self.window = nil, nil, nil
end
