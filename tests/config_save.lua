--------------------------------------------------------------------------------
-- Core/ConfigManager.lua Save and Load, driven against stand-in globals.
--
--   Run: lua tests/config_save.lua        (from the addon root)
--
-- A setting set to nil has to leave SavedVariables. Save used to copy keys
-- across and never remove one, so the old value sat on disk and Load brought it
-- back at the next login. PeaversUI found it: a finished layout preview kept
-- announcing itself on every /reload, and its undo slot - never cleared - would
-- roll an install back to a snapshot from days earlier.
--
-- Each case is a login, a change, a /reload (Load against what Save left in the
-- global), and a check of what came back.
--
-- Not addon code, and not packaged (see .pkgmeta). It overwrites globals on
-- purpose to drive the file under test.
---@diagnostic disable: undefined-global, lowercase-global, missing-fields
--------------------------------------------------------------------------------

local function DeepCopy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = DeepCopy(v) end
    return out
end

_G.PeaversCommons = {
    Utils = {
        DeepCopy = DeepCopy,
        TableKeys = function(t)
            local keys = {}
            for k in pairs(t) do keys[#keys + 1] = k end
            return keys
        end,
    },
    Compat = {
        GetSpecialization = function() return 1 end,
        GetSpecializationInfo = function() return 102 end,
    },
}
_G.GetLocale = function() return "enUS" end
_G.UnitName = function() return "Brown Bear" end
_G.GetRealmName = function() return "Classic Beta PvE" end

local ConfigManager = assert(loadfile("src/Core/ConfigManager.lua"))()
    or _G.PeaversCommons.ConfigManager

-- The font path is decided through Theme, which this test has no reason to load.
ConfigManager.GetDefaultFont = function() return "Fonts\\FRIZQT__.TTF" end
ConfigManager.IsFontCompatibleWithLocale = function() return true end

local failures, checks = 0, 0

local function check(label, got, want)
    checks = checks + 1
    if got ~= want then
        failures = failures + 1
        print(("  FAIL %s: got %s, want %s"):format(label, tostring(got), tostring(want)))
    end
end

-- A fresh config over whatever the global holds now: what a /reload does.
local function Login(constructor, defaults, options)
    local config = ConfigManager[constructor](ConfigManager, { name = "Test" }, defaults, options)
    config:Initialize()
    return config
end

-- The saved table a given kind of config writes its settings into.
local SAVED = {
    New = function(db) return db end,
    NewProfileBased = function(db) return db.profiles.Default end,
    NewCharacterBased = function(db) return db.profiles["Brown Bear-Classic Beta PvE"] end,
    NewCharacterSpecBased = function(db) return db.profiles["Brown Bear-Classic Beta PvE-102"] end,
}

for _, kind in ipairs({ "New", "NewProfileBased", "NewCharacterBased", "NewCharacterSpecBased" }) do
    _G.TestDB = nil
    local defaults = { installedVersion = false, pending = false }
    local options = { savedVariablesName = "TestDB" }

    -- First login: set a value, and a table holding one.
    local config = Login(kind, defaults, options)
    config.installedVersion = "1.0.16"
    config.previewRestore = { layout = "peavers" }
    config:Save()

    -- Second login: both came back. Then clear them the way PeaversUI does.
    config = Login(kind, defaults, options)
    check(kind .. " keeps a value across a reload", config.installedVersion, "1.0.16")
    check(kind .. " keeps a table across a reload",
        type(config.previewRestore) == "table" and config.previewRestore.layout, "peavers")
    config.previewRestore = nil
    config:Save()
    check(kind .. " removes a cleared key from the saved table",
        SAVED[kind](_G.TestDB).previewRestore, nil)

    -- Third login: the cleared key stays cleared, the untouched one survives.
    config = Login(kind, defaults, options)
    check(kind .. " does not resurrect a cleared key", config.previewRestore, nil)
    check(kind .. " leaves the other settings alone", config.installedVersion, "1.0.16")

    -- Something another piece of code wrote straight into the saved table is not
    -- this config's to delete.
    SAVED[kind](_G.TestDB).writtenElsewhere = true
    config:Save()
    check(kind .. " leaves keys it never owned", SAVED[kind](_G.TestDB).writtenElsewhere, true)

    -- Bookkeeping never reaches disk, however many times Save runs.
    check(kind .. " does not save the defaults table", SAVED[kind](_G.TestDB).defaults, nil)
    check(kind .. " does not save the dbName", SAVED[kind](_G.TestDB).dbName, nil)
end

-- Reset promises that keys the defaults do not name are gone. They were only
-- gone from memory: the next login read them back off disk.
do
    _G.TestDB = nil
    local options = { savedVariablesName = "TestDB" }
    local config = Login("New", { wanted = 1 }, options)
    config.scratch = "left behind"
    config:Save()

    config = Login("New", { wanted = 1 }, options)
    config:Reset()
    config = Login("New", { wanted = 1 }, options)
    check("Reset drops an unknown key for good", config.scratch, nil)
    check("Reset keeps the defaults", config.wanted, 1)
end

-- The settingsKey form writes into a sub-table, and clears from there too.
do
    _G.TestDB = nil
    local options = { savedVariablesName = "TestDB", settingsKey = "settings" }
    local config = Login("New", {}, options)
    config.notice = true
    config:Save()
    config = Login("New", {}, options)
    config.notice = nil
    config:Save()
    check("settingsKey: cleared key leaves the sub-table", _G.TestDB.settings.notice, nil)
end

if failures == 0 then
    print("\nall " .. checks .. " checks passed")
else
    print("\n" .. failures .. " of " .. checks .. " check(s) failed")
end

os.exit(failures == 0 and 0 or 1)
