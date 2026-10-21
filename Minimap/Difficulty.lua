local AUI = select(2, ...)

local L = AUI.L
local Schema = AUI.Schema
local Elements = AUI.MinimapElements

-- Difficulties GetDifficultyInfo cannot describe in a few letters, with the label each gets in the Other color.
local SPECIAL = {
	[24] = "TW", -- Timewalking dungeon
	[33] = "TW", -- Timewalking raid
	[205] = "Follower",
	[208] = "Delves",
	[220] = "Story",
}
-- Each tier's default color, in display order.
local TIERS = {
	{ key = "normal", color = { r = 0.118, g = 1, b = 0 } },
	{ key = "heroic", color = { r = 0, g = 0.439, b = 0.867 } },
	{ key = "mythic", color = { r = 0.639, g = 0.208, b = 0.933 } },
	{ key = "lfr", color = { r = 1, g = 0.502, b = 0 } },
	{ key = "other", color = { r = 1, g = 0.82, b = 0 } },
}
local EVENTS = {
	"PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_DIFFICULTY_CHANGED", "UPDATE_INSTANCE_INFO",
	"GROUP_ROSTER_UPDATE", "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET",
}
-- The preview's sample: a heroic raid of 25.
local SAMPLE = {
	difficultyID = 15,
	groupSize = 25,
	info = { instanceType = "raid", isHeroic = true, isChallengeMode = false, displayHeroic = true,
		displayMythic = false, isLFR = false, maxPlayers = 30 },
}

Elements:DeclareText("difficulty")

for _, tier in ipairs(TIERS) do
	Schema:Color("minimap.difficulty.colors." .. tier.key, tier.color)
end

---@alias AUIDifficultyTier "normal" | "heroic" | "mythic" | "lfr" | "other"

---What GetDifficultyInfo returns, by name.
---@class AUIDifficultyInfo
---@field instanceType string
---@field isHeroic boolean
---@field isChallengeMode boolean
---@field displayHeroic boolean
---@field displayMythic boolean
---@field isLFR boolean
---@field maxPlayers number?

---The instance's difficulty as short colored text beside the zone, for example "25H", "M", "M+12" or "LFR", shown
---only inside an instance. Its tooltip is Blizzard's difficulty tooltip.
---@class AUIMinimapDifficulty: AUIMinimapElement
---@field text FontString?
---@field value string? the label shown
---@field sample boolean? the label is the preview's sample
---@field tier AUIDifficultyTier? the tier whose color the label has
---@field TIERS table[] each tier's key and default color, in display order
local Difficulty = {
	key = "difficulty",
	kind = "text",
	TIERS = TIERS,
}

---Builds the label for a difficulty. Free of frame code.
---@param difficultyID number
---@param info AUIDifficultyInfo?
---@param groupSize number? the instance's group size, which sizes flexible raids
---@param keystone number? the active keystone's level, 0 without one
---@return string? text nil when there is nothing to label
---@return AUIDifficultyTier tier
function Difficulty:Label(difficultyID, info, groupSize, keystone)
	local special = SPECIAL[difficultyID]

	if special then
		return L[special], "other"
	end

	if not info then
		return nil, "other"
	end

	local instanceType = info.instanceType

	if instanceType == "pvp" or instanceType == "arena" then
		return L["PvP"], "other"
	end

	if info.isChallengeMode then
		return L["M+"] .. ((keystone or 0) > 0 and tostring(keystone) or ""), "mythic"
	end

	if info.isLFR then
		return L["LFR"], "lfr"
	end

	if info.displayMythic then
		return L["M"], "mythic"
	end

	local tier, letter = "normal", L["N"]

	if info.isHeroic or info.displayHeroic then
		tier, letter = "heroic", L["H"]
	end

	local size

	if instanceType == "raid" then
		size = (groupSize or 0) > 0 and groupSize or info.maxPlayers
	elseif instanceType == "party" then
		size = info.maxPlayers
	end

	return ((size or 0) > 0 and tostring(size) or "") .. letter, tier
end

---@param difficultyID number
---@return AUIDifficultyInfo? info
local function Info(difficultyID)
	local name, instanceType, isHeroic, isChallengeMode, displayHeroic, displayMythic, _, isLFR, _, maxPlayers =
		GetDifficultyInfo(difficultyID)

	if not name then
		return nil
	end

	return {
		instanceType = instanceType,
		isHeroic = isHeroic,
		isChallengeMode = isChallengeMode,
		displayHeroic = displayHeroic,
		displayMythic = displayMythic,
		isLFR = isLFR,
		maxPlayers = maxPlayers,
	}
