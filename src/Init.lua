local PeaversCommons = _G.PeaversCommons

-- Register for player entering world to show a single greeting message
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event, isInitialLogin, isReloadingUi)
    if isInitialLogin or isReloadingUi then
        C_Timer.After(0.5, function()
            print(" ")
            print(
                "|cff3abdf7Peavers|r|cfffbbf24Addons|r|cff808080:|r " ..
                "|cff4ade80NEW|r " ..
                "|cffc084fcparses.gg|r " ..
                "|cff808080•|r " ..
                "|cffe2e2e2the next generation of open combat logging|r"
            )
            print(" ")
        end)

        C_Timer.After(1, function()
            if PeaversCommons.Promoter then
                PeaversCommons.Promoter:Initialize()
            end
        end)
    end
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end)
