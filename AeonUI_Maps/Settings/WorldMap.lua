local AUI = select(2, ...)

local L = AUI.L

-- Each marker category's switch label.
local CATEGORY_LABELS = {
	dungeons = DUNGEONS,
	raids = RAIDS,
	worldBosses = L["World Bosses"],
	battlegrounds = BATTLEGROUNDS,
	boats = L["Boats"],
	zeppelins = L["Zeppelins"],
	skyships = L["Skyships"],
	trams = L["Trams"],
	portals = L["Portals"],
	leyLines = L["Ley Lines"],
	convergences = L["Elemental Convergences"],
	zoneExits = L["Zone Exits"],
	innkeepers = L["Innkeepers"],
	mailboxes = L["Mailboxes"],
	spiritHealers = L["Spirit Healers"],
	classTrainers = L["Class Trainers"],
	professionTrainers = L["Profession Trainers"],
	banks = L["Bank & Auction House"],
	repairs = L["Repairs"],
	supplies = L["Reagents, Ammo & Food"],
	stableMasters = L["Stable Masters"],
	vendors = L["Other Vendors"],
}

-- The page's sections of category switches, each listing its categories in order.
local SECTIONS = {
	{ id = "places", title = L["Places"], keys = { "dungeons", "raids", "worldBosses", "battlegrounds", "leyLines",
		"convergences" } },
	{ id = "travel", title = L["Travel"], keys = { "boats", "zeppelins", "skyships", "trams", "portals",
		"zoneExits" } },
	{ id = "town", title = L["Town"], keys = { "innkeepers", "mailboxes", "spiritHealers", "classTrainers",
		"professionTrainers", "banks", "repairs", "supplies", "stableMasters", "vendors" } },
}

---@param category AUIWorldMapCategory
---@return (fun(): boolean)? show offers the category's switch only to the race or class it is for
local function ForPlayer(category)
	if not category.race and not category.class then
		return nil
	end

	return function()
		local module = AUI.WorldMap

		return (not category.race or module.race == category.race)
			and (not category.class or module.class == category.class)
	end
end

---The World Map page, under the Maps header: how Blizzard's world map draws zones, then the markers, headed by their
---switch, with their categories' cards shown while it is on. Changes take effect at once. Left out where there is no
---marker data for the client's world.
---@class AUISettingsWorldMap
---@field pageIDs table<string, true> the World Map page
local SettingsWorldMap = {
	pageIDs = {},
}
AUI.SettingsWorldMap = SettingsWorldMap

---@return boolean
function SettingsWorldMap:IsAvailable()
	return AUI.can.worldMapMarkers == true
end

---The map's own options: unexplored areas, zone labels and dungeon maps.
---@param page table
function SettingsWorldMap:DeclareOptions(page)
	local Settings, Options = AUI.Settings, AUI.WorldMapOptions
	local unexplored = page:Section("unexplored", L["Unexplored Areas"])

	unexplored:Checkbox({
		id = "unexplored",
		label = L["Show Unexplored Areas"],
		description = L["Darkened, instead of left blank."],
		path = Options.UNEXPLORED_PATH,
		default = Settings:Default(Options.UNEXPLORED_PATH),
	})
	unexplored:Slider({
		id = "darkness",
		resettable = true,
		label = L["Darkness"],
		path = Options.DARKNESS_PATH,
		default = Settings:Default(Options.DARKNESS_PATH),
		depends = "unexplored",
		min = 10,
		max = 90,
		step = 5,
		format = "percent",
	})

	local levels = page:Section("levels", L["Zone Labels"])

	levels:Checkbox({
		id = "zoneLevels",
		label = L["Zone Levels"],
		description = L["Adds a zone's level range to its name as you hover it on a continent."],
		path = Options.ZONE_LEVELS_PATH,
		default = Settings:Default(Options.ZONE_LEVELS_PATH),
	})
	levels:Checkbox({
		id = "fishingLevels",
		label = L["Fishing Levels"],
		description = L["Adds the Fishing skill a zone's waters ask for, colored against yours."],
		path = Options.FISHING_LEVELS_PATH,
		default = Settings:Default(Options.FISHING_LEVELS_PATH),
	})

	local dungeons = page:Section("dungeonMaps", L["Dungeon Maps"])

	dungeons:Checkbox({
		id = "dungeonMarkers",
		label = L["Open from Markers"],
		description = L["Left-click a dungeon or raid marker for its floors and bosses."],
		path = Options.DUNGEON_MARKERS_PATH,
		default = Settings:Default(Options.DUNGEON_MARKERS_PATH),
	})
	dungeons:Checkbox({
		id = "dungeonInstances",
		label = L["Open Inside Instances"],
		description = L["Where Blizzard's map has none."],
		path = Options.DUNGEON_INSTANCES_PATH,
		default = Settings:Default(Options.DUNGEON_INSTANCES_PATH),
	})
