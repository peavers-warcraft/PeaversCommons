local MAJOR, MINOR = "PeaversCommons-BarManager", 2
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

local PeaversCommons = _G.PeaversCommons

-- Initialize BarManager namespace
PeaversCommons.BarManager = {}
local BarManager = PeaversCommons.BarManager

--[[
    BarManager - Manages collections of stat bars

    Features:
    - Optional BarPool integration for efficient frame reuse
    - Change detection (previous value tracking)
    - Growth direction support (up/down)
    - Category/role headers support
    - Configurable spacing and positioning

    Usage:
        -- Without pooling:
        local manager = PeaversCommons.BarManager:New(addon, config)
        manager:CreateBars(parent, barDefinitions)
        manager:UpdateAllBars(updates)

        -- With pooling:
        local pool = PeaversCommons.BarPool:New({ factory = ... })
        local manager = PeaversCommons.BarManager:New(addon, config, { pool = pool })
]]

-- Default options
local DEFAULT_OPTIONS = {
    barHeight = 20,
    barSpacing = 1,
    growDirection = "DOWN",         -- "DOWN" or "UP"
    anchorPoint = "TOPLEFT",        -- Where bars anchor from
    titleBarHeight = 20,
    trackChanges = true,            -- Track previous values for change detection
    showHeaders = false,            -- Support for category/role headers
}

-- Creates a new BarManager instance
-- @param addon The addon namespace (for accessing config, etc.)
-- @param config Config table with bar settings
-- @param options Optional settings table
-- @return BarManager instance
function BarManager:New(addon, config, options)
    local instance = {}
    setmetatable(instance, { __index = BarManager })

    instance.addon = addon
    instance.config = config
    instance.bars = {}              -- Array of bars (for iteration order)
    instance.barsByKey = {}         -- Hash of bars by type/key (for fast lookup)
    instance.previousValues = {}    -- For change detection
    instance.headers = {}           -- Category headers if used

    -- Merge options with defaults
    instance.options = {}
    for k, v in pairs(DEFAULT_OPTIONS) do
        instance.options[k] = v
    end
    if options then
        for k, v in pairs(options) do
            instance.options[k] = v
        end
    end

    -- Optional pool integration
    instance.pool = options and options.pool or nil

    return instance
end

-- Creates or recreates all stat bars based on bar definitions
-- @param parent Frame parent for bars
-- @param barDefinitions Array of {name, type, show, value, maxValue, color, ...}
-- @return number Total content height
function BarManager:CreateBars(parent, barDefinitions)
    -- Clear existing bars
    self:ClearBars()

    local config = self.config
    local opts = self.options

    local yOffset = 0
    local direction = opts.growDirection == "UP" and 1 or -1
    local barIndex = 0

    for _, barDef in ipairs(barDefinitions) do
        if barDef.show ~= false then  -- Default to showing if not specified
            local bar

            if self.pool then
                -- Use pool to acquire bar
                bar = self.pool:Acquire(parent, barDef.name, barDef.type)
            else
                -- Create new bar using StatBar
                local barOptions = {
                    height = config.barHeight or opts.barHeight,
                    width = config.frameWidth or parent:GetWidth(),
                    texture = config.barTexture,
                    fontFace = config.fontFace,
                    fontSize = config.fontSize,
                    fontOutline = config.fontOutline or "OUTLINE",
                    bgAlpha = config.barBgAlpha or 0.5,
                    showOverflow = barDef.showOverflow or false,
                    showNameText = barDef.showNameText or false,
                    showChangeText = barDef.showChangeText ~= false,
                    textFormat = barDef.textFormat or "value",
                }
                bar = PeaversCommons.StatBar:New(parent, barDef.name, barDef.type, barOptions)
            end

            -- Position the bar
            bar:SetPosition(0, yOffset, opts.anchorPoint)

            -- Initialize with values
            bar:Update(barDef.value or 0, barDef.maxValue or 100)

            -- Apply custom color if provided
            if barDef.color then
                bar:SetColor(barDef.color.r, barDef.color.g, barDef.color.b)
            end

            -- Show the bar
            bar:Show()

            -- Store the bar
            table.insert(self.bars, bar)
            self.barsByKey[barDef.type] = bar

            -- Store initial value for change detection
            if opts.trackChanges then
                self.previousValues[barDef.type] = barDef.value or 0
            end

            barIndex = barIndex + 1

            -- Calculate next position
            local spacing = config.barSpacing or opts.barSpacing
            local height = config.barHeight or opts.barHeight
            if spacing == 0 then
                yOffset = yOffset + (direction * height)
            else
                yOffset = yOffset + (direction * (height + spacing))
            end
        end
    end

    return math.abs(yOffset)
