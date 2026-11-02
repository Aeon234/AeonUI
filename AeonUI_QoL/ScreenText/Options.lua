local AUI = select(2, ...)

local Schema = AUI.Schema

---The Screen Text settings and the frame-free arithmetic behind them. The shared font, size and outline apply to every
---line; each line follows them until set. Sizes are percentages of the size Blizzard gives that line.
---@class AUIScreenTextOptions
---@field ENABLED_PATH string AeonUI styles the screen text
---@field LINES string[] the lines, in the order the page lists them
---@field FIELDS string[] the text settings each line has
---@field MIN_SCALE number
---@field MAX_SCALE number
local Options = {
	ENABLED_PATH = "screenText.enabled",
	-- messages: the error and objective lines, which share one frame and one font. pvp: the territory line under the zone
	-- or subzone.
	LINES = { "messages", "zone", "subZone", "pvp" },
	FIELDS = { "font", "size", "outline" },
	MIN_SCALE = 50,
	MAX_SCALE = 200,
}
AUI.ScreenTextOptions = Options

Schema:Boolean(Options.ENABLED_PATH, false)
Schema:String("screenText.text.font", "Friz Quadrata TT", 64)
Schema:Number("screenText.text.size", 100, Options.MIN_SCALE, Options.MAX_SCALE, true)
Schema:Choice("screenText.text.outline", "fontOutline", "SLUG")

for _, line in ipairs(Options.LINES) do
	for _, field in ipairs(Options.FIELDS) do
		Schema:Inherit("screenText." .. line .. "." .. field, "screenText.text." .. field)
	end
end

---@param line string? one of `LINES`; nil for the shared settings
---@param field string one of `FIELDS`
---@return string path
function Options:Path(line, field)
	return "screenText." .. (line or "text") .. "." .. field
end

---@param base number Blizzard's size for the line
---@param scale number the size setting, in percent
---@return number size rounded to the nearest whole size, at least 1
function Options:FontSize(base, scale)
	return math.max(1, math.floor(base * scale / 100 + 0.5))
end

---The message frame's size for a font scale: Blizzard's size grown with the font, never smaller.
---@param width number Blizzard's width
---@param height number Blizzard's height
---@param scale number the size setting, in percent
---@return number width
---@return number height
function Options:FrameSize(width, height, scale)
	local factor = math.max(1, scale / 100)

	return width * factor, height * factor
end
