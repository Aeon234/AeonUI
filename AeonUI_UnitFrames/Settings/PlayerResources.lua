local AUI = select(2, ...)

local L = AUI.L
local Options = AUI.UnitFrameOptions

local PREVIEW_HEIGHT = 84

local ATTACH_LABELS = {
	power = L["Player Power Bar"],
	screen = L["Screen"],
}

local COLOR_MODE_LABELS = {
	spec = SPECIALIZATION,
	class = CLASS,
	type = L["Power Type"],
	custom = L["Custom"],
}

-- The palette colors each class's resources use.
local CLASS_TOKENS = {
	DEATHKNIGHT = { "RUNES_BLOOD", "RUNES_FROST", "RUNES_UNHOLY", "RUNES" },
	DRUID = { "COMBO_POINTS" },
	EVOKER = { "ESSENCE" },
	MAGE = { "ARCANE_CHARGES" },
	MONK = { "CHI", "STAGGER_LIGHT", "STAGGER_MODERATE", "STAGGER_HEAVY" },
	PALADIN = { "HOLY_POWER" },
	ROGUE = { "COMBO_POINTS" },
	SHAMAN = { "MAELSTROM" },
	WARLOCK = { "SOUL_SHARDS" },
}

local TOKEN_LABELS = {
	RUNES_BLOOD = L["Blood"],
	RUNES_FROST = L["Frost"],
	RUNES_UNHOLY = L["Unholy"],
	RUNES = RUNES,
	COMBO_POINTS = L["Combo Points"],
	ESSENCE = POWER_TYPE_ESSENCE,
	ARCANE_CHARGES = L["Arcane Charges"],
	CHI = CHI,
	STAGGER_LIGHT = L["Light Stagger"],
	STAGGER_MODERATE = L["Moderate Stagger"],
	STAGGER_HEAVY = L["Heavy Stagger"],
	HOLY_POWER = HOLY_POWER,
	MAELSTROM = MAELSTROM,
	SOUL_SHARDS = SOUL_SHARDS_POWER,
}

---The Player Resources page: the power bar, the class resource and extra mana under one switch, usable without AeonUI's
---player frame.
---@class AUISettingsPlayerResources
local Page = {}
AUI.SettingsPlayerResources = Page

---@param page table
function Page:DeclarePower(page)
	local FramePage = AUI.SettingsFramePage
	local key = "playerPower"
	local card = page:Section(key .. "Card", L["Power"])
	local Field = FramePage.Field

	local function Own(field)
		return Options:Path(key, field)
	end

	card:Slider(Field("powerWidth", L["Width"], Own("width"), {
		min = Options.MIN_RESOURCE_WIDTH,
		max = Options.MAX_RESOURCE_WIDTH,
		step = 1,
	}))
	card:Slider(Field("powerHeight", L["Height"], Own("height"), {
		min = Options.MIN_POWER_HEIGHT,
		max = Options.MAX_HEIGHT,
		step = 1,
	}))
	card:Checkbox(Field("powerReverse", L["Reverse Fill"], Own("reverse")))
	card:Checkbox(Field("powerSmooth", L["Smooth Animation"], Options.RESOURCES_SMOOTH))

	local spec = Options:Spec(key) --[[@as AUIFrameSpec]]
	local rows = FramePage:New(spec)

	AUI.SettingsAllFrames:DeclarePowerColors(card, rows:PowerMaker(), function(field)
		return AUI.Profile:Get(Own("powerColors." .. field))
	end, rows:PowerGroup(card))

	local visibility = "powerVisibility"

	card:Details({ id = visibility, label = L["Visibility"] })
	card:Checkbox(Field("powerIdle", L["Idle Fade"], Own("fade.idle.enabled"), { details = visibility }))
	card:Slider(Field("powerIdleAlpha", L["Idle Fade Opacity"], Own("fade.idle.alpha"), {
		details = visibility,
		depends = "powerIdle",
		min = 0,
		max = 100,
		step = 5,
		format = "percent",
	}))
	rows:DeclareBars(page)
	rows:DeclareText(page)
