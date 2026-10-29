local AUI = select(2, ...)

local L = AUI.L

local PREVIEW_HEIGHT = 120
local ICON_MARKUP = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:16|t %s"

local VISIBILITY_LABELS = {
	ALWAYS = ALWAYS,
	GROUP = L["In Group"],
	GROUP_OR_TARGET = L["In Group or With a Target"],
}
local ORIENTATION_LABELS = {
	HORIZONTAL = L["Horizontal"],
	VERTICAL = L["Vertical"],
}
local FEEDBACK_LABELS = {
	highlight = L["Highlight Border"],
	grow = L["Grow on Hover"],
	press = L["Shrink on Press"],
}
local STYLE_LABELS = {
	FOREVER_MINIMAL = L["Forever Minimal"],
	FOREVER = L["Forever"],
	THIN_LINE = L["Thin Line"],
	NONE = NONE,
}

---The Raid Markers page, under the Quality of Life header: a sample bar as its preview, the Bar card headed by its
---switch, the Buttons, Layout and Border cards while the bar is on, and the World Marker Cycle card's key bindings and
---order. Changes take
---effect at once out of combat, and as combat ends otherwise.
---@class AUISettingsRaidMarkers
---@field sample AUIMarkerSample?
local SettingsRaidMarkers = {}
AUI.SettingsRaidMarkers = SettingsRaidMarkers

---@param values string[]
---@param labels table<string, string>
---@return table[] options
local function ChoiceOptions(values, labels)
	local options = {}

	for index, value in ipairs(values) do
		options[index] = { value = value, text = labels[value] }
	end

	return options
end

---@return boolean shown the bar is on, so the cards that shape it show
local function BarShown()
	return AUI.Profile:Get("markers.enabled") == true
end

---@param card table
---@param id string
---@param label string
---@param path string
local function Checkbox(card, id, label, path)
	card:Checkbox({
		id = id,
		label = label,
		path = path,
		default = AUI.Settings:Default(path),
		depends = "markersEnabled",
	})
end

---@param canvas Frame
---@param preview table
---@return number width
---@return number height
function SettingsRaidMarkers:RefreshPreview(canvas, preview)
	local Bar, Options = AUI.MarkerBar, AUI.MarkerOptions
	local sample = self.sample

	if not sample then
		sample = Bar:Build(canvas)
		sample:SetPoint("CENTER", canvas, "CENTER")
		self.sample = sample
	end

	Bar:Arrange(sample, Options:Kinds(Options:Get("markers.readyCheck"), Options:Get("markers.countdown")), false)
	preview:Part(sample, "markersSize")

	return sample:GetWidth(), sample:GetHeight()
end

---@param page table
function SettingsRaidMarkers:DeclareBar(page)
	local Settings, Options = AUI.Settings, AUI.MarkerOptions
	local card = page:Section("markersBar", L["Bar"])

	-- The cards hidden while the bar is off are found through this switch.
	card:Toggle({
		id = "markersEnabled",
		label = L["Show Bar"],
		path = "markers.enabled",
		default = Settings:Default("markers.enabled"),
		keywords = table.concat({ L["Buttons"], READY_CHECK, PLAYER_COUNTDOWN_BUTTON, L["Countdown Seconds"], L["Layout"],
			L["Orientation"], L["Button Size"], L["Spacing"], L["Border"], L["Border Style"], L["Border Color"],
			L["Border Thickness"] }, " "),
	})
	card:Dropdown({
		id = "markersVisibility",
		label = L["Visibility"],
		path = "markers.visibility",
		default = Settings:Default("markers.visibility"),
		depends = "markersEnabled",
		options = ChoiceOptions(Options.VISIBILITY, VISIBILITY_LABELS),
	})
	Checkbox(card, "markersMouseover", L["Show On Mouseover"], "markers.mouseover")
	Checkbox(card, "markersTooltips", L["Tooltips"], "markers.tooltips")
	local feedback = {}

	for _, value in ipairs(Options.FEEDBACK) do
		feedback[value] = Settings:Default("markers.feedback." .. value)
	end

	card:Dropdown({
		id = "markersFeedback",
		label = L["Button Feedback"],
		path = "markers.feedback",
		default = feedback,
		depends = "markersEnabled",
		multiple = true,
		options = ChoiceOptions(Options.FEEDBACK, FEEDBACK_LABELS),
	})
end

---@param page table
function SettingsRaidMarkers:DeclareButtons(page)
	local card = page:Section("markersButtons", L["Buttons"], { show = BarShown })

	Checkbox(card, "markersReadyCheck", READY_CHECK, "markers.readyCheck")
	Checkbox(card, "markersCountdown", PLAYER_COUNTDOWN_BUTTON, "markers.countdown")
	card:Slider({
		id = "markersSeconds",
		label = L["Countdown Seconds"],
		path = "markers.seconds",
		default = AUI.Settings:Default("markers.seconds"),
		depends = "markersCountdown",
		min = 1,
		max = 30,
		step = 1,
	})
