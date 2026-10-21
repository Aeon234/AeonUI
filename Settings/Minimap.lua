local AUI = select(2, ...)

local L = AUI.L

---The Minimap page: the module's switch, then the map's size, border, rows, fading and zoom. Its position is set in
---edit mode.
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

---@param value number
---@return string text the zoom reset delay, or Never for 0
local function ResetFormat(value)
	if value == 0 then
		return L["Never"]
	end

	return L["%d s"]:format(value)
end

---@param window table
function SettingsMinimap:Declare(window)
	local Settings = AUI.Settings
	local page = window:Page("minimap", {
		title = MINIMAP_LABEL,
		description = L["A rectangular minimap with information rows, a border and zoom. Move it in Edit Mode."],
		switch = { path = "minimap.enabled", default = Settings:Default("minimap.enabled") },
	})

	if not page then
		return
	end

	local map = page:Section("map", L["Map"])

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

	local rows = page:Section("rows", L["Rows"])

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
	rows:Slider({
		id = "textSize",
		resettable = true,
		label = L["Text Size"],
		path = "minimap.rows.textSize",
		default = Settings:Default("minimap.rows.textSize"),
		min = 8,
		max = 24,
		step = 1,
	})
	rows:Slider({
		id = "zoneTextSize",
		resettable = true,
		label = L["Zone Text Size"],
		path = "minimap.zone.textSize",
		default = Settings:Default("minimap.zone.textSize"),
		min = 8,
		max = 24,
		step = 1,
	})

	for _, group in ipairs({ { key = "rows", title = L["Row Fading"] }, { key = "map", title = L["Map Fading"] } }) do
		local base = "minimap.fade." .. group.key .. "."
		local fade = page:Section(group.key .. "Fade", group.title)

		local function Needs(path, reason)
			return function()
				if not AUI.Profile:Get(base .. path) then
					return reason
				end
			end
		end

		fade:Checkbox({
			id = group.key .. "Mouseover",
			label = L["Fade Until Mouseover"],
			path = base .. "mouseover",
			default = Settings:Default(base .. "mouseover"),
		})
		fade:Slider({
			id = group.key .. "MouseoverOpacity",
			resettable = true,
			label = L["Mouseover Opacity"],
			description = L["How visible it stays while the mouse is away."],
			path = base .. "mouseoverOpacity",
			default = Settings:Default(base .. "mouseoverOpacity"),
			min = 0,
			max = 100,
			step = 5,
			format = "percent",
			blocked = Needs("mouseover", L["Needs Fade Until Mouseover."]),
		})
		fade:Checkbox({
			id = group.key .. "Combat",
			label = L["Fade in Combat"],
			path = base .. "combat",
			default = Settings:Default(base .. "combat"),
		})
		fade:Slider({
			id = group.key .. "CombatOpacity",
			resettable = true,
			label = L["Combat Opacity"],
			description = L["How visible it stays in combat. The mouse brings it back."],
			path = base .. "combatOpacity",
			default = Settings:Default(base .. "combatOpacity"),
			min = 0,
			max = 100,
			step = 5,
			format = "percent",
			blocked = Needs("combat", L["Needs Fade in Combat."]),
		})
	end

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
