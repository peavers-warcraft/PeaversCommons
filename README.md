# PeaversCommons

A common library for Peavers addons providing shared utilities and UI components.

**Website:** [peavers.io](https://peavers.io) | **Addon Backup:** [vault.peavers.io](https://vault.peavers.io) | **Issues:** [GitHub](https://github.com/peavers-warcraft/PeaversCommons/issues)

## Features

- Standardized event handling
- Slash command registration
- Utility functions (formatting, table operations, player info)
- Common UI components and frame utilities
- Configuration UI framework
- Settings integration
- Patron support system

## Installation

1. Download from [CurseForge](https://www.curseforge.com/wow/addons/peaverscommons)
2. This library is required by other Peavers addons

## For Developers

Add as a dependency in your .toc file:

```
## Dependencies: PeaversCommons
```

### Basic Usage

```lua
local addonName, MyAddon = ...
local PeaversCommons = _G.PeaversCommons

-- Initialize addon
PeaversCommons.Events:Init(addonName, function()
    -- Register events
    PeaversCommons.Events:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        -- Your event handler
    end)
end)

-- Register slash commands
PeaversCommons.SlashCommands:Register(addonName, "myslash", {
    default = function() end,
    config = function() end
})
```

### Available Modules

- **Events**: Event handling and OnUpdate timers
- **SlashCommands**: Slash command registration
- **Utils**: Debug, Print, formatting, table utilities
- **FrameUtils**: UI element creation (buttons, sliders, dropdowns, etc.)
- **ConfigUIUtils**: Settings panel creation
- **ConfigManager**: Configuration handling with defaults
- **SettingsUI**: WoW Settings panel integration
- **Patrons**: Patron support system
