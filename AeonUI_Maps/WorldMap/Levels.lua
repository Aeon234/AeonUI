local AUI = select(2, ...)

local Options = AUI.WorldMapOptions

-- Fishing's skill line.
local FISHING_SKILL = 356

---Zone and fishing levels on Blizzard's area label: when the label names a zone hovered on the map, its level range
---follows the name as Blizzard writes its own (where the client gives none), and the Fishing skill its waters ask for
---goes below. It rides the label's own per-frame evaluation, hooked once, and writes only when Blizzard has written
---new text.
---@class AUIWorldMapLevels
---@field zone boolean zone levels are on
---@field fishing boolean fishing levels are on
---@field label table? Blizzard's area label, once hooked
---@field data { zone: table<number, number[]>, fishing: table<number, number[]> }? the ranges, loaded on first use
---@field name string? the label's name as last seen or written
---@field description string? its description as last seen or written
local Levels = {
	zone = false,
	fishing = false,
}
AUI.WorldMapLevels = Levels

---@return number? skill the player's Fishing skill with its modifiers, nil without Fishing
local function FishingSkill()
	local info = C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID and C_SkillInfo.GetSkillLineInfoByID(FISHING_SKILL)

	return info and info.rank + info.modifier or nil
end

---@param label table
---@return number? mapID the zone the label names: the map's child under the cursor, nil when the label shows anything
---else
local function HoveredZone(label)
	local types = MAP_AREA_LABEL_TYPE
	local info = label:GetHighestPriorityLabelInfo()

	if not types or not info or info ~= label.labelInfoByType[types.AREA_NAME] then
		return nil
	end

	local map = label.dataProvider and label.dataProvider:GetMap()
	local mapID = map and map:IsCanvasMouseFocus() and map:GetMapID()

	if not mapID then
		return nil
	end

	local x, y = map:GetNormalizedCursorPosition()
	local hovered = C_Map.GetMapInfoAtPosition(mapID, x, y)

	return hovered and hovered.mapID ~= mapID and hovered.mapID or nil
end

---Adds the hovered zone's ranges to the label's text after Blizzard writes it.
---@param label table
function Levels:Amend(label)
	if not (self.zone or self.fishing) then
		return
	end

	local name, description = label.Name:GetText(), label.Description:GetText()

	if name == self.name and description == self.description then
		return
	end

	self.name, self.description = name, description

	local mapID = name and name ~= "" and HoveredZone(label)

	if not mapID then
		return
	end

	self.data = self.data or AUI.WorldMapLevelData()

	local levels = self.zone and self.data.zone[mapID]
	local own = C_Map.GetMapLevels(mapID)

	if levels and not (own and own > 0) then
		local color = RGBTableToColorCode(AUI.WorldMap:LevelColor(levels))

		name = name .. color .. " " .. Options:RangeText(levels) .. FONT_COLOR_CODE_CLOSE
		label.Name:SetText(name)
	end

	local fishing = self.fishing and self.data.fishing[mapID]

	if fishing then
		local color = RGBTableToColorCode(QuestDifficultyColors[Options:FishingDifficulty(FishingSkill(), fishing)])
		local line = PROFESSIONS_FISHING .. " " .. color .. Options:RangeText(fishing) .. FONT_COLOR_CODE_CLOSE

		description = (description and description ~= "") and (description .. "\n" .. line) or line
		label.Description:SetText(description)
	end

	self.name, self.description = name, description
end

---@return boolean hooked Blizzard's area label is found and hooked
function Levels:Hook()
	if self.label then
		return true
	end

	for provider in pairs(WorldMapFrame.dataProviders or {}) do
		local label = provider.Label

		if label and label.EvaluateLabels and label.Name and label.Description then
			self.label = label
			hooksecurefunc(label, "EvaluateLabels", function(frame)
				Levels:Amend(frame)
			end)

			return true
		end
	end

	return false
end

---Reads the zone and fishing options, hooking the label the first time either is on.
function Levels:Apply()
	local Profile = AUI.Profile

	self.zone = Profile:Get(Options.ZONE_LEVELS_PATH) == true
	self.fishing = Profile:Get(Options.FISHING_LEVELS_PATH) == true

	if self.zone or self.fishing then
		self:Hook()
	end
end
