local AUI = select(2, ...)

local Options = AUI.InterfaceOptions

-- Blizzard's roll frame (`GroupLootFrameTemplate`, `GroupLootFrameBaseTemplate`), and its place while the bottom
-- managed container has none.
local BOX_WIDTH, BOX_HEIGHT = 277, 67
local FALLBACK_POSITION = { point = "BOTTOM", x = 0, y = 250 }

---Moves Blizzard's loot roll frames to a box placed in edit mode. Until a position is saved Blizzard places them.
---Once one is, a post-hook on `GroupLootContainer_Update` anchors each frame in `GroupLootContainer.rollFrames` to
---the box, stacked upward at Blizzard's spacing. The container itself is left to Blizzard's bottom managed layout and
---the alert frames, and no field is written on a Blizzard frame, so neither runs tainted. None of these frames is
---protected, so nothing waits for combat.
---@class AUILootRolls
---@field box Frame? the box the roll frames stack up from
---@field hooked boolean `GroupLootContainer_Update` is hooked
local LootRolls = {
	hooked = false,
}
AUI.LootRolls = LootRolls

---@return boolean fixed a position was saved, so AeonUI places the roll frames
function LootRolls:Fixed()
	return Options:Get(Options.LOOT_ROLLS_POSITION_PATH) ~= nil
end

---@return Frame box
function LootRolls:Box()
	local box = self.box

	if not box then
		box = CreateFrame("Frame", "AeonUILootRolls", UIParent)
		box:SetSize(BOX_WIDTH, BOX_HEIGHT)
		box:EnableMouse(false)
		self.box = box
		self:Place()
	end

	return box
end

---Puts the box at its saved place, or its default one.
function LootRolls:Place()
	local box = self.box

	if not box then
		return
	end

	local position = Options:Get(Options.LOOT_ROLLS_POSITION_PATH) or self:DefaultPosition()

	box:ClearAllPoints()
	box:SetPoint(position.point, UIParent, position.point, position.x, position.y)
end

---@return { point: string, x: number, y: number } position the bottom of Blizzard's managed container, where the
---first roll frame shows by default
function LootRolls:DefaultPosition()
	local container = BottomManagedFrameContainer
	local left, right, bottom = container:GetLeft(), container:GetRight(), container:GetBottom()

	if not left or not right or not bottom then
		return FALLBACK_POSITION
	end

	local scale = container:GetEffectiveScale() / UIParent:GetEffectiveScale()

	return {
		point = "BOTTOM",
		x = math.floor((left + right) / 2 * scale - UIParent:GetWidth() / 2 + 0.5),
		y = math.floor(bottom * scale + 0.5),
	}
end

---Anchors each roll frame where `GroupLootContainer_Update` puts it, measured from the box while fixed and from the
---container otherwise. Skipped under the Gamepad style, where Blizzard leaves the frames unplaced.
function LootRolls:Arrange()
	if InputUtil ~= nil and InputUtil.IsGamepadUIEnabled ~= nil and InputUtil.IsGamepadUIEnabled() then
		return
	end

	local container = GroupLootContainer --[[@as table]]
	local spacing = container.reservedSize
	local fixed = self:Fixed()
	local box = fixed and self:Box()

	for index = 1, container.maxIndex or 0 do
		local frame = container.rollFrames[index]

		if frame then
			frame:ClearAllPoints()

			if box then
				frame:SetPoint("CENTER", box, "CENTER", 0, spacing * (index - 1))
			else
				frame:SetPoint("CENTER", container, "BOTTOM", 0, spacing * (index - 0.5))
			end
		end
	end
end

function LootRolls:Apply()
	if not AUI.can.lootRolls then
		return
	end

	self:Place()

	if self:Fixed() and not self.hooked then
		self.hooked = true
		hooksecurefunc("GroupLootContainer_Update", function()
			if self:Fixed() then
				self:Arrange()
			end
		end)
	end

	if self.hooked and GroupLootContainer:IsShown() then
		self:Arrange()
	end
end
