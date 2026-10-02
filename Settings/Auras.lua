local AUI = select(2, ...)

local L = AUI.L
local Schema = AUI.Schema
local Pages = AUI.SettingsPages

local Row, Choice, Slider, Check, Setting = Pages.Row, Pages.Choice, Pages.Slider, Pages.Check, Pages.Setting

local ANCHORS = {
	aboveLeft = L["Above Left"],
	aboveRight = L["Above Right"],
	belowLeft = L["Below Left"],
	belowRight = L["Below Right"],
	left = L["Left Side"],
	right = L["Right Side"],
}

local GROWTHS = {
	right = L["Right"],
	left = L["Left"],
}

-- Category names, shared by the filter modes and the Hide checkboxes.
local CATEGORIES = {
	important = L["Important"],
	bigDefensive = L["Big Defensive"],
	externalDefensive = L["External Defensive"],
	raidInCombat = L["Raid In Combat"],
	crowdControl = L["Crowd Control"],
	dispellableByYou = L["Dispellable by You"],
	anyDispellable = L["Any Dispellable"],
	yours = L["Yours"],
	notYours = L["Not Yours"],
	boss = L["Boss"],
	role = L["Role"],
	stealable = L["Stealable"],
	classCanApply = L["Your Class Can Apply"],
	magic = L["Magic"],
	curse = L["Curse"],
	disease = L["Disease"],
	poison = L["Poison"],
}

local FILTERS = {
	all = L["All"],
	own = L["Yours"],
	importantOwn = L["Important and Yours"],
	hasDuration = L["Has Duration"],
	tracked = L["Tracked Spells"],
	categories = L["Categories"],
}

for value, label in pairs(CATEGORIES) do
	FILTERS[value] = FILTERS[value] or label
end

local BUFF_CATEGORIES = {
	defensives = L["Defensives"],
	activeMitigation = L["Active Mitigation"],
	raidCooldowns = L["Raid Cooldowns"],
	externals = L["Externals"],
	coreHealing = L["Core Healing"],
	lesserHealing = L["Lesser Healing"],
	support = L["Support"],
	offensive = L["Offensive Cooldowns"],
	movement = L["Movement"],
	utility = L["Utility"],
	consumables = L["Consumables"],
}

local CASTERS = {
	anyone = L["Anyone's"],
	yours = L["Yours"],
}

local SORTS = {
	stable = L["Stable Order"],
	shortest = L["Shortest First"],
	yours = L["Yours First"],
	blizzard = L["Blizzard Debuff Order"],
	importance = L["Importance"],
	name = L["Name"],
}

local CORNERS = {
	BOTTOMRIGHT = L["Bottom Right"],
	BOTTOMLEFT = L["Bottom Left"],
	TOPRIGHT = L["Top Right"],
	TOPLEFT = L["Top Left"],
	CENTER = L["Center"],
}

---The Buffs and Debuffs sections of the player, target, focus and boss pages.
---@class AUISettingsAuras
local Auras = {
	CORNERS = CORNERS,
}
AUI.SettingsAuras = Auras

