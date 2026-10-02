local AUI = select(2, ...)

local L = AUI.L
local Schema = AUI.Schema
local Pages = AUI.SettingsPages

local Section, Row, Choice, Slider, Check, Color = Pages.Section, Pages.Row, Pages.Choice, Pages.Slider, Pages.Check,
	Pages.Color

-- Offsets an attached bar takes from its frame, beyond the fixed gap.
local ATTACHED_OFFSET = 200

local SIDES = {
	below = L["Below"],
	above = L["Above"],
}

local STRATA = {
	BACKGROUND = L["Background"],
	LOW = L["Low"],
	MEDIUM = L["Medium"],
	HIGH = L["High"],
	DIALOG = L["Dialog"],
}

local ORIENTATIONS = {
	HORIZONTAL = L["Horizontal"],
	VERTICAL = L["Vertical"],
}

local ICON_SIDES = {
	LEFT = L["Left"],
	RIGHT = L["Right"],
}

local TIME_FORMATS = {
	remaining = L["Remaining"],
	elapsed = L["Elapsed"],
	remainingTotal = L["Remaining / Total"],
	elapsedTotal = L["Elapsed / Total"],
}

---The Cast Bar section of the player, target, focus and boss pages.
---@class AUISettingsCastBar
local CastBar = {}
AUI.SettingsCastBar = CastBar

