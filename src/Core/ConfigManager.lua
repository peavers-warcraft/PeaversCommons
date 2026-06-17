local PeaversCommons = _G.PeaversCommons
local ConfigManager = {}
PeaversCommons.ConfigManager = ConfigManager

local Utils = PeaversCommons.Utils

--------------------------------------------------------------------------------
-- Shared Configuration Utilities
-- These functions provide common functionality used across all Peavers addons
--------------------------------------------------------------------------------

-- Get the appropriate default font based on client locale
function ConfigManager.GetDefaultFont()
    local locale = GetLocale()
    if locale == "zhCN" then
        return "Fonts\\ARKai_T.ttf"
    elseif locale == "zhTW" then
        return "Fonts\\bLEI00D.ttf"
    elseif locale == "koKR" then
        return "Fonts\\2002.TTF"
    else
        return "Fonts\\FRIZQT__.TTF"
    end
end

-- Check if a font is compatible with the current client locale
function ConfigManager.IsFontCompatibleWithLocale(fontPath)
    local locale = GetLocale()

    if locale == "zhCN" or locale == "zhTW" or locale == "koKR" then
        local incompatibleFonts = {
            ["Fonts\\FRIZQT__.TTF"] = true,
            ["Fonts\\ARIALN.TTF"] = true,
            ["Fonts\\MORPHEUS.TTF"] = true,
            ["Fonts\\SKURRI.TTF"] = true,
        }
        if incompatibleFonts[fontPath] then
            return false
        end
    end
    return true
end

-- Returns a sorted table of available fonts, including those from LibSharedMedia
function ConfigManager.GetFonts()
    local fonts = {
        ["Fonts\\ARIALN.TTF"] = "Arial Narrow",
        ["Fonts\\FRIZQT__.TTF"] = "Default",
        ["Fonts\\MORPHEUS.TTF"] = "Morpheus",
        ["Fonts\\SKURRI.TTF"] = "Skurri",
        ["Fonts\\ARKai_T.ttf"] = "ARKai (Simplified Chinese)",
        ["Fonts\\bLEI00D.ttf"] = "bLEI (Traditional Chinese)",
        ["Fonts\\2002.TTF"] = "2002 (Korean)"
    }

    if LibStub and LibStub:GetLibrary("LibSharedMedia-3.0", true) then
        local LSM = LibStub:GetLibrary("LibSharedMedia-3.0")
        if LSM then
            for name, path in pairs(LSM:HashTable("font")) do
                fonts[path] = name
            end
        end
    end

    local sortedFonts = {}
    for path, name in pairs(fonts) do
        table.insert(sortedFonts, { path = path, name = name })
    end

    table.sort(sortedFonts, function(a, b)
        return a.name < b.name
    end)

    local result = {}
    for _, font in ipairs(sortedFonts) do
        result[font.path] = font.name
    end

    return result
end

-- Returns a sorted table of available statusbar textures from various sources
function ConfigManager.GetBarTextures()
    local textures = {
        ["Interface\\TargetingFrame\\UI-StatusBar"] = "Default",
        ["Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar"] = "Skill Bar",
        ["Interface\\PVPFrame\\UI-PVP-Progress-Bar"] = "PVP Bar",
        ["Interface\\RaidFrame\\Raid-Bar-Hp-Fill"] = "Raid"
    }

    if LibStub and LibStub:GetLibrary("LibSharedMedia-3.0", true) then
        local LSM = LibStub:GetLibrary("LibSharedMedia-3.0")
        if LSM then
            for name, path in pairs(LSM:HashTable("statusbar")) do
                textures[path] = name
            end
        end
    end

    if _G.Details and _G.Details.statusbar_info then
        for _, textureTable in ipairs(_G.Details.statusbar_info) do
            if textureTable.file and textureTable.name then
                textures[textureTable.file] = textureTable.name
            end
        end
    end

    local sortedTextures = {}
    for path, name in pairs(textures) do
        table.insert(sortedTextures, { path = path, name = name })
    end

    table.sort(sortedTextures, function(a, b)
        return a.name < b.name
    end)

    local result = {}
    for _, texture in ipairs(sortedTextures) do
        result[texture.path] = texture.name
    end

    return result
