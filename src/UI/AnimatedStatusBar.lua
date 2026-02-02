--------------------------------------------------------------------------------
-- AnimatedStatusBar Module
-- A simple, composable status bar with smooth value animations
-- No text, no overflow - just an animated bar that can be composed into larger UI
--------------------------------------------------------------------------------

local PeaversCommons = _G.PeaversCommons
PeaversCommons.AnimatedStatusBar = {}
local AnimatedStatusBar = PeaversCommons.AnimatedStatusBar

--------------------------------------------------------------------------------
-- Constructor
--------------------------------------------------------------------------------

-- Creates a new animated status bar
-- @param parent: Parent frame
-- @param options: Table with optional settings:
--   - width: Bar width (default: parent width)
--   - height: Bar height (default: 20)
--   - texture: StatusBar texture path
--   - bgAlpha: Background alpha (default: 0.5)
--   - barAlpha: Bar alpha (default: 1.0)
--   - color: {r, g, b} initial color (default: {0.8, 0.8, 0.8})
--   - minValue: Minimum value (default: 0)
--   - maxValue: Maximum value (default: 100)
--   - animationDuration: Animation duration in seconds (default: 0.3)
--   - showBackground: Whether to show background frame (default: true)
-- @return AnimatedStatusBar instance
function AnimatedStatusBar:New(parent, options)
    options = options or {}

    local obj = {
        parent = parent,
        value = 0,
        minValue = options.minValue or 0,
        maxValue = options.maxValue or 100,
        animationDuration = options.animationDuration or 0.3,
        smoothing = true,
        color = options.color or { r = 0.8, g = 0.8, b = 0.8 },
        barAlpha = options.barAlpha or 1.0,
    }
    setmetatable(obj, { __index = AnimatedStatusBar })

    obj.frame = obj:CreateFrame(parent, options)
    obj:InitAnimation()

    return obj
end

--------------------------------------------------------------------------------
-- Frame Creation
--------------------------------------------------------------------------------

function AnimatedStatusBar:CreateFrame(parent, options)
    local width = options.width or parent:GetWidth()
    local height = options.height or 20
    local bgAlpha = options.bgAlpha or 0.5
    local showBackground = options.showBackground ~= false

    -- Container frame
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(width, height)

    -- Background (optional)
    if showBackground then
        frame:SetBackdrop({
            bgFile = "Interface\\BUTTONS\\WHITE8X8",
            edgeFile = "Interface\\BUTTONS\\WHITE8X8",
            tile = true, edgeSize = 1,
        })
        frame:SetBackdropColor(0, 0, 0, bgAlpha)
        frame:SetBackdropBorderColor(0, 0, 0, bgAlpha)
    end

    -- Status bar
    local bar = CreateFrame("StatusBar", nil, frame)
    if showBackground then
        bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    else
        bar:SetAllPoints(frame)
    end
    bar:SetMinMaxValues(self.minValue, self.maxValue)
    bar:SetValue(0)

    -- Set texture
    if options.texture then
        bar:SetStatusBarTexture(options.texture)
    else
        local texture = bar:CreateTexture(nil, "ARTWORK")
        texture:SetAllPoints()
        texture:SetColorTexture(1, 1, 1, 1)
        bar:SetStatusBarTexture(texture)
    end

    -- Set initial color
    local color = self.color
    bar:SetStatusBarColor(color.r, color.g, color.b, self.barAlpha)

    frame.bar = bar

    return frame
end

--------------------------------------------------------------------------------
-- Animation System
--------------------------------------------------------------------------------

function AnimatedStatusBar:InitAnimation()
    self.animationGroup = self.frame.bar:CreateAnimationGroup()
    self.valueAnimation = self.animationGroup:CreateAnimation("Progress")
    self.valueAnimation:SetDuration(self.animationDuration)
    self.valueAnimation:SetSmoothing("OUT")

    local bar = self.frame.bar
    self.valueAnimation:SetScript("OnUpdate", function(anim)
        local progress = anim:GetProgress()
        local startValue = anim.startValue or 0
        local changeValue = anim.changeValue or 0
        local currentValue = startValue + (changeValue * progress)
        bar:SetValue(currentValue)
    end)
end

--------------------------------------------------------------------------------
-- Value Management
--------------------------------------------------------------------------------

