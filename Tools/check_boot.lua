-- Boots the addon outside the game for every combination of its feature addons, on each client: the real files load
-- in .toc order against permissive stubs, login fires, and the sidebar and the paths from the base into the features
-- run. This proves the base reaches no absent feature; it proves nothing about a feature's behavior.
-- Run from any directory with Lua 5.1: lua Tools/check_boot.lua
-- Exits non-zero on the first combination that fails.

local dir = (arg and arg[0] or ""):match("^(.-)[^/\\]*$")
local root = dir .. "../"
local windows = package.config:sub(1, 1) == "\\"

-- The sidebar pages each addon brings, and the pages only one client has.
local CLIENT_PAGES = { worldMap = "forever", movementAlert = "retail", travelersLog = "retail" }

local PAGES = {
	AeonUI_UnitFrames = { "unitFramesAll", "unitFramePlayer", "unitFrameResources", "castBar", "unitFrameTarget" },
	AeonUI_Tooltip = { "tooltipGeneral", "tooltipUnits", "tooltipItems" },
	AeonUI_Maps = { "minimap", "worldMap" },
	AeonUI_QoL = { "automation", "deleteCheapestItem", "merchantWindow", "travelersLog", "hiddenSettings", "macros", "playerMenu", "input",
		"alerts", "notifications", "movementAlert", "raidMarkers", "interface", "screenText", "cursor" },
	AeonUI = { "general", "profiles" },
}

