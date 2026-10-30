local AUI = select(2, ...)

---A console variable and the value a hold keeps it at.
---@class AUIHeldCVar
---@field name string
---@field value string

---The Hidden Settings rules: the values each hold keeps, and what saving, holding and restoring console variables
---write. Every function reads console variables through `read`, which returns nil for one the client lacks.
---@class AUIHiddenSettingsOptions
---@field LOOT_SPARKLE AUIHeldCVar[] quest items sparkle only while the outline mode is off and the loot effect is on
---@field LOOT_SPARKLE_TRIGGERS string[] console variables whose change resets the loot sparkle's
local Options = {
	LOOT_SPARKLE = {
		{ name = "outlineModeShowLootEffectWhenDisabled", value = "1" },
		{ name = "graphicsOutlineMode", value = "0" },
		{ name = "raidGraphicsOutlineMode", value = "0" },
		{ name = "OutlineEngineMode", value = "0" },
		{ name = "RAIDOutlineEngineMode", value = "0" },
	},
	LOOT_SPARKLE_TRIGGERS = { "graphicsQuality", "raidGraphicsQuality" },
}
AUI.HiddenSettingsOptions = Options

---Adds the current value of each held console variable not yet saved. Values already saved are kept.
---@param held AUIHeldCVar[]
---@param read fun(name: string): string?
---@param saved table<string, string>
---@return table<string, string> saved
function Options.Save(held, read, saved)
	for _, entry in ipairs(held) do
		if saved[entry.name] == nil then
			saved[entry.name] = read(entry.name)
		end
	end

	return saved
end

---@param wanted AUIHeldCVar[]
---@param read fun(name: string): string?
---@return AUIHeldCVar[] writes the entries whose console variable exists and holds another value, in order
function Options.Pending(wanted, read)
	local writes = {}

	for _, entry in ipairs(wanted) do
		local value = read(entry.name)

		if value ~= nil and value ~= entry.value then
			writes[#writes + 1] = entry
		end
	end

	return writes
end

---@param held AUIHeldCVar[]
---@param saved table<string, any> a save, possibly damaged: only held names with text values are restored
---@param read fun(name: string): string?
---@return AUIHeldCVar[] writes the saved values that differ from the current ones, in held order
function Options.Restore(held, saved, read)
	local wanted = {}

	for _, entry in ipairs(held) do
		local value = saved[entry.name]

		if type(value) == "string" then
			wanted[#wanted + 1] = { name = entry.name, value = value }
		end
	end

	return Options.Pending(wanted, read)
end

---@param names string[]
---@param cvar string? a console variable's name, in any case
---@return boolean
function Options.Watches(names, cvar)
	if type(cvar) ~= "string" then
		return false
	end

	cvar = cvar:lower()

	for _, name in ipairs(names) do
		if name:lower() == cvar then
			return true
		end
	end

	return false
end
