-- PeaversCommons SettingsUI Module
local PeaversCommons = _G.PeaversCommons
local SettingsUI = {}
PeaversCommons.SettingsUI = SettingsUI

-- Get reference to other modules
local Utils = PeaversCommons.Utils

-- Track registered addons
local registeredAddons = {}

-- Constants
local ICON_ALPHA = 0.1
local ICON_PATH = "Interface\\AddOns\\PeaversCommons\\src\\Media\\Icon" -- Always use PeaversCommons icon

-- Create a standardized settings UI for an addon
function SettingsUI:CreateSettingsPages(addonRef, addonName, addonTitle, addonDescription, slashCommands, options)
    -- Validate and prepare inputs
    if not addonRef or not addonName then
        return false
    end

    options = options or {}

    -- Track this addon if not already registered
    if not registeredAddons[addonName] then
        registeredAddons[addonName] = addonRef
    end

    -- Create the main panel (Support UI as landing page)
    local mainPanel = CreateFrame("Frame")
    mainPanel.name = addonName

    -- Required callbacks
    mainPanel.OnRefresh = function() end
    mainPanel.OnCommit = function() end
    mainPanel.OnDefault = function() end

    -- Get addon version
    local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "1.0.0"

    -- Add background image (always use PeaversCommons icon)
    local largeIcon = mainPanel:CreateTexture(nil, "BACKGROUND")
    largeIcon:SetTexture(ICON_PATH)
    largeIcon:SetPoint("TOPLEFT", mainPanel, "TOPLEFT", 0, 0)
    largeIcon:SetPoint("BOTTOMRIGHT", mainPanel, "BOTTOMRIGHT", 0, 0)
    largeIcon:SetAlpha(ICON_ALPHA)

    -- Create header and description
    local titleText = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    titleText:SetPoint("TOPLEFT", 16, -16)
    titleText:SetText(addonTitle)
    titleText:SetTextColor(1, 0.84, 0)  -- Gold color for title

    -- Version information
    local versionText = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    versionText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -8)
    versionText:SetText("Version: " .. version)

    -- Support information
    local supportInfo = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    supportInfo:SetPoint("TOPLEFT", 16, -70)
    supportInfo:SetPoint("TOPRIGHT", -16, -70)
    supportInfo:SetJustifyH("LEFT")
    supportInfo:SetText(addonDescription .. " If you enjoy this addon and would like to support its development, or if you need help, stop by the website.")
    supportInfo:SetSpacing(2)

    -- Website URL
    local websiteLabel = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    websiteLabel:SetPoint("TOPLEFT", 16, -120)
    websiteLabel:SetText("Website:")

    local websiteURL = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    websiteURL:SetPoint("TOPLEFT", websiteLabel, "TOPLEFT", 70, 0)
    websiteURL:SetText("peavers.io")
    websiteURL:SetTextColor(0.3, 0.6, 1.0)

    -- Additional info
    local additionalInfo = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    additionalInfo:SetPoint("BOTTOMRIGHT", -16, 16)
    additionalInfo:SetJustifyH("RIGHT")
    additionalInfo:SetText("Thank you for using Peavers Addons!")

    -- Now create/prepare the settings panel
    local settingsPanel

    if addonRef.ConfigUI and addonRef.ConfigUI.panel then
        -- Use existing ConfigUI panel
        settingsPanel = addonRef.ConfigUI.panel
    else
        -- Create a simple settings panel with commands
        settingsPanel = CreateFrame("Frame")
        settingsPanel.name = "Settings"

        -- Required callbacks
        settingsPanel.OnRefresh = function() end
        settingsPanel.OnCommit = function() end
        settingsPanel.OnDefault = function() end

        -- Add content
        local settingsTitle = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        settingsTitle:SetPoint("TOPLEFT", 16, -16)
        settingsTitle:SetText("Settings")

        -- Add commands if provided
        if slashCommands and #slashCommands > 0 then
            local commandsTitle = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            commandsTitle:SetPoint("TOPLEFT", settingsTitle, "BOTTOMLEFT", 0, -16)
            commandsTitle:SetText("Available Commands:")

            local commandsList = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            commandsList:SetPoint("TOPLEFT", commandsTitle, "BOTTOMLEFT", 10, -8)
            commandsList:SetJustifyH("LEFT")
            commandsList:SetText(table.concat(slashCommands, "\n"))
        end
    end

    -- Register with the Settings API
    if Settings then
        -- Register main category
        local category = Settings.RegisterCanvasLayoutCategory(mainPanel, mainPanel.name)

        -- This is the CRITICAL line to make it appear in Options > Addons
        Settings.RegisterAddOnCategory(category)

        -- Store the category and its ID
        addonRef.directCategory = category
        addonRef.directCategoryID = category:GetID()
        addonRef.directPanel = mainPanel
        addonRef.supportPanel = mainPanel  -- For PatronsUI compatibility

        -- Make sure the addon global can find this category too
        -- This is critical for slash commands
        local globalAddon = _G[addonName]
        if globalAddon then
            globalAddon.directCategory = category
            globalAddon.directCategoryID = category:GetID()
            globalAddon.directPanel = mainPanel
            globalAddon.supportPanel = mainPanel
        end

        -- Register settings panel as subcategory
        if settingsPanel then
            local settingsCategory = Settings.RegisterCanvasLayoutSubcategory(category, settingsPanel, settingsPanel.name)
            addonRef.directSettingsCategory = settingsCategory
            addonRef.directSettingsCategoryID = settingsCategory:GetID()

            -- Store this in the global addon reference too for slash commands
            if globalAddon then
                globalAddon.directSettingsCategory = settingsCategory
                globalAddon.directSettingsCategoryID = settingsCategory:GetID()
            end
        end

        -- Add patrons display automatically
        if PeaversCommons.PatronsUI then
            PeaversCommons.PatronsUI:AddToSupportPanel(addonRef)
        end

        return mainPanel, settingsPanel
    end

    return nil
end

-- Function to get all registered addons
function SettingsUI:GetRegisteredAddons()
    return registeredAddons
end

-- Return the module
return SettingsUI
