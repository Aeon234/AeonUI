local AUI = select(2, ...)

---The dungeon maps drawn on the client's own map art, built on first use, by the instance's map ID:
--- - `folder`: the art's folder under `Interface\WorldMap`, its tiles named `<folder><floor>_<tile>`, or
---   `<folder><tile>` where `flat` is set; twelve tiles, four across and three down;
--- - `floors`: the art's floor numbers in order; `wings`: the floor a wing's marker opens on;
--- - `pins`: by floor, each `{ x, y, ... }` as fractions of the art: `boss` its English name (`title` its title,
---   `level`, `optional` for an optional boss), `floor` a way to another floor (`up` when it leads up), or `entrance`.
---Forever's world.
---@return table<number, table>
function AUI.WorldMapDungeonData()
	return {
		[389] = { -- Ragefire Chasm
			folder = "Ragefire",
			floors = { 1 },
			pins = {
				[1] = {
					{ 0.611, 0.072, entrance = true },
					{ 0.564, 0.372, boss = "Oggleflint", title = "Ragefire Chieftain", level = 16 },
					{ 0.406, 0.574, boss = "Taragaman the Hungerer", level = 16 },
					{ 0.338, 0.84, boss = "Jergosh the Invoker", level = 16 },
					{ 0.422, 0.857, boss = "Bazzalan", level = 16 },
				},
			},
		},
		[36] = { -- The Deadmines
			folder = "TheDeadmines",
			floors = { 1, 2 },
			pins = {
				[1] = {
					{ 0.297, 0.133, entrance = true },
					{ 0.655, 0.667, floor = 2 },
					{ 0.374, 0.61, boss = "Rhahk'Zor", title = "The Foreman", level = 19 },
					{ 0.523, 0.51, boss = "Miner Johnson", level = 19, optional = true },
					{ 0.493, 0.862, boss = "Sneed's Shredder / Sneed", level = 20 },
					{ 0.607, 0.572, boss = "Gilnid", title = "The Smelter", level = 20 },
				},
				[2] = {
					{ 0.123, 0.883, floor = 1, up = true },
					{ 0.561, 0.265, boss = "Mr. Smite", title = "The Ship's First Mate", level = 20 },
					{ 0.632, 0.389, boss = "Captain Greenskin", level = 20 },
					{ 0.603, 0.455, boss = "Edwin VanCleef", title = "Defias Kingpin", level = 21 },
					{ 0.668, 0.398, boss = "Cookie", title = "The Ship's Cook", level = 20 },
				},
			},
		},
		[33] = { -- Shadowfang Keep
			folder = "ShadowfangKeep",
			floors = { 1, 2, 3, 4, 5, 6, 7 },
			pins = {
				[1] = {
					{ 0.705, 0.606, entrance = true },
					{ 0.367, 0.392, floor = 2 },
					{ 0.148, 0.866, floor = 2 },
					{ 0.355, 0.666, floor = 7, up = true },
					{ 0.65, 0.715, boss = "Rethilgore", title = "The Cell Keeper", level = 20 },
					{ 0.278, 0.601, boss = "Commander Springvale", level = 24 },
				},
				[2] = {
					{ 0.593, 0.121, floor = 1, up = true },
					{ 0.273, 0.881, floor = 1, up = true },
					{ 0.301, 0.762, boss = "Baron Silverlaine", level = 24 },
					{ 0.472, 0.277, boss = "Razorclaw the Butcher", level = 22 },
				},
				[3] = {
					{ 0.516, 0.904, floor = 7, up = true },
					{ 0.533, 0.6, floor = 4, up = true },
				},
				[4] = {
					{ 0.442, 0.749, floor = 5, up = true },
					{ 0.526, 0.872, floor = 3 },
					{ 0.544, 0.537, boss = "Fenrus the Devourer", level = 25 },
				},
				[5] = {
					{ 0.437, 0.743, floor = 6, up = true },
					{ 0.49, 0.78, floor = 4 },
				},
				[6] = {
					{ 0.42, 0.842, floor = 5 },
					{ 0.553, 0.627, boss = "Wolf Master Nandos", level = 25 },
					{ 0.639, 0.2, boss = "Archmage Arugal", level = 26 },
				},
				[7] = {
					{ 0.239, 0.745, floor = 1 },
					{ 0.436, 0.331, floor = 3, up = true },
					{ 0.595, 0.82, boss = "Odo the Blindwatcher", level = 24 },
					{ 0.69, 0.77, boss = "Deathsworn Captain", level = 25, optional = true },
				},
			},
		},
		[48] = { -- Blackfathom Deeps
			folder = "BlackFathomDeeps",
			floors = { 1, 2, 3 },
			pins = {
				[1] = {
					{ 0.453, 0.108, entrance = true },
					{ 0.621, 0.741, floor = 2 },
					{ 0.329, 0.602, boss = "Ghamoo-ra", level = 25 },
					{ 0.101, 0.36, boss = "Lady Sarevess", level = 25 },
					{ 0.536, 0.568, boss = "Gelihast", level = 26 },
					{ 0.614, 0.625, boss = "Lorgus Jett", level = 26 },
				},
				[2] = {
					{ 0.477, 0.707, floor = 3 },
					{ 0.35, 0.29, floor = 1 },
					{ 0.519, 0.816, boss = "Twilight Lord Kelris", level = 27 },
					{ 0.856, 0.866, boss = "Aku'mai", level = 28 },
				},
				[3] = {
					{ 0.3, 0.612, floor = 2, up = true },
					{ 0.606, 0.312, boss = "Old Serra'kis", level = 26 },
					{ 0.234, 0.498, boss = "Baron Aquanis", level = 28 },
				},
			},
		},
		[90] = { -- Gnomeregan
			folder = "Gnomeregan",
			floors = { 1, 2, 3, 4 },
			pins = {
				[1] = {
					{ 0.644, 0.275, entrance = true },
					{ 0.345, 0.64, floor = 2 },
					{ 0.47, 0.87, floor = 2 },
					{ 0.551, 0.44, floor = 2 },
					{ 0.77, 0.67, boss = "Grubbis", level = 32 },
				},
				[2] = {
					{ 0.245, 0.58, floor = 3 },
					{ 0.43, 0.83, floor = 1, up = true },
					{ 0.64, 0.58, floor = 1, up = true },
					{ 0.755, 0.45, boss = "Viscous Fallout", level = 30 },
					{ 0.245, 0.7, boss = "Electrocutioner 6000", level = 32 },
				},
				[3] = {
					{ 0.87, 0.48, entrance = true },
					{ 0.488, 0.71, floor = 4 },
					{ 0.273, 0.308, floor = 4 },
					{ 0.445, 0.43, floor = 2, up = true },
					{ 0.438, 0.865, boss = "Crowd Pummeler 9-60", level = 32 },
				},
				[4] = {
					{ 0.481, 0.54, floor = 3, up = true },
					{ 0.71, 0.773, floor = 3, up = true },
					{ 0.295, 0.54, boss = "Dark Iron Ambassador", level = 41, optional = true },
					{ 0.313, 0.3, boss = "Mekgineer Thermaplugg", level = 34 },
				},
			},
		},
		[34] = { -- The Stockade
			folder = "TheStockade",
			floors = { 1 },
			pins = {
				[1] = {
					{ 0.5, 0.815, entrance = true },
					{ 0.44, 0.446, boss = "Targorr the Dread", level = 24 },
					{ 0.691, 0.3, boss = "Kam Deepfury", level = 27 },
					{ 0.78, 0.454, boss = "Hamhock", level = 28 },
					{ 0.745, 0.562, boss = "Bazil Thredd", level = 29 },
					{ 0.213, 0.26, boss = "Dextren Ward", level = 26 },
					{ 0.497, 0.222, boss = "Bruegal Ironknuckle", level = 26, optional = true },
				},
			},
		},
		[47] = { -- Razorfen Kraul
			folder = "RazorfenKraul",
			floors = { 1 },
			pins = {
				[1] = {
					{ 0.715, 0.837, entrance = true },
					{ 0.81, 0.51, boss = "Roogug", level = 28 },
					{ 0.865, 0.41, boss = "Aggem Thorncurse", title = "Death's Head Prophet", level = 30 },
					{ 0.57, 0.3, boss = "Death Speaker Jargba", title = "Death's Head Captain", level = 30 },
					{ 0.215, 0.3, boss = "Overlord Ramtusk", level = 32 },
					{ 0.112, 0.724, boss = "Agathelos the Raging", level = 33 },
					{ 0.11, 0.303, boss = "Blind Hunter", level = 32, optional = true },
					{ 0.08, 0.69, boss = "Charlga Razorflank", title = "The Crone", level = 33 },
					{ 0.494, 0.471, boss = "Earthcaller Halmgar", level = 32, optional = true },
				},
			},
		},
		[129] = { -- Razorfen Downs
			folder = "RazorfenDowns",
			floors = { 1 },
			pins = {
				[1] = {
					{ 0.237, 0.19, entrance = true },
					{ 0.47, 0.2, boss = "Plaguemaw the Rotting", level = 40 },
					{ 0.857, 0.465, boss = "Mordresh Fire Eye", level = 39 },
					{ 0.35, 0.67, boss = "Glutton", level = 40 },
					{ 0.529, 0.672, boss = "Ragglesnout", level = 40 },
					{ 0.443, 0.596, boss = "Amnennar the Coldbringer", level = 41 },
					{ 0.59, 0.339, boss = "Tuten'kash", level = 40 },
				},
			},
		},
		[349] = { -- Maraudon
			folder = "Maraudon",
			floors = { 1, 2 },
			pins = {
				[1] = {
					{ 0.768, 0.657, entrance = true },
					{ 0.145, 0.57, floor = 2 },
					{ 0.622, 0.281, entrance = true },
					{ 0.348, 0.107, boss = "Noxxion", level = 48 },
					{ 0.162, 0.34, boss = "Razorlash", level = 48 },
					{ 0.377, 0.694, boss = "Lord Vyletongue", level = 47 },
					{ 0.246, 0.874, boss = "Meshlok the Harvester", level = 48, optional = true },
				},
				[2] = {
					{ 0.295, 0.04, floor = 1, up = true },
					{ 0.245, 0.144, boss = "Celebras the Cursed", level = 49 },
					{ 0.406, 0.482, boss = "Landslide", level = 50 },
					{ 0.484, 0.686, boss = "Tinkerer Gizlock", level = 50 },
					{ 0.333, 0.771, boss = "Rotgrip", level = 50 },
					{ 0.242, 0.784, boss = "Princess Theradras", level = 51 },
				},
			},
		},
		[209] = { -- Zul'Farrak
			folder = "ZulFarrak",
			floors = { 1 },
			flat = true,
			pins = {
				[1] = {
					{ 0.566, 0.901, entrance = true },
					{ 0.69, 0.256, boss = "Antu'sul", title = "Overseer of Sul", level = 48 },
					{ 0.554, 0.296, boss = "Theka the Martyr", level = 46 },
					{ 0.44, 0.16, boss = "Witch Doctor Zum'rah", level = 46 },
					{ 0.255, 0.13, boss = "Sergeant Bly", level = 45 },
					{ 0.289, 0.403, boss = "Hydromancer Velratha", level = 46 },
					{ 0.42, 0.36, boss = "Ruuzlu", level = 46 },
					{ 0.44, 0.33, boss = "Chief Ukorz Sandscalp", level = 48 },
					{ 0.538, 0.373, boss = "Zerillis", level = 45, optional = true },
					{ 0.463, 0.578, boss = "Sandarr Dunereaver", level = 45, optional = true },
					{ 0.317, 0.46, boss = "Dustwraith", level = 45, optional = true },
					{ 0.235, 0.183, boss = "Nekrum Gutchewer", level = 46 },
					{ 0.334, 0.17, boss = "Shadowpriest Sezz'ziz", level = 47 },
					{ 0.305, 0.4, boss = "Gahz'rilla", level = 46 },
				},
			},
		},
		[230] = { -- Blackrock Depths
			folder = "BlackrockDepths",
			floors = { 2 },
			pins = {
				[2] = {
					{ 0.367, 0.822, boss = "General Angerforge", level = 57 },
					{ 0.545, 0.975, boss = "Pyromancer Loregrain", level = 52 },
					{ 0.595, 0.662, boss = "Warder Stilgiss / Verek", level = 56 },
					{ 0.367, 0.65, boss = "Golem Lord Argelmach", level = 57 },
					{ 0.528, 0.649, boss = "Phalanx", level = 55 },
					{ 0.49, 0.625, boss = "Ribbly Screwspigot", level = 53 },
					{ 0.5, 0.609, boss = "Plugger Spazzring", level = 55 },
					{ 0.538, 0.488, boss = "Ambassador Flamelash", level = 57 },
					{ 0.805, 0.119, boss = "Magmus", level = 57 },
					{ 0.537, 0.248, boss = "Doom'rel / Dope'rel / Hate'rel / Seeth'rel / Vile'rel / Gloom'rel / Anger'rel", level = 57 },
					{ 0.918, 0.119, boss = "Emperor Dagran Thaurissan", level = 59 },
					{ 0.935, 0.119, boss = "Princess Moira Bronzebeard", title = "Princess of Ironforge", level = 58 },
					{ 0.48, 0.58, boss = "Hurley Blackbreath", level = 55 },
					{ 0.505, 0.354, boss = "Panzor the Invincible", level = 57, optional = true },
				},
			},
		},
		[109] = { -- The Temple of Atal'Hakkar
			folder = "TheTempleofAtalhakkar",
			floors = { 1 },
			pins = {
				[1] = {
					{ 0.525, 0.45, boss = "Dreamscythe", level = 53 },
					{ 0.47, 0.45, boss = "Weaver", level = 51 },
					{ 0.76, 0.37, boss = "Jammal'an the Prophet", level = 54 },
					{ 0.767, 0.361, boss = "Ogom the Wretched", level = 53 },
					{ 0.491, 0.845, boss = "Morphaz", level = 52 },
					{ 0.448, 0.851, boss = "Hazzas", level = 53 },
					{ 0.686, 0.874, boss = "Shade of Eranikus", level = 55 },
					{ 0.24, 0.457, boss = "Avatar of Hakkar", level = 49 },
				},
			},
		},
		[329] = { -- Stratholme
			folder = "Stratholme",
			floors = { 1, 2 },
			pins = {
				[1] = {
					{ 0.64, 0.88, entrance = true },
					{ 0.392, 0.287, boss = "Timmy the Cruel", level = 58, optional = true },
					{ 0.686, 0.88, entrance = true },
					{ 0.9, 0.33, floor = 2, up = true },
					{ 0.815, 0.438, boss = "Skul", level = 58, optional = true },
					{ 0.847, 0.454, boss = "Hearthsinger Forresten", level = 57, optional = true },
					{ 0.729, 0.193, boss = "The Unforgiven", level = 57 },
					{ 0.304, 0.4, boss = "Malor the Zealous", level = 60 },
					{ 0.036, 0.501, boss = "Cannon Master Willey", level = 60 },
					{ 0.271, 0.751, boss = "Archivist Galford", level = 60 },
					{ 0.188, 0.837, boss = "Balnazzar", level = 62 },
				},
				[2] = {
					{ 0.355, 0.39, floor = 1 },
					{ 0.57, 0.77, floor = 1 },
					{ 0.649, 0.489, boss = "Stonespine", level = 60, optional = true },
					{ 0.75, 0.468, boss = "Baroness Anastari", level = 59 },
					{ 0.564, 0.469, boss = "Nerub'enkan", level = 60 },
					{ 0.682, 0.199, boss = "Maleki the Pallid", level = 61 },
					{ 0.644, 0.752, boss = "Magistrate Barthilas", level = 58 },
					{ 0.372, 0.199, boss = "Baron Rivendare", level = 62 },
					{ 0.455, 0.2, boss = "Ramstein the Gorger", level = 61 },
				},
			},
		},
		[70] = { -- Uldaman
			folder = "Uldaman",
			floors = { 1, 2 },
			pins = {
				[1] = {
					{ 0.285, 0.692, entrance = true },
					{ 0.485, 0.21, floor = 2 },
					{ 0.68, 0.725, entrance = true },
					{ 0.541, 0.722, boss = "Revelosh", level = 40 },
					{ 0.585, 0.91, boss = "Baelog / Eric \"The Swift\" / Olaf", level = 41 },
					{ 0.474, 0.407, boss = "Ancient Stone Keeper", level = 44 },
					{ 0.258, 0.36, boss = "Galgann Firehammer", level = 45 },
					{ 0.212, 0.248, boss = "Grimlok", title = "Stonevault Chieftain", level = 45 },
					{ 0.36, 0.73, boss = "Ironaya", level = 40 },
				},
				[2] = {
					{ 0.645, 0.41, floor = 1, up = true },
					{ 0.554, 0.506, boss = "Archaedas", title = "Ancient Stone Watcher", level = 47 },
				},
			},
		},
		[189] = { -- Scarlet Monastery
			folder = "ScarletMonastery",
			floors = { 1, 2, 3, 4 },
			wings = { graveyard = 1, library = 2, armory = 3, cathedral = 4 },
			pins = {
				[1] = {
					{ 0.84, 0.83, entrance = true },
					{ 0.721, 0.593, boss = "Interrogator Vishas", level = 32 },
					{ 0.25, 0.56, boss = "Bloodmage Thalnos", level = 34 },
					{ 0.325, 0.66, boss = "Azshir the Sleepless", level = 33, optional = true },
					{ 0.4, 0.46, boss = "Fallen Champion", level = 33, optional = true },
					{ 0.4, 0.66, boss = "Ironspine", level = 33, optional = true },
				},
				[2] = {
					{ 0.13, 0.248, entrance = true },
					{ 0.3, 0.85, boss = "Houndmaster Loksey", level = 34 },
					{ 0.835, 0.74, boss = "Arcanist Doan", level = 37 },
				},
				[3] = {
					{ 0.61, 0.955, entrance = true },
					{ 0.785, 0.103, boss = "Herod", title = "The Scarlet Champion", level = 40 },
				},
				[4] = {
					{ 0.623, 0.92, entrance = true },
					{ 0.487, 0.28, boss = "Scarlet Commander Mograine", level = 42 },
					{ 0.493, 0.16, boss = "High Inquisitor Whitemane", level = 42 },
					{ 0.559, 0.243, boss = "High Inquisitor Fairbanks", level = 40 },
				},
			},
		},
		[429] = { -- Dire Maul
			folder = "DireMaul",
			floors = { 1, 2, 3, 4, 5, 6 },
			wings = { north = 1, west = 2, east = 5 },
			pins = {
				[1] = {
					{ 0.718, 0.926, entrance = true },
					{ 0.694, 0.752, boss = "Guard Mol'dar", level = 59 },
					{ 0.609, 0.681, boss = "Stomper Kreeg", title = "The Drunk", level = 59 },
					{ 0.495, 0.78, boss = "Guard Fengus", level = 59 },
					{ 0.265, 0.567, boss = "Guard Slip'kik", level = 59 },
					{ 0.318, 0.498, boss = "Captain Kromcrush", level = 61 },
					{ 0.304, 0.254, boss = "Cho'Rush the Observer", level = 60 },
					{ 0.319, 0.259, boss = "King Gordok", level = 62 },
				},
				[2] = {
					{ 0.935, 0.721, entrance = true },
					{ 0.936, 0.51, entrance = true },
					{ 0.27, 0.19, floor = 3 },
					{ 0.304, 0.43, floor = 4 },
					{ 0.332, 0.53, boss = "Tendris Warpwood", level = 60 },
					{ 0.212, 0.782, boss = "Illyanna Ravenoak", level = 60 },
				},
				[3] = {
					{ 0.415, 0.12, floor = 2 },
					{ 0.335, 0.436, boss = "Magister Kalendris", level = 60 },
					{ 0.322, 0.143, boss = "Tsu'zee", level = 59 },
				},
				[4] = {
					{ 0.745, 0.4, floor = 2, up = true },
					{ 0.35, 0.576, boss = "Immol'thar", level = 61 },
					{ 0.62, 0.23, boss = "Prince Tortheldrin", level = 61 },
				},
				[5] = {
					{ 0.07, 0.392, entrance = true },
					{ 0.164, 0.853, entrance = true },
					{ 0.954, 0.508, entrance = true },
					{ 0.505, 0.63, floor = 6 },
					{ 0.122, 0.31, boss = "Pusillin", level = 57 },
					{ 0.437, 0.477, boss = "Zevrim Thornhoof", level = 57 },
				},
				[6] = {
					{ 0.281, 0.555, entrance = true },
					{ 0.633, 0.844, floor = 5, up = true },
					{ 0.554, 0.269, boss = "Alzzin the Wildshaper", level = 58 },
					{ 0.533, 0.713, boss = "Hydrospawn", level = 57 },
					{ 0.576, 0.732, boss = "Lethtendris", level = 57 },
				},
			},
		},
		[229] = { -- Blackrock Spire
			folder = "BlackrockSpire",
			floors = { 1, 2, 3, 4, 5, 6, 7 },
			wings = { lower = 4, upper = 7 },
			pins = {
				[1] = {
					{ 0.64, 0.692, floor = 2 },
					{ 0.59, 0.6, floor = 2 },
					{ 0.52, 0.542, boss = "War Master Voone / Mor Grayhoof", level = 59 },
					{ 0.475, 0.62, boss = "Bannok Grimaxe <Firebrand Legion Champion> (Rare)", level = 16, optional = true },
				},
				[2] = {
					{ 0.64, 0.692, floor = 1 },
					{ 0.59, 0.6, floor = 1 },
					{ 0.535, 0.5, floor = 3 },
					{ 0.55, 0.69, boss = "Shadow Hunter Vosh'gajin", level = 58 },
					{ 0.55, 0.75, boss = "Crystal Fang (Rare)", level = 60, optional = true },
					{ 0.617, 0.733, boss = "Mother Smolderweb", level = 60 },
				},
				[3] = {
					{ 0.54, 0.38, floor = 4 },
					{ 0.535, 0.51, floor = 2 },
					{ 0.385, 0.582, boss = "Highlord Omokk", level = 59 },
				},
				[4] = {
					{ 0.37, 0.42, entrance = true },
					{ 0.54, 0.38, floor = 3 },
					{ 0.425, 0.725, floor = 5 },
					{ 0.45, 0.55, boss = "Urok Doomhowl", level = 60 },
				},
				[5] = {
					{ 0.425, 0.725, floor = 4 },
					{ 0.4, 0.595, floor = 6 },
					{ 0.54, 0.84, boss = "Quartermaster Zigris", title = "Bloodaxe Legion", level = 59 },
					{ 0.38, 0.825, boss = "Halycon / Gizrul the Slavener", level = 60 },
					{ 0.34, 0.66, boss = "Ghok Bashguud", title = "Bloodaxe Champion", level = 59, optional = true },
				},
				[6] = {
					{ 0.4, 0.595, floor = 5 },
					{ 0.57, 0.6, boss = "Overlord Wyrmthalak", level = 60 },
				},
				[7] = {
					{ 0.335, 0.245, boss = "Jed Runewatcher", title = "Blackhand Legion", level = 59, optional = true },
					{ 0.29, 0.25, boss = "Goraluk Anvilcrack", title = "Blackhand Legion Armorsmith", level = 61, optional = true },
					{ 0.485, 0.245, boss = "Warchief Rend Blackhand", level = 63 },
					{ 0.64, 0.315, boss = "The Beast", level = 63 },
					{ 0.35, 0.49, boss = "General Drakkisath", level = 63 },
				},
			},
		},
		[309] = { -- Zul'Gurub
			folder = "ZulGurub",
			floors = { 1 },
			flat = true,
			pins = {
				[1] = {
					{ 0.29, 0.49, entrance = true },
					{ 0.39, 0.73, boss = "High Priestess Jeklik" },
					{ 0.515, 0.54, boss = "High Priest Venoxis" },
					{ 0.47, 0.77, boss = "High Priestess Mar'li" },
					{ 0.625, 0.68, boss = "Bloodlord Mandokir" },
					{ 0.6, 0.462, boss = "Gri'lek / Hazza'rah / Renataki / Wushoolay" },
					{ 0.535, 0.32, boss = "Gahz'ranka" },
					{ 0.62, 0.34, boss = "High Priest Thekal" },
					{ 0.475, 0.19, boss = "High Priestess Arlokk" },
					{ 0.31, 0.24, boss = "Jin'do the Hexxer" },
					{ 0.505, 0.39, boss = "Hakkar" },
				},
			},
		},
		[409] = { -- Molten Core
			folder = "MoltenCore",
			floors = { 1 },
			pins = {
				[1] = {
					{ 0.264, 0.226, entrance = true },
					{ 0.66, 0.37, boss = "Lucifron" },
					{ 0.695, 0.23, boss = "Magmadar" },
					{ 0.35, 0.49, boss = "Gehennas" },
					{ 0.315, 0.69, boss = "Garr" },
					{ 0.55, 0.85, boss = "Shazzrah" },
					{ 0.535, 0.75, boss = "Baron Geddon" },
					{ 0.81, 0.82, boss = "Sulfuron Harbinger" },
					{ 0.685, 0.57, boss = "Golemagg the Incinerator" },
					{ 0.84, 0.66, boss = "Majordomo Executus" },
					{ 0.548, 0.54, boss = "Ragnaros" },
				},
			},
		},
		[469] = { -- Blackwing Lair
			folder = "BlackwingLair",
			floors = { 1, 2, 3, 4 },
			pins = {
				[1] = {
					{ 0.527, 0.836, entrance = true },
					{ 0.435, 0.3, floor = 2, up = true },
					{ 0.36, 0.13, floor = 2, up = true },
				},
				[2] = {
					{ 0.525, 0.32, floor = 1 },
					{ 0.463, 0.198, floor = 1 },
				},
			},
		},
		[509] = { -- Ruins of Ahn'Qiraj
			folder = "RuinsofAhnQiraj",
			floors = { 1 },
			flat = true,
			pins = {
				[1] = {
					{ 0.595, 0.108, entrance = true },
					{ 0.544, 0.348, boss = "Kurinaxx" },
					{ 0.568, 0.479, boss = "General Rajaxx" },
					{ 0.68, 0.607, boss = "Buru the Gorger" },
					{ 0.601, 0.879, boss = "Ayamiss the Hunter" },
					{ 0.32, 0.358, boss = "Moam" },
					{ 0.419, 0.679, boss = "Ossirian the Unscarred" },
				},
			},
		},
		[531] = { -- Temple of Ahn'Qiraj
			folder = "AhnQiraj",
			floors = { 1, 2, 3 },
			pins = {
				[1] = {
					{ 0.343, 0.452, floor = 2, up = true },
					{ 0.28, 0.491, boss = "Lord Kri / Princess Yauj / Vem", optional = true },
					{ 0.442, 0.333, boss = "Battleguard Sartura" },
					{ 0.619, 0.225, boss = "Fankriss the Unyielding" },
					{ 0.718, 0.182, boss = "Viscidus", optional = true },
					{ 0.43, 0.502, boss = "Princess Huhuran" },
					{ 0.618, 0.642, boss = "Emperor Vek'lor" },
					{ 0.628, 0.737, boss = "Emperor Vek'nilash" },
					{ 0.299, 0.811, boss = "Ouro", optional = true },
				},
				[2] = {
					{ 0.522, 0.265, entrance = true },
					{ 0.454, 0.51, boss = "The Prophet Skeram" },
					{ 0.488, 0.636, floor = 1 },
					{ 0.59, 0.687, floor = 3 },
				},
				[3] = {
					{ 0.586, 0.419, floor = 1, up = true },
					{ 0.568, 0.63, boss = "C'Thun" },
				},
			},
		},
		[249] = { -- Onyxia's Lair
			folder = "OnyxiasLair",
			floors = { 1 },
			pins = {
				[1] = {
					{ 0.341, 0.205, entrance = true },
					{ 0.67, 0.31, boss = "Onyxia" },
				},
			},
		},
	}
end
