-- Section-style headers: where a header places its title and controls, the bronze bar before its title and the
-- divider under it. Section headers and the preview panel's band share them.
local _, ns = ...
local AS = ns.AeonSettings
local tokens = AS.tokens

local HEADER_TOP_PADDING = 2 -- the gap's bottom edge to the header's title area
local HEADER_TOGGLE_LIFT = 2
local DIVIDER_ATLAS = "Options_HorizontalDivider"

---Where a section-style header places its title and its right-side controls: the title area's vertical
---center below the element's top edge, and how far the plus/minus and similar controls sit above that line.
---@return number titleCenter
---@return number toggleLift
function AS:HeaderLayout()
	return tokens.space.sectionGap + HEADER_TOP_PADDING + tokens.size.sectionHeader / 2, HEADER_TOGGLE_LIFT
end

---Adds the bronze bar a section-style header shows left of its title: `size.headerBar` wide, as tall as the
---header font, `space.headerBarToTitle` before the title.
---@param parent Frame
---@param title FontString
---@return Texture
function AS:CreateHeaderBar(parent, title)
	local accent = tokens.color.accent
	local bar = parent:CreateTexture(nil, "ARTWORK")
	bar:SetColorTexture(accent[1], accent[2], accent[3], 1)
	bar:SetSize(tokens.size.headerBar, tokens.font.headerSize)
	bar:SetPoint("RIGHT", title, "LEFT", -tokens.space.headerBarToTitle, 0)

	return bar
end

---Adds the divider a section-style header draws along its bottom edge: Blizzard's `Options_HorizontalDivider`,
---the page header's own line, at its atlas height and the header's full width.
---@param parent Frame
---@return Texture
function AS:CreateHeaderDivider(parent)
	local divider = parent:CreateTexture(nil, "ARTWORK")
	divider:SetAtlas(DIVIDER_ATLAS, TextureKitConstants.UseAtlasSize)
	divider:SetPoint("BOTTOMLEFT")
	divider:SetPoint("BOTTOMRIGHT")

	return divider
end
