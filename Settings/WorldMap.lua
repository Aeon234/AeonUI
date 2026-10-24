local AUI = select(2, ...)

local L = AUI.L

-- Each marker category's switch label.
local CATEGORY_LABELS = {
	dungeons = DUNGEONS,
}

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
		description = L["Dungeons and other places marked on the world map. Hover a marker for its name."],
		under = "worldMapHeader",
		switch = { path = Markers.ENABLED_PATH, default = Settings:Default(Markers.ENABLED_PATH) },
	})

	if not page then
		return
	end

	self.pageIDs.worldMapMarkers = true

	local markers = page:Section("markers", L["Markers"])

	for _, category in ipairs(Markers.CATEGORIES) do
		local path = Markers:CategoryPath(category.key)

		markers:Checkbox({
			id = "marker_" .. category.key,
			label = CATEGORY_LABELS[category.key],
			path = path,
			default = Settings:Default(path),
		})
	end

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
