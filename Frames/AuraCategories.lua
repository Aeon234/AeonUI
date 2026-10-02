local AUI = select(2, ...)

---@class AUIAuraCategory
---@field own boolean? buffs from the player's own abilities: only the player's class's spells and any-class ones
---are sent
---@field spells table<integer, string> each aura spell ID and the class that casts it, or "ALL"

-- Retail. Talent and form variants are listed as their own IDs.
---@type table<string, AUIAuraCategory>
local RETAIL = {
	defensives = {
		own = true,
		spells = {
			[48707] = "DEATHKNIGHT", -- Anti-Magic Shell
			[48792] = "DEATHKNIGHT", -- Icebound Fortitude
			[55233] = "DEATHKNIGHT", -- Vampiric Blood
			[49039] = "DEATHKNIGHT", -- Lichborne
			[196555] = "DEMONHUNTER", -- Netherwalk
			[212800] = "DEMONHUNTER", -- Blur
			[187827] = "DEMONHUNTER", -- Metamorphosis (Vengeance)
			[22812] = "DRUID", -- Barkskin
			[61336] = "DRUID", -- Survival Instincts
			[22842] = "DRUID", -- Frenzied Regeneration
			[363916] = "EVOKER", -- Obsidian Scales
			[374348] = "EVOKER", -- Renewing Blaze
			[186265] = "HUNTER", -- Aspect of the Turtle
			[264735] = "HUNTER", -- Survival of the Fittest
			[45438] = "MAGE", -- Ice Block
			[342246] = "MAGE", -- Alter Time
			[11426] = "MAGE", -- Ice Barrier
			[235313] = "MAGE", -- Blazing Barrier
			[235450] = "MAGE", -- Prismatic Barrier
			[122278] = "MONK", -- Dampen Harm
			[122783] = "MONK", -- Diffuse Magic
			[120954] = "MONK", -- Fortifying Brew
			[642] = "PALADIN", -- Divine Shield
			[498] = "PALADIN", -- Divine Protection
			[31850] = "PALADIN", -- Ardent Defender
			[86659] = "PALADIN", -- Guardian of Ancient Kings
			[184662] = "PALADIN", -- Shield of Vengeance
			[47585] = "PRIEST", -- Dispersion
			[19236] = "PRIEST", -- Desperate Prayer
			[586] = "PRIEST", -- Fade
			[5277] = "ROGUE", -- Evasion
			[31224] = "ROGUE", -- Cloak of Shadows
			[1966] = "ROGUE", -- Feint
			[108271] = "SHAMAN", -- Astral Shift
			[104773] = "WARLOCK", -- Unending Resolve
			[108416] = "WARLOCK", -- Dark Pact
			[871] = "WARRIOR", -- Shield Wall
			[12975] = "WARRIOR", -- Last Stand
			[118038] = "WARRIOR", -- Die by the Sword
			[184364] = "WARRIOR", -- Enraged Regeneration
		},
	},
	activeMitigation = {
		own = true,
		spells = {
			[77535] = "DEATHKNIGHT", -- Blood Shield
			[195181] = "DEATHKNIGHT", -- Bone Shield
			[203819] = "DEMONHUNTER", -- Demon Spikes
			[192081] = "DRUID", -- Ironfur
			[215479] = "MONK", -- Shuffle
			[132403] = "PALADIN", -- Shield of the Righteous
			[132404] = "WARRIOR", -- Shield Block
			[190456] = "WARRIOR", -- Ignore Pain
		},
	},
	raidCooldowns = {
		spells = {
			[145629] = "DEATHKNIGHT", -- Anti-Magic Zone
			[209426] = "DEMONHUNTER", -- Darkness
			[374227] = "EVOKER", -- Zephyr
			[31821] = "PALADIN", -- Aura Mastery
			[81782] = "PRIEST", -- Power Word: Barrier
			[325174] = "SHAMAN", -- Spirit Link Totem
			[97463] = "WARRIOR", -- Rallying Cry
		},
	},
	externals = {
		spells = {
			[102342] = "DRUID", -- Ironbark
			[357170] = "EVOKER", -- Time Dilation
			[53480] = "HUNTER", -- Roar of Sacrifice
			[116849] = "MONK", -- Life Cocoon
			[6940] = "PALADIN", -- Blessing of Sacrifice
			[1022] = "PALADIN", -- Blessing of Protection
			[204018] = "PALADIN", -- Blessing of Spellwarding
			[33206] = "PRIEST", -- Pain Suppression
			[47788] = "PRIEST", -- Guardian Spirit
		},
	},
	coreHealing = {
		spells = {
			[774] = "DRUID", -- Rejuvenation
			[155777] = "DRUID", -- Rejuvenation (Germination)
			[8936] = "DRUID", -- Regrowth
			[33763] = "DRUID", -- Lifebloom
			[48438] = "DRUID", -- Wild Growth
			[366155] = "EVOKER", -- Reversion
			[355941] = "EVOKER", -- Dream Breath
			[364343] = "EVOKER", -- Echo
			[119611] = "MONK", -- Renewing Mist
			[124682] = "MONK", -- Enveloping Mist
			[53563] = "PALADIN", -- Beacon of Light
			[156910] = "PALADIN", -- Beacon of Faith
			[139] = "PRIEST", -- Renew
			[17] = "PRIEST", -- Power Word: Shield
			[194384] = "PRIEST", -- Atonement
			[41635] = "PRIEST", -- Prayer of Mending
			[61295] = "SHAMAN", -- Riptide
			[974] = "SHAMAN", -- Earth Shield
		},
	},
	lesserHealing = {
		spells = {
			[102352] = "DRUID", -- Cenarion Ward
			[200389] = "DRUID", -- Cultivation
			[207386] = "DRUID", -- Spring Blossoms
			[287280] = "PALADIN", -- Glimmer of Light
			[77489] = "PRIEST", -- Echo of Light
		},
	},
	support = {
		spells = {
			[29166] = "DRUID", -- Innervate
			[395152] = "EVOKER", -- Ebon Might
			[410089] = "EVOKER", -- Prescience
			[360827] = "EVOKER", -- Blistering Scales
			[369459] = "EVOKER", -- Source of Magic
			[10060] = "PRIEST", -- Power Infusion
		},
	},
	offensive = {
		own = true,
		spells = {
			[47568] = "DEATHKNIGHT", -- Empower Rune Weapon
			[51271] = "DEATHKNIGHT", -- Pillar of Frost
			[207289] = "DEATHKNIGHT", -- Unholy Assault
			[162264] = "DEMONHUNTER", -- Metamorphosis
			[194223] = "DRUID", -- Celestial Alignment
			[102560] = "DRUID", -- Incarnation: Chosen of Elune
			[106951] = "DRUID", -- Berserk
			[102543] = "DRUID", -- Incarnation: Avatar of Ashamane
			[375087] = "EVOKER", -- Dragonrage
			[19574] = "HUNTER", -- Bestial Wrath
			[288613] = "HUNTER", -- Trueshot
			[360952] = "HUNTER", -- Coordinated Assault
			[12472] = "MAGE", -- Icy Veins
			[190319] = "MAGE", -- Combustion
			[365362] = "MAGE", -- Arcane Surge
			[137639] = "MONK", -- Storm, Earth, and Fire
			[31884] = "PALADIN", -- Avenging Wrath
			[194249] = "PRIEST", -- Voidform
			[13750] = "ROGUE", -- Adrenaline Rush
			[121471] = "ROGUE", -- Shadow Blades
			[114050] = "SHAMAN", -- Ascendance (Elemental)
			[114051] = "SHAMAN", -- Ascendance (Enhancement)
			[1719] = "WARRIOR", -- Recklessness
			[107574] = "WARRIOR", -- Avatar
			[10060] = "ALL", -- Power Infusion, from a priest
			[2825] = "ALL", -- Bloodlust
			[32182] = "ALL", -- Heroism
			[80353] = "ALL", -- Time Warp
			[390386] = "ALL", -- Fury of the Aspects
			[264667] = "ALL", -- Primal Rage
		},
	},
	movement = {
		spells = {
			[1850] = "DRUID", -- Dash
			[252216] = "DRUID", -- Tiger Dash
			[77764] = "DRUID", -- Stampeding Roar
			[358267] = "EVOKER", -- Hover
			[186257] = "HUNTER", -- Aspect of the Cheetah
			[116841] = "MONK", -- Tiger's Lust
			[1044] = "PALADIN", -- Blessing of Freedom
			[221883] = "PALADIN", -- Divine Steed
			[121557] = "PRIEST", -- Angelic Feather
			[65081] = "PRIEST", -- Body and Soul
			[2983] = "ROGUE", -- Sprint
			[192082] = "SHAMAN", -- Wind Rush
			[58875] = "SHAMAN", -- Spirit Walk
			[111400] = "WARLOCK", -- Burning Rush
		},
	},
	utility = {
		spells = {
			[130] = "MAGE", -- Slow Fall
			[1706] = "PRIEST", -- Levitate
			[546] = "SHAMAN", -- Water Walking
			[5384] = "HUNTER", -- Feign Death
			[1784] = "ROGUE", -- Stealth
			[11327] = "ROGUE", -- Vanish
			[32612] = "MAGE", -- Invisibility
		},
	},
	consumables = {
		spells = {
			[431932] = "ALL", -- Tempered Potion
		},
	},
}

