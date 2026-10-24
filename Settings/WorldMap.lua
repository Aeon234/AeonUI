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
}

-- The page's sections of category switches, each listing its categories in order.
local SECTIONS = {
	{ id = "places", title = L["Places"], keys = { "dungeons", "raids", "worldBosses", "battlegrounds", "leyLines",
		"convergences" } },
	{ id = "travel", title = L["Travel"], keys = { "boats", "zeppelins", "skyships", "trams", "portals" } },
}

---@param race number? the race a category is for
---@return (fun(): boolean)? show offers the switch only to that race
local function ForRace(race)
	if not race then
		return nil
	end

	return function()
		return AUI.WorldMap.race == race
	end
end

---The World Map header and its pages. Map Markers carries the markers' switch, which takes effect at once. Left out
---where there is no marker data for the client's world.
---@class AUISettingsWorldMap
---@field pageIDs table<string, true> the pages under the World Map header
local SettingsWorldMap = {
	pageIDs = {},
}
AUI.SettingsWorldMap = SettingsWorldMap

---@return boolean
function SettingsWorldMap:IsAvailable()
	return AUI.can.worldMapMarkers == true
end

---@param window table
function SettingsWorldMap:Declare(window)
	local Settings, Markers = AUI.Settings, AUI.WorldMapMarkers

	window:Header("worldMapHeader", WORLDMAP_BUTTON)

	local page = window:Page("worldMapMarkers", {
		title = L["Map Markers"],
		description = L["Dungeons, raids, travel and other places marked on the world map. Hover a marker for its name."],
		under = "worldMapHeader",
		switch = { path = Markers.ENABLED_PATH, default = Settings:Default(Markers.ENABLED_PATH) },
	})

	if not page then
		return
	end

	self.pageIDs.worldMapMarkers = true

	for _, info in ipairs(SECTIONS) do
		local section = page:Section(info.id, info.title)

		for _, key in ipairs(info.keys) do
			local path = Markers:CategoryPath(key)

			section:Checkbox({
				id = "marker_" .. key,
				label = CATEGORY_LABELS[key],
				path = path,
				default = Settings:Default(path),
				show = ForRace(Markers.byKey[key].race),
			})
		end
	end

	local markers = page:Section("display", L["Display"])

	markers:Checkbox({
		id = "otherFaction",
		label = L["Show Other Faction"],
		description = L["Also marks the other faction's boats, zeppelins, trams and battleground entrances."],
		path = Markers.OTHER_FACTION_PATH,
		default = Settings:Default(Markers.OTHER_FACTION_PATH),
	})

	markers:Slider({
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
	})
end
