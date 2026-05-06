local PeaversCommons = _G.PeaversCommons
local W = {}
PeaversCommons.Widgets = W

W.Colors = {
    bgBase      = { 0.10, 0.10, 0.18, 0.95 },
    bgPanel     = { 0.15, 0.15, 0.26, 1 },
    bgNested    = { 0.12, 0.12, 0.21, 1 },
    bgInput     = { 0.08, 0.08, 0.14, 1 },
    border      = { 0.23, 0.23, 0.36, 1 },
    borderHover = { 0.36, 0.36, 0.49, 1 },
    borderFocus = { 0.66, 0.33, 0.97, 1 },
    accent      = { 0.66, 0.33, 0.97, 1 },
    accentHover = { 0.75, 0.52, 0.99, 1 },
    accentLight = { 0.85, 0.70, 0.99, 1 },
    gold        = { 0.98, 0.75, 0.15, 1 },
    success     = { 0.20, 0.78, 0.35, 1 },
    danger      = { 0.90, 0.30, 0.30, 1 },
    text        = { 0.93, 0.93, 0.93, 1 },
    textSec     = { 0.82, 0.83, 0.85, 1 },
    textMuted   = { 0.55, 0.56, 0.60, 1 },
    selected    = { 0.66, 0.33, 0.97, 0.15 },
    highlight   = { 1, 1, 1, 0.04 },
}

local C = W.Colors

local FLAT_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}

local FLAT_BACKDROP_THICK = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 2,
}

function W:CreatePanel(parent, opts)
    opts = opts or {}
    local frame = CreateFrame("Frame", opts.name, parent, "BackdropTemplate")
    frame:SetBackdrop(FLAT_BACKDROP)
    frame:SetBackdropColor(unpack(opts.bg or C.bgPanel))
    frame:SetBackdropBorderColor(unpack(opts.border or C.border))
    if opts.width and opts.height then
        frame:SetSize(opts.width, opts.height)
    end
    return frame
end

function W:CreateSectionHeader(parent, text, x, y)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", x, y)
    container:SetSize(400, 22)

    local label = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("BOTTOMLEFT", 0, 4)
    label:SetText(text)
    label:SetTextColor(unpack(C.gold))
    label:SetFont(label:GetFont(), 11, "")

    local line = container:CreateTexture(nil, "ARTWORK")
    line:SetPoint("BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", 0, 0)
    line:SetHeight(1)
    line:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.6)

    return container, y - 24
end

function W:CreateCollapsibleSection(parent, title, opts)
    opts = opts or {}
    local defaultOpen = opts.defaultOpen ~= false

    local frame = CreateFrame("Frame", opts.name, parent, "BackdropTemplate")
    frame:SetBackdrop(FLAT_BACKDROP)
    frame:SetBackdropColor(unpack(C.bgPanel))
    frame:SetBackdropBorderColor(unpack(C.border))

    local header = CreateFrame("Button", nil, frame)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(32)

    local headerBg = header:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    headerBg:SetColorTexture(C.bgNested[1], C.bgNested[2], C.bgNested[3], 1)

    local arrow = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    arrow:SetPoint("LEFT", 10, 0)
    arrow:SetTextColor(C.accent[1], C.accent[2], C.accent[3])

    local titleText = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    titleText:SetPoint("LEFT", arrow, "RIGHT", 6, 0)
    titleText:SetText(title)
    titleText:SetTextColor(C.accentLight[1], C.accentLight[2], C.accentLight[3])

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", 0, -32)
    content:SetPoint("TOPRIGHT", 0, -32)

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", 0, -32)
    divider:SetPoint("TOPRIGHT", 0, -32)
    divider:SetHeight(1)
    divider:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)

    local isOpen = defaultOpen

    local function UpdateState()
        arrow:SetText(isOpen and "v" or ">")
        if isOpen then
            content:Show()
            divider:Show()
        else
            content:Hide()
            divider:Hide()
        end
    end

    header:SetScript("OnClick", function()
        isOpen = not isOpen
        UpdateState()
        if opts.onToggle then opts.onToggle(isOpen) end
    end)

    header:SetScript("OnEnter", function()
        headerBg:SetColorTexture(C.highlight[1], C.highlight[2], C.highlight[3], 0.08)
    end)
    header:SetScript("OnLeave", function()
        headerBg:SetColorTexture(C.bgNested[1], C.bgNested[2], C.bgNested[3], 1)
    end)

    UpdateState()

    frame.header = header
    frame.content = content
    frame.SetOpen = function(self, open)
        isOpen = open
        UpdateState()
    end

    return frame
