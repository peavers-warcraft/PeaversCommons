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
VisibilityManager.DISPLAY_PARTY_AND_RAID = "PARTY_AND_RAID"

--------------------------------------------------------------------------------
-- Content
--
-- Which kind of place the player is in. Every addon decides for itself which
-- of these it shows in, through one showIn<Content> boolean per type. A key that
-- is absent counts as shown, so an addon that offers none of them behaves exactly
-- as it did before they existed.
--------------------------------------------------------------------------------

VisibilityManager.CONTENT_MYTHIC_PLUS = "MYTHIC_PLUS"
VisibilityManager.CONTENT_RAID = "RAID"
VisibilityManager.CONTENT_DUNGEON = "DUNGEON"
VisibilityManager.CONTENT_DELVE = "DELVE"
VisibilityManager.CONTENT_SCENARIO = "SCENARIO"
VisibilityManager.CONTENT_PVP = "PVP"
VisibilityManager.CONTENT_OPEN_WORLD = "OPEN_WORLD"

-- The config key each content type is read from.
VisibilityManager.CONTENT_KEYS = {
    MYTHIC_PLUS = "showInMythicPlus",
    RAID = "showInRaid",
    DUNGEON = "showInDungeon",
    DELVE = "showInDelve",
    SCENARIO = "showInScenario",
    PVP = "showInPvP",
    OPEN_WORLD = "showInOpenWorld",
}

-- Difficulty 8 is a keystone, from the moment the key goes in rather than only
-- once the timer runs, so the frame is already up while the group gets ready.
-- 208 is a delve, checked as well as IsDelveInProgress because that one only
-- answers once the delve has actually started.
local DIFFICULTY_KEYSTONE = 8
local DIFFICULTY_DELVE = 208

--- @return string one of the CONTENT_* constants
function VisibilityManager:GetContentType()
    local inInstance, instanceType = IsInInstance()
    if not inInstance then
        return self.CONTENT_OPEN_WORLD
    end

    local difficultyID = select(3, GetInstanceInfo())

    if instanceType == "raid" then
        return self.CONTENT_RAID
    elseif instanceType == "party" then
        local active = C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive
            and C_ChallengeMode.IsChallengeModeActive()
        if active or difficultyID == DIFFICULTY_KEYSTONE then
            return self.CONTENT_MYTHIC_PLUS
        end
        return self.CONTENT_DUNGEON
    elseif instanceType == "pvp" or instanceType == "arena" then
        return self.CONTENT_PVP
    elseif instanceType == "scenario" then
        local delve = C_PartyInfo and C_PartyInfo.IsDelveInProgress and C_PartyInfo.IsDelveInProgress()
        if delve or difficultyID == DIFFICULTY_DELVE then
            return self.CONTENT_DELVE
        end
        return self.CONTENT_SCENARIO
    end

    return self.CONTENT_OPEN_WORLD
end

--- Whether the config allows showing in the current content.
function VisibilityManager:MatchesContent(config)
    local key = self.CONTENT_KEYS[self:GetContentType()]
    return not key or config[key] ~= false
end

-- Updates frame visibility based on config settings
-- @param frame: The frame to show/hide
-- @param config: Config table with displayMode, hideOutOfCombat, showOnLogin and
--   showIn<Content> fields
-- @param inCombat: Optional boolean override for combat state (defaults to InCombatLockdown())
-- @return boolean: Whether the frame is shown
function VisibilityManager:UpdateVisibility(frame, config, inCombat)
    if not frame then return false end

    local shouldShow = self:ShouldBeVisible(config, inCombat)

    if shouldShow then
        frame:Show()
    else
        frame:Hide()
    end

    return shouldShow
end

-- Checks if frame should be visible without actually changing visibility
-- Useful for determining state before making decisions
-- @param config: Config table with displayMode, hideOutOfCombat, showOnLogin and
--   showIn<Content> fields
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
        elseif displayMode == self.DISPLAY_PARTY_AND_RAID and (isInParty or isInRaid) then
            shouldShow = true
        end
    end

    -- Check content type
    if shouldShow and not self:MatchesContent(config) then
        shouldShow = false
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
