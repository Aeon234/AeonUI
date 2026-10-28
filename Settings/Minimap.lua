local AUI = select(2, ...)

local L = AUI.L
local lib = LibStub("LibAeonSettings-1.0")

---The Minimap page, under the Maps header: the module's switch, the row layout editor as its preview, the map's size,
---fading, zoom, border and rows, then a card for each row element, headed by the element's own switch. The minimap's
---position is set in edit mode.
---@class AUISettingsMinimap
---@field pageIDs table<string, true> the pages showing the minimap's samples
---@field titles table<string, string> each row element's name, in its card and in the layout editor
local SettingsMinimap = {
	pageIDs = { minimap = true },
	titles = {},
}
AUI.SettingsMinimap = SettingsMinimap

local STYLE_LABELS = {
	METAL = L["Metal"],
	FOREVER_MINIMAL = L["Forever Minimal"],
	FOREVER = L["Forever"],
	THIN_LINE = L["Thin Line"],
	NONE = NONE,
}

---@param base string the text settings' path, ending in a dot
---@return string summary the font and size, for a closed Text row
local function TextSummary(base)
	local Profile = AUI.Profile

	return ("%s, %d"):format(tostring(Profile:Get(base .. "font")), Profile:Get(base .. "size") or 0)
end

---Adds a Text row that opens to the text settings: the rows' own (`key` nil), or an element's, each following the
---rows' until set.
---@param section table
---@param key string? the element
---@param colored boolean? offer the text color
---@param depends string? the setting the Text row follows
local function DeclareText(section, key, colored, depends)
	local Settings = AUI.Settings
	local base = key and "minimap." .. key .. ".text." or "minimap.text."
	local prefix = key or "rows"
	local details = prefix .. "Text"

	section:Details({
		id = details,
		label = L["Text"],
		depends = depends,
		summary = function()
			return TextSummary(base)
		end,
	})

	local function Field(field, spec)
		spec.id = prefix .. "Text_" .. field
		spec.path = base .. field
		spec.default = Settings:Default("minimap.text." .. field)
		spec.details = details

		if key then
			spec.inherits = { path = "minimap.text." .. field, from = L["All Rows"] }
		else
			spec.resettable = true
		end

		return spec
	end

	section:Dropdown(Field("font", { label = L["Font"], picker = "font" }))
	section:Slider(Field("size", { label = FONT_SIZE, min = 8, max = 24, step = 1 }))
	section:Dropdown(Field("outline", { label = L["Outline"], options = lib.OUTLINES }))
	section:Slider(Field("offsetY", {
		label = L["Y Offset"],
		min = -10,
		max = 10,
		step = 1,
	}))

	if colored or not key then
		local note = L["For the clock, coordinates and the addon count; the zone and difficulty have their own colors."]

		section:Color(Field("color", { label = L["Text Color"], description = not key and note or nil }))
	end
end

---@param value number
---@return string text the zoom reset delay, or Never for 0
local function ResetFormat(value)
	if value == 0 then
		return L["Never"]
	end

	return L["%d s"]:format(value)
end

local TIER_LABELS = {
	normal = PLAYER_DIFFICULTY1,
	heroic = PLAYER_DIFFICULTY2,
	mythic = PLAYER_DIFFICULTY6,
	lfr = PLAYER_DIFFICULTY3,
	other = OTHER,
}
local TIER_DESCRIPTIONS = {
	mythic = L["Mythic, and Mythic+ with its keystone level."],
	other = L["Timewalking, Follower, Delves, Story and PvP."],
}

-- The row elements' cards, in the order the default layout shows them. `needs` names the capability without which an
-- element is left out, `note` what its card's footer says, `iconSize` whether it offers the button's Icon Size, `text`
-- whether it offers text settings and `colored` whether those include a color.
local ELEMENTS = {
	{
		key = "zone",
		title = ZONE,
		description = L["Hover for the zone tooltip; click to open the world map."],
		text = true,
	},
	{
		key = "difficulty",
		title = L["Instance Difficulty"],
		description = L["Shown inside instances."],
		text = true,
	},
	{
		key = "clock",
		title = TIMEMANAGER_TITLE,
		description = L["Hover for the realm's and your local time."],
		text = true,
		colored = true,
	},
	{
		key = "mail",
		iconSize = true,
		title = MAIL_LABEL,
		description = L["Hover for the latest senders."],
		note = L["The button keeps its place in the row; its icon shows only while you have unread mail."],
	},
	{
		key = "craftingOrders",
		iconSize = true,
		needs = "craftingOrders",
		title = L["Crafting Orders"],
		description = L["Hover for each profession's count."],
		note = L["The button keeps its place in the row; its icon shows only while you have personal orders."],
	},
	{
		key = "tracking",
		iconSize = true,
		title = TRACKING,
		description = L["Opens the tracking menu."],
	},
	{
		key = "coordinates",
		title = L["Coordinates"],
		description = L["Hidden where the map has no coordinates."],
		text = true,
		colored = true,
	},
	{
		key = "calendar",
		iconSize = true,
		title = L["Calendar"],
		description = L["Opens the calendar. Pulses while you have invites."],
	},
	{
		key = "compartment",
		title = L["Addon Compartment"],
		description = L["Shown while an addon uses it, with how many."],
		text = true,
		colored = true,
	},
}

