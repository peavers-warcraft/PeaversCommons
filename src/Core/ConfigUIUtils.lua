-- PeaversCommons ConfigUIUtils Module
-- This provides utilities for creating configuration UI elements
local PeaversCommons = _G.PeaversCommons
local ConfigUIUtils = {}
PeaversCommons.ConfigUIUtils = ConfigUIUtils

-- Dependencies
local FrameUtils = PeaversCommons.FrameUtils
local Utils = PeaversCommons.Utils

-- Creates a slider with standardized formatting
function ConfigUIUtils.CreateSlider(parent, name, label, min, max, step, defaultVal, width, callback)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width or 400, 50)

    local labelText = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", 0, 0)
    labelText:SetText(label .. ": " .. defaultVal)

    local slider = CreateFrame("Slider", name, container, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 0, -20)
    slider:SetWidth(width or 400)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetValue(defaultVal)

    -- Hide default slider text
    local sliderName = slider:GetName()
    if sliderName then
        local lowText = FrameUtils.GetGlobal(sliderName .. "Low")
        local highText = FrameUtils.GetGlobal(sliderName .. "High")
        local valueText = FrameUtils.GetGlobal(sliderName .. "Text")

        if lowText then lowText:SetText("") end
        if highText then highText:SetText("") end
        if valueText then valueText:SetText("") end
    end

    slider:SetScript("OnValueChanged", function(self, value)
        local roundedValue
        if step < 1 then
            -- For decimal values (like opacity 0-1)
            roundedValue = Utils.Round(value * (1 / step)) / (1 / step)
        else
            roundedValue = Utils.Round(value)
        end

        -- Format percentages
        if min == 0 and max == 1 then
            labelText:SetText(label .. ": " .. math.floor(roundedValue * 100) .. "%")
        else
            labelText:SetText(label .. ": " .. roundedValue)
        end

        -- Call the provided callback with the rounded value
        if callback then
            callback(roundedValue)
        end
    end)

    -- Return container, slider, labelText, and newY position (50px is container height)
    return container, slider, labelText, -50
end

-- Creates a dropdown with standardized formatting
function ConfigUIUtils.CreateDropdown(parent, name, label, options, defaultOption, width, callback)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width or 400, 60)

    local labelText = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", 0, 0)
    labelText:SetText(label)

    local dropdown = CreateFrame("Frame", name, container, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 0, -20)
    UIDropDownMenu_SetWidth(dropdown, (width or 400) - 55)
    UIDropDownMenu_SetText(dropdown, defaultOption)

    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for value, text in pairs(options) do
            info.text = text
            info.checked = (value == defaultOption or text == defaultOption)
            info.func = function()
                UIDropDownMenu_SetText(dropdown, text)
                if callback then
                    callback(value)
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    return container, dropdown, labelText
end

-- Creates a checkbox with standardized formatting
function ConfigUIUtils.CreateCheckbox(parent, name, label, x, y, checked, callback)
    return FrameUtils.CreateCheckbox(
        parent,
        name,
        label,
        x,
        y,
        checked,
        { 1, 1, 1 },
        function(self)
            if callback then
                callback(self:GetChecked())
            end
        end
    )
end

-- Creates a section header with standardized formatting
function ConfigUIUtils.CreateSectionHeader(parent, text, indent, yPos, fontSize)
    local header, newY = FrameUtils.CreateSectionHeader(parent, text, indent, yPos)
    header:SetFont(header:GetFont(), fontSize or 18)
    return header, newY
end

-- Creates a subsection label with standardized formatting
function ConfigUIUtils.CreateSubsectionLabel(parent, text, indent, y)
    local label, newY = FrameUtils.CreateLabel(parent, text, indent, y, "GameFontNormalSmall")
    label:SetTextColor(0.9, 0.9, 0.9)
    return label, newY
end

