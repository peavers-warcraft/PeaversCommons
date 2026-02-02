-- PeaversCommons SettingsPanels Module
-- Provides pre-built reusable settings panels for configuration UIs
local PeaversCommons = _G.PeaversCommons
local SettingsPanels = {}
PeaversCommons.SettingsPanels = SettingsPanels

-- Dependencies
local ConfigSchema = PeaversCommons.ConfigSchema
local ConfigControls = PeaversCommons.ConfigControls
local ConfigUIUtils = PeaversCommons.ConfigUIUtils
local DefaultConfig = PeaversCommons.DefaultConfig
local FrameUtils = PeaversCommons.FrameUtils

-- PanelBuilder class for fluent panel construction
local PanelBuilder = {}
PanelBuilder.__index = PanelBuilder

function PanelBuilder:New(addonRef, config, schema)
    local self = setmetatable({}, PanelBuilder)
    self.addonRef = addonRef
    self.config = config
    self.schema = schema or {}
    self.sections = {}
    self.controls = {}
    return self
end

-- Add a section with specified keys
-- @param sectionName string - section header text
-- @param keys table - list of config keys to include
-- @return self for chaining
function PanelBuilder:AddSection(sectionName, keys)
    table.insert(self.sections, {
        type = "section",
        name = sectionName,
        keys = keys,
    })
    return self
end

-- Add a subsection with specified keys
-- @param subsectionName string - subsection label text
-- @param keys table - list of config keys to include
-- @return self for chaining
function PanelBuilder:AddSubsection(subsectionName, keys)
    table.insert(self.sections, {
        type = "subsection",
        name = subsectionName,
        keys = keys,
    })
    return self
end

-- Add a custom section with a builder function
-- @param sectionName string - section header text
-- @param builderFunc function - function(content, y, baseSpacing, addonRef) returns newY
-- @return self for chaining
function PanelBuilder:AddCustomSection(sectionName, builderFunc)
    table.insert(self.sections, {
        type = "custom",
        name = sectionName,
        builder = builderFunc,
    })
    return self
end

-- Add a separator
-- @return self for chaining
function PanelBuilder:AddSeparator()
    table.insert(self.sections, {
        type = "separator",
    })
    return self
end

-- Build the panel contents
-- @param content frame - content frame to build into
-- @param startY number - starting Y position
-- @param baseSpacing number - base indentation
-- @return endY - final Y position
function PanelBuilder:Build(content, startY, baseSpacing)
    local y = startY

    for _, section in ipairs(self.sections) do
        if section.type == "section" then
            y = ConfigControls.CreateSection(
                content, section.name, section.keys,
                self.schema, self.config, y, baseSpacing, self.addonRef
            )
            y = y - 15 -- Add spacing after section
        elseif section.type == "subsection" then
            y = ConfigControls.CreateSubsection(
                content, section.name, section.keys,
                self.schema, self.config, y, baseSpacing, self.addonRef
            )
            y = y - 10 -- Add spacing after subsection
        elseif section.type == "custom" then
            -- Add section header
            local header, newY = ConfigUIUtils.CreateSectionHeader(content, section.name, baseSpacing, y)
            y = newY - 10

            -- Call custom builder
            y = section.builder(content, y, baseSpacing, self.addonRef)
            y = y - 15 -- Add spacing after custom section
        elseif section.type == "separator" then
            local UI = self.addonRef and self.addonRef.UI
            if UI and UI.CreateSeparator then
                local _, newY = UI:CreateSeparator(content, baseSpacing, y)
                y = newY - baseSpacing
            else
                local _, newY = FrameUtils.CreateSeparator(content, baseSpacing, y)
                y = newY - baseSpacing
            end
        end
    end

    return y
end

-- Refresh all controls in this builder
function PanelBuilder:RefreshAll()
    ConfigControls.RefreshAll()
end

SettingsPanels.PanelBuilder = PanelBuilder

-- Pre-built panel factories

-- Create a standard appearance panel with display and bar settings
-- @param addonRef table - addon reference
-- @param config table - config object
-- @param schema table - schema definitions
-- @param customSections table - optional custom sections to add { { name = "Name", keys = {...} } }
-- @return function - builder function(content, y, baseSpacing) returns newY
function SettingsPanels.CreateAppearancePanel(addonRef, config, schema, customSections)
    return function(content, y, baseSpacing)
        local builder = PanelBuilder:New(addonRef, config, schema)

        -- Display Settings
        builder:AddSection("Display Settings", { "frameWidth", "bgAlpha" })
        builder:AddSubsection("Visibility Options", { "showTitleBar", "lockPosition" })

        builder:AddSeparator()

        -- Bar Appearance
        builder:AddSection("Bar Appearance", { "barHeight", "barSpacing", "barBgAlpha", "barAlpha" })
        builder:AddSubsection("Bar Style", { "barTexture" })

        -- Add custom sections if provided
        if customSections then
            for _, section in ipairs(customSections) do
                builder:AddSeparator()
                if section.builder then
                    builder:AddCustomSection(section.name, section.builder)
                elseif section.keys then
                    builder:AddSection(section.name, section.keys)
                end
            end
        end

        return builder:Build(content, y, baseSpacing)
    end
