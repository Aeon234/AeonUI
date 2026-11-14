local AUI = select(2, ...)

local L = AUI.L
local Options, Gear = AUI.CharacterOptions, AUI.CharacterGear

local BLOCK_WIDTH, BLOCK_HEIGHT = 197, 69 -- a category title (40) over the value plate (29)
local VALUE_WIDTH, VALUE_HEIGHT = 187, 29
local LIST_TOP = 8 -- Blizzard's list, below the pane's top
local LIST_INSET_LEFT, LIST_INSET_RIGHT, LIST_INSET_BOTTOM = 10, 30, 30
local EDGE_FADE = 45
local MIN_LEVEL = 10 -- Blizzard's MIN_PLAYER_LEVEL_FOR_ITEM_LEVEL_DISPLAY
local ABOVE = 10 -- frame levels above Blizzard's faded list, whose rows would otherwise take the mouse

---@param elementData table
---@return string
local function Template(elementData)
	if elementData.isHeader then
		return "CharacterStatFrameCategoryScrollBoxElementTemplate"
	elseif elementData.texture or elementData.atlas then
		return "CharacterStatFrameScrollBoxIconElementTemplate"
	end

	return "CharacterStatFrameScrollBoxLabelElementTemplate"
end

local leaveHooked = setmetatable({}, { __mode = "k" }) -- the mirror's row frames whose OnLeave clears the fade

local function ClearFade()
	if AUI.CharacterSlots.fade then
		AUI.CharacterSlots:SetFade(nil)
	end
end

---Blizzard's `Init`, then the feature's additions to a row: its hover (`onEnter`) and the main stat's gold band.
---@param button table
---@param elementData table
local function Initialize(button, elementData)
	button:Init(elementData)

	if elementData.isHeader then
		return
	end

	if elementData.onEnter then
		button.onEnterFunc = elementData.onEnter
	end
	if not leaveHooked[button] then
		leaveHooked[button] = true
		button:HookScript("OnLeave", ClearFade)
	end

	local band, gold = button.Background, NORMAL_FONT_COLOR

	if elementData.band then
		band:Show()
		band:SetVertexColor(gold.r, gold.g, gold.b)
	else
		band:SetVertexColor(1, 1, 1)
	end
end

---Blizzard's stats list: a frame holding `ScrollBox`, `ScrollBar` and the `elementData` its `UpdateStats` fills.
---@return table
local function Pane()
	return CharacterStatsPaneScrollBox --[[@as table]]
end

---The frames the feature adds to the right pane, made once by `Build`.
---@class AUICharacterStatsUI
---@field block Frame the item level block
---@field title table its category title, from Blizzard's template
---@field level Frame its value plate
---@field value FontString
---@field list table the mirror's ScrollBox
---@field bar table the mirror's ScrollBar

---The character panel's right pane: the average item level fixed under Blizzard's sidebar tabs, and over Blizzard's
---stats list a mirror of it. Blizzard's list never reads anything the feature writes, since its rows compare stat
---values that can be secret: the mirror shows copies of Blizzard's elements, read after each `UpdateStats`, plus the
---feature's rows, in its own ScrollBox with Blizzard's row templates, while Blizzard's ScrollBox and ScrollBar sit at
---alpha 0 and keep updating. While unit stats are secret the mirror stands down and Blizzard's list shows.
---@class AUICharacterStats
---@field hooked boolean
---@field on boolean
---@field providers (fun(elements: table[]))[] add rows to the mirror's elements, in registration order
---@field elements table[]? the mirror's elements
---@field ui AUICharacterStatsUI?
local Stats = {
	hooked = false,
	on = false,
	providers = {},
}
AUI.CharacterStats = Stats

---@param elements table[]
---@return table[]
local function Copy(elements)
	local copies = {}

	for index, element in ipairs(elements) do
		local copy = {}

		for key, value in pairs(element) do
			copy[key] = value
		end
		copies[index] = copy
	end

	return copies
end

---@return number? equipped Blizzard's equipped average, empty slots counting as zero
local function Equipped()
	local _, equipped = GetAverageItemLevel()

	return AUI:Readable(equipped)
end

---@param ui AUICharacterStatsUI
local function UpdateBlock(ui)
	local equipped = Equipped()
	local top = LIST_TOP

	if ui.block:IsShown() then
		top = BLOCK_HEIGHT
		ui.value:SetText(equipped and ("%.1f"):format(equipped) or "")
	end

	ui.list:ClearAllPoints()
	ui.list:SetPoint("TOPLEFT", Pane(), "TOPLEFT", LIST_INSET_LEFT, -top)
	ui.list:SetPoint("BOTTOMRIGHT", Pane(), "BOTTOMRIGHT", -LIST_INSET_RIGHT, LIST_INSET_BOTTOM)
end

