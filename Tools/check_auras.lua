-- Checks Frames/Auras.lua outside the game: aura display settings and their defaults, the filter strings and sorts
-- handed to the client, placement against the frame with text and cast bar clearance, row wrapping, the groups
-- added to and updated on oUF's aura element, and button styling.
-- Run from any directory with Lua 5.1: lua Tools/check_auras.lua
-- The client's aura containers are stand-ins that record what AeonUI asks of them; their filtering, sorting and
-- layout are the client's and are not exercised here.

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

	function region:CreateFontString()
		return Region()
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
assert(loadfile(root .. "Core/Core.lua"))("AeonUI", AUI)
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
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

assert(loadfile(root .. "Profile/Schema.lua"))("AeonUI", AUI)
assert(loadfile(root .. "Frames/CastData.lua"))("AeonUI", AUI)
assert(loadfile(root .. "Frames/CastBar.lua"))("AeonUI", AUI)
assert(loadfile(root .. "Frames/Auras.lua"))("AeonUI", AUI)

local Auras, Schema = AUI.Auras, AUI.Schema

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

-- Settings ------------------------------------------------------------------------------------------------

local config = Schema:Defaults()
Equal("no auras on target of target", Auras:Resolve(config, "targettarget", "buffs"), nil)
Equal("no auras on the power bar", Auras:Resolve(config, "playerPower", "debuffs"), nil)

local function Display(key, kind)
	return Auras:Resolve(config, key, kind)
end

local targetBuffs, targetDebuffs = Display("target", "buffs"), Display("target", "debuffs")
Equal("target buffs on", targetBuffs.enabled, true)
Equal("target buffs above left", targetBuffs.anchor, "aboveLeft")
Equal("target buffs limit", targetBuffs.limit, 4)
Equal("target buffs all", targetBuffs.filter, "all")
Equal("target debuffs on", targetDebuffs.enabled, true)
Equal("target debuffs below left", targetDebuffs.anchor, "belowLeft")
Equal("target debuffs limit", targetDebuffs.limit, 20)
Equal("icon size", targetDebuffs.size, 22)
Equal("spacing", targetDebuffs.spacing, 2)
Equal("rows fit the frame", targetDebuffs.perRow, 0)
Equal("stable order", targetDebuffs.sort, "stable")
Equal("tooltips on", targetDebuffs.tooltips, true)
Equal("clicks off", targetDebuffs.clicks, false)
Equal("duration text off", targetDebuffs.duration, false)
Equal("duration size", targetDebuffs.durationSize, 10)
Equal("stack corner", targetDebuffs.countCorner, "BOTTOMRIGHT")
Equal("stack size", targetDebuffs.countSize, 14)
Equal("stack inset", targetDebuffs.countX, -1)
Equal("swipe on", targetDebuffs.swipe, true)
Equal("border on", targetDebuffs.border, true)
Equal("font follows the frame text", targetDebuffs.font, "Expressway")
Equal("player buffs off", Display("player", "buffs").enabled, false)
Equal("player debuffs off", Display("player", "debuffs").enabled, false)
Equal("player debuffs limit", Display("player", "debuffs").limit, 10)
Equal("focus buffs off", Display("focus", "buffs").enabled, false)
Equal("focus debuffs yours", Display("focus", "debuffs").filter, "own")
Equal("boss debuffs on the left side", Display("boss", "debuffs").anchor, "left")
Equal("boss debuffs grow left", Display("boss", "debuffs").growth, "left")
Equal("boss debuffs yours", Display("boss", "debuffs").filter, "own")
Equal("no Has Duration for debuffs", Schema:CheckValue("frames.target.debuffs.filter", "hasDuration"), false)
Equal("Has Duration for buffs", (Schema:CheckValue("frames.target.buffs.filter", "hasDuration")), true)
Equal("no Important OR Own", Schema:CheckValue("frames.target.debuffs.filter", "importantOrOwn"), false)

-- Filters and sorts ---------------------------------------------------------------------------------------

