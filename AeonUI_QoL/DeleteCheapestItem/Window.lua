local AUI = select(2, ...)

local L = AUI.L
local lib = LibStub("LibAeonSettings-1.0")
local Options = AUI.DeleteCheapestItemOptions
local Bags = AUI.DeleteCheapestItemBags
local Actions = AUI.DeleteCheapestItemActions

local NAME = "AeonUIDeleteCheapestItem"
local ROW_HEIGHT = 48
local ROW_SPACING = 2
local ROW_PAD = 6
-- Height the status lines add above the list, beyond the template's own top inset.
local HEADER_HEIGHT = 44
local GAP = 4
local EDGE_INSET = 20
local SETTLE_RESPONSE = 0.3
local PRESS_SCALE = 0.85
local PRESS_RESPONSE = 0.15
local ACTION_SIZE = 28
local LABEL_PADDING = 14
local DELETE_ICON = "common-icon-delete"
local DELETE_ICON_FALLBACK = "common-icon-redx"
-- Seconds a row asking to confirm waits for the second click.
local CONFIRM_SECONDS = 3
-- Seconds the Undo message stays.
local TOAST_SECONDS = 6

-- Each action mode's colors at rest, hovered and pressed: background, edge, and the icon's or label's color.
local ACTION_STYLES = {
	DELETE = {
		rest = { bg = { 0.14, 0.125, 0.1 }, edge = { 0.3, 0.27, 0.2 }, fg = { 0.8, 0.8, 0.8 } },
		hover = { bg = { 0.42, 0.08, 0.06 }, edge = { 0.82, 0.34, 0.25 }, fg = { 1, 1, 1 } },
		press = { bg = { 0.3, 0.05, 0.04 }, edge = { 0.82, 0.34, 0.25 }, fg = { 1, 1, 1 } },
	},
	CONFIRM = {
		rest = { bg = { 0.64, 0.13, 0.1 }, edge = { 1, 0.56, 0.45 }, fg = { 1, 1, 1 } },
		hover = { bg = { 0.76, 0.17, 0.13 }, edge = { 1, 0.66, 0.55 }, fg = { 1, 1, 1 } },
		press = { bg = { 0.5, 0.1, 0.08 }, edge = { 1, 0.56, 0.45 }, fg = { 1, 1, 1 } },
	},
	SELL = {
		rest = { bg = { 0.14, 0.125, 0.1 }, edge = { 0.3, 0.27, 0.2 }, fg = { 0.96, 0.84, 0.49 } },
		hover = { bg = { 0.3, 0.23, 0.05 }, edge = { 0.88, 0.7, 0.3 }, fg = { 1, 0.95, 0.77 } },
		press = { bg = { 0.22, 0.17, 0.04 }, edge = { 0.88, 0.7, 0.3 }, fg = { 1, 0.95, 0.77 } },
	},
}
local CHIP_FULL = { bg = { 0.36, 0.08, 0.06 }, text = { 1, 0.7, 0.66 } }
local CHIP_OK = { bg = { 0.12, 0.23, 0.09 }, text = { 0.71, 0.95, 0.65 } }
local WARN_COLOR = { 1, 0.69, 0.25 }

local BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }

---Why the window is open and what it sits beside.
---@class AUIDeleteCheapestItemContext
---@field kind "LOOT"|"MERCHANT"|"QUEST"|"HAND"
---@field opener Frame? the window it sits beside; the screen's left edge when nil
---@field incoming { name: string, quality: integer, value: number }? the item it makes room for
---@field lootSlot integer? the loot slot a delete makes room for, taken once the bags have settled

---The Delete Cheapest Item window: `ScrollingFlatPanelTemplate`, as the loot window uses, beside the window that
---opened it with their tops level. Created the first time it opens.
---@class AUIDeleteCheapestItemWindow
---@field frame AeonUIDeleteCheapestItemMixin?
---@field context AUIDeleteCheapestItemContext?
---@field onShown fun(shown: boolean, byCode: boolean)? called as the window shows and hides; `byCode` when it was
---closed by `Window:Close` rather than by hand
---@field closing boolean `Window:Close` started the hide
---@field hooked table<Frame, true> openers whose size changes re-place the window
---@field sliding AeonUIDeleteCheapestItemRowMixin? the row sliding out; the list is rebuilt when it finishes
---@field toastTimer table? hides the Undo message
local Window = {
	hooked = {},
	closing = false,
}
AUI.DeleteCheapestItemWindow = Window

