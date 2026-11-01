-- Checks ScreenText/ outside the game: the sizes as percentages of each font object's size, the lines following the
-- shared settings until set, the message frame growing with its font, nothing changed while off, and every line given
-- its font object and the frame its size back when turned off.
-- Run from any directory with Lua 5.1: lua Tools/check_screentext.lua
-- Loads the real files against stubbed globals. Exits non-zero on the first failed check.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

WOW_PROJECT_ID = 1
SlashCmdList = {}
StaticPopupDialogs = {}
C_AddOns = {
	GetAddOnMetadata = function(_, field)
		return field == "Version" and "dev" or "AeonUI"
	end,
}

function CallErrorHandler(message)
	error(message, 0)
end

-- WoW's xpcall forwards extra arguments to the function, as Lua 5.2 does; Lua 5.1's does not.
local luaXpcall = xpcall
function xpcall(fn, handler, ...)
	local count, args = select("#", ...), { ... }

	return luaXpcall(function()
		return fn(unpack(args, 1, count))
	end, handler)
end

C_Timer = { After = function(_, callback)
	callback()
end }

function CreateFrame()
	return { RegisterEvent = function() end, UnregisterEvent = function() end, SetScript = function() end }
end

---A font object with Blizzard's file, size and flags.
local function FontObject(file, size, flags)
	return { GetFont = function()
		return file, size, flags
	end }
end

ErrorFont = FontObject("Fonts\\FRIZQT__.TTF", 16, "")
ZoneTextFont = FontObject("Fonts\\FRIZQT__.TTF", 32, "THICKOUTLINE")
SubZoneTextFont = FontObject("Fonts\\FRIZQT__.TTF", 26, "THICKOUTLINE")
PVPInfoTextFont = FontObject("Fonts\\FRIZQT__.TTF", 20, "THICKOUTLINE")

---A font string or message frame: it records its font, and takes a font object's font with `SetFontObject`.
local function Region(object)
	local region = { calls = 0 }
	region.file, region.size, region.flags = object:GetFont()
	function region:SetFont(file, size, flags)
		self.calls = self.calls + 1
		self.file, self.size, self.flags = file, size, flags
	end
	function region:SetFontObject(font)
		self.calls = self.calls + 1
		self.file, self.size, self.flags = font:GetFont()
	end

	return region
end

UIErrorsFrame = Region(ErrorFont)
UIErrorsFrame.width, UIErrorsFrame.height = 512, 60
function UIErrorsFrame:GetSize()
	return self.width, self.height
end
function UIErrorsFrame:SetSize(width, height)
	self.width, self.height = width, height
end
ZoneTextString = Region(ZoneTextFont)
SubZoneTextString = Region(SubZoneTextFont)
PVPInfoTextString = Region(PVPInfoTextFont)
PVPArenaTextString = Region(PVPInfoTextFont)

-- Addon table ---------------------------------------------------------------------------------------------

local AUI = {}
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
assert(loadfile(root .. "Core/Core.lua"))("AeonUI", AUI)
AUI.can = { screenText = true }
AUI.Media = {
	Font = function(_, name)
		return "LSM:" .. name
	end,
	FontFlags = function(_, outline)
		return outline == "SLUG" and "SLUG" or outline
	end,
}

