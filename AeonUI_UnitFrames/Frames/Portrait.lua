local AUI = select(2, ...)

local Options = AUI.UnitFrameOptions

-- Space between a detached portrait and its frame.
local GAP = 4

-- The portrait's own border draws no fill: its background lies under the picture.
local NO_FILL = { r = 0, g = 0, b = 0, a = 0 }

---@class AUIPortraitSettings
---@field enabled boolean
---@field mode string "2d", "3d" or "class"
---@field style string "attached" or "detached"
---@field side string "LEFT" or "RIGHT"
---@field size number a detached portrait's size
---@field x number a detached portrait's offsets
---@field y number

---A portrait's regions: a holder with the bars' background, a texture for 2D and class icons, a divider beside the bar
---when attached, and what is made when first needed: a model for 3D and a border for Detached.
---@class AUIPortraitWidgets
---@field holder Frame
---@field background Texture
---@field texture Texture
---@field divider Texture
---@field model PlayerModel?
---@field border AUIBorder?

---Portraits: oUF's Portrait element on a texture or a model, placed attached inside the frame at a side or detached
---outside it.
---@class AUIPortrait
local Portrait = {}
AUI.Portrait = Portrait

---@param key string
---@return AUIPortraitSettings? settings nil for a frame without a portrait
function Portrait:Resolve(key)
	local spec = Options:Spec(key)

	if not spec or not spec.portrait then
		return nil
	end

	local settings = {}

	for _, field in ipairs({ "enabled", "mode", "style", "side", "size", "x", "y" }) do
		settings[field] = AUI.Profile:Get(Options:Path(key, "portrait." .. field))
	end

	return settings --[[@as AUIPortraitSettings]]
end

---@param key string
---@return number left the room an attached portrait takes from the bar at each side
---@return number right
function Portrait:Inset(key)
	local settings = self:Resolve(key)

	if not settings or not settings.enabled or settings.style ~= "attached" then
		return 0, 0
	end

	local height = AUI.UnitFrame:FrameHeight(key)

	if settings.side == "LEFT" then
		return height, 0
	end

	return 0, height
end

---@param key string
---@param settings AUIPortraitSettings
---@return number size the portrait's side: the frame's full height when attached
function Portrait:Size(key, settings)
	if settings.style == "attached" then
		return AUI.UnitFrame:FrameHeight(key)
	end

	return settings.size
end

---How far a detached portrait reaches past the frame, for sizing the preview.
---@param key string
---@return number above
---@return number below
---@return number left
---@return number right
function Portrait:Reach(key)
	local settings = self:Resolve(key)

	if not settings or not settings.enabled or settings.style ~= "detached" then
		return 0, 0, 0, 0
	end

	local height = AUI.UnitFrame:FrameHeight(key)
	local above = math.max(0, settings.y)
	local below = math.max(0, settings.size - settings.y - height)

	if settings.side == "LEFT" then
		return above, below, math.max(0, settings.size + GAP - settings.x), 0
	end

	return above, below, 0, math.max(0, settings.size + GAP + settings.x)
end

---@param unit string
---@return string? atlas the class icon of a player unit whose class can be read
function Portrait:ClassAtlas(unit)
	if not UnitIsPlayer(unit) then
		return nil
	end

	local _, class = UnitClass(unit)

	class = AUI:Readable(class)

	return class and ("classicon-" .. class) or nil
end

---@param parent Frame
---@param bar StatusBar the bar it sits beside, whose level it shares
---@return AUIPortraitWidgets
function Portrait:Create(parent, bar)
	local holder = CreateFrame("Frame", nil, parent)
	local background = holder:CreateTexture(nil, "BACKGROUND")
	local texture = holder:CreateTexture(nil, "ARTWORK")
	local divider = holder:CreateTexture(nil, "OVERLAY")

	holder:SetFrameLevel(bar:GetFrameLevel())
	background:SetAllPoints()
	background:SetColorTexture(1, 1, 1, 1)
	texture:SetAllPoints()
	divider:Hide()
	holder:Hide()

	return { holder = holder, background = background, texture = texture, divider = divider }
end

---@param widgets AUIPortraitWidgets
---@return PlayerModel model
function Portrait:Model(widgets)
	if not widgets.model then
		widgets.model = CreateFrame("PlayerModel", nil, widgets.holder)
		widgets.model:SetAllPoints()
		widgets.model:Hide()
	end

	return widgets.model
end

---Draws the line between an attached portrait and the bar, in the border style's own band where it has one.
---@param widgets AUIPortraitWidgets
---@param look AUIBarLook
---@param attached boolean
---@param left boolean the portrait is at the frame's left
local function StyleDivider(widgets, look, attached, left)
	local divider = widgets.divider
	local shown = attached and look.borderStyle ~= "NONE"

	divider:SetShown(shown)

	if not shown then
		return
	end

	local color = look.borderColor
	local width = AUI.Border:CellDividerWidth(look.borderStyle, look.borderThickness)

	if not width or not AUI.Border:StyleCellDivider(divider, look.borderStyle, color) then
		width = AUI:Pixel(widgets.holder)
		divider:SetDesaturated(false)
		divider:SetVertexColor(1, 1, 1, 1)
		divider:SetTexCoord(0, 1, 0, 1)
		divider:SetColorTexture(color.r, color.g, color.b, color.a or 1)
	end

	local edge = left and "RIGHT" or "LEFT"

	divider:ClearAllPoints()
	divider:SetPoint("TOP" .. edge, widgets.holder, "TOP" .. edge)
	divider:SetPoint("BOTTOM" .. edge, widgets.holder, "BOTTOM" .. edge)
	divider:SetWidth(width --[[@as number]])
