local AUI = select(2, ...)

local Options = AUI.UnitFrameOptions

-- Estimated width of each content at size 12, in UI units. Secret names cannot be measured, so slots that share a
-- row divide the bar by these estimates instead.
local ESTIMATES = {
	name = 110,
	level = 20,
	levelName = 130,
	health = 40,
	healthPercent = 36,
	healthAndPercent = 80,
	missingHealth = 40,
	absorb = 40,
	healAbsorb = 40,
	power = 40,
	powerPercent = 36,
}

-- Space kept between slots that share a row.
local GAP = 8

-- Contents that show health, and so can carry the frame's status.
local HEALTH_CONTENTS = { health = true, healthPercent = true, healthAndPercent = true, missingHealth = true }

-- The Status Line's inset from the bar's right edge.
local STATUS_INSET = 4

---@class AUITextSlot
---@field content string
---@field separator string
---@field anchor string
---@field placement string
---@field x number
---@field y number
---@field width number percent of the space the slot is given
---@field colorMode string
---@field font string
---@field size number
---@field outline string
---@field color table

---Text slots on a unit frame: where each sits, how wide it may grow, its style, and its oUF tag.
---@class AUIText
local Text = {}
AUI.Text = Text

---@param anchor string one of the nine points
---@return string vertical "TOP", "BOTTOM" or ""
---@return string horizontal "LEFT", "RIGHT" or ""
local function Split(anchor)
	local vertical = anchor:match("^TOP") or anchor:match("^BOTTOM") or ""
	local horizontal = anchor:match("LEFT$") or anchor:match("RIGHT$") or ""

	return vertical, horizontal
end

---@param point string
---@return string point "CENTER" for an empty point
local function Point(point)
	return point ~= "" and point or "CENTER"
end

