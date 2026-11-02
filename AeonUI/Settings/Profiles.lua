local AUI = select(2, ...)

local L = AUI.L

local Store = AUI.Store

---The Profiles page: the settings library's profiles page over AeonUI's profile owner, with a Damaged Profiles section
---while any profile cannot be used. The page names profiles; the owner keeps them by ID, and the adapter translates.
---@class AUISettingsProfiles
local Profiles = {}
AUI.SettingsProfiles = Profiles

local Profile = AUI.Profile

---@param name string
---@return string id the profile with that name, or an empty string the owner refuses
local function Find(name)
	return Profile:Find(name) or ""
end

---@param except string? a profile ID to leave out
---@return string? id a usable profile to take a deleted one's place: Default when usable, else the first by name
function Profiles:Replacement(except)
	local fallback

	for _, entry in ipairs(Profile:List()) do
		if entry.id ~= except and not entry.quarantined then
			if entry.id == Store.DEFAULT_ID then
				return entry.id
			end

			fallback = fallback or entry.id
		end
	end

	return fallback
end

local adapter = {
	List = function()
		local names = {}

		for _, entry in ipairs(Profile:List()) do
			if not entry.quarantined or entry.active then
				names[#names + 1] = entry.name
			end
		end

		return names
	end,
	Active = function()
		return Profile:Name(Profile.activeID or "") or Store.DEFAULT_NAME
	end,
	Switch = function(name)
		return Profile:Select(Find(name))
	end,
	New = function(name)
		return Profile:Create(name)
	end,
	Copy = function(name)
		return Profile:Duplicate(Profile.activeID or "", name)
	end,
	Rename = function(name)
		return Profile:Rename(Profile.activeID or "", name)
	end,
	Delete = function(name, replacement)
		return Profile:Delete(Find(name), Find(replacement))
	end,
	Reset = function()
		return Profile:Reset()
	end,
	Export = function()
		return Profile:Export(Profile.activeID or "") or ""
	end,
	Decode = function(text)
		local import, reason = Profile:Decode(text)

		if not import then
			return nil, reason
		end

		local summary = AUI:Branded(L["AeonUI profile \"%s\"."]):format(import.name)

		if import.dormant > 0 then
			summary = summary .. " " .. L["It holds %d settings this version doesn't use; they are kept."]:format(import.dormant)
		end

		return { name = import.name, summary = summary, import = import }
	end,
	Import = function(info, name)
		return Profile:Import(info.import, name)
	end,
}

---Profiles that cannot be used when the window is built, each with a Delete action. Quarantine is decided at login,
---so the list only shrinks; a deleted profile's row hides.
---@param page table
local function DeclareDamaged(page)
	local damaged = {}

	for _, entry in ipairs(Profile:List()) do
		if entry.quarantined then
			damaged[#damaged + 1] = entry
		end
	end

	if #damaged == 0 then
		return
	end

	local section = page:Section("damaged", L["Damaged Profiles"], {
		show = function()
			for _, entry in ipairs(damaged) do
				if Profile:Name(entry.id) then
					return true
				end
			end

			return false
		end,
	})

	if not section then
		return
	end

	section:Note(Profile.mode == "fallback"
		and L["The active profile can't be used, so default settings are shown. Choose another profile or delete it."]
		or L["These profiles can't be used. They are kept unchanged until you delete them."])

	for _, entry in ipairs(damaged) do
		local id = entry.id

		section:Button({
			id = "delete." .. id,
			label = entry.name,
			description = entry.quarantined,
			verb = DELETE,
			confirm = L["Delete the damaged profile \"%s\"? Characters using it switch to another profile."]:format(entry.name),
			show = function()
				return Profile:Name(id) ~= nil
			end,
			blocked = function()
				if not Profiles:Replacement(id) then
					return L["Create another profile first."]
				end
			end,
			run = function()
				return Profile:Delete(id, Profiles:Replacement(id) or "")
			end,
		})
	end
end

---@param window table
function Profiles:Declare(window)
	window:ProfilesPage("profiles", {
		title = L["Profiles"],
		icon = AUI.Media.sidebar.profiles,
		iconTint = true,
		adapter = adapter,
		sections = DeclareDamaged,
	})
end
