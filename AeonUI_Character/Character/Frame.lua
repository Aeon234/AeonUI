local AUI = select(2, ...)

local Options, Layout = AUI.CharacterOptions, AUI.CharacterLayout

-- Blizzard's slot buttons by slot ID, the ammo slot at `Options.AMMO_SLOT`.
local SLOT_BUTTONS = {
	[1] = "CharacterHeadSlot",
	[2] = "CharacterNeckSlot",
	[3] = "CharacterShoulderSlot",
	[4] = "CharacterShirtSlot",
	[5] = "CharacterChestSlot",
	[6] = "CharacterWaistSlot",
	[7] = "CharacterLegsSlot",
	[8] = "CharacterFeetSlot",
	[9] = "CharacterWristSlot",
	[10] = "CharacterHandsSlot",
	[11] = "CharacterFinger0Slot",
	[12] = "CharacterFinger1Slot",
	[13] = "CharacterTrinket0Slot",
	[14] = "CharacterTrinket1Slot",
	[15] = "CharacterBackSlot",
	[16] = "CharacterMainHandSlot",
	[17] = "CharacterSecondaryHandSlot",
	[18] = "CharacterRangedSlot",
	[19] = "CharacterTabardSlot",
	[0] = "CharacterAmmoSlot",
}
local SLOT_SIZE = 40
-- The race backdrop's textures on Blizzard's model scene, anchored to the scene.
local BACKDROP = { "BackgroundTopLeft", "BackgroundTopRight", "BackgroundBotLeft", "BackgroundBotRight" }
local NAME_TOP = -2 -- the name, down from the top strip's top
local LEVEL_Y = -11 -- Blizzard's level line, moved below the name

---Widens Blizzard's character panel on its Character tab and places Blizzard's own slot buttons in two columns with
---room for text, the weapons below. Everything changed is recorded on first touch and put back on other tabs, when the
---feature turns off and under the Gamepad style. None of these frames is protected, so nothing waits for combat.
---@class AUICharacterFrame
---@field hooked boolean
---@field extended boolean
---@field nameText FontString? the character's name, top center of the left pane
---@field backdrop Frame? where Blizzard's model scene sits, holding its race backdrop while the scene is narrowed
---@field saved table recorded points and sizes of Blizzard's frames, by frame
local Window = {
	hooked = false,
	extended = false,
	saved = {},
}
AUI.CharacterFrame = Window

---@return boolean
function Window:IsExtended()
	return self.extended
end

---@return boolean
local function Wanted()
	return AUI.Character:IsOn() and CharacterFrame.activeSubframe == "PaperDollFrame"
end

---Records a frame's points and size the first time the feature moves it.
---@param frame table
local function Save(frame)
	if Window.saved[frame] then
		return
	end

	local points = {}

	for index = 1, frame:GetNumPoints() do
		points[index] = { frame:GetPoint(index) }
	end
	Window.saved[frame] = { points = points, width = frame:GetWidth(), height = frame:GetHeight() }
end

---@param frame table
local function Restore(frame)
	local saved = Window.saved[frame]

	if not saved then
		return
	end

	frame:ClearAllPoints()
	for _, point in ipairs(saved.points) do
		frame:SetPoint(unpack(point))
	end
	frame:SetSize(saved.width, saved.height)
	Window.saved[frame] = nil
end

---Narrows Blizzard's model scene, and with it the model and its drag area, to the center column, and keeps its race
---backdrop over the area the scene covers natively.
---@param pane Frame
---@param place AUICharacterModelPlace
function Window:PlaceModel(pane, place)
	local scene = CharacterModelScene

	Save(scene)
	if not self.backdrop then
		self.backdrop = CreateFrame("Frame", nil, scene:GetParent())
		for _, point in ipairs(self.saved[scene].points) do
			self.backdrop:SetPoint(unpack(point))
		end
	end

	scene:ClearAllPoints()
	scene:SetPoint("TOPLEFT", pane, "TOPLEFT", place.x, -place.y)
	scene:SetSize(place.width, place.height)

	for _, key in ipairs(BACKDROP) do
		local texture = scene[key]

		Save(texture)
		texture:ClearAllPoints()
		for _, point in ipairs(self.saved[texture].points) do
			local anchor, relative, relativePoint, x, y = unpack(point)

			texture:SetPoint(anchor, relative == scene and self.backdrop or relative, relativePoint, x, y)
		end
	end
	scene.BackgroundOverlay:SetAllPoints(self.backdrop)
