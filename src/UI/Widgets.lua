local PeaversCommons = _G.PeaversCommons
local W = {}
PeaversCommons.Widgets = W

local Theme = PeaversCommons.Theme

-- Alias, not a copy: consumers capture `local C = W.Colors` at load time and hold a
-- reference to this exact table. See the table-identity note in Theme.lua.
W.Colors = Theme.Colors

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

--- Create a section header — the "eyebrow" motif from peavers.io: a small
--- uppercase indigo label over a hairline rule.
---
--- The text is uppercased here rather than at the call site, matching CSS
--- `text-transform: uppercase`; most consumers pass Title Case.
---
--- By default the rule spans the full width of the parent (the site's full-bleed
--- rule), mirroring the left inset on the right. Multi-column callers should pass
--- `opts.width` for a fixed width, or `opts.rightInset` to bleed to a different
--- right edge than their own left inset.
--- @param parent Frame
--- @param text string
--- @param x number
--- @param y number
--- @param opts? table { width = number, rightInset = number }
--- @return Frame container, number nextY
function W:CreateSectionHeader(parent, text, x, y, opts)
    opts = opts or {}

    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", x, y)
    if opts.width then
        container:SetSize(opts.width, 22)
    else
        container:SetPoint("TOPRIGHT", -(opts.rightInset or x), y)
        container:SetHeight(22)
    end

    -- Tracked, uppercase, mono — the site's eyebrow. Falls back to a plain
    -- FontString when the bundled font is unavailable (non-Latin locale, or the
    -- client has not been restarted since the font was added).
    local label
    if Theme.UsesCustomFonts() then
        label = Theme.TrackedLabel(container, text, 10, C.eyebrow)
        label:SetPoint("BOTTOMLEFT", 0, 4)
    else
        label = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("BOTTOMLEFT", 0, 4)
        label:SetText(tostring(text):upper())
        label:SetTextColor(unpack(C.eyebrow))
        label:SetFont(label:GetFont() --[[@as string]], 10, "")
    end

    local line = container:CreateTexture(nil, "ARTWORK")
    line:SetPoint("BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", 0, 0)
    line:SetHeight(1)
    line:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)

    container.label = label
    return container, y - 24
end

function W.CreateCollapsibleSection(_, parent, title, opts)
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
    headerBg:SetColorTexture(0, 0, 0, 0)

    local arrow = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    arrow:SetPoint("LEFT", 10, 0)
    arrow:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

    local titleText = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    titleText:SetPoint("LEFT", arrow, "RIGHT", 6, 0)
    titleText:SetText(title)
    titleText:SetTextColor(unpack(C.text))

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

local TRANSPARENT = { 0, 0, 0, 0 }

