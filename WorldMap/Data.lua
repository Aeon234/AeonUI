local AUI = select(2, ...)

---The world map's marker rows, built on first use. Each category's markers by the uiMapID they are placed on, in
---percent of that map: `{ x, y, instance }`, where `instance` is the instance's map ID. Forever's world.
---@return table<string, table<number, table[]>>
function AUI.WorldMapData()
	return {
		dungeons = {
			[1413] = { { 47.7, 35.0, 43 }, { 42.3, 89.9, 47 }, { 50.9, 92.9, 129 } }, -- The Barrens
			[1416] = { { 8.8, 59.6, 2959 } }, -- Alterac Mountains
			[1418] = { { 35.2, 10.3, 70 }, { 65.4, 43.6, 70 } }, -- Badlands
			[1420] = { { 85.1, 31.4, 189 }, { 63.1, 67.5, 2999 } }, -- Tirisfal Glades
			[1421] = { { 44.7, 67.8, 33 } }, -- Silverpine Forest
			[1422] = { { 69.1, 73.0, 289 } }, -- Western Plaguelands
			[1423] = { { 26.1, 10.4, 329 }, { 43.6, 19.0, 329 } }, -- Eastern Plaguelands
			[1426] = { { 17.7, 39.2, 90 } }, -- Dun Morogh
			[1427] = { { 40.8, 95.6, 229 }, { 27.1, 72.5, 230 } }, -- Searing Gorge
			[1428] = { { 33.0, 25.2, 229 }, { 22.6, 7.5, 230 } }, -- Burning Steppes
			[1435] = { { 77.3, 35.9, 109 } }, -- Swamp of Sorrows
			[1436] = { { 42.5, 71.7, 36 } }, -- Westfall
			[1437] = { { 48.0, 56.0, 2998 } }, -- Wetlands
			[1440] = { { 16.5, 11.0, 48 } }, -- Ashenvale
			[1443] = { { 29.1, 62.9, 349 } }, -- Desolace
			[1444] = { { 62.5, 24.9, 429 }, { 65.0, 29.8, 429 }, { 60.3, 30.3, 429 } }, -- Feralas
			[1446] = { { 38.7, 19.9, 209 } }, -- Tanaris
			[1453] = { { 50.4, 66.2, 34 } }, -- Stormwind City
			[1454] = { { 53.0, 48.9, 389 } }, -- Orgrimmar
			[1455] = { { 28.0, 48.0, 3065 } }, -- Ironforge
		},
	}
end