---The row's action button (`AeonUIDeleteCheapestItemActionTemplate`).
---@class AUIDeleteCheapestItemAction : Button, BackdropTemplate
---@field Icon Texture
---@field Label FontString

---A row's content (`AeonUIDeleteCheapestItemRowTemplate`), offset from the row while it settles.
---@class AUIDeleteCheapestItemRowContent : Frame
---@field Item ItemButton
---@field Action AUIDeleteCheapestItemAction
---@field Name FontString
---@field Source FontString
---@field Price FontString
---@field Highlight Texture

---The header's status chip.
---@class AUIDeleteCheapestItemChip : Frame
---@field Text FontString
---@field Background Texture

---The Undo message at the window's foot.
---@class AUIDeleteCheapestItemToast : Frame, BackdropTemplate
---@field Text FontString
---@field Undo Button
---@field itemID integer?

---A list row: an item card as the loot window draws them, with the item's worth and its action button.
---@class AeonUIDeleteCheapestItemRowMixin : Frame
---@field Content AUIDeleteCheapestItemRowContent
---@field SlideOutRightAnim AnimationGroup
---@field entry AUIDeleteCheapestItemEntry
---@field mode "DELETE"|"CONFIRM"|"SELL" what the action button does
---@field hovered boolean
---@field pressed boolean
---@field busy boolean its action ran; it is leaving the list
---@field confirmTimer table? returns the row from Confirm to Delete
---@field settle table the spring that brings the content back to the row after the list moves
---@field press table the spring that shrinks the action's icon while pressed
AeonUIDeleteCheapestItemRowMixin = {}

local Row = AeonUIDeleteCheapestItemRowMixin

function Row:OnLoad()
	local content = self.Content
	local action = content.Action

	content.Item:EnableMouse(false)
	self.mode, self.hovered, self.pressed, self.busy = "DELETE", false, false, false
	self.settle = lib:CreateSpring(0, function(offset)
		content:SetPoint("TOPLEFT", 0, offset)
		content:SetPoint("BOTTOMRIGHT", 0, offset)
	end, { response = SETTLE_RESPONSE, epsilon = 0.1 })
	self.press = lib:CreateSpring(1, function(scale)
		action.Icon:SetSize(16 * scale, 16 * scale)
	end, { response = PRESS_RESPONSE, epsilon = 0.002 })
	self.SlideOutRightAnim:SetScript("OnFinished", function()
		Window:OnSlideFinished(self)
	end)
	self:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" and self.entry and not self.busy then
			Window:ShowMenu(self)
		end
	end)

	action.Icon:SetAtlas(C_Texture.GetAtlasInfo(DELETE_ICON) and DELETE_ICON or DELETE_ICON_FALLBACK)
	action:SetBackdrop(BACKDROP)
	action:SetScript("OnEnter", function()
		self.hovered = true
		self:PaintAction()
		self:ShowActionTooltip()
	end)
	action:SetScript("OnLeave", function()
		self.hovered, self.pressed = false, false
		self:PaintAction()
		self.press:To(1)
		GameTooltip:Hide()
	end)
	action:SetScript("OnMouseDown", function()
		self.pressed = true
		self:PaintAction()
		self.press:To(PRESS_SCALE)
	end)
	action:SetScript("OnMouseUp", function()
		self.pressed = false
		self:PaintAction()
		self.press:To(1)
	end)
	action:SetScript("OnClick", function()
		Window:Act(self)
	end)
	self:SetMode("DELETE")
end

function Row:PaintAction()
	local action = self.Content.Action
	local styles = ACTION_STYLES[self.mode]
	local style = self.pressed and styles.press or self.hovered and styles.hover or styles.rest

	action:SetBackdropColor(style.bg[1], style.bg[2], style.bg[3], 1)
	action:SetBackdropBorderColor(style.edge[1], style.edge[2], style.edge[3], 1)
	action.Icon:SetVertexColor(style.fg[1], style.fg[2], style.fg[3])
	action.Label:SetTextColor(style.fg[1], style.fg[2], style.fg[3])
end

