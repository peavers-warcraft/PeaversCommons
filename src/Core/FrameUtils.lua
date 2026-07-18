local PeaversCommons = _G.PeaversCommons
local FrameUtils = {}
PeaversCommons.FrameUtils = FrameUtils

-- Shared palette. FrameUtils backs the legacy ConfigUIUtils helpers, which is
-- how PeaversConsumables and PeaversBestInSlot build their entire settings page,
-- so theming here is what brings those addons in line without touching them.
-- Theme.lua is loaded immediately before this file in the .toc.
local C = PeaversCommons.Theme.Colors

function FrameUtils.GetGlobal(name)
    if name and type(name) == "string" then
        return _G[name]
    end
    return nil
end

function FrameUtils.CreateSectionHeader(parent, text, x, y)
    local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", x, y)
    header:SetText(tostring(text):upper())
    header:SetTextColor(unpack(C.eyebrow))
    header:SetFont(header:GetFont(), 10, "")
    header:SetWidth(400)
    header:SetJustifyH("LEFT")
    return header, y - 25
end

function FrameUtils.CreateLabel(parent, text, x, y, fontObject)
    local label = parent:CreateFontString(nil, "ARTWORK", fontObject or "GameFontNormal")
    label:SetPoint("TOPLEFT", x, y)
    label:SetText(text)
    label:SetTextColor(unpack(C.text))
    return label, y - 20
end

function FrameUtils.CreateCheckbox(parent, name, text, x, y, initialValue, textColor, onClick)
    local checkbox = CreateFrame("CheckButton", name, parent, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", x, y)

    -- Replace the stock bevelled box and gold tick with the flat themed one.
    -- Restyled in place so :GetChecked()/:SetChecked() and the global name survive.
    PeaversCommons.Theme.StyleCheckButton(checkbox)

    local textObj = checkbox.Text
    if not textObj and checkbox:GetName() then
        textObj = FrameUtils.GetGlobal(checkbox:GetName() .. "Text")
    end

    if textObj then
        textObj:SetText(text)
        textObj:SetFontObject("GameFontNormal")
        -- The template anchors its label to the old 26px box; re-anchor so the
        -- gap matches the smaller box.
        textObj:ClearAllPoints()
        textObj:SetPoint("LEFT", checkbox, "RIGHT", 8, 0)
        textObj:SetTextColor(unpack(textColor or C.text))
    end

    if initialValue ~= nil then
        checkbox:SetChecked(initialValue)
    end

    if onClick then
        checkbox:SetScript("OnClick", onClick)
    end

    return checkbox, y - 25
end

function FrameUtils.CreateSlider(parent, name, minVal, maxVal, step, x, y, initialValue, width)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x, y)
    slider:SetWidth(width or 400)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetValue(initialValue)

    local sliderName = slider:GetName()
    if sliderName then
        local lowText = FrameUtils.GetGlobal(sliderName .. "Low")
        local highText = FrameUtils.GetGlobal(sliderName .. "High")
        local valueText = FrameUtils.GetGlobal(sliderName .. "Text")

        if lowText then
            lowText:SetText("")
        end
        if highText then
            highText:SetText("")
        end
        if valueText then
            valueText:SetText("")
        end
    end

    return slider, y - 40
end

function FrameUtils.CreateDropdown(parent, name, x, y, width, initialText)
    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", x, y)
    UIDropDownMenu_SetWidth(dropdown, width or 360)

    if initialText then
        UIDropDownMenu_SetText(dropdown, initialText)
    end

    return dropdown, y - 40
end

function FrameUtils.CreateScrollFrame(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 16, -16)
    scrollFrame:SetPoint("BOTTOMRIGHT", -32, 16)

    local content = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(content)
    content:SetWidth(scrollFrame:GetWidth() - 16)
    content:SetHeight(1)

    return scrollFrame, content
end

function FrameUtils.CreateFrame(name, parent, width, height, backdrop)
    local frame = CreateFrame("Frame", name, parent, backdrop and "BackdropTemplate" or nil)

    if width and height then
        frame:SetSize(width, height)
    end

    if backdrop then
        frame:SetBackdrop(backdrop)
    end

    return frame
end

