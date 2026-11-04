local AUI = select(2, ...)

local L = AUI.L
local lib = LibStub("LibAeonSettings-1.0")

local PREVIEW_HEIGHT = 96
local IN_RANGE, OUT_OF_RANGE, QUEUED = L["In Range"], L["Out of Range"], L["Queued"]

local VISIBILITY_LABELS = {
	COMBAT = L["In Combat"],
	ALWAYS = L["Always"],
}

local BORDER_STYLE_LABELS = {
	THIN_LINE = L["Thin Line"],
	FOREVER_MINIMAL = L["Forever Minimal"],
}

---The Swing Timer page, under the Unit Frames header on the clients that report swings: the module's switch, sample
---rows as its preview, and the Bars, Size, Range, Colors, Border and Text cards.
---@class AUISettingsSwingTimer
local SettingsSwingTimer = {}
AUI.SettingsSwingTimer = SettingsSwingTimer

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

---@param id string
---@param label string
---@param field string the setting's path under the module
---@param extra table? more of the setting's fields
---@return table setting
local function Field(id, label, field, extra)
	local setting = extra or {}
	local path = "swingTimer." .. field

	setting.id, setting.label, setting.path, setting.default = id, label, path, AUI.Settings:Default(path)

	return setting
end

---Still rows, styled as the live ones are.
---@class AUISwingTimerPreview
---@field rows AUISwingTimerRow[]
local SwingTimerPreview = { rows = {} }

---@param canvas Frame
function SwingTimerPreview:Create(canvas)
	for index, spec in ipairs(AUI.SwingTimerOptions.ROWS) do
		local row = AUI.SwingTimer:BuildRow(canvas, spec)

		row.isPreview = true
		self.rows[index] = row
	end
end

---@param state string a state's label
---@param preview table
---@return number width
---@return number height
function SwingTimerPreview:Refresh(state, preview)
	local Profile, Options, SwingTimer = AUI.Profile, AUI.SwingTimerOptions, AUI.SwingTimer
	local height, spacing = SwingTimer:RowHeight(), Profile:Get("swingTimer.spacing")
	local far = state == OUT_OF_RANGE and Profile:Get("swingTimer.rangeCheck") == true
	local canvas = self.rows[1]:GetParent() --[[@as Frame]]
	local _, class = UnitClass("player")
	local attacks = Options.NEXT_SWING[class]
	local queued = state == QUEUED and attacks and attacks[1]

	for _, row in ipairs(self.rows) do
		row:SetShown(Profile:Get("swingTimer." .. row.spec.show) == true)
		row.sampleField = queued and Options:QueueField(queued) or nil
		row.sampleAttack = queued and C_Spell.GetSpellName(queued) or nil
		SwingTimer:Style(row)
	end

	local shown = SwingTimer:Stack(self.rows, canvas, function()
		return true
	end)

	for _, row in ipairs(self.rows) do
		if row:IsShown() then
			SwingTimer:DrawSample(row, far)

			if not row.host then
				preview:Part(row.bar, row.spec.color)
			end
		end
	end

	return Profile:Get("swingTimer.width"), Options:StackHeight(shown, height, spacing)
end

---@param page table
function SettingsSwingTimer:DeclareBars(page)
	local Options = AUI.SwingTimerOptions
	local card = page:Section("swingTimerBars", L["Bars"])

	card:Checkbox(Field("showMH", L["Main Hand"], "showMH"))
	card:Checkbox(Field("showOH", L["Off Hand"], "showOH", {
		description = L["Shown while you have a weapon in your off hand."],
	}))
	card:Checkbox(Field("showR", L["Ranged"], "showR", {
		description = L["Shown while you have a bow, gun, crossbow, wand or thrown weapon."],
	}))
	card:Checkbox(Field("alwaysShowRows", L["Always Show Rows"], "alwaysShowRows", {
		description = L["Shows every bar turned on here, with or without a weapon in its slot."],
	}))
	card:Checkbox(Field("shieldRow", L["Show Shield As Off Hand"], "shieldRow", {
		description = L["Shows the Off Hand bar, labeled Shield, while a shield is equipped."],
	}))
	card:Checkbox(Field("combineHands", L["Combine Hands"], "combineHands", {
		description = L["Shows the off hand as a spark on the Main Hand bar, instead of its own bar."],
		blocked = function()
			local Profile = AUI.Profile

			if not (Profile:Get("swingTimer.showMH") and Profile:Get("swingTimer.showOH")) then
				return L["Needs the Main Hand and Off Hand bars."]
			end
		end,
	}))
	card:Dropdown(Field("visibility", L["Show"], "visibility", {
		options = ChoiceOptions(Options.VISIBILITIES, VISIBILITY_LABELS),
	}))
	card:Checkbox(Field("hideWhenIdle", L["Hide When Idle"], "hideWhenIdle", {
		description = L["Hides the bars while no swing is running."],
		blocked = function()
			if AUI.Profile:Get("swingTimer.visibility") ~= "COMBAT" then
				return L["Needs Show In Combat."]
			end
		end,
	}))
	card:Dropdown(Field("texture", L["Texture"], "texture", { picker = "texture" }))
	card:Checkbox(Field("depleteFill", L["Deplete Fill"], "depleteFill", {
		description = L["Starts each bar full and drains it, instead of filling it up."],
	}))
	card:Checkbox(Field("spark", L["Show Spark"], "spark"))
	card:Checkbox(Field("time", L["Show Time"], "time"))
	card:Checkbox(Field("label", L["Show Weapon Label"], "label"))
