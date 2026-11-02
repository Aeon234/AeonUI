local AUI = select(2, ...)

local L = AUI.L

local FUNDS_LABELS = {
	PERSONAL = L["Personal"],
	GUILD_FIRST = L["Guild First"],
	GUILD_ONLY = L["Guild Only"],
}
-- Each managed game setting's label, and its description where it has one.
local MANAGED_LABELS = {
	autoLoot = { label = L["Auto Loot"] },
	weather = { label = L["Weather"] },
	cameraDistance = { label = MAX_FOLLOW_DIST, description = OPTION_TOOLTIP_MAX_FOLLOW_DIST },
	trades = { label = L["Block Trades"] },
	guildInvites = { label = L["Block Guild Invites"] },
	channelInvites = { label = L["Block Channel Invites"] },
	duels = { label = L["Block Duels"], description = L["Includes duels to the death."] },
}
-- The weather levels' names, 0 to 3, as Blizzard's graphics settings name their quality levels.
local WEATHER_LABELS = { [0] = OFF, VIDEO_OPTIONS_LOW, VIDEO_OPTIONS_MEDIUM, VIDEO_OPTIONS_HIGH }

---The Quality of Life header and its Automation page: the merchant visit, mail, the Auction House filter, and game
---settings kept the same on every character using the profile. Changes take effect at once.
---@class AUISettingsAutomation
local SettingsAutomation = {}
AUI.SettingsAutomation = SettingsAutomation

---@param list string a managed choice list
---@return table[] options
local function ManagedOptions(list)
	local options = { { value = AUI.AutomationOptions.UNMANAGED, text = L["Not Managed"] } }

	if list == "managedSwitch" then
		options[2] = { value = "ON", text = L["Always On"] }
		options[3] = { value = "OFF", text = L["Always Off"] }
	elseif list == "managedCamera" then
		options[2] = { value = "MAX", text = MAXIMUM }
	elseif list == "managedBlock" then
		options[2] = { value = "BLOCKED", text = L["Blocked"] }
	else
		for level = 0, 3 do
			options[#options + 1] = { value = tostring(level), text = WEATHER_LABELS[level] }
		end
	end

	return options
end

---@param section table
---@param id string
---@param label string
---@param description string?
---@param path string
---@param depends string?
local function Checkbox(section, id, label, description, path, depends)
	section:Checkbox({
		id = id,
		label = label,
		description = description,
		path = path,
		default = AUI.Settings:Default(path),
		depends = depends,
	})
end

---@param page table
function SettingsAutomation:DeclareMerchant(page)
	local Options = AUI.AutomationOptions
	local merchant = page:Section("automationMerchant", MERCHANT)

	Checkbox(merchant, "sellJunk", L["Sell Junk"], nil, Options.SELL_JUNK_PATH)
	Checkbox(merchant, "reportSales", L["Report Sales"], L["One chat line per visit."], Options.REPORT_SALES_PATH,
		"sellJunk")
	Checkbox(merchant, "autoRepair", L["Auto Repair"], nil, Options.REPAIR_PATH)

	local funds = {}

	for index, value in ipairs(Options.FUNDS) do
		funds[index] = { value = value, text = FUNDS_LABELS[value] }
	end

	merchant:Dropdown({
		id = "repairFunds",
		label = L["Funds"],
		description = L["Guild First falls back to your money; Guild Only doesn't."],
		path = Options.REPAIR_FUNDS_PATH,
		default = AUI.Settings:Default(Options.REPAIR_FUNDS_PATH),
		depends = "autoRepair",
		options = funds,
	})
	merchant:Note(L["Hold Shift as a merchant opens to skip both."])
end

---@param page table
function SettingsAutomation:DeclareMail(page)
	local Options = AUI.AutomationOptions
	local mail = page:Section("automationMail", MAIL_LABEL)

	Checkbox(mail, "rememberRecipient", L["Remember Recipient"], nil, Options.REMEMBER_RECIPIENT_PATH)
	Checkbox(mail, "moneySubject", L["Money Subject"], L["Fills an empty subject with Money when you send gold."],
		Options.MONEY_SUBJECT_PATH)
end

---@param page table
function SettingsAutomation:DeclareAuctionHouse(page)
	local Options = AUI.AutomationOptions
	local auctionHouse = page:Section("automationAuctionHouse", L["Auction House"])

	Checkbox(auctionHouse, "expansionFilter", AUCTION_HOUSE_FILTER_CURRENTEXPANSION_ONLY,
		L["An Auction House search that finds nothing tries every expansion."],
		Options.EXPANSION_FILTER_PATH)
	Checkbox(auctionHouse, "expansionAuctionHouse", L["Auction House"], nil, Options.EXPANSION_AUCTION_HOUSE_PATH,
		"expansionFilter")
	Checkbox(auctionHouse, "expansionCraftingOrders", L["Crafting Orders"], nil,
		Options.EXPANSION_CRAFTING_ORDERS_PATH, "expansionFilter")
end

---The Game Settings and Blocks cards: a dropdown for each managed setting the client has.
---@param page table
function SettingsAutomation:DeclareGameSettings(page)
	local Options = AUI.AutomationOptions
	local sections = {
		game = page:Section("automationGameSettings", L["Game Settings"]),
		blocks = page:Section("automationBlocks", L["Blocks"]),
	}

	for _, key in ipairs(Options.MANAGED_KEYS) do
		local setting, text = Options.MANAGED[key], MANAGED_LABELS[key]

		if text and AUI.GameSettings.IsAvailable(setting) then
			sections[setting.group]:Dropdown({
				id = "managed" .. key,
				label = text.label,
				description = text.description,
				path = setting.path,
				default = AUI.Settings:Default(setting.path),
				options = ManagedOptions(setting.list),
			})
		end
	end
end

---@param window table
function SettingsAutomation:Declare(window)
	local page = window:Page("automation", {
		title = L["Automation"],
		under = "qualityOfLifeHeader",
		icon = AUI.Media.sidebar.automation,
		iconTint = true,
	})

	if not page then
		return
	end

	self:DeclareMerchant(page)

	if AUI.can.mail then
		self:DeclareMail(page)
	end

	if AUI.can.expansionFilter then
		self:DeclareAuctionHouse(page)
	end

	self:DeclareGameSettings(page)
end

AUI.Modules:Register({
	group = "qualityOfLife",
	page = SettingsAutomation,
	start = function()
		AUI.Automation:Start()
	end,
})
