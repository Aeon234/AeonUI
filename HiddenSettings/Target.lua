local AUI = select(2, ...)

local Options = AUI.HiddenSettingsOptions

local SOFT = "softinteract"
local CURSOR_PATH = "Interface\\Cursor\\"
-- Cursor files whose names `Options.CursorType` reads, each also in its Unable variant.
local CURSORS = { "Mine", "GatherHerbs", "Quest", "QuestRepeatable", "QuestTurnIn", "Interact", "PickLock", "LootAll",
	"Pickup" }
local QUEST_LINE = 8 -- Enum.TooltipDataLineType.QuestObjective

---Calls `fn`, returning nothing when it is missing or errors, and nil for each secret result.
---@param fn function?
---@return any first
---@return any second
local function Read(fn, ...)
	if not fn then
		return nil, nil
	end

	local ok, first, second = pcall(fn, ...)

	if not ok then
		return nil, nil
	end

	return AUI:Readable(first), AUI:Readable(second)
end

---The interaction soft target (`softinteract`) and what it is: its nameplate, its type from its cursor, the quest log
---or its loot, and whether it is within reach. Every read is guarded, and an unreadable answer counts as unknown.
---@class AUISparkleTarget
---@field plates table<string, true> the nameplate units shown
---@field probe Texture? hidden, receives the target's cursor
---@field cursors table<number, { [1]: string?, [2]: boolean }>? cursor file IDs, built on first use
---@field objectives string[] the unfinished objectives, normalized
---@field questsDirty boolean the objectives are rebuilt before the next match
local Target = {
	plates = {},
	objectives = {},
	questsDirty = true,
}
AUI.SparkleTarget = Target

---@param unit string
function Target:AddPlate(unit)
	self.plates[unit] = true
end

---@param unit string
function Target:RemovePlate(unit)
	self.plates[unit] = nil
end

---@param unit string
---@return Frame? plate
function Target.Plate(unit)
	return Read(C_NamePlate.GetNamePlateForUnit, unit)
end

---@return string? unit the soft target's token; nil while there is none, or none the client will say
---@return Frame? plate its nameplate, once the game shows it
function Target:Resolve()
	if Read(UnitExists, SOFT) ~= true and Read(UnitIsGameObject, SOFT) ~= true then
		return nil
	end

	local plate = self.Plate(SOFT)

	if plate then
		return SOFT, plate
	end

	for unit in pairs(self.plates) do
		if Read(UnitIsUnit, unit, SOFT) == true then
			plate = self.Plate(unit)

			if plate then
				return SOFT, plate
			end
		end
	end

	return SOFT, nil
end

function Target:MarkQuestsDirty()
	self.questsDirty = true
end

---@return string[] objectives the unfinished objectives, normalized, rebuilt after a quest log change
function Target:Objectives()
	if not self.questsDirty then
		return self.objectives
	end

	self.questsDirty = false
	self.objectives = {}

	for index = 1, Read(C_QuestLog.GetNumQuestLogEntries) or 0 do
		local questID = Read(C_QuestLog.GetQuestIDForLogIndex, index)
		local objectives = type(questID) == "number" and Read(C_QuestLog.GetQuestObjectives, questID)

		for _, objective in ipairs(type(objectives) == "table" and objectives or {}) do
			local text = AUI:Readable(objective.text)

			if not objective.finished and type(text) == "string" then
				text = Options.NormalizeObjective(text)

				if #text >= 4 then
					self.objectives[#self.objectives + 1] = text
				end
			end
		end
	end

	return self.objectives
end

---@param unit string
---@return boolean
function Target:IsQuest(unit)
	if Read(C_QuestLog.UnitIsRelatedToActiveQuest, unit) == true then
		return true
	end

	local data = C_TooltipInfo and Read(C_TooltipInfo.GetUnit, unit)

	if type(data) == "table" and type(data.lines) == "table" then
		for _, line in ipairs(data.lines) do
			if AUI:Readable(line.type) == QUEST_LINE then
				return true
			end
		end
	end

	return Options.MatchesObjective(Read(UnitName, unit), self:Objectives())
end

---@return table<number, { [1]: string?, [2]: boolean }> cursors each cursor file's type and Unable flag, by file ID
function Target:Cursors()
	if self.cursors then
		return self.cursors
	end

	self.cursors = {}

	for _, name in ipairs(CURSORS) do
		for _, variant in ipairs({ name, "Unable" .. name }) do
			local fileID = Read(GetFileIDFromPath, CURSOR_PATH .. variant)

			if type(fileID) == "number" then
				self.cursors[fileID] = { Options.CursorType(variant) }
			end
		end
	end

	return self.cursors
end

---@param unit string
---@return string? type the cursor's type
---@return boolean unable
function Target:Cursor(unit)
	if not self.probe then
		self.probe = UIParent:CreateTexture()
		self.probe:Hide()
	end

	if Read(SetUnitCursorTexture, self.probe, unit, nil, true) ~= true then
		return nil, false
	end

	local file, atlas = AUI:Readable(self.probe:GetTexture()), AUI:Readable(self.probe:GetAtlas())
	local known = type(file) == "number" and self:Cursors()[file]

	if known then
		return known[1], known[2]
	end

	local kind, unable = Options.CursorType(type(file) == "string" and file or nil)

	if kind then
		return kind, unable
	end

	local fromAtlas, atlasUnable = Options.CursorType(atlas)

	return fromAtlas, unable or atlasUnable
end

---@param unit string
---@param quests boolean look the object up in the quest log, which is costlier than its cursor
---@return string? type `ore`, `herbs`, `questObjects`, `corpses` or `other`; nil for anything that never sparkles
---@return boolean unable the game refuses it now, as for a vein above the player's skill
function Target:Classify(unit, quests)
	if Read(UnitIsGameObject, unit) == true then
		local kind, unable = self:Cursor(unit)

		if quests and kind ~= "ore" and kind ~= "herbs" and self:IsQuest(unit) then
			kind = "questObjects"
		end

		return kind, unable
	end

	if Read(UnitIsDead, unit) == true then
		local guid = Read(UnitGUID, unit)
		local hasLoot, canLoot = Read(CanLootUnit, guid)

		if type(guid) == "string" and hasLoot == true and canLoot ~= false then
			return "corpses", false
		end
	end

	return nil, false
end

---@param unit string
---@return boolean? inRange nil when the client does not say
function Target.InRange(unit)
	return Read(UnitIsInInteractRange, unit)
end
