--------------------------------------------------------------------------------
-- AddonInit Module
-- Provides standardized initialization boilerplate for Peavers addons
--------------------------------------------------------------------------------

local PeaversCommons = _G.PeaversCommons
local AddonInit = {}
PeaversCommons.AddonInit = AddonInit

-- Default required modules that all Peavers addons need
local DEFAULT_REQUIRED_MODULES = {"Events", "SlashCommands", "Utils"}

-- Check if PeaversCommons has all required modules
-- @param addonName: Name of the addon for error messages
-- @param requiredModules: Optional table of required module names (defaults to standard set)
-- @return boolean: Whether all modules are available
function AddonInit:CheckDependencies(addonName, requiredModules)
    requiredModules = requiredModules or DEFAULT_REQUIRED_MODULES

    for _, module in ipairs(requiredModules) do
        if not PeaversCommons[module] then
            print("|cffff0000Error:|r " .. addonName .. " requires PeaversCommons." .. module .. " which is missing.")
            return false
        end
    end

    return true
end

-- Initialize module namespaces for an addon
-- @param addon: The addon table
-- @param modules: Table of module names to initialize (e.g., {"Core", "UI", "Config"})
function AddonInit:InitializeModules(addon, modules)
    for _, moduleName in ipairs(modules) do
        addon[moduleName] = addon[moduleName] or {}
    end
end

-- Set up version and addon name metadata
-- @param addon: The addon table
-- @param addonName: The addon's folder/TOC name
function AddonInit:SetupMetadata(addon, addonName)
    addon.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "1.0.0"
    addon.addonName = addonName
    addon.name = addonName
end

-- Create a standard toggle display function
-- @param addon: The addon table (must have Core.frame)
-- @param functionName: Global function name (e.g., "ToggleStatsDisplay")
-- @return function: The toggle function
function AddonInit:CreateToggleFunction(addon, functionName)
    local toggleFunc = function()
        if addon.Core and addon.Core.frame then
            if addon.Core.frame:IsShown() then
                addon.Core.frame:Hide()
            else
                addon.Core.frame:Show()
            end
        end
    end

    -- Make globally accessible
    if functionName then
        _G[functionName] = toggleFunc
    end

    return toggleFunc
end

-- Register standard slash commands for an addon
-- @param addonName: Addon name
-- @param slashCmd: Slash command (e.g., "pds")
-- @param addon: Addon table
-- @param toggleFunc: Function to toggle display
-- @param extraCommands: Optional table of additional commands {name = function}
function AddonInit:RegisterSlashCommands(addonName, slashCmd, addon, toggleFunc, extraCommands)
    local commands = {
        default = toggleFunc,
        config = function()
            if addon.ConfigUI and addon.ConfigUI.OpenOptions then
                addon.ConfigUI:OpenOptions()
            end
        end,
        debug = function()
            if addon.Config then
                addon.Config.DEBUG_ENABLED = not addon.Config.DEBUG_ENABLED
                if addon.Utils and addon.Utils.Print then
                    if addon.Config.DEBUG_ENABLED then
                        addon.Utils.Print("Debug mode ENABLED")
                    else
                        addon.Utils.Print("Debug mode DISABLED")
                    end
                end
                if addon.Config.Save then
                    addon.Config:Save()
                end
            end
        end
    }

    -- Merge extra commands
    if extraCommands then
        for name, func in pairs(extraCommands) do
            commands[name] = func
        end
    end

    PeaversCommons.SlashCommands:Register(addonName, slashCmd, commands)
end

-- Create settings pages using SettingsUI
-- @param addon: Addon table
-- @param addonName: Addon name (e.g., "PeaversDynamicStats")
-- @param displayName: Display title (e.g., "Peavers Dynamic Stats")
-- @param description: Description text
-- @param slashCommands: Table of slash command strings to display
-- @param delay: Optional delay before creating (default 0.5)
function AddonInit:CreateSettingsPages(addon, addonName, displayName, description, slashCommands, delay)
    delay = delay or 0.5

    C_Timer.After(delay, function()
        local mainPanel, settingsPanel = PeaversCommons.SettingsUI:CreateSettingsPages(
            addon,
            addonName,
            displayName,
            description,
            slashCommands
        )

        -- Hook OnShow to refresh UI when settings panel is displayed
        if settingsPanel and addon.ConfigUI and addon.ConfigUI.RefreshUI then
            settingsPanel:HookScript("OnShow", function()
                addon.ConfigUI:RefreshUI()
            end)
        end

        return mainPanel, settingsPanel
    end)
end

-- Register common event handlers that most addons need
-- @param addon: Addon table
function AddonInit:RegisterCommonEvents(addon)
    -- Save on logout
    PeaversCommons.Events:RegisterEvent("PLAYER_LOGOUT", function()
        if addon.Config and addon.Config.Save then
            addon.Config:Save()
        end
    end)

    -- Combat state tracking with visibility updates
    PeaversCommons.Events:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        if addon.Core then
            addon.Core.inCombat = true
            if addon.Core.UpdateFrameVisibility then
                addon.Core:UpdateFrameVisibility()
            end
        end
    end)

    PeaversCommons.Events:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if addon.Core then
            addon.Core.inCombat = false
            if addon.Core.UpdateFrameVisibility then
                addon.Core:UpdateFrameVisibility()
            end
        end
        if addon.Config and addon.Config.Save then
            addon.Config:Save()
        end
    end)

    -- Group changes for visibility
    PeaversCommons.Events:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        if addon.Core and addon.Core.UpdateFrameVisibility then
            addon.Core:UpdateFrameVisibility()
        end
    end)
end

-- Full setup helper that combines all common initialization
-- @param addon: Addon table
-- @param addonName: Addon name
-- @param options: Table with configuration options:
--   - modules: Table of module names to initialize
--   - slashCommand: Slash command string (e.g., "pds")
--   - toggleFunctionName: Global toggle function name
--   - displayName: Settings panel display name
--   - description: Settings panel description
--   - slashCommandHelp: Table of slash command help strings
--   - extraSlashCommands: Extra slash command handlers
--   - requiredModules: Custom required modules list
-- @return boolean: Whether setup was successful
function AddonInit:Setup(addon, addonName, options)
    options = options or {}

    -- Check dependencies first
    if not self:CheckDependencies(addonName, options.requiredModules) then
        return false
    end

    -- Initialize module namespaces
    if options.modules then
        self:InitializeModules(addon, options.modules)
    end

    -- Set up metadata
    self:SetupMetadata(addon, addonName)

    -- Create toggle function
    local toggleFunc = self:CreateToggleFunction(addon, options.toggleFunctionName)

    -- Register slash commands
    if options.slashCommand then
        self:RegisterSlashCommands(
            addonName,
            options.slashCommand,
            addon,
            toggleFunc,
            options.extraSlashCommands
        )
    end

    return true
end

return AddonInit