end

function Window:Extend()
	local Profile = AUI.Profile
	local model = Profile:Get(Options.SHOW_MODEL_PATH) == true
	local layout = Layout:Compute({ model = model, gauges = Profile:Get(Options.GAUGES_PATH) == true })
	local pane = CharacterFrame.LeftPaneHost

	CharacterFrame:SetSize(CharacterFrame:IsRightPaneCollapsed() and layout.leftWidth or layout.width, layout.height)
	Save(pane)
	pane:SetWidth(layout.leftWidth)

	for slot, place in pairs(layout.slots) do
		local button = _G[SLOT_BUTTONS[slot]]
		local corner = place.side == "LEFT" and "TOPLEFT" or "TOPRIGHT"

		Save(button)
		button:ClearAllPoints()
		button:SetPoint(corner, pane, corner, place.side == "LEFT" and place.x or -place.x, -place.y)
		button:SetSize(SLOT_SIZE, SLOT_SIZE)
	end

	if layout.model then
		self:PlaceModel(pane, layout.model)
	end
	CharacterModelScene:SetShown(model)

	if not self.nameText then
		self.nameText = PaperDollFrame.TopBackgroundStripHost:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
		self.nameText:SetPoint("TOP", PaperDollFrame.TopBackgroundStripHost, "TOP", 0, NAME_TOP)
	end
	self.nameText:SetText(AUI:Readable(UnitPVPName("player"), ""))
	self.nameText:Show()
	Save(PaperDollLevelInfo)
	PaperDollLevelInfo:ClearAllPoints()
	PaperDollLevelInfo:SetPoint("CENTER", PaperDollFrame.TopBackgroundStripHost, "CENTER", 0, LEVEL_Y)

	self.extended = true
end

---Puts back everything `Extend` changed. When `native` is set, also Blizzard's own frame size, for a change the
---feature makes outside Blizzard's own resize.
---@param native boolean?
function Window:Restore(native)
	if not self.extended then
		return
	end

	self.extended = false
	Restore(CharacterFrame.LeftPaneHost)
	for _, name in pairs(SLOT_BUTTONS) do
		Restore(_G[name])
	end
	Restore(PaperDollLevelInfo)
	Restore(CharacterModelScene)
	for _, key in ipairs(BACKDROP) do
		Restore(CharacterModelScene[key])
	end
	CharacterModelScene.BackgroundOverlay:SetAllPoints()
	CharacterModelScene:Show()
	if self.nameText then
		self.nameText:Hide()
	end

	if native then
		CharacterFrame:SetSize(CharacterFrame:IsRightPaneCollapsed() and CHARACTER_FRAME_COLLAPSED_WIDTH
			or CHARACTER_FRAME_WIDTH, CHARACTER_FRAME_HEIGHT)
		CharacterFrame:UpdateTitle()
	end
end

function Window:OnUpdateSize()
	if Wanted() then
		self:Extend()
	else
		self:Restore()
	end
end

function Window:OnUpdateTitle()
	if self.extended then
		CharacterFrame:SetTitleColor(NORMAL_FONT_COLOR)
		CharacterFrame:SetTitle(CHARACTER)
	end
end

function Window:Hook()
	if self.hooked then
		return
	end

	self.hooked = true
	hooksecurefunc(CharacterFrame, "UpdateSize", function()
		Window:OnUpdateSize()
	end)
	hooksecurefunc(CharacterFrame, "UpdateTitle", function()
		Window:OnUpdateTitle()
	end)
end

---Follows a settings change: an open panel is redrawn at once, a closed one at its next resize.
function Window:Apply()
	if AUI.Character:IsOn() then
		self:Hook()
	end

	if not CharacterFrame:IsShown() then
		self:Restore(true)

		return
	end

	if Wanted() then
		self:Extend()
		self:OnUpdateTitle()
	else
		self:Restore(true)
	end
end
