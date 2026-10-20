local AUI = select(2, ...)

-- Guest element ids are the hosted addon's own, prefixed so they cannot collide with AeonUI's.
local PREFIX = "guest."

---The hosted addon's movable elements as layout editor elements. The guest keeps their positions in its own saved
---data and shows their samples in the real elements; the editor only places movers over them and tells the guest
---where each one goes. Every call into the guest is isolated: an error is reported and answers nothing.
---@class AUIEditorGuest
---@field elements AUIEditorElement[] the guest's elements listed last, in its order
---@field byID table<string, AUIEditorElement> the same elements by id, kept across listings so movers keep theirs
local Guest = {
	elements = {},
	byID = {},
}
AUI.EditorGuest = Guest

---@param method string
---@param ... any
---@return any ...
local function Call(method, ...)
	local participant = AUI.SettingsHost:Participant()

	if not participant then
		return nil
	end

	return AUI.AeonSettings:CallHost(nil, participant[method], participant, ...)
end

---@return boolean present a hosted addon takes part in the layout editor
function Guest:Present()
	return AUI.SettingsHost:Participant() ~= nil
end

---Lists the guest's elements afresh. An element keeps its table while the guest keeps listing it.
---@return AUIEditorElement[] elements
function Guest:Refresh()
	local addon = AUI.SettingsHost:Addon()
	local elements, byID = {}, {}

	for _, mover in ipairs(Call("Movers") or {}) do
		if type(mover) == "table" and type(mover.id) == "string" then
			local id = PREFIX .. mover.id
			local element = self.byID[id] or { id = id, key = "", base = "", guest = true }

			element.guestID = mover.id
			element.label = tostring(mover.label or mover.id)
			element.page = addon and mover.page and AUI.SettingsHost.Namespace(addon, mover.page) or ""
			elements[#elements + 1] = element
			byID[id] = element
		end
	end

	self.elements, self.byID = elements, byID

	return elements
end

---@param id string
---@return AUIEditorElement?
function Guest:Find(id)
	return self.byID[id]
end

---@param element AUIEditorElement
---@return number? left the element's rectangle, nil while the guest has none for it
---@return number? bottom
---@return number? width
---@return number? height
function Guest:Rect(element)
	local left, bottom, width, height = Call("Rect", element.guestID)

	if type(left) ~= "number" or type(bottom) ~= "number" or type(width) ~= "number" or type(height) ~= "number" then
		return nil
	end

	return left, bottom, width, height
end

---@param element AUIEditorElement
---@param screenWidth number
---@param screenHeight number
---@return number x the offset of the element's center from the screen's center
---@return number y
function Guest:Center(element, screenWidth, screenHeight)
	local left, bottom, width, height = self:Rect(element)

	if not left then
		return 0, 0
	end

	return left + width / 2 - screenWidth / 2, bottom + height / 2 - screenHeight / 2
end

---@param element AUIEditorElement
---@param left number
---@param bottom number
function Guest:Drag(element, left, bottom)
	Call("Drag", element.guestID, left, bottom)
end

---@param element AUIEditorElement
---@param left number
---@param bottom number
function Guest:Move(element, left, bottom)
	Call("Move", element.guestID, left, bottom)
end

---@param element AUIEditorElement
function Guest:Revert(element)
	Call("Revert", element.guestID)
end

---@param element AUIEditorElement
function Guest:Reset(element)
	Call("Reset", element.guestID)
end

---@param element AUIEditorElement
---@return boolean default
function Guest:IsDefault(element)
	return Call("IsDefault", element.guestID) == true
end

function Guest:Begin()
	Call("Begin")
end

---@param shown boolean
function Guest:Show(shown)
	Call("Show", shown)
end

---@return boolean dirty the guest's positions differ from the session's start
function Guest:IsDirty()
	return Call("IsDirty") == true
end

function Guest:Save()
	Call("Save")
end

function Guest:Discard()
	Call("Discard")
end

function Guest:End()
	Call("End")
	self.elements, self.byID = {}, {}
end
