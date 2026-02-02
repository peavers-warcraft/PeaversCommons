--------------------------------------------------------------------------------
-- BarTextManager Module
-- Manages optional text elements for status bars
-- Supports name (left), value (right), and change indicator (center) with animations
--------------------------------------------------------------------------------

local PeaversCommons = _G.PeaversCommons
PeaversCommons.BarTextManager = {}
local BarTextManager = PeaversCommons.BarTextManager

-- Default font settings
local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
local DEFAULT_FONT_SIZE = 10

--------------------------------------------------------------------------------
-- Font Utilities
--------------------------------------------------------------------------------

-- Safely set font with fallback
function BarTextManager.SafeSetFont(fontString, fontFace, fontSize, fontOutline)
    if not fontString then return false end

    local success = fontString:SetFont(fontFace, fontSize, fontOutline or "")
    if not success then
        success = fontString:SetFont(DEFAULT_FONT, fontSize or DEFAULT_FONT_SIZE, fontOutline or "")
    end

    return success
end

--------------------------------------------------------------------------------
-- Constructor
--------------------------------------------------------------------------------

-- Creates a new text manager for a status bar
-- @param parentBar: The StatusBar frame to attach text to
-- @param options: Table with settings:
--   - showName: Show name text on left (default: true)
--   - showValue: Show value text on right (default: true)
--   - showChange: Show change indicator in center (default: false)
--   - fontFace: Font path
--   - fontSize: Font size (default: 10)
--   - fontOutline: Use outline (default: true)
--   - fontShadow: Use shadow (default: false)
--   - textAlpha: Text alpha (default: 1.0)
--   - name: Initial name text
--   - value: Initial value text
-- @return BarTextManager instance
function BarTextManager:New(parentBar, options)
    options = options or {}

    local obj = {
        parentBar = parentBar,
        showName = options.showName ~= false,
        showValue = options.showValue ~= false,
        showChange = options.showChange or false,
        fontFace = options.fontFace or DEFAULT_FONT,
        fontSize = options.fontSize or DEFAULT_FONT_SIZE,
        fontOutline = options.fontOutline ~= false,
        fontShadow = options.fontShadow or false,
        textAlpha = options.textAlpha or 1.0,
        name = options.name or "",
        valueText = options.value or "",
    }
    setmetatable(obj, { __index = BarTextManager })

    -- Create text layer above the bar
    obj.textLayer = obj:CreateTextLayer(parentBar)

    -- Create text elements based on options
    if obj.showName then
        obj.nameElement = obj:CreateNameText()
    end

    if obj.showValue then
        obj.valueElement = obj:CreateValueText()
    end

    if obj.showChange then
        obj.changeElement = obj:CreateChangeText()
        obj:InitChangeAnimation()
    end

    return obj
end

--------------------------------------------------------------------------------
-- Text Layer Creation
--------------------------------------------------------------------------------

function BarTextManager:CreateTextLayer(parentBar)
    local layer = CreateFrame("Frame", nil, parentBar)
    layer:SetAllPoints()
    layer:SetFrameLevel(parentBar:GetFrameLevel() + 1)
    return layer
end

--------------------------------------------------------------------------------
-- Text Element Creation
--------------------------------------------------------------------------------

function BarTextManager:CreateNameText()
    local text = self.textLayer:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT", self.textLayer, "LEFT", 4, 0)
    text:SetJustifyH("LEFT")

    BarTextManager.SafeSetFont(text, self.fontFace, self.fontSize,
        self.fontOutline and "OUTLINE" or "")
    text:SetTextColor(1, 1, 1, self.textAlpha)
    text:SetText(self.name)

    if self.fontShadow then
        text:SetShadowOffset(1, -1)
    end

    return text
end

