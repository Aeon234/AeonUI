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
WORLDMAP_BUTTON = "World Map"
DUNGEONS = "Dungeons"
RAIDS = "Raids"
BATTLEGROUNDS = "Battlegrounds"
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
	resettable = true, details = true,
}
local CONTROL_FIELDS = {
	Checkbox = {},
	Button = { verb = true, confirm = true, run = true },
	Slider = { min = true, max = true, step = true, format = true },
	Dropdown = { options = true, picker = true, placeholder = true, titleCase = true, confirm = true, verb = true,
		width = true },
	Color = { hasOpacity = true, classColor = true },
	Toggle = {},
	Details = { summary = true },
}
local PAGE_FIELDS = { title = true, description = true, under = true, icon = true, iconTint = true, slot = true,
	switch = true }
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

local function NewSection(id, title)
	local section = { id = id, title = title, settings = {}, notes = {} }

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

	function page:Section(sectionID, title, sectionInfo)
		Allowed("section " .. sectionID, sectionInfo, { show = true, reveal = true, columns = true })

		local section = NewSection(sectionID, title)

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

-- CallbackHandler's embedded registration: one handler per owner and event, called with the event's name first.
local callbacks = {}
function lib.RegisterCallback(owner, event, handler)
	callbacks[event] = callbacks[event] or {}
	callbacks[event][owner] = handler
end

function lib:Fire(event, ...)
	for _, handler in pairs(callbacks[event] or {}) do
		handler(event, ...)
	end
end

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

	-- A page shown while the window is open is reported, as the library does.
	function window:SelectPage(id)
		self.page = id

		if self.shown then
			lib:Fire("OnPageShown", name, id)
		end
	end

	-- Opening shows the last page; the frame is built on the first opening, and Escape hides it without Close.
	function window:Open()
		if not self.frame then
			local frame = {}

			function frame:Hide()
				window.shown = false
				lib:Fire("OnClose", name)
			end

			self.frame = frame
		end

		self.shown = true
		lib:Fire("OnOpen", name)
		self:SelectPage(self.page)
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

local LSM = {
	MediaType = { FONT = "font", STATUSBAR = "statusbar" },
	Register = function() end,
	Fetch = function() end,
}

local LIBRARIES = { ["LibAeonSettings-1.0"] = lib, ["LibDataBroker-1.1"] = LDB, ["LibDBIcon-1.0"] = icon,
	["LibSharedMedia-3.0"] = LSM }
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
	"Profile/Store.lua", "Profile/Profile.lua", "Media/Media.lua", "UI/Border.lua", "Minimap/Layout.lua",
	"Minimap/Elements.lua", "Minimap/Rows.lua", "Minimap/Fade.lua", "Minimap/Text.lua", "Minimap/Difficulty.lua",
	"Minimap/Buttons.lua", "Minimap/Map.lua", "WorldMap/Markers.lua", "WorldMap/Options.lua", "Tooltip/Options.lua",
	"Tooltip/Tooltip.lua",
	"Settings/Window.lua", "Settings/MinimapEditor.lua", "Settings/General.lua", "Settings/Minimap.lua",
	"Settings/WorldMap.lua", "Settings/Tooltip.lua", "Settings/Profiles.lua", "Settings/Recovery.lua",
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
Equal("sidebar order", table.concat(window.order, " "), "general #mapsHeader minimap #tooltipHeader tooltipGeneral " ..
	"tooltipUnits tooltipItems - profiles")
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
local minimapSections = minimapPage.sections
local Media = AUI.Media
Equal("the Minimap sits under the Maps header", minimapPage.info.under, "mapsHeader")
Equal("with its icon", minimapPage.info.icon, Media.sidebar.minimap)
Equal("tinted as its title", minimapPage.info.iconTint, true)
Equal("it carries the module's switch", minimapPage.info.switch.path, "minimap.enabled")
Equal("which defaults on", minimapPage.info.switch.default, true)
Equal("the layout editor is its preview", type(minimapPage.preview.refresh), "function")
local minimapIDs = {}
for index, section in ipairs(minimapSections) do
	minimapIDs[index] = section.id
end
Equal("the map's cards, then each element's", table.concat(minimapIDs, " "),
	"map fade zoom border rows zone difficulty clock mail tracking coordinates calendar compartment")
Equal("the elements' cards are headed once", minimapSections.zone.title ~= nil and minimapSections.difficulty.title,
	nil)
