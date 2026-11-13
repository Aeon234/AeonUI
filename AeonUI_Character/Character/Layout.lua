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
---@field model AUICharacterModelPlace? between the columns, down to the weapon row; nil without the model

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

---@param opts { model: boolean, gauges: boolean }
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
		-- One row centered under the columns, its text narrowed to fit beside the ammo slot.
		local room = leftWidth - LEFT_PAD - RIGHT_PAD
		local ammo = ICON + WEAPON_GAP
		local textWidth = math.min(TEXT_WIDTH, math.floor((room - ammo - 2 * WEAPON_GAP) / 3) - ICON - gauge)
		local width = ICON + gauge + textWidth
		local x = LEFT_PAD + math.max(0, (room - (3 * width + 2 * WEAPON_GAP + ammo)) / 2)

		for _, slot in ipairs(Options.WEAPON_SLOTS) do
			slots[slot] = Place(x, weaponsTop, "LEFT", textWidth)
			x = x + width + WEAPON_GAP
		end
		slots[Options.AMMO_SLOT] = Place(x, weaponsTop, "LEFT", 0)
		bottom = weaponsTop + ICON
		model = { x = LEFT_PAD + column, y = TOP, width = MODEL_WIDTH, height = weaponsTop - TOP }
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
