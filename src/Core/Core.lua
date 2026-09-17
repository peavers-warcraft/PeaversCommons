local MAJOR, MINOR = "PeaversCommons-1.0", 4
local PeaversCommons = LibStub and LibStub:NewLibrary(MAJOR, MINOR) or {}

if not PeaversCommons then return end

PeaversCommons.name = "PeaversCommons"
PeaversCommons.version = MAJOR .. "." .. MINOR

PeaversCommons.Events = {}
PeaversCommons.SlashCommands = {}
PeaversCommons.Utils = {}
PeaversCommons.SupportUI = {}
PeaversCommons.Patrons = {}
PeaversCommons.PatronsUI = {}

PeaversCommons.FrameCore = {}
PeaversCommons.FrameUtils = {}
PeaversCommons.ConfigUIUtils = {}
PeaversCommons.ConfigManager = {}
PeaversCommons.ConfigRegistry = {}
PeaversCommons.SettingsUI = {}

PeaversCommons.BarManager = {}
PeaversCommons.StatBar = {}
PeaversCommons.TitleBar = {}
PeaversCommons.BarStyles = {}
PeaversCommons.Debug = {}

PeaversCommons.revision = MINOR

--------------------------------------------------------------------------------
-- Feature revisions
--
-- MINOR above is a feature revision, bumped whenever this library gains
-- something the addons build on. An addon asks for the revision it was written
-- against; an older installed library gets a plain false and one line in chat.
--
-- Loudly, and with no fallback, on purpose. Every addon used to carry its own
-- copy of whatever it needed "in case Commons is too old", and those copies drifted
-- - which is how WoW Forever came to be identified as retail in one addon and as
-- Classic in another. The same choice as the release pipeline's version matcher:
-- fail where it can be seen rather than quietly answer wrongly.
--
-- Revisions:
--   4  PeaversCommons.Client - one answer to which game this is
--------------------------------------------------------------------------------

local unmet = {}

--- @param revision number the feature revision the caller needs
--- @param addonName string|nil for the message
--- @return boolean ok
function PeaversCommons:Require(revision, addonName)
    if MINOR >= (tonumber(revision) or 0) then return true end

    unmet[#unmet + 1] = addonName or "a Peavers addon"

    -- Deferred because a print this early is swallowed before the chat frames are
    -- ready, and batched because eleven addons asking would be eleven lines about
    -- one problem.
    if #unmet == 1 and C_Timer and C_Timer.After then
        C_Timer.After(8, function()
            print(("|cffff6b6bPeaversCommons|r is out of date: %s %s a newer version. Update PeaversCommons."):format(
                table.concat(unmet, ", "), #unmet == 1 and "needs" or "need"))
        end)
    end

    return false
end

_G.PeaversCommons = PeaversCommons

return PeaversCommons