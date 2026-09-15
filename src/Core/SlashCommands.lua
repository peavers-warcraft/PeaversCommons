local PeaversCommons = _G.PeaversCommons
local SlashCommands = PeaversCommons.SlashCommands

local commandHandlers = {}

-- Function to open an addon's settings
local function OpenAddonSettings(addonName)
    -- Get the addon table
    local addon = _G[addonName]
    if not addon then return false end
    
    -- Try each potential settings opener function
    if addon.ConfigUI and addon.ConfigUI.OpenOptions then
        -- Method 1: Use the ConfigUI:OpenOptions() method
        addon.ConfigUI:OpenOptions()
        return true
    elseif addon.Config and addon.Config.OpenOptionsCommand then
        -- Method 2: Use the Config.OpenOptionsCommand() function
        addon.Config.OpenOptionsCommand()
        return true
    elseif addon.directSettingsCategory and Settings and Settings.OpenToCategory then
        -- Method 3: Use direct category reference
        Settings.OpenToCategory(addon.directSettingsCategory)
        return true
    elseif SettingsPanel and SettingsPanel.Open then
        -- Fallback: Open Settings panel to Addons tab
        SettingsPanel:Open()
        if SettingsPanel.AddOnsTab and SettingsPanel.AddOnsTab.Click then
            SettingsPanel.AddOnsTab:Click()
        end
        return true
    end
    return false
end

function SlashCommands:Register(addonName, commandPrefix, handlers)
    local slashName = string.upper(commandPrefix)
    
    _G["SLASH_" .. slashName .. "1"] = "/" .. string.lower(commandPrefix)
    
    commandHandlers[slashName] = handlers or {}
    
    if not commandHandlers[slashName].config then
        commandHandlers[slashName].config = function()
            OpenAddonSettings(addonName)
        end
    end
    
    if not commandHandlers[slashName].help then
        commandHandlers[slashName].help = function()
            print("|cFF00FF00" .. addonName .. " Commands:|r")
            print("  |cFFFFFF00/", string.lower(commandPrefix), "config|r - Open configuration")
            
            for cmd, _ in pairs(commandHandlers[slashName]) do
                if cmd ~= "config" and cmd ~= "help" then
                    print("  |cFFFFFF00/", string.lower(commandPrefix), cmd, "|r")
                end
            end
        end
    end
    
    SlashCmdList[slashName] = function(msg)
        local command, rest = msg:match("^(%S*)%s*(.-)$")
        command = command:lower()
        
        if commandHandlers[slashName][command] then
            commandHandlers[slashName][command](rest)
        elseif command == "" and commandHandlers[slashName].default then
            commandHandlers[slashName].default()
        else
            commandHandlers[slashName].help()
        end
    end
end

function SlashCommands:AddCommand(slashName, command, handler)
    slashName = string.upper(slashName)
    if commandHandlers[slashName] then
        commandHandlers[slashName][command:lower()] = handler
    end
end

return SlashCommands