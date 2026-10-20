local AUI = select(2, ...)

local Schema = AUI.Schema
local Store = AUI.Store

-- Callback channel fired after a committed change: the changed path, or nil when the whole profile may differ.
local CHANNEL = "Profile"

---@alias AUIProfileMode
---| "normal" # the active profile is valid and editable
---| "fallback" # the active profile is quarantined or missing; a disposable copy is shown until another is chosen
---| "recovery" # the saved data cannot be used; factory defaults are shown and the saved data is left untouched

---@class AUIProfileInfo
---@field mode AUIProfileMode
---@field problem string? why the mode is not normal
---@field newer boolean? the saved data comes from a newer version
---@field activeID string? the character's saved active profile, even when it cannot be used

---@class AUIProfileEntry
---@field id string
---@field name string
---@field active boolean
---@field quarantined string? why the profile cannot be used

---Owns `AeonUIDB`: loads and validates it, chooses the active config, and is the only writer. Every structural
---change is prepared on a copy of the store, validated and published at once; a failure before publishing leaves
---the saved data as it was.
---@class AUIProfile
---@field root AUIStoreRoot? the published store; nil before initialization and in recovery
---@field original any? the saved data found at login
---@field characterID string the player's GUID, the key of this character's record
---@field mode AUIProfileMode
---@field problem string?
---@field newer boolean?
---@field quarantined table<string, string>
---@field activeID string?
---@field config table the config the addon reads: the active profile's own, or a disposable copy
local Profile = {
	characterID = "",
	mode = "recovery",
	quarantined = {},
	config = {},
}
AUI.Profile = Profile

---Publishes a root as the saved data.
---@param root any the store, or the original saved data when putting it back
function Profile:Save(root)
	AeonUIDB = root
end

