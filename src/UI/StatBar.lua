--------------------------------------------------------------------------------
-- StatBar Module
-- Composes AnimatedStatusBar and BarTextManager into a full-featured stat bar
-- Provides hooks for addon-specific behavior (colors, values, tooltips)
--------------------------------------------------------------------------------

local PeaversCommons = _G.PeaversCommons
PeaversCommons.StatBar = {}
local StatBar = PeaversCommons.StatBar

local AnimatedStatusBar = PeaversCommons.AnimatedStatusBar
local BarTextManager = PeaversCommons.BarTextManager

--------------------------------------------------------------------------------
-- Constructor
--------------------------------------------------------------------------------

-- Creates a new stat bar instance
-- @param parent: Parent frame
-- @param name: Display name for the bar
-- @param statType: Identifier for the stat type (used for colors, tooltips)
-- @param config: Config table with bar settings
function StatBar:New(parent, name, statType, config)
    config = config or {}

    local obj = {
        name = name,
        statType = statType,
        config = config,
        value = 0,
        maxValue = 100,
        yOffset = 0,
        anchorPoint = "TOPLEFT",
    }
    setmetatable(obj, { __index = StatBar })

    -- Create container frame
    obj.frame = obj:CreateContainerFrame(parent, config)

    -- Create animated status bar
    obj.statusBar = AnimatedStatusBar:New(obj.frame, {
        texture = config.barTexture,
        bgAlpha = config.barBgAlpha or 0.5,
        barAlpha = config.barAlpha or 1.0,
        height = config.barHeight or 20,
        animationDuration = 0.3,
    })
    obj.statusBar:SetAllPoints(obj.frame)

    -- Create text manager
    obj.textManager = BarTextManager:New(obj.statusBar:GetStatusBar(), {
        showName = true,
        showValue = true,
        showChange = config.showStatChanges or false,
        fontFace = config.fontFace,
        fontSize = config.fontSize,
        fontOutline = config.fontOutline,
        fontShadow = config.fontShadow,
        textAlpha = config.barAlpha or 1.0,
        name = name,
    })

    -- Set initial color
    obj:UpdateColor()

    return obj
end

--------------------------------------------------------------------------------
-- Frame Creation
--------------------------------------------------------------------------------

function StatBar:CreateContainerFrame(parent, config)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(config.barWidth or 200, config.barHeight or 20)
    return frame
end

--------------------------------------------------------------------------------
-- Value Updates
--------------------------------------------------------------------------------

-- Updates the bar with a new value
-- @param value: The new value
-- @param maxValue: Optional max value (for percentage calculation)
-- @param change: Optional change amount to display
-- @param noAnimation: Skip animation if true
function StatBar:Update(value, maxValue, change, noAnimation)
    if self.value == value then return end

    self.value = value or 0
    maxValue = maxValue or self.maxValue

    -- Calculate bar percentage (override CalculateBarValues for custom behavior)
    local percentValue = self:CalculateBarValues(self.value, maxValue)

    -- Update status bar
    self.statusBar:SetMinMaxValues(0, 100)
    self.statusBar:SetValue(percentValue, noAnimation)

    -- Update value text (override GetDisplayValue for custom formatting)
    local displayValue = self:GetDisplayValue(self.value)
    self.textManager:SetValue(displayValue)

    -- Show change indicator if enabled
    if change and change ~= 0 and self.config.showStatChanges then
        self.textManager:ShowChange(change, function(c)
            return self:GetChangeDisplayValue(c)
        end)
    end
end

-- Calculates bar percentage (override in subclass for custom behavior)
-- @return percentValue: Value for the bar (0-100)
function StatBar:CalculateBarValues(value, maxValue)
    if maxValue <= 0 then
        return 0
    end
    return math.min((value / maxValue) * 100, 100)
end

-- Returns the display value for the bar (override for custom formatting)
function StatBar:GetDisplayValue(value)
    return tostring(math.floor(value + 0.5))
end

-- Returns formatted change value and color (override for custom behavior)
function StatBar:GetChangeDisplayValue(change)
    local prefix = change > 0 and "+" or ""
    local r, g, b = 1, 1, 1

    if change > 0 then
        r, g, b = 0, 1, 0  -- Green
    elseif change < 0 then
        r, g, b = 1, 0, 0  -- Red
    end

    return prefix .. tostring(math.floor(change + 0.5)), r, g, b
end

