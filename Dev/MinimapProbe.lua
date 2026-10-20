-- The M0 minimap probe: takes over Blizzard's minimap the way the Minimap module would, so each open question can be
-- answered in game on both clients. Development only; never packaged. Undo with /reload.
local AUI = select(2, ...)

local MEDIA = "Interface\\AddOns\\AeonUI\\Dev\\Media\\"

-- Each mask with the visible area's width-to-height ratio. "plain" is a square white mask: any crop comes from the
-- holder's clipping alone.
local MASKS = {
	plain = { file = "Interface\\BUTTONS\\WHITE8X8", aspect = 4 / 3 },
	["1x1"] = { file = MEDIA .. "Chamfer-1x1", aspect = 1 },
	["4x3"] = { file = MEDIA .. "Chamfer-4x3", aspect = 4 / 3 },
	["16x9"] = { file = MEDIA .. "Chamfer-16x9", aspect = 16 / 9 },
}

-- Blizzard methods whose calls are counted after the probe takes a frame over: each count is Blizzard moving,
-- reparenting or re-masking something the probe placed.
local WATCHED = {
	{ key = "Minimap", method = "SetParent" },
	{ key = "Minimap", method = "SetPoint" },
	{ key = "Minimap", method = "SetSize" },
	{ key = "Minimap", method = "SetMaskTexture" },
	{ key = "Tracking", method = "SetParent" },
	{ key = "Tracking", method = "SetPoint" },
	{ key = "Compartment", method = "SetParent" },
	{ key = "Compartment", method = "SetPoint" },
	{ key = "Compartment", method = "SetShown" },
	{ key = "Queue", method = "SetPoint" },
}

---@class AUIMinimapProbe
---@field active boolean the probe has taken the minimap over this session
---@field width number the map's width; its height follows the mask's ratio
---@field mask string a key of MASKS
---@field clip boolean the holder clips its children
---@field ignoreRotation boolean rotation is ignored while the probe is active
---@field counts table<string, integer> calls to each watched method that the probe did not make
---@field applying boolean the probe is making the calls itself
---@field holder Frame?
---@field hidden Frame?
---@field cells Frame[]?
---@field hybridHooked boolean? HybridMinimap's OnHide is hooked
local Probe = {
	active = false,
	width = 240,
	mask = "4x3",
	clip = true,
	ignoreRotation = true,
	counts = {},
	applying = false,
}
AUI.Dev.MinimapProbe = Probe

---@param key string
---@return table? frame the Blizzard frame the key names, when this client has it
local function Watched(key)
	if key == "Minimap" then
		return Minimap
	elseif key == "Tracking" then
		return MinimapCluster and MinimapCluster.Tracking and MinimapCluster.Tracking.Button
	elseif key == "Compartment" then
		return AddonCompartmentFrame
	elseif key == "Queue" then
		return QueueStatusButton
	end
end

function Probe:Watch()
	for _, entry in ipairs(WATCHED) do
		local frame = Watched(entry.key)
		local name = entry.key .. ":" .. entry.method

		if frame and frame[entry.method] and self.counts[name] == nil then
			self.counts[name] = 0

			hooksecurefunc(frame, entry.method, function()
				if not Probe.applying then
					Probe.counts[name] = Probe.counts[name] + 1
				end
			end)
		end
	end
end

---@return Frame holder
function Probe:Holder()
	if self.holder then
		return self.holder
	end

	local holder = CreateFrame("Frame", "AeonUIMinimapProbe", UIParent)

	holder:SetPoint("TOPRIGHT", -60, -60)
	holder:SetFrameStrata("LOW")

	local edge = holder:CreateTexture(nil, "BACKGROUND")

	edge:SetPoint("TOPLEFT", -2, 2)
	edge:SetPoint("BOTTOMRIGHT", 2, -2)
	edge:SetColorTexture(0.62, 0.46, 0.29, 1)

	local hidden = CreateFrame("Frame")

	hidden:Hide()
	self.hidden = hidden
	self.holder = holder

	return holder
end

---Places the map in the holder at the current width, mask and clipping. Out of combat only.
function Probe:Apply()
	local mask = MASKS[self.mask]
	local width = self.width
	local height = math.floor(width / mask.aspect + 0.5)
	local crop = (width - height) / 2
	local holder = self:Holder()

	self.applying = true

	holder:SetSize(width, height)
	holder:SetClipsChildren(self.clip)

	Minimap:SetParent(holder)
	Minimap:ClearAllPoints()
	Minimap:SetPoint("CENTER")
	Minimap:SetSize(width, width)
	Minimap:SetMaskTexture(mask.file)
	Minimap:SetHitRectInsets(0, 0, crop, crop)
	Minimap:SetArchBlobRingScalar(0)
	Minimap:SetQuestBlobRingScalar(0)
	Minimap:SetTaskBlobRingScalar(0)

	-- A zoom change makes the map draw again at its new size.
	local zoom = Minimap:GetZoom()

	Minimap:SetZoom(zoom > 0 and 0 or 1)
	Minimap:SetZoom(zoom)

	self.applying = false
end