---@param mode "DELETE"|"CONFIRM"|"SELL"
function Row:SetMode(mode)
	local action = self.Content.Action
	local label = mode == "CONFIRM" and L["Confirm"] or mode == "SELL" and L["Sell"] or nil

	self.mode = mode
	action.Icon:SetShown(label == nil)
	action.Label:SetShown(label ~= nil)
	action.Label:SetText(label or "")
	action:SetWidth(label and math.max(ACTION_SIZE, action.Label:GetStringWidth() + LABEL_PADDING) or ACTION_SIZE)
	self:PaintAction()
end

---Asks for a second click within a few seconds, or stops asking.
---@param on boolean
function Row:SetConfirming(on)
	if self.confirmTimer then
		self.confirmTimer:Cancel()
		self.confirmTimer = nil
	end

	if on then
		self.confirmTimer = C_Timer.NewTimer(CONFIRM_SECONDS, function()
			self.confirmTimer = nil
			self:SetMode("DELETE")
		end)
	end

	self:SetMode(on and "CONFIRM" or "DELETE")

	if self.hovered then
		self:ShowActionTooltip()
	end
end

---@param entry AUIDeleteCheapestItemEntry
---@param incoming number? copper the incoming item is worth
---@param selling boolean the action sells instead of deleting
function Row:Init(entry, incoming, selling)
	local content = self.Content
	local color = ITEM_QUALITY_COLORS[entry.quality] or HIGHLIGHT_FONT_COLOR
	local source = entry.source == "AUCTION" and L["Auction"] or L["Vendor"]

	if self.confirmTimer then
		self.confirmTimer:Cancel()
		self.confirmTimer = nil
	end

	self.entry = entry
	self.busy = false
	self.SlideOutRightAnim:Stop()
	self:SetAlpha(1)
	self.settle:Jump(0)
	self.press:Jump(1)
	self:SetMode(selling and "SELL" or "DELETE")

	SetItemButtonTexture(content.Item, entry.icon)
	SetItemButtonCount(content.Item, entry.count)
	SetItemButtonQuality(content.Item, entry.quality, entry.link)
	content.Name:SetText(entry.name)
	content.Name:SetTextColor(color.r, color.g, color.b)
	content.Price:SetText(GetMoneyString(entry.value, true))

	if entry.stacks > 1 then
		source = ("%s · %s"):format(source, L["%d stacks"]:format(entry.stacks))
	end

	if not selling and Options.NeedsConfirm(entry.value, incoming) then
		content.Source:SetText(L["More than the loot"])
		content.Source:SetTextColor(WARN_COLOR[1], WARN_COLOR[2], WARN_COLOR[3])
	else
		content.Source:SetText(source)
		content.Source:SetTextColor(GRAY_FONT_COLOR:GetRGB())
	end
end

---Shows the content where the row used to be, then lets it settle into place.
---@param offset number units the row moved up since the last layout; negative when it moved down
function Row:Settle(offset)
	self.settle:Jump(-offset)
	self.settle:To(0)
end

function Row:ShowActionTooltip()
	GameTooltip:SetOwner(self.Content.Action, "ANCHOR_RIGHT")
	GameTooltip:SetText(Window:ActionText(self.entry), 1, 1, 1, 1, true)
	GameTooltip:Show()
end

function Row:OnEnter()
	self.Content.Highlight:Show()
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetBagItem(self.entry.bag, self.entry.slot)
	GameTooltip:Show()
end

function Row:OnLeave()
	self.Content.Highlight:Hide()
	GameTooltip:Hide()
end

---The window's frame.
---@class AeonUIDeleteCheapestItemMixin : Frame
---@field ScrollBox table
---@field ScrollBar table
---@field Chip AUIDeleteCheapestItemChip
---@field Free FontString
---@field Detail FontString
---@field Empty FontString
---@field Toast AUIDeleteCheapestItemToast
---@field HideAnim AnimationGroup
---@field Open fun(self: AeonUIDeleteCheapestItemMixin) shows the panel, sizes it and plays its show animation
---@field Close fun(self: AeonUIDeleteCheapestItemMixin) plays the hide animation
---@field Resize fun(self: AeonUIDeleteCheapestItemMixin) sizes the panel to its rows
---@field SetTitle fun(self: AeonUIDeleteCheapestItemMixin, title: string)
AeonUIDeleteCheapestItemMixin = CreateFromMixins(ScrollingFlatPanelMixin)

local Panel = AeonUIDeleteCheapestItemMixin

