local AUI = select(2, ...)

---@class AUIUpgradeTrack
---@field minLevel number the item level at rank 1
---@field maxLevel number the item level at the last rank
---@field ranks integer
---@field quality integer the item quality whose color the rank takes
---@field crest integer? the currency the track's upgrades cost

---@param minLevel number
---@param maxLevel number
---@param quality integer
---@param crest integer
---@return AUIUpgradeTrack
local function Track(minLevel, maxLevel, quality, crest)
	return { minLevel = minLevel, maxLevel = maxLevel, ranks = 6, quality = quality, crest = crest }
end

---Upgrade tracks per season, keyed by the season's first interface version (`select(4, GetBuildInfo())`); the largest
---key not above the running client's applies. A track missing from a season leaves its items with their rank's color
---alone. Updated every season as part of release upkeep.
---@type table<integer, AUIUpgradeTrack[]>
AUI.TooltipUpgradeSeasons = {
	-- Midnight season 1: Adventurer, Veteran, Champion, Hero, Myth.
	[120001] = {
		Track(220, 237, 1, 3383),
		Track(233, 250, 2, 3341),
		Track(246, 263, 3, 3343),
		Track(259, 276, 4, 3345),
		Track(272, 289, 5, 3347),
	},
	-- Midnight season 2: Champion, Hero, Myth.
	[120100] = {
		Track(292, 308, 3, 3444),
		Track(305, 321, 4, 3445),
		Track(318, 334, 5, 3446),
	},
}