end

function W:CreateButton(parent, text, opts)
    opts = opts or {}
    local variant = opts.variant or "secondary"
    local width = opts.width or 120
    local height = opts.height or 26

    local btn = CreateFrame("Button", opts.name, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetBackdrop(FLAT_BACKDROP)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", 0, 0)
    label:SetText(text)

    local colors = {
        primary   = { bg = C.accent, hover = C.accentHover, text = { 1, 1, 1 } },
        secondary = { bg = C.bgNested, hover = C.border, text = C.text },
        danger    = { bg = { 0.35, 0.12, 0.12, 1 }, hover = C.danger, text = { 1, 0.8, 0.8 } },
        ghost     = { bg = { 0, 0, 0, 0 }, hover = C.highlight, text = C.textSec },
    }

    local c = colors[variant] or colors.secondary

    local function SetNormal()
        btn:SetBackdropColor(unpack(c.bg))
        btn:SetBackdropBorderColor(unpack(C.border))
        label:SetTextColor(c.text[1], c.text[2], c.text[3])
    end

    btn:SetScript("OnEnter", function()
        btn:SetBackdropColor(c.hover[1], c.hover[2], c.hover[3], c.hover[4] or 1)
        btn:SetBackdropBorderColor(C.borderHover[1], C.borderHover[2], C.borderHover[3], 1)
    end)
    btn:SetScript("OnLeave", SetNormal)
    btn:SetScript("OnMouseDown", function() label:SetPoint("CENTER", 0, -1) end)
    btn:SetScript("OnMouseUp", function() label:SetPoint("CENTER", 0, 0) end)

    if opts.onClick then
        btn:SetScript("OnClick", opts.onClick)
    end

    SetNormal()

    btn.label = label
    btn.SetLabel = function(self, newText) label:SetText(newText) end

    return btn
end

function W:CreateCheckbox(parent, labelText, opts)
    opts = opts or {}

    local frame = CreateFrame("Frame", opts.name, parent)
    frame:SetSize(opts.width or 300, 22)

    local btn = CreateFrame("Button", nil, frame)
    btn:SetAllPoints()

    local box = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    box:SetSize(16, 16)
    box:SetPoint("LEFT", 0, 0)
    box:SetBackdrop(FLAT_BACKDROP)
    box:SetBackdropColor(unpack(C.bgInput))
    box:SetBackdropBorderColor(unpack(C.border))

    local check = box:CreateTexture(nil, "OVERLAY")
    check:SetSize(12, 12)
    check:SetPoint("CENTER", 0, 0)
    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
    check:Hide()

    local label = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", box, "RIGHT", 8, 0)
    label:SetText(labelText)
    label:SetTextColor(unpack(C.text))

    if opts.description then
        local desc = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        desc:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
        desc:SetText(opts.description)
        desc:SetTextColor(unpack(C.textMuted))
        frame:SetHeight(36)
    end

    local checked = opts.checked or false

    local function UpdateState()
        if checked then
            check:Show()
            box:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
        else
            check:Hide()
            box:SetBackdropBorderColor(unpack(C.border))
        end
    end

    btn:SetScript("OnClick", function()
        checked = not checked
        UpdateState()
        if opts.onChange then opts.onChange(checked) end
    end)

    btn:SetScript("OnEnter", function()
        if not checked then box:SetBackdropBorderColor(unpack(C.borderHover)) end
        label:SetTextColor(C.accentLight[1], C.accentLight[2], C.accentLight[3])
    end)
    btn:SetScript("OnLeave", function()
        if not checked then box:SetBackdropBorderColor(unpack(C.border)) end
        label:SetTextColor(unpack(C.text))
    end)

    UpdateState()

    frame.SetChecked = function(self, value) checked = value; UpdateState() end
    frame.GetChecked = function(self) return checked end

    return frame
end

function W:CreateToggle(parent, labelText, opts)
    opts = opts or {}

    local frame = CreateFrame("Frame", opts.name, parent)
    frame:SetSize(opts.width or 300, 22)

    local btn = CreateFrame("Button", nil, frame)
    btn:SetAllPoints()

    local label = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", 0, 0)
    label:SetText(labelText)
    label:SetTextColor(unpack(C.text))

    local track = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    track:SetSize(34, 16)
    track:SetPoint("RIGHT", 0, 0)
    track:SetBackdrop(FLAT_BACKDROP)
    track:SetBackdropColor(unpack(C.bgInput))
    track:SetBackdropBorderColor(unpack(C.border))

    local thumb = track:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(12, 12)
    thumb:SetTexture("Interface\\Buttons\\WHITE8x8")

    local toggled = opts.checked or false

    local function UpdateState()
        if toggled then
            thumb:ClearAllPoints()
            thumb:SetPoint("RIGHT", track, "RIGHT", -2, 0)
            thumb:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
            track:SetBackdropColor(C.accent[1] * 0.3, C.accent[2] * 0.3, C.accent[3] * 0.3, 1)
            track:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
        else
            thumb:ClearAllPoints()
            thumb:SetPoint("LEFT", track, "LEFT", 2, 0)
            thumb:SetVertexColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
            track:SetBackdropColor(unpack(C.bgInput))
            track:SetBackdropBorderColor(unpack(C.border))
        end
    end

    btn:SetScript("OnClick", function()
        toggled = not toggled
        UpdateState()
        if opts.onChange then opts.onChange(toggled) end
    end)

    btn:SetScript("OnEnter", function()
        label:SetTextColor(C.accentLight[1], C.accentLight[2], C.accentLight[3])
        if not toggled then track:SetBackdropBorderColor(unpack(C.borderHover)) end
    end)
    btn:SetScript("OnLeave", function()
        label:SetTextColor(unpack(C.text))
        if not toggled then track:SetBackdropBorderColor(unpack(C.border)) end
    end)

    UpdateState()

    frame.SetChecked = function(self, value) toggled = value; UpdateState() end
    frame.GetChecked = function(self) return toggled end

    return frame
end

function W:CreateSlider(parent, labelText, opts)
    opts = opts or {}
    local min = opts.min or 0
    local max = opts.max or 100
    local step = opts.step or 1
    local value = opts.value or min
    local width = opts.width or 300

    local frame = CreateFrame("Frame", opts.name, parent)
    frame:SetSize(width, 44)

    local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(labelText)
    label:SetTextColor(unpack(C.text))

    local valueText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    valueText:SetPoint("TOPRIGHT", 0, 0)
    valueText:SetTextColor(C.accentLight[1], C.accentLight[2], C.accentLight[3])

    local function FormatValue(v)
        if opts.format then return opts.format(v) end
        if min == 0 and max == 1 then return math.floor(v * 100) .. "%" end
        if step < 1 then return string.format("%.2f", v) end
        return tostring(math.floor(v + 0.5))
    end

    valueText:SetText(FormatValue(value))

    local badgeBg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    badgeBg:SetBackdrop(FLAT_BACKDROP)
    badgeBg:SetBackdropColor(unpack(C.bgInput))
    badgeBg:SetBackdropBorderColor(unpack(C.border))
    badgeBg:SetHeight(16)
    badgeBg:SetFrameLevel(frame:GetFrameLevel())
    badgeBg:EnableMouse(false)
    valueText:SetParent(badgeBg)
    valueText:ClearAllPoints()
    valueText:SetPoint("CENTER", badgeBg, "CENTER", 0, 0)
    badgeBg:ClearAllPoints()
    badgeBg:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 2)
    badgeBg:SetWidth(math.max(40, valueText:GetStringWidth() + 12))

    local slider = CreateFrame("Slider", nil, frame, "BackdropTemplate")
    slider:SetPoint("TOPLEFT", 0, -20)
    slider:SetPoint("TOPRIGHT", 0, -20)
    slider:SetHeight(18)
    slider:SetOrientation("HORIZONTAL")
    slider:EnableMouse(true)
    slider:SetBackdrop(FLAT_BACKDROP)
    slider:SetBackdropColor(unpack(C.bgInput))
    slider:SetBackdropBorderColor(unpack(C.border))
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    slider:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    local thumbTex = slider:GetThumbTexture()
    thumbTex:SetSize(14, 16)
    thumbTex:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])

    slider:SetValue(value)

    local fill = slider:CreateTexture(nil, "BORDER")
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMLEFT", 1, 1)
    fill:SetTexture("Interface\\Buttons\\WHITE8x8")
    fill:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.3)
    fill:SetWidth(1)

    local function UpdateFill(v)
        if max == min then return end
        local pct = (v - min) / (max - min)
        local sliderWidth = slider:GetWidth()
        if sliderWidth and sliderWidth > 2 then
            fill:SetWidth(math.max(1, pct * (sliderWidth - 2)))
        end
    end

    slider:SetScript("OnValueChanged", function(self, v)
        local rounded
        if step < 1 then
            local factor = 1 / step
            rounded = math.floor(v * factor + 0.5) / factor
        else
            rounded = math.floor(v + 0.5)
        end
        valueText:SetText(FormatValue(rounded))
        badgeBg:SetWidth(math.max(40, valueText:GetStringWidth() + 12))
        UpdateFill(rounded)
        if opts.onChange then opts.onChange(rounded) end
    end)

    slider:SetScript("OnSizeChanged", function(self, w)
        if w and w > 0 then
            UpdateFill(self:GetValue())
        end
    end)

    slider:SetScript("OnEnter", function()
        slider:SetBackdropBorderColor(unpack(C.borderHover))
        thumbTex:SetVertexColor(C.accentHover[1], C.accentHover[2], C.accentHover[3])
    end)
    slider:SetScript("OnLeave", function()
        slider:SetBackdropBorderColor(unpack(C.border))
        thumbTex:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
    end)

    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", function(self, delta)
        self:SetValue(self:GetValue() + (delta * step))
    end)

    frame.slider = slider
    frame.SetValue = function(self, v) slider:SetValue(v) end
    frame.GetValue = function(self) return slider:GetValue() end

    return frame
