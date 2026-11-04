-- Checks Menus/ outside the game: realm slugs, regions and the sites' URLs; the External Links on player, Battle.net
-- and group finder menus, with secret names and the sites each client offers; the copy box; Guild Invite's targets
-- and the roster; and the module hooking each menu once.
-- Run from any directory with Lua 5.1: lua Tools/check_menus.lua
-- Loads the real files against the shared stub client. Exits non-zero on the first failed check.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"
local client = assert(loadfile(root .. "Tools/stub_client.lua"))({ project = "retail" })
local Equal = client.Equal

-- Environment ---------------------------------------------------------------------------------------------

CLOSE = "Close"
BNET_CLIENT_WOW = "WoW"
SlashCmdList = {}
StaticPopupDialogs = {}
C_AddOns = {
	GetAddOnMetadata = function(_, field)
		return field == "Version" and "dev" or "AeonUI"
	end,
}

function CallErrorHandler(message)
	error(message, 0)
end

local SECRET = client.Secret()

-- Blizzard's menus: each tag keeps the callbacks registered for it, and a menu is a list of what was created on it.
local modifiers = {}
Menu = {
	ModifyMenu = function(tag, callback)
		modifiers[tag] = modifiers[tag] or {}
		table.insert(modifiers[tag], callback)
	end,
}

local function OpenMenu(tag, owner, contextData)
	local menu = { entries = {} }
	function menu:CreateDivider()
		table.insert(self.entries, { kind = "divider" })
	end
	function menu:CreateTitle(text)
		table.insert(self.entries, { kind = "title", text = text })
	end
	function menu:CreateButton(text, onClick)
		table.insert(self.entries, { kind = "button", text = text, onClick = onClick })
	end
	for _, callback in ipairs(modifiers[tag] or {}) do
		callback(owner or {}, menu, contextData)
	end

	return menu
end

