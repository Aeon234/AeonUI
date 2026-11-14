local AUI = select(2, ...)

local Options = AUI.CharacterOptions

local ICON = 40
local STEP = 46 -- an icon and the gap below it
local TOP = 40 -- the first row, down from the left pane's top
local LEFT_PAD, RIGHT_PAD = 24, 20
local TEXT_WIDTH = 150
local GAUGE_WIDTH = 9 -- a 3-wide gauge with 3 either side
local MODEL_WIDTH = 210
local GAP_WITHOUT_MODEL = 16
local WEAPON_GAP = 10
local WEAPONS_BELOW = 16 -- from the last column row to the weapon row
local PANE_TOP = 20 -- the left pane, down from the frame's top
local STRIP = 36 -- Blizzard's top strip holding the name and level, where the model starts
-- The model's scene. Blizzard's camera sizes the model mostly by the scene's width; at this width and the height down
-- to the weapon row, the feet land just above that row.
local SCENE_WIDTH = 500
local BOTTOM_PAD = 26
local STATS_WIDTH = 233

---One slot's place in the left pane: `x` from the pane's left edge, or from its right edge on the right side, and
---`y` down from its top. The text sits on the side facing the middle.
---@class AUICharacterSlotPlace
---@field x number
---@field y number
---@field side "LEFT"|"RIGHT"
---@field textWidth number 0 for a slot without text

---The model's column in the left pane, as a slot's place without a side.
---@class AUICharacterModelPlace
---@field x number
---@field y number
---@field width number
---@field height number

---@class AUICharacterLayoutResult
---@field leftWidth number the left pane
---@field width number the frame with the stats pane shown
---@field height number
---@field slots table<integer, AUICharacterSlotPlace> by slot ID, the ammo slot at `Options.AMMO_SLOT`
---@field model AUICharacterModelPlace? centered, its feet at the weapon row; nil without the model

---The extended character panel's arithmetic: the frame's size and each slot's place.
---@class AUICharacterLayout
local Layout = {}
AUI.CharacterLayout = Layout

---@param x number
---@param y number
---@param side "LEFT"|"RIGHT"
---@param textWidth number
---@return AUICharacterSlotPlace
local function Place(x, y, side, textWidth)
	return { x = x, y = y, side = side, textWidth = textWidth }
end

---@param opts { model: boolean, gauges: boolean, ammo: boolean?, ranged: boolean? } `ammo` and `ranged` false when
---Blizzard hides that slot; nil counts as shown
---@return AUICharacterLayoutResult
function Layout:Compute(opts)
	local gauge = opts.gauges and GAUGE_WIDTH or 0
	local column = ICON + gauge + TEXT_WIDTH
	local leftWidth = LEFT_PAD + column + (opts.model and MODEL_WIDTH or GAP_WITHOUT_MODEL) + column + RIGHT_PAD
	local slots = {}

	for row, slot in ipairs(Options.LEFT_SLOTS) do
		slots[slot] = Place(LEFT_PAD, TOP + (row - 1) * STEP, "LEFT", TEXT_WIDTH)
	end
	for row, slot in ipairs(Options.RIGHT_SLOTS) do
		slots[slot] = Place(RIGHT_PAD, TOP + (row - 1) * STEP, "RIGHT", TEXT_WIDTH)
	end

	local mainHand, offHand, ranged = Options.WEAPON_SLOTS[1], Options.WEAPON_SLOTS[2], Options.WEAPON_SLOTS[3]
	local weaponsTop = TOP + (#Options.LEFT_SLOTS - 1) * STEP + ICON + WEAPONS_BELOW
	local bottom, model

	if opts.model then
		-- One row centered under the columns, its text narrowed to fit beside the ammo slot; Blizzard hides the ranged
		-- and ammo slots for classes without them, so the row leaves them out.
		local weapons = { mainHand, offHand }
		local room = leftWidth - LEFT_PAD - RIGHT_PAD
		local ammo = opts.ammo ~= false and ICON + WEAPON_GAP or 0

		if opts.ranged ~= false then
			weapons[3] = ranged
		end

		local gaps = (#weapons - 1) * WEAPON_GAP
		local textWidth = math.min(TEXT_WIDTH, math.floor((room - ammo - gaps) / #weapons) - ICON - gauge)
		local width = ICON + gauge + textWidth
		local x = LEFT_PAD + math.max(0, (room - (#weapons * width + gaps + ammo)) / 2)

		for _, slot in ipairs(weapons) do
			slots[slot] = Place(x, weaponsTop, "LEFT", textWidth)
			x = x + width + WEAPON_GAP
		end
		if opts.ammo ~= false then
			slots[Options.AMMO_SLOT] = Place(x, weaponsTop, "LEFT", 0)
		end
		bottom = weaponsTop + ICON
		model = { x = (leftWidth - SCENE_WIDTH) / 2, y = STRIP, width = SCENE_WIDTH, height = weaponsTop - STRIP }
	else
		-- Too narrow for a weapon row with text: the weapons continue the columns.
		slots[mainHand] = Place(LEFT_PAD, weaponsTop, "LEFT", TEXT_WIDTH)
		slots[offHand] = Place(RIGHT_PAD, weaponsTop, "RIGHT", TEXT_WIDTH)
		slots[ranged] = Place(LEFT_PAD, weaponsTop + STEP, "LEFT", TEXT_WIDTH)
		slots[Options.AMMO_SLOT] = Place(RIGHT_PAD, weaponsTop + STEP, "RIGHT", 0)
		bottom = weaponsTop + STEP + ICON
	end

	return {
		leftWidth = leftWidth,
		width = leftWidth + STATS_WIDTH,
		height = PANE_TOP + bottom + BOTTOM_PAD,
		slots = slots,
		model = model,
	}
end
