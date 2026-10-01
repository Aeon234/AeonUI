-- Page model: each page's built elements, section collapse, setting activity, search and reload tracking.
-- Frame-free; the window draws what it returns. Every host function runs through `AS:CallHost`.
local _, ns = ...
local AS = ns.AeonSettings
local L = AS.L

-- Returned in place of a host function's results when it raised an error.
local FAILED = {}

-- Stands in for a nil value in `memory.initial`, where nil means "not seen yet".
local NIL_VALUE = {}

---A page's elements from one `Build()` call and the settings found in them. `shown` and `map` describe the
---latest layout of those elements.
---@class AeonSettingsSnapshot
---@field all table[] every element the page built
---@field index table<string, table> the page's settings by id
---@field switch table? the page's switch setting
---@field shown AeonSettingsEntry[]? listed entries, in order
---@field map table<integer, integer>? full-list index to shown index

---@class AeonSettingsPageModel
---@field memory table the window's session memory; the model reads and writes `sections` and `initial`
---@field kinds table<string, AeonSettingsElementKind>
---@field categories table[]
---@field snapshots table<string, AeonSettingsSnapshot> the latest build of each page, by page id
---@field reloadChanges table<string, boolean> reload-pending states changed since the last `TakeReloadChanges`
local PageModel = {}
PageModel.__index = PageModel

---Creates a page model.
---@param memory { sections: table<string, table<string, boolean>>, initial: table<string, any> }
---@param kinds table<string, AeonSettingsElementKind> registered element kinds, read at each build
---@return AeonSettingsPageModel
function AS.CreatePageModel(memory, kinds)
	return setmetatable({
		memory = memory,
		kinds = kinds,
		categories = {},
		snapshots = {},
		reloadChanges = {},
	}, PageModel)
end

---Replaces the category and page definitions and drops every page's build. Collapse state and reload baselines
---are kept.
---@param categories table[]
function PageModel:SetCategories(categories)
	self.categories = categories
	self.snapshots = {}
end

---Calls the page's `Build()` once, indexes its settings and records reload tracking for each reload-requiring
---setting. The result replaces the page's previous build.
---@param page table
---@return AeonSettingsSnapshot
function PageModel:Snapshot(page)
	local all = page.Build and AS:CallHost(nil, page.Build) or {}
	local index, switch = {}, nil

	for _, data in ipairs(all) do
		local kind = self.kinds[data.kind]
		if kind and kind.Settings then
			for _, setting in ipairs(AS:CallHost(nil, kind.Settings, data) or {}) do
				index[setting.id] = setting
				if setting.pageSwitch and not switch then
					switch = setting
				end
				if setting.reload then
					self:TrackReload(page.id, setting)
				end
			end
		end
	end

	local snapshot = { all = all, index = index, switch = switch }
	self.snapshots[page.id] = snapshot

	return snapshot
end