end

-- Common default configuration values shared across addons
ConfigManager.CommonDefaults = {
    -- Frame settings
    frameWidth = 200,
    frameHeight = 100,
    framePoint = "CENTER",
    frameX = 0,
    frameY = 0,
    lockPosition = false,

    -- Bar settings
    barHeight = 20,
    barSpacing = 2,
    barBgAlpha = 0.5,
    barAlpha = 1.0,
    textAlpha = 1.0,
    barTexture = "Interface\\TargetingFrame\\UI-StatusBar",

    -- Font settings (fontFace will be set based on locale)
    fontFace = nil,
    fontSize = 9,
    fontOutline = "OUTLINE",
    fontShadow = false,

    -- Background settings
    bgAlpha = 0.8,
    bgColor = { r = 0, g = 0, b = 0 },

    -- Behavior settings
    showOnLogin = true,
    showTitleBar = true,
    updateInterval = 0.5,
    DEBUG_ENABLED = false,

    -- Custom colors storage
    customColors = {},

    -- Global appearance sync
    useGlobalAppearance = false,
}

--------------------------------------------------------------------------------
-- ConfigManager Instance Methods
--------------------------------------------------------------------------------

function ConfigManager.New(cls, addon, defaultSettings, options)
    local config = {}

    if type(defaultSettings) == "table" and defaultSettings.savedVariablesName then
        options = defaultSettings
        defaultSettings = {}
    end

    options = options or {}

    config.addon = addon

    -- Merge common defaults with addon-specific defaults
    local mergedDefaults = Utils.DeepCopy(ConfigManager.CommonDefaults)
    if defaultSettings then
        for k, v in pairs(defaultSettings) do
            if type(v) == "table" and type(mergedDefaults[k]) == "table" then
                for k2, v2 in pairs(v) do
                    mergedDefaults[k][k2] = v2
                end
            else
                mergedDefaults[k] = v
            end
        end
    end
    config.defaults = mergedDefaults

    local addonName
    if type(addon) == "string" then
        addonName = addon
    elseif type(addon) == "table" and addon.name then
        addonName = addon.name
    else
        error("ConfigManager:New - Invalid addon argument. Must be a string or table with name field")
    end
    
    config.dbName = options.savedVariablesName or (addonName .. "DB")
    config.settingsKey = options.settingsKey
    config.DEBUG_ENABLED = false
    
    for k, v in pairs(config.defaults) do
        config[k] = v
    end
    
    function config:Save()
        if not _G[self.dbName] then
            _G[self.dbName] = {}
        end
        
        local targetTable
        if self.settingsKey then
            if not _G[self.dbName][self.settingsKey] then
                _G[self.dbName][self.settingsKey] = {}
            end
            targetTable = _G[self.dbName][self.settingsKey]
        else
            targetTable = _G[self.dbName]
        end
        
        for k, v in pairs(self) do
            if type(v) ~= "function" and k ~= "addon" and k ~= "dbName" and 
               k ~= "defaults" and k ~= "settingsKey" then
                targetTable[k] = v
            end
        end
        
        return true
    end
    
    function config:Load()
        if not _G[self.dbName] then
            _G[self.dbName] = {}
            return false
        end
        
        local sourceTable
        if self.settingsKey then
            if not _G[self.dbName][self.settingsKey] then
                _G[self.dbName][self.settingsKey] = {}
                return false
            end
            sourceTable = _G[self.dbName][self.settingsKey]
        else
            sourceTable = _G[self.dbName]
        end
        
        for k, v in pairs(sourceTable) do
            self[k] = v
        end
        
        return true
    end
    
    function config:Reset()
        for k, v in pairs(self.defaults) do
            self[k] = v
        end
        
        self:Save()
        
        return true
    end
    
    function config:Initialize()
        self:Load()

        for k, v in pairs(self.defaults) do
            if self[k] == nil then
                self[k] = v
            end
        end

        -- Ensure font is set and compatible with locale
        if not self.fontFace then
            self.fontFace = ConfigManager.GetDefaultFont()
        elseif not ConfigManager.IsFontCompatibleWithLocale(self.fontFace) then
            self.fontFace = ConfigManager.GetDefaultFont()
        end

        self:Save()

        return true
    end

    -- Shared utility methods - these delegate to ConfigManager static methods
    function config:GetFonts()
        return ConfigManager.GetFonts()
    end

    function config:GetBarTextures()
        return ConfigManager.GetBarTextures()
    end

    function config:GetDefaultFont()
        return ConfigManager.GetDefaultFont()
    end

    function config:IsFontCompatibleWithLocale(fontPath)
        return ConfigManager.IsFontCompatibleWithLocale(fontPath)
    end
    
    function config:UpdateSetting(key, value)
        if key then
            self[key] = value
            self:Save()
            return true
        end
        
        return false
    end
    
    function config:GetSetting(key, default)
        if self[key] ~= nil then
            return self[key]
        else
            return default
        end
    end
    
    function config:ToggleSetting(key)
        if key and type(self[key]) == "boolean" then
            self[key] = not self[key]
            self:Save()
            return self[key]
        end

        return nil
    end

    --------------------------------------------------------------------------------
    -- Global Appearance Integration
    --------------------------------------------------------------------------------

    -- Enable global appearance sync for this addon
    -- @param addonName: Unique name for registration
    -- @param callback: Function(key, value) called when global setting changes
    function config:EnableGlobalAppearance(registrationName, callback)
        self.useGlobalAppearance = true

        -- Initialize GlobalAppearance if needed
        if PeaversCommons.GlobalAppearance then
            -- Sync current global settings to this config
            PeaversCommons.GlobalAppearance:SyncToConfig(self)

            -- Register for future updates
            PeaversCommons.GlobalAppearance:RegisterAddon(registrationName, self, callback)
        end

        self:Save()
    end

    -- Disable global appearance sync for this addon
    -- @param addonName: The name used during registration
    function config:DisableGlobalAppearance(registrationName)
        self.useGlobalAppearance = false

        if PeaversCommons.GlobalAppearance then
            PeaversCommons.GlobalAppearance:UnregisterAddon(registrationName)
        end

        self:Save()
    end

    -- Update an appearance setting (updates global if using global appearance)
    -- @param key: The setting key
    -- @param value: The new value
    function config:UpdateAppearanceSetting(key, value)
        self[key] = value

        -- If using global appearance and this is an appearance key, update global
        if self.useGlobalAppearance and PeaversCommons.GlobalAppearance then
            if PeaversCommons.GlobalAppearance:IsAppearanceKey(key) then
                PeaversCommons.GlobalAppearance:Set(key, value)
            end
        end

        self:Save()
    end

    -- Copy current appearance settings to global
    function config:CopyToGlobalAppearance()
        if PeaversCommons.GlobalAppearance then
            PeaversCommons.GlobalAppearance:SyncFromConfig(self)
        end
    end

    return config
