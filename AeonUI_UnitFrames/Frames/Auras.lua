local AUI = select(2, ...)

local Options = AUI.UnitFrameOptions

-- Space between a frame and its auras.
local GAP = 8

-- How the client selects each category: a filter keyword, a candidate filter field, a dispel type, or a duration.
-- A category is shown by its keyword or a true field, and hidden by the negated keyword or a false field.
local CATEGORIES = {
	important = { keyword = "IMPORTANT" },
	bigDefensive = { keyword = "BIG_DEFENSIVE" },
	externalDefensive = { keyword = "EXTERNAL_DEFENSIVE" },
	raidInCombat = { keyword = "RAID_IN_COMBAT" },
	crowdControl = { keyword = "CROWD_CONTROL" },
	dispellableByYou = { keyword = "RAID" },
	anyDispellable = { keyword = "DISPELLABLE" },
	yours = { keyword = "PLAYER" },
	notYours = { keyword = "PLAYER", negated = true },
	boss = { field = "isBossAura" },
	role = { field = "isRoleAura" },
	stealable = { field = "isStealable" },
	classCanApply = { field = "canApplyAura" },
	magic = { dispel = "Magic" },
	curse = { dispel = "Curse" },
	disease = { dispel = "Disease" },
	poison = { dispel = "Poison" },
	hasDuration = { duration = true },
}

-- Filter modes made of several categories; any other mode is the category of the same name, or all auras.
local MODES = {
	own = { "yours" },
	importantOwn = { "important", "yours" },
}

-- The client's sort for each sort choice.
local SORTS = {
	stable = "AuraInstanceIDOnly",
	shortest = "ExpirationOnly",
	yours = "Default",
	blizzard = "UnitFrameDebuff",
	importance = "ImportantOnly",
	name = "NameOnly",
}

-- Where a display sits against its frame: the container's point, the frame's point, the side, and which way rows
-- stack.
local ANCHORS = {
	aboveLeft = { point = "BOTTOMLEFT", relative = "TOPLEFT", side = "above", growthY = 1 },
	aboveRight = { point = "BOTTOMRIGHT", relative = "TOPRIGHT", side = "above", growthY = 1 },
	belowLeft = { point = "TOPLEFT", relative = "BOTTOMLEFT", side = "below", growthY = -1 },
	belowRight = { point = "TOPRIGHT", relative = "BOTTOMRIGHT", side = "below", growthY = -1 },
	left = { point = "TOPRIGHT", relative = "TOPLEFT", side = "left", growthY = -1 },
	right = { point = "TOPLEFT", relative = "TOPRIGHT", side = "right", growthY = -1 },
}

-- Icons are cropped past their built-in border.
local ICON_CROP = 0.08

---One aura display on a frame: an oUF aura element (a client aura container) with one group, and the buttons the
---client created for it.
---@class AUIAuraWidgets
---@field element table oUF's aura element
---@field kind "buffs"|"debuffs"
---@field frame table the unit frame
---@field group string? the group's key, once added
---@field buttons table[] the buttons created so far, styled again when settings change
---@field settings table? the resolved settings from the last `Configure`

---@class AUIAuras
---@field GAP number
local Auras = {
	GAP = GAP,
}
AUI.Auras = Auras

-- Settings ------------------------------------------------------------------------------------------------

