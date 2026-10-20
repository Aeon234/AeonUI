local AUI = select(2, ...)

local Schema = AUI.Schema

-- Each indicator setting and the oUF element that draws it.
local ELEMENTS = {
	raid = "RaidTargetIndicator",
	resting = "RestingIndicator",
	combat = "CombatIndicator",
	leader = "LeaderIndicator",
	pvp = "PvPIndicator",
	classification = "AeonClassification",
}

local TEXTURES = "Interface\\AddOns\\AeonUI\\Media\\Textures\\Classification\\"

-- The icon for each classification the client reports; a world boss shows as elite.
local CLASSIFICATIONS = {
	rare = TEXTURES .. "Rare.png",
	elite = TEXTURES .. "Elite.png",
	worldboss = TEXTURES .. "Elite.png",
	rareelite = TEXTURES .. "RareElite.png",
}

-- Threat border colors: gold near aggro, orange with aggro.
local NEAR_AGGRO = { r = 1, g = 0.82, b = 0 }
local AGGRO = { r = 1, g = 0.5, b = 0 }

-- Space between the player frame and its totems.
local TOTEM_GAP = 4

---Indicators on unit frames: oUF's raid marker, resting, combat, leader, assistant, PvP, threat and totem elements,
---AeonUI's classification icon, and the mouseover border.
---@class AUIIndicators
local Indicators = {
	CLASSIFICATIONS = CLASSIFICATIONS,
}
AUI.Indicators = Indicators

-- Settings ------------------------------------------------------------------------------------------------

---@param config table
---@param key string
---@param name string
---@return table? settings the indicator's settings, or nil for a frame without it
function Indicators:Resolve(config, key, name)
	local base = "frames." .. key .. ".indicators." .. name .. "."

	if not Schema:Field(base .. "enabled") then
		return nil
	end

	local settings = {}

	for _, field in ipairs({ "enabled", "size", "anchor", "placement", "x", "y" }) do
		settings[field] = Schema:Read(config, base .. field)
	end

	return settings
end

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
---@return number x the totem's offset left of the frame's right edge
function Indicators:TotemOffset(size, spacing, index)
	return -(index - 1) * (size + spacing)
end

-- Classification element ------------------------------------------------------------------------------------

---@param frame table
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

local function EnableClassification(frame)
	if frame.AeonClassification then
		frame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED", UpdateClassification)

		return true
	end
end

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

-- Widgets -------------------------------------------------------------------------------------------------

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
	local top, bottom, left, right = unpack(edges)

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

---Shows the threat border in a color, only inside a group instance.
---@param element Frame
---@param status number?
local function ThreatPostUpdate(element, _, status)
	local color = not issecretvalue(status) and Indicators:ThreatColor(status)
	local grouped = IsInGroup() and select(2, IsInInstance()) ~= "none"

	if not color or not grouped then
		element:Hide()

		return
	end

	for _, edge in ipairs(element.Edges) do
		edge:SetVertexColor(color.r, color.g, color.b, 1)
	end
end

---Gives a frame its indicator widgets, for the indicators its key has settings for. Called from the style function,
---so oUF enables the elements as the frame spawns.
---@param frame table the oUF frame
function Indicators:Create(frame)
	local key = frame.key
	local base = "frames." .. key .. ".indicators."
	local layer = CreateFrame("Frame", nil, frame)

	layer:SetAllPoints()
	layer:SetFrameLevel(frame:GetFrameLevel() + 10)
	frame.IndicatorLayer = layer

	for name, element in pairs(ELEMENTS) do
		if Schema:Field(base .. name .. ".enabled") then
			if name == "resting" then
				local text = layer:CreateFontString(nil, "OVERLAY", "NumberFontNormal")

				text:SetText("ZZZ")
				frame[element] = text
			else
				frame[element] = layer:CreateTexture(nil, "OVERLAY")
			end

			if name == "leader" then
				frame.AssistantIndicator = layer:CreateTexture(nil, "OVERLAY")
			end
		end
	end

	if Schema:Field(base .. "threat.enabled") then
		local threat = CreateFrame("Frame", nil, frame)

		threat.Edges = Edges(threat)
		threat.PostUpdate = ThreatPostUpdate
		threat:SetAllPoints()
		frame.ThreatIndicator = threat
	end

	if Schema:Field("frames." .. key .. ".totems.enabled") then
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

	if Schema:Field("frames." .. key .. ".highlight") then
		frame:HookScript("OnEnter", function()
			Indicators:Highlight(frame, true)
		end)
		frame:HookScript("OnLeave", function()
			Indicators:Highlight(frame, false)
		end)
	end