---Where a slot attaches: the text's point, the bar's point, and the text's justification.
---@param anchor string one of the nine points on the bar
---@param placement string "inside", "edge" (centered on the bar's edge) or "outside" (past the edge)
---@return string point
---@return string relativePoint
---@return string justify
function Text:Points(anchor, placement)
	local vertical, horizontal = Split(anchor)
	local justify = horizontal ~= "" and horizontal or "CENTER"

	if placement == "edge" and vertical ~= "" then
		return Point(horizontal), anchor, justify
	end

	if placement == "outside" then
		if vertical == "TOP" then
			return Point("BOTTOM" .. horizontal), anchor, justify
		end

		if vertical == "BOTTOM" then
			return Point("TOP" .. horizontal), anchor, justify
		end

		if horizontal == "LEFT" then
			return "RIGHT", anchor, "RIGHT"
		end

		if horizontal == "RIGHT" then
			return "LEFT", anchor, "LEFT"
		end
	end

	return anchor, anchor, justify
end

---@param slot AUITextSlot
---@return string row slots in the same row share the bar's width
local function Row(slot)
	local vertical, horizontal = Split(slot.anchor)
	local placement = slot.placement

	if vertical == "" then
		if placement == "outside" and horizontal ~= "" then
			return "side:" .. horizontal
		end

		return "middle"
	end

	return vertical .. ":" .. (placement == "inside" and "inside" or placement)
end

---@param slot AUITextSlot
---@return number estimate
local function Estimate(slot)
	return (ESTIMATES[slot.content] or 0) * slot.size / 12
end

---The width each slot may use. A slot alone in its row gets most of the bar; slots sharing a row split it, each
---leaving room for the others' estimated content. Width % then scales the result.
---@param slots AUITextSlot[] resolved slots; a slot with content "none" takes no space
---@param barWidth number
---@return number[] widths by slot index
function Text:Widths(slots, barWidth)
	local rows = {}

	for index, slot in ipairs(slots) do
		if slot.content ~= "none" then
			local row = Row(slot)

			rows[row] = rows[row] or {}
			rows[row][#rows[row] + 1] = index
		end
	end

	local widths = {}

	for index, slot in ipairs(slots) do
		local width = 0

		if slot.content ~= "none" then
			local members = rows[Row(slot)]
			local _, horizontal = Split(slot.anchor)
			local available = barWidth * (horizontal == "" and 0.9 or 0.95)

			if #members > 1 then
				local others = 0

				for _, other in ipairs(members) do
					if other ~= index then
						others = others + Estimate(slots[other]) + GAP
					end
				end

				available = math.max(barWidth - others, Estimate(slot))
			end

			width = math.max(available * slot.width / 100, 1)
		end

		widths[index] = width
	end

	return widths
end

---@param key string
---@param index integer
---@return AUITextSlot slot
function Text:Resolve(key, index)
	---@type AUITextSlot
	local slot = {}

	for _, field in ipairs({ "content", "separator", "anchor", "placement", "x", "y", "width", "colorMode", "font",
		"size", "outline", "color" }) do
		slot[field] = AUI.Profile:Get(Options:SlotPath(key, index, field))
	end

	return slot
end

---How far a frame's text reaches past its top and bottom: half a line for a slot on an edge, a whole line for one outside
---it, moved by its vertical offset. Empty slots reach nowhere.
---@param key string
---@return number above
---@return number below
function Text:Overhang(key)
	local above, below = 0, 0
	local spec = Options:Spec(key) --[[@as AUIFrameSpec]]

	for index = 1, spec.slots do
		local slot = self:Resolve(key, index)
		local vertical = Split(slot.anchor)

		if slot.content ~= "none" and slot.placement ~= "inside" and vertical ~= "" then
			local reach = slot.placement == "edge" and slot.size / 2 or slot.size

			if vertical == "TOP" then
				above = math.max(above, reach + slot.y)
			else
				below = math.max(below, reach - slot.y)
			end
		end
	end

	return above, below
end

---Resolves every slot of a frame and works out what each needs: its width and its tag context.
---@param key string the frame's key under `frames`
---@param count integer the frame's slot count
---@return AUITextSlot[] slots
---@return number[] widths
---@return AUITextContext[] contexts
function Text:Layout(key, count)
	local Profile = AUI.Profile
	local slots, contexts = {}, {}
	local status = Profile:Get(Options:Path(key, "text.status"))
	local nameFormat = Profile:Get(Options:Path(key, "text.nameFormat"))
	local precision = Profile:Get(Options:Path(key, "numbers.precision"))
	local decimals = Profile:Get(Options:Path(key, "numbers.percentDecimals"))

	for index = 1, count do
		slots[index] = self:Resolve(key, index)
		contexts[index] = {
			primary = index == status,
			precision = precision,
			decimals = decimals,
			nameFormat = nameFormat,
		}
	end

	local left, right = AUI.Portrait:Inset(key)

	return slots, self:Widths(slots, Profile:Get(Options:Path(key, "width")) - left - right), contexts
end

---@param slot AUITextSlot
---@return boolean middle the slot sits in the bar's middle row, where the Status Line also sits
function Text:InMiddleRow(slot)
	return slot.content ~= "none" and Row(slot) == "middle"
end

---Whether a frame shows its Status Line: it has one, the setting is on and no slot carries the status.
---@param key string
---@return boolean
function Text:NeedsStatusLine(key)
	local Profile = AUI.Profile
	local spec = Options:Spec(key)

	if not spec or not spec.statusLine or Profile:Get(Options:Path(key, "text.statusLine")) ~= true then
		return false
	end

	local status = Profile:Get(Options:Path(key, "text.status"))

	if status == 0 then
		return true
	end

	return not HEALTH_CONTENTS[Profile:Get(Options:SlotPath(key, status, "content"))]
end

---Creates a frame's slots' font strings on a layer above its bar, and its Status Line when asked.
---@param frame table the unit frame, or a preview's holder
---@param bar StatusBar the bar the text sits on
---@param count integer
---@param statusLine boolean? the frame can show a Status Line
function Text:Create(frame, bar, count, statusLine)
	local layer = CreateFrame("Frame", nil, bar)

	layer:SetAllPoints(bar)
	layer:SetFrameLevel(bar:GetFrameLevel() + AUI.UnitFrame.TEXT_LEVEL)

	local strings = {}

	for index = 1, count do
		local text = layer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")

		text:SetWordWrap(false)
		text:Hide()
		strings[index] = text
	end

	frame.TextLayer = layer
	frame.TextSlots = strings

	if statusLine then
		local line = layer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")

		line:SetWordWrap(false)
		line:SetJustifyH("RIGHT")
		line:Hide()
		frame.StatusLine = line
	end
end

---Shortens the middle-row slots by the Status Line's width while it shows a status, and restores them otherwise.
---Status labels are AeonUI's own strings, never secret, so the line can be measured.
---@param frame table made by `Text:Create`
function Text:FitStatusLine(frame)
	local line = frame.StatusLine
	local label = line:IsShown() and line:GetText()
	local room = 0

	if label and label ~= "" then
		room = line:GetUnboundedStringWidth() + GAP
	end

	for index in pairs(frame.middleSlots or {}) do
		frame.TextSlots[index]:SetWidth(math.max(frame.slotWidths[index] - room, 1))
	end
end

---Styles a Status Line like the frame's text and places it at the right of the bar, inside.
---@param line FontString
---@param bar Region
---@param key string
function Text:PlaceStatusLine(line, bar, key)
	local Profile = AUI.Profile
	local color = Profile:Get(Options:Path(key, "text.color"))

	line:SetFont(AUI.Media:Font(Profile:Get(Options:Path(key, "text.font"))), Profile:Get(Options:Path(key, "text.size")),
		AUI.Media:FontFlags(Profile:Get(Options:Path(key, "text.outline"))))
	line:SetTextColor(color.r, color.g, color.b)
	line:ClearAllPoints()
	line:SetPoint("RIGHT", bar, "RIGHT", -STATUS_INSET, 0)
end

---Shows or hides a frame's Status Line, tagged with the unit's status, and fits the middle-row slots around it.
---@param frame table a unit frame made by `Text:Create`
---@param key string
function Text:ApplyStatusLine(frame, key)
	local line = frame.StatusLine

	if not line then
		return
	end

	frame:Untag(line)

	if not self:NeedsStatusLine(key) then
		line:SetText("")
		line:Hide()
		self:FitStatusLine(frame)

		return
	end

	self:PlaceStatusLine(line, frame.Bar, key)
	frame:Tag(line, "[aui:status]")

	local update = line.UpdateTag

	line.UpdateTag = function(fontString)
		update(fontString)
		Text:FitStatusLine(frame)
	end

	line:Show()

	if frame:IsVisible() then
		line:UpdateTag()
	end
end

---Draws a still Status Line for a preview: the label while it needs one, nothing otherwise.
---@param preview table made by `Text:Create`
---@param key string
---@param label string? the sample's status
---@return boolean shown
function Text:DrawStatusSample(preview, key, label)
	local line = preview.StatusLine
	local shown = line ~= nil and label ~= nil and self:NeedsStatusLine(key)

	if line then
		if shown then
			self:PlaceStatusLine(line, preview.bar, key)
			line:SetText(label)
		end

		line:SetShown(shown)
		self:FitStatusLine(preview)
	end

	return shown
end

---Styles a slot's font string and places it on its bar.
---@param text FontString
---@param bar Region
---@param slot AUITextSlot
---@param width number
function Text:Place(text, bar, slot, width)
	local point, relativePoint, justify = self:Points(slot.anchor, slot.placement)
	local color = slot.color

	text:SetFont(AUI.Media:Font(slot.font), slot.size, AUI.Media:FontFlags(slot.outline))
	text:SetTextColor(color.r, color.g, color.b)
	text:SetJustifyH(justify)
	text:SetWidth(width)
	text:ClearAllPoints()
	text:SetPoint(point, bar, relativePoint, slot.x, slot.y)
end

---Applies every slot's settings to a frame: style, place, width and tag. Text is not protected, so this also runs
---in combat.
---@param frame table a unit frame made by `Text:Create`
---@param key string the frame's key under `frames`
function Text:Apply(frame, key)
	local slots, widths, contexts = self:Layout(key, #frame.TextSlots)

	frame.slotWidths = widths
	frame.middleSlots = {}

	for index, slot in ipairs(slots) do
		local text = frame.TextSlots[index]
		local tags = AUI.Tags:Compile(slot, contexts[index])

		frame:Untag(text)

		if tags then
			if self:InMiddleRow(slot) then
				frame.middleSlots[index] = true
			end

			self:Place(text, frame.Bar, slot, widths[index])
			frame:Tag(text, tags)
			text:Show()

			if frame:IsVisible() then
				text:UpdateTag()
			end
		else
			text:SetText("")
			text:Hide()
		end
	end

	self:ApplyStatusLine(frame, key)
end
