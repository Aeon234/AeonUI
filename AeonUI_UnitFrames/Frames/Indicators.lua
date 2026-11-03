local AUI = select(2, ...)

local Options = AUI.UnitFrameOptions

-- Each indicator setting and the oUF element that draws it.
local ELEMENTS = {
	raid = "RaidTargetIndicator",
	resting = "RestingIndicator",
	combat = "CombatIndicator",
	leader = "LeaderIndicator",
	pvp = "PvPIndicator",
	classification = "AeonClassification",
}

local CLASSIFICATION_ICONS = "Interface\\AddOns\\AeonUI\\Media\\Textures\\Classification\\"

-- The icon for each classification the client reports; a world boss shows as elite.
local CLASSIFICATIONS = {
	rare = CLASSIFICATION_ICONS .. "Rare.png",
	elite = CLASSIFICATION_ICONS .. "Elite.png",
	worldboss = CLASSIFICATION_ICONS .. "Elite.png",
	rareelite = CLASSIFICATION_ICONS .. "RareElite.png",
}

-- Threat border colors: gold near aggro, orange with aggro.
local NEAR_AGGRO = { r = 1, g = 0.82, b = 0 }
local AGGRO = { r = 1, g = 0.5, b = 0 }

-- The indicators' layer above the frame, over its bar, border and text.
local LAYER_LEVEL = 10

-- Blizzard's resting art on the player frame: an atlas of 42 frames, 6 columns by 7 rows, played over 1.5 seconds.
local REST_FLIPBOOK = "UI-HUD-UnitFrame-Player-Rest-Flipbook"
local FLIPBOOK = { rows = 7, columns = 6, frames = 42, duration = 1.5 }
-- The flipbook's frame for the still art, counted from 1: all three Zs at full opacity, before they fade out.
local REST_STILL_FRAME = 28
local REST_PORTRAIT = "UI-HUD-UnitFrame-PlayerPortrait-Rest"
local STATE_ICON = "Interface\\CharacterFrame\\UI-StateIcon"
local STATE_ICON_REST = { 0, 0.5, 0, 0.421875 }
local REST_FILES = "Interface\\AddOns\\AeonUI\\Media\\Textures\\Resting\\Resting"

---Indicators on unit frames: oUF's raid marker, resting, combat, leader, assistant, PvP, threat and totem elements.
---@class AUIIndicators
---@field ELEMENTS table<string, string>
local Indicators = {
	ELEMENTS = ELEMENTS,
}
AUI.Indicators = Indicators

---@param status number? the unit's threat situation, 0 to 3
---@return table? color the border color, or nil for no border
function Indicators:ThreatColor(status)
	if not status or status < 1 then
		return nil
	end

	return status == 1 and NEAR_AGGRO or AGGRO
end

---@param size number
---@param spacing number
---@param index integer
---@param growth string "left" or "right"
---@return number x the totem's offset from the first
function Indicators:TotemOffset(size, spacing, index, growth)
	local offset = (index - 1) * (size + spacing)

	return growth == "right" and offset or -offset
end

---@param icon string a resting icon setting
---@return string? file the icon's file, for those AeonUI ships
function Indicators:RestingFile(icon)
	local index = icon:match("^resting(%d)$")

	return index and (REST_FILES .. index .. ".tga") or nil
end

---@param icon string a resting icon setting
---@return boolean available this client has the icon's art
function Indicators:HasRestingIcon(icon)
	if icon == "portrait" then
		return C_Texture.GetAtlasInfo(REST_PORTRAIT) ~= nil
	elseif icon == "animated" or icon == "still" then
		return C_Texture.GetAtlasInfo(REST_FLIPBOOK) ~= nil
	end

	return true
end