end

---@param page table
function SettingsWorldMap:DeclareMarkers(page)
	local Settings, Markers = AUI.Settings, AUI.WorldMapMarkers

	local function Shown()
		return AUI.Profile:Get(Markers.ENABLED_PATH) == true
	end

	local display = page:Section("markers")

	display:Toggle({
		id = "markers",
		label = L["Map Markers"],
		description = L["Hover a marker for its name."],
		path = Markers.ENABLED_PATH,
		default = Settings:Default(Markers.ENABLED_PATH),
		-- The categories' cards show only while the markers are on.
		redraws = true,
	})
	display:Checkbox({
		id = "otherFaction",
		label = L["Show Other Faction"],
		description = L["Also marks the other faction's boats, zeppelins, trams and battleground entrances."],
		path = Markers.OTHER_FACTION_PATH,
		default = Settings:Default(Markers.OTHER_FACTION_PATH),
		depends = "markers",
	})
	display:Checkbox({
		id = "capitalsOnly",
		label = L["Vendors and Trainers in Cities Only"],
		description = L["Innkeepers, mailboxes and spirit healers show everywhere."],
		path = Markers.CAPITALS_PATH,
		default = Settings:Default(Markers.CAPITALS_PATH),
		depends = "markers",
	})
	display:Slider({
		id = "markerSize",
		resettable = true,
		label = L["Marker Size"],
		description = L["Markers keep this size on screen as the map zooms, smaller on continent maps."],
		path = Markers.SCALE_PATH,
		default = Settings:Default(Markers.SCALE_PATH),
		min = 50,
		max = 200,
		step = 5,
		format = "percent",
		depends = "markers",
	})
	display:Button({
		id = "forgetSpots",
		label = L["Forget Learned Spots"],
		description = L["Forgets the spots this account found by casting the racial. The shipped spots stay."],
		verb = L["Forget All"],
		confirm = L["Forget every spot this account found?"],
		depends = "markers",
		show = function()
			local race = AUI.WorldMap.race

			for _, category in ipairs(Markers.CATEGORIES) do
				if category.racial and category.race == race then
					return true
				end
			end

			return false
		end,
		blocked = function()
			if not AUI.WorldMapSpots:AnyLearned() then
				return L["No spots found yet."]
			end
		end,
		run = function()
			AUI.WorldMapSpots:ForgetAll()
		end,
	})

	for _, info in ipairs(SECTIONS) do
		local section = page:Section(info.id, info.title, { show = Shown, columns = 2 })

		for _, key in ipairs(info.keys) do
			local path = Markers:CategoryPath(key)

			section:Checkbox({
				id = "marker_" .. key,
				label = CATEGORY_LABELS[key],
				path = path,
				default = Settings:Default(path),
				show = ForPlayer(Markers.byKey[key]),
			})
		end
	end

	local minimap = page:Section("minimap", L["Minimap Pins"], { show = Shown, columns = 2 })
	local MINIMAP_LABELS = { mailboxes = L["Mailboxes"], spiritHealers = L["Spirit Healers"], docks = L["Docks"] }

	for _, entry in ipairs(Markers.MINIMAP) do
		local path = Markers:MinimapPath(entry.key)

		minimap:Checkbox({
			id = "minimap_" .. entry.key,
			label = MINIMAP_LABELS[entry.key],
			path = path,
			default = Settings:Default(path),
		})
	end

end

---@param window table
function SettingsWorldMap:Declare(window)
	local page = window:Page("worldMap", {
		title = WORLDMAP_BUTTON,
		under = "mapsHeader",
		icon = AUI.Media.sidebar.worldMap,
		iconTint = true,
	})

	if not page then
		return
	end

	self.pageIDs.worldMap = true
	self:DeclareOptions(page)
	self:DeclareMarkers(page)
end

AUI.Modules:Register({
	group = "maps",
	page = SettingsWorldMap,
	start = function()
		AUI.WorldMap:Start()
	end,
})
