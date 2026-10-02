local AUI = select(2, ...)

local L = AUI.L
local Schema = AUI.Schema

-- Space around the sample inside the preview panel.
local PAD = 12

-- Room kept above and below the bar for text on or past its edges, beyond the text size.
local TEXT_ROOM = 6

-- Sample health and power maximums.
local HEALTH_MAX = 588000
local POWER_MAX = 30000

-- Sample states by page: the label shown, then how full the bar is and any status.
local STATE_FULL, STATE_DAMAGED = L["Full"], L["Damaged"]
local STATE_HALF, STATE_EMPTY = L["Half"], L["Empty"]

local UNIT_STATES = {
	{ label = STATE_FULL, fill = 1 },
	{ label = STATE_DAMAGED, fill = 0.35 },
	{ label = DEAD, fill = 0, status = DEAD },
	{ label = PLAYER_OFFLINE, fill = 0, status = PLAYER_OFFLINE, offline = true },
}

-- Frames with health overlays add states that show them; amounts are shares of maximum health.
local OVERLAY_STATES = {
	{ label = L["Absorbs"], fill = 0.6, overlays = { health = 0.6, absorb = 0.25, healAbsorb = 0, healing = 0.15 } },
	{ label = L["Overflow"], fill = 0.3, overlays = { health = 0.3, absorb = 0.9, healAbsorb = 0.5, healing = 0 } },
}

local NO_OVERLAYS = { health = 0, absorb = 0, healAbsorb = 0, healing = 0 }

-- Group frames add a state that empties one slot, which keeps its place.
local GROUP_STATES = {
	{ label = L["Slot Lost"], fill = 1, lost = 2 },
}

-- How many samples a group's preview shows.
local GROUP_SAMPLES = 3

-- Frames with a cast bar add states that show its looks. Every other state shows the ordinary sample cast.
local CAST = { progress = 0.6, remaining = 1.2 }

local CAST_STATES = {
	{ label = L["Casting"], fill = 1, cast = CAST },
	{ label = L["Channeling"], fill = 1, cast = { progress = 0.6, remaining = 1.8, channel = true, ticks = 5 } },
	{ label = L["Not Interruptible"], fill = 1, cast = { progress = 0.6, remaining = 1.2, locked = true } },
	{ label = INTERRUPTED, fill = 1, cast = { progress = 1, remaining = 0, failed = INTERRUPTED } },
}

-- Attached cast bars add your interrupt's colors and cooldown mark, and the important-spell glow.
local KICK_STATES = {
	{ label = L["Interrupt Ready"], fill = 1, cast = { progress = 0.25, remaining = 1.5, mark = 0.4 } },
	{ label = L["Important"], fill = 1, cast = { progress = 0.6, remaining = 1.2, important = true } },
}

-- The player's cast bar adds an empowered cast with three stages and the hold after them.
local EMPOWER_STATES = {
	{ label = L["Empowered"], fill = 1, cast = { progress = 0.6, remaining = 1.1, stages = { 0.3, 0.25, 0.25 } } },
}

local SAMPLE_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Sample aura icons, present on both clients.
local AURA_ICONS = {
	"Interface\\Icons\\Spell_Nature_Rejuvenation",
	"Interface\\Icons\\Spell_Holy_PowerWordShield",
	"Interface\\Icons\\Spell_Shadow_ShadowWordPain",
	"Interface\\Icons\\Spell_Fire_Immolation",
	"Interface\\Icons\\Spell_Frost_FrostNova",
	"Interface\\Icons\\Ability_Rogue_Rupture",
}

-- Sample debuff borders: Magic, Curse, Poison and Disease.
local DISPEL_COLORS = {
	{ r = 0.2, g = 0.6, b = 1 },
	{ r = 0.6, g = 0, b = 1 },
	{ r = 0, g = 0.6, b = 0 },
	{ r = 0.6, g = 0.4, b = 0 },
}

local POWER_STATES = {
	{ label = STATE_FULL, fill = 1 },
	{ label = STATE_HALF, fill = 0.5 },
	{ label = STATE_EMPTY, fill = 0 },
}

