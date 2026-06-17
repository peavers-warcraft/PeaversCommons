local MAJOR = "PeaversCommons-1.0"
local PeaversCommons = LibStub and LibStub(MAJOR) or {}

-- Initialize BarStyles namespace with default configuration values
PeaversCommons.BarStyles = {
    -- Frame settings
    frameWidth = 250,
    frameHeight = 300,
    framePoint = "RIGHT",
    frameX = -20,
    frameY = 0,
    
    -- Enable/Show settings
    enabled = true,
    showTitleBar = true,
    
    -- Window appearance
    windowOpacity = 100,
    borderOpacity = 100,
    borderSize = 1,
    bgColor = { r = 0, g = 0, b = 0 },
    bgAlpha = 0.8,
    
    -- Bar dimensions
    barWidth = 200,
    barHeight = 20,
    barSpacing = 5,
    
    -- Bar appearance
    barTexture = "Interface\\TargetingFrame\\UI-StatusBar",
    barBgAlpha = 0.5,
    barOpacity = 100,
    
    -- Font settings
    fontFace = "Fonts\\FRIZQT__.TTF",
    fontSize = 12,
    fontOutline = "OUTLINE",
    fontShadow = true,
    
    -- Bar customization
    barMaxTextFormatStyle = 1,  -- 1: Short (10k), 2: Full (10,000), 3: None
    barTextFormatStyle = 1,     -- 1: Text on bar, 2: Value only, 3: Percentage
    barShowText = true,
    barAnimate = true,
    barAnimationSpeed = 5,
    
    -- Combat behavior
    onlyInCombat = false,
    hideWhenInactive = false,
    inactiveOpacity = 50,
    
    -- Positioning
    anchorPoint = "CENTER",
    anchorX = 0,
    anchorY = 0,
    
    -- Colors
    totalAPMColor = { r = 0.1, g = 0.8, b = 0.1 },  -- Green
    spellAPMColor = { r = 0.8, g = 0.4, b = 0.1 },  -- Orange  
    moveAPMColor = { r = 0.4, g = 0.4, b = 0.8 },   -- Blue

    textColor = { r = 1, g = 1, b = 1 },
    borderColor = { r = 0.5, g = 0.5, b = 0.5 },
    percentColor = { r = 1, g = 1, b = 0 },
    
    -- Debug
    debugMode = false,
    DEBUG_ENABLED = false,
}

local BarStyles = PeaversCommons.BarStyles

-- Creates a template configuration using BarStyles defaults
function BarStyles:CreateTemplate()
    local template = {}
    
    -- Copy all values from BarStyles
    for key, value in pairs(self) do
        if type(value) ~= "function" then
            if type(value) == "table" then
                -- Deep copy tables like colors
                template[key] = {}
                for subKey, subValue in pairs(value) do
                    template[key][subKey] = subValue
                end
            else
                template[key] = value
            end
        end
    end
    
    return template
end

-- Merges BarStyles defaults with addon-specific overrides
function BarStyles:MergeWithDefaults(overrides)
    local config = self:CreateTemplate()
    
    -- Apply overrides
    if overrides then
        for key, value in pairs(overrides) do
            if type(value) == "table" and type(config[key]) == "table" then
                -- Merge tables (like colors)
                for subKey, subValue in pairs(value) do
                    config[key][subKey] = subValue
                end
            else
                config[key] = value
            end
        end
    end
    
    return config
end

return BarStyles