function BarTextManager:CreateValueText()
    local text = self.textLayer:CreateFontString(nil, "OVERLAY")
    text:SetPoint("RIGHT", self.textLayer, "RIGHT", -4, 0)
    text:SetJustifyH("RIGHT")

    BarTextManager.SafeSetFont(text, self.fontFace, self.fontSize,
        self.fontOutline and "OUTLINE" or "")
    text:SetTextColor(1, 1, 1, self.textAlpha)
    text:SetText(self.valueText)

    if self.fontShadow then
        text:SetShadowOffset(1, -1)
    end

    return text
end

function BarTextManager:CreateChangeText()
    local text = self.textLayer:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", self.textLayer, "CENTER", 0, 0)
    text:SetJustifyH("CENTER")

    BarTextManager.SafeSetFont(text, self.fontFace, self.fontSize,
        self.fontOutline and "OUTLINE" or "")
    text:SetTextColor(1, 1, 1, self.textAlpha)
    text:SetText("")

    if self.fontShadow then
        text:SetShadowOffset(1, -1)
    end

    return text
end

--------------------------------------------------------------------------------
-- Change Text Animation
--------------------------------------------------------------------------------

function BarTextManager:InitChangeAnimation()
    if not self.changeElement then return end

    self.changeAnimGroup = self.changeElement:CreateAnimationGroup()

    self.changeFadeAnim = self.changeAnimGroup:CreateAnimation("Alpha")
    self.changeFadeAnim:SetFromAlpha(1.0)
    self.changeFadeAnim:SetToAlpha(0.0)
    self.changeFadeAnim:SetDuration(3.0)
    self.changeFadeAnim:SetStartDelay(1.0)
    self.changeFadeAnim:SetSmoothing("OUT")

    self.changeAnimGroup:SetScript("OnFinished", function()
        self.changeElement:SetText("")
        self.changeElement:SetAlpha(1.0)
    end)
end

-- Show change indicator with value and auto-fade
-- @param change: The change amount
-- @param formatFunc: Optional function(change) returns displayText, r, g, b
function BarTextManager:ShowChange(change, formatFunc)
    if not self.changeElement then return end

    -- Stop any running animation
    if self.changeAnimGroup then
        self.changeAnimGroup:Stop()
    end

    self.changeElement:SetAlpha(1.0)

    -- Format the change
    local displayText, r, g, b
    if formatFunc then
        displayText, r, g, b = formatFunc(change)
    else
        -- Default formatting
        local prefix = change > 0 and "+" or ""
        displayText = prefix .. tostring(math.floor(change + 0.5))

        if change > 0 then
            r, g, b = 0, 1, 0  -- Green
        elseif change < 0 then
            r, g, b = 1, 0, 0  -- Red
        else
            r, g, b = 1, 1, 1  -- White
        end
    end

    self.changeElement:SetText(displayText)
    self.changeElement:SetTextColor(r, g, b)

    -- Start fade animation
    if self.changeAnimGroup then
        self.changeAnimGroup:Play()
    end
end

--------------------------------------------------------------------------------
-- Text Updates
--------------------------------------------------------------------------------

-- Set name text
function BarTextManager:SetName(name)
    self.name = name or ""
    if self.nameElement then
        self.nameElement:SetText(self.name)
    end
end

-- Get name text
function BarTextManager:GetName()
    return self.name
end

-- Set value text
function BarTextManager:SetValue(value)
    self.valueText = value or ""
    if self.valueElement then
        self.valueElement:SetText(self.valueText)
    end
end

-- Get value text
function BarTextManager:GetValue()
    return self.valueText
end

-- Set value with unit (convenience method)
-- @param value: Numeric value
-- @param unit: Unit string (e.g., "FPS", "ms", "%")
function BarTextManager:SetValueWithUnit(value, unit)
    local displayText = tostring(value)
    if unit then
        displayText = displayText .. " " .. unit
    end
    self:SetValue(displayText)
end

--------------------------------------------------------------------------------
-- Name Text Truncation
--------------------------------------------------------------------------------

