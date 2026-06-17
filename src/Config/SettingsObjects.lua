local PeaversCommons = _G.PeaversCommons
local SettingsObjects = {}
PeaversCommons.SettingsObjects = SettingsObjects

local DefaultConfig = PeaversCommons.DefaultConfig
local ConfigSchema = PeaversCommons.ConfigSchema
local W = PeaversCommons.Widgets

local CONTROL_SPACING = 8
local SECTION_BOTTOM_SPACING = 20

local function ResolveWidth(parent, opts)
    local indent = opts.indent or 25
    local parentWidth = parent and parent:GetWidth() or 0
    if parentWidth > 100 then
        return parentWidth - (indent * 2) - 10
    end
    return opts.width or 360
end

local function MakeOnChange(config, key, opts)
    return function(value)
        config[key] = value
        if config.Save then config:Save() end
        if opts.onChanged then opts.onChanged(key, value) end
    end
end

local function DropdownOptionsFromSchema(schema)
    local items = {}
    if schema and schema.options then
        for value, label in pairs(schema.options) do
            table.insert(items, { value = value, label = label })
        end
        table.sort(items, function(a, b) return tostring(a.label) < tostring(b.label) end)
    end
    return items
end

local function FontDropdownOptions()
    local fonts = DefaultConfig.GetFonts()
    local items = {}
    for path, name in pairs(fonts) do
        table.insert(items, { value = path, label = name })
    end
    table.sort(items, function(a, b) return a.label < b.label end)
    return items
end

local function TextureDropdownOptions()
    local textures = DefaultConfig.GetBarTextures()
    local items = {}
    for path, name in pairs(textures) do
        table.insert(items, { value = path, label = name })
    end
    table.sort(items, function(a, b) return a.label < b.label end)
    return items
end

function SettingsObjects.BarAppearance(parent, config, y, opts)
    opts = opts or {}
    local indent = opts.indent or 25
    local width = ResolveWidth(parent, opts)
    local exclude = opts.exclude or {}

    local _, newY = W:CreateSectionHeader(parent, "Bar Appearance", indent, y)
    y = newY - CONTROL_SPACING

    if not exclude.barHeight then
        local schema = ConfigSchema.Common.barHeight
        local slider = W:CreateSlider(parent, schema.label, {
            min = schema.min, max = schema.max, step = schema.step,
            value = config.barHeight or schema.default,
            width = width,
            onChange = MakeOnChange(config, "barHeight", opts),
        })
        slider:SetPoint("TOPLEFT", indent, y)
        y = y - 52
    end

    if not exclude.barSpacing then
        local schema = ConfigSchema.Common.barSpacing
        local slider = W:CreateSlider(parent, schema.label, {
            min = schema.min, max = schema.max, step = schema.step,
            value = config.barSpacing or schema.default,
            width = width,
            onChange = MakeOnChange(config, "barSpacing", opts),
        })
        slider:SetPoint("TOPLEFT", indent, y)
        y = y - 52
    end

    if not exclude.barAlpha then
        local schema = ConfigSchema.Common.barAlpha
        local slider = W:CreateSlider(parent, schema.label, {
            min = schema.min, max = schema.max, step = schema.step,
            value = config.barAlpha or schema.default,
            width = width,
            onChange = MakeOnChange(config, "barAlpha", opts),
        })
        slider:SetPoint("TOPLEFT", indent, y)
        y = y - 52
    end

    if not exclude.barBgAlpha then
        local schema = ConfigSchema.Common.barBgAlpha
        local slider = W:CreateSlider(parent, schema.label, {
            min = schema.min, max = schema.max, step = schema.step,
            value = config.barBgAlpha or schema.default,
            width = width,
            onChange = MakeOnChange(config, "barBgAlpha", opts),
        })
        slider:SetPoint("TOPLEFT", indent, y)
        y = y - 52
    end

    if not exclude.barTexture then
        local dropdown = W:CreateDropdown(parent, "Bar Texture", {
            options = TextureDropdownOptions(),
            selected = config.barTexture or "Interface\\TargetingFrame\\UI-StatusBar",
            width = width,
            onChange = MakeOnChange(config, "barTexture", opts),
        })
        dropdown:SetPoint("TOPLEFT", indent, y)
        y = y - 58
    end

    return y - SECTION_BOTTOM_SPACING