---@param key string a row element's key
---@return string name its card's title
function SettingsMinimap:ElementTitle(key)
	if not next(self.titles) then
		for _, info in ipairs(ELEMENTS) do
			self.titles[info.key] = info.title
		end
	end

	return self.titles[key] or key
end

---@param page table
function SettingsMinimap:DeclareMap(page)
	local Settings = AUI.Settings
	local map = page:Section("map", L["Map"])

	map:Slider({
		id = "width",
		resettable = true,
		label = L["Width"],
		path = "minimap.width",
		default = Settings:Default("minimap.width"),
		min = 140,
		max = 400,
		step = 10,
		-- The width moves the height's limits.
		redraws = true,
	})
	map:Slider({
		id = "height",
		resettable = true,
		label = L["Height"],
		description = L["Kept within 3:2 of the width either way."],
		path = "minimap.height",
		default = Settings:Default("minimap.height"),
		min = function()
			local low = AUI.Minimap:HeightRange(AUI.Profile:Get("minimap.width"))

			return math.max(100, math.ceil(low / 10) * 10)
		end,
		max = function()
			local _, high = AUI.Minimap:HeightRange(AUI.Profile:Get("minimap.width"))

			return math.min(400, math.floor(high / 10) * 10)
		end,
		step = 10,
	})
	map:Slider({
		id = "scale",
		resettable = true,
		label = L["Scale"],
		path = "minimap.scale",
		default = Settings:Default("minimap.scale"),
		min = 50,
		max = 200,
		step = 5,
		format = "percent",
	})
	map:Note(L["The map stays north up; Rotate Minimap is ignored."])

	local fade = page:Section("fade", L["Fading"])

	fade:Checkbox({
		id = "fadeMouseover",
		label = L["Fade Until Mouseover"],
		path = "minimap.fade.mouseover",
		default = Settings:Default("minimap.fade.mouseover"),
	})
	fade:Slider({
		id = "fadeMouseoverOpacity",
		resettable = true,
		label = L["Mouseover Opacity"],
		path = "minimap.fade.mouseoverOpacity",
		default = Settings:Default("minimap.fade.mouseoverOpacity"),
		min = 0,
		max = 100,
		step = 5,
		format = "percent",
		depends = "fadeMouseover",
	})
	fade:Checkbox({
		id = "fadeCombat",
		label = L["Fade in Combat"],
		path = "minimap.fade.combat",
		default = Settings:Default("minimap.fade.combat"),
	})
	fade:Slider({
		id = "fadeCombatOpacity",
		resettable = true,
		label = L["Combat Opacity"],
		description = L["The mouse brings it back."],
		path = "minimap.fade.combatOpacity",
		default = Settings:Default("minimap.fade.combatOpacity"),
		min = 0,
		max = 100,
		step = 5,
		format = "percent",
		depends = "fadeCombat",
	})

	local zoom = page:Section("zoom", L["Zoom"])

	zoom:Checkbox({
		id = "wheelZoom",
		label = L["Zoom with Mouse Wheel"],
		path = "minimap.zoom.wheel",
		default = Settings:Default("minimap.zoom.wheel"),
	})
	zoom:Slider({
		id = "zoomReset",
		resettable = true,
		label = L["Reset Zoom After"],
		description = L["Returns to the widest view this long after the last zoom."],
		path = "minimap.zoom.reset",
		default = Settings:Default("minimap.zoom.reset"),
		min = 0,
		max = 60,
		step = 5,
		format = ResetFormat,
	})
end

---@param page table
function SettingsMinimap:DeclareBorder(page)
	local Settings = AUI.Settings
	local options = {}

	for index, style in ipairs(AUI.Border.STYLES) do
		options[index] = { value = style, text = STYLE_LABELS[style] }
	end

	local border = page:Section("border", L["Border"])

	border:Dropdown({
		id = "borderStyle",
		label = L["Border Style"],
		path = "minimap.border.style",
		default = Settings:Default("minimap.border.style"),
		options = options,
	})
	border:Color({
		id = "borderColor",
		resettable = true,
		label = L["Border Color"],
		path = "minimap.border.color",
		default = Settings:Default("minimap.border.color"),
		blocked = function()
			local style = AUI.Profile:Get("minimap.border.style")

			if style == "NONE" then
				return L["Needs a border style."]
			elseif style == "FOREVER" then
				return L["Forever keeps its own colors."]
			end
		end,
	})
	border:Slider({
		id = "borderThickness",
		resettable = true,
		label = L["Border Thickness"],
		description = L["Compared with Blizzard's own frames. A map too small for the corners draws them smaller."],
		path = "minimap.border.thickness",
		default = Settings:Default("minimap.border.thickness"),
		min = 50,
		max = 300,
		step = 10,
		format = "percent",
		blocked = function()
			local style = AUI.Profile:Get("minimap.border.style")

			if style == "THIN_LINE" or style == "NONE" then
				return L["Needs a Metal or Forever border style."]
			end
		end,
	})
	border:Color({
		id = "background",
		resettable = true,
		label = BACKGROUND,
		description = L["Shows behind the map's information rows."],
		path = "minimap.background",
		default = Settings:Default("minimap.background"),
		hasOpacity = true,
	})
