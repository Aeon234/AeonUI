local AUI = select(2, ...)

local L = AUI.L
local Pages = AUI.SettingsPages

local Section, Row, Choice, Slider, Check = Pages.Section, Pages.Row, Pages.Choice, Pages.Slider, Pages.Check

local BASE = "frames.classPower."

local ATTACH = {
	power = L["Player Power Bar"],
	screen = L["Screen"],
}

---The Class Resource page.
---@class AUISettingsClassPower
local ClassPower = {}
AUI.SettingsClassPower = ClassPower

---@param fields table?
---@return table fields depending on the page switch unless they name another
local function On(fields)
	fields = fields or {}
	fields.depends = fields.depends or "enabled"

	return fields
end

---@param name string
---@return number min
---@return number max
local function Range(name)
	return Pages.Range(BASE .. name)
end

---@return table[] elements
function ClassPower:Build()
	local halfWidth, halfHeight = math.floor(UIParent:GetWidth() / 2), math.floor(UIParent:GetHeight() / 2)
	local function Detached()
		if AUI.Profile:Get(BASE .. "attach") == "power" then
			return L["Follows the player power bar."]
		end
	end

	local widthMin, widthMax = Range("width")
	local heightMin, heightMax = Range("height")
	local spacingMin, spacingMax = Range("spacing")
	local textMin, textMax = Range("textSize")
	local manaMin, manaMax = Range("extraManaHeight")

	return {
		Section("layout", L["Layout"]),
		Row(Pages.Setting("toggle", "enabled", L["Show Class Resource"], BASE .. "enabled", { pageSwitch = true })),
		Row(
			Choice("attach", L["Attach To"], BASE .. "attach", Pages.Options("classPowerAttach", ATTACH), On({
				description = L["Above the player power bar, or anywhere on the screen."],
			})),
			Slider("spacing", L["Spacing"], BASE .. "spacing", spacingMin, spacingMax, On())
		),
		Row(
			Slider("width", L["Width"], BASE .. "width", widthMin, widthMax, On()),
			Slider("height", L["Height"], BASE .. "height", heightMin, heightMax, On())
		),
		Row(
			Slider("x", L["X Offset"], BASE .. "x", -halfWidth, halfWidth, On({ blocked = Detached })),
			Slider("y", L["Y Offset"], BASE .. "y", -halfHeight, halfHeight, On({ blocked = Detached }))
		),
		Section("look", L["Appearance"]),
		Row(
			Check("border", L["Segment Borders"], BASE .. "border", On()),
			Check("classColor", L["Class-Colored Fill"], BASE .. "classColor", On())
		),
		Row(
			Pages.Color("chargedColor", L["Charged Color"], BASE .. "chargedColor", On({
				description = L["Combo points charged by a talent or effect."],
			})),
			Check("darkenPartial", L["Darken Partial Segments"], BASE .. "darkenPartial", On({
				description = L["Segments still filling, such as recharging runes, show darker until complete."],
			}))
		),
		Section("text", L["Text"]),
		Row(
			Check("text", L["Show Count"], BASE .. "text", On()),
			Slider("textSize", L["Text Size"], BASE .. "textSize", textMin, textMax, On())
		),
		Row(Check("runeTimers", L["Rune Countdowns"], BASE .. "runeTimers", On({
			description = L["Seconds until each recharging rune is ready."],
		}))),
		Section("visibility", L["Visibility"]),
		Row(Check("hideOutOfCombat", L["Hide Out of Combat"], BASE .. "hideOutOfCombat", On())),
		Section("extraMana", L["Extra Mana"]),
		Row(
			Check("extraMana", L["Show Extra Mana"], BASE .. "extraMana", On({
				description = L["A thin mana bar under the resource while mana is not your main power, such as in a druid form."],
			})),
			Slider("extraManaHeight", L["Extra Mana Height"], BASE .. "extraManaHeight", manaMin, manaMax,
				On({ depends = "extraMana" }))
		),
	}
end
