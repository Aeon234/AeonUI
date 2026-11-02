local AUI = select(2, ...)

---Prints each channel the player starts: its spell ID, name and length, and whether the tick list has it.
---@class AUIChannelLog
---@field on boolean?
local ChannelLog = {}

---@param _ string
---@param unit string
function ChannelLog:OnChannel(_, unit)
	if unit ~= "player" then
		return
	end

	local name, _, _, start, finish, _, _, spellID = UnitChannelInfo("player")

	if issecretvalue(name) or issecretvalue(spellID) or issecretvalue(start) or issecretvalue(finish) then
		AUI:Print("channel: hidden by the client.")

		return
	end

	if name then
		AUI:Print("channel: %s, spell %d, %.2f s, %s", name, spellID, (finish - start) / 1000,
			AUI.CastBarTickData.spells[spellID] and "listed" or "not listed")
	end
end

---Turns the log on or off.
function ChannelLog:Toggle()
	self.on = not self.on

	if self.on then
		AUI.Events:Register("UNIT_SPELLCAST_CHANNEL_START", self, self.OnChannel)
	else
		AUI.Events:Unregister("UNIT_SPELLCAST_CHANNEL_START", self)
	end

	AUI:Print("channel log %s.", self.on and "on: start a channel" or "off")
end

AUI.Dev:Register("channel", function()
	ChannelLog:Toggle()
end)
