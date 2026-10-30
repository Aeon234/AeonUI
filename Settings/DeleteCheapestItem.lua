local AUI = select(2, ...)

local L = AUI.L
local lib = LibStub("LibAeonSettings-1.0")

local PRICE_LABELS = {
	VENDOR = L["Vendor"],
	AUCTION = L["Auction"],
	HIGHER = L["Higher"],
}

-- The ignore list's rows, as the library's other tables draw theirs.
local ROW_HEIGHT, EMPTY_HEIGHT = 40, 44
local CELL_INSET, ICON_SIZE = 20, 22
local REMOVE_WIDTH, REMOVE_HEIGHT = 96, 22
local ROW_LINE = { 1, 1, 1, 0.06 }
local DESCRIPTION_COLOR = { 1, 1, 1, 0.72 }

---The Delete Cheapest Item page, under the Quality of Life header after Automation: the switch, then the Open
---Automatically, List, Access and Ignored Items cards.
---@class AUISettingsDeleteCheapestItem
---@field area Frame? the ignore list's area, made the first time its card shows
---@field setting table? the ignore list's custom row
local SettingsDeleteCheapestItem = {}
AUI.SettingsDeleteCheapestItem = SettingsDeleteCheapestItem

---@param card table
---@param id string
---@param label string
---@param path string
local function Checkbox(card, id, label, path)
	card:Checkbox({ id = id, label = label, path = path, default = AUI.Settings:Default(path) })
end

---@param page table
function SettingsDeleteCheapestItem:DeclareOpen(page)
	local Options = AUI.DeleteCheapestItemOptions
	local card = page:Section("dciOpen", L["Open Automatically"])

	Checkbox(card, "dciBagsFull", L["Loot Doesn't Fit"], Options.OPEN_BAGS_FULL_PATH)
	card:Slider({
		id = "dciFreeSlots",
		label = L["Loot With Few Free Slots"],
		path = Options.OPEN_FREE_SLOTS_PATH,
		default = AUI.Settings:Default(Options.OPEN_FREE_SLOTS_PATH),
		min = 0,
		max = 20,
		step = 1,
		format = function(value)
			return value == 0 and OFF or ("%d"):format(value)
		end,
	})
	Checkbox(card, "dciMerchant", L["Purchase Doesn't Fit"], Options.OPEN_MERCHANT_PATH)
	Checkbox(card, "dciQuest", L["Quest Rewards Don't Fit"], Options.OPEN_QUEST_PATH)
end

---@param page table
function SettingsDeleteCheapestItem:DeclareList(page)
	local Options = AUI.DeleteCheapestItemOptions
	local card = page:Section("dciList", L["List"])
	local qualities, prices = {}, {}

	for index, value in ipairs(Options.QUALITIES) do
		qualities[index] = { value = value, text = _G["ITEM_QUALITY" .. Options.QUALITY[value] .. "_DESC"] or value }
	end

	for index, value in ipairs(Options.PRICES) do
		prices[index] = { value = value, text = PRICE_LABELS[value] }
	end

	card:Dropdown({
		id = "dciMaxQuality",
		label = L["Highest Quality"],
		path = Options.MAX_QUALITY_PATH,
		default = AUI.Settings:Default(Options.MAX_QUALITY_PATH),
		options = qualities,
	})
	card:Dropdown({
		id = "dciPrice",
		label = L["Price"],
		description = AUI.DeleteCheapestItemPrices:Source() == nil and L["Auctionator or TSM provides auction prices."]
			or nil,
		path = Options.PRICE_PATH,
		default = AUI.Settings:Default(Options.PRICE_PATH),
		options = prices,
	})
	Checkbox(card, "dciHideBound", L["Leave Out Soulbound Items"], Options.HIDE_BOUND_PATH)
	Checkbox(card, "dciHideNoValue", L["Leave Out Worthless Items"], Options.HIDE_NO_VALUE_PATH)
end

---@param page table
function SettingsDeleteCheapestItem:DeclareAccess(page)
	local card = page:Section("dciAccess", L["Access"])

	card:Button({
		id = "dciOpenWindow",
		label = L["Open Window"],
		verb = L["Open"],
		run = function()
			AUI.DeleteCheapestItem:Open()
		end,
	})
	card:Button({
		id = "dciKeys",
		label = KEY_BINDINGS,
		description = L["Or type /aui dci."],
		verb = L["Open"],
		run = function()
			AUI.Bindings:Open()
		end,
	})
end

