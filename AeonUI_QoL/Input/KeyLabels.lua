local AUI = select(2, ...)

local Options = AUI.InputOptions

-- Forever's totem bar buttons (`MultiCastActionBarFrame.xml`); at most this many exist.
local TOTEM_BUTTONS = 12

---@class AUIKeyLabelButton : Button
---@field HotKey FontString

---Short key labels on Blizzard's action buttons: the main bars, the pet bar and Forever's totem bar. Each button's own
---hotkey update is post-hooked the first time the feature is turned on, so nothing is hooked while it was never on.
---A bound keyboard or mouse key's label is rewritten from the binding key, and the label takes the chosen font, size
---and outline. Unbound buttons keep Blizzard's range dot, which its range check reads back, and gamepad keys keep
---Blizzard's icons. Turning it off gives each label Blizzard's text and font object back.
---@class AUIKeyLabels
---@field enabled boolean labels are being rewritten
---@field hooked boolean the buttons' hotkey updates are hooked
---@field buttons AUIKeyLabelButton[] the hooked buttons
---@field blizzard table<AUIKeyLabelButton, string> each rewritten button's text as Blizzard set it
---@field labels table<AUIKeyLabelButton, string> the label AeonUI set on each button
---@field fonts table<AUIKeyLabelButton, Font> each styled button's font object before AeonUI changed its font
local KeyLabels = {
	enabled = false,
	hooked = false,
	buttons = {},
	blizzard = {},
	labels = {},
	fonts = {},
}
AUI.KeyLabels = KeyLabels

---@param button AUIKeyLabelButton
---@return string? key the binding key the button's label shows
local function BindingKey(button)
	if button.SetHotkeys then
		return GetBindingKey("BONUSACTIONBUTTON" .. button:GetID())
	end

	return button.bindingAction and GetBindingKey(button.bindingAction)
		or GetBindingKey("CLICK " .. button:GetName() .. ":LeftButton")
end

---Replaces the label Blizzard just set with the short one, while the feature is on.
---@param button AUIKeyLabelButton
local function Rewrite(button)
	if not KeyLabels.enabled then
		return
	end

	local hotkey = button.HotKey
	local text = hotkey:GetText()

	if text == nil or text == "" or text == RANGE_INDICATOR or text == KeyLabels.labels[button] then
		return
	end

	local key = BindingKey(button)

	if not key or IsBindingForGamePad(key) then
		return
	end

	local label = Options.KeyLabel(key)

	KeyLabels.blizzard[button] = text
	KeyLabels.labels[button] = label
	hotkey:SetText(label)
end

---@return AUIKeyLabelButton[] buttons every Blizzard button whose key label this feature rewrites
---@return string[] methods each button's hotkey update method
local function Targets()
	---@type AUIKeyLabelButton[], string[]
	local buttons, methods = {}, {}

	local function Add(button, method)
		if button and button.HotKey and type(button[method]) == "function" then
			buttons[#buttons + 1] = button
			methods[#methods + 1] = method
		end
	end

	for _, prefix in ipairs(ActionButtonUtil.ActionBarButtonNames) do
		for index = 1, NUM_ACTIONBAR_BUTTONS or 12 do
			Add(_G[prefix .. index], "UpdateHotkeys")
		end
	end

	for index = 1, NUM_PET_ACTION_SLOTS or 10 do
		Add(_G["PetActionButton" .. index], "SetHotkeys")
	end

	for index = 1, TOTEM_BUTTONS do
		Add(_G["MultiCastActionButton" .. index], "UpdateHotkeys")
	end

	return buttons, methods
end

function KeyLabels:Hook()
	self.hooked = true

	local buttons, methods = Targets()

	for index, button in ipairs(buttons) do
		hooksecurefunc(button, methods[index], Rewrite)
	end

	self.buttons = buttons
end

---@param button AUIKeyLabelButton
function KeyLabels:Style(button)
	local Profile, Media = AUI.Profile, AUI.Media
	local hotkey = button.HotKey

	if not self.fonts[button] then
		self.fonts[button] = hotkey:GetFontObject()
	end

	hotkey:SetFont(Media:Font(Profile:Get(Options.KEY_FONT_PATH)), Profile:Get(Options.KEY_SIZE_PATH),
		Media:FontFlags(Profile:Get(Options.KEY_OUTLINE_PATH)))
end

---@param button AUIKeyLabelButton
function KeyLabels:Restore(button)
	local hotkey = button.HotKey

	if self.labels[button] and hotkey:GetText() == self.labels[button] then
		hotkey:SetText(self.blizzard[button])
	end

	if self.fonts[button] then
		hotkey:SetFontObject(self.fonts[button])
	end

	self.blizzard[button], self.labels[button], self.fonts[button] = nil, nil, nil
end

---Brings every button in line with the settings.
function KeyLabels:Apply()
	local enabled = AUI.can.keyLabels and Options:Get(Options.KEY_LABELS_PATH) == true

	if not enabled and not self.enabled then
		return
	end

	if enabled and not self.hooked then
		self:Hook()
	end

	self.enabled = enabled

	for _, button in ipairs(self.buttons) do
		if enabled then
			self:Style(button)
			Rewrite(button)
		else
			self:Restore(button)
		end
	end
end