---Settings previews: a copy of each frame drawn by the same bar, border and text code as the live frames, with
---fixed sample values. The copies are ordinary frames, never secure ones.
---@class AUISettingsPreviews
---@field samples table<string, table> each sample's frame and regions by page and slot, created on first draw
local Previews = {
	samples = {},
}
AUI.SettingsPreviews = Previews

---@param states table[]
---@param label string?
---@return table state
local function FindState(states, label)
	for _, state in ipairs(states) do
		if state.label == label then
			return state
		end
	end

	return states[1]
end

---@param states table[]
---@return string[] labels
local function Labels(states)
	local labels = {}

	for index, state in ipairs(states) do
		labels[index] = state.label
	end

	return labels
end

-- The state the layout editor draws its samples in.
Previews.EDIT_STATE = UNIT_STATES[1]

---Creates a sample: a frame shaped like the live unit frame, with its bars, text, overlays and cast bar.
---@param key string
---@param parent Frame
---@param slot integer the sample's place in its group; 1 for a single frame
---@return table sample
function Previews:NewSample(key, parent, slot)
	local frame = CreateFrame("Frame", nil, parent)
	local main = CreateFrame("Frame", nil, frame)
	local bar, background, border = AUI.UnitFrame:CreateBar(main)

	bar:SetMinMaxValues(0, 1)

	local sample = {
		key = key,
		slot = slot,
		frame = frame,
		main = main,
		bar = bar,
		background = background,
		border = border,
		Bar = bar,
	}

	-- The text code works on anything shaped like a unit frame's text: slots, a Status Line, and its bar.
	AUI.Text:Create(sample, bar, key)

	if Schema:Field("frames." .. key .. ".power.enabled") then
		local holder = CreateFrame("Frame", nil, frame)
		local power, powerBackground, powerBorder = AUI.UnitFrame:CreateBar(holder)

		power:SetMinMaxValues(0, 1)
		sample.powerHolder, sample.power = holder, power
		sample.powerBackground, sample.powerBorder = powerBackground, powerBorder
	end

	if AUI.Overlays:Resolve(AUI.Profile.config, key) then
		sample.overlays = AUI.Overlays:Create(bar)
	end

	if AUI.CastBar:Resolve(AUI.Profile.config, key) then
		sample.cast = AUI.CastBar:Create(frame)
	end

	return sample
end

---@param key string
---@param parent Frame the preview panel's sample frame
---@param slot integer the sample's place in its group; 1 for a single frame
---@return table sample the page's sample, created on first use
function Previews:Sample(key, parent, slot)
	local id = key .. slot
	local sample = self.samples[id]

	if not sample then
		sample = self:NewSample(key, parent, slot)
		self.samples[id] = sample
	end

	sample.frame:SetParent(parent)
	sample.frame:Show()

	return sample
end

---Hides every sample except a page's first `count`.
---@param key string
---@param count integer
function Previews:HideOthers(key, count)
	for _, sample in pairs(self.samples) do
		if sample.key ~= key or sample.slot > count then
			sample.frame:Hide()
		end
	end
end

---@return table? color the player's class color, unless it cannot be read
local function PlayerClassColor()
	local _, class = UnitClass("player")

	class = AUI:Readable(class)

	return class and AUI.oUF.colors.class[class]
end

---@return table color the player's power color
local function PlayerPowerColor()
	local _, token = UnitPowerType("player")
	local colors = AUI.oUF.colors.power

	token = AUI:Readable(token)

	return (token and colors[token]) or colors.MANA
end

