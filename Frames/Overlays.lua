local AUI = select(2, ...)

local Schema = AUI.Schema

-- Width of the incoming-heal overflow marker, at the far end of the bar.
local MARKER_WIDTH = 3

-- Width of the shield glow line, centered on the health edge.
local GLOW_WIDTH = 16

local GLOW_TEXTURE = "Interface\\RaidFrame\\Shield-Overshield"

-- Bar texture for the overflow marker: oUF replaces a texture-less marker with its own art.
local MARKER_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

-- Edge positions: the bar's side a strip sits on, and whether it fills from the right.
local FROM_RIGHT = { TOPRIGHT = true, BOTTOMRIGHT = true, RIGHT = true }

---The widgets of a bar's health overlays. On live frames the three main bars are oUF's Health sub-widgets; the
---overshield, glow and backing bars are AeonUI's and are fed from the same calculator after oUF's update.
---@class AUIOverlayWidgets
---@field bar StatusBar the health bar the overlays belong to
---@field healing StatusBar incoming heals, never clipped so Overheal can pass the bar's end
---@field marker Texture the incoming-heal overflow marker
---@field clip Frame clips the shield and heal-absorb bars to the health bar
---@field absorb StatusBar
---@field healAbsorb StatusBar
---@field backing StatusBar darkens the health under heal absorbs
---@field overshieldClip Frame spans the health fill; only the overshield inside it shows
---@field overshield StatusBar
---@field glow StatusBar full while any shield exists, empty otherwise
---@field settings table? the frame's resolved overlay settings, from the last `Apply`

---Health overlays: shields with their overshield, heal absorbs, heal prediction, the glow line and the backing.
---@class AUIOverlays
local Overlays = {}
AUI.Overlays = Overlays

---@param parent Frame
---@param level integer frame level above the health bar
---@return StatusBar
local function NewBar(parent, bar, level)
	local overlay = CreateFrame("StatusBar", nil, parent)

	overlay:SetFrameLevel(bar:GetFrameLevel() + level)
	AUI.Media:SetBarTexture(overlay, AUI.Media.FLAT)

	return overlay
end

---Creates a health bar's overlay widgets.
---@param bar StatusBar the health bar
---@return AUIOverlayWidgets widgets
function Overlays:Create(bar)
	local clip = CreateFrame("Frame", nil, bar)

	clip:SetAllPoints(bar)
	clip:SetClipsChildren(true)
	clip:SetFrameLevel(bar:GetFrameLevel() + 1)

	local overshieldClip = CreateFrame("Frame", nil, bar)

	overshieldClip:SetClipsChildren(true)
	overshieldClip:SetFrameLevel(bar:GetFrameLevel() + 3)

	local widgets = {
		bar = bar,
		clip = clip,
		healing = NewBar(bar, bar, 1),
		absorb = NewBar(clip, bar, 2),
		backing = NewBar(clip, bar, 2),
		healAbsorb = NewBar(clip, bar, 3),
		overshieldClip = overshieldClip,
		overshield = NewBar(overshieldClip, bar, 4),
		glow = NewBar(bar, bar, 5),
	}

	widgets.backing:SetStatusBarColor(0, 0, 0, 1)

	local glow = widgets.glow

	glow:SetStatusBarTexture(GLOW_TEXTURE)
	glow:GetStatusBarTexture():SetBlendMode("ADD")
	glow:SetMinMaxValues(0, 1)

	local marker = bar:CreateTexture(nil, "OVERLAY", nil, 6)

	marker:SetTexture(MARKER_TEXTURE)
	widgets.marker = marker

	return widgets
end

---@param config table
---@param key string
---@return table? settings the frame's overlay settings with the shared colors, or nil when it has no overlays
function Overlays:Resolve(config, key)
	local base = "frames." .. key .. ".overlays."

	if not Schema:Field(base .. "absorb.enabled") then
		return nil
	end

	local settings = {}

	for _, kind in ipairs({ "absorb", "healAbsorb", "healPrediction" }) do
		local path = base .. kind .. "."

		settings[kind] = {
			enabled = Schema:Read(config, path .. "enabled"),
			position = Schema:Read(config, path .. "position"),
			height = Schema:Read(config, path .. "height"),
			matchHeight = Schema:Read(config, path .. "matchHeight"),
			texture = Schema:Read(config, path .. "texture"),
			color = Schema:Read(config, "overlays.colors." .. kind),
		}
	end

	settings.absorb.overshield = Schema:Read(config, base .. "absorb.overshield")
	settings.absorb.glow = Schema:Read(config, base .. "absorb.glow")
	settings.healAbsorb.backing = Schema:Read(config, base .. "healAbsorb.backing")
	settings.healPrediction.overheal = Schema:Read(config, base .. "healPrediction.overheal")

	return settings
