local AUI = select(2, ...)

local Schema = AUI.Schema

local L = AUI.L

---An element the layout editor places. Its position and size live under `frames.<key>.<base>`.
---@class AUIEditorElement
---@field id string stable identity
---@field key string the frame key
---@field base string "" or the cast bar's "castbar."
---@field page string the settings page that opens on right-click
---@field setting string? the setting revealed on that page
---@field group boolean? the boss frames, placed as one

-- Elements in the order the picker lists them.
---@type AUIEditorElement[]
local ELEMENTS = {
	{ id = "unit.player", key = "player", base = "", page = "player" },
	{ id = "unit.pet", key = "pet", base = "", page = "pet" },
	{ id = "unit.target", key = "target", base = "", page = "target" },
	{ id = "unit.targettarget", key = "targettarget", base = "", page = "targettarget" },
	{ id = "unit.focus", key = "focus", base = "", page = "focus" },
	{ id = "boss.group", key = "boss", base = "", page = "boss", group = true },
	{ id = "power.player", key = "playerPower", base = "", page = "playerPower" },
	{ id = "resource.player", key = "classPower", base = "", page = "classPower" },
	{ id = "cast.player", key = "player", base = "castbar.", page = "player", setting = "castEnabled" },
}

---The elements the layout editor places, and the arithmetic of placing them: sizes and positions from the profile,
---snapping and clamping. Coordinates are UIParent units: stored positions are center offsets from the screen's
---center, positive right and up; on-screen rectangles are left, bottom, width and height from the bottom left.
---@class AUIEditorLayout
---@field ELEMENTS AUIEditorElement[]
---@field SNAP_DISTANCE number how close a dragged edge or center comes to a line before it snaps
local Layout = {
	ELEMENTS = ELEMENTS,
	SNAP_DISTANCE = 8,
}
AUI.EditorLayout = Layout

---@param id string
---@return AUIEditorElement?
function Layout:Find(id)
	for _, element in ipairs(ELEMENTS) do
		if element.id == id then
			return element
		end
	end
end

---@param element AUIEditorElement
---@return string label
function Layout:Label(element)
	if element.base == "castbar." then
		return L["Player Cast Bar"]
	end

	if element.key == "classPower" then
		return L["Class Resource"]
	end

	return AUI.SettingsText:FrameTitle(element.key)
end

---@param element AUIEditorElement
---@param field string
---@return string path
function Layout:Path(element, field)
	return "frames." .. element.key .. "." .. element.base .. field
end

---@param config table
---@param element AUIEditorElement
---@return boolean shown the element is on, and placed on the screen rather than attached to another
function Layout:Shown(config, element)
	local frame = Schema:Read(config, "frames." .. element.key .. ".enabled") == true

	if element.base == "castbar." then
		return frame and Schema:Read(config, self:Path(element, "enabled")) == true
	end

	if element.key == "classPower" then
		return frame and Schema:Read(config, "frames.classPower.attach") == "screen"
	end

	return frame
end

---@param config table
---@param element AUIEditorElement
---@return number x the stored horizontal offset of the element's center (a group's first slot) from the screen's
---@return number y
function Layout:Position(config, element)
	return Schema:Read(config, self:Path(element, "x")), Schema:Read(config, self:Path(element, "y"))
end

---@param config table
---@param element AUIEditorElement
---@return number width the element's size on screen: a frame with its attached power bar, a group's every slot
---@return number height
---@return number shiftX the offset of that rectangle's center from the stored position
---@return number shiftY
function Layout:Size(config, element)
	local key = element.key

	if element.base == "castbar." then
		return Schema:Read(config, self:Path(element, "width")), Schema:Read(config, self:Path(element, "height")), 0, 0
	end

	if key == "classPower" then
		return Schema:Read(config, "frames.classPower.width"), AUI.ClassPower:Height(AUI.ClassPower:Resolve(config)), 0, 0
	end

	local width = Schema:Read(config, "frames." .. key .. ".width")
	local main, power = AUI.UnitFrame:Heights(config, key)
	local height = main + power

	if not element.group then
		return width, height, 0, 0
	end

	-- The first slot sits at the stored position; the group spans every slot's rectangle.
	local left, right, bottom, top = -width / 2, width / 2, -height / 2, height / 2

	for slot = 2, self:GroupCount() do
		local x, y = AUI.UnitFrame:SlotOffset(config, key, slot)

		left, right = math.min(left, x - width / 2), math.max(right, x + width / 2)
		bottom, top = math.min(bottom, y - height / 2), math.max(top, y + height / 2)
	end

	return right - left, top - bottom, (left + right) / 2, (bottom + top) / 2
end

