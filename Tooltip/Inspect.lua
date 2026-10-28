local AUI = select(2, ...)

local Options, Format = AUI.TooltipOptions, AUI.TooltipFormat

-- Pacing, in seconds: the rest on one player before asking, the gap after anyone's request, how long an answer may
-- take, the wait before trying an out-of-reach player again, how long the player's own inspect holds requests back,
-- how long another addon's request keeps group members waiting for its answer, and how long an answer is kept.
local DWELL, GAP, WAIT_FOR, RETRY, USER_WAIT, FOREIGN_WAIT, KEEP = 0.9, 2, 4, 5, 8, 10, 300
local MAX_KEPT = 300
-- Gear still loading is averaged again this long after the last item arrives.
local LOAD_SETTLE = 0.2
local WAITING = "..."
local ROLE_ATLASES = { TANK = "roleicon-tiny-tank", HEALER = "roleicon-tiny-healer", DAMAGER = "roleicon-tiny-dps" }
local ICON_SIZE = 14
local INSPECT_DISTANCE = 1

---@param value any
---@return number? number a readable positive number, or nil
local function Positive(value)
	value = AUI:Readable(value)

	return type(value) == "number" and value > 0 and value or nil
end

---@param guid string
---@return string? unit a token for the player with that GUID: any the client gives, else "mouseover" when it is them
local function Token(guid)
	local unit = AUI:Readable(UnitTokenFromGUID(guid))

	if type(unit) == "string" then
		return unit
	end

	return AUI:Readable(UnitGUID("mouseover")) == guid and "mouseover" or nil
end

---@class AUIInspectEntry
---@field itemLevel number?
---@field specID number?
---@field at number when it was read
---@field links table<integer, string>? the gear whose item levels are still loading, by slot

---@class AUIInspectRequest
---@field guid string
---@field unit string
---@field at number

---Item level and specialization of other players on `GameTooltip`. A player's lines are added at once, with "..."
---while the answer is unknown, and filled in place when it arrives. Answers come from one inspect at a time, asked
---for only after the cursor rests on the player and paced against every inspect request the client sees, from any
---addon or the player's own; every addon's answers are kept, so a player another addon has inspected needs no request
---of its own. Where the client gives no item level, it is averaged from the inspected gear. Specializations are also
---taken from LibSpecialization, which shares them between players whose addons embed it.
---@class AUITooltipInspect
---@field hooked boolean
---@field kept table<string, AUIInspectEntry> answers, by GUID
---@field count integer
---@field shared table<string, number> specializations LibSpecialization shared, by player name
---@field pending AUIInspectRequest? the request in flight
---@field wanted AUIInspectRequest? the player the tooltip is waiting for
---@field armed boolean a timer will try the wanted player
---@field asking boolean AeonUI's own request is being sent
---@field lastAny number when any inspect was last requested
---@field lastForeign number when an inspect not AeonUI's was last requested
---@field userAt number when the player last opened an inspect
---@field shown { guid: string?, itemLevel: integer?, spec: integer? } the player on `GameTooltip` and their lines
---@field slots integer[] the equipment slots an average counts
---@field loading boolean
---@field guildAsked boolean
local Inspect = {
	hooked = false,
	kept = {},
	count = 0,
	shared = {},
	armed = false,
	asking = false,
	lastAny = -GAP,
	lastForeign = -FOREIGN_WAIT,
	userAt = -USER_WAIT,
	shown = {},
	slots = {},
	loading = false,
	guildAsked = false,
}
AUI.TooltipInspect = Inspect

---@param guid string
---@return AUIInspectEntry entry
function Inspect:Entry(guid)
	local entry = self.kept[guid]

	if entry then
		return entry
	end

	if self.count >= MAX_KEPT then
		local oldest, oldestAt

		for key, old in pairs(self.kept) do
			if not oldestAt or old.at < oldestAt then
				oldest, oldestAt = key, old.at
			end
		end

		self.kept[oldest] = nil
		self.count = self.count - 1
	end

	entry = { at = GetTime() }
	self.kept[guid] = entry
	self.count = self.count + 1

	return entry
end

---@param guid string
---@return AUIInspectEntry? entry an answer younger than the time answers are kept
function Inspect:Fresh(guid)
	local entry = self.kept[guid]

	if entry and GetTime() - entry.at < KEEP then
		return entry
	end

	return nil
