local AUI = select(2, ...)

local L = AUI.L

local FUNDS_LABELS = {
	PERSONAL = L["Personal"],
	GUILD_FIRST = L["Guild First"],
	GUILD_ONLY = L["Guild Only"],
}
-- Each managed game setting's label, and its description when it overrides no Blizzard option.
local MANAGED_LABELS = {
	autoLoot = { label = L["Auto Loot"], blizzard = AUTO_LOOT_DEFAULT_TEXT },
	weather = { label = L["Weather"], description = L["The intensity of weather effects, from 0 (none) to 3."] },
	trades = { label = L["Block Trades"], blizzard = BLOCK_TRADES },
	guildInvites = { label = L["Block Guild Invites"], blizzard = BLOCK_GUILD_INVITES },
	channelInvites = { label = L["Block Channel Invites"], blizzard = BLOCK_CHAT_CHANNEL_INVITE },
	duels = { label = L["Block Duels"], description = L["Declines every duel request, including duels to the death."] },
}

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
	elseif list == "managedBlock" then
		options[2] = { value = "BLOCKED", text = L["Blocked"] }
	else
		for level = 0, 3 do
			options[#options + 1] = { value = tostring(level), text = L["Set To %s"]:format(level) }
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

	Checkbox(merchant, "sellJunk", L["Sell Junk"],
		L["Sells your junk when a merchant opens. Hold Shift as the merchant opens to skip it."], Options.SELL_JUNK_PATH)
	Checkbox(merchant, "reportSales", L["Report Sales"],
		L["One chat line per visit with the number of items sold and what they earned."], Options.REPORT_SALES_PATH,
		"sellJunk")
	Checkbox(merchant, "autoRepair", L["Auto Repair"],
		L["Repairs your gear when a merchant who can repair opens. Hold Shift as the merchant opens to skip it."],
		Options.REPAIR_PATH)

	local funds = {}

	for index, value in ipairs(Options.FUNDS) do
		funds[index] = { value = value, text = FUNDS_LABELS[value] }
	end

	merchant:Dropdown({
		id = "repairFunds",
		label = L["Funds"],
		description = L["Guild First uses guild funds while the guild allows it, otherwise your own. Guild Only never spends your own money."],
		path = Options.REPAIR_FUNDS_PATH,
		default = AUI.Settings:Default(Options.REPAIR_FUNDS_PATH),
		depends = "autoRepair",
		options = funds,
	})
end

---@param page table
function SettingsAutomation:DeclareMail(page)
	local Options = AUI.AutomationOptions
	local mail = page:Section("automationMail", MAIL_LABEL)

	Checkbox(mail, "rememberRecipient", L["Remember Recipient"],
		L["Keeps the last recipient in the To field after a mail is sent."], Options.REMEMBER_RECIPIENT_PATH)
	Checkbox(mail, "moneySubject", L["Money Subject"],
		L["Fills an empty subject with Money when you enter gold to send, so a mail with only gold can go."],
		Options.MONEY_SUBJECT_PATH)
end

---@param page table
function SettingsAutomation:DeclareAuctionHouse(page)
	local Options = AUI.AutomationOptions
	local auctionHouse = page:Section("automationAuctionHouse", L["Auction House"])

	Checkbox(auctionHouse, "expansionFilter", AUCTION_HOUSE_FILTER_CURRENTEXPANSION_ONLY,
		L["Turns on Current Expansion Only when the Auction House or the crafting orders window opens. Turning it off by hand lasts until the window closes. An Auction House search that finds nothing runs again across every expansion."],
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
				description = text.blizzard and L["Overrides Blizzard's %s option."]:format(text.blizzard)
					or text.description,
				path = setting.path,
				default = AUI.Settings:Default(setting.path),
				options = ManagedOptions(setting.list),
			})
		end
	end
end

---@param window table
function SettingsAutomation:Declare(window)
	window:Header("qualityOfLifeHeader", L["Quality of Life"])

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
