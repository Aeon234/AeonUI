-- Checks TravelersLog/ outside the game: the fields' defaults, the fraction parser on the client's real requirement
-- strings, which activities show progress, each kind of progress and its label; then nothing hooked while off or on a
-- client without it, Blizzard's addon never loaded from here, the wait for it to load, the bar on each kind of row, rows
-- left bare, a pooled row reused, a fill set on opening and moved on live progress, Reduce Motion, every setting, off and
-- on again, and the settings page. Drawing and the real list are not exercised.
-- Run from any directory with Lua 5.1: lua Tools/check_travelerslog.lua
-- Loads the real files against stubbed globals. Widgets are modeled by type. Exits non-zero on the first failed check.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

WOW_PROJECT_ID = 1
SlashCmdList = {}
StaticPopupDialogs = {}
NONE = "None"
MONTHLY_ACTIVITIES_TAB = "Traveler's Log"

local journalLoaded = false
local loadRequests = 0
C_AddOns = {
	GetAddOnMetadata = function(_, field)
		return field == "Version" and "dev" or "AeonUI"
	end,
	IsAddOnLoaded = function(name)
		assert(name == "Blizzard_EncounterJournal", "unexpected addon " .. tostring(name))

		return journalLoaded
	end,
	LoadAddOn = function()
		loadRequests = loadRequests + 1
	end,
}