end

function ConfigManager.NewProfileBased(cls, addon, defaultSettings, options)
    if type(defaultSettings) == "table" and defaultSettings.savedVariablesName then
        options = defaultSettings
        defaultSettings = {}
    end
    
    options = options or {}
    
    local config = cls:New(addon, defaultSettings, options)

    config.currentProfile = "Default"
    config.profiles = config.profiles or {}

    function config:Save()
        if not _G[self.dbName] then
            _G[self.dbName] = {
                profiles = {},
                currentProfile = self.currentProfile
            }
        end
        
        if not _G[self.dbName].profiles then
            _G[self.dbName].profiles = {}
        end
        
        if not _G[self.dbName].profiles[self.currentProfile] then
            _G[self.dbName].profiles[self.currentProfile] = {}
        end
        
        _G[self.dbName].currentProfile = self.currentProfile
        
        for k, v in pairs(self) do
            if type(v) ~= "function" and k ~= "addon" and k ~= "dbName" and k ~= "defaults" 
               and k ~= "profiles" and k ~= "currentProfile" then
                _G[self.dbName].profiles[self.currentProfile][k] = v
            end
        end
        
        return true
    end
    
    function config:Load()
        if not _G[self.dbName] then
            return false
        end
        
        self.currentProfile = _G[self.dbName].currentProfile or "Default"
        
        if not _G[self.dbName].profiles or not _G[self.dbName].profiles[self.currentProfile] then
            if not _G[self.dbName].profiles then
                _G[self.dbName].profiles = {}
            end
            
            _G[self.dbName].profiles[self.currentProfile] = {}
            
            return false
        end
        
        for k, v in pairs(_G[self.dbName].profiles[self.currentProfile]) do
            self[k] = v
        end
        
        self.profiles = Utils.TableKeys(_G[self.dbName].profiles)
        
        return true
    end
    
    function config:SwitchProfile(profileName)
        if not profileName or profileName == "" then
            return false
        end
        
        self:Save()
        self.currentProfile = profileName
        self:Load()
        
        if not _G[self.dbName].profiles[profileName] then
            for k, v in pairs(self.defaults) do
                self[k] = v
            end
            
            self:Save()
        end
        
        return true
    end
    
    function config:CreateProfile(profileName)
        if not profileName or profileName == "" then
            return false
        end
        
        self:Save()
        self.currentProfile = profileName
        
        for k, v in pairs(self.defaults) do
            self[k] = v
        end
        
        self:Save()
        
        self.profiles = self.profiles or {}
        if not Utils.TableContains(self.profiles, profileName) then
            table.insert(self.profiles, profileName)
        end
        
        return true
    end
    
    function config:DeleteProfile(profileName)
        if not profileName or profileName == "" or profileName == "Default" then
            return false
        end
        
        if profileName == self.currentProfile then
            return false
        end
        
        if not _G[self.dbName] or not _G[self.dbName].profiles then
            return false
        end
        
        _G[self.dbName].profiles[profileName] = nil
        self.profiles = Utils.TableKeys(_G[self.dbName].profiles)

        return true
    end

    return config
