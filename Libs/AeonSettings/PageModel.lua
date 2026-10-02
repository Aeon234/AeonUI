-- Page model: each page's built elements, tabs, pickers, section collapse, setting activity, search and reload
-- tracking.
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
---@field settingsOf table<integer, table[]> each element's settings, by full-list index
---@field tabOf table<integer, string>? each element's tab, by full-list index, on a page with `tabs`
---@field tabs table[]? the page's tabs that hold elements, in the page's order
---@field pickers table<string, table> the page's picker elements by id
---@field pickOf table<integer, { picker: string, option: string }> each picked element's picker and option, by
---full-list index
---@field shown AeonSettingsEntry[]? listed entries, in order
---@field map table<integer, integer>? full-list index to shown index

---@class AeonSettingsPageModel
---@field memory table the window's session memory; the model reads and writes `sections`, `tabs`, `picks` and
---`initial`
---@field kinds table<string, AeonSettingsElementKind>
---@field categories table[]
---@field snapshots table<string, AeonSettingsSnapshot> the latest build of each page, by page id
---@field reloadChanges table<string, boolean> reload-pending states changed since the last `TakeReloadChanges`
local PageModel = {}
PageModel.__index = PageModel

---Creates a page model.
---@param memory { sections: table<string, table<string, boolean>>, tabs: table<string, string>?, picks: table<string, table<string, string>>?, initial: table<string, any> }
---@param kinds table<string, AeonSettingsElementKind> registered element kinds, read at each build
---@return AeonSettingsPageModel
function AS.CreatePageModel(memory, kinds)
	memory.tabs = memory.tabs or {}
	memory.picks = memory.picks or {}

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

