local AUI = select(2, ...)

local L = AUI.L
local Schema = AUI.Schema

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

---A setting that reads and writes one profile path. A refused write reports the library's own message. A frame setting
---that follows a shared one shows whether it is Shared or Custom, and Use Shared clears its own value.
---@param control string
---@param id string
---@param label string
---@param path string
---@param fields table?
---@return table setting
function Pages.Setting(control, id, label, path, fields)
	local field = Schema:Field(path)
	local inherit

	if field and field.shared then
		inherit = {
			custom = function()
				return AUI.Profile:IsCustom(path)
			end,
			clear = function()
				if not AUI.Profile:Set(path, nil) then
					return false
				end
			end,
		}
	end

	return Merge({
		id = id,
		control = control,
		label = label,
		path = path,
		inherit = inherit,
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

---Disables a placed element's position or size slider while the layout editor's relationships set it.
---@param base string the element's settings path, ending in a dot
---@param kind "position"|"width"|"height"
---@param other (fun(): string?)? another reason, checked first
---@return (fun(): string?)? blocked nil for a path that is no placed element
function Pages.Placed(base, kind, other)
	local name = kind == "position" and "layout.attach.target" or ("layout." .. kind)

	if not Schema:Field(base .. name) then
		return other
	end

	return function()
		local reason = other and other()

		if reason then
			return reason
		end

		local id = AUI.Profile:Get(base .. name)
		local element = id ~= "none" and AUI.EditorLayout:Find(id)

		if element then
			local label = AUI.EditorLayout:Label(element)

			if kind == "position" and AUI.Profile:Get(base .. "layout.attach.waiting") then
				return L["Waiting to reconnect to %s."]:format(label)
			end

			if kind == "position" then
				return L["Attached to %s. Move it in Edit Mode."]:format(label)
			end

			return L["Matches %s."]:format(label)
		end
	end
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

---A picker row: one button per option. The rows after it that name an option in `pick` show while it is picked.
---@param id string
---@param label string
---@param options { id: string, title: string }[]
---@return table element
function Pages.Picker(id, label, options)
	return { kind = "picker", id = id, label = label, options = options }
end

---Names the picker option elements belong to.
---@param option string
---@param elements table[]
---@return table[] elements
function Pages.Pick(option, elements)
	for _, element in ipairs(elements) do
		element.pick = option
	end

	return elements
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

---@param elements table[]
---@param more table[]
local function Append(elements, more)
	for _, element in ipairs(more) do
		elements[#elements + 1] = element
	end
end

---The Numbers rows: on Globals, or a frame's own, which follow Globals.
---@param base string `numbers.` or a frame's `frames.<key>.numbers.`
---@return table element
local function NumberRow(base)
	return Row(
		Choice("precision", L["Abbreviation"], base .. "precision", Pages.Options("precision", PRECISIONS), {
			description = L["How large numbers are shortened, such as 588K or 588.4K."],
		}),
		Choice("percentDecimals", L["Percent Decimals"], base .. "percentDecimals", DECIMALS)
	)
end

---@return table[] elements
local function GlobalsPage()
	local elements = AUI.SettingsShared:GlobalSections()

	Append(elements, { Section("numbers", L["Numbers"]), NumberRow("numbers.") })
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
	local hides = Schema:Field(base .. "hideBlizzard") ~= nil
	local widthMin, widthMax = Pages.Range(base .. "width")
	local heightMin, heightMax = Pages.Range(base .. "height")
	local elements = {
		Section("layout", L["Layout"]),
		Row(Setting("toggle", "enabled", switchLabel, base .. "enabled", { pageSwitch = true, reload = hides or nil })),
		Row(
			Slider("width", L["Width"], base .. "width", widthMin, widthMax, { blocked = Pages.Placed(base, "width") }),
			Slider("height", L["Height"], base .. "height", heightMin, heightMax,
				{ blocked = Pages.Placed(base, "height") })
		),
		Row(
			Slider("x", L["X Offset"], base .. "x", -halfWidth, halfWidth, { blocked = Pages.Placed(base, "position") }),
			Slider("y", L["Y Offset"], base .. "y", -halfHeight, halfHeight, { blocked = Pages.Placed(base, "position") })
		),
	}

	if hides then
		elements[#elements + 1] = Row(Check("hideBlizzard", L["Hide Blizzard's Frame"], base .. "hideBlizzard", {
			reload = true,
			description = L["Hides Blizzard's own frame for this unit while this one is shown. Takes effect after a reload."],
		}))
	end

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

---@param key string
---@return table element the Appearance section's header
local function AppearanceSection(key)
	local Shared = AUI.SettingsShared

	return Shared:Section("appearance", L["Appearance"], key, Shared.SCOPES.appearance, true)
end

local PORTRAIT_MODES = {
	["2d"] = L["2D"],
	["3d"] = L["3D"],
	class = L["Class Icon"],
}

local PORTRAIT_STYLES = {
	attached = L["Attached"],
	detached = L["Detached"],
}

local SIDES = {
	LEFT = L["Left"],
	RIGHT = L["Right"],
}

---@param key string
---@return table[] elements the frame page's Power Colors section, or nothing for a frame without a power bar
local function PowerSection(key)
	local Shared = AUI.SettingsShared
	local base = "frames." .. key .. ".powerColors."

	if not Schema:Field(base .. "mode") then
		return {}
	end

	local elements = { Shared:Section("powerColors", L["Power Colors"], key, Shared.SCOPES.powerColors, true) }

	Append(elements, Shared:PowerRows(base))

	return elements
end

---@param key string
---@return table[] elements the frame page's Portrait section, or nothing for a frame without a portrait
local function PortraitSection(key)
	local base = "frames." .. key .. ".portrait."

	if not Schema:Field(base .. "enabled") then
		return {}
	end

	local sizeMin, sizeMax = Pages.Range(base .. "size")
	local offsetMin, offsetMax = Pages.Range(base .. "x")
	local function Detached()
		if AUI.Profile:Get(base .. "style") ~= "detached" then
			return L["Only for a detached portrait."]
		end
	end

	return {
		Section("portrait", L["Portrait"]),
		Row(
			Check("portrait", L["Show Portrait"], base .. "enabled"),
			Choice("portraitMode", L["Mode"], base .. "mode", Pages.Options("portraitMode", PORTRAIT_MODES), {
				depends = "portrait",
				description = L["Class Icon shows a player's class; other units show their 2D portrait."],
			})
		),
		Row(
			Choice("portraitStyle", L["Placement"], base .. "style", Pages.Options("portraitStyle", PORTRAIT_STYLES), {
				depends = "portrait",
				description = L["Attached sits inside the frame at its side; Detached sits outside it."],
			}),
			Choice("portraitSide", L["Side"], base .. "side", Pages.Options("portraitSide", SIDES), { depends = "portrait" })
		),
		Row(Slider("portraitSize", L["Size"], base .. "size", sizeMin, sizeMax, {
			depends = "portrait",
			blocked = Detached,
		})),
		Row(
			Slider("portraitX", L["X Offset"], base .. "x", offsetMin, offsetMax, { depends = "portrait", blocked = Detached }),
			Slider("portraitY", L["Y Offset"], base .. "y", offsetMin, offsetMax, { depends = "portrait", blocked = Detached })
		),
	}
end

-- The tabs of a frame's page, in order.
local FRAME_TABS = {
	{ id = "frame", title = L["Frame"] },
	{ id = "colors", title = COLORS },
	{ id = "castBar", title = L["Cast Bar"] },
	{ id = "auras", title = L["Auras"] },
	{ id = "text", title = L["Text"] },
	{ id = "indicators", title = L["Indicators"] },
}

-- The tab each section of a frame's page shows on, by section id.
local SECTION_TABS = {
	layout = "frame",
	appearance = "frame",
	portrait = "frame",
	healthColors = "colors",
	powerColors = "colors",
	absorbsAndHeals = "colors",
	castBar = "castBar",
	buffs = "auras",
	debuffs = "auras",
	text = "text",
	textSlots = "text",
	numbers = "text",
	indicators = "indicators",
	fading = "indicators",
}

---Names each section's tab.
---@param elements table[]
---@return table[] elements
local function Tabbed(elements)
	for _, element in ipairs(elements) do
		if element.kind == "section" then
			element.tab = SECTION_TABS[element.id]
		end
	end

	return elements
end

---@param key string a frame with health
---@param switchLabel string
---@return table[] elements
local function UnitPage(key, switchLabel)
	local base = "frames." .. key .. "."
	local Shared = AUI.SettingsShared
	local elements = Layout(key, switchLabel)

	Append(elements, {
		AppearanceSection(key),
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
	Append(elements, Shared:BarRows(base .. "bars."))
	Append(elements, PortraitSection(key))
	Append(elements, { Shared:Section("healthColors", L["Health Colors"], key, Shared.SCOPES.healthColors, true) })
	Append(elements, Shared:HealthRows(base .. "health."))
	Append(elements, PowerSection(key))
	Append(elements, AUI.SettingsOverlays:Sections(key))
	Append(elements, AUI.SettingsCastBar:Sections(key))
	Append(elements, AUI.SettingsAuras:Sections(key))
	Append(elements, AUI.SettingsIndicators:Sections(key))
	Append(elements, AUI.SettingsIndicators:FadingSection(key))
	Append(elements, AUI.SettingsText:Sections(key))
	Append(elements, {
		Shared:Section("numbers", L["Numbers"], key, Shared.SCOPES.numbers, false),
		NumberRow(base .. "numbers."),
	})

	return Tabbed(elements)
end

---@return table[] elements
local function PowerPage()
	local elements = Layout("playerPower", L["Show Player Power Bar"])

	elements[#elements + 1] = AppearanceSection("playerPower")
	Append(elements, AUI.SettingsShared:BarRows("frames.playerPower.bars."))
	Append(elements, PowerSection("playerPower"))
	Append(elements, AUI.SettingsIndicators:FadingSection("playerPower"))
	Append(elements, AUI.SettingsText:Sections("playerPower"))

	return Tabbed(elements)
end

-- The frame pages' builders, by frame key.
local FRAME_PAGES = {
	player = function()
		return UnitPage("player", L["Show Player Frame"])
	end,
	pet = function()
		return UnitPage("pet", L["Show Pet Frame"])
	end,
	target = function()
		return UnitPage("target", L["Show Target Frame"])
	end,
	targettarget = function()
		return UnitPage("targettarget", L["Show Target of Target Frame"])
	end,
	focus = function()
		return UnitPage("focus", L["Show Focus Frame"])
	end,
	boss = function()
		return UnitPage("boss", L["Show Boss Frames"])
	end,
	playerPower = PowerPage,
}

---@param key string a frame with a page of its own
---@return table[] elements the frame's page, as built now
function Pages:BuildFrame(key)
	local build = assert(FRAME_PAGES[key], key)

	return build()
end

---A page whose Defaults button resets one profile scope.
---@param id string
---@param title string
---@param scope string|string[]
---@param build fun(): table[]
---@param tabs table[]? the page's tabs; its sections name theirs
---@return table page
local function Page(id, title, scope, build, tabs)
	return {
		id = id,
		title = title,
		tabs = tabs,
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
		Page("globals", L["Globals"], { "bars", "text", "castbar", "auras", "numbers", "overlays" }, GlobalsPage),
		Page("player", PLAYER, "frames.player", FRAME_PAGES.player, FRAME_TABS),
		Page("pet", PET, "frames.pet", FRAME_PAGES.pet, FRAME_TABS),
		Page("target", TARGET, "frames.target", FRAME_PAGES.target, FRAME_TABS),
		Page("targettarget", L["Target of Target"], "frames.targettarget", FRAME_PAGES.targettarget, FRAME_TABS),
		Page("focus", L["Focus"], "frames.focus", FRAME_PAGES.focus, FRAME_TABS),
		Page("boss", L["Bosses"], "frames.boss", FRAME_PAGES.boss, FRAME_TABS),
		Page("playerPower", L["Player Power"], "frames.playerPower", FRAME_PAGES.playerPower, FRAME_TABS),
		Page("classPower", L["Class Resource"], "frames.classPower", function()
			return AUI.SettingsClassPower:Build()
		end),
	}
end
