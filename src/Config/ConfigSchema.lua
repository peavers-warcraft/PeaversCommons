-- PeaversCommons ConfigSchema Module
-- Provides type definitions and validation for configuration UI generation
local PeaversCommons = _G.PeaversCommons
local ConfigSchema = {}
PeaversCommons.ConfigSchema = ConfigSchema

-- Schema type constants
ConfigSchema.Types = {
    NUMBER = "number",
    INTEGER = "integer",
    BOOLEAN = "boolean",
    STRING = "string",
    COLOR = "color",
    DROPDOWN = "dropdown",
    FONT = "font",
    TEXTURE = "texture",
}

-- Schema builder functions
-- Each returns a schema definition table that ConfigControls can use

-- Number schema (slider for decimal values)
-- @param min number - minimum value
-- @param max number - maximum value
-- @param step number - step increment
-- @param default number - default value
-- @param options table - optional settings { label, category, tooltip, width }
function ConfigSchema.Number(min, max, step, default, options)
    options = options or {}
    return {
        type = ConfigSchema.Types.NUMBER,
        min = min,
        max = max,
        step = step or 0.01,
        default = default,
        label = options.label,
        category = options.category,
        tooltip = options.tooltip,
        width = options.width or 400,
    }
end

-- Integer schema (slider for whole numbers)
-- @param min number - minimum value
-- @param max number - maximum value
-- @param default number - default value
-- @param options table - optional settings { label, category, tooltip, width }
function ConfigSchema.Integer(min, max, default, options)
    options = options or {}
    return {
        type = ConfigSchema.Types.INTEGER,
        min = min,
        max = max,
        step = 1,
        default = default,
        label = options.label,
        category = options.category,
        tooltip = options.tooltip,
        width = options.width or 400,
    }
end

-- Boolean schema (checkbox)
-- @param default boolean - default value
-- @param options table - optional settings { label, category, tooltip }
function ConfigSchema.Boolean(default, options)
    options = options or {}
    return {
        type = ConfigSchema.Types.BOOLEAN,
        default = default,
        label = options.label,
        category = options.category,
        tooltip = options.tooltip,
    }
end

-- String schema (text input)
-- @param default string - default value
-- @param options table - optional settings { label, category, tooltip, width, maxLength }
function ConfigSchema.String(default, options)
    options = options or {}
    return {
        type = ConfigSchema.Types.STRING,
        default = default,
        label = options.label,
        category = options.category,
        tooltip = options.tooltip,
        width = options.width or 200,
        maxLength = options.maxLength,
    }
end

-- Dropdown schema
-- @param optionsTable table - key-value pairs of dropdown options { value = "Display Text" }
-- @param default any - default value (key from optionsTable)
-- @param options table - optional settings { label, category, tooltip, width }
function ConfigSchema.Dropdown(optionsTable, default, options)
    options = options or {}
    return {
        type = ConfigSchema.Types.DROPDOWN,
        options = optionsTable,
        default = default,
        label = options.label,
        category = options.category,
        tooltip = options.tooltip,
        width = options.width or 400,
    }
end

-- Color schema (color picker)
-- @param default table - default color { r, g, b } or { r = 1, g = 1, b = 1 }
-- @param options table - optional settings { label, category, tooltip, hasReset, resetCallback }
function ConfigSchema.Color(default, options)
    options = options or {}
    return {
        type = ConfigSchema.Types.COLOR,
        default = default or { r = 1, g = 1, b = 1 },
        label = options.label,
        category = options.category,
        tooltip = options.tooltip,
        hasReset = options.hasReset,
        resetCallback = options.resetCallback,
    }
end

-- Font schema (dropdown with font options)
-- @param options table - optional settings { label, category, tooltip, width }
function ConfigSchema.Font(options)
    options = options or {}
    return {
        type = ConfigSchema.Types.FONT,
        label = options.label or "Font",
        category = options.category,
        tooltip = options.tooltip,
        width = options.width or 400,
    }
end

-- Texture schema (dropdown with texture options)
-- @param options table - optional settings { label, category, tooltip, width }
function ConfigSchema.Texture(options)
    options = options or {}
    return {
        type = ConfigSchema.Types.TEXTURE,
        label = options.label or "Texture",
        category = options.category,
        tooltip = options.tooltip,
        width = options.width or 400,
    }
end

