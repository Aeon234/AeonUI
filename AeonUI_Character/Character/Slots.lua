local AUI = select(2, ...)

local L = AUI.L
local Options, Gear = AUI.CharacterOptions, AUI.CharacterGear

local ICON = 40
local SHADOW_SIZE = 80 -- the shadow texture's canvas, centered on the icon
local TEXT_GAP = 6 -- between the icon, or its gauge, and the text
local GAUGE_GAP, GAUGE_WIDTH = 3, 3
local GAUGE_ROOM = 9 -- a gauge and the gaps either side, as Layout widens each column
local WHITE = { r = 1, g = 1, b = 1 }
local AMMO_FRAME = "UI-Character-Info-GearSlotSmall" -- the ammo slot's frame, an unnamed texture on the button

---The textures and text the feature adds to one slot button, kept apart from Blizzard's frame.
---@class AUICharacterSlotParts
---@field overlay Frame above the button, holding the outline, shade and text
---@field shadow Texture on the button, below its icon
---@field slotFrame table? Blizzard's frame around the slot: the template's `BorderFrame`, or the ammo slot's texture
---@field outline Texture
---@field shade Texture
---@field level FontString the item level on the icon
---@field name FontString
---@field enchant FontString
---@field gauge Texture the durability gauge's track
---@field fill Texture

---Dresses Blizzard's slot buttons while the panel is extended: a quality outline with its shadow and the icon's
---inner shade, the item level on the icon, and beside it the item's name and enchant, or an empty slot's name. Blizzard's
---own border, slot frame and icon are only cropped, tinted or cleared, and put back by `Restore`.
---@class AUICharacterSlots
---@field hooked boolean
---@field painted table<table, true> the buttons dressed since the last `Restore`
---@field parts table<table, AUICharacterSlotParts> by button, created on first paint
---@field holding boolean an item is on the cursor
---@field fade (fun(slot: integer): boolean)? the slots a fade keeps; the rest sit at `fadeAlpha`
---@field fadeAlpha number
local Slots = {
	hooked = false,
	painted = {},
	parts = {},
	holding = false,
	fadeAlpha = 1,
}
AUI.CharacterSlots = Slots

---@param button table
---@return AUICharacterSlotParts
local function Build(button)
	local overlay = CreateFrame("Frame", nil, button)
	local parts = { overlay = overlay, slotFrame = button.BorderFrame }

	if not parts.slotFrame then
		for _, region in ipairs({ button:GetRegions() }) do
			if region.GetAtlas and region:GetAtlas() == AMMO_FRAME then
				parts.slotFrame = region
			end
		end
	end

	overlay:SetAllPoints(button)
	overlay:SetFrameLevel(button:GetFrameLevel() + 1)

	parts.shadow = button:CreateTexture(nil, "BACKGROUND")
	parts.shadow:SetTexture(Options.SHADOW)
	parts.shadow:SetVertexColor(0, 0, 0, Options.SHADOW_ALPHA)
	parts.shadow:SetSize(SHADOW_SIZE, SHADOW_SIZE)
	parts.shadow:SetPoint("CENTER", button, "CENTER")

	parts.shade = overlay:CreateTexture(nil, "ARTWORK")
	parts.shade:SetTexture(Options.SHADE)
	parts.shade:SetVertexColor(0, 0, 0, Options.SHADE_ALPHA)
	parts.shade:SetAllPoints(button)

	parts.outline = overlay:CreateTexture(nil, "OVERLAY")
	parts.outline:SetAllPoints(button)

	parts.level = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	parts.level:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)

	parts.name = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	parts.name:SetWordWrap(false)
	parts.enchant = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	parts.enchant:SetWordWrap(false)

	parts.gauge = overlay:CreateTexture(nil, "ARTWORK")
	parts.gauge:SetColorTexture(0, 0, 0, 0.6)
	parts.gauge:SetSize(GAUGE_WIDTH, ICON)
	parts.fill = overlay:CreateTexture(nil, "OVERLAY")
	parts.fill:SetTexture("Interface\\Buttons\\WHITE8x8")
	parts.fill:SetWidth(GAUGE_WIDTH)
	parts.fill:SetPoint("BOTTOM", parts.gauge, "BOTTOM")

	return parts
end

---Places the text beside the icon, toward the middle of the pane: two lines around the icon's middle, or one line
---centered on it.
---@param parts AUICharacterSlotParts
---@param button table
---@param place AUICharacterSlotPlace
---@param gauge boolean the column holds a gauge
---@param twoLines boolean
local function Arrange(parts, button, place, gauge, twoLines)
	local left = place.side == "LEFT"
	local edge = left and "RIGHT" or "LEFT"
	local sign = left and 1 or -1
	local offset = sign * (TEXT_GAP + (gauge and GAUGE_ROOM or 0))
	local justify = left and "LEFT" or "RIGHT"

	parts.gauge:ClearAllPoints()
	parts.gauge:SetPoint(left and "LEFT" or "RIGHT", button, edge, sign * GAUGE_GAP, 0)

	for _, text in ipairs({ parts.name, parts.enchant }) do
		text:ClearAllPoints()
		text:SetWidth(place.textWidth)
		text:SetJustifyH(justify)
	end

	if twoLines then
		parts.name:SetPoint("BOTTOM" .. justify, button, edge, offset, 1)
		parts.enchant:SetPoint("TOP" .. justify, button, edge, offset, -1)
	else
		parts.name:SetPoint(justify, button, edge, offset, 0)
	end
end

---@param slot integer
---@return number
function Slots:Alpha(slot)
	local alpha = 1

	if self.holding and not C_PaperDollInfo.CursorCanGoInSlot(slot) then
		alpha = Options.DIM
	end
	if self.fade and not self.fade(slot) then
		alpha = math.min(alpha, self.fadeAlpha)
	end

	return alpha
