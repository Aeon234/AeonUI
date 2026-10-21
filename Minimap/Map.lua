local AUI = select(2, ...)

local Schema = AUI.Schema

-- The map stays square and its mask crops it: Blizzard's white square for a square map, otherwise a band mask built by
-- Tools/minimap-masks.py whose opaque middle <rows> of 256 rows (or columns) are the visible part.
local SQUARE_MASK = "Interface\\BUTTONS\\WHITE8X8"
local MASKS = "Interface\\AddOns\\" .. AUI.name .. "\\Media\\Textures\\Masks\\"
local MASK_SIZE = 256
local MASK_STEP = 4
-- The longest the long side may be against the short one. The whole square must stay on the screen (the engine draws
-- the map inside the screen only, so a square past an edge slides off the frame), so the frame keeps the hidden part of
-- the square away from the screen's edges; at 3:2 that margin is at most a sixth of the long side.
local MAX_RATIO = 1.5
local MASK_MIN_ROWS = 172
local HYBRID_ADDON = "Blizzard_HybridMinimap"
-- How far the Forever styles' art reaches outside the map, in texels. The band (texels 6 to 9 on the straight edges)
-- is drawn above the map and crosses each corner's diagonal from x + y = 22 to 30, so with the map's edge 10.5 texels
-- in, the map runs flush under the band and its square corners lie under the band's chamfer.
local ART_OUTSET = 10.5
-- The least room between a styled cell divider and the cells on either side of it, together.
local CELL_GAP = 4

Schema:Choices("minimapBorderStyle", AUI.Border.STYLES)
Schema:Boolean("minimap.enabled", true)
Schema:Number("minimap.width", 240, 140, 400, true)
Schema:Number("minimap.height", 180, 100, 400, true)
Schema:Number("minimap.scale", 100, 50, 200, true)
Schema:Choice("minimap.border.style", "minimapBorderStyle", "METAL")
Schema:Color("minimap.border.color", AUI.Border.ART_COLOR)
Schema:Number("minimap.border.thickness", 100, 50, 300, true)
Schema:Color("minimap.background", { r = 0.067, g = 0.067, b = 0.067, a = 0.9 })
Schema:Boolean("minimap.zoom.wheel", true)
Schema:Number("minimap.zoom.reset", 0, 0, 60, true)
Schema:Position("minimap.position")

---@class AUIMinimapGeometry
---@field side number the map's own width and height: it stays square, so the terrain stays under the player arrow
---@field width number the visible width, which the nearest mask may make slightly different from the setting
---@field height number the visible height
---@field mask string the mask file that crops the square to the visible area
---@field insetX number how far the square reaches past the visible area at the left and right
---@field insetY number how far it reaches past the visible area at the top and bottom

---The Minimap module: moves Blizzard's minimap into AeonUI's frame, crops it to a rectangle, adds the information rows
---above and below it and borders the whole, and parks Blizzard's minimap cluster, with everything left in it, on a
---hidden frame. Taken over at login when enabled; turning the module on or off takes effect after a reload, and while
---off nothing of Blizzard's is touched.
---@class AUIMinimap
---@field DEFAULT_POSITION table
---@field active boolean the module took the minimap over this session
---@field holder Frame? the named root frame, sized to the visible map and its rows
---@field content Frame? holds the map, sized to its visible area; Blizzard's map draws unit dots only inside its parent
---@field mask string the mask in use
---@field geometry AUIMinimapGeometry? the map's, as last applied
---@field arranged string? the assembly's size and the map's place in it, as last arranged
---@field border AUIBorder?
---@field hidden Frame? parks Blizzard's frames
---@field pending boolean an apply is waiting for combat to end
---@field resetTimer table? the automatic zoom reset's timer
local Map = {
	DEFAULT_POSITION = { point = "TOPRIGHT", x = -20, y = -20 },
	active = false,
	pending = false,
	mask = SQUARE_MASK,
}
AUI.Minimap = Map