---The sample a page shows in a state.
---@param key string
---@param state table
---@param slot integer? the sample's place in its group
---@return AUITextSample values
---@return table barColor
function Previews:Values(key, state, slot)
	local colors = AUI.oUF.colors
	local fill = state.fill
	local health = HEALTH_MAX * fill
	local values = {
		status = state.status,
		health = health,
		percent = fill * 100,
		missing = HEALTH_MAX - health,
		absorb = HEALTH_MAX * (state.overlays and state.overlays.absorb or 0),
		healAbsorb = HEALTH_MAX * (state.overlays and state.overlays.healAbsorb or 0),
		power = POWER_MAX * 0.8,
		powerPercent = 80,
	}
	local barColor

	if key == "target" or key == "focus" or key == "boss" or key == "pet" then
		values.name = L["Sample Target"]

		if key == "focus" then
			values.name = L["Sample Focus"]
		elseif key == "boss" then
			values.name = L["Sample Boss %d"]:format(slot or 1)
		elseif key == "pet" then
			values.name = L["Sample Pet"]
		end

		-- A pet is friendly; the other samples are hostile.
		local reaction = colors.reaction[key == "pet" and 5 or 2]

		values.level = 60
		values.classColor = reaction
		values.powerColor = colors.power.MANA
		barColor = reaction
	else
		values.name = AUI:Readable(UnitName("player")) or PLAYER
		values.level = AUI:Readable(UnitLevel("player")) or 60
		values.classColor = PlayerClassColor()
		values.powerColor = PlayerPowerColor()
		barColor = values.classColor or colors.health
	end

	if key == "playerPower" then
		values.power = POWER_MAX * fill
		values.powerPercent = fill * 100
		barColor = values.powerColor
	end

	values.difficultyColor = GetCreatureDifficultyColor(values.level)

	if state.offline then
		barColor = colors.disconnected
	end

	return values, barColor
end

local function Ignore() end

