local AUI = select(2, ...)

local Options = AUI.TooltipOptions

-- The font objects every tooltip line is drawn with, and which of Blizzard's sizes each has.
local FONTS = {
	{ name = "GameTooltipHeaderText", size = "header" },
	{ name = "GameTooltipText", size = "body" },
	{ name = "GameTooltipTextSmall", size = "small" },
}

---The tooltip's look: the font objects its lines are drawn with, and whether `GameTooltip`'s health bar shows, with
---its place, height and texture. Blizzard's backdrop and border are left as they are. Each part is changed only once its
---setting asks for it, and put back as Blizzard had it when the setting or the module goes off. While the bar is a
---strip inside the tooltip, a tooltip showing it keeps room below its last line for it.
---@class AUITooltipAppearance
---@field original table<string, table>? each font object's font, size and flags before AeonUI changed them
---@field fontsChanged boolean the font objects hold AeonUI's font or sizes
---@field barChanged boolean the health bar is not as Blizzard left it
---@field barHidden boolean the health bar is kept transparent
---@field showHooked boolean
---@field stripPadding number the room a tooltip showing the strip keeps for it; 0 while the bar is not a strip
---@field padded number the room AeonUI added to `GameTooltip`'s bottom padding, taken back when its lines clear
---@field hooked boolean
local Appearance = {
	fontsChanged = false,
	barChanged = false,
	barHidden = false,
	showHooked = false,
	stripPadding = 0,
	padded = 0,
	hooked = false,
}
AUI.TooltipAppearance = Appearance

---@param on boolean the module is on
function Appearance:Apply(on)
	self:ApplyFonts(on)
	self:ApplyBar(on)
end

---Gives the tooltip's font objects the font settings: the chosen face and outline with Custom Font, and Blizzard's
---sizes times the font scale. Blizzard's own fonts are left untouched, or put back, while neither asks for a change.
---@param on boolean the module is on
function Appearance:ApplyFonts(on)
	local Profile, Media = AUI.Profile, AUI.Media
	local custom = on and Profile:Get(Options.FONT_CUSTOM_PATH) == true
	local scale = on and Profile:Get(Options.FONT_SCALE_PATH) or 100

	if not custom and scale == 100 and not self.fontsChanged then
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

	if not custom and scale == 100 then
		for name, saved in pairs(self.original) do
			local font = _G[name] --[[@as Font]]

			font:SetFont(saved.file, saved.size, saved.flags)
		end

		self.fontsChanged = false

		return
	end

	local file = custom and Media:Font(Profile:Get(Options.FONT_FACE_PATH))
	local flags = custom and Media:FontFlags(Profile:Get(Options.FONT_OUTLINE_PATH))

	for _, info in ipairs(FONTS) do
		local font = _G[info.name] --[[@as Font?]]
		local saved = self.original[info.name]

		if font and saved then
			font:SetFont(file or saved.file, Options:FontSize(info.size, scale), flags or saved.flags)
		end
	end

	self.fontsChanged = true
end

---Shows or hides `GameTooltip`'s health bar, places it and gives it its height and texture, or puts Blizzard's back.
---@param on boolean the module is on
function Appearance:ApplyBar(on)
	local bar = GameTooltipStatusBar

	if not bar or GameTooltip:IsForbidden() then
		return
	end

	local Profile, Media = AUI.Profile, AUI.Media
	local shown = not on or Profile:Get(Options.BAR_SHOWN_PATH) == true

	self:SetBarShown(shown)

	if not on and not self.barChanged then
		return
	end

	local style, texture, height

	if on then
		style = Profile:Get(Options.BAR_STYLE_PATH)
		texture = Profile:Get(Options.BAR_TEXTURE_PATH)
		height = Profile:Get(Options.BAR_HEIGHT_PATH)
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
	self.stripPadding = (on and shown and style == "STRIP") and Options:StripPadding(height) or 0
end

---Hides the health bar by its alpha, which Blizzard never sets, so its own showing and hiding go on as they are; each
---time Blizzard shows it, it is made transparent again.
---@param shown boolean
function Appearance:SetBarShown(shown)
	local bar = GameTooltipStatusBar --[[@as StatusBar]]

	if shown ~= self.barHidden then
		return
	end

	self.barHidden = not shown

	if not shown and not self.showHooked then
		self.showHooked = true
		hooksecurefunc(bar, "Show", function(shownBar)
			if Appearance.barHidden then
				shownBar:SetAlpha(0)
			end
		end)
	end

	bar:SetAlpha(shown and 1 or 0)
end

---Keeps room below the last line of a tooltip whose health bar shows as a strip. Runs after Blizzard has shown or
---hidden the bar for the unit or object, and before the tooltip sizes itself.
---@param tooltip GameTooltip
function Appearance:PadForStrip(tooltip)
	if tooltip ~= GameTooltip or tooltip:IsForbidden() or self.stripPadding == 0 or self.padded > 0 then
		return
	end

	local bar = GameTooltipStatusBar

	if not bar or not bar:IsShown() then
		return
	end

	-- A layout restriction inherited from the tooltip's owner can refuse the read.
	local ok, right, bottom, left, top = pcall(tooltip.GetPadding, tooltip)

	if not ok or issecretvalue(bottom) then
		return
	end

	self.padded = self.stripPadding
	tooltip:SetPadding(right, bottom + self.padded, left, top)
end

---Takes back the room added for the strip when the tooltip's lines clear for new content.
---@param tooltip GameTooltip
function Appearance:Unpad(tooltip)
	if self.padded == 0 or tooltip:IsForbidden() then
		return
	end

	local ok, right, bottom, left, top = pcall(tooltip.GetPadding, tooltip)
	local padded = self.padded

	self.padded = 0

	if ok and not issecretvalue(bottom) then
		tooltip:SetPadding(right, math.max(0, bottom - padded), left, top)
	end
end

---Installs the strip's padding hooks once; they do nothing while the bar is not a strip.
function Appearance:Hook()
	if self.hooked or not TooltipDataProcessor or not GameTooltip then
		return
	end

	self.hooked = true

	local function Pad(tooltip)
		Appearance:PadForStrip(tooltip)
	end

	-- The unit and object types are the ones Blizzard's health bar rule shows the bar for.
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, Pad)
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, Pad)
	GameTooltip:HookScript("OnTooltipCleared", function(tooltip)
		Appearance:Unpad(tooltip)
	end)
	-- Blizzard clears the padding as the tooltip hides.
	GameTooltip:HookScript("OnHide", function()
		Appearance.padded = 0
	end)
end