local outlineChoices = {}
for index, option in ipairs(minimapSections.difficulty.settings.difficultyText_outline.options) do
	outlineChoices[index] = option.value
end
Equal("every outline the library offers is a valid choice", table.concat(outlineChoices, " "),
	table.concat(AUI.Schema.choices.fontOutline, " "))
Equal("icon size follows day and night", minimapSections.clock.settings.iconSize.depends, "dayNight")
Equal("the rows' text opens from its row", minimapSections.rows.settings.rowsText_size.details, "rowsText")
Equal("which reads the rows' text", minimapSections.rows.settings.rowsText_size.path, "minimap.text.size")
Equal("and sums it up", minimapSections.rows.settings.rowsText.summary(),
	("%s, %d"):format(Profile:Get("minimap.text.font"), Profile:Get("minimap.text.size")))
Equal("the zone offers no text color", minimapSections.zone.settings.zoneText_color, nil)
Equal("the clock does", minimapSections.clock.settings.clockText_color.inherits.path, "minimap.text.color")
Equal("an element's text follows its switch", minimapSections.clock.settings.clockText.depends, "clock")
local tiers = 0
for _, setting in ipairs(minimapSections.difficulty.settings) do
	tiers = tiers + (setting.details == "difficultyColors" and 1 or 0)