end

--------------------------------------------------------------------------------
-- Character-Based Profile Config
-- Creates a config that stores settings per character (Name-Realm)
--------------------------------------------------------------------------------

function ConfigManager.NewCharacterBased(cls, addon, defaultSettings, options)
    options = options or {}

    -- CommonDefaults are now merged in ConfigManager:New()
    local config = cls:New(addon, defaultSettings, options)

    -- Character identification
    config.currentCharacter = nil
    config.currentRealm = nil

    function config:GetPlayerName()
        return UnitName("player")
    end

    function config:GetRealmName()
        return GetRealmName()
    end

    function config:GetCharacterKey()
        return self:GetPlayerName() .. "-" .. self:GetRealmName()
    end

    function config:UpdateCurrentIdentifiers()
        self.currentCharacter = self:GetPlayerName()
        self.currentRealm = self:GetRealmName()
    end

    -- Override Save for character-based profiles
    function config:Save()
        if not _G[self.dbName] then
            _G[self.dbName] = {
                profiles = {},
                global = {}
            }
        end

        _G[self.dbName].profiles = _G[self.dbName].profiles or {}
        _G[self.dbName].global = _G[self.dbName].global or {}

        self:UpdateCurrentIdentifiers()
        local charKey = self:GetCharacterKey()

        if not _G[self.dbName].profiles[charKey] then
            _G[self.dbName].profiles[charKey] = {}
        end

        local profile = _G[self.dbName].profiles[charKey]

        for k, v in pairs(self) do
            if type(v) ~= "function" and k ~= "addon" and k ~= "dbName" and
               k ~= "defaults" and k ~= "settingsKey" and
               k ~= "currentCharacter" and k ~= "currentRealm" then
                profile[k] = v
            end
        end

        return true
    end

    -- Override Load for character-based profiles
    function config:Load()
        if not _G[self.dbName] then
            _G[self.dbName] = {
                profiles = {},
                global = {}
            }
        end

        _G[self.dbName].profiles = _G[self.dbName].profiles or {}
        _G[self.dbName].global = _G[self.dbName].global or {}

        self:UpdateCurrentIdentifiers()
        local charKey = self:GetCharacterKey()

        if not _G[self.dbName].profiles[charKey] then
            _G[self.dbName].profiles[charKey] = {}
            return false
        end

        local profile = _G[self.dbName].profiles[charKey]

        for k, v in pairs(profile) do
            self[k] = v
        end

        return true
    end

    -- Override Initialize for character-based configs
    function config:Initialize()
        self:UpdateCurrentIdentifiers()
        self:Load()

        -- Apply defaults for any missing values
        for k, v in pairs(self.defaults) do
            if self[k] == nil then
                self[k] = v
            end
        end

        -- Ensure font is set and compatible with locale
        if not self.fontFace then
            self.fontFace = ConfigManager.GetDefaultFont()
        elseif not ConfigManager.IsFontCompatibleWithLocale(self.fontFace) then
            self.fontFace = ConfigManager.GetDefaultFont()
        end

        -- Ensure customColors is initialized
        if not self.customColors then
            self.customColors = {}
        end

        -- Sync from global appearance if enabled
        if self.useGlobalAppearance and PeaversCommons.GlobalAppearance then
            PeaversCommons.GlobalAppearance:SyncToConfig(self)
        end

        self:Save()
        return true
    end

    return config
