--------------------------------------------------------------------------------
-- GlobalAppearance Module
-- Manages shared appearance settings across all Peavers addons
-- Stored in PeaversCommonsDB.globalAppearance
--------------------------------------------------------------------------------

local PeaversCommons = _G.PeaversCommons
PeaversCommons.GlobalAppearance = {}
local GlobalAppearance = PeaversCommons.GlobalAppearance

local ConfigManager = PeaversCommons.ConfigManager

--------------------------------------------------------------------------------
-- Appearance Keys
-- These are the settings that can be synced across addons
--------------------------------------------------------------------------------

GlobalAppearance.Keys = {
    -- Bar appearance
    "barHeight",
    "barSpacing",
    "barAlpha",
    "barBgAlpha",
    "barTexture",

    -- Font settings
    "fontFace",
    "fontSize",
    "fontOutline",
    "fontShadow",

    -- Background settings
    "bgAlpha",
    "bgColor",

    -- Title bar
    "showTitleBar",
}

-- Create a lookup table for fast checking
GlobalAppearance.KeyLookup = {}
for _, key in ipairs(GlobalAppearance.Keys) do
    GlobalAppearance.KeyLookup[key] = true
end

--------------------------------------------------------------------------------
-- Registered Addons
-- Addons register here to receive updates when global appearance changes
--------------------------------------------------------------------------------

GlobalAppearance.registeredAddons = {}

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function GlobalAppearance:Initialize()
    -- Ensure PeaversCommonsDB exists
    if not _G.PeaversCommonsDB then
        _G.PeaversCommonsDB = {}
    end

    -- Initialize global appearance with defaults if not present
    if not _G.PeaversCommonsDB.globalAppearance then
        _G.PeaversCommonsDB.globalAppearance = self:GetDefaults()
    end

    -- Ensure all keys exist
    local defaults = self:GetDefaults()
    for key, value in pairs(defaults) do
        if _G.PeaversCommonsDB.globalAppearance[key] == nil then
            _G.PeaversCommonsDB.globalAppearance[key] = value
        end
    end
end

function GlobalAppearance:GetDefaults()
    local defaults = {}
    for _, key in ipairs(self.Keys) do
        if ConfigManager.CommonDefaults[key] ~= nil then
            local value = ConfigManager.CommonDefaults[key]
            -- Deep copy tables
            if type(value) == "table" then
                defaults[key] = PeaversCommons.Utils.DeepCopy(value)
            else
                defaults[key] = value
            end
        end
    end

    -- Ensure font has a value
    if not defaults.fontFace then
        defaults.fontFace = ConfigManager.GetDefaultFont()
    end

    return defaults
end

--------------------------------------------------------------------------------
-- Get/Set Global Appearance
--------------------------------------------------------------------------------

function GlobalAppearance:Get(key)
    self:Initialize()

    if key then
        return _G.PeaversCommonsDB.globalAppearance[key]
    end

    return _G.PeaversCommonsDB.globalAppearance
end

function GlobalAppearance:Set(key, value)
    self:Initialize()

    if not self.KeyLookup[key] then
        return false
    end

    -- Deep copy tables
    if type(value) == "table" then
        _G.PeaversCommonsDB.globalAppearance[key] = PeaversCommons.Utils.DeepCopy(value)
    else
        _G.PeaversCommonsDB.globalAppearance[key] = value
    end

    -- Notify all registered addons
    self:NotifyAddons(key, value)

    return true
end

function GlobalAppearance:SetMultiple(settings)
    self:Initialize()

    local changed = {}
    for key, value in pairs(settings) do
        if self.KeyLookup[key] then
            if type(value) == "table" then
                _G.PeaversCommonsDB.globalAppearance[key] = PeaversCommons.Utils.DeepCopy(value)
            else
                _G.PeaversCommonsDB.globalAppearance[key] = value
            end
            changed[key] = value
        end
    end

    -- Notify all registered addons
    for key, value in pairs(changed) do
        self:NotifyAddons(key, value)
    end

    return true
end

--------------------------------------------------------------------------------
-- Addon Registration
--------------------------------------------------------------------------------

-- Register an addon to receive global appearance updates
-- @param addonName: Unique identifier for the addon
-- @param config: The addon's config object (must have useGlobalAppearance field)
-- @param callback: Function(key, value) called when global setting changes
function GlobalAppearance:RegisterAddon(addonName, config, callback)
    self.registeredAddons[addonName] = {
        config = config,
        callback = callback,
    }
end

function GlobalAppearance:UnregisterAddon(addonName)
    self.registeredAddons[addonName] = nil
end

-- Notify all registered addons of a setting change
function GlobalAppearance:NotifyAddons(key, value)
    for addonName, addon in pairs(self.registeredAddons) do
        -- Only notify addons that are using global appearance
        if addon.config and addon.config.useGlobalAppearance then
            -- Update the addon's config
            addon.config[key] = value

            -- Call the callback if provided
            if addon.callback then
                addon.callback(key, value)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Sync Helpers
--------------------------------------------------------------------------------

-- Copy global appearance settings to an addon's config
function GlobalAppearance:SyncToConfig(config)
    self:Initialize()

    local global = _G.PeaversCommonsDB.globalAppearance

    for _, key in ipairs(self.Keys) do
        if global[key] ~= nil then
            if type(global[key]) == "table" then
                config[key] = PeaversCommons.Utils.DeepCopy(global[key])
            else
                config[key] = global[key]
            end
        end
    end
end

-- Copy an addon's config settings to global appearance
function GlobalAppearance:SyncFromConfig(config)
    self:Initialize()

    for _, key in ipairs(self.Keys) do
        if config[key] ~= nil then
            if type(config[key]) == "table" then
                _G.PeaversCommonsDB.globalAppearance[key] = PeaversCommons.Utils.DeepCopy(config[key])
            else
                _G.PeaversCommonsDB.globalAppearance[key] = config[key]
            end
        end
    end
end

-- Check if a key is a global appearance key
function GlobalAppearance:IsAppearanceKey(key)
    return self.KeyLookup[key] == true
end

--------------------------------------------------------------------------------
-- Reset
--------------------------------------------------------------------------------

function GlobalAppearance:Reset()
    _G.PeaversCommonsDB.globalAppearance = self:GetDefaults()

    -- Notify all registered addons
    for _, key in ipairs(self.Keys) do
        self:NotifyAddons(key, _G.PeaversCommonsDB.globalAppearance[key])
    end
end

return GlobalAppearance
