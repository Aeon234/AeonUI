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

local POWER_STATES = {
	{ label = STATE_FULL, fill = 1 },
	{ label = STATE_HALF, fill = 0.5 },
	{ label = STATE_EMPTY, fill = 0 },
}

---Settings previews: a copy of each frame drawn by the same bar, border and text code as the live frames, with
---fixed sample values. The copies are ordinary frames, never secure ones.
---@class AUISettingsPreviews
---@field samples table<string, table> each page's sample frame and regions, created on first draw
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

---@param key string
---@param parent Frame the preview panel's sample frame
---@return table sample
function Previews:Sample(key, parent)
	local sample = self.samples[key]

	if not sample then
		local frame = CreateFrame("Frame", nil, parent)
		local main = CreateFrame("Frame", nil, frame)
		local bar, _, border = AUI.UnitFrame:CreateBar(main)

		bar:SetMinMaxValues(0, 1)
		sample = { frame = frame, main = main, bar = bar, border = border, Bar = bar }

		-- The text code works on anything shaped like a unit frame's text: slots, a Status Line, and its bar.
		AUI.Text:Create(sample, bar, key)

		if Schema:Field("frames." .. key .. ".power.enabled") then
			local holder = CreateFrame("Frame", nil, frame)
			local power, _, powerBorder = AUI.UnitFrame:CreateBar(holder)

			power:SetMinMaxValues(0, 1)
			sample.powerHolder, sample.power, sample.powerBorder = holder, power, powerBorder
		end

		self.samples[key] = sample
	end

	for other, cached in pairs(self.samples) do
		if other ~= key then
			cached.frame:Hide()
		end
	end

	sample.frame:SetParent(parent)
	sample.frame:Show()

	return sample
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
---@return AUITextSample values
---@return table barColor
function Previews:Values(key, state)
	local colors = AUI.oUF.colors
	local fill = state.fill
	local health = HEALTH_MAX * fill
	local values = {
		status = state.status,
		health = health,
		percent = fill * 100,
		missing = HEALTH_MAX - health,
		absorb = 0,
		healAbsorb = 0,
		power = POWER_MAX * 0.8,
		powerPercent = 80,
	}
	local barColor

	if key == "target" or key == "focus" then
		values.name = key == "focus" and L["Sample Focus"] or L["Sample Target"]
		values.level = 60
		values.classColor = colors.reaction[2]
		values.powerColor = colors.power.MANA
		barColor = colors.reaction[2]
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

---@param key string
---@param states table[]
---@return table preview
local function Preview(key, states)
	return {
		states = Labels(states),
		stateKey = key ~= "playerPower" and "unit" or nil,
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
			local sample = Previews:Sample(key, parent)
			local values, barColor = Previews:Values(key, FindState(states, label))
			local frame, bar = sample.frame, sample.bar
			local pixel = AUI:Pixel(frame)

			frame:SetSize(width, height)
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -(PAD + room))
			sample.main:ClearAllPoints()
			sample.main:SetPoint("TOPLEFT")
			sample.main:SetPoint("TOPRIGHT")
			sample.main:SetHeight(main)
			AUI.UnitFrame:LayoutBorder(sample.border, bar, pixel)

			if sample.powerHolder then
				local holder, power = sample.powerHolder, sample.power

				holder:SetShown(powerHeight > 0)

				if powerHeight > 0 then
					local color = values.powerColor or AUI.oUF.colors.power.MANA

					holder:ClearAllPoints()
					holder:SetPoint("TOPLEFT", sample.main, "BOTTOMLEFT")
					holder:SetPoint("TOPRIGHT", sample.main, "BOTTOMRIGHT")
					holder:SetHeight(powerHeight)
					AUI.UnitFrame:LayoutBorder(sample.powerBorder, power, pixel)
					power:SetReverseFill(Schema:Read(config, base .. "reverse") == true)
					power:SetValue(values.status and 0 or values.powerPercent / 100)
					power:SetStatusBarColor(color.r, color.g, color.b)
					addPart(power, "powerHeight")
				end
			end

			bar:SetReverseFill(Schema:Read(config, base .. "reverse") == true)
			bar:SetValue(key == "playerPower" and values.powerPercent / 100 or values.percent / 100)
			bar:SetStatusBarColor(barColor.r, barColor.g, barColor.b)
			addPart(bar, key == "playerPower" and "width" or "reverse")

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

			local window = AUI.Settings.window

			if window then
				window:SetPreviewChosen(AUI.SettingsText:Chosen(key))
			end

			return width + PAD * 2, height + (PAD + room) * 2
		end,
	}
end

---@param pageID string
---@return table? preview the page's preview, or nil for a page without one
function Previews:For(pageID)
	if pageID == "player" or pageID == "target" or pageID == "targettarget" or pageID == "focus" then
		return Preview(pageID, UNIT_STATES)
	end

	if pageID == "playerPower" then
		return Preview(pageID, POWER_STATES)
	end
end
