local PeaversCommons = _G.PeaversCommons
local Promoter = {}
PeaversCommons.Promoter = Promoter

local COOLDOWN_SECONDS = 600
local DELAY_SECONDS = 3
local MESSAGE = "Check out how to improve at https://wowcompare.io"

local lastPromoteTime = 0

local function IsEnabled()
    return PeaversCommonsDB
        and PeaversCommonsDB.config
        and PeaversCommonsDB.config.promoteInChat == true
end

local function IsOnCooldown()
    return (GetTime() - lastPromoteTime) < COOLDOWN_SECONDS
end

local function GetChatChannel()
    if IsInRaid() then
        return "RAID"
    elseif IsInGroup() then
        return "PARTY"
    end
    return nil
end

local function SendPromo()
    if not IsEnabled() then return end
    if IsOnCooldown() then return end

    local channel = GetChatChannel()
    if not channel then return end

    lastPromoteTime = GetTime()
    SendChatMessage(MESSAGE, channel)
end

local function SchedulePromo()
    if not IsEnabled() then return end
    if IsOnCooldown() then return end

    C_Timer.After(DELAY_SECONDS, SendPromo)
end

function Promoter:Initialize()
    PeaversCommons.Events:RegisterEvent("CHALLENGE_MODE_COMPLETED", function()
        SchedulePromo()
    end)

    PeaversCommons.Events:RegisterEvent("ENCOUNTER_END", function(event, encounterID, encounterName, difficultyID, groupSize, success)
        if success == 1 then
            SchedulePromo()
        end
    end)
end

return Promoter
