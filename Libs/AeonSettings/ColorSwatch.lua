-- Color swatch: a color, with or without opacity, chosen in Blizzard's color picker.
local _, ns = ...
local AS = ns.AeonSettings

-- The frame art (`Media\Swatch\Frame.png`): 110x110 in the top-left of a 128x128 file, drawn at the swatch's size;
-- the color fills its inside, ART_INSIDE art pixels in, masked to the inside's shape (`Mask.png`).
local ART, ART_FILE, ART_INSIDE = 110, 128, 15
local CHECKER_DARK = 0.1
local CHECKER_LIGHT = 0.4
local HOVER_ALPHA = 0.15
local SAME_COLOR = 0.0005

---@alias AeonSettingsColor { r: number, g: number, b: number, a: number? }

---@param a AeonSettingsColor
---@param b AeonSettingsColor
---@param hasOpacity boolean
---@return boolean
local function SameColor(a, b, hasOpacity)
	local function Near(x, y)
		return math.abs((x or 1) - (y or 1)) <= SAME_COLOR
	end

	return Near(a.r, b.r) and Near(a.g, b.g) and Near(a.b, b.b) and (not hasOpacity or Near(a.a, b.a))
end

-- The swatch whose color the picker is showing. One hook on the picker serves every swatch.
local activeSwatch
local pickerHooked = false

local function OnPickerHidden()
	local swatch = activeSwatch
	if not swatch or not swatch.picking then
		return
	end

	activeSwatch = nil
	swatch.picking = false
	if not swatch.canceled and ColorPickerFrame:GetExtraInfo() == swatch.token then
		swatch:Commit()
	else
		swatch:Restore()
	end
	swatch:InteractionEnded()
end

---@class AeonSettingsColorSwatch : Frame, AeonSettingsControlMixin
---@field hasOpacity boolean
---@field saved AeonSettingsColor
---@field shown AeonSettingsColor the color on the swatch, saved or previewed
---@field picking boolean the picker is showing this swatch's color
---@field canceled boolean? the current pick ended in Cancel
---@field original AeonSettingsColor? the saved color when the current pick began, put back by Cancel
---@field pending boolean a picked color waits for the next frame to be saved
---@field pickRefused boolean? a save was refused during the current pick, so the rest of it only previews
---@field token table identifies this swatch's pick in the picker's extra info
AeonUISettings_ColorSwatchMixin = CreateFromMixins(AS.ControlMixin)