end

function W:CreateDropdown(parent, labelText, opts)
    opts = opts or {}
    local options = opts.options or {}
    local selected = opts.selected
    local width = opts.width or 200

    local frame = CreateFrame("Frame", opts.name, parent)
    frame:SetSize(width, 50)

    if labelText and labelText ~= "" then
        local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("TOPLEFT", 0, 0)
        label:SetText(labelText)
        label:SetTextColor(unpack(C.text))
    end

    local btn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    btn:SetPoint("TOPLEFT", 0, labelText and -18 or 0)
    btn:SetSize(width, 26)
    btn:SetBackdrop(FLAT_BACKDROP)
    btn:SetBackdropColor(unpack(C.bgInput))
    btn:SetBackdropBorderColor(unpack(C.border))

    local selectedText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    selectedText:SetPoint("LEFT", 10, 0)
    selectedText:SetPoint("RIGHT", -24, 0)
    selectedText:SetJustifyH("LEFT")
    selectedText:SetTextColor(unpack(C.text))

    local arrowText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrowText:SetPoint("RIGHT", -8, 0)
    arrowText:SetText("v")
    arrowText:SetTextColor(unpack(C.textMuted))

    local function GetDisplayText(value)
        for _, opt in ipairs(options) do
            if type(opt) == "table" then
                if opt.value == value then return opt.label end
            end
        end
        return tostring(value or "Select...")
    end

    selectedText:SetText(GetDisplayText(selected))

    local menuFrame = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    menuFrame:SetBackdrop(FLAT_BACKDROP)
    menuFrame:SetBackdropColor(C.bgPanel[1], C.bgPanel[2], C.bgPanel[3], 0.98)
    menuFrame:SetBackdropBorderColor(unpack(C.border))
    menuFrame:SetFrameStrata("TOOLTIP")
    menuFrame:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    menuFrame:SetPoint("TOPRIGHT", btn, "BOTTOMRIGHT", 0, -2)
    menuFrame:Hide()

    local menuButtons = {}

    local function BuildMenu()
        for _, mb in ipairs(menuButtons) do mb:Hide() end
        menuButtons = {}

        local itemHeight = 24
        local yOff = -2
        for _, opt in ipairs(options) do
            local value, display
            if type(opt) == "table" then
                value = opt.value
                display = opt.label
            else
                value = opt
                display = tostring(opt)
            end

            local item = CreateFrame("Button", nil, menuFrame)
            item:SetPoint("TOPLEFT", 2, yOff)
            item:SetPoint("TOPRIGHT", -2, yOff)
            item:SetHeight(itemHeight)

            local itemBg = item:CreateTexture(nil, "BACKGROUND")
            itemBg:SetAllPoints()
            itemBg:SetColorTexture(0, 0, 0, 0)

            local itemLabel = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            itemLabel:SetPoint("LEFT", 8, 0)
            itemLabel:SetText(display)
            itemLabel:SetTextColor(value == selected and C.accent[1] or C.text[1], value == selected and C.accent[2] or C.text[2], value == selected and C.accent[3] or C.text[3])

            item:SetScript("OnEnter", function() itemBg:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.15) end)
            item:SetScript("OnLeave", function() itemBg:SetColorTexture(0, 0, 0, 0) end)
            item:SetScript("OnClick", function()
                selected = value
                selectedText:SetText(display)
                menuFrame:Hide()
                if opts.onChange then opts.onChange(value) end
            end)

            table.insert(menuButtons, item)
            yOff = yOff - itemHeight
        end

        menuFrame:SetHeight(math.abs(yOff) + 4)
    end

    btn:SetScript("OnClick", function()
        if menuFrame:IsShown() then menuFrame:Hide() else BuildMenu(); menuFrame:Show() end
    end)
    btn:SetScript("OnEnter", function() btn:SetBackdropBorderColor(unpack(C.borderHover)) end)
    btn:SetScript("OnLeave", function()
        if not menuFrame:IsShown() then btn:SetBackdropBorderColor(unpack(C.border)) end
    end)

    menuFrame:SetScript("OnShow", function() arrowText:SetText("^") end)
    menuFrame:SetScript("OnHide", function() arrowText:SetText("v"); btn:SetBackdropBorderColor(unpack(C.border)) end)

    menuFrame:SetScript("OnUpdate", function()
        if not menuFrame:IsMouseOver() and not btn:IsMouseOver() then
            if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
                menuFrame:Hide()
            end
        end
    end)

    frame.SetSelected = function(self, value) selected = value; selectedText:SetText(GetDisplayText(value)) end
    frame.GetSelected = function(self) return selected end

    return frame
