-- Profile dialog: naming, export, import and replacement dialogs for the Profiles page, one at a time.
local _, ns = ...
local AS = ns.AeonSettings
local L = AS.L
local tokens = AS.tokens

local DIALOG_NAME = "AeonUISettings_ProfileDialog"
local SMALL_WIDTH = 356 -- name and replace dialogs
local LARGE_WIDTH = 520 -- export and import dialogs
local INSET_X = 18
local INSET_TOP = 34
local INSET_BOTTOM = 16
local MESSAGE_GAP = 10
local WELL_HEIGHT = 180
local WELL_GAP = 6
local SUMMARY_STEP = 20
local NAME_INDENT = 6 -- the input box draws its border outside its frame
local NAME_STEP = 26
local ERROR_STEP = 18
local CHOICE_STEP = 34
local BUTTON_HEIGHT = 26
local BUTTON_GAP = 8
local SMALL_TEXT_SIZE = 12
local OFFSET_Y = 80 -- first shown this far above the screen's center

---@class AeonSettingsProfileDialogOptions
---@field title string
---@field verb string? the action button's text
---@field message string?
---@field text string? export: the string shown; name: the box's starting text
---@field hint string? the name box's placeholder
---@field validate (fun(name: string): string?)? returns a problem, "" to refuse without a message, or nil
---@field decode (fun(text: string): table?, string?)? import: returns { name, summary } or nil and a reason
---@field choices { value: any, text: string }[]? replace: the profiles to choose from
---@field default any? replace: the choice selected at first
---@field accept fun(value: any, name: string?) name: the name; import: the decoded info and the name; replace: the choice

---@class AeonSettingsProfileDialog : Frame
---@field kind "name"|"export"|"import"|"replace"|nil
---@field options AeonSettingsProfileDialogOptions?
---@field decoded table? the import text's decoded info while it is valid
---@field choice any? the replacement chosen
AeonUISettings_ProfileDialogMixin = {}

function AeonUISettings_ProfileDialogMixin:OnLoad()
	local body = self.Body
	self:RegisterForDrag("LeftButton")
	self:SetScript("OnDragStart", self.StartMoving)
	self:SetScript("OnDragStop", self.StopMovingOrSizing)

	AS:SetFont(body.Message, "body")
	AS:SetFont(body.Summary, "body", SMALL_TEXT_SIZE)
	AS:SetFont(body.Error, "body", SMALL_TEXT_SIZE)
	body.Message:SetTextColor(unpack(tokens.color.text))
	body.Error:SetTextColor(unpack(tokens.color.error))

	local name = body.Name
	-- The placeholder starts where typed text does.
	local left, right = name:GetTextInsets()
	name.Instructions:ClearAllPoints()
	name.Instructions:SetPoint("TOPLEFT", name, "TOPLEFT", left, 0)
	name.Instructions:SetPoint("BOTTOMRIGHT", name, "BOTTOMRIGHT", -right, 0)
	name:SetScript("OnTextChanged", function(box)
		InputBoxInstructions_OnTextChanged(box)
		self:Validate()
	end)
	name:SetScript("OnEnterPressed", function()
		if body.Accept:IsEnabled() then
			body.Accept:Click()
		end
	end)

	local scroll = body.Well.Scroll
	ScrollUtil.RegisterScrollBoxWithScrollBar(scroll:GetScrollBox(), body.Well.ScrollBar)
	scroll:RegisterCallback("OnTextChanged", function(_, editBox, userChanged)
		self:OnLargeTextChanged(editBox, userChanged)
	end, self)

	body.Choice:SetupMenu(function(_, root)
		local choices = self.options and self.options.choices or {}
		for _, choice in ipairs(choices) do
			root:CreateRadio(choice.text, function(value)
				return self.choice == value
			end, function(value)
				self.choice = value
				self:Validate()
			end, choice.value)
		end
	end)

	body.Accept:SetMotionScriptsWhileDisabled(true)
	body.Accept:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		self:Accept()
	end)
	body.Cancel:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		self:Close()
	end)
end

---Returns the dialog, creating it on first use. It closes with Escape.
---@return AeonSettingsProfileDialog
function AS:ProfileDialogFrame()
	if not self.ProfileDialog then
		self.ProfileDialog = CreateFrame("Frame", DIALOG_NAME, UIParent, "AeonUISettings_ProfileDialogTemplate")
		tinsert(UISpecialFrames, DIALOG_NAME)
	end

	return self.ProfileDialog
end

---Hides every field; `Open` shows and places those its kind uses.
function AeonUISettings_ProfileDialogMixin:ResetFields()
	local body = self.Body
	for _, region in ipairs({ body.Message, body.Well, body.Summary, body.Name, body.Error, body.Choice }) do
		region:ClearAllPoints()
		region:Hide()
	end

	body.Name:ClearFocus()
	body.Name:SetText("")
	body.Name.Instructions:SetText("")
	body.Error:SetText("")
	body.Summary:SetText("")
	body.Well.Scroll:ClearFocus()
	body.Well.Scroll:ClearText()
	self.decoded = nil
	self.choice = nil
end

---Places a field full width at `y` below the body's top and shows it.
---@param region Region
---@param y number
---@param indent number?
local function Place(region, y, indent)
	region:SetPoint("TOPLEFT", indent or 0, y)
	region:SetPoint("TOPRIGHT", 0, y)
	region:Show()
end

