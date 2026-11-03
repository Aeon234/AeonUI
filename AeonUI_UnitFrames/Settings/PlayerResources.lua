local AUI = select(2, ...)

local L = AUI.L
local Options = AUI.UnitFrameOptions

local PREVIEW_HEIGHT = 84

local ATTACH_LABELS = {
	power = L["Player Power Bar"],
	screen = L["Screen"],
}

---The Player Resources page: the power bar, the class resource and extra mana, each with its own switch, since they
---are their own frames, usable without AeonUI's player frame.
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

	local function On()
		return AUI.Profile:Get(Own("enabled")) == true
	end

	card:Toggle(Field("powerEnabled", L["Show Power Bar"], Own("enabled")))
	card:Slider(Field("powerWidth", L["Width"], Own("width"), {
		depends = "powerEnabled",
		min = Options.MIN_RESOURCE_WIDTH,
		max = Options.MAX_RESOURCE_WIDTH,
		step = 1,
	}))
	card:Slider(Field("powerHeight", L["Height"], Own("height"), {
		depends = "powerEnabled",
		min = Options.MIN_POWER_HEIGHT,
		max = Options.MAX_HEIGHT,
		step = 1,
	}))
	card:Checkbox(Field("powerReverse", L["Reverse Fill"], Own("reverse"), { depends = "powerEnabled" }))

	local spec = Options:Spec(key) --[[@as AUIFrameSpec]]
	local rows = FramePage:New(spec)

	AUI.SettingsAllFrames:DeclarePowerColors(card, rows:PowerMaker(), function(field)
		return AUI.Profile:Get(Own("powerColors." .. field))
	end, rows:PowerGroup(card, "powerEnabled"), "powerEnabled")
	rows:DeclareBars(page, { show = On })
	rows:DeclareText(page, { show = On })
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

	local function On(extra)
		extra.depends = extra.depends or (not extra.details and "classEnabled") or nil

		return extra
	end

	card:Toggle(Field("classEnabled", L["Show Class Resource"], Own("enabled")))
	card:Dropdown(Field("classAttach", L["Attach To"], Own("attach"), On({
		options = FramePage.ChoiceOptions(Options.RESOURCE_ATTACHES, ATTACH_LABELS),
	})))
	card:Slider(Field("classWidth", L["Width"], Own("width"), On({
		min = Options.MIN_RESOURCE_WIDTH,
		max = Options.MAX_RESOURCE_WIDTH,
		step = 1,
	})))
	card:Slider(Field("classHeight", L["Height"], Own("height"), On({
		min = Options.MIN_POWER_HEIGHT,
		max = Options.MAX_RESOURCE_HEIGHT,
		step = 1,
	})))
	card:Slider(Field("classSpacing", L["Spacing"], Own("spacing"), On({
		min = 0,
		max = Options.MAX_RESOURCE_SPACING,
		step = 1,
	})))

	local look = "classLook"

	card:Details({ id = look, label = L["Look"], depends = "classEnabled" })
	card:Checkbox(Field("classBorder", L["Segment Borders"], Own("border"), { details = look }))
	card:Checkbox(Field("classColor", L["Class-Colored Fill"], Own("classColor"), { details = look }))
	card:Color(Field("classCharged", L["Charged Color"], Own("chargedColor"), { details = look }))
	card:Checkbox(Field("classPartial", L["Darken Partial Segments"], Own("darkenPartial"), { details = look }))

	local text = "classText"

	card:Details({
		id = text,
		label = L["Text"],
		depends = "classEnabled",
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

	card:Details({ id = visibility, label = L["Visibility"], depends = "classEnabled" })
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

				if frame and AUI.Frames:IsOn("playerPower") then
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
				if frame and Options:ResourceOn("classPower") and not AUI.ClassPower:IsAttached() then
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