end

---@return boolean inspecting the player's own inspect window or talent inspection is open, or was just asked for
function Inspect:UserInspecting()
	local talents = PlayerSpellsFrame

	if talents and talents.IsInspecting and talents:IsInspecting() then
		return true
	end

	local frame = InspectFrame

	return frame ~= nil and (frame:IsShown() or GetTime() - self.userAt < USER_WAIT)
end

-- An item's info arriving while some answer's gear is still loading: averaged again once a burst settles.
local function ItemsSettled()
	Inspect:ItemsLoaded()
end

local function ItemInfoReceived()
	AUI.Events:Merge("tooltipInspectItems", LOAD_SETTLE, ItemsSettled)
end

---Averages an entry's gear; gear still loading keeps its links and is averaged again once it arrives.
---@param entry AUIInspectEntry
---@return boolean complete
function Inspect:Average(entry)
	local links = entry.links or {}
	local levels, complete = {}, true

	for slot, link in pairs(links) do
		local level = Positive(C_Item.GetDetailedItemLevelInfo(link))

		if level then
			levels[slot] = level
		else
			complete = false
		end
	end

	local mainHand = links[INVSLOT_MAINHAND]
	local mainHandType = mainHand and select(9, C_Item.GetItemInfo(mainHand))

	entry.itemLevel = Format:GearAverage(self.slots, levels, AUI:Readable(mainHandType))

	if complete then
		entry.links = nil
	elseif not self.loading then
		self.loading = true
		AUI.Events:Register("GET_ITEM_INFO_RECEIVED", self, ItemInfoReceived)
	end

	return complete
end

---Averages again every entry whose gear was loading, and stops listening once none is.
function Inspect:ItemsLoaded()
	local waiting, now = false, GetTime()

	for guid, entry in pairs(self.kept) do
		if entry.links then
			local complete = self:Average(entry)

			-- Gear that has not loaded within the answer's lifetime is given up on, keeping the average so far.
			if not complete and now - entry.at < KEEP then
				waiting = true
			elseif not complete then
				entry.links = nil
			end

			self:Changed(guid)
		end
	end

	if not waiting and self.loading then
		self.loading = false
		AUI.Events:Unregister("GET_ITEM_INFO_RECEIVED", self)
	end
end

---Reads an inspected player's answer.
---@param unit string
---@param guid string
function Inspect:Read(unit, guid)
	local entry = self:Entry(guid)
	local itemLevel = Positive(C_PaperDollInfo.GetInspectItemLevel(unit))

	entry.at = GetTime()
	entry.specID = Positive(C_SpecializationInfo.GetInspectSpecialization(unit)) or entry.specID

	if itemLevel then
		entry.itemLevel, entry.links = itemLevel, nil
	else
		entry.links = {}

		for _, slot in ipairs(self.slots) do
			local link = AUI:Readable(GetInventoryItemLink(unit, slot))

			if type(link) == "string" then
				entry.links[slot] = link
			end
		end

		self:Average(entry)
	end

	self:Changed(guid)
end

---Keeps every inspect's answer, whoever asked for it.
---@param guid any
function Inspect:OnInspectReady(guid)
	guid = AUI:Readable(guid)

	if type(guid) ~= "string" then
		return
	end

	local pending = self.pending
	local ours = pending ~= nil and pending.guid == guid
	local unit

	if pending and ours then
		unit, self.pending = pending.unit, nil
	else
		unit = Token(guid)
	end

	if type(unit) == "string" and AUI:Readable(UnitGUID(unit)) == guid then
		self:Read(unit, guid)
	end

	if ours and not self:UserInspecting() then
		ClearInspectPlayer()
	end
end

---@param guid string
---@return boolean showing `GameTooltip` shows that player's lines
function Inspect:Showing(guid)
	return self.shown.guid == guid and GameTooltip:IsShown() and not GameTooltip:IsForbidden()
end

---@param delay number seconds
function Inspect:Arm(delay)
	if self.armed then
		return
	end

	self.armed = true
	C_Timer.After(delay, function()
		Inspect.armed = false
		Inspect:Try()
	end)
end