end

function SettingsObjects.FontSettings(parent, config, y, opts)
    opts = opts or {}
    local indent = opts.indent or 25
    local width = ResolveWidth(parent, opts)
    local exclude = opts.exclude or {}

    local _, newY = W:CreateSectionHeader(parent, "Font Settings", indent, y)
    y = newY - CONTROL_SPACING

    if not exclude.fontFace then
        local dropdown = W:CreateDropdown(parent, "Font", {
            options = FontDropdownOptions(),
            selected = config.fontFace or DefaultConfig.GetDefaultFont(),
            width = width,
            onChange = MakeOnChange(config, "fontFace", opts),
        })
        dropdown:SetPoint("TOPLEFT", indent, y)
        y = y - 58
    end

    if not exclude.fontSize then
        local schema = ConfigSchema.Common.fontSize
        local slider = W:CreateSlider(parent, schema.label, {
            min = schema.min, max = schema.max, step = schema.step,
            value = config.fontSize or schema.default,
            width = width,
            onChange = MakeOnChange(config, "fontSize", opts),
        })
        slider:SetPoint("TOPLEFT", indent, y)
        y = y - 52
    end

    if not exclude.fontOutline then
        local currentValue
        if type(config.fontOutline) == "string" then
            currentValue = (config.fontOutline == "OUTLINE")
        else
            currentValue = config.fontOutline ~= false
        end
        local toggle = W:CreateToggle(parent, "Font Outline", {
            checked = currentValue,
            width = width,
            onChange = function(checked)
                if type(config.fontOutline) == "string" or config.fontOutline == nil then
                    config.fontOutline = checked and "OUTLINE" or ""
                else
                    config.fontOutline = checked
                end
                if config.Save then config:Save() end
                if opts.onChanged then opts.onChanged("fontOutline", config.fontOutline) end
            end,
        })
        toggle:SetPoint("TOPLEFT", indent, y)
        y = y - 30
    end

    if not exclude.fontShadow then
        local toggle = W:CreateToggle(parent, "Font Shadow", {
            checked = config.fontShadow or false,
            width = width,
            onChange = MakeOnChange(config, "fontShadow", opts),
        })
        toggle:SetPoint("TOPLEFT", indent, y)
        y = y - 30
    end

    return y - SECTION_BOTTOM_SPACING
end

function SettingsObjects.Visibility(parent, config, y, opts)
    opts = opts or {}
    local indent = opts.indent or 25
    local width = ResolveWidth(parent, opts)
    local exclude = opts.exclude or {}

    local _, newY = W:CreateSectionHeader(parent, "Visibility", indent, y)
    y = newY - CONTROL_SPACING

    if not exclude.displayMode then
        local schema = ConfigSchema.Common.displayMode
        local dropdown = W:CreateDropdown(parent, schema.label, {
            options = DropdownOptionsFromSchema(schema),
            selected = config.displayMode or schema.default,
            width = width,
            onChange = MakeOnChange(config, "displayMode", opts),
        })
        dropdown:SetPoint("TOPLEFT", indent, y)
        y = y - 58
    end

    if not exclude.hideOutOfCombat then
        local toggle = W:CreateToggle(parent, "Hide When Out of Combat", {
            checked = config.hideOutOfCombat or false,
            width = width,
            onChange = MakeOnChange(config, "hideOutOfCombat", opts),
        })
        toggle:SetPoint("TOPLEFT", indent, y)
        y = y - 30
    end

    if not exclude.showOnLogin then
        local toggle = W:CreateToggle(parent, "Show on Login", {
            checked = config.showOnLogin ~= false,
            width = width,
            onChange = MakeOnChange(config, "showOnLogin", opts),
        })
        toggle:SetPoint("TOPLEFT", indent, y)
        y = y - 30
    end

    if not exclude.showTitleBar then
        local toggle = W:CreateToggle(parent, "Show Title Bar", {
            checked = config.showTitleBar ~= false,
            width = width,
            onChange = MakeOnChange(config, "showTitleBar", opts),
        })
        toggle:SetPoint("TOPLEFT", indent, y)
        y = y - 30
    end

    return y - SECTION_BOTTOM_SPACING
