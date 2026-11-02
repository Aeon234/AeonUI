local AUI = select(2, ...)

local Schema = AUI.Schema

local UNMANAGED = "UNMANAGED"
-- The largest `cameraDistanceMaxZoomFactor` both clients accept.
local CAMERA_DISTANCE_MAX = "2.6"

---The Automation settings and the frame-free arithmetic behind them: which funds pay for a repair, and the value a
---managed game setting holds.
---@class AUIAutomationOptions
---@field SELL_JUNK_PATH string junk is sold when a merchant opens
---@field REPORT_SALES_PATH string a chat line reports each sale
---@field REPAIR_PATH string gear is repaired when a merchant who can repair opens
---@field REPAIR_FUNDS_PATH string a `repairFunds` choice
---@field EXPANSION_FILTER_PATH string Current Expansion Only is turned on as trading windows open (Retail)
---@field EXPANSION_AUCTION_HOUSE_PATH string in the Auction House
---@field EXPANSION_CRAFTING_ORDERS_PATH string in the crafting orders window
---@field REMEMBER_RECIPIENT_PATH string the To field keeps the last recipient after a mail is sent
---@field MONEY_SUBJECT_PATH string an empty subject becomes Money when gold is entered to send
---@field MANAGED table<string, AUIManagedSetting> each managed game setting, by key
---@field MANAGED_KEYS string[] the managed game settings, in the order the page lists them
---@field FUNDS string[]
---@field UNMANAGED string the choice that leaves a game setting to the game
local Options = {
	SELL_JUNK_PATH = "automation.sellJunk",
	REPORT_SALES_PATH = "automation.reportSales",
	REPAIR_PATH = "automation.repair",
	REPAIR_FUNDS_PATH = "automation.repairFunds",
	EXPANSION_FILTER_PATH = "automation.expansionFilter.enabled",
	EXPANSION_AUCTION_HOUSE_PATH = "automation.expansionFilter.auctionHouse",
	EXPANSION_CRAFTING_ORDERS_PATH = "automation.expansionFilter.craftingOrders",
	REMEMBER_RECIPIENT_PATH = "automation.mail.rememberRecipient",
	MONEY_SUBJECT_PATH = "automation.mail.moneySubject",
	-- GUILD_FIRST: guild funds while the guild allows it, otherwise the player's own. GUILD_ONLY: never the player's.
	FUNDS = { "PERSONAL", "GUILD_FIRST", "GUILD_ONLY" },
	UNMANAGED = UNMANAGED,
	MANAGED = {},
	MANAGED_KEYS = {},
}
AUI.AutomationOptions = Options

---A game setting AeonUI can keep the same on every character using the profile.
---@class AUIManagedSetting
---@field key string
---@field path string
---@field list string the choice list: `managedSwitch` (on or off), `managedLevel` (0 to 3), `managedCamera`
---(the largest camera distance) or `managedBlock`
---@field group "game"|"blocks" the card that lists it
---@field cvar string? the console variable it keeps
---@field guild boolean? it keeps the guild-invite auto decline
---@field duel boolean? it declines duel requests

-- Each managed setting without its path, which is added below.
local MANAGED = {
	{ key = "autoLoot", list = "managedSwitch", group = "game", cvar = "autoLootDefault" },
	{ key = "weather", list = "managedLevel", group = "game", cvar = "weatherDensity" },
	{ key = "cameraDistance", list = "managedCamera", group = "game", cvar = "cameraDistanceMaxZoomFactor" },
	{ key = "trades", list = "managedSwitch", group = "blocks", cvar = "blockTrades" },
	{ key = "guildInvites", list = "managedSwitch", group = "blocks", guild = true },
	{ key = "channelInvites", list = "managedSwitch", group = "blocks", cvar = "blockChannelInvites" },
	{ key = "duels", list = "managedBlock", group = "blocks", duel = true },
}

Schema:Choices("repairFunds", Options.FUNDS)
Schema:Choices("managedSwitch", { UNMANAGED, "ON", "OFF" })
Schema:Choices("managedLevel", { UNMANAGED, "0", "1", "2", "3" })
Schema:Choices("managedCamera", { UNMANAGED, "MAX" })
Schema:Choices("managedBlock", { UNMANAGED, "BLOCKED" })

Schema:Boolean(Options.SELL_JUNK_PATH, false)
Schema:Boolean(Options.REPORT_SALES_PATH, true)
Schema:Boolean(Options.REPAIR_PATH, false)
Schema:Choice(Options.REPAIR_FUNDS_PATH, "repairFunds", "GUILD_FIRST")
Schema:Boolean(Options.EXPANSION_FILTER_PATH, false)
Schema:Boolean(Options.EXPANSION_AUCTION_HOUSE_PATH, true)
Schema:Boolean(Options.EXPANSION_CRAFTING_ORDERS_PATH, true)
Schema:Boolean(Options.REMEMBER_RECIPIENT_PATH, false)
Schema:Boolean(Options.MONEY_SUBJECT_PATH, false)

for _, setting in ipairs(MANAGED) do
	setting.path = "automation.game." .. setting.key
	Options.MANAGED[setting.key] = setting
	Options.MANAGED_KEYS[#Options.MANAGED_KEYS + 1] = setting.key
	Schema:Choice(setting.path, setting.list, UNMANAGED)
end

---@param path string one of the paths above
---@return any value
function Options:Get(path)
	return AUI.Profile:Get(path)
end

---Guild money the player may spend on repairs now. A withdrawal limit of -1 means no limit.
---@param withdrawLimit number? `GetGuildBankWithdrawMoney()`
---@param bankMoney number? `GetGuildBankMoney()`
---@return number copper
function Options.GuildFunds(withdrawLimit, bankMoney)
	if not withdrawLimit or not bankMoney then
		return 0
	end

	if withdrawLimit < 0 then
		return bankMoney
	end

	return math.min(withdrawLimit, bankMoney)
end

---Which funds pay for a repair.
---@param funds string a `repairFunds` choice
---@param cost number copper
---@param canGuild boolean the player may repair from the guild bank
---@param guildFunds number copper the guild allows now
---@param money number copper the player has
---@return "guild"|"personal"|nil source
---@return "money"|"guild"|nil shortage what was short when there is no source
function Options.ChooseFunds(funds, cost, canGuild, guildFunds, money)
	if funds ~= "PERSONAL" and canGuild and guildFunds >= cost then
		return "guild"
	end

	if funds == "GUILD_ONLY" then
		return nil, "guild"
	end

	if money >= cost then
		return "personal"
	end

	return nil, "money"
end

---The value a managed console variable should hold.
---@param choice string a `managedSwitch`, `managedLevel` or `managedCamera` choice
---@return string? value nil while the setting is left to the game
function Options.Wanted(choice)
	if choice == "ON" then
		return "1"
	elseif choice == "OFF" then
		return "0"
	elseif choice == "MAX" then
		return CAMERA_DISTANCE_MAX
	elseif choice == UNMANAGED or choice == nil then
		return nil
	end

	return choice
end

---Whether a console variable already holds the wanted value. Numbers compare by value, since the client may format a
---decimal value differently from the string it was set with.
---@param current string? `C_CVar.GetCVar()`
---@param wanted string
---@return boolean
function Options.Holds(current, wanted)
	if current == wanted then
		return true
	end

	local number = tonumber(current)

	return number ~= nil and number == tonumber(wanted)
end