---@param guid string
---@param unit string
function Inspect:Want(guid, unit)
	local wanted = self.wanted

	if wanted and wanted.guid == guid then
		wanted.unit = unit

		return
	end

	self.wanted = { guid = guid, unit = unit, at = GetTime() }
	self:Arm(DWELL)
end

---Asks for the wanted player once every hold-off has passed: the rest on the player, the gap after any request, the
---request in flight, another addon's polling of the group, and the player's own inspect.
function Inspect:Try()
	local wanted = self.wanted

	if not wanted then
		return
	end

	if not self:Showing(wanted.guid) or self:Fresh(wanted.guid) or InCombatLockdown()
		or not AUI.Tooltip:IsEnabled() then
		self.wanted = nil

		return
	end

	local unit, now = wanted.unit, GetTime()
	local ready = math.max(wanted.at + DWELL, self.lastAny + GAP)

	if self.pending then
		ready = math.max(ready, self.pending.at + WAIT_FOR)
	end

	if AUI:Readable(UnitInParty(unit)) == true or AUI:Readable(UnitInRaid(unit)) ~= nil then
		ready = math.max(ready, self.lastForeign + FOREIGN_WAIT)
	end

	if self:UserInspecting() then
		ready = math.max(ready, now + GAP)
	end

	if ready > now then
		self:Arm(ready - now)

		return
	end

	if AUI:Readable(UnitGUID(unit)) ~= wanted.guid then
		self.wanted = nil

		return
	end

	if AUI:Readable(CanInspect(unit)) ~= true or AUI:Readable(CheckInteractDistance(unit, INSPECT_DISTANCE)) ~= true then
		self:Arm(RETRY)

		return
	end

	self.pending = { guid = wanted.guid, unit = unit, at = now }
	self.asking = true
	NotifyInspect(unit)
	self.asking = false
	self:Arm(WAIT_FOR)
end

---@param itemLevel number?
---@return string text
---@return AUITooltipColor color
function Inspect:ItemLevelText(itemLevel)
	if not itemLevel then
		return WAITING, HIGHLIGHT_FONT_COLOR
	end

	local season = AUI.can.upgrades and AUI.TooltipUpgrades.season or nil

	return tostring(math.floor(itemLevel + 0.5)), Format:Grade(season, itemLevel) or HIGHLIGHT_FONT_COLOR
end

---@param specID number?
---@return string text the role's icon and the specialization's name
function Inspect:SpecText(specID)
	local _, name, _, _, role = GetSpecializationInfoByID(specID or 0)

	name, role = AUI:Readable(name), AUI:Readable(role)

	if type(name) ~= "string" or name == "" then
		return WAITING
	end

	local atlas = ROLE_ATLASES[role or ""]

	return (atlas and CreateAtlasMarkup(atlas, ICON_SIZE, ICON_SIZE) .. " " or "") .. name
end

---@param unit string
---@return number? specID what LibSpecialization shared for that player
function Inspect:SharedSpec(unit)
	local name, realm = UnitName(unit)

	name, realm = AUI:Readable(name), AUI:Readable(realm)

	if type(name) ~= "string" then
		return nil
	end

	return self.shared[type(realm) == "string" and realm ~= "" and (name .. "-" .. realm) or name]
end

---@return number? specID the player's own
local function OwnSpec()
	local index = C_SpecializationInfo.GetSpecialization()

	return index and Positive((C_SpecializationInfo.GetSpecializationInfo(index))) or nil
end

---@param guid string
---@return number? itemLevel
---@return number? specID
function Inspect:Known(guid)
	local entry = self:Fresh(guid)

	return entry and entry.itemLevel, entry and entry.specID
end