end

---@param page table
function SettingsSwingTimer:DeclareSize(page)
	local Options = AUI.SwingTimerOptions
	local card = page:Section("swingTimerSize", L["Size"])

	card:Slider(Field("width", L["Width"], "width", { min = Options.MIN_WIDTH, max = Options.MAX_WIDTH, step = 1 }))
	card:Slider(Field("height", L["Height"], "height", {
		description = L["Forever Minimal keeps the bar at least 16 tall."],
		min = Options.MIN_HEIGHT,
		max = Options.MAX_HEIGHT,
		step = 1,
	}))
	card:Slider(Field("spacing", L["Spacing"], "spacing", { min = 0, max = Options.MAX_SPACING, step = 1 }))
end

---@param page table
function SettingsSwingTimer:DeclareRange(page)
	local card = page:Section("swingTimerRange", L["Range"])

	card:Checkbox(Field("rangeCheck", L["Range Check"], "rangeCheck", {
		description = L["Dims a bar and turns its text red while your target is out of that weapon's range."],
	}))
	card:Slider(Field("outOfRangeAlpha", L["Out of Range Opacity"], "outOfRangeAlpha", {
		depends = "rangeCheck",
		min = 0,
		max = 100,
		step = 5,
		format = "percent",
	}))
end

---@param page table
function SettingsSwingTimer:DeclareColors(page)
	local card = page:Section("swingTimerColors", L["Colors"])

	card:Checkbox(Field("classColor", L["Class Color"], "classColor"))
	card:Color(Field("mhColor", L["Main Hand Color"], "mhColor"))
	card:Color(Field("ohColor", L["Off Hand Color"], "ohColor"))
	card:Color(Field("rColor", L["Ranged Color"], "rColor"))
	card:Color(Field("background", L["Background"], "background", { hasOpacity = true }))
end

---@param page table
function SettingsSwingTimer:DeclareQueued(page)
	local card = page:Section("swingTimerQueued", L["Queued Attacks"], {
		show = function()
			local _, class = UnitClass("player")

			return AUI.SwingTimerOptions.NEXT_SWING[class] ~= nil
		end,
	})

	card:Toggle(Field("queueHighlight", L["Color Queued Attacks"], "queueHighlight", {
		description = L["While Heroic Strike, Cleave, Maul or Raptor Strike is queued, the melee bars take its color and name."],
	}))
	card:Color(Field("queueColor", L["Queued Attack Color"], "queueColor", { depends = "queueHighlight" }))
	card:Color(Field("cleaveColor", L["Cleave Color"], "cleaveColor", { depends = "queueHighlight" }))
end

---@param page table
function SettingsSwingTimer:DeclareSeals(page)
	local card = page:Section("swingTimerSeals", L["Seal Colors"], {
		show = function()
			local _, class = UnitClass("player")

			return class == "PALADIN"
		end,
	})

	card:Toggle(Field("sealColors", L["Color By Seal"], "sealColors", {
		description = L["The melee bars take your seal's color. In combat that is the last seal you cast until it runs out, since the game keeps your buffs from addons there."],
	}))

	for _, seal in ipairs(AUI.SwingTimerOptions.SEALS) do
		card:Color(Field(seal.color, C_Spell.GetSpellName(seal.id) or seal.label, seal.color, { depends = "sealColors" }))
	end
end

---@param page table
function SettingsSwingTimer:DeclareSwingWindow(page)
	local Options = AUI.SwingTimerOptions
	local card = page:Section("swingTimerSwingWindow", L["Swing End Window"])

	card:Toggle(Field("swingWindow", L["Show Swing End Window"], "swingWindow", {
		description = L["Shades the last part of each melee swing: when to twist a seal, finish a weave or queue an attack before the hit."],
	}))
	card:Slider(Field("swingWindowTime", L["Window Length"], "swingWindowTime", {
		depends = "swingWindow",
		min = Options.MIN_WINDOW,
		max = Options.MAX_WINDOW,
		step = 0.1,
		format = "decimal",
	}))
	card:Color(Field("swingWindowColor", L["Window Color"], "swingWindowColor", {
		depends = "swingWindow",
		hasOpacity = true,
	}))
	card:Checkbox(Field("windowLatency", L["Add Latency"], "windowLatency", {
		description = L["Widens the swing and Auto Shot windows by your world latency, so they show when to press rather than when the server acts."],
	}))