---@param width number
---@return number min the shortest height the width allows
---@return number max the tallest
function Map:HeightRange(width)
	return width / MAX_RATIO, width * MAX_RATIO
end

---The square the map is drawn in and the mask that crops it to the setting's rectangle. The short side is kept within
---3:2 of the long one and snaps to the nearest mask, a step of 4/256 of the long side.
---@param width number
---@param height number
---@return AUIMinimapGeometry
function Map:Geometry(width, height)
	local side = math.max(width, height)
	local short = math.max(math.min(width, height), side / MAX_RATIO)
	local rows = math.floor(short / side * MASK_SIZE / MASK_STEP + 0.5) * MASK_STEP

	rows = math.max(MASK_MIN_ROWS, rows)

	if rows >= MASK_SIZE then
		return { side = side, width = side, height = side, mask = SQUARE_MASK, insetX = 0, insetY = 0 }
	end

	short = side * rows / MASK_SIZE

	local wide = width >= height
	local visibleWidth = wide and side or short
	local visibleHeight = wide and short or side

	return {
		side = side,
		width = visibleWidth,
		height = visibleHeight,
		mask = MASKS .. (wide and "Wide-" or "Tall-") .. rows,
		insetX = (side - visibleWidth) / 2,
		insetY = (side - visibleHeight) / 2,
	}
end

---@return boolean
function Map:IsEnabled()
	return AUI.Profile:Get("minimap.enabled") == true
end

function Map:Build()
	local holder = CreateFrame("Frame", "AeonUIMinimap", UIParent)

	holder:SetFrameStrata("LOW")
	holder:SetClampedToScreen(true)
	holder:SetPoint(self.DEFAULT_POSITION.point, self.DEFAULT_POSITION.x, self.DEFAULT_POSITION.y)

	local content = CreateFrame("Frame", nil, holder)

	content:SetPoint("TOPLEFT")

	local hidden = CreateFrame("Frame")

	hidden:Hide()

	self.holder = holder
	self.content = content
	self.border = AUI.Border:Create(holder, ART_OUTSET, true)
	self.hidden = hidden

	AUI.MinimapRows:Build(holder, function()
		Map:OnEnter()
	end, function()
		Map:OnLeave()
	end)
	AUI.MinimapElements:Build(holder)
end

function Map:OnEnter()
	AUI.MinimapFade:SetHovered(true)
end

---Leaving one part of the assembly for another keeps it hovered.
function Map:OnLeave()
	if not (self.holder --[[@as Frame]]):IsMouseOver() then
		AUI.MinimapFade:SetHovered(false)
	end
end

---@param _ table
---@param delta number
local function OnMouseWheel(_, delta)
	local zoom = Minimap:GetZoom() + (delta > 0 and 1 or -1)

	Minimap:SetZoom(math.max(0, math.min(Minimap:GetZoomLevels() - 1, zoom)))
end

---Keeps the map north up whatever `rotateMinimap` says; the player's setting itself is left alone.
function Map:IgnoreRotation()
	C_Minimap.SetIgnoreRotateMinimap(true)
end