function Panel:OnLoad()
	ScrollingFlatPanelMixin.OnLoad(self)
	self:SetTitle(L["Delete Cheapest Item"])
	self:RegisterForDrag("LeftButton")

	local scrollBox = self.ScrollBox

	scrollBox:SetPoint("TOPLEFT", 4, -22 - HEADER_HEIGHT)
	self.ScrollBar:SetPoint("TOPLEFT", self, "TOPRIGHT", -16, -28 - HEADER_HEIGHT)
	self.Empty:SetPoint("TOPLEFT", scrollBox, "TOPLEFT", 12, -14)
	self.Empty:SetPoint("TOPRIGHT", scrollBox, "TOPRIGHT", -12, -14)

	local view = CreateScrollBoxListLinearView(ROW_PAD, ROW_PAD, ROW_PAD, ROW_PAD, ROW_SPACING)

	view:SetElementInitializer("AeonUIDeleteCheapestItemRowTemplate", function(row, entry)
		local context = Window.context
		local incoming = context and context.incoming

		row:Init(entry, incoming and incoming.value, context ~= nil and context.kind == "MERCHANT")
	end)
	ScrollUtil.InitScrollBoxWithScrollBar(scrollBox, self.ScrollBar, view)

	-- The scroll-edge shadows above every row and its buttons, scaled and inset as the loot window's are.
	scrollBox:SetShadowsFrameLevel(scrollBox.ScrollTarget:GetFrameLevel() + 15)
	scrollBox:SetShadowsScale(0.2)
	scrollBox:GetUpperShadowTexture():SetTexCoord(0, 1, 1, 0)
	scrollBox:GetUpperShadowTexture():SetPoint("TOPLEFT", 30, 0)
	scrollBox:GetUpperShadowTexture():SetPoint("TOPRIGHT", -30, 0)
	scrollBox:GetLowerShadowTexture():SetPoint("BOTTOMLEFT", 30, 0)
	scrollBox:GetLowerShadowTexture():SetPoint("BOTTOMRIGHT", -30, 0)

	local toast = self.Toast

	toast:SetFrameLevel(scrollBox.ScrollTarget:GetFrameLevel() + 20)
	toast:SetBackdrop(BACKDROP)
	toast:SetBackdropColor(0.07, 0.065, 0.06, 0.95)
	toast:SetBackdropBorderColor(0.42, 0.35, 0.22, 1)
	toast.Undo:SetText(L["Undo"])
	toast.Undo:SetScript("OnClick", function()
		Window:Undo()
	end)
end

---@return number height the rows' height, at least one row's for the empty state, and the status lines
function Panel:CalculateElementsHeight()
	local rows = ScrollUtil.CalculateScrollBoxElementExtent(self.ScrollBox:GetDataProviderSize(), ROW_HEIGHT,
		ROW_SPACING)

	return math.max(rows, ROW_HEIGHT) + HEADER_HEIGHT
end

---Hides directly: Blizzard's `HideUIPanel` does nothing in combat.
function Panel:OnHideAnimFinished()
	self:Hide()
end

function Panel:OnShow()
	Window.closing = false

	if Window.onShown then
		Window.onShown(true, false)
	end
end

function Panel:OnHide()
	local byCode = Window.closing

	Window.closing = false
	Window:HideToast()
	Window.sliding = nil

	if Window.onShown then
		Window.onShown(false, byCode)
	end
end

function Panel:OnDragStart()
	self:StartMoving()
end

---A drag moves the window for this opening only: the client would otherwise save the place and restore it.
function Panel:OnDragStop()
	self:StopMovingOrSizing()
	self:SetUserPlaced(false)
end

---@return AeonUIDeleteCheapestItemMixin frame
function Window:Frame()
	if not self.frame then
		local frame = CreateFrame("Frame", NAME, UIParent, "AeonUIDeleteCheapestItemTemplate")

		---@cast frame AeonUIDeleteCheapestItemMixin
		tinsert(UISpecialFrames, NAME)
		self.frame = frame
	end

	return self.frame
end

---@return boolean shown
function Window:IsShown()
	return self.frame ~= nil and self.frame:IsShown()
end

