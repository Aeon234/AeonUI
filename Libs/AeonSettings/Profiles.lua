-- Profiles page: the active profile, managing and sharing profiles, drawn from an addon's profile adapter.
-- Profiles and saved data stay with the addon; every adapter call runs through `AS:CallHost`.
local _, ns = ...
local AS = ns.AeonSettings
local L = AS.L

local DEFAULT_BUILTIN = "Default"
local NAME_MAX_LETTERS = 32

---An addon's profiles, as the Profiles page reads and changes them.
---@class AeonSettingsProfileAdapter
---@field builtin string? saved key of the built-in profile, shown as Blizzard's `DEFAULT`; "Default" when nil
---@field List fun(): string[] every profile's saved key
---@field Active fun(): string
---@field Switch fun(name: string)
---@field New fun(name: string) creates a profile with default settings and activates it
---@field Copy fun(name: string) copies the active profile to a new profile and activates it
---@field Rename fun(name: string) renames the active profile
---@field Delete fun(name: string, replacement: string) deletes a profile and activates `replacement`
---@field Reset fun() resets the active profile to default settings
---@field Export fun(): string the active profile as an export string
---@field Decode fun(text: string): table?, string? `{ name, summary }` for a valid string, or nil and the reason
---@field Import fun(info: table, name: string) creates a profile from decoded `info`, named `name`, and activates it
---@field IsEditing (fun(): boolean)? whether the addon's edit mode is open
---@field UsesCharacterProfile (fun(): boolean)? with `SetUseCharacterProfile`, shows the character option
---@field SetUseCharacterProfile (fun(on: boolean))?
---@field Sections (fun(): table[])? further page elements, placed after the Active Profile section

---@param adapter AeonSettingsProfileAdapter
---@return string
local function Builtin(adapter)
	return adapter.builtin or DEFAULT_BUILTIN
end

---The name a profile is shown under: Blizzard's `DEFAULT` for the built-in profile, else its saved key.
---@param name string
---@param builtin string
---@return string
function AS:ProfileDisplayName(name, builtin)
	return name == builtin and DEFAULT or name
end

---Sorts profile keys in place: the built-in profile first, then case-insensitively.
---@param names string[]
---@param builtin string
---@return string[] names
function AS:SortProfiles(names, builtin)
	table.sort(names, function(a, b)
		if a == builtin or b == builtin then
			return a == builtin and b ~= builtin
		end

		return a:lower() < b:lower()
	end)

	return names
end

---Checks a proposed profile name. Names are unique case-insensitively, and the built-in profile's key and shown
---name are reserved for it.
---@param name string trimmed
---@param names string[] existing profile keys
---@param builtin string the built-in profile's key
---@param except string? the key being renamed, which may keep or recase its own name
---@return string? problem a sentence, or nil when the name is valid
function AS:CheckProfileName(name, names, builtin, except)
	if strlenutf8(name) > NAME_MAX_LETTERS then
		return L["It can be %d letters at most."]:format(NAME_MAX_LETTERS)
	end

	local lower = name:lower()
	if except ~= builtin and (lower == builtin:lower() or lower == DEFAULT:lower()) then
		return L["\"%s\" is the built-in profile's name."]:format(DEFAULT)
	end

	for _, existing in ipairs(names) do
		if existing ~= except and existing:lower() == lower then
			return L["A profile named \"%s\" already exists."]:format(self:ProfileDisplayName(existing, builtin))
		end
	end
end

