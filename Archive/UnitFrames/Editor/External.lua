local AUI = select(2, ...)

local L = AUI.L
local Layout = AUI.EditorLayout

-- How long after login a loaded addon's frame may take to get a position before it counts as missing, in seconds.
local GRACE = 5

-- How long a burst of moves and resizes settles before the frames are measured again, in seconds.
local SETTLE = 0.2

---Measures other addons' frames that AeonUI's elements can snap, attach and match sizes to, and recalculates the
---profile when one moves, resizes or goes missing. The frames are hooked, never changed.
---@class AUIEditorExternal
---@field started number? when watching began
---@field hooked table<Frame, true>
---@field noted boolean the login note about waiting elements has been printed
local External = {
	hooked = {},
	noted = false,
}
AUI.EditorExternal = External

---@param a AUIExternalRect|false|nil
---@param b AUIExternalRect|false|nil
---@return boolean same
local function Same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end

	for _, key in ipairs({ "x", "y", "width", "height" }) do
		if math.abs(a[key] - b[key]) > 0.01 then
			return false
		end
	end

	return true
end

---@param frame Frame
---@return AUIExternalRect? rect the frame's rectangle in UIParent units, or nil while it has no position
local function Measure(frame)
	local left, bottom, width, height = frame:GetRect()

	if not left then
		return nil
	end

	local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()

	left, bottom, width, height = left * scale, bottom * scale, width * scale, height * scale

	return {
		x = left + width / 2 - UIParent:GetWidth() / 2,
		y = bottom + height / 2 - UIParent:GetHeight() / 2,
		width = width,
		height = height,
	}
end

function External:Queue()
	AUI.Events:Merge("editorExternal", SETTLE, function()
		self:Update()
	end)
end

---@param frame Frame
function External:Hook(frame)
	if self.hooked[frame] then
		return
	end

	self.hooked[frame] = true

	local queue = function()
		self:Queue()
	end

	hooksecurefunc(frame, "SetPoint", queue)
	hooksecurefunc(frame, "SetScale", queue)
	frame:HookScript("OnSizeChanged", queue)
end

---Measures every external target; a change recalculates the profile.
function External:Update()
	local changed = false
	local late = false

	for _, element in ipairs(Layout.EXTERNAL) do
		local frame = C_AddOns.IsAddOnLoaded(element.addon --[[@as string]]) and _G[element.global] or nil
		---@type AUIExternalRect|false|nil
		local rect = false

		if frame then
			self:Hook(frame)
			rect = Measure(frame)

			-- A loaded addon may still be placing its frame just after login.
			if not rect and GetTime() - (self.started or 0) < GRACE then
				rect, late = nil, true
			elseif not rect then
				rect = false
			end
		end

		if not Same(Layout.external[element.id], rect) then
			Layout.external[element.id] = rect
			changed = true
		end
	end

	if changed and AUI.Profile:CanEdit() then
		AUI.Profile:Recalculate()
	end

	if late then
		AUI.Events:Merge("editorExternalGrace", GRACE, function()
			self:Update()
		end)
	else
		self:Note()
	end
end

---Prints once per login which elements wait for a missing frame.
function External:Note()
	if self.noted or not AUI.Profile:CanEdit() then
		return
	end

	self.noted = true

	local config = AUI.Profile.config

	for _, element in ipairs(Layout.ELEMENTS) do
		local target = Layout:AttachTarget(config, element)

		if target and Layout:Waiting(config, element) then
			AUI:Print(L["%s waits to reconnect to %s. Open Edit Mode to reconnect or detach it."], Layout:Label(element),
				Layout:Label(target))
		end
	end
end

---Begins watching, once the saved settings have loaded.
function External:Start()
	if self.started then
		return
	end

	self.started = GetTime()

	for _, event in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "ADDON_LOADED" }) do
		AUI.Events:Register(event, self, self.Queue)
	end

	self:Queue()
end
