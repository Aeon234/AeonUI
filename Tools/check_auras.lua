-- Checks AeonUI_UnitFrames/Frames/Auras.lua and AuraCategories.lua outside the game: aura display settings and their
-- defaults, the filter strings and candidate filters handed to the client, placement against the frame with text
-- clearance, row wrapping, groups added to and updated on oUF's aura element, button styling and the buff categories.
-- Run from any directory with Lua 5.1: lua Tools/check_auras.lua
-- The client's aura containers are stand-ins that record what AeonUI asks of them; their filtering, sorting and layout
-- are the client's and are not exercised here.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

UNKNOWN = "Unknown"
SlashCmdList = {}
C_AddOns = {
	GetAddOnMetadata = function() end,
}
Enum = {
	CustomAuraButtonDispelTypeTextureStyle = { Border = 0, Icon = 1, PreserveAsset = 2 },
	CustomAuraButtonDispelTypeStealableFilter = { Stealable = 1 },
}
AnchorUtil = { FlowLayoutAxis = { Horizontal = 0, Vertical = 1 } }
AuraContainerSortMethod = {
	Default = 0, UnitFrameDebuff = 2, ImportantOnly = 3, ExpirationOnly = 5, NameOnly = 7, AuraInstanceIDOnly = 8,
}
AuraContainerSortDirection = { Normal = 0, Reverse = 1 }

function issecretvalue()
	return false
end

function UnitClass()
	return "Mage", "MAGE"
end