---Gives the indoor map the outdoor map's mask in place of its round one.
function Map:MaskHybrid()
	local hybrid = HybridMinimap

	if hybrid and hybrid.CircleMask then
		hybrid.CircleMask:SetTexture(self.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	end
end

---Masks the indoor map like the outdoor one, and puts rotation back off when the indoor map hides: its OnHide clears
---the flag.
function Map:AdoptHybrid()
	local hybrid = HybridMinimap

	if not hybrid then
		return
	end

	self:MaskHybrid()
	hybrid:HookScript("OnHide", function()
		Map:IgnoreRotation()
	end)
end

function Map:TakeOver()
	Minimap:SetParent(self.content)
	Minimap:ClearAllPoints()
	Minimap:SetPoint("CENTER")
	Minimap:SetArchBlobRingScalar(0)
	Minimap:SetQuestBlobRingScalar(0)
	Minimap:SetTaskBlobRingScalar(0)

	MinimapCluster:SetParent(self.hidden)

	-- The round frame art lives on MinimapBackdrop, a child of the map itself, which also holds the landing page and
	-- event buttons; only its textures are made invisible. Blizzard re-shows and re-textures them but never sets alpha.
	for _, texture in ipairs({ MinimapCompassTexture or false, MinimapCompassTextureUnderlay or false,
		MinimapBackdrop and MinimapBackdrop.StaticOverlayTexture or false }) do
		if texture then
			texture:SetAlpha(0)
		end
	end

	for _, key in ipairs({ "ZoomIn", "ZoomOut", "ZoomHitArea" }) do
		if Minimap[key] then
			Minimap[key]:SetParent(self.hidden)
		end
	end

	Minimap:SetScript("OnMouseWheel", OnMouseWheel)
	Minimap:HookScript("OnEnter", function()
		Map:OnEnter()
	end)
	Minimap:HookScript("OnLeave", function()
		Map:OnLeave()
	end)
	AUI.MinimapFade:Start(self.holder --[[@as Frame]])

	GetMinimapShape = function()
		return "SQUARE"
	end

	-- Forever sets Blizzard's own mask again whenever rotation is switched.
	if AUI.can.minimapConfig then
		hooksecurefunc(MinimapCluster, "UpdateMinimapConfig", function()
			Minimap:SetMaskTexture(Map.mask)
		end)
	end

	if C_AddOns.IsAddOnLoaded(HYBRID_ADDON) then
		self:AdoptHybrid()
	else
		EventUtil.ContinueOnAddOnLoaded(HYBRID_ADDON, function()
			Map:AdoptHybrid()
		end)
	end

	self:IgnoreRotation()

	AUI.Events:Register("CVAR_UPDATE", self, self.OnCVarUpdate)
	AUI.Events:Register("MINIMAP_UPDATE_ZOOM", self, self.OnZoomChanged)
	AUI.Events:Register("PLAYER_REGEN_ENABLED", self, self.OnCombatEnded)
	AUI.Callbacks:Register("Profile", self, self.OnProfileChanged)
end

---@param _ string
---@param name string
function Map:OnCVarUpdate(_, name)
	if type(name) == "string" and name:lower() == "rotateminimap" then
		self:IgnoreRotation()
	end
end

---Starts, or restarts, the automatic return to the widest zoom after a zoom change.
function Map:OnZoomChanged()
	if self.resetTimer then
		self.resetTimer:Cancel()
		self.resetTimer = nil
	end

	local delay = AUI.Profile:Get("minimap.zoom.reset")

	if delay > 0 and Minimap:GetZoom() > 0 then
		self.resetTimer = C_Timer.NewTimer(delay, function()
			Map.resetTimer = nil
			Minimap:SetZoom(0)
		end)
	end
end

function Map:OnCombatEnded()
	if self.pending then
		self:Apply()
	end
end

---@param path string?
function Map:OnProfileChanged(path)
	if path == nil or path:sub(1, 8) == "minimap." then
		self:Apply()
	end
end

---Sizes the assembly for the map and the rows that have something to show, places the map, the rows and their cells,
---and borders the whole. A change of the assembly's size waits for combat to end; within the same size, cells are
---placed at once.
---@param force boolean? place and border everything even when the size is unchanged
function Map:Arrange(force)
	local geometry = self.geometry

	if not self.active or not geometry then
		return
	end

	local Profile = AUI.Profile
	local holder = self.holder --[[@as Frame]]
	local style, thickness = Profile:Get("minimap.border.style"), Profile:Get("minimap.border.thickness")
	local separator, divider = AUI.Border:Gaps(style, thickness, AUI:Pixel(holder))
	local cellDivider = AUI.Border:CellDividerWidth(style, thickness)
	local layout = AUI.MinimapLayout:Compute({
		width = geometry.width,
		mapHeight = geometry.height,
		rowHeight = Profile:Get("minimap.rows.height"),
		separator = separator,
		divider = divider,
		spacing = cellDivider and math.max(AUI.MinimapLayout.SPACING, cellDivider + CELL_GAP) or nil,
		rows = AUI.MinimapElements:Rows(),
	})
	local arranged = ("%s %s %s"):format(layout.width, layout.height, layout.mapTop)
	local color = style == "FOREVER" and AUI.Border.ART_COLOR or Profile:Get("minimap.border.color")

	if force or arranged ~= self.arranged then
		if InCombatLockdown() then
			self.pending = true

			return
		end

		self.arranged = arranged
		holder:SetSize(layout.width, layout.height)

		local content = self.content --[[@as Frame]]

		content:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -layout.mapTop)
		content:SetSize(geometry.width, geometry.height)
		-- The engine draws the map inside the screen only: a square reaching past an edge is drawn shifted off the
		-- holder. The holder's clamping reaches out over the part of the square past the assembly, so the whole square
		-- stays on the screen; the map itself is not clamped, so it never moves within the holder.
		holder:SetClampRectInsets(-geometry.insetX, geometry.insetX, math.max(0, geometry.insetY - layout.mapTop),
			-math.max(0, geometry.insetY - layout.mapBottom))

		if AUI.EditTargets then
			AUI.EditTargets:Apply()
		end

		-- After the holder is placed: the Forever art snaps its band to whole pixels where the holder now is.
		local border = self.border --[[@as AUIBorder]]

		border:Apply({
			style = style,
			color = Profile:Get("minimap.border.color"),
			background = Profile:Get("minimap.background"),
			thickness = thickness,
			top = layout.top,
			bottom = layout.bottom,
		})
		-- The rows' text sits above the border: the metal title bar behind it is opaque.
		border:SetFrameLevel(Minimap:GetFrameLevel() + 10)
		AUI.MinimapRows:SetFrameLevel(Minimap:GetFrameLevel() + 15)
	end

	AUI.MinimapRows:Place(holder, layout, { style = style, color = color, thickness = thickness })
