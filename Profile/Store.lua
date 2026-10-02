local AUI = select(2, ...)

local Schema = AUI.Schema

---@class AUIProfileRecord
---@field name string
---@field schemaVersion integer
---@field config table

---@class AUICharacterRecord
---@field activeProfileID string
---@field specAssignments table<integer, string> specialization ID to profile ID

---The account SavedVariables root, `AeonUIDB`.
---@class AUIStoreRoot
---@field schemaVersion integer
---@field profilesByID table<string, AUIProfileRecord>
---@field charactersByID table<string, AUICharacterRecord>
---@field editorPreferences table
---@field nextID integer
---@field migrationBackup table?

---What `Store:Inspect` found in a root.
---@class AUIStoreReport
---@field problem string? why the envelope cannot be used; nil when it can
---@field newer boolean? the root comes from a newer schema
---@field migrate boolean? the root comes from an older schema and can be offered to `Store:Migrate`
---@field quarantined table<string, string> profile ID to the reason that profile cannot be used

---The saved-data envelope: its structure, validation, profile IDs and names, and schema migrations. Pure functions
---over root tables; the Profile owner decides what to publish.
---@class AUIStore
---@field SCHEMA integer the envelope schema version
---@field DEFAULT_ID string
---@field DEFAULT_NAME string
---@field NAME_MAX_LETTERS integer
---@field MAX_PROFILES integer
---@field migrations table<integer, fun(root: table)> step from the keyed version to the next
local Store = {
	SCHEMA = 2,
	DEFAULT_ID = "p00000001",
	DEFAULT_NAME = "Default",
	NAME_MAX_LETTERS = 32,
	MAX_PROFILES = 128,
	migrations = {},
}
AUI.Store = Store

-- Schema 2: each profile config moves to profile schema version 2, where a frame follows the shared appearance.
Store.migrations[1] = function(root)
	for _, record in pairs(type(root.profilesByID) == "table" and root.profilesByID or {}) do
		if type(record) == "table" and record.schemaVersion == 1 and type(record.config) == "table" then
			Schema.upgrades[1](record.config)
			record.schemaVersion = 2
		end
	end
end

local ID_PATTERN = "^p%d%d%d%d%d%d%d%d$"
local ID_FORMAT = "p%08d"

---@param value any
---@return boolean
local function IsCount(value)
	return type(value) == "number" and value >= 1 and value == math.floor(value) and value < 2 ^ 31
end

---Case-insensitive name equality, through the client's UTF-8 comparison.
---@param a string
---@param b string
---@return boolean
function Store:SameName(a, b)
	return strcmputf8i(a, b) == 0
end

---@param characterID string
---@return AUIStoreRoot root a new store holding the Default profile and the character's record
function Store:NewRoot(characterID)
	return {
		schemaVersion = self.SCHEMA,
		profilesByID = {
			[self.DEFAULT_ID] = {
				name = self.DEFAULT_NAME,
				schemaVersion = Schema.VERSION,
				config = Schema:Defaults(),
			},
		},
		charactersByID = {
			[characterID] = { activeProfileID = self.DEFAULT_ID, specAssignments = {} },
		},
		editorPreferences = {},
		nextID = 2,
	}
end

---@param record any
---@return string? problem why a profile record cannot be used
local function ProfileProblem(record)
	if type(record) ~= "table" then
		return "the profile is not a table"
	end

	if type(record.name) ~= "string" or record.name == "" then
		return "the profile has no name"
	end

	if strlenutf8(record.name) > Store.NAME_MAX_LETTERS then
		return "the profile name is too long"
	end

	if record.schemaVersion ~= Schema.VERSION then
		if type(record.schemaVersion) == "number" and record.schemaVersion > Schema.VERSION then
			return "the profile comes from a newer version of AeonUI"
		end

		return "the profile has an unsupported schema version"
	end

	local ok, problem = Schema:ValidateConfig(record.config)

	if not ok then
		return problem
	end

	for key, value in pairs(record) do
		if key ~= "name" and key ~= "schemaVersion" and key ~= "config" and not Schema:IsPlain(value) then
			return "the profile holds something other than plain data"
		end
	end
end

---@param record any
---@return string? problem why a character record cannot be used
local function CharacterProblem(record)
	if type(record) ~= "table" or type(record.activeProfileID) ~= "string" then
		return "a character record has no active profile"
	end

	if type(record.specAssignments) ~= "table" then
		return "a character record has no specialization assignments"
	end

	for specID, profileID in pairs(record.specAssignments) do
		if not IsCount(specID) or type(profileID) ~= "string" then
			return "a character record has a malformed specialization assignment"
		end
	end
end

