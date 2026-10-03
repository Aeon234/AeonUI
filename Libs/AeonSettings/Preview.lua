-- Preview panel: a real-size sample of the page's settings, under the page's tabs, with click to find.
local _, ns = ...
local AS = ns.AeonSettings
local L = AS.L
local tokens = AS.tokens

local HINT_TOP = 6 -- the hint's top below the panel's
local ROOM_VERTICAL = 12 -- kept clear above and below the sample
local MIN_HEIGHT = 96
local MAX_HEIGHT = 240
local TEXT_HIT_PAD = 2
local HIT_LAYER_OFFSET = 100 -- hit areas stay above any frame the sample draws

---A page's preview definition.
---@class AeonSettingsPreview
---@field Draw fun(sample: Frame, state: string?, addPart: fun(region: Region, settingID: string, isText: boolean?, key: any?)): number, number
---Draws the sample into `sample` at real size and returns its width and height in UI units. It runs again
---after every save and redraw on the same `sample`, so it reuses its regions rather than creating new ones.
---`addPart` makes a region clickable to find its setting; parts added later take precedence where they
---overlap. `key` names the part for `Pick` and `window:SetPreviewChosen`; it defaults to `settingID`.
---@field states string[]? sample states; the panel draws the first, since it offers no state selector
---@field Pick fun(key: any)? called with a part's key when the part is clicked, before its setting is found
---@field Stop fun()? stops any animation the sample runs; called when the page changes and the window hides

---@class AeonSettingsPreviewPanel : Frame
AeonUISettings_PreviewPanelMixin = {}

function AeonUISettings_PreviewPanelMixin:OnLoad()
	self.hits = {}
	self.activeHits = 0

	local hint = self.Hint
	AS:SetFont(hint, "body", tokens.font.hintSize)
	hint:SetTextColor(1, 1, 1, tokens.alpha.description)
	hint:SetText(L["Click an element to find its settings"])
	-- Regions declared without anchors fill their parent; clear that before placing them.
	hint:ClearAllPoints()
	hint:SetPoint("TOPLEFT", 0, -HINT_TOP)

	self.Room:SetPoint("TOPLEFT", 0, -ROOM_VERTICAL)
	self.Room:SetPoint("BOTTOMRIGHT", 0, ROOM_VERTICAL)
end

---Shows the panel for a page and returns its height: the sample at real size plus the room above and below it,
---within the panel's limits; a sample still too large shrinks to fit.
---@param window table
---@param page table
---@param faded boolean the page's switch is off
---@return number height
function AeonUISettings_PreviewPanelMixin:Setup(window, page, faded)
	local preview = page.preview
	local sample = self.Sample
	self.window = window
	self.page = page
	self:Show()
	self:ReleaseHits()
	sample:SetScale(1)

	-- A Draw that raises an error returns no size: the sample is 1 by 1.
	local state = preview.states and preview.states[1]
	local width, height = AS:CallHost(nil, preview.Draw, sample, state, function(region, settingID, isText, key)
		self:AddPart(region, settingID, isText, key)
	end)
	width, height = math.max(width or 1, 1), math.max(height or 1, 1)

	local real = UIParent:GetEffectiveScale() / self:GetEffectiveScale()
	local panelHeight = Clamp(height * real + ROOM_VERTICAL * 2, MIN_HEIGHT, MAX_HEIGHT)
	local scale = math.min(real, (panelHeight - ROOM_VERTICAL * 2) / height)
	local roomWidth = self:GetWidth()
	if roomWidth > 0 then
		scale = math.min(scale, roomWidth / width)
	end
	self:SetHeight(panelHeight)

	sample:SetScale(scale)
	sample:SetSize(width, height)
	sample:ClearAllPoints()
	sample:SetPoint("CENTER", self.Room, "CENTER")
	sample:SetAlpha(faded and tokens.alpha.inactive or 1)

	local hits = self.Hits
	hits:SetScale(scale)
	hits:SetAllPoints(sample)
	hits:SetFrameLevel(sample:GetFrameLevel() + HIT_LAYER_OFFSET)

	return panelHeight
end

---Makes a sample region clickable: hovering outlines it, a click finds its setting. The chosen part keeps its
---outline.
---@param region Region
---@param settingID string
---@param isText boolean?
---@param key any? the part's name for `Pick` and the chosen outline; `settingID` when nil
function AeonUISettings_PreviewPanelMixin:AddPart(region, settingID, isText, key)
	local index = self.activeHits + 1
	local hit = self.hits[index]
	local layer = self.Hits
	if not hit then
		hit = CreateFrame("Button", nil, layer)
		hit:RegisterForClicks("LeftButtonUp")
		hit.outline = AS:CreateOutline(hit, tokens.color.flash)
		hit.outline:SetAllPoints()
		hit:SetScript("OnEnter", function()
			AS:ShowOutline(hit.outline)
		end)
		hit:SetScript("OnLeave", function()
			if hit.key == nil or hit.key ~= self.chosen then
				AS:HideOutline(hit.outline)
			end
		end)
		hit:SetScript("OnClick", function()
			local pick = self.page and self.page.preview and self.page.preview.Pick
			if pick then
				AS:CallHost(nil, pick, hit.key)
			end
			self.window:FindSetting(hit.settingID)
		end)
		self.hits[index] = hit
	end

	local pad = isText and TEXT_HIT_PAD or 0
	hit.settingID = settingID
	hit.key = key == nil and settingID or key
	hit:SetFrameLevel(layer:GetFrameLevel() + index * 2)
	hit.outline:SetFrameLevel(hit:GetFrameLevel() + 1)
	hit:ClearAllPoints()
	hit:SetPoint("TOPLEFT", region, "TOPLEFT", -pad, pad)
	hit:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", pad, -pad)
	hit:Show()
	self.activeHits = index
	if self.chosen ~= nil and hit.key == self.chosen then
		AS:ShowOutline(hit.outline)
	end
end

---Keeps the outline on the part with `key` until another part is chosen; nil chooses none.
---@param key any?
function AeonUISettings_PreviewPanelMixin:SetChosen(key)
	self.chosen = key
	for index = 1, self.activeHits do
		local hit = self.hits[index]
		if key ~= nil and hit.key == key then
			AS:ShowOutline(hit.outline)
		elseif not hit:IsMouseOver() then
			AS:HideOutline(hit.outline)
		end
	end
end

---Hides every hit area; they are reused by the next draw.
function AeonUISettings_PreviewPanelMixin:ReleaseHits()
	for _, hit in ipairs(self.hits) do
		AS:HideOutline(hit.outline)
		hit:Hide()
		hit:ClearAllPoints()
	end
	self.activeHits = 0
end
