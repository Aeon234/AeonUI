local AUI = select(2, ...)

local L = AUI.L

---The General page: settings that belong to the addon as a whole rather than one feature.
---@class AUISettingsGeneral
local General = {}
AUI.SettingsGeneral = General

---@param window table
function General:Declare(window)
	local page = window:Page("general", {
		title = GENERAL,
	})

	if not page then
		return
	end

	local access = page:Section("access", L["Access"])

	access:Checkbox({
		id = "minimapButton",
		label = L["Show Minimap Button"],
		description = L["Left-click opens settings."],
		get = function()
			return not AUI.Broker:Hidden()
		end,
		set = function(value)
			AUI.Broker:SetHidden(not value)
		end,
	})
	access:Note(L["/aui and the addon compartment open settings too."])

	self:DeclareScale(page)
end

---@param section table
---@param key string a stable id suffix
---@param label string
---@param description string
---@param percent fun(): number the scale the button sets
local function PresetButton(section, key, label, description, percent)
	local UIScale = AUI.UIScale

	section:Button({
		id = "uiScalePreset" .. key,
		label = label,
		description = description,
		verb = APPLY,
		depends = "uiScale",
		blocked = function()
			return UIScale:Blocked()
		end,
		run = function()
			UIScale:SetScale(percent())
		end,
	})
end

---The Scale section: the interface's scale and its presets, then the game menu's.
---@param page table
function General:DeclareScale(page)
	local UIScale, GameMenuScale = AUI.UIScale, AUI.GameMenuScale
	local scale = page:Section("scale", L["Scale"])

	local function Blocked()
		return UIScale:Blocked()
	end

	scale:Checkbox({
		id = "uiScale",
		label = UI_SCALE,
		description = L["Sets the scale of the whole interface, below the game's own minimum if needed. Turning it off takes a reload."],
		blocked = Blocked,
		get = function()
			return UIScale:IsEnabled()
		end,
		set = function(value)
			UIScale:SetEnabled(value)
		end,
	})
	scale:Slider({
		id = "uiScaleValue",
		label = L["Scale"],
		depends = "uiScale",
		blocked = Blocked,
		min = UIScale.MIN_PERCENT,
		max = UIScale.MAX_PERCENT,
		step = 1,
		format = "percent",
		get = function()
			return UIScale:Current()
		end,
		set = function(value)
			UIScale:SetScale(value)
		end,
	})

	PresetButton(scale, "PixelPerfect", L["Pixel Perfect"],
		L["The scale at which one interface unit is one pixel on this screen."], function()
			local _, height = GetPhysicalScreenSize()

			return UIScale.PixelPerfect(height)
		end)

	for _, preset in ipairs(UIScale.PRESETS) do
		PresetButton(scale, preset.key, preset.key, L["The pixel-perfect scale for a %s screen."]:format(preset.key),
			function()
				return UIScale.PixelPerfect(preset.height)
			end)
	end

	scale:Slider({
		id = "gameMenuScale",
		label = L["Game Menu Scale"],
		description = L["Scales the game menu that Escape opens."],
		default = GameMenuScale.DEFAULT,
		resettable = true,
		min = GameMenuScale.MIN_PERCENT,
		max = GameMenuScale.MAX_PERCENT,
		step = GameMenuScale.STEP,
		format = "percent",
		get = function()
			return GameMenuScale:Get()
		end,
		set = function(value)
			GameMenuScale:Set(value)
		end,
	})
end
