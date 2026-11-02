-- Checks Automation/ outside the game: the repair funds' arithmetic, the merchant visit (sale, settle, report, repair,
-- the Shift bypass, a merchant closed mid-sale), the expansion filter's windows and its all-expansions retry, the
-- send-mail helpers, the managed game settings with duels, and the module following profile changes.
-- Run from any directory with Lua 5.1: lua Tools/check_automation.lua
-- Loads the real files against stubbed globals. Exits non-zero on the first failed check.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

MONEY = "Money"
SlashCmdList = {}
NUM_BAG_SLOTS = 4
Enum = { ItemQuality = { Poor = 0 }, AuctionHouseFilter = { CurrentExpansionOnly = 9 } }

function CallErrorHandler(message)
	error(message, 0)
end

-- WoW's xpcall forwards extra arguments to the function, as Lua 5.2 does; Lua 5.1's does not.
local luaXpcall = xpcall
function xpcall(fn, handler, ...)
	local count, args = select("#", ...), { ... }

	return luaXpcall(function()
		return fn(unpack(args, 1, count))
	end, handler)
end

-- Timers run only when the check says so.
local timers, nextFrame = {}, {}
C_Timer = {
	NewTimer = function(_, callback)
		local timer = { callback = callback }
		function timer:Cancel()
			self.cancelled = true
		end
		timers[#timers + 1] = timer

		return timer
	end,
	After = function(_, callback)
		nextFrame[#nextFrame + 1] = callback
	end,
}

local function RunTimers()
	local due = timers
	timers = {}
	for _, timer in ipairs(due) do
		if not timer.cancelled then
			timer.callback()
		end
	end
end

local function RunNextFrame()
	local due = nextFrame
	nextFrame = {}
	for _, callback in ipairs(due) do
		callback()
	end
end

local eventFrame
function CreateFrame(kind)
	assert(kind == "Frame", "unexpected frame type " .. tostring(kind))
	local frame = { events = {} }
	function frame:RegisterEvent(event)
		self.events[event] = true
	end
	function frame:UnregisterEvent(event)
		self.events[event] = nil
	end
	function frame:SetScript(_, handler)
		self.onEvent = handler
	end
	eventFrame = frame

	return frame
end

local function Fire(event, ...)
	if eventFrame.events[event] then
		eventFrame.onEvent(eventFrame, event, ...)
	end
end

-- Blizzard's post-hook, on a global function or a table's method.
function hooksecurefunc(object, method, hook)
	if type(object) == "string" then
		object, method, hook = _G, object, method
	end
	local original = object[method]
	object[method] = function(...)
		local results = { original(...) }
		hook(...)

		return unpack(results)
	end
end

-- A frame whose scripts can be hooked and run.
local function ScriptFrame(fields)
	local frame = fields or {}
	frame.hooks = {}
	function frame:HookScript(name, handler)
		self.hooks[name] = self.hooks[name] or {}
		table.insert(self.hooks[name], handler)
	end
	function frame:Run(name)
		for _, handler in ipairs(self.hooks[name] or {}) do
			handler(self)
		end
	end

	return frame
end

local function EditBox(text)
	local box = ScriptFrame({ text = text or "" })
	function box:GetText()
		return self.text
	end
	function box:SetText(value)
		self.text = value
	end
	function box:ClearFocus()
		self.cleared = true
	end

	return box
end

-- Money, bags and the merchant.
local money, shift = 1000, false
function GetMoney()
	return money
end

function IsShiftKeyDown()
	return shift
end

function GetMoneyString(copper)
	return copper .. "c"
end

local junk, sellAllEnabled = 0, true
C_MerchantFrame = {
	GetNumJunkItems = function()
		return junk
	end,
	IsSellAllJunkEnabled = function()
		return sellAllEnabled
	end,
	SellAllJunkItems = function()
		C_MerchantFrame.sold = (C_MerchantFrame.sold or 0) + 1
	end,
}

local bags = {}
C_Container = {
	GetContainerNumSlots = function(bag)
		return bags[bag] and #bags[bag] or 0
	end,
	GetContainerItemInfo = function(bag, slot)
		return bags[bag] and bags[bag][slot]
	end,
	UseContainerItem = function(bag, slot)
		bags[bag][slot].isLocked = true
	end,
}

local repair = { can = true, cost = 500, guild = false, withdraw = 0, bank = 0, calls = {} }
function CanMerchantRepair()
	return repair.can
end

function GetRepairAllCost()
	return repair.cost, repair.cost > 0
end

function CanGuildBankRepair()
	return repair.guild
end

function GetGuildBankWithdrawMoney()
	return repair.withdraw
end

function GetGuildBankMoney()
	return repair.bank
end

function RepairAllItems(guild)
	repair.calls[#repair.calls + 1] = guild and "guild" or "personal"
end

local printed = {}
function print(text)
	printed[#printed + 1] = text
end

-- Game settings.
local cvars = {
	autoLootDefault = "0",
	weatherDensity = "3",
	cameraDistanceMaxZoomFactor = "1.9",
	blockTrades = "0",
	blockChannelInvites = "0",
}
local cvarSets = 0
C_CVar = {
	GetCVarInfo = function(name)
		return cvars[name]
	end,
	GetCVar = function(name)
		return cvars[name]
	end,
	SetCVar = function(name, value)
		cvars[name] = value
		cvarSets = cvarSets + 1
	end,
}

local declineGuild = false
function GetAutoDeclineGuildInvites()
	return declineGuild
end

function SetAutoDeclineGuildInvites(value)
	declineGuild = value
end

local duelsCancelled, popupsHidden = 0, {}
function CancelDuel()
	duelsCancelled = duelsCancelled + 1
end

function StaticPopup_Hide(which)
	popupsHidden[#popupsHidden + 1] = which
end

-- Mail.
SendMailNameEditBox = EditBox("")
SendMailSubjectEditBox = EditBox("")
local copperEntered = 0
SendMailMoney = { gold = ScriptFrame(), silver = ScriptFrame(), copper = ScriptFrame() }
SendMailSendMoneyButton = { checked = true, GetChecked = function(self)
	return self.checked
end }
function MoneyInputFrame_GetCopper()
	return copperEntered
end

function SendMailFrame_SendMail() end

function SendMailFrame_Reset()
	SendMailNameEditBox.text = ""
end

-- The Auction House and crafting orders.
local loadedAddOns = {}
C_AddOns = {
	GetAddOnMetadata = function(_, field)
		return field == "Version" and "dev" or "AeonUI"
	end,
	IsAddOnLoaded = function(name)
		return loadedAddOns[name] == true
	end,
}

local browse = { full = true, results = {} }
C_AuctionHouse = {
	GetFilterGroups = function()
		return { { filters = { 1, 9 } } }
	end,
	HasFullBrowseResults = function()
		return browse.full
	end,
	GetBrowseResults = function()
		return browse.results
	end,
}

AuctionHouseFrameMixin = { Event = { BrowseSearchStarted = "BrowseSearchStarted" } }

local function FilterButton()
	local button = { filters = {} }
	function button:GetFilters()
		return self.filters
	end
	function button:ToggleFilter(filter)
		self.filters[filter] = not self.filters[filter] or nil
	end

	return button
end

-- Addon table ---------------------------------------------------------------------------------------------

local AUI = {}
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
assert(loadfile(root .. "Core/Core.lua"))("AeonUI", AUI)
AUI.can = { mail = true, expansionFilter = true, autoDeclineGuildInvites = true }

for _, file in ipairs({ "Core/Callbacks.lua", "Core/Events.lua", "Profile/Schema.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

-- The profile: the schema's defaults, with the values the check sets.
local values = {}
AUI.Profile = {
	Get = function(_, path)
		local value = values[path]
		if value == nil then
			local field = AUI.Schema:Field(path)
			value = field and field.default
		end

		return value
	end,
}

local function Set(path, value)
	assert(AUI.Schema:CheckValue(path, value), "not a valid value for " .. path)
	values[path] = value
	AUI.Callbacks:Fire("Profile", path)
	RunNextFrame()
end

for _, file in ipairs({ "AeonUI_QoL/Automation/Options.lua", "AeonUI_QoL/Automation/Merchant.lua", "AeonUI_QoL/Automation/ExpansionFilter.lua",
	"AeonUI_QoL/Automation/Mail.lua", "AeonUI_QoL/Automation/GameSettings.lua", "AeonUI_QoL/Automation/Automation.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Options, Merchant, ExpansionFilter = AUI.AutomationOptions, AUI.Merchant, AUI.ExpansionFilter

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

local function LastPrint()
	return (printed[#printed] or ""):gsub("^.-: ", "")
end

-- Arithmetic ----------------------------------------------------------------------------------------------

Equal("no guild limit means the bank", Options.GuildFunds(-1, 900), 900)
Equal("a limit below the bank", Options.GuildFunds(300, 900), 300)
Equal("no guild data is nothing", Options.GuildFunds(nil, 900), 0)
Equal("Guild First uses the guild", Options.ChooseFunds("GUILD_FIRST", 100, true, 200, 0), "guild")
Equal("then falls back to the player", Options.ChooseFunds("GUILD_FIRST", 100, true, 50, 200), "personal")
Equal("Personal never uses the guild", Options.ChooseFunds("PERSONAL", 100, true, 200, 200), "personal")
local source, shortage = Options.ChooseFunds("GUILD_ONLY", 100, true, 50, 500)
Equal("Guild Only never spends the player's money", tostring(source) .. " " .. shortage, "nil guild")
source, shortage = Options.ChooseFunds("PERSONAL", 100, false, 0, 50)
Equal("short of money", tostring(source) .. " " .. shortage, "nil money")
Equal("a managed switch", Options.Wanted("ON") .. Options.Wanted("OFF"), "10")
Equal("a level", Options.Wanted("2"), "2")
Equal("unmanaged holds nothing", Options.Wanted("UNMANAGED"), nil)
Equal("the largest camera distance", Options.Wanted("MAX"), "2.6")
Equal("a value held as written", Options.Holds("1", "1"), true)
Equal("a decimal formatted differently", Options.Holds("2.600000", "2.6"), true)
Equal("a different value", Options.Holds("1.9", "2.6"), false)
Equal("no value", Options.Holds(nil, "2.6"), false)
Equal("one sale", Merchant.SaleReport(1, "5c"), "Sold 1 junk item for 5c.")
Equal("several", Merchant.SaleReport(3, "5c"), "Sold 3 junk items for 5c.")

-- Start ---------------------------------------------------------------------------------------------------

AUI.Automation:Start()
Equal("nothing listens with everything off", eventFrame.events.MERCHANT_SHOW, nil)
Equal("no game setting is touched", cvarSets, 0)
Equal("game changes are not followed", eventFrame.events.CVAR_UPDATE, nil)

-- Merchant ------------------------------------------------------------------------------------------------

Set(Options.SELL_JUNK_PATH, true)
Equal("selling listens for merchants", eventFrame.events.MERCHANT_SHOW, true)

junk = 3
Fire("MERCHANT_SHOW")
Equal("Sell All Junk is used", C_MerchantFrame.sold, 1)
Equal("the sale waits for the money", Merchant.selling, true)
junk, money = 0, 1300
Fire("PLAYER_MONEY")
Equal("no junk left and money in: the sale is over", Merchant.selling, false)
Equal("and reported", LastPrint(), "Sold 3 junk items for 300c.")
Equal("repairing is off, so nothing is repaired", #repair.calls, 0)

Set(Options.REPAIR_PATH, true)
junk = 1
Fire("MERCHANT_SHOW")
money = 1400
RunTimers()
Equal("a quiet sale ends on its timer", Merchant.selling, false)
Equal("then the repair runs from the player's money", repair.calls[#repair.calls], "personal")
Equal("and is reported", LastPrint(), "Repaired for 500c.")

repair.guild, repair.withdraw, repair.bank = true, -1, 10000
junk = 0
Fire("MERCHANT_SHOW")
Equal("with nothing to sell the repair runs at once, from the guild first", repair.calls[#repair.calls], "guild")
Equal("naming guild funds", LastPrint(), "Repaired for 500c from guild funds.")

Set(Options.REPAIR_FUNDS_PATH, "GUILD_ONLY")
repair.bank = 100
local calls = #repair.calls
Fire("MERCHANT_SHOW")
Equal("Guild Only short of guild money repairs nothing", #repair.calls, calls)
Equal("and says why", LastPrint(), "Not enough guild funds to repair (500c).")
Set(Options.REPAIR_FUNDS_PATH, "GUILD_FIRST")

shift = true
junk = 2
local sold = C_MerchantFrame.sold
Fire("MERCHANT_SHOW")
Equal("Shift skips selling", C_MerchantFrame.sold, sold)
Equal("and repairing", #repair.calls, calls)
shift = false

Set(Options.REPORT_SALES_PATH, false)
local printCount = #printed
Fire("MERCHANT_SHOW")
junk, money = 0, money + 50
Fire("MERCHANT_CLOSED")
Equal("closing the merchant ends the sale", Merchant.selling, false)
Equal("without a report while reports are off, and no repair after closing", #printed, printCount)

sellAllEnabled = false
Fire("MERCHANT_SHOW")
Equal("Sell All Junk switched off by the client sells nothing", Merchant.selling, false)
sellAllEnabled = true

C_MerchantFrame.SellAllJunkItems = nil
bags[0] = { { quality = 0 }, { quality = 0, hasNoValue = true }, { quality = 1 } }
Equal("the fallback sells poor items that have a price", #Merchant:FallbackSlots(), 1)
Merchant:StartSale()
Equal("slot by slot", bags[0][1].isLocked, true)
Merchant:StopSale()

Set(Options.SELL_JUNK_PATH, false)
Set(Options.REPAIR_PATH, false)
Equal("both off: merchants are no longer followed", eventFrame.events.MERCHANT_SHOW, nil)

-- Expansion filter ----------------------------------------------------------------------------------------

Equal("a filter the client offers", ExpansionFilter.Offered(C_AuctionHouse.GetFilterGroups(), 9), true)
Equal("one it does not", ExpansionFilter.Offered(C_AuctionHouse.GetFilterGroups(), 7), false)

local filterButton = FilterButton()
local searchBox = { text = "", GetSearchString = function(self)
	return self.text
end }
local searches = 0
AuctionHouseFrame = ScriptFrame({
	SearchBar = {
		FilterButton = filterButton,
		SearchBox = searchBox,
		StartSearch = function()
			searches = searches + 1
		end,
	},
})
function AuctionHouseFrame:RegisterCallback(event, handler)
	self.callbacks = self.callbacks or {}
	self.callbacks[event] = handler
end

local craftingFilters = { filters = {} }
function craftingFilters:ValidateResetState()
	self.validated = true
end
ProfessionsCustomerOrdersFrame = ScriptFrame({ BrowseOrders = { SearchBar = { FilterDropdown = craftingFilters } } })

Set(Options.EXPANSION_FILTER_PATH, true)
Equal("the windows wait for their addons", eventFrame.events.ADDON_LOADED, true)
loadedAddOns.Blizzard_AuctionHouseUI = true
Fire("ADDON_LOADED", "Blizzard_AuctionHouseUI")
loadedAddOns.Blizzard_ProfessionsCustomerOrders = true
Fire("ADDON_LOADED", "Blizzard_ProfessionsCustomerOrders")
Equal("both hooked, the load watch ends", eventFrame.events.ADDON_LOADED, nil)

AuctionHouseFrame:Run("OnShow")
Equal("the Auction House opens filtered", filterButton.filters[9], true)
AuctionHouseFrame:Run("OnShow")
Equal("an already-set filter is left on", filterButton.filters[9], true)

searchBox.text = "Linen"
AuctionHouseFrame.callbacks.BrowseSearchStarted()
Fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
Equal("an empty search runs again", searches, 1)
Equal("with the filter back on for the next", filterButton.filters[9], true)
Equal("and says so", LastPrint(), "Nothing in the current expansion, so all expansions were searched.")
AuctionHouseFrame.callbacks.BrowseSearchStarted()
Fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
Equal("the retry itself is not retried", searches, 1)
AuctionHouseFrame.callbacks.BrowseSearchStarted()
browse.results = { {} }
Fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
Equal("a search with results is not retried", searches, 1)
browse.results = {}

ProfessionsCustomerOrdersFrame:Run("OnShow")
Equal("crafting orders open filtered", craftingFilters.filters[9], true)
Equal("and the dropdown is told", craftingFilters.validated, true)

Set(Options.EXPANSION_AUCTION_HOUSE_PATH, false)
filterButton.filters = {}
AuctionHouseFrame:Run("OnShow")
Equal("the Auction House can be left out", filterButton.filters[9], nil)
Set(Options.EXPANSION_FILTER_PATH, false)
Equal("off: search results are not followed", eventFrame.events.AUCTION_HOUSE_BROWSE_RESULTS_UPDATED, nil)
craftingFilters.filters = {}
ProfessionsCustomerOrdersFrame:Run("OnShow")
Equal("and no window is filtered", craftingFilters.filters[9], nil)

-- Mail ----------------------------------------------------------------------------------------------------

Set(Options.REMEMBER_RECIPIENT_PATH, true)
SendMailNameEditBox.text = "Thrall"
SendMailFrame_SendMail()
SendMailFrame_Reset()
Equal("the recipient comes back after the form resets", SendMailNameEditBox.text, "Thrall")
Equal("without keeping focus", SendMailNameEditBox.cleared, true)

copperEntered = 100
SendMailMoney.gold:Run("OnTextChanged")
Equal("Money Subject off leaves the subject", SendMailSubjectEditBox.text, "")
Set(Options.MONEY_SUBJECT_PATH, true)
SendMailMoney.gold:Run("OnTextChanged")
Equal("gold to send fills an empty subject", SendMailSubjectEditBox.text, "Money")
SendMailSubjectEditBox.text = "Rent"
SendMailMoney.silver:Run("OnTextChanged")
Equal("a subject already written stays", SendMailSubjectEditBox.text, "Rent")
SendMailSubjectEditBox.text = ""
SendMailSendMoneyButton.checked = false
SendMailMoney.copper:Run("OnTextChanged")
Equal("a C.O.D. charge does not name the mail", SendMailSubjectEditBox.text, "")

Set(Options.REMEMBER_RECIPIENT_PATH, false)
SendMailNameEditBox.text = "Jaina"
SendMailFrame_SendMail()
SendMailFrame_Reset()
Equal("off, the form resets as Blizzard's", SendMailNameEditBox.text, "")

-- Game settings -------------------------------------------------------------------------------------------

Set(Options.MANAGED.autoLoot.path, "ON")
Equal("Always On sets the console variable", cvars.autoLootDefault, "1")
Equal("the game's changes are followed", eventFrame.events.CVAR_UPDATE, true)
cvars.autoLootDefault = "0"
Fire("CVAR_UPDATE", "autoLootDefault")
RunNextFrame()
Equal("and put back", cvars.autoLootDefault, "1")
local sets = cvarSets
Fire("CVAR_UPDATE", "weatherDensity")
RunNextFrame()
Equal("an unmanaged change is left alone", cvarSets, sets)

Set(Options.MANAGED.weather.path, "1")
Equal("a level is set", cvars.weatherDensity, "1")

Set(Options.MANAGED.cameraDistance.path, "MAX")
Equal("Maximum sets the largest camera distance", cvars.cameraDistanceMaxZoomFactor, "2.6")
cvars.cameraDistanceMaxZoomFactor = "2.600000"
sets = cvarSets
Fire("CVAR_UPDATE", "cameraDistanceMaxZoomFactor")
RunNextFrame()
Equal("the same distance formatted differently is not set again", cvarSets, sets)
cvars.cameraDistanceMaxZoomFactor = "1.9"
Fire("CVAR_UPDATE", "cameraDistanceMaxZoomFactor")
RunNextFrame()
Equal("a changed distance is put back", cvars.cameraDistanceMaxZoomFactor, "2.6")

Set(Options.MANAGED.guildInvites.path, "ON")
Equal("guild invites are declined", declineGuild, true)
SetAutoDeclineGuildInvites(false)
RunNextFrame()
Equal("and put back when Blizzard's option changes it", declineGuild, true)

Fire("DUEL_REQUESTED")
Equal("duels are left alone while unmanaged", duelsCancelled, 0)
Set(Options.MANAGED.duels.path, "BLOCKED")
Fire("DUEL_TO_THE_DEATH_REQUESTED")
Equal("a blocked duel is declined", duelsCancelled, 1)
RunNextFrame()
Equal("and both prompts hidden", table.concat(popupsHidden, " "), "DUEL_REQUESTED DUEL_TO_THE_DEATH_REQUESTED")

for _, key in ipairs(Options.MANAGED_KEYS) do
	values[Options.MANAGED[key].path] = nil
end
AUI.Callbacks:Fire("Profile", nil)
RunNextFrame()
Equal("a profile with nothing managed stops following the game", eventFrame.events.CVAR_UPDATE, nil)
Equal("and leaves the values as they are", cvars.autoLootDefault, "1")

cvars.weatherDensity = nil
Equal("a console variable the client lacks is unavailable",
	AUI.GameSettings.IsAvailable(Options.MANAGED.weather), false)
values[Options.MANAGED.weather.path] = "2"
AUI.GameSettings:Apply()
Equal("and never set", cvars.weatherDensity, nil)

-- Clients without the features ----------------------------------------------------------------------------

AUI.can.expansionFilter, AUI.can.mail = nil, nil
ExpansionFilter.listening = false
values[Options.EXPANSION_FILTER_PATH] = true
ExpansionFilter:Apply()
Equal("without the filter API nothing is followed", eventFrame.events.AUCTION_HOUSE_BROWSE_RESULTS_UPDATED, nil)

io.stdout:write(("check_automation: %d checks passed\n"):format(checks))
