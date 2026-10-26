local AUI = select(2, ...)

local Options = AUI.TooltipOptions

-- Where the box sits before Blizzard's container has a place, and while it has none.
local FALLBACK_POSITION = { point = "BOTTOMRIGHT", x = -100, y = 100 }

---@param tooltip table
---@return boolean global `GameTooltip`, or a stand-in that asks to be treated as it
local function GlobalLike(tooltip)
	return tooltip == GameTooltip or (type(tooltip) == "table" and tooltip.LIKE_GLOBAL_GAMETOOLTIP == true)
end

---@param owner table?
---@return boolean usable an owner a tooltip can be anchored to: not forbidden
local function Usable(owner)
	if not owner then
		return false
	end

	local IsForbidden = owner.IsForbidden

	return not (type(IsForbidden) == "function" and IsForbidden(owner))
end

---Where default-anchored tooltips sit: Blizzard's place, AeonUI's own place (a box moved in edit mode), or riding
---the cursor; and which way they grow. Each runs after `GameTooltip_SetDefaultAnchor`, the path every
---default-anchored tooltip takes; a tooltip anchored by its owner is left alone. Blizzard's container can anchor the
---tooltip again a few frames after it shows without clearing its points, so while a default-anchored `GameTooltip`
---shows, any point that is not AeonUI's is replaced. Values a `SetPoint` hook receives may be secret, so the hook reads
---none of them. Also writes Blizzard's Enhanced Tooltips setting when its checkbox is changed.
---@class AUITooltipAnchor
---@field hooked boolean
---@field box Frame? the box default-anchored tooltips are pinned inside while AeonUI places them
---@field cursor Frame? a point that follows the cursor while a tooltip rides it
---@field armed boolean `GameTooltip` was anchored by default, so its points are kept
---@field enforcing boolean AeonUI is setting the points itself
local Anchor = {
	hooked = false,
	armed = false,
	enforcing = false,
}
AUI.TooltipAnchor = Anchor

---@return boolean
function Anchor:Cursor()
	return AUI.Tooltip:IsEnabled() and AUI.Profile:Get(Options.CURSOR_PATH) == true
end

---@return boolean fixed AeonUI places default-anchored tooltips: a place was saved and they do not ride the cursor
function Anchor:Fixed()
	return AUI.Tooltip:IsEnabled() and not self:Cursor() and AUI.Profile:Get(Options.POSITION_PATH) ~= nil
end

---@return Frame box
function Anchor:Box()
	local box = self.box

	if not box then
		box = CreateFrame("Frame", "AeonUITooltipAnchor", UIParent)
		box:SetSize(Options.ANCHOR_WIDTH, Options.ANCHOR_HEIGHT)
		box:EnableMouse(false)
		self.box = box
		self:Place(AUI.Profile:Get(Options.POSITION_PATH) or self:DefaultPosition())
	end

	return box
end

---@param position { point: string, x: number, y: number }
function Anchor:Place(position)
	local box = self:Box()

	box:ClearAllPoints()
	box:SetPoint(position.point, UIParent, position.point, position.x, position.y)
end

---@return { point: string, x: number, y: number } position where Blizzard's container puts the tooltip now
function Anchor:DefaultPosition()
	local container = GameTooltipDefaultContainer
	local left, bottom = container and container:GetLeft(), container and container:GetBottom()

	if not left or not bottom then
		return FALLBACK_POSITION
	end

	local scale = container:GetEffectiveScale() / UIParent:GetEffectiveScale()

	return Options:ContainerPosition(left * scale, bottom * scale, container:GetWidth() * scale,
		container:GetHeight() * scale, UIParent:GetWidth(), UIParent:GetHeight())
end

---@return Frame cursor at the cursor now
function Anchor:FollowCursor()
	local cursor = self.cursor

	if not cursor then
		cursor = CreateFrame("Frame", "AeonUITooltipCursor", UIParent)
		cursor:SetSize(1, 1)
		cursor:SetFrameStrata("TOOLTIP")
		cursor:Hide()
		-- Runs only while a tooltip rides the cursor; hidden with it.
		cursor:SetScript("OnUpdate", function(frame)
			Anchor:MoveCursor(frame)
		end)
		self.cursor = cursor
	end

	cursor:Show()
	self:MoveCursor(cursor)

	return cursor
end

---@param cursor Frame
function Anchor:MoveCursor(cursor)
	local scale = UIParent:GetEffectiveScale()

	if scale <= 0 then
		return
	end

	local x, y = GetCursorPosition()

	cursor:ClearAllPoints()
	cursor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end

