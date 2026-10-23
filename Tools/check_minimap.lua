-- Checks the Minimap module outside the game: the map's geometry, its settings and their bounds, stored positions, the
-- automatic zoom reset, keeping rotation off, which profile changes re-apply the map, the rows' layout, which elements
-- each row holds, the border's row gaps and the fade targets.
-- Run from any directory with Lua 5.1: lua Tools/check_minimap.lua
-- Loads the real files against stubbed globals. It proves the logic, not the drawing.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

UNKNOWN = "Unknown"
TIMEMANAGER_TICKER_24HOUR = "%02d:%02d"
TIME_TWELVEHOURAM = "%d:%02d AM"
TIME_TWELVEHOURPM = "%d:%02d PM"
NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
SlashCmdList = {}
C_AddOns = {
	GetAddOnMetadata = function() end,
}

function CallErrorHandler(message)
	error(message, 0)
end

local luaXpcall = xpcall
function xpcall(fn, handler, ...)
	local count, args = select("#", ...), { ... }

	return luaXpcall(function()
		return fn(unpack(args, 1, count))
	end, handler)
end

function CreateFrame()
	return { RegisterEvent = function() end, UnregisterEvent = function() end, SetScript = function() end }
end

-- Blizzard's minimap, modeled with only the zoom methods the module's handlers call.
Minimap = { zoom = 0, levels = 6 }
function Minimap:GetZoom()
	return self.zoom
end
function Minimap:GetZoomLevels()
	return self.levels
end
function Minimap:SetZoom(zoom)
	self.zoom = zoom
end

local ignored = 0
C_Minimap = {
	SetIgnoreRotateMinimap = function(ignore)
		if ignore then
			ignored = ignored + 1
		end
	end,
}