---Opens a dialog of `kind`, replacing any open one.
---@param kind "name"|"export"|"import"|"replace"
---@param options AeonSettingsProfileDialogOptions
function AeonUISettings_ProfileDialogMixin:Open(kind, options)
	self:Close()
	self.kind, self.options = kind, options
	self:ResetFields()

	local body = self.Body
	local large = kind == "export" or kind == "import"
	local width = large and LARGE_WIDTH or SMALL_WIDTH
	local contentWidth = width - INSET_X * 2
	local y = 0
	-- The width comes first: the message wraps to it before its height is measured.
	self:SetWidth(width)

	self.NineSlice.Text:SetText(options.title)
	body.Accept:SetText(options.verb or ACCEPT)
	body.Accept:SetShown(kind ~= "export")
	body.Cancel:SetText(kind == "export" and CLOSE or CANCEL)

	local message = kind == "export" and L["Press Ctrl+C to copy the text below."] or options.message
	if message then
		body.Message:SetWidth(contentWidth)
		body.Message:SetText(message)
		Place(body.Message, y)
		y = y - body.Message:GetStringHeight() - MESSAGE_GAP
	end

	if large then
		Place(body.Well, y)
		y = y - WELL_HEIGHT - WELL_GAP
		if kind == "export" then
			body.Well.Scroll:SetText(options.text or "")
		else
			Place(body.Summary, y)
			y = y - SUMMARY_STEP
		end
	end

	if kind == "name" or kind == "import" then
		Place(body.Name, y, NAME_INDENT)
		body.Name.Instructions:SetText(options.hint or "")
		body.Name:SetText(options.text or "")
		body.Name:SetShown(kind == "name")
		y = y - NAME_STEP
		Place(body.Error, y)
		y = y - ERROR_STEP
	end

	if kind == "replace" then
		self.choice = options.default
		body.Choice:SetPoint("TOPLEFT", 0, y)
		body.Choice:Show()
		body.Choice:GenerateMenu()
		y = y - CHOICE_STEP
	end

	self:SetSize(width, INSET_TOP - y + BUTTON_GAP + BUTTON_HEIGHT + INSET_BOTTOM)
	self:ClearAllPoints()
	self:SetPoint("CENTER", UIParent, "CENTER", 0, OFFSET_Y)
	self:Show()
	self:Validate(true)

	if kind == "name" then
		body.Name:SetFocus()
		body.Name:HighlightText()
	elseif kind == "export" then
		body.Well.Scroll:SetFocus()
		body.Well.Scroll:GetEditBox():HighlightText()
	elseif kind == "import" then
		body.Well.Scroll:SetFocus()
	end
end

---Keeps export text read-only and checks import text as it changes.
---@param editBox EditBox
---@param userChanged boolean
function AeonUISettings_ProfileDialogMixin:OnLargeTextChanged(editBox, userChanged)
	if not userChanged then
		return
	end

	if self.kind == "export" then
		self.Body.Well.Scroll:SetText(self.options.text or "")
		editBox:HighlightText()
	elseif self.kind == "import" then
		self:Validate(true)
	end
end

---Updates the import summary, the error line and whether the action button is active. `decode` decodes the
---import text again; a name change reuses the last result.
---@param decode boolean?
function AeonUISettings_ProfileDialogMixin:Validate(decode)
	local kind, options = self.kind, self.options
	if not kind or not options then
		return
	end

	local body = self.Body
	local ok = true

	if kind == "import" and decode then
		local text = strtrim(body.Well.Scroll:GetInputText() or "")
		local info, reason
		if text ~= "" and options.decode then
			info, reason = AS:CallHost(nil, options.decode, text)
		end
		self.decoded = info

		if info then
			body.Summary:SetTextColor(unpack(tokens.color.text))
			body.Summary:SetText(info.summary or "")
			body.Name.Instructions:SetText(info.name or "")
		else
			body.Summary:SetTextColor(unpack(tokens.color.error))
			body.Summary:SetText(reason or "")
		end
		body.Name:SetShown(info ~= nil)
	end
	if kind == "import" then
		ok = self.decoded ~= nil
	end

	if kind == "name" or (kind == "import" and self.decoded) then
		local name = strtrim(body.Name:GetText() or "")
		local problem = name ~= "" and options.validate and AS:CallHost("", options.validate, name) or nil
		body.Error:SetText(problem or "")
		ok = ok and name ~= "" and problem == nil
	else
		body.Error:SetText("")
	end

	if kind == "replace" then
		ok = self.choice ~= nil
	end

	body.Accept:SetEnabled(ok)
end

function AeonUISettings_ProfileDialogMixin:Accept()
	local kind, options = self.kind, self.options
	if not kind or not options or not self.Body.Accept:IsEnabled() then
		return
	end

	local name = strtrim(self.Body.Name:GetText() or "")
	if kind == "name" then
		AS:CallHost(nil, options.accept, name)
	elseif kind == "import" then
		AS:CallHost(nil, options.accept, self.decoded, name)
	elseif kind == "replace" then
		AS:CallHost(nil, options.accept, self.choice)
	end
	self:Close()
end

---Closes the dialog without acting.
function AeonUISettings_ProfileDialogMixin:Close()
	self:Hide()
end

function AeonUISettings_ProfileDialogMixin:OnHide()
	self:StopMovingOrSizing()
	self.Body.Name:ClearFocus()
	self.Body.Well.Scroll:ClearFocus()
	self.kind, self.options, self.decoded, self.choice = nil, nil, nil, nil
end
