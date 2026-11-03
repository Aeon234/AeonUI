local AUI = select(2, ...)

---Prints the spells measuring range and what the client reports for the target now.
local function Report()
	local RangeFade = AUI.RangeFade

	RangeFade:FindSpells()
	AUI:Print("range: harmful %s, helpful %s", tostring(RangeFade.harmful), tostring(RangeFade.helpful))

	if not UnitExists("target") then
		AUI:Print("range: no target")

		return
	end

	local inRange = RangeFade:InRange("target")

	AUI:Print("range: target %s", issecretvalue(inRange) and "secret" or tostring(inRange))
end

AUI.Dev:Register("range", Report)
