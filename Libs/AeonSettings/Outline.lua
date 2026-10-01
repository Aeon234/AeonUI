-- Outline: a 2-unit frame drawn inside a region, shown steadily or flashed and faded; bronze by default.
local _, ns = ...
local AS = ns.AeonSettings
local tokens = AS.tokens

local THICKNESS = 2
local FLASH_DURATION = 0.75

---@class AeonSettingsOutline : Frame
---@field fade AnimationGroup

---Creates a hidden outline on `parent`; the caller anchors it to the region to outline.
---@param parent Frame
---@param color number[]? r, g, b; `color.accent` when nil
---@return AeonSettingsOutline
function AS:CreateOutline(parent, color)
	local outline = CreateFrame("Frame", nil, parent)
	outline:SetFrameLevel(parent:GetFrameLevel() + 5)
	outline:Hide()

	local accent = color or tokens.color.accent
	local edges = {
		{ "TOPLEFT", "TOPRIGHT", nil, THICKNESS },
		{ "BOTTOMLEFT", "BOTTOMRIGHT", nil, THICKNESS },
		{ "TOPLEFT", "BOTTOMLEFT", THICKNESS, nil },
		{ "TOPRIGHT", "BOTTOMRIGHT", THICKNESS, nil },
	}
	for _, edge in ipairs(edges) do
		local texture = outline:CreateTexture(nil, "OVERLAY")
		texture:SetColorTexture(accent[1], accent[2], accent[3], 1)
		texture:SetPoint(edge[1])
		texture:SetPoint(edge[2])
		if edge[3] then
			texture:SetWidth(edge[3])
		else
			texture:SetHeight(edge[4])
		end
	end

	local fade = outline:CreateAnimationGroup()
	local alpha = fade:CreateAnimation("Alpha")
	alpha:SetFromAlpha(1)
	alpha:SetToAlpha(0)
	alpha:SetDuration(FLASH_DURATION)
	fade:SetScript("OnFinished", function()
		outline:Hide()
	end)
	outline.fade = fade

	outline:SetScript("OnHide", function()
		fade:Stop()
	end)

	return outline
end

---Shows the outline steadily at full strength, stopping a running fade.
---@param outline AeonSettingsOutline
function AS:ShowOutline(outline)
	outline.fade:Stop()
	outline:SetAlpha(1)
	outline:Show()
end

---Shows the outline at full strength, then fades it out. A new flash restarts the fade.
---@param outline AeonSettingsOutline
function AS:FlashOutline(outline)
	self:ShowOutline(outline)
	outline.fade:Play()
end

---Hides the outline at once.
---@param outline AeonSettingsOutline
function AS:HideOutline(outline)
	outline.fade:Stop()
	outline:Hide()
end
