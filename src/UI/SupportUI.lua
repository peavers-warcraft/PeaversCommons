local PeaversCommons = _G.PeaversCommons
local SupportUI = PeaversCommons.SupportUI or {}
PeaversCommons.SupportUI = SupportUI

local ICON_ALPHA = 0.1
local registeredAddons = {}
local initializedAddons = {}

SupportUI._pendingRegistrations = SupportUI._pendingRegistrations or {}

for _, addon in ipairs(SupportUI._pendingRegistrations) do
    if addon and addon.name then
        registeredAddons[addon.name] = addon
    end
end

while #SupportUI._pendingRegistrations > 0 do
    table.remove(SupportUI._pendingRegistrations)
end

function SupportUI:RegisterAddon(addon)
    if not addon or not addon.name then
        error("SupportUI:RegisterAddon - addon table with name field is required")
        return false
    end

    registeredAddons[addon.name] = addon
    return true
end

local function CreateSupportPanel(addon)
    local addonName = addon.name
    local version = addon.version or "Unknown"
    local iconPath = addon.iconPath or ("Interface\\AddOns\\" .. addonName .. "\\src\\Media\\Icon")

    local panel = CreateFrame("Frame")
    panel.name = "Support"

    local largeIcon = panel:CreateTexture(nil, "BACKGROUND")
    largeIcon:SetTexture(iconPath)
    largeIcon:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    largeIcon:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    largeIcon:SetAlpha(ICON_ALPHA)

    local titleText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    titleText:SetPoint("TOPLEFT", 16, -16)
    titleText:SetText("Support " .. addonName)

    local versionText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    versionText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -8)
    versionText:SetText("Version: " .. version)

    local supportInfo = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    supportInfo:SetPoint("TOPLEFT", 16, -70)
    supportInfo:SetPoint("TOPRIGHT", -16, -70)
    supportInfo:SetJustifyH("LEFT")
    supportInfo:SetText("If you enjoy " .. addonName .. " and would like to support its development, or if you need help or want to request new features, stop by the website.")
    supportInfo:SetSpacing(2)

    local websiteLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    websiteLabel:SetPoint("TOPLEFT", 16, -120)
    websiteLabel:SetText("Website:")

    local websiteURL = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    websiteURL:SetPoint("TOPLEFT", websiteLabel, "TOPLEFT", 70, 0)
    websiteURL:SetText("peavers.io")
    websiteURL:SetTextColor(0.3, 0.6, 1.0)

    local additionalInfo = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    additionalInfo:SetPoint("BOTTOMRIGHT", -16, 16)
    additionalInfo:SetJustifyH("RIGHT")
    additionalInfo:SetText("Thank you for using Peavers Addons!")

    panel.OnRefresh = function() end
    panel.OnCommit = function() end
    panel.OnDefault = function() end

    return panel
end

function SupportUI:InitializeAddonSupport(addon)
    if not addon or not addon.name then
        error("SupportUI:InitializeAddonSupport - addon object with name is required")
        return false
    end

    if initializedAddons[addon.name] then
        return true
    end

    if not addon.mainCategory then
        local category = nil

        if Settings and Settings.GetCategoryCount and Settings.GetCategoryInfo then
            local categoryCount = Settings.GetCategoryCount()
            if categoryCount and type(categoryCount) == "number" then
                for i = 1, categoryCount do
                    local id = Settings.GetCategoryInfo(i)
                    if id then
                        local name = Settings.GetCategoryInfo(id)
                        if id == addon.name or name == addon.name then
                            category = id
                            break
                        end
                    end
                end
            end
        end

        if category then
            addon.mainCategory = category
        else
            local mainPanel = CreateFrame("Frame")
            mainPanel.name = addon.name

            mainPanel.layoutIndex = 1
            mainPanel.OnShow = function() return true end

            local registeredCategory = Settings.RegisterCanvasLayoutCategory(mainPanel, mainPanel.name)
            if registeredCategory then
                addon.mainCategory = registeredCategory
                addon.mainCategory.ID = mainPanel.name
                Settings.RegisterAddOnCategory(addon.mainCategory)
            else
                local categoryData = Settings.CreateCategory(mainPanel.name, mainPanel.name, mainPanel.name)
                if categoryData then
                    addon.mainCategory = categoryData
                    addon.mainCategory.ID = mainPanel.name
                    Settings.RegisterAddOnCategory(categoryData)
                else
                    addon.mainCategory = mainPanel.name
                end
            end

            mainPanel.OnRefresh = function() end
            mainPanel.OnCommit = function() end
            mainPanel.OnDefault = function() end
        end
    end

    if not addon.supportCategory then
        local supportPanel = CreateSupportPanel(addon)

        local mainCategory = addon.mainCategory
        if type(mainCategory) == "string" then
            for i = 1, Settings.GetCategoryCount() do
                local id = Settings.GetCategoryInfo(i)
                if id == mainCategory then
                    mainCategory = id
                    break
                end
            end
        end

        if type(mainCategory) ~= "table" or not mainCategory.AddSubcategory then
            if type(mainCategory) == "string" then
                for i = 1, Settings.GetCategoryCount() do
                    local id = Settings.GetCategoryInfo(i)
                    if id == mainCategory then
                        mainCategory = id
                        break
                    end
                end
            end
        end

        if type(mainCategory) == "table" and mainCategory.AddSubcategory then
            local supportCategory = Settings.RegisterCanvasLayoutSubcategory(mainCategory, supportPanel, supportPanel.name)
            if supportCategory then
                addon.supportCategory = supportCategory
                addon.supportCategory.ID = supportPanel.name
            end
        end
    end

    if addon.ConfigUI and addon.ConfigUI.panel then
        local configPanel = addon.ConfigUI.panel
        if not addon.configCategory and addon.mainCategory then
            local mainCategory = addon.mainCategory

            if type(mainCategory) ~= "table" or not mainCategory.AddSubcategory then
                if type(mainCategory) == "string" then
                    for i = 1, Settings.GetCategoryCount() do
                        local id = Settings.GetCategoryInfo(i)
                        if id == mainCategory then
                            mainCategory = id
                            break
                        end
                    end
                end
            end

            if type(mainCategory) == "table" and mainCategory.AddSubcategory then
                local configCategory = Settings.RegisterCanvasLayoutSubcategory(mainCategory, configPanel, configPanel.name or "Settings")
                if configCategory then
                    addon.configCategory = configCategory
                    addon.configCategory.ID = configPanel.name or "Settings"
                end
            end
        end
    end

    if addon.supportPanel and not addon.supportCategory and addon.mainCategory then
        local mainCategory = addon.mainCategory

        if type(mainCategory) ~= "table" or not mainCategory.AddSubcategory then
            if type(mainCategory) == "string" then
                for i = 1, Settings.GetCategoryCount() do
                    local id = Settings.GetCategoryInfo(i)
                    if id == mainCategory then
                        mainCategory = id
                        break
                    end
                end
            end
        end

        if type(mainCategory) == "table" and mainCategory.AddSubcategory then
            local supportCategory = Settings.RegisterCanvasLayoutSubcategory(mainCategory, addon.supportPanel, addon.supportPanel.name or "Support")
            if supportCategory then
                addon.supportCategory = supportCategory
                addon.supportCategory.ID = addon.supportPanel.name or "Support"
            end
        end
    end

    initializedAddons[addon.name] = true
    return true
