local AUI = select(2, ...)

local Schema = AUI.Schema

-- `GetCurrentRegion()` and a Battle.net friend's `regionID`, as the sites name them.
local REGIONS = { [1] = "us", [2] = "kr", [3] = "eu", [4] = "tw", [5] = "cn" }

-- Russian realms by their name as the client writes it without spaces, with the English name Raider.IO uses.
local RUSSIAN_REALMS = {
	["Азурегос"] = "Azuregos",
	["Борейскаятундра"] = "Borean Tundra",
	["ВечнаяПесня"] = "Eversong",
	["Галакронд"] = "Galakrond",
	["Голдринн"] = "Goldrinn",
	["Гордунни"] = "Gordunni",
	["Дракономор"] = "Draenor",
	["Король-лич"] = "Lich King",
	["Пиратскаябухта"] = "Pirates' Cove",
	["Разувий"] = "Razuvious",
	["Ревущийфьорд"] = "Howling Fjord",
	["СвежевательДуш"] = "Soulflayer",
	["Седогрив"] = "Greymane",
	["СтражСмерти"] = "Deathguard",
	["Термоштепсель"] = "Thermaplugg",
	["ТкачСмерти"] = "Deathweaver",
	["ЧёрныйШрам"] = "Blackscar",
	["Ясеневыйлес"] = "Ashenvale",
}

---The player-menu settings and the frame-free arithmetic behind the external links: regions, realm slugs and URLs.
---@class AUIMenuOptions
---@field GUILD_INVITE_PATH string a player's right-click menu offers Guild Invite
---@field SITES AUIMenuSite[] the external link sites, in the order the menu lists them
local Options = {
	GUILD_INVITE_PATH = "menus.guildInvite",
	SITES = {},
}
AUI.MenuOptions = Options

---An external site with a page for each character.
---@class AUIMenuSite
---@field key string
---@field label string the site's own name, which the menu and the settings show
---@field path string its setting
---@field can string the `AUI.can` flag that holds where the client has characters the site lists
---@field Url fun(region: string, realm: string, name: string): string? the character's page, or nil when the realm has
---no page there

---Lowercases the Cyrillic capitals of UTF-8 text, which `string.lower` leaves as they are.
---@param text string
---@return string
local function LowerCyrillic(text)
	return (text:gsub("[\208\209][\128-\191]", function(char)
		local first, second = char:byte(1, 2)
		local code = (first - 0xC0) * 0x40 + (second - 0x80)

		if code >= 0x410 and code <= 0x42F then
			code = code + 0x20
		elseif code == 0x401 then
			code = 0x451
		else
			return char
		end

		return string.char(0xC0 + math.floor(code / 0x40), 0x80 + code % 0x40)
	end))
end

---@param realm string a realm as the client writes it, often without spaces ("ArgentDawn")
---@return string slug the realm in lowercase words joined by dashes, apostrophes dropped ("argent-dawn")
function Options.Slug(realm)
	local words = realm:gsub("(%l)(%u)", "%1 %2"):gsub("'", "")

	return (LowerCyrillic(words):lower():gsub("%s+", "-"))
end

---@param realm string
---@return string? english the realm's English name for a Russian realm; the realm itself otherwise; nil for a Russian
---realm with no known English name
function Options.EnglishRealm(realm)
	if realm:find("[\208\209]") then
		return RUSSIAN_REALMS[(realm:gsub("%s+", ""))]
	end

	return realm
end

---@param regionID number?
---@return string region the sites' name for it; a region they do not know falls back to Europe's
function Options.Region(regionID)
	return regionID and REGIONS[regionID] or "eu"
end

---@param name string a character's name, with or without "-Realm"
---@param server string? their realm, when the name has none
---@param ownRealm string the player's realm, for a name with neither
---@return string? name
---@return string? realm
function Options.SplitName(name, server, ownRealm)
	local base, realm = name:match("^(.-)%-(.+)$")

	if not base then
		base, realm = name, (server and server ~= "") and server or ownRealm
	end

	if base == "" or realm == "" then
		return nil
	end

	return base, realm
end

Options.SITES = {
	{
		key = "raiderIO",
		label = "Raider.IO",
		path = "menus.links.raiderIO",
		can = "raiderIOLinks",
		Url = function(region, realm, name)
			local english = Options.EnglishRealm(realm)

			return english and ("https://raider.io/characters/%s/%s/%s"):format(region, Options.Slug(english), name)
		end,
	},
	{
		key = "warcraftLogs",
		label = "Warcraft Logs",
		path = "menus.links.warcraftLogs",
		can = "warcraftLogsLinks",
		Url = function(region, realm, name)
			return ("https://www.warcraftlogs.com/character/%s/%s/%s"):format(region, Options.Slug(realm), name)
		end,
	},
}

Schema:Boolean(Options.GUILD_INVITE_PATH, true)

for _, site in ipairs(Options.SITES) do
	Schema:Boolean(site.path, true)
end

---@param path string
---@return any value
function Options:Get(path)
	return AUI.Profile:Get(path)
end
