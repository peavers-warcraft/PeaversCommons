--------------------------------------------------------------------------------
-- TitleBar Module
-- Creates a standard title bar with title, separator, and version text
--------------------------------------------------------------------------------

local PeaversCommons = _G.PeaversCommons
PeaversCommons.TitleBar = {}
local TitleBar = PeaversCommons.TitleBar

-- Default font fallback
local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
local DEFAULT_FONT_SIZE = 10

--------------------------------------------------------------------------------
-- Title Bar Creation
--------------------------------------------------------------------------------

-- Creates a title bar with title, vertical separator, and version/subtitle
-- @param parentFrame: The parent frame for the title bar
-- @param config: Config table with bgColor, bgAlpha, fontFace, fontSize, fontOutline, fontShadow
-- @param options: Table with title, version/subtitle text
-- @return titleBar: The created title bar frame
function TitleBar:Create(parentFrame, config, options)
    config = config or {}
    options = options or {}

    local titleBar = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
    titleBar:SetHeight(20)
    titleBar:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", 0, 0)
    titleBar:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\BUTTONS\\WHITE8X8",
        tile = true, tileSize = 16, edgeSize = 1,
    })

    -- Background color
    local bgColor = config.bgColor or { r = 0, g = 0, b = 0 }
    local bgAlpha = config.bgAlpha or 0.8
    titleBar:SetBackdropColor(bgColor.r, bgColor.g, bgColor.b, bgAlpha)
    titleBar:SetBackdropBorderColor(0, 0, 0, bgAlpha)

    -- Font settings
    local fontFace = config.fontFace or DEFAULT_FONT
    local fontSize = config.fontSize or DEFAULT_FONT_SIZE
    local fontOutline = config.fontOutline and "OUTLINE" or ""
    local fontShadow = config.fontShadow

    -- Title text
    local title = titleBar:CreateFontString(nil, "OVERLAY")
    title:SetFont(fontFace, fontSize, fontOutline)
    title:SetPoint("LEFT", titleBar, "LEFT", options.leftPadding or 5, 0)
    title:SetText(options.title or "Title")
    title:SetTextColor(1, 1, 1)
    if fontShadow then
        title:SetShadowOffset(1, -1)
    else
        title:SetShadowOffset(0, 0)
    end
    titleBar.title = title

    -- Vertical line separator
    local verticalLine = titleBar:CreateTexture(nil, "ARTWORK")
    verticalLine:SetSize(1, 16)
    verticalLine:SetPoint("LEFT", title, "RIGHT", 5, 0)
    verticalLine:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    titleBar.verticalLine = verticalLine

    -- Subtitle/version text
    local subtitle = titleBar:CreateFontString(nil, "OVERLAY")
    subtitle:SetFont(fontFace, fontSize, fontOutline)
    subtitle:SetPoint("LEFT", verticalLine, "RIGHT", 5, 0)
    subtitle:SetText(options.subtitle or ("v" .. (options.version or "1.0.0")))
    subtitle:SetTextColor(0.8, 0.8, 0.8)
    if fontShadow then
        subtitle:SetShadowOffset(1, -1)
    else
        subtitle:SetShadowOffset(0, 0)
    end
    titleBar.subtitle = subtitle

    -- Store config reference for updates
    titleBar.config = config
    titleBar.parent = parentFrame

    -- Attach methods
    titleBar.UpdateColors = TitleBar.UpdateColors
    titleBar.UpdateFont = TitleBar.UpdateFont
    titleBar.UpdateTitle = TitleBar.UpdateTitle
    titleBar.UpdateSubtitle = TitleBar.UpdateSubtitle
    titleBar.UpdateWidth = TitleBar.UpdateWidth

    return titleBar
end

--------------------------------------------------------------------------------
-- Update Methods (called on titleBar instances)
--------------------------------------------------------------------------------

-- Updates the background colors
function TitleBar:UpdateColors(bgColor, bgAlpha)
    bgColor = bgColor or self.config.bgColor or { r = 0, g = 0, b = 0 }
    bgAlpha = bgAlpha or self.config.bgAlpha or 0.8
    self:SetBackdropColor(bgColor.r, bgColor.g, bgColor.b, bgAlpha)
    self:SetBackdropBorderColor(0, 0, 0, bgAlpha)
end

-- Updates the font settings
function TitleBar:UpdateFont(fontFace, fontSize, fontOutline, fontShadow)
    fontFace = fontFace or self.config.fontFace or DEFAULT_FONT
    fontSize = fontSize or self.config.fontSize or DEFAULT_FONT_SIZE
    fontOutline = fontOutline or (self.config.fontOutline and "OUTLINE" or "")
    fontShadow = fontShadow or self.config.fontShadow

    self.title:SetFont(fontFace, fontSize, fontOutline)
    self.subtitle:SetFont(fontFace, fontSize, fontOutline)

    if fontShadow then
        self.title:SetShadowOffset(1, -1)
        self.subtitle:SetShadowOffset(1, -1)
    else
        self.title:SetShadowOffset(0, 0)
        self.subtitle:SetShadowOffset(0, 0)
    end
end

-- Updates the title text
function TitleBar:UpdateTitle(newTitle)
    self.title:SetText(newTitle)
end

-- Updates the subtitle/version text
function TitleBar:UpdateSubtitle(newSubtitle)
    self.subtitle:SetText(newSubtitle)
end

-- Updates the width to match parent
function TitleBar:UpdateWidth()
    self:SetWidth(self.parent:GetWidth())
end

return TitleBar