---@return string|number file the resting flipbook's file
---@return number[] coords the frame with all three Zs
local function StillFrame()
	local info = C_Texture.GetAtlasInfo(REST_FLIPBOOK) --[[@as table]]
	local width = (info.rightTexCoord - info.leftTexCoord) / FLIPBOOK.columns
	local height = (info.bottomTexCoord - info.topTexCoord) / FLIPBOOK.rows
	local index = REST_STILL_FRAME - 1
	local left = info.leftTexCoord + (index % FLIPBOOK.columns) * width
	local top = info.topTexCoord + math.floor(index / FLIPBOOK.columns) * height

	return info.file or info.filename, { left, left + width, top, top + height }
end

---Draws a resting icon on its texture. The same icon keeps running, so a redraw does not restart its animation.
---@param texture Texture
---@param icon string a resting icon setting
function Indicators:StyleResting(texture, icon)
	if not self:HasRestingIcon(icon) then
		icon = "classic"
	end

	if texture.restingIcon == icon then
		return
	end

	texture.restingIcon = icon

	if texture.restingAnimation then
		texture.restingAnimation:Stop()
	end

	texture:SetTexCoord(0, 1, 0, 1)

	if icon == "animated" then
		texture:SetAtlas(REST_FLIPBOOK)

		if not texture.restingAnimation then
			local group = texture:CreateAnimationGroup()
			local flipbook = group:CreateAnimation("FlipBook")

			group:SetLooping("REPEAT")
			flipbook:SetFlipBookFrameWidth(0)
			flipbook:SetFlipBookFrameHeight(0)
			flipbook:SetFlipBookRows(FLIPBOOK.rows)
			flipbook:SetFlipBookColumns(FLIPBOOK.columns)
			flipbook:SetFlipBookFrames(FLIPBOOK.frames)
			flipbook:SetDuration(FLIPBOOK.duration)
			texture.restingAnimation = group
		end
	elseif icon == "still" then
		local file, coords = StillFrame()

		texture:SetTexture(file)
		texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
	elseif icon == "portrait" then
		texture:SetAtlas(REST_PORTRAIT)
	elseif icon == "classic" then
		texture:SetTexture(STATE_ICON)
		texture:SetTexCoord(STATE_ICON_REST[1], STATE_ICON_REST[2], STATE_ICON_REST[3], STATE_ICON_REST[4])
	else
		texture:SetTexture(self:RestingFile(icon))
	end

	self:PlayResting(texture, texture:IsShown())
end

---@param texture Texture
---@param shown boolean
function Indicators:PlayResting(texture, shown)
	local group = texture.restingAnimation

	if not group then
		return
	end

	if shown and texture.restingIcon == "animated" then
		group:Play()
	else
		group:Stop()
	end
end

---oUF's `RestingIndicator.PostUpdate`: the animation runs only while the icon shows.
---@param element Texture
---@param isResting boolean
local function RestingPostUpdate(element, isResting)
	Indicators:PlayResting(element, isResting)
end

---@param key string
---@param name string
---@return table settings the indicator's: `enabled`, `size`, `anchor`, `placement`, `x` and `y`
function Indicators:Resolve(key, name)
	local settings = {}

	for _, field in ipairs({ "enabled", "size", "anchor", "placement", "x", "y" }) do
		settings[field] = AUI.Profile:Get(Options:Path(key, "indicators." .. name .. "." .. field))
	end

	return settings
end

---@param parent Frame
---@return Texture[] edges top, bottom, left and right
local function Edges(parent)
	local edges = {}

	for index = 1, 4 do
		edges[index] = parent:CreateTexture(nil, "BACKGROUND")
		edges[index]:SetColorTexture(1, 1, 1, 1)
	end

	return edges
end