---@return integer count the boss group's slots
function Layout:GroupCount()
	return MAX_BOSS_FRAMES or 5
end

---@param config table
---@param element AUIEditorElement
---@param screenWidth number
---@param screenHeight number
---@return number left the element's rectangle on screen
---@return number bottom
---@return number width
---@return number height
function Layout:Rect(config, element, screenWidth, screenHeight)
	local x, y = self:Position(config, element)
	local width, height, shiftX, shiftY = self:Size(config, element)

	return screenWidth / 2 + x + shiftX - width / 2, screenHeight / 2 + y + shiftY - height / 2, width, height
end

---@param config table
---@param element AUIEditorElement
---@param dx number
---@param dy number
---@return table<string, number> values the position, and an attached element's offsets, moved by the deltas, by path
function Layout:Moved(config, element, dx, dy)
	local x, y = self:Position(config, element)
	local values = { [self:Path(element, "x")] = x + dx, [self:Path(element, "y")] = y + dy }

	if self:AttachTarget(config, element) then
		local offsetX, offsetY = self:Offsets(config, element)

		values[self:Path(element, "layout.attach.x")] = offsetX + dx
		values[self:Path(element, "layout.attach.y")] = offsetY + dy
	end

	return values
end

-- Attachments and size links ----------------------------------------------------------------------------------

---@param config table
---@param element AUIEditorElement
---@return AUIEditorElement? target the element it is attached to
function Layout:AttachTarget(config, element)
	local id = Schema:Read(config, self:Path(element, "layout.attach.target"))

	return id ~= "none" and self:Find(id) or nil
end

---@param config table
---@param element AUIEditorElement
---@param dimension "width"|"height"
---@return AUIEditorElement? target the element whose size it keeps
function Layout:SizeTarget(config, element, dimension)
	local id = Schema:Read(config, self:Path(element, "layout." .. dimension))

	return id ~= "none" and self:Find(id) or nil
end

---@param config table
---@param element AUIEditorElement
---@return number x an attached element's offsets from its place against the target's edge
---@return number y
function Layout:Offsets(config, element)
	return Schema:Read(config, self:Path(element, "layout.attach.x")),
		Schema:Read(config, self:Path(element, "layout.attach.y"))
end

---@param config table
---@param element AUIEditorElement
---@return number x the center of the element's rectangle, as an offset from the screen's center
---@return number y
function Layout:Center(config, element)
	local x, y = self:Position(config, element)
	local _, _, shiftX, shiftY = self:Size(config, element)

	return x + shiftX, y + shiftY
end

---Where an element's center goes against a target's side, before its offsets: its near edge on the target's edge,
---centered along it.
---@param config table
---@param element AUIEditorElement
---@param target AUIEditorElement
---@param side string "LEFT", "RIGHT", "TOP" or "BOTTOM"
---@return number x
---@return number y
function Layout:SidePoint(config, element, target, side)
	local tx, ty = self:Center(config, target)
	local tw, th = self:Size(config, target)
	local cw, ch = self:Size(config, element)

	if side == "LEFT" then
		return tx - tw / 2 - cw / 2, ty
	elseif side == "RIGHT" then
		return tx + tw / 2 + cw / 2, ty
	elseif side == "TOP" then
		return tx, ty + th / 2 + ch / 2
	end

	return tx, ty - th / 2 - ch / 2
end

---@param config table
---@param element AUIEditorElement
---@param target AUIEditorElement? nil detaches, keeping the position
---@param side string?
---@return table<string, any> values the attachment, with offsets that keep the element where it is, by path
function Layout:Attach(config, element, target, side)
	if not target then
		return { [self:Path(element, "layout.attach.target")] = "none" }
	end

	side = side or Schema:Read(config, self:Path(element, "layout.attach.side"))

	local cx, cy = self:Center(config, element)
	local px, py = self:SidePoint(config, element, target, side)

	return {
		[self:Path(element, "layout.attach.target")] = target.id,
		[self:Path(element, "layout.attach.side")] = side,
		[self:Path(element, "layout.attach.x")] = cx - px,
		[self:Path(element, "layout.attach.y")] = cy - py,
	}
end

---@param element AUIEditorElement
---@param dimension "width"|"height"
---@param value number
---@return number value fitted to the element's own setting: inside its range, whole when it must be
function Layout:Fit(element, dimension, value)
	local field = Schema:Field(self:Path(element, dimension)) --[[@as AUISchemaField]]

	value = self:Clamp(value, field.min or value, field.max or value)

	if field.integer then
		value = math.floor(value + 0.5)
	end

	return value
end

