local AUI = select(2, ...)

local Options = AUI.UnitFrameOptions

---Power bar colors: the palette by power type, and each bar's fill mode, gradient, opacity and background. oUF
---still decides a bar's base color, special power displays included; the palette replaces entries in AeonUI's
---private oUF color table, so oUF, power text and the extra mana bar all follow it, and the bar's mode recolors
---after oUF's step.
---@class AUIPowerColor
---@field blizzard table<string, table> each palette entry's own color, kept for when a setting is cleared
local PowerColor = {
	blizzard = {},
}
AUI.PowerColor = PowerColor

---@param key string
---@return table settings the frame's power colors, with its bar background
function PowerColor:Resolve(key)
	local settings = {}

	for _, name in ipairs(Options.POWER_LOOK) do
		settings[name] = AUI.Profile:Get(Options:Path(key, "powerColors." .. name))
	end

	settings.barBackground = AUI.Profile:Get(Options:Path(key, "bars.background"))

	return settings
end

---@param settings table from `Resolve`
---@param base table oUF's color for the bar
---@param classColor table? the unit's class color, for a player
---@return table fill the bar's color in its mode
function PowerColor:Fill(settings, base, classColor)
	if settings.mode == "custom" then
		return settings.color
	end

	if settings.mode == "class" and classColor then
		return classColor
	end

	return base
end

---@param settings table
---@param fill table the bar's color
---@return table color the background: the bar background, or the power color at its opacity
function PowerColor:Background(settings, fill)
	local custom = settings.barBackground

	if settings.background == "power" then
		return { r = fill.r, g = fill.g, b = fill.b, a = custom.a or 1 }
	end

	return custom
end

---@param token string a power type's token
---@return table? color Blizzard's color for it, kept from before any palette color replaced it
function PowerColor:Blizzard(token)
	local entry = AUI.oUF.colors.power[token]

	if entry and not self.blizzard[token] then
		self.blizzard[token] = { r = entry.r, g = entry.g, b = entry.b }
	end

	return self.blizzard[token]
end

---Writes the palette into oUF's power colors: a set color replaces the entry, a cleared one restores Blizzard's.
function PowerColor:ApplyPalette()
	local colors = AUI.oUF.colors.power

	for _, token in ipairs(Options.POWER_TOKENS) do
		local entry = colors[token]

		if entry then
			local blizzard = self:Blizzard(token) --[[@as table]]
			local color = AUI.Profile:Get(Options.ALL .. "powerColors.palette." .. token) or blizzard

			if entry.SetRGB then
				entry:SetRGB(color.r, color.g, color.b)
			else
				entry.r, entry.g, entry.b = color.r, color.g, color.b
			end
		end
	end
end

---@param unit string
---@return table? color a player unit's class color
local function ClassColor(unit)
	if not (UnitIsPlayer(unit) or UnitInPartyIsAI(unit)) then
		return nil
	end

	local _, class = UnitClass(unit)

	if issecretvalue(class) then
		return C_ClassColor.GetClassColor(class)
	end

	return class and AUI.oUF.colors.class[class]
end

---Takes a frame's resolved power colors and the background its power bar paints.
---@param frame table an AeonUI unit frame with a power bar
---@param settings table from `Resolve`
---@param background Texture the power bar's background
function PowerColor:Apply(frame, settings, background)
	frame.powerColors = settings
	frame.powerBackground = background
end

---oUF's `Power.PostUpdateColor`: recolors the bar in its mode, with its gradient, opacity and background.
---@param element table oUF's Power element, a status bar with `__owner`, its frame
---@param unit string
---@param color table? oUF's color for the bar
---@param r number? oUF's alternate color, when it used one
---@param g number?
---@param b number?
function PowerColor.PostUpdateColor(element, unit, color, r, g, b)
	local frame = element.__owner
	local settings = frame and frame.powerColors

	if not settings or not frame.powerBackground then
		return
	end

	local base = color or (r and { r = r, g = g, b = b }) or AUI.oUF.colors.power.MANA
	local fill = PowerColor:Fill(settings, base, settings.mode == "class" and ClassColor(unit) or nil)

	AUI.HealthColor:Paint(element, frame.powerBackground, settings, fill, PowerColor:Background(settings, fill))
end