---@param key string
---@param kind "buffs"|"debuffs"
---@return table settings the display's settings
function Auras:Resolve(key, kind)
	local Profile = AUI.Profile
	local base = Options:Path(key, kind .. ".")
	local settings = { key = key, kind = kind }

	for path in pairs(AUI.Schema.fields) do
		if path:sub(1, #base) == base then
			local name = path:sub(#base + 1)
			local group, field = name:match("^(%a+)%.(%w+)$")

			if group then
				settings[group] = settings[group] or {}
				settings[group][field] = Profile:Get(path)
			else
				settings[name] = Profile:Get(path)
			end
		end
	end

	settings.font = Profile:Get(Options:Path(key, "text.font"))
	settings.outline = Profile:Get(Options:Path(key, "text.outline"))

	return settings
end

---@param text string spell IDs separated by commas or spaces
---@return table<integer, true> spells
function Auras:SpellList(text)
	local spells = {}

	for id in (text or ""):gmatch("%d+") do
		spells[tonumber(id) --[[@as integer]]] = true
	end

	return spells
end

---@param text string
---@return string? problem why the text is not a spell list
function Auras:CheckSpellList(text)
	if text:find("[^%d,%s]") then
		return AUI.L["Enter spell IDs separated by commas."]
	end
end

---The client filter string and candidate filters for a display: its filter mode, its hidden categories and its
---spell lists. A display's keywords all apply together, so a mode and the hidden categories narrow each other.
---@param settings table
---@return string filter the client filter string
---@return table? candidateFilters
function Auras:Filter(settings)
	local keywords, seen = { settings.kind == "buffs" and "HELPFUL" or "HARMFUL" }, {}
	local candidates = {}

	local function Add(name, hide)
		local category = CATEGORIES[name] --[[@as table]]

		if category.keyword then
			local negated = (category.negated == true) ~= (hide == true)
			local keyword = (negated and "!" or "") .. category.keyword

			if not seen[keyword] then
				seen[keyword] = true
				keywords[#keywords + 1] = keyword
			end
		elseif category.field then
			candidates[category.field] = not hide
		elseif category.dispel then
			local list = hide and "excludeDispelTypes" or "includeDispelTypes"

			candidates[list] = candidates[list] or {}
			candidates[list][category.dispel] = true
		elseif category.duration and not hide then
			-- A maximum duration also leaves out permanent auras.
			candidates.maxDuration = math.huge
		end
	end

	local mode = settings.filter

	if mode == "tracked" then
		candidates.includeSpellIDs = self:SpellList(settings.include)

		if settings.listCaster == "yours" then
			Add("yours")
		end
	elseif mode == "categories" then
		local _, class = UnitClass("player")

		candidates.includeSpellIDs = AUI.AuraCategories:Spells(settings.categories, AUI:Readable(class))
	end

	for _, name in ipairs(MODES[mode] or { mode }) do
		if CATEGORIES[name] then
			Add(name)
		end
	end

	for _, name in ipairs(settings.kind == "buffs" and Options.BUFF_HIDE or Options.DEBUFF_HIDE) do
		if settings.hide and settings.hide[name] then
			Add(name, true)
		end
	end

	local exclude = self:SpellList(settings.exclude)

	if next(exclude) then
		candidates.excludeSpellIDs = exclude
	end

	return table.concat(keywords, "|"), next(candidates) and candidates or nil
end

---@param settings table
---@return string method an `AuraContainerSortMethod` key
---@return string direction an `AuraContainerSortDirection` key
function Auras:Sort(settings)
	return SORTS[settings.sort] or SORTS.stable, settings.reverse and "Reverse" or "Normal"
end

---How far a frame's own parts reach past its top and bottom. Auras on that side keep clear of them.
---@param key string
---@return number above
---@return number below
function Auras:Clearance(key)
	return AUI.Text:Overhang(key)
end

---@class AUIAuraPlacement
---@field point string the container's point, where its icons start
---@field relative string the frame's point
---@field x number
---@field y number
---@field growthX integer 1 right, -1 left
---@field growthY integer 1 up, -1 down
---@field lineSize number how wide a row may grow before wrapping

---@param settings table
---@param frameWidth number
---@param above number the frame's clearance above
---@param below number the frame's clearance below
---@return AUIAuraPlacement placement
function Auras:Placement(settings, frameWidth, above, below)
	local anchor = ANCHORS[settings.anchor] or ANCHORS.belowLeft
	local x, y = settings.x, settings.y

	if anchor.side == "above" then
		y = y + GAP + above
	elseif anchor.side == "below" then
		y = y - GAP - below
	elseif anchor.side == "left" then
		x = x - GAP
	else
		x = x + GAP
	end

	local lineSize = frameWidth

	if settings.perRow > 0 then
		lineSize = settings.perRow * settings.size + (settings.perRow - 1) * settings.spacing
	end

	return {
		point = anchor.point,
		relative = anchor.relative,
		x = x,
		y = y,
		growthX = settings.growth == "left" and -1 or 1,
		growthY = anchor.growthY,
		lineSize = math.max(lineSize, settings.size),
	}
end

---@param settings table
---@param placement AUIAuraPlacement
---@return integer perRow how many icons fit in a row
function Auras:PerRow(settings, placement)
	local step = settings.size + settings.spacing

	return math.max(1, math.floor((placement.lineSize + settings.spacing) / step))
end

---Where each icon's corner sits against the container's point, row by row, for the settings preview.
---@param settings table
---@param placement AUIAuraPlacement
---@param count integer
---@return table[] offsets `x` and `y` of each icon
function Auras:IconOffsets(settings, placement, count)
	local perRow = self:PerRow(settings, placement)
	local step = settings.size + settings.spacing
	local offsets = {}

	for index = 0, count - 1 do
		local column, row = index % perRow, math.floor(index / perRow)

		offsets[index + 1] = { x = column * step * placement.growthX, y = row * step * placement.growthY }
	end

	return offsets
end

-- Buttons -------------------------------------------------------------------------------------------------

---@param fontString FontString
---@param settings table
---@param size number
local function Font(fontString, settings, size)
	fontString:SetFont(AUI.Media:Font(settings.font), size, AUI.Media:FontFlags(settings.outline))
end

---Gives a client aura button its regions; created once per button, then styled.
---@param widgets AUIAuraWidgets
---@param button table a client aura button
function Auras:CreateButton(widgets, button)
	local edge = button:CreateTexture(nil, "BACKGROUND")

	edge:SetAllPoints()
	edge:SetColorTexture(0, 0, 0, 1)

	local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")

	cooldown:SetReverse(true)
	cooldown:SetDrawEdge(false)
	cooldown:SetHideCountdownNumbers(true)
	button.Cooldown = cooldown
	button:SetDurationCooldown(cooldown)

	local icon = button:CreateTexture(nil, "BORDER")

	icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	button.Icon = icon
	button:SetIcon(icon)
	cooldown:SetAllPoints(icon)

	-- Text sits above the cooldown swipe.
	local text = CreateFrame("Frame", nil, button)

	text:SetAllPoints()
	text:SetFrameLevel(cooldown:GetFrameLevel() + 1)

	-- The client writes into these as soon as they are bound, so they need a font first.
	button.Count = text:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	button.Time = text:CreateFontString(nil, "OVERLAY", "NumberFontNormal")

	local settings = widgets.settings

	if settings then
		Font(button.Count, settings, settings.countSize)
		Font(button.Time, settings, settings.durationSize)
	end

	button:SetApplicationCount(button.Count, {})
	button:SetDurationText(button.Time, {})

	local border = button:CreateTexture(nil, "OVERLAY")

	border:SetAllPoints()
	button.Border = border

	if widgets.kind == "debuffs" then
		button:AddDispelTypeTexture(border, {
			style = Enum.CustomAuraButtonDispelTypeTextureStyle.Border,
			showWhenHarmful = true,
			customDispelColorMap = widgets.frame.colors.dispel,
		})
	else
		border:SetPoint("TOPLEFT", -3, 3)
		border:SetPoint("BOTTOMRIGHT", 3, -3)
		border:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Stealable")
		border:SetBlendMode("ADD")
		button:AddDispelTypeTexture(border, {
			style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
			showWhenHelpful = true,
			showWithoutDispelType = true,
			stealableFilter = Enum.CustomAuraButtonDispelTypeStealableFilter.Stealable,
		})
	end

	if widgets.kind == "buffs" and widgets.frame.key == "player" then
		button:SetCancelAuraButtons("RightButtonUp")
	end

	button:SetTooltipAnchorPoint("ANCHOR_BOTTOMLEFT", 0, 0)
	widgets.buttons[#widgets.buttons + 1] = button
	self:StyleButton(widgets, button)
end

---Applies a display's settings to one of its buttons: size, mouse, swipe, text and border. The icon sits one screen
---pixel inside the button, showing the black behind it as an edge.
---@param widgets AUIAuraWidgets
---@param button table
function Auras:StyleButton(widgets, button)
	local settings = widgets.settings

	if not settings then
		return
	end

	local pixel = AUI:Pixel(button)

	button:SetSize(settings.size, settings.size)
	button.Icon:ClearAllPoints()
	button.Icon:SetPoint("TOPLEFT", button, "TOPLEFT", pixel, -pixel)
	button.Icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -pixel, pixel)
	button:SetMouseMotionEnabled(settings.tooltips)
	button:SetMouseClickEnabled(settings.clicks)
	button.Cooldown:SetDrawSwipe(settings.swipe)

	local count, time = button.Count, button.Time

	Font(count, settings, settings.countSize)
	count:ClearAllPoints()
	count:SetPoint(settings.countCorner, button, settings.countCorner, settings.countX, settings.countY)
	Font(time, settings, settings.durationSize)
	time:ClearAllPoints()
	time:SetPoint("CENTER", button, "CENTER", settings.durationX, settings.durationY)
	time:SetAlpha(settings.duration and 1 or 0)
	button.Border:SetAlpha(settings.border and 1 or 0)
end

-- Displays ------------------------------------------------------------------------------------------------

---Creates a frame's display of one kind; its group is added when settings first apply.
---@param frame table the oUF frame, in its style function
---@param kind "buffs"|"debuffs"
---@return AUIAuraWidgets widgets
function Auras:Create(frame, kind)
	local element = frame:CreateAuras({ layout = AnchorUtil.FlowLayoutAxis.Horizontal })
	local widgets = { element = element, kind = kind, frame = frame, buttons = {} }

	function element.CreateButton(_, _, button)
		Auras:CreateButton(widgets, button)
	end

	return widgets
end

---Applies what the client's container holds: the group's filter, sort, limit and spacing, and every button's style.
---Runs out of combat, when aura access is never restricted.
---@param widgets AUIAuraWidgets
---@param settings table
function Auras:Configure(widgets, settings)
	local element = widgets.element
	local filter, candidates = self:Filter(settings)
	local method, direction = self:Sort(settings)
	local sortMethod, sortDirection = AuraContainerSortMethod[method], AuraContainerSortDirection[direction]
	local layout = {
		elementSpacing = settings.spacing,
		lineSpacing = settings.spacing,
		elementWidth = settings.size,
		elementHeight = settings.size,
	}

	widgets.settings = settings

	if not widgets.group then
		widgets.group = element:AddGroup(filter, {
			maxFrameCount = settings.limit,
			sortMethod = sortMethod,
			sortDirection = sortDirection,
			candidateFilters = candidates,
			layout = layout,
		})
	else
		local group = widgets.group

		element:SetAuraGroupFilterString(group, filter)
		element:SetAuraGroupCandidateFilters(group, candidates)
		element:SetAuraGroupMaxFrameCount(group, settings.limit)
		element:SetAuraGroupSortMethod(group, sortMethod, sortDirection)
		element:SetAuraGroupLayout(group, layout)
	end

	for _, button in ipairs(widgets.buttons) do
		self:StyleButton(widgets, button)
	end

	element:SetEnabled(settings.enabled)
	element:SetShown(settings.enabled)
end

---Places a display against its frame. The container is not protected, so this also runs in combat.
---@param widgets AUIAuraWidgets
---@param settings table
---@param frameWidth number
---@param above number
---@param below number
function Auras:Place(widgets, settings, frameWidth, above, below)
	local element = widgets.element
	local placement = self:Placement(settings, frameWidth, above, below)

	element:ClearAllPoints()
	element:SetPoint(placement.point, widgets.frame, placement.relative, placement.x, placement.y)
	element:SetFlowLayoutAnchorPoint(placement.point)
	element:SetFlowLayoutGrowthDirection(placement.growthX, placement.growthY)
	element:SetFlowLayoutMaximumLineSize(placement.lineSize)
end
