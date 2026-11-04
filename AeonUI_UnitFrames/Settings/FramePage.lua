local AUI = select(2, ...)

local L = AUI.L
local lib = LibStub("LibAeonSettings-1.0")
local Options = AUI.UnitFrameOptions

local PREVIEW_HEIGHT = 84

local TITLES = {
	player = PLAYER,
	target = TARGET,
}

local SWITCHES = {
	player = L["Show Player Frame"],
	target = L["Show Target Frame"],
}

local ICONS = {
	player = "unitPlayer",
	target = "unitTarget",
}

-- The switch on a frame's power card.
local POWER_SWITCH = "powerEnabled"

local CONTENT_LABELS = {
	none = NONE,
	name = L["Name"],
	level = L["Level"],
	levelName = L["Level + Name"],
	health = L["Health"],
	healthPercent = L["Health %"],
	healthAndPercent = L["Health + %"],
	missingHealth = L["Missing Health"],
	absorb = L["Absorb"],
	healAbsorb = L["Heal Absorb"],
	power = L["Power"],
	powerPercent = L["Power %"],
}

local SEPARATOR_LABELS = {
	bar = "|",
	dash = "-",
	slash = "/",
	space = L["Space"],
	parentheses = "( )",
	brackets = "[ ]",
	bullet = "•",
}

local ANCHOR_LABELS = {
	TOPLEFT = L["Top Left"],
	TOP = L["Top"],
	TOPRIGHT = L["Top Right"],
	LEFT = L["Left"],
	CENTER = L["Center"],
	RIGHT = L["Right"],
	BOTTOMLEFT = L["Bottom Left"],
	BOTTOM = L["Bottom"],
	BOTTOMRIGHT = L["Bottom Right"],
}

local PLACEMENT_LABELS = {
	inside = L["Inside"],
	edge = L["On Edge"],
	outside = L["Outside"],
}

local OVERLAY_POSITION_LABELS = {
	attach = L["Attach"],
	TOPLEFT = L["Top Left"],
	TOPRIGHT = L["Top Right"],
	BOTTOMLEFT = L["Bottom Left"],
	BOTTOMRIGHT = L["Bottom Right"],
	LEFT = L["Left"],
	RIGHT = L["Right"],
}

local OVERSHIELD_LABELS = {
	never = L["Never"],
	always = L["Always"],
	fromLeft = L["From Left"],
}

local AURA_ANCHOR_LABELS = {
	aboveLeft = L["Above Left"],
	aboveRight = L["Above Right"],
	belowLeft = L["Below Left"],
	belowRight = L["Below Right"],
	left = L["Left Side"],
	right = L["Right Side"],
}

local AURA_GROWTH_LABELS = {
	right = L["Right"],
	left = L["Left"],
}

-- Category names, shared by the filter modes and Hide Categories.
local AURA_CATEGORY_LABELS = {
	important = L["Important"],
	bigDefensive = L["Big Defensive"],
	externalDefensive = L["External Defensive"],
	raidInCombat = L["Raid In Combat"],
	crowdControl = L["Crowd Control"],
	dispellableByYou = L["Dispellable by You"],
	anyDispellable = L["Any Dispellable"],
	yours = L["Yours"],
	notYours = L["Not Yours"],
	boss = BOSS,
	role = ROLE,
	stealable = L["Stealable"],
	classCanApply = L["Your Class Can Apply"],
	magic = L["Magic"],
	curse = L["Curse"],
	disease = L["Disease"],
	poison = L["Poison"],
}

local AURA_FILTER_LABELS = {
	all = ALL,
	own = L["Yours"],
	importantOwn = L["Important and Yours"],
	hasDuration = L["Has Duration"],
	tracked = L["Tracked Spells"],
	categories = L["Categories"],
}

for value, label in pairs(AURA_CATEGORY_LABELS) do
	AURA_FILTER_LABELS[value] = AURA_FILTER_LABELS[value] or label
end

local BUFF_CATEGORY_LABELS = {
	defensives = L["Defensives"],
	activeMitigation = L["Active Mitigation"],
	raidCooldowns = L["Raid Cooldowns"],
	externals = L["Externals"],
	coreHealing = L["Core Healing"],
	lesserHealing = L["Lesser Healing"],
	support = L["Support"],
	offensive = L["Offensive Cooldowns"],
	movement = L["Movement"],
	utility = L["Utility"],
	consumables = L["Consumables"],
}

local LIST_CASTER_LABELS = {
	anyone = L["Anyone's"],
	yours = L["Yours"],
}

local AURA_SORT_LABELS = {
	stable = L["Stable Order"],
	shortest = L["Shortest First"],
	yours = L["Yours First"],
	blizzard = L["Blizzard Debuff Order"],
	importance = L["Importance"],
	name = L["Name"],
}

local PORTRAIT_MODE_LABELS = {
	["2d"] = L["2D"],
	["3d"] = L["3D"],
	class = L["Class Icon"],
}

local PORTRAIT_STYLE_LABELS = {
	attached = L["Attached"],
	detached = L["Detached"],
}

local SIDE_LABELS = {
	LEFT = L["Left"],
	RIGHT = L["Right"],
}

local INDICATOR_LABELS = {
	raid = L["Raid Marker"],
	resting = L["Resting"],
	combat = COMBAT,
	leader = L["Leader and Assistant"],
	pvp = PVP,
	classification = L["Classification"],
}

local RESTING_ICON_LABELS = {
	animated = L["Animated"],
	still = L["Resting Art, Still"],
	classic = L["Classic"],
	portrait = L["Portrait"],
}

