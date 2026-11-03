local AUI = select(2, ...)

local lib = LibStub("LibAeonSettings-1.0")

local ADDON_NAME = ...

---AeonUI's frames in LibAeonSettings' edit mode. Positions are kept in the active profile, one setting per frame.
---@class AUIEditTargets
---@field registration table?
local EditTargets = {}
AUI.EditTargets = EditTargets

---@return table[] targets the frames that exist this session, in the library's form
function EditTargets:Targets()
	local targets = {}

	for _, module in ipairs(AUI.Modules.list) do
		for _, editTarget in ipairs(module.editTargets or {}) do
			local target = editTarget.target()

			if target then
				target.key = editTarget.key
				targets[#targets + 1] = target
			end
		end
	end

	return targets
end

function EditTargets:Register()
	if self.registration or AUI.failed then
		return
	end

	self.registration = lib:Placement(ADDON_NAME, {
		title = AUI.brand,
		get = function(key)
			local path = AUI.Modules.paths[key]

			return path and AUI.Profile:Get(path)
		end,
		set = function(key, position)
			local path = AUI.Modules.paths[key]

			if path then
				AUI.Profile:Set(path, position)
			end
		end,
		account = function()
			return AUI.Profile:Global()
		end,
		targets = function()
			return EditTargets:Targets()
		end,
	})
end

---Opens edit mode; the library refuses in combat and waits for Blizzard's panels to close.
function EditTargets:Open()
	lib:OpenEditMode(ADDON_NAME)
end

---Places every target at its position again, after a profile change or a size change.
function EditTargets:Apply()
	if self.registration then
		self.registration:Apply()
	end
end