---@param config table
---@param element AUIEditorElement
---@param dimension "width"|"height"
---@param target AUIEditorElement
---@return table<string, number> values the target's size copied once, fitted to the element, by path
function Layout:MatchNow(config, element, dimension, target)
	local value = Schema:Read(config, self:Path(target, dimension))

	return { [self:Path(element, dimension)] = self:Fit(element, dimension, value) }
end

---@param config table
---@param element AUIEditorElement
---@return AUIEditorElement[] targets the elements it can be attached or linked to: not itself, and none that relies
---on it
function Layout:Eligible(config, element)
	local targets = {}

	for _, other in ipairs(ELEMENTS) do
		if other ~= element and not Schema:DependsOn(config, other.id, element.id) then
			targets[#targets + 1] = other
		end
	end

	return targets
end

---Recalculates every attached element's position and every linked size, targets before what relies on them.
---@param config table a config with no relationship loop
---@return boolean changed
function Layout:Resolve(config)
	local changed, done = false, {}

	local function Write(path, value)
		if Schema:Read(config, path) ~= value then
			Schema:Write(config, path, value)
			changed = true
		end
	end

	local function Visit(element)
		if done[element.id] then
			return
		end

		done[element.id] = true

		for _, id in ipairs(Schema:LayoutTargets(config, element.id)) do
			local target = self:Find(id)

			if target then
				Visit(target)
			end
		end

		for _, dimension in ipairs({ "width", "height" }) do
			local target = self:SizeTarget(config, element, dimension)

			if target then
				Write(self:Path(element, dimension),
					self:Fit(element, dimension, Schema:Read(config, self:Path(target, dimension))))
			end
		end

		local target = self:AttachTarget(config, element)

		if target then
			local side = Schema:Read(config, self:Path(element, "layout.attach.side"))
			local px, py = self:SidePoint(config, element, target, side)
			local offsetX, offsetY = self:Offsets(config, element)
			local _, _, shiftX, shiftY = self:Size(config, element)

			Write(self:Path(element, "x"), px + offsetX - shiftX)
			Write(self:Path(element, "y"), py + offsetY - shiftY)
		end
	end

	for _, element in ipairs(ELEMENTS) do
		Visit(element)
	end

	return changed
end

---@param config table
---@param element AUIEditorElement
---@param field string "x", "y", "width" or "height"
---@return string path where the panel's field reads and writes: an attached element's X and Y are its offsets
function Layout:FieldPath(config, element, field)
	if (field == "x" or field == "y") and self:AttachTarget(config, element) then
		return self:Path(element, "layout.attach." .. field)
	end

	return self:Path(element, field)
end

AUI.Profile.Normalize = function(config)
	return Layout:Resolve(config)
end

---@param value number
---@param minimum number
---@param maximum number
---@return number
function Layout:Clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

---@class AUISnapLines
---@field x number[]
---@field y number[]

---@param rects table[] the other elements' rectangles, each `{ left, bottom, width, height }`
---@param screenWidth number
---@param screenHeight number
---@return AUISnapLines lines each rectangle's edges and center, and the screen's center
function Layout:Lines(rects, screenWidth, screenHeight)
	local lines = { x = { screenWidth / 2 }, y = { screenHeight / 2 } }

	for _, rect in ipairs(rects) do
		local left, bottom, width, height = rect[1], rect[2], rect[3], rect[4]

		lines.x[#lines.x + 1] = left
		lines.x[#lines.x + 1] = left + width / 2
		lines.x[#lines.x + 1] = left + width
		lines.y[#lines.y + 1] = bottom
		lines.y[#lines.y + 1] = bottom + height / 2
		lines.y[#lines.y + 1] = bottom + height
	end

	return lines
end

---@param start number
---@param size number
---@param lines number[]
---@param threshold number
---@return number shift
---@return number? line the line met, or nil when none is close enough
local function Nearest(start, size, lines, threshold)
	local best, bestLine = nil, nil

	for _, line in ipairs(lines) do
		for _, edge in ipairs({ start, start + size / 2, start + size }) do
			local shift = line - edge

			if math.abs(shift) <= threshold and (not best or math.abs(shift) < math.abs(best)) then
				best, bestLine = shift, line
			end
		end
	end

	return best or 0, bestLine
end

---Moves a rectangle so its nearest edge or center meets a line within the threshold, on each axis.
---@param left number
---@param bottom number
---@param width number
---@param height number
---@param lines AUISnapLines
---@param threshold number
---@return number left
---@return number bottom
---@return number? guideX the vertical line met
---@return number? guideY the horizontal line met
function Layout:Snap(left, bottom, width, height, lines, threshold)
	local shiftX, guideX = Nearest(left, width, lines.x, threshold)
	local shiftY, guideY = Nearest(bottom, height, lines.y, threshold)

	return left + shiftX, bottom + shiftY, guideX, guideY
end
