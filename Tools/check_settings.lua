-- Checks Settings/*.lua and Core/Broker.lua outside the game: which pages the window declares in each profile mode,
-- the declaration's store and write hooks, the Profiles adapter's translation between names and profile IDs, the
-- Damaged Profiles section, the Recovery page's export and reset, and the minimap button's saved state.
-- Run from any directory with Lua 5.1: lua Tools/check_settings.lua
-- Loads the real files against a stand-in for LibAeonSettings that records declarations and refuses fields the
-- library does not accept. It proves the declarations and adapters, not the library's drawing.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

UNKNOWN = "Unknown"
GENERAL = "General"
DELETE = "Delete"
RESET = "Reset"
CANCEL = "Cancel"
CLOSE = "Close"
NONE = "None"
BACKGROUND = "Background"
MINIMAP_LABEL = "Minimap"
MAIL_LABEL = "Mail"
TRACKING = "Tracking"
ZONE = "Zone"
FONT_SIZE = "Font Size"
OTHER = "Other"
PLAYER_DIFFICULTY1 = "Normal"
PLAYER_DIFFICULTY2 = "Heroic"
PLAYER_DIFFICULTY3 = "Raid Finder"
PLAYER_DIFFICULTY6 = "Mythic"
TIMEMANAGER_TITLE = "Clock"
TIMEMANAGER_24HOURMODE = "24 Hour Mode"
TIMEMANAGER_LOCALTIME = "Use Local Time"
SlashCmdList = {}
StaticPopupDialogs = {}
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

function strcmputf8i(a, b)
	a, b = a:lower(), b:lower()

	return a == b and 0 or (a < b and -1 or 1)
end

function strlenutf8(text)
	local _, count = text:gsub("[^\128-\191]", "")

	return count
end

local popups = {}
function StaticPopup_Show(which, text, _, data)
	popups[#popups + 1] = { which = which, text = text, data = data }
end

function StaticPopup_StandardEditBoxOnEscapePressed() end

local confirmations = {}
function StaticPopup_StandardConfirmationTextHandler(editBox, expected)
	confirmations[#confirmations + 1] = { editBox = editBox, expected = expected }
end

local reloads = 0
function ReloadUI()
	reloads = reloads + 1
end

-- LibAeonSettings stand-in ----------------------------------------------------------------------------------

-- Fields the library accepts, from its Source/Model.lua, Sidebar.lua, Window.lua and Profiles.lua; control fields
-- from each control's RegisterControl call.
local SETTING_FIELDS = {
	id = true, label = true, description = true, path = true, default = true, get = true, set = true, depends = true,
	blocked = true, show = true, wide = true, inherits = true, keywords = true, tooltip = true, redraws = true,
	resettable = true,
}
local CONTROL_FIELDS = {
	Checkbox = {},
	Button = { verb = true, confirm = true, run = true },
	Slider = { min = true, max = true, step = true, format = true },
	Dropdown = { options = true, picker = true, placeholder = true, titleCase = true, confirm = true, verb = true,
		width = true },
	Color = { hasOpacity = true, classColor = true },
}
local PAGE_FIELDS = { title = true, description = true, under = true, icon = true, slot = true, switch = true }
local DECLARATION_FIELDS = {
	title = true, version = true, store = true, write = true, account = true, width = true, height = true,
	footer = true, frameName = true,
}
local ADAPTER_REQUIRED = { "List", "Active", "Switch", "New", "Copy", "Rename", "Delete", "Reset", "Export", "Decode",
	"Import" }

local function Allowed(where, info, allowed, extra)
	for field in pairs(info or {}) do
		if not allowed[field] and not (extra and extra[field]) then
			error(("%s: unknown field %s"):format(where, tostring(field)), 2)
		end
	end
end

local function NewSection(id)
	local section = { id = id, settings = {}, notes = {} }

	for kind in pairs(CONTROL_FIELDS) do
		section[kind] = function(self, info)
			Allowed(kind .. " " .. tostring(info.id), info, SETTING_FIELDS, CONTROL_FIELDS[kind])
			info.kind = kind
			self.settings[#self.settings + 1] = info
			self.settings[info.id] = info

			return info
		end
	end

	function section:Note(text, small)
		self.notes[#self.notes + 1] = { text = text, small = small }
	end

	return section
end

local function NewPage(id, info)
	Allowed("page " .. id, info, PAGE_FIELDS)

	local page = { id = id, info = info, sections = {} }

	function page:Preview(previewInfo)
		Allowed("preview " .. id, previewInfo, { height = true, states = true, create = true, refresh = true,
			caption = true, pick = true, stop = true })
		self.preview = previewInfo

		return previewInfo
	end

	function page:Section(sectionID, _, sectionInfo)
		Allowed("section " .. sectionID, sectionInfo, { show = true })

		local section = NewSection(sectionID)

		section.info = sectionInfo or {}
		self.sections[#self.sections + 1] = section
		self.sections[sectionID] = section

		return section
	end

	return page
end

-- Blizzard's post-hook, on a table's method.
function hooksecurefunc(object, method, hook)
	local original = object[method]

	object[method] = function(...)
		local results = { original(...) }

		hook(...)

		return unpack(results)
	end
end

local lib = {
	OUTLINES = { { value = "NONE" }, { value = "OUTLINE" }, { value = "THICKOUTLINE" }, { value = "SLUG" },
		{ value = "SLUG_OUTLINE" }, { value = "SLUG_THICKOUTLINE" } },
}

function lib:Settings(name, declaration)
	Allowed("declaration", declaration, DECLARATION_FIELDS)

	local window = { name = name, declaration = declaration, order = {}, pages = {}, refreshed = 0 }

	function window:Page(id, info)
		local page = NewPage(id, info)

		self.pages[id] = page
		self.order[#self.order + 1] = id

		return page
	end

	function window:Divider()
		self.order[#self.order + 1] = "-"
	end

	function window:Header(id)
		self.order[#self.order + 1] = "#" .. id
	end

	function window:ProfilesPage(id, info)
		for _, method in ipairs(ADAPTER_REQUIRED) do
			assert(type(info.adapter[method]) == "function", "adapter needs " .. method)
		end

		local page = self:Page(id, { title = info.title, description = info.description })

		page.adapter = info.adapter

		if info.sections then
			info.sections(page)
		end

		return page
	end

	function window:Refresh()
		self.refreshed = self.refreshed + 1
	end

	function window:IsShown()
		return self.shown == true
	end

	function window:SelectPage(id)
		self.page = id
	end

	-- The frame is built on the first opening; its scripts can be hooked, and Escape hides it without Close.
	function window:Open()
		if not self.frame then
			local frame = { scripts = {} }

			function frame:HookScript(script, hook)
				self.scripts[script] = hook
			end

			function frame:SetShown(shown)
				window.shown = shown
				self.scripts[shown and "OnShow" or "OnHide"]()
			end

			self.frame = frame
		end

		self.shown = true
	end

	self.window = window

	return window
end

local placements = {}
function lib:Placement(name, declaration)
	local registration = { name = name, declaration = declaration, applied = 0 }

	function registration:Apply()
		self.applied = self.applied + 1
	end

	placements[name] = registration

	return registration
end

-- LibDataBroker and LibDBIcon stand-ins.
local launchers = {}
local LDB = {
	NewDataObject = function(_, name, object)
		launchers[name] = object

		return object
	end,
}
local icon = { registered = {}, hidden = {}, compartment = {} }
function icon:Register(name, _, db)
	self.registered[name] = db
end
function icon:Hide(name)
	self.hidden[name] = true
end
function icon:Show(name)
	self.hidden[name] = false
end
function icon:AddButtonToCompartment(name)
	self.compartment[name] = true
end

local LIBRARIES = { ["LibAeonSettings-1.0"] = lib, ["LibDataBroker-1.1"] = LDB, ["LibDBIcon-1.0"] = icon }
function LibStub(name)
	return assert(LIBRARIES[name], name)
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
for _, file in ipairs({ "Core/Callbacks.lua", "Core/Capabilities.lua", "Core/Broker.lua", "Profile/Schema.lua",
	"Profile/Store.lua", "Profile/Profile.lua", "UI/Border.lua", "Minimap/Layout.lua", "Minimap/Elements.lua",
	"Minimap/Rows.lua", "Minimap/Fade.lua", "Minimap/Text.lua", "Minimap/Difficulty.lua",
	"Minimap/Buttons.lua", "Minimap/Map.lua", "Settings/Window.lua", "Settings/MinimapEditor.lua",
	"Settings/General.lua", "Settings/Minimap.lua", "Settings/Profiles.lua", "Settings/Recovery.lua",
	"Settings/EditTargets.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Settings, Profile, Store, Broker = AUI.Settings, AUI.Profile, AUI.Store, AUI.Broker

AUI.Schema:Number("fixture.width", 270, 40, 800, true)

function Profile:Save(data)
	AeonUIDB = data
end

local function Load(data)
	AeonUIDB = data
	Profile.root, Profile.quarantined = nil, {}
	Profile:Initialize(data, "Player-1")
	Settings.window = nil

	return Settings:Window()
end

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

-- Normal mode ------------------------------------------------------------------------------------------------

local window = Load(nil)
local declaration = window.declaration
Equal("registered under the addon's name", window.name, "AeonUI")
Equal("named root frame", declaration.frameName, "AeonUISettings")
Equal("sidebar order", table.concat(window.order, " "), "general - #minimapHeader minimap minimapBorder minimapRows " ..
	"minimapZone minimapDifficulty minimapClock minimapMail minimapTracking minimapCoordinates minimapCalendar " ..
	"minimapCompartment - profiles")
Equal("Settings:Window reuses the window", Settings:Window(), window)
Equal("the store is the active config", declaration.store(), Profile.config)
Equal("account settings are the store's", declaration.account(), AeonUIDB.global)
Equal("write saves through the owner", (declaration.write("fixture.width", 300)), true)
Equal("the value is saved", Profile:Get("fixture.width"), 300)
local ok, reason = declaration.write("fixture.width", 1)
Equal("write passes a refusal back", ok, false)
Equal("with its reason", type(reason), "string")
Equal("a setting's default", Settings:Default("fixture.width"), 270)
Equal("no default for an unknown path", Settings:Default("fixture.nothing"), nil)
local before = window.refreshed
Profile:Create("Hidden")
Equal("a profile change leaves a closed window alone", window.refreshed, before)
window.shown = true
Profile:Create("Refresh")
Equal("a profile change redraws an open window", window.refreshed > before, true)
window.shown = false

-- Minimap page --------------------------------------------------------------------------------------------------

local minimapPage = window.pages.minimap
local MINIMAP_PAGES = { "minimap", "minimapBorder", "minimapRows", "minimapZone", "minimapClock", "minimapDifficulty",
	"minimapCoordinates", "minimapMail", "minimapTracking", "minimapCalendar", "minimapCompartment" }
local outlineChoices = {}
for index, option in ipairs(window.pages.minimapDifficulty.sections.difficultyText.settings.difficultyText_outline.options) do
	outlineChoices[index] = option.value
end
Equal("every outline the library offers is a valid choice", table.concat(outlineChoices, " "),
	table.concat(AUI.Schema.choices.fontOutline, " "))
local iconSize = window.pages.minimapClock.sections.clock.settings.iconSize
Equal("icon size is free while day and night shows", iconSize.blocked(), nil)
Profile:Set("minimap.clock.dayNight", false)
Equal("icon size waits for day and night", type(iconSize.blocked()), "string")
Profile:Set("minimap.clock.dayNight", true)
Equal("the rows' text has its own section", window.pages.minimapRows.sections.rowsText.settings.rowsText_size.path,
	"minimap.text.size")
Equal("the zone offers no text color", window.pages.minimapZone.sections.zoneText.settings.zoneText_color, nil)
Equal("the clock does", window.pages.minimapClock.sections.clockText.settings.clockText_color.inherits.path,
	"minimap.text.color")
Equal("a color for each difficulty tier", #window.pages.minimapDifficulty.sections.difficultyColors.settings, 5)

for _, id in ipairs(MINIMAP_PAGES) do
	local page = window.pages[id]

	Equal(id .. " sits under the Minimap header", page.info.under, "minimapHeader")
	local element = id:match("^minimap(%u%l+)$")
	local elementKey = element and element ~= "Border" and element ~= "Rows" and element:lower()

	Equal(id .. " carries its switch", page.info.switch.path,
		elementKey and "minimap.elements." .. elementKey .. ".enabled" or "minimap.enabled")
	Equal(id .. " switch defaults on", page.info.switch.default, true)

	for _, section in ipairs(page.sections) do
		for _, setting in ipairs(section.settings) do
			Equal(setting.id .. " names a setting", AUI.Schema:Field(setting.path) ~= nil, true)
			local field = AUI.Schema:Field(setting.path)
			local source = field.shared and AUI.Schema:Field(field.shared) or field

			Equal(setting.id .. " carries its default", setting.default == nil, source.default == nil)
			Equal(setting.id .. " follows what its field follows", setting.inherits and setting.inherits.path,
				field.shared)
		end
	end
end

local fade = minimapPage.sections.fade.settings
Equal("mouseover opacity waits for its fade", type(fade.fadeMouseoverOpacity.blocked()), "string")
Equal("combat opacity waits for its fade", type(fade.fadeCombatOpacity.blocked()), "string")
Profile:Set("minimap.fade.mouseover", true)
Profile:Set("minimap.fade.combat", true)
Equal("mouseover opacity follows its fade", fade.fadeMouseoverOpacity.blocked(), nil)
Equal("combat opacity follows its fade", fade.fadeCombatOpacity.blocked(), nil)
Profile:Set("minimap.fade.mouseover", false)
Profile:Set("minimap.fade.combat", false)
Equal("row height is on the page", window.pages.minimapRows.sections.rows.settings.rowHeight.path, "minimap.rows.height")
Equal("precision is a plain count of decimal places",
	window.pages.minimapCoordinates.sections.coordinates.settings.precision.format, nil)

local borderSection = window.pages.minimapBorder.sections.border
Equal("every border style is offered", #borderSection.settings.borderStyle.options, #AUI.Border.STYLES)
local borderSettings = borderSection.settings
Equal("border color is free with Metal", borderSettings.borderColor.blocked(), nil)
Equal("thickness is free with Metal", borderSettings.borderThickness.blocked(), nil)
Profile:Set("minimap.border.style", "NONE")
Equal("border color needs a style", type(borderSettings.borderColor.blocked()), "string")
Equal("thickness needs an art style", type(borderSettings.borderThickness.blocked()), "string")
Profile:Set("minimap.border.style", "FOREVER")
Equal("Forever keeps its own colors", type(borderSettings.borderColor.blocked()), "string")
Equal("Forever takes a thickness", borderSettings.borderThickness.blocked(), nil)
Profile:Set("minimap.border.style", "FOREVER_MINIMAL")
Equal("Forever Minimal takes a color", borderSettings.borderColor.blocked(), nil)
Profile:Set("minimap.border.style", "METAL")
local resetSlider = minimapPage.sections.zoom.settings.zoomReset
Equal("a zero reset reads Never", resetSlider.format(0), "Never")
Equal("a reset reads in seconds", resetSlider.format(15), "15 s")

-- Edit mode ----------------------------------------------------------------------------------------------------

AUI.EditTargets.registration = nil
AUI.EditTargets:Register()
local placement = placements.AeonUI
Equal("edit mode is registered", placement ~= nil, true)
Equal("no target while the module is off this session", #placement.declaration.targets(), 0)
AUI.Minimap.active, AUI.Minimap.holder = true, {}
local target = placement.declaration.targets()[1]
Equal("the minimap is a target", target and target.key, "minimap")
Equal("it moves the module's frame", target.frame, AUI.Minimap.holder)
Equal("it starts at the default place", target.default, AUI.Minimap.DEFAULT_POSITION)
Equal("Element Options lands on its page", target.settings.page, "minimap")
Equal("no stored position at first", placement.declaration.get("minimap"), nil)
placement.declaration.set("minimap", { point = "TOPLEFT", x = 12, y = -30 })
Equal("a moved position is saved in the profile", Profile:Get("minimap.position").point, "TOPLEFT")
Equal("and read back", placement.declaration.get("minimap").x, 12)
placement.declaration.set("minimap", { point = "NOWHERE", x = 0, y = 0 })
Equal("a malformed position is refused", Profile:Get("minimap.position").point, "TOPLEFT")
Equal("an unknown key reads nothing", placement.declaration.get("other"), nil)
AUI.Minimap.active, AUI.Minimap.holder = false, nil

-- Profiles adapter --------------------------------------------------------------------------------------------

Load(nil)
local adapter = Settings:Window().pages.profiles.adapter
Equal("list names the default profile", adapter.List()[1], "Default")
Equal("active is the default", adapter.Active(), "Default")
Equal("new", (adapter.New("Raid")), true)
Equal("new activates", adapter.Active(), "Raid")
Equal("a refused name passes the reason", select(2, adapter.New("raid")) ~= nil, true)
Equal("copy", (adapter.Copy("Raid Copy")), true)
Equal("copy activates", adapter.Active(), "Raid Copy")
Equal("rename", (adapter.Rename("Raid Two")), true)
Equal("rename is kept", Profile:Name(Profile.activeID), "Raid Two")
Equal("switch by name", (adapter.Switch("Raid")), true)
Equal("switch selects the ID", Profile.activeID, Profile:Find("Raid"))
Equal("switch to a missing name is refused", (adapter.Switch("Nobody")), false)
Equal("delete by names", (adapter.Delete("Raid", "Default")), true)
Equal("delete removes it", Profile:Find("Raid"), nil)
Equal("delete moves the character", adapter.Active(), "Default")
Equal("list after delete", #adapter.List(), 2)
Profile:Set("fixture.width", 500)
Equal("reset", (adapter.Reset()), true)
Equal("reset restores defaults", Profile:Get("fixture.width"), 270)
Equal("no damaged section without damage", Settings:Window().pages.profiles.sections.damaged, nil)

-- Damaged profiles ----------------------------------------------------------------------------------------------

local damagedData = Store:NewRoot("Player-1")
damagedData.profilesByID.p00000002 = { name = "Broken", schemaVersion = AUI.Schema.VERSION,
	config = { fixture = { width = "x" } } }
damagedData.nextID = 3
local page = Load(damagedData).pages.profiles
local damaged = page.sections.damaged
Equal("a damaged section", damaged ~= nil, true)
Equal("it shows", damaged.info.show(), true)
local row = damaged.settings["delete.p00000002"]
Equal("a row per damaged profile", row ~= nil, true)
Equal("the row names it", row.label, "Broken")
Equal("the row says why", type(row.description), "string")
Equal("deleting has a replacement", row.blocked(), nil)
Equal("damaged profiles stay out of the list", #page.adapter.List(), 1)
Equal("delete runs", (row.run()), true)
Equal("the profile is gone", Profile:Name("p00000002"), nil)
Equal("its row hides", row.show(), false)
Equal("the section hides", damaged.info.show(), false)

-- Recovery ---------------------------------------------------------------------------------------------------

window = Load({})
Equal("recovery mode", Profile.mode, "recovery")
Equal("recovery is the only page", table.concat(window.order, " "), "recovery")
Equal("no account settings in recovery", window.declaration.account(), nil)
local section = window.pages.recovery.sections.recovery
Equal("the problem is noted", section.notes[1].small ~= nil and section.notes[1].small ~= "", true)

function Profile:RawExport()
	return "raw", false
end

section.settings.export.run()
Equal("export opens its dialog", popups[#popups].which, "AEONUI_DIAGNOSTIC_EXPORT")
Equal("an incomplete export says so", popups[#popups].text, "Diagnostic Export (Incomplete)")
Equal("the dialog holds the text", popups[#popups].data.text, "raw")
local reset = section.settings.reset
Equal("reset asks first", type(reset.confirm), "string")
reset.run()
Equal("then asks for the word", popups[#popups].which, "AEONUI_RESET_SAVED_SETTINGS")
local resetPopup = StaticPopupDialogs.AEONUI_RESET_SAVED_SETTINGS
resetPopup.EditBoxOnTextChanged("box")
Equal("the word is RESET", confirmations[#confirmations].expected, "RESET")
resetPopup.OnAccept()
Equal("reset leaves recovery", Profile.mode, "normal")
Equal("reset saves a new store", AeonUIDB, Profile.root)
Equal("reset reloads", reloads, 1)
Equal("the export dialog is registered", StaticPopupDialogs.AEONUI_DIAGNOSTIC_EXPORT.hasEditBox, true)
Equal("Escape on the reset dialog is harmless", resetPopup.button2, CANCEL)

-- The layout editor ----------------------------------------------------------------------------------------------

local Editor = AUI.MinimapEditor
window = Load(nil)
Equal("the Rows page draws the layout editor", type(window.pages.minimapRows.preview.refresh), "function")
Equal("elements are named by their pages", AUI.SettingsMinimap:ElementTitle("difficulty"), "Instance Difficulty")
local slots = {
	{ row = "TOP1", index = 1, x = 10, y = 11 }, { row = "TOP1", index = 2, x = 60, y = 11 },
	{ row = "TOP2", index = 1, x = 10, y = 39 }, { row = "TOP2", index = 2, x = 90, y = 39 },
}
local slot = Editor:NearestSlot(slots, 70, 30)
Equal("a drop goes to the nearest row", slot.row, "TOP2")
Equal("at the nearest place in it", slot.index, 2)
local function Shown(key)
	return key ~= "craftingOrders"
end
local top2 = { "mail", "craftingOrders", "tracking", "coordinates" }
Equal("a place among shown elements skips those the client cannot show",
	Editor:ListIndex(top2, "coordinates", 2, Shown), 3)
Equal("the dragged element is left out", Editor:ListIndex(top2, "mail", 1, Shown), 2)
Equal("past the last shown element is the end", Editor:ListIndex(top2, "mail", 9, Shown), 4)

-- The minimap's preview ------------------------------------------------------------------------------------------

local Elements = AUI.MinimapElements
window = Settings:Window()
window.page = "minimapZone"
window:Open()
Equal("opening on a minimap page shows the minimap's samples", Elements.previewers.settings, true)
window:SelectPage("general")
Equal("another page takes them away", Elements.previewers.settings, nil)
window:SelectPage("minimapCalendar")
Equal("a minimap page brings them back", Elements.previewers.settings, true)
window.frame:SetShown(false)
Equal("hiding the window takes them away", Elements.previewers.settings, nil)
window.frame:SetShown(true)
Equal("showing it again on a minimap page brings them back", Elements.previewers.settings, true)
window.frame:SetShown(false)

-- Crafting orders, on a client with them --------------------------------------------------------------------------

AUI.can.craftingOrders = true
window = Load(nil)
Equal("crafting orders get a page after mail", window.order[11], "minimapCraftingOrders")
Equal("which turns the element on or off", window.pages.minimapCraftingOrders.info.switch.path,
	"minimap.elements.craftingOrders.enabled")
AUI.can.craftingOrders = nil

-- Minimap button -------------------------------------------------------------------------------------------------

window = Load(nil)
AUI.can.compartment = true
Broker:Create()
Equal("a launcher", launchers.AeonUI ~= nil, true)
Equal("LibDBIcon keeps the saved table", icon.registered.AeonUI, AeonUIDB.global.minimapButton)
Equal("shown by default", Broker:Hidden(), false)
Equal("added to the compartment", icon.compartment.AeonUI, true)
local checkbox = window.pages.general.sections.access.settings.minimapButton
Equal("the checkbox reads shown", checkbox.get(), true)
checkbox.set(false)
Equal("hiding is saved", AeonUIDB.global.minimapButton.hide, true)
Equal("hiding hides the button", icon.hidden.AeonUI, true)
Equal("the checkbox reads hidden", checkbox.get(), false)
Profile:Create("Keeps Button")
Equal("a profile change keeps the button's table", AeonUIDB.global.minimapButton, icon.registered.AeonUI)
checkbox.set(true)
Equal("showing shows the button", icon.hidden.AeonUI, false)

io.stdout:write(("check_settings: %d checks passed\n"):format(checks))
