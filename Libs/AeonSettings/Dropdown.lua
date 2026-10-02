-- Dropdown: one choice from a list on Blizzard's menu, with font, texture and sound picker variants, or several
-- choices at once as checkboxes.
local ADDON_NAME, ns = ...
local AS = ns.AeonSettings
local L = AS.L
local tokens = AS.tokens

local WIDTH = tokens.size.valueControl
local PLAY_SIZE = tokens.size.speaker
local PLAY_GAP = tokens.space.speakerGap
local PLAY_ICON_GRAY = tokens.color.speakerIcon[1]
local SCROLL_AFTER = 20 -- entries shown before the list scrolls
local ENTRY_HEIGHT = 20
local SCROLL_EXTRA = 18 -- Blizzard's scroll bar and its pad widen a scrolling list by this much
local MENU_INSETS = 16
local ENTRY_PADDING = 20
local RADIO_MARK = 20
local SCROLL_SHARE_LOSS = 18
local FIT_MIN = 90 -- narrowest a fitted dropdown gets
local PICKER_FONT_SIZE = 14
local SAMPLE_ALPHA = 0.6
local CONFIRM_POPUP = "AeonUISettings_CONFIRM_CHOICE"
local CONFIRM_FAILED = {}

StaticPopupDialogs[CONFIRM_POPUP] = {
	text = "%s",
	button1 = ACCEPT,
	button2 = CANCEL,
	showAlert = true,
	OnAccept = function(_, data)
		local control = data.control
		if control.enabled and control.confirmToken == data.token then
			control.confirmToken = nil
			control.confirmData = nil
			control:Request(data.value)
		end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

local LSM = LibStub("LibSharedMedia-3.0")

-- One font object per font file, named after the host addon so copies never share globals.
local pickerFonts = {}
local pickerFontCount = 0

---@param file string
---@return Font
local function PickerFont(file)
	local font = pickerFonts[file]
	if not font then
		pickerFontCount = pickerFontCount + 1
		font = CreateFont(ADDON_NAME .. "PickerFont" .. pickerFontCount)
		font:SetFont(file, PICKER_FONT_SIZE, "")
		font:SetTextColor(1, 1, 1)
		pickerFonts[file] = font
	end

	return font
end

---@class AeonSettingsDropdown : Frame, AeonSettingsControlMixin
---@field Motion Frame holds the dropdown button and the play button; the shake moves it
---@field options AeonSettingsChoice[]|fun(): AeonSettingsChoice[]
---@field picker "font" | "texture" | "sound" | nil
---@field multi boolean? several choices at once: the value is a set, `{ [value] = true }`
---@field summary (fun(count: integer): string)? the closed button's text for a multi-select, by how many are chosen
---@field saved any
AeonUISettings_DropdownMixin = CreateFromMixins(AS.ControlMixin)

function AeonUISettings_DropdownMixin:OnLoad()
	local motion = self.Motion
	local dropdown = motion.Dropdown
	self.options = {}

	dropdown:EnableMouseWheel(false)
	dropdown:SetMotionScriptsWhileDisabled(true)
	dropdown:SetupMenu(function(_, root)
		self:BuildMenu(root)
	end)
	dropdown:SetSelectionText(function(selections)
		if self.multi then
			return self:SummaryText()
		end
		if #selections == 0 and self.saved ~= nil then
			return tostring(self.saved)
		end
	end)
	dropdown:RegisterCallback(DropdownButtonMixin.Event.OnMenuOpen, function(_, button)
		self:CenterSelection(button.menu)
	end, self)

	local sample = dropdown.Sample
	sample:SetAlpha(SAMPLE_ALPHA)
	sample:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 6, -4)
	sample:SetPoint("BOTTOMRIGHT", dropdown.Arrow, "BOTTOMLEFT", 0, 9)

	self:InitPlayButton()
	self:InitControl(motion, dropdown)
	self:Layout()
end