-- Sample indicators: how each is drawn. The raid marker is the skull.
local INDICATOR_ART = {
	raid = { texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcons", coords = { 0.75, 1, 0.25, 0.5 } },
	combat = { atlas = "UI-HUD-UnitFrame-Player-CombatIcon" },
	leader = { atlas = "UI-HUD-UnitFrame-Player-Group-LeaderIcon" },
	pvp = { atlas = "UI-HUD-UnitFrame-Player-PVP-AllianceIcon" },
}

---Draws a sample's enabled indicators where the live frame would show them.
---@param sample table
---@param key string
---@param config table
---@param addPart fun(region: Region, settingID: string, ...)
local function DrawIndicators(sample, key, config, addPart)
	sample.indicators = sample.indicators or {}

	for _, name in ipairs({ "raid", "resting", "combat", "leader", "pvp", "classification" }) do
		local settings = AUI.Indicators:Resolve(config, key, name)
		local region = sample.indicators[name]

		if settings and not region then
			if name == "resting" then
				region = sample.main:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
				region:SetText("ZZZ")
			else
				region = sample.main:CreateTexture(nil, "OVERLAY", nil, 7)

				local art = INDICATOR_ART[name]

				if art and art.atlas then
					region:SetAtlas(art.atlas)
				elseif art then
					region:SetTexture(art.texture)
					region:SetTexCoord(unpack(art.coords))
				else
					region:SetTexture(AUI.Indicators.CLASSIFICATIONS.rareelite)
				end
			end

			sample.indicators[name] = region
		end

		if region then
			region:SetShown(settings ~= nil and settings.enabled)
		end

		if settings and settings.enabled then
			local point, relative = AUI.Text:Points(settings.anchor, settings.placement)

			region:ClearAllPoints()
			region:SetPoint(point, sample.main, relative, settings.x, settings.y)

			if name == "resting" then
				region:SetFont(AUI.Media:Font(Schema:Read(config, "frames." .. key .. ".text.font")), settings.size,
					AUI.Media:FontFlags(Schema:Read(config, "frames." .. key .. ".text.outline")))
			else
				region:SetSize(settings.size, settings.size)
			end

			addPart(region, name)
		end
	end
end

-- Where each sample icon's corner sits, as a rectangle against the frame's top left (y up).
local CORNER_RECTS = {
	BOTTOMLEFT = { 0, 1, 0, 1 },
	TOPLEFT = { 0, 1, -1, 0 },
	TOPRIGHT = { -1, 0, -1, 0 },
	BOTTOMRIGHT = { -1, 0, 0, 1 },
}

-- Each frame point against the frame's top left (y up), as shares of its width and height.
local FRAME_POINTS = {
	TOPLEFT = { 0, 0 },
	TOPRIGHT = { 1, 0 },
	BOTTOMLEFT = { 0, -1 },
	BOTTOMRIGHT = { 1, -1 },
}

---How far a frame's aura displays reach past its edges at their limits, for sizing the preview.
---@param config table
---@param key string
---@param width number
---@param height number
---@return number above
---@return number below
---@return number left
---@return number right
function Previews:AuraSpace(config, key, width, height)
	local above, below, left, right = 0, 0, 0, 0
	local clearAbove, clearBelow = AUI.Auras:Clearance(config, key)

	for _, kind in ipairs({ "buffs", "debuffs" }) do
		local settings = AUI.Auras:Resolve(config, key, kind)

		if settings and settings.enabled then
			local placement = AUI.Auras:Placement(settings, width, clearAbove, clearBelow)
			local frame = FRAME_POINTS[placement.relative] or FRAME_POINTS.TOPLEFT
			local corner = CORNER_RECTS[placement.point] or CORNER_RECTS.TOPLEFT
			local size = settings.size

			for _, offset in ipairs(AUI.Auras:IconOffsets(settings, placement, settings.limit)) do
				local x = frame[1] * width + placement.x + offset.x
				local y = frame[2] * height + placement.y + offset.y

				left = math.max(left, -(x + corner[1] * size))
				right = math.max(right, x + corner[2] * size - width)
				above = math.max(above, y + corner[4] * size)
				below = math.max(below, -height - (y + corner[3] * size))
			end
		end
	end

	return above, below, left, right
end

---Draws a sample's aura displays at their limits.
---@param sample table
---@param key string
---@param config table
---@param addPart fun(region: Region, settingID: string, ...)
local function DrawAuras(sample, key, config, addPart)
	local width = Schema:Read(config, "frames." .. key .. ".width")
	local clearAbove, clearBelow = AUI.Auras:Clearance(config, key)

	sample.auraIcons = sample.auraIcons or { buffs = {}, debuffs = {} }

	for kind, icons in pairs(sample.auraIcons) do
		local settings = AUI.Auras:Resolve(config, key, kind)
		local count = 0

		if settings and settings.enabled then
			count = settings.limit
			local placement = AUI.Auras:Placement(settings, width, clearAbove, clearBelow)
			local font = AUI.Media:Font(settings.font)
			local flags = AUI.Media:FontFlags(settings.outline)

			for index, offset in ipairs(AUI.Auras:IconOffsets(settings, placement, count)) do
				local icon = icons[index]

				if not icon then
					local frame = CreateFrame("Frame", nil, sample.frame)

					icon = {
						frame = frame,
						texture = frame:CreateTexture(nil, "ARTWORK"),
						border = frame:CreateTexture(nil, "BACKGROUND"),
						count = frame:CreateFontString(nil, "OVERLAY"),
						time = frame:CreateFontString(nil, "OVERLAY"),
					}
					icon.texture:SetAllPoints()
					icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
					-- The border is a colored backing one unit wider than the icon on each side.
					icon.border:SetPoint("TOPLEFT", -1, 1)
					icon.border:SetPoint("BOTTOMRIGHT", 1, -1)
					icons[index] = icon
				end

				local frame = icon.frame
				local dispel = DISPEL_COLORS[(index - 1) % #DISPEL_COLORS + 1]

				frame:SetSize(settings.size, settings.size)
				frame:ClearAllPoints()
				frame:SetPoint(placement.point, sample.frame, placement.relative, placement.x + offset.x,
					placement.y + offset.y)
				icon.texture:SetTexture(AURA_ICONS[(index - 1) % #AURA_ICONS + 1])
				icon.border:SetColorTexture(dispel.r, dispel.g, dispel.b, 1)
				icon.border:SetShown(kind == "debuffs" and settings.border)
				icon.count:SetFont(font, settings.countSize, flags)
				icon.count:ClearAllPoints()
				icon.count:SetPoint(settings.countCorner, frame, settings.countCorner, settings.countX, settings.countY)
				icon.count:SetText(index % 3 == 0 and "2" or "")
				icon.time:SetFont(font, settings.durationSize, flags)
				icon.time:ClearAllPoints()
				icon.time:SetPoint("CENTER", frame, "CENTER", settings.durationX, settings.durationY)
				icon.time:SetText(settings.duration and tostring(4 * index) or "")
				frame:Show()

				if index == 1 then
					addPart(frame, kind == "buffs" and "buffEnabled" or "debuffEnabled")
				end
			end
		end

		for index = count + 1, #icons do
			icons[index].frame:Hide()
		end
	end
end

---A frame's cast bar settings as its preview draws them: always under the sample, even the player's, which on
---screen stands on its own, and in the window's strata.
---@param config table
---@param key string
---@param standalone boolean? leave out a bar that stands on its own, which the layout editor places separately
---@return table? settings nil when the frame has no cast bar or it is off
function Previews:CastSettings(config, key, standalone)
	local settings = AUI.CastBar:Resolve(config, key)

	if not settings or not settings.enabled or (standalone and not settings.attached) then
		return nil
	end

	if not settings.attached then
		settings.attached, settings.side, settings.x, settings.y = true, "below", 0, 0
	end

	-- The sample draws in the settings window's own strata.
	settings.strata = nil

	return settings
end

---@param config table
---@param key string
---@param width number the sample's width
---@return number above the space a cast bar takes above the sample
---@return number below the space below it
---@return number width the wider of the sample and its cast bar
function Previews:CastSpace(config, key, width)
	local settings = self:CastSettings(config, key)

	if not settings then
		return 0, 0, width
	end

	local castWidth, castHeight = AUI.CastBar:Size(settings, width)
	local space = AUI.CastBar.GAP + castHeight + math.abs(settings.y)

	if settings.side == "above" then
		return space, 0, math.max(width, castWidth)
	end

	return 0, space, math.max(width, castWidth)
end

---Shows the sample cast for a state on cast bar widgets.
---@param cast AUICastBarWidgets
---@param state table
function Previews:ShowCast(cast, state)
	local sampleCast = state.cast or CAST

	AUI.CastBar:ShowSample(cast, {
		name = L["Sample Spell"],
		icon = SAMPLE_ICON,
		progress = sampleCast.progress,
		remaining = sampleCast.remaining,
		channel = sampleCast.channel,
		locked = sampleCast.locked,
		failed = sampleCast.failed,
		stages = sampleCast.stages,
		ticks = sampleCast.ticks,
		mark = sampleCast.mark,
		important = sampleCast.important,
		target = AUI:Readable(UnitName("player")) or PLAYER,
		targetColor = PlayerClassColor(),
	})
end

---Draws one sample in a state.
---@param sample table
---@param key string
---@param config table
---@param state table
---@param addPart fun(region: Region, settingID: string, ...)
---@param editing boolean? for the layout editor, which places a cast bar standing on its own separately
local function DrawSample(sample, key, config, state, addPart, editing)
	local base = "frames." .. key .. "."
	local main, powerHeight = AUI.UnitFrame:Heights(config, key)
	local values, barColor = Previews:Values(key, state, sample.slot)
	local bar = sample.bar
	local pixel = AUI:Pixel(sample.frame)
	local reverse = Schema:Read(config, base .. "reverse") == true

	sample.main:ClearAllPoints()
	sample.main:SetPoint("TOPLEFT")
	sample.main:SetPoint("TOPRIGHT")
	sample.main:SetHeight(main)
	AUI.UnitFrame:StyleBar(bar, sample.background, sample.border,
		AUI.UnitFrame:BarLook(config, key, key == "playerPower"), pixel)

	if sample.powerHolder then
		local holder, power = sample.powerHolder, sample.power

		holder:SetShown(powerHeight > 0)

		if powerHeight > 0 then
			local color = values.powerColor or AUI.oUF.colors.power.MANA

			holder:ClearAllPoints()
			holder:SetPoint("TOPLEFT", sample.main, "BOTTOMLEFT")
			holder:SetPoint("TOPRIGHT", sample.main, "BOTTOMRIGHT")
			holder:SetHeight(powerHeight)
			AUI.UnitFrame:StyleBar(power, sample.powerBackground, sample.powerBorder,
				AUI.UnitFrame:BarLook(config, key, true), pixel)
			power:SetReverseFill(reverse)
			AUI.UnitFrame:AnchorBackground(power, sample.powerBackground, reverse)
			power:SetValue(values.status and 0 or values.powerPercent / 100)
			power:SetStatusBarColor(color.r, color.g, color.b)
			addPart(power, "powerHeight")
		end
	end

	bar:SetReverseFill(reverse)
	AUI.UnitFrame:AnchorBackground(bar, sample.background, reverse)
	bar:SetValue(key == "playerPower" and values.powerPercent / 100 or values.percent / 100)

	local healthColors = AUI.HealthColor:Resolve(config, key)

	if healthColors then
		local hostile = key == "target" or key == "focus" or key == "boss"
		local fill, backdrop = AUI.HealthColor:Sample(healthColors, {
			connected = not state.offline,
			tapDenied = false,
			classColor = not hostile and key ~= "pet" and values.classColor or nil,
			reaction = key == "pet" and 5 or 2,
		}, values.percent / 100, state.status == DEAD)

		AUI.HealthColor:Paint(bar, sample.background, healthColors, fill, backdrop)
	else
		bar:SetStatusBarColor(barColor.r, barColor.g, barColor.b)
	end
	addPart(bar, key == "playerPower" and "width" or "reverse")

	local cast = sample.cast
	local castSettings = cast and Previews:CastSettings(config, key, editing)

	if cast and castSettings then
		AUI.CastBar:Apply(cast, castSettings, sample.frame, sample.frame:GetWidth())
		Previews:ShowCast(cast, state)
		addPart(cast.bar, "castEnabled")
	elseif cast then
		cast.bar:Hide()
		cast.holder:Hide()
	end

	if Schema:Field("frames." .. key .. ".buffs.enabled") then
		DrawAuras(sample, key, config, addPart)
	end

	DrawIndicators(sample, key, config, addPart)

	local settings = sample.overlays and AUI.Overlays:Resolve(config, key)

	if settings then
		AUI.Overlays:Apply(sample.overlays, settings, reverse, nil)
		AUI.Overlays:ShowSample(sample.overlays, state.overlays or NO_OVERLAYS, settings.healPrediction.overheal)
	end

	local slots, widths, contexts = AUI.Text:Layout(config, key, #sample.TextSlots)

	sample.slotWidths = widths
	sample.middleSlots = {}

	for index, slot in ipairs(slots) do
		local text = sample.TextSlots[index]
		local shown = AUI.Tags:Sample(slot, contexts[index], values)

		if shown then
			if AUI.Text:InMiddleRow(slot) then
				sample.middleSlots[index] = true
			end

			AUI.Text:Place(text, bar, slot, widths[index])
			text:SetText(shown)
			text:Show()
			addPart(text, "slot", true, index)
		else
			text:Hide()
		end
	end

	local line = sample.StatusLine

	if line then
		local showLine = AUI.Text:NeedsStatusLine(config, key)

		line:SetText(showLine and values.status or "")
		line:SetShown(showLine)

		if showLine then
			AUI.Text:PlaceStatusLine(line, bar, config, key)
			addPart(line, "statusLine", true)
		end

		AUI.Text:FitStatusLine(sample)
	end
end

---Draws a sample for the layout editor, in the editor's state, with no settings parts.
---@param sample table from `NewSample`
---@param key string
---@param config table
function Previews:DrawEditSample(sample, key, config)
	DrawSample(sample, key, config, self.EDIT_STATE, Ignore, true)
end

---Draws the player's cast bar for the layout editor, centered on `anchor`.
---@param cast AUICastBarWidgets from `CastBar:Create`
---@param config table
---@param anchor Region
function Previews:DrawEditCast(cast, config, anchor)
	local settings = AUI.CastBar:Resolve(config, "player")

	if not settings then
		return
	end

	settings.x, settings.y, settings.strata = 0, 0, nil

	AUI.CastBar:Apply(cast, settings, anchor, anchor:GetWidth())
	self:ShowCast(cast, self.EDIT_STATE)
end

---@param key string
---@param states table[]
---@param stateKey string? pages with the same state list share the chosen state
---@return table preview
local function Preview(key, states, stateKey)
	local count = Schema:Field("frames." .. key .. ".growth") and GROUP_SAMPLES or 1

	return {
		states = Labels(states),
		stateKey = stateKey,
		Pick = function(index)
			local window = AUI.Settings.window

			if type(index) == "number" and window then
				AUI.SettingsText:Choose(key, index)
				window:SetPreviewChosen(index)
				window:RefreshPage()
			end
		end,
		Draw = function(parent, label, addPart)
			local config = AUI.Profile.config
			local base = "frames." .. key .. "."
			local width = Schema:Read(config, base .. "width")
			local main, powerHeight = AUI.UnitFrame:Heights(config, key)
			local height = main + powerHeight
			local room = Schema:Read(config, base .. "text.size") + TEXT_ROOM
			local castAbove, castBelow, fullWidth = Previews:CastSpace(config, key, width)
			local auraAbove, auraBelow, auraLeft, auraRight = Previews:AuraSpace(config, key, width, height)
			local topMargin = math.max(room + castAbove, auraAbove)
			local bottomMargin = math.max(room + castBelow, auraBelow)
			local rightMargin = math.max(fullWidth - width, auraRight)
			local state = FindState(states, label)
			local offsets, left, right, top, bottom = {}, 0, 0, 0, 0

			for slot = 1, count do
				local x, y = AUI.UnitFrame:SlotOffset(config, key, count > 1 and slot or nil)

				offsets[slot] = { x = x, y = y }
				left, right = math.min(left, x), math.max(right, x)
				top, bottom = math.max(top, y), math.min(bottom, y)
			end

			Previews:HideOthers(key, count)

			-- Only the first sample's regions open settings, so each setting is reached from one place.
			for slot = 1, count do
				local sample = Previews:Sample(key, parent, slot)
				local offset = offsets[slot]

				sample.frame:SetSize(width, height)
				sample.frame:ClearAllPoints()
				sample.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + auraLeft + offset.x - left,
					-(PAD + topMargin + top - offset.y))
				DrawSample(sample, key, config, state, slot == 1 and addPart or Ignore)
				sample.frame:SetShown(state.lost ~= slot)
			end

			local window = AUI.Settings.window

			if window then
				window:SetPreviewChosen(AUI.SettingsText:Chosen(key))
			end

			return width + auraLeft + rightMargin + right - left + PAD * 2,
				height + top - bottom + topMargin + bottomMargin + PAD * 2
		end,
	}
end

---@param ... table[] state lists
---@return table[] states
local function Join(...)
	local states = {}

	for index = 1, select("#", ...) do
		for _, state in ipairs((select(index, ...))) do
			states[#states + 1] = state
		end
	end

	return states
end

-- Each class's sample resource: its oUF power color, how many segments, and whether talents can charge them.
local RESOURCES = {
	DEATHKNIGHT = { power = "RUNES", count = 6 },
	EVOKER = { power = "ESSENCE", count = 5 },
	MAGE = { power = "ARCANE_CHARGES", count = 4 },
	MONK = { power = "CHI", count = 5 },
	PALADIN = { power = "HOLY_POWER", count = 5 },
	WARLOCK = { power = "SOUL_SHARDS", count = 5 },
}

local COMBO_POINTS = { power = "COMBO_POINTS", count = 5, charged = true }

local RESOURCE_STATES = {
	{ label = STATE_FULL, filled = 1 },
	{ label = L["Partial"], filled = 0.5 },
	{ label = STATE_EMPTY, filled = 0 },
	{ label = L["Charged"], filled = 1, charged = true },
}

---@return table resource the player's class resource for the preview; combo points for a class without one
local function PlayerResource()
	local _, class = UnitClass("player")

	class = AUI:Readable(class)

	return class and RESOURCES[class] or COMBO_POINTS
end

---Creates a class resource sample: its segments, extra mana bar and count, in a frame of its own.
---@param parent Frame
---@return table sample
function Previews:NewClassPowerSample(parent)
	local frame = CreateFrame("Frame", nil, parent)
	local sample = { frame = frame, segments = {} }

	sample.count = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")

	for index = 1, 10 do
		sample.segments[index] = AUI.ClassPower:CreateSegment(frame)
	end

	sample.extra = AUI.ClassPower:CreateSegment(frame)

	return sample
end

---Draws a class resource sample in a state, sizing its frame; the caller places the frame.
---@param sample table from `NewClassPowerSample`
---@param config table
---@param state table
---@param addPart fun(region: Region, settingID: string, ...)
---@return number width
---@return number height
function Previews:DrawClassPower(sample, config, state, addPart)
	local settings = AUI.ClassPower:Resolve(config)
	local resource = PlayerResource()
	local colors = AUI.oUF.colors.power
	local color = colors[resource.power] or colors.MANA
	local height = AUI.ClassPower:Height(settings)
	local frame, segments, extra, count = sample.frame, sample.segments, sample.extra, sample.count
	local pixel = AUI:Pixel(frame)

	frame:SetSize(settings.width, height)
	frame:Show()

	if settings.classColor then
		color = PlayerClassColor() or color
	end

	local partialIndex = math.ceil(resource.count * state.filled)

	for index = 1, 10 do
		segments[index]:Hide()
	end

	for index, spot in ipairs(AUI.ClassPower:Segments(settings.width, resource.count, settings.spacing)) do
		local segment = segments[index] --[[@as table]]
		local value = 0

		if state.filled == 1 or index < partialIndex then
			value = 1
		elseif index == partialIndex and state.filled > 0 then
			value = 0.5
		end

		local charged = state.charged and resource.charged and (index == 2 or index == 4)
		local shade = settings.darkenPartial and value > 0 and value < 1

		AUI.ClassPower:PlaceSegment(segment, frame, spot.x, 0, spot.w, settings.height, settings, pixel)
		segment:SetValue(value)
		segment:SetStatusBarColor(AUI.ClassPower:Shade(charged and settings.chargedColor or color, shade))
		segment.Text:SetText("")
		segment:Show()
		addPart(segment, index == 1 and "width" or "spacing")
	end

	extra:SetShown(settings.extraMana)

	if settings.extraMana then
		local mana = colors.MANA

		AUI.ClassPower:PlaceSegment(extra, frame, 0, settings.height + AUI.ClassPower.GAP, settings.width,
			settings.extraManaHeight, settings, pixel)
		extra:SetValue(0.7)
		extra:SetStatusBarColor(mana.r, mana.g, mana.b)
		addPart(extra, "extraManaHeight")
	end

	count:SetFont(AUI.Media:Font(settings.font), settings.textSize, AUI.Media:FontFlags(settings.outline))
	count:ClearAllPoints()
	count:SetPoint("CENTER", frame, "TOPLEFT", settings.width / 2, -settings.height / 2)
	count:SetText(settings.text and tostring(math.floor(resource.count * state.filled)) or "")

	return settings.width, height
end

-- The state the layout editor draws the class resource in.
Previews.EDIT_RESOURCE_STATE = RESOURCE_STATES[1]

---@return table preview the Class Resource page's preview
local function ClassPowerPreview()
	local sample

	return {
		states = Labels(RESOURCE_STATES),
		Draw = function(parent, label, addPart)
			if not sample then
				sample = Previews:NewClassPowerSample(parent)
				-- Listed with the unit samples, so a page change hides it like the others.
				Previews.samples.classPower = { key = "classPower", slot = 1, frame = sample.frame }
			end

			local frame = sample.frame

			Previews:HideOthers("classPower", 1)

			frame:SetParent(parent)
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -PAD)

			local width, height = Previews:DrawClassPower(sample, AUI.Profile.config, FindState(RESOURCE_STATES, label),
				addPart)

			return width + PAD * 2, height + PAD * 2
		end,
	}
end

---@param pageID string
---@return table? preview the page's preview, or nil for a page without one
function Previews:For(pageID)
	if pageID == "classPower" then
		return ClassPowerPreview()
	end

	if pageID == "player" or pageID == "target" or pageID == "focus" then
		if pageID == "player" then
			return Preview(pageID, Join(UNIT_STATES, OVERLAY_STATES, CAST_STATES, EMPOWER_STATES), "player")
		end

		return Preview(pageID, Join(UNIT_STATES, OVERLAY_STATES, CAST_STATES, KICK_STATES), "overlays")
	end

	if pageID == "boss" then
		return Preview(pageID, Join(UNIT_STATES, OVERLAY_STATES, CAST_STATES, KICK_STATES, GROUP_STATES), "group")
	end

	if pageID == "targettarget" or pageID == "pet" then
		return Preview(pageID, UNIT_STATES, "unit")
	end

	if pageID == "playerPower" then
		return Preview(pageID, POWER_STATES)
	end
end