end

---Where an attached overlay starts. Forward bars (heal prediction, shields) grow in the fill direction from the
---edge's far side; backward bars (heal absorbs) grow against it from the same side of the edge.
---@param backward boolean
---@param reversed boolean the health bar fills right to left
---@return string point the overlay's point
---@return string relative the edge's point it attaches to
---@return boolean reverseFill the overlay fills right to left
function Overlays:AttachPoints(backward, reversed)
	local growsRight = (not reversed) ~= backward
	local point = growsRight and "LEFT" or "RIGHT"
	local relative = point

	if not backward then
		relative = growsRight and "RIGHT" or "LEFT"
	end

	return point, relative, not growsRight
end

---Places one overlay bar: attached to an edge texture, or as a strip on one side of the health bar.
---@param overlay StatusBar
---@param bar StatusBar the health bar
---@param edge Region the texture whose far edge an attached bar starts from
---@param option table the overlay's settings
---@param backward boolean an attached bar grows back over the health instead of forward
---@param reversed boolean the health bar fills right to left
local function Place(overlay, bar, edge, option, backward, reversed)
	overlay:ClearAllPoints()

	local height = option.matchHeight and bar:GetHeight() or option.height
	local position = option.position

	if position == "attach" then
		local point, relative, reverseFill = Overlays:AttachPoints(backward, reversed)

		if option.matchHeight then
			overlay:SetPoint("TOP", bar, "TOP")
			overlay:SetPoint("BOTTOM", bar, "BOTTOM")
			overlay:SetPoint(point, edge, relative)
		else
			overlay:SetPoint("TOP" .. point, edge, "TOP" .. relative)
			overlay:SetHeight(height)
		end

		overlay:SetReverseFill(reverseFill)

		return
	end

	local side = FROM_RIGHT[position] and "RIGHT" or "LEFT"

	if option.matchHeight then
		overlay:SetPoint("TOP" .. side, bar, "TOP" .. side)
		overlay:SetPoint("BOTTOM" .. side, bar, "BOTTOM" .. side)
	else
		overlay:SetPoint(position, bar, position)
		overlay:SetHeight(height)
	end

	overlay:SetReverseFill(FROM_RIGHT[position] == true)
end

---Applies a frame's overlay settings to its widgets: visibility, geometry, textures and colors. Not protected; runs
---in combat too.
---@param widgets AUIOverlayWidgets
---@param settings table from `Overlays:Resolve`
---@param reversed boolean the health bar fills right to left
---@param health table? oUF's Health element on a live frame, whose calculator modes are set here
function Overlays:Apply(widgets, settings, reversed, health)
	local bar = widgets.bar
	local fill = bar:GetStatusBarTexture()
	local absorb, healAbsorb, prediction = settings.absorb, settings.healAbsorb, settings.healPrediction

	widgets.settings = settings

	for kind, overlay in pairs({ absorb = widgets.absorb, healAbsorb = widgets.healAbsorb, healPrediction = widgets.healing }) do
		local option = settings[kind]
		local color = option.color

		AUI.Media:SetBarTexture(overlay, option.texture)
		overlay:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
		overlay:SetShown(option.enabled)
	end

	-- Heal prediction, then shields after it when both are attached and shown.
	Place(widgets.healing, bar, fill, prediction, false, reversed)

	local shieldEdge = fill

	if prediction.enabled and prediction.position == "attach" then
		shieldEdge = widgets.healing:GetStatusBarTexture()
	end

	Place(widgets.absorb, bar, shieldEdge, absorb, false, reversed)
	Place(widgets.healAbsorb, bar, fill, healAbsorb, true, reversed)
	Place(widgets.backing, bar, fill, healAbsorb, true, reversed)
	widgets.backing:SetStatusBarColor(0, 0, 0, (healAbsorb.backing or 0) / 100)
	widgets.backing:SetShown(healAbsorb.enabled and (healAbsorb.backing or 0) > 0)

	-- The overshield is drawn across the whole bar and seen only where it overlaps the health fill.
	local attached = absorb.enabled and absorb.position == "attach"
	local overshieldClip, overshield = widgets.overshieldClip, widgets.overshield

	overshieldClip:ClearAllPoints()
	overshieldClip:SetPoint(reversed and "TOPRIGHT" or "TOPLEFT", bar)
	overshieldClip:SetPoint(reversed and "BOTTOMLEFT" or "BOTTOMRIGHT", fill)
	overshield:ClearAllPoints()
	overshield:SetAllPoints(bar)
	overshield:SetReverseFill((absorb.overshield == "fromLeft") == reversed)
	AUI.Media:SetBarTexture(overshield, absorb.texture)
	overshield:SetStatusBarColor(absorb.color.r, absorb.color.g, absorb.color.b, absorb.color.a or 1)
	overshieldClip:SetShown(attached and absorb.overshield ~= "never")

	local glow = widgets.glow

	glow:ClearAllPoints()
	glow:SetPoint("TOP", bar)
	glow:SetPoint("BOTTOM", bar)
	glow:SetPoint("CENTER", fill, reversed and "LEFT" or "RIGHT")
	glow:SetWidth(GLOW_WIDTH)
	glow:SetShown(attached and absorb.glow == true)

	local marker = widgets.marker
	local markerColor = prediction.color

	marker:ClearAllPoints()
	marker:SetPoint(reversed and "LEFT" or "RIGHT", bar)
	marker:SetSize(MARKER_WIDTH, bar:GetHeight() / 2)
	marker:SetVertexColor(markerColor.r, markerColor.g, markerColor.b, 1)
	marker:SetShown(prediction.enabled and prediction.position == "attach")

	if health then
		health.incomingHealOverflow = 1 + (prediction.overheal or 0) / 100

		local values = health.values

		if values then
			values:SetIncomingHealOverflowPercent(health.incomingHealOverflow)
		end
	end