end

function W:CreateInput(parent, labelText, opts)
    opts = opts or {}
    local width = opts.width or 240

    local frame = CreateFrame("Frame", opts.name, parent)
    frame:SetSize(width, labelText and 44 or 28)

    if labelText and labelText ~= "" then
        local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("TOPLEFT", 0, 0)
        label:SetText(labelText)
        label:SetTextColor(unpack(C.text))
    end

    local container = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    container:SetPoint("TOPLEFT", 0, labelText and -18 or 0)
    container:SetSize(width, 26)
    container:SetBackdrop(FLAT_BACKDROP)
    container:SetBackdropColor(unpack(C.bgInput))
    container:SetBackdropBorderColor(unpack(C.border))

    local editBox = CreateFrame("EditBox", nil, container)
    editBox:SetPoint("TOPLEFT", 8, -5)
    editBox:SetPoint("BOTTOMRIGHT", -8, 5)
    editBox:SetFontObject("GameFontHighlight")
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(opts.maxLetters or 100)

    if opts.placeholder then
        local placeholder = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        placeholder:SetPoint("LEFT", 8, 0)
        placeholder:SetText(opts.placeholder)
        placeholder:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3], 0.6)

        editBox:SetScript("OnTextChanged", function(self)
            local text = self:GetText()
            placeholder[text == "" and "Show" or "Hide"](placeholder)
            if opts.onChange then opts.onChange(text) end
        end)
    else
        editBox:SetScript("OnTextChanged", function(self)
            if opts.onChange then opts.onChange(self:GetText()) end
        end)
    end

    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    editBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if opts.onSubmit then opts.onSubmit(self:GetText()) end
    end)
    editBox:SetScript("OnEditFocusGained", function() container:SetBackdropBorderColor(unpack(C.borderFocus)) end)
    editBox:SetScript("OnEditFocusLost", function() container:SetBackdropBorderColor(unpack(C.border)) end)
    container:SetScript("OnMouseDown", function() editBox:SetFocus() end)

    if opts.text then editBox:SetText(opts.text) end

    frame.editBox = editBox
    frame.GetText = function(self) return editBox:GetText() end
    frame.SetText = function(self, t) editBox:SetText(t) end
    frame.ClearFocus = function(self) editBox:ClearFocus() end

    return frame