end

---Dresses one slot button from its item. Does nothing unless the panel is extended and the button is placed.
---@param button table
function Slots:Paint(button)
	local layout = AUI.CharacterFrame.layout
	local slot = button:GetID()
	local place = layout and layout.slots[slot]

	if not place or _G[Options.SLOT_BUTTONS[slot]] ~= button then
		return
	end

	local Profile = AUI.Profile
	local parts = self.parts[button] or Build(button)
	local item = Gear:Read(slot)
	local icon = button.icon
	local crop = Options.ICON_CROP
	local hasText = place.textWidth > 0
	local gauges = Profile:Get(Options.GAUGES_PATH) == true

	-- The ammo slot's item has no link on Forever; Blizzard's own test for a filled slot is its texture.
	if not item and GetInventoryItemTexture("player", slot) then
		item = { quality = AUI:Readable(GetInventoryItemQuality("player", slot)) }
	end

	self.parts[button] = parts
	self.painted[button] = true
	parts.overlay:Show()
	button.IconBorder:SetAlpha(0)
	if parts.slotFrame then
		parts.slotFrame:SetAlpha(0)
	end
	button:SetAlpha(self:Alpha(slot))
	icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)

	if not item then
		parts.outline:SetTexture(Options.EMPTY_FRAME)
		parts.outline:SetVertexColor(unpack(Options.EMPTY_COLOR))
		parts.shadow:Hide()
		parts.shade:Hide()
		parts.level:Hide()
		parts.enchant:Hide()
		parts.gauge:Hide()
		parts.fill:Hide()
		icon:SetVertexColor(0, 0, 0)
		icon:SetAlpha(Options.WELL_ALPHA)
		parts.name:SetText(Options:SlotName(slot))
		parts.name:SetTextColor(unpack(Options.EMPTY_TEXT))
		parts.name:SetShown(hasText)
		Arrange(parts, button, place, gauges, false)

		return
	end

	local color = item.quality and ITEM_QUALITY_COLORS[item.quality] or WHITE
	local enchant = hasText and Profile:Get(Options.ENCHANTS_PATH) == true and item.enchantable
	local current, maximum = item.current, item.maximum
	local itemLevel = Profile:Get(Options.ITEM_LEVEL_PATH) == true and item.itemLevel or nil

	parts.outline:SetTexture(Options.OUTLINES[Profile:Get(Options.QUALITY_BORDER_PATH)] or Options.OUTLINES.NORMAL)
	parts.outline:SetVertexColor(color.r, color.g, color.b)
	parts.shadow:Show()
	parts.shade:Show()
	icon:SetAlpha(1)

	if itemLevel then
		parts.level:SetText(tostring(itemLevel))
	end
	parts.level:SetShown(itemLevel ~= nil)

	parts.name:SetText(item.name)
	parts.name:SetTextColor(color.r, color.g, color.b)
	parts.name:SetShown(hasText)

	if enchant then
		local textColor = item.enchant and GREEN_FONT_COLOR or RED_FONT_COLOR

		parts.enchant:SetText(item.enchant or L["No Enchant"])
		parts.enchant:SetTextColor(textColor.r, textColor.g, textColor.b)
	end
	parts.enchant:SetShown(enchant == true)

	local durability, fraction = false, 0

	if gauges and current and maximum and maximum > 0 then
		durability, fraction = true, current / maximum

		local fill = Options:GaugeColor(fraction)

		parts.fill:SetHeight(ICON * fraction)
		parts.fill:SetVertexColor(fill.r, fill.g, fill.b)
	end
	parts.gauge:SetShown(durability)
	parts.fill:SetShown(fraction > 0)

	Arrange(parts, button, place, gauges, enchant == true)
end

function Slots:PaintAll()
	for _, name in pairs(Options.SLOT_BUTTONS) do
		self:Paint(_G[name])
	end

	AUI.Events:Register("CURSOR_CHANGED", self, self.OnCursorChanged)
end

---Sets every dressed slot's alpha from the held item and the fade.
function Slots:UpdateAlpha()
	for button in pairs(self.painted) do
		button:SetAlpha(self:Alpha(button:GetID()))
	end
end

function Slots:OnCursorChanged()
	AUI.Events:Coalesce("characterCursor", function()
		Slots.holding = CursorHasItem() == true
		Slots:UpdateAlpha()
	end)
end

---Fades every slot `predicate` does not keep to `alpha`; a nil predicate clears the fade.
---@param predicate (fun(slot: integer): boolean)?
---@param alpha number?
function Slots:SetFade(predicate, alpha)
	self.fade, self.fadeAlpha = predicate, alpha or 1
	self:UpdateAlpha()
end

---Puts back everything `Paint` changed on Blizzard's buttons and hides what it added.
function Slots:Restore()
	AUI.Events:Unregister("CURSOR_CHANGED", self)
	AUI.Events:Cancel("characterCursor")
	self.holding = false

	for button in pairs(self.painted) do
		local parts = self.parts[button]

		parts.overlay:Hide()
		parts.shadow:Hide()
		button.IconBorder:SetAlpha(1)
		if parts.slotFrame then
			parts.slotFrame:SetAlpha(1)
		end
		button:SetAlpha(1)
		button.icon:SetTexCoord(0, 1, 0, 1)
		button.icon:SetAlpha(1)
		if not GetInventoryItemLink("player", button:GetID()) then
			button.icon:SetVertexColor(1, 1, 1)
		end
	end
	self.painted = {}
end

function Slots:Hook()
	if self.hooked then
		return
	end

	self.hooked = true
	hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
		if AUI.CharacterFrame:IsExtended() then
			Slots:Paint(button)
		end
	end)
end
