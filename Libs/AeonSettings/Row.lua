-- Setting row: one or two settings, each a label on the left and its control on the right.
local _, ns = ...
local AS = ns.AeonSettings
local tokens = AS.tokens

local SURFACE_INSET = 2 -- bands stay inside the surface's bronze border

---@class AeonSettingsControlDefinition
---@field frameType string frame type of the template
---@field template string virtual template that builds the control

---A control created from a definition mixes in `AS.ControlMixin` and implements:
---  `Configure(setting)`: applies the setting's control-specific fields.
---  `SetChecked(value, instant)`: shows a value; animates from the current state unless `instant`.
---The mixin supplies the rest of what a row uses, driven by the control's hooks (`Control.lua`):
---  `SetEnabled(enabled, reason)`: restyles, and ends an interaction in progress when going inactive; never
---    stops or snaps a running animation.
---  `Reject(message)`: signals a refused save and shows `message`.
---  `Release()`: ends any interaction and animation and clears `onRequest`; leaves `enabled` and `reason`.
---User input reaches the row as `onRequest(value)` through the mixin's `Request`, which asks nothing for an
---unchanged value. The mixin keeps `enabled` and `reason` current and refreshes the `label` when there is one.
---@type table<string, AeonSettingsControlDefinition>
AS.controls = AS.controls or {}

---Registers a control kind that settings name in their `control` field.
---@param kind string
---@param definition AeonSettingsControlDefinition
function AS:RegisterControl(kind, definition)
	self.controls[kind] = definition
end

---A setting shown in a row. The page owns its value.
---@class AeonSettingsSetting
---@field id string unique on its page
---@field control string registered control kind
---@field label string?
---@field description string?
---@field get (fun(): any)? the saved value; absent on an action
---@field set fun(value: any, window: table): boolean?, string? saves the value, or runs an action; returns false and a
---full sentence ("Couldn't save X: reason.") to refuse. `window` offers `ShowStatus` for an action's result.
---@field depends string? id of a setting that must be on for this one to be active
---@field pageSwitch boolean? the page's enable toggle; every other setting on the page depends on it
---@field blocked (fun(): string?)? returns a reason while the setting is temporarily unavailable
---@field reload boolean? changing it takes effect after a reload
---@field rebuild boolean? saving it may change other settings, so the page is rebuilt after a save
---@field searchText string? extra text matched by search

-- Half -----------------------------------------------------------------------------------------------------

---One setting's half of a row: its label, outline and one control frame per control kind, created on first use.
---Its slot binds the setting to the control shown.
---@class AeonSettingsRowHalf
---@field frame Frame
---@field label AeonSettingsLabel
---@field outline Frame
---@field controls table<string, table>
---@field slot AeonSettingsSettingSlot
local Half = {}
Half.__index = Half

---@param frame Frame
---@return AeonSettingsRowHalf
local function CreateHalf(frame)
	local half = setmetatable({ frame = frame, controls = {} }, Half)
	half.label = AS:CreateLabel(frame)
	half.outline = AS:CreateOutline(frame, tokens.color.flash)
	half.outline:SetAllPoints()
	half.slot = AS:CreateSettingSlot(half.label)

	return half
end

---@param kind string
---@return table
function Half:Control(kind)
	local control = self.controls[kind]
	if not control then
		local definition = AS.controls[kind]
		assert(definition, ("AeonSettings: unknown control kind %q"):format(tostring(kind)))
		control = CreateFrame(definition.frameType, nil, self.frame, definition.template)
		control:SetPoint("RIGHT", self.frame, "RIGHT", -tokens.space.rowInset, 0)
		self.controls[kind] = control
	end

	return control
end

---Shows the control for the setting's kind, lays out the label, and binds the setting through the slot.
---@param setting AeonSettingsSetting
---@param pageID string
---@param window table
function Half:Bind(setting, pageID, window)
	local control = self:Control(setting.control)
	for kind, other in pairs(self.controls) do
		other:SetShown(kind == setting.control)
	end

	local label = self.label
	label:SetText(setting.label)
	label:SetDescription(setting.description)
	label:SetShown(setting.label ~= nil)

	local text = label.text
	text:ClearAllPoints()
	text:SetJustifyH("LEFT")
	text:SetPoint("LEFT", self.frame, "LEFT", tokens.space.rowInset, 0)
	text:SetPoint("RIGHT", control, "LEFT", -tokens.space.labelToControl, 0)

	self.slot:Bind(setting, pageID, window, control)
