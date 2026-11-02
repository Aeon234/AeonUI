local AUI = select(2, ...)

-- Sidebar order. A group's header is declared before its first available page.
local GROUPS = {
	{ key = "unitFrames", header = "unitFramesHeader", title = "Unit Frames" },
	{ key = "maps", header = "mapsHeader", title = "Maps" },
	{ key = "tooltip", header = "tooltipHeader", title = "Tooltip" },
	{ key = "qualityOfLife", header = "qualityOfLifeHeader", title = "Quality of Life" },
}

local RANKS = {}

for rank, group in ipairs(GROUPS) do
	RANKS[group.key] = rank
end

---@class AUIEditTargetDeclaration
---@field key string the library's target key
---@field path string the profile setting holding the position
---@field target fun(): table? the library's target without its key, or nil while the frame has no place to move

---@class AUIModuleDeclaration
---@field group string a key of GROUPS
---@field start fun() runs at login, once saved data is ready
---@field page table? the settings page object: `Declare(window)`, and `IsAvailable()` when a client may lack the page
---@field reloadNeeded (fun(): boolean)? whether the settings footer offers a reload for this feature
---@field commands table<string, fun()>? `/aui` subcommands
---@field pageShown fun(page: string?)? called when the settings window shows a page or closes (nil)
---@field editTargets AUIEditTargetDeclaration[]?

---The features plugged into the base addon. Each declares itself at load, and the base reaches a feature only through
---its declaration.
---@class AUIModules
---@field list AUIModuleDeclaration[] by group, then in registration order
---@field paths table<string, string> each edit target's position setting, by key
local Modules = { list = {}, paths = {} }
AUI.Modules = Modules

---@param module AUIModuleDeclaration
function Modules:Register(module)
	local rank = RANKS[module.group]

	if not rank then
		error("unknown module group: " .. tostring(module.group), 2)
	end

	local list = self.list
	local index = #list + 1

	while index > 1 and RANKS[list[index - 1].group] > rank do
		index = index - 1
	end

	table.insert(list, index, module)

	for _, editTarget in ipairs(module.editTargets or {}) do
		self.paths[editTarget.key] = editTarget.path
	end
end

---Starts every module. An error is reported and the remaining modules still start.
function Modules:Start()
	for _, module in ipairs(self.list) do
		xpcall(module.start, CallErrorHandler)
	end
end

---Declares the available pages under their group headers.
---@param window table
function Modules:DeclarePages(window)
	local group

	for _, module in ipairs(self.list) do
		local page = module.page

		if page and (not page.IsAvailable or page:IsAvailable()) then
			if module.group ~= group then
				group = module.group

				local entry = GROUPS[RANKS[group]]

				window:Header(entry.header, AUI.L[entry.title])
			end

			page:Declare(window)
		end
	end
end

---@return boolean
function Modules:ReloadNeeded()
	for _, module in ipairs(self.list) do
		if module.reloadNeeded and module.reloadNeeded() then
			return true
		end
	end

	return false
end

---@param command string
---@return fun()? handler
function Modules:Command(command)
	for _, module in ipairs(self.list) do
		local handler = module.commands and module.commands[command]

		if handler then
			return handler
		end
	end
end

---@param page string? the page shown; nil when the window is closed
function Modules:PageShown(page)
	for _, module in ipairs(self.list) do
		if module.pageShown then
			module.pageShown(page)
		end
	end
end