function AeonUISettings_DropdownMixin:InitPlayButton()
	local play = self.Motion.Play
	play.Icon:SetVertexColor(PLAY_ICON_GRAY, PLAY_ICON_GRAY, PLAY_ICON_GRAY)
	play:SetMotionScriptsWhileDisabled(true)
	play:SetScript("OnEnter", function()
		if self.enabled then
			play.Icon:SetVertexColor(1, 1, 1)
		end
		AS.Tooltip:Show(play, AS.Tooltip:Lines(nil, L["Play sound"]))
	end)
	play:SetScript("OnLeave", function()
		play.Icon:SetVertexColor(PLAY_ICON_GRAY, PLAY_ICON_GRAY, PLAY_ICON_GRAY)
		AS.Tooltip:Hide(play)
	end)
	play:SetScript("OnMouseDown", function()
		if self.enabled then
			play.Icon:SetPoint("CENTER", 1, -1)
		end
	end)
	play:SetScript("OnMouseUp", function()
		play.Icon:SetPoint("CENTER", 0, 0)
	end)
	play:SetScript("OnClick", function()
		self:PlayChoice()
	end)
end

---The width that fits the longest choice in the menu: its text, the radio mark, the entry padding and the menu's
---insets, which also leaves the closed button room for its arrow.
---@return number
function AeonUISettings_DropdownMixin:FitWidth()
	local measure = self.measure
	if not measure then
		measure = self:CreateFontString(nil, "ARTWORK")
		measure:Hide()
		self.measure = measure
	end
	measure:SetFontObject(self.Motion.Dropdown.Text:GetFontObject())

	local widest = 0
	for _, choice in ipairs(self:Choices()) do
		if not choice.title then
			measure:SetText(choice.text)
			widest = math.max(widest, measure:GetUnboundedStringWidth())
		end
	end

	return math.max(FIT_MIN, math.ceil(widest + MENU_INSETS + ENTRY_PADDING + RADIO_MARK))
end

---Sizes the dropdown: its setting's width, the width that fits its choices (`width = "fit"`) or the full
---value-control width, less the play button and its gap for a sound picker.
function AeonUISettings_DropdownMixin:Layout()
	local sound = self.picker == "sound"
	local width = self.width == "fit" and self:FitWidth() or self.width or WIDTH
	self:SetWidth(width)
	self.Motion:SetWidth(width)
	self.Motion.Play:SetShown(sound)
	self.Motion.Dropdown:SetWidth(sound and width - PLAY_SIZE - PLAY_GAP or width)
end

---Returns the choices from the setting's options and picker (`AS:DropdownChoices`), worked out again on every
---call so a changing options function or newly registered media shows at once.
---@return AeonSettingsChoice[]
function AeonUISettings_DropdownMixin:Choices()
	return AS:DropdownChoices(self.options, self.picker, LSM)
end

---Fills the menu: a radio per choice at the button's width, scrolling past twenty entries.
---@param root table root menu description
function AeonUISettings_DropdownMixin:BuildMenu(root)
	local choices = self:Choices()
	local width = self.Motion.Dropdown:GetWidth()
	local scrolling = #choices > SCROLL_AFTER
	local share = width - MENU_INSETS - ENTRY_PADDING - RADIO_MARK - (scrolling and SCROLL_SHARE_LOSS or 0)

	if scrolling then
		root:SetScrollMode(SCROLL_AFTER * ENTRY_HEIGHT)
		root:SetMinimumWidth(width - SCROLL_EXTRA)
	else
		root:SetMinimumWidth(width)
		root:SetMaximumWidth(width)
	end

	for _, choice in ipairs(choices) do
		if choice.title then
			root:CreateTitle(choice.text)
		else
			self:AddChoice(root, choice, share)
		end
	end
end

