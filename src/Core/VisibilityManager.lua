--------------------------------------------------------------------------------
-- VisibilityManager Module
-- Provides consistent frame visibility behavior based on display mode and combat state
--------------------------------------------------------------------------------

local PeaversCommons = _G.PeaversCommons
local VisibilityManager = {}
PeaversCommons.VisibilityManager = VisibilityManager

-- Display mode constants
VisibilityManager.DISPLAY_ALWAYS = "ALWAYS"
VisibilityManager.DISPLAY_PARTY_ONLY = "PARTY_ONLY"
VisibilityManager.DISPLAY_RAID_ONLY = "RAID_ONLY"

-- Updates frame visibility based on config settings
-- @param frame: The frame to show/hide
-- @param config: Config table with displayMode, hideOutOfCombat, showOnLogin fields
-- @param inCombat: Optional boolean override for combat state (defaults to InCombatLockdown())
-- @return boolean: Whether the frame is shown
function VisibilityManager:UpdateVisibility(frame, config, inCombat)
    if not frame then return false end

    local shouldShow = true
    inCombat = inCombat or InCombatLockdown()

    -- Check display mode
    local displayMode = config.displayMode or self.DISPLAY_ALWAYS

    if displayMode ~= self.DISPLAY_ALWAYS then
        local isInParty = IsInGroup() and not IsInRaid()
        local isInRaid = IsInRaid()

        shouldShow = false
        if displayMode == self.DISPLAY_PARTY_ONLY and isInParty then
            shouldShow = true
        elseif displayMode == self.DISPLAY_RAID_ONLY and isInRaid then
            shouldShow = true
        end
    end

    -- Check combat visibility
    if shouldShow and config.hideOutOfCombat and not inCombat then
        shouldShow = false
    end

    -- Check showOnLogin setting
    if shouldShow and config.showOnLogin == false then
        shouldShow = false
    end

    -- Apply visibility
    if shouldShow then
        frame:Show()
    else
        frame:Hide()
    end

    return shouldShow
end

-- Checks if frame should be visible without actually changing visibility
-- Useful for determining state before making decisions
-- @param config: Config table with displayMode, hideOutOfCombat, showOnLogin fields
-- @param inCombat: Optional boolean override for combat state
-- @return boolean: Whether the frame should be shown
function VisibilityManager:ShouldBeVisible(config, inCombat)
    local shouldShow = true
    inCombat = inCombat or InCombatLockdown()

    -- Check display mode
    local displayMode = config.displayMode or self.DISPLAY_ALWAYS

    if displayMode ~= self.DISPLAY_ALWAYS then
        local isInParty = IsInGroup() and not IsInRaid()
        local isInRaid = IsInRaid()

        shouldShow = false
        if displayMode == self.DISPLAY_PARTY_ONLY and isInParty then
            shouldShow = true
        elseif displayMode == self.DISPLAY_RAID_ONLY and isInRaid then
            shouldShow = true
        end
    end

    -- Check combat visibility
    if shouldShow and config.hideOutOfCombat and not inCombat then
        shouldShow = false
    end

    -- Check showOnLogin setting
    if shouldShow and config.showOnLogin == false then
        shouldShow = false
    end

    return shouldShow
end

-- Registers combat events to auto-update visibility
-- @param frame: The frame to manage
-- @param config: Config table
-- @param core: Optional core module with inCombat tracking
-- @return function: Unregister function to remove the handlers
function VisibilityManager:RegisterCombatEvents(frame, config, core)
    local eventFrame = CreateFrame("Frame")

    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

    eventFrame:SetScript("OnEvent", function(_, event)
        local inCombat = InCombatLockdown()

        if core then
            core.inCombat = inCombat
        end

        self:UpdateVisibility(frame, config, inCombat)
    end)

    -- Return unregister function
    return function()
        eventFrame:UnregisterAllEvents()
        eventFrame:SetScript("OnEvent", nil)
    end
end

return VisibilityManager
