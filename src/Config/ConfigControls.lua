-- PeaversCommons ConfigControls Module
-- Provides schema-driven UI control creation for configuration panels
local PeaversCommons = _G.PeaversCommons
local ConfigControls = {}
PeaversCommons.ConfigControls = ConfigControls

-- Dependencies
local ConfigSchema = PeaversCommons.ConfigSchema
local DefaultConfig = PeaversCommons.DefaultConfig
local ConfigUIUtils = PeaversCommons.ConfigUIUtils
local FrameUtils = PeaversCommons.FrameUtils
local Utils = PeaversCommons.Utils

-- Storage for bound controls that need refreshing
ConfigControls.boundControls = {}

-- Create a control from a schema definition
-- @param parent frame - parent frame for the control
-- @param key string - config key
-- @param schema table - schema definition
-- @param config table - config object to bind to
-- @param y number - Y position
-- @param indent number - X indentation
-- @param width number - control width
-- @param addonRef table - addon reference for refresh callbacks
-- @return control, newY - the created control and new Y position
function ConfigControls.CreateFromSchema(parent, key, schema, config, y, indent, width, addonRef)
    if not schema then
        return nil, y
    end

    local schemaType = schema.type
    width = width or schema.width or 400

    if schemaType == ConfigSchema.Types.NUMBER or schemaType == ConfigSchema.Types.INTEGER then
        return ConfigControls.CreateBoundSlider(parent, key, schema.label or key, schema, config, y, indent, width, addonRef)
    elseif schemaType == ConfigSchema.Types.BOOLEAN then
        return ConfigControls.CreateBoundCheckbox(parent, key, schema.label or key, schema, config, y, indent, addonRef)
    elseif schemaType == ConfigSchema.Types.DROPDOWN then
        return ConfigControls.CreateBoundDropdown(parent, key, schema.label or key, schema, config, y, indent, width, addonRef)
    elseif schemaType == ConfigSchema.Types.COLOR then
        return ConfigControls.CreateBoundColorPicker(parent, key, schema.label or key, schema, config, y, indent, addonRef)
    elseif schemaType == ConfigSchema.Types.FONT then
        return ConfigControls.CreateBoundFontDropdown(parent, key, schema.label or key, config, y, indent, width, addonRef)
    elseif schemaType == ConfigSchema.Types.TEXTURE then
        return ConfigControls.CreateBoundTextureDropdown(parent, key, schema.label or key, config, y, indent, width, addonRef)
    end

    return nil, y
end

-- Create a bound slider that auto-saves and auto-refreshes
function ConfigControls.CreateBoundSlider(parent, key, label, schema, config, y, indent, width, addonRef)
    local currentValue = config[key]
    if currentValue == nil then
        currentValue = schema.default or schema.min or 0
    end

    local container, slider, labelText = ConfigUIUtils.CreateSlider(
        parent,
        "PeaversSlider" .. key,
        label,
        schema.min,
        schema.max,
        schema.step,
        currentValue,
        width,
        function(value)
            config[key] = value
            if config.Save then
                config:Save()
            end
            -- Call refresh callback if provided
            if addonRef and addonRef.OnConfigChanged then
                addonRef.OnConfigChanged(key, value)
            end
        end
    )

    container:SetPoint("TOPLEFT", indent, y)

    -- Store reference for refresh
    local controlRef = {
        type = "slider",
        key = key,
        control = slider,
        config = config,
    }
    table.insert(ConfigControls.boundControls, controlRef)

    return slider, y - 55
end

-- Create a bound checkbox that auto-saves and auto-refreshes
function ConfigControls.CreateBoundCheckbox(parent, key, label, schema, config, y, indent, addonRef)
    local currentValue = config[key]
    if currentValue == nil then
        currentValue = schema.default or false
    end

    local checkbox, newY = ConfigUIUtils.CreateCheckbox(
        parent,
        "PeaversCheckbox" .. key,
        label,
        indent,
        y,
        currentValue,
        function(checked)
            config[key] = checked
            if config.Save then
                config:Save()
            end
            if addonRef and addonRef.OnConfigChanged then
                addonRef.OnConfigChanged(key, checked)
            end
        end
    )

    -- Store reference for refresh
    local controlRef = {
        type = "checkbox",
        key = key,
        control = checkbox,
        config = config,
    }
    table.insert(ConfigControls.boundControls, controlRef)

    return checkbox, newY - 8