end

--------------------------------------------------------------------------------
-- Character + Spec Based Profile Config
-- Creates a config that stores settings per character and specialization
-- (like PeaversDynamicStats uses)
--------------------------------------------------------------------------------

function ConfigManager.NewCharacterSpecBased(cls, addon, defaultSettings, options)
    options = options or {}

    local config = cls:NewCharacterBased(addon, defaultSettings, options)

    -- Add spec tracking
    config.currentSpec = nil
    config.specIDs = {}

    function config:GetSpecialization()
        local currentSpec = GetSpecialization()
        if not currentSpec then
            return nil
        end
        local specID = GetSpecializationInfo(currentSpec)
        return specID
    end

    function config:GetFullProfileKey()
        local charKey = self:GetCharacterKey()
        local specID = self:GetSpecialization()

        if not specID then
            return charKey
        end

        return charKey .. "-" .. tostring(specID)
    end

    -- Override UpdateCurrentIdentifiers to include spec
    local baseUpdateIdentifiers = config.UpdateCurrentIdentifiers
    function config:UpdateCurrentIdentifiers()
        baseUpdateIdentifiers(self)
        self.currentSpec = self:GetSpecialization()
    end

    -- Override Save for character+spec profiles
    function config:Save()
        if not _G[self.dbName] then
            _G[self.dbName] = {
                profiles = {},
                characters = {},
                global = {}
            }
        end

        _G[self.dbName].profiles = _G[self.dbName].profiles or {}
        _G[self.dbName].characters = _G[self.dbName].characters or {}
        _G[self.dbName].global = _G[self.dbName].global or {}

        self:UpdateCurrentIdentifiers()
        local charKey = self:GetCharacterKey()
        local profileKey = self:GetFullProfileKey()

        -- Initialize character data
        if not _G[self.dbName].characters[charKey] then
            _G[self.dbName].characters[charKey] = {
                lastSpec = self.currentSpec,
                specs = {}
            }
        end

        _G[self.dbName].characters[charKey].lastSpec = self.currentSpec

        if self.currentSpec then
            _G[self.dbName].characters[charKey].specs = _G[self.dbName].characters[charKey].specs or {}
            _G[self.dbName].characters[charKey].specs[tostring(self.currentSpec)] = true
        end

        -- Initialize profile data
        if not _G[self.dbName].profiles[profileKey] then
            _G[self.dbName].profiles[profileKey] = {}
        end

        local profile = _G[self.dbName].profiles[profileKey]

        for k, v in pairs(self) do
            if type(v) ~= "function" and k ~= "addon" and k ~= "dbName" and
               k ~= "defaults" and k ~= "settingsKey" and
               k ~= "currentCharacter" and k ~= "currentRealm" and
               k ~= "currentSpec" and k ~= "specIDs" then
                profile[k] = v
            end
        end

        return true
    end

    -- Override Load for character+spec profiles
    function config:Load()
        if not _G[self.dbName] then
            _G[self.dbName] = {
                profiles = {},
                characters = {},
                global = {}
            }
        end

        _G[self.dbName].profiles = _G[self.dbName].profiles or {}
        _G[self.dbName].characters = _G[self.dbName].characters or {}
        _G[self.dbName].global = _G[self.dbName].global or {}

        self:UpdateCurrentIdentifiers()
        local charKey = self:GetCharacterKey()
        local profileKey = self:GetFullProfileKey()

        -- Initialize character data
        if not _G[self.dbName].characters[charKey] then
            _G[self.dbName].characters[charKey] = {
                lastSpec = self.currentSpec,
                specs = {}
            }
        end

        -- If we don't have a profile for this spec, try to copy from last spec
        if not _G[self.dbName].profiles[profileKey] then
            local lastSpec = _G[self.dbName].characters[charKey].lastSpec
            if lastSpec then
                local lastProfileKey = charKey .. "-" .. lastSpec
                if _G[self.dbName].profiles[lastProfileKey] then
                    _G[self.dbName].profiles[profileKey] = Utils.DeepCopy(_G[self.dbName].profiles[lastProfileKey])
                end
            end
        end

        if not _G[self.dbName].profiles[profileKey] then
            _G[self.dbName].profiles[profileKey] = {}
            return false
        end

        local profile = _G[self.dbName].profiles[profileKey]

        for k, v in pairs(profile) do
            self[k] = v
        end

        return true
    end

    return config
