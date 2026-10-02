local AUI = select(2, ...)

local Schema = AUI.Schema

-- Space between a detached portrait and its frame.
local GAP = 4

local QUESTION_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local QUESTION_MODEL = "Interface\\Buttons\\TalkToMeQuestionMark.m2"

---@class AUIPortraitSettings
---@field enabled boolean
---@field mode string "2d", "3d" or "class"
---@field style string "attached" or "detached"
---@field side string "LEFT" or "RIGHT"
---@field size number a detached portrait's size
---@field x number a detached portrait's offsets
---@field y number

---A portrait's regions: a holder with the bars' background and border, a texture for 2D and class icons, and a
---model for 3D, created when first needed.
---@class AUIPortraitWidgets
---@field holder Frame
---@field background Texture
---@field border Texture[]
---@field texture Texture
---@field model PlayerModel?

---Portraits on the player, target, focus and boss frames: oUF's Portrait element on a texture or a model, placed
---attached inside the frame at a side or detached outside it.
---@class AUIPortrait
local Portrait = {}
AUI.Portrait = Portrait

---@param config table
---@param key string
---@return AUIPortraitSettings? settings nil for a frame without a portrait
function Portrait:Resolve(config, key)
	local base = "frames." .. key .. ".portrait."

	if not Schema:Field(base .. "enabled") then
		return nil
	end

	return {
		enabled = Schema:Read(config, base .. "enabled"),
		mode = Schema:Read(config, base .. "mode"),
		style = Schema:Read(config, base .. "style"),
		side = Schema:Read(config, base .. "side"),
		size = Schema:Read(config, base .. "size"),
		x = Schema:Read(config, base .. "x"),
		y = Schema:Read(config, base .. "y"),
	}
end

---@param config table
---@param key string
---@return number left the room an attached portrait takes from the bars at each side
---@return number right
function Portrait:Inset(config, key)
	local settings = self:Resolve(config, key)

	if not settings or not settings.enabled or settings.style ~= "attached" then
		return 0, 0
	end

	local main, power = AUI.UnitFrame:Heights(config, key)

	if settings.side == "LEFT" then
		return main + power, 0
	end

	return 0, main + power
end

---@param config table
---@param key string
---@param settings AUIPortraitSettings
---@return number size the portrait's side: the frame's full height when attached
function Portrait:Size(config, key, settings)
	if settings.style == "attached" then
		local main, power = AUI.UnitFrame:Heights(config, key)

		return main + power
	end

	return settings.size
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
---@return AUIPortraitWidgets
function Portrait:Create(parent)
	local holder = CreateFrame("Frame", nil, parent)
	local background = holder:CreateTexture(nil, "BACKGROUND")
	local texture = holder:CreateTexture(nil, "ARTWORK")
	local border = {}

	background:SetAllPoints()
	background:SetColorTexture(1, 1, 1, 1)

	for index = 1, 4 do
		border[index] = holder:CreateTexture(nil, "OVERLAY", nil, 7)
	end

	holder:Hide()

	return { holder = holder, background = background, border = border, texture = texture }
end

---@param widgets AUIPortraitWidgets
---@return PlayerModel model
function Portrait:Model(widgets)
	if not widgets.model then
		widgets.model = CreateFrame("PlayerModel", nil, widgets.holder)
		widgets.model:Hide()
	end

	return widgets.model
end

---Sizes and places a portrait against its frame, in the bars' background and border.
---@param widgets AUIPortraitWidgets
---@param settings AUIPortraitSettings
---@param anchor Region the frame
---@param config table
---@param key string
---@param pixel number one physical pixel in the frame's units
function Portrait:Place(widgets, settings, anchor, config, key, pixel)
	local holder = widgets.holder
	local size = self:Size(config, key, settings)
	local look = AUI.UnitFrame:BarLook(config, key)
	local fill, edge = look.background, look.borderColor
	local inset = look.border * pixel
	local left = settings.side == "LEFT"

	holder:ClearAllPoints()
	holder:SetSize(size, size)

	if settings.style == "attached" then
		holder:SetPoint(left and "TOPLEFT" or "TOPRIGHT", anchor)
	elseif left then
		holder:SetPoint("TOPRIGHT", anchor, "TOPLEFT", settings.x - GAP, settings.y)
	else
		holder:SetPoint("TOPLEFT", anchor, "TOPRIGHT", settings.x + GAP, settings.y)
	end

	widgets.background:SetVertexColor(fill.r, fill.g, fill.b, fill.a or 1)

	for _, texture in ipairs(widgets.border) do
		texture:SetColorTexture(edge.r, edge.g, edge.b, edge.a or 1)
		texture:SetShown(look.border > 0)
	end

	AUI.UnitFrame:LayoutBorder(widgets.border, holder, inset)

	for _, region in ipairs({ widgets.texture, widgets.model }) do
		region:ClearAllPoints()
		region:SetPoint("TOPLEFT", holder, "TOPLEFT", inset, -inset)
		region:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -inset, inset)
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
---@param config table
function Portrait:Apply(frame, config)
	local widgets = frame.PortraitWidgets --[[@as AUIPortraitWidgets]]
	local settings = self:Resolve(config, frame.key) --[[@as AUIPortraitSettings]]

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

	self:Place(widgets, settings, frame, config, frame.key, AUI:Pixel(frame))
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
	frame.Portrait = widget
	frame.portraitMode = settings.mode
	frame:EnableElement("Portrait")

	if frame:IsVisible() and widget.ForceUpdate then
		widget:ForceUpdate()
	end
end

---Draws a sample's portrait: the player's own for the player sample, a question mark for the others.
---@param widgets AUIPortraitWidgets
---@param config table
---@param key string
---@param anchor Region the sample frame
---@param pixel number
function Portrait:DrawSample(widgets, config, key, anchor, pixel)
	local settings = self:Resolve(config, key) --[[@as AUIPortraitSettings]]

	widgets.holder:SetShown(settings.enabled)

	if not settings.enabled then
		return
	end

	local model = settings.mode == "3d" and self:Model(widgets) or nil

	self:Place(widgets, settings, anchor, config, key, pixel)

	local texture = widgets.texture
	local own = key == "player"

	texture:SetShown(model == nil)

	if widgets.model then
		widgets.model:SetShown(model ~= nil)
	end

	if model then
		model:ClearModel()

		if own then
			model:SetUnit("player")
		else
			model:SetModel(QUESTION_MODEL)
		end

		return
	end

	local atlas = settings.mode == "class" and own and self:ClassAtlas("player")

	texture:SetTexCoord(0, 1, 0, 1)

	if atlas then
		texture:SetAtlas(atlas)
	elseif own then
		SetPortraitTexture(texture, "player")
	else
		texture:SetTexture(QUESTION_ICON)
	end
end