end

-- Create a bound dropdown that auto-saves and auto-refreshes
function ConfigControls.CreateBoundDropdown(parent, key, label, schema, config, y, indent, width, addonRef)
    local currentValue = config[key]
    if currentValue == nil then
        currentValue = schema.default
    end

    local currentText = schema.options[currentValue] or "Select..."

    local container, dropdown = ConfigUIUtils.CreateDropdown(
        parent,
        "PeaversDropdown" .. key,
        label,
        schema.options,
        currentText,
        width,
        function(value)
            config[key] = value
            if config.Save then
                config:Save()
            end
            if addonRef and addonRef.OnConfigChanged then
                addonRef.OnConfigChanged(key, value)
            end
        end
    )

    container:SetPoint("TOPLEFT", indent, y)

    -- Store reference for refresh
    local controlRef = {
        type = "dropdown",
        key = key,
        control = dropdown,
        config = config,
        options = schema.options,
    }
    table.insert(ConfigControls.boundControls, controlRef)

    return dropdown, y - 65
end

-- Create a bound color picker that auto-saves and auto-refreshes
function ConfigControls.CreateBoundColorPicker(parent, key, label, schema, config, y, indent, addonRef)
    local currentValue = config[key]
    if currentValue == nil then
        currentValue = schema.default or { r = 1, g = 1, b = 1 }
    end

    local resetHandler = nil
    if schema.hasReset then
        resetHandler = function()
            local defaultColor = schema.default or { r = 1, g = 1, b = 1 }
            config[key] = { r = defaultColor.r, g = defaultColor.g, b = defaultColor.b }
            if config.Save then
                config:Save()
            end
            if schema.resetCallback then
                schema.resetCallback()
            end
            if addonRef and addonRef.OnConfigChanged then
                addonRef.OnConfigChanged(key, config[key])
            end
        end
    end

    local colorContainer, colorPicker, resetButton, newY = ConfigUIUtils.CreateColorPicker(
        parent,
        "PeaversColorPicker" .. key,
        label,
        indent,
        y,
        currentValue,
        function(r, g, b)
            config[key] = { r = r, g = g, b = b }
            if config.Save then
                config:Save()
            end
            if addonRef and addonRef.OnConfigChanged then
                addonRef.OnConfigChanged(key, config[key])
            end
        end,
        resetHandler
    )

    -- Store reference for refresh
    local controlRef = {
        type = "colorpicker",
        key = key,
        control = colorPicker,
        config = config,
    }
    table.insert(ConfigControls.boundControls, controlRef)

    return colorPicker, newY
end

-- Create a bound font dropdown that auto-saves and auto-refreshes
function ConfigControls.CreateBoundFontDropdown(parent, key, label, config, y, indent, width, addonRef)
    local fonts = DefaultConfig.GetFonts()
    local currentValue = config[key] or DefaultConfig.GetDefaultFont()
    local currentText = fonts[currentValue] or "Default"

    local container, dropdown = ConfigUIUtils.CreateDropdown(
        parent,
        "PeaversFontDropdown" .. key,
        label,
        fonts,
        currentText,
        width,
        function(value)
            config[key] = value
            if config.Save then
                config:Save()
            end
            if addonRef and addonRef.OnConfigChanged then
                addonRef.OnConfigChanged(key, value)
            end
        end
    )

    container:SetPoint("TOPLEFT", indent, y)

    -- Store reference for refresh
    local controlRef = {
        type = "fontdropdown",
        key = key,
        control = dropdown,
        config = config,
    }
    table.insert(ConfigControls.boundControls, controlRef)

    return dropdown, y - 65
end