local errors = {}
function CallErrorHandler(message)
	errors[#errors + 1] = message
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

function GetTime()
	return 100
end

local now = 1000
function GetServerTime()
	return now
end

function BreakUpLargeNumbers(value)
	local text = tostring(value)
	local count

	repeat
		text, count = text:gsub("^(%d+)(%d%d%d)", "%1,%2")
	until count == 0

	return text
end

function Mixin(object, ...)
	for index = 1, select("#", ...) do
		for key, value in pairs((select(index, ...))) do
			object[key] = value
		end
	end

	return object
end

PixelUtil = { SetSize = function(region, width, height)
	region:SetSize(width, height)
end }

local function Region()
	local region = { shown = true }
	region.SetShown = function(self, shown)
		self.shown = shown
	end
	region.SetAllPoints = function() end
	region.SetColorTexture = function(self, r, g, b, a)
		self.color = { r, g, b, a }
	end

	return region
end

local function FontString()
	local text = Region()
	text.SetPoint = function(self, point, _, relative, x)
		self.point = { point, relative, x }
	end
	text.SetWidth = function(self, width)
		self.width = width
	end
	text.SetJustifyH = function(self, justify)
		self.justify = justify
	end
	text.SetText = function(self, value)
		self.value = value
	end
	text.SetTextColor = function(self, r)
		self.red = r
	end

	return text
end

local bars = {}

local function StatusBar(parent)
	local bar = { parent = parent, shown = true, value = 0 }
	local fill = Region()
	bar.GetParent = function(self)
		return self.parent
	end
	bar.SetSize = function(self, width, height)
		self.width, self.height = width, height
	end
	bar.SetPoint = function(self, point, relativeTo, relative, x, y)
		self.point = { point, relativeTo, relative, x, y }
	end
	bar.SetStatusBarTexture = function() end
	bar.SetStatusBarColor = function(self, r, g, b)
		self.color = { r, g, b }
	end
	bar.SetMinMaxValues = function(self, low, high)
		self.low, self.high = low, high
	end
	bar.SetValue = function(self, value)
		self.value = value
	end
	bar.GetStatusBarTexture = function()
		return fill
	end
	bar.CreateTexture = Region
	bar.CreateFontString = function(_, _, _, template)
		assert(template == "GameFontHighlightSmall", "unexpected font " .. tostring(template))

		return FontString()
	end
	bar.Show = function(self)
		self.shown = true
	end
	bar.Hide = function(self)
		self.shown = false
	end
	bars[#bars + 1] = bar

	return bar
end

local eventFrame
function CreateFrame(kind, _, parent)
	if kind == "StatusBar" then
		return StatusBar(parent)
	end

	assert(kind == "Frame", "unexpected frame " .. tostring(kind))
	local frame = { scripts = {}, events = {} }
	frame.SetScript = function(self, script, handler)
		self.scripts[script] = handler
	end
	frame.RegisterEvent = function(self, event)
		self.events[event] = true
	end
	frame.UnregisterEvent = function(self, event)
		self.events[event] = nil
	end
	eventFrame = eventFrame or frame

	return frame
end

local lib = {}
local springs = assert(loadfile(root .. "Tools/springs.lua"))(lib)
function LibStub()
	return lib
end

-- Addon ---------------------------------------------------------------------------------------------------

local AUI = {}
assert(loadfile(root .. "AeonUI/Core/Core.lua"))("AeonUI", AUI)
AUI.can = { travelersLog = true }

for _, file in ipairs({ "AeonUI/Core/Callbacks.lua", "AeonUI/Core/Events.lua", "AeonUI/Profile/Schema.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local values = {}
AUI.Profile = {
	Get = function(_, path)
		local value = values[path]

		if value == nil then
			local field = AUI.Schema:Field(path)
			value = field and field.default
		end

		return value
	end,
}

local function Set(path, value)
	values[path] = value
	AUI.Callbacks:Fire("Profile", path)
end

for _, file in ipairs({ "AeonUI_QoL/TravelersLog/Options.lua", "AeonUI_QoL/TravelersLog/RowProgress.lua",
	"AeonUI_QoL/TravelersLog/TravelersLog.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Schema, Options, Log, Rows = AUI.Schema, AUI.TravelersLogOptions, AUI.TravelersLog, AUI.TravelersLogRows

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1

	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(name, tostring(expected), tostring(actual)), 2)
	end
end

local function Requirement(text, completed)
	return { requirementText = text, completed = completed == true }
end

local function Activity(id, requirements, fields)
	local activity = { ID = id, requirementsList = requirements, completed = false, restricted = false }

	for key, value in pairs(fields or {}) do
		activity[key] = value
	end

	return activity
end

local function Progress(activity)
	local ratio, current, required = Options:Progress(activity)

	return ("%s %s %s"):format(tostring(ratio), tostring(current), tostring(required))
end

-- Settings ------------------------------------------------------------------------------------------------

Equal("off by default", Schema:Field(Options.ENABLED_PATH).default, false)
Equal("bars by default", Schema:Field(Options.BARS_PATH).default, true)
Equal("counts by default", Schema:Field(Options.TEXT_PATH).default, "COUNT")
Equal("three text choices", table.concat(Options.TEXT_CHOICES, " "), "COUNT PERCENT NONE")

-- The parser, on strings the client returned (Retail 12.1.5.70688, enUS) ------------------------------------

local function Parse(text)
	local current, required = Options:ParseFraction(text)

	return tostring(current) .. " " .. tostring(required)
end

Equal("a count", Parse("- 5 / 25 Dungeon bosses defeated"), "5 25")
Equal("a large count", Parse("- 0 / 7500 Honor earned"), "0 7500")
Equal("a checkmark's atlas numbers are skipped",
	Parse("|A:activities-icon-checkmark:0:0:0:0|a 5 / 5 The Headless Horseman defeated"), "5 5")
Equal("a slash in the words after", Parse("- 0 / 1 Use the /thank emote"), "0 1")
Equal("a comma in the words after", Parse("- 0 / 50 Herbs, ores, skins, or fish gathered"), "0 50")
Equal("a period at the end", Parse("- 0 / 3 Chambers completed."), "0 3")
Equal("no count", Parse("- Thorm'belan"), "nil nil")

-- Not returned by the client; each guards a shape the parser must not misread.
Equal("a number after stays out", Parse("- 0 / 1 10-Player raid completed"), "0 1")
Equal("group separators", Parse("- 1,550 / 2,500 Honor earned"), "1550 2500")
Equal("no spaces", Parse("3/5 Quests"), "3 5")

-- Which activities show ----------------------------------------------------------------------------------

Equal("an ordinary activity shows", Options:Shows(Activity(1, {}), now), true)
Equal("completed does not", Options:Shows(Activity(1, {}, { completed = true }), now), false)
Equal("restricted does not", Options:Shows(Activity(1, {}, { restricted = true }), now), false)
Equal("expired does not", Options:Shows(Activity(1, {}, { eventEndTime = now - 1 }), now), false)
Equal("still running does", Options:Shows(Activity(1, {}, { eventEndTime = now + 1 }), now), true)

-- Progress and labels ------------------------------------------------------------------------------------

Equal("no requirements", Progress(Activity(1, {})), "nil nil nil")
Equal("one count", Progress(Activity(1, { Requirement("- 5 / 25 Dungeon bosses defeated") })), "0.2 5 25")
Equal("one with no count", Progress(Activity(1, { Requirement("- Thorm'belan") })), "nil nil nil")
Equal("a zero requirement", Progress(Activity(1, { Requirement("- 0 / 0 Odd") })), "nil nil nil")
Equal("past its requirement", Progress(Activity(1, { Requirement("- 7 / 5 Quests") })), "1 5 5")
Equal("done whatever the text says", Progress(Activity(1, { Requirement("- 3 / 5 Quests", true) })), "1 5 5")
Equal("several named, counted as done", Progress(Activity(1, {
	Requirement("- Lu'ashal", true), Requirement("- Cragpine"), Requirement("- Predaxas"), Requirement("- Thorm'belan"),
})), "0.25 1 4")
Equal("several mixed, partial counts in the bar only", Progress(Activity(1, {
	Requirement("- 1 / 2 Scarab Gong rang"), Requirement("- Slid on ice", true),
})), "0.75 1 2")

Equal("count", Options:Label("COUNT", 0.2, 5, 25), "5/25")
Equal("count with separators", Options:Label("COUNT", 0.62, 1550, 2500), "1,550/2,500")
Equal("percent", Options:Label("PERCENT", 0.2, 5, 25), "20%")
Equal("percent rounds down", Options:Label("PERCENT", 0.999, 999, 1000), "99%")
Equal("none", Options:Label("NONE", 0.2, 5, 25), nil)

-- Off, and waiting for Blizzard's addon --------------------------------------------------------------------

local function Fire(event, ...)
	if eventFrame.events[event] then
		eventFrame.scripts.OnEvent(eventFrame, event, ...)
	end
end

local rows, initialized, hooks = {}, nil, {}

local function Row(activity)
	local row = {
		activity = activity,
		node = { GetData = function(self)
			return self.row.activity
		end },
	}
	row.node.row = row
	rows[#rows + 1] = row

	return row
end

local scrollBox = { ForEachFrame = function(_, callback)
	for _, row in ipairs(rows) do
		callback(row, row.node)
	end
end }
local logFrame = { ScrollBox = scrollBox, HookScript = function(_, script, handler)
	hooks[script] = handler
end }
ScrollUtil = { AddInitializedFrameCallback = function(box, callback, owner, iterateExisting)
	assert(box == scrollBox and owner == Rows and iterateExisting == false, "unexpected callback")
	assert(not initialized, "hooked twice")
	initialized = callback
end }

Log:Start()
Equal("started", Log.active, true)
Equal("not waiting while off", Log.waiting, false)
Equal("nothing followed while off", eventFrame.events.ADDON_LOADED, nil)
Log:Start()

Set(Options.ENABLED_PATH, true)
Equal("waits for Blizzard's addon", Log.waiting, true)
Equal("followed while waiting", eventFrame.events.ADDON_LOADED, true)
Equal("nothing hooked yet", Rows.hooked, false)
Fire("ADDON_LOADED", "SomeOtherAddon")
Equal("another addon changes nothing", Log.waiting, true)

journalLoaded = true
EncounterJournal = { MonthlyActivitiesFrame = logFrame }
Fire("ADDON_LOADED", "Blizzard_EncounterJournal")
Equal("hooked once it has loaded", Rows.hooked, true)
Equal("no longer waiting", Log.waiting, false)
Equal("no longer followed", eventFrame.events.ADDON_LOADED, nil)
Equal("never loads Blizzard's addon", loadRequests, 0)
Rows:Hook()

local function Init(row)
	initialized(Rows, row, row.node)
end

-- Rows ----------------------------------------------------------------------------------------------------

local full = Row(Activity(1, { Requirement("- 5 / 25 Quests completed") }))
Init(full)
local bar = full.aeonUIProgress
Equal("a bar on a full row", bar ~= nil, true)
Equal("its width leaves the label's column", bar.width, 370 - Options.LABEL_WIDTH - Options.LABEL_GAP)
Equal("its height", bar.height, 5)
Equal("on the row", bar.point[2], full)
Equal("at the text's left edge", bar.point[4], 36)
Equal("above the bottom edge", bar.point[5], 9)
Equal("gold", bar.color[1], Options.FILL_COLOR.r)
Equal("from 0 to 1", bar.low .. " " .. bar.high, "0 1")
Equal("its value set at once", bar.value, 0.2)
Equal("not moving", springs.Moving(), false)
Equal("the label", bar.label.value, "5/25")
Equal("right aligned", bar.label.justify, "RIGHT")
Equal("light with progress", bar.label.red, Options.LABEL_COLOR.r)

local child = Row(Activity(2, { Requirement("- 0 / 10 Quests completed") }, { isChild = true }))
Init(child)
Equal("a child row's bar is thinner", child.aeonUIProgress.height, 3)
Equal("a child row's left edge", child.aeonUIProgress.point[4], 40)
Equal("a child row's width", child.aeonUIProgress.width, 350 - Options.LABEL_WIDTH - Options.LABEL_GAP)
Equal("dimmer at no progress", child.aeonUIProgress.label.red, Options.LABEL_EMPTY_COLOR.r)

local bare = Row(Activity(3, { Requirement("- 1 / 5 Quests completed", true) }, { completed = true }))
Init(bare)
Equal("nothing on a completed row", bare.aeonUIProgress, nil)
bare.activity = Activity(4, { Requirement("- Thorm'belan") })
Init(bare)
Equal("nothing on one with no count", bare.aeonUIProgress, nil)
bare.activity = Activity(5, {})
Init(bare)
Equal("nothing on one with no requirements", bare.aeonUIProgress, nil)
bare.activity = Activity(6, { Requirement("- 1 / 5 Quests") }, { eventEndTime = now - 1 })
Init(bare)
Equal("nothing on an expired row", bare.aeonUIProgress, nil)

-- A pooled row -------------------------------------------------------------------------------------------

local reused = Row(Activity(7, { Requirement("- 8 / 10 Quests") }))
Init(reused)
local reusedBar = reused.aeonUIProgress
reused.activity = Activity(8, { Requirement("- 9 / 10 Quests") })
Init(reused)
Equal("a reused row sets another activity's fill", reusedBar.value, 0.9)
Equal("without moving", springs.Moving(), false)
Equal("keeps its one bar", reused.aeonUIProgress, reusedBar)
reused.activity = Activity(9, { Requirement("- 1 / 5 Quests", true) }, { completed = true })
Init(reused)
Equal("a reused row on a completed activity is bare", reusedBar.shown, false)
reused.activity = Activity(10, { Requirement("- 1 / 2 Quests") })
Init(reused)
Equal("shown again on another", reusedBar.shown, true)
Equal("with that one's value", reusedBar.value, 0.5)

-- Live progress ------------------------------------------------------------------------------------------

full.activity = Activity(1, { Requirement("- 10 / 25 Quests completed") })
Init(full)
Equal("gained progress moves the fill", springs.Moving(), true)
Equal("from where it was", bar.value, 0.2)
springs.Frames(1)
Equal("settles at the new value", bar.value, 0.4)
Equal("at rest", springs.Moving(), false)

local swapped = Row(Activity(1, { Requirement("- 15 / 25 Quests completed") }))
Init(swapped)
Equal("on another pooled row, it still moves", springs.Moving(), true)
Equal("from where that activity was", swapped.aeonUIProgress.value, 0.4)
springs.Frames(1)
Equal("settled on that row", swapped.aeonUIProgress.value, 0.6)
rows[#rows] = nil

full.activity = Activity(1, { Requirement("- 10 / 25 Quests completed") })
Init(full)
Equal("lost progress is set, not moved", tostring(springs.Moving()) .. " " .. bar.value, "false 0.4")

springs.reduce = true
full.activity = Activity(1, { Requirement("- 20 / 25 Quests completed") })
Init(full)
Equal("Reduce Motion sets the fill", tostring(springs.Moving()) .. " " .. bar.value, "false 0.8")
springs.reduce = false

hooks.OnHide()
full.activity = Activity(1, { Requirement("- 25 / 25 Quests completed") })
Init(full)
Equal("after closing the log, opening it sets the fill", tostring(springs.Moving()) .. " " .. bar.value, "false 1")

-- Settings, off and on -----------------------------------------------------------------------------------

Set(Options.TEXT_PATH, "PERCENT")
Equal("every row follows Percent", child.aeonUIProgress.label.value, "0%")
Equal("and a row with progress", bar.label.value, "100%")
Set(Options.TEXT_PATH, "NONE")
Equal("no label", bar.label.value, "")
Equal("the bar stays", bar:GetStatusBarTexture().shown, true)
Set(Options.BARS_PATH, false)
Equal("neither hides the whole bar", bar.shown, false)
Set(Options.TEXT_PATH, "COUNT")
Equal("text alone shows", bar.shown, true)
Equal("without its fill", bar:GetStatusBarTexture().shown, false)
Equal("without its trough", bar.trough.shown, false)
Equal("with its label", bar.label.value, "25/25")
Set(Options.BARS_PATH, true)
Equal("the fill returns", bar:GetStatusBarTexture().shown, true)
Equal("the trough returns", bar.trough.shown, true)

Set(Options.ENABLED_PATH, false)
Equal("turned off, every bar hides", bar.shown or child.aeonUIProgress.shown, false)
local rowsAtOff = #bars
local fresh = Row(Activity(20, { Requirement("- 1 / 2 Quests") }))
Init(fresh)
Equal("a row initialized while off gets nothing", fresh.aeonUIProgress, nil)
Equal("no bar built while off", #bars, rowsAtOff)
Set(Options.ENABLED_PATH, true)
Equal("on again, bars return", bar.shown, true)
Equal("a new row too", fresh.aeonUIProgress ~= nil, true)
Equal("not hooked twice", Rows.hooked, true)

AUI.can.travelersLog = false
Equal("a client without it is off", Log:IsOn(), false)
AUI.can.travelersLog = true

-- Settings page -------------------------------------------------------------------------------------------

AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
AUI.Media = { sidebar = { travelersLog = "SidebarTravelersLog.tga" } }
AUI.Settings = { Default = function(_, path)
	return Schema:Field(path).default
end }

local declared
AUI.Modules = { Register = function(_, module)
	declared = module
end }
assert(loadfile(root .. "AeonUI_QoL/Settings/TravelersLog.lua"))("AeonUI", AUI)

local page = { sections = {} }
page.Section = function(self, id, title)
	local section = { id = id, title = title, rows = {} }

	for _, kind in ipairs({ "Checkbox", "Dropdown" }) do
		section[kind] = function(owner, row)
			row.kind = kind
			owner.rows[#owner.rows + 1] = row
		end
	end

	self.sections[#self.sections + 1] = section

	return section
end

local pageID, pageInfo
AUI.SettingsTravelersLog:Declare({ Page = function(_, id, info)
	pageID, pageInfo = id, info

	return page
end })

Equal("the page's ID", pageID, "travelersLog")
Equal("Blizzard's name for it", pageInfo.title, "Traveler's Log")
Equal("under Quality of Life", pageInfo.under, "qualityOfLifeHeader")
Equal("its icon", pageInfo.icon, "SidebarTravelersLog.tga")
Equal("its switch", pageInfo.switch.path, Options.ENABLED_PATH)
Equal("its switch's label", pageInfo.switch.label, "Enhance Traveler's Log")
Equal("one card", #page.sections, 1)
Equal("the card", page.sections[1].id, "travelersLogRows")
Equal("the bars", page.sections[1].rows[1].path, Options.BARS_PATH)
Equal("the text", page.sections[1].rows[2].path, Options.TEXT_PATH)
Equal("the text's choices", page.sections[1].rows[2].options[3].text, "None")
Equal("available with the log", AUI.SettingsTravelersLog:IsAvailable(), true)
AUI.can.travelersLog = false
Equal("not without it", AUI.SettingsTravelersLog:IsAvailable(), false)
AUI.can.travelersLog = true
Equal("the module's group", declared.group, "qualityOfLife")
declared.start()
Equal("started once", Log.active, true)

Equal("no Lua error in the run", errors[1], nil)

io.stdout:write(("check_travelerslog: %d checks passed\n"):format(checks))