---Validates a root's envelope, then each profile on its own. A malformed envelope, an unsupported schema or a root
---with no profile is a problem for the whole store; a malformed profile is only quarantined. Of two profiles whose
---names match case-insensitively, the one with the later ID is quarantined.
---@param root any
---@return AUIStoreReport report
function Store:Inspect(root)
	local report = { quarantined = {} }

	if type(root) ~= "table" then
		report.problem = "the saved data is not a table"

		return report
	end

	local version = root.schemaVersion

	if not IsCount(version) then
		report.problem = "the saved data has no schema version"

		return report
	end

	if version > self.SCHEMA then
		report.problem = "the saved data comes from a newer version of AeonUI"
		report.newer = true

		return report
	end

	if version < self.SCHEMA then
		report.problem = ("the saved data uses schema %d, which needs migrating"):format(version)
		report.migrate = true

		return report
	end

	if type(root.profilesByID) ~= "table" or type(root.charactersByID) ~= "table" then
		report.problem = "the saved data is missing its profiles or characters"

		return report
	end

	if type(root.editorPreferences) ~= "table" or not Schema:IsPlain(root.editorPreferences) then
		report.problem = "the saved editor preferences are malformed"

		return report
	end

	if not IsCount(root.nextID) then
		report.problem = "the saved data has no valid next profile ID"

		return report
	end

	if root.migrationBackup ~= nil and type(root.migrationBackup) ~= "table" then
		report.problem = "the saved migration backup is malformed"

		return report
	end

	local ids = {}

	for id in pairs(root.profilesByID) do
		if type(id) ~= "string" or not id:match(ID_PATTERN) then
			report.problem = "the saved data holds a malformed profile ID"

			return report
		end

		ids[#ids + 1] = id
	end

	if #ids == 0 then
		report.problem = "the saved data holds no profiles"

		return report
	end

	for characterID, record in pairs(root.charactersByID) do
		---@type string?
		local problem = "a character key is malformed"

		if type(characterID) == "string" then
			problem = CharacterProblem(record)
		end

		if problem then
			report.problem = problem

			return report
		end
	end

	table.sort(ids)

	local kept = {}

	for _, id in ipairs(ids) do
		local record = root.profilesByID[id]
		local problem = ProfileProblem(record)

		if not problem then
			for _, other in ipairs(kept) do
				if self:SameName(record.name, root.profilesByID[other].name) then
					problem = ("the profile name repeats the name of profile %s"):format(other)

					break
				end
			end
		end

		if problem then
			report.quarantined[id] = problem
		else
			kept[#kept + 1] = id
		end
	end

	return report
end

---Brings an older root up to the current schema on a copy, one step at a time.
---@param root AUIStoreRoot
---@return AUIStoreRoot? migrated the migrated copy, with the original as its backup; nil on failure
---@return string? problem
function Store:Migrate(root)
	local version = root.schemaVersion

	if not IsCount(version) or version >= self.SCHEMA then
		return nil, "the saved data does not need migrating"
	end

	local candidate = AUI:CopyTable(root)

	candidate.migrationBackup = nil

	local backup = AUI:CopyTable(candidate)

	while candidate.schemaVersion < self.SCHEMA do
		local step = self.migrations[candidate.schemaVersion]

		if not step then
			return nil, ("there is no migration from schema %d"):format(candidate.schemaVersion)
		end

		local ok, problem = pcall(step, candidate)

		if not ok then
			return nil, ("the migration from schema %d failed: %s"):format(candidate.schemaVersion, tostring(problem))
		end

		candidate.schemaVersion = candidate.schemaVersion + 1
	end

	candidate.migrationBackup = backup

	return candidate
end

---@param root AUIStoreRoot
---@return string id a profile ID no record uses, past every ID allocated so far
function Store:AllocateID(root)
	local next = root.nextID

	for id in pairs(root.profilesByID) do
		local number = tonumber(id:sub(2))

		if number and number >= next then
			next = number + 1
		end
	end

	root.nextID = next + 1

	return ID_FORMAT:format(next)
end

---@param root AUIStoreRoot
---@param name any
---@param exceptID string? the profile being renamed, whose own name does not collide
---@return string? problem why the name cannot be used
function Store:CheckName(root, name, exceptID)
	local L = AUI.L

	if type(name) ~= "string" or not name:match("%S") then
		return L["A profile needs a name."]
	end

	if strlenutf8(name) > self.NAME_MAX_LETTERS then
		return L["A profile name can be %d letters at most."]:format(self.NAME_MAX_LETTERS)
	end

	if exceptID ~= self.DEFAULT_ID and self:SameName(name, self.DEFAULT_NAME) then
		return L["That name belongs to the default profile."]
	end

	for id, record in pairs(root.profilesByID) do
		if id ~= exceptID and type(record) == "table" and type(record.name) == "string" then
			if self:SameName(name, record.name) then
				return L["A profile with that name already exists."]
			end
		end
	end
end

---@param root AUIStoreRoot
---@return integer count
function Store:CountProfiles(root)
	local count = 0

	for _ in pairs(root.profilesByID) do
		count = count + 1
	end

	return count
end
