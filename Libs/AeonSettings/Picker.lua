-- Picker row: a label and one button per option. The rows after it that name an option show only while that
-- option is picked.
local _, ns = ...
local AS = ns.AeonSettings
local tokens = AS.tokens

local SURFACE_INSET = 2 -- the band stays inside the surface's bronze border
local BUTTON_HEIGHT = 26
local BUTTON_GAP = 4
local BUTTON_PADDING = 30 -- BigRedThreeSliceButtonTemplate's fit-to-text padding
local BUTTON_MIN_WIDTH = 80

---A picker element: `{ kind = "picker", id, label, options = { { id, title } } }`. Each following element with
---`pick = optionID` belongs to it, until the next picker or the next section that is not collapsible, so a
---"Details" group after it is picked with it (`AeonSettingsPageModel:Snapshot`).
AeonUISettings_PickerRowMixin = {}

function AeonUISettings_PickerRowMixin:OnLoad()
	self.surface = AS:CreateSurface(self)
	self.Band:SetColorTexture(0, 0, 0, 1)
	AS:SetFont(self.Label, "body")
	self.Label:SetTextColor(unpack(tokens.color.text))
	self.buttons = {}
end

---@param entry AeonSettingsEntry `entry.picked` is the picked option's id
---@param window table
function AeonUISettings_PickerRowMixin:Init(entry, window)
	local data = entry.data
	self.entry = entry
	self.window = window

	self.surface:SetShape(entry.onSurface and (entry.last and "LAST_ROW" or "ROW") or "NONE")
	local inset = entry.onSurface and SURFACE_INSET or 0
	local even = (entry.position or 1) % 2 == 0
	self.Band:ClearAllPoints()
	self.Band:SetPoint("TOPLEFT", inset, 0)
	self.Band:SetPoint("BOTTOMRIGHT", -inset, entry.last and inset or 0)
	self.Band:SetAlpha(even and tokens.alpha.bandEven or tokens.alpha.bandOdd)

	-- Buttons right to left from the row's right inset, in option order on screen.
	local options = data.options
	local right
	for index = #options, 1, -1 do
		local button = self:Button(index)
		local option = options[index]
		button.optionID = option.id
		button:SetText(option.title)
		button:SetSize(math.max(BUTTON_MIN_WIDTH, button:GetTextWidth() + BUTTON_PADDING), BUTTON_HEIGHT)
		button:ClearAllPoints()
		if right then
			button:SetPoint("RIGHT", right, "LEFT", -BUTTON_GAP, 0)
		else
			button:SetPoint("RIGHT", self, "RIGHT", -tokens.space.rowInset, 0)
		end
		button:Show()
		self:ApplyPicked(button)
		right = button
	end
	for index = #options + 1, #self.buttons do
		self.buttons[index]:Hide()
	end

	self.Label:SetText(data.label or "")
	self.Label:ClearAllPoints()
	self.Label:SetPoint("LEFT", self, "LEFT", tokens.space.rowInset, 0)
	if right then
		self.Label:SetPoint("RIGHT", right, "LEFT", -tokens.space.labelToControl, 0)
	end
end

---Returns the option button at `index`, creating it on first use.
---@param index integer
---@return Button
function AeonUISettings_PickerRowMixin:Button(index)
	local button = self.buttons[index]
	if not button then
		button = CreateFrame("Button", nil, self, "SharedButtonSmallTemplate")
		button:SetScript("OnClick", function()
			local entry = self.entry
			if entry and button.optionID ~= entry.picked then
				PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
				self.window:SetPick(entry.pageID, entry.data.id, button.optionID)
			end
			-- A click on the picked option leaves the page as it is; its button stays pressed.
			self:ApplyPicked(button)
		end)
		self.buttons[index] = button
	end

	return button
end

---Draws the picked option's button pressed with gold text, and the others raised with gray text.
---@param button Button
function AeonUISettings_PickerRowMixin:ApplyPicked(button)
	local picked = self.entry ~= nil and button.optionID == self.entry.picked
	button:SetNormalFontObject(picked and "GameFontNormal" or "GameFontDisable")
	button:SetButtonState(picked and "PUSHED" or "NORMAL", picked)
	button:UpdateButton(picked and "PUSHED" or "NORMAL")
end

function AeonUISettings_PickerRowMixin:Release()
	self.entry = nil
	self.window = nil
end

AS:RegisterElementKind("picker", {
	template = "AeonUISettings_PickerRowTemplate",
	picker = true,
	Init = function(frame, entry, window)
		frame:Init(entry, window)
	end,
	Reset = function(frame)
		frame:Release()
	end,
})