end

---@param page table
function SettingsMinimap:DeclareRows(page)
	local Settings = AUI.Settings
	local Editor = AUI.MinimapEditor

	page:Preview({
		height = Editor:Height(),
		create = function(canvas)
			Editor:Create(canvas)
		end,
		refresh = function()
			return Editor:Draw()
		end,
		caption = function()
			return Editor:Caption()
		end,
	})

	local rows = page:Section("rows", L["Rows"])

	rows:Slider({
		id = "rowHeight",
		resettable = true,
		label = L["Row Height"],
		description = L["Buttons are square at this height."],
		path = "minimap.rows.height",
		default = Settings:Default("minimap.rows.height"),
		min = 16,
		max = 40,
		step = 1,
	})
	DeclareText(rows)
end

---Each element's card: its switch first, then its own settings, which leave while it is off.
---@param page table
function SettingsMinimap:DeclareElements(page)
	local Settings = AUI.Settings
	local first = true

	for _, info in ipairs(ELEMENTS) do
		if not info.needs or AUI.can[info.needs] then
			local key = info.key
			local switchPath = AUI.MinimapElements:EnabledPath(key)
			local card = page:Section(key, first and L["Elements"] or nil)

			first = false
			card:Toggle({
				id = key,
				label = info.title,
				description = info.description,
				path = switchPath,
				default = Settings:Default(switchPath),
			})

			if key == "zone" then
				card:Dropdown({
					id = "zoneColor",
					label = L["Zone Color"],
					path = "minimap.zone.color",
					default = Settings:Default("minimap.zone.color"),
					depends = key,
					options = {
						{ value = "PVP", text = L["By PvP Status"] },
						{ value = "GOLD", text = L["Gold"] },
					},
				})
			elseif key == "difficulty" then
				local difficulty = AUI.MinimapElements.byKey.difficulty --[[@as AUIMinimapDifficulty]]

				card:Details({
					id = "difficultyColors",
					label = L["Colors"],
					depends = key,
				})

				for _, tier in ipairs(difficulty.TIERS) do
					local path = "minimap.difficulty.colors." .. tier.key

					card:Color({
						id = "difficulty_" .. tier.key,
						resettable = true,
						label = TIER_LABELS[tier.key],
						description = TIER_DESCRIPTIONS[tier.key],
						path = path,
						default = Settings:Default(path),
						details = "difficultyColors",
					})
				end
			elseif key == "clock" then
				card:Checkbox({
					id = "twentyFour",
					label = TIMEMANAGER_24HOURMODE,
					path = "minimap.clock.twentyFour",
					default = Settings:Default("minimap.clock.twentyFour"),
					depends = key,
				})
				card:Checkbox({
					id = "localTime",
					label = TIMEMANAGER_LOCALTIME,
					description = L["Off shows the realm's time."],
					path = "minimap.clock.localTime",
					default = Settings:Default("minimap.clock.localTime"),
					depends = key,
				})
				card:Checkbox({
					id = "dayNight",
					label = L["Show Day and Night"],
					path = "minimap.clock.dayNight",
					default = Settings:Default("minimap.clock.dayNight"),
					depends = key,
				})
				card:Slider({
					id = "iconSize",
					resettable = true,
					label = L["Icon Size"],
					path = "minimap.clock.iconSize",
					default = Settings:Default("minimap.clock.iconSize"),
					min = 8,
					max = 32,
					step = 1,
					depends = "dayNight",
				})
			elseif key == "coordinates" then
				card:Slider({
					id = "precision",
					resettable = true,
					label = L["Decimal Places"],
					path = "minimap.coordinates.precision",
					default = Settings:Default("minimap.coordinates.precision"),
					min = 0,
					max = 2,
					step = 1,
					depends = key,
				})
			end

			if info.iconSize then
				local path = "minimap." .. key .. ".iconSize"

				card:Slider({
					id = key .. "IconSize",
					resettable = true,
					label = L["Icon Size"],
					description = L["Compared with the row's height."],
					path = path,
					default = Settings:Default(path),
					min = 50,
					max = 120,
					step = 5,
					format = "percent",
					depends = key,
				})
			end

			if info.text then
				DeclareText(card, key, info.colored, key)
			end

			if info.note then
				card:Note(info.note)
			end
		end
	end
end

---@param window table
function SettingsMinimap:Declare(window)
	local Settings = AUI.Settings
	local page = window:Page("minimap", {
		title = MINIMAP_LABEL,
		description = L["Replaces Blizzard's minimap. Turning it on or off needs a reload."],
		under = "mapsHeader",
		icon = AUI.Media.sidebar.minimap,
		iconTint = true,
		switch = { path = "minimap.enabled", default = Settings:Default("minimap.enabled") },
	})

	if not page then
		return
	end

	self:DeclareMap(page)
	self:DeclareBorder(page)
	self:DeclareRows(page)
	self:DeclareElements(page)
end
