--------------------------------------------------------------------------------
-- PeaversCommons compatibility
--
-- One place that knows which game client this is and what it can do, so the
-- rest of the collection asks a question instead of assuming retail.
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

local version, build, _, interface = GetBuildInfo()
Compat.version = version
Compat.build = tonumber(build)
Compat.interface = tonumber(interface) or 0

local project = _G.WOW_PROJECT_ID
Compat.isRetail = project ~= nil and project == _G.WOW_PROJECT_MAINLINE
Compat.isClassic = not Compat.isRetail

-- By interface number rather than project ID: the project constants for the
-- newer Classic clients have changed names before, the interface number has not.
Compat.isClassicEra = Compat.isClassic and Compat.interface < 20000
Compat.isAnniversary = Compat.isClassic and Compat.interface >= 20000 and Compat.interface < 30000
Compat.isMists = Compat.isClassic and Compat.interface >= 50000 and Compat.interface < 60000

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
