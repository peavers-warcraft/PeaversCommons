# PeaversCommons

Common library for Peavers addons.

### New!
Check out [peavers.io](https://peavers.io) and [bootstrap.peavers.io](https://bootstrap.peavers.io) for all my WoW addons and support.

## Features

- Standardized event handling
- Consistent slash command registration
- Utility functions
- Common UI components
- Frame creation and management utilities
- Configuration UI framework
- Settings integration
- Patron support system

## Usage

1. Add this addon as a dependency in your .toc file:

```
## Dependencies: PeaversCommons
```

2. Access the library in your addon code:

```lua
-- In your Main.lua or other core files
local addonName, MyAddon = ...
local PeaversCommons = _G.PeaversCommons

-- Register slash commands
PeaversCommons.SlashCommands:Register(addonName, "myslash", {
    default = function()
        -- Your default command handler
    end,
    config = function()
        -- Open configuration
    end
})

-- Initialize addon
PeaversCommons.Events:Init(addonName, function()
    -- Initialize your addon components

    -- Register events
    PeaversCommons.Events:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        -- Your event handler
    end)

    -- Set up update timers
    PeaversCommons.Events:RegisterOnUpdate(0.5, function(elapsed)
        -- Do something periodically
    end, "MyAddon_Update")
end)
```

## Event Handling

```lua
-- Register an event
PeaversCommons.Events:RegisterEvent("EVENT_NAME", function(event, ...)
    -- Handle event
end)

-- Unregister an event
PeaversCommons.Events:UnregisterEvent("EVENT_NAME")

-- Register OnUpdate handler
PeaversCommons.Events:RegisterOnUpdate(interval, handler, "unique_key")

-- Unregister OnUpdate handler
PeaversCommons.Events:UnregisterOnUpdate("unique_key")
```

## Slash Commands

```lua
-- Register slash commands
PeaversCommons.SlashCommands:Register(addonName, "cmd", {
    default = function()
        -- Default command with no args
    end,
    config = function()
        -- Called when user types "/cmd config"
    end,
    help = function()
        -- Called when user types "/cmd help"
        -- Also called when an unrecognized subcommand is used
    end
})

-- Add a new command handler later
PeaversCommons.SlashCommands:AddCommand("cmd", "newcmd", function()
    -- This will be called when user types "/cmd newcmd"
end)
```

## Utility Functions

```lua
-- Debug messages (only shown if addon.Config.DEBUG_ENABLED is true)
PeaversCommons.Utils.Debug(addon, "Debug message")

-- User-facing messages
PeaversCommons.Utils.Print(addon, "User message")

-- Data manipulation
local copy = PeaversCommons.Utils.DeepCopy(table)
local merged = PeaversCommons.Utils.MergeDefaults(target, defaults)

-- Number formatting (adds K, M suffixes)
local formatted = PeaversCommons.Utils.FormatNumber(1234567) -- "1.2M"
local percent = PeaversCommons.Utils.FormatPercent(0.1234) -- "12.34%"
local change = PeaversCommons.Utils.FormatChange(-0.1234) -- "-12.34"
local rounded = PeaversCommons.Utils.Round(1.2345, 2) -- 1.23
local money = PeaversCommons.Utils.FormatMoney(12345) -- "1g 23s 45c"
local time = PeaversCommons.Utils.FormatTime(3665) -- "1h 1m"

-- Table utilities
local contains = PeaversCommons.Utils.TableContains(table, value) -- true/false
local key = PeaversCommons.Utils.TableFindKey(table, value) -- returns key or nil
local count = PeaversCommons.Utils.TableCount(table) -- number of entries
local keys = PeaversCommons.Utils.TableKeys(table) -- array of keys

-- Player information
local playerInfo = PeaversCommons.Utils.GetPlayerInfo()
-- Returns name, realm, fullName, class, classID, className, level, spec info
local charKey = PeaversCommons.Utils.GetCharacterKey() -- "PlayerName-Realm"

-- Combat check
local inCombat = PeaversCommons.Utils.IsInCombat()
```

## Patron Support System

The Patron Support System provides a way to display and thank supporters across all your addons.

### Setup in your addon

1. Add the patron template to your addon:

```lua
-- In your addon's initialization
local addonName, MyAddon = ...

-- Copy the patrons_template.lua to your addon's Utils directory
-- or include it directly from PeaversCommons
local Patrons = MyAddon.Patrons or {}
MyAddon.Patrons = Patrons

-- Initialize patrons support in your addon's initialization
function MyAddon:OnInitialize()
    -- Initialize other components

    -- Initialize patrons support
    if MyAddon.Patrons and MyAddon.Patrons.Initialize then
        MyAddon.Patrons:Initialize()
    end
end
```

### Managing patrons

To add, remove, or access patrons centrally from any addon:

```lua
-- Add a patron (from any addon)
PeaversCommons.Patrons:AddPatron("PatronName", "gold")  -- tiers: bronze, silver, gold, platinum

-- Add multiple patrons at once
PeaversCommons.Patrons:AddPatrons({
    { name = "Patron1", tier = "platinum" },
    { name = "Patron2", tier = "gold" },
    "Patron3"  -- uses default "bronze" tier
})

-- Remove a patron
PeaversCommons.Patrons:RemovePatron("PatronName")

-- Get all patrons
local allPatrons = PeaversCommons.Patrons:GetAll()

-- Get patrons sorted by tier (platinum -> gold -> silver -> bronze) and then by name
local sortedPatrons = PeaversCommons.Patrons:GetSorted()

-- Get patrons of a specific tier
local goldPatrons = PeaversCommons.Patrons:GetByTier("gold")
```

The patrons list is maintained centrally and will appear in all addons that implement the patron system.

## Frame Core and UI Utilities

The Frame Core module provides a standard implementation for creating addon frames with consistent behavior.

```lua
-- Create a frame core for your addon
local addonName, MyAddon = ...
local PeaversCommons = _G.PeaversCommons

-- Initialize core components
function MyAddon:InitializeFrame()
    local options = {
        frameName = "MyAddonFrame",
        width = 200,
        height = 300,
        showTitleBar = true,
        backgroundColor = {r = 0, g = 0, b = 0, a = 0.5},
        createBars = true
    }

    MyAddon.Core = PeaversCommons.FrameCore:New(MyAddon, options)
    MyAddon.Core:Initialize()
end
```

### Frame Utilities

The FrameUtils module provides utilities for creating UI elements:

```lua
local FrameUtils = PeaversCommons.FrameUtils

-- Create common UI elements
local header = FrameUtils.CreateSectionHeader(parent, "My Section", 10, -10)
local label = FrameUtils.CreateLabel(parent, "Label Text", 10, -30)
local checkbox = FrameUtils.CreateCheckbox(parent, "MyCheckbox", "Enable Feature", 10, -50, true, nil, myOnClickHandler)
local button = FrameUtils.CreateButton(parent, "MyButton", "Click Me", 10, -80, 120, 25, myButtonHandler)
local slider = FrameUtils.CreateSlider(parent, "MySlider", 0, 100, 5, 10, -120, 50)
local dropdown = FrameUtils.CreateDropdown(parent, "MyDropdown", 10, -160, 150, "Select an option")
local colorPicker = FrameUtils.CreateColorPicker(parent, "MyColorPicker", "Choose Color", 10, -200, {r=1,g=0,b=0}, myColorHandler)
local scrollFrame, content = FrameUtils.CreateScrollFrame(parent)
local separator = FrameUtils.CreateSeparator(parent, 10, -250, 200)
local frame = FrameUtils.CreateFrame("MyFrame", parent, 200, 300, {backdrop info})
```

### Configuration UI Utilities

The ConfigUIUtils module provides higher-level utilities for creating configuration options:

```lua
local ConfigUIUtils = PeaversCommons.ConfigUIUtils

-- Create a settings panel with consistent styling
local panel = ConfigUIUtils.CreateSettingsPanel("My Addon", "Configuration options for My Addon")
local yPos = panel.yPos
local baseSpacing = panel.baseSpacing

-- Add UI elements to the panel
local header, newY = ConfigUIUtils.CreateSectionHeader(panel.content, "Display Settings", baseSpacing, yPos)
yPos = newY - 10

-- Create sliders, color pickers, etc. with consistent styling
local container, slider = ConfigUIUtils.CreateSlider(
    panel.content, "MySlider", "Width", 50, 300, 10,
    200, 400,
    function(value)
        -- Handle value change
    end
)
container:SetPoint("TOPLEFT", baseSpacing + 15, yPos)
yPos = yPos - 60

-- Add a "NEW" badge to highlight new features
local badge = ConfigUIUtils.CreateNewBadge(panel.content, header, 10, 0)

-- Update the content height when done adding elements
panel:UpdateContentHeight(yPos)
```

## Configuration Manager

The ConfigManager module provides a standardized way to handle addon configurations:

```lua
local addonName, MyAddon = ...
local PeaversCommons = _G.PeaversCommons

-- Create a standard config object
MyAddon.Config = PeaversCommons.ConfigManager.New(addonName, {
    -- Default settings
    frameWidth = 200,
    frameHeight = 300,
    showTitleBar = true,
    bgColor = {r = 0, g = 0, b = 0, a = 0.5},
    customColors = {},
    showStats = {
        CRIT = true,
        HASTE = true,
        MASTERY = true
    }
})

-- Or create a profile-based config with per-character or per-spec settings
MyAddon.Config = PeaversCommons.ConfigManager.NewProfileBased(addonName, {
    -- Default settings (same as above)
}, {
    useSharedProfile = false,  -- Whether to use shared profile or per-spec profile
    perCharacter = true,      -- Whether profiles are per-character or global
})

-- Access settings
local width = MyAddon.Config.frameWidth

-- Save changes
MyAddon.Config.frameWidth = 250
MyAddon.Config:Save()

-- Reset to defaults
MyAddon.Config:ResetToDefaults()
```

## Settings UI Integration

The SettingsUI module provides a standard way to integrate with WoW's Settings panel:

```lua
local addonName, MyAddon = ...
local PeaversCommons = _G.PeaversCommons

-- Create settings pages for your addon
function MyAddon:InitializeSettings()
    -- Create the settings pages factory
    MyAddon.settingsPages = PeaversCommons.SettingsUI.CreateSettingsPages(MyAddon)

    -- Add a main settings page
    MyAddon.settingsPages:AddMainPage(function(mainPage)
        -- Add UI elements to the main page
        -- Returns the main page panel object
        return MyAddon.ConfigUI:CreateMainOptions(mainPage)
    end)

    -- Add a sub-page
    MyAddon.settingsPages:AddSubPage("Advanced", function(subPage)
        -- Add UI elements to the sub-page
        -- Returns the sub-page panel object
        return MyAddon.ConfigUI:CreateAdvancedOptions(subPage)
    end)

    -- Register all pages with WoW's Settings UI
    MyAddon.settingsPages:Register()
end
```

<!-- Workflow triggered: 2025-06-16T10:45:58.347298 -->