---@param key string
---@param kind "buffs"|"debuffs"
---@return table[] elements
local function Display(key, kind)
	local base = "frames." .. key .. "." .. kind .. "."
	local id = kind == "buffs" and "buff" or "debuff"
	local show = id .. "Enabled"
	local elements = {}

	local function Add(left, right)
		elements[#elements + 1] = Row(left, right)
	end

	---@param fields table?
	---@return table fields depending on the display's switch unless they name another
	local function On(fields)
		fields = fields or {}
		fields.depends = fields.depends or show

		return fields
	end

	local function Range(name)
		return Pages.Range(base .. name)
	end

	local filterList = kind == "buffs" and "buffFilter" or "debuffFilter"

	local Shared = AUI.SettingsShared

	elements[1] = Shared:Section(kind, kind == "buffs" and L["Buffs"] or L["Debuffs"], key, Shared.SCOPES[kind], true)

	local categorized = Schema:Field(base .. "categories.defensives") ~= nil
	local filters = {}

	-- Curated categories exist only for the player's buffs.
	for _, option in ipairs(Pages.Options(filterList, FILTERS)) do
		if option.value ~= "categories" or categorized then
			filters[#filters + 1] = option
		end
	end

	Add(
		Check(show, kind == "buffs" and L["Show Buffs"] or L["Show Debuffs"], base .. "enabled"),
		Choice(id .. "Filter", L["Filter"], base .. "filter", filters, On())
	)

	if categorized then
		local switches = {}
		local function Categorized()
			if AUI.Profile:Get(base .. "filter") ~= "categories" then
				return L["Only with the Categories filter."]
			end
		end

		for _, category in ipairs(AUI.AuraCategories:Available()) do
			switches[#switches + 1] = Check(id .. "Category" .. category, BUFF_CATEGORIES[category] or category,
				base .. "categories." .. category, On({
					blocked = Categorized,
					description = L["Player buffs in curated groups. Each switch shows or hides one group; Never Show still wins."],
				}))
		end

		for index = 1, #switches, 2 do
			Add(switches[index], switches[index + 1])
		end
	end
	Add(
		Slider(id .. "Size", L["Icon Size"], base .. "size", Range("size")),
		Slider(id .. "Limit", L["Limit"], base .. "limit", Range("limit"))
	)
	Add(
		Choice(id .. "Anchor", L["Position"], base .. "anchor", Pages.Options("auraAnchor", ANCHORS), On()),
		Choice(id .. "Growth", L["Growth Direction"], base .. "growth", Pages.Options("auraGrowth", GROWTHS), On())
	)

	local offsetMin, offsetMax = Range("x")

	Add(
		Slider(id .. "X", L["X Offset"], base .. "x", offsetMin, offsetMax, On()),
		Slider(id .. "Y", L["Y Offset"], base .. "y", offsetMin, offsetMax, On())
	)
	local hides = Schema.choices[kind == "buffs" and "buffHide" or "debuffHide"]
	local hideOptions, hideSearch = {}, {}

	for index, name in ipairs(hides) do
		hideOptions[index] = { value = name, text = CATEGORIES[name] }
		hideSearch[index] = L["Hide %s"]:format(CATEGORIES[name])
	end

	-- One switch per category, saved as one set: each category's `hide.<name>` is true while it is in the set.
	Add(
		Pages.Merge({
			id = id .. "Hide",
			control = "dropdown",
			label = L["Hide Categories"],
			description = L["Auras in the chosen categories never show here, whatever the filter."],
			multi = true,
			options = hideOptions,
			searchText = table.concat(hideSearch, " "),
			summary = function(count)
				return count == 0 and NONE or L["%d Hidden"]:format(count)
			end,
			get = function()
				local set = {}

				for _, name in ipairs(hides) do
					if AUI.Profile:Get(base .. "hide." .. name) then
						set[name] = true
					end
				end

				return set
			end,
			set = function(value)
				for _, name in ipairs(hides) do
					if not AUI.Profile:Set(base .. "hide." .. name, value[name] == true) then
						return false
					end
				end
			end,
		}, On()),
		Check(id .. "Duration", L["Show Duration"], base .. "duration", On())
	)

	elements[#elements + 1] = Pages.Details(kind, kind == "buffs" and L["Buffs"] or L["Debuffs"])

	local perRowMin, perRowMax = Range("perRow")
	local spacingMin, spacingMax = Range("spacing")

	Add(
		Slider(id .. "PerRow", L["Icons Per Row"], base .. "perRow", perRowMin, perRowMax, On({
			description = L["0 fits as many icons as the frame is wide."],
		})),
		Slider(id .. "Spacing", L["Spacing"], base .. "spacing", spacingMin, spacingMax, On())
	)

	local validate = function(text)
		return AUI.Auras:CheckSpellList(text)
	end

	Add(
		Setting("text", id .. "Include", L["Tracked Spells"], base .. "include", On({
			allowEmpty = true,
			validate = validate,
			description = L["Spell IDs, separated by commas, that the Tracked Spells filter shows. The game applies spell lists only to buffs on you, your group and your pets, and to debuffs on enemies."],
		})),
		Choice(id .. "ListCaster", L["Tracked Caster"], base .. "listCaster", Pages.Options("listCaster", CASTERS), On())
	)
	Add(Setting("text", id .. "Exclude", L["Never Show"], base .. "exclude", On({
		allowEmpty = true,
		validate = validate,
		description = L["Spell IDs, separated by commas, this display never shows, whatever its filter. The game applies spell lists only to buffs on you, your group and your pets, and to debuffs on enemies."],
	})))
	Add(
		Choice(id .. "Sort", L["Sort"], base .. "sort", Pages.Options("auraSort", SORTS), On()),
		Check(id .. "Reverse", L["Reverse Sort"], base .. "reverse", On())
	)
	Add(
		Check(id .. "Tooltips", L["Tooltips"], base .. "tooltips", On()),
		Check(id .. "Clicks", L["Clicks"], base .. "clicks", On({
			description = key == "player" and kind == "buffs"
				and L["Off lets clicks pass through to the frame. On, right-click cancels the buff."]
				or L["Off lets clicks pass through to the frame."],
		}))
	)
	Add(
		Check(id .. "Swipe", L["Cooldown Swipe"], base .. "swipe", On()),
		Check(id .. "Border", kind == "buffs" and L["Stealable Glow"] or L["Dispel Type Border"], base .. "border", On())
	)

	local textMin, textMax = Range("durationSize")
	local shiftMin, shiftMax = Range("durationX")

	Add(Slider(id .. "DurationSize", L["Duration Size"], base .. "durationSize", textMin, textMax,
		On({ depends = id .. "Duration" })))
	Add(
		Slider(id .. "DurationX", L["Duration X"], base .. "durationX", shiftMin, shiftMax, On({ depends = id .. "Duration" })),
		Slider(id .. "DurationY", L["Duration Y"], base .. "durationY", shiftMin, shiftMax, On({ depends = id .. "Duration" }))
	)
	Add(
		Choice(id .. "CountCorner", L["Stack Position"], base .. "countCorner", Pages.Options("auraCorner", CORNERS), On()),
		Slider(id .. "CountSize", L["Stack Size"], base .. "countSize", textMin, textMax, On())
	)
	Add(
		Slider(id .. "CountX", L["Stack X"], base .. "countX", shiftMin, shiftMax, On()),
		Slider(id .. "CountY", L["Stack Y"], base .. "countY", shiftMin, shiftMax, On())
	)

	return elements
end

---@param key string
---@return table[] elements the frame page's Buffs and Debuffs sections, or nothing for a frame without auras
function Auras:Sections(key)
	if not Schema:Field("frames." .. key .. ".buffs.enabled") then
		return {}
	end

	local elements = Display(key, "buffs")

	for _, element in ipairs(Display(key, "debuffs")) do
		elements[#elements + 1] = element
	end

	return elements
end