function FrameUtils.CreateButton(parent, name, text, x, y, width, height, onClick)
    local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", x, y)
    button:SetSize(width or 100, height or 22)
    button:SetText(text)

    if onClick then
        button:SetScript("OnClick", onClick)
    end

    return button, y - (height or 22) - 5
end

function FrameUtils.CreateColorPicker(parent, name, label, x, y, initialColor, onChange)
    local colorFrame = CreateFrame("Button", name, parent, "BackdropTemplate")
    colorFrame:SetPoint("TOPLEFT", x, y)
    colorFrame:SetSize(16, 16)
    colorFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })

    if initialColor then
        colorFrame:SetBackdropColor(initialColor.r, initialColor.g, initialColor.b)
    else
        colorFrame:SetBackdropColor(1, 1, 1)
    end

    local colorLabel
    if label then
        colorLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        colorLabel:SetPoint("LEFT", colorFrame, "RIGHT", 5, 0)
        colorLabel:SetText(label)
    end

    colorFrame:SetScript("OnClick", function()
        local function applyColor(newR, newG, newB)
            colorFrame:SetBackdropColor(newR, newG, newB)
            if onChange then
                onChange(newR, newG, newB)
            end
        end

        local curR, curG, curB = colorFrame:GetBackdropColor()

        ColorPickerFrame:SetupColorPickerAndShow({
            r = curR, g = curG, b = curB,
            hasOpacity = false,
            previousValues = { r = curR, g = curG, b = curB },
            swatchFunc = function() applyColor(ColorPickerFrame:GetColorRGB()) end,
            cancelFunc = function(previous) applyColor(previous.r, previous.g, previous.b) end,
        })
    end)

    return colorFrame, colorLabel, y - 25
end

function FrameUtils.CreateSeparator(parent, x, y, width)
    local separator = parent:CreateTexture(nil, "ARTWORK")
    separator:SetPoint("TOPLEFT", x, y)
    separator:SetSize(width or 450, 1)
    separator:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)

    return separator, y - 15
end

function FrameUtils.CreateTab(dialog, id, text, tabPrefix)
    local tabName = (tabPrefix or "Tab") .. id
    local tab = CreateFrame("Button", tabName, dialog, "PanelTabButtonTemplate")
    tab:SetText(text)
    tab:SetID(id)

    if id == 1 then
        tab:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 5, -30)
    else
        tab:SetPoint("LEFT", dialog.Tabs[id - 1], "RIGHT", -16, 0)
    end

    tab:SetScript("OnClick", function()
        PanelTemplates_SetTab(dialog, id)
        for _, content in pairs(dialog.TabContents) do
            content:Hide()
        end
        dialog.TabContents[id]:Show()
    end)

    return tab
end

function FrameUtils.CreateTabContent(dialog)
    local content = CreateFrame("Frame", nil, dialog)
    content:SetPoint("TOPLEFT", dialog, "TOPLEFT", 0, -25)
    content:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", 0, -30)
    content:Hide()
    return content
end

function FrameUtils.CreateTitleBackground(dialog, height)
    local titleBg = CreateFrame("Frame", nil, dialog)
    titleBg:SetPoint("TOPLEFT", 0, 0)
    titleBg:SetPoint("TOPRIGHT", 0, 0)
    titleBg:SetHeight(height or 20)
    titleBg:SetFrameLevel(dialog:GetFrameLevel() + 1)
    return titleBg
end

function FrameUtils.CreateCloseButton(dialog)
    local closeButton = CreateFrame("Button", nil, dialog, "UIPanelCloseButtonNoScripts")
    closeButton:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", 0, 0)
    closeButton:SetFrameStrata("DIALOG")
    closeButton:SetFrameLevel(dialog:GetFrameLevel() + 1000)
    closeButton:Raise()
    closeButton:SetScript("OnClick", function()
        dialog:Hide()
    end)
    return closeButton
end

function FrameUtils.CreateInputBox(parent, name, width, height, x, y)
    local editBox = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
    editBox:SetPoint("TOPLEFT", x, y)
    editBox:SetSize(width or 200, height or 20)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(255)
    
    return editBox, y - (height or 20) - 5
end

function FrameUtils.AddTooltip(frame, title, text)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if title then
            GameTooltip:SetText(title, 1, 1, 1)
        end
        if text then
            GameTooltip:AddLine(text, nil, nil, nil, true)
        end
        GameTooltip:Show()
    end)
    
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

return FrameUtils