-- Update name text with truncation if it doesn't fit
-- @param maxWidth: Optional max width (defaults to available space)
function BarTextManager:UpdateNameTruncation(maxWidth)
    if not self.nameElement then return end

    local barWidth = self.textLayer:GetWidth()
    if barWidth == 0 then return end

    -- Calculate available width
    local valueWidth = 0
    if self.valueElement then
        valueWidth = self.valueElement:GetStringWidth() + 8
    end

    local availableWidth = maxWidth or (barWidth - valueWidth - 12)

    -- Set full name first to measure
    self.nameElement:SetText(self.name)
    local nameWidth = self.nameElement:GetStringWidth()

    -- Truncate if needed
    if nameWidth > availableWidth and availableWidth > 10 then
        local truncated = self.name
        local ellipsis = "..."

        while self.nameElement:GetStringWidth() > (availableWidth - self.nameElement:GetStringWidth(ellipsis))
              and #truncated > 1 do
            truncated = string.sub(truncated, 1, #truncated - 1)
            self.nameElement:SetText(truncated)
        end

        self.nameElement:SetText(truncated .. ellipsis)
    end
end

--------------------------------------------------------------------------------
-- Font Updates
--------------------------------------------------------------------------------

-- Update font settings for all text elements
function BarTextManager:UpdateFont(fontFace, fontSize, fontOutline, fontShadow)
    self.fontFace = fontFace or self.fontFace
    self.fontSize = fontSize or self.fontSize
    self.fontOutline = fontOutline ~= nil and fontOutline or self.fontOutline
    self.fontShadow = fontShadow ~= nil and fontShadow or self.fontShadow

    local outline = self.fontOutline and "OUTLINE" or ""

    if self.nameElement then
        BarTextManager.SafeSetFont(self.nameElement, self.fontFace, self.fontSize, outline)
        if self.fontShadow then
            self.nameElement:SetShadowOffset(1, -1)
        else
            self.nameElement:SetShadowOffset(0, 0)
        end
    end

    if self.valueElement then
        BarTextManager.SafeSetFont(self.valueElement, self.fontFace, self.fontSize, outline)
        if self.fontShadow then
            self.valueElement:SetShadowOffset(1, -1)
        else
            self.valueElement:SetShadowOffset(0, 0)
        end
    end

    if self.changeElement then
        BarTextManager.SafeSetFont(self.changeElement, self.fontFace, self.fontSize, outline)
        if self.fontShadow then
            self.changeElement:SetShadowOffset(1, -1)
        else
            self.changeElement:SetShadowOffset(0, 0)
        end
    end
end

-- Set text alpha for all elements
function BarTextManager:SetTextAlpha(alpha)
    self.textAlpha = alpha

    if self.nameElement then
        self.nameElement:SetTextColor(1, 1, 1, alpha)
    end

    if self.valueElement then
        self.valueElement:SetTextColor(1, 1, 1, alpha)
    end
end

--------------------------------------------------------------------------------
-- Visibility
--------------------------------------------------------------------------------

-- Show/hide name text
function BarTextManager:SetNameShown(shown)
    if self.nameElement then
        self.nameElement:SetShown(shown)
    end
end

-- Show/hide value text
function BarTextManager:SetValueShown(shown)
    if self.valueElement then
        self.valueElement:SetShown(shown)
    end
end

-- Show/hide change text
function BarTextManager:SetChangeShown(shown)
    if self.changeElement then
        self.changeElement:SetShown(shown)
    end
end

--------------------------------------------------------------------------------
-- Element Access
--------------------------------------------------------------------------------

function BarTextManager:GetNameElement()
    return self.nameElement
end

function BarTextManager:GetValueElement()
    return self.valueElement
end

function BarTextManager:GetChangeElement()
    return self.changeElement
end

function BarTextManager:GetTextLayer()
    return self.textLayer
end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

function BarTextManager:Destroy()
    if self.changeAnimGroup then
        self.changeAnimGroup:Stop()
    end

    if self.textLayer then
        self.textLayer:Hide()
    end
end

return BarTextManager