--- Create a themed button.
--- Tiers follow peavers.io: `primary` is a near-white fill with dark text (the sole
--- high-contrast element in the design), `secondary` is a hairline outline that
--- brightens its *border* on hover, and `ghost` is text-only. `danger` is an
--- extension — the site has no destructive action.
--- @param parent Frame
--- @param text string
--- @param opts? table { variant|style, width, height, onClick, name }
function W.CreateButton(_, parent, text, opts)
    opts = opts or {}
    -- `style` is accepted as an alias for `variant`: several addons pass it, and
    -- silently fell through to the secondary default before this.
    local variant = opts.variant or opts.style or "secondary"
    local width = opts.width or 120
    local height = opts.height or 26

    local btn = CreateFrame("Button", opts.name, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetBackdrop(FLAT_BACKDROP)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", 0, 0)
    label:SetText(text)

    -- bg/hover are fills; border/borderHover are the hairline. Keeping them
    -- separate is what lets secondary and ghost hover without a fill change.
    local colors = {
        -- Solid indigo rather than the site's near-white pill. On peavers.io the
        -- white pill is a single hero CTA surrounded by whitespace; in a dense
        -- settings window it reads as a glaring block next to its neighbours.
        -- Indigo keeps the "this is the primary action" weight and stays on brand
        -- with the eyebrows and active dots.
        primary = {
            bg = C.accent, hover = C.accentHover,
            border = C.accent, borderHover = C.accentHover,
            text = { 1, 1, 1 }, textHover = { 1, 1, 1 },
        },
        secondary = {
            bg = TRANSPARENT, hover = TRANSPARENT,
            border = C.border, borderHover = C.textMuted,
            text = C.text, textHover = C.text,
        },
        ghost = {
            bg = TRANSPARENT, hover = TRANSPARENT,
            border = TRANSPARENT, borderHover = TRANSPARENT,
            text = C.textSec, textHover = C.text,
        },
        danger = {
            bg = TRANSPARENT, hover = { C.danger[1], C.danger[2], C.danger[3], 0.10 },
            border = { C.danger[1], C.danger[2], C.danger[3], 0.50 }, borderHover = C.danger,
            text = C.danger, textHover = C.danger,
        },
    }

    local c = colors[variant] or colors.secondary

    local function SetNormal()
        btn:SetBackdropColor(unpack(c.bg))
        btn:SetBackdropBorderColor(unpack(c.border))
        label:SetTextColor(c.text[1], c.text[2], c.text[3])
    end

    btn:SetScript("OnEnter", function()
        btn:SetBackdropColor(unpack(c.hover))
        btn:SetBackdropBorderColor(unpack(c.borderHover))
        label:SetTextColor(c.textHover[1], c.textHover[2], c.textHover[3])
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

function W.CreateCheckbox(_, parent, labelText, opts)
    opts = opts or {}

    local frame = CreateFrame("Frame", opts.name, parent)
    frame:SetSize(opts.width or 300, 22)

    local btn = CreateFrame("Button", nil, frame)
    btn:SetAllPoints()

    local box = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    box:SetSize(16, 16)
    box:SetPoint("LEFT", 0, 0)

    -- Rounded fill + border as sliced textures, matching the legacy FrameUtils
    -- checkbox exactly so both code paths render the same control. Falls back to
    -- the flat backdrop if the art is unavailable.
    local boxFill = box:CreateTexture(nil, "BACKGROUND")
    boxFill:SetAllPoints(box --[[@as Frame]])
    local boxBorder = box:CreateTexture(nil, "BORDER")
    boxBorder:SetAllPoints(box --[[@as Frame]])
    local boxRounded = true

    -- Filled indigo box with a flat white check. Blizzard's UI-CheckBox-Check
    -- has bevel, inner shading and a glow baked into the art, which goes muddy
    -- when tinted onto a flat fill — hence our own mask.
    local check = box:CreateTexture(nil, "OVERLAY")
    check:SetSize(12, 12)
    check:SetPoint("CENTER", 0, 0)
    check:SetTexture(Theme.Textures.check)
    if not check:GetTexture() then
        check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    end
    check:SetVertexColor(1, 1, 1)
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
        local fillColor = checked and C.accent or C.bgNested
        local edgeColor = checked and C.accent or C.border

        if boxRounded then
            boxRounded = Theme.Slice(boxFill, "roundedFill4", fillColor)
                and Theme.Slice(boxBorder, "roundedBorder4", edgeColor)
        end
        if not boxRounded then
            box:SetBackdrop(FLAT_BACKDROP)
            box:SetBackdropColor(unpack(fillColor))
            box:SetBackdropBorderColor(unpack(edgeColor))
        end

        check:SetShown(checked and true or false)
    end

    btn:SetScript("OnClick", function()
        checked = not checked
        UpdateState()
        if opts.onChange then opts.onChange(checked) end
    end)

    -- Hover tints the border texture, not the backdrop: in the rounded path the
    -- box has no backdrop, so SetBackdropBorderColor would silently do nothing.
    local function SetEdge(color)
        if checked then return end
        if boxRounded then
            boxBorder:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
        else
            box:SetBackdropBorderColor(unpack(color))
        end
    end

    btn:SetScript("OnEnter", function()
        SetEdge(C.borderHover)
        label:SetTextColor(unpack(C.text))
    end)
    btn:SetScript("OnLeave", function()
        SetEdge(C.border)
        label:SetTextColor(unpack(C.text))
    end)

    UpdateState()

    frame.SetChecked = function(self, value) checked = value; UpdateState() end
    frame.GetChecked = function(self) return checked end
    -- Test seam: lets a harness invoke the same handler a click would fire.
    frame.__isPeaversCheckbox = true
    frame.__onChange = function() if opts.onChange then opts.onChange(checked) end end

    return frame
end

function W.CreateToggle(_, parent, labelText, opts)
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
        thumb:ClearAllPoints()
        if toggled then
            thumb:SetPoint("RIGHT", track, "RIGHT", -2, 0)
            -- White thumb on a solid accent track. The old code drew an accent
            -- thumb on an accent-tinted track, which was nearly invisible.
            thumb:SetVertexColor(1, 1, 1)
            track:SetBackdropColor(unpack(C.accent))
            track:SetBackdropBorderColor(unpack(C.accent))
        else
            thumb:SetPoint("LEFT", track, "LEFT", 2, 0)
            thumb:SetVertexColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
            -- Filled groove rather than a transparent track, so the off state
            -- reads as a switch instead of a floating square.
            track:SetBackdropColor(unpack(C.bgNested))
            track:SetBackdropBorderColor(unpack(C.border))
        end
    end

    btn:SetScript("OnClick", function()
        toggled = not toggled
        UpdateState()
        if opts.onChange then opts.onChange(toggled) end
    end)

    btn:SetScript("OnEnter", function()
        label:SetTextColor(unpack(C.text))
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

function W.CreateSlider(_, parent, labelText, opts)
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
    valueText:SetTextColor(unpack(C.accent))

    local function FormatValue(v)
        if opts.format then return opts.format(v) end
        if min == 0 and max == 1 then return math.floor(v * 100) .. "%" end
        if step < 1 then return string.format("%.2f", v) end
        return tostring(math.floor(v + 0.5))
    end

    valueText:SetText(FormatValue(value))

    -- Badge idiom from the site: a primary/8 fill with no border and mono-ish
    -- accent text, rather than a bordered input well.
    local badgeBg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    badgeBg:SetBackdrop(FLAT_BACKDROP)
    badgeBg:SetBackdropColor(unpack(C.selected))
    badgeBg:SetBackdropBorderColor(0, 0, 0, 0)
    badgeBg:SetHeight(16)
    badgeBg:SetFrameLevel(frame:GetFrameLevel())
    badgeBg:EnableMouse(false)
    valueText:SetParent(badgeBg --[[@as Frame]])
    valueText:ClearAllPoints()
    valueText:SetPoint("CENTER", badgeBg, "CENTER", 0, 0)
    badgeBg:ClearAllPoints()
    badgeBg:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 2)
    badgeBg:SetWidth(math.max(40, valueText:GetStringWidth() + 12))

    -- Thin 6px track with a round-ish thumb, matching the site's control weight.
    -- Kept vertically centred in the same 18px band the old track occupied so
    -- callers' row heights are unaffected.
    local TRACK_H = 6
    local slider = CreateFrame("Slider", nil, frame, "BackdropTemplate")
    slider:SetPoint("TOPLEFT", 0, -26)
    slider:SetPoint("TOPRIGHT", 0, -26)
    slider:SetHeight(TRACK_H)
    slider:SetOrientation("HORIZONTAL")
    slider:EnableMouse(true)
    slider:SetBackdrop(FLAT_BACKDROP)
    slider:SetBackdropColor(unpack(C.bgNested))
    slider:SetBackdropBorderColor(unpack(C.border))
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    slider:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    local thumbTex = slider:GetThumbTexture()
    thumbTex:SetSize(12, 12)
    thumbTex:SetVertexColor(unpack(C.accent))

    slider:SetValue(value)

    local fill = slider:CreateTexture(nil, "BORDER")
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMLEFT", 1, 1)
    fill:SetTexture("Interface\\Buttons\\WHITE8x8")
    -- Solid rather than the old 30% wash: the track is thin enough to carry it.
    fill:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
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

function W.CreateDropdown(_, parent, labelText, opts)
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

function W.CreateInput(_, parent, labelText, opts)
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

function W.CreateColorPicker(_, parent, labelText, opts)
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
        local function applyColor(newR, newG, newB)
            r, g, b = newR, newG, newB
            swatch:SetBackdropColor(r, g, b, 1)
            UpdateHex()
            if opts.onChange then opts.onChange(r, g, b) end
        end

        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b,
            hasOpacity = false,
            previousValues = { r = r, g = g, b = b },
            swatchFunc = function() applyColor(ColorPickerFrame:GetColorRGB()) end,
            cancelFunc = function(previous) applyColor(previous.r, previous.g, previous.b) end,
        })
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
    -- Full strength: `border` is already the hairline value composited on paper.
    line:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
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

