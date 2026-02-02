local MAJOR, MINOR = "PeaversCommons-StatBar", 2
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

local PeaversCommons = _G.PeaversCommons

-- Initialize StatBar namespace
PeaversCommons.StatBar = {}
local StatBar = PeaversCommons.StatBar

local Utils = PeaversCommons.Utils

--[[
    StatBar - Unified stat bar component

    Features:
    - Pool-compatible with Reset() method
    - WoW AnimationGroup API for smooth animations (better than C_Timer)
    - Optional overflow bar support (for stats > 100%)
    - Configurable anchor points for growth direction
    - Name truncation with performance optimization
    - Change text with fade animation
    - Drag support via content frame

    Usage:
        local bar = PeaversCommons.StatBar:New(parent, "MyBar", "health", options)
        bar:Update(75, 100, 5)  -- value, maxValue, change
        bar:SetColor(0, 1, 0)
]]

-- Default options
local DEFAULT_OPTIONS = {
    height = 20,
    width = 200,
    texture = "Interface\\TargetingFrame\\UI-StatusBar",
    fontFace = "Fonts\\FRIZQT__.TTF",
    fontSize = 12,
    fontOutline = "OUTLINE",
    bgAlpha = 0.5,
    smoothing = true,
    animationDuration = 0.3,
    showOverflow = false,           -- Enable overflow bar for values > maxValue
    overflowColor = nil,            -- Auto-calculated contrasting color if nil
    showChangeText = true,
    changeTextDelay = 1.0,          -- Seconds before fade starts
    changeTextFadeDuration = 3.0,   -- Seconds to fade out
    textFormat = "value",           -- "value", "percent", "both", "none"
    anchorPoint = "TOP",            -- Anchor point for positioning
    growDirection = "DOWN",         -- "DOWN" or "UP"
    showNameText = false,           -- Show name text on left side
    showValueText = true,           -- Show value text on right side
    nameMaxWidth = nil,             -- Max width for name truncation (nil = no truncation)
}

-- Creates a new stat bar instance
-- @param parent Frame parent
-- @param name String name for the bar
-- @param barType String identifier for this bar type
-- @param options Table of options (optional)
function StatBar:New(parent, name, barType, options)
    local obj = {}
    setmetatable(obj, { __index = StatBar })

    -- Merge options with defaults
    obj.options = {}
    for k, v in pairs(DEFAULT_OPTIONS) do
        obj.options[k] = v
    end
    if options then
        for k, v in pairs(options) do
            obj.options[k] = v
        end
    end

    obj.name = name
    obj.type = barType
    obj.value = 0
    obj.maxValue = 100
    obj.targetValue = 0
    obj.smoothing = obj.options.smoothing
    obj.yOffset = 0
    obj._poolKey = nil  -- For pool tracking

    -- Color state
    obj.barColor = { r = 0.8, g = 0.8, b = 0.8 }

    -- Create visual elements
    obj.frame = obj:CreateFrame(parent)

    -- Set default color
    obj:SetColor(0.8, 0.8, 0.8)

    -- Initialize animation systems
    obj:InitAnimationSystem()
    obj:InitChangeTextFadeAnimation()

    return obj
end

