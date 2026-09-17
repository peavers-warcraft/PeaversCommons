--------------------------------------------------------------------------------
-- PeaversCommons compatibility
--
-- What this client can DO. Which client it IS lives in Client.lua next door, and
-- the split is the point: a capability is found out by asking the client, and a
-- client is identified by its interface number. Answering either with the other's
-- method is where the Forever bugs came from.
--
-- The flavour flags are for wording and defaults. Anything that decides whether
-- code can run asks about the capability itself - an event, a frame, a function -
-- because Blizzard back-ports retail systems to the Classic clients over time,
-- and a check written as "not on Classic" goes wrong the day it arrives.
--
-- Loaded straight after Core.lua, before anything that registers events.
--------------------------------------------------------------------------------

local PeaversCommons = _G.PeaversCommons
local Compat = {}
PeaversCommons.Compat = Compat

--------------------------------------------------------------------------------
-- Which client
--------------------------------------------------------------------------------

-- Which client this is now lives in PeaversCommons.Client, which is the only
-- place that works it out. These are aliases so that code written against Compat
-- keeps reading, and so that the two can never disagree. New code should ask
-- Client directly; what belongs here is the capability half below - the questions
-- answered by asking the client rather than by comparing a version number.
local Client = PeaversCommons.Client

Compat.version = Client.version
Compat.build = Client.build
Compat.interface = Client.interface

Compat.isForever = Client.isForever
Compat.isRetail = Client.isRetail
Compat.isClassic = Client.isClassic
Compat.isClassicEra = Client.isClassicEra
Compat.isAnniversary = Client.isAnniversary
Compat.isMists = Client.isMists
Compat.isModernClient = Client.isModernClient

--------------------------------------------------------------------------------
-- Events
--
-- Registering an event the client does not have is a hard Lua error, and it is
-- raised wherever the registration happens - usually halfway through somebody's
-- initialisation. Asking first costs nothing.
--------------------------------------------------------------------------------

local probe = CreateFrame("Frame")
local eventCache = {}

function Compat.IsEventValid(event)
    local cached = eventCache[event]
    if cached ~= nil then return cached end

    local valid
    if C_EventUtils and C_EventUtils.IsEventValid then
        valid = C_EventUtils.IsEventValid(event) and true or false
    else
        valid = pcall(probe.RegisterEvent, probe, event)
        if valid then probe:UnregisterEvent(event) end
    end

    eventCache[event] = valid
    return valid
end

--------------------------------------------------------------------------------
-- Systems
--------------------------------------------------------------------------------

-- Everything LibEditMode touches while it loads. A client with only some of it
-- would load the library halfway, which is worse than not loading it at all.
Compat.hasEditMode = _G.EditModeManagerFrame ~= nil
    and _G.EditModeSystemSettingsDialog ~= nil
    and _G.C_EditMode ~= nil
    and _G.Enum ~= nil and _G.Enum.EditModeSettingDisplayType ~= nil

Compat.hasSpecializations = type(_G.GetSpecialization) == "function"
    and type(_G.GetSpecializationInfo) == "function"

Compat.hasSettingsPanel = _G.Settings ~= nil
    and type(_G.Settings.RegisterCanvasLayoutCategory) == "function"
    and type(_G.Settings.RegisterAddOnCategory) == "function"

--- The player's specialization index, or nil on a client without them.
function Compat.GetSpecialization()
    if not Compat.hasSpecializations then return nil end
    return GetSpecialization()
end

--- GetSpecializationInfo, or nothing on a client without specializations.
function Compat.GetSpecializationInfo(index)
    if not Compat.hasSpecializations or not index then return nil end
    return GetSpecializationInfo(index)
end

return Compat