end

---Sizes and places a portrait against its frame, in the bars' background and border. An attached one lies under the
---frame's border; a detached one has its own.
---@param widgets AUIPortraitWidgets
---@param settings AUIPortraitSettings
---@param anchor Region the frame
---@param key string
function Portrait:Place(widgets, settings, anchor, key)
	local holder = widgets.holder
	local size = self:Size(key, settings)
	local look = AUI.UnitFrame:BarLook(key)
	local fill = look.background
	local left = settings.side == "LEFT"
	local attached = settings.style == "attached"

	holder:ClearAllPoints()
	holder:SetSize(size, size)

	if attached then
		holder:SetPoint(left and "TOPLEFT" or "TOPRIGHT", anchor)
	elseif left then
		holder:SetPoint("TOPRIGHT", anchor, "TOPLEFT", settings.x - GAP, settings.y)
	else
		holder:SetPoint("TOPLEFT", anchor, "TOPRIGHT", settings.x + GAP, settings.y)
	end

	widgets.background:SetVertexColor(fill.r, fill.g, fill.b, fill.a or 1)
	StyleDivider(widgets, look, attached, left)

	if not attached and not widgets.border then
		widgets.border = AUI.Border:Create(holder, true)
		widgets.border:SetFrameLevel(holder:GetFrameLevel() + 3)
	end

	if widgets.border then
		widgets.border:Apply({
			style = attached and "NONE" or look.borderStyle,
			color = look.borderColor,
			thickness = look.borderThickness,
			edgeFile = look.edgeFile,
			background = NO_FILL,
		})
	end
end

---oUF's `Portrait.Override` in Class Icon mode: a readable player class shows its icon, anything else the 2D portrait.
---@param frame table the oUF frame
---@param _ string? the event
---@param unit string?
local function ClassOverride(frame, _, unit)
	if not unit or unit ~= frame.__unit then
		return
	end

	local element = frame.Portrait
	local atlas = Portrait:ClassAtlas(unit)

	if atlas then
		element:SetAtlas(atlas)
	else
		element:SetTexCoord(0, 1, 0, 1)
		SetPortraitTexture(element, unit)
	end
end

---Shows, places and switches a live frame's portrait: the texture for 2D and class icons, the model for 3D. Not
---protected; runs in combat too.
---@param frame table an AeonUI unit frame with portrait widgets
function Portrait:Apply(frame)
	local widgets = frame.PortraitWidgets --[[@as AUIPortraitWidgets]]
	local settings = self:Resolve(frame.key) --[[@as AUIPortraitSettings]]

	if not settings.enabled then
		if frame.Portrait then
			frame:DisableElement("Portrait")
			frame.Portrait = nil
		end

		frame.portraitMode = nil
		widgets.holder:Hide()

		return
	end

	local model = settings.mode == "3d" and self:Model(widgets) or nil

	self:Place(widgets, settings, frame, frame.key)
	widgets.holder:Show()

	if frame.portraitMode == settings.mode then
		return
	end

	if frame.Portrait then
		frame:DisableElement("Portrait")
	end

	local widget = model or widgets.texture

	widgets.texture:Hide()
	widgets.texture:SetTexCoord(0, 1, 0, 1)

	if widgets.model then
		widgets.model:Hide()
	end

	widget.Override = settings.mode == "class" and ClassOverride or nil
	widget:Show()
	frame.Portrait = widget
	frame.portraitMode = settings.mode
	frame:EnableElement("Portrait")

	if frame:IsVisible() and widget.ForceUpdate then
		widget:ForceUpdate()
	end
end

---Draws a sample's portrait: the player's own.
---@param widgets AUIPortraitWidgets
---@param key string
---@param anchor Region the sample frame
function Portrait:DrawSample(widgets, key, anchor)
	local settings = self:Resolve(key) --[[@as AUIPortraitSettings]]

	widgets.holder:SetShown(settings.enabled)

	if not settings.enabled then
		return
	end

	local model = settings.mode == "3d" and self:Model(widgets) or nil

	self:Place(widgets, settings, anchor, key)

	local texture = widgets.texture

	texture:SetShown(model == nil)

	if widgets.model then
		widgets.model:SetShown(model ~= nil)
	end

	if model then
		model:ClearModel()
		model:SetUnit("player")

		return
	end

	local atlas = settings.mode == "class" and self:ClassAtlas("player")

	texture:SetTexCoord(0, 1, 0, 1)

	if atlas then
		texture:SetAtlas(atlas)
	else
		SetPortraitTexture(texture, "player")
	end
end