-- Creates the visual elements of the stat bar
function StatBar:CreateFrame(parent)
    local opts = self.options

    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(opts.width, opts.height)

    -- Background
    local bg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    bg:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = nil,
        tile = false,
        tileSize = 32,
        edgeSize = 0,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    bg:SetBackdropColor(0, 0, 0, opts.bgAlpha)
    self.bg = bg

    -- Main status bar
    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetAllPoints(frame)
    bar:SetStatusBarTexture(opts.texture)
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(0)
    self.bar = bar

    -- Overflow bar (for values > 100%)
    if opts.showOverflow then
        local overflowBar = CreateFrame("StatusBar", nil, frame)
        overflowBar:SetAllPoints(frame)
        overflowBar:SetStatusBarTexture(opts.texture)
        overflowBar:SetMinMaxValues(0, 100)
        overflowBar:SetValue(0)
        overflowBar:SetAlpha(0.7)
        overflowBar:SetFrameLevel(bar:GetFrameLevel() + 1)
        overflowBar:Hide()
        self.overflowBar = overflowBar
    end

    -- Name text (left side, for player names etc.)
    if opts.showNameText then
        local nameText = bar:CreateFontString(nil, "OVERLAY")
        Utils.SafeSetFont(nameText, opts.fontFace, opts.fontSize, opts.fontOutline)
        nameText:SetPoint("LEFT", bar, "LEFT", 5, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetTextColor(1, 1, 1, 1)
        self.nameText = nameText
    end

    -- Value text (center or right)
    local text = bar:CreateFontString(nil, "OVERLAY")
    Utils.SafeSetFont(text, opts.fontFace, opts.fontSize, opts.fontOutline)
    if opts.showNameText then
        text:SetPoint("RIGHT", bar, "RIGHT", -5, 0)
        text:SetJustifyH("RIGHT")
    else
        text:SetPoint("CENTER", bar, "CENTER", 0, 0)
        text:SetJustifyH("CENTER")
    end
    text:SetTextColor(1, 1, 1, 1)
    self.text = text

    -- Change text (shows +/- changes with fade)
    local changeText = bar:CreateFontString(nil, "OVERLAY")
    Utils.SafeSetFont(changeText, opts.fontFace, opts.fontSize - 2, opts.fontOutline)
    changeText:SetPoint("CENTER", bar, "CENTER", 0, 0)
    changeText:SetJustifyH("CENTER")
    changeText:SetText("")
    changeText:SetAlpha(0)
    self.changeText = changeText

    return frame
end

-- Initialize animation for smooth bar updates using AnimationGroup
function StatBar:InitAnimationSystem()
    -- Create animation group for main bar
    local animGroup = self.bar:CreateAnimationGroup()
    self.barAnimGroup = animGroup

    -- We'll animate manually but use AnimationGroup's OnUpdate for frame-rate independence
    self.animTimer = nil
    self.animStartValue = 0
    self.animEndValue = 0
    self.animDuration = self.options.animationDuration
    self.animElapsed = 0

    -- Overflow bar animation if exists
    if self.overflowBar then
        self.overflowAnimGroup = self.overflowBar:CreateAnimationGroup()
        self.overflowAnimStartValue = 0
        self.overflowAnimEndValue = 0
    end
end

-- Initialize change text fade animation using AnimationGroup
function StatBar:InitChangeTextFadeAnimation()
    if not self.options.showChangeText then return end

    -- Create fade animation group
    local fadeGroup = self.changeText:CreateAnimationGroup()
    self.changeTextFadeGroup = fadeGroup

    -- Alpha animation for fade out
    local fadeAnim = fadeGroup:CreateAnimation("Alpha")
    fadeAnim:SetFromAlpha(1)
    fadeAnim:SetToAlpha(0)
    fadeAnim:SetDuration(self.options.changeTextFadeDuration)
    fadeAnim:SetSmoothing("OUT")
    fadeAnim:SetStartDelay(self.options.changeTextDelay)
    self.changeTextFadeAnim = fadeAnim

    fadeGroup:SetScript("OnFinished", function()
        self.changeText:SetAlpha(0)
    end)

    self.changeTextAlpha = 0
    self.changeTextTimer = nil  -- Legacy timer support
end

-- Updates the stat bar value with optional animation
-- @param value Current value
-- @param maxValue Maximum value (optional, uses previous if nil)
-- @param change Change amount for change text (optional)
-- @param noAnimation Skip animation if true
function StatBar:Update(value, maxValue, change, noAnimation)
    value = value or 0
    maxValue = maxValue or self.maxValue

    if maxValue ~= self.maxValue then
        self.maxValue = maxValue
        self.bar:SetMinMaxValues(0, maxValue)
        if self.overflowBar then
            self.overflowBar:SetMinMaxValues(0, maxValue)
        end
    end

    self.targetValue = value

    -- Update text immediately
    self:UpdateText(value, maxValue)

    -- Show change text if there's a significant change
    if self.options.showChangeText and change and math.abs(change) > 0.01 then
        self:ShowChangeText(change)
    end

    -- Handle overflow
    if self.options.showOverflow then
        self:HandleOverflow(value, maxValue)
    end

    -- Update bar value (with animation if enabled)
    if self.smoothing and self.frame:IsVisible() and not noAnimation then
        self:AnimateToValue(value)
    else
        self.value = value
        local barValue = self.options.showOverflow and math.min(value, maxValue) or value
        self.bar:SetValue(barValue)
    end
end

-- Handles overflow bar display for values exceeding maxValue
function StatBar:HandleOverflow(value, maxValue)
    if not self.overflowBar then return end

    if value > maxValue then
        local overflowAmount = value - maxValue
        self.overflowBar:SetValue(overflowAmount)
        self.overflowBar:Show()

        -- Update overflow color if not set
        if not self.overflowColor then
            self:UpdateOverflowColor()
        end
    else
        self.overflowBar:SetValue(0)
        self.overflowBar:Hide()
    end
end

-- Updates the overflow bar color to contrast with main bar
function StatBar:UpdateOverflowColor()
    if not self.overflowBar then return end

    local r, g, b = self.barColor.r, self.barColor.g, self.barColor.b

    if self.options.overflowColor then
        self.overflowBar:SetStatusBarColor(
            self.options.overflowColor.r,
            self.options.overflowColor.g,
            self.options.overflowColor.b
        )
    else
        -- Calculate contrasting color
        local cr, cg, cb = Utils.GetContrastingColor(r, g, b)
        self.overflowBar:SetStatusBarColor(cr, cg, cb)
        self.overflowColor = { r = cr, g = cg, b = cb }
    end
end

-- Animates the bar to a new value over time using AnimationGroup
function StatBar:AnimateToValue(targetValue)
    -- If we're already animating to this value, don't restart
    if self.animTimer and self.animEndValue == targetValue then
        return
    end

    -- Cancel any existing animation
    if self.animTimer then
        self.animTimer:Cancel()
        self.animTimer = nil
    end

    local startValue = self.value
    local duration = self.animDuration

    -- Handle overflow: animate main bar to min(target, max)
    local mainTarget = self.options.showOverflow and math.min(targetValue, self.maxValue) or targetValue
    local mainStart = self.options.showOverflow and math.min(startValue, self.maxValue) or startValue

    self.animStartValue = mainStart
    self.animEndValue = mainTarget
    self.animElapsed = 0

    -- Use C_Timer for frame-rate independent animation
    local elapsed = 0
    self.animTimer = C_Timer.NewTicker(0.016, function()  -- ~60 FPS
        elapsed = elapsed + 0.016

        if elapsed >= duration then
            -- Animation complete
            self.value = targetValue
            self.bar:SetValue(mainTarget)
            if self.animTimer then
                self.animTimer:Cancel()
                self.animTimer = nil
            end
        else
            -- Calculate eased position (ease-out cubic)
            local progress = elapsed / duration
            local easedProgress = 1 - math.pow(1 - progress, 3)

            local currentValue = mainStart + (mainTarget - mainStart) * easedProgress
            self.value = self.animStartValue + (targetValue - self.animStartValue) * easedProgress
            self.bar:SetValue(currentValue)

            -- Animate overflow if applicable
            if self.options.showOverflow and self.overflowBar and targetValue > self.maxValue then
                local overflowStart = math.max(0, startValue - self.maxValue)
                local overflowTarget = targetValue - self.maxValue
                local overflowCurrent = overflowStart + (overflowTarget - overflowStart) * easedProgress
                self.overflowBar:SetValue(overflowCurrent)
            end
        end
    end)
end

-- Updates the text displayed on the bar
function StatBar:UpdateText(value, maxValue)
    local format = self.options.textFormat

    if format == "none" or self.hideText then
        self.text:SetText("")
        return
    end

    local text = ""
    if format == "percent" then
        local percentage = maxValue > 0 and (value / maxValue * 100) or 0
        text = string.format("%.1f%%", percentage)
    elseif format == "both" then
        local percentage = maxValue > 0 and (value / maxValue * 100) or 0
        text = string.format("%d / %d (%.1f%%)", math.floor(value), math.floor(maxValue), percentage)
    else  -- "value" or default
        text = string.format("%.1f", value)
    end

    self.text:SetText(text)
end

-- Updates the name text (left side)
-- @param name The name to display
-- @param truncate Whether to truncate to fit (uses nameMaxWidth option)
function StatBar:UpdateNameText(name)
    if not self.nameText then return end

    if not name then
        self.nameText:SetText("")
        return
    end

    local maxWidth = self.options.nameMaxWidth
    if maxWidth and Utils.TruncateText then
        local truncated = Utils.TruncateText(self.nameText, name, maxWidth)
        self.nameText:SetText(truncated)
    else
        self.nameText:SetText(name)
    end
end

-- Shows temporary change text that fades out
function StatBar:ShowChangeText(change)
    if not self.options.showChangeText then return end

    local prefix = change > 0 and "+" or ""
    local displayValue

    if math.abs(change) < 1 then
        displayValue = string.format("%.2f", change)
    else
        displayValue = tostring(math.floor(change))
    end

    self.changeText:SetText(prefix .. displayValue)

    if change > 0 then
        self.changeText:SetTextColor(0, 1, 0, 1)  -- Green for positive
    else
        self.changeText:SetTextColor(1, 0, 0, 1)  -- Red for negative
    end

    -- Use AnimationGroup if available
    if self.changeTextFadeGroup then
        self.changeTextFadeGroup:Stop()
        self.changeText:SetAlpha(1)
        self.changeTextFadeGroup:Play()
    else
        -- Fallback to C_Timer
        if self.changeTextTimer then
            self.changeTextTimer:Cancel()
        end

        self.changeTextAlpha = 1
        self.changeText:SetAlpha(1)

        local fadeDelay = self.options.changeTextDelay
        local fadeDuration = self.options.changeTextFadeDuration

        self.changeTextTimer = C_Timer.NewTicker(0.02, function()
            fadeDelay = fadeDelay - 0.02

            if fadeDelay <= 0 then
                self.changeTextAlpha = self.changeTextAlpha - (0.02 / fadeDuration)

                if self.changeTextAlpha <= 0 then
                    self.changeTextAlpha = 0
                    self.changeText:SetAlpha(0)
                    self.changeTextTimer:Cancel()
                    self.changeTextTimer = nil
                else
                    self.changeText:SetAlpha(self.changeTextAlpha)
                end
            end
        end)
    end
end

-- Sets the color of the bar
function StatBar:SetColor(r, g, b)
    self.barColor = { r = r, g = g, b = b }
    self.bar:SetStatusBarColor(r, g, b)

    -- Reset overflow color so it recalculates
    if self.overflowBar and not self.options.overflowColor then
        self.overflowColor = nil
        self:UpdateOverflowColor()
    end
end

-- Updates the height of the bar
function StatBar:UpdateHeight(height)
    self.frame:SetHeight(height)
    self.options.height = height
end

-- Updates the width of the bar
function StatBar:UpdateWidth(width)
    width = width or self.frame:GetParent():GetWidth()
    self.frame:SetWidth(width)
    self.options.width = width
end

-- Updates the bar texture
function StatBar:UpdateTexture(texture)
    if texture then
        self.bar:SetStatusBarTexture(texture)
        if self.overflowBar then
            self.overflowBar:SetStatusBarTexture(texture)
        end
        self.options.texture = texture
    end
end

-- Updates the font settings
function StatBar:UpdateFont(fontFace, fontSize, fontOutline)
    fontFace = fontFace or self.options.fontFace
    fontSize = fontSize or self.options.fontSize
    fontOutline = fontOutline or self.options.fontOutline

    Utils.SafeSetFont(self.text, fontFace, fontSize, fontOutline)
    Utils.SafeSetFont(self.changeText, fontFace, fontSize - 2, fontOutline)

    if self.nameText then
        Utils.SafeSetFont(self.nameText, fontFace, fontSize, fontOutline)
    end

    self.options.fontFace = fontFace
    self.options.fontSize = fontSize
    self.options.fontOutline = fontOutline
end

-- Updates background opacity
function StatBar:UpdateBackgroundOpacity(alpha)
    local r, g, b = self.bg:GetBackdropColor()
    self.bg:SetBackdropColor(r, g, b, alpha)
    self.options.bgAlpha = alpha
end

-- Sets the position of the bar
-- @param x X offset
-- @param y Y offset
-- @param anchorPoint Optional anchor point override
function StatBar:SetPosition(x, y, anchorPoint)
    anchorPoint = anchorPoint or self.options.anchorPoint
    self.frame:ClearAllPoints()
    self.frame:SetPoint(anchorPoint, self.frame:GetParent(), anchorPoint, x, y)
    self.yOffset = y
end

-- Shows/hides the bar
function StatBar:SetShown(show)
    if show then
        self.frame:Show()
    else
        self.frame:Hide()
    end
end

-- Resets the bar for pool reuse
-- Called by BarPool when releasing a bar
function StatBar:Reset()
    -- Stop animations
    if self.animTimer then
        self.animTimer:Cancel()
        self.animTimer = nil
    end
    if self.changeTextTimer then
        self.changeTextTimer:Cancel()
        self.changeTextTimer = nil
    end
    if self.changeTextFadeGroup then
        self.changeTextFadeGroup:Stop()
    end

    -- Reset values
    self.value = 0
    self.targetValue = 0
    self.bar:SetValue(0)

    if self.overflowBar then
        self.overflowBar:SetValue(0)
        self.overflowBar:Hide()
    end

    -- Reset text
    self.text:SetText("")
    self.changeText:SetText("")
    self.changeText:SetAlpha(0)

    if self.nameText then
        self.nameText:SetText("")
    end

    -- Reset color
    self:SetColor(0.8, 0.8, 0.8)

    -- Hide frame
    self.frame:Hide()
end

-- Hides the bar (alias for pool compatibility)
function StatBar:Hide()
    self.frame:Hide()
end

-- Shows the bar
function StatBar:Show()
    self.frame:Show()
end

-- Clean up the bar
function StatBar:Destroy()
    self:Reset()
    self.frame:SetParent(nil)
end

-- Sets up tooltip drag behavior
-- @param mainFrame The main frame to drag (parent frame)
-- @param saveCallback Optional function(point, x, y) called on drag stop
function StatBar:InitDragBehavior(mainFrame, saveCallback)
    self.frame:EnableMouse(true)
    self.frame:RegisterForDrag("LeftButton")

    self.frame:SetScript("OnDragStart", function()
        if mainFrame and mainFrame:IsMovable() then
            mainFrame:StartMoving()
        end
    end)

    self.frame:SetScript("OnDragStop", function()
        if mainFrame then
            mainFrame:StopMovingOrSizing()
            if saveCallback then
                local point, _, _, x, y = mainFrame:GetPoint()
                saveCallback(point, x, y)
            end
        end
    end)
end

-- Gets the frame (for external access)
function StatBar:GetFrame()
    return self.frame
end

-- Gets the current value
function StatBar:GetValue()
    return self.value
end

-- Gets the bar type
function StatBar:GetType()
    return self.type
end

return StatBar