end

---@param page table
function Page:DeclareClassResource(page)
	local FramePage = AUI.SettingsFramePage
	local Field = FramePage.Field
	local key = "classPower"
	local card = page:Section(key .. "Card", L["Class Resource"])

	local function Own(field)
		return Options:Path(key, field)
	end

	local function Attached()
		return AUI.Profile:Get(Own("attach")) == "power"
	end

	card:Dropdown(Field("classAttach", L["Attach To"], Own("attach"), {
		options = FramePage.ChoiceOptions(Options.RESOURCE_ATTACHES, ATTACH_LABELS),
	}))
	card:Slider(Field("classAttachX", L["X Offset"], Own("attachX"), {
		min = -Options.MAX_RESOURCE_OFFSET,
		max = Options.MAX_RESOURCE_OFFSET,
		step = 1,
		show = Attached,
	}))
	card:Slider(Field("classAttachY", L["Y Offset"], Own("attachY"), {
		min = -Options.MAX_RESOURCE_OFFSET,
		max = Options.MAX_RESOURCE_OFFSET,
		step = 1,
		show = Attached,
	}))
	card:Slider(Field("classWidth", L["Width"], Own("width"), {
		min = Options.MIN_RESOURCE_WIDTH,
		max = Options.MAX_RESOURCE_WIDTH,
		step = 1,
	}))
	card:Slider(Field("classHeight", L["Height"], Own("height"), {
		min = Options.MIN_POWER_HEIGHT,
		max = Options.MAX_RESOURCE_HEIGHT,
		step = 1,
	}))
	card:Dropdown(Field("classColorMode", COLOR, Own("colorMode"), {
		options = FramePage.ChoiceOptions(Options.CLASS_COLOR_MODES, COLOR_MODE_LABELS),
	}))
	card:Color(Field("classCustomColor", L["Custom Color"], Own("color"), {
		show = function()
			return AUI.Profile:Get(Own("colorMode")) == "custom"
		end,
	}))

	local colors = "classColors"

	card:Details({ id = colors, label = L["Colors"] })

	local _, class = UnitClass("player")

	for _, token in ipairs(CLASS_TOKENS[AUI:Readable(class) or ""] or {}) do
		card:Color(Field("class" .. token, TOKEN_LABELS[token] or token, Own("palette." .. token), { details = colors }))
	end

	card:Color(Field("classCharged", L["Charged Color"], Own("chargedColor"), { details = colors }))
	card:Checkbox(Field("classPartial", L["Darken Partial Segments"], Own("darkenPartial"), { details = colors }))
	card:Checkbox(Field("classRecharge", L["Recharge Color"], Own("recharge"), { details = colors }))
	card:Color(Field("classRechargeColor", L["Recharge Color"], Own("rechargeColor"), {
		details = colors,
		depends = "classRecharge",
	}))

	local text = "classText"

	card:Details({
		id = text,
		label = L["Text"],
		summary = function()
			return AUI.Profile:Get(Own("text")) and L["On"] or OFF
		end,
	})
	card:Checkbox(Field("classCount", L["Show Count"], Own("text"), { details = text }))
	card:Slider(Field("classTextSize", L["Size"], Own("textSize"), {
		details = text,
		min = Options.MIN_AURA_TEXT,
		max = Options.MAX_AURA_TEXT,
		step = 1,
	}))
	card:Checkbox(Field("classRuneTimers", L["Rune Countdowns"], Own("runeTimers"), { details = text }))

	local visibility = "classVisibility"

	card:Details({ id = visibility, label = L["Visibility"] })
	card:Checkbox(Field("classHide", L["Hide Out of Combat"], Own("hideOutOfCombat"), { details = visibility }))
	card:Checkbox(Field("classIdle", L["Idle Fade"], Own("fade.idle.enabled"), { details = visibility }))
	card:Slider(Field("classIdleAlpha", L["Idle Fade Opacity"], Own("fade.idle.alpha"), {
		details = visibility,
		depends = "classIdle",
		min = 0,
		max = 100,
		step = 5,
		format = "percent",
	}))

	local spec = Options:Spec(key) --[[@as AUIFrameSpec]]
	local bars = FramePage:New(spec, "class"):DeclareBars(page, L["Class Resource Bars"])
	local dividers = "classDividers"

	local function Plain()
		local look = AUI.UnitFrame:BarLook(key)

		return AUI.Border:CellDividerWidth(look.borderStyle, look.borderThickness) == nil
	end

	bars:Details({ id = dividers, label = L["Dividers"], show = Plain })
	bars:Slider(Field("classSpacing", L["Spacing"], Own("spacing"), {
		details = dividers,
		min = 0,
		max = Options.MAX_RESOURCE_SPACING,
		step = 1,
	}))
	bars:Color(Field("classDividerColor", L["Divider Color"], Own("dividerColor"), {
		details = dividers,
		hasOpacity = true,
	}))