end

function W:CreateColorPicker(parent, labelText, opts)
    opts = opts or {}
    local r, g, b = opts.r or 1, opts.g or 1, opts.b or 1

    local frame = CreateFrame("Frame", opts.name, parent)
    frame:SetSize(opts.width or 300, 22)

    local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", 0, 0)
    label:SetText(labelText)
    label:SetTextColor(unpack(C.text))

    local swatch = CreateFrame("Button", nil, frame, "BackdropTemplate")
    swatch:SetSize(22, 22)
    swatch:SetPoint("RIGHT", 0, 0)
    swatch:SetBackdrop(FLAT_BACKDROP_THICK)
    swatch:SetBackdropColor(r, g, b, 1)
    swatch:SetBackdropBorderColor(unpack(C.border))

    local hexText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hexText:SetPoint("RIGHT", swatch, "LEFT", -8, 0)
    hexText:SetTextColor(unpack(C.textMuted))

    local function UpdateHex()
        hexText:SetText(string.format("#%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)))
    end
    UpdateHex()

    swatch:SetScript("OnClick", function()
        local function ColorCallback(restore)
            if restore then
                r, g, b = unpack(restore)
            else
                r, g, b = ColorPickerFrame.Content.ColorPicker:GetColorRGB()
            end
            swatch:SetBackdropColor(r, g, b, 1)
            UpdateHex()
            if opts.onChange then opts.onChange(r, g, b) end
        end

        ColorPickerFrame.func = ColorCallback
        ColorPickerFrame.swatchFunc = ColorCallback
        ColorPickerFrame.cancelFunc = ColorCallback
        ColorPickerFrame.opacityFunc = nil
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = { r, g, b }
        ColorPickerFrame.Content.ColorPicker:SetColorRGB(r, g, b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end)

    swatch:SetScript("OnEnter", function() swatch:SetBackdropBorderColor(unpack(C.borderHover)) end)
    swatch:SetScript("OnLeave", function() swatch:SetBackdropBorderColor(unpack(C.border)) end)

    frame.SetColor = function(self, newR, newG, newB) r, g, b = newR, newG, newB; swatch:SetBackdropColor(r, g, b, 1); UpdateHex() end
    frame.GetColor = function(self) return r, g, b end

    return frame
end

function W:CreateSeparator(parent, x, y, width)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", x, y)
    line:SetSize(width or 400, 1)
    line:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.5)
    return line, y - 12
end

function W:CreateLabel(parent, text, opts)
    opts = opts or {}
    local label = parent:CreateFontString(nil, "ARTWORK", opts.font or "GameFontNormal")
    label:SetText(text)
    local color = opts.color or C.text
    label:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    if opts.size then
        label:SetFont(label:GetFont(), opts.size, opts.outline or "")
    end
    return label
end

function W:CreateTabBar(parent, tabs, opts)
    opts = opts or {}
    local height = opts.height or 30

    local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bar:SetHeight(height)
    bar:SetBackdrop(FLAT_BACKDROP)
    bar:SetBackdropColor(C.bgNested[1], C.bgNested[2], C.bgNested[3], 1)
    bar:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0)

    local bottomBorder = bar:CreateTexture(nil, "ARTWORK")
    bottomBorder:SetPoint("BOTTOMLEFT", 0, 0)
    bottomBorder:SetPoint("BOTTOMRIGHT", 0, 0)
    bottomBorder:SetHeight(1)
    bottomBorder:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)

    local tabButtons = {}
    local selectedKey = tabs[1] and tabs[1].key

    local function UpdateTabs()
        for _, tb in ipairs(tabButtons) do
            if tb.key == selectedKey then
                tb.label:SetTextColor(C.accentLight[1], C.accentLight[2], C.accentLight[3])
                tb.indicator:Show()
            else
                tb.label:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
                tb.indicator:Hide()
            end
        end
    end

    local xOff = 8
    for _, tab in ipairs(tabs) do
        local btn = CreateFrame("Button", nil, bar)
        btn:SetPoint("TOPLEFT", xOff, 0)
        btn:SetHeight(height)

        local label = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("CENTER", 0, 1)
        label:SetText(tab.label)
        label:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

        local textWidth = label:GetStringWidth()
        btn:SetWidth(math.max(textWidth + 20, 60))

        local indicator = btn:CreateTexture(nil, "OVERLAY")
        indicator:SetPoint("BOTTOMLEFT", 4, 0)
        indicator:SetPoint("BOTTOMRIGHT", -4, 0)
        indicator:SetHeight(2)
        indicator:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
        indicator:Hide()

        btn:SetScript("OnClick", function()
            selectedKey = tab.key
            UpdateTabs()
            if opts.onChange then opts.onChange(tab.key) end
        end)

        btn:SetScript("OnEnter", function()
            if tab.key ~= selectedKey then
                label:SetTextColor(C.textSec[1], C.textSec[2], C.textSec[3])
            end
        end)

        btn:SetScript("OnLeave", function()
            if tab.key ~= selectedKey then
                label:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
            end
        end)

        btn.key = tab.key
        btn.label = label
        btn.indicator = indicator
        table.insert(tabButtons, btn)

        xOff = xOff + btn:GetWidth() + 2
    end

    UpdateTabs()

    bar.Select = function(self, key)
        selectedKey = key
        UpdateTabs()
        if opts.onChange then opts.onChange(key) end
    end
    bar.GetSelected = function(self) return selectedKey end

    return bar
end

return W
