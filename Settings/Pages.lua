local AUI = select(2, ...)

local L = AUI.L
local Schema = AUI.Schema

-- The choice that clears a frame's own number setting so it follows the Globals page.
local GLOBAL = "__global"

---Setting builders bound to the profile owner, and the unit-frame pages built from them.
---@class AUISettingsPages
local Pages = {}
AUI.SettingsPages = Pages

---@param setting table
---@param fields table?
---@return table setting
function Pages.Merge(setting, fields)
	for key, value in pairs(fields or {}) do
		setting[key] = value
	end

	return setting
end

local Merge = Pages.Merge

---A setting that reads and writes one profile path. A refused write reports the library's own message.
---@param control string
---@param id string
---@param label string
---@param path string
---@param fields table?
---@return table setting
function Pages.Setting(control, id, label, path, fields)
	return Merge({
		id = id,
		control = control,
		label = label,
		get = function()
			return AUI.Profile:Get(path)
		end,
		set = function(value)
			if not AUI.Profile:Set(path, value) then
				return false
			end
		end,
	}, fields)
end

local Setting = Pages.Setting

---@param id string
---@param label string
---@param path string
---@param fields table?
---@return table setting
function Pages.Check(id, label, path, fields)
	return Setting("checkbox", id, label, path, fields)
end

---@param id string
---@param label string
---@param path string
---@param minimum number
---@param maximum number
---@param fields table?
---@return table setting
function Pages.Slider(id, label, path, minimum, maximum, fields)
	return Setting("slider", id, label, path, Merge({ min = minimum, max = maximum, step = 1, format = "integer" }, fields))
end

---@param list string a choice list in `Schema.choices`
---@param labels table<string, string> each choice's label
---@return table[] options
function Pages.Options(list, labels)
	local options = {}

	for index, value in ipairs(Schema.choices[list]) do
		options[index] = { value = value, text = labels[value] or value }
	end

	return options
end

---@param id string
---@param label string
---@param path string
---@param options table[]|fun(): table[]
---@param fields table?
---@return table setting
function Pages.Choice(id, label, path, options, fields)
	return Setting("dropdown", id, label, path, Merge({ options = options }, fields))
end

---A color stored as `{ r, g, b }`.
---@param id string
---@param label string
---@param path string
---@param fields table?
---@return table setting
function Pages.Color(id, label, path, fields)
	local opacity = fields and fields.hasOpacity

	return Setting("color", id, label, path, Merge({
		set = function(value)
			local color = { r = value.r, g = value.g, b = value.b, a = opacity and (value.a or 1) or nil }

			if not AUI.Profile:Set(path, color) then
				return false
			end
		end,
	}, fields))
end

---@param path string a number setting
---@return number min
---@return number max
function Pages.Range(path)
	local field = assert(Schema:Field(path), path)

	return field.min or 0, field.max or 0
end

---@param id string
---@param title string
---@param fields table?
---@return table element
function Pages.Section(id, title, fields)
	return Merge({ kind = "section", id = id, title = title }, fields)
end

---@param left table
---@param right table?
---@return table element
function Pages.Row(left, right)
	if right then
		return { kind = "setting", settings = { left, right } }
	end

	return { kind = "setting", setting = left }
end

local Section, Row, Choice, Slider, Check = Pages.Section, Pages.Row, Pages.Choice, Pages.Slider, Pages.Check

-- Labels ----------------------------------------------------------------------------------------------------

-- Bar textures: AeonUI's own choices first; a texture picker lists LibSharedMedia's other bar textures after them.
Pages.TEXTURES = {
	{ value = AUI.Media.FLAT, text = L["Flat"] },
	{ value = AUI.Media.STRIPED, text = L["Striped"], texture = AUI.Media.files[AUI.Media.STRIPED] },
	{ value = AUI.Media.SHIELD, text = L["Blizzard"], texture = AUI.Media.files[AUI.Media.SHIELD] },
}

Pages.OUTLINES = {
	NONE = NONE,
	OUTLINE = L["Outline"],
	THICKOUTLINE = L["Thick Outline"],
	SLUG = L["Slug"],
	SLUG_OUTLINE = L["Slug Outline"],
	SLUG_THICKOUTLINE = L["Slug Thick Outline"],
}

local PRECISIONS = {
	default = L["Blizzard Default"],
	decimal = L["One Decimal"],
}

local GROWTHS = {
	down = L["Down"],
	up = L["Up"],
	right = L["Right"],
	left = L["Left"],
}

local DECIMALS = {
	{ value = 0, text = "100%" },
	{ value = 1, text = "100.0%" },
}

-- Numbers ---------------------------------------------------------------------------------------------------

---@param value any
---@return string
local function DecimalsLabel(value)
	return value == 1 and DECIMALS[2].text or DECIMALS[1].text
end