---@param key string a frame with a cast bar
---@return table[] elements the frame page's Cast Bar section, or nothing for a frame without one
function CastBar:Sections(key)
	local base = "frames." .. key .. ".castbar."

	if not Schema:Field(base .. "enabled") then
		return {}
	end

	local attached = Schema:Field(base .. "side") ~= nil
	local offsetX, offsetY = ATTACHED_OFFSET, ATTACHED_OFFSET

	if not attached then
		offsetX, offsetY = math.floor(UIParent:GetWidth() / 2), math.floor(UIParent:GetHeight() / 2)
	end

	---@param fields table?
	---@return table fields the same fields, depending on Show Cast Bar unless they name another switch
	local function On(fields)
		fields = fields or {}
		fields.depends = fields.depends or "castEnabled"

		return fields
	end

	local widthMin, widthMax = Pages.Range(base .. "width")
	local heightMin, heightMax = Pages.Range(base .. "height")
	local sizeMin, sizeMax = Pages.Range(base .. "name.size")
	local lengthMin, lengthMax = Pages.Range(base .. "name.maxLength")
	local borderMin, borderMax = Pages.Range(base .. "border")
	local holdMin, holdMax = Pages.Range(base .. "holdTime")

	local elements = {
		Section("castBar", L["Cast Bar"]),
		Row(
			Check("castEnabled", L["Show Cast Bar"], base .. "enabled", {
				description = attached and nil or L["Replaces Blizzard's player cast bar while shown."],
			}),
			Choice("castStrata", L["Frame Strata"], base .. "strata", Pages.Options("strata", STRATA), On())
		),
	}

	local function Add(left, right)
		elements[#elements + 1] = Row(left, right)
	end

	local width = Slider("castWidth", L["Width"], base .. "width", widthMin, widthMax, On())

	if attached then
		width.blocked = function()
			if AUI.Profile:Get(base .. "matchWidth") then
				return L["Matches the frame's width."]
			end
		end

		Add(
			Choice("castSide", L["Position"], base .. "side", Pages.Options("castSide", SIDES), On()),
			Check("castMatchWidth", L["Match Frame Width"], base .. "matchWidth", On())
		)
	end

	Add(width, Slider("castHeight", L["Height"], base .. "height", heightMin, heightMax, On()))
	Add(
		Slider("castX", L["X Offset"], base .. "x", -offsetX, offsetX, On()),
		Slider("castY", L["Y Offset"], base .. "y", -offsetY, offsetY, On())
	)
	Add(
		Check("castAlwaysShow", L["Always Show"], base .. "alwaysShow", On({
			description = L["Keep the empty bar visible between casts."],
		})),
		Check("castSmooth", L["Smooth Animation"], base .. "smooth", On())
	)
	Add(
		Pages.Setting("dropdown", "castTexture", L["Bar Texture"], base .. "texture", On({
			picker = "texture",
			options = Pages.TEXTURES,
		})),
		Check("castReverse", L["Reverse Fill"], base .. "reverse", On())
	)
	Add(
		Color("castColor", L["Fill Color"], base .. "color", On()),
		Check("castClassColor", L["Class-Colored Fill"], base .. "classColor", On({
			description = L["Color the fill by the casting unit's class, when it has one."],
		}))
	)
	Add(
		Check("castGradient", L["Gradient"], base .. "gradient", On()),
		Choice("castGradientDirection", L["Gradient Direction"], base .. "gradientDirection",
			Pages.Options("orientation", ORIENTATIONS), On({ depends = "castGradient" }))
	)
	Add(
		Color("castGradientColor", L["Gradient End Color"], base .. "gradientColor", On({ depends = "castGradient" })),
		Color("castBackground", L["Background"], base .. "background", On({ hasOpacity = true }))
	)
	Add(
		Slider("castBorder", L["Border Size"], base .. "border", borderMin, borderMax, On()),
		Check("castSpark", L["Show Spark"], base .. "spark", On())
	)
	Add(
		Check("castIcon", L["Show Icon"], base .. "icon", On()),
		Choice("castIconSide", L["Icon Side"], base .. "iconSide", Pages.Options("iconSide", ICON_SIDES),
			On({ depends = "castIcon" }))
	)
	Add(
		Check("castName", L["Show Spell Name"], base .. "name.enabled", On()),
		Slider("castNameSize", L["Spell Name Size"], base .. "name.size", sizeMin, sizeMax, On({ depends = "castName" }))
	)
	Add(
		Color("castNameColor", L["Spell Name Color"], base .. "name.color", On({ depends = "castName" })),
		Slider("castNameLength", L["Max Length"], base .. "name.maxLength", lengthMin, lengthMax, On({
			depends = "castName",
			description = L["The most letters of a spell name shown. 0 shortens a name only where it meets the time."],
		}))
	)
	Add(
		Slider("castNameX", L["Spell Name X"], base .. "name.x", -ATTACHED_OFFSET, ATTACHED_OFFSET,
			On({ depends = "castName" })),
		Slider("castNameY", L["Spell Name Y"], base .. "name.y", -ATTACHED_OFFSET, ATTACHED_OFFSET,
			On({ depends = "castName" }))
	)
	Add(
		Check("castTime", L["Show Time"], base .. "time.enabled", On()),
		Choice("castTimeFormat", L["Time Format"], base .. "time.format", Pages.Options("timeFormat", TIME_FORMATS),
			On({ depends = "castTime" }))
	)
	Add(
		Slider("castTimeSize", L["Time Size"], base .. "time.size", sizeMin, sizeMax, On({ depends = "castTime" })),
		Color("castTimeColor", L["Time Color"], base .. "time.color", On({ depends = "castTime" }))
	)
	Add(
		Slider("castTimeX", L["Time X"], base .. "time.x", -ATTACHED_OFFSET, ATTACHED_OFFSET,
			On({ depends = "castTime" })),
		Slider("castTimeY", L["Time Y"], base .. "time.y", -ATTACHED_OFFSET, ATTACHED_OFFSET,
			On({ depends = "castTime" }))
	)
	Add(
		Choice("castOutline", L["Outline"], base .. "outline", Pages.Options("outline", Pages.OUTLINES), On()),
		Check("castShadow", L["Text Shadow"], base .. "shadow", On())
	)
	Add(
		Color("castNotInterruptible", L["Not Interruptible"], base .. "notInterruptible", On({
			description = L["The fill color while the cast cannot be interrupted."],
		})),
		Color("castInterrupted", L["Interrupted"], base .. "interrupted", On({
			description = L["The fill color while Interrupted or Failed shows."],
		}))
	)
	Add(Slider("castHoldTime", L["Hold Time"], base .. "holdTime", holdMin, holdMax, On({
		step = 0.1,
		format = "decimal",
		description = L["How long Interrupted or Failed stays on the bar, in seconds."],
	})))

	if Schema:Field(base .. "latency") then
		Add(
			Check("castLatency", L["Show Latency"], base .. "latency", On({
				description = L["Shades the end of the cast that falls within your latency."],
			})),
			Color("castLatencyColor", L["Latency Color"], base .. "latencyColor", On({
				depends = "castLatency",
				hasOpacity = true,
			}))
		)
		Add(Check("castLatencyText", L["Show Latency Text"], base .. "latencyText", On({ depends = "castLatency" })))
		Add(
			Check("castEmpowerColors", L["Colored Empowered Stages"], base .. "empowerColors", On({
				description = L["Colors each stage of an empowered cast as it charges."],
			})),
			Check("castStageLabel", L["Show Stage Label"], base .. "stageLabel", On({
				description = L["Shows the stage reached, and Hold at full charge, in place of the time."],
			}))
		)

		for index = 1, 4, 2 do
			Add(
				Color("castStage" .. index, L["Stage %d Color"]:format(index), base .. "stage." .. index,
					On({ depends = "castEmpowerColors" })),
				Color("castStage" .. index + 1, L["Stage %d Color"]:format(index + 1), base .. "stage." .. index + 1,
					On({ depends = "castEmpowerColors" }))
			)
		end
	end

	return elements
end