local function Texts(menu)
	local texts = {}
	for _, entry in ipairs(menu.entries) do
		texts[#texts + 1] = entry.kind == "divider" and "|" or entry.text
	end

	return table.concat(texts, ",")
end

local function Button(menu, text)
	for _, entry in ipairs(menu.entries) do
		if entry.kind == "button" and entry.text == text then
			return entry
		end
	end
end

-- Units and the world.
local units = {
	target = { name = "Thrall", player = true, friend = true },
	other = { name = "Jaina", realm = "Argent Dawn", player = true, friend = true, guild = "Kirin Tor" },
	npc = { name = "Hogger" },
	hidden = { name = SECRET, player = true, friend = true },
	player = { name = "Me", player = true, friend = true, self = true },
}
function UnitName(unit)
	local info = units[unit]

	return info and info.name, info and info.realm
end

function GetUnitName(unit)
	local info = units[unit]
	if not info then
		return nil
	end
	if info.name == SECRET then
		return SECRET
	end

	return info.realm and (info.name .. "-" .. info.realm:gsub(" ", "")) or info.name
end

function UnitIsPlayer(unit)
	return units[unit] ~= nil and units[unit].player == true
end

function UnitIsUnit(unit, other)
	return other == "player" and units[unit] ~= nil and units[unit].self == true
end

function UnitIsFriend(_, unit)
	return units[unit] ~= nil and units[unit].friend == true
end

function GetGuildInfo(unit)
	return units[unit] and units[unit].guild
end

local region = 3
function GetCurrentRegion()
	return region
end

function GetNormalizedRealmName()
	return "TwistingNether"
end

local friends = {}
C_BattleNet = {
	GetAccountInfoByID = function(id)
		return friends[id]
	end,
}

local applicants, listings = {}, {}
C_LFGList = {
	GetApplicantMemberInfo = function(applicantID, memberIndex)
		return applicants[applicantID .. ":" .. memberIndex]
	end,
	GetSearchResultInfo = function(resultID)
		return listings[resultID]
	end,
}

local roster, canInvite, invited = {}, true, {}
function GetNumGuildMembers()
	return #roster
end

function GetGuildRosterInfo(index)
	return roster[index]
end

function CanGuildInvite()
	return canInvite
end

C_GuildInfo = { Invite = function(name)
	invited[#invited + 1] = name
end }

local popups = {}
function StaticPopup_Show(which, text, _, data)
	popups[#popups + 1] = { which = which, text = text, data = data }
end

function StaticPopup_StandardEditBoxOnEscapePressed() end

-- Addon table ---------------------------------------------------------------------------------------------

local AUI = {}
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
assert(loadfile(root .. "AeonUI/Core/Core.lua"))("AeonUI", AUI)
AUI.can = { playerMenus = true, guildInvite = true, battleNetFriends = true, groupFinderMenus = true,
	raiderIOLinks = true, warcraftLogsLinks = true }

for _, file in ipairs({ "AeonUI/Core/Callbacks.lua", "AeonUI/Core/Events.lua", "AeonUI/Profile/Schema.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

-- Events.lua's frame, the only one these files create.
local eventFrame = client.frames[#client.frames]

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
	values[path] = value
	AUI.Callbacks:Fire("Profile", path)
end

for _, file in ipairs({ "AeonUI_QoL/Menus/Options.lua", "AeonUI_QoL/Menus/Links.lua", "AeonUI_QoL/Menus/GuildInvite.lua", "AeonUI_QoL/Menus/Menus.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Options, GuildInvite = AUI.MenuOptions, AUI.GuildInvite
local raiderIO, warcraftLogs = Options.SITES[1], Options.SITES[2]

-- Arithmetic ----------------------------------------------------------------------------------------------

Equal("a realm written without spaces", Options.Slug("ArgentDawn"), "argent-dawn")
Equal("a realm with spaces and an apostrophe", Options.Slug("Kael'thas Sunstrider"), "kaelthas-sunstrider")
Equal("Cyrillic is lowercased", Options.Slug("Гордунни"), "гордунни")
Equal("a Russian realm in English", Options.EnglishRealm("Гордунни"), "Gordunni")
Equal("an unknown Russian realm has none", Options.EnglishRealm("Неизвестный"), nil)
Equal("other realms stay", Options.EnglishRealm("Silvermoon"), "Silvermoon")
Equal("regions", Options.Region(1) .. Options.Region(2) .. Options.Region(3) .. Options.Region(4) .. Options.Region(5),
	"uskreutwcn")
Equal("an unknown region falls back to Europe", Options.Region(99), "eu")
local name, realm = Options.SplitName("Jaina-ArgentDawn", nil, "Home")
Equal("a name with a realm", name .. " " .. realm, "Jaina ArgentDawn")
name, realm = Options.SplitName("Bob-Azjol-Nerub", nil, "Home")
Equal("a realm with a dash", realm, "Azjol-Nerub")
name, realm = Options.SplitName("Thrall", "Draenor", "Home")
Equal("a server beside the name", realm, "Draenor")
name, realm = Options.SplitName("Thrall", "", "Home")
Equal("no realm is the player's", realm, "Home")
Equal("Raider.IO", raiderIO.Url("eu", "TwistingNether", "Thrall"),
	"https://raider.io/characters/eu/twisting-nether/Thrall")
Equal("Raider.IO uses the English name of a Russian realm", raiderIO.Url("eu", "Гордунни", "Тралл"),
	"https://raider.io/characters/eu/gordunni/Тралл")
Equal("and has no page for an unknown one", raiderIO.Url("eu", "Неизвестный", "Тралл"), nil)
Equal("Warcraft Logs", warcraftLogs.Url("us", "ArgentDawn", "Jaina"),
	"https://www.warcraftlogs.com/character/us/argent-dawn/Jaina")
Equal("Warcraft Logs keeps a Russian realm's own name", warcraftLogs.Url("eu", "Гордунни", "Тралл"),
	"https://www.warcraftlogs.com/character/eu/гордунни/Тралл")
Equal("every entry is on by default", AUI.Profile:Get(Options.GUILD_INVITE_PATH) and AUI.Profile:Get(raiderIO.path)
	and AUI.Profile:Get(warcraftLogs.path), true)

-- Start ---------------------------------------------------------------------------------------------------

AUI.Menus:Start()
AUI.Menus:Start()
Equal("each player menu is hooked once", #modifiers.MENU_UNIT_PLAYER, 2)
Equal("Battle.net friends", #modifiers.MENU_UNIT_BN_FRIEND, 1)
Equal("group finder applicants", #modifiers.MENU_LFG_FRAME_MEMBER_APPLY, 1)
Equal("and listings", #modifiers.MENU_LFG_FRAME_SEARCH_ENTRY, 1)
Equal("guild invite only where an invite fits", modifiers.MENU_UNIT_GUILD ~= nil and #modifiers.MENU_UNIT_GUILD, 1)
Equal("the roster is followed", eventFrame.events.GUILD_ROSTER_UPDATE, true)

-- External Links ------------------------------------------------------------------------------------------

local menu = OpenMenu("MENU_UNIT_PLAYER", nil, { unit = "target" })
Equal("a stranger's menu", Texts(menu), "Guild Invite,|,External Links,Raider.IO,Warcraft Logs")
Button(menu, "Raider.IO").onClick()
Equal("a site's button shows the copy box", popups[#popups].which, "AEONUI_COPY_LINK")
Equal("with the character's page", popups[#popups].data.url, "https://raider.io/characters/eu/twisting-nether/Thrall")
Equal("named for the site", popups[#popups].text, "Raider.IO\nPress Ctrl+C to copy.")

menu = OpenMenu("MENU_UNIT_RAID_PLAYER", nil, { unit = "other" })
Equal("another realm's player keeps their realm", Button(menu, "Warcraft Logs") and true, true)
Button(menu, "Warcraft Logs").onClick()
Equal("in the link", popups[#popups].data.url, "https://www.warcraftlogs.com/character/eu/argent-dawn/Jaina")

Equal("no links for an NPC", Texts(OpenMenu("MENU_UNIT_PLAYER", nil, { unit = "npc" })), "")
Equal("nor for a secret name", Texts(OpenMenu("MENU_UNIT_PARTY", nil, { unit = "hidden" })), "")
Equal("nor without context", Texts(OpenMenu("MENU_UNIT_CHAT_ROSTER", nil, nil)), "")
Equal("your own menu has links but no invite", Texts(OpenMenu("MENU_UNIT_SELF", nil, { unit = "player" })),
	"|,External Links,Raider.IO,Warcraft Logs")

menu = OpenMenu("MENU_UNIT_GUILD", nil, { name = "Varian-Stormrage" })
Button(menu, "Raider.IO").onClick()
Equal("a roster name with its realm", popups[#popups].data.url, "https://raider.io/characters/eu/stormrage/Varian")
menu = OpenMenu("MENU_UNIT_COMMUNITIES_WOW_MEMBER", nil, { name = SECRET })
Equal("a secret roster name adds nothing", Texts(menu), "")

region = 1
menu = OpenMenu("MENU_UNIT_FRIEND", nil, { name = "Anduin", server = "Wyrmrest Accord" })
Button(menu, "Raider.IO").onClick()
Equal("the player's region and the friend's server", popups[#popups].data.url,
	"https://raider.io/characters/us/wyrmrest-accord/Anduin")
region = 3

friends[7] = { gameAccountInfo = { clientProgram = "WoW", wowProjectID = 1, characterName = "Sylvanas",
	realmName = "Silvermoon", regionID = 2 } }
friends[8] = { gameAccountInfo = { clientProgram = "WoW", wowProjectID = 2, characterName = "Elsewhere",
	realmName = "Faerlina", regionID = 1 } }
friends[9] = { gameAccountInfo = { clientProgram = "App" } }
menu = OpenMenu("MENU_UNIT_BN_FRIEND", nil, { bnetIDAccount = 7 })
Button(menu, "Raider.IO").onClick()
Equal("a Battle.net friend in their own region", popups[#popups].data.url,
	"https://raider.io/characters/kr/silvermoon/Sylvanas")
Equal("not on another client's character", Texts(OpenMenu("MENU_UNIT_BN_FRIEND", nil, { bnetIDAccount = 8 })), "")
Equal("nor outside the game", Texts(OpenMenu("MENU_UNIT_BN_FRIEND_OFFLINE", nil, { bnetIDAccount = 9 })), "")

applicants["4:2"] = "Garrosh-Ragnaros"
local application = CreateFrame("Frame")
local row = CreateFrame("Frame", nil, application)
application.applicantID, row.memberIdx = 4, 2
menu = OpenMenu("MENU_LFG_FRAME_MEMBER_APPLY", row, nil)
Button(menu, "Warcraft Logs").onClick()
Equal("an applicant", popups[#popups].data.url, "https://www.warcraftlogs.com/character/eu/ragnaros/Garrosh")
listings[12] = { leaderName = "Tyrande" }
menu = OpenMenu("MENU_LFG_FRAME_SEARCH_ENTRY", { resultID = 12 }, nil)
Button(menu, "Raider.IO").onClick()
Equal("a listing's leader on your realm", popups[#popups].data.url,
	"https://raider.io/characters/eu/twisting-nether/Tyrande")
listings[13] = { leaderName = nil }
Equal("a listing that hides its leader adds nothing",
	Texts(OpenMenu("MENU_LFG_FRAME_SEARCH_ENTRY", { resultID = 13 }, nil)), "")

Set(raiderIO.path, false)
Equal("a site turned off is left out", Texts(OpenMenu("MENU_UNIT_SELF", nil, { unit = "player" })),
	"|,External Links,Warcraft Logs")
Set(warcraftLogs.path, false)
Equal("with none left, no divider or title", Texts(OpenMenu("MENU_UNIT_SELF", nil, { unit = "player" })), "")
Set(raiderIO.path, true)
Set(warcraftLogs.path, true)
AUI.can.raiderIOLinks, AUI.can.warcraftLogsLinks = nil, nil
Equal("a client the sites do not list gets no links", Texts(OpenMenu("MENU_UNIT_SELF", nil, { unit = "player" })), "")
AUI.can.raiderIOLinks, AUI.can.warcraftLogsLinks = true, true

-- Copy box ------------------------------------------------------------------------------------------------

local dialog = StaticPopupDialogs.AEONUI_COPY_LINK
local box
local popup = Mixin(CreateFrame("Frame"), { GetEditBox = function()
	return box
end })
box = CreateFrame("EditBox", nil, popup)
dialog.OnShow(popup, { url = "https://example.test" })
Equal("the box holds the link, selected", box.text .. tostring(box.highlighted), "https://example.testtrue")
box:SetText("typed over")
dialog.EditBoxOnTextChanged(box, { url = "https://example.test" })
Equal("typing puts the link back", box.text, "https://example.test")
Equal("Escape and the button close it", dialog.button1 .. tostring(dialog.hideOnEscape), "Closetrue")

-- Guild Invite --------------------------------------------------------------------------------------------

roster[1] = "Thrall-TwistingNether"
client:Fire("GUILD_ROSTER_UPDATE")
Equal("a guild member gets no invite", Texts(OpenMenu("MENU_UNIT_PLAYER", nil, { unit = "target" })),
	"|,External Links,Raider.IO,Warcraft Logs")
Equal("nor a player in another guild", Button(OpenMenu("MENU_UNIT_PARTY", nil, { unit = "other" }), "Guild Invite"),
	nil)
menu = OpenMenu("MENU_UNIT_FRIEND", nil, { name = "Anduin", server = "WyrmrestAccord" })
Button(menu, "Guild Invite").onClick()
Equal("a chat name is invited with its realm", invited[#invited], "Anduin-WyrmrestAccord")
menu = OpenMenu("MENU_UNIT_FRIEND", nil, { name = "Thrall" })
Equal("a chat name on the roster gets none", Button(menu, "Guild Invite"), nil)
canInvite = false
Equal("without the right to invite there is none",
	Button(OpenMenu("MENU_UNIT_FRIEND", nil, { name = "Anduin" }), "Guild Invite"), nil)
canInvite = true
Set(Options.GUILD_INVITE_PATH, false)
Equal("off: the roster is no longer followed", eventFrame.events.GUILD_ROSTER_UPDATE, nil)
Equal("and no button", Button(OpenMenu("MENU_UNIT_FRIEND", nil, { name = "Anduin" }), "Guild Invite"), nil)
Equal("and the roster is dropped", next(GuildInvite.members), nil)

io.stdout:write(("check_menus: %d checks passed\n"):format(client.checks))