---Blizzard's item level tooltip, white title and gold note, the note giving the worn items' own average.
---@param owner Frame
function Stats:ShowTooltip(owner)
	local equipped = Equipped()

	if not equipped then
		return
	end

	local average, counted, slots = Options:EquippedAverage(Gear:Summary().levels)

	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(("%s %.1f"):format(STAT_AVERAGE_ITEM_LEVEL, equipped), HIGHLIGHT_FONT_COLOR.r,
		HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	if average then
		GameTooltip:AddLine(L["Equipped items average %.1f (%d of %d slots)"]:format(average, counted, slots),
			NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
	end
	GameTooltip:Show()
end

function Stats:Build()
	if self.ui then
		return
	end

	local pane = Pane()
	local block = CreateFrame("Frame", nil, pane)

	block:SetFrameLevel(pane.ScrollBox:GetFrameLevel() + ABOVE)

	local title = CreateFrame("Frame", nil, block, "CharacterStatFrameCategoryTemplate")

	block:SetSize(BLOCK_WIDTH, BLOCK_HEIGHT)
	block:SetPoint("TOP", pane, "TOP", 0, 0)
	title:SetPoint("TOP", block, "TOP")
	title.Title:SetText(STAT_AVERAGE_ITEM_LEVEL)

	local level = CreateFrame("Frame", nil, block)
	local plate = level:CreateTexture(nil, "BORDER")
	local value = level:CreateFontString(nil, "ARTWORK", "Game15Font_o1")

	level:SetSize(VALUE_WIDTH, VALUE_HEIGHT)
	level:SetPoint("TOP", title, "BOTTOM")
	plate:SetAtlas("UI-Character-Info-ItemLevel-Bounce", true)
	plate:SetPoint("CENTER", level, "CENTER")
	value:SetPoint("CENTER", level, "CENTER", 0, -1)
	level:SetScript("OnEnter", function(frame)
		Stats:ShowTooltip(frame)
	end)
	level:SetScript("OnLeave", GameTooltip_Hide)

	local list = CreateFrame("Frame", nil, pane, "WowScrollBoxList")
	local bar = CreateFrame("EventFrame", nil, pane, "MinimalScrollBar")
	local view = CreateScrollBoxListLinearView(0, LIST_TOP, 0, 0, 0)

	list:SetFrameLevel(pane.ScrollBox:GetFrameLevel() + ABOVE)
	bar:SetFrameLevel(pane.ScrollBar:GetFrameLevel() + ABOVE)
	bar:SetPoint("TOPLEFT", list, "TOPRIGHT", 5, -12)
	bar:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 0, 0)
	view:SetElementFactory(function(factory, elementData)
		factory(Template(elementData), Initialize)
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(list, bar, view)
	list:SetEdgeFadeLength(EDGE_FADE)
	list:RegisterCallback(ScrollBoxListMixin.Event.OnUpdate, self.RemoveHidden, self)
	self.ui = { block = block, title = title, level = level, value = value, list = list, bar = bar }
end

---Drops the copies Blizzard's row `Init` flagged to hide (a stat at its hide value), as Blizzard's list does.
function Stats:RemoveHidden()
	local elements, ui, changed = self.elements, self.ui, false

	if not elements or not ui then
		return
	end

	for index = #elements, 1, -1 do
		if elements[index].shouldRemove then
			table.remove(elements, index)
			changed = true
		end
	end

	if changed then
		ui.list:SetDataProvider(CreateDataProvider(elements), ScrollBoxConstants.RetainScrollPosition)
	end
end

---@param shown boolean the feature's block and mirror, rather than Blizzard's list
function Stats:Show(shown)
	local pane, ui = Pane(), self.ui

	if ui then
		local level = AUI:Readable(UnitLevel("player"), 0) --[[@as number]]
		local average = AUI.Profile:Get(Options.AVERAGE_PATH) == true

		ui.block:SetShown(shown and average and level >= MIN_LEVEL)
		ui.list:SetShown(shown)
		ui.bar:SetShown(shown)
	end
	pane.ScrollBox:SetAlpha(shown and 0 or 1)
	pane.ScrollBar:SetAlpha(shown and 0 or 1)
end

---Rebuilds the mirror from Blizzard's current elements, or hands the pane back to Blizzard while stats are secret.
function Stats:Refresh()
	local source, ui = Pane().elementData, self.ui

	-- A closed pane is rebuilt by Blizzard's own update when it opens.
	if not self.on or not source or not ui or not Pane():IsVisible() then
		return
	end

	-- The interface style has no event, so the Gamepad check runs here as on every paint.
	if C_Secrets.ShouldUnitStatsBeSecret() or not AUI.Character:IsOn() then
		self:Show(false)

		return
	end

	local elements = Copy(source)

	for _, provider in ipairs(self.providers) do
		provider(elements)
	end

	self.elements = elements
	ui.list:SetDataProvider(CreateDataProvider(elements), ScrollBoxConstants.RetainScrollPosition)
	self:Show(true)
	UpdateBlock(ui)
end

---Registers rows for the mirror: `provider` receives the copied elements after each update and inserts its own.
---@param provider fun(elements: table[])
function Stats:AddRows(provider)
	self.providers[#self.providers + 1] = provider
	self:Refresh()
end

---Rebuilds on the next frame: after a restriction change, which applies once the event's dispatch completes, and after
---a durability change, which Blizzard's list does not update for.
function Stats:OnRestrictionChanged()
	AUI.Events:Coalesce("characterStats", function()
		Stats:Refresh()
	end)
end

function Stats:Hook()
	if self.hooked then
		return
	end

	self.hooked = true
	hooksecurefunc(Pane(), "UpdateStats", function()
		Stats:Refresh()
	end)
end

function Stats:Apply()
	if not AUI.Character:IsOn() then
		self:Restore()

		return
	end

	self:Hook()
	self:Build()
	self.on = true
	AUI.Events:Register("ADDON_RESTRICTION_STATE_CHANGED", self, self.OnRestrictionChanged)
	AUI.Events:Register("UPDATE_INVENTORY_DURABILITY", self, self.OnRestrictionChanged)
	self:Refresh()
end

function Stats:Restore()
	if not self.on then
		return
	end

	self.on = false
	AUI.Events:Unregister("ADDON_RESTRICTION_STATE_CHANGED", self)
	AUI.Events:Unregister("UPDATE_INVENTORY_DURABILITY", self)
	AUI.Events:Cancel("characterStats")
	self:Show(false)
end