end

---Turns the frame's border white while the mouse is over it, when its highlight setting is on.
---@param frame table
---@param over boolean
function Indicators:Highlight(frame, over)
	local lit = over and Schema:Read(AUI.Profile.config, "frames." .. frame.key .. ".highlight") == true
	local shade = lit and 1 or 0

	for _, edge in ipairs(frame.Border or {}) do
		edge:SetColorTexture(shade, shade, shade, 1)
	end
end

---Places one indicator widget against the frame's main bar.
---@param widget Region
---@param anchor Region
---@param settings table
local function Place(widget, anchor, settings)
	local point, relative = AUI.Text:Points(settings.anchor, settings.placement)

	widget:ClearAllPoints()
	widget:SetPoint(point, anchor, relative, settings.x, settings.y)
end

---Applies a frame's indicator settings: which elements run, and where and how large each is. Not protected; also
---runs in combat.
---@param frame table
---@param config table
function Indicators:Apply(frame, config)
	local key = frame.key
	local anchor = frame.Main or frame

	for name, element in pairs(ELEMENTS) do
		local widget = frame[element]
		local settings = widget and self:Resolve(config, key, name)

		if settings then
			if settings.enabled then
				frame:EnableElement(element)
			else
				frame:DisableElement(element)
				widget:Hide()
			end

			Place(widget, anchor, settings)

			if name == "resting" then
				widget:SetFont(AUI.Media:Font(Schema:Read(config, "frames." .. key .. ".text.font")), settings.size,
					AUI.Media:FontFlags(Schema:Read(config, "frames." .. key .. ".text.outline")))
			else
				widget:SetSize(settings.size, settings.size)
			end

			if name == "leader" and frame.AssistantIndicator then
				local assistant = frame.AssistantIndicator

				if settings.enabled then
					frame:EnableElement("AssistantIndicator")
				else
					frame:DisableElement("AssistantIndicator")
					assistant:Hide()
				end

				Place(assistant, anchor, settings)
				assistant:SetSize(settings.size, settings.size)
			end
		end
	end

	local threat = frame.ThreatIndicator

	if threat then
		local base = "frames." .. key .. ".indicators.threat."

		if Schema:Read(config, base .. "enabled") then
			frame:EnableElement("ThreatIndicator")
		else
			frame:DisableElement("ThreatIndicator")
			threat:Hide()
		end

		PlaceOutside(threat.Edges, frame, Schema:Read(config, base .. "size") * AUI:Pixel(frame))
	end

	local totems = frame.Totems

	if totems then
		local base = "frames." .. key .. ".totems."
		local size, spacing = Schema:Read(config, base .. "size"), Schema:Read(config, base .. "spacing")

		if Schema:Read(config, base .. "enabled") then
			frame:EnableElement("Totems")
		else
			frame:DisableElement("Totems")

			for _, totem in ipairs(totems) do
				totem:Hide()
			end
		end

		for index, totem in ipairs(totems) do
			totem:ClearAllPoints()
			totem:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", self:TotemOffset(size, spacing, index), -TOTEM_GAP)
			totem:SetSize(size, size)
		end
	end
end