function AeonUISettings_ColorSwatchMixin:OnLoad()
	local swatch = self.Swatch
	self.hasOpacity = false
	self.saved = { r = 1, g = 1, b = 1 }
	self.shown = self.saved
	self.picking = false
	self.pending = false

	local border = swatch.Border
	local size = AS.tokens.size.swatch
	local inset = size * ART_INSIDE / ART
	local width, height = size - inset * 2, size - inset * 2
	border:SetTexture(AS.MEDIA .. "Swatch\\Frame.png")
	border:SetTexCoord(0, ART / ART_FILE, 0, ART / ART_FILE)

	local mask = swatch:CreateMaskTexture()
	mask:SetTexture(AS.MEDIA .. "Swatch\\Mask.png", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetPoint("TOPLEFT", border, "TOPLEFT", inset, -inset)
	mask:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", -inset, inset)

	-- A 3 x 3 checkerboard filling the inside, dark in the corners and the middle.
	self.checker = {}
	for row = 0, 2 do
		for column = 0, 2 do
			local square = swatch:CreateTexture(nil, "ARTWORK", nil, 0)
			local gray = (row + column) % 2 == 0 and CHECKER_DARK or CHECKER_LIGHT
			square:SetColorTexture(gray, gray, gray, 1)
			square:SetSize(width / 3, height / 3)
			square:SetPoint("TOPLEFT", border, "TOPLEFT", inset + column * width / 3, -(inset + row * height / 3))
			square:AddMaskTexture(mask)
			self.checker[#self.checker + 1] = square
		end
	end

	swatch.Color:SetPoint("TOPLEFT", border, "TOPLEFT", inset, -inset)
	swatch.Color:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", -inset, inset)
	swatch.Color:AddMaskTexture(mask)

	swatch.Highlight:SetColorTexture(1, 1, 1, HOVER_ALPHA)
	swatch.Highlight:SetAllPoints(swatch.Color)
	swatch.Highlight:AddMaskTexture(mask)

	swatch:SetMotionScriptsWhileDisabled(true)
	swatch:SetScript("OnEnter", function()
		swatch.Highlight:SetShown(self.enabled)
	end)
	swatch:SetScript("OnLeave", function()
		swatch.Highlight:Hide()
	end)
	swatch:SetScript("OnClick", function()
		self:OpenPicker()
	end)

	self:InitControl(swatch, swatch)
	self:ShowColor(self.saved)
end

---Draws a color; the checkerboard shows through while it is not fully opaque.
---@param color AeonSettingsColor
function AeonUISettings_ColorSwatchMixin:ShowColor(color)
	self.shown = color
	local alpha = self.hasOpacity and (color.a or 1) or 1
	self.Swatch.Color:SetColorTexture(color.r, color.g, color.b, alpha)
	for _, square in ipairs(self.checker) do
		square:SetShown(alpha < 1)
	end
end

---Saves the color the picker shows, at most once a frame, so the page's preview and the owner's frames follow
---the pick. A refused save ends live saving for the rest of the pick.
function AeonUISettings_ColorSwatchMixin:SaveLive()
	if self.pending or self.pickRefused then
		return
	end

	self.pending = true
	C_Timer.After(0, function()
		self.pending = false
		if self.picking and not self.pickRefused then
			self:Request(self:PickedValue())
		end
	end)
end

---@return AeonSettingsColor
function AeonUISettings_ColorSwatchMixin:PickedValue()
	local color = self.shown
	return { r = color.r, g = color.g, b = color.b, a = self.hasOpacity and (color.a or 1) or nil }
end

---Opens Blizzard's picker on the saved color. A pick already open on this swatch ends as Cancel first.
function AeonUISettings_ColorSwatchMixin:OpenPicker()
	if not self.enabled then
		return
	end

	self:CancelPick()
	if activeSwatch then
		activeSwatch:CancelPick()
	end

	if not pickerHooked then
		ColorPickerFrame:HookScript("OnHide", OnPickerHidden)
		pickerHooked = true
	end

	local saved = self.saved
	local function Preview()
		if self.picking and ColorPickerFrame:GetExtraInfo() == self.token then
			local r, g, b = ColorPickerFrame:GetColorRGB()
			local a = self.hasOpacity and ColorPickerFrame:GetColorAlpha() or nil
			self:ShowColor({ r = r, g = g, b = b, a = a })
			self:SaveLive()
		end
	end

	self.token = {}
	self.picking = true
	self.canceled = false
	self.pickRefused = false
	self.original = saved
	activeSwatch = self
	ColorPickerFrame:SetupColorPickerAndShow({
		r = saved.r,
		g = saved.g,
		b = saved.b,
		opacity = self.hasOpacity and (saved.a or 1) or nil,
		hasOpacity = self.hasOpacity,
		swatchFunc = Preview,
		opacityFunc = Preview,
		cancelFunc = function()
			self.canceled = true
		end,
		extraInfo = self.token,
	})
	-- Previews reported while the picker opens can carry the previous caller's opacity.
	self:ShowColor(self.saved)
end

---Ends this swatch's pick as a Cancel and closes the picker if it still shows this swatch's color.
---@param keepPicker boolean? leave the picker open for its next caller
function AeonUISettings_ColorSwatchMixin:CancelPick(keepPicker)
	if not self.picking then
		return
	end

	self.picking = false
	if activeSwatch == self then
		activeSwatch = nil
	end
	self:Restore()
	self:InteractionEnded()
	if not keepPicker and ColorPickerFrame:IsShown() and ColorPickerFrame:GetExtraInfo() == self.token then
		ColorPickerFrame:Hide()
	end
end

---Asks to save the picked color; when nothing is asked, the saved color shows again.
function AeonUISettings_ColorSwatchMixin:Commit()
	self.original = nil
	if not self:Request(self:PickedValue()) then
		self:ShowColor(self.saved)
	end
end

---Ends a pick as a Cancel: asks to save the color from before the pick again if live saving changed it, then
---shows the saved color.
function AeonUISettings_ColorSwatchMixin:Restore()
	local original = self.original
	self.original = nil
	if original then
		self:Request(original)
	end
	self:ShowColor(self.saved)
end

---@return boolean
function AeonUISettings_ColorSwatchMixin:IsInteracting()
	return self.picking
end

---A refused save during a pick stops live saving until the pick ends.
---@param message string?
function AeonUISettings_ColorSwatchMixin:Reject(message)
	if self.picking then
		self.pickRefused = true
	end
	AS.ControlMixin.Reject(self, message)
end

---@param value AeonSettingsColor
---@return boolean
function AeonUISettings_ColorSwatchMixin:IsSaved(value)
	return SameColor(value, self.saved, self.hasOpacity)
end

---@param setting { hasOpacity: boolean? }
function AeonUISettings_ColorSwatchMixin:Configure(setting)
	self.hasOpacity = setting.hasOpacity == true
end

---Shows the saved color; the swatch never animates.
---@param value AeonSettingsColor
---@param _ boolean? instant
function AeonUISettings_ColorSwatchMixin:SetChecked(value, _)
	value = value or { r = 1, g = 1, b = 1 }
	self.saved = { r = value.r, g = value.g, b = value.b, a = self.hasOpacity and (value.a or 1) or nil }
	if not self.picking then
		self:ShowColor(self.saved)
	end
end

---@param enabled boolean
function AeonUISettings_ColorSwatchMixin:ApplyEnabled(enabled)
	self.Swatch:SetEnabled(enabled)
end

---Ends a pick as a Cancel and hides the hover highlight.
function AeonUISettings_ColorSwatchMixin:EndInteraction()
	self:CancelPick()
	self.Swatch.Highlight:Hide()
end

AS:RegisterControl("color", { frameType = "Frame", template = "AeonUISettings_ColorSwatchTemplate" })