---@param root AUIStoreRoot
---@param quarantined table<string, string>
---@return string id the profile a new character starts on: Default when usable, else the first usable one
local function StartingProfile(root, quarantined)
	if root.profilesByID[Store.DEFAULT_ID] and not quarantined[Store.DEFAULT_ID] then
		return Store.DEFAULT_ID
	end

	local ids = {}

	for id in pairs(root.profilesByID) do
		if not quarantined[id] then
			ids[#ids + 1] = id
		end
	end

	if #ids == 0 then
		for id in pairs(root.profilesByID) do
			ids[#ids + 1] = id
		end
	end

	table.sort(ids)

	return ids[1]
end

---@return table config a disposable copy of the valid Default profile, or factory defaults
function Profile:FallbackConfig()
	local default = self.root and self.root.profilesByID[Store.DEFAULT_ID]

	if default and not self.quarantined[Store.DEFAULT_ID] then
		return AUI:CopyTable(default.config)
	end

	return Schema:Defaults()
end

---Chooses the active config from a validated root.
---@param report AUIStoreReport
function Profile:Resolve(report)
	self.quarantined = report.quarantined
	self.newer = nil

	local root = self.root --[[@as AUIStoreRoot]]
	local record = root.charactersByID[self.characterID]
	local id = record and record.activeProfileID
	local profile = id and root.profilesByID[id]

	self.activeID = id

	if profile and not self.quarantined[id] then
		self.mode = "normal"
		self.problem = nil
		self.config = profile.config

		return
	end

	self.mode = "fallback"
	self.problem = id and self.quarantined[id] or "the active profile no longer exists"
	self.config = self:FallbackConfig()
end

---@param report AUIStoreReport
function Profile:EnterRecovery(report)
	self.root = nil
	self.mode = "recovery"
	self.problem = report.problem
	self.newer = report.newer
	self.quarantined = {}
	self.activeID = nil
	self.config = Schema:Defaults()
end

---Loads the saved data for a character. Absent data starts a new store; data that cannot be used enters recovery
---and stays untouched; an older schema is migrated and published with the original as its backup.
---@param original any the SavedVariables root as the client loaded it
---@param characterID string
function Profile:Initialize(original, characterID)
	self.original = original
	self.characterID = characterID

	if original == nil then
		local root = Store:NewRoot(characterID)

		self:Save(root)
		self.root = root
		self:Resolve(Store:Inspect(root))

		return
	end

	local report = Store:Inspect(original)

	if report.problem and report.migrate then
		local migrated, problem = Store:Migrate(original)

		if not migrated then
			self:EnterRecovery({ problem = problem, quarantined = {} })

			return
		end

		report = Store:Inspect(migrated)

		if not report.problem then
			self:Save(migrated)
			original = migrated
		end
	end

	if report.problem then
		self:EnterRecovery(report)

		return
	end

	self.root = original
	self:Resolve(report)

	if not original.charactersByID[characterID] then
		self:Commit(function(candidate)
			candidate.charactersByID[characterID] = {
				activeProfileID = StartingProfile(candidate, self.quarantined),
				specAssignments = {},
			}
		end, true)
	end
end

---Applies a change to a copy of the store and publishes it when the result is valid. The change returns false and a
---problem to refuse. Nothing is published, and nothing changes, unless every step succeeds.
---@param change fun(candidate: AUIStoreRoot): boolean?, string?
---@param quiet boolean? skip the change notification
---@return boolean ok
---@return string? problem
function Profile:Commit(change, quiet)
	if not self.root then
		return false, "the saved data is in recovery"
	end

	local candidate = AUI:CopyTable(self.root)
	local ran, result, refusal = pcall(change, candidate)

	if not ran then
		return false, tostring(result)
	end

	if result == false then
		return false, refusal
	end

	local report = Store:Inspect(candidate)

	if report.problem then
		return false, report.problem
	end

	for id, reason in pairs(report.quarantined) do
		if not self.quarantined[id] then
			return false, reason
		end
	end

	local previous = self.root
	local saved, problem = pcall(self.Save, self, candidate)

	if not saved then
		pcall(self.Save, self, previous)

		return false, tostring(problem)
	end

	self.root = candidate
	self:Resolve(report)

	if not quiet then
		AUI.Callbacks:Fire(CHANNEL, nil)
	end

	return true
end

---@return AUIProfileInfo
function Profile:Info()
	return { mode = self.mode, problem = self.problem, newer = self.newer, activeID = self.activeID }
end

---@return boolean
function Profile:CanEdit()
	return self.mode == "normal"
end

---@return AUIProfileEntry[] entries every profile, sorted by name
function Profile:List()
	local entries = {}

	if not self.root then
		return entries
	end

	for id, record in pairs(self.root.profilesByID) do
		local name = type(record) == "table" and type(record.name) == "string" and record.name or id

		entries[#entries + 1] = {
			id = id,
			name = name,
			active = id == self.activeID,
			quarantined = self.quarantined[id],
		}
	end

	table.sort(entries, function(a, b)
		local left, right = a.name:lower(), b.name:lower()

		if left == right then
			return a.id < b.id
		end

		return left < right
	end)

	return entries
end

---@param id string
---@return string? name
function Profile:Name(id)
	local record = self.root and self.root.profilesByID[id]

	return type(record) == "table" and type(record.name) == "string" and record.name or nil
end

---@param name string
---@return string? id the profile with exactly that name
function Profile:Find(name)
	if not self.root then
		return nil
	end

	for id, record in pairs(self.root.profilesByID) do
		if type(record) == "table" and record.name == name then
			return id
		end
	end
end

---@param path string
---@return any value the active config's value, or the field's default; a table value is a copy
function Profile:Get(path)
	return AUI:CopyTable(Schema:Read(self.config, path))
end

---@param path string
---@return boolean custom the setting follows a shared one and the active profile holds its own value
function Profile:IsCustom(path)
	return Schema:IsCustom(self.config, path)
end

---Changes one setting of the active profile.
---@param path string
---@param value any
---@return boolean ok
---@return string? problem
function Profile:Set(path, value)
	if not self:CanEdit() then
		return false, "the active profile cannot be edited"
	end

	local ok, problem = Schema:CheckValue(path, value)

	if not ok then
		return false, problem
	end

	local field = Schema:Field(path)
	local current

	if field and field.shared then
		current = Schema:Lookup(self.config, path)
	else
		current = Schema:Read(self.config, path)
	end

	if current == value then
		return true
	end

	Schema:Write(self.config, path, AUI:CopyTable(value))
	AUI.Callbacks:Fire(CHANNEL, path)

	return true
end

---@param candidate AUIStoreRoot
---@param id string
---@return AUIProfileRecord? record the profile, unless it is missing or quarantined
function Profile:Usable(candidate, id)
	local record = candidate.profilesByID[id]

	if record and not self.quarantined[id] then
		return record
	end
end

---Adds a profile to a candidate store and makes it this character's active profile.
---@param candidate AUIStoreRoot
---@param name string
---@param config table
---@return string? id
---@return string? problem
function Profile:AddTo(candidate, name, config)
	if Store:CountProfiles(candidate) >= Store.MAX_PROFILES then
		return nil, ("there can be at most %d profiles"):format(Store.MAX_PROFILES)
	end

	local problem = Store:CheckName(candidate, name)

	if problem then
		return nil, problem
	end

	local id = Store:AllocateID(candidate)

	candidate.profilesByID[id] = { name = name, schemaVersion = Schema.VERSION, config = config }
	candidate.charactersByID[self.characterID].activeProfileID = id

	return id
end

---Creates a profile with default settings and makes it active.
---@param name string
---@return boolean ok
---@return string? idOrProblem the new profile's ID, or why it was refused
function Profile:Create(name)
	local created

	local ok, problem = self:Commit(function(candidate)
		local id, refusal = self:AddTo(candidate, name, Schema:Defaults())

		if not id then
			return false, refusal
		end

		created = id
	end)

	return ok, ok and created or problem
end

---Copies a profile, dormant settings included, under a new name and makes the copy active.
---@param sourceID string
---@param name string
---@return boolean ok
---@return string? idOrProblem
function Profile:Duplicate(sourceID, name)
	local created

	local ok, problem = self:Commit(function(candidate)
		local source = self:Usable(candidate, sourceID)

		if not source then
			return false, "the profile to copy cannot be used"
		end

		local id, refusal = self:AddTo(candidate, name, AUI:CopyTable(source.config))

		if not id then
			return false, refusal
		end

		created = id
	end)

	return ok, ok and created or problem
end

---@param id string
---@param name string
---@return boolean ok
---@return string? problem
function Profile:Rename(id, name)
	return self:Commit(function(candidate)
		local record = self:Usable(candidate, id)

		if not record then
			return false, "the profile cannot be renamed"
		end

		if id == Store.DEFAULT_ID then
			return false, "the default profile cannot be renamed"
		end

		local problem = Store:CheckName(candidate, name, id)

		if problem then
			return false, problem
		end

		record.name = name
	end)
end

---Makes a valid profile this character's active profile. Specialization assignments are left as they are.
---@param id string
---@return boolean ok
---@return string? problem
function Profile:Select(id)
	if id == self.activeID and self.mode == "normal" then
		return true
	end

	return self:Commit(function(candidate)
		if not self:Usable(candidate, id) then
			return false, "the profile cannot be used"
		end

		candidate.charactersByID[self.characterID].activeProfileID = id
	end)
end

---Deletes a profile, quarantined ones included, and points every character's active profile and specialization
---assignment that used it at the replacement.
---@param id string
---@param replacementID string
---@return boolean ok
---@return string? problem
function Profile:Delete(id, replacementID)
	return self:Commit(function(candidate)
		if not candidate.profilesByID[id] then
			return false, "the profile does not exist"
		end

		if Store:CountProfiles(candidate) <= 1 then
			return false, "the last profile cannot be deleted"
		end

		if replacementID == id or not self:Usable(candidate, replacementID) then
			return false, "the replacement profile cannot be used"
		end

		for _, record in pairs(candidate.charactersByID) do
			if record.activeProfileID == id then
				record.activeProfileID = replacementID
			end

			for specID, assigned in pairs(record.specAssignments) do
				if assigned == id then
					record.specAssignments[specID] = replacementID
				end
			end
		end

		candidate.profilesByID[id] = nil
	end)
end

---Restores default settings in the active profile, removing everything else stored in the scope, dormant settings
---included. Settings outside the scope are kept.
---@param scope string|string[]? a section or setting path, or several reset together; the whole profile when nil
---@return boolean ok
---@return string? problem
function Profile:Reset(scope)
	if not self:CanEdit() then
		return false, "the active profile cannot be edited"
	end

	local scopes = type(scope) == "table" and scope or { scope }

	for _, each in ipairs(scopes) do
		if not Schema:IsScope(each) then
			return false, ("%s is not a section or setting"):format(each)
		end
	end

	local id = self.activeID --[[@as string]]

	return self:Commit(function(candidate)
		local config = candidate.profilesByID[id].config

		if scope == nil then
			Schema:ResetScope(config, nil)
		end

		for _, each in ipairs(scopes) do
			Schema:ResetScope(config, each)
		end
	end)
end

---Replaces saved data that cannot be used with a new store. Only available in recovery.
---@return boolean ok
---@return string? problem
function Profile:ResetStore()
	if self.mode ~= "recovery" then
		return false, "the saved data is not in recovery"
	end

	local root = Store:NewRoot(self.characterID)
	local saved, problem = pcall(self.Save, self, root)

	if not saved then
		pcall(self.Save, self, self.original)

		return false, tostring(problem)
	end

	self.original = root
	self.root = root
	self:Resolve(Store:Inspect(root))
	AUI.Callbacks:Fire(CHANNEL, nil)

	return true
end

---A decoded profile string, ready to import under a name the player chooses.
---@class AUIProfileImport
---@field name string the name the profile had when exported
---@field version integer its schema version
---@field config table
---@field dormant integer stored settings this version does not use

---@param id string
---@return string? text the profile as a profile string
---@return string? problem
function Profile:Export(id)
	local record = self.root and self:Usable(self.root, id)

	if not record then
		return nil, "the profile cannot be exported"
	end

	local text = AUI.Codec:Encode(AUI.Codec.PREFIX, {
		addon = AUI.name,
		version = Schema.VERSION,
		name = record.name,
		profile = record.config,
	})

	if not text then
		return nil, "the profile could not be encoded"
	end

	return text
end

---Decodes and validates a profile string without changing anything.
---@param text string
---@return AUIProfileImport? import
---@return string? reason why the string was refused, for the player
function Profile:Decode(text)
	local L = AUI.L
	local payload, problem = AUI.Codec:Decode(AUI.Codec.PREFIX, text)

	if problem == "newer" then
		return nil, L["This profile string was made by a newer version of AeonUI."]
	end

	if not payload or payload.addon ~= AUI.name then
		return nil, L["This is not an AeonUI profile string, or it was cut short."]
	end

	local version = payload.version

	if type(version) == "number" and version > Schema.VERSION then
		return nil, L["This profile string was made by a newer version of AeonUI."]
	end

	if version ~= Schema.VERSION or type(payload.name) ~= "string" or not Schema:ValidateConfig(payload.profile) then
		return nil, L["This profile string holds settings AeonUI can't use."]
	end

	return {
		name = payload.name,
		version = version,
		config = payload.profile,
		dormant = Schema:CountDormant(payload.profile),
	}
end

---Creates a profile from a decoded string, dormant settings included, and makes it active.
---@param import AUIProfileImport
---@param name string
---@return boolean ok
---@return string? idOrProblem
function Profile:Import(import, name)
	local created

	local ok, problem = self:Commit(function(candidate)
		local id, refusal = self:AddTo(candidate, name, AUI:CopyTable(import.config))

		if not id then
			return false, refusal
		end

		created = id
	end)

	return ok, ok and created or problem
end

---The saved data found at login as a diagnostic export, for recovery. It is not a profile string.
---@return string? text
---@return boolean complete whether every saved value could be encoded
function Profile:RawExport()
	local version, build = GetBuildInfo()

	return AUI.Codec:EncodeRecovery(self.original, {
		addon = AUI.name,
		addonVersion = AUI.version,
		client = ("%s.%s"):format(tostring(version), tostring(build)),
		problem = self.problem,
	})
end
