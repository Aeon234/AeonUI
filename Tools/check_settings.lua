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

local lib = {}

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
	"Minimap/Rows.lua", "Minimap/Fade.lua", "Minimap/Text.lua", "Minimap/Map.lua", "Settings/Window.lua",
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
Equal("sidebar order", table.concat(window.order, " "), "general minimap - profiles")
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
Equal("the module's switch is the enabled setting", minimapPage.info.switch.path, "minimap.enabled")
Equal("the switch defaults on", minimapPage.info.switch.default, true)

for _, section in ipairs(minimapPage.sections) do
	for _, setting in ipairs(section.settings) do
		Equal(setting.id .. " names a setting", AUI.Schema:Field(setting.path) ~= nil, true)
		Equal(setting.id .. " carries its default", setting.default == nil, AUI.Schema:Field(setting.path).default == nil)
	end
end

for _, group in ipairs({ "rows", "map" }) do
	local fade = minimapPage.sections[group .. "Fade"].settings

	Equal(group .. " mouseover opacity waits for its fade", type(fade[group .. "MouseoverOpacity"].blocked()), "string")
	Equal(group .. " combat opacity waits for its fade", type(fade[group .. "CombatOpacity"].blocked()), "string")
	Profile:Set("minimap.fade." .. group .. ".mouseover", true)
	Profile:Set("minimap.fade." .. group .. ".combat", true)
	Equal(group .. " mouseover opacity follows its fade", fade[group .. "MouseoverOpacity"].blocked(), nil)
	Equal(group .. " combat opacity follows its fade", fade[group .. "CombatOpacity"].blocked(), nil)
	Profile:Set("minimap.fade." .. group .. ".mouseover", false)
	Profile:Set("minimap.fade." .. group .. ".combat", false)
end
Equal("row height is on the page", minimapPage.sections.rows.settings.rowHeight.path, "minimap.rows.height")

local borderSection = minimapPage.sections.border
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
