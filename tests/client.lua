--------------------------------------------------------------------------------
-- Core/Client.lua, driven against stand-in globals.
--
--   Run: lua tests/client.lua        (from the addon root)
--
-- Plain Lua on purpose. Which game a client is gets decided from one number, the
-- rule for reading it is not obvious, and getting it wrong is expensive but
-- invisible - WoW Forever was identified as retail by one addon and as Classic Era
-- by another, and both looked fine until somebody played on it. Given an interface
-- number there is exactly one right answer, and none of it needs a game client to
-- check.
--
-- Not addon code, and not packaged (see .pkgmeta). It overwrites globals on
-- purpose to drive the file under test.
--------------------------------------------------------------------------------

local CASES = {
    { iface = 120100, ver = "12.1.0", key = "retail", modern = true,
      timed = "Mythic+", short = "M+", unmanaged = "battleground, arena, scenario" },

    -- The one that broke things. Vanilla content on a retail-generation client,
    -- reporting WOW_PROJECT_ID as mainline and sharing major version 1 with Era.
    { iface = 16001, ver = "1.60.1", key = "forever", modern = true,
      timed = nil, short = nil, unmanaged = "battleground" },

    { iface = 11509, ver = "1.15.9", key = "era", modern = false,
      timed = nil, short = nil, unmanaged = "battleground" },
    { iface = 20506, ver = "2.5.6", key = "anniversary", modern = false,
      timed = nil, short = nil, unmanaged = "battleground, arena" },
    { iface = 50504, ver = "5.5.4", key = "mists", modern = false,
      timed = "Challenge Mode", short = "CM", unmanaged = "battleground, arena, scenario" },

    -- An interface nobody has seen yet must read as retail, so an unfamiliar
    -- client keeps today's behaviour instead of quietly losing features.
    { iface = 130000, ver = "13.0.0", key = "retail", modern = true,
      timed = "Mythic+", short = "M+", unmanaged = "battleground, arena, scenario" },
}

local failures = 0

local function check(label, got, want)
    if got ~= want then
        failures = failures + 1
        print(("  FAIL %s: got %s, want %s"):format(label, tostring(got), tostring(want)))
    end
end

for _, case in ipairs(CASES) do
    -- Fresh globals per case: the module reads GetBuildInfo once, at load.
    ---@diagnostic disable-next-line: missing-fields
    _G.PeaversCommons = {}
    _G.GetBuildInfo = function() return case.ver, "69893", "", case.iface end

    -- A client that claims the Cooldown Manager as loudly as Forever does.
    _G.C_CooldownViewer = { IsCooldownViewerAvailable = function() return true end }
    _G.EssentialCooldownViewer = {}

    local Client = assert(loadfile("src/Core/Client.lua"))()

    print(("%-12s %s"):format(case.key, Client:Describe()))

    check(case.key .. ".key", Client.key, case.key)
    check(case.key .. ".interface", Client.interface, case.iface)
    check(case.key .. ".isModernClient", Client.isModernClient, case.modern)
    check(case.key .. ".timedDungeonName", Client.timedDungeonName, case.timed)
    check(case.key .. ".timedDungeonShort", Client.timedDungeonShort, case.short)
    check(case.key .. ".hasTimedDungeons", Client.hasTimedDungeons, case.timed ~= nil)
    check(case.key .. ".unmanagedInstanceText", Client.unmanagedInstanceText, case.unmanaged)

    -- Exactly one identity, always. Overlapping ranges are the failure mode that
    -- put Forever in two places at once.
    local claimed = 0
    for _, flag in ipairs({ Client.isRetail, Client.isForever, Client.isClassicEra,
        Client.isAnniversary, Client.isMists }) do
        if flag then claimed = claimed + 1 end
    end
    check(case.key .. " claims exactly one identity", claimed, 1)
    check(case.key .. ".isClassic agrees", Client.isClassic,
        case.key == "era" or case.key == "anniversary" or case.key == "mists")

    -- Only retail has a Cooldown Manager. Forever must refuse it however loudly
    -- the client says yes - the stubs above say yes as loudly as it does - and the
    -- Classic clients never had one.
    check(case.key .. ".hasCooldownManager", Client.hasCooldownManager, case.key == "retail")
end

if failures == 0 then
    print("\nall " .. #CASES .. " clients read correctly")
else
    print("\n" .. failures .. " failure(s)")
end

os.exit(failures == 0 and 0 or 1)
