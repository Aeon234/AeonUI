local AUI = select(2, ...)

local L = AUI.L
local lib = LibStub("LibAeonSettings-1.0")
local Options = AUI.UnitFrameOptions

---The All Frames page: what every frame follows until its own page changes it.
---@class AUISettingsAllFrames
---@field PRECISION_LABELS table<string, string>
local SettingsAllFrames = {
	PRECISION_LABELS = {
		default = L["Short"],
		decimal = L["Short With One Decimal"],
	},
}
AUI.SettingsAllFrames = SettingsAllFrames

---@return table[] options AeonUI's border styles, then LibSharedMedia's borders under a heading
function SettingsAllFrames.BorderOptions()
	local options = {
		{ value = "FOREVER_MINIMAL", text = L["Forever Minimal"] },
		{ value = "FOREVER", text = L["Forever"] },
		{ value = "SLATE", text = L["Slate"] },
		{ value = "THIN_LINE", text = L["Thin Line"] },
		{ value = "NONE", text = NONE },
	}
	local names = AUI.Media:BorderNames()

	if #names > 0 then
		options[#options + 1] = { title = true, text = L["Shared Media"] }

		for _, name in ipairs(names) do
			options[#options + 1] = { value = name, text = name }
		end
	end

	return options
end

---@param style string a border style
---@return boolean thick the style has a thickness
function SettingsAllFrames:HasThickness(style)
	return style ~= "THIN_LINE" and style ~= "NONE"
end

---@param style string a border style
---@return boolean tinted the style is drawn in the Border Color
function SettingsAllFrames:HasTint(style)
	return style ~= "THIN_LINE" and style ~= "NONE" and style ~= "FOREVER"
end

---@param style string a border style
---@return boolean colored hovering draws the style in the Hover Color, rather than lightening it
function SettingsAllFrames:HasHoverColor(style)
	return style ~= "NONE" and not Options.LIGHTENED[style]
end

---@param id string
---@param label string
---@param field string the path under the shared settings
---@param extra table? more of the setting's fields
---@return table setting
local function Field(id, label, field, extra)
	local setting = extra or {}
	local path = Options.ALL .. field

	setting.id, setting.label, setting.path = id, label, path
	setting.default, setting.resettable = AUI.Settings:Default(path), true

	return setting
end

---@param window table
function SettingsAllFrames:Declare(window)
	local page = window:Page("unitFramesAll", {
		title = L["All Frames"],
		under = "unitFramesHeader",
		icon = AUI.Media.sidebar.allFrames,
		iconTint = true,
	})

	if not page then
		return
	end

	local bars = page:Section("allFramesBars", L["Bars"])

	bars:Dropdown(Field("texture", L["Bar Texture"], "bars.texture", { picker = "texture" }))
	bars:Color(Field("background", L["Background"], "bars.background", { hasOpacity = true }))

	local function Style()
		return AUI.Profile:Get(Options.ALL .. "bars.borderStyle")
	end

	bars:Dropdown(Field("borderStyle", L["Border Style"], "bars.borderStyle", {
		options = self.BorderOptions,
		titleCase = false,
	}))
	bars:Color(Field("borderColor", L["Border Color"], "bars.borderColor", {
		show = function()
			return self:HasTint(Style())
		end,
	}))
	bars:Color(Field("lineColor", L["Border Color"], "bars.lineColor", {
		hasOpacity = true,
		show = function()
			return Style() == "THIN_LINE"
		end,
	}))
	bars:Slider(Field("borderThickness", L["Border Thickness"], "bars.borderThickness", {
		min = Options.MIN_BORDER_THICKNESS,
		max = Options.MAX_BORDER_THICKNESS,
		step = 10,
		format = "percent",
		show = function()
			return self:HasThickness(Style())
		end,
	}))
	bars:Checkbox(Field("hover", L["Highlight on Hover"], "bars.hover", {
		show = function()
			return Style() ~= "NONE"
		end,
	}))
	bars:Color(Field("hoverColor", L["Hover Color"], "bars.hoverColor", {
		depends = "hover",
		show = function()
			return self:HasHoverColor(Style())
		end,
	}))

	local text = page:Section("allFramesText", L["Text"])

	text:Dropdown(Field("font", L["Font"], "text.font", { picker = "font" }))
	text:Slider(Field("size", L["Size"], "text.size", { min = Options.MIN_TEXT, max = Options.MAX_TEXT, step = 1 }))
	text:Dropdown(Field("outline", L["Outline"], "text.outline", { options = lib.OUTLINES }))
	text:Color(Field("color", COLOR, "text.color"))

	local numbers = page:Section("allFramesNumbers", L["Numbers"])
	local precision = {}

	for index, value in ipairs(Options.PRECISIONS) do
		precision[index] = { value = value, text = self.PRECISION_LABELS[value] }
	end

	numbers:Dropdown(Field("precision", L["Number Format"], "numbers.precision", { options = precision }))
	numbers:Slider(Field("percentDecimals", L["Percent Decimals"], "numbers.percentDecimals", {
		min = 0,
		max = 1,
		step = 1,
	}))
end

AUI.Modules:Register({
	group = "unitFrames",
	page = SettingsAllFrames,
	start = function()
		AUI.Frames:Start()
	end,
	reloadNeeded = function()
		return AUI.Frames:ReloadNeeded()
	end,
})