---Builds the Profiles page.
---@param options { id: string, title: string?, icon: string?, adapter: AeonSettingsProfileAdapter }
---@return table page a page for `window:SetCategories`
function AS:CreateProfilesPage(options)
	local adapter = options.adapter
	local builtin = Builtin(adapter)
	local id = options.id

	local function Call(fallback, name, ...)
		local fn = adapter[name]
		if not fn then
			return fallback
		end

		return AS:CallHost(fallback, fn, ...)
	end

	local function Names()
		local names = Call({}, "List")
		return AS:SortProfiles(CopyTable(names), builtin)
	end

	local function Display(name)
		return AS:ProfileDisplayName(name, builtin)
	end

	local function Exists(name)
		for _, existing in ipairs(Names()) do
			if existing == name then
				return true
			end
		end

		return false
	end

	local function Locked()
		if Call(false, "IsEditing") then
			return L["Unavailable while editing the layout."]
		end
	end

	local function Check(name, except)
		return AS:CheckProfileName(name, Names(), builtin, except)
	end

	---Reports a finished change and rebuilds the page, whose values it may have changed.
	local function Done(window, text)
		window:ShowStatus(text)
		window:RefreshPage()
	end

	local function Dialog()
		return AS:ProfileDialogFrame()
	end

	local function Setting(key, fields)
		fields.id = id .. "." .. key
		return fields
	end

	local function Action(key, label, verb, run, extra)
		local setting = Setting(key, { control = "action", label = label, verb = verb, blocked = Locked })
		setting.set = function(_, window)
			run(window)

			return true
		end
		for field, value in pairs(extra or {}) do
			setting[field] = value
		end

		return setting
	end

	local active = Setting("active", {
		control = "dropdown",
		label = L["Active Profile"],
		rebuild = true,
		blocked = Locked,
		options = function()
			local choices = {}
			for _, name in ipairs(Names()) do
				choices[#choices + 1] = { value = name, text = Display(name) }
			end

			return choices
		end,
		get = function()
			return Call(nil, "Active")
		end,
		set = function(value)
			Call(nil, "Switch", value)
		end,
	})

	local character = Setting("character", {
		control = "checkbox",
		label = L["Use a Profile for This Character"],
		description = L["Switches to a profile named after this character, made the first time."],
		rebuild = true,
		blocked = Locked,
		get = function()
			return Call(false, "UsesCharacterProfile") == true
		end,
		set = function(value)
			Call(nil, "SetUseCharacterProfile", value)
		end,
	})

	local new = Action("new", L["New Profile"], L["New"], function(window)
		Dialog():Open("name", {
			title = L["New Profile"],
			verb = L["Create"],
			message = L["Name the new profile. It starts with default settings."],
			hint = L["Profile name"],
			validate = Check,
			accept = function(name)
				Call(nil, "New", name)
				Done(window, L["Profile \"%s\" created."]:format(name))
			end,
		})
	end)

	local copy = Action("copy", L["Copy Current Profile"], L["Copy"], function(window)
		local source = Display(Call("", "Active"))
		Dialog():Open("name", {
			title = L["Copy Profile"],
			verb = L["Copy"],
			message = L["Name the copy of \"%s\"."]:format(source),
			hint = L["Copy of %s"]:format(source),
			validate = Check,
			accept = function(name)
				Call(nil, "Copy", name)
				Done(window, L["Copied \"%s\" to \"%s\"."]:format(source, name))
			end,
		})
	end)

	local rename = Action("rename", L["Rename Current Profile"], L["Rename"], function(window)
		local old = Call("", "Active")
		local shown = Display(old)
		Dialog():Open("name", {
			title = L["Rename Profile"],
			verb = L["Rename"],
			message = L["Rename \"%s\" to:"]:format(shown),
			text = shown,
			validate = function(name)
				if name == shown then
					return ""
				end

				return Check(name, old)
			end,
			accept = function(name)
				Call(nil, "Rename", name)
				Done(window, L["Renamed \"%s\" to \"%s\"."]:format(shown, name))
			end,
		})
	end)

	local function DeleteBlocked()
		if #Names() <= 1 then
			return L["The last profile can't be deleted."]
		end

		return Locked()
	end

	local delete = Action("delete", L["Delete Current Profile"], L["Delete"], function(window)
		local name = Call("", "Active")
		if name ~= builtin and Exists(builtin) then
			Call(nil, "Delete", name, builtin)
			Done(window, L["Profile \"%s\" deleted; now using \"%s\"."]:format(Display(name), Display(builtin)))

			return
		end

		local choices = {}
		for _, other in ipairs(Names()) do
			if other ~= name then
				choices[#choices + 1] = { value = other, text = Display(other) }
			end
		end
		Dialog():Open("replace", {
			title = L["Delete Profile"],
			verb = L["Delete"],
			message = L["Delete the profile \"%s\"? Its settings will be lost. Choose the profile to use instead:"]
				:format(Display(name)),
			choices = choices,
			default = choices[1] and choices[1].value,
			accept = function(replacement)
				Call(nil, "Delete", name, replacement)
				Done(window, L["Profile \"%s\" deleted; now using \"%s\"."]:format(Display(name), Display(replacement)))
			end,
		})
	end, {
		blocked = DeleteBlocked,
		-- Deleting the active profile while the built-in one remains asks here; otherwise the replacement
		-- dialog asks instead.
		confirm = function()
			local name = Call("", "Active")
			if name ~= builtin and Exists(builtin) then
				return L["Delete the profile \"%s\"? Its settings will be lost, and \"%s\" becomes active."]
					:format(Display(name), DEFAULT)
			end
		end,
	})

	local reset = Action("reset", L["Reset Current Profile"], L["Reset"], function(window)
		local name = Display(Call("", "Active"))
		Call(nil, "Reset")
		Done(window, L["Profile \"%s\" reset."]:format(name))
	end, {
		confirm = function()
			return L["Reset the profile \"%s\" to default settings?"]:format(Display(Call("", "Active")))
		end,
	})

	local export = Action("export", L["Export Current Profile"], L["Export"], function()
		Dialog():Open("export", { title = L["Export Profile"], text = Call("", "Export") })
	end)
	-- Export changes nothing, so edit mode does not lock it.
	export.blocked = nil

	local import = Action("import", L["Import Profile"], L["Import"], function(window)
		Dialog():Open("import", {
			title = L["Import Profile"],
			verb = L["Import"],
			message = L["Paste a profile string. Importing creates a new profile."],
			decode = function(text)
				return Call(nil, "Decode", text)
			end,
			validate = Check,
			accept = function(info, name)
				Call(nil, "Import", info, name)
				Done(window, L["Imported \"%s\" as \"%s\"."]:format(Display(info.name or ""), name))
			end,
		})
	end)

	local page = { id = id, title = options.title or L["Profiles"], icon = options.icon }

	function page.Build()
		local elements = {
			{ kind = "section", id = "active", title = L["Active Profile"] },
			{ kind = "setting", setting = active },
		}
		if adapter.UsesCharacterProfile and adapter.SetUseCharacterProfile then
			elements[#elements + 1] = { kind = "setting", setting = character }
		end
		for _, element in ipairs(Call({}, "Sections")) do
			elements[#elements + 1] = element
		end
		elements[#elements + 1] = { kind = "section", id = "manage", title = L["Manage"] }
		elements[#elements + 1] = { kind = "setting", settings = { new, copy } }
		elements[#elements + 1] = { kind = "setting", settings = { rename, delete } }
		elements[#elements + 1] = { kind = "setting", setting = reset }
		elements[#elements + 1] = { kind = "section", id = "share", title = L["Share"] }
		elements[#elements + 1] = { kind = "setting", settings = { export, import } }

		return elements
	end

	return page
end
