--------------------------------------------------------------------------------
-- BarManager Module
-- Manages collections of StatBars with layout, positioning, and updates
--------------------------------------------------------------------------------

local PeaversCommons = _G.PeaversCommons
PeaversCommons.BarManager = {}
local BarManager = PeaversCommons.BarManager

--------------------------------------------------------------------------------
-- Bar Collection Management
--------------------------------------------------------------------------------

-- Creates a new BarManager instance
-- Unlike StatBar, BarManagers are per-addon singletons, so we use a factory
function BarManager:New()
    local obj = {
        bars = {},
        previousValues = {},
    }
    setmetatable(obj, { __index = BarManager })
    return obj
end

--------------------------------------------------------------------------------
-- Growth Direction Support
--------------------------------------------------------------------------------

-- Parses growth direction from config
-- @param growthDirection: String like "DOWN", "UP", or config with GetGrowthDirection
-- @return yMult: -1 for down, 1 for up
-- @return xMult: Always 1 (for future horizontal support)
-- @return anchorPoint: "TOPLEFT" or "BOTTOMLEFT"
function BarManager:GetGrowthDirection(config)
    -- If config has a GetGrowthDirection method, use it
    if config and config.GetGrowthDirection then
        return config:GetGrowthDirection()
    end

    -- Default to growing down from top
    local growthDirection = config and config.growthDirection or "DOWN"

    if growthDirection == "UP" then
        return 1, 1, "BOTTOMLEFT"
    else
        return -1, 1, "TOPLEFT"
    end
end

--------------------------------------------------------------------------------
-- Bar Creation
--------------------------------------------------------------------------------

-- Creates bars based on definitions
-- @param parent: Parent frame for bars
-- @param barDefinitions: Array of {name, type, value, maxValue, show, color}
-- @param config: Config table with barHeight, barSpacing, growthDirection
-- @param StatBarClass: StatBar class to use (defaults to PeaversCommons.StatBar)
-- @return totalHeight: Total height of all created bars
function BarManager:CreateBars(parent, barDefinitions, config, StatBarClass)
    StatBarClass = StatBarClass or PeaversCommons.StatBar

    -- Clear existing bars
    self:Clear()

    -- Get growth direction
    local yMult, xMult, anchorPoint = self:GetGrowthDirection(config)

    local barHeight = config.barHeight or 20
    local barSpacing = config.barSpacing or 0

    local yOffset = 0
    for _, barDef in ipairs(barDefinitions) do
        if barDef.show ~= false then
            local bar = StatBarClass:New(parent, barDef.name, barDef.type, config)
            bar:SetPosition(0, yOffset, anchorPoint)

            if barDef.value then
                bar:Update(barDef.value, barDef.maxValue or 100, nil, true)
            end

            if barDef.color then
                bar.frame.bar:SetStatusBarColor(barDef.color.r, barDef.color.g, barDef.color.b)
            end

            bar:UpdateColor()

            table.insert(self.bars, bar)

            -- Calculate offset based on growth direction
            local barStep = barHeight + barSpacing
            yOffset = yOffset + (barStep * yMult)
        end
    end

    return math.abs(yOffset)
end

-- Clears all bars from the collection
function BarManager:Clear()
    for _, bar in ipairs(self.bars) do
        if bar.frame then
            bar.frame:Hide()
        end
        if bar.Destroy then
            bar:Destroy()
        end
    end
    self.bars = {}
    self.previousValues = {}
end

--------------------------------------------------------------------------------
-- Bar Updates
--------------------------------------------------------------------------------

-- Updates all bars with a value getter function
-- @param getValueFunc: function(bar) returns value, change
-- @param noAnimation: Skip animation
function BarManager:UpdateAllBars(getValueFunc, noAnimation)
    for _, bar in ipairs(self.bars) do
        local value, change = getValueFunc(bar)

        if value then
            -- Track changes if not provided
            if change == nil then
                local key = bar.statType or bar.name
                local previous = self.previousValues[key] or 0
                change = value - previous
                self.previousValues[key] = value
            end

            bar:Update(value, nil, change, noAnimation)
            bar:UpdateColor()
        end
    end
end

-- Updates all bars from an updates table
-- @param updates: Table keyed by bar type with {value, maxValue, change}
function BarManager:UpdateFromTable(updates)
    for _, bar in ipairs(self.bars) do
        local update = updates[bar.statType or bar.type]
        if update then
            bar:Update(update.value, update.maxValue, update.change)
        end
    end
end

-- Update specific bar by type
function BarManager:UpdateBar(barType, value, maxValue, change)
    local bar = self:GetBar(barType)
    if bar then
        bar:Update(value, maxValue, change)
    end
end

--------------------------------------------------------------------------------
-- Bar Resizing
--------------------------------------------------------------------------------

-- Resizes all bars based on config
function BarManager:ResizeBars(config)
    for _, bar in ipairs(self.bars) do
        bar:UpdateHeight()
        bar:UpdateWidth()
        bar:UpdateTexture()
        bar:UpdateFont()
        bar:UpdateBackgroundOpacity()
    end

    return self:CalculateTotalHeight(config)
end

-- Calculate total height of all bars
-- @param config: Config with barHeight and barSpacing
-- @return totalHeight
function BarManager:CalculateTotalHeight(config)
    local barCount = #self.bars
    if barCount == 0 then return 0 end

    local barHeight = config.barHeight or 20
    local barSpacing = config.barSpacing or 0

    -- barSpacing can be negative to make bars overlap
    return barCount * barHeight + (barCount - 1) * barSpacing
end

--------------------------------------------------------------------------------
-- Frame Height Adjustment
--------------------------------------------------------------------------------

-- Adjusts the frame height based on number of bars and title bar visibility
-- @param frame: The main frame
-- @param contentFrame: The content frame (optional)
-- @param titleBarVisible: Whether title bar is visible
-- @param config: Config with barHeight and barSpacing (optional if self has config)
-- @param extraHeight: Additional height to add (e.g., for headers)
function BarManager:AdjustFrameHeight(frame, contentFrame, titleBarVisible, config, extraHeight)
    config = config or self.config or {}
    extraHeight = extraHeight or 0

    local contentHeight = self:CalculateTotalHeight(config) + extraHeight

    if contentHeight == 0 then
        if titleBarVisible then
            frame:SetHeight(20) -- Just title bar
        else
            frame:SetHeight(10) -- Minimal height
        end
    else
        if titleBarVisible then
            frame:SetHeight(contentHeight + 20) -- Add title bar height
        else
            frame:SetHeight(contentHeight)
        end
    end
end

--------------------------------------------------------------------------------
-- Bar Lookups
--------------------------------------------------------------------------------

-- Gets a bar by its type
function BarManager:GetBar(barType)
    for _, bar in ipairs(self.bars) do
        if bar.statType == barType or bar.type == barType then
            return bar
        end
    end
    return nil
end

-- Gets the number of bars
function BarManager:GetBarCount()
    return #self.bars
end

-- Iterate over all bars
function BarManager:ForEach(func)
    for i, bar in ipairs(self.bars) do
        func(bar, i)
    end
end

--------------------------------------------------------------------------------
-- Visibility
--------------------------------------------------------------------------------

function BarManager:ShowAll()
    for _, bar in ipairs(self.bars) do
        bar:Show()
    end
end

function BarManager:HideAll()
    for _, bar in ipairs(self.bars) do
        bar:Hide()
    end
end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

function BarManager:Destroy()
    self:Clear()
end

return BarManager
