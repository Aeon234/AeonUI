local AUI = select(2, ...)

local L = AUI.L
local Schema = AUI.Schema
local Pages = AUI.SettingsPages

local Section, Row, Choice, Slider, Check = Pages.Section, Pages.Row, Pages.Choice, Pages.Slider, Pages.Check

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

local FILTERS = {
	all = L["All"],
	own = L["Yours"],
	important = L["Important"],
	importantOwn = L["Important and Yours"],
	hasDuration = L["Has Duration"],
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
local Auras = {}
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

	elements[1] = Section(kind, kind == "buffs" and L["Buffs"] or L["Debuffs"])

	Add(
		Check(show, kind == "buffs" and L["Show Buffs"] or L["Show Debuffs"], base .. "enabled"),
		Choice(id .. "Filter", L["Filter"], base .. "filter", Pages.Options(filterList, FILTERS), On())
	)
	Add(
		Slider(id .. "Size", L["Icon Size"], base .. "size", Range("size")),
		Slider(id .. "Limit", L["Limit"], base .. "limit", Range("limit"))
	)

	local perRowMin, perRowMax = Range("perRow")
	local spacingMin, spacingMax = Range("spacing")

	Add(
		Slider(id .. "PerRow", L["Icons Per Row"], base .. "perRow", perRowMin, perRowMax, On({
			description = L["0 fits as many icons as the frame is wide."],
		})),
		Slider(id .. "Spacing", L["Spacing"], base .. "spacing", spacingMin, spacingMax, On())
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

	Add(
		Check(id .. "Duration", L["Show Duration"], base .. "duration", On()),
		Slider(id .. "DurationSize", L["Duration Size"], base .. "durationSize", textMin, textMax,
			On({ depends = id .. "Duration" }))
	)
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
