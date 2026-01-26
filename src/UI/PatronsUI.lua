-- PeaversCommons PatronsUI Module
local PeaversCommons = _G.PeaversCommons
local PatronsUI = {}
PeaversCommons.PatronsUI = PatronsUI

-- Reference to other modules
local Patrons = PeaversCommons.Patrons
local Utils = PeaversCommons.Utils

-- Constants for UI
local PADDING = 16
local LINE_HEIGHT = 18
local SECTION_SPACING = 15
local SCROLL_THRESHOLD = 10  -- Enable scrolling when more than this many patrons
local SCROLL_HEIGHT = 120    -- Height of scroll area when scrolling is enabled

-- Create a frame to display patron information
function PatronsUI:CreatePatronsFrame(parentFrame)
    -- Safety check
    if not parentFrame then
        return nil
    end
    
    -- Container frame
    local patronsFrame = CreateFrame("Frame", nil, parentFrame)
    patronsFrame:SetPoint("TOP", 0, -260)  -- Position below other support UI elements (adjusted for UI Vault + margins)
    patronsFrame:SetPoint("LEFT", PADDING, 0)
    patronsFrame:SetPoint("RIGHT", -PADDING, 0)
    patronsFrame:SetHeight(200)  -- Initial height, will be adjusted as needed
    
    -- UI Vault callout frame
    local uiVaultFrame = CreateFrame("Frame", nil, patronsFrame)
    uiVaultFrame:SetPoint("BOTTOM", patronsFrame, "TOP", 0, 50)  -- 50px margin below
    uiVaultFrame:SetPoint("LEFT", 0, 0)
    uiVaultFrame:SetPoint("RIGHT", 0, 0)
    uiVaultFrame:SetHeight(60)
    
    -- UI Vault title
    local uiVaultTitle = uiVaultFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    uiVaultTitle:SetPoint("TOP", 0, 0)
    uiVaultTitle:SetText("NEW: UI Vault")
    uiVaultTitle:SetTextColor(0.3, 0.8, 1.0)  -- Light blue color
    
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
    titleText:SetTextColor(1, 0.82, 0)  -- Gold-ish color
    
    -- Container for patron list (will hold either simple text or scroll frame)
    local listContainer = CreateFrame("Frame", nil, patronsFrame)
    listContainer:SetPoint("TOP", titleText, "BOTTOM", 0, -SECTION_SPACING)
    listContainer:SetPoint("LEFT", patronsFrame, "LEFT", PADDING, 0)
    listContainer:SetPoint("RIGHT", patronsFrame, "RIGHT", -PADDING, 0)
    listContainer:SetHeight(LINE_HEIGHT * 3)  -- Initial height

    -- Simple text display for small patron counts
    local patronsList = listContainer:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    patronsList:SetPoint("TOPLEFT", 0, 0)
    patronsList:SetPoint("TOPRIGHT", 0, 0)
    patronsList:SetJustifyH("CENTER")
    patronsList:SetSpacing(5)

    -- Scroll frame for large patron counts (created on demand)
    local scrollFrame = nil
    local scrollChild = nil
    local scrollText = nil

    local function CreateScrollFrame()
        if scrollFrame then return end

        -- Create scroll frame
        scrollFrame = CreateFrame("ScrollFrame", nil, listContainer, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 0, 0)
        scrollFrame:SetPoint("BOTTOMRIGHT", -24, 0)  -- Leave room for scrollbar

        -- Create scroll child
        scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetSize(listContainer:GetWidth() - 24, 1)  -- Height set dynamically
        scrollFrame:SetScrollChild(scrollChild)

        -- Create text in scroll child
        scrollText = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        scrollText:SetPoint("TOPLEFT", 0, 0)
        scrollText:SetPoint("TOPRIGHT", 0, 0)
        scrollText:SetJustifyH("CENTER")
        scrollText:SetSpacing(5)

        scrollFrame:Hide()  -- Hidden by default
    end

    -- Store references to UI elements
    patronsFrame.titleText = titleText
    patronsFrame.patronsList = patronsList
    patronsFrame.listContainer = listContainer

    -- Immediately load and display patron list
    function patronsFrame:UpdatePatrons()
        -- Safety check for Patrons module
        if not Patrons or not Patrons.GetSorted then
            self:Hide()
            return
        end

        -- Get sorted patrons (gold tier first, then silver, then alphabetically)
        local allPatrons = Patrons:GetSorted()

        -- Hide the frame if no patrons
        if #allPatrons == 0 then
            self:Hide()
            return
        else
            self:Show()
        end

        -- Build colored patron names with tier colors
        local patronNames = {}
        for _, patron in ipairs(allPatrons) do
            local coloredName = Patrons:GetColoredName(patron)
            table.insert(patronNames, coloredName)
        end

        -- Join with bullet points
        local displayText = table.concat(patronNames, " |cffffffff•|r ")

        -- Determine if we need scrolling
        local useScrolling = #allPatrons > SCROLL_THRESHOLD

        if useScrolling then
            -- Create scroll frame if needed
            CreateScrollFrame()

            -- Show scroll frame, hide simple text
            scrollFrame:Show()
            patronsList:Hide()

            -- Set content
            scrollText:SetText(displayText)

            -- Set scroll child height based on content
            local textHeight = scrollText:GetStringHeight() + PADDING
            scrollChild:SetHeight(textHeight)
            scrollChild:SetWidth(listContainer:GetWidth() - 24)

            -- Set container height to scroll area height
            listContainer:SetHeight(SCROLL_HEIGHT)
        else
            -- Hide scroll frame if it exists
            if scrollFrame then
                scrollFrame:Hide()
            end
            patronsList:Show()

            -- Set content
            patronsList:SetText(displayText)

            -- Set height based on text height
            local textHeight = patronsList:GetStringHeight() + PADDING
            listContainer:SetHeight(textHeight)
        end

        -- Update total frame height (including UI Vault section above with margins)
        self:SetHeight(self.titleText:GetHeight() + SECTION_SPACING + listContainer:GetHeight() + PADDING + 60 + 100)

        -- Flag as updated
        self.isUpdated = true
    end
    
    -- Force update function (simplified)
    patronsFrame.ForceUpdate = function()
        patronsFrame:UpdatePatrons()
    end
    
    -- Do the initial update immediately
    patronsFrame:UpdatePatrons()
    
    return patronsFrame
