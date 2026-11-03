local AUI = select(2, ...)

local Options = AUI.UnitFrameOptions

-- The sidebar follows registration order: Player's page comes first, then Player Resources and Cast Bar, then these.
for index = 2, #Options.FRAMES do
	AUI.SettingsFramePage.Register(Options.FRAMES[index])
end