function W.CreateTabBar(_, parent, tabs, opts)
    opts = opts or {}
    local height = opts.height or 30

    local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bar:SetHeight(height)
    bar:SetBackdrop(FLAT_BACKDROP)
    -- Transparent bar on paper; only the bottom hairline separates it.
    bar:SetBackdropColor(0, 0, 0, 0)
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
                tb.label:SetTextColor(unpack(C.text))
                tb.indicator:Show()
            else
                tb.label:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
                tb.indicator:Hide()
            end
        end
    end

    local DOT = 5

    local xOff = 8
    for _, tab in ipairs(tabs) do
        local btn = CreateFrame("Button", nil, bar)
        btn:SetPoint("TOPLEFT", xOff, 0)
        btn:SetHeight(height)

        local label = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        -- Offset right to leave room for the active dot, so the label does not
        -- shift horizontally when selection changes.
        label:SetPoint("CENTER", (DOT + 4) / 2, 1)
        label:SetText(tab.label)
        label:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

        local textWidth = label:GetStringWidth()
        btn:SetWidth(math.max(textWidth + 20 + DOT + 4, 60))

        -- Active marker: an indigo dot to the left of the label, replacing the
        -- old 2px underline.
        local indicator = btn:CreateTexture(nil, "OVERLAY")
        indicator:SetPoint("RIGHT", label, "LEFT", -4, 0)
        Theme.Dot(indicator, DOT, C.accent)
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
