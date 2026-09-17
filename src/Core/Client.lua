--------------------------------------------------------------------------------
-- PeaversCommons.Client
--
-- Which game this is, answered once for the whole collection.
--
-- Every addon used to work this out for itself, and they disagreed. The reason
-- they existed was honest - Compat was unreleased when they were written, so
-- "never assume Compat exists" was true - but it stopped being true, and five
-- copies of a rule this subtle are five chances to get it wrong. WoW Forever got
-- two of them.
--
-- THREE DIFFERENT QUESTIONS
--
-- This file answers two of them and deliberately refuses the third:
--
--   which game is this?      -> the interface number. Mythic+ exists here.
--   which client generation? -> the interface number. TooltipDataProcessor
--                               exists here.
--   does this feature work?  -> NOT HERE. Probe it. See Compat.
--
-- Conflating any two of those is where every Forever bug came from. Existence is
-- not the same as working, and a version number is not the same as a generation.
-- So capability questions - is this event valid, is there an Edit Mode, are there
-- specializations, is there a ranged slot - live in Compat or in the addon that
-- cares, and are answered by asking the client, never by comparing a number.
-- Nothing here may grow an answer that could be probed instead.
--
-- THE ORDERING RULE
--
-- Forever is identified first, and only by its interface range. It reports
-- WOW_PROJECT_ID equal to WOW_PROJECT_MAINLINE - the same value retail reports -
-- so every mainline test calls it retail; and it continues the vanilla 1.x line,
-- so every major-version test calls it Classic Era. Measured on the beta:
-- 1.60.1.69893, interface 16001, WOW_PROJECT_ID 1, GetExpansionLevel() 0.
--
-- Loaded straight after Core.lua, before anything that asks which client it is.
--------------------------------------------------------------------------------

local PeaversCommons = _G.PeaversCommons
local Client = {}
PeaversCommons.Client = Client

--------------------------------------------------------------------------------
-- Identity
--------------------------------------------------------------------------------

local version, build, _, interface = GetBuildInfo()

Client.version = version
Client.build = tonumber(build)
Client.interface = tonumber(interface) or 0

-- Interface ranges rather than project IDs throughout. The project constants for
-- the newer Classic clients have been renamed before, Forever's is outright
-- misleading, and the interface number has never lied.
local iface = Client.interface

Client.isForever = iface >= 16000 and iface < 20000
Client.isClassicEra = iface >= 11000 and iface < 16000
Client.isAnniversary = iface >= 20000 and iface < 30000
Client.isMists = iface >= 50000 and iface < 60000

-- Retail is what is left once every client we can name is out of the running, so
-- an unrecognised future client behaves as retail rather than silently losing
-- features. The mainline check is deliberately not used here: it agrees for retail
-- and for Forever alike, which is exactly why it cannot be the thing that decides.
Client.isClassic = Client.isClassicEra or Client.isAnniversary or Client.isMists
Client.isRetail = not Client.isForever and not Client.isClassic

--- "retail" | "forever" | "era" | "anniversary" | "mists"
Client.key = (Client.isForever and "forever")
    or (Client.isClassicEra and "era")
    or (Client.isAnniversary and "anniversary")
    or (Client.isMists and "mists")
    or "retail"

--- What to call it in front of a player.
Client.label = ({
    retail = "World of Warcraft",
    forever = "WoW Forever",
    era = "Classic Era",
    anniversary = "Anniversary",
    mists = "Mists of Pandaria Classic",
})[Client.key]

-- The client's generation, as opposed to which game it is. Forever is built from
-- retail's branch and probes identically to it - the same valid events, the same
-- graphics CVars, the same frame methods, a newer build number, and the modern
-- tooltip, aura and minimap APIs Classic Era does not have - while its content is
-- vanilla. Ask this when the question is "can I use the modern API"; ask isRetail
-- when the question is "does this game have Mythic+".
Client.isModernClient = Client.isRetail or Client.isForever

--------------------------------------------------------------------------------
-- Content
--
-- Facts about what this game contains, which no amount of probing will tell you:
-- every frame and function for a feature can be present while the feature itself
-- does not exist here. Used for wording and for defaults, never to decide whether
-- code can run.
--------------------------------------------------------------------------------

-- Timed dungeons that report instance difficulty 8: Mythic+ on retail, Challenge
-- Mode on Mists Classic, named for what players there call them. Era, Anniversary
-- and Forever have neither.
if Client.isRetail then
    Client.timedDungeonName, Client.timedDungeonShort = "Mythic+", "M+"
elseif Client.isMists then
    Client.timedDungeonName, Client.timedDungeonShort = "Challenge Mode", "CM"
end
Client.hasTimedDungeons = Client.timedDungeonName ~= nil

-- Arenas arrived in The Burning Crusade, scenarios in Mists. Forever is vanilla
-- content, so it has neither however modern the client underneath it is.
Client.hasArenas = Client.isRetail or Client.isAnniversary or Client.isMists
Client.hasScenarios = Client.isRetail or Client.isMists

--- The instance types that exist here but that auto-switching leaves alone. Only
--- ever shown in a "you are currently in" line, so it has to be honest rather
--- than exhaustive.
Client.unmanagedInstanceText = (Client.hasScenarios and "battleground, arena, scenario")
    or (Client.hasArenas and "battleground, arena")
    or "battleground"

-- The Cooldown Manager, and the one place in the collection where a feature is
-- decided by which game this is rather than by asking.
--
-- Forever ships every part of it and none of it works: Blizzard_CooldownViewer is
-- listed and loaded, C_CooldownViewer has its full function set, all four viewers
-- exist hidden at width 1, and C_CooldownViewer.IsCooldownViewerAvailable()
-- answers true - while no player can use it, and Blizzard have said it will not
-- be available. Every capability signal there is says yes, so asking the client is
-- the one thing that cannot work here.
--
-- If it ever ships on Forever, delete the isForever term and let
-- IsCooldownViewerAvailable answer.
-- Purely version-derived, and it has to be: the viewers are load-on-demand, so
-- looking for them at load time would answer "no" on a retail session where the
-- player simply has not opened them yet. This says whether the GAME has the
-- feature. Whether it is loaded and usable right now is a separate question, and
-- belongs to whoever is about to use it.
Client.hasCooldownManager = Client.isRetail

--------------------------------------------------------------------------------
-- Description
--------------------------------------------------------------------------------

--- One line for a debug dump or a bug report.
function Client:Describe()
    return ("%s (%s) interface %d build %s"):format(
        self.label, self.key, self.interface, tostring(self.build))
end

return Client
