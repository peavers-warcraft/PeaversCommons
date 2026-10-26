--------------------------------------------------------------------------------
-- Core/VisibilityManager.lua, driven against stand-in globals.
--
--   Run: lua tests/visibility.lua        (from the addon root)
--
-- Which kind of place the player is in comes from three APIs that disagree at
-- the edges: a keystone is a "party" instance, a delve is a "scenario", and
-- neither says so until you ask about the difficulty. Given those answers there
-- is one right content type, and none of it needs a client to check.
--
-- Not addon code, and not packaged (see .pkgmeta). It overwrites globals on
-- purpose to drive the file under test.
---@diagnostic disable: undefined-global, duplicate-set-field, lowercase-global, missing-fields
--------------------------------------------------------------------------------

local world = {}

_G = _G or _ENV
_G.PeaversCommons = {}
_G.IsInInstance = function() return world.inInstance, world.instanceType end
_G.GetInstanceInfo = function() return "Somewhere", world.instanceType, world.difficultyID end
_G.C_ChallengeMode = { IsChallengeModeActive = function() return world.keyActive end }
_G.C_PartyInfo = { IsDelveInProgress = function() return world.delve end }
_G.IsInGroup = function() return world.group end
_G.IsInRaid = function() return world.raid end
_G.InCombatLockdown = function() return world.combat end

dofile("src/Core/VisibilityManager.lua")
local VM = PeaversCommons.VisibilityManager

local failures = 0
local function check(label, got, want)
    if got ~= want then
        failures = failures + 1
        print(("FAIL %s: got %s, want %s"):format(label, tostring(got), tostring(want)))
    end
end

local CONTENT = {
    { "open world", {}, "OPEN_WORLD" },
    { "normal dungeon", { inInstance = true, instanceType = "party", difficultyID = 1 }, "DUNGEON" },
    { "keystone before the timer", { inInstance = true, instanceType = "party", difficultyID = 8 }, "MYTHIC_PLUS" },
    { "keystone running", { inInstance = true, instanceType = "party", difficultyID = 8, keyActive = true }, "MYTHIC_PLUS" },
    { "raid", { inInstance = true, instanceType = "raid", difficultyID = 16 }, "RAID" },
    { "delve by difficulty", { inInstance = true, instanceType = "scenario", difficultyID = 208 }, "DELVE" },
    { "delve by flag", { inInstance = true, instanceType = "scenario", difficultyID = 0, delve = true }, "DELVE" },
    { "other scenario", { inInstance = true, instanceType = "scenario", difficultyID = 12 }, "SCENARIO" },
    { "battleground", { inInstance = true, instanceType = "pvp" }, "PVP" },
    { "arena", { inInstance = true, instanceType = "arena" }, "PVP" },
}

for _, case in ipairs(CONTENT) do
    world = case[2]
    check(case[1], VM:GetContentType(), case[3])
end

-- An addon that offers no content settings is shown everywhere, as before.
world = { inInstance = true, instanceType = "scenario", difficultyID = 208 }
check("no content keys", VM:ShouldBeVisible({}), true)
check("delves off", VM:ShouldBeVisible({ showInDelve = false }), false)
check("other content off", VM:ShouldBeVisible({ showInRaid = false }), true)

-- Content combines with the existing rules rather than replacing them.
world = { inInstance = true, instanceType = "raid", difficultyID = 16, raid = true, group = true }
check("raid allowed, out of combat hidden", VM:ShouldBeVisible({ hideOutOfCombat = true }), false)
world.combat = true
check("raid allowed, in combat", VM:ShouldBeVisible({ hideOutOfCombat = true }), true)
check("party only in a raid", VM:ShouldBeVisible({ displayMode = "PARTY_ONLY" }), false)

-- UpdateVisibility applies what ShouldBeVisible decides.
local shown
local frame = { Show = function() shown = true end, Hide = function() shown = false end }
world = { inInstance = true, instanceType = "party", difficultyID = 8 }
VM:UpdateVisibility(frame, { showInMythicPlus = false })
check("UpdateVisibility hides", shown, false)
VM:UpdateVisibility(frame, { showInMythicPlus = true })
check("UpdateVisibility shows", shown, true)

if failures > 0 then
    print(failures .. " failure(s)")
    os.exit(1)
end
print("visibility: all passed")