local function Filter(kind, mode)
	local settings = { kind = kind, filter = mode }
	local filter, candidates = Auras:Filter(settings)

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
for _, value in ipairs(Schema.choices.auraSort) do
	Equal(value .. " has a client sort", AuraContainerSortMethod[(Auras:Sort({ sort = value }))] ~= nil, true)
end

-- Placement -----------------------------------------------------------------------------------------------

local function Place(settings, above, below)
	local p = Auras:Placement(settings, 270, above or 0, below or 0)

	return table.concat({ p.point, p.relative, p.x, p.y, p.growthX, p.growthY, p.lineSize }, " ")
end

Equal("above left", Place(targetBuffs), "BOTTOMLEFT TOPLEFT 0 8 1 1 270")
Equal("above clears text", Place(targetBuffs, 6), "BOTTOMLEFT TOPLEFT 0 14 1 1 270")
Equal("below left", Place(targetDebuffs), "TOPLEFT BOTTOMLEFT 0 -8 1 -1 270")
Equal("below clears the cast bar", Place(targetDebuffs, 0, 20), "TOPLEFT BOTTOMLEFT 0 -28 1 -1 270")
local boss = Display("boss", "debuffs")
Equal("left side", Place(boss), "TOPRIGHT TOPLEFT -8 0 -1 -1 270")
boss.anchor, boss.growth = "right", "right"
Equal("right side", Place(boss), "TOPLEFT TOPRIGHT 8 0 1 -1 270")
targetBuffs.anchor, targetBuffs.growth = "aboveRight", "left"
Equal("above right grows left", Place(targetBuffs), "BOTTOMRIGHT TOPRIGHT 0 8 -1 1 270")
targetBuffs.anchor, targetBuffs.x, targetBuffs.y = "belowRight", 5, -3
Equal("offsets", Place(targetBuffs), "TOPRIGHT BOTTOMRIGHT 5 -11 -1 -1 270")
targetDebuffs.perRow = 4
Equal("icons per row", Place(targetDebuffs), "TOPLEFT BOTTOMLEFT 0 -8 1 -1 94")
targetDebuffs.perRow = 0

local placement = Auras:Placement(targetDebuffs, 270, 0, 0)
Equal("icons that fit the frame", Auras:PerRow(targetDebuffs, placement), 11)
placement.lineSize = 10
Equal("always at least one", Auras:PerRow(targetDebuffs, placement), 1)
targetDebuffs.perRow = 4
placement = Auras:Placement(targetDebuffs, 270, 0, 0)
Equal("per row override fits exactly", Auras:PerRow(targetDebuffs, placement), 4)
local offsets = Auras:IconOffsets(targetDebuffs, placement, 6)
Equal("first icon at the corner", offsets[1].x == 0 and offsets[1].y == 0, true)
Equal("fourth icon ends the row", offsets[4].x, 72)
Equal("fifth icon wraps down", offsets[5].x .. "," .. offsets[5].y, "0,-24")
local left = Auras:Placement(Display("boss", "debuffs"), 200, 0, 0)
offsets = Auras:IconOffsets(Display("boss", "debuffs"), left, 9)
Equal("left growth", offsets[2].x, -24)
Equal("rows below", offsets[9].y, -24)
targetDebuffs.perRow = 0

-- Clearance -----------------------------------------------------------------------------------------------

overhang = { 6, 0 }
Equal("text above", (Auras:Clearance(config, "target")), 6)
Equal("cast bar below target", select(2, Auras:Clearance(config, "target")), 20)
Equal("cast bar above focus", (Auras:Clearance(config, "focus")), 26)
Equal("player cast bar takes no frame space", select(2, Auras:Clearance(config, "player")), 0)
Schema:Write(config, "frames.target.castbar.enabled", false)
Equal("no space for a hidden cast bar", select(2, Auras:Clearance(config, "target")), 0)
Schema:Write(config, "frames.target.castbar.enabled", true)
overhang = { 0, 0 }

-- Live displays -------------------------------------------------------------------------------------------