local function FeatureAddons()
	local listing = windows and ('dir /b /ad "%sAeonUI_*" 2>nul'):format(root:gsub("/", "\\"))
		or ('ls -d "%s"AeonUI_*/ 2>/dev/null'):format(root)
	local pipe = assert(io.popen(listing))
	local addons = {}

	for line in pipe:lines() do
		addons[#addons + 1] = line:match("([^/\\]+)[/\\]?$")
	end
	pipe:close()
	table.sort(addons)

	return addons
end

-- Parent: one interpreter per combination, since each boot leaves its stubs and globals behind ------------------

if not arg[1] then
	local lua = arg[-1] or "lua"
	local addons = FeatureAddons()

	for mask = 0, 2 ^ #addons - 1 do
		local chosen, bits = {}, mask

		for _, addon in ipairs(addons) do
			if bits % 2 == 1 then
				chosen[#chosen + 1] = addon
			end
			bits = math.floor(bits / 2)
		end

		for _, client in ipairs({ "retail", "forever" }) do
			local command = ('"%s" "%scheck_boot.lua" %s "%s"'):format(lua, dir, client, table.concat(chosen, ","))

			-- cmd.exe strips one pair of outer quotes from the whole line.
			local status = os.execute(windows and '"' .. command .. '"' or command)

			if status ~= 0 and status ~= true then
				print(("check_boot: failed on %s with [%s]"):format(client, table.concat(chosen, ", ")))
				os.exit(1)
			end
		end
	end

	print(("check_boot: %d combinations of %d feature addons booted on both clients"):format(2 ^ #addons, #addons))

	return
end

-- Child: one boot -----------------------------------------------------------------------------------------------

local client, chosen = arg[1], arg[2] or ""
local errors = {}

local function Fail(text)
	io.stderr:write(("FAIL: %s\n"):format(text))
	os.exit(1)
end

function print() end

-- Reads as nothing for any list and as itself for anything else. Numeric keys stay nil so ipairs ends.
local Any = {}

setmetatable(Any, {
	__index = function(_, key)
		if type(key) ~= "number" then
			return Any
		end
	end,
	__newindex = function() end,
	__call = function()
		return Any
	end,
	__tostring = function()
		return "any"
	end,
	__concat = function()
		return "any"
	end,
	__add = function()
		return 0
	end,
	__sub = function()
		return 0
	end,
	__mul = function()
		return 0
	end,
	__div = function()
		return 0
	end,
	__unm = function()
		return 0
	end,
})

-- Globals the addon tests for absence. A name in capitals reads as a global string; everything else unknown is Any.
local ABSENT = { AeonUIDB = true, ElvUI = true, EllesmereUI = true, Clique = true, Auctionator = true, TSM_API = true }

setmetatable(_G, {
	__index = function(_, key)
		if ABSENT[key] then
			return nil
		end

		return key:match("^[%u%d_]+$") and key or Any
	end,
})

WOW_PROJECT_MAINLINE, WOW_PROJECT_ID = 1, client == "retail" and 1 or 18
WOW_PROJECT_CAMELOT = client == "forever" and 18 or nil
ABSENT.WOW_PROJECT_CAMELOT = client == "retail" or nil
SlashCmdList, StaticPopupDialogs, UISpecialFrames = {}, {}, {}
INVSLOT_HEAD, INVSLOT_BODY, INVSLOT_OFFHAND = 1, 4, 17

function issecretvalue()
	return false
end

function canaccessvalue()
	return true
end

function GetLocale()
	return "enUS"
end

C_Map = setmetatable({ GetMapRectOnMap = function() end }, { __index = Any })

function GetNumGuildMembers()
	return 0
end

function CreateAtlasMarkup()
	return ""
end

function CreateTextureMarkup()
	return ""
end

function GetTime()
	return 0
end

function UnitGUID()
	return "Player-1"
end

function hooksecurefunc() end

function Mixin(object, ...)
	for index = 1, select("#", ...) do
		for key, value in pairs((select(index, ...))) do
			object[key] = value
		end
	end

	return object
end

function CreateFromMixins(...)
	-- A Blizzard mixin is Any, so its methods are too.
	return setmetatable(Mixin({}, ...), { __index = Any })
end

function wipe(list)
	for key in pairs(list) do
		list[key] = nil
	end

	return list
end

tinsert, tremove, format = table.insert, table.remove, string.format
time, date = os.time, os.date
strlenutf8, strlower, strupper, strsub, strmatch, gsub = string.len, string.lower, string.upper, string.sub, string.match, string.gsub

function CallErrorHandler(message)
	errors[#errors + 1] = tostring(message)
end

function geterrorhandler()
	return CallErrorHandler
end

-- WoW's xpcall forwards extra arguments to the function, as Lua 5.2 does; Lua 5.1's does not.
local luaXpcall = xpcall

function xpcall(fn, handler, ...)
	local count, args = select("#", ...), { ... }

	return luaXpcall(function()
		return fn(unpack(args, 1, count))
	end, handler)
end

-- Frames record what the boot fires; every other method is Any.
local frames = {}

local FrameMethods = {
	RegisterEvent = function(self, event)
		self.events[event] = true
	end,
	UnregisterEvent = function(self, event)
		self.events[event] = nil
	end,
	SetScript = function(self, name, handler)
		self.scripts[name] = handler
	end,
	GetScript = function(self, name)
		return self.scripts[name]
	end,
}

setmetatable(FrameMethods, { __index = Any })

function CreateFrame()
	local frame = setmetatable({ events = {}, scripts = {} }, { __index = FrameMethods })

	frames[#frames + 1] = frame

	return frame
end

local function Fire(event, ...)
	for _, frame in ipairs(frames) do
		if frame.events[event] and frame.scripts.OnEvent then
			frame.scripts.OnEvent(frame, event, ...)
		end
	end
end

-- The library: the window records its sidebar, and everything a page declares is Any.
local declared, windowDeclaration = {}, nil

local Window = setmetatable({
	pages = {},
	Header = function(self, id)
		declared[#declared + 1] = "#" .. id
	end,
	Page = function(self, id)
		declared[#declared + 1] = id
		self.pages[id] = Any

		return Any
	end,
	ProfilesPage = function(self, id)
		declared[#declared + 1] = id
		self.pages[id] = Any

		return Any
	end,
	IsShown = function()
		return false
	end,
}, { __index = Any })

local Library = setmetatable({
	Settings = function(_, _, declaration)
		windowDeclaration = declaration

		return Window
	end,
}, { __index = Any })

function LibStub(name)
	return name == "LibAeonSettings-1.0" and Library or Any
end

-- Files ---------------------------------------------------------------------------------------------------------

local function Read(path)
	local file = io.open(root .. path, "rb")

	return file and file:read("*a"), file and file:close()
end

local function LoadFile(path, addon, namespace)
	local folder = path:match("^(.*/)") or ""

	if path:match("%.xml$") then
		local text = assert(Read(path), "missing " .. path):gsub("<!%-%-.-%-%->", "")

		for tag, file in text:gmatch("<(%a+)%s+file%s*=%s*\"([^\"]+)\"") do
			if tag == "Script" or tag == "Include" then
				LoadFile(folder .. file:gsub("\\", "/"), addon, namespace)
			end
		end
	elseif path:match("%.lua$") then
		local chunk, problem = loadfile(root .. path)

		if not chunk then
			Fail(problem)
		end

		local ok, failure = pcall(chunk, addon, namespace)

		if not ok then
			Fail(("%s failed to load: %s"):format(path, tostring(failure)))
		end
	end
end

local function LoadAddon(addon)
	local folder = addon .. "/"
	local toc = assert(Read(folder .. addon .. ".toc"), "missing .toc of " .. addon)
	local namespace = {}
	local packaged = true

	for line in toc:gmatch("[^\r\n]+") do
		if line:match("^#@do%-not%-package@") then
			packaged = false
		elseif line:match("^#@end%-do%-not%-package@") then
			packaged = true
		elseif packaged and line:match("%S") and not line:match("^%s*#") then
			local path = line:match("^%s*(.-)%s*$"):gsub("\\", "/")

			-- Libraries are stubbed.
			if not path:match("^Libs/") then
				LoadFile(folder .. path, addon, namespace)
			end
		end
	end

	Fire("ADDON_LOADED", addon)

	return namespace
end

-- The boot ------------------------------------------------------------------------------------------------------

local AUI = LoadAddon("AeonUI")

-- oUF's reaction colors, which the health settings show until set.
AUI.oUF = { colors = { reaction = {}, power = {} } }

for level = 1, 8 do
	AUI.oUF.colors.reaction[level] = { r = level / 10, g = 0, b = 0 }
end

local loaded = { AeonUI = true }

for addon in chosen:gmatch("[^,]+") do
	LoadAddon(addon)
	loaded[addon] = true
end

Fire("PLAYER_LOGIN")
Fire("PLAYER_ENTERING_WORLD", true, false)

if AUI.failed then
	Fail("the base turned itself off")
end

if #errors > 0 then
	Fail("module starts reported:\n  " .. table.concat(errors, "\n  "))
end

local ok, problem = pcall(function()
	AUI.Settings:Window()
	windowDeclaration.reloadNeeded()
	AUI.Settings:UpdatePreview()
	AUI.EditTargets:Targets()
	SlashCmdList.AEONUI("dci")
end)

if not ok then
	Fail("the sidebar or a path into a feature failed: " .. tostring(problem))
end

local shown = {}

for _, id in ipairs(declared) do
	shown[id] = true
end

for addon, pages in pairs(PAGES) do
	for _, id in ipairs(pages) do
		local expected = loaded[addon] == true and (CLIENT_PAGES[id] or client) == client

		if (shown[id] == true) ~= expected then
			Fail(("page %s of %s: shown %s with [%s] on %s"):format(id, addon, tostring(shown[id]), chosen, client))
		end
	end
end

for index, id in ipairs(declared) do
	local nextID = declared[index + 1]

	if id:sub(1, 1) == "#" and (not nextID or nextID:sub(1, 1) == "#") then
		Fail("a header with no page: " .. id)
	end
end
