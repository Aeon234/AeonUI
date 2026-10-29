local AUI = select(2, ...)

local L = AUI.L
local Options = AUI.MarkerOptions
local lib = LibStub("LibAeonSettings-1.0")

local FLAT = [[Interface\Buttons\WHITE8X8]]
local BUTTON_FILL = { 0, 0, 0, 0.5 }
local EDGE = { 0, 0, 0, 1 }
local EDGE_HOVER = { 0.7, 0.7, 0, 1 }
local BACKGROUND = { r = 0, g = 0, b = 0, a = 0.5 }
local DEFAULT_POSITION = { point = "TOP", x = 0, y = -20 }

local ICONS = {
	clear = [[Interface\Buttons\UI-GroupLoot-Pass-Up]],
	readyCheck = [[Interface\RaidFrame\ReadyCheck-Ready]],
	countdown = "Interface\\AddOns\\" .. AUI.name .. "\\Media\\Textures\\Countdown",
}
-- The Countdown icon's middle, cropped from its file.
local COUNTDOWN_CROP = { 0.25, 0.8, 0.2, 0.75 }

---@class AUIMarkerButton : Button
---@field kind string "marker", "clear", "readyCheck" or "countdown"
---@field index number? a marker button's raid target index
---@field fill Texture
---@field edges Texture[] a one-unit edge just outside the button
---@field icon Texture
---@field size number the button's size, which the icon's scale is of
---@field scale table the spring sizing the icon
---@field hovered boolean?
---@field pressed boolean?
---@field hooked boolean? its clicks and feedback are set
---@field attributeKeys string[]? the secure attributes it was given last

---@class AUIMarkerSample : Frame
---@field buttons AUIMarkerButton[]
---@field border AUIBorder

---The Raid Markers Bar: secure buttons for raid targets and world markers, Clear, Ready Check and Countdown. Its
---layout, attributes, place and visibility driver change only out of combat, the latest request winning. The marker
---and Clear buttons dim while the player may not mark, a marker's icon dims while its world marker is down, and the bar
---fades in on mouseover when asked; all of these are opacity, which combat allows. As Button Feedback asks, a hovered
---button's edge lights, and icons grow under the cursor and shrink while pressed on the settings library's springs.
---@class AUIMarkerBar
---@field active boolean started this session
---@field bar AUIMarkerSample? the named bar, created the first time it is turned on
---@field fade table? the spring fading the bar on mouseover
---@field pending boolean an apply waits for combat to end
---@field sampling boolean edit mode shows the bar
---@field DEFAULT_POSITION { point: string, x: number, y: number }
local Bar = {
	active = false,
	pending = false,
	sampling = false,
	DEFAULT_POSITION = DEFAULT_POSITION,
}
AUI.MarkerBar = Bar

---@return boolean able the player may set raid targets: anywhere but a raid without lead or assist
local function CanMark()
	if not IsInRaid() then
		return true
	end

	return AUI:Readable(UnitIsGroupLeader("player"), false) == true
		or AUI:Readable(UnitIsGroupAssistant("player"), false) == true
		or AUI:Readable(IsEveryoneAssistant(), false) == true
end

---@param parent Frame
---@param name string?
---@return AUIMarkerSample
function Bar:Build(parent, name)
	local bar = CreateFrame("Frame", name, parent) --[[@as AUIMarkerSample]]

	bar.buttons = {}
	bar.border = AUI.Border:Create(bar)

	return bar
end

---@param button AUIMarkerButton
local function PaintEdges(button)
	local color = button.hovered and Options:Get("markers.feedback.highlight") and EDGE_HOVER or EDGE

	for _, edge in ipairs(button.edges) do
		edge:SetVertexColor(color[1], color[2], color[3], color[4])
	end
end

---@param button AUIMarkerButton
local function Resize(button)
	button.scale:To(Options:IconScale(button.hovered == true, button.pressed == true,
		Options:Get("markers.feedback.grow") == true, Options:Get("markers.feedback.press") == true))
end

