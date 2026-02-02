-- PeaversCommons DefaultConfig Module
-- Provides standardized default values for all Peavers addons
local PeaversCommons = _G.PeaversCommons
local DefaultConfig = {}
PeaversCommons.DefaultConfig = DefaultConfig

-- Default values organized by category
DefaultConfig.Frame = {
    frameWidth = 250,
    frameHeight = 300,
    framePoint = "RIGHT",
    frameX = -20,
    frameY = 0,
    lockPosition = false,
}

DefaultConfig.Bar = {
    barHeight = 20,
    barSpacing = 2,
    barTexture = "Interface\\TargetingFrame\\UI-StatusBar",
    barAlpha = 1.0,
    barBgAlpha = 0.7,
}

DefaultConfig.Font = {
    fontFace = nil, -- Will be set based on locale
    fontSize = 9,
    fontOutline = "OUTLINE",
    fontShadow = false,
}

DefaultConfig.Background = {
    bgAlpha = 0.8,
    bgColor = { r = 0, g = 0, b = 0 },
}

DefaultConfig.Visibility = {
    showOnLogin = true,
    showTitleBar = true,
}

DefaultConfig.Behavior = {
    hideOutOfCombat = false,
    displayMode = "ALWAYS",
    updateInterval = 0.5,
}

-- Preset configurations for different addon types
DefaultConfig.Presets = {
    -- PeaversSystemBars preset
    SystemBars = {
        frameWidth = 200,
        frameHeight = 100,
        framePoint = "RIGHT",
        frameX = -20,
        frameY = 0,
        lockPosition = false,
        barHeight = 20,
        barSpacing = 2,
        barTexture = "Interface\\TargetingFrame\\UI-StatusBar",
        barAlpha = 1.0,
        barBgAlpha = 0.5, -- PSB uses 0.5
        fontFace = nil,
        fontSize = 9,
        fontOutline = "OUTLINE",
        fontShadow = false,
        bgAlpha = 0.8,
        bgColor = { r = 0, g = 0, b = 0 },
        showOnLogin = true,
        showTitleBar = true,
        updateInterval = 0.5,
        -- PSB-specific
        showFrameBackground = true,
        showStatNames = true,
        showStatValues = true,
        DEBUG_ENABLED = false,
        customColors = {},
    },

    -- PeaversItemLevel preset
    PlayerBars = {
        frameWidth = 250,
        frameHeight = 300,
        framePoint = "RIGHT",
        frameX = -20,
        frameY = 0,
        lockPosition = false,
        barWidth = 230,
        barHeight = 20,
        barSpacing = 2,
        barTexture = "Interface\\TargetingFrame\\UI-StatusBar",
        barAlpha = 1.0,
        barBgAlpha = 0.7,
        fontFace = "Fonts\\FRIZQT__.TTF",
        fontSize = 8,
        fontOutline = "OUTLINE",
        fontShadow = false,
        bgAlpha = 0.8,
        bgColor = { r = 0, g = 0, b = 0 },
        showOnLogin = true,
        showTitleBar = true,
        hideOutOfCombat = false,
        displayMode = "ALWAYS",
        updateInterval = 0.5,
        combatUpdateInterval = 0.2,
        -- PIL-specific
        sortOption = "NAME_ASC",
        groupByRole = false,
        ilvlStepPercentage = 2.0,
        showStats = { ["ITEM_LEVEL"] = true },
        customColors = {},
    },

    -- PeaversDynamicStats preset
    StatBars = {
        frameWidth = 250,
        frameHeight = 300,
        framePoint = "RIGHT",
        frameX = -20,
        frameY = 0,
        lockPosition = false,
        growthAnchor = "TOPLEFT",
        barWidth = 230,
        barHeight = 20,
        barSpacing = 2,
        barTexture = "Interface\\TargetingFrame\\UI-StatusBar",
        barAlpha = 1.0,
        barBgAlpha = 0.7,
        fontFace = nil,
        fontSize = 9,
        fontOutline = "OUTLINE",
        fontShadow = false,
        bgAlpha = 0.8,
        bgColor = { r = 0, g = 0, b = 0 },
        showOnLogin = true,
        showTitleBar = true,
        hideOutOfCombat = false,
        displayMode = "ALWAYS",
        updateInterval = 0.5,
        combatUpdateInterval = 0.2,
        -- PDS-specific
        showOverflowBars = true,
        showStatChanges = true,
        showRatings = true,
        enableTalentAdjustments = true,
        showStats = {},
        customColors = {},
        DEBUG_ENABLED = false,
        lastAppliedTemplate = nil,
    },
}

-- Get the appropriate default font based on client locale
function DefaultConfig.GetDefaultFont()
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

-- Check if a font is compatible with the current locale
function DefaultConfig.IsFontCompatibleWithLocale(fontPath)
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

-- Deep copy a table
local function deepCopy(source)
    if type(source) ~= "table" then
        return source
    end

    local copy = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            copy[key] = deepCopy(value)
        else
            copy[key] = value
        end
    end

    return copy
end

-- Create defaults from specified categories with optional overrides
-- @param categories table - list of category names to include (e.g., {"Frame", "Bar", "Font"})
-- @param overrides table - optional table of values to override defaults
-- @return table - merged default values
function DefaultConfig.Create(categories, overrides)
    local defaults = {}

    -- Merge specified categories
    for _, category in ipairs(categories or {}) do
        local categoryDefaults = DefaultConfig[category]
        if categoryDefaults then
            for key, value in pairs(categoryDefaults) do
                if type(value) == "table" then
                    defaults[key] = deepCopy(value)
                else
                    defaults[key] = value
                end
            end
        end
    end

    -- Handle font default based on locale
    if defaults.fontFace == nil then
        defaults.fontFace = DefaultConfig.GetDefaultFont()
    end

    -- Apply overrides
    if overrides then
        for key, value in pairs(overrides) do
            if type(value) == "table" then
                defaults[key] = deepCopy(value)
            else
                defaults[key] = value
            end
        end
    end

    return defaults
end

-- Create defaults from a preset with optional additional overrides
-- @param presetName string - name of the preset (e.g., "SystemBars", "PlayerBars", "StatBars")
-- @param additionalOverrides table - optional table of values to override preset defaults
-- @return table - preset values with overrides applied
function DefaultConfig.FromPreset(presetName, additionalOverrides)
    local preset = DefaultConfig.Presets[presetName]
    if not preset then
        -- Return empty table with locale font if preset not found
        return { fontFace = DefaultConfig.GetDefaultFont() }
    end

    local defaults = deepCopy(preset)

    -- Handle font default based on locale if not explicitly set
    if defaults.fontFace == nil then
        defaults.fontFace = DefaultConfig.GetDefaultFont()
    end

    -- Apply overrides
    if additionalOverrides then
        for key, value in pairs(additionalOverrides) do
            if type(value) == "table" then
                defaults[key] = deepCopy(value)
            else
                defaults[key] = value
            end
        end
    end

    return defaults
end

-- Apply defaults to a config table, only setting values that don't exist
-- @param config table - the config table to apply defaults to
-- @param defaults table - the default values to apply
function DefaultConfig.ApplyDefaults(config, defaults)
    for key, value in pairs(defaults) do
        if config[key] == nil then
            if type(value) == "table" then
                config[key] = deepCopy(value)
            else
                config[key] = value
            end
        end
    end
end

-- Returns a sorted table of available fonts, including those from LibSharedMedia
function DefaultConfig.GetFonts()
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
function DefaultConfig.GetBarTextures()
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
        for i, textureTable in ipairs(_G.Details.statusbar_info) do
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

return DefaultConfig