---Adds one choice as a radio entry, or as a checkbox in a multi-select, which keeps the menu open.
---@param root table root menu description
---@param choice AeonSettingsChoice
---@param share number widest the entry's text may be
function AeonUISettings_DropdownMixin:AddChoice(root, choice, share)
	local entry
	if self.multi then
		entry = root:CreateCheckbox(choice.text, function(data)
			return type(self.saved) == "table" and self.saved[data.value] == true
		end, function(data)
			self:Toggle(data.value)
		end, choice)
	else
		entry = root:CreateRadio(choice.text, function(data)
			return data.value == self.saved
		end, function(data)
			self:Choose(data.value)
		end, choice)
	end

	entry:AddInitializer(function(button)
		local text = button.fontString
		if choice.font then
			text:SetFontObject(PickerFont(choice.font))
		end
		text:SetTextToFit(choice.text)
		if text:GetWidth() > share then
			text:SetWidth(share)
		end
		if choice.texture then
			local sample = button:AttachTexture()
			sample:SetTexture(choice.texture)
			sample:SetDrawLayer("BACKGROUND")
			sample:SetAlpha(SAMPLE_ALPHA)
			sample:SetPoint("TOPLEFT", 18, -2)
			sample:SetPoint("BOTTOMRIGHT", -2, 2)
		end
	end)

	if choice.blocked then
		entry:SetEnabled(false)
		entry:SetTooltip(function(tooltip)
			local color = tokens.color.error
			tooltip:SetText(choice.blocked, color[1], color[2], color[3], 1, true)
		end)
	elseif choice.tooltip then
		entry:SetTooltip(function(tooltip)
			tooltip:SetText(choice.tooltip, 1, 1, 1, 1, true)
		end)
	end
end

---Asks the owner to save the multi-select's set with one choice added or taken out.
---@param value any
function AeonUISettings_DropdownMixin:Toggle(value)
	local set = {}
	if type(self.saved) == "table" then
		for chosen, on in pairs(self.saved) do
			set[chosen] = on == true or nil
		end
	end
	set[value] = not set[value] or nil

	self:Choose(set)
end

---@return integer count the multi-select's chosen choices
function AeonUISettings_DropdownMixin:ChosenCount()
	local count = 0
	if type(self.saved) == "table" then
		for _, on in pairs(self.saved) do
			if on == true then
				count = count + 1
			end
		end
	end

	return count
end

---@return string text the multi-select's closed button text: the setting's summary, or the count
function AeonUISettings_DropdownMixin:SummaryText()
	local count = self:ChosenCount()
	if self.summary then
		return AS:CallHost(tostring(count), self.summary, count)
	end

	return tostring(count)
end

---Scrolls an open scrolling list so the saved choice sits in the middle; a multi-select stays at its top.
---@param menu table?
function AeonUISettings_DropdownMixin:CenterSelection(menu)
	local scrollBox = menu and menu.ScrollBox
	if self.multi or not scrollBox or not scrollBox:IsShown() or not scrollBox:HasScrollableExtent() then
		return
	end

	local _, index = AS:FindChoice(self:Choices(), self.saved)
	if index then
		scrollBox:ScrollToElementDataIndex(index, ScrollBoxConstants.AlignCenter, 0,
			ScrollBoxConstants.NoScrollInterpolation)
	end
end

---Asks the owner to save a picked choice, first asking the player when the setting's `confirm` gives a question
---for that choice.
---@param value any
function AeonUISettings_DropdownMixin:Choose(value)
	local confirm = self.confirm
	if type(confirm) == "function" then
		local text = AS:CallHost(CONFIRM_FAILED, confirm, value)
		-- A question that raised an error neither asks nor saves.
		if text == CONFIRM_FAILED then
			return
		end
		if text then
			self.confirmToken = {}
			self.confirmData = { control = self, token = self.confirmToken, value = value }
			StaticPopupDialogs[CONFIRM_POPUP].button1 = self.confirmVerb or ACCEPT
			StaticPopup_Show(CONFIRM_POPUP, text, nil, self.confirmData)

			return
		end
	end

	self:Request(value)
end

---Closes this dropdown's open confirmation, if any.
function AeonUISettings_DropdownMixin:CloseConfirmation()
	if self.confirmData then
		StaticPopup_Hide(CONFIRM_POPUP, self.confirmData)
		self.confirmData = nil
	end
	self.confirmToken = nil
end