end

local allInitialized = false

function SupportUI:GetRegisteredAddons()
    return registeredAddons
end

function SupportUI:DirectRegisterAddon(addon)
    if not addon or not addon.name then return false end

    if not Settings then
        C_Timer.After(1, function() self:DirectRegisterAddon(addon) end)
        return false
    end

    local panel = CreateFrame("Frame")
    panel.name = addon.name

    panel.OnRefresh = function() end
    panel.OnCommit = function() end
    panel.OnDefault = function() end

    if not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then
        C_Timer.After(1, function() self:DirectRegisterAddon(addon) end)
        return false
    end

    local category = Settings.RegisterCanvasLayoutCategory(panel, addon.name)
    if not category then
        return false
    end

    Settings.RegisterAddOnCategory(category)

    addon.mainCategory = category
    addon.mainPanel = panel

    if addon.ConfigUI and addon.ConfigUI.panel then
        local configPanel = addon.ConfigUI.panel

        local configCategory = Settings.RegisterCanvasLayoutSubcategory(category, configPanel, configPanel.name or "Settings")
        if configCategory then
            addon.configCategory = configCategory
        end
    end

    if addon.SupportUI then
        if addon.supportPanel then
            local supportCategory = Settings.RegisterCanvasLayoutSubcategory(category, addon.supportPanel, addon.supportPanel.name or "Support")
            if supportCategory then
                addon.supportCategory = supportCategory
            end
        else
            local supportPanel = CreateFrame("Frame")
            supportPanel.name = "Support"

            local largeIcon = supportPanel:CreateTexture(nil, "BACKGROUND")
            largeIcon:SetTexture("Interface\\AddOns\\" .. addon.name .. "\\src\\Media\\Icon")
            largeIcon:SetPoint("TOPLEFT", supportPanel, "TOPLEFT", 0, 0)
            largeIcon:SetPoint("BOTTOMRIGHT", supportPanel, "BOTTOMRIGHT", 0, 0)
            largeIcon:SetAlpha(ICON_ALPHA)

            local titleText = supportPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
            titleText:SetPoint("TOPLEFT", 16, -16)
            titleText:SetText("Support " .. addon.name)

            supportPanel.OnRefresh = function() end
            supportPanel.OnCommit = function() end
            supportPanel.OnDefault = function() end

            local supportCategory = Settings.RegisterCanvasLayoutSubcategory(category, supportPanel, "Support")
            if supportCategory then
                addon.supportCategory = supportCategory
                addon.supportPanel = supportPanel
            end
        end
    end

    return true
end

function SupportUI:InitializeAll()
    if allInitialized then
        return
    end

    C_Timer.After(0.5, function()
        for addonName, addon in pairs(registeredAddons) do
            self:DirectRegisterAddon(addon)
        end
    end)

    allInitialized = true
end

return SupportUI