---Places a border's edges just outside a region.
---@param edges Texture[]
---@param region Region
---@param size number
local function PlaceOutside(edges, region, size)
	local top, bottom, left, right = edges[1], edges[2], edges[3], edges[4]

	for _, edge in ipairs(edges) do
		edge:ClearAllPoints()
	end

	top:SetPoint("BOTTOMLEFT", region, "TOPLEFT", -size, 0)
	top:SetPoint("BOTTOMRIGHT", region, "TOPRIGHT", size, 0)
	top:SetHeight(size)
	bottom:SetPoint("TOPLEFT", region, "BOTTOMLEFT", -size, 0)
	bottom:SetPoint("TOPRIGHT", region, "BOTTOMRIGHT", size, 0)
	bottom:SetHeight(size)
	left:SetPoint("TOPRIGHT", region, "TOPLEFT")
	left:SetPoint("BOTTOMRIGHT", region, "BOTTOMLEFT")
	left:SetWidth(size)
	right:SetPoint("TOPLEFT", region, "TOPRIGHT")
	right:SetPoint("BOTTOMLEFT", region, "BOTTOMRIGHT")
	right:SetWidth(size)
end

---@param key string
---@return boolean ring threat draws a ring around the frame: its border is a line or absent, with no band to color
function Indicators:UsesThreatRing(key)
	local style = AUI.UnitFrame:BarLook(key).borderStyle

	return style == "THIN_LINE" or style == "NONE"
end

---Shows threat in a color, or nothing: as a ring around the frame, or in the frame's own border, whose band would
---cover a ring.
---@param frame table
---@param color table?
function Indicators:ShowThreat(frame, color)
	local element = frame.ThreatIndicator
	local ring = self:UsesThreatRing(frame.key)
	local borderColor = not ring and color or nil

	element.threatColor = color
	element:SetShown(ring and color ~= nil)

	if ring and color then
		for _, edge in ipairs(element.Edges) do
			edge:SetVertexColor(color.r, color.g, color.b, 1)
		end
	end

	if frame.threatColor ~= borderColor then
		frame.threatColor = borderColor
		frame:ShowHovered(frame.hovered == true)
	end
end

---oUF's `ThreatIndicator.PostUpdate`: threat shows only inside a group instance.
---@param element Frame
---@param status number?
local function ThreatPostUpdate(element, _, status)
	local color = not issecretvalue(status) and Indicators:ThreatColor(status) or nil
	local grouped = IsInGroup() and select(2, IsInInstance()) ~= "none"

	Indicators:ShowThreat(element.owner, grouped and color or nil)
end

---Gives a frame its indicator widgets. Called from the style function, so oUF enables the elements as the frame spawns.
---@param frame table the oUF frame
function Indicators:Create(frame)
	local spec = frame.spec

	if spec.indicators then
		local layer = CreateFrame("Frame", nil, frame.Content)

		layer:SetAllPoints()
		layer:SetFrameLevel(frame.Content:GetFrameLevel() + LAYER_LEVEL)
		frame.IndicatorLayer = layer

		for _, indicator in ipairs(spec.indicators) do
			local element = ELEMENTS[indicator.name] --[[@as string]]

			frame[element] = layer:CreateTexture(nil, "OVERLAY")

			if indicator.name == "resting" then
				frame[element].PostUpdate = RestingPostUpdate
			end

			if indicator.name == "leader" then
				frame.AssistantIndicator = layer:CreateTexture(nil, "OVERLAY")
			end
		end
	end

	if spec.threat then
		local threat = CreateFrame("Frame", nil, frame)

		threat.Edges = Edges(threat)
		threat.PostUpdate = ThreatPostUpdate
		threat.owner = frame
		threat:SetAllPoints()
		frame.ThreatIndicator = threat
	end

	if spec.totems then
		local totems = {}

		for index = 1, MAX_TOTEMS or 4 do
			local totem = CreateFrame("Button", nil, frame)
			local icon = totem:CreateTexture(nil, "OVERLAY")
			local cooldown = CreateFrame("Cooldown", nil, totem, "CooldownFrameTemplate")

			icon:SetAllPoints()
			icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			cooldown:SetAllPoints()
			cooldown:SetReverse(true)
			cooldown:SetDrawEdge(false)
			totem.Icon, totem.Cooldown = icon, cooldown
			totems[index] = totem
		end

		frame.Totems = totems
	end
end

