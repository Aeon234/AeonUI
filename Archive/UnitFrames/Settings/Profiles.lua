local AUI = select(2, ...)

local L = AUI.L
local AS = AUI.AeonSettings --[[@as table]]
local Store = AUI.Store
local Pages = AUI.SettingsPages

---The Profiles page: the settings library's profiles page over AeonUI's profile owner. The page names profiles;
---the owner keeps them by ID, and this adapter translates.
---@class AUISettingsProfiles
---@field page table?
local Profiles = {}
AUI.SettingsProfiles = Profiles

---@param ok boolean
---@param problem string?
local function Report(ok, problem)
	if not ok and problem then
		AUI:Warn(problem)
	end
end

---@param name string
---@return string? id
local function Find(name)
	return AUI.Profile:Find(name)
end

---@return string? id a usable profile to take a deleted one's place: Default when usable, else the first by name
function Profiles:Replacement(except)
	local fallback

	for _, entry in ipairs(AUI.Profile:List()) do
		if entry.id ~= except and not entry.quarantined then
			if entry.id == Store.DEFAULT_ID then
				return entry.id
			end

			fallback = fallback or entry.id
		end
	end

	return fallback
end

---Profiles that cannot be used, each with a Delete action, shown when there are any.
---@return table[] elements
function Profiles:DamagedSection()
	local damaged = {}

	for _, entry in ipairs(AUI.Profile:List()) do
		if entry.quarantined then
			damaged[#damaged + 1] = entry
		end
	end

	if #damaged == 0 then
		return {}
	end

	local elements = {
		Pages.Section("damaged", L["Damaged Profiles"]),
		{
			kind = "note",
			id = "damagedNote",
			text = AUI.Profile.mode == "fallback"
					and L["The active profile can't be used, so default settings are shown. Choose another profile or delete it."]
				or L["These profiles can't be used. They are kept unchanged until you delete them."],
		},
	}

	for _, entry in ipairs(damaged) do
		local id = entry.id

		elements[#elements + 1] = Pages.Row({
			id = "delete." .. id,
			control = "action",
			label = entry.name,
			description = entry.quarantined,
			verb = DELETE,
			confirm = L["Delete the damaged profile \"%s\"? Characters using it switch to another profile."]:format(entry.name),
			blocked = function()
				if not self:Replacement(id) then
					return L["Create another profile first."]
				end
			end,
			set = function()
				local ok, problem = AUI.Profile:Delete(id, self:Replacement(id) or "")

				Report(ok, problem)

				return ok
			end,
		})
	end

	return elements
end

local adapter = {
	builtin = Store.DEFAULT_NAME,
	List = function()
		local names = {}

		for _, entry in ipairs(AUI.Profile:List()) do
			if not entry.quarantined or entry.active then
				names[#names + 1] = entry.name
			end
		end

		return names
	end,
	Active = function()
		return AUI.Profile:Name(AUI.Profile.activeID or "") or Store.DEFAULT_NAME
	end,
	Switch = function(name)
		Report(AUI.Profile:Select(Find(name) or ""))
	end,
	New = function(name)
		Report(AUI.Profile:Create(name))
	end,
	Copy = function(name)
		Report(AUI.Profile:Duplicate(AUI.Profile.activeID or "", name))
	end,
	Rename = function(name)
		Report(AUI.Profile:Rename(AUI.Profile.activeID or "", name))
	end,
	Delete = function(name, replacement)
		Report(AUI.Profile:Delete(Find(name) or "", Find(replacement) or ""))
	end,
	Reset = function()
		Report(AUI.Profile:Reset())
	end,
	Export = function()
		return AUI.Profile:Export(AUI.Profile.activeID or "") or ""
	end,
	Decode = function(text)
		local import, reason = AUI.Profile:Decode(text)

		if not import then
			return nil, reason
		end

		local summary = L["AeonUI profile \"%s\"."]:format(import.name)

		if import.dormant > 0 then
			summary = summary .. " " .. L["It holds %d settings this version doesn't use; they are kept."]:format(import.dormant)
		end

		return { name = import.name, summary = summary, import = import }
	end,
	Import = function(info, name)
		Report(AUI.Profile:Import(info.import, name))
	end,
	Sections = function()
		return Profiles:DamagedSection()
	end,
}

---@return table page
function Profiles:Page()
	if not self.page then
		self.page = AS:CreateProfilesPage({ id = "profiles", title = L["Profiles"], adapter = adapter })
	end

	return self.page
end