---Lists a page: builds it, or with `reuse` keeps its latest build when there is one, then lays out its entries,
---leaving out the members of collapsed sections.
---@param page table
---@param reuse boolean?
---@return AeonSettingsEntry[] entries shown entries in list order
---@return AeonSettingsEntry[] sections the section entries among them
---@return table<integer, integer> map full-list index to shown index
function PageModel:Build(page, reuse)
	local snapshot = reuse and self.snapshots[page.id] or self:Snapshot(page)
	local collapsed = self.memory.sections[page.id] or {}
	local kinds = self.kinds
	local shown, sections, map = {}, {}, {}
	local hiding, inSection, position = false, false, 0

	for index, data in ipairs(snapshot.all) do
		local kind = kinds[data.kind]
		if kind then
			local entry
			if kind.section then
				hiding = data.collapsible and collapsed[data.id] == true or false
				inSection, position = true, 0
				entry = { kind = data.kind, data = data, pageID = page.id, collapsed = hiding }
				sections[#sections + 1] = entry
			elseif not hiding then
				position = position + 1
				entry = { kind = data.kind, data = data, pageID = page.id, position = position, onSurface = inSection }
			end
			if entry then
				shown[#shown + 1] = entry
				map[index] = #shown
			end
		end
	end

	for i, entry in ipairs(shown) do
		local nextEntry = shown[i + 1]
		local closes = nextEntry == nil or kinds[nextEntry.kind].section
		if kinds[entry.kind].section then
			entry.empty = not entry.collapsed and closes or nil
		else
			entry.last = entry.onSurface and closes or nil
		end
	end

	snapshot.shown, snapshot.map = shown, map

	return shown, sections, map
end

---@param pageID string
---@return table? switch the page's switch setting in its latest build
function PageModel:PageSwitch(pageID)
	local snapshot = self.snapshots[pageID]

	return snapshot and snapshot.switch
end

---Returns whether a setting is active and, when not, the reason. A setting is inactive while the page's
---switch is off, while anything up its `depends` chain is off (the furthest first), or while its own
---`blocked()` returns a reason. Dependencies resolve against the page's latest build.
---@param pageID string
---@param setting table
---@return boolean enabled
---@return string? reason
function PageModel:State(pageID, setting)
	local snapshot = self.snapshots[pageID]
	local index = snapshot and snapshot.index or {}

	local switch = snapshot and snapshot.switch
	if switch and switch ~= setting and not AS:CallHost(nil, switch.get) then
		return false, L["Requires %s to be enabled."]:format(switch.label or switch.id)
	end

	local chain = {}
	local seen = { [setting] = true }
	local parent = setting.depends and index[setting.depends]
	while parent and not seen[parent] do
		seen[parent] = true
		chain[#chain + 1] = parent
		parent = parent.depends and index[parent.depends]
	end
	for i = #chain, 1, -1 do
		if not AS:CallHost(nil, chain[i].get) then
			return false, L["Requires %s to be enabled."]:format(chain[i].label or chain[i].id)
		end
	end

	local reason = setting.blocked and AS:CallHost(FAILED, setting.blocked)
	if reason == FAILED then
		return false
	elseif reason then
		return false, reason
	end

	return true
end

---Collapses or expands a section on a page, for the session. Takes effect at the page's next `Build`.
---@param pageID string
---@param sectionID string
---@param collapsed boolean
function PageModel:SetCollapsed(pageID, sectionID, collapsed)
	local sections = self.memory.sections[pageID] or {}
	self.memory.sections[pageID] = sections
	sections[sectionID] = collapsed or nil
end

---Expands the section that holds an element of the page's latest build, so the element is listed at the next
---`Build`.
---@param pageID string
---@param index integer index into the page's full element list
---@return boolean expanded a collapsed section was expanded
function PageModel:Reveal(pageID, index)
	local collapsed = self.memory.sections[pageID]
	local snapshot = self.snapshots[pageID]
	if not collapsed or not snapshot then
		return false
	end

	for i = index, 1, -1 do
		local data = snapshot.all[i]
		local kind = data and self.kinds[data.kind]
		if kind and kind.section then
			local wasCollapsed = collapsed[data.id] == true
			collapsed[data.id] = nil

			return wasCollapsed
		end
	end

	return false
end

---Finds the first element of the page's latest build that shows a setting.
---@param pageID string
---@param settingID string
---@return integer? index index into the page's full element list
---@return integer? shownIndex its index in the latest layout; nil while its section is collapsed
---@return integer? anchor shown index of its section's header, or its own when it is in no section
function PageModel:Locate(pageID, settingID)
	local snapshot = self.snapshots[pageID]
	if not snapshot then
		return nil
	end

	for index, data in ipairs(snapshot.all) do
		local kind = self.kinds[data.kind]
		if kind and kind.Settings then
			for _, setting in ipairs(AS:CallHost(nil, kind.Settings, data) or {}) do
				if setting.id == settingID then
					local shownIndex = snapshot.map and snapshot.map[index]
					if not shownIndex then
						return index
					end

					local anchor = shownIndex
					for i = shownIndex - 1, 1, -1 do
						if self.kinds[snapshot.shown[i].kind].section then
							anchor = i
							break
						end
					end

					return index, shownIndex, anchor
				end
			end
		end
	end

	return nil
end

---Builds every page and matches `text`, case-insensitively and literally, against each element's search text.
---Section elements are never matched.
---@param text string
---@return { page: table, hits: { index: integer, data: table }[] }[] groups pages with hits, in category order
---@return { categories: table<string, integer>, pages: table<string, integer> } counts hits per category and page
function PageModel:Search(text)
	local query = text:lower()
	local groups = {}
	local counts = { categories = {}, pages = {} }

	for _, category in ipairs(self.categories) do
		for _, page in ipairs(category.pages) do
			local hits = {}
			for index, data in ipairs(self:Snapshot(page).all) do
				local kind = self.kinds[data.kind]
				local searchText = kind and not kind.section and kind.Search and AS:CallHost(nil, kind.Search, data)
				if searchText and searchText:lower():find(query, 1, true) then
					hits[#hits + 1] = { index = index, data = data }
				end
			end
			if #hits > 0 then
				groups[#groups + 1] = { page = page, hits = hits }
				counts.pages[page.id] = #hits
				counts.categories[category.id] = (counts.categories[category.id] or 0) + #hits
			end
		end
	end

	return groups, counts
end

---Compares two setting values; tables are compared by their fields, one level deep.
---@param a any
---@param b any
---@return boolean
local function SameValue(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for key, value in pairs(a) do
		if b[key] ~= value then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end

	return true
end

---Records a reload-requiring setting's value the first time it is seen this session; afterward, records
---whether its current value differs from that one. Collect the results with `TakeReloadChanges`.
---@param pageID string
---@param setting table
function PageModel:TrackReload(pageID, setting)
	if not setting.get then
		return
	end

	local key = pageID .. "/" .. setting.id
	local current = AS:CallHost(nil, setting.get)
	local initial = self.memory.initial[key]
	if initial == nil then
		if current == nil then
			self.memory.initial[key] = NIL_VALUE
		elseif type(current) == "table" then
			self.memory.initial[key] = CopyTable(current, true)
		else
			self.memory.initial[key] = current
		end

		return
	end

	if initial == NIL_VALUE then
		initial = nil
	end
	self.reloadChanges[key] = not SameValue(current, initial)
end

---Returns the reload-pending state of each setting tracked since the last call, keyed `pageID/settingID`,
---and clears the record.
---@return table<string, boolean>
function PageModel:TakeReloadChanges()
	local changes = self.reloadChanges
	self.reloadChanges = {}

	return changes
end
