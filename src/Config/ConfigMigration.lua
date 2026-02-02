-- PeaversCommons ConfigMigration Module
-- Provides utilities for migrating saved configuration data
local PeaversCommons = _G.PeaversCommons
local ConfigMigration = {}
PeaversCommons.ConfigMigration = ConfigMigration

-- Deep copy a table
local function deepCopy(source)
    if type(source) ~= "table" then
        return source
    end

    local copy = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            copy[key] = deepCopy(value)
        else
            copy[key] = value
        end
    end

    return copy
end

-- Run migrations on a saved variables database
-- @param dbName string - name of the saved variables global (e.g., "PeaversSystemBarsDB")
-- @param migrations table - list of migration functions { version = function(db) }
-- @return boolean - true if any migrations were run
function ConfigMigration.Migrate(dbName, migrations)
    local db = _G[dbName]
    if not db then
        return false
    end

    -- Initialize version tracking if not present
    if not db._version then
        db._version = 0
    end

    local migrationsRun = false
    local sortedVersions = {}

    -- Sort migration versions
    for version in pairs(migrations) do
        table.insert(sortedVersions, version)
    end
    table.sort(sortedVersions)

    -- Run migrations in order
    for _, version in ipairs(sortedVersions) do
        if db._version < version then
            local migrationFunc = migrations[version]
            if migrationFunc then
                local success, err = pcall(migrationFunc, db)
                if success then
                    db._version = version
                    migrationsRun = true
                else
                    -- Log migration error but continue
                    if PeaversCommons.Debug and PeaversCommons.Debug.Print then
                        PeaversCommons.Debug.Print("Migration error for version " .. version .. ": " .. tostring(err))
                    end
                end
            end
        end
    end

    return migrationsRun
end

-- Rename a key in a data table
-- @param data table - the data table to modify
-- @param oldKey string - the old key name
-- @param newKey string - the new key name
-- @return boolean - true if the key was renamed
function ConfigMigration.RenameKey(data, oldKey, newKey)
    if data[oldKey] ~= nil and data[newKey] == nil then
        data[newKey] = data[oldKey]
        data[oldKey] = nil
        return true
    end
    return false
end

-- Convert a value using a converter function
-- @param data table - the data table to modify
-- @param key string - the key to convert
-- @param converter function - function(oldValue) returns newValue
-- @return boolean - true if the value was converted
function ConfigMigration.ConvertValue(data, key, converter)
    if data[key] ~= nil then
        local newValue = converter(data[key])
        if newValue ~= nil then
            data[key] = newValue
            return true
        end
    end
    return false
end

-- Migrate multiple profiles in a database
-- @param db table - the database containing profiles
-- @param profileMigrations table - list of migration functions to apply to each profile
-- @return number - count of profiles migrated
function ConfigMigration.MigrateProfiles(db, profileMigrations)
    if not db or not db.profiles then
        return 0
    end

    local count = 0

    for profileKey, profile in pairs(db.profiles) do
        for _, migration in ipairs(profileMigrations) do
            local success, err = pcall(migration, profile, profileKey)
            if success then
                count = count + 1
            else
                if PeaversCommons.Debug and PeaversCommons.Debug.Print then
                    PeaversCommons.Debug.Print("Profile migration error for " .. profileKey .. ": " .. tostring(err))
                end
            end
        end
    end

    return count
end

-- Copy default values to a config, only setting values that don't exist
-- @param config table - the config to apply defaults to
-- @param defaults table - the default values
function ConfigMigration.ApplyDefaults(config, defaults)
    for key, value in pairs(defaults) do
        if config[key] == nil then
            if type(value) == "table" then
                config[key] = deepCopy(value)
            else
                config[key] = value
            end
        end
    end
end

-- Migrate from flat database to profiles structure
-- @param db table - the database to migrate
-- @param getProfileKey function - function() returns profileKey for current character
-- @param keysToMigrate table - list of keys to move to profile
-- @return boolean - true if migration was performed
function ConfigMigration.MigrateToProfiles(db, getProfileKey, keysToMigrate)
    if not db then
        return false
    end

    -- Check if we have old-style flat data
    local hasOldData = false
    for _, key in ipairs(keysToMigrate) do
        if db[key] ~= nil then
            hasOldData = true
            break
        end
    end

    if not hasOldData then
        return false
    end

    -- Initialize new structure
    db.profiles = db.profiles or {}
    db.characters = db.characters or {}
    db.global = db.global or {}

    -- Get profile key
    local profileKey = getProfileKey()
    if not profileKey then
        return false
    end

    -- Create profile if it doesn't exist
    if not db.profiles[profileKey] then
        db.profiles[profileKey] = {}
    end

    -- Move old data to profile
    local profile = db.profiles[profileKey]
    for _, key in ipairs(keysToMigrate) do
        if db[key] ~= nil then
            if type(db[key]) == "table" then
                profile[key] = deepCopy(db[key])
            else
                profile[key] = db[key]
            end
            db[key] = nil
        end
    end

    return true
end

-- Common converters for use with ConvertValue

-- Convert a boolean sort preference to a string sort option
ConfigMigration.Converters = {
    -- Convert old boolean sortByIlvl to new string sortOption
    SortByIlvlToSortOption = function(oldValue)
        if type(oldValue) == "boolean" then
            return oldValue and "ILVL_DESC" or "NAME_ASC"
        end
        return oldValue
    end,

    -- Convert old font outline string to boolean
    FontOutlineToBoolean = function(oldValue)
        if type(oldValue) == "string" then
            return oldValue == "OUTLINE" or oldValue == "THICKOUTLINE"
        end
        return oldValue
    end,

    -- Convert boolean font outline to string
    FontOutlineBooleanToString = function(oldValue)
        if type(oldValue) == "boolean" then
            return oldValue and "OUTLINE" or ""
        end
        return oldValue
    end,

    -- Ensure color table has proper keys
    NormalizeColor = function(oldValue)
        if type(oldValue) ~= "table" then
            return { r = 1, g = 1, b = 1 }
        end

        return {
            r = oldValue.r or oldValue[1] or 1,
            g = oldValue.g or oldValue[2] or 1,
            b = oldValue.b or oldValue[3] or 1,
        }
    end,
}

-- Get a list of common config keys for migration
function ConfigMigration.GetCommonKeys()
    return {
        -- Frame settings
        "frameWidth", "frameHeight", "framePoint", "frameX", "frameY", "lockPosition",
        -- Bar settings
        "barWidth", "barHeight", "barSpacing", "barTexture", "barAlpha", "barBgAlpha",
        -- Font settings
        "fontFace", "fontSize", "fontOutline", "fontShadow",
        -- Background settings
        "bgAlpha", "bgColor",
        -- Visibility settings
        "showOnLogin", "showTitleBar",
        -- Behavior settings
        "hideOutOfCombat", "displayMode", "updateInterval",
        -- Common extras
        "showStats", "customColors",
    }
end

return ConfigMigration
