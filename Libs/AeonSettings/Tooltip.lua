-- Control tooltips on GameTooltip: body-text lines only, no title line.
local _, ns = ...
local AS = ns.AeonSettings
local tokens = AS.tokens

---@class AeonSettingsTooltip
---@field owner Region? region the shown tooltip belongs to
local Tooltip = {}
AS.Tooltip = Tooltip

local function UseBodyFont()
	GameTooltipTextLeft1:SetFontObject(GameTooltipText)
	GameTooltipTextRight1:SetFontObject(GameTooltipText)
end

local function RestoreHeaderFont()
	GameTooltipTextLeft1:SetFontObject(GameTooltipHeaderText)
	GameTooltipTextRight1:SetFontObject(GameTooltipHeaderText)
end

---Shows lines above `owner`. Each line is `{ text, color }`; nothing shows when `lines` is empty.
---@param owner Region
---@param lines { [1]: string, [2]: number[] }[]
function Tooltip:Show(owner, lines)
	if #lines == 0 then
		self:Hide(owner)

		return
	end

	GameTooltip:SetOwner(owner, "ANCHOR_TOP")
	UseBodyFont()
	for _, line in ipairs(lines) do
		local color = line[2]
		GameTooltip:AddLine(line[1], color[1], color[2], color[3], true)
	end
	GameTooltip:Show()
	self.owner = owner
end

---Hides the tooltip if `owner` holds it, and restores GameTooltip's title font.
---@param owner Region
function Tooltip:Hide(owner)
	if self.owner ~= owner then
		return
	end

	self.owner = nil
	RestoreHeaderFont()
	if GameTooltip:GetOwner() == owner then
		GameTooltip:Hide()
	end
end

---@param owner Region
---@return boolean
function Tooltip:IsShownFor(owner)
	return self.owner == owner and GameTooltip:GetOwner() == owner and GameTooltip:IsShown()
end

---Builds the standard lines: truncated label text, description, then the inactive reason.
---@param fullText string? label text when it is cut off
---@param description string?
---@param reason string? inactive reason
---@return { [1]: string, [2]: number[] }[]
function Tooltip:Lines(fullText, description, reason)
	local lines = {}
	if fullText then
		lines[#lines + 1] = { fullText, tokens.color.text }
	end
	if description then
		lines[#lines + 1] = { description, tokens.color.text }
	end
	if reason then
		lines[#lines + 1] = { reason, tokens.color.error }
	end

	return lines
end