---Moves Blizzard's minimap out of its cluster and parks the cluster, with everything still in it, on a hidden frame.
function Probe:TakeOver()
	self:Holder()
	self:Watch()
	self:Apply()

	self.applying = true

	MinimapCluster:SetParent(self.hidden)

	for _, key in ipairs({ "ZoomIn", "ZoomOut", "ZoomHitArea" }) do
		if Minimap[key] then
			Minimap[key]:SetParent(self.hidden)
		end
	end

	Minimap:EnableMouseWheel(true)
	Minimap:SetScript("OnMouseWheel", function(_, delta)
		local zoom = Minimap:GetZoom() + (delta > 0 and 1 or -1)

		Minimap:SetZoom(math.max(0, math.min(Minimap:GetZoomLevels() - 1, zoom)))
	end)

	self.applying = false

	if self.ignoreRotation then
		C_Minimap.SetIgnoreRotateMinimap(true)
	end

	-- Leaving a hybrid (indoor) map turns rotation back on: HybridMinimap's OnHide clears the ignore flag.
	if HybridMinimap and not self.hybridHooked then
		self.hybridHooked = true
		HybridMinimap:HookScript("OnHide", function()
			if Probe.active and Probe.ignoreRotation then
				C_Minimap.SetIgnoreRotateMinimap(true)
			end
		end)
	end

	GetMinimapShape = function()
		return "SQUARE"
	end

	local icon = LibStub("LibDBIcon-1.0", true)

	if icon and AUI.Broker.icon then
		icon:Refresh(AUI.name, AUI.Broker.state)
	end

	self.active = true
end

---Puts Blizzard's tracking button and the addon compartment into two cells above the map, with the event and
---landing page buttons in the map's top-left corner, to see whether Blizzard moves them back.
function Probe:Buttons()
	local holder = self:Holder()

	if not self.cells then
		self.cells = {}

		for index = 1, 2 do
			local cell = CreateFrame("Frame", nil, holder)

			cell:SetSize(24, 24)
			cell:SetPoint("BOTTOMRIGHT", holder, "TOPRIGHT", -(index - 1) * 28, 4)
			self.cells[index] = cell
		end
	end

	self.applying = true

	local tracking = Watched("Tracking")

	if tracking then
		tracking:SetParent(self.cells[1])
		tracking:ClearAllPoints()
		tracking:SetPoint("CENTER")
	end

	if AddonCompartmentFrame then
		AddonCompartmentFrame:SetParent(self.cells[2])
		AddonCompartmentFrame:ClearAllPoints()
		AddonCompartmentFrame:SetPoint("CENTER")
	end

	local external = MinimapBackdrop and MinimapBackdrop.ExternalEventURLButton
	local landing = ExpansionLandingPageMinimapButton

	for _, button in ipairs({ external or false, landing or false }) do
		if button then
			button:SetParent(holder)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", 4, -4)
		end
	end

	self.applying = false
end

---@param frame table?
---@return string text where a frame sits: shown, its parent's name and its first point
local function Where(frame)
	if not frame then
		return "absent"
	end

	local parent = frame:GetParent()
	local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
	local relative = relativeTo and (relativeTo:GetName() or tostring(relativeTo)) or "nil"

	return ("visible %s, parent %s, %s %s %s %.0f %.0f"):format(tostring(frame:IsVisible()),
		parent and (parent:GetName() or tostring(parent)) or "nil", tostring(point), relative, tostring(relativePoint),
		x or 0, y or 0)
end

function Probe:Report()
	local version, build = GetBuildInfo()

	AUI:Print("minimap probe: client %s.%s, active %s, mask %s, width %d, clip %s", tostring(version),
		tostring(build), tostring(self.active), self.mask, self.width, tostring(self.clip))
	AUI:Print("map: size %.0f x %.0f, zoom %d of %d, rotateMinimap %s, shape %s", Minimap:GetWidth(),
		Minimap:GetHeight(), Minimap:GetZoom(), Minimap:GetZoomLevels(), tostring(GetCVar("rotateMinimap")),
		GetMinimapShape and GetMinimapShape() or "none")
	AUI:Print("cluster: %s; bottom %s", Where(MinimapCluster), tostring(MinimapCluster:GetBottom()))
	AUI:Print("calendar: %s", Where(GameTimeFrame))
	AUI:Print("coordinates: %s", Where(MinimapCluster.MinimapContainer and MinimapCluster.MinimapContainer.PlayerCoords))
	AUI:Print("hybrid map: %s", Where(HybridMinimap))
	AUI:Print("tracking: %s", Where(Watched("Tracking")))
	AUI:Print("compartment: %s", Where(AddonCompartmentFrame))
	AUI:Print("queue status: %s", Where(QueueStatusButton))
	AUI:Print("event button: %s", Where(MinimapBackdrop and MinimapBackdrop.ExternalEventURLButton))
	AUI:Print("landing page: %s", Where(ExpansionLandingPageMinimapButton))

	local names = {}

	for name in pairs(self.counts) do
		names[#names + 1] = name
	end

	table.sort(names)

	for _, name in ipairs(names) do
		AUI:Print("  Blizzard %s: %d", name, self.counts[name])
	end
end

local HELP = "minimap probe: on, mask <plain|1x1|4x3|16x9>, width <n>, clip <on|off>, rotation <ignore|follow>, "
	.. "buttons, report; /reload undoes it"

---@param line string
function Probe:Command(line)
	local command, value = line:match("^(%S*)%s*(%S*)")

	if command == "report" then
		self:Report()

		return
	end

	if InCombatLockdown() then
		AUI:Warn("the minimap probe changes frames only out of combat.")

		return
	end

	if command == "on" then
		self:TakeOver()
		self:Report()
	elseif command == "mask" and MASKS[value or ""] then
		self.mask = value
		self:Apply()
	elseif command == "width" and tonumber(value) then
		self.width = math.max(100, math.min(500, tonumber(value) --[[@as number]]))
		self:Apply()
	elseif command == "clip" and (value == "on" or value == "off") then
		self.clip = value == "on"
		self:Apply()
	elseif command == "rotation" and (value == "ignore" or value == "follow") then
		self.ignoreRotation = value == "ignore"
		C_Minimap.SetIgnoreRotateMinimap(self.ignoreRotation)
	elseif command == "buttons" then
		self:Buttons()
		self:Report()
	else
		AUI:Print(HELP)
	end
end
