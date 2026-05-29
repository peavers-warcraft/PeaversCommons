-- PeaversCommons Config Module
local PeaversCommons = _G.PeaversCommons
local Config = {}
PeaversCommons.Config = Config

-- Debug mode - set to true to enable debug messages
Config.DEBUG_ENABLED = true

-- Version information
Config.VERSION = PeaversCommons.version or "1.0"

-- Saved variables
PeaversCommonsDB = PeaversCommonsDB or {}

-- Function to initialize config
function Config:Initialize()
    -- Initialize saved variables if needed
    if not PeaversCommonsDB.config then
        PeaversCommonsDB.config = {}
    end

    -- Load debug setting from saved variables if available
    if PeaversCommonsDB.config.debugEnabled ~= nil then
        Config.DEBUG_ENABLED = PeaversCommonsDB.config.debugEnabled
    end

    if PeaversCommonsDB.config.promoteInChat == nil then
        PeaversCommonsDB.config.promoteInChat = false
    end

    return true
end

-- Function to save config
function Config:Save()
    PeaversCommonsDB.config = PeaversCommonsDB.config or {}
    PeaversCommonsDB.config.debugEnabled = Config.DEBUG_ENABLED
    PeaversCommonsDB.config.promoteInChat = PeaversCommonsDB.config.promoteInChat or false
    return true
end

-- Function to toggle debug mode
function Config:ToggleDebug()
    Config.DEBUG_ENABLED = not Config.DEBUG_ENABLED
    self:Save()
    return Config.DEBUG_ENABLED
end

-- Return the module
return Config