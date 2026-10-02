local AUI = select(2, ...)

-- Spell data the client does not provide. Every entry is unverified until it is seen in game; record the check in
-- AeonDocs when it is. Spell IDs from Retail and Forever share each table: an ID a character does not know is never
-- matched. `/aui dev channel` prints the current channel's spell ID, name and duration for adding entries.

---@class AUIChannelTicks
---@field ticks integer? a fixed number of ticks; haste shortens the channel and the ticks with it
---@field interval number? seconds between ticks; haste lengthens the channel and adds ticks
---@field talent integer? a spell that changes the tick count while known
---@field talentTicks integer? the tick count while `talent` is known

---@class AUICastData
---@field channels table<integer, AUIChannelTicks> the player's channeled spells, by spell ID
---@field interrupts table<string, integer[]> each class's interrupts, by class file name; later entries win
local CastData = {
	channels = {
		-- Priest
		[15407] = { ticks = 6 }, -- Mind Flay
		[391403] = { ticks = 4 }, -- Mind Flay: Insanity
		[47757] = { ticks = 3, talent = 193134, talentTicks = 4 }, -- Penance (heal), Castigation
		[47758] = { ticks = 3, talent = 193134, talentTicks = 4 }, -- Penance (damage), Castigation
		[373129] = { ticks = 3, talent = 193134, talentTicks = 4 }, -- Dark Reprimand (damage)
		[400171] = { ticks = 3, talent = 193134, talentTicks = 4 }, -- Dark Reprimand (heal)
		[263165] = { ticks = 4 }, -- Void Torrent
		[64843] = { ticks = 4 }, -- Divine Hymn
		-- Mage
		[5143] = { ticks = 5 }, -- Arcane Missiles
		[205021] = { ticks = 5 }, -- Ray of Frost
		[382440] = { ticks = 4 }, -- Shifting Power
		[12051] = { ticks = 6 }, -- Evocation
		-- Warlock
		[234153] = { ticks = 5 }, -- Drain Life
		[198590] = { ticks = 5 }, -- Drain Soul
		[755] = { ticks = 5 }, -- Health Funnel
		-- Druid
		[740] = { ticks = 4 }, -- Tranquility
		-- Monk
		[117952] = { ticks = 4 }, -- Crackling Jade Lightning
		[115175] = { interval = 1 }, -- Soothing Mist
		[113656] = { ticks = 5 }, -- Fists of Fury
		[101546] = { ticks = 4 }, -- Spinning Crane Kick
		-- Evoker
		[356995] = { ticks = 4 }, -- Disintegrate
		-- Hunter
		[257044] = { ticks = 7 }, -- Rapid Fire
		-- Demon Hunter
		[198013] = { interval = 0.2 }, -- Eye Beam
		[212084] = { interval = 0.2 }, -- Fel Devastation
	},
	interrupts = {
		DEATHKNIGHT = { 47528 }, -- Mind Freeze
		DEMONHUNTER = { 183752 }, -- Disrupt
		DRUID = { 78675, 106839 }, -- Solar Beam, Skull Bash
		EVOKER = { 351338 }, -- Quell
		HUNTER = { 187707, 147362 }, -- Muzzle, Counter Shot
		MAGE = { 2139 }, -- Counterspell
		MONK = { 116705 }, -- Spear Hand Strike
		PALADIN = { 31935, 96231 }, -- Avenger's Shield, Rebuke
		PRIEST = { 15487 }, -- Silence
		ROGUE = { 1766, 1767, 1768, 1769, 38768 }, -- Kick and its ranks
		SHAMAN = { 8042, 8044, 8045, 8046, 10412, 10413, 10414, 57994 }, -- Earth Shock ranks, Wind Shear
		-- Felhunter Spell Lock (and its command-demon forms), Felguard Axe Toss, Observer Optical Blast
		WARLOCK = { 19244, 19647, 119910, 132409, 89766, 115781 },
		WARRIOR = { 72, 1671, 1672, 6552, 6554 }, -- Shield Bash and Pummel ranks
	},
}
AUI.CastData = CastData