-- Create a bound texture dropdown that auto-saves and auto-refreshes
function ConfigControls.CreateBoundTextureDropdown(parent, key, label, config, y, indent, width, addonRef)
    local textures = DefaultConfig.GetBarTextures()
    local currentValue = config[key] or "Interface\\TargetingFrame\\UI-StatusBar"
    local currentText = textures[currentValue] or "Default"

    local container, dropdown = ConfigUIUtils.CreateDropdown(
        parent,
        "PeaversTextureDropdown" .. key,
        label,
        textures,
        currentText,
        width,
        function(value)
            config[key] = value
            if config.Save then
                config:Save()
            end
            if addonRef and addonRef.OnConfigChanged then
                addonRef.OnConfigChanged(key, value)
            end
        end
    )

    container:SetPoint("TOPLEFT", indent, y)

    -- Store reference for refresh
    local controlRef = {
        type = "texturedropdown",
        key = key,
        control = dropdown,
        config = config,
    }
    table.insert(ConfigControls.boundControls, controlRef)

    return dropdown, y - 65
end

-- Create a section with multiple controls from schema
-- @param parent frame - parent frame
-- @param sectionName string - section header text
-- @param keys table - list of config keys to create controls for
-- @param schema table - schema definitions
-- @param config table - config object
-- @param y number - starting Y position
-- @param baseSpacing number - base indentation
-- @param addonRef table - addon reference
-- @return newY - new Y position after all controls
function ConfigControls.CreateSection(parent, sectionName, keys, schema, config, y, baseSpacing, addonRef)
    local controlIndent = baseSpacing + 15
    local sliderWidth = 400

    -- Section header
    local header, newY = ConfigUIUtils.CreateSectionHeader(parent, sectionName, baseSpacing, y)
    y = newY - 10

    -- Create controls for each key
    for _, key in ipairs(keys) do
        local keySchema = schema[key]
        if keySchema then
            local control
            control, y = ConfigControls.CreateFromSchema(parent, key, keySchema, config, y, controlIndent, sliderWidth, addonRef)
        end
    end

    return y
end

-- Create a subsection with a label and controls
-- @param parent frame - parent frame
-- @param subsectionName string - subsection label text
-- @param keys table - list of config keys to create controls for
-- @param schema table - schema definitions
-- @param config table - config object
-- @param y number - starting Y position
-- @param baseSpacing number - base indentation
-- @param addonRef table - addon reference
-- @return newY - new Y position after all controls
function ConfigControls.CreateSubsection(parent, subsectionName, keys, schema, config, y, baseSpacing, addonRef)
    local controlIndent = baseSpacing + 15
    local sliderWidth = 400

    -- Subsection label
    local label, newY = ConfigUIUtils.CreateSubsectionLabel(parent, subsectionName, controlIndent, y)
    y = newY - 8

    -- Create controls for each key
    for _, key in ipairs(keys) do
        local keySchema = schema[key]
        if keySchema then
            local control
            control, y = ConfigControls.CreateFromSchema(parent, key, keySchema, config, y, controlIndent, sliderWidth, addonRef)
        end
    end

    return y
end

-- Refresh all bound controls to match current config values
function ConfigControls.RefreshAll()
    for _, controlRef in ipairs(ConfigControls.boundControls) do
        local value = controlRef.config[controlRef.key]

        if controlRef.type == "slider" then
            if controlRef.control and value then
                controlRef.control:SetValue(value)
            end
        elseif controlRef.type == "checkbox" then
            if controlRef.control then
                controlRef.control:SetChecked(value or false)
            end
        elseif controlRef.type == "dropdown" then
            if controlRef.control and controlRef.options then
                local text = controlRef.options[value] or "Select..."
                UIDropDownMenu_SetText(controlRef.control, text)
            end
        elseif controlRef.type == "colorpicker" then
            if controlRef.control and value then
                controlRef.control:SetBackdropColor(value.r or 1, value.g or 1, value.b or 1)
            end
        elseif controlRef.type == "fontdropdown" then
            if controlRef.control then
                local fonts = DefaultConfig.GetFonts()
                local text = fonts[value] or "Default"
                UIDropDownMenu_SetText(controlRef.control, text)
            end
        elseif controlRef.type == "texturedropdown" then
            if controlRef.control then
                local textures = DefaultConfig.GetBarTextures()
                local text = textures[value] or "Default"
                UIDropDownMenu_SetText(controlRef.control, text)
            end
        end
    end
end

-- Clear all bound control references
function ConfigControls.ClearBindings()
    ConfigControls.boundControls = {}
end

return ConfigControls
