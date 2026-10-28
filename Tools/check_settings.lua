-- Checks Settings/*.lua and Core/Broker.lua outside the game: which pages the window declares in each profile mode,
-- the declaration's store and write hooks, the Profiles adapter's translation between names and profile IDs, the
-- Damaged Profiles section, the Recovery page's export and reset, and the minimap button's saved state.
-- Run from any directory with Lua 5.1: lua Tools/check_settings.lua
-- Loads the real files against a stand-in for LibAeonSettings that records declarations and refuses fields the
-- library does not accept. It proves the declarations and adapters, not the library's drawing.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

UNKNOWN = "Unknown"
GUILD = "Guild"
ACTIONBARS_LABEL = "Action Bars"
RAID_TARGET_8 = "Skull"
APPLY = "Apply"
RELOADUI = "Reload UI"
UI_SCALE = "UI Scale"
CHOOSE = "Choose"
OFF = "Off"
VIDEO_OPTIONS_LOW = "Low"
VIDEO_OPTIONS_MEDIUM = "Good"
VIDEO_OPTIONS_HIGH = "High"
MERCHANT = "Merchant"
AUCTION_HOUSE_FILTER_CURRENTEXPANSION_ONLY = "Current Expansion Only"
AUTO_LOOT_DEFAULT_TEXT = "Auto Loot"
BLOCK_TRADES = "Block Trades"
BLOCK_GUILD_INVITES = "Block Guild Invites"
BLOCK_CHAT_CHANNEL_INVITE = "Block Chat Channel Invites"
local cvars = { autoLootDefault = "0", weatherDensity = "3", blockTrades = "0", blockChannelInvites = "0" }
C_CVar = {
	GetCVarInfo = function(name)
		return cvars[name]
	end,
}
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
local cliqueLoaded = false
C_AddOns = {
	GetAddOnMetadata = function() end,
	IsAddOnLoaded = function(name) return name == "Clique" and cliqueLoaded end,
}
UIParent = { GetScale = function() return 0.8 end }
GameMenuFrame = { SetScale = function(self, scale) self.scale = scale end }
function GetPhysicalScreenSize()
	return 2560, 1440
end

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
		width = true, action = true },
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
	"Tooltip/Tooltip.lua", "Interface/UIScale.lua", "Interface/GameMenuScale.lua",
	"Automation/Options.lua", "Automation/GameSettings.lua", "Menus/Options.lua", "Input/Options.lua",
	"Input/FocusShortcut.lua",
	"Settings/Window.lua", "Settings/MinimapEditor.lua", "Settings/General.lua", "Settings/Minimap.lua",
	"Settings/WorldMap.lua", "Settings/Tooltip.lua", "Settings/Automation.lua", "Settings/PlayerMenu.lua",
	"Settings/Input.lua", "Settings/Profiles.lua", "Settings/Recovery.lua",
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
	"tooltipUnits tooltipItems #qualityOfLifeHeader automation - profiles")
AUI.can.playerMenus, AUI.can.guildInvite, AUI.can.raiderIOLinks, AUI.can.warcraftLogsLinks = true, true, true, true
window = Load(nil)
Equal("Player Menu follows Automation", table.concat(window.order, " "), "general #mapsHeader minimap " ..
	"#tooltipHeader tooltipGeneral tooltipUnits tooltipItems #qualityOfLifeHeader automation playerMenu - profiles")
local playerMenuPage = window.pages.playerMenu
local playerMenuIDs = {}
for _, section in ipairs(playerMenuPage.sections) do
	for _, setting in ipairs(section.settings) do
		playerMenuIDs[#playerMenuIDs + 1] = section.title .. ":" .. setting.id .. "=" .. tostring(setting.default)
	end
end
Equal("cards named as the menu shows them, every entry on", table.concat(playerMenuIDs, " "),
	"Guild:guildInvite=true External Links:raiderIOLink=true External Links:warcraftLogsLink=true")
Equal("the links as a choice card", playerMenuPage.sections.playerMenuLinks.info.columns, 2)
Equal("under the Quality of Life header", playerMenuPage.info.under, "qualityOfLifeHeader")
AUI.can.raiderIOLinks, AUI.can.warcraftLogsLinks = nil, nil
window = Load(nil)
Equal("Forever: the Guild card alone", window.pages.playerMenu.sections[1].id .. " "
	.. tostring(window.pages.playerMenu.sections.playerMenuLinks), "playerMenuGuild nil")
AUI.can.playerMenus, AUI.can.guildInvite = nil, nil
window = Load(nil)
Equal("no Player Menu page without player menus", window.pages.playerMenu, nil)
AUI.can.clickDown, AUI.can.focusShortcut = true, true
window = Load(nil)
Equal("Input follows Player Menu's place", table.concat(window.order, " "), "general #mapsHeader minimap " ..
	"#tooltipHeader tooltipGeneral tooltipUnits tooltipItems #qualityOfLifeHeader automation input - profiles")
local inputPage = window.pages.input
local inputIDs = {}
for _, section in ipairs(inputPage.sections) do
	for _, setting in ipairs(section.settings) do
		inputIDs[#inputIDs + 1] = section.id .. ":" .. setting.id .. "=" .. tostring(setting.default)
	end
end
Equal("a card for each, every setting at its default", table.concat(inputIDs, " "),
	"inputClickDown:clickDown=UNMANAGED inputFocusShortcut:focusShortcut=false inputFocusShortcut:focusModifier=shift "
	.. "inputFocusShortcut:focusButton=1 inputFocusShortcut:focusWorld=true inputFocusShortcut:focusMark=false "
	.. "inputFocusShortcut:focusMarker=8")
Equal("under the Quality of Life header", inputPage.info.under, "qualityOfLifeHeader")
local clickDown = inputPage.sections.inputClickDown.settings.clickDown
local clickDownTexts = {}
for _, option in ipairs(clickDown.options) do
	clickDownTexts[#clickDownTexts + 1] = option.value .. "=" .. option.text
end
Equal("Click Down's choices", table.concat(clickDownTexts, " "),
	"UNMANAGED=Not Managed ON=Always On COMBAT=In Combat Only OFF=Always Off")
Equal("named for what it does, with no second line", clickDown.label .. " " .. tostring(clickDown.description),
	"Cast on Key Down nil")
Equal("cards titled", inputPage.sections.inputClickDown.title .. " | " .. inputPage.sections.inputFocusShortcut.title,
	"Action Bars | Focus Keybind")
local focusCard = inputPage.sections.inputFocusShortcut.settings
Equal("Focus Keybind is headed by its switch", focusCard.focusShortcut.kind .. " " .. focusCard.focusShortcut.label,
	"Toggle Focus on Click")
Equal("with no line while Clique is away", focusCard.focusShortcut.description, nil)
Equal("its settings follow it", focusCard.focusModifier.depends .. " " .. focusCard.focusButton.depends .. " "
	.. focusCard.focusWorld.depends .. " " .. focusCard.focusMark.depends, "focusShortcut focusShortcut focusShortcut "
	.. "focusShortcut")
Equal("the marker follows Mark Focus", focusCard.focusMarker.depends, "focusMark")
Equal("markers by Blizzard's names", focusCard.focusMarker.options[8].text, "Skull")
Equal("modifiers", #focusCard.focusModifier.options .. " " .. focusCard.focusModifier.options[4].text, "6 Ctrl + Shift")
cliqueLoaded = true
window = Load(nil)
Equal("with Clique, the switch says where to bind Focus",
	window.pages.input.sections.inputFocusShortcut.settings.focusShortcut.description,
	"Clique handles unit frames; bind Focus there.")
cliqueLoaded = false
AUI.can.clickDown = nil
window = Load(nil)
Equal("without the console variable, Focus Shortcut alone", window.pages.input.sections[1].id .. " "
	.. tostring(window.pages.input.sections.inputClickDown), "inputFocusShortcut nil")
AUI.can.focusShortcut = nil
window = Load(nil)
Equal("no Input page without either", window.pages.input, nil)
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
Equal("the mail's card has no footer", #minimapSections.mail.notes, 0)

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
Equal("Action Bar Tooltips Here is the game's, not the profile's", place.enhancedTooltips.path, nil)
Equal("and is no longer a visibility setting", visibility.enhancedTooltips, nil)
Equal("the cursor anchor starts off", place.anchorCursor.default, false)
Equal("its place follows it", place.cursorPoint.depends, "anchorCursor")
Equal("so do its offsets", place.cursorX.depends .. " " .. place.cursorY.depends, "anchorCursor anchorCursor")
Equal("every place around the cursor is offered", #place.cursorPoint.options, #TooltipOptions.CURSOR_POINTS)
Equal("growth is free while the tooltip has a place", place.growth.blocked(), nil)
local items = window.pages.tooltipItems
local detailIDs = items.sections.tooltipDetailIDs.settings
Equal("the Items page has the Details preview", items.preview ~= nil, true)
Equal("the Units page has the samples' preview", window.pages.tooltipUnits.preview ~= nil, true)
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
local geometry = { left = 70, top = { TOP1 = 14, TOP2 = 42, BOTTOM1 = 116, BOTTOM2 = 144 } }
local rows = { TOP1 = { "zone", "clock" }, TOP2 = { "mail" }, BOTTOM1 = {}, BOTTOM2 = {} }
local widths = { zone = 40, clock = 30, mail = 20 }
local places = Editor:Positions(rows, widths, geometry)
Equal("pieces sit left to right", places.zone.x .. " " .. places.clock.x, "74 118")
Equal("inside their row", places.zone.y, 16)
places = Editor:Positions(rows, widths, geometry, { key = "clock", target = { row = "TOP2", index = 1 } })
Equal("a carried piece's target row opens a gap for it", places.mail.x, 108)
Equal("where it will land", places.clock.x .. " " .. places.clock.y, "74 44")
Equal("its own row closes up", places.zone.x, 74)
places = Editor:Positions(rows, widths, geometry, { key = "zone", target = { row = "TOP1", index = 2 } })
Equal("within its row it changes places", places.clock.x .. " " .. places.zone.x, "74 108")
places = Editor:Positions(rows, widths, geometry, { key = "zone" })
Equal("without a target everything keeps its place", places.zone.x .. " " .. places.clock.x, "74 118")
local dragSlots = Editor:Slots(rows, widths, geometry, "clock")
Equal("slots leave the carried piece out", #dragSlots, 2 + 2 + 1 + 1)
Equal("before the first piece", dragSlots[1].x .. " " .. dragSlots[1].index, "72 1")
Equal("and after the last", dragSlots[2].x .. " " .. dragSlots[2].index, "116 2")
Equal("at the row's middle", dragSlots[1].y, 25)

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

-- Scale section ----------------------------------------------------------------------------------------------

window = Load(nil)
local scale = window.pages.general.sections.scale
local order = {}
for _, setting in ipairs(scale.settings) do
	order[#order + 1] = setting.id
end
Equal("the Scale section's order", table.concat(order, " "), "uiScale uiScaleValue uiScalePixelPerfect " ..
	"uiScaleResolution gameMenuScale")
Equal("the section follows Access", window.pages.general.sections[2], scale)
Equal("UI Scale is on by default", scale.settings.uiScale.get(), true)
Equal("the slider reads the current scale with nothing saved", scale.settings.uiScaleValue.get(), 80)
for _, id in ipairs({ "uiScaleValue", "uiScalePixelPerfect", "uiScaleResolution" }) do
	Equal(id .. " follows UI Scale", scale.settings[id].depends, "uiScale")
	Equal(id .. " is not blocked", scale.settings[id].blocked(), nil)
end
scale.settings.uiScalePixelPerfect.run()
Equal("Pixel Perfect saves this screen's scale account-wide", math.floor(AeonUIDB.global.uiScale.scale * 100 + 0.5),
	5333)
local resolution = scale.settings.uiScaleResolution
Equal("the other resolutions are an action dropdown", resolution.action, true)
Equal("offering each preset", #resolution.options .. " " .. resolution.options[3].value, "3 4K")
Equal("with no choice of its own", resolution.get, nil)
resolution.set("4K")
Equal("4K saves its scale", math.floor(AeonUIDB.global.uiScale.scale * 100 + 0.5), 3556)
scale.settings.uiScaleValue.set(75)
Equal("the slider saves", AeonUIDB.global.uiScale.scale, 75)
Profile:Create("Keeps Scale")
Equal("a profile change keeps the scale", scale.settings.uiScaleValue.get(), 75)
local menu = scale.settings.gameMenuScale
Equal("the game menu reads 100% by default", menu.get(), 100)
Equal("its default", menu.default, 100)
menu.set(80)
Equal("the game menu's scale is saved account-wide", AeonUIDB.global.gameMenuScale, 80)
Equal("and applied", GameMenuFrame.scale, 0.8)

-- Details preview --------------------------------------------------------------------------------------------

-- The preview's tooltips, as GameTooltipTemplate makes them: a data update only flags a refresh.
local previewTooltips = {}
local createFrame = CreateFrame
function CreateFrame(kind, name)
	assert(kind == "GameTooltip", "unexpected frame type " .. tostring(kind))
	local tooltip = { name = name, shown = true, refreshed = 0, scripts = {} }
	function tooltip:HookScript(script, handler)
		self.scripts[script] = handler
	end
	function tooltip:IsShown()
		return self.shown
	end
	function tooltip:RefreshData()
		self.shouldRefreshData = false
		self.refreshed = self.refreshed + 1
	end
	function tooltip:Event(event)
		if event == "TOOLTIP_DATA_UPDATE" then
			self.shouldRefreshData = true
		end
		self.scripts.OnEvent(self, event)
	end
	previewTooltips[#previewTooltips + 1] = tooltip

	return tooltip
end
AUI.TooltipDetails = AUI.TooltipDetails or {}
window.pages.tooltipItems.preview.create({})
CreateFrame = createFrame
local itemPreview = previewTooltips[1]
Equal("three preview tooltips", #previewTooltips, 3)
itemPreview:Event("TOOLTIP_DATA_UPDATE")
Equal("an item that finishes loading rebuilds its tooltip", itemPreview.refreshed, 1)
Equal("and clears the flag", itemPreview.shouldRefreshData, false)
itemPreview:Event("MODIFIER_STATE_CHANGED")
Equal("other events rebuild nothing", itemPreview.refreshed, 1)
itemPreview.shown = false
itemPreview:Event("TOOLTIP_DATA_UPDATE")
Equal("a hidden preview waits", itemPreview.refreshed, 1)

-- Automation page ------------------------------------------------------------------------------------------

local function SettingIDs(section)
	local ids = {}
	for _, setting in ipairs(section.settings) do
		ids[#ids + 1] = setting.id
	end

	return table.concat(ids, " ")
end

AUI.can.mail, AUI.can.expansionFilter, AUI.can.autoDeclineGuildInvites = true, true, true
window = Load(nil)
local automation = window.pages.automation
Equal("under the Quality of Life header", automation.info.under, "qualityOfLifeHeader")
Equal("with its icon", automation.info.icon, AUI.Media.sidebar.automation)
local sectionIDs = {}
for index, section in ipairs(automation.sections) do
	sectionIDs[index] = section.id
end
Equal("the cards in order", table.concat(sectionIDs, " "), "automationMerchant automationMail automationAuctionHouse " ..
	"automationGameSettings automationBlocks")
local merchantCard = automation.sections.automationMerchant
Equal("the merchant card", SettingIDs(merchantCard), "sellJunk reportSales autoRepair repairFunds")
Equal("Report Sales follows Sell Junk", merchantCard.settings.reportSales.depends, "sellJunk")
Equal("Funds follows Auto Repair", merchantCard.settings.repairFunds.depends, "autoRepair")
Equal("selling is off by default", merchantCard.settings.sellJunk.default, false)
Equal("repairing is off by default", merchantCard.settings.autoRepair.default, false)
Equal("reports are on by default", merchantCard.settings.reportSales.default, true)
Equal("guild funds first by default", merchantCard.settings.repairFunds.default, "GUILD_FIRST")
Equal("three funds", #merchantCard.settings.repairFunds.options, 3)
Equal("the filter's windows follow it", automation.sections.automationAuctionHouse.settings.expansionAuctionHouse.depends,
	"expansionFilter")
Equal("the game settings card", SettingIDs(automation.sections.automationGameSettings), "managedautoLoot managedweather")
Equal("the blocks card", SettingIDs(automation.sections.automationBlocks),
	"managedtrades managedguildInvites managedchannelInvites managedduels")
local weather = automation.sections.automationGameSettings.settings.managedweather
Equal("weather offers Not Managed and four levels", #weather.options, 5)
Equal("managed settings start unmanaged", weather.default, "UNMANAGED")
Equal("the weather levels use Blizzard's names", weather.options[2].text .. " " .. weather.options[5].text, "Off High")
Equal("a setting Blizzard also offers has no second line",
	automation.sections.automationBlocks.settings.managedtrades.description, nil)
Equal("the merchant card ends with the Shift note", merchantCard.notes[1].text,
	"Hold Shift as a merchant opens to skip both.")
Equal("a value is written to the profile", (declaration.write("automation.sellJunk", true)), true)
Equal("and read back", Profile:Get("automation.sellJunk"), true)

AUI.can.mail, AUI.can.expansionFilter, AUI.can.autoDeclineGuildInvites = nil, nil, nil
cvars.weatherDensity = nil
window = Load(nil)
automation = window.pages.automation
Equal("Forever: no Auction House card", automation.sections.automationAuctionHouse, nil)
Equal("no Mail card without the send form", automation.sections.automationMail, nil)
Equal("a setting the client lacks is left out", SettingIDs(automation.sections.automationGameSettings), "managedautoLoot")
Equal("as is the guild-invite block", SettingIDs(automation.sections.automationBlocks),
	"managedtrades managedchannelInvites managedduels")
cvars.weatherDensity = "3"

io.stdout:write(("check_settings: %d checks passed\n"):format(checks))