end

---@param parent Frame
function Difficulty:Build(parent)
	local frame = CreateFrame("Frame", nil, parent)
	local text = frame:CreateFontString(nil, "OVERLAY")

	text:SetFontObject(GameFontNormalSmall)
	text:SetPoint("LEFT")
	text:SetPoint("RIGHT")
	text:SetJustifyH("LEFT")
	text:SetWordWrap(false)
	frame:EnableMouse(true)
	frame:SetScript("OnEnter", function(owner)
		Difficulty:ShowTooltip(owner)
	end)
	frame:SetScript("OnLeave", function()
		GameTooltip_Hide()
	end)
	frame:Hide()

	self.frame, self.text = frame, text
end

---Applies the label's font, size, outline and Y Offset, and its tier's color.
function Difficulty:Style()
	local text = self.text --[[@as FontString]]
	local y = Elements:StyleText(self.key, text)

	text:ClearAllPoints()
	text:SetPoint("LEFT", 0, y)
	text:SetPoint("RIGHT", 0, y)

	if self.active then
		self.tier = nil
		self:Update()
	end
end

---@return boolean
function Difficulty:IsShown()
	return self.active == true and self.value ~= nil
end

---@return number
function Difficulty:Width()
	return math.ceil((self.text --[[@as FontString]]):GetUnboundedStringWidth())
end

---@param active boolean
function Difficulty:SetActive(active)
	for _, event in ipairs(EVENTS) do
		if active then
			AUI.Events:Register(event, self, function()
				AUI.Events:Coalesce("minimapDifficulty", function()
					Difficulty:Update()
				end)
			end)
		else
			AUI.Events:Unregister(event, self)
		end
	end

	if active then
		self:Update()
	end
end

function Difficulty:Update()
	local inInstance, instanceType = IsInInstance()
	local label, tier

	if self.active and inInstance and instanceType ~= "interior" and instanceType ~= "neighborhood" then
		local _, _, difficultyID, _, _, _, _, _, groupSize = GetInstanceInfo()
		local keystone = C_ChallengeMode.GetActiveKeystoneInfo()

		label, tier = self:Label(difficultyID or 0, Info(difficultyID or 0), groupSize, keystone)
	end

	if label == "" then
		label = nil
	end

	self.sample = label == nil and Elements.preview

	if self.sample then
		label, tier = self:Label(SAMPLE.difficultyID, SAMPLE.info, SAMPLE.groupSize, 0)
	end

	if label and tier ~= self.tier then
		local color = AUI.Profile:Get("minimap.difficulty.colors." .. tier)

		self.tier = tier
		;(self.text --[[@as FontString]]):SetTextColor(color.r or 1, color.g or 1, color.b or 1)
	end

	if label ~= self.value then
		self.value = label
		;(self.text --[[@as FontString]]):SetText(label)
		Elements:Changed()
	end
end

---Blizzard's difficulty tooltip (Blizzard_FrameXML/InstanceDifficulty.lua): the difficulty's name, Raid Finder for
---a Raid Finder group, and the group's size against the instance's.
---@param owner Frame
function Difficulty:ShowTooltip(owner)
	-- The eleventh return, whether the instance has a world tier, is read by both clients' FrameXML but missing from
	-- the annotations.
	local _, _, difficultyID, _, maxPlayers, _, _, _, groupSize, lfgID = GetInstanceInfo()
	local hasWorldTier = select(11, GetInstanceInfo())

	if self.sample then
		difficultyID, maxPlayers, groupSize, lfgID, hasWorldTier = SAMPLE.difficultyID, SAMPLE.info.maxPlayers,
			SAMPLE.groupSize, nil, false
	end
	local isLFR = select(8, GetDifficultyInfo(difficultyID))
	local name = hasWorldTier and DifficultyUtil.GetWorldTierDifficultyName() or
		DifficultyUtil.GetDifficultyName(difficultyID)

	if not name then
		return
	end

	GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
	GameTooltip_SetTitle(GameTooltip, DUNGEON_DIFFICULTY_BANNER_TOOLTIP:format(name))

	if isLFR and lfgID then
		GameTooltip_SetTitle(GameTooltip, RAID_FINDER)
	end

	if (maxPlayers or 0) > 0 then
		GameTooltip_AddNormalLine(GameTooltip, DUNGEON_DIFFICULTY_BANNER_TOOLTIP_PLAYER_COUNT:format(groupSize,
			maxPlayers))
	end

	GameTooltip:Show()
end

Elements:Register(Difficulty, "TOP1", 2)