---@param area Frame
---@return Frame row an ignored item's row: its icon, its name in its quality color and a Remove button
local function CreateRow(area)
	local row = CreateFrame("Frame", nil, area)
	local line = row:CreateTexture(nil, "BACKGROUND")

	row:SetHeight(ROW_HEIGHT)
	line:SetColorTexture(ROW_LINE[1], ROW_LINE[2], ROW_LINE[3], ROW_LINE[4])
	line:SetHeight(1)
	line:SetPoint("BOTTOMLEFT")
	line:SetPoint("BOTTOMRIGHT")
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(ICON_SIZE, ICON_SIZE)
	row.icon:SetPoint("LEFT", CELL_INSET, 0)
	row.name = row:CreateFontString(nil, "OVERLAY")
	lib:SetFont(row.name, "body", 14)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 10, 0)
	row.remove = CreateFrame("Button", nil, row, "SharedButtonTemplate")
	row.remove:SetSize(REMOVE_WIDTH, REMOVE_HEIGHT)
	row.remove:SetPoint("RIGHT", -CELL_INSET, 0)
	row.remove:SetText(REMOVE)
	lib:SetFont(row.remove:GetFontString(), "body", 13)
	row.remove:SetScript("OnClick", function()
		AUI.DeleteCheapestItemActions:SetIgnored(row.itemID, false)
		AUI.DeleteCheapestItemWindow:Refresh()
	end)
	row.name:SetPoint("RIGHT", row.remove, "LEFT", -10, 0)

	return row
end

---@param area Frame
---@param setting table
function SettingsDeleteCheapestItem:Create(area, setting)
	self.area, self.setting = area, setting
	area.rows = {}
	area.empty = area:CreateFontString(nil, "OVERLAY")
	lib:SetFont(area.empty, "body", 14)
	area.empty:SetTextColor(DESCRIPTION_COLOR[1], DESCRIPTION_COLOR[2], DESCRIPTION_COLOR[3], DESCRIPTION_COLOR[4])
	area.empty:SetJustifyH("LEFT")
	area.empty:SetPoint("LEFT", CELL_INSET, 0)
	area.empty:SetPoint("RIGHT", -CELL_INSET, 0)
	area.empty:SetText(L["Right-click an item in the window to stop suggesting it."])
	AUI.Callbacks:Register("DeleteCheapestItemIgnored", self, self.Draw)
end

---@return { itemID: integer, name: string, quality: integer, icon: number? }[] items the ignore list, by name
local function IgnoredItems()
	local items = {}

	for _, itemID in ipairs(AUI.DeleteCheapestItemOptions.IgnoredList(AUI.DeleteCheapestItemActions:Ignored() or {})) do
		local name, _, quality = C_Item.GetItemInfo(itemID)

		items[#items + 1] = {
			itemID = itemID,
			name = name or ("item:%d"):format(itemID),
			quality = quality or 1,
			icon = C_Item.GetItemIconByID(itemID),
		}
	end

	table.sort(items, function(a, b)
		return a.name < b.name
	end)

	return items
end

---Draws the ignore list's rows; a list that gains or loses rows lays the page out again.
function SettingsDeleteCheapestItem:Draw()
	local area, setting = self.area, self.setting

	if not area or not setting then
		return
	end

	local items = IgnoredItems()
	local y = 0

	for index, item in ipairs(items) do
		local row = area.rows[index] or CreateRow(area)
		local color = ITEM_QUALITY_COLORS[item.quality] or HIGHLIGHT_FONT_COLOR

		area.rows[index] = row
		row.itemID = item.itemID
		row.icon:SetTexture(item.icon)
		row.name:SetText(item.name)
		row.name:SetTextColor(color.r, color.g, color.b)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 0, -y)
		row:SetPoint("TOPRIGHT", 0, -y)
		row:Show()
		y = y + ROW_HEIGHT
	end

	for index = #items + 1, #area.rows do
		area.rows[index]:Hide()
	end

	area.empty:SetShown(#items == 0)

	if #items == 0 then
		y = EMPTY_HEIGHT
	end

	if y ~= setting.height then
		setting.height = y

		if area:IsVisible() then
			C_Timer.After(0, function()
				setting.window:LayoutPage()
			end)
		end
	end
end

---@param page table
function SettingsDeleteCheapestItem:DeclareIgnored(page)
	local card = page:Section("dciIgnored", L["Ignored Items"])

	card:Custom({
		id = "dciIgnoredItems",
		wide = true,
		height = EMPTY_HEIGHT,
		create = function(area, setting)
			self:Create(area, setting)
		end,
		refresh = function()
			self:Draw()
		end,
	})
end

---@param window table
function SettingsDeleteCheapestItem:Declare(window)
	local Options = AUI.DeleteCheapestItemOptions
	local page = window:Page("deleteCheapestItem", {
		title = L["Delete Cheapest Item"],
		under = "qualityOfLifeHeader",
		icon = AUI.Media.sidebar.deleteCheapestItem,
		iconTint = true,
		switch = {
			path = Options.ENABLED_PATH,
			default = AUI.Settings:Default(Options.ENABLED_PATH),
			label = L["Suggest Items to Delete"],
		},
	})

	if not page then
		return
	end

	self:DeclareOpen(page)
	self:DeclareList(page)
	self:DeclareAccess(page)
	self:DeclareIgnored(page)
end
