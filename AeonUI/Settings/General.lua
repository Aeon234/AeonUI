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
		icon = AUI.Media.sidebar.general,
		iconTint = true,
	})

	if not page then
		return
	end

	local access = page:Section("access", L["Access"])

	access:Checkbox({
		id = "minimapButton",
		label = L["Show Minimap Button"],
		description = L["Left-click opens settings. Right-click opens edit mode."],
		get = function()
			return not AUI.Broker:Hidden()
		end,
		set = function(value)
			AUI.Broker:SetHidden(not value)
		end,
	})
	access:Button({
		id = "keyBindings",
		label = KEY_BINDINGS,
		verb = L["Open"],
		run = function()
			AUI.Bindings:Open()
		end,
	})

	self:DeclareScale(page)
end

---The Scale section: the interface's scale, Pixel Perfect for this screen and for other resolutions, then the game
---menu's scale.
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
		description = L["Goes below the game's own minimum. Turning it off needs a reload."],
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

	scale:Button({
		id = "uiScalePixelPerfect",
		label = L["Pixel Perfect"],
		description = L["One interface unit per pixel on this screen."],
		verb = APPLY,
		depends = "uiScale",
		blocked = Blocked,
		run = function()
			local _, height = GetPhysicalScreenSize()

			UIScale:SetScale(UIScale.PixelPerfect(height))
		end,
	})

	local resolutions = {}

	for index, preset in ipairs(UIScale.PRESETS) do
		resolutions[index] = { value = preset.key, text = preset.key }
	end

	scale:Dropdown({
		id = "uiScaleResolution",
		label = L["Pixel Perfect For"],
		action = true,
		placeholder = CHOOSE,
		depends = "uiScale",
		blocked = Blocked,
		options = resolutions,
		set = function(key)
			for _, preset in ipairs(UIScale.PRESETS) do
				if preset.key == key then
					UIScale:SetScale(UIScale.PixelPerfect(preset.height))
				end
			end
		end,
	})

	scale:Slider({
		id = "gameMenuScale",
		label = L["Game Menu Scale"],
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
