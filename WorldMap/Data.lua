local AUI = select(2, ...)

---The world map's marker rows, built on first use. Each category's markers by the uiMapID they are placed on: `x` and
---`y` in percent of that map, then the marker's fields:
--- - `instance`: the instance's map ID, which names it in the client's language;
--- - `name`: the English name, the locale key used where the client has no name for it;
--- - `wing`: which wing or entrance of the instance (a key of the World Map's wing labels);
--- - `levels`: the level range, `{ min, max }`; `players`: a raid's size;
--- - `faction`: "Alliance" or "Horde" for one side's markers; neutral markers have none;
--- - `to`: a transport's destinations, `{ uiMapID, areaID }` with the areaID naming the stop where known;
--- - `race`: the race ID the marker is shown to.
---Zone exits lead to the zone in `to`.
---Forever's world.
---@return table<string, table<number, table[]>>
function AUI.WorldMapData()
	return {
		dungeons = {
			[1413] = { -- The Barrens
				{ 42.3, 89.9, instance = 47, levels = { 29, 38 } },
				{ 46.0, 36.3, instance = 43, levels = { 17, 24 } },
				{ 50.9, 92.9, instance = 129, levels = { 37, 46 } },
			},
			[1416] = { -- Alterac Mountains
				{ 8.8, 59.6, instance = 2959, wing = "sewer", levels = { 28, 33 } },
			},
			[1418] = { -- Badlands
				{ 44.0, 12.0, instance = 70, wing = "main", levels = { 41, 51 } },
				{ 65.4, 43.6, instance = 70, wing = "back", levels = { 41, 51 } },
			},
			[1420] = { -- Tirisfal Glades
				{ 63.1, 67.5, instance = 2999, levels = { 15, 20 } },
				{ 85.1, 31.4, instance = 189, wing = "graveyard", levels = { 26, 36 } },
				{ 83.9, 31.6, instance = 189, wing = "library", levels = { 29, 39 } },
				{ 83.9, 31.6, instance = 189, wing = "cathedral", levels = { 35, 45 } },
				{ 83.9, 31.6, instance = 189, wing = "armory", levels = { 32, 42 } },
			},
			[1421] = { -- Silverpine Forest
				{ 44.7, 67.8, instance = 33, levels = { 22, 30 } },
			},
			[1422] = { -- Western Plaguelands
				{ 69.1, 73.0, instance = 289, levels = { 58, 60 } },
			},
			[1423] = { -- Eastern Plaguelands
				{ 26.1, 10.4, instance = 329, wing = "gate", levels = { 58, 60 } },
				{ 43.6, 19.0, instance = 329, wing = "service", levels = { 58, 60 } },
			},
			[1426] = { -- Dun Morogh
				{ 17.7, 39.2, instance = 90, levels = { 29, 38 } },
				{ 21.6, 30.0, instance = 90, levels = { 29, 38 } },
			},
			[1427] = { -- Searing Gorge
				{ 40.8, 95.6, instance = 229, wing = "upper", levels = { 55, 60 } },
				{ 41.1, 95.3, instance = 229, wing = "lower", levels = { 55, 60 } },
				{ 27.1, 72.5, instance = 230, levels = { 52, 60 } },
			},
			[1428] = { -- Burning Steppes
				{ 33.0, 25.2, instance = 229, wing = "upper", levels = { 55, 60 } },
				{ 32.0, 39.0, instance = 229, wing = "lower", levels = { 55, 60 } },
				{ 22.6, 7.5, instance = 230, levels = { 52, 60 } },
			},
			[1434] = { -- Stranglethorn Vale
				{ 21.4, 27.9, levels = { 35, 40 }, name = "The Drowned City" },
			},
			[1435] = { -- Swamp of Sorrows
				{ 69.6, 53.7, instance = 109, levels = { 50, 60 } },
			},
			[1436] = { -- Westfall
				{ 43.2, 72.4, instance = 36, levels = { 17, 26 } },
			},
			[1437] = { -- Wetlands
				{ 53.4, 65.3, instance = 2998, levels = { 24, 29 } },
			},
			[1440] = { -- Ashenvale
				{ 13.9, 14.3, instance = 48, levels = { 24, 32 } },
			},
			[1441] = { -- Thousand Needles
				{ 12.2, 66.7, instance = 3001, levels = { 58, 60 } },
			},
			[1443] = { -- Desolace
				{ 29.1, 62.9, instance = 349, levels = { 46, 55 } },
			},
			[1444] = { -- Feralas
				{ 60.3, 30.3, instance = 429, wing = "west", levels = { 55, 60 } },
				{ 62.5, 24.9, instance = 429, wing = "north", levels = { 55, 60 } },
				{ 65.0, 29.8, instance = 429, wing = "east", levels = { 55, 60 } },
				{ 67.1, 34.0, instance = 429, wing = "east", levels = { 55, 60 } },
				{ 77.1, 36.9, instance = 429, wing = "east", levels = { 55, 60 } },
			},
			[1445] = { -- Dustwallow Marsh
				{ 75.0, 14.0, instance = 2994, levels = { 48, 53 } },
			},
			[1446] = { -- Tanaris
				{ 38.7, 19.9, instance = 209, levels = { 44, 54 } },
			},
			[1447] = { -- Azshara
				{ 38.0, 32.4, levels = { 55, 60 }, name = "Blackmaw Hold" },
			},
			[1449] = { -- Un'Goro Crater
				{ 42.6, 6.1, instance = 3001, levels = { 58, 60 } },
			},
			[1453] = { -- Stormwind City
				{ 50.4, 66.2, instance = 34, levels = { 24, 32 } },
			},
			[1454] = { -- Orgrimmar
				{ 53.2, 48.7, instance = 389, levels = { 13, 18 } },
			},
			[1455] = { -- Ironforge
				{ 43.0, 51.0, instance = 3065, levels = { 13, 18 } },
			},
			[1458] = { -- Undercity
				{ 71.6, 11.4, instance = 2999, levels = { 15, 20 } },
			},
			[2548] = { -- Riverglades
				{ 37.9, 37.6, levels = { 40, 45 }, name = "Krol'dok Stronghold" },
			},
		},
		raids = {
			[1427] = { -- Searing Gorge
				{ 33.2, 83.3, instance = 469, levels = { 60, 60 }, players = 40, name = "Blackwing Lair" },
				{ 33.2, 86.0, instance = 409, levels = { 60, 60 }, players = 40, name = "Molten Core" },
			},
			[1428] = { -- Burning Steppes
				{ 27.3, 36.3, instance = 469, levels = { 60, 60 }, players = 40, name = "Blackwing Lair" },
				{ 27.3, 39.0, instance = 409, levels = { 60, 60 }, players = 40, name = "Molten Core" },
			},
			[1434] = { -- Stranglethorn Vale
				{ 53.0, 17.2, instance = 309, levels = { 60, 60 }, players = 20, name = "Zul'Gurub" },
			},
			[1445] = { -- Dustwallow Marsh
				{ 52.9, 78.2, instance = 249, levels = { 60, 60 }, players = 40 },
			},
			[1451] = { -- Silithus
				{ 26.9, 98.7, instance = 531, levels = { 60, 60 }, players = 40, name = "Temple of Ahn'Qiraj" },
				{ 30.5, 98.7, instance = 509, levels = { 60, 60 }, players = 20, name = "Ruins of Ahn'Qiraj" },
			},
			[1452] = { -- Winterspring
				{ 50.3, 47.9, instance = 3052, levels = { 60, 60 }, players = 10 },
			},
			[2482] = { -- Mt. Hyjal
				{ 70.1, 62.0, instance = 3052, levels = { 60, 60 }, players = 10 },
				{ 85.3, 33.0, instance = 2981, levels = { 60, 60 }, players = 20 },
			},
		},
		worldBosses = {
			[1425] = { -- The Hinterlands
				{ 63.2, 21.7, levels = { 60, 60 }, name = "Emerald Dragon" },
			},
			[1431] = { -- Duskwood
				{ 46.5, 35.7, levels = { 60, 60 }, name = "Emerald Dragon" },
			},
			[1440] = { -- Ashenvale
				{ 93.7, 35.5, levels = { 60, 60 }, name = "Emerald Dragon" },
			},
			[1444] = { -- Feralas
				{ 51.2, 10.8, levels = { 60, 60 }, name = "Emerald Dragon" },
			},
			[1447] = { -- Azshara
				{ 53.5, 81.6, levels = { 60, 60 }, name = "Azuregos" },
			},
		},
		battlegrounds = {
			[1413] = { -- The Barrens
				{ 43.0, 10.0, instance = 489, faction = "Horde", name = "Warsong Gulch" },
				{ 64.3, 33.3, faction = "Horde", name = "Darkspear Islands" },
			},
			[1416] = { -- Alterac Mountains
				{ 39.7, 79.7, instance = 30, faction = "Alliance", name = "Alterac Valley" },
				{ 64.1, 58.4, instance = 30, faction = "Horde", name = "Alterac Valley" },
			},
			[1417] = { -- Arathi Highlands
				{ 46.0, 47.0, instance = 529, faction = "Alliance", name = "Arathi Basin" },
				{ 74.0, 34.0, instance = 529, faction = "Horde", name = "Arathi Basin" },
			},
			[1440] = { -- Ashenvale
				{ 62.0, 83.0, instance = 489, faction = "Alliance", name = "Warsong Gulch" },
			},
			[1445] = { -- Dustwallow Marsh
				{ 54.3, 8.1, faction = "Alliance", name = "Darkspear Islands" },
			},
		},
		boats = {
			[1413] = { -- The Barrens
				{ 63.8, 38.8, to = { { 1434, 35 } } },
			},
			[1424] = { -- Hillsbrad Foothills
				{ 50.7, 70.4, faction = "Alliance", to = { { 1439, 442 }, { 1437 } } },
			},
			[1434] = { -- Stranglethorn Vale
				{ 25.7, 73.1, to = { { 1413, 392 } } },
			},
			[1437] = { -- Wetlands
				{ 4.6, 57.1, faction = "Alliance", to = { { 1424, 271 }, { 1439 } } },
				{ 5.0, 63.5, faction = "Alliance", to = { { 1445, 513 } } },
			},
			[1438] = { -- Teldrassil
				{ 55.2, 95.0, faction = "Alliance", to = { { 1439, 442 } } },
			},
			[1439] = { -- Darkshore
				{ 30.5, 40.9, faction = "Alliance", to = { { 1453, 17203 } } },
				{ 32.4, 43.8, faction = "Alliance", to = { { 1437, 150 }, { 1424 } } },
				{ 33.3, 39.8, faction = "Alliance", to = { { 1438, 702 } } },
			},
			[1444] = { -- Feralas
				{ 31.0, 39.5, faction = "Alliance", to = { { 1444, 1108 } } },
				{ 43.1, 42.8, faction = "Alliance", to = { { 1444, 1116 } } },
			},
			[1445] = { -- Dustwallow Marsh
				{ 71.7, 56.7, faction = "Alliance", to = { { 1437, 150 } } },
			},
			[1446] = { -- Tanaris
				{ 69.0, 23.0, to = { { 2548, 16727 } } },
			},
			[1453] = { -- Stormwind City
				{ 22.0, 57.0, faction = "Alliance", to = { { 1439, 442 } } },
			},
			[2548] = { -- Riverglades
				{ 79.0, 52.3, to = { { 1446, 977 } } },
			},
		},
		zeppelins = {
			[1411] = { -- Durotar
				{ 51.2, 13.4, faction = "Horde", to = { { 1420, 1497 }, { 1434, 117 } } },
			},
			[1420] = { -- Tirisfal Glades
				{ 61.3, 58.6, faction = "Horde", to = { { 1411, 1637 }, { 1434, 117 } } },
			},
			[1434] = { -- Stranglethorn Vale
				{ 31.4, 29.8, faction = "Horde", to = { { 1420, 1497 }, { 1411, 1637 } } },
			},
		},
		skyships = {
			[1412] = { -- Mulgore
				{ 34.3, 25.8, faction = "Horde", to = { { 2521, 16628 } } },
			},
			[1416] = { -- Alterac Mountains
				{ 12.5, 51.8, faction = "Alliance", to = { { 2521, 16628 } } },
			},
			[2521] = { -- Zephras Isle
				{ 58.0, 81.0, faction = "Horde", to = { { 1412, 17045 } } },
				{ 65.8, 83.8, faction = "Alliance", to = { { 1416, 279 } } },
			},
		},
		trams = {
			[1453] = { -- Stormwind City
				{ 69.4, 30.5, faction = "Alliance", to = { { 1455, 1537 } } },
			},
			[1455] = { -- Ironforge
				{ 76.6, 51.2, faction = "Alliance", to = { { 1453, 1519 } } },
			},
		},
		portals = {
			[1416] = { -- Alterac Mountains
				{ 12.0, 56.2, faction = "Alliance", to = { { 1453 } }, race = 95 },
			},
			[1453] = { -- Stormwind City
				{ 50.0, 87.0, faction = "Alliance", to = { { 1416, 279 } }, race = 95 },
			},
		},
		leyLines = {
			[1413] = { -- The Barrens
				{ 44.3, 16.0, race = 95 },
				{ 44.6, 90.4, race = 95 },
				{ 46.7, 39.2, race = 95 },
				{ 46.8, 82.7, race = 95 },
				{ 48.6, 24.1, race = 95 },
				{ 48.9, 36.3, race = 95 },
				{ 51.7, 48.5, race = 95 },
				{ 55.8, 34.2, race = 95 },
				{ 56.8, 24.0, race = 95 },
				{ 57.4, 51.0, race = 95 },
				{ 59.1, 39.6, race = 95 },
			},
			[1416] = { -- Alterac Mountains
				{ 19.9, 86.1, race = 95 },
			},
			[1417] = { -- Arathi Highlands
				{ 25.3, 30.0, race = 95 },
				{ 48.0, 60.5, race = 95 },
			},
			[1426] = { -- Dun Morogh
				{ 38.4, 38.8, race = 95 },
				{ 45.9, 44.2, race = 95 },
				{ 56.6, 45.6, race = 95 },
				{ 63.8, 50.7, race = 95 },
				{ 76.8, 51.9, race = 95 },
			},
			[1428] = { -- Burning Steppes
				{ 78.6, 61.8, race = 95 },
			},
			[1429] = { -- Elwynn Forest
				{ 27.4, 94.3, race = 95 },
				{ 37.3, 55.5, race = 95 },
				{ 38.4, 73.6, race = 95 },
				{ 64.9, 67.3, race = 95 },
				{ 75.2, 51.9, race = 95 },
				{ 84.7, 75.7, race = 95 },
			},
			[1431] = { -- Duskwood
				{ 18.7, 57.2, race = 95 },
				{ 25.7, 34.7, race = 95 },
				{ 34.1, 70.9, race = 95 },
				{ 62.8, 74.2, race = 95 },
				{ 72.5, 30.6, race = 95 },
				{ 78.2, 35.8, race = 95 },
			},
			[1432] = { -- Loch Modan
				{ 49.3, 25.0, race = 95 },
			},
			[1433] = { -- Redridge Mountains
				{ 12.6, 72.8, race = 95 },
				{ 19.6, 51.5, race = 95 },
				{ 30.2, 55.0, race = 95 },
				{ 31.0, 46.1, race = 95 },
				{ 55.0, 64.7, race = 95 },
				{ 65.4, 74.8, race = 95 },
				{ 68.5, 44.3, race = 95 },
			},
			[1436] = { -- Westfall
				{ 35.0, 73.0, race = 95 },
				{ 42.4, 25.2, race = 95 },
				{ 46.0, 20.0, race = 95 },
				{ 46.3, 59.0, race = 95 },
				{ 51.1, 67.5, race = 95 },
				{ 51.3, 22.5, race = 95 },
				{ 59.8, 31.5, race = 95 },
				{ 41.9, 83.3, race = 95 },
			},
			[1437] = { -- Wetlands
				{ 14.7, 37.3, race = 95 },
				{ 40.2, 38.6, race = 95 },
				{ 46.3, 25.3, race = 95 },
				{ 53.8, 64.5, race = 95 },
				{ 55.0, 29.7, race = 95 },
				{ 56.2, 63.9, race = 95 },
				{ 69.0, 36.5, race = 95 },
			},
			[1439] = { -- Darkshore
				{ 36.0, 86.2, race = 95 },
				{ 42.3, 30.1, race = 95 },
				{ 42.8, 59.8, race = 95 },
				{ 44.4, 21.7, race = 95 },
				{ 45.2, 50.3, race = 95 },
				{ 46.3, 38.2, race = 95 },
				{ 57.6, 26.6, race = 95 },
				{ 60.4, 19.5, race = 95 },
			},
			[1440] = { -- Ashenvale
				{ 7.4, 14.2, race = 95 },
				{ 13.6, 30.8, race = 95 },
				{ 20.4, 42.6, race = 95 },
				{ 22.1, 52.9, race = 95 },
				{ 29.0, 29.4, race = 95 },
				{ 36.0, 54.6, race = 95 },
				{ 60.6, 55.6, race = 95 },
				{ 66.8, 82.1, race = 95 },
				{ 75.5, 65.7, race = 95 },
				{ 81.4, 48.9, race = 95 },
				{ 13.1, 24.8, race = 95 },
				{ 33.5, 66.9, race = 95 },
			},
			[1441] = { -- Thousand Needles
				{ 77.0, 77.5, race = 95 },
			},
			[1442] = { -- Stonetalon Mountains
				{ 34.9, 60.3, race = 95 },
				{ 36.4, 12.4, race = 95 },
				{ 48.6, 46.9, race = 95 },
				{ 58.7, 65.9, race = 95 },
				{ 69.6, 52.0, race = 95 },
				{ 73.7, 86.5, race = 95 },
				{ 53.4, 35.8, race = 95 },
				{ 78.4, 97.9, race = 95 },
			},
			[1446] = { -- Tanaris
				{ 60.4, 24.9, race = 95 },
			},
			[2521] = { -- Zephras Isle
				{ 33.8, 55.5, race = 95 },
				{ 35.3, 33.7, race = 95 },
				{ 38.4, 47.6, race = 95 },
				{ 45.5, 81.3, race = 95 },
				{ 46.0, 18.1, race = 95 },
				{ 48.0, 59.1, race = 95 },
				{ 50.3, 33.2, race = 95 },
				{ 52.5, 66.0, race = 95 },
				{ 53.8, 66.3, race = 95 },
				{ 55.0, 50.4, race = 95 },
				{ 58.8, 33.5, race = 95 },
				{ 63.9, 74.1, race = 95 },
				{ 63.7, 45.9, race = 95 },
				{ 68.8, 61.9, race = 95 },
			},
			[2548] = { -- Riverglades
				{ 56.9, 76.3, race = 95 },
			},
		},
		convergences = {
			[1411] = { -- Durotar
				{ 45.1, 15.7, race = 96 },
				{ 41.8, 21.8, race = 96 },
				{ 53.2, 16.2, race = 96 },
			},
			[1412] = { -- Mulgore
				{ 38.6, 44.7, race = 96 },
				{ 50.6, 52.9, race = 96 },
				{ 52.0, 34.2, race = 96 },
			},
			[1413] = { -- The Barrens
				{ 44.8, 55.0, race = 96 },
				{ 45.7, 69.8, race = 96 },
				{ 47.0, 80.2, race = 96 },
				{ 49.7, 34.6, race = 96 },
				{ 49.8, 28.6, race = 96 },
				{ 49.1, 15.5, race = 96 },
				{ 53.1, 22.2, race = 96 },
				{ 54.0, 26.6, race = 96 },
				{ 54.6, 14.9, race = 96 },
				{ 54.8, 34.7, race = 96 },
				{ 56.3, 41.6, race = 96 },
				{ 63.1, 41.1, race = 96 },
				{ 39.9, 13.9, race = 96 },
				{ 43.6, 42.1, race = 96 },
				{ 48.5, 46.3, race = 96 },
				{ 50.4, 58.7, race = 96 },
			},
			[1417] = { -- Arathi Highlands
				{ 25.4, 30.0, race = 96 },
				{ 52.0, 50.7, race = 96 },
				{ 68.3, 30.4, race = 96 },
			},
			[1420] = { -- Tirisfal Glades
				{ 49.2, 63.9, race = 96 },
			},
			[1421] = { -- Silverpine Forest
				{ 45.5, 21.0, race = 96 },
				{ 48.1, 75.4, race = 96 },
				{ 49.4, 52.7, race = 96 },
				{ 52.5, 70.4, race = 96 },
				{ 55.5, 24.1, race = 96 },
				{ 55.0, 66.0, race = 96 },
				{ 56.0, 46.4, race = 96 },
				{ 56.2, 10.0, race = 96 },
				{ 60.9, 80.0, race = 96 },
			},
			[1424] = { -- Hillsbrad Foothills
				{ 60.3, 10.6, race = 96 },
				{ 72.9, 63.6, race = 96 },
				{ 80.8, 45.3, race = 96 },
				{ 89.1, 58.8, race = 96 },
			},
			[1432] = { -- Loch Modan
				{ 27.5, 52.1, race = 96 },
				{ 59.0, 36.6, race = 96 },
			},
			[1434] = { -- Stranglethorn Vale
				{ 13.4, 15.0, race = 96 },
			},
			[1436] = { -- Westfall
				{ 34.8, 73.1, race = 96 },
				{ 41.6, 82.0, race = 96 },
				{ 59.7, 36.2, race = 96 },
			},
			[1437] = { -- Wetlands
				{ 54.1, 26.9, race = 96 },
				{ 60.2, 57.0, race = 96 },
			},
			[1439] = { -- Darkshore
				{ 58.4, 19.8, race = 96 },
			},
			[1440] = { -- Ashenvale
				{ 9.9, 27.9, race = 96 },
				{ 11.1, 13.5, race = 96 },
				{ 15.8, 19.6, race = 96 },
				{ 20.6, 32.2, race = 96 },
				{ 25.9, 42.5, race = 96 },
				{ 32.8, 39.4, race = 96 },
				{ 33.6, 67.8, race = 96 },
				{ 48.1, 69.5, race = 96 },
				{ 60.0, 63.0, race = 96 },
				{ 62.1, 61.6, race = 96 },
				{ 76.3, 67.5, race = 96 },
				{ 86.1, 58.7, race = 96 },
				{ 89.4, 49.8, race = 96 },
			},
			[1441] = { -- Thousand Needles
				{ 23.4, 30.4, race = 96 },
				{ 27.3, 41.5, race = 96 },
				{ 42.2, 49.5, race = 96 },
				{ 54.8, 48.3, race = 96 },
				{ 67.3, 62.1, race = 96 },
				{ 68.6, 52.0, race = 96 },
			},
			[1442] = { -- Stonetalon Mountains
				{ 33.4, 63.9, race = 96 },
				{ 49.3, 36.0, race = 96 },
				{ 65.7, 46.0, race = 96 },
				{ 72.6, 57.5, race = 96 },
				{ 74.8, 94.4, race = 96 },
				{ 80.9, 90.5, race = 96 },
			},
			[1445] = { -- Dustwallow Marsh
				{ 33.0, 30.8, race = 96 },
			},
			[2521] = { -- Zephras Isle
				{ 34.1, 59.8, race = 96 },
				{ 35.9, 33.7, race = 96 },
				{ 46.6, 38.2, race = 96 },
				{ 47.6, 69.5, race = 96 },
				{ 48.4, 20.3, race = 96 },
				{ 48.5, 55.8, race = 96 },
				{ 48.4, 80.6, race = 96 },
				{ 52.8, 57.5, race = 96 },
				{ 59.1, 79.8, race = 96 },
				{ 61.6, 51.5, race = 96 },
				{ 64.8, 38.0, race = 96 },
				{ 67.9, 74.9, race = 96 },
				{ 68.4, 66.0, race = 96 },
				{ 70.0, 61.4, race = 96 },
				{ 67.5, 50.5, race = 96 },
			},
			[2548] = { -- Riverglades
				{ 33.6, 39.4, race = 96 },
				{ 70.9, 58.5, race = 96 },
			},
		},
		zoneExits = {
			[1411] = { -- Durotar
				{ 34.7, 42.6, to = { { 1413 } } },
				{ 45.6, 12.1, to = { { 1454 } } },
			},
			[1412] = { -- Mulgore
				{ 39.9, 13.3, to = { { 1442 } } },
				{ 70.5, 56.5, to = { { 1413 } } },
				{ 37.0, 32.0, to = { { 1456 } } },
			},
			[1413] = { -- The Barrens
				{ 35.5, 27.6, to = { { 1442 } } },
				{ 38.5, 59.5, to = { { 1412 } } },
				{ 44.6, 90.5, to = { { 1441 } } },
				{ 48.3, 5.7, to = { { 1440 } } },
				{ 50.0, 78.6, to = { { 1445 } } },
				{ 63.4, 19.3, to = { { 1411 } } },
			},
			[1416] = { -- Alterac Mountains
				{ 20.8, 89.7, to = { { 1424 } } },
				{ 57.0, 75.0, to = { { 1424 } } },
				{ 80.0, 33.0, to = { { 1422 } } },
			},
			[1417] = { -- Arathi Highlands
				{ 20.3, 30.0, to = { { 1424 } } },
				{ 44.0, 92.5, to = { { 1437 } } },
				{ 77.2, 21.8, to = { { 1425 } } },
			},
			[1418] = { -- Badlands
				{ 46.2, 9.5, to = { { 1432 } } },
				{ 6.0, 60.0, to = { { 1427 } } },
			},
			[1419] = { -- Blasted Lands
				{ 52.9, 2.8, to = { { 1435 } } },
			},
			[1420] = { -- Tirisfal Glades
				{ 54.5, 72.5, to = { { 1421 } } },
				{ 61.9, 65.0, to = { { 1458 } } },
				{ 83.5, 69.8, to = { { 1422 } } },
			},
			[1421] = { -- Silverpine Forest
				{ 67.5, 4.6, to = { { 1420 } } },
				{ 67.0, 81.5, to = { { 1424 } } },
			},
			[1422] = { -- Western Plaguelands
				{ 27.0, 56.5, to = { { 1420 } } },
				{ 43.0, 85.0, to = { { 1416 } } },
				{ 69.5, 50.2, to = { { 1423 } } },
			},
			[1423] = { -- Eastern Plaguelands
				{ 8.0, 63.0, to = { { 1422 } } },
			},
			[1424] = { -- Hillsbrad Foothills
				{ 12.5, 46.5, to = { { 1421 } } },
				{ 29.2, 29.8, to = { { 1416 } } },
				{ 55.8, 19.5, to = { { 1416 } } },
				{ 83.3, 58.8, to = { { 1417 } } },
				{ 88.0, 33.0, to = { { 1425 } } },
			},
			[1425] = { -- The Hinterlands
				{ 8.5, 46.5, to = { { 1424 } } },
				{ 23.0, 28.8, to = { { 1423 } } },
				{ 56.6, 80.6, to = { { 1417 } } },
			},
			[1426] = { -- Dun Morogh
				{ 53.5, 34.5, to = { { 1455 } } },
				{ 85.5, 51.2, to = { { 1432 } } },
			},
			[1427] = { -- Searing Gorge
				{ 35.0, 85.0, to = { { 1428 } } },
				{ 79.0, 46.0, to = { { 1418 } } },
			},
			[1428] = { -- Burning Steppes
				{ 28.6, 17.1, to = { { 1427 } } },
				{ 75.0, 84.3, to = { { 1433 } } },
			},
			[1429] = { -- Elwynn Forest
				{ 20.6, 80.6, to = { { 1436 } } },
				{ 32.0, 49.5, to = { { 1453 } } },
				{ 41.5, 93.5, to = { { 1431 } } },
				{ 95.5, 72.3, to = { { 1433 } } },
			},
			[1430] = { -- Deadwind Pass
				{ 32.0, 35.0, to = { { 1431 } } },
				{ 60.2, 43.1, to = { { 1435 } } },
			},
			[1431] = { -- Duskwood
				{ 7.5, 62.0, to = { { 1436 } } },
				{ 44.5, 88.5, to = { { 1434 } } },
				{ 27.3, 21.5, to = { { 1429 } } },
				{ 90.5, 41.0, to = { { 1430 } } },
				{ 86.5, 9.0, to = { { 1433 } } },
			},
			[1432] = { -- Loch Modan
				{ 21.0, 68.5, to = { { 1426 } } },
				{ 20.5, 10.5, to = { { 1437 } } },
				{ 46.2, 76.0, to = { { 1418 } } },
			},
			[1433] = { -- Redridge Mountains
				{ 4.5, 71.7, to = { { 1429 } } },
				{ 36.0, 7.0, to = { { 1428 } } },
				{ 43.7, 8.8, to = { { 2548 } } },
				{ 70.3, 18.9, to = { { 2548 } } },
				{ 2.0, 90.0, to = { { 1431 } } },
				{ 53.5, 78.6, to = { { 1435 } } },
			},
			[1434] = { -- Stranglethorn Vale
				{ 38.2, 3.0, to = { { 1431 } } },
			},
			[1435] = { -- Swamp of Sorrows
				{ 5.0, 63.0, to = { { 1430 } } },
				{ 34.5, 66.0, to = { { 1419 } } },
				{ 27.0, 6.0, to = { { 1433 } } },
			},
			[1436] = { -- Westfall
				{ 61.5, 18.0, to = { { 1429 } } },
				{ 68.0, 70.5, to = { { 1431 } } },
			},
			[1437] = { -- Wetlands
				{ 51.0, 10.5, to = { { 1417 } } },
				{ 52.5, 87.5, to = { { 1432 } } },
			},
			[1438] = { -- Teldrassil
				{ 29.5, 56.0, to = { { 1457 } } },
			},
			[1439] = { -- Darkshore
				{ 43.5, 92.5, to = { { 1440 } } },
			},
			[1440] = { -- Ashenvale
				{ 26.5, 4.0, to = { { 1439 } } },
				{ 42.0, 71.0, to = { { 1442 } } },
				{ 56.0, 26.0, to = { { 1448 } } },
				{ 68.9, 89.6, to = { { 1413 } } },
				{ 94.5, 47.5, to = { { 1447 } } },
			},
			[1441] = { -- Thousand Needles
				{ 11.5, 36.5, to = { { 1444 } } },
				{ 31.5, 21.5, to = { { 1413 } } },
				{ 76.5, 97.0, to = { { 1446 } } },
			},
			[1442] = { -- Stonetalon Mountains
				{ 29.5, 77.5, to = { { 1443 } } },
				{ 69.5, 96.5, to = { { 1412 } } },
				{ 78.0, 42.0, to = { { 1440 } } },
				{ 80.0, 90.0, to = { { 1413 } } },
			},
			[1443] = { -- Desolace
				{ 45.0, 95.0, to = { { 1444 } } },
				{ 56.9, 88.6, to = { { 2652 } } },
				{ 54.0, 7.0, to = { { 1442 } } },
				{ 65.9, 78.6, to = { { 2652 } } },
			},
			[1444] = { -- Feralas
				{ 46.5, 2.0, to = { { 1443 } } },
				{ 89.0, 46.0, to = { { 1441 } } },
			},
			[1445] = { -- Dustwallow Marsh
				{ 28.0, 47.5, to = { { 1413 } } },
			},
			[1446] = { -- Tanaris
				{ 31.7, 28.5, to = { { 1449 } } },
				{ 51.0, 21.0, to = { { 1441 } } },
			},
			[1447] = { -- Azshara
				{ 11.5, 78.5, to = { { 1440 } } },
			},
			[1448] = { -- Felwood
				{ 55.5, 96.0, to = { { 1440 } } },
				{ 64.5, 8.0, to = { { 1452 } } },
				{ 63.0, 6.5, to = { { 1450 } } },
			},
			[1449] = { -- Un'Goro Crater
				{ 29.0, 22.5, to = { { 1451 } } },
				{ 79.5, 49.5, to = { { 1446 } } },
			},
			[1450] = { -- Moonglade
				{ 29.7, 98.0, to = { { 1448 } } },
			},
			[1451] = { -- Silithus
				{ 82.0, 18.0, to = { { 1449 } } },
			},
			[1452] = { -- Winterspring
				{ 28.0, 34.0, to = { { 1448 } } },
			},
			[2548] = { -- Riverglades
				{ 17.5, 69.1, to = { { 1433 } } },
				{ 28.1, 70.8, to = { { 1433 } } },
			},
			[2652] = { -- Shen'dralas
				{ 22.2, 23.0, to = { { 1443 } } },
				{ 34.0, 6.7, to = { { 1443 } } },
			},
		},
	}
end