-- Set the bar value with optional animation
-- @param value: New value
-- @param noAnimation: Skip animation if true
function AnimatedStatusBar:SetValue(value, noAnimation)
    value = value or 0

    -- Clamp to min/max
    value = math.max(self.minValue, math.min(self.maxValue, value))

    if self.value == value then return end
    self.value = value

    if self.smoothing and not noAnimation then
        self:AnimateToValue(value)
    else
        self.frame.bar:SetValue(value)
    end
end

-- Get current value
function AnimatedStatusBar:GetValue()
    return self.value
end

-- Set min/max values
function AnimatedStatusBar:SetMinMaxValues(minVal, maxVal)
    self.minValue = minVal
    self.maxValue = maxVal
    self.frame.bar:SetMinMaxValues(minVal, maxVal)
end

-- Animate to a new value
function AnimatedStatusBar:AnimateToValue(newValue)
    self.animationGroup:Stop()

    local currentValue = self.frame.bar:GetValue()

    if math.abs(newValue - currentValue) >= 0.5 then
        self.valueAnimation.startValue = currentValue
        self.valueAnimation.changeValue = newValue - currentValue
        self.animationGroup:Play()
    else
        self.frame.bar:SetValue(newValue)
    end
end

--------------------------------------------------------------------------------
-- Appearance
--------------------------------------------------------------------------------

-- Set bar color
function AnimatedStatusBar:SetColor(r, g, b, alpha)
    self.color = { r = r, g = g, b = b }
    self.barAlpha = alpha or self.barAlpha
    self.frame.bar:SetStatusBarColor(r, g, b, self.barAlpha)
end

-- Get bar color
function AnimatedStatusBar:GetColor()
    return self.color.r, self.color.g, self.color.b
end

-- Set bar texture
function AnimatedStatusBar:SetTexture(texture)
    if texture then
        self.frame.bar:SetStatusBarTexture(texture)
    end
    -- Reapply color after texture change
    self.frame.bar:SetStatusBarColor(self.color.r, self.color.g, self.color.b, self.barAlpha)
end

-- Set background alpha
function AnimatedStatusBar:SetBackgroundAlpha(alpha)
    self.frame:SetBackdropColor(0, 0, 0, alpha)
    self.frame:SetBackdropBorderColor(0, 0, 0, alpha)
end

-- Set bar alpha
function AnimatedStatusBar:SetBarAlpha(alpha)
    self.barAlpha = alpha
    self.frame.bar:SetStatusBarColor(self.color.r, self.color.g, self.color.b, alpha)
end

--------------------------------------------------------------------------------
-- Size and Position
--------------------------------------------------------------------------------

function AnimatedStatusBar:SetSize(width, height)
    self.frame:SetSize(width, height)
end

function AnimatedStatusBar:SetHeight(height)
    self.frame:SetHeight(height)
end

function AnimatedStatusBar:SetWidth(width)
    self.frame:SetWidth(width)
end

function AnimatedStatusBar:SetPoint(...)
    self.frame:ClearAllPoints()
    self.frame:SetPoint(...)
end

function AnimatedStatusBar:SetAllPoints(frame)
    self.frame:SetAllPoints(frame)
end

function AnimatedStatusBar:ClearAllPoints()
    self.frame:ClearAllPoints()
end

--------------------------------------------------------------------------------
-- Animation Control
--------------------------------------------------------------------------------

-- Enable or disable smooth animation
function AnimatedStatusBar:SetSmoothing(enabled)
    self.smoothing = enabled
end

-- Set animation duration
function AnimatedStatusBar:SetAnimationDuration(duration)
    self.animationDuration = duration
    self.valueAnimation:SetDuration(duration)
end

-- Stop any running animation
function AnimatedStatusBar:StopAnimation()
    self.animationGroup:Stop()
end

--------------------------------------------------------------------------------
-- Visibility
--------------------------------------------------------------------------------

function AnimatedStatusBar:Show()
    self.frame:Show()
end

function AnimatedStatusBar:Hide()
    self.frame:Hide()
end

function AnimatedStatusBar:SetShown(shown)
    self.frame:SetShown(shown)
end

function AnimatedStatusBar:IsShown()
    return self.frame:IsShown()
end

--------------------------------------------------------------------------------
-- Frame Access
--------------------------------------------------------------------------------

-- Get the container frame (for attaching text, etc.)
function AnimatedStatusBar:GetFrame()
    return self.frame
end

-- Get the status bar itself
function AnimatedStatusBar:GetStatusBar()
    return self.frame.bar
end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

function AnimatedStatusBar:Destroy()
    self.animationGroup:Stop()
    self.frame:Hide()
    self.frame:SetParent(nil)
end

return AnimatedStatusBar
