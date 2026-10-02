local AUI = select(2, ...)

local L = AUI.L
local Schema = AUI.Schema
local Pages = AUI.SettingsPages

local Section, Row, Choice, Slider, Check = Pages.Section, Pages.Row, Pages.Choice, Pages.Slider, Pages.Check

-- Indicators in page order, with their labels.
local INDICATORS = {
	{ name = "raid", label = L["Raid Marker"] },
	{ name = "resting", label = L["Resting"] },
	{ name = "combat", label = L["Combat"] },
	{ name = "leader", label = L["Leader and Assistant"] },
	{ name = "pvp", label = L["PvP"] },
	{ name = "classification", label = L["Rare and Elite"] },
}

---The Indicators and Fading sections of the frame pages.
---@class AUISettingsIndicators
local Indicators = {}
AUI.SettingsIndicators = Indicators

---@param key string
---@return table[] elements the frame page's Indicators section, or nothing for a frame without indicators
function Indicators:Sections(key)
	local base = "frames." .. key .. "."
	local elements = {}

	local function Add(left, right)
		elements[#elements + 1] = Row(left, right)
	end

	local anchors = AUI.SettingsText.ANCHORS
	local placements = AUI.SettingsText.PLACEMENTS

	for _, indicator in ipairs(INDICATORS) do
		local path = base .. "indicators." .. indicator.name .. "."

		if Schema:Field(path .. "enabled") then
			local id = indicator.name
			local sizeMin, sizeMax = Pages.Range(path .. "size")
			local offsetMin, offsetMax = Pages.Range(path .. "x")
			local on = { depends = id }

			Add(
				Check(id, indicator.label, path .. "enabled"),
				Slider(id .. "Size", L["Size"], path .. "size", sizeMin, sizeMax, Pages.Merge({}, on))
			)
			Add(
				Choice(id .. "Anchor", L["Anchor"], path .. "anchor", Pages.Options("anchor", anchors), Pages.Merge({}, on)),
				Choice(id .. "Placement", L["Placement"], path .. "placement", Pages.Options("placement", placements),
					Pages.Merge({}, on))
			)
			Add(
				Slider(id .. "X", L["X Offset"], path .. "x", offsetMin, offsetMax, Pages.Merge({}, on)),
				Slider(id .. "Y", L["Y Offset"], path .. "y", offsetMin, offsetMax, Pages.Merge({}, on))
			)
		end
	end

	if Schema:Field(base .. "indicators.threat.enabled") then
		local sizeMin, sizeMax = Pages.Range(base .. "indicators.threat.size")

		Add(
			Check("threat", L["Threat Border"], base .. "indicators.threat.enabled", {
				description = L["A border around the frame in group instances: gold near aggro, orange with aggro."],
			}),
			Slider("threatSize", L["Border Size"], base .. "indicators.threat.size", sizeMin, sizeMax, { depends = "threat" })
		)
	end

	if Schema:Field(base .. "totems.enabled") then
		local sizeMin, sizeMax = Pages.Range(base .. "totems.size")
		local spacingMin, spacingMax = Pages.Range(base .. "totems.spacing")

		Add(
			Check("totems", L["Totems"], base .. "totems.enabled", {
				description = L["Your totems and similar summons, under the frame's right end."],
			}),
			Slider("totemSize", L["Totem Size"], base .. "totems.size", sizeMin, sizeMax, { depends = "totems" })
		)
		Add(Slider("totemSpacing", L["Totem Spacing"], base .. "totems.spacing", spacingMin, spacingMax,
			{ depends = "totems" }))
	end

	if Schema:Field(base .. "highlight") then
		Add(Check("highlight", L["Mouseover Highlight"], base .. "highlight", {
			description = L["Turns the frame's border white while the mouse is over it."],
		}))
	end

	if #elements == 0 then
		return {}
	end

	local Shared = AUI.SettingsShared

	table.insert(elements, 1, Shared:Section("indicators", L["Indicators"], key, Shared.SCOPES.indicators, true))

	if Schema:Field(base .. "tooltip.enabled") then
		Add(
			Check("tooltip", L["Tooltip"], base .. "tooltip.enabled", {
				description = L["Shows the unit's tooltip while the mouse is over the frame."],
			}),
			Check("tooltipCombat", L["Hide Tooltip in Combat"], base .. "tooltip.hideInCombat", { depends = "tooltip" })
		)
	end

	return elements
end

---@param key string
---@return table[] elements the frame page's Fading section, or nothing for a frame without fades
function Indicators:FadingSection(key)
	local base = "frames." .. key .. ".fade."
	local elements = {}

	if Schema:Field(base .. "range.enabled") then
		elements[#elements + 1] = Row(
			Check("rangeFade", L["Range Fade"], base .. "range.enabled", {
				description = L["Fades the frame while the unit is out of your spells' range. Unknown range never fades it."],
			}),
			Slider("rangeAlpha", L["Range Fade Opacity"], base .. "range.alpha", 0, 100, {
				depends = "rangeFade",
				format = "percent",
			})
		)
	end

	if Schema:Field(base .. "idle.enabled") then
		elements[#elements + 1] = Row(
			Check("idleFade", L["Idle Fade"], base .. "idle.enabled", {
				description = L["Fades the frame while you are out of combat, have no target and are not casting."],
			}),
			Slider("idleAlpha", L["Idle Fade Opacity"], base .. "idle.alpha", 0, 100, {
				depends = "idleFade",
				format = "percent",
			})
		)
	end

	if #elements == 0 then
		return {}
	end

	table.insert(elements, 1, Section("fading", L["Fading"]))

	return elements
end
