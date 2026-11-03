-- Checks TravelersLog/ outside the game: the fields' defaults, the fraction parser on the client's real requirement
-- strings, which activities show progress, each kind of progress and its label; then nothing hooked while off or on a
-- client without it, Blizzard's addon never loaded from here, the wait for it to load, the bar on each kind of row, rows
-- left bare, a pooled row reused, a fill set on opening and moved on live progress, Reduce Motion, every setting, off and
-- on again; which activities are hidden, each sort's order, the list pass on a tree that caches its row order as
-- Blizzard's does, the dropdown, search and its stand-down; and the settings page. Drawing and the real list are not exercised.
-- Run from any directory with Lua 5.1: lua Tools/check_travelerslog.lua
-- Loads the real files against stubbed globals. Widgets are modeled by type. Exits non-zero on the first failed check.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

WOW_PROJECT_ID = 1
SlashCmdList = {}
StaticPopupDialogs = {}
NONE = "None"
MONTHLY_ACTIVITIES_TAB = "Traveler's Log"

local journalLoaded, searcherLoaded = false, false
local loadRequests = 0
C_AddOns = {
	GetAddOnMetadata = function(_, field)
		return field == "Version" and "dev" or "AeonUI"
	end,
	IsAddOnLoaded = function(name)
		if name == "TravelersLogSearcher" then
			return searcherLoaded
		end

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

local dropdowns = {}
local eventFrame
function CreateFrame(kind, _, parent, template)
	if kind == "StatusBar" then
		return StatusBar(parent)
	end

	if kind == "EditBox" then
		assert(template == "SearchBoxTemplate", "unexpected template " .. tostring(template))
		local box = { parent = parent, shown = true, text = "", points = {}, scripts = {} }
		box.SetHeight = function(self, height)
			self.height = height
		end
		box.SetPoint = function(self, point, relativeTo, relative, x)
			self.points[point] = { relativeTo, relative, x }
		end
		box.SetFrameLevel = function(self, level)
			self.level = level
		end
		box.SetAutoFocus = function(self, autoFocus)
			self.autoFocus = autoFocus
		end
		box.SetShown = function(self, shown)
			self.shown = shown
		end
		box.GetText = function(self)
			return self.text
		end
		box.SetText = function(self, text)
			self.text = text
			self.scripts.OnTextChanged(self)
		end
		box.HookScript = function(self, script, handler)
			self.scripts[script] = handler
		end

		return box
	end

	if kind == "DropdownButton" then
		assert(template == "WowStyle1DropdownTemplate", "unexpected template " .. tostring(template))
		local dropdown = { parent = parent, shown = true, level = 0 }
		dropdown.SetWidth = function(self, width)
			self.width = width
		end
		dropdown.SetPoint = function(self, point, relativeTo, relative, x)
			self.point = { point, relativeTo, relative, x }
		end
		dropdown.SetFrameLevel = function(self, level)
			self.level = level
		end
		dropdown.SetupMenu = function(self, generator)
			self.generator = generator
		end
		dropdown.SetShown = function(self, shown)
			self.shown = shown
		end
		dropdown.OverrideText = function(self, text)
			self.text = text
		end
		dropdowns[#dropdowns + 1] = dropdown

		return dropdown
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
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
DEFAULT, HIDE, UNAVAILABLE, RAID_FRAME_SORT_LABEL = "Default", "Hide", "Unavailable", "Sort By"
QUEST_LOG_NO_RESULTS = "No results found"
ScrollBoxConstants = { RetainScrollPosition = true, DiscardScrollPosition = false }
TreeDataProviderConstants = { IncludeCollapsed = false }
AUI.Profile = {
	Set = function(_, path, value)
		values[path] = value
		AUI.Callbacks:Fire("Profile", path)
	end,
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
	"AeonUI_QoL/TravelersLog/ActivityList.lua", "AeonUI_QoL/TravelersLog/TravelersLog.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Schema, Options, Log, Rows = AUI.Schema, AUI.TravelersLogOptions, AUI.TravelersLog, AUI.TravelersLogRows
local List = AUI.TravelersLogList

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
local logFrame = {
	ScrollBox = scrollBox,
	HeaderContainer = { TimeLeft = {}, Month = {} },
	visible = false,
	pending = {},
	animating = {},
	HookScript = function(_, script, handler)
		local earlier = hooks[script]

		hooks[script] = function()
			if earlier then
				earlier()
			end

			handler()
		end
	end,
	CreateFontString = function(_, _, _, template)
		assert(template == "GameFontNormal", "unexpected font " .. tostring(template))
		local text = FontString()
		text.Hide = function(self)
			self.shown = false
		end

		return text
	end,
	IsVisible = function(self)
		return self.visible
	end,
	IsActivityPendingComplete = function(self, id)
		return self.pending[id]
	end,
	NeedsToAnimatePendingComplete = function(self, id)
		return self.animating[id] == true
	end,
}
scrollBox.GetDataProvider = function(self)
	return self.provider
end

local setActivitiesHook
function hooksecurefunc(owner, method, hook)
	assert(owner == logFrame, "unexpected hook")

	if method == "ScrollToPerksActivityID" then
		logFrame.scrollHook = hook

		return
	end

	assert(method == "SetActivities" and not setActivitiesHook, "unexpected hook")
	setActivitiesHook = hook
end
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
Equal("just past the bar's end", bar.label.point[1] .. " " .. bar.label.point[2] .. " " .. bar.label.point[3],
	"LEFT RIGHT " .. Options.LABEL_GAP)
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

-- Hiding ---------------------------------------------------------------------------------------------------

local ALL_HIDDEN = { completed = true, expired = true, unavailable = true }
local NONE_HIDDEN = { completed = false, expired = false, unavailable = false }

Equal("hides completed", Options:IsHidden(Activity(1, {}, { completed = true }), now, ALL_HIDDEN), true)
Equal("keeps completed", Options:IsHidden(Activity(1, {}, { completed = true }), now, NONE_HIDDEN), false)
Equal("hides expired", Options:IsHidden(Activity(1, {}, { areAllConditionsMet = true, eventEndTime = now - 1 }), now,
	ALL_HIDDEN), true)
Equal("keeps expired", Options:IsHidden(Activity(1, {}, { areAllConditionsMet = true, eventEndTime = now - 1 }), now,
	NONE_HIDDEN), false)
Equal("hides conditions unmet", Options:IsHidden(Activity(1, {}, { areAllConditionsMet = false }), now, ALL_HIDDEN), true)
Equal("hides not yet begun", Options:IsHidden(Activity(1, {}, { areAllConditionsMet = true, eventStartTime = now + 1,
	eventEndTime = now + 2 }), now, ALL_HIDDEN), true)
Equal("keeps what can be worked on", Options:IsHidden(Activity(1, {}, { areAllConditionsMet = true,
	eventStartTime = now - 1, eventEndTime = now + 1 }), now, ALL_HIDDEN), false)
Equal("keeps tracked and expired", Options:IsHidden(Activity(1, {}, { tracked = true, eventEndTime = now - 1 }), now,
	ALL_HIDDEN), false)
Equal("hides tracked and completed", Options:IsHidden(Activity(1, {}, { tracked = true, completed = true }), now,
	ALL_HIDDEN), true)
Equal("keeps a restricted list", Options:IsHidden(Activity(1, {}, { restricted = true, completed = true }), now,
	ALL_HIDDEN), false)

-- Sorting ------------------------------------------------------------------------------------------------

local function Named(id, name, points, fields)
	fields = fields or {}
	fields.name, fields.points = name, points
	fields.areAllConditionsMet = true

	fields.tagNames, fields.conditions = fields.tagNames or {}, fields.conditions or {}
	fields.activityName, fields.description = name, fields.description or ""

	return Activity(id, fields.requirements or { Requirement("- 0 / 10 Quests") }, fields)
end

local function Nodes(activities)
	local nodes = {}

	for index, activity in ipairs(activities) do
		nodes[index] = { GetData = function()
			return activity
		end }
	end

	return nodes
end

local function Order(sort, activities, pending)
	local nodes = Nodes(activities)
	local comparator = assert(Options:Comparator(sort, now, function(id)
		return pending and pending[id]
	end))

	table.sort(nodes, comparator)

	local ids = {}

	for index, node in ipairs(nodes) do
		ids[index] = node:GetData().ID
	end

	return table.concat(ids, " ")
end

Equal("Blizzard's own order has no comparator", Options:Comparator("DEFAULT", now, function() end), nil)

local SORTED = {
	Named(1, "Beta", 50, { requirements = { Requirement("- 5 / 10 Quests") } }),
	Named(2, "Alpha", 100, { requirements = { Requirement("- 1 / 10 Quests") } }),
	Named(3, "Gamma", 100, { requirements = { Requirement("- 9 / 10 Quests") } }),
	Named(4, "Done", 500, { completed = true }),
}

Equal("points high to low, then name, finished last", Order("POINTS_HIGH", SORTED), "2 3 1 4")
Equal("points low to high", Order("POINTS_LOW", SORTED), "1 2 3 4")
Equal("closest to complete", Order("CLOSEST", SORTED), "3 1 2 4")
Equal("name", Order("NAME", SORTED), "2 1 3 4")
Equal("a completion animating comes first", Order("POINTS_HIGH", SORTED, { [4] = true }), "4 2 3 1")

local SORTED_BY_TIME = {
	Named(1, "No event", 100),
	Named(2, "Soon", 100, { eventStartTime = now - 10, eventEndTime = now + 10 }),
	Named(3, "Later", 100, { eventStartTime = now - 10, eventEndTime = now + 20 }),
	Named(4, "Upcoming", 100, { eventStartTime = now + 10, eventEndTime = now + 20 }),
	Named(5, "Expired long ago", 100, { eventStartTime = now - 30, eventEndTime = now - 20 }),
	Named(6, "Just expired", 100, { eventStartTime = now - 30, eventEndTime = now - 10 }),
	Named(7, "Done", 100, { completed = true, eventEndTime = now + 5 }),
}
Equal("time remaining's groups and orders", Order("TIME", SORTED_BY_TIME), "2 3 1 4 6 5 7")

-- The list pass, on a tree that caches its row order as Blizzard's does -------------------------------------

local Provider = {}
Provider.__index = Provider

local function TreeNode(provider, data)
	local node = { provider = provider, data = data, nodes = {} }

	node.GetData = function(self)
		return self.data
	end
	node.GetNodes = function(self)
		return self.nodes
	end
	node.Insert = function(self, childData)
		local child = TreeNode(self.provider, childData)

		self.nodes[#self.nodes + 1] = child

		return child
	end
	node.Remove = function(self, child, skipInvalidation)
		for index, candidate in ipairs(self.nodes) do
			if candidate == child then
				table.remove(self.nodes, index)
				assert(skipInvalidation == true, "each removal would redraw the list")

				return child
			end
		end
	end

	return node
end

function Provider:GetRootNode()
	return self.root
end

function Provider:Insert(data)
	return self.root:Insert(data)
end

function Provider:SetSortComparator(comparator)
	table.sort(self.root.nodes, comparator)
end

function Provider:Invalidate()
	self.linearized = nil
	self.invalidated = self.invalidated + 1
end

function Provider:IsEmpty()
	return #self.root.nodes == 0
end

---What the view would draw: the cached order, built when first asked for.
function Provider:FindElementDataByPredicate(predicate, excludeCollapsed)
	assert(excludeCollapsed == TreeDataProviderConstants.IncludeCollapsed, "a collapsed child must be found")

	for _, node in ipairs(self.root.nodes) do
		if predicate(node) then
			return node
		end

		for _, child in ipairs(node.nodes) do
			if predicate(child) then
				return child
			end
		end
	end
end

function Provider:Drawn()
	if not self.linearized then
		local linearized = {}

		for _, node in ipairs(self.root.nodes) do
			linearized[#linearized + 1] = node.data.ID

			for _, child in ipairs(node.nodes) do
				linearized[#linearized + 1] = child.data.ID
			end
		end

		self.linearized = table.concat(linearized, " ")
	end

	return self.linearized
end

local function Build(activities)
	local provider = setmetatable({ invalidated = 0 }, Provider)

	provider.root = TreeNode(provider)

	for _, activity in ipairs(activities) do
		activity.hasChild = activity.children ~= nil
		local node = provider:Insert(activity)

		for _, child in ipairs(activity.children or {}) do
			node:Insert(child)
		end
	end

	scrollBox.provider = provider
	provider:Drawn()

	if setActivitiesHook then
		setActivitiesHook(logFrame)
	end

	return provider
end

local TREE = {
	Named(1, "Beta", 50, { requirements = { Requirement("- 5 / 10 Quests") } }),
	Named(2, "Alpha", 100),
	Named(3, "Done", 500, { completed = true }),
	Named(4, "Over", 75, { eventEndTime = now - 1 }),
	Named(5, "Upcoming", 60, { eventStartTime = now + 1, eventEndTime = now + 2 }),
}

local latest = TREE
logFrame.SetActivities = function()
	Build(latest)
end
C_PerksActivities = { GetPerksActivitiesInfo = function()
	return { activities = latest }
end }
MenuResponse = { Refresh = 2 }

Equal("hooked with the row callback", setActivitiesHook ~= nil, true)
Equal("the dropdown's header place", List.dropdown.point[2], logFrame.HeaderContainer.TimeLeft)
Equal("above the header", List.dropdown.level, 560)

Set(Options.SORT_PATH, "DEFAULT")
local provider = Build(TREE)
Equal("default: Blizzard's order, hidden rows gone", provider:Drawn(), "1 2 5")
Equal("default: redrawn once", provider.invalidated, 1)
Equal("nothing hidden is not a message", List.message.shown, false)

values[Options.SORT_PATH] = "POINTS_HIGH"
provider = Build(TREE)
Equal("a sort reaches the view without a scroll", provider:Drawn(), "2 5 1")
Equal("a sort changes what the view draws, once", provider.invalidated, 1)

values[Options.HIDE_COMPLETED_PATH] = false
values[Options.HIDE_EXPIRED_PATH] = false
provider = Build(TREE)
Equal("with nothing hidden, the sort still reaches the view", provider:Drawn(), "2 4 5 1 3")
values[Options.HIDE_COMPLETED_PATH] = nil
values[Options.HIDE_EXPIRED_PATH] = nil

values[Options.SORT_PATH] = "DEFAULT"
values[Options.HIDE_COMPLETED_PATH] = false
values[Options.HIDE_EXPIRED_PATH] = false
provider = Build(TREE)
Equal("default with nothing hidden leaves the view alone", provider.invalidated, 0)
values[Options.HIDE_COMPLETED_PATH] = nil
values[Options.HIDE_EXPIRED_PATH] = nil

values[Options.HIDE_UNAVAILABLE_PATH] = true
provider = Build(TREE)
Equal("Hide Unavailable", provider:Drawn(), "1 2")
values[Options.HIDE_UNAVAILABLE_PATH] = nil

logFrame.animating[3] = true
values[Options.SORT_PATH] = "POINTS_HIGH"
logFrame.pending[3] = true
provider = Build(TREE)
Equal("a completion animating stays, on top", provider:Drawn(), "3 2 5 1")
logFrame.animating[3] = nil
provider = Build(TREE)
Equal("gone at the next build", provider:Drawn(), "2 5 1")
logFrame.pending[3] = nil

local parent = Named(10, "Parent", 100, { children = { Named(11, "Child", 100, { eventEndTime = now - 1 }) } })
provider = Build({ parent })
Equal("a hidden child goes, its parent stays", provider:Drawn(), "10")
Equal("and stops offering to expand", parent.hasChild, false)

local over = Named(12, "Over", 100, { eventEndTime = now - 1, children = { Named(13, "Doable", 100) } })
provider = Build({ over })
Equal("a surviving child keeps its parent", provider:Drawn(), "12 13")
Equal("which still expands", over.hasChild, true)

provider = Build({ Named(14, "Done", 100, { completed = true }) })
Equal("a list emptied gets the message", List.message.shown, true)
Equal("the message's text", List.message.value, "Everything here is hidden.")
provider = Build(TREE)
Equal("gone when something shows", List.message.shown, false)
provider = Build({})
Equal("an empty category with nothing hidden is no message", List.message.shown, false)

-- The dropdown -------------------------------------------------------------------------------------------

local radios, checks_, titles = {}, {}, {}
local menuRoot = {
	CreateTitle = function(_, text)
		titles[#titles + 1] = text
	end,
	CreateDivider = function() end,
	CreateRadio = function(_, text, isSelected, select_)
		radios[#radios + 1] = { text = text, isSelected = isSelected, select = select_ }
	end,
	CreateCheckbox = function(_, text, isChecked, toggle)
		checks_[#checks_ + 1] = { text = text, isChecked = isChecked, toggle = toggle }
	end,
}
List.dropdown.generator(List.dropdown, menuRoot)
Equal("the titles", table.concat(titles, " "), "Sort By Hide")
Equal("six sorts", #radios, 6)
Equal("the first", radios[1].text, "Default")
Equal("the fourth", radios[4].text, "Closest to Complete")
Equal("three hides", #checks_, 3)
Equal("the last", checks_[3].text, "Unavailable")

latest, logFrame.visible = TREE, true
values[Options.SORT_PATH] = "DEFAULT"
Equal("the menu keeps open", radios[2].select(), MenuResponse.Refresh)
Equal("the sort is saved", AUI.Profile:Get(Options.SORT_PATH), "POINTS_HIGH")
Equal("the radio follows", radios[2].isSelected(), true)
Equal("the list reorders at once, with no scrolling", scrollBox.provider:Drawn(), "2 5 1")
Equal("the button names the sort alone", List.dropdown.text, "Points: High to Low")

Equal("Hide Completed starts checked", checks_[1].isChecked(), true)
checks_[1].toggle()
Equal("turned off", AUI.Profile:Get(Options.HIDE_COMPLETED_PATH), false)
Equal("the completed row returns, at once", scrollBox.provider:Drawn(), "2 5 1 3")
checks_[1].toggle()

logFrame.SetActivities = function()
	Build(TREE)
end
scrollBox.provider = nil
Set(Options.SORT_PATH, "NAME")
Equal("no rebuild before the log has built its list", scrollBox.provider, nil)
scrollBox.provider = Build(TREE)
logFrame.visible = false
local before = scrollBox.provider
Set(Options.SORT_PATH, "POINTS_LOW")
Equal("no rebuild while the log is closed", scrollBox.provider, before)
logFrame.visible = true

Set(Options.ENABLED_PATH, false)
Equal("turned off, the dropdown hides", List.dropdown.shown, false)
Equal("and Blizzard's list returns, with nothing hidden", scrollBox.provider:Drawn(), "1 2 3 4 5")
Set(Options.ENABLED_PATH, true)
Equal("on again, the dropdown shows", List.dropdown.shown, true)
Equal("one dropdown ever", #dropdowns, 1)
Equal("the sort returns", scrollBox.provider:Drawn(), "1 5 2")
Set(Options.SORT_PATH, "DEFAULT")
logFrame.visible = false

-- Search -------------------------------------------------------------------------------------------------

Equal("trims and lowers", Options:NormalizeQuery("  Ärger ÉTÉ "), ("Ärger ÉTÉ"):lower())
Equal("blank is no search", Options:NormalizeQuery("   "), "")

local function Searchable(fields)
	return Named(1, fields.name or "Name", 100, fields)
end

Equal("no query matches", Options:Matches(Searchable({}), ""), true)
Equal("the name, any case", Options:Matches(Searchable({ name = "Defeat Bosses" }), "bosses"), true)
Equal("the description", Options:Matches(Searchable({ description = "Find Treats" }), "treats"), true)
Equal("the event", Options:Matches(Searchable({ eventName = "Darkmoon Faire" }), "darkmoon"), true)
Equal("a tag", Options:Matches(Searchable({ tagNames = { "Pet Battles" } }), "pet"), true)
Equal("a condition", Options:Matches(Searchable({ conditions = { { text = "Requires level 80" } } }), "level 80"), true)
Equal("a requirement", Options:Matches(Searchable({ requirements = { Requirement("- Thorm'belan") } }), "thorm"), true)
Equal("nothing", Options:Matches(Searchable({}), "absent"), false)
Equal("not a pattern", Options:Matches(Searchable({ name = "Name" }), "n.me"), false)
Equal("a pattern's characters are text", Options:Matches(Searchable({ name = "Name (A)" }), "(a"), true)
Equal("not a checkmark's markup", Options:Matches(Searchable({ requirements = {
	Requirement("|A:activities-icon-checkmark:0:0:0:0|a 5 / 5 Horseman defeated", true),
} }), "checkmark"), false)
Equal("the words after a checkmark", Options:Matches(Searchable({ requirements = {
	Requirement("|A:activities-icon-checkmark:0:0:0:0|a 5 / 5 Horseman defeated", true),
} }), "horseman"), true)

local box = List.searchBox
Equal("a search box", box ~= nil, true)
Equal("after the month's name", box.points.LEFT[1], logFrame.HeaderContainer.Month)
Equal("before the dropdown", box.points.RIGHT[1], List.dropdown)
Equal("not taking the keyboard", box.autoFocus, false)
Equal("above the header", box.level, 560)

local SEARCHED = {
	Named(21, "Quests in Draenor", 100),
	Named(22, "Pet Tamers", 100),
	Named(23, "Parent One", 100, { children = { Named(24, "Hidden Child", 100) } }),
	Named(25, "Darkmoon Tickets", 100, { children = { Named(26, "More Tickets", 100) } }),
	Named(27, "Finished Quests", 100, { completed = true }),
}
logFrame.SetActivities = function()
	Build(SEARCHED)
end
logFrame.visible = true
Build(SEARCHED)
Equal("no search keeps all but the hidden", scrollBox.provider:Drawn(), "21 22 23 24 25 26")

local replaced = 0
local realSetActivities = logFrame.SetActivities
logFrame.SetActivities = function(_, _, retainScroll)
	replaced = replaced + 1
	logFrame.lastRetain = retainScroll
	realSetActivities()
end

box:SetText("Draenor")
Equal("typing narrows the list", scrollBox.provider:Drawn(), "21")
Equal("once for the change", replaced, 1)
Equal("from the top of the list", logFrame.lastRetain, false)
box:SetText(" draenor ")
Equal("the same search does not rebuild", replaced, 1)

box:SetText("finished")
Equal("a hidden row stays hidden when it matches", scrollBox.provider:Drawn(), "")

box:SetText("hidden child")
Equal("a matching child keeps its parent", scrollBox.provider:Drawn(), "23 24")
Equal("which still expands", SEARCHED[3].hasChild, true)
box:SetText("darkmoon")
Equal("a matching parent keeps its child", scrollBox.provider:Drawn(), "25 26")
box:SetText("absent")
Equal("nothing matches", scrollBox.provider:Drawn(), "")
Equal("the message shows", List.message.shown, true)
Equal("says so", List.message.value, "No results found")
box:SetText("")
Equal("cleared, the list returns", scrollBox.provider:Drawn(), "21 22 23 24 25 26")
Equal("the message goes", List.message.shown, false)

values[Options.SORT_PATH] = "NAME"
box:SetText("t")
Equal("search and sort together", scrollBox.provider:Drawn(), "25 26 23 24 22 21")
box:SetText("")
values[Options.SORT_PATH] = nil

-- The objective tracker's link to an activity the search left out.
local scrolled = {}
logFrame.ScrollToPerksActivityID = function(self, id)
	scrolled[#scrolled + 1] = id
	self.scrollHook(self, id)
end
box:SetText("darkmoon")
logFrame:ScrollToPerksActivityID(25)
Equal("a shown activity leaves the search", box.text, "darkmoon")
Equal("scrolled once", #scrolled, 1)
logFrame:ScrollToPerksActivityID(26)
Equal("a collapsed child found too", box.text, "darkmoon")
logFrame:ScrollToPerksActivityID(22)
Equal("one left out clears the search", box.text, "")
Equal("and its query", List.query, "")
Equal("and rebuilds", scrollBox.provider:Drawn(), "21 22 23 24 25 26")
Equal("and scrolls again", scrolled[#scrolled], 22)
Equal("once more", #scrolled, 4)
logFrame:ScrollToPerksActivityID(22)
Equal("no search, nothing to do", #scrolled, 5)

box:SetText("darkmoon")
hooks.OnHide()
Equal("closing the log empties the search", box.text .. List.query, "")
Set(Options.ENABLED_PATH, true)

box:SetText("darkmoon")
Set(Options.ENABLED_PATH, false)
Equal("turned off, the box hides", box.shown, false)
Equal("and empties", box.text, "")
Equal("and Blizzard's list returns", scrollBox.provider:Drawn(), "21 22 23 24 25 26 27")
Set(Options.ENABLED_PATH, true)
Equal("on again, the box shows", box.shown, true)
logFrame.visible = false
logFrame.SetActivities = realSetActivities

-- Standing down for TravelersLogSearcher, which has its own box and replaces the list's build method.
searcherLoaded = true
setActivitiesHook = nil
logFrame.scrollHook = nil
assert(loadfile(root .. "AeonUI_QoL/TravelersLog/ActivityList.lua"))("AeonUI", AUI)
local standing = AUI.TravelersLogList
standing:Hook()
Equal("no box beside it", standing.searchBox, nil)
Equal("the dropdown stays", standing.dropdown ~= nil, true)
Equal("the list pass stays", setActivitiesHook ~= nil, true)
Equal("no scroll hook", logFrame.scrollHook, nil)
standing:Apply()
Equal("following the settings works without a box", standing.dropdown.shown, true)
standing:ClearSearch()
Equal("nothing to empty", standing.query, "")
searcherLoaded = false
AUI.TravelersLogList = List

-- Settings page -------------------------------------------------------------------------------------------

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