end

-- Function to add patron display to an addon's support UI
function PatronsUI:AddToSupportPanel(addon)
    -- Check for needed addon support panel
    if not addon then
        return false
    end
    
    -- For the direct approach used in addons, check for the direct panel
    if not addon.supportPanel and addon.directPanel then
        addon.supportPanel = addon.directPanel
    end
    
    if not addon.supportPanel then
        -- Create a support panel for the addon if needed
        if addon.name and addon.mainCategory then
            addon.supportPanel = CreateFrame("Frame")
            addon.supportPanel.name = "Support"
        else
            return false
        end
    end
    
    -- Create patrons frame if it doesn't exist
    if not addon.patronsFrame then
        addon.patronsFrame = self:CreatePatronsFrame(addon.supportPanel)
        
        -- Hook the panel's OnShow to update patrons
        if addon.patronsFrame and addon.supportPanel.SetScript then
            local originalOnShow = addon.supportPanel:GetScript("OnShow")
            addon.supportPanel:SetScript("OnShow", function(panel, ...)
                -- Call original OnShow if it exists
                if originalOnShow then
                    originalOnShow(panel, ...)
                end
                
                -- Update patrons display using the ForceUpdate function
                if addon.patronsFrame and addon.patronsFrame.ForceUpdate then
                    addon.patronsFrame.ForceUpdate()
                end
            end)
        end
        
        -- Try again after a delay in case panel isn't fully initialized
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
    -- Check all major sources of addon registrations
    local registeredAddons = {}
    
    -- Check SettingsUI first (newer system)
    if PeaversCommons.SettingsUI and PeaversCommons.SettingsUI.GetRegisteredAddons then
        local settingsAddons = PeaversCommons.SettingsUI:GetRegisteredAddons()
        if settingsAddons then
            for addonName, addon in pairs(settingsAddons) do
                registeredAddons[addonName] = addon
            end
        end
    end
    
    -- Check SupportUI second (older system)
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
    
    -- Check specific known addons
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
    
    -- Add patrons display to each addon
    for addonName, addon in pairs(registeredAddons) do
        -- Try existing panel first
        if addon.supportPanel or addon.directPanel then
            if not addon.supportPanel and addon.directPanel then
                addon.supportPanel = addon.directPanel
            end
            self:AddToSupportPanel(addon)
        else
            -- Try again after a delay
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

-- Return the module
return PatronsUI