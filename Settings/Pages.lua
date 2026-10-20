local AUI = select(2, ...)

---Page element builders shared by the settings pages.
---@class AUISettingsPages
local Pages = {}
AUI.SettingsPages = Pages

---@param setting table
---@param fields table?
---@return table setting
function Pages.Merge(setting, fields)
	for key, value in pairs(fields or {}) do
		setting[key] = value
	end

	return setting
end

---@param id string
---@param title string
---@param fields table?
---@return table element
function Pages.Section(id, title, fields)
	return Pages.Merge({ kind = "section", id = id, title = title }, fields)
end

---@param left table
---@param right table?
---@return table element
function Pages.Row(left, right)
	if right then
		return { kind = "setting", settings = { left, right } }
	end

	return { kind = "setting", setting = left }
end