-- Creates a color picker with label and reset button
function ConfigUIUtils.CreateColorPicker(parent, name, label, x, y, initialColor, onColorChanged, onReset)
    local colorContainer = CreateFrame("Frame", nil, parent)
    colorContainer:SetSize(400, 30)
    colorContainer:SetPoint("TOPLEFT", x, y)

    local colorLabel = colorContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    colorLabel:SetPoint("LEFT", 0, 0)
    colorLabel:SetText(label)

    local colorPicker = CreateFrame("Button", name, colorContainer, "BackdropTemplate")
    colorPicker:SetPoint("LEFT", colorLabel, "RIGHT", 10, 0)
    colorPicker:SetSize(20, 20)
    colorPicker:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    
    local r, g, b = 1, 1, 1
    if initialColor then
        r = initialColor.r or initialColor[1] or 1
        g = initialColor.g or initialColor[2] or 1
        b = initialColor.b or initialColor[3] or 1
    end
    colorPicker:SetBackdropColor(r, g, b)

    local colorText = colorContainer:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    colorText:SetPoint("LEFT", colorPicker, "RIGHT", 10, 0)
    colorText:SetText("Change color")

    -- Create reset button if a reset handler is provided
    local resetButton
    if onReset then
        resetButton = CreateFrame("Button", name .. "ResetButton", colorContainer, "UIPanelButtonTemplate")
        resetButton:SetSize(80, 20)
        resetButton:SetPoint("LEFT", colorText, "RIGHT", 15, 0)
        resetButton:SetText("Reset")
        resetButton:SetScript("OnClick", function()
            if onReset then
                onReset()
            end
        end)
    end

    colorPicker:SetScript("OnClick", function()
        local function ColorCallback(restore)
            local newR, newG, newB
            if restore then
                newR, newG, newB = unpack(restore)
            else
                -- Get color using the latest API
                newR, newG, newB = ColorPickerFrame.Content.ColorPicker:GetColorRGB()
            end

            colorPicker:SetBackdropColor(newR, newG, newB)

            if onColorChanged then
                onColorChanged(newR, newG, newB)
            end
        end

        local r, g, b = colorPicker:GetBackdropColor()

        -- Set both func and swatchFunc for compatibility with different API versions
        ColorPickerFrame.func = ColorCallback
        ColorPickerFrame.swatchFunc = ColorCallback
        ColorPickerFrame.cancelFunc = ColorCallback
        ColorPickerFrame.opacityFunc = nil
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = { r, g, b }

        -- Set color using the latest API
        ColorPickerFrame.Content.ColorPicker:SetColorRGB(r, g, b)

        ColorPickerFrame:Hide() -- Hide first to trigger OnShow handler
        ColorPickerFrame:Show()
    end)

    return colorContainer, colorPicker, resetButton, y - 35
end

-- Creates a horizontal separator line with consistent styling
function ConfigUIUtils.CreateSeparator(parent, x, y, width)
    return FrameUtils.CreateSeparator(parent, x, y, width or 400)
end

-- Create a NEW badge with animation for highlighting new features
function ConfigUIUtils.CreateNewBadge(parent, anchorFrame, xOffset, yOffset)
    local newBadge = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    newBadge:SetPoint("LEFT", anchorFrame, "RIGHT", xOffset or 10, yOffset or 0)
    newBadge:SetText("NEW!")
    newBadge:SetTextColor(0, 1, 0)
    
    -- Create a colored glow around the NEW badge
    local newBadgeGlow = parent:CreateTexture(nil, "BACKGROUND")
    newBadgeGlow:SetPoint("CENTER", newBadge, "CENTER", 0, 0)
    newBadgeGlow:SetSize(50, 25)
    newBadgeGlow:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
    newBadgeGlow:SetBlendMode("ADD")
    newBadgeGlow:SetAlpha(0.7)
    
    -- Animate the glow
    local animGroup = newBadgeGlow:CreateAnimationGroup()
    animGroup:SetLooping("REPEAT")
    
    local fadeOut = animGroup:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(0.7)
    fadeOut:SetToAlpha(0.3)
    fadeOut:SetDuration(1)
    fadeOut:SetOrder(1)
    
    local fadeIn = animGroup:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0.3)
    fadeIn:SetToAlpha(0.7)
    fadeIn:SetDuration(1)
    fadeIn:SetOrder(2)
    
    animGroup:Play()
    
    return newBadge, newBadgeGlow
end

-- Creates a help icon with tooltip
function ConfigUIUtils.CreateHelpIcon(parent, anchorFrame, tooltipTitle, tooltipText, xOffset, yOffset)
    local helpIcon = parent:CreateTexture(nil, "OVERLAY")
    helpIcon:SetSize(16, 16)
    helpIcon:SetPoint("LEFT", anchorFrame, "RIGHT", xOffset or 5, yOffset or 0)
    helpIcon:SetTexture("Interface\\Common\\help-i")
    
    local helpFrame = CreateFrame("Frame", nil, parent)
    helpFrame:SetAllPoints(helpIcon)
    
    FrameUtils.AddTooltip(helpFrame, tooltipTitle, tooltipText)
    
    return helpIcon, helpFrame
end

--------------------------------------------------------------------------------
-- Global Appearance Section
-- Creates UI elements for managing global appearance sync
--------------------------------------------------------------------------------