for _, file in ipairs({ "Core/Callbacks.lua", "Core/Events.lua", "Profile/Schema.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

-- Declared by Minimap/Elements.lua, which loads before ScreenText/ in the game.
AUI.Schema:Choices("fontOutline", { "NONE", "OUTLINE", "THICKOUTLINE", "SLUG", "SLUG_OUTLINE", "SLUG_THICKOUTLINE" })

local values = {}
AUI.Profile = {
	Get = function(_, path)
		local value = values[path]
		local field = AUI.Schema:Field(path)

		if value == nil and field and field.shared then
			return AUI.Profile:Get(field.shared)
		end

		if value == nil then
			value = field and field.default
		end

		return value
	end,
}

local function Set(path, value)
	values[path] = value
	AUI.Callbacks:Fire("Profile", path)
end

for _, file in ipairs({ "ScreenText/Options.lua", "ScreenText/ScreenText.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Options, ScreenText = AUI.ScreenTextOptions, AUI.ScreenText

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

---@return string font the region's file, size and flags, joined
local function Font(region)
	return ("%s %s %s"):format(region.file, tostring(region.size), region.flags)
end

-- Arithmetic ----------------------------------------------------------------------------------------------

Equal("100% keeps Blizzard's size", Options:FontSize(32, 100), 32)
Equal("150% rounds to the nearest size", Options:FontSize(13, 150), 20)
Equal("50%", Options:FontSize(16, 50), 8)
Equal("never below 1", Options:FontSize(1, 50), 1)
local width, height = Options:FrameSize(512, 60, 150)
Equal("the frame grows with its font", width .. "x" .. height, "768x90")
width, height = Options:FrameSize(512, 60, 50)
Equal("never smaller than Blizzard's", width .. "x" .. height, "512x60")
Equal("the shared path", Options:Path(nil, "size"), "screenText.text.size")
Equal("a line's path", Options:Path("pvp", "outline"), "screenText.pvp.outline")
Equal("the lines", table.concat(Options.LINES, ","), "messages,zone,subZone,pvp")
for _, line in ipairs(Options.LINES) do
	for _, field in ipairs(Options.FIELDS) do
		local path = Options:Path(line, field)
		Equal(path .. " follows the shared setting", AUI.Schema:Field(path).shared, Options:Path(nil, field))
	end
end
Equal("off by default", AUI.Schema:Field(Options.ENABLED_PATH).default, false)
Equal("Slug by default", AUI.Schema:Field("screenText.text.outline").default, "SLUG")
Equal("100% by default", AUI.Schema:Field("screenText.text.size").default, 100)

-- Off -----------------------------------------------------------------------------------------------------

ScreenText:Start()
Equal("nothing changed while off", UIErrorsFrame.calls + ZoneTextString.calls + PVPArenaTextString.calls, 0)
Equal("the frame keeps its size", UIErrorsFrame.width .. "x" .. UIErrorsFrame.height, "512x60")

-- On ------------------------------------------------------------------------------------------------------

Set(Options.ENABLED_PATH, true)
Equal("errors and objectives at 100%", Font(UIErrorsFrame), "LSM:Friz Quadrata TT 16 SLUG")
Equal("zone at 100%", Font(ZoneTextString), "LSM:Friz Quadrata TT 32 SLUG")
Equal("subzone at 100%", Font(SubZoneTextString), "LSM:Friz Quadrata TT 26 SLUG")
Equal("territory under the zone", Font(PVPInfoTextString), "LSM:Friz Quadrata TT 20 SLUG")
Equal("territory under the subzone", Font(PVPArenaTextString), "LSM:Friz Quadrata TT 20 SLUG")

Set("screenText.text.size", 150)
Set("screenText.text.font", "Expressway")
Equal("the shared scale sets every line", Font(ZoneTextString), "LSM:Expressway 48 SLUG")
Equal("and the messages", Font(UIErrorsFrame), "LSM:Expressway 24 SLUG")
Equal("the frame grows with the messages", UIErrorsFrame.width .. "x" .. UIErrorsFrame.height, "768x90")

Set("screenText.zone.size", 80)
Set("screenText.zone.outline", "THICKOUTLINE")
Equal("a line's own setting wins", Font(ZoneTextString), "LSM:Expressway 26 THICKOUTLINE")
Equal("other lines keep the shared ones", Font(SubZoneTextString), "LSM:Expressway 39 SLUG")

Set("screenText.messages.size", 100)
Equal("the messages' own scale", Font(UIErrorsFrame), "LSM:Expressway 16 SLUG")
Equal("the frame follows the messages' scale", UIErrorsFrame.width .. "x" .. UIErrorsFrame.height, "512x60")

Set("screenText.zone.size", nil)
Equal("a cleared setting follows the shared one again", Font(ZoneTextString), "LSM:Expressway 48 THICKOUTLINE")

-- Off again -----------------------------------------------------------------------------------------------

Set("screenText.messages.size", 200)
Set(Options.ENABLED_PATH, false)
Equal("errors and objectives get ErrorFont back", Font(UIErrorsFrame), "Fonts\\FRIZQT__.TTF 16 ")
Equal("zone gets its font back", Font(ZoneTextString), "Fonts\\FRIZQT__.TTF 32 THICKOUTLINE")
Equal("territory gets its font back", Font(PVPArenaTextString), "Fonts\\FRIZQT__.TTF 20 THICKOUTLINE")
Equal("the frame gets its size back", UIErrorsFrame.width .. "x" .. UIErrorsFrame.height, "512x60")
local calls = ZoneTextString.calls
Set("screenText.text.size", 120)
Equal("nothing changed while off again", ZoneTextString.calls, calls)

AUI.can.screenText = nil
Set(Options.ENABLED_PATH, true)
Equal("nothing changed without the frames", ZoneTextString.calls, calls)

io.stdout:write(("check_screentext: %d checks passed\n"):format(checks))