end

---@param page table
function SettingsRaidMarkers:DeclareLayout(page)
	local Settings, Options = AUI.Settings, AUI.MarkerOptions
	local card = page:Section("markersLayout", L["Layout"], { show = BarShown })

	card:Dropdown({
		id = "markersOrientation",
		label = L["Orientation"],
		path = "markers.orientation",
		default = Settings:Default("markers.orientation"),
		depends = "markersEnabled",
		options = ChoiceOptions(Options.ORIENTATIONS, ORIENTATION_LABELS),
	})
	card:Slider({
		id = "markersSize",
		label = L["Button Size"],
		path = "markers.size",
		default = Settings:Default("markers.size"),
		depends = "markersEnabled",
		min = 16,
		max = 60,
		step = 1,
	})
	card:Slider({
		id = "markersSpacing",
		label = L["Spacing"],
		path = "markers.spacing",
		default = Settings:Default("markers.spacing"),
		depends = "markersEnabled",
		min = 0,
		max = 30,
		step = 1,
	})
end

---@param page table
function SettingsRaidMarkers:DeclareBorder(page)
	local Settings = AUI.Settings
	local options = ChoiceOptions(AUI.MarkerOptions.BORDER_STYLES, STYLE_LABELS)
	local card = page:Section("markersBorder", L["Border"], { show = BarShown })

	card:Dropdown({
		id = "markersBorderStyle",
		label = L["Border Style"],
		path = "markers.border.style",
		default = Settings:Default("markers.border.style"),
		depends = "markersEnabled",
		options = options,
	})
	card:Color({
		id = "markersBorderColor",
		resettable = true,
		label = L["Border Color"],
		path = "markers.border.color",
		default = Settings:Default("markers.border.color"),
		depends = "markersEnabled",
		blocked = function()
			local style = AUI.Profile:Get("markers.border.style")

			if style == "NONE" then
				return L["Needs a border style."]
			elseif style == "FOREVER" then
				return L["Forever keeps its own colors."]
			end
		end,
	})
	card:Slider({
		id = "markersBorderThickness",
		resettable = true,
		label = L["Border Thickness"],
		path = "markers.border.thickness",
		default = Settings:Default("markers.border.thickness"),
		depends = "markersEnabled",
		min = 50,
		max = 300,
		step = 10,
		format = "percent",
		blocked = function()
			local style = AUI.Profile:Get("markers.border.style")

			if style == "THIN_LINE" or style == "NONE" then
				return L["Needs a Forever border style."]
			end
		end,
	})
end

---@param page table
function SettingsRaidMarkers:DeclareCycle(page)
	local Options = AUI.MarkerOptions
	local shown = {}

	for _, name in ipairs(Options.NAMES) do
		shown[name] = AUI.Settings:Default("markers.cycle.show." .. name)
	end

	local card = page:Section("markersCycle", L["World Marker Cycle"])

	card:Button({
		id = "markersKeys",
		label = KEY_BINDINGS,
		description = L["Bind Place Next World Marker and Clear World Markers under AeonUI."],
		verb = L["Open"],
		run = function()
			Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID, BINDING_HEADER_AEONUI)
		end,
	})
	card:OrderedList({
		id = "markersCycleOrder",
		title = L["World Marker Order"],
		resettable = true,
		path = "markers.cycle.order",
		default = AUI.Settings:Default("markers.cycle.order"),
		items = function()
			local items = {}

			for index, name in ipairs(Options.NAMES) do
				items[index] = { value = name, text = ICON_MARKUP:format(index, _G["RAID_TARGET_" .. index] or name) }
			end

			return items
		end,
		enabled = { path = "markers.cycle.show", default = shown },
	})
end

---@param window table
function SettingsRaidMarkers:Declare(window)
	local can = AUI.can

	if not (can.raidMarkers or can.worldMarkers) then
		return
	end

	local page = window:Page("raidMarkers", {
		title = L["Raid Markers"],
		under = "qualityOfLifeHeader",
		icon = AUI.Media.sidebar.raidMarkers,
		iconTint = true,
	})

	if not page then
		return
	end

	if can.raidMarkers then
		page:Preview({
			height = PREVIEW_HEIGHT,
			refresh = function(canvas, _, preview)
				return SettingsRaidMarkers:RefreshPreview(canvas, preview)
			end,
		})
		self:DeclareBar(page)
		self:DeclareButtons(page)
		self:DeclareLayout(page)
		self:DeclareBorder(page)
	end

	if can.worldMarkers then
		self:DeclareCycle(page)
	end
end
