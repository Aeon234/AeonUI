-- The S0 Delete Cheapest Item probe: a window on the loot window's template that lists the cheapest bag items and
-- deletes one from a button click, with an event trace, so each open question can be answered in game. Development
-- only; never packaged. Undo with /reload.
local AUI = select(2, ...)

local ROW_HEIGHT = 46
local ROW_SPACING = 2
local ROW_PAD = 6
local ROW_LIMIT = 8
local EDGE_INSET = 20
local EDGE_FADE_LENGTH = 30

local TRACED_EVENTS = {
	"LOOT_READY", "LOOT_OPENED", "LOOT_CLOSED", "LOOT_SLOT_CLEARED", "UI_ERROR_MESSAGE", "BAG_UPDATE",
	"BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "DELETE_ITEM_CONFIRM", "CURSOR_CHANGED", "ITEM_PUSH",
}

---@class AUIDeleteCheapestItemProbeEntry
---@field bag integer
---@field slot integer
---@field itemID integer
---@field link string
---@field name string
---@field quality integer
---@field icon number
---@field count integer
---@field value integer the stack's sell price in copper

---@class AUIDeleteCheapestItemProbe
---@field frame AeonUIDeleteCheapestItemProbeMixin? the probe window, `AeonUIDeleteCheapestItemProbe`, set at load
---@field opener table? the window the probe sits beside
---@field side "auto"|"right"|"left" which side of the opener the probe takes
---@field gap number horizontal gap between the opener and the probe
---@field maxQuality integer the highest quality listed
---@field lootMode "after"|"immediate"|"off" when a loot slot is taken after a delete
---@field closeMode "override"|"blizzard" what finishing the hide animation calls
---@field dragMode "clear"|"dontsave"|"none" how a drag's saved position is suppressed
---@field edgeMode "fade"|"shadow" how the list marks rows scrolled out of view
---@field tracing boolean the event trace prints
---@field traceStart number GetTimePreciseSec when the trace started
---@field pending table? the delete waiting for its bag update
---@field watching boolean blocked-action events are registered
local Probe = {
	side = "auto",
	gap = 4,
	maxQuality = 0,
	lootMode = "after",
	closeMode = "override",
	dragMode = "clear",
	edgeMode = "shadow",
	tracing = false,
	traceStart = 0,
	watching = false,
}
AUI.Dev.DeleteCheapestItemProbe = Probe

---@return string text milliseconds since the trace started
local function Stamp()
	return ("%7.1f ms"):format((GetTimePreciseSec() - Probe.traceStart) * 1000)
end

---@param format string
---@param ... any
local function Log(format, ...)
	AUI:Print("dci %s  " .. format, Stamp(), ...)
end

---@return integer? slot the first loot slot holding an item, while the loot window is open
local function FirstLootItem()
	if not LootFrame:IsShown() then
		return nil
	end

	for slot = 1, GetNumLootItems() do
		if LootSlotHasItem(slot) then
			return slot
		end
	end

	return nil
end

---@return integer free free slots in general-purpose bags
---@return AUIDeleteCheapestItemProbeEntry[] entries listed bag items, cheapest first
---@return integer uncached items skipped because their info is not cached
function Probe:Scan()
	local free, entries, uncached = 0, {}, 0

	for bag = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
		local bagFree, family = C_Container.GetContainerNumFreeSlots(bag)

		if family == 0 then
			free = free + bagFree
		end

		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)

			if info and not info.hasNoValue and not info.isLocked and (info.quality or 0) <= self.maxQuality then
				local name, _, _, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(info.hyperlink)

				if name and sellPrice then
					entries[#entries + 1] = {
						bag = bag,
						slot = slot,
						itemID = info.itemID,
						link = info.hyperlink,
						name = name,
						quality = info.quality or 0,
						icon = info.iconFileID,
						count = info.stackCount,
						value = sellPrice * info.stackCount,
					}
				else
					uncached = uncached + 1
				end
			end
		end
	end

	table.sort(entries, function(a, b)
		if a.value ~= b.value then
			return a.value < b.value
		end

		return a.bag < b.bag or (a.bag == b.bag and a.slot < b.slot)
	end)

	return free, entries, uncached
end