-- Forever: vanilla-style classes, each spell with every rank.
---@type table<string, AUIAuraCategory>
local FOREVER = {
	defensives = {
		own = true,
		spells = {
			[22812] = "DRUID", -- Barkskin
			[22842] = "DRUID", [22895] = "DRUID", [22896] = "DRUID", -- Frenzied Regeneration
			[11958] = "MAGE", -- Ice Block
			[11426] = "MAGE", [13031] = "MAGE", [13032] = "MAGE", [13033] = "MAGE", -- Ice Barrier
			[1463] = "MAGE", [8494] = "MAGE", [8495] = "MAGE", [10191] = "MAGE", [10192] = "MAGE", -- Mana Shield
			[10193] = "MAGE",
			[642] = "PALADIN", [1020] = "PALADIN", -- Divine Shield
			[498] = "PALADIN", [5573] = "PALADIN", -- Divine Protection
			[586] = "PRIEST", [9578] = "PRIEST", [9579] = "PRIEST", [9592] = "PRIEST", -- Fade
			[10941] = "PRIEST", [10942] = "PRIEST",
			[27827] = "PRIEST", -- Spirit of Redemption
			[5277] = "ROGUE", -- Evasion
			[11327] = "ROGUE", [11329] = "ROGUE", -- Vanish
			[871] = "WARRIOR", -- Shield Wall
			[12976] = "WARRIOR", -- Last Stand
			[20230] = "WARRIOR", -- Retaliation
			[19263] = "HUNTER", -- Deterrence
			[6229] = "WARLOCK", [11739] = "WARLOCK", [11740] = "WARLOCK", [28610] = "WARLOCK", -- Shadow Ward
		},
	},
	raidCooldowns = {
		spells = {
			[740] = "DRUID", [8918] = "DRUID", [9862] = "DRUID", [9863] = "DRUID", -- Tranquility
		},
	},
	externals = {
		spells = {
			[1022] = "PALADIN", [5599] = "PALADIN", [10278] = "PALADIN", -- Blessing of Protection
			[6940] = "PALADIN", [20729] = "PALADIN", -- Blessing of Sacrifice
			[10060] = "PRIEST", -- Power Infusion
			[29166] = "DRUID", -- Innervate
		},
	},
	coreHealing = {
		spells = {
			[139] = "PRIEST", [6074] = "PRIEST", [6075] = "PRIEST", [6076] = "PRIEST", [6077] = "PRIEST", -- Renew
			[6078] = "PRIEST", [10927] = "PRIEST", [10928] = "PRIEST", [10929] = "PRIEST", [25315] = "PRIEST",
			[17] = "PRIEST", [592] = "PRIEST", [600] = "PRIEST", [3747] = "PRIEST", [6065] = "PRIEST", -- Power Word: Shield
			[6066] = "PRIEST", [10898] = "PRIEST", [10899] = "PRIEST", [10900] = "PRIEST", [10901] = "PRIEST",
			[774] = "DRUID", [1058] = "DRUID", [1430] = "DRUID", [2090] = "DRUID", [2091] = "DRUID", -- Rejuvenation
			[3627] = "DRUID", [8910] = "DRUID", [9839] = "DRUID", [9840] = "DRUID", [9841] = "DRUID", [25299] = "DRUID",
			[8936] = "DRUID", [8938] = "DRUID", [8939] = "DRUID", [8940] = "DRUID", [8941] = "DRUID", -- Regrowth
			[9750] = "DRUID", [9856] = "DRUID", [9857] = "DRUID", [9858] = "DRUID",
		},
	},
	offensive = {
		own = true,
		spells = {
			[12042] = "MAGE", -- Arcane Power
			[11129] = "MAGE", -- Combustion
			[12043] = "MAGE", -- Presence of Mind
			[13877] = "ROGUE", -- Blade Flurry
			[13750] = "ROGUE", -- Adrenaline Rush
			[1719] = "WARRIOR", -- Recklessness
			[12292] = "WARRIOR", -- Death Wish
			[12328] = "WARRIOR", -- Sweeping Strikes
			[19574] = "HUNTER", -- Bestial Wrath
			[3045] = "HUNTER", -- Rapid Fire
			[16166] = "SHAMAN", -- Elemental Mastery
			[10060] = "ALL", -- Power Infusion, from a priest
		},
	},
	movement = {
		spells = {
			[2983] = "ROGUE", [8696] = "ROGUE", [11305] = "ROGUE", -- Sprint
			[1850] = "DRUID", [9821] = "DRUID", -- Dash
			[5118] = "HUNTER", -- Aspect of the Cheetah
			[13159] = "HUNTER", -- Aspect of the Pack
			[1044] = "PALADIN", -- Blessing of Freedom
		},
	},
	utility = {
		spells = {
			[130] = "MAGE", -- Slow Fall
			[1706] = "PRIEST", -- Levitate
			[6346] = "PRIEST", -- Fear Ward
			[546] = "SHAMAN", -- Water Walking
			[131] = "SHAMAN", -- Water Breathing
			[5384] = "HUNTER", -- Feign Death
			[1784] = "ROGUE", -- Stealth
		},
	},
	consumables = {
		spells = {
			[17543] = "ALL", -- Greater Fire Protection Potion
			[17544] = "ALL", -- Greater Frost Protection Potion
			[17546] = "ALL", -- Greater Nature Protection Potion
			[17548] = "ALL", -- Greater Shadow Protection Potion
			[17549] = "ALL", -- Greater Arcane Protection Potion
			[6615] = "ALL", -- Free Action Potion
			[17538] = "ALL", -- Elixir of the Mongoose
			[11405] = "ALL", -- Elixir of the Giants
			[17539] = "ALL", -- Greater Arcane Elixir
			[17626] = "ALL", -- Flask of the Titans
			[17627] = "ALL", -- Flask of Distilled Wisdom
			[17628] = "ALL", -- Flask of Supreme Power
			[16323] = "ALL", -- Juju Power
			[16329] = "ALL", -- Juju Might
			[17038] = "ALL", -- Winterfall Firewater
			[10667] = "ALL", -- Rage of Ages
		},
	},
}

---Curated player buff categories: spell lists by client, and the list a display's chosen categories send to the game.
---@class AUIAuraCategories
---@field ORDER string[] every category, in display order
local AuraCategories = {
	ORDER = AUI.Schema.choices.buffCategories,
}
AUI.AuraCategories = AuraCategories

---@return table<string, AUIAuraCategory> catalogue the running client's
function AuraCategories:Catalogue()
	return AUI.can.retailSpells and RETAIL or FOREVER
end

---@return string[] categories the running client offers, in display order
function AuraCategories:Available()
	local catalogue, available = self:Catalogue(), {}

	for _, key in ipairs(self.ORDER) do
		if catalogue[key] then
			available[#available + 1] = key
		end
	end

	return available
end

---@param chosen table<string, boolean>? each category's switch
---@param class string? the player's class
---@return table<integer, boolean> spells the spell IDs to show
function AuraCategories:Spells(chosen, class)
	local spells = {}

	for key, category in pairs(self:Catalogue()) do
		if not chosen or chosen[key] ~= false then
			for id, owner in pairs(category.spells) do
				if not category.own or owner == "ALL" or owner == class then
					spells[id] = true
				end
			end
		end
	end

	return spells
end