end

-- Create a standard text settings panel
-- @param addonRef table - addon reference
-- @param config table - config object
-- @param schema table - schema definitions
-- @return function - builder function(content, y, baseSpacing) returns newY
function SettingsPanels.CreateTextPanel(addonRef, config, schema)
    return function(content, y, baseSpacing)
        local builder = PanelBuilder:New(addonRef, config, schema)

        builder:AddSection("Text Settings", { "fontFace", "fontSize" })
        builder:AddSubsection("Font Style", { "fontOutline", "fontShadow" })

        return builder:Build(content, y, baseSpacing)
    end
end

-- Create a standard behavior settings panel
-- @param addonRef table - addon reference
-- @param config table - config object
-- @param schema table - schema definitions
-- @return function - builder function(content, y, baseSpacing) returns newY
function SettingsPanels.CreateBehaviorPanel(addonRef, config, schema)
    return function(content, y, baseSpacing)
        local builder = PanelBuilder:New(addonRef, config, schema)

        builder:AddSection("Behavior Settings", { "hideOutOfCombat", "displayMode", "updateInterval" })

        return builder:Build(content, y, baseSpacing)
    end
end

-- Create a complete standard settings panel with common sections
-- @param addonRef table - addon reference
-- @param config table - config object
-- @param schema table - schema definitions
-- @param options table - panel options { title, description, appearance, text, behavior, customSections }
-- @return panel - the created settings panel
function SettingsPanels.CreateStandardPanel(addonRef, config, schema, options)
    options = options or {}

    local panel = ConfigUIUtils.CreateSettingsPanel(
        options.title or "Settings",
        options.description or "Configuration options"
    )

    local content = panel.content
    local y = panel.yPos
    local baseSpacing = panel.baseSpacing

    local builder = PanelBuilder:New(addonRef, config, schema)

    -- Display Settings section (if appearance is enabled)
    if options.appearance ~= false then
        builder:AddSection("Display Settings", { "frameWidth", "bgAlpha" })
        builder:AddSubsection("Visibility Options", { "showTitleBar", "lockPosition" })
        builder:AddSeparator()

        -- Bar Appearance
        builder:AddSection("Bar Appearance", { "barHeight", "barSpacing", "barBgAlpha", "barAlpha" })
        builder:AddSubsection("Bar Style", { "barTexture" })
        builder:AddSeparator()
    end

    -- Custom appearance sections
    if options.customSections then
        for _, section in ipairs(options.customSections) do
            if section.builder then
                builder:AddCustomSection(section.name, section.builder)
            elseif section.keys then
                builder:AddSection(section.name, section.keys)
            end
            builder:AddSeparator()
        end
    end

    -- Text Settings section (if text is enabled)
    if options.text ~= false then
        builder:AddSection("Text Settings", { "fontFace", "fontSize" })
        builder:AddSubsection("Font Style", { "fontOutline", "fontShadow" })
        builder:AddSeparator()
    end

    -- Behavior Settings section (if behavior is enabled)
    if options.behavior ~= false then
        builder:AddSection("Behavior Settings", { "hideOutOfCombat", "displayMode" })
        if options.updateInterval ~= false then
            builder:AddSubsection("Update Settings", { "updateInterval" })
        end
    end

    y = builder:Build(content, y, baseSpacing)

    panel:UpdateContentHeight(y)
    panel.builder = builder

    return panel
end

-- Create a minimal panel with just the most essential settings
-- @param addonRef table - addon reference
-- @param config table - config object
-- @param schema table - schema definitions
-- @param title string - panel title
-- @param description string - panel description
-- @return panel - the created settings panel
function SettingsPanels.CreateMinimalPanel(addonRef, config, schema, title, description)
    local panel = ConfigUIUtils.CreateSettingsPanel(
        title or "Settings",
        description or "Configuration options"
    )

    local content = panel.content
    local y = panel.yPos
    local baseSpacing = panel.baseSpacing

    local builder = PanelBuilder:New(addonRef, config, schema)

    builder:AddSection("Display", { "frameWidth", "bgAlpha", "showTitleBar", "lockPosition" })
    builder:AddSeparator()
    builder:AddSection("Appearance", { "barHeight", "barTexture", "fontFace", "fontSize" })

    y = builder:Build(content, y, baseSpacing)

    panel:UpdateContentHeight(y)
    panel.builder = builder

    return panel
end

return SettingsPanels