-- Creates a complete global appearance UI section
-- @param parent: Parent frame for the UI elements
-- @param addonName: Name of the addon (e.g., "PeaversSystemBars")
-- @param addon: The addon table (e.g., PSB)
-- @param x: X offset for positioning
-- @param y: Y offset for positioning
-- @param onRefreshUI: Callback to refresh the addon's UI after changes
-- @return lastElement, newY: The last UI element created and the new Y position
function ConfigUIUtils.CreateGlobalAppearanceSection(parent, addonName, addon, x, y, onRefreshUI)
    local GlobalAppearance = PeaversCommons.GlobalAppearance
    local config = addon.Config

    -- Section header
    local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", x, y)
    header:SetText("Global Appearance")
    header:SetTextColor(1, 0.84, 0)
    y = y - 25

    -- Description
    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", x, y)
    desc:SetText("Sync appearance settings across all Peavers addons")
    desc:SetTextColor(0.7, 0.7, 0.7)
    y = y - 25

    -- Checkbox to enable/disable global appearance
    local checkbox = ConfigUIUtils.CreateCheckbox(
        parent,
        addonName .. "_UseGlobalAppearance",
        "Use Global Appearance",
        x,
        y,
        config.useGlobalAppearance,
        function(checked)
            if checked then
                config:EnableGlobalAppearance(addonName, function(key, value)
                    if onRefreshUI then onRefreshUI() end
                end)
            else
                config:DisableGlobalAppearance(addonName)
            end
            config:Save()
            if onRefreshUI then onRefreshUI() end
        end
    )
    y = y - 30

    -- Button container
    local buttonContainer = CreateFrame("Frame", nil, parent)
    buttonContainer:SetSize(400, 30)
    buttonContainer:SetPoint("TOPLEFT", x, y)

    -- "Copy to Global" button - copies current addon settings to global
    local copyToGlobalBtn = CreateFrame("Button", addonName .. "_CopyToGlobal", buttonContainer, "UIPanelButtonTemplate")
    copyToGlobalBtn:SetSize(150, 24)
    copyToGlobalBtn:SetPoint("LEFT", 0, 0)
    copyToGlobalBtn:SetText("Copy to Global")
    copyToGlobalBtn:SetScript("OnClick", function()
        if GlobalAppearance then
            config:CopyToGlobalAppearance()
            if PeaversCommons.Utils and PeaversCommons.Utils.Print then
                PeaversCommons.Utils.Print(addonName .. ": Appearance settings copied to global")
            end
        end
    end)

    -- Add tooltip to explain the button
    FrameUtils.AddTooltip(copyToGlobalBtn, "Copy to Global",
        "Copies this addon's current appearance settings (bar height, fonts, textures, etc.) to the global profile. Other addons using global appearance will receive these settings.")

    -- "Sync from Global" button - syncs global settings to this addon
    local syncFromGlobalBtn = CreateFrame("Button", addonName .. "_SyncFromGlobal", buttonContainer, "UIPanelButtonTemplate")
    syncFromGlobalBtn:SetSize(150, 24)
    syncFromGlobalBtn:SetPoint("LEFT", copyToGlobalBtn, "RIGHT", 10, 0)
    syncFromGlobalBtn:SetText("Sync from Global")
    syncFromGlobalBtn:SetScript("OnClick", function()
        if GlobalAppearance then
            GlobalAppearance:SyncToConfig(config)
            config:Save()
            if onRefreshUI then onRefreshUI() end
            if PeaversCommons.Utils and PeaversCommons.Utils.Print then
                PeaversCommons.Utils.Print(addonName .. ": Synced appearance from global settings")
            end
        end
    end)

    -- Add tooltip to explain the button
    FrameUtils.AddTooltip(syncFromGlobalBtn, "Sync from Global",
        "Copies the global appearance settings to this addon. Use this to manually update this addon's appearance to match the global profile.")

    y = y - 35

    -- Separator after section
    local separator = ConfigUIUtils.CreateSeparator(parent, x, y, 400)
    y = y - 15

    return separator, y
end

-- Creates a standard settings panel with scrollable content
function ConfigUIUtils.CreateSettingsPanel(title, description)
    local panel = CreateFrame("Frame")
    panel.name = title
    
    local scrollFrame, content = FrameUtils.CreateScrollFrame(panel)
    local yPos = 0
    
    -- Golden ratio for spacing (approximately 1.618)
    local goldenRatio = 1.618
    local baseSpacing = 25
    local sectionSpacing = baseSpacing * goldenRatio -- ~40px
    
    -- Create header and description
    local titleText = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    titleText:SetPoint("TOPLEFT", baseSpacing, yPos)
    titleText:SetText(title)
    titleText:SetTextColor(1, 0.84, 0) -- Gold color for main title
    titleText:SetFont(titleText:GetFont(), 24, "OUTLINE")
    yPos = yPos - (baseSpacing * goldenRatio)
    
    if description then
        local subtitleText = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        subtitleText:SetPoint("TOPLEFT", baseSpacing, yPos)
        subtitleText:SetText(description)
        subtitleText:SetFont(subtitleText:GetFont(), 14)
        yPos = yPos - sectionSpacing
    end
    
    -- Add a separator after the header
    local _, newY = FrameUtils.CreateSeparator(content, baseSpacing, yPos)
    yPos = newY - baseSpacing
    
    -- Add panel information and provide content scrolling setup
    panel.content = content
    panel.scrollFrame = scrollFrame
    panel.yPos = yPos
    panel.baseSpacing = baseSpacing
    panel.sectionSpacing = sectionSpacing
    
    -- Function to update content height
    panel.UpdateContentHeight = function(self, newYPos)
        self.content:SetHeight(math.abs(newYPos) + 50)
    end
    
    -- Standard panel callbacks
    panel.OnRefresh = function() end
    panel.OnCommit = function() end
    panel.OnDefault = function() end
    
    return panel
end

return ConfigUIUtils