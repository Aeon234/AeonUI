local AUI = select(2, ...)

local lib = LibStub("LibAeonSettings-1.0")

local ADDON_NAME = ...

---AeonUI's frames in LibAeonSettings' edit mode. Positions are kept in the active profile, one setting per frame.
---@class AUIEditTargets
---@field registration table?
local EditTargets = {}
AUI.EditTargets = EditTargets

-- Each target's position setting, by key.
local PATHS = {
	minimap = "minimap.position",
	tooltip = "tooltip.position",
	notifications = "notifications.position",
}

---@return table[] targets the frames that exist this session, in the library's form
function EditTargets:Targets()
	local targets = {}
	local minimap = AUI.Minimap

	if minimap.active then
		targets[#targets + 1] = {
			key = "minimap",
			label = MINIMAP_LABEL,
			frame = minimap.holder,
			default = minimap.DEFAULT_POSITION,
			settings = { page = "minimap", section = "map" },
		}
	end

	local Anchor = AUI.TooltipAnchor

	-- A tooltip riding the cursor has no place to move.
	if AUI.Tooltip.active and not Anchor:Cursor() then
		targets[#targets + 1] = {
			key = "tooltip",
			label = AUI.L["Tooltip"],
			frame = Anchor:Box(),
			default = Anchor:DefaultPosition(),
			settings = { page = "tooltipGeneral", section = "tooltipPlace" },
			place = function(position)
				Anchor:Place(position)
			end,
		}
	end

	local Notifications = AUI.Notifications

	if Notifications.active then
		targets[#targets + 1] = {
			key = "notifications",
			label = AUI.L["Notifications"],
			frame = Notifications:Frame(),
			default = Notifications:DefaultPosition(),
			fixedEdge = "TOP",
			sample = function(shown)
				Notifications:Sample(shown)
			end,
			settings = { page = "notifications", section = "notificationsStyle" },
		}
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
			local path = PATHS[key]

			return path and AUI.Profile:Get(path)
		end,
		set = function(key, position)
			local path = PATHS[key]

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

---Places every target at its position again, after a profile change or a size change.
function EditTargets:Apply()
	if self.registration then
		self.registration:Apply()
	end
end