---@return Frame? bags Blizzard's open bags: the combined bag, or the leftmost open general bag
function Window:OpenBags()
	if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then
		return ContainerFrameCombinedBags
	end

	local leftmost

	for index = 1, NUM_CONTAINER_FRAMES or 0 do
		local frame = _G["ContainerFrame" .. index]

		if frame and frame:IsShown() and (not leftmost or (frame:GetLeft() or 0) < (leftmost:GetLeft() or 0)) then
			leftmost = frame
		end
	end

	return leftmost
end

---Anchors the window beside its opener with their tops level, on the side with room, or at the screen's left edge.
function Window:Place()
	local frame, context = self.frame, self.context

	if not frame or not context then
		return
	end

	local opener = context.opener

	frame:ClearAllPoints()

	if not opener or not opener:IsShown() then
		frame:SetPoint("LEFT", UIParent, "LEFT", EDGE_INSET, 0)

		return
	end

	local ratio = opener:GetEffectiveScale() / frame:GetEffectiveScale()
	local side = Options.Side((opener:GetLeft() or 0) * ratio, (opener:GetRight() or 0) * ratio, frame:GetWidth(), GAP,
		UIParent:GetLeft() or 0, UIParent:GetRight() or 0)

	if side == "RIGHT" then
		frame:SetPoint("TOPLEFT", opener, "TOPRIGHT", GAP, 0)
	else
		frame:SetPoint("TOPRIGHT", opener, "TOPLEFT", -GAP, 0)
	end

	if not self.hooked[opener] then
		self.hooked[opener] = true
		opener:HookScript("OnSizeChanged", function()
			if self.context and self.context.opener == opener and self:IsShown() then
				self:Place()
			end
		end)
	end
end

---@param free integer
function Window:Header(free)
	local frame = self.frame --[[@as AeonUIDeleteCheapestItemMixin]]
	local context = self.context --[[@as AUIDeleteCheapestItemContext]]
	local chip, style, label = frame.Chip, CHIP_OK, L["Space"]
	local incoming = context.incoming

	if context.kind == "MERCHANT" then
		label = MERCHANT
	elseif free == 0 then
		style, label = CHIP_FULL, L["Bags Full"]
	end

	chip.Text:SetText(label)
	chip.Text:SetTextColor(style.text[1], style.text[2], style.text[3])
	chip.Background:SetColorTexture(style.bg[1], style.bg[2], style.bg[3], 1)
	chip:SetWidth(chip.Text:GetStringWidth() + 12)
	frame.Free:SetText(free == 1 and L["1 free slot"] or L["%d free slots"]:format(free))

	if context.kind == "LOOT" and incoming then
		local quality = ITEM_QUALITY_COLORS[incoming.quality]
		local name = quality and quality.color:WrapTextInColorCode(incoming.name) or incoming.name

		frame.Detail:SetText(L["Looting %s · %s"]:format(name, GetMoneyString(incoming.value, true)))
	elseif context.kind == "MERCHANT" then
		frame.Detail:SetText(L["Sell the cheapest to make room."])
	else
		frame.Detail:SetText("")
	end
end

