local AUI = select(2, ...)

local Schema = AUI.Schema

---@class AUIFrameSpec
---@field key string the frame's key under `frames` in the profile
---@field unit string
---@field name string the frame's global name
---@field page string the frame's settings page
---@field slots integer how many text slots it has
---@field overlays boolean? it shows shields, heal absorbs and heal prediction
---@field position { point: string, x: number, y: number } its place until moved

---The unit frames' settings: every frame's, and the shared ones they follow. Holds no frame code.
---@class AUIUnitFrameOptions
---@field FRAMES AUIFrameSpec[] in creation order
local Options = {
	FRAMES = {
		{
			key = "player",
			unit = "player",
			name = "AeonUIPlayer",
			page = "unitFramePlayer",
			slots = 4,
			overlays = true,
			position = { point = "CENTER", x = -330, y = -200 },
		},
	},
	CONTENTS = {
		"none", "name", "level", "levelName", "health", "healthPercent", "healthAndPercent", "missingHealth",
		"absorb", "healAbsorb", "power", "powerPercent",
	},
	SEPARATORS = { "bar", "dash", "slash", "space", "parentheses", "brackets", "bullet" },
	ANCHORS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" },
	PLACEMENTS = { "inside", "edge", "outside" },
	COLOR_MODES = { "custom", "class", "power", "difficulty" },
	NAME_FORMATS = { "first", "full" },
	PRECISIONS = { "default", "decimal" },
	HEALTH_MODES = { "classReaction", "custom", "classic", "stops", "classFade" },
	HEALTH_BACKGROUNDS = { "custom", "classReaction" },
	ORIENTATIONS = { "HORIZONTAL", "VERTICAL" },
	OVERLAY_KINDS = { "absorb", "healAbsorb", "healPrediction" },
	OVERLAY_POSITIONS = { "attach", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "LEFT", "RIGHT" },
	OVERSHIELDS = { "never", "always", "fromLeft" },
	MIN_OVERLAY_HEIGHT = 1,
	MAX_OVERLAY_HEIGHT = 40,
	MAX_OVERHEAL = 50,
	-- The health colors a frame can change, as paths under its `health.`.
	HEALTH_LOOK = {
		"mode", "color", "stops.full", "stops.half", "stops.empty", "gradient", "gradientDirection", "gradientColor",
		"background", "fillAlpha", "deadBackground", "deadColor", "dark", "darkFill", "darkBackground",
	},
	ALL = "frames.all.",
	MIN_WIDTH = 80,
	MAX_WIDTH = 600,
	MIN_HEIGHT = 16,
	MAX_HEIGHT = 120,
	-- AeonUI's own border styles; any other value names a LibSharedMedia border.
	BORDER_STYLES = { "FOREVER_MINIMAL", "FOREVER", "SLATE", "THIN_LINE", "NONE" },
	-- Border styles that lighten on hover instead of taking the Hover Color.
	LIGHTENED = { FOREVER_MINIMAL = true, FOREVER = true },
	-- How far Forever Minimal's color moves toward white on hover.
	LIGHTEN = 0.4,
	MIN_BORDER_THICKNESS = 50,
	MAX_BORDER_THICKNESS = 300,
	MIN_TEXT = 6,
	MAX_TEXT = 48,
	MAX_OFFSET = 200,
	MIN_SLOT_WIDTH = 20,
	MAX_SLOT_WIDTH = 200,
}
AUI.UnitFrameOptions = Options

---@param style string a saved border style
---@return boolean own it is one of AeonUI's own
function Options:IsOwnBorderStyle(style)
	for _, own in ipairs(self.BORDER_STYLES) do
		if own == style then
			return true
		end
	end

	return false
end

---@param key string
---@return AUIFrameSpec? spec
function Options:Spec(key)
	for _, spec in ipairs(self.FRAMES) do
		if spec.key == key then
			return spec
		end
	end
end

---@param key string
---@param rest string the rest of the path
---@return string path
function Options:Path(key, rest)
	return "frames." .. key .. "." .. rest
end

---@param key string
---@param index integer
---@param field string
---@return string path
function Options:SlotPath(key, index, field)
	return self:Path(key, "text.slots." .. index .. "." .. field)
end

Schema:Choices("unitFrameContent", Options.CONTENTS)
Schema:Choices("unitFrameSeparator", Options.SEPARATORS)
Schema:Choices("unitFrameAnchor", Options.ANCHORS)
Schema:Choices("unitFramePlacement", Options.PLACEMENTS)
Schema:Choices("unitFrameColorMode", Options.COLOR_MODES)
Schema:Choices("unitFrameNameFormat", Options.NAME_FORMATS)
Schema:Choices("unitFramePrecision", Options.PRECISIONS)
Schema:Choices("unitFrameHealthMode", Options.HEALTH_MODES)
Schema:Choices("unitFrameHealthBackground", Options.HEALTH_BACKGROUNDS)
Schema:Choices("unitFrameOrientation", Options.ORIENTATIONS)
Schema:Choices("unitFrameOverlayPosition", Options.OVERLAY_POSITIONS)
Schema:Choices("unitFrameOvershield", Options.OVERSHIELDS)

