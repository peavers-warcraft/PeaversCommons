local PeaversCommons = _G.PeaversCommons
local Promoter = {}
PeaversCommons.Promoter = Promoter

local COOLDOWN_SECONDS = 600
local DELAY_SECONDS = 3

-- What this used to say, and what it still says when the link cannot be built.
--
-- Kept as the fallback rather than deleted: a message with no address at all is
-- better than one with a broken address in it, and the two failure cases below
-- are both "we do not know who you are", which no amount of retrying fixes.
local FALLBACK = "Check out free and open combat logs at https://parses.gg"

local lastPromoteTime = 0

--- The realm as parses.gg compares realms.
--
-- The server folds every realm through one canonical form before matching, so
-- this has to produce the same string its `realm_key()` does: strip the region
-- suffix while it is still a hyphen-delimited token, then strip everything that
-- is not a letter or a digit, then lowercase. "Area 52" and "Area52-US" are both
-- `area52`, which is the point - a log writes one spelling and Blizzard's
-- profile API writes another.
--
-- The order matters and is not interchangeable. Stripping punctuation first
-- would turn "Tichondrius" into "tichondri" once the trailing "us" was no longer
-- behind a hyphen.
--
-- `GetRealmName()` returns the display spelling with no region on it, so the
-- suffix step is a no-op today. It is here anyway because this function's
-- contract is "the same answer as the server", and a version of it that only
-- happens to agree is one that stops agreeing without saying so.
local function RealmKey(realm)
    if not realm then return nil end
    local key = realm:gsub("%-[Uu][Ss]$", ""):gsub("%-[Ee][Uu]$", "")
        :gsub("%-[Kk][Rr]$", ""):gsub("%-[Tt][Ww]$", ""):gsub("%-[Cc][Nn]$", "")
    key = key:gsub("[^%a%d]", ""):lower()
    if key == "" then return nil end
    return key
end

--- The live page for the character this is running on, or nil.
--
-- The whole reason the live page is addressed by character rather than by
-- recording: an addon knows its own name and realm, and knows nothing about the
-- desktop client's session id, which is minted on the machine tailing the log.
-- So this address can be worked out in chat, and the previous one could only be
-- fetched from the site and pasted by hand.
--
-- **The link can be live before anything is recorded, and that is deliberate on
-- the page's side** - it answers "nothing recorded here yet, leave it open" and
-- fills in on its own as pulls land. So it is worth sending at the end of a
-- fight even though the upload has not finished yet.
--
-- **It resolves for anyone whose raid somebody is logging, not only for people
-- running the client themselves.** That is the point of promoting it: a raider
-- who has never installed anything still has a working page, as long as one
-- person in the group uploads. Where nobody in the group does, the link lands on
-- the waiting state rather than on an error.
local function LiveUrl()
    local name = UnitName("player")
    local realm = RealmKey(GetRealmName())
    if not name or name == "" or not realm then return nil end
    return "https://parses.gg/live/" .. realm .. "/" .. name
end

local function Message()
    local url = LiveUrl()
    if not url then return FALLBACK end
    return "Live log for this fight: " .. url
end

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
    SendChatMessage(Message(), channel)
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

-- Exposed for the same reason the URL is built from a pure function at all: the
-- only way to check it agrees with the server's `realm_key()` is to be able to
-- call it with a realm and compare, and there is no Lua test harness in this
-- repo to do that from inside.
Promoter.RealmKey = RealmKey
Promoter.LiveUrl = LiveUrl

return Promoter
