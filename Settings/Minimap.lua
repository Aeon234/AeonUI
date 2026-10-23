local AUI = select(2, ...)

local L = AUI.L
local lib = LibStub("LibAeonSettings-1.0")

---The Minimap header and its pages: Map (size, fading, zoom), Border, Rows, and a page for each element with settings.
---Map, Border and Rows carry the module's switch; each element's page carries that element's. The minimap's position
---is set in edit mode.
---@class AUISettingsMinimap
local SettingsMinimap = {}
AUI.SettingsMinimap = SettingsMinimap

local STYLE_LABELS = {
	METAL = L["Metal"],
	FOREVER_MINIMAL = L["Forever Minimal"],
	FOREVER = L["Forever"],
	THIN_LINE = L["Thin Line"],
	NONE = NONE,
}

---Adds the text settings to a section: the rows' own (`key` nil), or an element's, each following the rows' until set.
---@param section table
---@param key string? the element
---@param colored boolean? offer the text color
local function DeclareText(section, key, colored)
	local Settings = AUI.Settings
	local base = key and "minimap." .. key .. ".text." or "minimap.text."
	local prefix = key or "rows"

	local function Field(field, spec)
		spec.id = prefix .. "Text_" .. field
		spec.path = base .. field
		spec.default = Settings:Default("minimap.text." .. field)

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
		description = L["Raises the text, or lowers it below 0, to sit it in the middle of the row."],
		min = -10,
		max = 10,
		step = 1,
	}))

	if colored or not key then
		local note =
			L["For the clock, coordinates and the addon count; the zone and instance difficulty have colors of their own."]

		section:Color(Field("color", { label = L["Text Color"], description = not key and note or nil }))
	end

	if not key then
		section:Note(L["Each element's page can change its own font, size, outline, offset and color."])
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

-- The header's pages in sidebar order. `minimap` is the page edit mode's Element Options opens; `element` names the row
-- element a page belongs to, `needs` the capability without which it is left out, and `note` what a button's page says
-- about it.
local PAGES = {
	{ id = "minimap", title = L["Map"], description = L["The map's size, fading and zoom. Move it in Edit Mode."] },
	{ id = "minimapBorder", title = L["Border"], description = L["The frame around the map and its rows."] },
	{ id = "minimapRows", title = L["Rows"], description = L["The information rows above and below the map."] },
	{
		id = "minimapZone",
		element = "zone",
		title = ZONE,
		description = L["The zone's name. Hover it for Blizzard's zone tooltip; click it to open the world map."],
	},
	{
		id = "minimapClock",
		element = "clock",
		title = TIMEMANAGER_TITLE,
		description = L["The time, with day and night. Hover it for both the realm's and your local time."],
	},
	{
		id = "minimapDifficulty",
		element = "difficulty",
		title = L["Instance Difficulty"],
		description = L["The instance's difficulty beside the zone, shown inside an instance."],
	},
	{
		id = "minimapCoordinates",
		element = "coordinates",
		title = L["Coordinates"],
		description = L["Your position on the map, where the map has one."],
	},
	{
		id = "minimapMail",
		element = "mail",
		title = MAIL_LABEL,
		description = L["Unread mail. Hover it for the latest senders."],
		note = L["The button keeps its place in the row; its icon shows only while you have unread mail."],
	},
	{
		id = "minimapCraftingOrders",
		element = "craftingOrders",
		needs = "craftingOrders",
		title = L["Crafting Orders"],
		description = L["Personal crafting orders waiting for you. Hover it for each profession's count."],
		note = L["The button keeps its place in the row; its icon shows only while you have personal orders."],
	},
	{
		id = "minimapTracking",
		element = "tracking",
		title = TRACKING,
		description = L["Opens Blizzard's tracking menu, to choose what the map shows."],
		note = L["The menu is Blizzard's own, so it lists what this game version can track."],
	},
	{
		id = "minimapCalendar",
		element = "calendar",
		title = L["Calendar"],
		description = L["Shows or hides the calendar. On Retail its icon shows the day of the month."],
		note = L["It pulses while you have calendar invites; a click then opens the calendar on them."],
	},
	{
		id = "minimapCompartment",
		element = "compartment",
		title = L["Addon Compartment"],
		description = L["Blizzard's addon compartment, with every addon's entry."],
		note = L["It is Blizzard's own button, showing how many addons use it; shown while an addon does."],
	},
}