local timers = {}
C_Timer = {
	NewTimer = function(delay, callback)
		local timer = { delay = delay, callback = callback, cancelled = false }

		function timer:Cancel()
			self.cancelled = true
		end

		timers[#timers + 1] = timer

		return timer
	end,
}

local inCombat = false
function InCombatLockdown()
	return inCombat
end

function Mixin(object, ...)
	for index = 1, select("#", ...) do
		for key, value in pairs((select(index, ...))) do
			object[key] = value
		end
	end

	return object
end

local AUI = {}
assert(loadfile(root .. "Core/Core.lua"))("AeonUI", AUI)
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
for _, file in ipairs({ "Core/Callbacks.lua", "Profile/Schema.lua", "UI/Border.lua", "Minimap/Layout.lua",
	"Minimap/Elements.lua", "Minimap/Rows.lua", "Minimap/Fade.lua", "Minimap/Text.lua", "Minimap/Difficulty.lua",
	"Minimap/Buttons.lua", "Minimap/Map.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Schema, Map = AUI.Schema, AUI.Minimap

-- A profile owner reduced to reading the schema's defaults and stored values.
local stored = {}
AUI.Profile = {
	Get = function(_, path)
		return Schema:Read(stored, path)
	end,
}

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

-- Geometry ------------------------------------------------------------------------------------------------

local wide = Map:Geometry(240, 180)
Equal("a wide map stays square at its width", wide.side, 240)
Equal("4:3 lands on a mask exactly", wide.height, 180)
Equal("its mask is the wide one for 192 rows", wide.mask:match("[^\\]+$"), "Wide-192")
Equal("it is cropped at the top and bottom", wide.insetY, 30)
Equal("and not at the sides", wide.insetX, 0)
Equal("the visible width is the setting's", wide.width, 240)
local tall = Map:Geometry(220, 300)
Equal("a tall map stays square at its height", tall.side, 300)
Equal("its mask is a tall one", tall.mask:match("[^\\]+$"), "Tall-188")
Equal("the short side snaps to the mask", tall.width, 300 * 188 / 256)
Equal("it is cropped at the sides", tall.insetX, (300 - tall.width) / 2)
Equal("and not at the top and bottom", tall.insetY, 0)
local square = Map:Geometry(200, 200)
Equal("a square map is not cropped", square.insetX + square.insetY, 0)
Equal("and uses Blizzard's white square", square.mask, "Interface\\BUTTONS\\WHITE8X8")
local narrow = Map:Geometry(400, 100)
Equal("a shape past 3:2 is kept at 3:2", narrow.mask:match("[^\\]+$"), "Wide-172")
Equal("so its height is two thirds of its width or a little more", narrow.height >= 400 / 1.5, true)
local skinny = Map:Geometry(140, 400)
Equal("a tall shape past 3:2 is kept at 3:2", skinny.mask:match("[^\\]+$"), "Tall-172")
local low, high = Map:HeightRange(240)
Equal("the shortest height for a width", low, 160)
Equal("the tallest height for a width", high, 360)
local near = Map:Geometry(250, 249)
Equal("nearly square snaps to square", near.mask, "Interface\\BUTTONS\\WHITE8X8")

-- Every mask the geometry can name exists.
local names = {}
for width = 140, 400, 10 do
	for height = 100, 400, 10 do
		local mask = Map:Geometry(width, height).mask:match("[^\\]+$")

		names[mask] = true
	end
end
for mask in pairs(names) do
	if mask ~= "WHITE8X8" then
		local file = io.open(root .. "Media/Textures/Masks/" .. mask .. ".tga", "rb")

		Equal(mask .. " exists", file ~= nil, true)

		if file then
			file:close()
		end
	end
end

-- Settings ------------------------------------------------------------------------------------------------

Equal("on by default", Schema:Read(stored, "minimap.enabled"), true)
Equal("default width", Schema:Read(stored, "minimap.width"), 240)
Equal("default height", Schema:Read(stored, "minimap.height"), 180)
Equal("default border", Schema:Read(stored, "minimap.border.style"), "METAL")
Equal("border color defaults to the art's own", Schema:Read(stored, "minimap.border.color").r, AUI.Border.ART_COLOR.r)
Equal("no automatic zoom reset by default", Schema:Read(stored, "minimap.zoom.reset"), 0)
Equal("Blizzard's border thickness by default", Schema:Read(stored, "minimap.border.thickness"), 100)
Equal("too thin", (Schema:CheckValue("minimap.border.thickness", 40)), false)

-- Border fit -------------------------------------------------------------------------------------------------------

local Border = AUI.Border
Equal("a map big enough keeps the art's scale", Border:FitScale(48, 15, 240, 0.5), 0.5)
Equal("a map too small for two corners draws them smaller", Border:FitScale(48, 15, 20, 0.5), 20 / 66)
Equal("corners inside the outset never shrink the art", Border:FitScale(10, 15, 20, 0.5), 0.5)
Equal("every Forever style names its art", Border.ART.FOREVER.file ~= nil and Border.ART.FOREVER_MINIMAL.file ~= nil,
	true)
Equal("no stored position by default", Schema:Read(stored, "minimap.position"), nil)
Equal("every border style is a choice", #Schema.choices.minimapBorderStyle, #AUI.Border.STYLES)
Equal("too narrow", (Schema:CheckValue("minimap.width", 100)), false)
Equal("too tall", (Schema:CheckValue("minimap.height", 500)), false)
Equal("an unknown border", (Schema:CheckValue("minimap.border.style", "GOLD")), false)

-- Positions -------------------------------------------------------------------------------------------------

Equal("a position", (Schema:CheckValue("minimap.position", { point = "TOPRIGHT", x = -20, y = -20 })), true)
Equal("cleared to the default place", (Schema:CheckValue("minimap.position", nil)), true)
Equal("an unknown point", (Schema:CheckValue("minimap.position", { point = "MIDDLE", x = 0, y = 0 })), false)
Equal("a missing offset", (Schema:CheckValue("minimap.position", { point = "TOP", x = 0 })), false)
Equal("an infinite offset", (Schema:CheckValue("minimap.position", { point = "TOP", x = 1 / 0, y = 0 })), false)
Equal("an extra key", (Schema:CheckValue("minimap.position", { point = "TOP", x = 0, y = 0, scale = 1 })), false)
Equal("not a table", (Schema:CheckValue("minimap.position", "TOP")), false)
Equal("the default place is a valid position", (Schema:CheckValue("minimap.position", Map.DEFAULT_POSITION)), true)

-- Zoom reset ------------------------------------------------------------------------------------------------

Minimap.zoom = 3
Map:OnZoomChanged()
Equal("no timer while the reset is off", #timers, 0)
stored.minimap = { zoom = { reset = 10 } }
Map:OnZoomChanged()
Equal("a zoom starts the timer", #timers, 1)
Equal("for the chosen delay", timers[1].delay, 10)
Map:OnZoomChanged()
Equal("another zoom cancels the first timer", timers[1].cancelled, true)
Equal("and starts a new one", #timers, 2)
timers[2].callback()
Equal("the timer zooms all the way out", Minimap.zoom, 0)
Equal("and forgets itself", Map.resetTimer, nil)
Map:OnZoomChanged()
Equal("no timer at the widest zoom", #timers, 2)

-- Rotation ---------------------------------------------------------------------------------------------------

ignored = 0
Map:OnCVarUpdate("CVAR_UPDATE", "rotateMinimap")
Equal("switching rotation keeps the map north up", ignored, 1)
Map:OnCVarUpdate("CVAR_UPDATE", "ROTATEMINIMAP")
Equal("whatever the CVar's case", ignored, 2)
Map:OnCVarUpdate("CVAR_UPDATE", "cameraDistanceMaxZoomFactor")
Equal("other CVars are ignored", ignored, 2)

-- Row layout -------------------------------------------------------------------------------------------------

local Layout = AUI.MinimapLayout
local PADDING, SPACING = Layout.PADDING, Layout.SPACING

local cells, dividers = Layout:Row({
	{ key = "zone", kind = "text", width = 60, flexible = true },
	{ key = "difficulty", kind = "text", width = 30 },
	{ key = "clock", kind = "text", width = 40 },
}, 240, 22)
Equal("the first cell starts at the padding", cells[1].x, PADDING)
Equal("the flexible zone takes the room left over", cells[1].width, 240 - 2 * PADDING - 2 * SPACING - 30 - 40)
Equal("so the last cell ends at the right padding", cells[3].x + cells[3].width, 240 - PADDING)
Equal("cells keep their natural widths", cells[2].width .. " " .. cells[3].width, "30 40")
Equal("no divider follows the flexible zone, only the next pair", #dividers, 1)
Equal("each divider sits in the middle of the space before its cell", dividers[1], cells[3].x - SPACING / 2)

cells, dividers = Layout:Row({
	{ key = "mail", kind = "button" },
	{ key = "tracking", kind = "button" },
	{ key = "coordinates", kind = "text", width = 50 },
	{ key = "calendar", kind = "button" },
	{ key = "compartment", kind = "button" },
}, 240, 22)
Equal("buttons are square at the row's height", cells[1].width, 22)
Equal("cells run in their order", cells[2].x, PADDING + 22 + SPACING)
Equal("buttons after the text end at the right padding", cells[5].x + cells[5].width, 240 - PADDING)
local slotLeft, slotRight = cells[2].x + 22 + SPACING, cells[4].x - SPACING
Equal("text that is not flexible is centered in the room left over", cells[3].x - slotLeft,
	slotRight - (cells[3].x + cells[3].width))
Equal("at its natural width", cells[3].width, 50)
Equal("dividers bound the text's whole room", dividers[2], slotLeft - SPACING / 2)

cells = Layout:Row({ { key = "mail", kind = "button" }, { key = "calendar", kind = "button" } }, 240, 22)
Equal("a row of buttons sits at the right", cells[2].x + 22, 240 - PADDING)

cells = Layout:Row({
	{ key = "zone", kind = "text", width = 300, flexible = true },
	{ key = "clock", kind = "text", width = 30 },
	{ key = "mail", kind = "button" },
}, 240, 22)
Equal("a flexible cell shrinks to leave room for the rest", cells[1].width, 240 - 2 * PADDING - 2 * SPACING - 30 - 22)
Equal("and the rest keep their width", cells[2].width, 30)
Equal("the last cell still ends inside the row", cells[3].x + cells[3].width, 240 - PADDING)

cells, dividers = Layout:Row({
	{ key = "a", kind = "text", width = 200 },
	{ key = "b", kind = "text", width = 100 },
}, 240, 22)
Equal("text that does not fit shrinks in proportion", math.floor(cells[1].width / cells[2].width * 1000 + 0.5), 2000)
Equal("and fills the row", math.floor(cells[2].x + cells[2].width + 0.5), 240 - PADDING)

cells, dividers = Layout:Row({
	{ key = "a", kind = "button" }, { key = "b", kind = "button" }, { key = "c", kind = "button" },
}, 70, 22)
Equal("a button past the room is dropped", cells[3].width, 0)
Equal("and has no divider", #dividers, 1)

local function Compute(rows)
	return Layout:Compute({ width = 240, mapHeight = 180, rowHeight = 22, separator = 2, divider = 4, rows = rows })
end

local bare = Compute({})
Equal("without rows the assembly is the map", bare.height, 180)
Equal("and the map is at its top", bare.mapTop, 0)
Equal("with nothing above or below", bare.top == nil and bare.bottom == nil, true)

local text = { { key = "zone", kind = "text", width = 50 } }
local both = Compute({ TOP1 = text, TOP2 = text, BOTTOM1 = text })
Equal("two rows and a divider above", both.top.height, 22 + 4 + 22)
Equal("the divider starts after the outer row", both.top.divider, 22)
Equal("one row below has no divider", both.bottom.divider, nil)
Equal("the map sits under the rows and the separator", both.mapTop, 48 + 2)
Equal("the assembly holds everything", both.height, 50 + 180 + 2 + 22)
Equal("rows run top to bottom", both.rows[1].key .. both.rows[2].key .. both.rows[3].key, "TOP1TOP2BOTTOM1")
Equal("Top 2 follows the divider", both.rows[2].y, 26)
Equal("Bottom 1 follows the map and the separator", both.rows[3].y, 50 + 180 + 2)
local inner = Compute({ TOP2 = text, BOTTOM2 = text, BOTTOM1 = {} })
Equal("a lone row sits at the edge, whichever it is", inner.rows[1].y, 0)
Equal("an empty row is not drawn", #inner.rows, 2)

-- Row gaps -----------------------------------------------------------------------------------------------------

local separator, divider = Border:Gaps("METAL", 100, 0.5)
Equal("metal rows meet the map along the band's middle", separator, 2.25)
Equal("metal rows are divided by the band", divider, 4.5)
separator = Border:Gaps("METAL", 200, 0.5)
Equal("the metal gaps follow the thickness", separator, 4.5)
separator, divider = Border:Gaps("FOREVER", 100, 0.5)
Equal("the Forever band separates at Blizzard's width", separator, 2)
Equal("and divides the same", divider, 2)
Equal("a thin line is one pixel", (Border:Gaps("THIN_LINE", 100, 0.5)), 0.5)
Equal("no border leaves no gap", (Border:Gaps("NONE", 100, 0.5)), 0)

-- Elements -----------------------------------------------------------------------------------------------------

local Elements = AUI.MinimapElements
local defaults = Elements:DefaultLayout()
Equal("Top 1 starts with the zone, the difficulty and the clock", table.concat(defaults.TOP1, " "),
	"zone difficulty clock")
Equal("Top 2 starts with the buttons around the coordinates", table.concat(defaults.TOP2, " "),
	"mail craftingOrders tracking coordinates calendar compartment")
Equal("nothing starts below the map or off it", #defaults.BOTTOM1 + #defaults.BOTTOM2 + #defaults.HIDDEN, 0)
Equal("no saved layout is the default", table.concat(Elements:FullLayout(nil).TOP1, " "), "zone difficulty clock")
local full = Elements:FullLayout({ TOP1 = { "clock", "zone", "gone" }, HIDDEN = { "difficulty", "clock" } })
Equal("a saved layout keeps its order and drops unknown keys", table.concat(full.TOP1, " "), "clock zone")
Equal("each element is in one list, the first that names it", table.concat(full.HIDDEN, " "), "difficulty")
Equal("an element the saved layout lacks returns after its default neighbor", table.concat(full.TOP2, " "),
	"mail craftingOrders tracking coordinates calendar compartment")
full = Elements:FullLayout({ TOP2 = { "calendar", "mail" } })
Equal("missing elements slot in after the nearest default neighbor", table.concat(full.TOP2, " "),
	"calendar compartment mail craftingOrders tracking coordinates")
local moved = Elements:Move(defaults, "clock", "BOTTOM1")
Equal("a move takes the element out of its list", table.concat(moved.TOP1, " "), "zone difficulty")
Equal("and puts it at the end of the other", moved.BOTTOM1[1], "clock")
moved = Elements:Move(defaults, "clock", "TOP1", 1)
Equal("or at a place in the same list", table.concat(moved.TOP1, " "), "clock zone difficulty")
Equal("the original is untouched", table.concat(defaults.TOP1, " "), "zone difficulty clock")
Equal("a layout is a valid setting", (Schema:CheckValue("minimap.layout", moved)), true)
Equal("an unknown list is not", (Schema:CheckValue("minimap.layout", { LEFT = { "zone" } })), false)
Equal("nor an element in two lists", (Schema:CheckValue("minimap.layout", { TOP1 = { "zone" }, TOP2 = { "zone" } })),
	false)
Equal("nor a list with a gap", (Schema:CheckValue("minimap.layout", { TOP1 = { [1] = "zone", [3] = "clock" } })),
	false)
Equal("default row height", Schema:Read(stored, "minimap.rows.height"), 22)
Equal("default text size", Schema:Read(stored, "minimap.text.size"), 12)
Equal("the zone follows the rows' text size", Schema:Read(stored, "minimap.zone.text.size"), 12)
stored.minimap = { text = { size = 15 } }
Equal("and follows a change to it", Schema:Read(stored, "minimap.clock.text.size"), 15)
stored.minimap.clock = { text = { size = 10 } }
Equal("until it is given its own", Schema:Read(stored, "minimap.clock.text.size"), 10)
Equal("which leaves the others following", Schema:Read(stored, "minimap.coordinates.text.size"), 15)
stored.minimap = nil
Equal("the zone keeps its own colors", Schema:Field("minimap.zone.text.color"), nil)
Equal("the clock takes the text color", Schema:Read(stored, "minimap.clock.text.color").r, 1)

local zone, clock = Elements.byKey.zone, Elements.byKey.clock
local Zone = zone
function zone:Width()
	return 80
end
function clock:Width()
	return 30
end
zone.active, zone.value, clock.active, clock.value = true, "Dalaran", true, "12:00"
local rows = Elements:Rows()
Equal("each element in its default row and order", rows.TOP1[1].key .. rows.TOP1[2].key, "zoneclock")
Equal("text cells carry their width", rows.TOP1[1].width, 80)
Equal("the zone gives way first", rows.TOP1[1].flexible, true)
stored.minimap = { layout = { BOTTOM1 = { "clock", "zone" } } }
rows = Elements:Rows()
Equal("a row holds its elements by order", rows.BOTTOM1[1].key .. rows.BOTTOM1[2].key, "clockzone")
Equal("and leaves the default rows empty", rows.TOP1 == nil and rows.TOP2 == nil, true)
zone.value = ""
Equal("an element with nothing to show takes no cell", #Elements:Rows().BOTTOM1, 1)
stored.minimap.layout.HIDDEN = { "clock" }
stored.minimap.layout.BOTTOM1 = { "zone" }
Equal("a hidden element takes no cell", Elements:Rows().BOTTOM1, nil)
Equal("every element starts on", Schema:Read({}, "minimap.elements.coordinates.enabled"), true)
stored.minimap = nil

-- Text elements ----------------------------------------------------------------------------------------------

local Clock, Coordinates, Difficulty = Elements.byKey.clock, Elements.byKey.coordinates, Elements.byKey.difficulty
Equal("24-hour time", Clock:Format(9, 5, true), "09:05")
Equal("12-hour morning", Clock:Format(9, 5, false), "9:05 AM")
Equal("midnight is 12 AM", Clock:Format(0, 0, false), "12:00 AM")
Equal("noon is 12 PM", Clock:Format(12, 30, false), "12:30 PM")
Equal("evening", Clock:Format(23, 59, false), "11:59 PM")
Equal("day starts at dawn", Clock:IsDay(5, 30), true)
Equal("night before dawn", Clock:IsDay(5, 29), false)
Equal("night from dusk", Clock:IsDay(21, 0), false)
Equal("clock defaults", tostring(Schema:Read(stored, "minimap.clock.twentyFour")) ..
	tostring(Schema:Read(stored, "minimap.clock.localTime")) .. tostring(Schema:Read(stored, "minimap.clock.dayNight")),
	"truetruetrue")
Equal("one decimal by default", Coordinates:Format(45.678, 62.345, 1), "45.7, 62.3")
Equal("no decimals", Coordinates:Format(45.678, 62.345, 0), "46, 62")
Equal("default precision", Schema:Read(stored, "minimap.coordinates.precision"), 1)
local rect = { x = 1000, y = 2000, width = -500, height = -1000 }
local mapX, mapY = Coordinates:MapPercent(750, 1500, rect)
Equal("a world position halfway across the map", mapX, 50)
Equal("and halfway down it", mapY, 50)
Equal("a map with no extent gives no position", Coordinates:MapPercent(0, 0, { x = 0, y = 0, width = 0, height = 0 }),
	nil)
Equal("zone colored by PvP status by default", Schema:Read(stored, "minimap.zone.color"), "PVP")
Equal("a sanctuary is blue", Zone:Color("sanctuary").b, 0.94)
Equal("no status is gold", Zone:Color(nil).g, 0.82)

local function Label(id, info, size, keystone)
	return table.concat({ Difficulty:Label(id, info, size, keystone) }, " ")
end
Equal("heroic raid by group size", Label(15, { instanceType = "raid", isHeroic = true, maxPlayers = 30 }, 25, 0),
	"25H heroic")
Equal("mythic", Label(16, { instanceType = "raid", displayMythic = true, maxPlayers = 20 }, 20, 0), "M mythic")
Equal("keystone", Label(8, { instanceType = "party", isChallengeMode = true, maxPlayers = 5 }, 5, 12), "M+12 mythic")
Equal("raid finder", Label(17, { instanceType = "raid", isLFR = true, maxPlayers = 30 }, 25, 0), "LFR lfr")
Equal("normal dungeon", Label(1, { instanceType = "party", maxPlayers = 5 }, 5, 0), "5N normal")
Equal("timewalking", Label(24, nil, 5, 0), "TW other")
Equal("battlegrounds", Label(0, { instanceType = "pvp" }, 0, 0), "PvP other")
Equal("an unknown difficulty has no label", Difficulty:Label(999, nil, 0, 0), nil)

function IsInInstance()
	return false
end
AUI.Events = AUI.Events or { Coalesce = function() end }
local labelColor
Difficulty.text = { SetText = function() end, SetTextColor = function(_, r, g, b) labelColor = { r, g, b } end }
zone.active, clock.active, Difficulty.active = nil, nil, true
Difficulty:Update()
Equal("no badge outside an instance", Difficulty:IsShown(), false)
Elements:SetPreview(true, "dev")
Equal("the preview shows a sample badge", Difficulty.value, "25H")
Equal("marked as the sample", Difficulty.sample, true)
Equal("in the heroic color", labelColor[3], 0.867)
stored.minimap = { difficulty = { colors = { heroic = { r = 1, g = 0, b = 0 } } } }
Difficulty.tier = nil
Difficulty:Update()
Equal("a chosen tier color is used", labelColor[1], 1)
stored.minimap = nil
Equal("Friz Quadrata by default", Schema:Read(stored, "minimap.difficulty.text.font"), "Friz Quadrata TT")
Equal("no outline by default", Schema:Read(stored, "minimap.difficulty.text.outline"), "NONE")
for _, key in ipairs({ "zone", "clock", "coordinates", "difficulty" }) do
	Equal(key .. " text sits in the row's middle by default", Schema:Read(stored, "minimap." .. key .. ".text.offsetY"),
		0)
end
Equal("an offset past the limit", (Schema:CheckValue("minimap.zone.text.offsetY", 11)), false)
Equal("an unknown outline", (Schema:CheckValue("minimap.difficulty.text.outline", "GLOW")), false)
Equal("following again", (Schema:CheckValue("minimap.difficulty.text.outline", nil)), true)
Elements:SetPreview(true, "settings")
Elements:SetPreview(false, "dev")
Equal("another source keeps the preview on", Elements.preview, true)
Elements:SetPreview(false, "settings")
Equal("and takes it away again", Difficulty:IsShown(), false)
Difficulty.active, Difficulty.text = nil, nil

-- Button elements --------------------------------------------------------------------------------------------

local Mail, Calendar, Compartment = Elements.byKey.mail, Elements.byKey.calendar, Elements.byKey.compartment
Equal("an hour before midnight", Calendar:SecondsToMidnight(23, 0), 3600 + 5)
Equal("from midnight, a whole day", Calendar:SecondsToMidnight(0, 0), 86400 + 5)
Mail.active, Calendar.active = true, true
rows = Elements:Rows()
Equal("mail keeps its cell without mail", rows.TOP2 and rows.TOP2[1].key, "mail")
Equal("as a button", rows.TOP2[1].kind, "button")
Equal("buttons carry no width", rows.TOP2[1].width, nil)
Equal("then the calendar", rows.TOP2[2].key, "calendar")
Equal("the compartment takes no cell without Blizzard's button", Compartment:IsShown(), false)
Equal("crafting orders take no cell on a client without them", Elements.byKey.craftingOrders:IsShown(), false)
Mail.active, Calendar.active = nil, nil

-- Fading -------------------------------------------------------------------------------------------------------

local Fade = AUI.MinimapFade
local fading = { mouseover = true, mouseoverOpacity = 30, combat = true, combatOpacity = 50 }
Equal("hovering shows it fully", Fade:Target(fading, true, true), 1)
Equal("away from the mouse it fades", Fade:Target(fading, false, false), 0.3)
Equal("the lower opacity wins in combat", Fade:Target(fading, false, true), 0.3)
fading.mouseover = false
Equal("combat alone fades in combat", Fade:Target(fading, false, true), 0.5)
Equal("and not out of it", Fade:Target(fading, false, false), 1)
Equal("metal draws its own cell divider", Border:CellDividerWidth("METAL", 100), 9)
Equal("which follows the thickness", Border:CellDividerWidth("METAL", 200), 18)
Equal("Forever Minimal divides with its band", Border:CellDividerWidth("FOREVER_MINIMAL", 100), 2)
Equal("Forever divides with its band", Border:CellDividerWidth("FOREVER", 100), 2)
Equal("thin line draws a plain line", Border:CellDividerWidth("THIN_LINE", 100), nil)
cells = Layout:Row({ { key = "a", kind = "text", width = 20, flexible = true }, { key = "b", kind = "text", width = 20 } },
	240, 22, 22)
Equal("a wider spacing makes room for a wide divider", cells[2].x - (cells[1].x + cells[1].width), 22)
Equal("no fading by default", Schema:Read(stored, "minimap.fade.mouseover") or
	Schema:Read(stored, "minimap.fade.combat"), false)

-- Applying ---------------------------------------------------------------------------------------------------

local applied = 0
function Map:Apply()
	applied = applied + 1
end

Map:OnProfileChanged("minimap.width")
Equal("a minimap setting re-applies", applied, 1)
Map:OnProfileChanged(nil)
Equal("a profile switch re-applies", applied, 2)
Map:OnProfileChanged("fixture.width")
Equal("other settings do not", applied, 2)
Map.pending = false
Map:OnCombatEnded()
Equal("combat ending applies nothing unless asked", applied, 2)
Map.pending = true
Map:OnCombatEnded()
Equal("a request made in combat applies when it ends", applied, 3)

io.stdout:write(("check_minimap: %d checks passed\n"):format(checks))