---@param bar AUIMarkerSample
---@param slot number
---@param secure boolean the bar's own buttons, as opposed to the settings preview's
---@return AUIMarkerButton
function Bar:Button(bar, slot, secure)
	local button = bar.buttons[slot]

	if button then
		return button
	end

	button = CreateFrame(secure and "Button" or "Frame", nil, bar, secure and "SecureActionButtonTemplate" or nil)
		--[[@as AUIMarkerButton]]
	button.fill = button:CreateTexture(nil, "BACKGROUND")
	button.fill:SetTexture(FLAT)
	button.fill:SetVertexColor(BUTTON_FILL[1], BUTTON_FILL[2], BUTTON_FILL[3], BUTTON_FILL[4])
	button.fill:SetAllPoints()

	local top, bottom = button:CreateTexture(nil, "BORDER"), button:CreateTexture(nil, "BORDER")
	local left, right = button:CreateTexture(nil, "BORDER"), button:CreateTexture(nil, "BORDER")

	top:SetPoint("BOTTOMLEFT", button, "TOPLEFT", -1, 0)
	top:SetPoint("BOTTOMRIGHT", button, "TOPRIGHT", 1, 0)
	top:SetHeight(1)
	bottom:SetPoint("TOPLEFT", button, "BOTTOMLEFT", -1, 0)
	bottom:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 1, 0)
	bottom:SetHeight(1)
	left:SetPoint("TOPRIGHT", button, "TOPLEFT")
	left:SetPoint("BOTTOMRIGHT", button, "BOTTOMLEFT")
	left:SetWidth(1)
	right:SetPoint("TOPLEFT", button, "TOPRIGHT")
	right:SetPoint("BOTTOMLEFT", button, "BOTTOMRIGHT")
	right:SetWidth(1)
	button.edges = { top, bottom, left, right }

	for _, edge in ipairs(button.edges) do
		edge:SetTexture(FLAT)
	end

	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetPoint("CENTER")
	-- Snapped edges round to whole pixels, turning a few pixels of resizing into visible steps.
	button.icon:SetSnapToPixelGrid(false)
	button.icon:SetTexelSnappingBias(0)
	button.size = 1
	button.scale = lib:CreateSpring(1, function(scale)
		button.icon:SetSize(button.size * scale, button.size * scale)
	end, { response = Options.ICON_RESPONSE, epsilon = 0.002 })
	PaintEdges(button)
	bar.buttons[slot] = button

	return button
end