end

-- Clears all bars (releases to pool or hides)
function BarManager:ClearBars()
    if self.pool then
        self.pool:ReleaseAll()
    else
        for _, bar in ipairs(self.bars) do
            bar:Hide()
        end
    end

    self.bars = {}
    self.barsByKey = {}
    self.previousValues = {}
    self.headers = {}
end

-- Updates all stat bars with latest values
-- @param updates Table of {barType = {value, maxValue, change (optional)}}
-- @param noAnimation Skip animations if true (e.g., during combat)
function BarManager:UpdateAllBars(updates, noAnimation)
    for _, bar in ipairs(self.bars) do
        local update = updates[bar.type]
        if update then
            local change = update.change

            -- Calculate change if not provided and tracking is enabled
            if change == nil and self.options.trackChanges then
                local prev = self.previousValues[bar.type]
                if prev then
                    change = update.value - prev
                end
            end

            bar:Update(update.value, update.maxValue, change, noAnimation)

            -- Update previous value
            if self.options.trackChanges then
                self.previousValues[bar.type] = update.value
            end
        end
    end
end

-- Update specific bar by type
-- @param barType The bar type identifier
-- @param value Current value
-- @param maxValue Maximum value
-- @param change Change amount (optional, calculated if tracking enabled)
function BarManager:UpdateBar(barType, value, maxValue, change)
    local bar = self.barsByKey[barType]
    if bar then
        -- Calculate change if not provided
        if change == nil and self.options.trackChanges then
            local prev = self.previousValues[barType]
            if prev then
                change = value - prev
            end
        end

        bar:Update(value, maxValue, change)

        -- Update previous value
        if self.options.trackChanges then
            self.previousValues[barType] = value
        end
    end
end

-- Resizes all bars based on current configuration
-- @param config Optional config override
-- @return number Total content height
function BarManager:ResizeBars(config)
    config = config or self.config

    for _, bar in ipairs(self.bars) do
        bar:UpdateHeight(config.barHeight)
        bar:UpdateWidth(config.frameWidth)
        bar:UpdateTexture(config.barTexture)
        bar:UpdateFont(config.fontFace, config.fontSize, config.fontOutline)
        bar:UpdateBackgroundOpacity(config.barBgAlpha or 0.5)
    end

    -- Reposition bars
    self:RepositionBars(config)

    return self:GetTotalBarsHeight(config)
end

-- Repositions all bars without recreating them
-- @param config Optional config override
function BarManager:RepositionBars(config)
    config = config or self.config
    local opts = self.options

    local direction = opts.growDirection == "UP" and 1 or -1
    local yOffset = 0

    for _, bar in ipairs(self.bars) do
        bar:SetPosition(0, yOffset, opts.anchorPoint)

        local spacing = config.barSpacing or opts.barSpacing
        local height = config.barHeight or opts.barHeight
        if spacing == 0 then
            yOffset = yOffset + (direction * height)
        else
            yOffset = yOffset + (direction * (height + spacing))
        end
    end
end

-- Gets total height of all bars including spacing
-- @param config Optional config override
-- @return number Total height
function BarManager:GetTotalBarsHeight(config)
    config = config or self.config
    local opts = self.options

    local barCount = #self.bars
    if barCount == 0 then return 0 end

    local height = config.barHeight or opts.barHeight
    local spacing = config.barSpacing or opts.barSpacing

    if spacing == 0 then
        return barCount * height
    else
        return barCount * (height + spacing) - spacing
    end