---Rebuilds the list from the bags. Rows that stay show where they were and settle into their new places.
---@param settle boolean
function Window:Fill(settle)
	local frame = self.frame --[[@as AeonUIDeleteCheapestItemMixin]]
	local scrollBox = frame.ScrollBox
	local tops = {}

	if settle then
		scrollBox:ForEachFrame(function(row)
			if row.entry and not row.busy then
				tops[Options.RowKey(row.entry)] = row:GetTop()
			end
		end)
	end

	local entries, free = Bags:List(Actions:Ignored())
	local provider = CreateDataProvider()

	for _, entry in ipairs(entries) do
		provider:Insert(entry)
	end

	self:Header(free)
	scrollBox:SetDataProvider(provider, ScrollBoxConstants.RetainScrollPosition)
	frame.Empty:SetText(L["Nothing to suggest. Ignored items and items above %s aren't listed."]:format(
		_G["ITEM_QUALITY" .. Options:Rules().maxQuality .. "_DESC"] or ""))
	frame.Empty:SetShown(#entries == 0)
	frame:Resize()

	if settle then
		scrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
		scrollBox:ForEachFrame(function(row)
			local top = row.entry and tops[Options.RowKey(row.entry)]

			if top then
				row:Settle((row:GetTop() or top) - top)
			end
		end)
	end
end

---@param entry AUIDeleteCheapestItemEntry
---@return string text what the row's action does
function Window:ActionText(entry)
	local context = self.context
	local incoming = context and context.incoming

	if context and context.kind == "MERCHANT" then
		return L["Sell %s"]:format(entry.name)
	end

	if context and context.kind == "LOOT" and incoming then
		return L["Delete %s, then loot %s"]:format(entry.name, incoming.name)
	end

	return L["Delete %s"]:format(entry.name)
end

---Runs a row's action: sells at a merchant; otherwise deletes, after a second click when the row is worth more than
---the incoming item. A row whose stack moved is not acted on; the list is rebuilt instead.
---@param row AeonUIDeleteCheapestItemRowMixin
function Window:Act(row)
	local context, entry = self.context, row.entry

	if row.busy or not context or not entry then
		return
	end

	local done

	if context.kind == "MERCHANT" then
		done = Actions:Sell(entry)
	else
		local incoming = context.incoming

		if row.mode ~= "CONFIRM" and Options.NeedsConfirm(entry.value, incoming and incoming.value) then
			row:SetConfirming(true)

			return
		end

		done = Actions:Delete(entry, context.lootSlot)
	end

	if done then
		self:SlideOut(row)
	else
		self:Refresh()
	end
end

---Slides an acted-on row out to the right, as the loot window's cards leave; the list is rebuilt when it has gone.
---With Reduce Motion the row hides at once and the bags' update rebuilds the list.
---@param row AeonUIDeleteCheapestItemRowMixin
function Window:SlideOut(row)
	row.busy = true
	row:SetConfirming(false)
	GameTooltip:Hide()

	if lib:ReduceMotion() then
		row:SetAlpha(0)

		return
	end

	self.sliding = row
	row.SlideOutRightAnim:Play()
end

---@param row AeonUIDeleteCheapestItemRowMixin
function Window:OnSlideFinished(row)
	if self.sliding ~= row then
		return
	end

	self.sliding = nil

	if self:IsShown() then
		self:Fill(true)
	end
end

---@param row AeonUIDeleteCheapestItemRowMixin
function Window:ShowMenu(row)
	local entry = row.entry

	MenuUtil.CreateContextMenu(row, function(_, root)
		root:CreateTitle(entry.name)
		root:CreateButton(L["Never Suggest"], function()
			self:Ignore(entry)
		end)
		root:CreateButton(L["Link in Chat"], function()
			ChatFrameUtil.LinkItem(entry.itemID, entry.link)
		end)
	end)
end

---Leaves an item out of every list from now on, with an Undo message.
---@param entry AUIDeleteCheapestItemEntry
function Window:Ignore(entry)
	local toast = (self.frame --[[@as AeonUIDeleteCheapestItemMixin]]).Toast

	Actions:SetIgnored(entry.itemID, true)
	toast.itemID = entry.itemID
	toast.Text:SetText(L["Won't suggest %s."]:format(entry.name))
	toast:Show()

	if self.toastTimer then
		self.toastTimer:Cancel()
	end

	self.toastTimer = C_Timer.NewTimer(TOAST_SECONDS, function()
		self.toastTimer = nil
		self:HideToast()
	end)
	self:Refresh()
end

function Window:Undo()
	local toast = (self.frame --[[@as AeonUIDeleteCheapestItemMixin]]).Toast

	if toast.itemID then
		Actions:SetIgnored(toast.itemID, false)
	end

	self:HideToast()
	self:Refresh()
end

function Window:HideToast()
	if self.toastTimer then
		self.toastTimer:Cancel()
		self.toastTimer = nil
	end

	if self.frame then
		self.frame.Toast.itemID = nil
		self.frame.Toast:Hide()
	end
end

---Opens the window, or brings an open one to a new context.
---@param context AUIDeleteCheapestItemContext
function Window:Open(context)
	local frame = self:Frame()

	self.context = context
	self:Fill(false)

	-- A window still playing its hide animation shows again rather than hiding when the animation ends.
	if not frame:IsShown() or frame.HideAnim:IsPlaying() then
		self.closing = false
		frame:Open()
	else
		frame:Resize()
	end

	self:Place()
end

---Rebuilds an open window's list, its rows settling into their new places. While a row slides out, its finish
---rebuilds the list instead.
function Window:Refresh()
	if self:IsShown() and not self.sliding then
		self:Fill(true)
	end
end

function Window:Close()
	local frame = self.frame

	if frame and frame:IsShown() then
		self.closing = true
		frame:Close()
	end
end