---Adds a player's Item Level and Specialization lines, asking for an inspect when they are unknown. Out of combat
---only an unknown line waits with "..."; in combat it is left out, since no request can be made.
---@param tooltip GameTooltip
---@param guid string
---@param unit string
function Inspect:AddLines(tooltip, guid, unit)
	local shown = self.shown
	local levels = Options:Get(Options.ITEM_LEVEL_PATH) == true
	local specs = AUI.can.specializations and Options:Get(Options.SPECIALIZATION_PATH) == true

	shown.guid, shown.itemLevel, shown.spec = guid, nil, nil

	if not levels and not specs then
		return
	end

	local itemLevel, specID

	if AUI:Readable(UnitIsUnit(unit, "player")) == true then
		local _, equipped = GetAverageItemLevel()

		itemLevel, specID = Positive(equipped), OwnSpec()
	else
		itemLevel, specID = self:Known(guid)
		specID = self:SharedSpec(unit) or specID

		if (levels and not itemLevel) or (specs and not specID) then
			-- An answered player's unknown value, or one no request can be made for in combat, has no line.
			if self:Fresh(guid) or InCombatLockdown() then
				levels, specs = levels and itemLevel ~= nil, specs and specID ~= nil
			else
				self:Want(guid, unit)
			end
		end
	end

	local gold = NORMAL_FONT_COLOR

	if levels then
		local text, color = self:ItemLevelText(itemLevel)

		tooltip:AddDoubleLine(STAT_AVERAGE_ITEM_LEVEL, text, gold.r, gold.g, gold.b, color.r, color.g, color.b)
		shown.itemLevel = tooltip:NumLines()
	end

	if specs then
		local white = HIGHLIGHT_FONT_COLOR

		tooltip:AddDoubleLine(SPECIALIZATION, self:SpecText(specID), gold.r, gold.g, gold.b, white.r, white.g, white.b)
		shown.spec = tooltip:NumLines()
	end
end

---Fills the shown player's lines in place when their answer changes.
---@param guid string
function Inspect:Changed(guid)
	if not self:Showing(guid) then
		return
	end

	local shown, tooltip = self.shown, GameTooltip
	local itemLevel, specID = self:Known(guid)
	local wanted = self.wanted
	local unit = wanted and wanted.guid == guid and wanted.unit or Token(guid)

	specID = (type(unit) == "string" and self:SharedSpec(unit)) or specID

	local right = shown.itemLevel and _G["GameTooltipTextRight" .. shown.itemLevel] --[[@as FontString?]]

	if right then
		local text, color = self:ItemLevelText(itemLevel)

		right:SetText(text)
		right:SetTextColor(color.r, color.g, color.b)
	end

	right = shown.spec and _G["GameTooltipTextRight" .. shown.spec] --[[@as FontString?]]

	if right then
		right:SetText(self:SpecText(specID))
	end

	-- Resizes the tooltip to its new text; a show from addon code can be refused while it is restricted.
	pcall(tooltip.Show, tooltip)
end

---@param specID any
---@param name any the sender, as `Ambiguate(sender, "none")` gives it
local function OnShared(specID, _, _, name)
	if type(specID) == "number" and type(name) == "string" then
		Inspect.shared[name] = specID
	end
end

---Installs the inspect hooks, events and LibSpecialization's callbacks once; they do nothing while the module is off.
function Inspect:Hook()
	if self.hooked or not GameTooltip then
		return
	end

	self.hooked = true

	for slot = INVSLOT_HEAD, INVSLOT_OFFHAND do
		if slot ~= INVSLOT_BODY then
			self.slots[#self.slots + 1] = slot
		end
	end

	if AUI.can.rangedSlot then
		self.slots[#self.slots + 1] = INVSLOT_RANGED
	end

	hooksecurefunc("NotifyInspect", function()
		local now = GetTime()

		Inspect.lastAny = now

		if not Inspect.asking then
			Inspect.lastForeign = now
		end
	end)

	if InspectUnit then
		hooksecurefunc("InspectUnit", function()
			Inspect.userAt = GetTime()
			Inspect.pending = nil
		end)
	end

	AUI.Events:Register("INSPECT_READY", self, function(_, _, guid)
		Inspect:OnInspectReady(guid)
	end)
	GameTooltip:HookScript("OnTooltipCleared", function()
		Inspect.shown.guid = nil
	end)
	GameTooltip:HookScript("OnHide", function()
		Inspect.shown.guid, Inspect.wanted = nil, nil
	end)

	local LibSpecialization = AUI.can.specializations and LibStub("LibSpecialization", true)

	if not LibSpecialization then
		return
	end

	LibSpecialization.RegisterGroup(self, OnShared)
	LibSpecialization.RegisterGuild(self, OnShared)
	-- Guild members share only when asked; one request per session is enough for the tooltip.
	AUI.Events:Register("PLAYER_ENTERING_WORLD", self, function()
		if not Inspect.guildAsked and IsInGuild() then
			Inspect.guildAsked = true
			LibSpecialization.RequestGuildSpecialization()
		end
	end)
end