end

-- Adjusts the frame height based on number of bars and title bar visibility
-- @param frame The main frame
-- @param contentFrame The content frame (unused but kept for compatibility)
-- @param titleBarVisible Whether title bar is shown
-- @param config Optional config override
function BarManager:AdjustFrameHeight(frame, contentFrame, titleBarVisible, config)
    config = config or self.config

    local contentHeight = self:GetTotalBarsHeight(config)
    local titleHeight = self.options.titleBarHeight

    if contentHeight == 0 then
        if titleBarVisible then
            frame:SetHeight(titleHeight)
        else
            frame:SetHeight(10)  -- Minimal height
        end
    else
        if titleBarVisible then
            frame:SetHeight(contentHeight + titleHeight)
        else
            frame:SetHeight(contentHeight)
        end
    end
end

-- Gets a bar by its type
-- @param barType The bar type identifier
-- @return bar or nil
function BarManager:GetBar(barType)
    return self.barsByKey[barType]
end

-- Gets the number of visible bars
-- @return number
function BarManager:GetBarCount()
    return #self.bars
end

-- Gets all bars
-- @return array of bars
function BarManager:GetAllBars()
    return self.bars
end

-- Iterates over all bars
-- @param callback function(bar, index) called for each bar
function BarManager:ForEach(callback)
    for i, bar in ipairs(self.bars) do
        callback(bar, i)
    end
end

-- Shows all bars
function BarManager:ShowAll()
    for _, bar in ipairs(self.bars) do
        bar:Show()
    end
end

-- Hides all bars
function BarManager:HideAll()
    for _, bar in ipairs(self.bars) do
        bar:Hide()
    end
end

-- Clean up all bars
function BarManager:Destroy()
    if self.pool then
        self.pool:Clear()
    else
        for _, bar in ipairs(self.bars) do
            bar:Destroy()
        end
    end
    self.bars = {}
    self.barsByKey = {}
    self.previousValues = {}
    self.headers = {}
end

-- ============================================================================
-- Header Support (for role grouping, categories, etc.)
-- ============================================================================

-- Creates a header frame
-- @param parent Parent frame
-- @param key Unique identifier
-- @param text Header text
-- @param yOffset Y position
-- @return header frame, next yOffset
function BarManager:CreateHeader(parent, key, text, yOffset)
    local config = self.config

    local header = CreateFrame("Frame", nil, parent)
    header:SetHeight(20)
    header:SetWidth(config.frameWidth or parent:GetWidth())
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)

    local label = header:CreateFontString(nil, "OVERLAY")
    label:SetFont(config.fontFace or "Fonts\\FRIZQT__.TTF", config.fontSize or 12, "OUTLINE")
    label:SetPoint("LEFT", header, "LEFT", 5, 0)
    label:SetText(text)
    label:SetTextColor(1, 1, 1, 0.8)
    header.label = label

    -- Optional value text on right side
    local valueText = header:CreateFontString(nil, "OVERLAY")
    valueText:SetFont(config.fontFace or "Fonts\\FRIZQT__.TTF", config.fontSize or 12, "OUTLINE")
    valueText:SetPoint("RIGHT", header, "RIGHT", -5, 0)
    valueText:SetTextColor(0.7, 0.7, 0.7)
    header.valueText = valueText

    self.headers[key] = header

    return header, yOffset - 20
end

-- Updates a header's value text
-- @param key Header key
-- @param text New value text
function BarManager:UpdateHeaderValue(key, text)
    local header = self.headers[key]
    if header and header.valueText then
        header.valueText:SetText(text)
    end
end

-- Hides all headers
function BarManager:HideHeaders()
    for _, header in pairs(self.headers) do
        header:Hide()
    end
end

-- Shows all headers
function BarManager:ShowHeaders()
    for _, header in pairs(self.headers) do
        header:Show()
    end
end

return BarManager