---@param window table
function SettingsMinimap:Declare(window)
	local Settings = AUI.Settings
	local pages = {}

	window:Header("minimapHeader", MINIMAP_LABEL)

	for _, info in ipairs(PAGES) do
		if not info.needs or AUI.can[info.needs] then
			-- An element's page turns that element on or off; the others, the whole minimap.
			local switchPath = info.element and select(3, AUI.MinimapElements:Paths(info.element)) or "minimap.enabled"
			local page = window:Page(info.id, {
				title = info.title,
				description = info.description,
				under = "minimapHeader",
				switch = { path = switchPath, default = Settings:Default(switchPath) },
			})

			if not page then
				return
			end

			pages[info.id] = page

			if info.note then
				page:Section(info.id .. "About", info.title):Note(info.note)
			end
		end
	end

	local map = pages.minimap:Section("map", L["Map"])

	map:Note(L["Turning the minimap on or off takes effect after a /reload. While it is off, Blizzard's minimap is left as it is."])
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
	map:Note(L["The map stays north up while AeonUI's minimap is on, whatever the Rotate Minimap option says."])

	local options = {}

	for index, style in ipairs(AUI.Border.STYLES) do
		options[index] = { value = style, text = STYLE_LABELS[style] }
	end

	local border = pages.minimapBorder:Section("border", L["Border"])

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

	local rows = pages.minimapRows:Section("rows", L["Rows"])

	rows:Slider({
		id = "rowHeight",
		resettable = true,
		label = L["Row Height"],
		description = L["Every row's height. Buttons are square at it."],
		path = "minimap.rows.height",
		default = Settings:Default("minimap.rows.height"),
		min = 16,
		max = 40,
		step = 1,
	})
	DeclareText(pages.minimapRows:Section("rowsText", L["Text"]))

	local zone = pages.minimapZone:Section("zone", ZONE)

	zone:Dropdown({
		id = "zoneColor",
		label = L["Zone Color"],
		path = "minimap.zone.color",
		default = Settings:Default("minimap.zone.color"),
		options = {
			{ value = "PVP", text = L["By PvP Status"] },
			{ value = "GOLD", text = L["Gold"] },
		},
	})
	DeclareText(pages.minimapZone:Section("zoneText", L["Text"]), "zone")

	local clock = pages.minimapClock:Section("clock", TIMEMANAGER_TITLE)

	clock:Checkbox({
		id = "twentyFour",
		label = TIMEMANAGER_24HOURMODE,
		path = "minimap.clock.twentyFour",
		default = Settings:Default("minimap.clock.twentyFour"),
	})
	clock:Checkbox({
		id = "localTime",
		label = TIMEMANAGER_LOCALTIME,
		description = L["Off shows the realm's time."],
		path = "minimap.clock.localTime",
		default = Settings:Default("minimap.clock.localTime"),
	})
	clock:Checkbox({
		id = "dayNight",
		label = L["Show Day and Night"],
		path = "minimap.clock.dayNight",
		default = Settings:Default("minimap.clock.dayNight"),
	})
	clock:Slider({
		id = "iconSize",
		resettable = true,
		label = L["Icon Size"],
		path = "minimap.clock.iconSize",
		default = Settings:Default("minimap.clock.iconSize"),
		min = 8,
		max = 32,
		step = 1,
		blocked = function()
			if not AUI.Profile:Get("minimap.clock.dayNight") then
				return L["Needs Show Day and Night."]
			end
		end,
	})
	DeclareText(pages.minimapClock:Section("clockText", L["Text"]), "clock", true)

	local coordinates = pages.minimapCoordinates:Section("coordinates", L["Coordinates"])

	coordinates:Slider({
		id = "precision",
		resettable = true,
		label = L["Decimal Places"],
		path = "minimap.coordinates.precision",
		default = Settings:Default("minimap.coordinates.precision"),
		min = 0,
		max = 2,
		step = 1,
	})
	DeclareText(pages.minimapCoordinates:Section("coordinatesText", L["Text"]), "coordinates", true)
	DeclareText(pages.minimapCompartment:Section("compartmentText", L["Text"]), "compartment", true)

	local fade = pages.minimap:Section("fade", L["Fading"])

	local function Needs(path, reason)
		return function()
			if not AUI.Profile:Get(path) then
				return reason
			end
		end
	end

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
		description = L["How visible the minimap stays while the mouse is away."],
		path = "minimap.fade.mouseoverOpacity",
		default = Settings:Default("minimap.fade.mouseoverOpacity"),
		min = 0,
		max = 100,
		step = 5,
		format = "percent",
		blocked = Needs("minimap.fade.mouseover", L["Needs Fade Until Mouseover."]),
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
		description = L["How visible the minimap stays in combat. The mouse brings it back."],
		path = "minimap.fade.combatOpacity",
		default = Settings:Default("minimap.fade.combatOpacity"),
		min = 0,
		max = 100,
		step = 5,
		format = "percent",
		blocked = Needs("minimap.fade.combat", L["Needs Fade in Combat."]),
	})

	DeclareText(pages.minimapDifficulty:Section("difficultyText", L["Text"]), "difficulty")

	local colors = pages.minimapDifficulty:Section("difficultyColors", L["Colors"])

	local difficulty = AUI.MinimapElements.byKey.difficulty --[[@as AUIMinimapDifficulty]]

	for _, tier in ipairs(difficulty.TIERS) do
		local path = "minimap.difficulty.colors." .. tier.key

		colors:Color({
			id = "difficulty_" .. tier.key,
			resettable = true,
			label = TIER_LABELS[tier.key],
			description = TIER_DESCRIPTIONS[tier.key],
			path = path,
			default = Settings:Default(path),
		})
	end

	local zoom = pages.minimap:Section("zoom", L["Zoom"])

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
