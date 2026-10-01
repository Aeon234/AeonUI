local AUI = select(2, ...)

local Schema = AUI.Schema

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

---Resolves a slot's settings, filling its style from the frame's text style where the slot has none of its own.
---@param config table the active profile config
---@param unit string
---@param index integer
---@return AUITextSlot
function Text:Resolve(config, unit, index)
	local text = "frames." .. unit .. ".text."
	local base = text .. "slots." .. index .. "."
	---@type AUITextSlot
	local slot = {}

	for _, key in ipairs({ "content", "separator", "anchor", "placement", "x", "y", "width", "colorMode" }) do
		slot[key] = Schema:Read(config, base .. key)
	end

	for _, key in ipairs({ "font", "size", "outline", "color" }) do
		local own = Schema:Read(config, base .. key)

		if own == nil then
			own = Schema:Read(config, text .. key)
		end

		slot[key] = own
	end

	return slot
end

---@param config table
---@param unit string
---@param path string a path under `numbers.`
---@return any value the frame's own number setting, else the shared one
local function NumberSetting(config, unit, path)
	local own = Schema:Read(config, "frames." .. unit .. ".numbers." .. path)

	if own == nil then
		return Schema:Read(config, "numbers." .. path)
	end

	return own
end

---Creates the font strings for a frame's slots, on a layer above its bar.
---@param frame table the unit frame
---@param bar StatusBar the bar the text sits on
---@param count integer how many slots the frame has
function Text:Create(frame, bar, count)
	local layer = CreateFrame("Frame", nil, frame)

	layer:SetAllPoints(bar)
	layer:SetFrameLevel(bar:GetFrameLevel() + 5)

	local strings = {}

	for index = 1, count do
		local text = layer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")

		text:SetWordWrap(false)
		text:Hide()
		strings[index] = text
	end

	frame.TextLayer = layer
	frame.TextSlots = strings
end

---Resolves every slot of a frame and works out what each needs: its width and its tag context.
---@param config table the active profile config
---@param key string the frame's key under `frames`
---@param count integer the frame's slot count
---@return AUITextSlot[] slots
---@return number[] widths
---@return AUITextContext[] contexts
function Text:Layout(config, key, count)
	local slots, contexts = {}, {}

	for index = 1, count do
		slots[index] = self:Resolve(config, key, index)
	end

	local base = "frames." .. key
	local status = Schema:Read(config, base .. ".text.status")
	local nameFormat = Schema:Read(config, base .. ".text.nameFormat")
	local precision = NumberSetting(config, key, "precision")
	local decimals = NumberSetting(config, key, "percentDecimals")

	for index = 1, count do
		contexts[index] = {
			primary = index == status,
			precision = precision,
			decimals = decimals,
			nameFormat = nameFormat,
		}
	end

	return slots, self:Widths(slots, Schema:Read(config, base .. ".width")), contexts
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
---@param config table the active profile config
function Text:Apply(frame, key, config)
	local slots, widths, contexts = self:Layout(config, key, #frame.TextSlots)

	for index, slot in ipairs(slots) do
		local text = frame.TextSlots[index]
		local tags = AUI.Tags:Compile(slot, contexts[index])

		frame:Untag(text)

		if tags then
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
end