---An oUF aura element stand-in.
local function Element()
	local element = Region()
	element.groups = {}

	function element:AddGroup(filter, options)
		self.groups[#self.groups + 1] = { filter = filter, options = options }

		return "Group" .. #self.groups
	end

	function element:SetAuraGroupFilterString(_, filter)
		self.groups[1].filter = filter
	end

	return element
end

local frame = { key = "target", colors = { dispel = {} } }
function frame:CreateAuras(options)
	self.options = options

	return Element()
end

local widgets = Auras:Create(frame, "debuffs")
local element = widgets.element
Equal("horizontal flow", frame.options.layout, 0)
Equal("no group before settings", #element.groups, 0)

local debuffs = Display("target", "debuffs")
Auras:Configure(widgets, debuffs)
Equal("one group", #element.groups, 1)
Equal("group filter", element.groups[1].filter, "HARMFUL")
Equal("group limit", element.groups[1].options.maxFrameCount, 20)
Equal("group sort", element.groups[1].options.sortMethod, 8)
Equal("group direction", element.groups[1].options.sortDirection, 0)
Equal("group icon size", element.groups[1].options.layout.elementWidth, 22)
Equal("group spacing", element.groups[1].options.layout.elementSpacing, 2)
Equal("row spacing", element.groups[1].options.layout.lineSpacing, 2)
Equal("enabled", element.last.SetEnabled[1], true)

debuffs.filter, debuffs.limit, debuffs.sort, debuffs.reverse = "own", 6, "shortest", true
Auras:Configure(widgets, debuffs)
Equal("still one group", #element.groups, 1)
Equal("filter updated", element.groups[1].filter, "HARMFUL|PLAYER")
Equal("limit updated", element.last.SetAuraGroupMaxFrameCount[2], 6)
Equal("sort updated", element.last.SetAuraGroupSortMethod[2] .. "," .. element.last.SetAuraGroupSortMethod[3], "5,1")
Equal("no extra filters", element.last.SetAuraGroupCandidateFilters[2], nil)
debuffs.enabled = false
Auras:Configure(widgets, debuffs)
Equal("disabled", element.last.SetEnabled[1], false)
Equal("hidden", element.shown, false)

Auras:Place(widgets, Display("target", "debuffs"), 270, 0, 20)
Equal("anchored under the cast bar", table.concat({ element.points[1][1], element.points[1][3], element.points[1][5] }, " "),
	"TOPLEFT BOTTOMLEFT -28")
Equal("anchored to the frame", element.points[1][2], frame)
Equal("flow starts at the corner", element.last.SetFlowLayoutAnchorPoint[1], "TOPLEFT")
Equal("flow grows right and down", element.last.SetFlowLayoutGrowthDirection[1] .. "," .. element.last.SetFlowLayoutGrowthDirection[2],
	"1,-1")
Equal("rows wrap at the frame width", element.last.SetFlowLayoutMaximumLineSize[1], 270)

-- Buttons -------------------------------------------------------------------------------------------------

debuffs = Display("target", "debuffs")
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
Equal("stack bound", button.last.SetApplicationCount[1], button.Count)
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

frame.key = "player"
widgets = Auras:Create(frame, "buffs")
Auras:Configure(widgets, Display("player", "buffs"))
button = Region()
widgets.element.CreateButton(widgets.element, {}, button)
Equal("player buffs cancel with a right-click", button.last.SetCancelAuraButtons[1], "RightButtonUp")
Equal("stealable glow on buffs", button.last.AddDispelTypeTexture[2].stealableFilter, 1)
Equal("glow texture", button.Border.last.SetTexture[1], "Interface\\TargetingFrame\\UI-TargetingFrame-Stealable")
frame.key = "target"
widgets = Auras:Create(frame, "buffs")
Auras:Configure(widgets, Display("target", "buffs"))
button = Region()
widgets.element.CreateButton(widgets.element, {}, button)
Equal("no cancel off the player", button.last.SetCancelAuraButtons, nil)

local hasDuration = Display("target", "buffs")
hasDuration.filter = "hasDuration"
Auras:Configure(widgets, hasDuration)
Equal("duration filter", widgets.element.last.SetAuraGroupCandidateFilters[2].maxDuration, math.huge)

print(("check_auras: %d checks passed"):format(checks))
