local AUI = select(2, ...)

-- Channeled spells' ticks, which the client does not provide. Every entry is unverified until it is seen in game;
-- `/aui dev channel` prints the current channel's spell ID and length for checking and adding entries. Each client has
-- its own table: the same spell ID can tick differently on each.

---@class AUICastBarTicks
---@field ticks integer? ticks spread evenly with the last at the channel's end; haste speeds them up
---@field missiles integer? shots with the first at the channel's start and the last at its end
---@field interval number? seconds between ticks; haste lengthens the channel and adds ticks
---@field talent integer? a spell that changes the tick count while known
---@field talentTicks integer? the tick count while `talent` is known
---@field addMissiles table<integer, integer>? more missiles while each spell is known

---@param spells table<integer, AUICastBarTicks> the table to add to
---@param ids integer[]
---@param entry AUICastBarTicks
local function Ranks(spells, ids, entry)
	for _, id in ipairs(ids) do
		spells[id] = entry
	end
end

local CASTIGATION = 193134
local PENANCE = { ticks = 2, talent = CASTIGATION, talentTicks = 3 }

---@type table<integer, AUICastBarTicks>
local RETAIL = {
	-- Death Knight
	[206931] = { ticks = 3 }, -- Blooddrinker
	-- Demon Hunter
	[198013] = { interval = 0.2 }, -- Eye Beam
	[473728] = { interval = 0.2 }, -- Void Ray
	[212084] = { ticks = 10 }, -- Fel Devastation
	-- Druid
	[740] = { ticks = 4 }, -- Tranquility
	-- Evoker
	[356995] = { ticks = 3, talent = 1219723, talentTicks = 4 }, -- Disintegrate, Azure Celerity
	-- Hunter
	[120360] = { ticks = 15 }, -- Barrage
	[257044] = { missiles = 7, addMissiles = { [459794] = 3 } }, -- Rapid Fire, Quick Draw
	-- Mage
	[5143] = { missiles = 5, addMissiles = { [236628] = 2 } }, -- Arcane Missiles, Amplification
	[12051] = { ticks = 6 }, -- Evocation
	[205021] = { ticks = 5 }, -- Ray of Frost
	[382440] = { ticks = 4 }, -- Shifting Power
	-- Monk
	[113656] = { ticks = 4 }, -- Fists of Fury
	[115175] = { ticks = 12 }, -- Soothing Mist
	[117952] = { ticks = 4 }, -- Crackling Jade Lightning
	[101546] = { ticks = 4 }, -- Spinning Crane Kick
	[443028] = { ticks = 4 }, -- Celestial Conduit
	-- Priest
	[15407] = { ticks = 6 }, -- Mind Flay
	[391403] = { ticks = 4 }, -- Mind Flay: Insanity
	[48045] = { ticks = 6 }, -- Mind Sear
	[263165] = { ticks = 4 }, -- Void Torrent
	[64843] = { ticks = 4 }, -- Divine Hymn
	[64902] = { ticks = 5 }, -- Symbol of Hope
	[47757] = PENANCE, -- Penance (heal)
	[47758] = PENANCE, -- Penance (damage)
	[373129] = PENANCE, -- Dark Reprimand (damage)
	[400171] = PENANCE, -- Dark Reprimand (heal)
	-- Warlock
	[198590] = { ticks = 5 }, -- Drain Soul
	[755] = { ticks = 5 }, -- Health Funnel
	[234153] = { ticks = 5 }, -- Drain Life
	-- Racial
	[291944] = { ticks = 6 }, -- Regeneratin
}

---@type table<integer, AUICastBarTicks>
local FOREVER = {}

Ranks(FOREVER, { 740, 8918, 9862, 9863 }, { ticks = 5 }) -- Tranquility
Ranks(FOREVER, { 16914, 17401, 17402 }, { ticks = 10 }) -- Hurricane
Ranks(FOREVER, { 1510, 14294, 14295 }, { ticks = 6 }) -- Volley
Ranks(FOREVER, { 136, 3111, 3661, 3662, 13542, 13543, 13544 }, { ticks = 5 }) -- Mend Pet
Ranks(FOREVER, { 10, 6141, 8427, 10185, 10186, 10187 }, { ticks = 8 }) -- Blizzard
FOREVER[5143] = { ticks = 3 } -- Arcane Missiles, rank 1
FOREVER[5144] = { ticks = 4 } -- Arcane Missiles, rank 2
Ranks(FOREVER, { 5145, 8416, 8417, 10211, 10212 }, { ticks = 5 }) -- Arcane Missiles, ranks 3 to 7
FOREVER[12051] = { ticks = 4 } -- Evocation
Ranks(FOREVER, { 15407, 17311, 17312, 17313, 17314, 18807 }, { ticks = 3 }) -- Mind Flay
-- Penance, each rank's damage, heal and cast spells; a bolt lands as the channel starts.
Ranks(FOREVER, { 402261, 402277, 402174, 1240734, 1240732, 1240720, 1240736, 1240733, 1240721, 1316994, 1316992,
	1316995 }, { ticks = 2 })
Ranks(FOREVER, { 1120, 8288, 8289, 11675 }, { ticks = 5 }) -- Drain Soul
Ranks(FOREVER, { 755, 3698, 3699, 3700, 11693, 11694, 11695 }, { ticks = 10 }) -- Health Funnel
Ranks(FOREVER, { 689, 699, 709, 7651, 11699, 11700 }, { ticks = 5 }) -- Drain Life
Ranks(FOREVER, { 5740, 6219, 11677, 11678 }, { ticks = 4 }) -- Rain of Fire
Ranks(FOREVER, { 1949, 11683, 11684 }, { ticks = 15 }) -- Hellfire
Ranks(FOREVER, { 5138, 6226, 11703, 11704 }, { ticks = 5 }) -- Drain Mana
-- Bandages.
Ranks(FOREVER, { 23567, 23696, 24414, 18610, 18608, 10839, 10838, 7927, 7926 }, { ticks = 8 })
Ranks(FOREVER, { 3268, 3267 }, { ticks = 7 })
Ranks(FOREVER, { 1159, 746 }, { ticks = 6 })

---@class AUICastBarTickData
---@field RETAIL table<integer, AUICastBarTicks>
---@field FOREVER table<integer, AUICastBarTicks>
---@field spells table<integer, AUICastBarTicks> the running client's
AUI.CastBarTickData = {
	RETAIL = RETAIL,
	FOREVER = FOREVER,
	spells = WOW_PROJECT_ID == WOW_PROJECT_CAMELOT and FOREVER or RETAIL,
}
