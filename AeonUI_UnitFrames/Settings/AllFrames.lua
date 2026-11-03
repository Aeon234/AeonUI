local AUI = select(2, ...)

local L = AUI.L
local lib = LibStub("LibAeonSettings-1.0")
local Options = AUI.UnitFrameOptions

---The All Frames page: what every frame follows until its own page changes it.
---@class AUISettingsAllFrames
---@field PRECISION_LABELS table<string, string>
---@field HEALTH_MODE_LABELS table<string, string>
---@field HEALTH_BACKGROUND_LABELS table<string, string>
---@field ORIENTATION_LABELS table<string, string>
---@field CORNER_LABELS table<string, string>
---@field POWER_MODE_LABELS table<string, string>
---@field POWER_BACKGROUND_LABELS table<string, string>
local SettingsAllFrames = {
	PRECISION_LABELS = {
		default = L["Short"],
		decimal = L["Short With One Decimal"],
	},
	HEALTH_MODE_LABELS = {
		classReaction = L["Class / Reaction"],
		custom = L["Custom"],
		classic = L["Classic"],
		stops = L["Custom Stops"],
		classFade = L["Class Fade"],
	},
	HEALTH_BACKGROUND_LABELS = {
		custom = L["Bar Background"],
		classReaction = L["Class / Reaction"],
	},
	ORIENTATION_LABELS = {
		HORIZONTAL = L["Horizontal"],
		VERTICAL = L["Vertical"],
	},
	POWER_MODE_LABELS = {
		type = L["Power Type"],
		class = CLASS,
		custom = L["Custom"],
	},
	POWER_BACKGROUND_LABELS = {
		custom = L["Bar Background"],
		power = L["Power Color"],
	},
	CORNER_LABELS = {
		BOTTOMRIGHT = L["Bottom Right"],
		BOTTOMLEFT = L["Bottom Left"],
		TOPRIGHT = L["Top Right"],
		TOPLEFT = L["Top Left"],
		CENTER = L["Center"],
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

---@param values string[]
---@param labels table<string, string>
---@return table[] options
local function ChoiceOptions(values, labels)
	local options = {}

	for index, value in ipairs(values) do
		options[index] = { value = value, text = labels[value] }
	end

	return options
end

---Declares the health color rows All Frames and a frame's Health card share.
---@param card table
---@param make fun(id: string, label: string, field: string, extra: table?): table builds a setting for a field under `health.`
---@param read fun(field: string): any the current value of a field under `health.`
---@param group fun(name: string, label: string?, summary: (fun(): string)?): string? the detail row a named group of settings goes in, nil for the card itself
function SettingsAllFrames:DeclareHealthColors(card, make, read, group)
	local function FillBlocked()
		if read("dark") then
			return L["Dark Mode sets the fill."]
		end
	end

	local function OnOff(field)
		return function()
			return read(field) and L["On"] or OFF
		end
	end

	local function ModeColor(id, label, field, modes, details)
		card:Color(make(id, label, field, {
			details = details,
			show = function()
				return modes[read("mode")] == true
			end,
			blocked = FillBlocked,
		}))
	end

	card:Dropdown(make("healthMode", L["Health Color"], "mode", {
		options = ChoiceOptions(Options.HEALTH_MODES, self.HEALTH_MODE_LABELS),
		blocked = FillBlocked,
	}))

	local colors = group("colors")

	ModeColor("healthCustom", L["Custom Color"], "color", { custom = true }, colors)
	ModeColor("healthFull", L["Full Health Color"], "stops.full", { stops = true }, colors)
	ModeColor("healthHalf", L["Half Health Color"], "stops.half", { stops = true, classFade = true }, colors)
	ModeColor("healthEmpty", L["Empty Health Color"], "stops.empty", { stops = true, classFade = true }, colors)

	local background = group("background", L["Background"], function()
		return self.HEALTH_BACKGROUND_LABELS[read("background")]
	end)

	card:Dropdown(make("healthBackground", L["Background Color"], "background", {
		details = background,
		options = ChoiceOptions(Options.HEALTH_BACKGROUNDS, self.HEALTH_BACKGROUND_LABELS),
	}))
	card:Slider(make("healthFillAlpha", L["Fill Opacity"], "fillAlpha", {
		details = background,
		min = 0,
		max = 100,
		step = 5,
		format = "percent",
	}))

	local gradient = group("gradient", L["Gradient"], OnOff("gradient"))

	card:Checkbox(make("healthGradient", L["Gradient"], "gradient", { details = gradient }))
	card:Dropdown(make("healthGradientDirection", L["Gradient Direction"], "gradientDirection", {
		details = gradient,
		depends = "healthGradient",
		options = ChoiceOptions(Options.ORIENTATIONS, self.ORIENTATION_LABELS),
	}))
	card:Color(make("healthGradientColor", L["Gradient End Color"], "gradientColor", {
		details = gradient,
		depends = "healthGradient",
		hasOpacity = true,
	}))

	local dark = group("dark", L["Dark Mode"], OnOff("dark"))

	card:Checkbox(make("healthDark", L["Dark Mode"], "dark", { details = dark }))
	card:Color(make("healthDarkFill", L["Dark Fill"], "darkFill", {
		details = dark,
		depends = "healthDark",
		hasOpacity = true,
	}))
	card:Color(make("healthDarkBackground", L["Dark Background"], "darkBackground", {
		details = dark,
		depends = "healthDark",
		hasOpacity = true,
	}))

	local dead = group("dead", L["Dead Background"], OnOff("deadBackground"))

	card:Checkbox(make("healthDead", L["Dead Background"], "deadBackground", { details = dead }))
	card:Color(make("healthDeadColor", L["Dead Background Color"], "deadColor", {
		details = dead,
		depends = "healthDead",
		hasOpacity = true,
	}))
end

---Declares the power color rows All Frames and a power bar's card share.
---@param card table
---@param make fun(id: string, label: string, field: string, extra: table?): table builds a setting for a field under `powerColors.`
---@param read fun(field: string): any the current value of a field under `powerColors.`
---@param group fun(name: string, label: string?, summary: (fun(): string)?): string? the detail row a named group goes in, nil for the card itself
function SettingsAllFrames:DeclarePowerColors(card, make, read, group)
	card:Dropdown(make("powerMode", L["Power Color"], "mode", {
		options = ChoiceOptions(Options.POWER_MODES, self.POWER_MODE_LABELS),
	}))

	local colors = group("colors")

	card:Color(make("powerCustom", L["Custom Color"], "color", {
		details = colors,
		show = function()
			return read("mode") == "custom"
		end,
	}))

	local background = group("background", L["Background"], function()
		return self.POWER_BACKGROUND_LABELS[read("background")]
	end)

	card:Dropdown(make("powerBackground", L["Background Color"], "background", {
		details = background,
		options = ChoiceOptions(Options.POWER_BACKGROUNDS, self.POWER_BACKGROUND_LABELS),
	}))
	card:Slider(make("powerFillAlpha", L["Fill Opacity"], "fillAlpha", {
		details = background,
		min = 0,
		max = 100,
		step = 5,
		format = "percent",
	}))

	local gradient = group("gradient", L["Gradient"], function()
		return read("gradient") and L["On"] or OFF
	end)

	card:Checkbox(make("powerGradient", L["Gradient"], "gradient", { details = gradient }))
	card:Dropdown(make("powerGradientDirection", L["Gradient Direction"], "gradientDirection", {
		details = gradient,
		depends = "powerGradient",
		options = ChoiceOptions(Options.ORIENTATIONS, self.ORIENTATION_LABELS),
	}))
	card:Color(make("powerGradientColor", L["Gradient End Color"], "gradientColor", {
		details = gradient,
		depends = "powerGradient",
		hasOpacity = true,
	}))
end

---The power type colors every bar shares, each only where the client has it and Blizzard's until set.
---@param card table
---@param make fun(id: string, label: string, field: string, extra: table?): table
---@param read fun(field: string): any
---@param group fun(name: string, label: string?, summary: (fun(): string)?): string?
function SettingsAllFrames:DeclarePowerPalette(card, make, read, group)
	local palette = group("palette", L["Palette"], function()
		local changed = 0

		for _, token in ipairs(Options.POWER_TOKENS) do
			if read("palette." .. token) then
				changed = changed + 1
			end
		end

		return changed > 0 and L["%d changed"]:format(changed) or DEFAULT
	end)

	for _, token in ipairs(Options.POWER_TOKENS) do
		local blizzard = AUI.PowerColor:Blizzard(token)

		if blizzard then
			local field = "palette." .. token
			local setting = make("power" .. token, _G[token] or token, field, {
				details = palette,
				get = function()
					return read(field) or blizzard
				end,
			})

			setting.default = blizzard
			card:Color(setting)
		end
	end
end

---The health colors every frame shares and none overrides: reactions, tapped and disconnected.
---@param card table
---@param make fun(id: string, label: string, field: string, extra: table?): table
---@param read fun(field: string): any
---@param group fun(name: string, label: string?, summary: (fun(): string)?): string?
function SettingsAllFrames:DeclareHealthStates(card, make, read, group)
	local names = { "hostile", "neutral", "friendly" }
	local reactions = group("reactions", L["Reaction Colors"], function()
		local changed = 0

		for _, name in ipairs(names) do
			if read("reaction." .. name) then
				changed = changed + 1
			end
		end

		return changed > 0 and L["%d changed"]:format(changed) or DEFAULT
	end)

	for _, reaction in ipairs({
		{ name = "hostile", label = FACTION_STANDING_LABEL2, level = 2 },
		{ name = "neutral", label = FACTION_STANDING_LABEL4, level = 4 },
		{ name = "friendly", label = FACTION_STANDING_LABEL5, level = 5 },
	}) do
		local field = "reaction." .. reaction.name
		local color = AUI.oUF.colors.reaction[reaction.level]
		local blizzard = { r = color.r, g = color.g, b = color.b }
		local setting = make("reaction" .. reaction.name, reaction.label, field, {
			details = reactions,
			get = function()
				return read(field) or blizzard
			end,
		})

		setting.default = blizzard
		card:Color(setting)
	end

	local states = group("states", L["Tapped and Disconnected"], function()
		return (read("tapped") or read("disconnected")) and L["On"] or OFF
	end)

	card:Checkbox(make("healthTapped", L["Tapped"], "tapped", { details = states }))
	card:Color(make("healthTappedColor", L["Tapped Color"], "tappedColor", {
		details = states,
		depends = "healthTapped",
	}))
	card:Checkbox(make("healthDisconnected", L["Disconnected"], "disconnected", { details = states }))
	card:Color(make("healthDisconnectedColor", L["Disconnected Color"], "disconnectedColor", {
		details = states,
		depends = "healthDisconnected",
	}))
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

	local health = page:Section("allFramesHealth", L["Health Colors"])

	local function HealthField(id, label, field, extra)
		return Field(id, label, "health." .. field, extra)
	end

	local function HealthRead(field)
		return AUI.Profile:Get(Options.ALL .. "health." .. field)
	end

	local function HealthGroup(name, label, summary)
		if label then
			local id = "allFramesHealth" .. name

			health:Details({ id = id, label = label, summary = summary })

			return id
		end
	end

	self:DeclareHealthColors(health, HealthField, HealthRead, HealthGroup)
	self:DeclareHealthStates(health, HealthField, HealthRead, HealthGroup)

	local power = page:Section("allFramesPower", L["Power Colors"])

	local function PowerField(id, label, field, extra)
		return Field(id, label, "powerColors." .. field, extra)
	end

	local function PowerRead(field)
		return AUI.Profile:Get(Options.ALL .. "powerColors." .. field)
	end

	local function PowerGroup(name, label, summary)
		if label then
			local id = "allFramesPower" .. name

			power:Details({ id = id, label = label, summary = summary })

			return id
		end
	end

	self:DeclarePowerColors(power, PowerField, PowerRead, PowerGroup)
	self:DeclarePowerPalette(power, PowerField, PowerRead, PowerGroup)

	local overlays = page:Section("allFramesAbsorbs", L["Absorbs and Heals"])
	local kinds = {
		{ kind = "absorb", color = L["Shield Color"], texture = L["Shield Texture"] },
		{ kind = "healAbsorb", color = L["Heal Absorb Color"], texture = L["Heal Absorb Texture"] },
		{ kind = "healPrediction", color = L["Heal Prediction Color"], texture = L["Heal Prediction Texture"] },
	}

	for _, entry in ipairs(kinds) do
		overlays:Color(Field(entry.kind .. "Color", entry.color, "overlays.colors." .. entry.kind, { hasOpacity = true }))
	end

	overlays:Details({
		id = "allFramesAbsorbTextures",
		label = L["Textures"],
		summary = function()
			local changed = 0

			for _, kind in ipairs(Options.OVERLAY_KINDS) do
				if AUI.Profile:IsCustom(Options.ALL .. "overlays.textures." .. kind) then
					changed = changed + 1
				end
			end

			return changed > 0 and L["%d changed"]:format(changed) or DEFAULT
		end,
	})

	for _, entry in ipairs(kinds) do
		overlays:Dropdown(Field(entry.kind .. "Texture", entry.texture, "overlays.textures." .. entry.kind, {
			details = "allFramesAbsorbTextures",
			picker = "texture",
		}))
	end

	local auras = page:Section("allFramesAuras", AURAS)

	local function AuraRead(field)
		return AUI.Profile:Get(Options.ALL .. "auras." .. field)
	end

	auras:Checkbox(Field("auraSwipe", L["Cooldown Swipe"], "auras.swipe"))
	auras:Checkbox(Field("auraBorder", L["Aura Borders"], "auras.border"))
	auras:Details({
		id = "allFramesAuraDuration",
		label = L["Duration Text"],
		summary = function()
			return AuraRead("duration") and L["On"] or OFF
		end,
	})
	auras:Checkbox(Field("auraDuration", L["Show Duration"], "auras.duration", { details = "allFramesAuraDuration" }))
	auras:Slider(Field("auraDurationSize", L["Duration Size"], "auras.durationSize", {
		details = "allFramesAuraDuration",
		depends = "auraDuration",
		min = Options.MIN_AURA_TEXT,
		max = Options.MAX_AURA_TEXT,
		step = 1,
	}))
	auras:Details({
		id = "allFramesAuraStack",
		label = L["Stack Text"],
		summary = function()
			return self.CORNER_LABELS[AuraRead("countCorner")]
		end,
	})
	auras:Dropdown(Field("auraCountCorner", L["Stack Position"], "auras.countCorner", {
		details = "allFramesAuraStack",
		options = ChoiceOptions(Options.AURA_CORNERS, self.CORNER_LABELS),
	}))
	auras:Slider(Field("auraCountSize", L["Stack Size"], "auras.countSize", {
		details = "allFramesAuraStack",
		min = Options.MIN_AURA_TEXT,
		max = Options.MAX_AURA_TEXT,
		step = 1,
	}))

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