Schema:String(Options.ALL .. "bars.texture", "Solid", 64)
Schema:Color(Options.ALL .. "bars.background", { r = 0.067, g = 0.067, b = 0.067, a = 1 })
Schema:String(Options.ALL .. "bars.borderStyle", "THIN_LINE", 64)
Schema:Number(Options.ALL .. "bars.borderThickness", 100, Options.MIN_BORDER_THICKNESS, Options.MAX_BORDER_THICKNESS, true)
Schema:Color(Options.ALL .. "bars.borderColor", AUI.Border.ART_COLOR)
Schema:Color(Options.ALL .. "bars.lineColor", { r = 0, g = 0, b = 0, a = 1 })
Schema:Boolean(Options.ALL .. "bars.hover", true)
Schema:Color(Options.ALL .. "bars.hoverColor", { r = 1, g = 1, b = 1 })
Schema:String(Options.ALL .. "text.font", "Expressway", 64)
Schema:Number(Options.ALL .. "text.size", 12, Options.MIN_TEXT, Options.MAX_TEXT, true)
Schema:Choice(Options.ALL .. "text.outline", "fontOutline", "SLUG")
Schema:Color(Options.ALL .. "text.color", { r = 1, g = 1, b = 1 })
Schema:Choice(Options.ALL .. "numbers.precision", "unitFramePrecision", "default")
Schema:Number(Options.ALL .. "numbers.percentDecimals", 0, 0, 1, true)
Schema:Choice(Options.ALL .. "health.mode", "unitFrameHealthMode", "classReaction")
Schema:Color(Options.ALL .. "health.color", { r = 0.192, g = 0.812, b = 0.145 })
Schema:Color(Options.ALL .. "health.stops.full", { r = 0, g = 1, b = 0 })
Schema:Color(Options.ALL .. "health.stops.half", { r = 0.925, g = 0.925, b = 0.196 })
Schema:Color(Options.ALL .. "health.stops.empty", { r = 0.890, g = 0.188, b = 0.188 })
Schema:Boolean(Options.ALL .. "health.gradient", false)
Schema:Choice(Options.ALL .. "health.gradientDirection", "unitFrameOrientation", "HORIZONTAL")
Schema:Color(Options.ALL .. "health.gradientColor", { r = 0.1, g = 0.1, b = 0.1, a = 1 })
Schema:Choice(Options.ALL .. "health.background", "unitFrameHealthBackground", "custom")
Schema:Number(Options.ALL .. "health.fillAlpha", 100, 0, 100, true)
Schema:Boolean(Options.ALL .. "health.deadBackground", false)
Schema:Color(Options.ALL .. "health.deadColor", { r = 0.35, g = 0.05, b = 0.05, a = 1 })
Schema:Boolean(Options.ALL .. "health.dark", false)
Schema:Color(Options.ALL .. "health.darkFill", { r = 0.067, g = 0.067, b = 0.067, a = 0.9 })
Schema:Color(Options.ALL .. "health.darkBackground", { r = 0.31, g = 0.31, b = 0.31, a = 1 })
Schema:Boolean(Options.ALL .. "health.tapped", true)
Schema:Color(Options.ALL .. "health.tappedColor", { r = 0.6, g = 0.6, b = 0.6 })
Schema:Boolean(Options.ALL .. "health.disconnected", true)
Schema:Color(Options.ALL .. "health.disconnectedColor", { r = 0.6, g = 0.6, b = 0.6 })
Schema:Color(Options.ALL .. "health.reaction.hostile", nil)
Schema:Color(Options.ALL .. "health.reaction.neutral", nil)
Schema:Color(Options.ALL .. "health.reaction.friendly", nil)
Schema:Color(Options.ALL .. "overlays.colors.absorb", { r = 0.502, g = 0.753, b = 1, a = 0.8 })
Schema:Color(Options.ALL .. "overlays.colors.healAbsorb", { r = 0.502, g = 0.251, b = 1, a = 1 })
Schema:Color(Options.ALL .. "overlays.colors.healPrediction", { r = 0.251, g = 1, b = 0.251, a = 1 })

for _, kind in ipairs(Options.OVERLAY_KINDS) do
	Schema:String(Options.ALL .. "overlays.textures." .. kind, "Solid", 64)
end