---Sizes a bar, places its buttons for the shown kinds and draws its border. Out of combat only for the secure bar.
---@param bar AUIMarkerSample
---@param kinds string[]
---@param secure boolean
function Bar:Arrange(bar, kinds, secure)
	local size, spacing = Options:Get("markers.size"), Options:Get("markers.spacing")
	local vertical = Options:Get("markers.orientation") == "VERTICAL"
	local index = 0

	bar:SetSize(Options:BarSize(#kinds, size, spacing, vertical))

	for slot, kind in ipairs(kinds) do
		local button = self:Button(bar, slot, secure)
		local offset = Options:Offset(slot, size, spacing)

		if kind == "marker" then
			index = index + 1
			button.icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. index)
		else
			button.icon:SetTexture(ICONS[kind])
		end

		if kind == "countdown" then
			button.icon:SetTexCoord(COUNTDOWN_CROP[1], COUNTDOWN_CROP[2], COUNTDOWN_CROP[3], COUNTDOWN_CROP[4])
		else
			button.icon:SetTexCoord(0, 1, 0, 1)
		end

		button.kind, button.index, button.size = kind, kind == "marker" and index or nil, size
		button:SetSize(size, size)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", bar, "TOPLEFT", vertical and Options.PAD or offset, -(vertical and offset or Options.PAD))
		button.scale:Jump(button.scale.target)
		button:Show()
	end

	for slot = #kinds + 1, #bar.buttons do
		bar.buttons[slot]:Hide()
	end

	local style = Options:Get("markers.border.style")

	bar.border:Apply({
		style = style,
		color = style == "FOREVER" and AUI.Border.ART_COLOR or Options:Get("markers.border.color"),
		thickness = Options:Get("markers.border.thickness"),
		background = BACKGROUND,
	})
end

---@param button AUIMarkerButton
function Bar:ShowTooltip(button)
	if not Options:Get("markers.tooltips") then
		return
	end

	local title

	if button.kind == "marker" then
		title = _G["RAID_TARGET_" .. tostring(button.index)]
	elseif button.kind == "clear" then
		title = CLEAR_ALL
	elseif button.kind == "readyCheck" then
		title = READY_CHECK
	else
		title = PLAYER_COUNTDOWN_BUTTON
	end

	GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
	GameTooltip:SetText(title or "", 1, 1, 1)

	for _, line in ipairs(Options:ClickLines(button.kind, AUI.can.worldMarkers == true, Options:Get("markers.seconds"))) do
		GameTooltip:AddDoubleLine(line.click, line.action, 1, 0.82, 0, 1, 1, 1)
	end

	GameTooltip:Show()
end

---Sets the bar's own button behavior once: hover and press feedback, the tooltip, the role check, and the placed
---world markers read again after a click.
---@param button AUIMarkerButton
function Bar:Hook(button)
	button.hooked = true
	button:RegisterForClicks("AnyUp")
	button:SetAttribute("useOnKeyDown", false)
	button:HookScript("OnEnter", function()
		button.hovered = true
		PaintEdges(button)
		Resize(button)
		self:ShowTooltip(button)
		self:Fade()
	end)
	button:HookScript("OnLeave", function()
		button.hovered, button.pressed = false, false
		PaintEdges(button)
		Resize(button)
		GameTooltip:Hide()
		self:Fade()
	end)
	button:HookScript("OnMouseDown", function()
		button.pressed = true
		Resize(button)
	end)
	button:HookScript("OnMouseUp", function()
		button.pressed = false
		Resize(button)
	end)
	button:SetScript("PostClick", function(_, mouseButton)
		if button.kind == "readyCheck" and mouseButton == "RightButton" and not IsShiftKeyDown() then
			InitiateRolePoll()
		elseif button.kind == "marker" or button.kind == "clear" then
			self:ShowPlaced()
		end
	end)
end

---@return AUIMarkerSample bar the named bar, created on first call
function Bar:Frame()
	if self.bar then
		return self.bar
	end

	local bar = self:Build(UIParent, "AeonUIRaidMarkers")

	bar:SetFrameStrata("MEDIUM")
	bar:SetClampedToScreen(true)
	bar:Hide()
	bar:SetScript("OnEnter", function()
		self:Fade()
	end)
	bar:SetScript("OnLeave", function()
		self:Fade()
	end)
	self.bar = bar
	self.fade = lib:CreateSpring(1, function(alpha)
		bar:SetAlpha(math.min(math.max(alpha, 0), 1))
	end, { response = Options.FADE_RESPONSE, epsilon = 0.005 })

	return bar
end

---@param position { point: string, x: number, y: number }? the place to use; the saved one when nil
function Bar:Place(position)
	local bar = self.bar

	if not bar then
		return
	end

	if InCombatLockdown() then
		self:Defer()

		return
	end

	position = position or Options:Get("markers.position") or DEFAULT_POSITION
	bar:ClearAllPoints()
	bar:SetPoint(position.point, UIParent, position.point, position.x, position.y)
end

---Waits for combat to end, then applies everything with the settings of that moment.
function Bar:Defer()
	if not self.pending then
		self.pending = true
		AUI.Events:Register("PLAYER_REGEN_ENABLED", self, self.OnCombatEnded)
	end
end

function Bar:OnCombatEnded()
	AUI.Events:Unregister("PLAYER_REGEN_ENABLED", self)
	self.pending = false
	self:Apply()
end

---Replaces a button's secure attributes.
---@param button AUIMarkerButton
---@param attributes table<string, any>
local function SetAttributes(button, attributes)
	for _, key in ipairs(button.attributeKeys or {}) do
		button:SetAttribute(key, nil)
	end

	button.attributeKeys = {}

	for key, value in pairs(attributes) do
		button:SetAttribute(key, value)
		button.attributeKeys[#button.attributeKeys + 1] = key
	end
end

---Brings the bar in line with the settings: built, arranged, given its actions, placed and given its visibility
---driver while on; hidden, without actions or driver while off. In combat it waits for combat to end.
function Bar:Apply()
	if InCombatLockdown() then
		self:Defer()

		return
	end

	if not Options:Get("markers.enabled") then
		self:Stop()

		return
	end

	local bar = self:Frame()
	local kinds = Options:Kinds(Options:Get("markers.readyCheck"), Options:Get("markers.countdown"))
	local start, cancel = Options:Countdown(Options:Get("markers.seconds"), C_AddOns.IsAddOnLoaded("BigWigs") == true,
		C_AddOns.IsAddOnLoaded("DBM-Core") == true)
	local countdown = { start = start, cancel = cancel }

	self:Arrange(bar, kinds, true)

	for slot = 1, #kinds do
		local button = bar.buttons[slot]

		if not button.hooked then
			self:Hook(button)
		end

		SetAttributes(button, Options:Attributes(button.kind, button.index, AUI.can.worldMarkers == true, countdown))
	end

	for slot = #kinds + 1, #bar.buttons do
		SetAttributes(bar.buttons[slot], {})
	end

	bar:EnableMouse(Options:Get("markers.mouseover") == true)
	self:Place()
	self:Follow()
	self:ApplyVisibility()
	self:Dim()
	self:ShowPlaced()
	self:Fade()
end

---Sets the visibility driver, or shows the bar outright for edit mode, while the bar is on. Out of combat only.
function Bar:ApplyVisibility()
	local bar = self.bar

	if not bar or not Options:Get("markers.enabled") then
		return
	end

	if self.sampling then
		UnregisterStateDriver(bar, "visibility")
		bar:Show()

		return
	end

	RegisterStateDriver(bar, "visibility", Options:Visibility(Options:Get("markers.visibility")))
end

---Dims the marker and Clear buttons while the player may not set raid targets.
function Bar:Dim()
	local bar = self.bar

	if not bar then
		return
	end

	local mark = CanMark()

	for _, button in ipairs(bar.buttons) do
		local able = mark or button.kind == "readyCheck" or button.kind == "countdown"

		button:SetAlpha(able and 1 or Options.DIMMED)
	end
end

---Dims each marker's icon while its world marker is down. The answer may be secret in an instance, so it goes
---straight to the icon's opacity without being tested.
function Bar:ShowPlaced()
	local bar = self.bar

	if not bar or not AUI.can.worldMarkers then
		return
	end

	for _, button in ipairs(bar.buttons) do
		if button.kind == "marker" and button.index then
			button.icon:SetAlphaFromBoolean(IsRaidMarkerActive(Options.TARGET_TO_WORLD[button.index]), Options.PLACED, 1)
		else
			button.icon:SetAlpha(1)
		end
	end
end

---Shows the bar while the cursor is over it, when Show On Mouseover is on.
function Bar:Fade()
	local bar, fade = self.bar, self.fade

	if not bar or not fade then
		return
	end

	local hidden = Options:Get("markers.mouseover") and not self.sampling and not bar:IsMouseOver()

	fade:To(hidden and 0 or 1)
end

function Bar:Follow()
	for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "PLAYER_ENTERING_WORLD" }) do
		AUI.Events:Register(event, self, self.OnGroupChanged)
	end

	if AUI.can.worldMarkers then
		AUI.Events:Register("RAID_TARGET_UPDATE", self, self.ShowPlaced)
	end
end

function Bar:OnGroupChanged()
	AUI.Events:Coalesce("markerBarGroup", function()
		Bar:Dim()
		Bar:ShowPlaced()
	end)
end

---Out of combat: the bar hides, its buttons lose their actions and its events are dropped.
function Bar:Stop()
	local bar = self.bar

	AUI.Events:Cancel("markerBarGroup")

	for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "PLAYER_ENTERING_WORLD",
		"RAID_TARGET_UPDATE" }) do
		AUI.Events:Unregister(event, self)
	end

	if not bar then
		return
	end

	UnregisterStateDriver(bar, "visibility")
	bar:Hide()

	for _, button in ipairs(bar.buttons) do
		SetAttributes(button, {})
	end
end

---Shows the bar whatever its visibility while edit mode is open, which never runs in combat.
---@param shown boolean
function Bar:Sample(shown)
	self.sampling = shown

	if not InCombatLockdown() then
		self:ApplyVisibility()
	end

	self:Fade()
end