end

--------------------------------------------------------------------------------
-- AceDB-Backed Config
-- Creates a config object backed by AceDB-3.0 for proper profile management.
-- Maintains backward-compatible config.key access via metatable proxy.
--------------------------------------------------------------------------------

function ConfigManager.NewWithAceDB(cls, addon, defaultSettings, options)
    options = options or {}

    if type(defaultSettings) == "table" and defaultSettings.savedVariablesName then
        options = defaultSettings
        defaultSettings = {}
    end

    local addonName
    if type(addon) == "string" then
        addonName = addon
    elseif type(addon) == "table" then
        addonName = addon.name or addon.addonName
            or (options.savedVariablesName and options.savedVariablesName:gsub("DB$", ""))
        if not addonName then
            error("ConfigManager:NewWithAceDB - Cannot determine addon name")
        end
    else
        error("ConfigManager:NewWithAceDB - Invalid addon argument")
    end

    -- Merge common defaults with addon-specific defaults
    local mergedDefaults = Utils.DeepCopy(ConfigManager.CommonDefaults)
    if defaultSettings then
        for k, v in pairs(defaultSettings) do
            if type(v) == "table" and type(mergedDefaults[k]) == "table" then
                for k2, v2 in pairs(v) do
                    mergedDefaults[k][k2] = v2
                end
            else
                mergedDefaults[k] = v
            end
        end
    end

    -- Ensure font default
    if not mergedDefaults.fontFace then
        mergedDefaults.fontFace = ConfigManager.GetDefaultFont()
    end

    local dbName = options.savedVariablesName or (addonName .. "DB")
    local profileType = options.profileType or "shared"

    -- Build AceDB defaults structure
    local aceDefaults = {
        profile = Utils.DeepCopy(mergedDefaults),
        global = {},
        char = {},
    }

    -- AceDB default profile: nil means per-character profiles (CharName - Realm)
    -- Every character gets their own profile automatically
    local defaultProfile = nil

    -- Reserved keys that should NOT proxy to db.profile
    local reservedKeys = {
        addon = true, db = true, dbName = true, defaults = true,
        profileType = true, specFrame = true, onProfileChanged = true,
    }

    -- The config object
    local config = {}
    config.addon = addon
    config.dbName = dbName
    config.defaults = mergedDefaults
    config.profileType = profileType
    config.db = nil
    config.onProfileChanged = options.onProfileChanged

    -- Migrate old SavedVariables format to AceDB format before AceDB sees it
    local function migrateOldFormat()
        local sv = _G[dbName]
        if not sv then return end

        -- Already in AceDB format (has profileKeys)
        if sv.profileKeys then return end

        -- Old flat format: { barHeight = 20, fontSize = 9, ... }
        -- Or old profile format: { profiles = { ["Default"] = {...} }, currentProfile = "..." }
        local hasOldProfiles = sv.profiles and type(sv.profiles) == "table"

        if hasOldProfiles then
            -- Old ProfileBased/CharacterBased format
            local newSV = {
                profileKeys = {},
                profiles = {},
                global = sv.global or {},
                char = {},
            }

            for profileName, profileData in pairs(sv.profiles) do
                newSV.profiles[profileName] = Utils.DeepCopy(profileData)
            end

            -- Map character keys from old format
            if sv.currentProfile then
                -- Simple profile-based: one active profile
                local charKey = UnitName("player") .. " - " .. GetRealmName()
                newSV.profileKeys[charKey] = sv.currentProfile
            elseif sv.characters then
                -- Character+Spec based: map each character
                for charKey, charData in pairs(sv.characters) do
                    local aceCharKey = charKey:gsub("%-", " - ", 1)
                    if charData.lastSpec then
                        local specProfile = charKey .. "-" .. charData.lastSpec
                        if newSV.profiles[specProfile] then
                            newSV.profileKeys[aceCharKey] = specProfile
                        end
                    end
                end
            end

            _G[dbName] = newSV
        else
            -- Flat format: move everything into a "Default" profile
            local settings = {}
            for k, v in pairs(sv) do
                if k ~= "global" then
                    settings[k] = v
                end
            end

            _G[dbName] = {
                profileKeys = {},
                profiles = { ["Default"] = settings },
                global = sv.global or {},
                char = {},
            }
        end
    end

    function config:Initialize()
        migrateOldFormat()

        local AceDB = LibStub("AceDB-3.0")
        self.db = AceDB:New(self.dbName, aceDefaults, defaultProfile)

        -- Set up metatable proxy: config.key reads/writes to db.profile
        local mt = {
            __index = function(t, key)
                if reservedKeys[key] then
                    return rawget(t, key)
                end
                local db = rawget(t, "db")
                if db and db.profile then
                    local val = db.profile[key]
                    if val ~= nil then
                        return val
                    end
                end
                return rawget(t, key)
            end,
            __newindex = function(t, key, value)
                if reservedKeys[key] then
                    rawset(t, key, value)
                    return
                end
                local db = rawget(t, "db")
                if db and db.profile and mergedDefaults[key] ~= nil then
                    db.profile[key] = value
                else
                    rawset(t, key, value)
                end
            end,
        }
        setmetatable(self, mt)

        -- Ensure font compatibility
        if not ConfigManager.IsFontCompatibleWithLocale(self.fontFace) then
            self.fontFace = ConfigManager.GetDefaultFont()
        end

        -- Register profile change callbacks
        self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChangedHandler")
        self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChangedHandler")
        self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChangedHandler")

        -- Set up spec-based auto-switching
        if self.profileType == "spec" then
            self:SetupSpecSwitching()
        end

        -- Sync from global appearance if enabled
        if self.useGlobalAppearance and PeaversCommons.GlobalAppearance then
            PeaversCommons.GlobalAppearance:SyncToConfig(self)
        end

        return true
    end

    function config:OnProfileChangedHandler()
        -- Ensure font compatibility after profile switch
        if not ConfigManager.IsFontCompatibleWithLocale(self.fontFace) then
            self.fontFace = ConfigManager.GetDefaultFont()
        end

        -- Re-sync global appearance if enabled
        if self.useGlobalAppearance and PeaversCommons.GlobalAppearance then
            PeaversCommons.GlobalAppearance:SyncToConfig(self)
        end

        -- Notify the addon
        if self.onProfileChanged then
            self.onProfileChanged()
        end
    end

    -- Save is mostly a no-op with AceDB (it auto-persists), but kept for API compat
    function config:Save()
        return true
    end

    function config:Load()
        return true
    end

    function config:Reset()
        if self.db then
            self.db:ResetProfile()
        end
        return true
    end

    function config:UpdateSetting(key, value)
        if key then
            self[key] = value
            return true
        end
        return false
    end

    function config:GetSetting(key, default)
        local val = self[key]
        if val ~= nil then
            return val
        end
        return default
    end

    function config:ToggleSetting(key)
        if key and type(self[key]) == "boolean" then
            self[key] = not self[key]
            return self[key]
        end
        return nil
    end

    -- Profile management methods (delegate to AceDB)
    function config:SetProfile(name)
        if self.db then
            self.db:SetProfile(name)
        end
    end

    function config:GetCurrentProfile()
        if self.db then
            return self.db:GetCurrentProfile()
        end
        return "Default"
    end

    function config:GetProfiles()
        if self.db then
            return self.db:GetProfiles({})
        end
        return {}
    end

    function config:CopyProfile(name)
        if self.db then
            self.db:CopyProfile(name)
        end
    end

    function config:DeleteProfile(name)
        if self.db and name ~= self:GetCurrentProfile() then
            self.db:DeleteProfile(name)
            return true
        end
        return false
    end

    function config:ResetProfile()
        if self.db then
            self.db:ResetProfile()
        end
    end

    -- Spec-switching support
    function config:SetupSpecSwitching()
        if self.specFrame then return end

        self.specFrame = CreateFrame("Frame")
        self.specFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        self.specFrame:SetScript("OnEvent", function(_, event, unit)
            if unit == "player" or not unit then
                self:OnSpecChanged()
            end
        end)

        -- Apply spec profile on initial setup (defer if spec data isn't available yet)
        if not self:OnSpecChanged() then
            C_Timer.After(1, function() self:OnSpecChanged() end)
        end
    end

    function config:OnSpecChanged()
        if not self.db then return false end

        local specIndex = GetSpecialization()
        if not specIndex then return false end

        local specID, specName = GetSpecializationInfo(specIndex)
        if not specID or not specName then return false end

        local charName = UnitName("player")
        local realm = GetRealmName()
        local profileName = charName .. " - " .. realm .. " (" .. specName .. ")"

        -- Only switch if the profile exists or we should create it
        local profiles = self:GetProfiles()
        local profileExists = false
        for _, p in ipairs(profiles) do
            if p == profileName then
                profileExists = true
                break
            end
        end

        if profileExists then
            self:SetProfile(profileName)
        elseif self:GetCurrentProfile() ~= profileName then
            -- Create the spec profile by copying from current
            local currentProfile = self:GetCurrentProfile()
            self.db:SetProfile(profileName)
            if currentProfile then
                self.db:CopyProfile(currentProfile, true)
            end
        end

        return true
    end

    function config:GetSpecProfileName()
        local specIndex = GetSpecialization()
        if not specIndex then return nil end
        local _, specName = GetSpecializationInfo(specIndex)
        if not specName then return nil end
        local charName = UnitName("player")
        local realm = GetRealmName()
        return charName .. " - " .. realm .. " (" .. specName .. ")"
    end

    -- Shared utility methods
    function config:GetFonts()
        return ConfigManager.GetFonts()
    end

    function config:GetBarTextures()
        return ConfigManager.GetBarTextures()
    end

    function config:GetDefaultFont()
        return ConfigManager.GetDefaultFont()
    end

    function config:IsFontCompatibleWithLocale(fontPath)
        return ConfigManager.IsFontCompatibleWithLocale(fontPath)
    end

    -- Global Appearance integration
    function config:EnableGlobalAppearance(addonNameParam, callback)
        self.useGlobalAppearance = true
        if PeaversCommons.GlobalAppearance then
            PeaversCommons.GlobalAppearance:SyncToConfig(self)
            PeaversCommons.GlobalAppearance:RegisterAddon(addonNameParam, self, callback)
        end
    end

    function config:DisableGlobalAppearance(addonNameParam)
        self.useGlobalAppearance = false
        if PeaversCommons.GlobalAppearance then
            PeaversCommons.GlobalAppearance:UnregisterAddon(addonNameParam)
        end
    end

    function config:UpdateAppearanceSetting(key, value)
        self[key] = value
        if self.useGlobalAppearance and PeaversCommons.GlobalAppearance then
            if PeaversCommons.GlobalAppearance:IsAppearanceKey(key) then
                PeaversCommons.GlobalAppearance:Set(key, value)
            end
        end
    end

    function config:CopyToGlobalAppearance()
        if PeaversCommons.GlobalAppearance then
            PeaversCommons.GlobalAppearance:SyncFromConfig(self)
        end
    end

    return config
end

return ConfigManager