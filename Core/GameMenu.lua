local AUI = select(2, ...)

-- The space `AddSection` leaves above a section, used when the menu's own spacing cannot be read.
local SECTION_GAP = 20

---The AeonUI entry in the game menu (Escape): an AeonUI-owned button in its own section above the logout section.
---Blizzard's pooled buttons are moved after each layout pass, never added to or changed otherwise.
---@class AUIGameMenu
---@field button Button? created once by `Create`
local GameMenu = {}
AUI.GameMenu = GameMenu

---Where the AeonUI section goes, from the top padding of each pooled button in layout order (a padding above zero
---starts a section): before the last section, or before the one above it when the last holds only the close button.
---@param paddings number[]
---@return integer? index the button the section goes above; nil to go below the last button
---@return number gap the space above a section
function GameMenu.Slot(paddings)
	local count = #paddings
	local last, previous

	for index = 2, count do
		if paddings[index] > 0 then
			previous, last = last, index
		end
	end

	local slot = last

	if last == count and previous then
		slot = previous
	end

	if not slot then
		return nil, SECTION_GAP
	end

	return slot, paddings[slot]
end

---A button from `GameMenuFrame.buttonPool`, with the fields its vertical layout reads.
---@class AUIGameMenuPooledButton : Button
---@field layoutIndex integer
---@field topPadding number?

---@param left AUIGameMenuPooledButton
---@param right AUIGameMenuPooledButton
---@return boolean
local function ByLayoutIndex(left, right)
	return left.layoutIndex < right.layoutIndex
end

local function OnClick()
	if not InCombatLockdown() then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
		HideUIPanel(GameMenuFrame)
	end

	AUI:OpenSettings()
end

---Places the button after Blizzard's layout pass: sized as its neighbor, in its own section, with the buttons below
---it moved down and the menu grown by the same amount.
function GameMenu:Place()
	local button = self.button

	if not button then
		return
	end

	local buttons = {}

	for pooled in GameMenuFrame.buttonPool:EnumerateActive() do
		if pooled.layoutIndex then
			buttons[#buttons + 1] = pooled
		end
	end

	if #buttons == 0 then
		button:Hide()

		return
	end

	table.sort(buttons, ByLayoutIndex)

	local paddings = {}

	for index, pooled in ipairs(buttons) do
		paddings[index] = pooled.topPadding or 0
	end

	local slot, gap = GameMenu.Slot(paddings)
	local above = buttons[slot and slot - 1 or #buttons]
	local width, height = above:GetSize()

	button:SetSize(width, height)
	button:ClearAllPoints()
	button:SetPoint("TOP", above, "BOTTOM", 0, -gap)
	button:Show()

	local shift = height + gap

	for index = slot or #buttons + 1, #buttons do
		local pooled = buttons[index]
		local point, relativeTo, relativePoint, x, y = pooled:GetPoint(1)

		if point then
			pooled:ClearAllPoints()
			pooled:SetPoint(point, relativeTo, relativePoint, x, (y or 0) - shift)
		end
	end

	GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + shift)
end

---Creates the button once and follows Blizzard's layout passes. Runs at login.
function GameMenu:Create()
	if self.button or not AUI.can.gameMenu then
		return
	end

	local button = CreateFrame("Button", "AeonUIGameMenuButton", GameMenuFrame, GameMenuFrame.buttonTemplate)
	button:SetText(AUI.brand)
	button:SetScript("OnClick", OnClick)
	button:Hide()
	self.button = button

	hooksecurefunc(GameMenuFrame, "Layout", function()
		self:Place()
	end)
end