end

function SettingsObjects.FrameSettings(parent, config, y, opts)
    opts = opts or {}
    local indent = opts.indent or 25
    local width = ResolveWidth(parent, opts)
    local exclude = opts.exclude or {}

    local _, newY = W:CreateSectionHeader(parent, "Frame Settings", indent, y)
    y = newY - CONTROL_SPACING

    if not exclude.frameWidth then
        local schema = ConfigSchema.Common.frameWidth
        local slider = W:CreateSlider(parent, schema.label, {
            min = schema.min, max = schema.max, step = schema.step,
            value = config.frameWidth or schema.default,
            width = width,
            onChange = MakeOnChange(config, "frameWidth", opts),
        })
        slider:SetPoint("TOPLEFT", indent, y)
        y = y - 52
    end

    if not exclude.bgAlpha then
        local schema = ConfigSchema.Common.bgAlpha
        local slider = W:CreateSlider(parent, schema.label, {
            min = schema.min, max = schema.max, step = schema.step,
            value = config.bgAlpha or schema.default,
            width = width,
            onChange = MakeOnChange(config, "bgAlpha", opts),
        })
        slider:SetPoint("TOPLEFT", indent, y)
        y = y - 52
    end

    if not exclude.bgColor then
        local color = config.bgColor or ConfigSchema.Common.bgColor.default
        local colorPicker = W:CreateColorPicker(parent, "Background Color", {
            r = color.r or 0, g = color.g or 0, b = color.b or 0,
            width = width,
            onChange = function(r, g, b)
                config.bgColor = { r = r, g = g, b = b }
                if config.Save then config:Save() end
                if opts.onChanged then opts.onChanged("bgColor", config.bgColor) end
            end,
        })
        colorPicker:SetPoint("TOPLEFT", indent, y)
        y = y - 30
    end

    if not exclude.lockPosition then
        local toggle = W:CreateToggle(parent, "Lock Frame Position", {
            checked = config.lockPosition or false,
            width = width,
            onChange = MakeOnChange(config, "lockPosition", opts),
        })
        toggle:SetPoint("TOPLEFT", indent, y)
        y = y - 30
    end

    return y - SECTION_BOTTOM_SPACING
end

function SettingsObjects.UpdateInterval(parent, config, y, opts)
    opts = opts or {}
    local indent = opts.indent or 25
    local width = ResolveWidth(parent, opts)

    local _, newY = W:CreateSectionHeader(parent, "Update Settings", indent, y)
    y = newY - CONTROL_SPACING

    local schema = ConfigSchema.Common.updateInterval
    local dropdown = W:CreateDropdown(parent, schema.label, {
        options = DropdownOptionsFromSchema(schema),
        selected = config.updateInterval or schema.default,
        width = width,
        onChange = MakeOnChange(config, "updateInterval", opts),
    })
    dropdown:SetPoint("TOPLEFT", indent, y)
    y = y - 58

    return y - SECTION_BOTTOM_SPACING
end

function SettingsObjects.BuildPage(config, opts)
    opts = opts or {}
    local sections = opts.sections or {}
    local custom = opts.custom or {}

    return function(parentFrame)
        local y = -10
        local pageOpts = {
            indent = opts.indent or 25,
            width = opts.width or 360,
            onChanged = opts.onChanged,
            exclude = opts.exclude or {},
        }

        for _, sectionName in ipairs(sections) do
            local sectionFunc = SettingsObjects[sectionName]
            if sectionFunc then
                y = sectionFunc(parentFrame, config, y, pageOpts)
            end

            for _, c in ipairs(custom) do
                if c.after == sectionName and c.builder then
                    y = c.builder(parentFrame, config, y, pageOpts)
                end
            end
        end

        parentFrame:SetHeight(math.abs(y) + 30)
    end
end

return SettingsObjects