--------------------------------------------------------------------------------
-- Color Management
--------------------------------------------------------------------------------

-- Returns the color for the stat type (override in subclass)
function StatBar:GetColorForStat(statType)
    return 0.8, 0.8, 0.8
end

-- Updates the color of the bar
function StatBar:UpdateColor()
    local r, g, b = self:GetColorForStat(self.statType)
    r = r or 0.8
    g = g or 0.8
    b = b or 0.8

    self.statusBar:SetColor(r, g, b, self.config.barAlpha or 1.0)
end

--------------------------------------------------------------------------------
-- Position and Size
--------------------------------------------------------------------------------

-- Sets the position of the bar relative to its parent
function StatBar:SetPosition(x, y, anchorPoint)
    self.yOffset = y
    self.anchorPoint = anchorPoint or "TOPLEFT"
    self.frame:ClearAllPoints()

    local isBottomAnchor = self.anchorPoint == "BOTTOMLEFT" or
                           self.anchorPoint == "BOTTOM" or
                           self.anchorPoint == "BOTTOMRIGHT"

    if isBottomAnchor then
        self.frame:SetPoint("BOTTOMLEFT", self.frame:GetParent(), "BOTTOMLEFT", x, y)
        self.frame:SetPoint("BOTTOMRIGHT", self.frame:GetParent(), "BOTTOMRIGHT", 0, y)
    else
        self.frame:SetPoint("TOPLEFT", self.frame:GetParent(), "TOPLEFT", x, y)
        self.frame:SetPoint("TOPRIGHT", self.frame:GetParent(), "TOPRIGHT", 0, y)
    end
end

function StatBar:UpdateHeight()
    local height = self.config.barHeight or 20
    self.frame:SetHeight(height)
    self.statusBar:SetHeight(height)
    self:UpdateNameText()
end

function StatBar:UpdateWidth()
    self:SetPosition(0, self.yOffset, self.anchorPoint)
    self:UpdateNameText()
end

function StatBar:UpdateNameText()
    self.textManager:UpdateNameTruncation()
end

--------------------------------------------------------------------------------
-- Appearance Updates
--------------------------------------------------------------------------------

function StatBar:UpdateFont()
    self.textManager:UpdateFont(
        self.config.fontFace,
        self.config.fontSize,
        self.config.fontOutline,
        self.config.fontShadow
    )
    self.textManager:SetTextAlpha(self.config.barAlpha or 1.0)
    self:UpdateNameText()
end

function StatBar:UpdateTexture()
    self.statusBar:SetTexture(self.config.barTexture)
    self:UpdateColor()
end

function StatBar:UpdateBackgroundOpacity()
    self.statusBar:SetBackgroundAlpha(self.config.barBgAlpha or 0.5)
end

--------------------------------------------------------------------------------
-- Tooltip Support (override in subclass)
--------------------------------------------------------------------------------

function StatBar:InitTooltip()
    -- Override in subclass for custom tooltip behavior
    self.tooltipInitialized = true
end

function StatBar:ShowTooltip()
    -- Override in subclass
end

function StatBar:HideTooltip()
    if self.tooltip then
        self.tooltip:Hide()
    end
end

--------------------------------------------------------------------------------
-- Selection State
--------------------------------------------------------------------------------

function StatBar:SetSelected(selected)
    if selected then
        if not self.highlight then
            local bar = self.statusBar:GetStatusBar()
            self.highlight = bar:CreateTexture(nil, "OVERLAY")
            self.highlight:SetAllPoints()
            self.highlight:SetColorTexture(1, 1, 1, 0.1)
        end
        self.highlight:Show()
    elseif self.highlight then
        self.highlight:Hide()
    end
end

--------------------------------------------------------------------------------
-- Visibility
--------------------------------------------------------------------------------

function StatBar:Show()
    self.frame:Show()
end

function StatBar:Hide()
    self.frame:Hide()
end

function StatBar:SetShown(show)
    self.frame:SetShown(show)
end

function StatBar:IsVisible()
    return self.frame:IsVisible()
end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

function StatBar:Destroy()
    if self.tooltip then
        self.tooltip:Hide()
        self.tooltip:ClearLines()
        self.tooltip = nil
    end

    if self.textManager then
        self.textManager:Destroy()
    end

    if self.statusBar then
        self.statusBar:Destroy()
    end

    if self.frame then
        self.frame:Hide()
    end
end

return StatBar
