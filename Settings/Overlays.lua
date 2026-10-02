local AUI = select(2, ...)

local L = AUI.L
local Schema = AUI.Schema
local Pages = AUI.SettingsPages

local Section, Row, Choice, Slider, Check = Pages.Section, Pages.Row, Pages.Choice, Pages.Slider, Pages.Check

local POSITIONS = {
	attach = L["Attach"],
	TOPLEFT = L["Top Left"],
	TOPRIGHT = L["Top Right"],
	BOTTOMLEFT = L["Bottom Left"],
	BOTTOMRIGHT = L["Bottom Right"],
	LEFT = L["Left"],
	RIGHT = L["Right"],
}

local OVERSHIELD = {
	never = L["Never"],
	always = L["Always"],
	fromLeft = L["From Left"],
}

---The Absorbs and Heals sections: the overlay rows of each frame page, and the shared colors on Globals.
---@class AUISettingsOverlays
local Overlays = {}
AUI.SettingsOverlays = Overlays


---@param path string the overlay's path, ending in a dot
---@return fun(): string? blocked a reason while the overlay is not attached
local function OnlyAttached(path)
	return function()
		if AUI.Profile:Get(path .. "position") ~= "attach" then
			return L["Only in the Attach position."]
		end
	end
end

---The rows one overlay shares with the others: show, position, height and texture.
---@param path string the overlay's path, ending in a dot
---@param id string
---@param labels table `show`, `position`, `height`, `texture`
---@param extra table? the setting paired with the texture
---@return table[] elements
local function Common(path, id, labels, extra)
	local heightMin, heightMax = Pages.Range(path .. "height")
	local options = function()
		return Pages.Options("overlayPosition", POSITIONS)
	end

	return {
		Row(
			Check(id, labels.show, path .. "enabled"),
			Choice(id .. "Position", labels.position, path .. "position", options, { depends = id })
		),
		Row(
			Check(id .. "Match", L["Match Health Height"], path .. "matchHeight", { depends = id }),
			Slider(id .. "Height", labels.height, path .. "height", heightMin, heightMax, {
				depends = id,
				blocked = function()
					if AUI.Profile:Get(path .. "matchHeight") then
						return L["Matches the health bar's height."]
					end
				end,
			})
		),
		Row(
			Pages.Setting("dropdown", id .. "Texture", labels.texture, path .. "texture", {
				picker = "texture",
				options = Pages.TEXTURES,
				depends = id,
			}),
			extra
		),
	}
end

---@param key string a frame with overlays
---@return table[] elements the frame page's Absorbs and Heals section, or nothing for a frame without overlays
function Overlays:Sections(key)
	local base = "frames." .. key .. ".overlays."

	if not Schema:Field(base .. "absorb.enabled") then
		return {}
	end

	local absorb, healAbsorb, prediction = base .. "absorb.", base .. "healAbsorb.", base .. "healPrediction."
	local elements = { Section("absorbsAndHeals", L["Absorbs and Heals"]) }

	local function Append(list)
		for _, element in ipairs(list) do
			elements[#elements + 1] = element
		end
	end

	Append(Common(absorb, "absorb", {
		show = L["Show Absorbs"],
		position = L["Absorb Position"],
		height = L["Absorb Height"],
		texture = L["Absorb Texture"],
	}, Choice("overshield", L["Show Overshield"], absorb .. "overshield", Pages.Options("overshield", OVERSHIELD), {
		depends = "absorb",
		blocked = OnlyAttached(absorb),
		description = L["The part of a shield larger than the missing health. Always draws it back over the health from the shield's edge; From Left grows it from the other end of the bar; Never hides it."],
	})))
	elements[#elements + 1] = Row(Check("glow", L["Blizzard Glow Line"], absorb .. "glow", {
		depends = "absorb",
		blocked = OnlyAttached(absorb),
		description = L["Blizzard's shield glow where the shield meets current health."],
	}))

	Append(Common(healAbsorb, "healAbsorb", {
		show = L["Show Heal Absorbs"],
		position = L["Heal Absorb Position"],
		height = L["Heal Absorb Height"],
		texture = L["Heal Absorb Texture"],
	}, Slider("backing", L["Backing Opacity"], healAbsorb .. "backing", 0, 100, {
		depends = "healAbsorb",
		format = "percent",
		step = 5,
		description = L["Darkens the health under heal absorbs."],
	})))

	Append(Common(prediction, "healPrediction", {
		show = L["Show Heal Prediction"],
		position = L["Heal Prediction Position"],
		height = L["Heal Prediction Height"],
		texture = L["Heal Prediction Texture"],
	}, Slider("overheal", L["Overheal"], prediction .. "overheal", 0, 50, {
		depends = "healPrediction",
		format = "percent",
		description = L["How far incoming heals can extend past the end of the health bar, as a percent of its length. 0 keeps them inside the bar."],
	})))

	return elements
end

---@return table[] elements the Globals page's Absorbs and Heals colors
function Overlays:GlobalSection()
	return {
		Section("absorbsAndHeals", L["Absorbs and Heals"]),
		Row(
			Pages.Color("absorbColor", L["Absorb Color"], "overlays.colors.absorb", { hasOpacity = true }),
			Pages.Color("healAbsorbColor", L["Heal Absorb Color"], "overlays.colors.healAbsorb", { hasOpacity = true })
		),
		Row(Pages.Color("healPredictionColor", L["Heal Prediction Color"], "overlays.colors.healPrediction", {
			hasOpacity = true,
		})),
	}
end