end

---@param page table
function Page:DeclareExtraMana(page)
	local FramePage = AUI.SettingsFramePage
	local card = page:Section("extraManaCard", L["Extra Mana"])

	card:Toggle(FramePage.Field("extraMana", L["Show Extra Mana"], Options:Path("classPower", "extraMana"), {
		description = L["A thin mana bar while mana is not your main power, such as in a druid form."],
	}))
	card:Slider(FramePage.Field("extraManaHeight", L["Height"], Options:Path("classPower", "extraManaHeight"), {
		depends = "extraMana",
		min = 2,
		max = Options.MAX_EXTRA_MANA,
		step = 1,
	}))
end

---@param window table
function Page:Declare(window)
	local page = window:Page("unitFrameResources", {
		title = L["Player Resources"],
		under = "unitFramesHeader",
		icon = AUI.Media.sidebar.playerResources,
		iconTint = true,
		switch = {
			path = Options.RESOURCES_PATH,
			default = AUI.Settings:Default(Options.RESOURCES_PATH),
			label = L["Show Player Resources"],
		},
	})

	if not page then
		return
	end

	local preview = AUI.ResourcePreview:New()

	page:Preview({
		height = PREVIEW_HEIGHT,
		states = AUI.ResourcePreview.STATES,
		create = function(canvas)
			preview:Create(canvas)
		end,
		refresh = function(_, state, target)
			return preview:Refresh(state, target)
		end,
	})

	self:DeclarePower(page)
	self:DeclareClassResource(page)
	self:DeclareExtraMana(page)
end

AUI.Modules:Register({
	group = "unitFrames",
	page = Page,
	start = function() end,
	editTargets = {
		{
			key = "unitFrameResourcesPower",
			path = Options:Path("playerPower", "position"),
			target = function()
				local frame = AUI.Frames.objects.playerPower

				if frame and Options:ResourcesOn() then
					return {
						label = L["Power"],
						frame = frame,
						default = (Options:Spec("playerPower") --[[@as AUIFrameSpec]]).position,
						settings = { page = "unitFrameResources", section = "playerPowerCard" },
					}
				end
			end,
		},
		{
			key = "unitFrameResourcesClass",
			path = Options:Path("classPower", "position"),
			target = function()
				local frame = AUI.Frames.objects.classPower

				-- Attached to the power bar, it moves with that bar.
				if frame and Options:ResourcesOn() and not AUI.ClassPower:IsAttached() then
					return {
						label = L["Class Resource"],
						frame = frame,
						default = (Options:Spec("classPower") --[[@as AUIFrameSpec]]).position,
						settings = { page = "unitFrameResources", section = "classPowerCard" },
					}
				end
			end,
		},
	},
})
