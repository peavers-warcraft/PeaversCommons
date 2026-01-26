-- PeaversCommons PatronsUI Module
local PeaversCommons = _G.PeaversCommons
local PatronsUI = {}
PeaversCommons.PatronsUI = PatronsUI

-- Reference to other modules
local Patrons = PeaversCommons.Patrons
local Utils = PeaversCommons.Utils

-- Constants for UI
local PADDING = 16
local SECTION_SPACING = 15

-- Create a frame to display patron information
function PatronsUI:CreatePatronsFrame(parentFrame)
    -- Safety check
    if not parentFrame then
        return nil
    end

    -- Container frame
    local patronsFrame = CreateFrame("Frame", nil, parentFrame)
    patronsFrame:SetPoint("TOP", 0, -260)
    patronsFrame:SetPoint("LEFT", PADDING, 0)
    patronsFrame:SetPoint("RIGHT", -PADDING, 0)
    patronsFrame:SetHeight(200)

    -- UI Vault callout frame
    local uiVaultFrame = CreateFrame("Frame", nil, patronsFrame)
    uiVaultFrame:SetPoint("BOTTOM", patronsFrame, "TOP", 0, 50)
    uiVaultFrame:SetPoint("LEFT", 0, 0)
    uiVaultFrame:SetPoint("RIGHT", 0, 0)
    uiVaultFrame:SetHeight(60)

    -- UI Vault title
    local uiVaultTitle = uiVaultFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    uiVaultTitle:SetPoint("TOP", 0, 0)
    uiVaultTitle:SetText("NEW: UI Vault")
    uiVaultTitle:SetTextColor(0.3, 0.8, 1.0)

    -- UI Vault description
    local uiVaultDesc = uiVaultFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    uiVaultDesc:SetPoint("TOP", uiVaultTitle, "BOTTOM", 0, -8)
    uiVaultDesc:SetPoint("LEFT", uiVaultFrame, "LEFT", PADDING, 0)
    uiVaultDesc:SetPoint("RIGHT", uiVaultFrame, "RIGHT", -PADDING, 0)
    uiVaultDesc:SetJustifyH("CENTER")
    uiVaultDesc:SetText("One-click backup and restore of all WoW addons")

    -- UI Vault URL
    local uiVaultURL = uiVaultFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    uiVaultURL:SetPoint("TOP", uiVaultDesc, "BOTTOM", 0, -8)
    uiVaultURL:SetText("Get it at |cff3abdf7vault.peavers.io|r")
    uiVaultURL:SetTextColor(1, 1, 1)

    -- Patrons title
    local titleText = patronsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    titleText:SetPoint("TOP", 0, 0)
    titleText:SetText("Special Thanks To Our Patrons")
    titleText:SetTextColor(1, 0.82, 0)

    -- Patron list - simple centered text (same anchoring style as title)
    local patronsList = patronsFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    patronsList:SetPoint("TOP", titleText, "BOTTOM", 0, -SECTION_SPACING)
    patronsList:SetJustifyH("CENTER")
    patronsList:SetSpacing(4)

    -- Store references
    patronsFrame.titleText = titleText
    patronsFrame.patronsList = patronsList

    -- Update patron list display
    function patronsFrame:UpdatePatrons()
        if not Patrons or not Patrons.GetSorted then
            self:Hide()
            return
        end

        local allPatrons = Patrons:GetSorted()

        if #allPatrons == 0 then
            self:Hide()
            return
        else
            self:Show()
        end

        -- Build colored patron names (one per line)
        local patronLines = {}
        for _, patron in ipairs(allPatrons) do
            local coloredName = Patrons:GetColoredName(patron)
            table.insert(patronLines, coloredName)
        end

        -- Display as vertical list
        local displayText = table.concat(patronLines, "\n")
        self.patronsList:SetText(displayText)

        -- Update frame height
        local textHeight = self.patronsList:GetStringHeight() + PADDING
        self:SetHeight(self.titleText:GetHeight() + SECTION_SPACING + textHeight + 60 + 100)

        self.isUpdated = true
    end

    -- Force update function
    patronsFrame.ForceUpdate = function()
        patronsFrame:UpdatePatrons()
    end

    -- Initial update
    patronsFrame:UpdatePatrons()

    return patronsFrame
end

-- Function to add patron display to an addon's support UI
function PatronsUI:AddToSupportPanel(addon)
    if not addon then
        return false
    end

    if not addon.supportPanel and addon.directPanel then
        addon.supportPanel = addon.directPanel
    end

    if not addon.supportPanel then
        if addon.name and addon.mainCategory then
            addon.supportPanel = CreateFrame("Frame")
            addon.supportPanel.name = "Support"
        else
            return false
        end
    end

    if not addon.patronsFrame then
        addon.patronsFrame = self:CreatePatronsFrame(addon.supportPanel)

        if addon.patronsFrame and addon.supportPanel.SetScript then
            local originalOnShow = addon.supportPanel:GetScript("OnShow")
            addon.supportPanel:SetScript("OnShow", function(panel, ...)
                if originalOnShow then
                    originalOnShow(panel, ...)
                end
                if addon.patronsFrame and addon.patronsFrame.ForceUpdate then
                    addon.patronsFrame.ForceUpdate()
                end
            end)
        end

        C_Timer.After(1, function()
            if not addon.patronsFrame.isUpdated and addon.patronsFrame.ForceUpdate then
                addon.patronsFrame.ForceUpdate()
            end
        end)
    end

    return true
end

-- Function to initialize patrons display for all registered addons
function PatronsUI:InitializeForAllAddons()
    local registeredAddons = {}

    if PeaversCommons.SettingsUI and PeaversCommons.SettingsUI.GetRegisteredAddons then
        local settingsAddons = PeaversCommons.SettingsUI:GetRegisteredAddons()
        if settingsAddons then
            for addonName, addon in pairs(settingsAddons) do
                registeredAddons[addonName] = addon
            end
        end
    end

    if PeaversCommons.SupportUI and PeaversCommons.SupportUI.GetRegisteredAddons then
        local supportAddons = PeaversCommons.SupportUI:GetRegisteredAddons()
        if supportAddons then
            for addonName, addon in pairs(supportAddons) do
                if not registeredAddons[addonName] then
                    registeredAddons[addonName] = addon
                end
            end
        end
    end

    local knownAddons = {
        "PeaversDynamicStats", "PeaversAlwaysSquare", "PeaversActionPerMinute",
        "PeaversItemLevel", "PeaversRemembersYou", "PeaversSafeList",
        "PeaversTalents", "PeaversTalentsData"
    }

    for _, addonName in ipairs(knownAddons) do
        if _G[addonName] and not registeredAddons[addonName] then
            registeredAddons[addonName] = _G[addonName]
        end
    end

    for addonName, addon in pairs(registeredAddons) do
        if addon.supportPanel or addon.directPanel then
            if not addon.supportPanel and addon.directPanel then
                addon.supportPanel = addon.directPanel
            end
            self:AddToSupportPanel(addon)
        else
            C_Timer.After(1, function()
                if addon.supportPanel or addon.directPanel then
                    if not addon.supportPanel and addon.directPanel then
                        addon.supportPanel = addon.directPanel
                    end
                    self:AddToSupportPanel(addon)
                end
            end)
        end
    end

    return true
end

return PatronsUI
