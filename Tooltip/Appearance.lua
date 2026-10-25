local AUI = select(2, ...)

local Options = AUI.TooltipOptions

-- The font objects every tooltip line is drawn with, and which size setting each takes.
local FONTS = {
	{ name = "GameTooltipHeaderText", size = "header" },
	{ name = "GameTooltipText", size = "body" },
	{ name = "GameTooltipTextSmall", size = "small" },
}

---The tooltip's look: the font objects its lines are drawn with, and the place, height and texture of
---`GameTooltip`'s health bar. Blizzard's backdrop and border are left as they are. Each part is changed only once its
---setting asks for it, and put back as Blizzard had it when the setting or the module goes off.
---@class AUITooltipAppearance
---@field original table<string, table>? each font object's font, size and flags before AeonUI changed them
---@field fontsChanged boolean the font objects hold AeonUI's font
---@field barChanged boolean the health bar is not as Blizzard left it
local Appearance = {
	fontsChanged = false,
	barChanged = false,
}
AUI.TooltipAppearance = Appearance

---@param on boolean the module is on
function Appearance:Apply(on)
	local Profile = AUI.Profile

	self:ApplyFonts(on and Profile:Get(Options.FONT_CUSTOM_PATH) == true)
	self:ApplyBar(on)
end

---Gives the tooltip's font objects the font settings, or Blizzard's own fonts back.
---@param custom boolean
function Appearance:ApplyFonts(custom)
	if not custom and not self.fontsChanged then
		return
	end

	if not self.original then
		self.original = {}

		for _, info in ipairs(FONTS) do
			local font = _G[info.name] --[[@as Font?]]

			if font then
				local file, size, flags = font:GetFont()

				self.original[info.name] = { file = file, size = size, flags = flags }
			end
		end
	end

	if not custom then
		for name, saved in pairs(self.original) do
			local font = _G[name] --[[@as Font]]

			font:SetFont(saved.file, saved.size, saved.flags)
		end

		self.fontsChanged = false

		return
	end

	local Profile, Media = AUI.Profile, AUI.Media
	local file = Media:Font(Profile:Get(Options.FONT_FACE_PATH))
	local flags = Media:FontFlags(Profile:Get(Options.FONT_OUTLINE_PATH))
	local body = Profile:Get(Options.FONT_BODY_PATH)
	---@type table<string, number>
	local sizes = { header = Profile:Get(Options.FONT_HEADER_PATH), body = body, small = Options:SmallSize(body) }

	for _, info in ipairs(FONTS) do
		local font = _G[info.name] --[[@as Font?]]

		if font and self.original[info.name] then
			font:SetFont(file, sizes[info.size], flags)
		end
	end

	self.fontsChanged = true
end

---Places `GameTooltip`'s health bar and gives it its height and texture, or puts Blizzard's back.
---@param on boolean the module is on
function Appearance:ApplyBar(on)
	local bar = GameTooltipStatusBar

	if not bar or GameTooltip:IsForbidden() or (not on and not self.barChanged) then
		return
	end

	local Profile, Media = AUI.Profile, AUI.Media
	local style, texture, height

	if on then
		style = Profile:Get(Options.BAR_STYLE_PATH)
		texture = Profile:Get(Options.BAR_TEXTURE_PATH)
		height = Options:BarHeight(style, Profile:Get(Options.BAR_HEIGHT_PATH), Profile:Get(Options.STRIP_HEIGHT_PATH))
	else
		style, texture, height = "BLIZZARD", Media.TOOLTIP_BAR, Options.BLIZZARD_BAR_HEIGHT
	end

	local left, right = Options:BarPlace(style)

	bar:ClearAllPoints()
	bar:SetPoint(left.from, GameTooltip, left.to, left.x, left.y)
	bar:SetPoint(right.from, GameTooltip, right.to, right.x, right.y)
	bar:SetHeight(height)
	Media:SetBarTexture(bar, texture)
	self.barChanged = on
end