---Assigns each element of a page with `tabs` to a tab: a section to the tab it names, or to the tab of the section
---before it when it names none or an unknown one; every other element to its section's tab. Elements before the
---first section take the first tab.
---@param pageTabs table[] the page's tabs, `{ id, title }`
---@param all table[]
---@param kinds table<string, AeonSettingsElementKind>
---@return table<integer, string> tabOf
---@return table[] tabs the tabs that hold elements, in the page's order
local function AssignTabs(pageTabs, all, kinds)
	local known, tabOf, used = {}, {}, {}
	for _, tab in ipairs(pageTabs) do
		known[tab.id] = true
	end

	local current = pageTabs[1] and pageTabs[1].id
	for index, data in ipairs(all) do
		local kind = kinds[data.kind]
		if kind and kind.section and known[data.tab] then
			current = data.tab
		end
		if current then
			tabOf[index] = current
			used[current] = true
		end
	end

	local tabs = {}
	for _, tab in ipairs(pageTabs) do
		if used[tab.id] then
			tabs[#tabs + 1] = tab
		end
	end

	return tabOf, tabs
end

---Assigns each element that names an option (`pick`) to the picker before it. A picker's reach ends at the next
---picker or the next section that is not collapsible; an element naming an option its picker lacks, or with no
---picker in reach, is always listed.
---@param all table[]
---@param kinds table<string, AeonSettingsElementKind>
---@return table<string, table> pickers
---@return table<integer, { picker: string, option: string }> pickOf
local function AssignPicks(all, kinds)
	local pickers, pickOf = {}, {}
	local current, options

	for index, data in ipairs(all) do
		local kind = kinds[data.kind]
		if kind and kind.picker then
			current, options = data, {}
			for _, option in ipairs(data.options or {}) do
				options[option.id] = true
			end
			pickers[data.id] = data
		elseif kind and kind.section and not data.collapsible then
			current = nil
		elseif current and data.pick ~= nil and options[data.pick] then
			pickOf[index] = { picker = current.id, option = data.pick }
		end
	end

	return pickers, pickOf
end

---Calls the page's `Build()` once, indexes its settings, assigns its elements to tabs and pickers and records
---reload tracking for each reload-requiring setting. The result replaces the page's previous build.
---@param page table
---@return AeonSettingsSnapshot
function PageModel:Snapshot(page)
	local all = page.Build and AS:CallHost(nil, page.Build) or {}
	local index, switch, settingsOf = {}, nil, {}

	for position, data in ipairs(all) do
		local kind = self.kinds[data.kind]
		if kind and kind.Settings then
			settingsOf[position] = AS:CallHost(nil, kind.Settings, data) or {}
			for _, setting in ipairs(settingsOf[position]) do
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

	local snapshot = { all = all, index = index, switch = switch, settingsOf = settingsOf }
	snapshot.pickers, snapshot.pickOf = AssignPicks(all, self.kinds)
	if page.tabs then
		snapshot.tabOf, snapshot.tabs = AssignTabs(page.tabs, all, self.kinds)
	end
	self.snapshots[page.id] = snapshot

	return snapshot
end

---Lists a page: builds it, or with `reuse` keeps its latest build when there is one, then lays out its entries,
---leaving out the members of collapsed sections, the elements of options not picked and, on a page with tabs,
---every element outside the active tab. A collapsible section starts collapsed.
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
	local hiding, position = false, 0
	local tabOf, activeTab = snapshot.tabOf, self:ActiveTab(page.id)
	local pickOf = snapshot.pickOf

	for index, data in ipairs(snapshot.all) do
		local kind = kinds[data.kind]
		local pick = pickOf[index]
		local listed = (not tabOf or tabOf[index] == activeTab)
			and (not pick or pick.option == self:ActivePick(page.id, pick.picker))
		if kind and listed then
			local entry
			if kind.section then
				hiding = data.collapsible and collapsed[data.id] ~= false or false
				position = 0
				entry = { kind = data.kind, data = data, pageID = page.id, collapsed = hiding }
				sections[#sections + 1] = entry
			elseif not hiding then
				position = position + 1
				entry = { kind = data.kind, data = data, pageID = page.id, position = position,
					settings = snapshot.settingsOf[index] }
				if kind.picker then
					entry.picked = self:ActivePick(page.id, data.id)
				end
			end
			if entry then
				shown[#shown + 1] = entry
				map[index] = #shown
			end
		end
	end

	self:MarkIndents(shown)

	snapshot.shown, snapshot.map = shown, map

	return shown, sections, map
end

---Marks the listed rows that sit one level in, `entry.indent`: every setting in the row depends on a setting in an
---earlier listed row of the same section, other than the section's first row, which is its switch.
---@param shown AeonSettingsEntry[]
function PageModel:MarkIndents(shown)
	local first, earlier

	for _, entry in ipairs(shown) do
		local kind = self.kinds[entry.kind]
		if kind.section then
			first, earlier = nil, {}
		elseif entry.settings then
			local settings = entry.settings
			if not first then
				first, earlier = {}, earlier or {}
				for _, setting in ipairs(settings) do
					first[setting.id] = true
				end
			else
				local indent = #settings > 0
				for _, setting in ipairs(settings) do
					local parent = setting.depends
					if not (parent and earlier[parent] and not first[parent]) then
						indent = false
					end
				end
				entry.indent = indent or nil
			end
			for _, setting in ipairs(settings) do
				earlier[setting.id] = true
			end
		end
	end
end

---@param pageID string
---@return table[]? tabs the tabs that hold elements in the page's latest build; nil on a page without tabs
function PageModel:Tabs(pageID)
	local snapshot = self.snapshots[pageID]

	return snapshot and snapshot.tabs
end

---Returns the page's active tab: the one chosen this session while the latest build still has it, otherwise the
---first.
---@param pageID string
---@return string? tabID nil on a page without tabs, or with none that holds elements
function PageModel:ActiveTab(pageID)
	local tabs = self:Tabs(pageID)
	if not tabs or not tabs[1] then
		return nil
	end

	local chosen = self.memory.tabs[pageID]
	for _, tab in ipairs(tabs) do
		if tab.id == chosen then
			return chosen
		end
	end

	return tabs[1].id
end

---Chooses a page's tab for the session. Takes effect at the page's next `Build`.
---@param pageID string
---@param tabID string
function PageModel:SetTab(pageID, tabID)
	self.memory.tabs[pageID] = tabID
end

---@param pageID string
---@param index integer index into the page's full element list
---@return string? tabID the element's tab in the page's latest build; nil on a page without tabs
function PageModel:TabOf(pageID, index)
	local snapshot = self.snapshots[pageID]

	return snapshot and snapshot.tabOf and snapshot.tabOf[index]
end

---Returns a picker's picked option: the one chosen this session while the picker still offers it, otherwise its
---first.
---@param pageID string
---@param pickerID string
---@return string? optionID nil when the page's latest build has no such picker, or it has no options
function PageModel:ActivePick(pageID, pickerID)
	local snapshot = self.snapshots[pageID]
	local picker = snapshot and snapshot.pickers[pickerID]
	local options = picker and picker.options
	if not options or not options[1] then
		return nil
	end

	local chosen = self.memory.picks[pageID] and self.memory.picks[pageID][pickerID]
	for _, option in ipairs(options) do
		if option.id == chosen then
			return chosen
		end
	end

	return options[1].id
end

---Picks a picker's option for the session. Takes effect at the page's next `Build`.
---@param pageID string
---@param pickerID string
---@param optionID string
function PageModel:SetPick(pageID, pickerID, optionID)
	local picks = self.memory.picks[pageID] or {}
	self.memory.picks[pageID] = picks
	picks[pickerID] = optionID
end

---Chooses the tab and the picked option that list an element of the page's latest build, for the session.
---@param pageID string
---@param index integer index into the page's full element list
---@return boolean changed the tab or a picked option changed
function PageModel:Choose(pageID, index)
	local snapshot = self.snapshots[pageID]
	if not snapshot then
		return false
	end

	local changed = false
	local tab = self:TabOf(pageID, index)
	if tab and tab ~= self:ActiveTab(pageID) then
		self:SetTab(pageID, tab)
		changed = true
	end

	local pick = snapshot.pickOf[index]
	if pick and pick.option ~= self:ActivePick(pageID, pick.picker) then
		self:SetPick(pageID, pick.picker, pick.option)
		changed = true
	end

	return changed
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

---Collapses or expands a collapsible section on a page, for the session. Takes effect at the page's next `Build`.
---@param pageID string
---@param sectionID string
---@param collapsed boolean
function PageModel:SetCollapsed(pageID, sectionID, collapsed)
	local sections = self.memory.sections[pageID] or {}
	self.memory.sections[pageID] = sections
	sections[sectionID] = collapsed
end

---Expands the section that holds an element of the page's latest build, so the element is listed at the next
---`Build`.
---@param pageID string
---@param index integer index into the page's full element list
---@return boolean expanded a collapsed section was expanded
function PageModel:Reveal(pageID, index)
	local snapshot = self.snapshots[pageID]
	if not snapshot then
		return false
	end

	for i = index, 1, -1 do
		local data = snapshot.all[i]
		local kind = data and self.kinds[data.kind]
		if kind and kind.section then
			if not data.collapsible then
				return false
			end

			local collapsed = self.memory.sections[pageID] or {}
			self.memory.sections[pageID] = collapsed
			local wasCollapsed = collapsed[data.id] ~= false
			collapsed[data.id] = false

			return wasCollapsed
		end
	end

	return false
end

---Finds the first element of the page's latest build that shows a setting.
---@param pageID string
---@param settingID string
---@return integer? index index into the page's full element list
---@return integer? shownIndex its index in the latest layout; nil while its section is collapsed or its tab inactive
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
-- Search synonyms -------------------------------------------------------------------------------------------

-- A synonym engages from this many of its letters (a shorter term needs all of its own).
local SYNONYM_MIN_PREFIX = 3

---Other words for what a setting's label calls something: each term a player might type, and the words labels use
---instead. Terms and alternates are plain lowercase words. Addons add their own with `AS:AddSearchSynonyms`.
---@type { [1]: string, [2]: string[] }[]
AS.searchSynonyms = AS.searchSynonyms or {
	{ "shield", { "absorb" } },
	{ "absorb", { "shield" } },
	{ "hp", { "health" } },
	{ "incoming", { "heal prediction" } },
	{ "transparency", { "opacity" } },
	{ "alpha", { "opacity" } },
	{ "colour", { "color" } },
	{ "move", { "offset", "position" } },
	{ "drag", { "offset", "position" } },
	{ "cd", { "cooldown" } },
	{ "kick", { "interrupt" } },
	{ "aggro", { "threat" } },
	{ "xp", { "experience" } },
	{ "experience", { "xp" } },
}

---Adds search synonyms for an addon's own labels.
---@param list { [1]: string, [2]: string[] }[] terms and the words to search for in their place
function AS:AddSearchSynonyms(list)
	for _, entry in ipairs(list) do
		self.searchSynonyms[#self.searchSynonyms + 1] = entry
	end
end

---@param text string
---@param first integer
---@param last integer
---@return boolean bounded the span starts and ends on word boundaries: a space or either end of the text
local function OnWordBoundaries(text, first, last)
	local before = first == 1 or text:sub(first - 1, first - 1) == " "
	local after = last == #text or text:sub(last + 1, last + 1) == " "

	return before and after
end

---The query and its synonym variants. A term engages while it is still being typed: the longest prefix of it, at
---least `SYNONYM_MIN_PREFIX` letters, that sits in the query on word boundaries is replaced by each alternate, so
---"shi", "shie" and "shield" all also search for "absorb".
---@param query string lowercase
---@return string[] queries the query first, then each distinct variant
function AS:SearchVariants(query)
	local queries, seen = { query }, { [query] = true }

	for _, synonym in ipairs(self.searchSynonyms) do
		local term = synonym[1]
		local found

		for length = #term, math.min(SYNONYM_MIN_PREFIX, #term), -1 do
			local prefix = term:sub(1, length)
			local first, last = query:find(prefix, 1, true)

			while first do
				if OnWordBoundaries(query, first, last) then
					found = { first, last }

					break
				end

				first, last = query:find(prefix, first + 1, true)
			end

			if found then
				break
			end
		end

		if found then
			for _, alternate in ipairs(synonym[2]) do
				local variant = query:sub(1, found[1] - 1) .. alternate .. query:sub(found[2] + 1)

				if not seen[variant] then
					seen[variant] = true
					queries[#queries + 1] = variant
				end
			end
		end
	end

	return queries
end

---@param text string lowercase
---@param queries string[]
---@return boolean
local function MatchesAny(text, queries)
	for _, query in ipairs(queries) do
		if text:find(query, 1, true) then
			return true
		end
	end

	return false
end

---Section elements are never matched. A query also matches through its synonyms (`AS:SearchVariants`).
---@param text string
---@return { page: table, hits: { index: integer, data: table }[] }[] groups pages with hits, in category order
---@return { categories: table<string, integer>, pages: table<string, integer> } counts hits per category and page
function PageModel:Search(text)
	local queries = AS:SearchVariants(text:lower())
	local groups = {}
	local counts = { categories = {}, pages = {} }

	for _, category in ipairs(self.categories) do
		for _, page in ipairs(category.pages) do
			local hits = {}
			for index, data in ipairs(self:Snapshot(page).all) do
				local kind = self.kinds[data.kind]
				local searchText = kind and not kind.section and kind.Search and AS:CallHost(nil, kind.Search, data)
				if searchText and MatchesAny(searchText:lower(), queries) then
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