---A multi-select's set is saved when it chooses the same choices.
---@param value any
---@return boolean
function AeonUISettings_DropdownMixin:IsSaved(value)
	if self.multi and type(value) == "table" and type(self.saved) == "table" then
		for chosen, on in pairs(value) do
			if on == true and self.saved[chosen] ~= true then
				return false
			end
		end
		for chosen, on in pairs(self.saved) do
			if on == true and value[chosen] ~= true then
				return false
			end
		end

		return true
	end

	return value == self.saved
end

---Plays the saved choice's sound on the Master channel.
function AeonUISettings_DropdownMixin:PlayChoice()
	if not self.enabled then
		return
	end

	local choice = AS:FindChoice(self:Choices(), self.saved)
	if not choice then
		return
	end

	if choice.soundKit then
		PlaySound(choice.soundKit, "Master")
	elseif choice.soundFile then
		PlaySoundFile(choice.soundFile, "Master")
	end
end

---Shows the saved choice's texture behind the closed button's text, for a texture picker.
function AeonUISettings_DropdownMixin:UpdateSample()
	local sample = self.Motion.Dropdown.Sample
	local texture
	if self.picker == "texture" then
		local choice = AS:FindChoice(self:Choices(), self.saved)
		texture = choice and choice.texture
		if not texture and type(self.saved) == "string" then
			texture = AS:MediaFile(LSM, LSM.MediaType.STATUSBAR, self.saved)
		end
	end

	sample:SetShown(texture ~= nil)
	if texture then
		sample:SetTexture(texture)
	end
end

---Applies the setting's choices, picker kind and placeholder, the text shown while no choice is saved.
---`confirm(value)`, when set, returns a question to ask before saving that choice (nil: save without asking);
---`verb` names the question's accept button.
---`width` narrows a dropdown that needs less than the value-control width (a header dropdown); "fit" sizes it to
---its longest choice. `multi` lists the choices as checkboxes and saves a set, `{ [value] = true }`, after each
---click; `summary(count)` gives the closed button's text, otherwise the count.
---@param setting { options: AeonSettingsChoice[]|fun(): AeonSettingsChoice[], picker: string?, placeholder: string?, confirm: (fun(value: any): string?)?, verb: string?, width: number|"fit"?, multi: boolean?, summary: (fun(count: integer): string)? }
function AeonUISettings_DropdownMixin:Configure(setting)
	self:CloseConfirmation()
	self.options = setting.options or {}
	self.multi = setting.multi == true
	self.summary = setting.summary
	self.picker = setting.picker
	self.confirm = setting.confirm
	self.confirmVerb = setting.verb
	self.width = setting.width
	self.Motion.Dropdown:SetDefaultText(setting.placeholder or "")
	self:Layout()
end

---Shows the saved choice on the closed button.
---@param value any
---@param _ boolean? instant; the dropdown never animates
function AeonUISettings_DropdownMixin:SetChecked(value, _)
	self.saved = value
	local dropdown = self.Motion.Dropdown
	if dropdown:IsMenuOpen() then
		dropdown:SignalUpdate()
	else
		dropdown:GenerateMenu()
	end
	self:UpdateSample()
end

---The closed button's full choice name when it is cut off.
---@return string?
function AeonUISettings_DropdownMixin:TooltipFullText()
	local text = self.Motion.Dropdown.Text
	if text:IsTruncated() then
		return text:GetText()
	end
end

---@param enabled boolean
function AeonUISettings_DropdownMixin:ApplyEnabled(enabled)
	self.Motion.Dropdown:SetEnabled(enabled)
	self.Motion.Play:SetEnabled(enabled)
end

---Closes the open list, an open confirmation and the play button's tooltip.
function AeonUISettings_DropdownMixin:EndInteraction()
	self:CloseConfirmation()
	local dropdown = self.Motion.Dropdown
	if dropdown:IsMenuOpen() then
		dropdown:CloseMenu()
	end
	AS.Tooltip:Hide(self.Motion.Play)
end

AS:RegisterControl("dropdown", { frameType = "Frame", template = "AeonUISettings_DropdownTemplate" })