---@return table[] options the resting icons this client has: by name, or the art itself
local function RestingIconOptions()
	local options = {}

	for _, icon in ipairs(Options.RESTING_ICONS) do
		if AUI.Indicators:HasRestingIcon(icon) then
			local file = AUI.Indicators:RestingFile(icon)

			options[#options + 1] = { value = icon, text = file and ("|T%s:16:16|t"):format(file) or RESTING_ICON_LABELS[icon] }
		end
	end

	return options
end

local COLOR_MODE_LABELS = {
	custom = L["Custom"],
	class = L["Class / Reaction"],
	power = L["Power"],
	difficulty = L["Level Difficulty"],
}

local NAME_FORMAT_LABELS = {
	first = L["First Name"],
	full = L["Full Name"],
}

-- Contents that join two values, and so use the separator.
local COMBINED = { levelName = true, healthAndPercent = true }

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

---A frame's settings page: its switch, a sample as its preview, then the cards. One object per frame, built from the
---frame table.
---@class AUISettingsFramePage
---@field spec AUIFrameSpec
local FramePage = {}
FramePage.__index = FramePage
AUI.SettingsFramePage = FramePage
FramePage.ChoiceOptions = ChoiceOptions
FramePage.TITLES = TITLES

---@param spec AUIFrameSpec
---@param prefix string? starts its Bars settings' ids, where a page holds two such cards
---@return AUISettingsFramePage page
function FramePage:New(spec, prefix)
	return setmetatable({ spec = spec, prefix = prefix or "" }, self)
end

---@param id string
---@param label string
---@param path string
---@param extra table? more of the setting's fields
---@return table setting
local function Field(id, label, path, extra)
	local setting = extra or {}

	setting.id, setting.label, setting.path, setting.default = id, label, path, AUI.Settings:Default(path)

	return setting
end

FramePage.Field = Field

---A setting that follows a shared one until changed.
---@param id string
---@param label string
---@param path string
---@param shared string the setting it follows
---@param from string what the setting says it follows
---@param extra table? more of the setting's fields
---@return table setting
local function Inherited(id, label, path, shared, from, extra)
	local setting = Field(id, label, path, extra)

	setting.default = AUI.Settings:Default(shared)
	setting.inherits = {
		from = from,
		get = function()
			return AUI.Profile:Get(shared)
		end,
	}

	return setting
end

---@param paths string[]
---@return string summary "All Frames", or how many of the settings hold their own value
local function InheritSummary(paths)
	local changed = 0

	for _, path in ipairs(paths) do
		if AUI.Profile:IsCustom(path) then
			changed = changed + 1
		end
	end

	return changed > 0 and L["%d changed"]:format(changed) or L["All Frames"]
end

---@return fun(id: string, label: string, field: string, extra: table?): table make a power color setting that follows All Frames
function FramePage:PowerMaker()
	local key = self.spec.key

	return function(id, label, field, extra)
		return Inherited(id, label, Options:Path(key, "powerColors." .. field), Options.ALL .. "powerColors." .. field,
			L["All Frames"], extra)
	end
end

---@param card table
---@param depends string? the switch the row depends on
---@return fun(): string group the one Colors row every group of power colors goes in, declared when first asked for
function FramePage:PowerGroup(card, depends)
	local key = self.spec.key
	local details = key .. "PowerColors"
	local declared = false

	return function()
		if not declared then
			declared = true
			card:Details({
				id = details,
				label = L["Colors"],
				depends = depends,
				summary = function()
					local paths = {}

					for _, field in ipairs(Options.POWER_LOOK) do
						if field ~= "mode" then
							paths[#paths + 1] = Options:Path(key, "powerColors." .. field)
						end
					end

					return InheritSummary(paths)
				end,
			})
		end

		return details
	end
end

---@param page table
function FramePage:DeclareSize(page)
	local key = self.spec.key
	local card = page:Section(key .. "Size", L["Size"])

	AUI.SettingsFrameCopy:LinkFrame(card, page, key, "size")

	card:Slider(Field("width", L["Width"], Options:Path(key, "width"), {
		min = Options.MIN_WIDTH,
		max = Options.MAX_WIDTH,
		step = 1,
	}))
	card:Slider(Field("height", L["Height"], Options:Path(key, "height"), {
		min = Options.MIN_HEIGHT,
		max = Options.MAX_HEIGHT,
		step = 1,
	}))
	card:Checkbox(Field("reverse", L["Reverse Fill"], Options:Path(key, "reverse")))
end

---The frame's border and bars, which follow All Frames until changed.
---@param page table
---@param title string? the card's title, when not Bars
---@return table card
function FramePage:DeclareBars(page, title)
	local key = self.spec.key
	local AllFrames = AUI.SettingsAllFrames
	local card = page:Section(key .. "Bars", title or L["Bars"])

	AUI.SettingsFrameCopy:LinkFrame(card, page, key, "bars")
	local details = key .. "BarsLook"
	local from = L["All Frames"]
	local look = { "texture", "background", "borderColor", "lineColor", "borderThickness" }
	local hover = not self.spec.passive

	local function Own(field)
		return Options:Path(key, "bars." .. field)
	end

	local function Shared(field)
		return Options.ALL .. "bars." .. field
	end

	local function Style()
		return AUI.Profile:Get(Own("borderStyle"))
	end

	local prefix = self.prefix or ""

	card:Dropdown(Inherited(prefix .. "borderStyle", L["Border Style"], Own("borderStyle"), Shared("borderStyle"), from, {
		options = AllFrames.BorderOptions,
		titleCase = false,
	}))
	card:Details({
		id = details,
		label = L["Look"],
		summary = function()
			local paths = {}

			for index, field in ipairs(look) do
				paths[index] = Own(field)
			end

			if hover then
				paths[#paths + 1] = Own("hover")
				paths[#paths + 1] = Own("hoverColor")
			end

			return InheritSummary(paths)
		end,
	})
	card:Dropdown(Inherited(prefix .. "barTexture", L["Bar Texture"], Own("texture"), Shared("texture"), from, {
		details = details,
		picker = "texture",
	}))
	card:Color(Inherited(prefix .. "barBackground", L["Background"], Own("background"), Shared("background"), from, {
		details = details,
		hasOpacity = true,
	}))
	card:Color(Inherited(prefix .. "borderColor", L["Border Color"], Own("borderColor"), Shared("borderColor"), from, {
		details = details,
		show = function()
			return AllFrames:HasTint(Style())
		end,
	}))
	card:Color(Inherited(prefix .. "lineColor", L["Border Color"], Own("lineColor"), Shared("lineColor"), from, {
		details = details,
		hasOpacity = true,
		show = function()
			return Style() == "THIN_LINE"
		end,
	}))
	card:Slider(Inherited(prefix .. "borderThickness", L["Border Thickness"], Own("borderThickness"), Shared("borderThickness"),
		from, {
			details = details,
			min = Options.MIN_BORDER_THICKNESS,
			max = Options.MAX_BORDER_THICKNESS,
			step = 10,
			format = "percent",
			show = function()
				return AllFrames:HasThickness(Style())
			end,
		}))

	if not hover then
		return card
	end

	card:Checkbox(Inherited("hover", L["Highlight on Hover"], Own("hover"), Shared("hover"), from, {
		details = details,
		show = function()
			return Style() ~= "NONE"
		end,
	}))
	card:Color(Inherited("hoverColor", L["Hover Color"], Own("hoverColor"), Shared("hoverColor"), from, {
		details = details,
		depends = "hover",
		show = function()
			return AllFrames:HasHoverColor(Style())
		end,
	}))

	return card
end

---The power bar under the frame's health, off by default, with its colors following All Frames until changed.
---@param page table
function FramePage:DeclarePower(page)
	local key = self.spec.key
	local card = page:Section(key .. "Power", L["Power"])

	AUI.SettingsFrameCopy:LinkFrame(card, page, key, "power")
	local make = self:PowerMaker()

	card:Toggle(Field(POWER_SWITCH, L["Show Power Bar"], Options:Path(key, "power.enabled")))
	card:Slider(Field("powerHeight", L["Height"], Options:Path(key, "power.height"), {
		depends = POWER_SWITCH,
		min = Options.MIN_POWER_HEIGHT,
		max = Options.MAX_ATTACHED_POWER,
		step = 1,
	}))
	AUI.SettingsAllFrames:DeclarePowerColors(card, function(id, label, field, extra)
		extra = extra or {}
		extra.depends = extra.depends or (not extra.details and POWER_SWITCH) or nil

		return make(id, label, field, extra)
	end, function(field)
		return AUI.Profile:Get(Options:Path(key, "powerColors." .. field))
	end, self:PowerGroup(card, POWER_SWITCH))
end

---The frame's cast bar: its own size and place, and its look, which follows All Frames and the frame's border.
---@param page table
function FramePage:DeclareCastBar(page)
	local key = self.spec.key
	local AllFrames = AUI.SettingsAllFrames
	local CastOptions = AUI.CastBarOptions
	local base = AUI.UnitCastBar:Base(key)
	local card = page:Section(key .. "CastBar", L["Cast Bar"])

	AUI.SettingsFrameCopy:LinkFrame(card, page, key, "castBar")
	local position, look = "castPosition", "castLook"

	local function Style()
		return AUI.Profile:Get(base .. "bars.borderStyle")
	end

	card:Toggle(Field("castEnabled", L["Show Cast Bar"], base .. "enabled"))
	card:Checkbox(Field("castMatch", L["Match Frame Width"], base .. "matchWidth", { depends = "castEnabled" }))
	card:Slider(Field("castWidth", L["Width"], base .. "width", {
		depends = "castEnabled",
		min = CastOptions.MIN_WIDTH,
		max = CastOptions.MAX_WIDTH,
		step = 1,
		show = function()
			return AUI.Profile:Get(base .. "matchWidth") ~= true
		end,
	}))
	card:Slider(Field("castHeight", L["Height"], base .. "height", {
		depends = "castEnabled",
		min = CastOptions.MIN_HEIGHT,
		max = CastOptions.MAX_HEIGHT,
		step = 1,
	}))
	card:Checkbox(Field("castIcon", L["Spell Icon"], base .. "icon", { depends = "castEnabled" }))
	card:Details({ id = position, label = L["Position"], depends = "castEnabled" })
	card:Dropdown(Field("castIconSide", L["Icon Side"], base .. "iconSide", {
		details = position,
		options = ChoiceOptions(CastOptions.SIDES, AllFrames.CAST_SIDE_LABELS),
	}))
	card:Slider(Field("castX", L["X Offset"], base .. "x", {
		details = position,
		min = -CastOptions.MAX_OFFSET,
		max = CastOptions.MAX_OFFSET,
		step = 1,
	}))
	card:Slider(Field("castY", L["Y Offset"], base .. "y", {
		details = position,
		min = -CastOptions.MAX_OFFSET,
		max = CastOptions.MAX_OFFSET,
		step = 1,
	}))
	card:Dropdown(Field("castStrata", L["Frame Strata"], base .. "strata", {
		details = position,
		options = ChoiceOptions(CastOptions.STRATAS, AllFrames.CAST_STRATA_LABELS),
	}))
	card:Checkbox(Field("castAlwaysShow", L["Always Show"], base .. "alwaysShow", { details = position }))
	card:Details({ id = look, label = L["Look"], depends = "castEnabled" })

	local from = TITLES[key] or key

	local function Border(field)
		return base .. "bars." .. field, Options:Path(key, "bars." .. field)
	end

	local styleOwn, styleShared = Border("borderStyle")

	card:Dropdown(Inherited("castBorderStyle", L["Border Style"], styleOwn, styleShared, from, {
		details = look,
		options = AllFrames.BorderOptions,
		titleCase = false,
	}))

	local colorOwn, colorShared = Border("borderColor")

	card:Color(Inherited("castBorderColor", L["Border Color"], colorOwn, colorShared, from, {
		details = look,
		show = function()
			return AllFrames:HasTint(Style())
		end,
	}))

	local lineOwn, lineShared = Border("lineColor")

	card:Color(Inherited("castLineColor", L["Border Color"], lineOwn, lineShared, from, {
		details = look,
		hasOpacity = true,
		show = function()
			return Style() == "THIN_LINE"
		end,
	}))

	local thicknessOwn, thicknessShared = Border("borderThickness")

	card:Slider(Inherited("castBorderThickness", L["Border Thickness"], thicknessOwn, thicknessShared, from, {
		details = look,
		min = Options.MIN_BORDER_THICKNESS,
		max = Options.MAX_BORDER_THICKNESS,
		step = 10,
		format = "percent",
		show = function()
			return AllFrames:HasThickness(Style())
		end,
	}))
	AllFrames:DeclareCastLook(card, function(id, label, field, extra)
		return Inherited(id, label, base .. field, Options.ALL .. "castBars." .. field, L["All Frames"], extra)
	end, function()
		return look
	end)
end

---The frame's health color, with its other colors in one row; all follow All Frames until changed.
---@param page table
function FramePage:DeclareHealth(page)
	local key = self.spec.key
	local card = page:Section(key .. "Health", L["Health"])

	AUI.SettingsFrameCopy:LinkFrame(card, page, key, "health")
	local details = key .. "HealthColors"
	local declared = false

	local function Own(field)
		return Options:Path(key, "health." .. field)
	end

	local function Make(id, label, field, extra)
		return Inherited(id, label, Own(field), Options.ALL .. "health." .. field, L["All Frames"], extra)
	end

	local function Read(field)
		return AUI.Profile:Get(Own(field))
	end

	local function Group()
		if not declared then
			declared = true
			card:Details({
				id = details,
				label = L["Colors"],
				summary = function()
					local paths = {}

					for _, field in ipairs(Options.HEALTH_LOOK) do
						if field ~= "mode" then
							paths[#paths + 1] = Own(field)
						end
					end

					return InheritSummary(paths)
				end,
			})
		end

		return details
	end

	AUI.SettingsAllFrames:DeclareHealthColors(card, Make, Read, Group)

	if self.spec.overlays then
		self:DeclareOverlays(card)
	end
end

---One overlay's row, opening to what it shows and where.
---@param card table
---@param kind string
---@param label string
---@param show string the switch's label
---@param keywords string? other words search finds it by
---@return string details the row's id
---@return fun(field: string): string path the path of a field of the overlay
---@return fun(): boolean attached the overlay is in the Attach position
function FramePage:DeclareOverlay(card, kind, label, show, keywords)
	local key = self.spec.key
	local details = key .. kind .. "Details"

	local function Own(field)
		return Options:Path(key, "overlays." .. kind .. "." .. field)
	end

	card:Details({
		id = details,
		label = label,
		summary = function()
			if not AUI.Profile:Get(Own("enabled")) then
				return OFF
			end

			return OVERLAY_POSITION_LABELS[AUI.Profile:Get(Own("position"))]
		end,
	})
	card:Checkbox(Field(kind .. "Enabled", show, Own("enabled"), { details = details, keywords = keywords }))
	card:Dropdown(Field(kind .. "Position", L["Position"], Own("position"), {
		details = details,
		depends = kind .. "Enabled",
		options = ChoiceOptions(Options.OVERLAY_POSITIONS, OVERLAY_POSITION_LABELS),
	}))
	card:Dropdown(Inherited(kind .. "Texture", L["Texture"], Own("texture"), Options.ALL .. "overlays.textures." .. kind,
		L["All Frames"], {
			details = details,
			depends = kind .. "Enabled",
			picker = "texture",
		}))
	card:Checkbox(Field(kind .. "Match", L["Match Health Height"], Own("matchHeight"), {
		details = details,
		depends = kind .. "Enabled",
	}))
	card:Slider(Field(kind .. "Height", L["Height"], Own("height"), {
		details = details,
		depends = kind .. "Enabled",
		min = Options.MIN_OVERLAY_HEIGHT,
		max = Options.MAX_OVERLAY_HEIGHT,
		step = 1,
		show = function()
			return AUI.Profile:Get(Own("matchHeight")) ~= true
		end,
	}))

	return details, Own, function()
		return AUI.Profile:Get(Own("position")) == "attach"
	end
end

---The rows for shields, heal absorbs and heal prediction.
---@param card table
function FramePage:DeclareOverlays(card)
	local details, Own, Attached = self:DeclareOverlay(card, "absorb", L["Shields"], L["Show Shields"], L["Absorb"])

	card:Dropdown(Field("overshield", L["Show Overshield"], Own("overshield"), {
		details = details,
		depends = "absorbEnabled",
		description = L["The part of a shield larger than the missing health."],
		options = ChoiceOptions(Options.OVERSHIELDS, OVERSHIELD_LABELS),
		show = Attached,
	}))
	card:Checkbox(Field("shieldGlow", L["Blizzard Glow Line"], Own("glow"), {
		details = details,
		depends = "absorbEnabled",
		show = Attached,
	}))

	details, Own = self:DeclareOverlay(card, "healAbsorb", L["Heal Absorbs"], L["Show Heal Absorbs"])

	card:Slider(Field("healAbsorbBacking", L["Backing Opacity"], Own("backing"), {
		details = details,
		depends = "healAbsorbEnabled",
		description = L["Darkens the health under heal absorbs."],
		min = 0,
		max = 100,
		step = 5,
		format = "percent",
	}))

	details, Own = self:DeclareOverlay(card, "healPrediction", L["Heal Prediction"], L["Show Heal Prediction"])

	card:Slider(Field("overheal", L["Overheal"], Own("overheal"), {
		details = details,
		depends = "healPredictionEnabled",
		description = L["How far incoming heals can pass the end of the bar."],
		min = 0,
		max = Options.MAX_OVERHEAL,
		step = 1,
		format = "percent",
	}))
end

---The portrait's card: its switch, mode and side, then its placement in a row.
---@param page table
function FramePage:DeclarePortrait(page)
	local key = self.spec.key
	local card = page:Section(key .. "Portrait", L["Portrait"])

	AUI.SettingsFrameCopy:LinkFrame(card, page, key, "portrait")
	local details = key .. "PortraitPlacement"

	local function Own(field)
		return Options:Path(key, "portrait." .. field)
	end

	local function Detached()
		return AUI.Profile:Get(Own("style")) == "detached"
	end

	card:Toggle(Field("portraitEnabled", L["Show Portrait"], Own("enabled")))
	card:Dropdown(Field("portraitMode", L["Mode"], Own("mode"), {
		depends = "portraitEnabled",
		description = L["Class Icon shows a player's class; other units show their 2D portrait."],
		options = ChoiceOptions(Options.PORTRAIT_MODES, PORTRAIT_MODE_LABELS),
	}))
	card:Dropdown(Field("portraitSide", L["Side"], Own("side"), {
		depends = "portraitEnabled",
		options = ChoiceOptions(Options.PORTRAIT_SIDES, SIDE_LABELS),
	}))
	card:Details({
		id = details,
		label = L["Placement"],
		depends = "portraitEnabled",
		summary = function()
			return PORTRAIT_STYLE_LABELS[AUI.Profile:Get(Own("style"))]
		end,
	})
	card:Dropdown(Field("portraitStyle", L["Placement"], Own("style"), {
		details = details,
		options = ChoiceOptions(Options.PORTRAIT_STYLES, PORTRAIT_STYLE_LABELS),
	}))
	card:Slider(Field("portraitSize", L["Size"], Own("size"), {
		details = details,
		min = Options.MIN_PORTRAIT,
		max = Options.MAX_PORTRAIT,
		step = 1,
		show = Detached,
	}))
	card:Slider(Field("portraitX", L["X Offset"], Own("x"), {
		details = details,
		min = -Options.MAX_OFFSET,
		max = Options.MAX_OFFSET,
		step = 1,
		show = Detached,
	}))
	card:Slider(Field("portraitY", L["Y Offset"], Own("y"), {
		details = details,
		min = -Options.MAX_OFFSET,
		max = Options.MAX_OFFSET,
		step = 1,
		show = Detached,
	}))
end

---The rows a placed element shares: where it attaches and how far it moves from there.
---@param card table
---@param prefix string
---@param details string its row's id
---@param depends string its switch's id
---@param Own fun(field: string): string
local function DeclarePlacement(card, prefix, details, depends, Own)
	card:Dropdown(Field(prefix .. "Anchor", L["Anchor"], Own("anchor"), {
		details = details,
		depends = depends,
		options = ChoiceOptions(Options.ANCHORS, ANCHOR_LABELS),
	}))
	card:Dropdown(Field(prefix .. "Placement", L["Placement"], Own("placement"), {
		details = details,
		depends = depends,
		options = ChoiceOptions(Options.PLACEMENTS, PLACEMENT_LABELS),
	}))
	card:Slider(Field(prefix .. "X", L["X Offset"], Own("x"), {
		details = details,
		depends = depends,
		min = -Options.MAX_OFFSET,
		max = Options.MAX_OFFSET,
		step = 1,
	}))
	card:Slider(Field(prefix .. "Y", L["Y Offset"], Own("y"), {
		details = details,
		depends = depends,
		min = -Options.MAX_OFFSET,
		max = Options.MAX_OFFSET,
		step = 1,
	}))
end

---@param Own fun(field: string): string
---@return string summary "Off", or where it attaches
local function PlacementSummary(Own)
	if not AUI.Profile:Get(Own("enabled")) then
		return OFF
	end

	return ("%s, %s"):format(ANCHOR_LABELS[AUI.Profile:Get(Own("anchor"))],
		PLACEMENT_LABELS[AUI.Profile:Get(Own("placement"))])
end

---The indicators' card: a row for each, opening to its switch, size and place.
---@param page table
function FramePage:DeclareIndicators(page)
	local spec = self.spec
	local key = spec.key
	local card = page:Section(key .. "Indicators", L["Indicators"])

	AUI.SettingsFrameCopy:LinkFrame(card, page, key, "indicators")

	for _, indicator in ipairs(spec.indicators or {}) do
		local name = indicator.name
		local details = key .. name .. "Indicator"
		local show = name .. "Indicator"

		local function Own(field)
			return Options:Path(key, "indicators." .. name .. "." .. field)
		end

		card:Details({
			id = details,
			label = INDICATOR_LABELS[name],
			summary = function()
				return PlacementSummary(Own)
			end,
		})
		card:Checkbox(Field(show, SHOW, Own("enabled"), { details = details }))

		if name == "resting" then
			card:Dropdown(Field("restingIcon", L["Icon"], Own("icon"), {
				details = details,
				depends = show,
				titleCase = false,
				options = RestingIconOptions,
			}))
		end

		card:Slider(Field(name .. "Size", L["Size"], Own("size"), {
			details = details,
			depends = show,
			min = Options.MIN_INDICATOR,
			max = Options.MAX_INDICATOR,
			step = 1,
		}))
		DeclarePlacement(card, name, details, show, Own)
	end

	if spec.threat then
		local details = key .. "ThreatIndicator"

		card:Details({
			id = details,
			label = L["Threat Border"],
			summary = function()
				return AUI.Profile:Get(Options:Path(key, "indicators.threat.enabled")) and L["On"] or OFF
			end,
		})
		card:Checkbox(Field("threatIndicator", SHOW, Options:Path(key, "indicators.threat.enabled"), {
			details = details,
			description = L["Shows your threat in group instances: gold near aggro, orange with aggro."],
		}))
		card:Slider(Field("threatSize", L["Size"], Options:Path(key, "indicators.threat.size"), {
			details = details,
			depends = "threatIndicator",
			min = 1,
			max = Options.MAX_THREAT_SIZE,
			step = 1,
			show = function()
				return AUI.Indicators:UsesThreatRing(key)
			end,
		}))
	end

	if spec.totems then
		local details = key .. "TotemsIndicator"

		local function Own(field)
			return Options:Path(key, "totems." .. field)
		end

		card:Details({
			id = details,
			label = L["Totems"],
			summary = function()
				return PlacementSummary(Own)
			end,
		})
		card:Checkbox(Field("totemsIndicator", SHOW, Own("enabled"), { details = details }))
		card:Slider(Field("totemSize", L["Size"], Own("size"), {
			details = details,
			depends = "totemsIndicator",
			min = Options.MIN_AURA_SIZE,
			max = Options.MAX_AURA_SIZE,
			step = 1,
		}))
		card:Slider(Field("totemSpacing", L["Spacing"], Own("spacing"), {
			details = details,
			depends = "totemsIndicator",
			min = 0,
			max = Options.MAX_AURA_SPACING,
			step = 1,
		}))
		card:Dropdown(Field("totemGrowth", L["Growth Direction"], Own("growth"), {
			details = details,
			depends = "totemsIndicator",
			options = ChoiceOptions(Options.AURA_GROWTHS, AURA_GROWTH_LABELS),
		}))
		DeclarePlacement(card, "totem", details, "totemsIndicator", Own)
	end
end

---The fading card for a frame that fades with range: the range fade, then how strong it is in a row.
---@param page table
function FramePage:DeclareRangeFading(page)
	local key = self.spec.key
	local card = page:Section(key .. "Fading", L["Fading"])

	AUI.SettingsFrameCopy:LinkFrame(card, page, key, "fading")
	local details = key .. "FadeStrength"

	local function Own(field)
		return Options:Path(key, "fade.range." .. field)
	end

	card:Checkbox(Field("rangeFade", L["Range Fade"], Own("enabled"), {
		description = L["Fades the frame while its unit is out of range of your spells."],
	}))
	card:Details({
		id = details,
		label = L["Strength"],
		depends = "rangeFade",
		summary = function()
			return ("%d%%"):format(AUI.Profile:Get(Own("alpha")))
		end,
	})
	card:Slider(Field("rangeAlpha", L["Range Fade Opacity"], Own("alpha"), {
		details = details,
		min = 0,
		max = 100,
		step = 5,
		format = "percent",
	}))
end

---The fading card: the idle fade, then how strong it is in a row.
---@param page table
function FramePage:DeclareFading(page)
	local key = self.spec.key
	local card = page:Section(key .. "Fading", L["Fading"])

	AUI.SettingsFrameCopy:LinkFrame(card, page, key, "fading")
	local details = key .. "FadeStrength"

	local function Own(field)
		return Options:Path(key, "fade.idle." .. field)
	end

	card:Checkbox(Field("idleFade", L["Idle Fade"], Own("enabled"), {
		description = L["Fades the frame while you are out of combat, have no target and are not casting."],
	}))
	card:Details({
		id = details,
		label = L["Strength"],
		depends = "idleFade",
		summary = function()
			return ("%d%%"):format(AUI.Profile:Get(Own("alpha")))
		end,
	})
	card:Slider(Field("idleAlpha", L["Idle Fade Opacity"], Own("alpha"), {
		details = details,
		min = 0,
		max = 100,
		step = 5,
		format = "percent",
	}))
end

---The interaction card: the unit tooltip.
---@param page table
function FramePage:DeclareInteraction(page)
	local key = self.spec.key
	local card = page:Section(key .. "Interaction", L["Interaction"])

	AUI.SettingsFrameCopy:LinkFrame(card, page, key, "interaction")

	card:Checkbox(Field("tooltip", L["Tooltip"], Options:Path(key, "tooltip.enabled")))
	card:Checkbox(Field("tooltipCombat", L["Hide Tooltip in Combat"], Options:Path(key, "tooltip.hideInCombat"), {
		depends = "tooltip",
	}))
end

---One aura display's card: its switch, size and limits, then its layout, filter, text and interaction in rows.
---@param page table
---@param kind "buffs"|"debuffs"
function FramePage:DeclareAuraDisplay(page, kind)
	local key = self.spec.key
	local buffs = kind == "buffs"
	local prefix = buffs and "buff" or "debuff"
	local show = prefix .. "Enabled"
	local card = page:Section(key .. kind, buffs and L["Buffs"] or L["Debuffs"])

	AUI.SettingsFrameCopy:LinkFrame(card, page, key, kind)

	local function Own(field)
		return Options:Path(key, kind .. "." .. field)
	end

	local function Read(field)
		return AUI.Profile:Get(Own(field))
	end

	-- A setting in a detail row follows the row, which follows the switch.
	local function On(extra)
		if not extra.details then
			extra.depends = extra.depends or show
		end

		return extra
	end

	local function Detail(name, label, summary)
		local id = key .. kind .. name

		card:Details(On({ id = id, label = label, summary = summary }))

		return id
	end

	card:Toggle(Field(show, buffs and L["Show Buffs"] or L["Show Debuffs"], Own("enabled")))
	card:Slider(Field(prefix .. "Size", L["Icon Size"], Own("size"), On({
		min = Options.MIN_AURA_SIZE,
		max = Options.MAX_AURA_SIZE,
		step = 1,
	})))
	card:Slider(Field(prefix .. "Limit", L["Limit"], Own("limit"), On({ min = 1, max = Options.MAX_AURA_LIMIT, step = 1 })))
	card:Slider(Field(prefix .. "PerRow", L["Icons Per Row"], Own("perRow"), On({
		description = L["0 fits as many icons as the frame is wide."],
		min = 0,
		max = Options.MAX_AURA_LIMIT,
		step = 1,
	})))

	local layout = Detail("Layout", L["Layout"], function()
		return AURA_ANCHOR_LABELS[Read("anchor")]
	end)

	card:Dropdown(Field(prefix .. "Anchor", L["Position"], Own("anchor"), On({
		details = layout,
		options = ChoiceOptions(Options.AURA_ANCHORS, AURA_ANCHOR_LABELS),
	})))
	card:Dropdown(Field(prefix .. "Growth", L["Growth Direction"], Own("growth"), On({
		details = layout,
		options = ChoiceOptions(Options.AURA_GROWTHS, AURA_GROWTH_LABELS),
	})))
	card:Slider(Field(prefix .. "Spacing", L["Spacing"], Own("spacing"), On({
		details = layout,
		min = 0,
		max = Options.MAX_AURA_SPACING,
		step = 1,
	})))
	card:Slider(Field(prefix .. "X", L["X Offset"], Own("x"), On({
		details = layout,
		min = -Options.MAX_OFFSET,
		max = Options.MAX_OFFSET,
		step = 1,
	})))
	card:Slider(Field(prefix .. "Y", L["Y Offset"], Own("y"), On({
		details = layout,
		min = -Options.MAX_OFFSET,
		max = Options.MAX_OFFSET,
		step = 1,
	})))

	local filter = Detail("Filter", FILTER, function()
		return AURA_FILTER_LABELS[Read("filter")]
	end)
	local filters = {}

	for _, value in ipairs(buffs and Options.BUFF_FILTERS or Options.DEBUFF_FILTERS) do
		if value ~= "categories" or self.spec.buffCategories then
			filters[#filters + 1] = { value = value, text = AURA_FILTER_LABELS[value] }
		end
	end

	card:Dropdown(Field(prefix .. "Filter", FILTER, Own("filter"), On({ details = filter, options = filters })))

	if buffs and self.spec.buffCategories then
		local available, chosen = {}, {}

		for _, category in ipairs(AUI.AuraCategories:Available()) do
			available[#available + 1] = category
			chosen[category] = true
		end

		card:Dropdown(On({
			id = prefix .. "Categories",
			label = L["Categories"],
			path = Own("categories"),
			default = chosen,
			details = filter,
			multiple = true,
			options = ChoiceOptions(available, BUFF_CATEGORY_LABELS),
			show = function()
				return Read("filter") == "categories"
			end,
		}))
	end

	local hides = buffs and Options.BUFF_HIDE or Options.DEBUFF_HIDE
	local hidden = {}

	for _, category in ipairs(hides) do
		hidden[category] = false
	end

	card:Dropdown(On({
		id = prefix .. "Hide",
		label = L["Hide Categories"],
		path = Own("hide"),
		default = hidden,
		details = filter,
		multiple = true,
		options = ChoiceOptions(hides, AURA_CATEGORY_LABELS),
	}))

	local function CheckList(text)
		return AUI.Auras:CheckSpellList(text)
	end

	local function Tracked()
		return Read("filter") == "tracked"
	end

	card:TextInput(Field(prefix .. "Include", L["Tracked Spells"], Own("include"), On({
		details = filter,
		allowEmpty = true,
		maxLetters = Options.MAX_SPELL_LIST,
		validate = CheckList,
		description = L["Spell IDs separated by commas. Applies only to buffs on you, your group and your pets, and to debuffs on enemies."],
		show = Tracked,
	})))
	card:Dropdown(Field(prefix .. "ListCaster", L["Tracked Caster"], Own("listCaster"), On({
		details = filter,
		options = ChoiceOptions(Options.LIST_CASTERS, LIST_CASTER_LABELS),
		show = Tracked,
	})))
	card:TextInput(Field(prefix .. "Exclude", L["Never Show"], Own("exclude"), On({
		details = filter,
		allowEmpty = true,
		maxLetters = Options.MAX_SPELL_LIST,
		validate = CheckList,
		description = L["Spell IDs separated by commas. Applies only to buffs on you, your group and your pets, and to debuffs on enemies."],
	})))
	card:Dropdown(Field(prefix .. "Sort", L["Sort"], Own("sort"), On({
		details = filter,
		options = ChoiceOptions(Options.AURA_SORTS, AURA_SORT_LABELS),
	})))
	card:Checkbox(Field(prefix .. "Reverse", L["Reverse Sort"], Own("reverse"), On({ details = filter })))

	local text = Detail("Text", L["Text and Borders"], function()
		local paths = {}

		for _, field in ipairs(Options.AURA_LOOK) do
			paths[#paths + 1] = Own(field)
		end

		return InheritSummary(paths)
	end)

	local function Look(id, label, field, extra)
		extra.details = text

		return Inherited(prefix .. id, label, Own(field), Options.ALL .. "auras." .. field, L["All Frames"], On(extra))
	end

	card:Checkbox(Look("Swipe", L["Cooldown Swipe"], "swipe", {}))
	card:Checkbox(Look("Border", buffs and L["Stealable Glow"] or L["Dispel Type Border"], "border", {}))
	card:Checkbox(Look("Duration", L["Show Duration"], "duration", {}))

	local duration = prefix .. "Duration"

	card:Slider(Look("DurationSize", L["Duration Size"], "durationSize", {
		depends = duration,
		min = Options.MIN_AURA_TEXT,
		max = Options.MAX_AURA_TEXT,
		step = 1,
	}))

	local function Shift(id, label, field, depends)
		card:Slider(Field(prefix .. id, label, Own(field), On({
			details = text,
			depends = depends,
			min = -Options.MAX_AURA_SHIFT,
			max = Options.MAX_AURA_SHIFT,
			step = 1,
		})))
	end

	Shift("DurationX", L["Duration X"], "durationX", duration)
	Shift("DurationY", L["Duration Y"], "durationY", duration)
	card:Dropdown(Look("CountCorner", L["Stack Position"], "countCorner", {
		options = ChoiceOptions(Options.AURA_CORNERS, AUI.SettingsAllFrames.CORNER_LABELS),
	}))
	card:Slider(Look("CountSize", L["Stack Size"], "countSize", {
		min = Options.MIN_AURA_TEXT,
		max = Options.MAX_AURA_TEXT,
		step = 1,
	}))
	Shift("CountX", L["Stack X"], "countX")
	Shift("CountY", L["Stack Y"], "countY")

	local interaction = Detail("Interaction", L["Interaction"], function()
		if Read("clicks") then
			return L["Clicks"]
		end

		return Read("tooltips") and L["Tooltips"] or NONE
	end)

	card:Checkbox(Field(prefix .. "Tooltips", L["Tooltips"], Own("tooltips"), On({ details = interaction })))
	card:Checkbox(Field(prefix .. "Clicks", L["Clicks"], Own("clicks"), On({
		details = interaction,
		description = buffs and key == "player" and L["On, right-click cancels the buff."] or nil,
	})))
end

---A slot's row, opening to what the slot shows and where.
---@param card table
---@param index integer
function FramePage:DeclareSlot(card, index)
	local key = self.spec.key
	local prefix = "slot" .. index
	local details = prefix .. "Details"

	local function SlotField(field)
		return Options:SlotPath(key, index, field)
	end

	local function Extra(extra)
		extra.details = details

		return extra
	end

	card:Details({
		id = details,
		label = L["Text %d"]:format(index),
		summary = function()
			local content = AUI.Profile:Get(SlotField("content"))

			if content == "none" then
				return NONE
			end

			return ("%s, %s"):format(CONTENT_LABELS[content], ANCHOR_LABELS[AUI.Profile:Get(SlotField("anchor"))])
		end,
	})
	card:Dropdown(Field(prefix .. "Content", L["Content"], SlotField("content"), Extra({
		options = ChoiceOptions(Options.CONTENTS, CONTENT_LABELS),
	})))
	card:Dropdown(Field(prefix .. "Separator", L["Separator"], SlotField("separator"), Extra({
		options = ChoiceOptions(Options.SEPARATORS, SEPARATOR_LABELS),
		show = function()
			return COMBINED[AUI.Profile:Get(SlotField("content"))] == true
		end,
	})))
	card:Dropdown(Field(prefix .. "Anchor", L["Anchor"], SlotField("anchor"), Extra({
		options = ChoiceOptions(Options.ANCHORS, ANCHOR_LABELS),
	})))
	card:Dropdown(Field(prefix .. "Placement", L["Placement"], SlotField("placement"), Extra({
		options = ChoiceOptions(Options.PLACEMENTS, PLACEMENT_LABELS),
	})))
	card:Slider(Field(prefix .. "X", L["X Offset"], SlotField("x"), Extra({
		min = -Options.MAX_OFFSET,
		max = Options.MAX_OFFSET,
		step = 1,
	})))
	card:Slider(Field(prefix .. "Y", L["Y Offset"], SlotField("y"), Extra({
		min = -Options.MAX_OFFSET,
		max = Options.MAX_OFFSET,
		step = 1,
	})))
	card:Slider(Field(prefix .. "Width", L["Width %"], SlotField("width"), Extra({
		min = Options.MIN_SLOT_WIDTH,
		max = Options.MAX_SLOT_WIDTH,
		step = 1,
	})))
	card:Dropdown(Field(prefix .. "ColorMode", L["Text Color"], SlotField("colorMode"), Extra({
		options = ChoiceOptions(Options.COLOR_MODES, COLOR_MODE_LABELS),
	})))

	local from = L["Frame Text"]

	local function Text(field)
		return Options:Path(key, "text." .. field)
	end

	card:Dropdown(Inherited(prefix .. "Font", L["Font"], SlotField("font"), Text("font"), from, Extra({
		picker = "font",
	})))
	card:Slider(Inherited(prefix .. "TextSize", L["Size"], SlotField("size"), Text("size"), from, Extra({
		min = Options.MIN_TEXT,
		max = Options.MAX_TEXT,
		step = 1,
	})))
	card:Dropdown(Inherited(prefix .. "Outline", L["Outline"], SlotField("outline"), Text("outline"), from, Extra({
		options = lib.OUTLINES,
	})))
	card:Color(Inherited(prefix .. "Color", COLOR, SlotField("color"), Text("color"), from, Extra({
		show = function()
			return AUI.Profile:Get(SlotField("colorMode")) == "custom"
		end,
	})))
end

---The frame's text style and numbers, which follow All Frames until changed.
---@param card table
function FramePage:DeclareStyle(card)
	local key = self.spec.key
	local details = key .. "TextStyle"
	local from = L["All Frames"]

	local function Own(field)
		return Options:Path(key, field)
	end

	local function Shared(field)
		return Options.ALL .. field
	end

	card:Details({
		id = details,
		label = L["Style"],
		summary = function()
			return InheritSummary({
				Own("text.font"), Own("text.size"), Own("text.outline"), Own("text.color"), Own("numbers.precision"),
				Own("numbers.percentDecimals"),
			})
		end,
	})
	card:Dropdown(Inherited("textFont", L["Font"], Own("text.font"), Shared("text.font"), from, {
		details = details,
		picker = "font",
	}))
	card:Slider(Inherited("textSize", L["Size"], Own("text.size"), Shared("text.size"), from, {
		details = details,
		min = Options.MIN_TEXT,
		max = Options.MAX_TEXT,
		step = 1,
	}))
	card:Dropdown(Inherited("textOutline", L["Outline"], Own("text.outline"), Shared("text.outline"), from, {
		details = details,
		options = lib.OUTLINES,
	}))
	card:Color(Inherited("textColor", COLOR, Own("text.color"), Shared("text.color"), from, { details = details }))
	card:Dropdown(Inherited("precision", L["Number Format"], Own("numbers.precision"), Shared("numbers.precision"),
		from, {
			details = details,
			options = ChoiceOptions(Options.PRECISIONS, AUI.SettingsAllFrames.PRECISION_LABELS),
		}))
	card:Slider(Inherited("percentDecimals", L["Percent Decimals"], Own("numbers.percentDecimals"),
		Shared("numbers.percentDecimals"), from, {
			details = details,
			min = 0,
			max = 1,
			step = 1,
		}))
end

---@param page table
function FramePage:DeclareText(page)
	local key = self.spec.key
	local card = page:Section(key .. "Text", L["Text"])

	AUI.SettingsFrameCopy:LinkFrame(card, page, key, "text")

	for index = 1, self.spec.slots do
		self:DeclareSlot(card, index)
	end

	local statusOptions = { { value = 0, text = NONE } }

	for index = 1, self.spec.slots do
		statusOptions[index + 1] = { value = index, text = L["Text %d"]:format(index) }
	end

	card:Dropdown(Field("status", L["Status Text In"], Options:Path(key, "text.status"), { options = statusOptions }))

	if AUI.can.surnames then
		card:Dropdown(Field("nameFormat", L["Name Format"], Options:Path(key, "text.nameFormat"), {
			options = ChoiceOptions(Options.NAME_FORMATS, NAME_FORMAT_LABELS),
		}))
	end

	self:DeclareStyle(card)
end

---@param window table
function FramePage:Declare(window)
	local spec = self.spec
	local enabled = Options:Path(spec.key, "enabled")
	local page = window:Page(spec.page, {
		title = TITLES[spec.key],
		under = "unitFramesHeader",
		icon = AUI.Media.sidebar[ICONS[spec.key]],
		iconTint = true,
		switch = {
			path = enabled,
			default = AUI.Settings:Default(enabled),
			label = SWITCHES[spec.key],
		},
	})

	if not page then
		return
	end

	local preview = AUI.FramePreview:New(spec)

	page:Preview({
		height = PREVIEW_HEIGHT,
		states = AUI.UnitCastBar:Has(spec) and AUI.FramePreview.CAST_STATES
			or spec.overlays and AUI.FramePreview.OVERLAY_STATES or AUI.FramePreview.STATES,
		create = function(canvas)
			preview:Create(canvas)
		end,
		refresh = function(_, state, target)
			return preview:Refresh(state, target)
		end,
	})

	self:DeclareSize(page)
	self:DeclareBars(page)
	self:DeclareHealth(page)

	if spec.power then
		self:DeclarePower(page)
	end

	if spec.portrait then
		self:DeclarePortrait(page)
	end

	self:DeclareText(page)

	if AUI.UnitCastBar:Has(spec) then
		self:DeclareCastBar(page)
	end

	if spec.auras then
		self:DeclareAuraDisplay(page, "buffs")
		self:DeclareAuraDisplay(page, "debuffs")
	end

	if spec.indicators then
		self:DeclareIndicators(page)
	end

	if spec.idleFade then
		self:DeclareFading(page)
	elseif spec.rangeFade then
		self:DeclareRangeFading(page)
	end

	self:DeclareInteraction(page)
end

---Adds a frame's page to the sidebar, after those registered so far, and its edit target.
---@param spec AUIFrameSpec
function FramePage.Register(spec)
	AUI.Modules:Register({
		group = "unitFrames",
		page = setmetatable({ spec = spec }, FramePage),
		start = function() end,
		editTargets = {
			{
				key = spec.page,
				path = Options:Path(spec.key, "position"),
				target = function()
					local frame = AUI.Frames.objects[spec.key]

					if frame then
						return {
							label = TITLES[spec.key],
							frame = frame,
							default = spec.position,
							sample = spec.unit ~= "player" and function(shown)
								AUI.Frames:SampleUnit(spec.key, shown)
							end or nil,
							settings = { page = spec.page, section = spec.key .. "Size" },
						}
					end
				end,
			},
		},
	})
end

FramePage.Register(Options.FRAMES[1])
