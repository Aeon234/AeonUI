-- Section-style headers and the content side's divider line. Section headers and search-result page dividers share
-- the header look: a capitalized title over a line across the list; the tabs and the preview end on the divider.
local _, ns = ...
local AS = ns.AeonSettings
local tokens = AS.tokens

local TITLE_TO_LINE = 8 -- the title's bottom above the header's line
local HEADER_TOGGLE_LIFT = 2
local DIVIDER_LEFT = 4 -- the divider's reach left of the content side's edge, onto the category divider's line
local DIVIDER_RIGHT = 3 -- the divider's end, in from the inner frame's right edge, on its border's line

---Where a section-style header places its title and its right-side controls: the title's vertical center below
---the element's top edge, and how far the plus/minus and similar controls sit above that line.
---@return number titleCenter
---@return number toggleLift
function AS:HeaderLayout()
	local height = tokens.space.sectionGap + tokens.size.sectionHeader

	return height - TITLE_TO_LINE - tokens.font.sectionSize / 2, HEADER_TOGGLE_LIFT
end

---The height of a section-style header element: the section gap, then the header.
---@return number
function AS:HeaderExtent()
	return tokens.space.sectionGap + tokens.size.sectionHeader
end

---Styles a section-style header's title: `font.body`'s face at `font.sectionSize`, `color.sectionTitle`.
---@param title FontString
function AS:StyleHeaderTitle(title)
	self:SetFont(title, "body", tokens.font.sectionSize)
	title:SetTextColor(unpack(tokens.color.sectionTitle))
end

---Adds the line a section-style header draws along its bottom edge, across its width: 1 px of
---`color.sectionTitle` at `alpha.sectionLine`.
---@param parent Frame
---@return Texture
function AS:CreateHeaderLine(parent)
	local color = tokens.color.sectionTitle
	local line = parent:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(color[1], color[2], color[3], tokens.alpha.sectionLine)
	line:SetHeight(1)
	line:SetPoint("BOTTOMLEFT")
	line:SetPoint("BOTTOMRIGHT")

	return line
end

---Draws the content side's divider line under `frame`, on it so it shows and hides with it: three 1 px rows of
---`color.divider`, the middle opaque and the outer two at `alpha.dividerSoft`, the top row on the frame's bottom edge.
---`left` and `right` are the distances from the frame's left and right edges to the content side's left edge and
---the inner frame's right edge; the line reaches onto the category divider's line and ends on the border's.
---@param frame Frame
---@param left number
---@param right number
---@return number height the line's height below the frame
function AS:CreateContentDivider(frame, left, right)
	local color = tokens.color.divider
	for row = 0, 2 do
		local line = frame:CreateTexture(nil, "ARTWORK")
		line:SetColorTexture(color[1], color[2], color[3], row == 1 and 1 or tokens.alpha.dividerSoft)
		line:SetHeight(1)
		line:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -(left + DIVIDER_LEFT), -row)
		line:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", right - DIVIDER_RIGHT, -row)
	end

	return 3
end