---A frame's shields, heal absorbs and heal prediction.
---@param key string
local function DeclareOverlays(key)
	for _, kind in ipairs(Options.OVERLAY_KINDS) do
		local path = Options:Path(key, "overlays." .. kind .. ".")

		Schema:Boolean(path .. "enabled", true)
		Schema:Choice(path .. "position", "unitFrameOverlayPosition", "attach")
		Schema:Number(path .. "height", 4, Options.MIN_OVERLAY_HEIGHT, Options.MAX_OVERLAY_HEIGHT, true)
		Schema:Boolean(path .. "matchHeight", true)
		Schema:Inherit(path .. "texture", Options.ALL .. "overlays.textures." .. kind)
	end

	Schema:Choice(Options:Path(key, "overlays.absorb.overshield"), "unitFrameOvershield", "always")
	Schema:Boolean(Options:Path(key, "overlays.absorb.glow"), false)
	Schema:Number(Options:Path(key, "overlays.healAbsorb.backing"), 0, 0, 100, true)
	Schema:Number(Options:Path(key, "overlays.healPrediction.overheal"), 0, 0, Options.MAX_OVERHEAL, true)
end

---@class AUITextSlotDefault
---@field content string
---@field anchor string
---@field placement string
---@field x number?

---@param key string
---@param index integer
---@param slot AUITextSlotDefault?
local function DeclareSlot(key, index, slot)
	slot = slot or { content = "none", anchor = "CENTER", placement = "inside" }

	Schema:Choice(Options:SlotPath(key, index, "content"), "unitFrameContent", slot.content)
	Schema:Choice(Options:SlotPath(key, index, "separator"), "unitFrameSeparator", "dash")
	Schema:Choice(Options:SlotPath(key, index, "anchor"), "unitFrameAnchor", slot.anchor)
	Schema:Choice(Options:SlotPath(key, index, "placement"), "unitFramePlacement", slot.placement)
	Schema:Number(Options:SlotPath(key, index, "x"), slot.x or 0, -Options.MAX_OFFSET, Options.MAX_OFFSET)
	Schema:Number(Options:SlotPath(key, index, "y"), 0, -Options.MAX_OFFSET, Options.MAX_OFFSET)
	Schema:Number(Options:SlotPath(key, index, "width"), 100, Options.MIN_SLOT_WIDTH, Options.MAX_SLOT_WIDTH, true)
	Schema:Choice(Options:SlotPath(key, index, "colorMode"), "unitFrameColorMode", "custom")

	for _, field in ipairs({ "font", "size", "outline", "color" }) do
		Schema:Inherit(Options:SlotPath(key, index, field), Options:Path(key, "text." .. field))
	end
end

---@param spec AUIFrameSpec
---@param width number
---@param height number
---@param status integer the slot that shows the unit's status; 0 for none
---@param slots AUITextSlotDefault[]
local function DeclareFrame(spec, width, height, status, slots)
	local key = spec.key

	Schema:Boolean(Options:Path(key, "enabled"), false)
	Schema:Position(Options:Path(key, "position"))
	Schema:Number(Options:Path(key, "width"), width, Options.MIN_WIDTH, Options.MAX_WIDTH)
	Schema:Number(Options:Path(key, "height"), height, Options.MIN_HEIGHT, Options.MAX_HEIGHT)
	Schema:Boolean(Options:Path(key, "reverse"), false)

	for _, field in ipairs({ "texture", "background", "borderStyle", "borderThickness", "borderColor", "lineColor", "hover", "hoverColor" }) do
		Schema:Inherit(Options:Path(key, "bars." .. field), Options.ALL .. "bars." .. field)
	end

	for _, field in ipairs({ "font", "size", "outline", "color" }) do
		Schema:Inherit(Options:Path(key, "text." .. field), Options.ALL .. "text." .. field)
	end

	for _, field in ipairs({ "precision", "percentDecimals" }) do
		Schema:Inherit(Options:Path(key, "numbers." .. field), Options.ALL .. "numbers." .. field)
	end

	for _, field in ipairs(Options.HEALTH_LOOK) do
		Schema:Inherit(Options:Path(key, "health." .. field), Options.ALL .. "health." .. field)
	end

	if spec.overlays then
		DeclareOverlays(key)
	end

	Schema:Number(Options:Path(key, "text.status"), status, 0, spec.slots, true)
	Schema:Choice(Options:Path(key, "text.nameFormat"), "unitFrameNameFormat", "first")

	for index = 1, spec.slots do
		DeclareSlot(key, index, slots[index])
	end
end

DeclareFrame(Options:Spec("player") --[[@as AUIFrameSpec]], 270, 36, 1, {
	{ content = "healthAndPercent", anchor = "TOPRIGHT", placement = "edge", x = -4 },
})