end

---Feeds the overshield, glow and backing bars after oUF updated the three main bars. The shield amount is passed
---straight from bar to bar; whether the shield exceeds the empty space comes from the calculator's flag, read in
---the missing-health mode and switched back, so no hidden value is tested in Lua.
---@param widgets AUIOverlayWidgets
---@param values table the health element's heal-prediction calculator
function Overlays:Update(widgets, values)
	local settings = widgets.settings

	if not settings then
		return
	end

	local absorb = widgets.absorb

	if widgets.overshieldClip:IsShown() then
		local minimum, maximum = absorb:GetMinMaxValues()

		widgets.overshield:SetMinMaxValues(minimum, maximum)
		widgets.overshield:SetValue(absorb:GetValue())
		values:SetDamageAbsorbClampMode(Enum.UnitDamageAbsorbClampMode.MissingHealthWithoutIncomingHeals)

		local _, exceeds = values:GetDamageAbsorbs()

		values:SetDamageAbsorbClampMode(Enum.UnitDamageAbsorbClampMode.MaximumHealth)
		widgets.overshieldClip:SetAlphaFromBoolean(exceeds, 1, 0)
	end

	if widgets.glow:IsShown() then
		widgets.glow:SetValue(absorb:GetValue())
	end

	if widgets.backing:IsShown() then
		local minimum, maximum = widgets.healAbsorb:GetMinMaxValues()

		widgets.backing:SetMinMaxValues(minimum, maximum)
		widgets.backing:SetValue(widgets.healAbsorb:GetValue())
	end
end

---The sample amounts the calculator would return, for the settings preview. Heal absorbs and incoming heals cancel
---each other; incoming heals stop at the empty space plus Overheal; shields and heal absorbs are limited to maximum
---health and trimmed by the bar.
---@param sample table `health`, `absorb`, `healAbsorb` and `healing`, each a share of maximum health
---@param overheal number 0 to 50, percent of the bar's length heals may pass its end
---@return number healing
---@return number healAbsorb
---@return number absorb
---@return boolean healingExceeds
---@return boolean absorbExceeds the shield is larger than the empty space
function Overlays:SampleAmounts(sample, overheal)
	local room = 1 - sample.health
	local net = sample.healing - sample.healAbsorb
	local healing = math.max(net, 0)
	local limit = room + overheal / 100

	return math.min(healing, limit), math.min(math.max(-net, 0), 1), math.min(sample.absorb, 1), healing > limit,
		sample.absorb > room
end

---Shows sample amounts, for the settings preview: every amount as a share of maximum health, plain numbers.
---@param widgets AUIOverlayWidgets
---@param sample table `health`, `absorb`, `healAbsorb` and `healing`, each 0 to 1 of maximum health
---@param overheal number 0 to 50, percent of the bar's length heals may pass its end
function Overlays:ShowSample(widgets, sample, overheal)
	local healing, healAbsorb, absorb, healingExceeds, absorbExceeds = self:SampleAmounts(sample, overheal)

	for _, overlay in ipairs({ widgets.healing, widgets.absorb, widgets.healAbsorb, widgets.backing, widgets.overshield }) do
		overlay:SetMinMaxValues(0, 1)
	end

	widgets.healing:SetValue(healing)
	widgets.absorb:SetValue(absorb)
	widgets.healAbsorb:SetValue(healAbsorb)
	widgets.backing:SetValue(healAbsorb)
	widgets.overshield:SetValue(absorb)
	widgets.overshieldClip:SetAlpha(absorbExceeds and 1 or 0)
	widgets.glow:SetValue(absorb)
	widgets.marker:SetAlpha(healingExceeds and 1 or 0)
end
