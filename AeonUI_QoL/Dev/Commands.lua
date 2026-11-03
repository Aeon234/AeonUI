-- Development commands for the quality of life features. Not packaged.
local AUI = select(2, ...)

local Dev = AUI.Dev

Dev:Register("dci", function(rest)
	(Dev.DeleteCheapestItemProbe --[[@as AUIDeleteCheapestItemProbe]]):Command(rest)
end)
Dev:Register("movealert", function(rest)
	if AUI.can.movementAlert then
		(Dev.MovementAlertProbe --[[@as AUIMovementAlertProbe]]):Command(rest)
	else
		AUI:Print("movealert: this client has no Movement Alerts.")
	end
end)
Dev:Register("travelerslog", function(rest)
	if AUI.can.travelersLog then
		(Dev.TravelersLogProbe --[[@as AUITravelersLogProbe]]):Command(rest)
	else
		AUI:Print("travelerslog: this client has no Traveler's Log.")
	end
end)
Dev:Register("sparkles", function()
	if AUI.can.approachSparkles then
		(Dev.SparklesProbe --[[@as AUISparklesProbe]]):Command()
	else
		AUI:Print("sparkles: this client has no approached-object glints.")
	end
end)
