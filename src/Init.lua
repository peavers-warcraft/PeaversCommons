local PeaversCommons = _G.PeaversCommons

-- Register for player entering world to show a single greeting message
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event, isInitialLogin, isReloadingUi)
    if isInitialLogin or isReloadingUi then
        C_Timer.After(0.5, function()
            print("|cff3abdf7Peavers|r: Thanks for using Peavers addons, checkout my latest tool |cff3abdf7wowcompare.io|r")
        end)
    end
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end)
