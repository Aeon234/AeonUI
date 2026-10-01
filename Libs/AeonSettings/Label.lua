-- Control label: one line of body text that dims with its control and carries the control's tooltip.
local _, ns = ...
local AS = ns.AeonSettings
local tokens = AS.tokens

---@class AeonSettingsLabel
---@field text FontString
---@field hover Frame hover region: the visible text plus a margin; takes no clicks
---@field control table? the control this label describes; its `enabled` and `reason` fields drive dimming
---@field description string?
local Label = {}
Label.__index = Label

---Creates a label on `parent`. The caller positions `label.text`.
---@param parent Frame
---@return AeonSettingsLabel
function AS:CreateLabel(parent)
	local label = setmetatable({}, Label)

	label.text = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	AS:SetFont(label.text, "body")
	label.text:SetTextColor(unpack(tokens.color.text))
	label.text:SetWordWrap(false)
	label.text:SetMaxLines(1)

	local hover = CreateFrame("Frame", nil, parent)
	hover:SetMouseClickEnabled(false)
	hover:SetMouseMotionEnabled(true)
	hover:Hide()
	hover:SetScript("OnEnter", function()
		label:ShowTooltip()
	end)
	hover:SetScript("OnLeave", function()
		AS.Tooltip:Hide(hover)
	end)
	hover:SetScript("OnHide", function()
		AS.Tooltip:Hide(hover)
	end)
	label.hover = hover

	return label
end

---@param text string?
function Label:SetText(text)
	self.text:SetText(text or "")
end

---@param description string?
function Label:SetDescription(description)
	self.description = description
end

---@param color number[]? RGB; nil restores white
function Label:SetColor(color)
	self.text:SetTextColor(unpack(color or tokens.color.text))
end

---Links the label and a control both ways, unlinking the control it described before.
---@param control table?
function Label:SetControl(control)
	local previous = self.control
	if previous and previous.label == self then
		previous.label = nil
	end
	self.control = control
	if control then
		control.label = self
	end
end

---@param shown boolean
function Label:SetShown(shown)
	self.text:SetShown(shown)
	if not shown then
		self.hover:Hide()
	end
end

---@return { [1]: string, [2]: number[] }[]
function Label:TooltipLines()
	local control = self.control
	local fullText = self.text:IsTruncated() and self.text:GetText() or nil
	local reason = control and control.enabled == false and control.reason or nil

	return AS.Tooltip:Lines(fullText, self.description, reason)
end

function Label:ShowTooltip()
	AS.Tooltip:Show(self.hover, self:TooltipLines())
end

---Re-reads the control's state: dims when inactive, sizes the hover region, and redraws an open tooltip.
function Label:Refresh()
	local control = self.control
	local inactive = control ~= nil and control.enabled == false
	self.text:SetAlpha(inactive and tokens.alpha.inactive or 1)

	if not self.text:IsShown() or #self:TooltipLines() == 0 then
		self.hover:Hide()

		return
	end

	local margin = tokens.space.hover
	local text = self.text
	local width = math.min(text:GetUnboundedStringWidth(), text:GetWidth())
	local hover = self.hover
	hover:ClearAllPoints()
	if text:GetJustifyH() == "RIGHT" then
		hover:SetPoint("RIGHT", text, "RIGHT", margin, 0)
	else
		hover:SetPoint("LEFT", text, "LEFT", -margin, 0)
	end
	hover:SetSize(width + margin * 2, text:GetStringHeight() + margin * 2)
	hover:Show()

	if AS.Tooltip:IsShownFor(hover) then
		self:ShowTooltip()
	end
end

---Places a standalone label beside its control.
---@param control Region
---@param position "LEFT" | "RIGHT" | "TOP" | "BOTTOM"
---@param maxWidth number? width at which the text is cut with an ellipsis
function Label:PlaceBeside(control, position, maxWidth)
	local text = self.text
	local gap = tokens.space.gap
	text:ClearAllPoints()
	if maxWidth then
		text:SetWidth(maxWidth)
	end

	if position == "RIGHT" then
		text:SetJustifyH("LEFT")
		text:SetPoint("LEFT", control, "RIGHT", gap, 0)
	elseif position == "TOP" then
		text:SetJustifyH("LEFT")
		text:SetPoint("BOTTOMLEFT", control, "TOPLEFT", 0, gap)
	elseif position == "BOTTOM" then
		text:SetJustifyH("LEFT")
		text:SetPoint("TOPLEFT", control, "BOTTOMLEFT", 0, -gap)
	else
		text:SetJustifyH("RIGHT")
		text:SetPoint("RIGHT", control, "LEFT", -gap, 0)
	end
	self:Refresh()
end