---Fills the list from the bags and resizes and places the window.
function Probe:Fill()
	local frame = self.frame

	if not frame then
		return
	end

	local free, entries, uncached = self:Scan()
	local provider = CreateDataProvider()

	for index = 1, math.min(#entries, ROW_LIMIT) do
		provider:Insert(entries[index])
	end

	frame.ScrollBox:SetDataProvider(provider)
	frame:Resize()
	self:Place()
	frame:SetTitle(("Probe: %d free, %d listed%s"):format(free, #entries,
		uncached > 0 and (", " .. uncached .. " uncached") or ""))
end

function Probe:Refresh()
	if self.frame and self.frame:IsShown() then
		self:Fill()
	end
end

---@return number right the opener's right edge in the probe's coordinates
local function RightEdge(opener, frame)
	return (opener:GetRight() or 0) * opener:GetEffectiveScale() / frame:GetEffectiveScale()
end

---Anchors the probe beside its opener with the tops level, or at the left edge of the screen without one.
function Probe:Place()
	local frame = self.frame

	if not frame then
		return
	end

	local opener = self.opener

	frame:ClearAllPoints()

	if not opener or not opener:IsShown() then
		frame:SetPoint("LEFT", UIParent, "LEFT", EDGE_INSET, 0)

		return
	end

	local side = self.side

	if side == "auto" then
		local fits = RightEdge(opener, frame) + self.gap + frame:GetWidth() <= UIParent:GetRight()

		side = fits and "right" or "left"
	end

	if side == "right" then
		frame:SetPoint("TOPLEFT", opener, "TOPRIGHT", self.gap, 0)
	else
		frame:SetPoint("TOPRIGHT", opener, "TOPLEFT", -self.gap, 0)
	end
end

---@return table? opener the shown window the probe belongs beside
---@return string kind
local function FindOpener()
	if LootFrame:IsShown() then
		return LootFrame, "loot"
	end

	if MerchantFrame:IsShown() then
		return MerchantFrame, "merchant"
	end

	if QuestFrame:IsShown() then
		return QuestFrame, "quest"
	end

	return nil, "none"
end

function Probe:Watch()
	if self.watching then
		return
	end

	self.watching = true
	AUI.Events:Register("ADDON_ACTION_BLOCKED", self, self.OnBlocked)
	AUI.Events:Register("ADDON_ACTION_FORBIDDEN", self, self.OnBlocked)
	AUI.Events:Register("BAG_UPDATE_DELAYED", self, self.OnBagsSettled)
	AUI.Events:Register("GET_ITEM_INFO_RECEIVED", self, self.Refresh)
end

---@param event string
---@param addon string
---@param action string
function Probe:OnBlocked(event, addon, action)
	if addon == AUI.name then
		Log("|cffff4040%s|r %s, combat %s", event, tostring(action), tostring(InCombatLockdown()))
	end
end

function Probe:Open()
	self:Watch()

	local frame = self.frame

	if not frame then
		return
	end

	local opener, kind = FindOpener()

	self.opener = opener

	AUI:Print("dci: opener %s, user placed before placing %s, points %d", kind, tostring(frame:IsUserPlaced()),
		frame:GetNumPoints())

	self:Fill()
	frame:Open()
	self:Place()
	self:ReportPlacement()
end

function Probe:ReportPlacement()
	local frame = self.frame

	if not frame then
		return
	end

	local opener = self.opener
	local point, relative, relativePoint, x, y = frame:GetPoint(1)

	AUI:Print("dci: %s to %s %s (%.1f, %.1f), user placed %s, don't save %s", tostring(point),
		relative and (relative:GetName() or "?") or "nil", tostring(relativePoint), x or 0, y or 0,
		tostring(frame:IsUserPlaced()), tostring(frame:GetDontSavePosition()))

	if opener then
		local scale = frame:GetEffectiveScale()
		local openerTop = (opener:GetTop() or 0) * opener:GetEffectiveScale()

		AUI:Print("dci: tops differ by %.2f pixels; probe %.0f x %.0f, opener %.0f x %.0f, scroll bar %s",
			(frame:GetTop() or 0) * scale - openerTop, frame:GetWidth(), frame:GetHeight(), opener:GetWidth(),
			opener:GetHeight(), tostring(frame.ScrollBar:IsShown()))
	end
end

---Deletes an entry's bag slot from the delete button's click, after checking that the slot still holds it.
---@param entry AUIDeleteCheapestItemProbeEntry
---@param row table the row frame
function Probe:Delete(entry, row)
	if CursorHasItem() then
		Log("refused: the cursor already holds something")

		return
	end

	local info = C_Container.GetContainerItemInfo(entry.bag, entry.slot)

	if not info or info.hyperlink ~= entry.link or info.stackCount ~= entry.count then
		Log("refused: bag %d slot %d changed since the list was built", entry.bag, entry.slot)
		self:Refresh()

		return
	end

	C_Container.PickupContainerItem(entry.bag, entry.slot)

	local kind, itemID = GetCursorInfo()

	if kind ~= "item" or itemID ~= entry.itemID then
		Log("refused: the cursor holds %s %s after the pickup", tostring(kind), tostring(itemID))
		ClearCursor()

		return
	end

	self.pending = { entry = entry, at = GetTimePreciseSec() }
	DeleteCursorItem()
	Log("DeleteCursorItem called for %s x%d (quality %d); cursor still holds an item: %s", entry.link, entry.count,
		entry.quality, tostring(CursorHasItem()))

	if row.SlideOutRightAnim then
		row.SlideOutRightAnim:Play()
	end

	if self.lootMode == "immediate" then
		local slot = FirstLootItem()

		if slot then
			Log("LootSlot(%d) at once, as Reloaded does", slot)
			LootSlot(slot)
		end
	end
end

function Probe:OnBagsSettled()
	local pending = self.pending

	if pending then
		local entry = pending.entry
		local info = C_Container.GetContainerItemInfo(entry.bag, entry.slot)

		self.pending = nil
		Log("bags settled %.1f ms after the delete; bag %d slot %d %s", (GetTimePreciseSec() - pending.at) * 1000,
			entry.bag, entry.slot, info and ("holds " .. info.hyperlink) or "is empty")

		if self.lootMode == "after" then
			local slot = FirstLootItem()

			if slot then
				Log("LootSlot(%d) after the bag update", slot)
				LootSlot(slot)
			end
		end
	end

	self:Refresh()
end

---@param event string
---@param ... any
function Probe:OnTraced(event, ...)
	if event == "UI_ERROR_MESSAGE" then
		local messageType, message = ...

		Log("%s %s %s%s", event, tostring(messageType), tostring(message), message == ERR_INV_FULL and "  (ERR_INV_FULL)"
			or "")

		return
	end

	local values = {}

	for index = 1, select("#", ...) do
		values[index] = tostring((select(index, ...)))
	end

	Log("%s %s", event, table.concat(values, " "))
end

---@param on boolean
function Probe:Trace(on)
	self.tracing = on
	self.traceStart = GetTimePreciseSec()

	for _, event in ipairs(TRACED_EVENTS) do
		if on then
			AUI.Events:Register(event, self, self.OnTraced)
		else
			AUI.Events:Unregister(event, self)
		end
	end

	if not on then
		self.watching = false
		AUI.Events:UnregisterAll(self)
		self:Watch()
	end

	AUI:Print("dci: trace %s, auto loot %s, loot under mouse %s", on and "on" or "off",
		tostring(GetCVarBool("autoLootDefault")), tostring(GetCVarBool("lootUnderMouse")))
end

---Marks rows scrolled out of view with the ScrollBox's edge fade, whose strength follows the scroll position, or
---with its shadows, which show and hide at each end.
---@param frame AeonUIDeleteCheapestItemProbeMixin
function Probe:ApplyEdge(frame)
	local scrollBox = frame.ScrollBox

	if self.edgeMode == "fade" then
		scrollBox:SetEdgeFadeLength(EDGE_FADE_LENGTH)
		scrollBox:SetShadowsShown(false, false)
	else
		scrollBox:ClearEdgeFade()
	end

	if frame:IsShown() then
		scrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
	end
end

---@class AeonUIDeleteCheapestItemProbeRowMixin : Frame
---@field Item table
---@field Delete table
---@field Text FontString
---@field Price FontString
---@field HighlightNameFrame Texture
---@field SlideOutRightAnim AnimationGroup
---@field entry AUIDeleteCheapestItemProbeEntry
AeonUIDeleteCheapestItemProbeRowMixin = {}

local Row = AeonUIDeleteCheapestItemProbeRowMixin

---@param entry AUIDeleteCheapestItemProbeEntry
function Row:Init(entry)
	local color = ITEM_QUALITY_COLORS[entry.quality] or HIGHLIGHT_FONT_COLOR

	self.entry = entry
	self.SlideOutRightAnim:Stop()
	self:SetAlpha(1)
	SetItemButtonTexture(self.Item, entry.icon)
	SetItemButtonCount(self.Item, entry.count)
	SetItemButtonQuality(self.Item, entry.quality, entry.link)
	self.Text:SetText(entry.name)
	self.Text:SetTextColor(color.r, color.g, color.b)
	self.Price:SetText(GetMoneyString(entry.value, true))
	self.Delete:SetText(DELETE)
	self.Delete:SetScript("OnClick", function()
		Probe:Delete(self.entry, self)
	end)
end

function Row:OnEnter()
	self.HighlightNameFrame:Show()
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetBagItem(self.entry.bag, self.entry.slot)
	GameTooltip:Show()
end

function Row:OnLeave()
	self.HighlightNameFrame:Hide()
	GameTooltip:Hide()
end

---@class AeonUIDeleteCheapestItemProbeMixin : Frame
---@field ScrollBox table
---@field ScrollBar table
---@field Open fun(self: AeonUIDeleteCheapestItemProbeMixin) shows the panel, sizes it and plays its show animation
---@field Close fun(self: AeonUIDeleteCheapestItemProbeMixin) plays the hide animation
---@field Resize fun(self: AeonUIDeleteCheapestItemProbeMixin) sizes the panel to its rows
---@field SetTitle fun(self: AeonUIDeleteCheapestItemProbeMixin, title: string)
AeonUIDeleteCheapestItemProbeMixin = CreateFromMixins(ScrollingFlatPanelMixin)

local Window = AeonUIDeleteCheapestItemProbeMixin

function Window:OnLoad()
	ScrollingFlatPanelMixin.OnLoad(self)

	self:RegisterForDrag("LeftButton")

	local view = CreateScrollBoxListLinearView(ROW_PAD, ROW_PAD, ROW_PAD, ROW_PAD, ROW_SPACING)

	view:SetElementInitializer("AeonUIDeleteCheapestItemProbeRowTemplate", function(row, entry)
		row:Init(entry)
	end)

	ScrollUtil.InitScrollBoxWithScrollBar(self.ScrollBox, self.ScrollBar, view)

	-- The scroll-edge shadows sit above every row and its buttons, scaled and inset as LootFrame's are.
	local scrollBox = self.ScrollBox

	scrollBox:SetShadowsFrameLevel(scrollBox.ScrollTarget:GetFrameLevel() + 15)
	scrollBox:SetShadowsScale(0.2)
	scrollBox:GetUpperShadowTexture():SetTexCoord(0, 1, 1, 0)
	scrollBox:GetUpperShadowTexture():SetPoint("TOPLEFT", 30, 0)
	scrollBox:GetUpperShadowTexture():SetPoint("TOPRIGHT", -30, 0)
	scrollBox:GetLowerShadowTexture():SetPoint("BOTTOMLEFT", 30, 0)
	scrollBox:GetLowerShadowTexture():SetPoint("BOTTOMRIGHT", -30, 0)
	Probe:ApplyEdge(self)
	Probe.frame = self
end

---@return number height the rows' total height, never less than one row
function Window:CalculateElementsHeight()
	local height = ScrollUtil.CalculateScrollBoxElementExtent(self.ScrollBox:GetDataProviderSize(), ROW_HEIGHT,
		ROW_SPACING)

	return math.max(height, ROW_HEIGHT)
end

function Window:OnHideAnimFinished()
	if Probe.closeMode == "blizzard" then
		ScrollingFlatPanelMixin.OnHideAnimFinished(self)
	else
		self:Hide()
	end

	AUI:Print("dci: closed with %s, still shown %s, combat %s", Probe.closeMode, tostring(self:IsShown()),
		tostring(InCombatLockdown()))
end

function Window:OnDragStart()
	if Probe.dragMode == "dontsave" then
		self:SetDontSavePosition(true)
	end

	self:StartMoving()
end

function Window:OnDragStop()
	self:StopMovingOrSizing()

	local placed = self:IsUserPlaced()

	if Probe.dragMode == "clear" then
		self:SetUserPlaced(false)
	end

	AUI:Print("dci: drag ended (%s), user placed %s then %s, don't save %s", Probe.dragMode, tostring(placed),
		tostring(self:IsUserPlaced()), tostring(self:GetDontSavePosition()))
end

---Opens the feature's window as S5's openers will: beside the merchant, or beside the loot window making room for its
---first item, which a delete then loots.
---@param kind "merchant"|"loot"
function Probe:OpenWindow(kind)
	if kind == "merchant" then
		if not MerchantFrame:IsShown() then
			AUI:Print("dci: open a merchant first")

			return
		end

		AUI.DeleteCheapestItemWindow:Open({ kind = "MERCHANT", opener = MerchantFrame })

		return
	end

	local slot = FirstLootItem()

	if not slot then
		AUI:Print("dci: open a loot window holding an item first")

		return
	end

	local _, name, quantity, _, quality = GetLootSlotInfo(slot)
	local sellPrice = select(11, C_Item.GetItemInfo(GetLootSlotLink(slot) or ""))

	AUI.DeleteCheapestItemWindow:Open({
		kind = "LOOT",
		opener = LootFrame,
		incoming = { name = name, quality = quality or 1, value = (sellPrice or 0) * (quantity or 1) },
		lootSlot = slot,
	})
end

local HELP = "dci probe: open, close, trace <on|off>, quality <0-4>, loot <after|immediate|off>, "
	.. "side <auto|right|left>, gap <n>, closemode <override|blizzard>, drag <clear|dontsave|none>, "
	.. "edge <fade|shadow>, report, atlases, feature <on|off>, window <merchant|loot>; "
	.. "/reload undoes it"

local OPTIONS = {
	loot = { field = "lootMode", values = { after = true, immediate = true, off = true } },
	side = { field = "side", values = { auto = true, right = true, left = true } },
	closemode = { field = "closeMode", values = { override = true, blizzard = true } },
	drag = { field = "dragMode", values = { clear = true, dontsave = true, none = true } },
	edge = { field = "edgeMode", values = { fade = true, shadow = true } },
}

---@param line string
function Probe:Command(line)
	local command, value = line:match("^(%S*)%s*(%S*)")

	command, value = command or "", value or ""

	local frame = self.frame

	if not frame then
		return
	end

	local option = OPTIONS[command]

	if command == "" or command == "open" then
		self:Open()
	elseif command == "close" then
		frame:Close()
	elseif command == "trace" and (value == "on" or value == "off") then
		self:Trace(value == "on")
	elseif command == "quality" and tonumber(value) then
		self.maxQuality = math.max(0, math.min(4, tonumber(value) --[[@as number]]))
		AUI:Print("dci: listing quality %d and below", self.maxQuality)
		self:Refresh()
	elseif command == "gap" and tonumber(value) then
		self.gap = tonumber(value) --[[@as number]]
		self:Place()
		self:ReportPlacement()
	elseif option and option.values[value] then
		self[option.field] = value
		AUI:Print("dci: %s %s", command, value)

		if command == "side" and frame:IsShown() then
			self:Place()
			self:ReportPlacement()
		elseif command == "edge" then
			self:ApplyEdge(frame)
		end
	elseif command == "report" then
		local version, build = GetBuildInfo()

		AUI:Print("dci: client %s.%s, shown %s", tostring(version), tostring(build), tostring(frame:IsShown()))
		self:ReportPlacement()
	elseif command == "atlases" then
		AUI.Dev:Atlases("looting_itemcard_bg looting_itemcard_stroke_normal looting_itemcard_stroke_clickstate "
			.. "_looting_itemcard_shadow-center looting_raritytag_frame common-icon-delete")
	elseif command == "window" and (value == "merchant" or value == "loot") then
		self:OpenWindow(value)
	elseif command == "feature" and (value == "on" or value == "off") then
		local ok, problem = AUI.Profile:Set(AUI.DeleteCheapestItemOptions.ENABLED_PATH, value == "on")

		AUI:Print("dci: the feature %s", ok and value or tostring(problem))
	else
		AUI:Print(HELP)
	end
end