end
Equal("a color for each difficulty tier", tiers, 5)
Equal("the mail's card notes its empty slot", #minimapSections.mail.notes, 1)

for _, section in ipairs(minimapSections) do
	local key = section.id
	local element = AUI.MinimapElements.byKey[key]

	if element then
		local switch = section.settings[1]

		Equal(key .. " is headed by its switch", switch.kind, "Toggle")
		Equal(key .. " switch is the element's", switch.path, AUI.MinimapElements:EnabledPath(key))
		Equal(key .. " switch defaults on", switch.default, true)

		for index = 2, #section.settings do
			local setting = section.settings[index]

			Equal(setting.id .. " follows something in its card", setting.depends ~= nil or setting.details ~= nil, true)
		end
	end

	for _, setting in ipairs(section.settings) do
		if setting.path then
			Equal(setting.id .. " names a setting", AUI.Schema:Field(setting.path) ~= nil, true)
			local field = AUI.Schema:Field(setting.path)
			local source = field.shared and AUI.Schema:Field(field.shared) or field

			Equal(setting.id .. " carries its default", setting.default == nil, source.default == nil)
			Equal(setting.id .. " follows what its field follows", setting.inherits and setting.inherits.path,
				field.shared)
		end
	end
end

local fade = minimapSections.fade.settings
Equal("mouseover opacity follows its fade", fade.fadeMouseoverOpacity.depends, "fadeMouseover")
Equal("combat opacity follows its fade", fade.fadeCombatOpacity.depends, "fadeCombat")
Equal("row height is on the page", minimapSections.rows.settings.rowHeight.path, "minimap.rows.height")
Equal("precision is a plain count of decimal places", minimapSections.coordinates.settings.precision.format, nil)

local borderSection = minimapSections.border
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
local resetSlider = minimapSections.zoom.settings.zoomReset
Equal("a zero reset reads Never", resetSlider.format(0), "Never")
Equal("a reset reads in seconds", resetSlider.format(15), "15 s")

-- Tooltip pages -------------------------------------------------------------------------------------------------

local TooltipOptions = AUI.TooltipOptions
local TOOLTIP_SWITCH = "tooltipGeneral/enabled"

for id in pairs(AUI.SettingsTooltip.pageIDs) do
	local page = window.pages[id]

	Equal(id .. " sits under the Tooltip header", page.info.under, "tooltipHeader")
	Equal(id .. " has its icon", page.info.icon, Media.sidebar[id])
	Equal(id .. " carries the switch only on General", page.info.switch ~= nil, id == "tooltipGeneral")

	for _, section in ipairs(page.sections) do
		for _, setting in ipairs(section.settings) do
			if setting.path then
				Equal(setting.id .. " names a setting", AUI.Schema:Field(setting.path) ~= nil, true)
				Equal(setting.id .. " carries its default", setting.default, AUI.Schema:Field(setting.path).default)
			else
				Equal(setting.id .. " reads and writes its own value", type(setting.get) == "function"
					and type(setting.set) == "function", true)
			end

			if id ~= "tooltipGeneral" then
				local parent = setting

				while parent.depends and parent.depends ~= TOOLTIP_SWITCH do
					parent = section.settings[parent.depends]
				end

				Equal(setting.id .. " follows the module's switch", parent and parent.depends, TOOLTIP_SWITCH)
			end
		end
	end
end

local general = window.pages.tooltipGeneral
Equal("the switch is the module's", general.info.switch.path, TooltipOptions.ENABLED_PATH)
Equal("which defaults on", general.info.switch.default, true)
Equal("and is named for the tooltip", general.info.switch.label, "Tooltip")
local tooltipBar = general.sections.tooltipHealthBar.settings
Equal("every bar style is offered", #tooltipBar.barStyle.options, #TooltipOptions.BAR_STYLES)
Equal("one height for both styles", tooltipBar.barHeight.path, TooltipOptions.BAR_HEIGHT_PATH)
Equal("no second height", tooltipBar.stripHeight, nil)
local tooltipFont = general.sections.tooltipFont.settings
Equal("the font follows Custom Font", tooltipFont.fontFace.depends, "customFont")
Equal("the scale stands on its own", tooltipFont.fontScale.depends, nil)
Equal("the bar's style follows Show Health Bar", tooltipBar.barStyle.depends, "showHealthBar")
Equal("so does its height", tooltipBar.barHeight.depends, "showHealthBar")
local unitAdded = window.pages.tooltipUnits.sections.tooltipUnitAdded.settings
local mythicPlus, auraCasterNames = AUI.can.mythicPlus, AUI.can.auraCasterNames
AUI.can.mythicPlus, AUI.can.auraCasterNames = nil, nil
Equal("the rating is offered only where players have one", unitAdded.showRating.show(), false)
Equal("the caster names only where the client has them", unitAdded.auraCasters.show(), false)
AUI.can.mythicPlus, AUI.can.auraCasterNames = true, true
Equal("the rating on Retail", unitAdded.showRating.show(), true)
Equal("the caster names where the client has them", unitAdded.auraCasters.show(), true)
AUI.can.mythicPlus, AUI.can.auraCasterNames = mythicPlus, auraCasterNames
Equal("the Target line is offered everywhere", unitAdded.showTarget.show, nil)
Equal("titles are hidden by default", window.pages.tooltipUnits.sections.tooltipUnitLines.settings.showTitles.default,
	false)
local visibility = general.sections.tooltipVisibility.settings
local place = general.sections.tooltipPlace.settings
Equal("every show mode is offered", #visibility.showMode.options, #TooltipOptions.SHOW_MODES)
Equal("tooltips show always by default", visibility.showMode.default, "ALWAYS")
Equal("the show key needs a mode that hides", visibility.peekKey.blocked() ~= nil, true)
Equal("Enhanced Tooltips is the game's, not the profile's", visibility.enhancedTooltips.path, nil)
Equal("the cursor anchor starts off", place.anchorCursor.default, false)
Equal("its place follows it", place.cursorPoint.depends, "anchorCursor")
Equal("so do its offsets", place.cursorX.depends .. " " .. place.cursorY.depends, "anchorCursor anchorCursor")
Equal("every place around the cursor is offered", #place.cursorPoint.options, #TooltipOptions.CURSOR_POINTS)
Equal("growth is free while the tooltip has a place", place.growth.blocked(), nil)
local items = window.pages.tooltipItems
local detailIDs = items.sections.tooltipDetailIDs.settings
Equal("the Items page has the Details preview", items.preview ~= nil, true)
Equal("every modifier is offered", #detailIDs.idModifier.options, #TooltipOptions.MODIFIERS)
Equal("the modifier has a card of its own", #items.sections.tooltipDetailIDs.settings, 1)
local idLines = items.sections.tooltipDetailIDLines.settings
Equal("one checkbox per ID line", #idLines, #TooltipOptions.ID_KEYS)
Equal("ID lines default on", idLines.showSpellID.default, true)
Equal("an ID line's scope is in its tooltip", idLines.showItemID.tooltip, "Items and toys.")
Equal("with no modifier", detailIDs.idModifier.default, "NONE")
local expansions = AUI.can.expansions
AUI.can.expansions = nil
Equal("the expansion is offered only where items have one",
	items.sections.tooltipDetailLines.settings.showExpansion.show(), false)
AUI.can.expansions = expansions

-- Choice cards ---------------------------------------------------------------------------------------------------

-- The library draws a section asking for two columns one to a line unless every row is a checkbox with no second
-- line; the pages must keep to that.
local function ChoiceCards(page)
	local cards = {}

	for _, section in ipairs(page.sections) do
		if section.info and section.info.columns == 2 then
			cards[#cards + 1] = section.id
			Equal(section.id .. " has two or more choices", #section.settings >= 2, true)

			for _, setting in ipairs(section.settings) do
				Equal(setting.id .. " is a checkbox", setting.kind, "Checkbox")
				Equal(setting.id .. " has no second line", setting.description, nil)
			end
		end
	end

	return table.concat(cards, " ")
end

Equal("the Units page's choice cards", ChoiceCards(window.pages.tooltipUnits), "tooltipUnitLines tooltipUnitAdded")
Equal("the Items page's", ChoiceCards(window.pages.tooltipItems), "tooltipDetailLines tooltipDetailIDLines")
Equal("a unit line says what it adds in its tooltip",
	type(window.pages.tooltipUnits.sections.tooltipUnitLines.settings.colorLevels.tooltip), "string")
Equal("the layout editor's stage is as tall as the diagram", window.pages.minimap.preview.height,
	AUI.MinimapEditor:Height())
Equal("which is its margins, four rows and the map", AUI.MinimapEditor:Height(), 180)

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
Equal("on the Map card, which offers Edit Position", target.settings.section, "map")
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
local clicked, matches = {}, false
local resetDialog = { GetButton1 = function()
	return { IsEnabled = function()
		return matches
	end }
end }
local resetBox = { GetParent = function()
	return resetDialog
end }
function StaticPopup_OnClick(dialog, index)
	clicked[#clicked + 1] = { dialog = dialog, index = index }
end
resetPopup.EditBoxOnEnterPressed(resetBox)
Equal("Enter does nothing before the word matches", #clicked, 0)
matches = true
resetPopup.EditBoxOnEnterPressed(resetBox)
Equal("then Enter presses Reset", #clicked == 1 and clicked[1].dialog == resetDialog and clicked[1].index == 1, true)
StaticPopup_OnClick = nil
resetPopup.OnAccept()
Equal("reset leaves recovery", Profile.mode, "normal")
Equal("reset saves a new store", AeonUIDB, Profile.root)
Equal("reset reloads", reloads, 1)
Equal("the export dialog is registered", StaticPopupDialogs.AEONUI_DIAGNOSTIC_EXPORT.hasEditBox, true)
Equal("Escape on the reset dialog is harmless", resetPopup.button2, CANCEL)

-- The layout editor ----------------------------------------------------------------------------------------------

local Editor = AUI.MinimapEditor
window = Load(nil)
Equal("elements are named by their cards", AUI.SettingsMinimap:ElementTitle("difficulty"), "Instance Difficulty")
Equal("the calendar offers an icon size", window.pages.minimap.sections.calendar.settings.calendarIconSize.path,
	"minimap.calendar.iconSize")
Equal("the calendar's icon starts larger", AUI.Settings:Default("minimap.calendar.iconSize"), 100)
Equal("the compartment has no icon to size", window.pages.minimap.sections.compartment.settings.compartmentIconSize,
	nil)
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
window.page = "minimap"
window:Open()
Equal("opening on the Minimap page shows the minimap's samples", Elements.previewers.settings, true)
window:SelectPage("general")
Equal("another page takes them away", Elements.previewers.settings, nil)
window:SelectPage("minimap")
Equal("the Minimap page brings them back", Elements.previewers.settings, true)
window.frame:Hide()
Equal("hiding the window takes them away", Elements.previewers.settings, nil)
window:Open()
Equal("opening it again on the Minimap page brings them back", Elements.previewers.settings, true)
window.frame:Hide()

-- Crafting orders, on a client with them --------------------------------------------------------------------------

AUI.can.craftingOrders = true
window = Load(nil)
local craftingCard = window.pages.minimap.sections.craftingOrders
Equal("crafting orders get a card after mail", window.pages.minimap.sections[10], craftingCard)
Equal("which turns the element on or off", craftingCard.settings[1].path, "minimap.elements.craftingOrders.enabled")
AUI.can.craftingOrders = nil

-- World Map, on a client with marker data -------------------------------------------------------------------------

Equal("no World Map page without marker data", window.pages.worldMap, nil)
AUI.can.worldMapMarkers = true
window = Load(nil)
Equal("the World Map follows the Minimap under Maps", table.concat(window.order, " "):match("#mapsHeader (.-) #"),
	"minimap worldMap")
local worldMap = window.pages.worldMap
Equal("the World Map sits under the Maps header", worldMap.info.under, "mapsHeader")
Equal("with its icon", worldMap.info.icon, Media.sidebar.worldMap)
Equal("with no page switch", worldMap.info.switch, nil)
local worldMapIDs = {}
for index, section in ipairs(worldMap.sections) do
	worldMapIDs[index] = section.id
end
Equal("the map's cards, then the markers'", table.concat(worldMapIDs, " "),
	"unexplored levels dungeonMaps markers places travel town minimap")
local switches = 0
for _, section in ipairs(worldMap.sections) do
	for _, setting in ipairs(section.settings) do
		local field = AUI.Schema:Field(setting.path)

		switches = switches + (setting.id:match("^marker_") and 1 or 0)
		Equal(setting.id .. " names a setting", field ~= nil, true)
		Equal(setting.id .. " carries its default", setting.default, field.default)
		Equal(setting.id .. " has a label", type(setting.label), "string")
	end
end
Equal("a switch for every category", switches, #AUI.WorldMapMarkers.CATEGORIES)
Equal("the categories and pins are choice cards", ChoiceCards(worldMap), "places travel town minimap")
local darkness = worldMap.sections.unexplored.settings.darkness
Equal("darkness is a percentage", darkness.format, "percent")
Equal("which needs the unexplored areas on", darkness.depends, "unexplored")
Equal("fishing levels start off", worldMap.sections.levels.settings.fishingLevels.default, false)
local markers = worldMap.sections.markers
Equal("the markers' card is headed by their switch", markers.settings[1].kind, "Toggle")
Equal("which is the markers'", markers.settings[1].path, "worldMap.markers.enabled")
Equal("which defaults on", markers.settings[1].default, true)
Equal("and redraws the page", markers.settings[1].redraws, true)
Equal("the cities-only switch sits with the markers", markers.settings.capitalsOnly.path,
	"worldMap.markers.capitalsOnly")
Equal("and follows their switch", markers.settings.capitalsOnly.depends, "markers")
Equal("marker size is a percentage", markers.settings.markerSize.format, "percent")
Equal("the other faction stays hidden by default", markers.settings.otherFaction.default, false)
Equal("a minimap switch for each group", #worldMap.sections.minimap.settings, #AUI.WorldMapMarkers.MINIMAP)
Equal("the categories show while the markers are on", worldMap.sections.town.info.show(), true)
Profile:Set("worldMap.markers.enabled", false)
Equal("and leave while they are off", worldMap.sections.places.info.show(), false)
Equal("with the minimap pins", worldMap.sections.minimap.info.show(), false)
Profile:Set("worldMap.markers.enabled", true)
local leyLines = worldMap.sections.places.settings.marker_leyLines
local stables = worldMap.sections.town.settings.marker_stableMasters
AUI.WorldMap = { race = 1, class = "MAGE" }
Equal("ley lines are offered only to their race", leyLines.show(), false)
Equal("stable masters only to hunters", stables.show(), false)
AUI.WorldMap.race, AUI.WorldMap.class = 95, "HUNTER"
Equal("which sees them", leyLines.show(), true)
Equal("a hunter sees stable masters", stables.show(), true)
Equal("dungeons are offered to everyone", worldMap.sections.places.settings.marker_dungeons.show, nil)
AUI.WorldMap = nil
Equal("the page is listed as the World Map's", AUI.SettingsWorldMap.pageIDs.worldMap, true)
AUI.can.worldMapMarkers = nil

-- Tooltip upgrades, on a client with upgrade tracks ---------------------------------------------------------------

Equal("no upgrade card without upgrade tracks", window.pages.tooltipItems.sections.tooltipUpgradeLine, nil)
AUI.can.upgrades = true
window = Load(nil)
local upgradeSection = window.pages.tooltipItems.sections.tooltipUpgradeLine
Equal("the upgrade card ends the Items page", window.pages.tooltipItems.sections[#window.pages.tooltipItems.sections],
	upgradeSection)
local upgradeLine = upgradeSection.settings
Equal("the range color follows the range", upgradeLine.upgradeRangeColor.depends, "upgradeRange")
Equal("the range follows the module's switch", upgradeLine.upgradeRange.depends, TOOLTIP_SWITCH)
Equal("the range color defaults to white", upgradeLine.upgradeRangeColor.default.g, 1)
Equal("the rank and range are on by default", upgradeLine.upgradeRank.default and upgradeLine.upgradeRange.default,
	true)
Equal("the next crest is off", upgradeLine.upgradeCrest.default, false)
AUI.can.upgrades = nil

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