-- Pre-defined common schemas for standard settings
ConfigSchema.Common = {
    -- Frame settings
    frameWidth = ConfigSchema.Integer(50, 400, 250, { label = "Frame Width", category = "Frame" }),
    frameHeight = ConfigSchema.Integer(50, 600, 300, { label = "Frame Height", category = "Frame" }),
    frameX = ConfigSchema.Integer(-2000, 2000, -20, { label = "Frame X Position", category = "Frame" }),
    frameY = ConfigSchema.Integer(-2000, 2000, 0, { label = "Frame Y Position", category = "Frame" }),
    lockPosition = ConfigSchema.Boolean(false, { label = "Lock Frame Position", category = "Frame" }),

    -- Bar settings
    barHeight = ConfigSchema.Integer(10, 40, 20, { label = "Bar Height", category = "Bar" }),
    barSpacing = ConfigSchema.Integer(-5, 10, 2, { label = "Bar Spacing", category = "Bar" }),
    barAlpha = ConfigSchema.Number(0, 1, 0.05, 1.0, { label = "Bar Opacity", category = "Bar" }),
    barBgAlpha = ConfigSchema.Number(0, 1, 0.05, 0.7, { label = "Bar Background Opacity", category = "Bar" }),
    barTexture = ConfigSchema.Texture({ label = "Bar Texture", category = "Bar" }),

    -- Font settings
    fontFace = ConfigSchema.Font({ label = "Font", category = "Font" }),
    fontSize = ConfigSchema.Integer(6, 18, 9, { label = "Font Size", category = "Font" }),
    fontOutline = ConfigSchema.Boolean(true, { label = "Font Outline", category = "Font" }),
    fontShadow = ConfigSchema.Boolean(false, { label = "Font Shadow", category = "Font" }),

    -- Background settings
    bgAlpha = ConfigSchema.Number(0, 1, 0.05, 0.8, { label = "Background Opacity", category = "Background" }),
    bgColor = ConfigSchema.Color({ r = 0, g = 0, b = 0 }, { label = "Background Color", category = "Background" }),

    -- Visibility settings
    showOnLogin = ConfigSchema.Boolean(true, { label = "Show on Login", category = "Visibility" }),
    showTitleBar = ConfigSchema.Boolean(true, { label = "Show Title Bar", category = "Visibility" }),

    -- Behavior settings
    hideOutOfCombat = ConfigSchema.Boolean(false, { label = "Hide When Out of Combat", category = "Behavior" }),
    displayMode = ConfigSchema.Dropdown(
        {
            ["ALWAYS"] = "Always Show",
            ["PARTY_ONLY"] = "Show in Party Only",
            ["RAID_ONLY"] = "Show in Raid Only",
        },
        "ALWAYS",
        { label = "Display Mode", category = "Behavior" }
    ),
    updateInterval = ConfigSchema.Dropdown(
        {
            [0.5] = "0.5s",
            [1] = "1s",
            [2] = "2s",
            [5] = "5s",
            [10] = "10s",
        },
        0.5,
        { label = "Update Interval", category = "Behavior" }
    ),
}

-- Factory for creating addon-specific schemas by combining common and addon-specific definitions
-- @param commonKeys table - list of keys from ConfigSchema.Common to include
-- @param addonSpecific table - addon-specific schema definitions { key = schema }
-- @return table - complete schema for the addon
function ConfigSchema.CreateAddonSchema(commonKeys, addonSpecific)
    local schema = {}

    -- Add common schemas
    for _, key in ipairs(commonKeys or {}) do
        if ConfigSchema.Common[key] then
            schema[key] = ConfigSchema.Common[key]
        end
    end

    -- Add addon-specific schemas
    if addonSpecific then
        for key, definition in pairs(addonSpecific) do
            schema[key] = definition
        end
    end

    return schema
end

-- Validate a value against a schema definition
-- @param value any - the value to validate
-- @param schema table - the schema definition
-- @return boolean, string - true if valid, false and error message if invalid
function ConfigSchema.Validate(value, schema)
    if not schema then
        return false, "No schema provided"
    end

    local schemaType = schema.type

    if schemaType == ConfigSchema.Types.NUMBER or schemaType == ConfigSchema.Types.INTEGER then
        if type(value) ~= "number" then
            return false, "Expected number, got " .. type(value)
        end
        if schema.min and value < schema.min then
            return false, "Value " .. value .. " is below minimum " .. schema.min
        end
        if schema.max and value > schema.max then
            return false, "Value " .. value .. " is above maximum " .. schema.max
        end
        if schemaType == ConfigSchema.Types.INTEGER and math.floor(value) ~= value then
            return false, "Expected integer, got decimal"
        end
    elseif schemaType == ConfigSchema.Types.BOOLEAN then
        if type(value) ~= "boolean" then
            return false, "Expected boolean, got " .. type(value)
        end
    elseif schemaType == ConfigSchema.Types.STRING then
        if type(value) ~= "string" then
            return false, "Expected string, got " .. type(value)
        end
        if schema.maxLength and #value > schema.maxLength then
            return false, "String length " .. #value .. " exceeds maximum " .. schema.maxLength
        end
    elseif schemaType == ConfigSchema.Types.COLOR then
        if type(value) ~= "table" then
            return false, "Expected color table, got " .. type(value)
        end
        if not (value.r or value[1]) then
            return false, "Color table missing r/1 component"
        end
    elseif schemaType == ConfigSchema.Types.DROPDOWN then
        if schema.options and not schema.options[value] then
            return false, "Value not in dropdown options"
        end
    end

    return true
end

-- Get the default value from a schema
-- @param schema table - the schema definition
-- @return any - the default value
function ConfigSchema.GetDefault(schema)
    if not schema then
        return nil
    end
    return schema.default
end

return ConfigSchema