---Places one indicator against the frame's bar.
---@param widget Region
---@param anchor Region
---@param settings table `anchor`, `placement`, `x` and `y`
function Indicators:Place(widget, anchor, settings)
	local point, relative = AUI.Text:Points(settings.anchor, settings.placement)

	widget:ClearAllPoints()
	widget:SetPoint(point, anchor, relative, settings.x, settings.y)
end

---@param frame table
---@param _ string the event
---@param unit string?
local function UpdateClassification(frame, _, unit)
	local element = frame.AeonClassification
	local classification = UnitClassification(unit or frame.__unit)

	if issecretvalue(classification) then
		element:Hide()

		return
	end

	local file = CLASSIFICATIONS[classification]

	element:SetShown(file ~= nil)

	if file then
		element:SetTexture(file)
	end
end

---@param frame table
---@return boolean? active
local function EnableClassification(frame)
	if frame.AeonClassification then
		frame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED", UpdateClassification)

		return true
	end
end

---@param frame table
local function DisableClassification(frame)
	if frame.AeonClassification then
		frame.AeonClassification:Hide()
		frame:UnregisterEvent("UNIT_CLASSIFICATION_CHANGED", UpdateClassification)
	end
end

---Adds the classification element to AeonUI's oUF, before any frame spawns.
function Indicators:Register()
	AUI.oUF:AddElement("AeonClassification", UpdateClassification, EnableClassification, DisableClassification)
end

---Runs or stops an element. oUF draws nothing as it enables an element, so one turned back on is updated here.
---@param frame table
---@param element string
---@param on boolean
---@param widget table the element's widget, or its list of widgets
function Indicators:SetElement(frame, element, on, widget)
	if on then
		if not frame:IsElementEnabled(element) then
			frame:EnableElement(element)

			if widget.ForceUpdate then
				widget:ForceUpdate()
			end
		end
	else
		frame:DisableElement(element)

		if widget.Hide then
			widget:Hide()
		end
	end
end

---Applies a frame's indicator settings: which elements run and how large each is. Not protected; also runs in combat.
---@param frame table
function Indicators:Apply(frame)
	local key, spec, Profile = frame.key, frame.spec, AUI.Profile

	local function Get(field)
		return Profile:Get(Options:Path(key, field))
	end

	for _, indicator in ipairs(spec.indicators or {}) do
		local name = indicator.name
		local element = ELEMENTS[name] --[[@as string]]
		local widget = frame[element]
		local settings = self:Resolve(key, name)
		local on, size = settings.enabled, settings.size

		self:SetElement(frame, element, on, widget)
		self:Place(widget, frame.Bar, settings)
		widget:SetSize(size, size)

		if name == "resting" then
			self:StyleResting(widget, Get("indicators.resting.icon"))
		end

		if name == "leader" then
			self:SetElement(frame, "AssistantIndicator", on, frame.AssistantIndicator)
			self:Place(frame.AssistantIndicator, frame.Bar, settings)
			frame.AssistantIndicator:SetSize(size, size)
		end
	end

	local threat = frame.ThreatIndicator

	if threat then
		local on = Get("indicators.threat.enabled")

		self:SetElement(frame, "ThreatIndicator", on, threat)
		PlaceOutside(threat.Edges, frame, Get("indicators.threat.size") * AUI:Pixel(frame))
		self:ShowThreat(frame, on and threat.threatColor or nil)
	end

	local totems = frame.Totems

	if totems then
		local size, spacing = Get("totems.size"), Get("totems.spacing")
		local on = Get("totems.enabled")
		local point, relative = AUI.Text:Points(Get("totems.anchor"), Get("totems.placement"))
		local x, y, growth = Get("totems.x"), Get("totems.y"), Get("totems.growth")

		self:SetElement(frame, "Totems", on, totems)

		for index, totem in ipairs(totems) do
			if not on then
				totem:Hide()
			end

			totem:ClearAllPoints()
			totem:SetPoint(point, frame, relative, x + self:TotemOffset(size, spacing, index, growth), y)
			totem:SetSize(size, size)
		end
	end
end