end

---Sizes, scales, crops and borders the map and arranges its rows from the active profile. Out of combat only; in
---combat the latest request waits for combat to end.
function Map:Apply()
	if not self.active then
		return
	end

	if InCombatLockdown() then
		self.pending = true

		return
	end

	self.pending = false

	local Profile = AUI.Profile
	local width, height = Profile:Get("minimap.width"), Profile:Get("minimap.height")
	local geometry = self:Geometry(width, height)
	local holder = self.holder --[[@as Frame]]

	holder:SetScale(Profile:Get("minimap.scale") / 100)

	self.geometry = geometry
	self.mask = geometry.mask
	Minimap:SetSize(geometry.side, geometry.side)
	Minimap:SetMaskTexture(geometry.mask)
	self:MaskHybrid()
	Minimap:SetHitRectInsets(geometry.insetX, geometry.insetX, geometry.insetY, geometry.insetY)
	Minimap:SetClampedToScreen(false)
	Minimap:EnableMouseWheel(Profile:Get("minimap.zoom.wheel"))

	-- A zoom change makes the map draw again at its new size.
	local zoom = Minimap:GetZoom()

	Minimap:SetZoom(zoom > 0 and 0 or 1)
	Minimap:SetZoom(zoom)

	local icon = AUI.Broker.icon

	if icon then
		icon:Refresh(AUI.name, AUI.Broker.state)
	end

	AUI.MinimapElements:Refresh()
	self:Arrange(true)
	AUI.MinimapFade:Refresh()
end

---Takes the minimap over at login when the module is enabled; a login in combat waits for combat to end.
function Map:Start()
	if self.active or not self:IsEnabled() then
		return
	end

	if InCombatLockdown() then
		AUI.Events:Register("PLAYER_REGEN_ENABLED", self, function()
			AUI.Events:Unregister("PLAYER_REGEN_ENABLED", self)
			self:Start()
		end)

		return
	end

	self:Build()
	self:TakeOver()
	self.active = true
	self:Apply()
end
