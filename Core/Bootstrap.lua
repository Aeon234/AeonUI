local AUI = select(2, ...)

local frame = CreateFrame("Frame")

frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		self:UnregisterEvent(event)

		local L = AUI.L
		local guid = UnitGUID("player")

		if issecretvalue(guid) or type(guid) ~= "string" or guid == "" then
			AUI.failed = true
			AUI:Warn(L["your character could not be identified, so AeonUI is off for this session."])

			return
		end

		AUI.Capabilities:Resolve()

		local ok, problem = pcall(AUI.Profile.Initialize, AUI.Profile, AeonUIDB, guid)

		if not ok then
			AUI.failed = true
			AUI:Warn(L["saved settings failed to load, so AeonUI is off for this session."])
			AUI:Warn(tostring(problem))

			return
		end

		local mode = AUI.Profile.mode

		if mode == "recovery" then
			if AUI.Profile.newer then
				AUI:Warn(
					L["saved settings come from a newer version of AeonUI, so this version is using default settings and leaves them unchanged."]
				)
			else
				AUI:Warn(
					L["saved settings are damaged, so AeonUI is using default settings and leaves them unchanged until you reset them."]
				)
			end
		elseif mode == "fallback" then
			AUI:Warn(
				L["the active profile can't be used, so AeonUI is showing default settings until you choose another profile."]
			)
		end

		AUI.UIScale:Start()
		AUI.Broker:Create()
		AUI.GameMenu:Create()
		AUI.GameMenuScale:Start()
		AUI.Minimap:Start()
		AUI.WorldMap:Start()
		AUI.Tooltip:Start()
		AUI.EditTargets:Register()
	end
end)
