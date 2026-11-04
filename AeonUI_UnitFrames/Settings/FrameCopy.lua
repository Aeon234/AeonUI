local AUI = select(2, ...)

local L = AUI.L
local lib = LibStub("LibAeonSettings-1.0")
local Schema = AUI.Schema
local Options = AUI.UnitFrameOptions

---Copy From on a card's title line: a menu of the other places holding that card's settings, each with how many values
---differ. A pick applies at once as one Undo step and flashes the rows it changed. A setting following a shared one stays
---following; the frame's own switch and place belong to no card, so they are never copied.
---@class AUISettingsFrameCopy
---@field SCOPES table<string, string[]> each frame card's settings under the frame: a setting, or a branch ending in a dot
local FrameCopy = {
	SCOPES = {
		size = { "width", "height", "reverse" },
		bars = { "bars." },
		health = { "health.", "overlays." },
		power = { "power.", "powerColors." },
		portrait = { "portrait." },
		text = { "text.", "numbers." },
		castBar = { "castBar." },
		buffs = { "buffs." },
		debuffs = { "debuffs." },
		indicators = { "indicators.", "totems." },
		fading = { "fade." },
		interaction = { "tooltip." },
	},
}
AUI.SettingsFrameCopy = FrameCopy

---@param rest string a setting's path under its base
---@param scope string[]?
---@return boolean inside
local function InScope(rest, scope)
	if not scope then
		return true
	end

	for _, entry in ipairs(scope) do
		if rest == entry or (entry:sub(-1) == "." and rest:sub(1, #entry) == entry) then
			return true
		end
	end

	return false
end

---@param a any
---@param b any
---@return boolean same
local function Same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end

	for key, value in pairs(a) do
		if not Same(value, b[key]) then
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

---Works out what copying one place's settings onto another would change.
---@param fromBase string the start of the source's paths
---@param toBase string the start of the target's paths
---@param scope string[]? the settings under them, or all of them
---@return { path: string, value: any }[] changes
---@return integer shared how many settings both places have
function FrameCopy:Plan(fromBase, toBase, scope)
	local config = AUI.Profile.config
	local changes, shared = {}, 0

	for _, source in ipairs(Schema.order) do
		local rest = source:sub(1, #fromBase) == fromBase and source:sub(#fromBase + 1)
		local target = rest and InScope(rest, scope) and toBase .. rest
		local field = target and Schema:Field(target)

		if field then
			local value = Schema:Lookup(config, source)

			shared = shared + 1

			if value == nil and not (Schema:Field(source).shared and field.shared) then
				value = Schema:Read(config, source)
			end

			local current

			if value == nil then
				current = Schema:Lookup(config, target)
			else
				current = Schema:Read(config, target)
			end

			if not Same(current, value) and Schema:CheckValue(target, value) then
				changes[#changes + 1] = { path = target, value = value }
			end
		end
	end

	return changes, shared
end

---Saves a plan as one Undo step.
---@param changes { path: string, value: any }[]
---@param page table the page holding the card
---@param text string Undo's line
---@return table<string, true> written the paths saved
function FrameCopy:Apply(changes, page, text)
	local Profile = AUI.Profile
	local before, written = {}, {}

	for _, change in ipairs(changes) do
		local value = Schema:Lookup(Profile.config, change.path)

		if value == nil and not Schema:Field(change.path).optional then
			value = Schema:Read(Profile.config, change.path)
		end

		local saved = AUI:CopyTable(value)

		if Profile:Set(change.path, change.value) then
			before[#before + 1] = { path = change.path, before = saved }
			written[change.path] = true
		end
	end

	local window = AUI.Settings.window --[[@as table]]

	window:RecordChange({ paths = before, text = text, page = page.id })

	return written
end

---Flashes the rows of the settings written, or the whole card when none of them shows.
---@param page table
---@param card table
---@param written table<string, true>
local function Flash(page, card, written)
	local window = AUI.Settings.window --[[@as table]]
	local settings = {}

	for _, setting in pairs(page.settings) do
		if written[setting.path] then
			settings[#settings + 1] = setting
		end
	end

	window:Refresh()

	if window:FlashSettings(settings) == 0 then
		local header = window:HeaderOf(card)

		if header and header.top then
			window:Flash(header, header.top, (header.bottom or header.top) - header.top)
		end
	end
end

---Puts Copy From on a card's title line, when another place has any of its settings.
---@param card table
---@param page table
---@param toBase string the start of the card's paths
---@param scope string[]?
---@param sources { title: string, base: string }[]
function FrameCopy:Link(card, page, toBase, scope, sources)
	local function Build(menu)
		for _, source in ipairs(sources) do
			local changes, shared = self:Plan(source.base, toBase, scope)

			if #changes > 0 then
				menu:Action(L["%s (%d different)"]:format(source.title, #changes), function()
					lib:CloseMenus()
					Flash(page, card, self:Apply(changes, page, L["%s copied from %s."]:format(card.title, source.title)))
				end)
			elseif shared > 0 then
				menu:Hint(L["%s (no differences)"]:format(source.title))
			end
		end
	end

	card:LinkMenu({
		text = L["Copy From"],
		build = Build,
		show = function()
			for _, source in ipairs(sources) do
				local _, shared = self:Plan(source.base, toBase, scope)

				if shared > 0 then
					return true
				end
			end

			return false
		end,
	})
end

---Puts Copy From on a frame page's card, listing the other frames.
---@param card table
---@param page table
---@param key string the page's frame
---@param name string the card's entry in `SCOPES`
function FrameCopy:LinkFrame(card, page, key, name)
	local sources, own = {}, false

	for _, spec in ipairs(Options.FRAMES) do
		if spec.key == key then
			own = true
		else
			sources[#sources + 1] = {
				title = AUI.SettingsFramePage.TITLES[spec.key] --[[@as string]],
				base = Options:Path(spec.key, ""),
			}
		end
	end

	if own then
		self:Link(card, page, Options:Path(key, ""), self.SCOPES[name], sources)
	end
end