end

function Half:Release()
	AS.Tooltip:Hide(self.label.hover)
	AS:HideOutline(self.outline)
	self.slot:Release()
end

-- Row ------------------------------------------------------------------------------------------------------

AeonUISettings_SettingRowMixin = {}

function AeonUISettings_SettingRowMixin:OnLoad()
	self.surface = AS:CreateSurface(self)
	self.halves = { CreateHalf(self.First), CreateHalf(self.Second) }
	self.Band:SetColorTexture(0, 0, 0, 1)
	local accent = tokens.color.accent
	self.Divider:SetColorTexture(accent[1], accent[2], accent[3], tokens.alpha.divider)
end

---@param entry AeonSettingsEntry
---@param window table
function AeonUISettings_SettingRowMixin:Init(entry, window)
	local settings = AeonUISettings_SettingRowMixin.Settings(entry.data)
	local split = #settings > 1

	self.surface:SetShape(entry.onSurface and (entry.last and "LAST_ROW" or "ROW") or "NONE")

	local inset = entry.onSurface and SURFACE_INSET or 0
	local even = (entry.position or 1) % 2 == 0
	self.Band:ClearAllPoints()
	self.Band:SetPoint("TOPLEFT", inset, 0)
	self.Band:SetPoint("BOTTOMRIGHT", -inset, entry.last and inset or 0)
	self.Band:SetAlpha(even and tokens.alpha.bandEven or tokens.alpha.bandOdd)

	self.Divider:SetShown(split)
	self.First:ClearAllPoints()
	self.First:SetPoint("TOPLEFT")
	self.First:SetPoint("BOTTOMRIGHT", self, split and "BOTTOM" or "BOTTOMRIGHT")
	self.Second:ClearAllPoints()
	self.Second:SetPoint("TOPLEFT", self, "TOP")
	self.Second:SetPoint("BOTTOMRIGHT")
	self.Second:SetShown(split)

	self.halves[1]:Bind(settings[1], entry.pageID, window)
	if split then
		self.halves[2]:Bind(settings[2], entry.pageID, window)
	else
		self.halves[2]:Release()
	end
end

function AeonUISettings_SettingRowMixin:RefreshState()
	for _, half in ipairs(self.halves) do
		half.slot:RefreshState()
	end
end

---Flashes the outline of the half that shows a setting, or of every half showing one when `settingID` is nil.
---@param settingID string?
function AeonUISettings_SettingRowMixin:FlashSetting(settingID)
	for _, half in ipairs(self.halves) do
		local setting = half.slot.setting
		if setting and (settingID == nil or setting.id == settingID) then
			AS:FlashOutline(half.outline)
		end
	end
end

function AeonUISettings_SettingRowMixin:Release()
	for _, half in ipairs(self.halves) do
		half:Release()
	end
end

---Returns an element's settings: `{ setting = s }` or `{ settings = { a, b } }`.
---@param data table
---@return AeonSettingsSetting[]
function AeonUISettings_SettingRowMixin.Settings(data)
	local settings = data.settings or { data.setting }
	assert(#settings >= 1 and #settings <= 2, "AeonSettings: a setting row holds one or two settings")

	return settings
end

AS:RegisterElementKind("setting", {
	template = "AeonUISettings_SettingRowTemplate",
	Init = function(frame, entry, window)
		frame:Init(entry, window)
	end,
	Reset = function(frame)
		frame:Release()
	end,
	Settings = AeonUISettings_SettingRowMixin.Settings,
	Refresh = function(frame)
		frame:RefreshState()
	end,
	Flash = function(frame, settingID)
		frame:FlashSetting(settingID)
	end,
	Search = function(data)
		local parts = {}
		for _, setting in ipairs(AeonUISettings_SettingRowMixin.Settings(data)) do
			parts[#parts + 1] = setting.label
			parts[#parts + 1] = setting.searchText
		end

		return table.concat(parts, " ")
	end,
})