end

---@param page table
function SettingsSwingTimer:DeclareAutoShot(page)
	local card = page:Section("swingTimerAutoShot", L["Auto Shot Window"], {
		show = function()
			local _, class = UnitClass("player")

			return class == "HUNTER"
		end,
	})

	card:Toggle(Field("autoShotWindow", L["Show Auto Shot Window"], "autoShotWindow", {
		description = L["Shades Auto Shot's cast at the end of the Ranged bar. It turns red while you move, since moving holds the shot."],
	}))
	card:Color(Field("autoShotStandColor", L["Standing Color"], "autoShotStandColor", {
		depends = "autoShotWindow",
		hasOpacity = true,
	}))
	card:Color(Field("autoShotMovingColor", L["Moving Color"], "autoShotMovingColor", {
		depends = "autoShotWindow",
		hasOpacity = true,
	}))
end

---@param page table
function SettingsSwingTimer:DeclareBorder(page)
	local Options = AUI.SwingTimerOptions
	local card = page:Section("swingTimerBorder", L["Border"])

	card:Dropdown(Field("borderStyle", L["Border Style"], "borderStyle", {
		options = ChoiceOptions(Options.BORDER_STYLES, BORDER_STYLE_LABELS),
	}))
	card:Color(Field("borderColor", L["Border Color"], "borderColor", {
		blocked = function()
			if AUI.Profile:Get("swingTimer.borderStyle") ~= "THIN_LINE" then
				return L["Needs the Thin Line border style."]
			end
		end,
	}))
	card:Checkbox(Field("showShadow", L["Show Shadow"], "showShadow"))
	card:Slider(Field("shadowSize", L["Shadow Size"], "shadowSize", {
		depends = "showShadow",
		min = 1,
		max = 10,
		step = 1,
	}))
	card:Color(Field("shadowColor", L["Shadow Color"], "shadowColor", {
		depends = "showShadow",
		hasOpacity = true,
	}))
end

---@param page table
function SettingsSwingTimer:DeclareText(page)
	local Options = AUI.SwingTimerOptions
	local card = page:Section("swingTimerText", L["Text"])

	card:Dropdown(Field("font", L["Font"], "font", { picker = "font" }))
	card:Dropdown(Field("outline", L["Outline"], "outline", { options = lib.OUTLINES }))
	card:Slider(Field("textSize", L["Text Size"], "textSize", {
		min = Options.MIN_TEXT,
		max = Options.MAX_TEXT,
		step = 1,
	}))
end

---@return boolean
function SettingsSwingTimer:IsAvailable()
	return AUI.can.swingTimer == true
end

---@param window table
function SettingsSwingTimer:Declare(window)
	local Options = AUI.SwingTimerOptions

	local page = window:Page("swingTimer", {
		title = L["Swing Timer"],
		under = "unitFramesHeader",
		icon = AUI.Media.sidebar.castBar,
		iconTint = true,
		switch = {
			path = Options.ENABLED_PATH,
			default = AUI.Settings:Default(Options.ENABLED_PATH),
			label = L["Show Swing Timer"],
		},
	})

	if not page then
		return
	end

	local _, class = UnitClass("player")
	local states = { IN_RANGE, OUT_OF_RANGE }

	if Options.NEXT_SWING[class] then
		states[3] = QUEUED
	end

	page:Preview({
		height = PREVIEW_HEIGHT,
		states = states,
		create = function(canvas)
			SwingTimerPreview:Create(canvas)
		end,
		refresh = function(_, state, preview)
			return SwingTimerPreview:Refresh(state or IN_RANGE, preview)
		end,
	})

	page:Section("swingTimerBlizzard", L["Blizzard's Swing Timer"], {
		show = function()
			return C_CVar.GetCVarBool("showSwingTimer") == true
		end,
	}):Note(L["Blizzard's own swing timer is also on, so both show. Turn it off in the game's Interface options."])

	self:DeclareBars(page)
	self:DeclareSize(page)
	self:DeclareRange(page)
	self:DeclareColors(page)
	self:DeclareQueued(page)
	self:DeclareSeals(page)
	self:DeclareSwingWindow(page)
	self:DeclareAutoShot(page)
	self:DeclareBorder(page)
	self:DeclareText(page)
end

AUI.Modules:Register({
	group = "unitFrames",
	page = SettingsSwingTimer,
	start = function()
		AUI.SwingTimer:Start()
	end,
	editTargets = {
		{
			key = "swingTimer",
			path = "swingTimer.position",
			target = function()
				local SwingTimer = AUI.SwingTimer

				if SwingTimer.frame and SwingTimer:IsOn() then
					return {
						label = L["Swing Timer"],
						frame = SwingTimer.frame,
						default = AUI.SwingTimerOptions.DEFAULT_POSITION,
						sample = function(shown)
							SwingTimer:Sample(shown)
						end,
						settings = { page = "swingTimer", section = "swingTimerBars" },
					}
				end
			end,
		},
	},
})
