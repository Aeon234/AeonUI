local AUI = select(2, ...)

---Each class's spells for measuring range, the first one a character knows being used. Spell IDs from Retail and Forever
---share each list: an ID a character does not know is never matched. A class with no list for a kind of unit never fades
---for that kind.
---@class AUIRangeSpells
---@field harmful table<string, integer[]> for an enemy
---@field helpful table<string, integer[]> for a friend
AUI.RangeSpells = {
	harmful = {
		DEATHKNIGHT = { 47541, 49576 }, -- Death Coil, Death Grip
		DEMONHUNTER = { 185123, 204021, 183752 }, -- Throw Glaive, Fiery Brand, Consume Magic
		DRUID = { 8921, 5176, 6795 }, -- Moonfire, Wrath, Growl
		EVOKER = { 361469, 362969 }, -- Living Flame, Azure Strike
		HUNTER = { 75, 3044 }, -- Auto Shot, Arcane Shot
		MAGE = { 116, 133, 44425, 2139 }, -- Frostbolt, Fireball, Arcane Barrage, Counterspell
		MONK = { 117952, 115546 }, -- Crackling Jade Lightning, Provoke
		PALADIN = { 20271, 62124, 853 }, -- Judgment, Hand of Reckoning, Hammer of Justice
		PRIEST = { 589, 585 }, -- Shadow Word: Pain, Smite
		ROGUE = { 185565, 185763, 36554, 2094, 2764 }, -- Poisoned Knife, Pistol Shot, Shadowstep, Blind, Throw
		SHAMAN = { 188196, 403, 370 }, -- Lightning Bolt (both), Purge
		WARLOCK = { 686, 232670, 234153, 172, 348 }, -- Shadow Bolt (both), Drain Life, Corruption, Immolate
		WARRIOR = { 355, 100 }, -- Taunt, Charge
	},
	helpful = {
		DEATHKNIGHT = { 47541 }, -- Death Coil
		DRUID = { 8936, 5185 }, -- Regrowth, Healing Touch
		EVOKER = { 361469 }, -- Living Flame
		MAGE = { 1459, 475 }, -- Arcane Intellect, Remove Curse
		MONK = { 116670 }, -- Vivify
		PALADIN = { 19750, 635 }, -- Flash of Light, Holy Light
		PRIEST = { 2061, 2050, 2054 }, -- Flash Heal, Lesser Heal, Heal
		ROGUE = { 57934 }, -- Tricks of the Trade
		SHAMAN = { 8004, 188070, 331 }, -- Healing Surge (both), Healing Wave
		WARLOCK = { 20707, 5697 }, -- Soulstone, Unending Breath
		WARRIOR = { 3411 }, -- Intervene
	},
}