---A frame's override of a Globals number setting: "Global (value)" first, then the choices.
---@param id string
---@param label string
---@param path string the frame's own path
---@param globalPath string the Globals path it follows
---@param options table[] the choices
---@param describe fun(value: any): string the label of a value
---@return table setting
local function Override(id, label, path, globalPath, options, describe)
	return Setting("dropdown", id, label, path, {
		options = function()
			local list = { { value = GLOBAL, text = L["Global (%s)"]:format(describe(AUI.Profile:Get(globalPath))) } }

			for _, option in ipairs(options) do
				list[#list + 1] = option
			end

			return list
		end,
		get = function()
			local own = AUI.Profile:Get(path)

			if own == nil then
				return GLOBAL
			end

			return own
		end,
		set = function(value)
			if not AUI.Profile:Set(path, value ~= GLOBAL and value or nil) then
				return false
			end
		end,
	})
end

---@param precision string
---@return string
local function PrecisionLabel(precision)
	return PRECISIONS[precision] or precision
end

---@param elements table[]
---@param more table[]
local function Append(elements, more)
	for _, element in ipairs(more) do
		elements[#elements + 1] = element
	end
end

---@return table[] elements
local function GlobalsPage()
	local elements = {
		Section("numbers", L["Numbers"]),
		Row(
			Choice("precision", L["Abbreviation"], "numbers.precision", Pages.Options("precision", PRECISIONS), {
				description = L["How large numbers are shortened, such as 588K or 588.4K."],
			}),
			Choice("percentDecimals", L["Percent Decimals"], "numbers.percentDecimals", DECIMALS)
		),
	}

	Append(elements, AUI.SettingsOverlays:GlobalSection())

	return elements
end

-- Frame pages -----------------------------------------------------------------------------------------------

---@return number halfWidth
---@return number halfHeight
local function ScreenHalf()
	return math.floor(UIParent:GetWidth() / 2), math.floor(UIParent:GetHeight() / 2)
end

---The Layout section: the page's switch, size and position.
---@param key string
---@param switchLabel string
---@return table[] elements
local function Layout(key, switchLabel)
	local base = "frames." .. key .. "."
	local halfWidth, halfHeight = ScreenHalf()
	local elements = {
		Section("layout", L["Layout"]),
		Row(Setting("toggle", "enabled", switchLabel, base .. "enabled", { pageSwitch = true })),
		Row(
			Slider("width", L["Width"], base .. "width", Pages.Range(base .. "width")),
			Slider("height", L["Height"], base .. "height", Pages.Range(base .. "height"))
		),
		Row(
			Slider("x", L["X Offset"], base .. "x", -halfWidth, halfWidth),
			Slider("y", L["Y Offset"], base .. "y", -halfHeight, halfHeight)
		),
	}

	if Schema:Field(base .. "growth") then
		local spacingMin, spacingMax = Pages.Range(base .. "spacing")

		elements[#elements + 1] = Row(
			Choice("growth", L["Growth Direction"], base .. "growth", Pages.Options("growth", GROWTHS), {
				description = L["The direction the frames after the first are placed in."],
			}),
			Slider("spacing", L["Spacing"], base .. "spacing", spacingMin, spacingMax)
		)
	end

	return elements
end

---@param key string a frame with health
---@param switchLabel string
---@return table[] elements
local function UnitPage(key, switchLabel)
	local base = "frames." .. key .. "."
	local elements = Layout(key, switchLabel)

	Append(elements, {
		Section("health", HEALTH),
		Row(Check("reverse", L["Reverse Fill"], base .. "reverse", {
			description = L["Fill the bar from right to left."],
		})),
	})

	if Schema:Field(base .. "power.enabled") then
		local heightMin, heightMax = Pages.Range(base .. "power.height")

		Append(elements, {
			Row(
				Check("power", L["Show Power Bar"], base .. "power.enabled", {
					description = L["A power bar under health. It adds to the frame's height."],
				}),
				Slider("powerHeight", L["Power Bar Height"], base .. "power.height", heightMin, heightMax, {
					depends = "power",
				})
			),
		})
	end
	Append(elements, AUI.SettingsOverlays:Sections(key))
	Append(elements, AUI.SettingsCastBar:Sections(key))
	Append(elements, AUI.SettingsAuras:Sections(key))
	Append(elements, AUI.SettingsText:Sections(key))
	Append(elements, {
		Section("numbers", L["Numbers"]),
		Row(
			Override("precision", L["Abbreviation"], base .. "numbers.precision", "numbers.precision",
				Pages.Options("precision", PRECISIONS), PrecisionLabel),
			Override("percentDecimals", L["Percent Decimals"], base .. "numbers.percentDecimals", "numbers.percentDecimals",
				DECIMALS, DecimalsLabel)
		),
	})

	return elements
end

---@return table[] elements
local function PowerPage()
	local elements = Layout("playerPower", L["Show Player Power Bar"])

	Append(elements, AUI.SettingsText:Sections("playerPower"))

	return elements
end

---A page whose Defaults button resets one profile scope.
---@param id string
---@param title string
---@param scope string|string[]
---@param build fun(): table[]
---@return table page
local function Page(id, title, scope, build)
	return {
		id = id,
		title = title,
		preview = AUI.SettingsPreviews:For(id),
		Build = build,
		Reset = function()
			AUI.Profile:Reset(scope)
		end,
	}
end

---@return table[] pages the Unit Frames category's pages, in order
function Pages:UnitFramePages()
	return {
		Page("globals", L["Globals"], { "numbers", "overlays" }, GlobalsPage),
		Page("player", PLAYER, "frames.player", function()
			return UnitPage("player", L["Show Player Frame"])
		end),
		Page("target", TARGET, "frames.target", function()
			return UnitPage("target", L["Show Target Frame"])
		end),
		Page("targettarget", L["Target of Target"], "frames.targettarget", function()
			return UnitPage("targettarget", L["Show Target of Target Frame"])
		end),
		Page("focus", L["Focus"], "frames.focus", function()
			return UnitPage("focus", L["Show Focus Frame"])
		end),
		Page("boss", L["Bosses"], "frames.boss", function()
			return UnitPage("boss", L["Show Boss Frames"])
		end),
		Page("playerPower", L["Player Power"], "frames.playerPower", PowerPage),
		Page("classPower", L["Class Resource"], "frames.classPower", function()
			return AUI.SettingsClassPower:Build()
		end),
	}
end
