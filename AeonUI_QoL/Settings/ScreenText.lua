local AUI = select(2, ...)

local L = AUI.L
local lib = LibStub("LibAeonSettings-1.0")

-- Blizzard's sanctuary color, which the sample's zone lines take.
local SANCTUARY_R, SANCTUARY_G, SANCTUARY_B = 0.41, 0.8, 0.94
-- The room between the sample's two columns.
local COLUMN_GAP = 40
local PREVIEW_HEIGHT = 150
-- The sample's lines: the zone, subzone and territory, then an error and an objective.
local SAMPLE_LINES = { "zone", "subZone", "pvp", "messages", "messages" }
-- The sample's columns, left to right, as indexes into `SAMPLE_LINES`, each read top to bottom.
local SAMPLE_COLUMNS = { { 1, 2, 3 }, { 4, 5 } }

local LINE_LABELS = {
	messages = L["Errors and Objectives"],
	zone = ZONE,
	subZone = L["Subzone"],
	pvp = L["PvP Status"],
}

---The Screen Text page, under the Quality of Life header: the module's switch, a sample of every line as its preview,
---and the Text card, whose All Text row sets every line and whose line rows each follow it until set.
---@class AUISettingsScreenText
local SettingsScreenText = {}
AUI.SettingsScreenText = SettingsScreenText

---@param line string? a line; nil for the shared settings
---@return string id the line's Text row
local function DetailsID(line)
	return (line or "all") .. "Text"
end

---@param line string? a line; nil for the shared settings
---@return string summary the font and size, for a closed Text row
local function TextSummary(line)
	local Profile, Options = AUI.Profile, AUI.ScreenTextOptions

	return ("%s, %d%%"):format(tostring(Profile:Get(Options:Path(line, "font"))),
		Profile:Get(Options:Path(line, "size")) or 0)
end

---Adds a Text row that opens to a line's font, size and outline, or to the shared ones when `line` is nil.
---@param section table
---@param line string?
local function DeclareText(section, line)
	local Settings, Options = AUI.Settings, AUI.ScreenTextOptions
	local details = DetailsID(line)

	section:Details({
		id = details,
		label = line and LINE_LABELS[line] or L["All Text"],
		summary = function()
			return TextSummary(line)
		end,
	})

	local function Field(field, spec)
		spec.id = details .. "_" .. field
		spec.path = Options:Path(line, field)
		spec.default = Settings:Default(Options:Path(nil, field))
		spec.details = details

		if line then
			spec.inherits = { path = Options:Path(nil, field), from = L["All Text"] }
		else
			spec.resettable = true
		end

		return spec
	end

	section:Dropdown(Field("font", { label = L["Font"], picker = "font" }))
	section:Slider(Field("size", {
		label = L["Font Scale"],
		min = Options.MIN_SCALE,
		max = Options.MAX_SCALE,
		step = 5,
		format = "percent",
	}))
	section:Dropdown(Field("outline", { label = L["Outline"], options = lib.OUTLINES }))
end

---A sample of each line in its chosen style and Blizzard's color: the zone, subzone and territory, then an error and
---an objective.
---@class AUIScreenTextPreview
---@field texts FontString[] the sample's font strings, one for each of `SAMPLE_LINES`
local ScreenTextPreview = {
	texts = {},
}

---@param canvas Frame
function ScreenTextPreview:Create(canvas)
	for index = 1, #SAMPLE_LINES do
		self.texts[index] = canvas:CreateFontString(nil, "OVERLAY")
	end
end

---@param preview table
---@return number width
---@return number height
function ScreenTextPreview:Refresh(preview)
	local ScreenText = AUI.ScreenText
	local texts = self.texts
	local zone, subZone, pvp, errorLine, objectiveLine = texts[1], texts[2], texts[3], texts[4], texts[5]
	local subZoneText = GetSubZoneText()

	-- A font string without a font refuses text, so each line is styled first.
	for index, line in ipairs(SAMPLE_LINES) do
		ScreenText:Style(texts[index], line)
	end

	zone:SetText(GetZoneText())
	subZone:SetText(subZoneText ~= "" and subZoneText or LINE_LABELS.subZone)
	pvp:SetText(SANCTUARY_TERRITORY)
	errorLine:SetText(ERR_OUT_OF_RANGE)
	objectiveLine:SetText(ERR_QUEST_UNKNOWN_COMPLETE)

	for _, text in ipairs({ zone, subZone, pvp }) do
		text:SetTextColor(SANCTUARY_R, SANCTUARY_G, SANCTUARY_B)
	end

	errorLine:SetTextColor(RED_FONT_COLOR:GetRGB())
	objectiveLine:SetTextColor(YELLOW_FONT_COLOR:GetRGB())

	local widths, heights = {}, {}
	local width, height = 0, 0

	for column, indexes in ipairs(SAMPLE_COLUMNS) do
		widths[column], heights[column] = 0, 0

		for _, index in ipairs(indexes) do
			local text = texts[index]

			widths[column] = math.max(widths[column], math.ceil(text:GetUnboundedStringWidth()))
			heights[column] = heights[column] + math.ceil(text:GetStringHeight())
		end

		width = width + (column > 1 and COLUMN_GAP or 0) + widths[column]
		height = math.max(height, heights[column])
	end

	-- Each column's lines are centered across it, and the column is centered down the sample.
	local left = 0

	for column, indexes in ipairs(SAMPLE_COLUMNS) do
		local top = math.floor((height - heights[column]) / 2)

		for _, index in ipairs(indexes) do
			local text = texts[index]

			text:ClearAllPoints()
			text:SetPoint("TOP", text:GetParent(), "TOPLEFT", left + widths[column] / 2, -top)
			top = top + math.ceil(text:GetStringHeight())
			preview:Part(text, DetailsID(SAMPLE_LINES[index]), { text = true })
		end

		left = left + widths[column] + COLUMN_GAP
	end

	return width, height
end

---@return boolean
function SettingsScreenText:IsAvailable()
	return AUI.can.screenText == true
end

---@param window table
function SettingsScreenText:Declare(window)
	local Settings, Options = AUI.Settings, AUI.ScreenTextOptions
	local page = window:Page("screenText", {
		title = L["Screen Text"],
		under = "qualityOfLifeHeader",
		icon = AUI.Media.sidebar.screenText,
		iconTint = true,
		switch = {
			path = Options.ENABLED_PATH,
			default = Settings:Default(Options.ENABLED_PATH),
			label = L["Style Screen Text"],
		},
	})

	if not page then
		return
	end

	page:Preview({
		height = PREVIEW_HEIGHT,
		create = function(canvas)
			ScreenTextPreview:Create(canvas)
		end,
		refresh = function(_, _, preview)
			return ScreenTextPreview:Refresh(preview)
		end,
	})

	local card = page:Section("screenTextLines", L["Text"])

	DeclareText(card)

	for _, line in ipairs(Options.LINES) do
		DeclareText(card, line)
	end
end

AUI.Modules:Register({
	group = "qualityOfLife",
	page = SettingsScreenText,
	start = function()
		AUI.ScreenText:Start()
	end,
})
