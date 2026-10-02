-- Preview panel: a real-size sample of the page's settings, pinned above the page list, with click to find.
local _, ns = ...
local AS = ns.AeonSettings
local L = AS.L
local tokens = AS.tokens

local SLOT_GAP = 10 -- state selector to plus/minus
local HINT_GAP = 12 -- hint to state selector
local HINT_SIZE = 11
local HINT_ALPHA = 0.45
local ROOM_SIDE = 20
local ROOM_VERTICAL = 10
local TEXT_HIT_PAD = 2
local DEFAULT_MIN_ROWS = 5
local DEFAULT_MAX_ROWS = 7
local HIT_LAYER_OFFSET = 100 -- hit areas stay above any frame the sample draws

---A page's preview definition.
---@class AeonSettingsPreview
---@field Draw fun(sample: Frame, state: string?, addPart: fun(region: Region, settingID: string, isText: boolean?, key: any?)): number, number
---Draws the sample into `sample` at real size and returns its width and height in UI units. It runs again
---after every save and redraw on the same `sample`, so it reuses its regions rather than creating new ones.
---`addPart` makes a region clickable to find its setting; parts added later take precedence where they
---overlap. `key` names the part for `Pick` and `window:SetPreviewChosen`; it defaults to `settingID`.
---@field minRows integer? smallest panel height in rows, title band included
---@field maxRows integer? largest panel height in rows
---@field states string[]? sample states, first is the default
---@field stateKey string? pages sharing a key share the selected state
---@field Pick fun(key: any)? called with a part's key when the part is clicked, before its setting is found
---@field Stop fun()? stops any animation the sample runs; called when the sample state changes, the body hides,
---the page changes and the window hides

---@class AeonSettingsPreviewPanel : Frame
AeonUISettings_PreviewPanelMixin = {}

function AeonUISettings_PreviewPanelMixin:OnLoad()
	local band = self.Band
	self.bandSurface = AS:CreateSurface(band)
	self.bodySurface = AS:CreateSurface(self.Body)
	self.hits = {}
	self.activeHits = 0

	local titleCenter, toggleLift = AS:HeaderLayout()
	local inset = tokens.space.rowInset

	AS:SetFont(band.Title, "header")
	band.Title:SetTextColor(unpack(tokens.color.sectionTitle))
	band.Title:SetText(L["Preview"])
	-- Regions declared without anchors fill their parent; clear that before placing them.
	band.Title:ClearAllPoints()
	band.Title:SetPoint("LEFT", band, "TOPLEFT", inset, -titleCenter)
	AS:CreateHeaderBar(band, band.Title)

	band.Toggle:ClearAllPoints()
	band.Toggle:SetPoint("RIGHT", band, "TOPRIGHT", -inset, -titleCenter + toggleLift)
	band.StateSlot:SetPoint("RIGHT", band.Toggle, "LEFT", -SLOT_GAP, -toggleLift)

	AS:SetFont(band.Hint, "body", HINT_SIZE)
	band.Hint:SetTextColor(1, 1, 1, HINT_ALPHA)
	band.Hint:SetText(L["Click part of the preview to find its setting"])
	self.toggleLift = toggleLift

	local states = CreateFrame("Frame", nil, band.StateSlot, "AeonUISettings_DropdownTemplate")
	states:SetPoint("CENTER")
	states.onRequest = function(value)
		self.window:SetPreviewState(value)
	end
	self.states = states

	band:SetHitRectInsets(0, 0, tokens.space.sectionGap, 0)
	band:SetScript("OnClick", function()
		self.window:SetPreviewHidden(not self.hidden)
	end)

	local room = self.Body.Room
	room:SetPoint("TOPLEFT", ROOM_SIDE, -ROOM_VERTICAL)
	room:SetPoint("BOTTOMRIGHT", -ROOM_SIDE, ROOM_VERTICAL)
end

---Shows the panel for a page and returns its height, which the page list gives up.
---@param window table
---@param page table
---@param hidden boolean the body is hidden: the panel is its title band alone
---@param state string?
---@param faded boolean the page's switch is off
---@param availableRows integer rows the panel may take at most
---@return number height
function AeonUISettings_PreviewPanelMixin:Setup(window, page, hidden, state, faded, availableRows)
	local row = tokens.size.row
	local band = self.Band
	self.window = window
	self.hidden = hidden

	band.Toggle:SetAtlas(hidden and "common-button-list-plus" or "common-button-list-minus",
		TextureKitConstants.UseAtlasSize)
	band.Hint:SetShown(not hidden)
	band.StateSlot:SetShown(not hidden)
	self:Show()

	local stateNames = page.preview.states
	self.states:SetShown(stateNames ~= nil)

	-- The hint sits left of the state selector, or of the plus/minus when the page has no states; both on the
	-- title's center line.
	band.Hint:ClearAllPoints()
	if stateNames then
		band.Hint:SetPoint("RIGHT", band.StateSlot, "LEFT", -HINT_GAP, 0)
	else
		band.Hint:SetPoint("RIGHT", band.Toggle, "LEFT", -HINT_GAP, -self.toggleLift)
	end
	if stateNames then
		local options = {}
		for _, name in ipairs(stateNames) do
			options[#options + 1] = { value = name, text = name }
		end
		self.states:Configure({ options = options, width = "fit" })
		self.states:SetChecked(state, true)
		band.StateSlot:SetWidth(self.states:GetWidth())
	end

	if hidden then
		self.bandSurface:SetShape("CLOSED_HEADER")
		self.Body:Hide()
		self:ReleaseHits()
		self:SetHeight(row)

		return row
	end

	self.bandSurface:SetShape("HEADER")
	self.Body:Show()

	local preview = page.preview
	local sample = self.Body.Sample
	self:ReleaseHits()
	sample:SetScale(1)
	-- A Draw that raises an error returns no size: the sample is 1 by 1 at the minimum rows.
	self.page = page
	local width, height = AS:CallHost(nil, preview.Draw, sample, state, function(region, settingID, isText, key)
		self:AddPart(region, settingID, isText, key)
	end)
	width, height = math.max(width or 1, 1), math.max(height or 1, 1)

	local extra = row + ROOM_VERTICAL * 2 + tokens.space.sectionGap
	local roomWidth = self:GetWidth() - ROOM_SIDE * 2
	local scale = math.min(UIParent:GetEffectiveScale() / self.Body:GetEffectiveScale(), roomWidth / width)
	local maxRows = math.min(preview.maxRows or DEFAULT_MAX_ROWS, availableRows)
	local minRows = math.min(preview.minRows or DEFAULT_MIN_ROWS, maxRows)
	local rows = Clamp(math.ceil((extra + height * scale) / row), minRows, maxRows)
	scale = math.min(scale, (rows * row - extra) / height)

	local panelHeight = rows * row
	self:SetHeight(panelHeight)
	local bodyHeight = panelHeight - row - tokens.space.sectionGap
	self.Body:SetHeight(bodyHeight)
	self.bodySurface:SetShape("BODY", bodyHeight)

	sample:SetScale(scale)
	sample:SetSize(width, height)
	sample:ClearAllPoints()
	sample:SetPoint("CENTER", self.Body.Room, "CENTER")
	sample:SetAlpha(faded and tokens.alpha.inactive or 1)

	local hits = self.Body.Hits
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
	local layer = self.Body.Hits
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