---Keeps a default-anchored `GameTooltip` on AeonUI's point: the box's corner, or Blizzard's own corner turned to the
---growth direction. Points written by restricted code read back secret; they are never AeonUI's, so they are replaced
---in the box and skipped otherwise.
---@param tooltip table
function Anchor:Enforce(tooltip)
	if tooltip:IsForbidden() then
		return
	end

	local point, relativeTo, _, x, y = tooltip:GetPoint(1)
	local secret = issecretvalue(point) or issecretvalue(relativeTo) or issecretvalue(x) or issecretvalue(y)
	local growth = AUI.Profile:Get(Options.GROWTH_PATH)
	local wanted, target

	if self:Fixed() then
		local box = self:Box()
		local left, bottom = box:GetLeft(), box:GetBottom()

		target = box
		wanted = Options:FixedCorner(
			left and (left + Options.ANCHOR_WIDTH / 2 - UIParent:GetWidth() / 2) or 1,
			bottom and (bottom + Options.ANCHOR_HEIGHT / 2 - UIParent:GetHeight() / 2) or -1, growth)
		x, y = 0, 0
	elseif growth ~= "DEFAULT" and AUI.Tooltip:IsEnabled() and not secret and point then
		target = relativeTo or GameTooltipDefaultContainer
		wanted = Options:GrowthPoint(point, growth)
	end

	if not wanted or not target or (not secret and tooltip:GetNumPoints() == 1 and point == wanted
		and relativeTo == target) then
		return
	end

	self.enforcing = true
	tooltip:ClearAllPoints()
	tooltip:SetPoint(wanted, target, wanted, x or 0, y or 0)
	self.enforcing = false
end

---@param tooltip table
---@param owner table?
function Anchor:OnDefaultAnchor(tooltip, owner)
	if not GlobalLike(tooltip) or not AUI.Tooltip:IsEnabled() or tooltip:IsForbidden() then
		return
	end

	-- Nothing can be anchored to a forbidden owner, such as a nameplate's aura button.
	if not Usable(owner) then
		self.armed = false

		return
	end

	if self:Cursor() then
		local Profile = AUI.Profile
		local point = Options:CursorPoint(Profile:Get(Options.CURSOR_POINT_PATH))

		tooltip:ClearAllPoints()
		tooltip:SetPoint(point, self:FollowCursor(), "CENTER", Profile:Get(Options.CURSOR_X_PATH),
			Profile:Get(Options.CURSOR_Y_PATH))

		return
	end

	-- Only `GameTooltip`'s own setters are hooked, so only it is kept on its point afterwards.
	self.armed = tooltip == GameTooltip
	self:Enforce(tooltip)
end

---@return boolean on Blizzard's Enhanced Tooltips setting
function Anchor:Enhanced()
	return C_CVar.GetCVarBool("UberTooltips") == true
end

---Writes Blizzard's Enhanced Tooltips setting; it belongs to the game, so profiles never hold it.
---@param on boolean
function Anchor:SetEnhanced(on)
	C_CVar.SetCVar("UberTooltips", on and "1" or "0")
end

---Installs the anchoring hooks once; they do nothing while the module is off.
function Anchor:Hook()
	if self.hooked or not GameTooltip or not GameTooltip_SetDefaultAnchor then
		return
	end

	self.hooked = true

	hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, owner)
		Anchor:OnDefaultAnchor(tooltip, owner)
	end)
	-- Every tooltip build starts with SetOwner, before the default anchor's hook arms the points again, so a tooltip
	-- its owner anchors is never moved.
	hooksecurefunc(GameTooltip, "SetOwner", function()
		Anchor.armed = false
	end)
	hooksecurefunc(GameTooltip, "SetPoint", function(tooltip)
		if Anchor.armed and not Anchor.enforcing and tooltip == GameTooltip then
			Anchor:Enforce(tooltip)
		end
	end)
	GameTooltip:HookScript("OnHide", function()
		if Anchor.cursor then
			Anchor.cursor:Hide()
		end
	end)

	-- A world unit's tooltip fades for a moment after the cursor leaves; riding the cursor, it would trail behind.
	if GameTooltip.FadeOut then
		hooksecurefunc(GameTooltip, "FadeOut", function(tooltip)
			if tooltip == GameTooltip and Anchor:Cursor() then
				tooltip:Hide()
			end
		end)
	end
end

---@param on boolean the module is on
function Anchor:Apply(on)
	if not on and self.cursor then
		self.cursor:Hide()
	end

	if self.box then
		self:Place(AUI.Profile:Get(Options.POSITION_PATH) or self:DefaultPosition())
	end
end