---A frame or region stand-in recording the last call of each method.
local function Region()
	local region = { last = {}, shown = true, alpha = 1, level = 1 }

	function region:SetShown(shown)
		self.shown = shown == true
	end

	function region:SetAlpha(alpha)
		self.alpha = alpha
	end

	function region:GetFrameLevel()
		return self.level
	end

	function region:CreateTexture()
		return Region()
	end

	function region:CreateFontString(_, _, template)
		local font = Region()

		font.template = template

		return font
	end

	function region:SetPoint(...)
		self.points = rawget(self, "points") or {}
		self.points[#self.points + 1] = { ... }
	end

	function region:ClearAllPoints()
		self.points = {}
	end

	return setmetatable(region, {
		__index = function(_, method)
			if not method:find("^%u") then
				return nil
			end

			return function(self, ...)
				self.last[method] = { ... }
			end
		end,
	})
end

function CreateFrame(_, _, parent)
	local frame = Region()

	frame.parent = parent

	return frame
end

local AUI = {}

assert(loadfile(root .. "AeonUI/Core/Core.lua"))("AeonUI", AUI)
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
AUI.can = {}
AUI.Pixel = function()
	return 0.5
end
AUI.Border = { ART_COLOR = { r = 0.5, g = 0.4, b = 0.3 } }
AUI.Media = {
	FLAT = "flat",
	Font = function(_, name)
		return name
	end,
	FontFlags = function(_, outline)
		return outline == "NONE" and "" or outline
	end,
}

local overhang = { 0, 0 }

AUI.Text = {
	Overhang = function()
		return overhang[1], overhang[2]
	end,
}

assert(loadfile(root .. "AeonUI/Profile/Schema.lua"))("AeonUI", AUI)
assert(loadfile(root .. "AeonUI_UnitFrames/Frames/Options.lua"))("AeonUI", AUI)
assert(loadfile(root .. "AeonUI_UnitFrames/Frames/AuraCategories.lua"))("AeonUI", AUI)
AUI.UnitCastBar = {
	Extent = function()
		return 0
	end,
}
assert(loadfile(root .. "AeonUI_UnitFrames/Frames/Auras.lua"))("AeonUI", AUI)

local Auras, Schema, Options = AUI.Auras, AUI.Schema, AUI.UnitFrameOptions
local config = Schema:Defaults()

AUI.Profile = {
	Get = function(_, path)
		return Schema:Read(config, path)
	end,
}

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

local function Display(kind)
	return Auras:Resolve("player", kind)
end

-- Settings ------------------------------------------------------------------------------------------------

local buffs, debuffs = Display("buffs"), Display("debuffs")
Equal("buffs off", buffs.enabled, false)
Equal("buffs above left", buffs.anchor, "aboveLeft")
Equal("buffs limit", buffs.limit, 4)
Equal("buffs all", buffs.filter, "all")
Equal("debuffs off", debuffs.enabled, false)
Equal("debuffs below left", debuffs.anchor, "belowLeft")
Equal("debuffs limit", debuffs.limit, 10)
Equal("icon size", debuffs.size, 22)
Equal("spacing", debuffs.spacing, 2)
Equal("rows fit the frame", debuffs.perRow, 0)
Equal("stable order", debuffs.sort, "stable")
Equal("tooltips on", debuffs.tooltips, true)
Equal("clicks off", debuffs.clicks, false)
Equal("duration text off", debuffs.duration, false)
Equal("duration size", debuffs.durationSize, 10)
Equal("stack corner", debuffs.countCorner, "BOTTOMRIGHT")
Equal("stack size", debuffs.countSize, 14)
Equal("stack inset", debuffs.countX, -1)
Equal("swipe on", debuffs.swipe, true)
Equal("border on", debuffs.border, true)
Equal("font follows the frame text", debuffs.font, "Expressway")
Equal("no Has Duration for debuffs", (Schema:CheckValue("frames.player.debuffs.filter", "hasDuration")), false)
Equal("Has Duration for buffs", (Schema:CheckValue("frames.player.buffs.filter", "hasDuration")), true)
Equal("no Important OR Own", (Schema:CheckValue("frames.player.debuffs.filter", "importantOrOwn")), false)
Schema:Write(config, Options.ALL .. "auras.swipe", false)
Equal("a display's look follows All Frames", Display("buffs").swipe, false)
Schema:Write(config, "frames.player.buffs.swipe", true)
Equal("until it holds its own", Display("buffs").swipe, true)
config = Schema:Defaults()

-- Filters and sorts ---------------------------------------------------------------------------------------

local function Filter(kind, mode)
	local filter, candidates = Auras:Filter({ kind = kind, filter = mode })

	return filter .. (candidates and (" max " .. tostring(candidates.maxDuration)) or "")
end

Equal("all debuffs", Filter("debuffs", "all"), "HARMFUL")
Equal("your debuffs", Filter("debuffs", "own"), "HARMFUL|PLAYER")
Equal("important debuffs", Filter("debuffs", "important"), "HARMFUL|IMPORTANT")
Equal("important and yours", Filter("debuffs", "importantOwn"), "HARMFUL|IMPORTANT|PLAYER")
Equal("all buffs", Filter("buffs", "all"), "HELPFUL")
Equal("your buffs", Filter("buffs", "own"), "HELPFUL|PLAYER")
Equal("buffs with a duration", Filter("buffs", "hasDuration"), "HELPFUL max " .. tostring(math.huge))
Equal("unknown mode falls back", Filter("debuffs", "nonsense"), "HARMFUL")

local function Sort(sort, reverse)
	return table.concat({ Auras:Sort({ sort = sort, reverse = reverse }) }, " ")
end

Equal("stable", Sort("stable"), "AuraInstanceIDOnly Normal")
Equal("shortest", Sort("shortest"), "ExpirationOnly Normal")
Equal("yours first", Sort("yours"), "Default Normal")
Equal("blizzard order", Sort("blizzard"), "UnitFrameDebuff Normal")
Equal("importance", Sort("importance"), "ImportantOnly Normal")
Equal("name", Sort("name", true), "NameOnly Reverse")

for _, value in ipairs(Options.AURA_SORTS) do
	Equal(value .. " has a client sort", AuraContainerSortMethod[(Auras:Sort({ sort = value }))] ~= nil, true)
end

-- Categories and spell lists -------------------------------------------------------------------------------

local function Build(kind, fields)
	local settings = Display(kind)

	for key, value in pairs(fields) do
		settings[key] = value
	end

	return Auras:Filter(settings)
end

local filter, candidates = Build("debuffs", { filter = "crowdControl" })
Equal("crowd control", filter, "HARMFUL|CROWD_CONTROL")
Equal("no extra filters", candidates, nil)
filter, candidates = Build("debuffs", { filter = "boss" })
Equal("boss by field", filter .. tostring(candidates.isBossAura), "HARMFULtrue")
filter, candidates = Build("debuffs", { filter = "magic" })
Equal("dispel type", candidates.includeDispelTypes.Magic, true)
filter = Build("debuffs", { filter = "notYours" })
Equal("not yours", filter, "HARMFUL|!PLAYER")
filter = Build("debuffs", { filter = "dispellableByYou" })
Equal("dispellable by you", filter, "HARMFUL|RAID")
filter, candidates = Build("buffs", { filter = "stealable" })
Equal("stealable buffs", filter .. tostring(candidates.isStealable), "HELPFULtrue")

local hide = { crowdControl = true, boss = true, poison = true, notYours = true, classCanApply = false }
filter, candidates = Build("debuffs", { filter = "important", hide = hide })
Equal("hidden keywords negated", filter, "HARMFUL|IMPORTANT|!CROWD_CONTROL|PLAYER")
Equal("hidden field false", candidates.isBossAura, false)
Equal("hidden dispel type excluded", candidates.excludeDispelTypes.Poison, true)
Equal("unchecked categories stay", candidates.canApplyAura, nil)
filter = Build("debuffs", { filter = "own", hide = { yours = true } })
Equal("contradicting categories show nothing", filter, "HARMFUL|PLAYER|!PLAYER")
filter = Build("debuffs", { filter = "importantOwn", hide = { notYours = true } })
Equal("repeated keywords once", filter, "HARMFUL|IMPORTANT|PLAYER")
filter = Build("buffs", { filter = "all", hide = { crowdControl = true } })
Equal("buffs ignore debuff categories", filter, "HELPFUL")

filter, candidates = Build("debuffs", { filter = "tracked", include = "8921, 93402 155722" })
Equal("tracked filter", filter, "HARMFUL")
Equal("tracked spells", candidates.includeSpellIDs[93402] and candidates.includeSpellIDs[155722], true)
filter, candidates = Build("debuffs", { filter = "tracked", include = "", listCaster = "yours" })
Equal("tracked yours", filter, "HARMFUL|PLAYER")
Equal("nothing tracked shows nothing", next(candidates.includeSpellIDs), nil)
filter, candidates = Build("debuffs", { filter = "all", include = "8921" })
Equal("tracked list only with the tracked filter", candidates, nil)
filter, candidates = Build("debuffs", { filter = "all", exclude = "8921,1" })
Equal("never shown", candidates.excludeSpellIDs[8921] and candidates.excludeSpellIDs[1], true)

Equal("spell list parsed", Auras:SpellList(" 12,  34 56 ")[56], true)
Equal("empty list", next(Auras:SpellList("")), nil)
Equal("ids accepted", Auras:CheckSpellList("12, 34 56"), nil)
Equal("words refused", Auras:CheckSpellList("12, Moonfire") ~= nil, true)
Equal("hide fields grouped", Display("debuffs").hide.crowdControl, false)
Equal("empty lists by default", Display("debuffs").include, "")
Equal("empty text valid", (Schema:CheckValue("frames.player.debuffs.include", "")), true)

-- Placement -----------------------------------------------------------------------------------------------

local function Place(settings, above, below)
	local p = Auras:Placement(settings, 270, above or 0, below or 0)

	return table.concat({ p.point, p.relative, p.x, p.y, p.growthX, p.growthY, p.lineSize }, " ")
end

buffs, debuffs = Display("buffs"), Display("debuffs")
Equal("above left", Place(buffs), "BOTTOMLEFT TOPLEFT 0 8 1 1 270")
Equal("above clears text", Place(buffs, 6), "BOTTOMLEFT TOPLEFT 0 14 1 1 270")
Equal("below left", Place(debuffs), "TOPLEFT BOTTOMLEFT 0 -8 1 -1 270")
Equal("below clears what is there", Place(debuffs, 0, 20), "TOPLEFT BOTTOMLEFT 0 -28 1 -1 270")
local side = Display("debuffs")
side.anchor, side.growth = "left", "left"
Equal("left side", Place(side), "TOPRIGHT TOPLEFT -8 0 -1 -1 270")
side.anchor, side.growth = "right", "right"
Equal("right side", Place(side), "TOPLEFT TOPRIGHT 8 0 1 -1 270")
buffs.anchor, buffs.growth = "aboveRight", "left"
Equal("above right grows left", Place(buffs), "BOTTOMRIGHT TOPRIGHT 0 8 -1 1 270")
buffs.anchor, buffs.x, buffs.y = "belowRight", 5, -3
Equal("offsets", Place(buffs), "TOPRIGHT BOTTOMRIGHT 5 -11 -1 -1 270")
debuffs.perRow = 4
Equal("icons per row", Place(debuffs), "TOPLEFT BOTTOMLEFT 0 -8 1 -1 94")
debuffs.perRow = 0

local placement = Auras:Placement(debuffs, 270, 0, 0)
Equal("icons that fit the frame", Auras:PerRow(debuffs, placement), 11)
placement.lineSize = 10
Equal("always at least one", Auras:PerRow(debuffs, placement), 1)
debuffs.perRow = 4
placement = Auras:Placement(debuffs, 270, 0, 0)
Equal("per row override fits exactly", Auras:PerRow(debuffs, placement), 4)
local offsets = Auras:IconOffsets(debuffs, placement, 6)
Equal("first icon at the corner", offsets[1].x == 0 and offsets[1].y == 0, true)
Equal("fourth icon ends the row", offsets[4].x, 72)
Equal("fifth icon wraps down", offsets[5].x .. "," .. offsets[5].y, "0,-24")
side.anchor, side.growth = "left", "left"
local left = Auras:Placement(side, 200, 0, 0)
offsets = Auras:IconOffsets(side, left, 9)
Equal("left growth", offsets[2].x, -24)
Equal("rows below", offsets[9].y, -24)

overhang = { 6, 2 }
Equal("text above", (Auras:Clearance("player")), 6)
Equal("text below", select(2, Auras:Clearance("player")), 2)
overhang = { 0, 0 }

-- Live displays -------------------------------------------------------------------------------------------

---An oUF aura element stand-in.
local function Element()
	local element = Region()

	element.groups = {}

	function element:AddGroup(groupFilter, options)
		self.groups[#self.groups + 1] = { filter = groupFilter, options = options }

		return "Group" .. #self.groups
	end

	function element:SetAuraGroupFilterString(_, groupFilter)
		self.groups[1].filter = groupFilter
	end

	return element
end

local frame = { key = "player", colors = { dispel = {} } }

function frame:CreateAuras(options)
	self.options = options

	return Element()
end

local widgets = Auras:Create(frame, "debuffs")
local element = widgets.element
Equal("horizontal flow", frame.options.layout, 0)
Equal("no group before settings", #element.groups, 0)

debuffs = Display("debuffs")
Auras:Configure(widgets, debuffs)
Equal("one group", #element.groups, 1)
Equal("group filter", element.groups[1].filter, "HARMFUL")
Equal("group limit", element.groups[1].options.maxFrameCount, 10)
Equal("group sort", element.groups[1].options.sortMethod, 8)
Equal("group direction", element.groups[1].options.sortDirection, 0)
Equal("group icon size", element.groups[1].options.layout.elementWidth, 22)
Equal("group spacing", element.groups[1].options.layout.elementSpacing, 2)
Equal("row spacing", element.groups[1].options.layout.lineSpacing, 2)
Equal("off by default", element.last.SetEnabled[1], false)
Equal("and hidden", element.shown, false)

debuffs.filter, debuffs.limit, debuffs.sort, debuffs.reverse, debuffs.enabled = "own", 6, "shortest", true, true
Auras:Configure(widgets, debuffs)
Equal("still one group", #element.groups, 1)
Equal("filter updated", element.groups[1].filter, "HARMFUL|PLAYER")
Equal("limit updated", element.last.SetAuraGroupMaxFrameCount[2], 6)
Equal("sort updated", element.last.SetAuraGroupSortMethod[2] .. "," .. element.last.SetAuraGroupSortMethod[3], "5,1")
Equal("no extra filters", element.last.SetAuraGroupCandidateFilters[2], nil)
Equal("on", element.last.SetEnabled[1], true)
Equal("and shown", element.shown, true)

Auras:Place(widgets, Display("debuffs"), 270, 0, 20)
Equal("anchored below what is there", table.concat({ element.points[1][1], element.points[1][3], element.points[1][5] }, " "),
	"TOPLEFT BOTTOMLEFT -28")
Equal("anchored to the frame", element.points[1][2], frame)
Equal("flow starts at the corner", element.last.SetFlowLayoutAnchorPoint[1], "TOPLEFT")
Equal("flow grows right and down", element.last.SetFlowLayoutGrowthDirection[1] .. ","
	.. element.last.SetFlowLayoutGrowthDirection[2], "1,-1")
Equal("rows wrap at the frame width", element.last.SetFlowLayoutMaximumLineSize[1], 270)

-- Buttons -------------------------------------------------------------------------------------------------

debuffs = Display("debuffs")
Auras:Configure(widgets, debuffs)

local button = Region()

element.CreateButton(element, {}, button)
Equal("button remembered", widgets.buttons[1], button)
Equal("button size", button.last.SetSize[1], 22)
Equal("tooltips on", button.last.SetMouseMotionEnabled[1], true)
Equal("clicks pass through", button.last.SetMouseClickEnabled[1], false)
Equal("reverse swipe", button.Cooldown.last.SetReverse[1], true)
Equal("no swipe edge", button.Cooldown.last.SetDrawEdge[1], false)
Equal("swipe on", button.Cooldown.last.SetDrawSwipe[1], true)
Equal("no countdown numbers", button.Cooldown.last.SetHideCountdownNumbers[1], true)
Equal("cooldown bound", button.last.SetDurationCooldown[1], button.Cooldown)
Equal("icon bound", button.last.SetIcon[1], button.Icon)
Equal("the icon sits one pixel inside the button", button.Icon.points[1][4], 0.5)
Equal("on every side", button.Icon.points[2][5], 0.5)
Equal("the swipe covers the icon alone", button.Cooldown.last.SetAllPoints[1], button.Icon)
Equal("stack bound", button.last.SetApplicationCount[1], button.Count)
Equal("stack has a font before it is bound", button.Count.template, "NumberFontNormal")
Equal("duration has a font before it is bound", button.Time.template, "NumberFontNormal")
Equal("duration bound", button.last.SetDurationText[1], button.Time)
Equal("dispel border", button.last.AddDispelTypeTexture[2].showWhenHarmful, true)
Equal("dispel colors", button.last.AddDispelTypeTexture[2].customDispelColorMap, frame.colors.dispel)
Equal("stack corner", button.Count.points[1][1], "BOTTOMRIGHT")
Equal("stack font", button.Count.last.SetFont[2], 14)
Equal("duration hidden", button.Time.alpha, 0)
Equal("border shown", button.Border.alpha, 1)
Equal("no cancel on debuffs", button.last.SetCancelAuraButtons, nil)

debuffs.size, debuffs.clicks, debuffs.duration, debuffs.border, debuffs.swipe = 30, true, true, false, false
Auras:Configure(widgets, debuffs)
Equal("restyled size", button.last.SetSize[1], 30)
Equal("clicks on", button.last.SetMouseClickEnabled[1], true)
Equal("duration shown", button.Time.alpha, 1)
Equal("border hidden", button.Border.alpha, 0)
Equal("swipe off", button.Cooldown.last.SetDrawSwipe[1], false)

widgets = Auras:Create(frame, "buffs")
Auras:Configure(widgets, Display("buffs"))
button = Region()
widgets.element.CreateButton(widgets.element, {}, button)
Equal("player buffs cancel with a right-click", button.last.SetCancelAuraButtons[1], "RightButtonUp")
Equal("stealable glow on buffs", button.last.AddDispelTypeTexture[2].stealableFilter, 1)
Equal("glow texture", button.Border.last.SetTexture[1], "Interface\\TargetingFrame\\UI-TargetingFrame-Stealable")
frame.key = "target"
widgets = Auras:Create(frame, "buffs")
Auras:Configure(widgets, Display("buffs"))
button = Region()
widgets.element.CreateButton(widgets.element, {}, button)
Equal("no cancel off the player", button.last.SetCancelAuraButtons, nil)

local hasDuration = Display("buffs")
hasDuration.filter = "hasDuration"
Auras:Configure(widgets, hasDuration)
Equal("duration filter", widgets.element.last.SetAuraGroupCandidateFilters[2].maxDuration, math.huge)

-- Player buff categories -----------------------------------------------------------------------------------

local Categories = AUI.AuraCategories

AUI.can.retailSpells = true
Equal("retail offers every category", #Categories:Available(), 11)
Equal("player buffs have category switches, all on", Display("buffs").categories.support, true)
Equal("debuffs have none", Display("debuffs").categories, nil)

local mageSpells = Categories:Spells(nil, "MAGE")
Equal("own defensive for the class", mageSpells[45438], true)
Equal("another class's own defensive left out", mageSpells[871], nil)
Equal("an any-class offensive buff kept", mageSpells[2825], true)
Equal("another class's external kept", mageSpells[6940], true)
Equal("another class's healing kept", mageSpells[774], true)
Equal("a switch turned off leaves its category out", Categories:Spells({ externals = false }, "MAGE")[6940], nil)

for _, category in pairs(Categories:Catalogue()) do
	for id, owner in pairs(category.spells) do
		Equal("retail spell IDs are whole numbers", id == math.floor(id) and id > 0, true)
		Equal("retail owner is a class or ALL", type(owner), "string")
	end
end

AUI.can.retailSpells = false

local forever = Categories:Available()
Equal("forever offers eight categories", #forever, 8)

for _, key in ipairs(forever) do
	Equal("forever has no " .. key .. " left over", key ~= "activeMitigation" and key ~= "lesserHealing" and key ~= "support", true)
end

Equal("forever lists every rank", Categories:Spells(nil, "PRIEST")[10901], true)

for _, key in ipairs(Categories.ORDER) do
	Equal("every category has a switch: " .. key, Schema:Field("frames.player.buffs.categories." .. key) ~= nil, true)
end

AUI.can.retailSpells = true

local playerBuffs = Display("buffs")
playerBuffs.filter = "categories"
playerBuffs.exclude = "45438"

local _, categoryCandidates = Auras:Filter(playerBuffs)
Equal("categories send their spells", categoryCandidates.includeSpellIDs[342246], true)
Equal("never show still applies", categoryCandidates.excludeSpellIDs[45438], true)

io.stdout:write(("check_auras: %d checks passed\n"):format(checks))
