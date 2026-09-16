local PeaversCommons = _G.PeaversCommons
local W = {}
PeaversCommons.Widgets = W

local Theme = PeaversCommons.Theme
local Style = PeaversCommons.Style

-- Alias, not a copy: consumers capture `local C = W.Colors` at load time and hold a
-- reference to this exact table. See the table-identity note in Theme.lua.
W.Colors = Theme.Colors

local C = W.Colors

--------------------------------------------------------------------------------
-- The (frame, nextY) contract
--
-- CreateSectionHeader and CreateSeparator have always taken an x/y and handed
-- back where the next thing goes. The other factories did not, so every caller
-- had to know how tall the control it just made was - and a survey of the
-- thirteen addons that lay out pages by hand found the same 22px checkbox
-- advanced past by SEVEN different numbers, with gaps from +4 to +18. Nobody was
-- doing it wrong; there was no right way to write it.
--
-- So every factory now accepts an optional `opts.x`/`opts.y`, anchors itself when
-- given one, and returns `(frame, nextY)`. Callers that pass no y get nil as the
-- second value and carry on exactly as before - this is additive, and the
-- existing hundred-odd call sites keep working untouched.
--
-- Once a caller has adopted it, the control's height stops being its business,
-- which is what makes the metrics safe to change afterwards.
--------------------------------------------------------------------------------

-- The air under a control before the next one starts. One number, so a page
-- built from these has one rhythm rather than each call site inventing its own.
local GAP = 8

--- Anchor a freshly built widget if the caller gave a position, and work out
--- where the next one goes.
--- @return Frame frame, number|nil nextY
local function Place(frame, opts, height)
    if not opts or opts.y == nil then return frame, nil end
    frame:SetPoint("TOPLEFT", opts.x or 0, opts.y)
    return frame, opts.y - height - (opts.gap or GAP)
end

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

    -- Tracked, uppercase, mono - the eyebrow, kept because the letter-spacing is
    -- genuinely nicer than a plain label and costs nothing on a string this
    -- short. Falls back to a plain FontString when the bundled font is
    -- unavailable (non-Latin locale, or the client has not been restarted since
    -- the font was added).
    --
    -- White at the muted alpha rather than indigo. A heading that reads the same
    -- on every page is not state, and spending the accent on all thirty-nine of
    -- them is what stops it meaning anything on the one row you have selected.
    local HEADING = { 1, 1, 1 }
    local label
    if Theme.UsesCustomFonts() then
        label = Theme.TrackedLabel(container, text, Style.Size.section,
            { HEADING[1], HEADING[2], HEADING[3], Style.Alpha.muted })
        label:SetPoint("BOTTOMLEFT", 0, 4)
    else
        label = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("BOTTOMLEFT", 0, 4)
        label:SetText(tostring(text):upper())
        Style.Text(label, Style.Size.section, Style.Alpha.muted)
    end

    -- The rule belongs to the content below rather than the heading above, and
    -- sits at the section weight: barely there, enough to group.
    local line = Style.Hairline(container, Style.Rule.section)
    line:SetPoint("BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", 0, 0)

    container.label = label
    return container, y - 24
end

function W.CreateCollapsibleSection(_, parent, title, opts)
    opts = opts or {}
    local defaultOpen = opts.defaultOpen ~= false

    local frame = CreateFrame("Frame", opts.name, parent)

    local panelFill = frame:CreateTexture(nil, "BACKGROUND")
    panelFill:SetAllPoints()
    panelFill:SetColorTexture(C.bgPanel[1], C.bgPanel[2], C.bgPanel[3], C.bgPanel[4] or 1)

    local panelBorder = Style.Border(frame)
    panelBorder:SetColor(1, 1, 1, Style.Rule.chrome)

    local header = CreateFrame("Button", nil, frame)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(32)

    local headerBg = header:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    headerBg:SetColorTexture(0, 0, 0, 0)

    local arrow = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    arrow:SetPoint("LEFT", 10, 0)
    Style.Text(arrow, Style.Size.value, Style.Alpha.muted)

    local titleText = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    titleText:SetPoint("LEFT", arrow, "RIGHT", 6, 0)
    titleText:SetText(title)
    Style.Text(titleText, Style.Size.label, Style.Alpha.primary)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", 0, -32)
    content:SetPoint("TOPRIGHT", 0, -32)

    local divider = Style.Hairline(frame, Style.Rule.divider)
    divider:SetPoint("TOPLEFT", 0, -32)
    divider:SetPoint("TOPRIGHT", 0, -32)

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

    -- Hover is alpha, and leaving restores nothing rather than painting the
    -- header a different colour than it started - which is what it did before,
    -- so a section you had once hovered stayed visibly darker than its siblings.
    header:SetScript("OnEnter", function()
        headerBg:SetColorTexture(1, 1, 1, Style.Row.hover)
    end)
    header:SetScript("OnLeave", function()
        headerBg:SetColorTexture(0, 0, 0, 0)
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

--- Create a themed button.
---
--- Every variant shares one solid dark fill and differs only in the colour and
--- alpha of its outline and label: `primary` wears the accent, `secondary` white,
--- `danger` red, and `ghost` drops the fill and border entirely to become a text
--- link. Nothing is filled with the accent - a block of colour in a dense
--- settings window reads as a warning rather than as the way forward.
---
--- Pass `opts.y` (and optionally `opts.x`) to have the button anchor itself and
--- hand back where the next control goes; see the (frame, nextY) note above.
--- @param parent Frame
--- @param text string
--- @param opts? table { variant|style, width, height, onClick, name, x, y, gap }
function W.CreateButton(_, parent, text, opts)
    opts = opts or {}
    -- `style` is accepted as an alias for `variant`: several addons pass it, and
    -- silently fell through to the secondary default before this.
    local variant = opts.variant or opts.style or "secondary"
    local width = opts.width or 120
    local height = opts.height or 26

    local btn = CreateFrame("Button", opts.name, parent)
    btn:SetSize(width, height)

    -- One solid dark fill on every variant, in every state. A translucent fill
    -- lets the window through and the button reads as an outline drawn onto the
    -- background rather than an object sitting on top of it.
    local fill = btn:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0.06, 0.08, 0.10, 0.92)

    -- Four unsnapped textures rather than a backdrop edge: a nominal one-pixel
    -- edgeSize is multiplied by the frame's effective scale, so at a fractional
    -- scale it rounds up along the bottom and right and down along the top and
    -- left. See Style.Border.
    local border = Style.Border(btn)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", 0, 0)
    label:SetText(text)
    -- Set once here rather than through Style.Text on every hover: only the
    -- colour moves between states, and re-applying a font is work for nothing.
    label:SetFont(Style.Face(), Style.Size.label, "")

    -- Emphasis is the accent on the outline and the label, never as a fill.
    -- The previous primary was a solid indigo block, on the reasoning that a
    -- white pill reads as glaring in a dense window - which is true, and the
    -- answer is not to fill it with a different colour but not to fill it at
    -- all. Both variants share one background, so the eye separates them by
    -- colour and alpha alone, and only the border and text move on hover.
    local variants = {
        primary   = { color = C.accent,    border = 0.90, borderHover = 1.00, alpha = 0.90, hover = 1.00 },
        secondary = { color = { 1, 1, 1 }, border = 0.35, borderHover = 0.60, alpha = 0.55, hover = 1.00 },
        ghost     = { color = { 1, 1, 1 },                                    alpha = 0.50, hover = 1.00 },
        danger    = { color = C.danger,    border = 0.55, borderHover = 1.00, alpha = 0.75, hover = 1.00 },
    }

    local c = variants[variant] or variants.secondary

    -- Ghost is a text link: no fill and no border at all, which is what marks it
    -- as the quiet way out rather than a third competing button.
    if not c.border then
        fill:Hide()
        border:SetShown(false)
    end

    local function Paint(textAlpha, borderAlpha)
        label:SetTextColor(c.color[1], c.color[2], c.color[3], textAlpha)
        if c.border then
            border:SetColor(c.color[1], c.color[2], c.color[3], borderAlpha)
        end
    end

    btn:SetScript("OnEnter", function() Paint(c.hover, c.borderHover) end)
    btn:SetScript("OnLeave", function() Paint(c.alpha, c.border) end)
    btn:SetScript("OnMouseDown", function() label:SetPoint("CENTER", 0, -1) end)
    btn:SetScript("OnMouseUp", function() label:SetPoint("CENTER", 0, 0) end)

    if opts.onClick then
        btn:SetScript("OnClick", opts.onClick)
    end

    Paint(c.alpha, c.border)

    btn.label = label
    btn.SetLabel = function(self, newText) label:SetText(newText) end

    return Place(btn, opts, height)
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
    boxFill:SetAllPoints()
    local boxBorder = box:CreateTexture(nil, "BORDER")
    boxBorder:SetAllPoints()
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
    Style.Text(label, Style.Size.label, Style.Alpha.primary)

    local height = 22
    if opts.description then
        local desc = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        desc:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
        desc:SetText(opts.description)
        -- The description is the same sentence one step quieter, by alpha
        -- rather than by a second colour.
        Style.Text(desc, Style.Size.value, Style.Alpha.muted)
        height = 36
        frame:SetHeight(height)
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

    btn:SetScript("OnEnter", function() SetEdge(C.borderHover) end)
    btn:SetScript("OnLeave", function() SetEdge(C.border) end)

    UpdateState()

    frame.SetChecked = function(self, value) checked = value; UpdateState() end
    frame.GetChecked = function(self) return checked end
    -- Test seam: lets a harness invoke the same handler a click would fire.
    frame.__isPeaversCheckbox = true
    frame.__onChange = function() if opts.onChange then opts.onChange(checked) end end

    return Place(frame, opts, height)
end

-- Deprecated: the switch-style toggle was retired in favour of the checkbox
-- for visual consistency across the ecosystem. Kept as a delegate because
-- already-released addon versions still call it; new code should use
-- CreateCheckbox directly. The two contracts are identical (opts.checked /
-- onChange / width / name, SetChecked / GetChecked on the returned frame).
function W.CreateToggle(_, parent, labelText, opts)
    return W:CreateCheckbox(parent, labelText, opts)
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
    -- A readout, not a state: the accent stays on the fill and the thumb, which
    -- are what actually show the value.
    Style.Text(valueText, Style.Size.value, Style.Alpha.secondary)

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
    -- Track fill as a texture with an unsnapped border, rather than a backdrop
    -- edge: on a track only six pixels tall, an edge that rounds to two on one
    -- side and one on the other is the whole control looking crooked.
    local trackFill = slider:CreateTexture(nil, "BACKGROUND")
    trackFill:SetAllPoints()
    trackFill:SetColorTexture(C.bgNested[1], C.bgNested[2], C.bgNested[3], 1)
    local trackBorder = Style.Border(slider)
    trackBorder:SetColor(1, 1, 1, Style.Rule.divider)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    slider:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    local thumbTex = slider:GetThumbTexture()
    thumbTex:SetSize(12, 12)
    thumbTex:SetVertexColor(unpack(C.accent))

    slider:SetValue(value)

    -- ARTWORK, not BORDER: the track's own outline is four textures on the
    -- BORDER layer now, and two things on one layer in the same place have no
    -- defined order between them. The progress fill belongs above both.
    local fill = slider:CreateTexture(nil, "ARTWORK")
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
        trackBorder:SetColor(1, 1, 1, Style.Rule.chrome)
        thumbTex:SetVertexColor(C.accentHover[1], C.accentHover[2], C.accentHover[3])
    end)
    slider:SetScript("OnLeave", function()
        trackBorder:SetColor(1, 1, 1, Style.Rule.divider)
        thumbTex:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
    end)

    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", function(self, delta)
        self:SetValue(self:GetValue() + (delta * step))
    end)

    frame.slider = slider
    frame.SetValue = function(self, v) slider:SetValue(v) end
    frame.GetValue = function(self) return slider:GetValue() end

    return Place(frame, opts, 44)
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

    -- A dropdown of collected addon buttons is as long as the number of addons
    -- installed, and a font list is longer still. Past this the menu scrolls
    -- rather than growing off the bottom of the screen.
    local MAX_MENU_HEIGHT = opts.maxMenuHeight or 300
    local ITEM_HEIGHT = 24

    if menuFrame.SetClipsChildren then
        menuFrame:SetClipsChildren(true)
    end

    -- The items live on their own frame so scrolling is one anchor change
    -- rather than repositioning every row.
    local menuContent = CreateFrame("Frame", nil, menuFrame)
    menuContent:SetPoint("TOPLEFT")
    menuContent:SetPoint("TOPRIGHT")
    menuContent:SetHeight(1)

    -- Without something to see, a menu that scrolls looks exactly like a menu
    -- that has been cut off.
    local thumb = menuFrame:CreateTexture(nil, "OVERLAY")
    thumb:SetWidth(3)
    thumb:SetColorTexture(C.textMuted[1], C.textMuted[2], C.textMuted[3], 0.5)
    thumb:Hide()

    local scrollOffset, maxScroll = 0, 0

    local function ApplyScroll()
        menuContent:ClearAllPoints()
        menuContent:SetPoint("TOPLEFT", 0, scrollOffset)
        menuContent:SetPoint("TOPRIGHT", 0, scrollOffset)

        if maxScroll <= 0 then
            thumb:Hide()
            return
        end

        local track = menuFrame:GetHeight() - 4
        local visible = track / (track + maxScroll)
        local height = math.max(16, track * visible)
        thumb:SetHeight(height)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", menuFrame, "TOPRIGHT", -2,
            -2 - ((track - height) * (scrollOffset / maxScroll)))
        thumb:Show()
    end

    menuFrame:EnableMouseWheel(true)
    menuFrame:SetScript("OnMouseWheel", function(_, delta)
        if maxScroll <= 0 then return end
        -- Positive Y is up, so scrolling down moves the content up.
        scrollOffset = math.max(0, math.min(maxScroll, scrollOffset - (delta * ITEM_HEIGHT)))
        ApplyScroll()
    end)

    local menuButtons = {}

    local function BuildMenu()
        for _, mb in ipairs(menuButtons) do mb:Hide() end
        menuButtons = {}

        local itemHeight = ITEM_HEIGHT
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

            local item = CreateFrame("Button", nil, menuContent)
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

            -- Hover is alpha, not a tint. An accent wash under the cursor reads
            -- as "this one is chosen", which is what the selected item's own
            -- accent text already says.
            item:SetScript("OnEnter", function() itemBg:SetColorTexture(1, 1, 1, Style.Row.hover) end)
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

        local contentHeight = math.abs(yOff) + 4
        menuContent:SetHeight(contentHeight)

        menuFrame:SetHeight(math.min(contentHeight, MAX_MENU_HEIGHT))
        maxScroll = math.max(0, contentHeight - menuFrame:GetHeight())

        -- Opening the menu starts at the top rather than wherever it was left.
        scrollOffset = 0
        ApplyScroll()
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

    return Place(frame, opts, 50)
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

    return Place(frame, opts, labelText and 44 or 28)
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

    return Place(frame, opts, 22)
end

function W:CreateSeparator(parent, x, y, width)
    -- White at the divider weight rather than the pre-composited border grey, so
    -- one value stays correct whatever paper it lands on, and with pixel
    -- snapping off so it cannot vanish at a fractional scale.
    local line = Style.Hairline(parent, Style.Rule.divider)
    line:SetPoint("TOPLEFT", x, y)
    line:SetWidth(width or 400)
    return line, y - 12
end

function W:CreateLabel(parent, text, opts)
    opts = opts or {}
    local label = parent:CreateFontString(nil, "ARTWORK", opts.font or "GameFontNormal")
    label:SetText(text)
    -- An explicit colour still wins: plenty of callers pass C.danger or a class
    -- colour and mean it. Absent one, text lands on the hierarchy - white at the
    -- primary alpha - rather than on a named grey.
    local color = opts.color
    if color then
        label:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    else
        Style.Text(label, opts.size or Style.Size.label, Style.Alpha.primary)
    end
    if opts.size then
        label:SetFont(Style.Face(), opts.size, opts.outline or "")
    end
    -- A FontString with no width sizes itself to its text and stays on one
    -- line, so a paragraph passed here runs off the panel rather than wrapping.
    -- `width` is what gives wrapping something to wrap against; without it
    -- `wrap` has nothing to do. Justification is set explicitly because the
    -- game font objects carry their own, and a body block anchored TOPLEFT
    -- wants LEFT/TOP whatever that happens to be.
    if opts.width then
        label:SetWidth(opts.width)
        label:SetJustifyH(opts.justifyH or "LEFT")
        label:SetJustifyV(opts.justifyV or "TOP")
    elseif opts.justifyH then
        label:SetJustifyH(opts.justifyH)
    end
    if opts.wrap ~= nil then
        label:SetWordWrap(opts.wrap and true or false)
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

    local bottomBorder = Style.Hairline(bar, Style.Rule.chrome)
    bottomBorder:SetPoint("BOTTOMLEFT", 0, 0)
    bottomBorder:SetPoint("BOTTOMRIGHT", 0, 0)

    local tabButtons = {}
    local selectedKey = tabs[1] and tabs[1].key

    local function UpdateTabs()
        for _, tb in ipairs(tabButtons) do
            local isSelected = (tb.key == selectedKey)
            Style.Text(tb.label, Style.Size.label,
                isSelected and Style.Alpha.primary or Style.Alpha.muted)
            tb.indicator:SetShown(isSelected)
        end
    end

    -- The label is centred and the tab is sized from its text. There used to be
    -- a dot beside the label, and both numbers below carried a reservation for
    -- it; the marker is an underline now, so the reservation is gone with it.
    local LABEL_PAD = 20

    local xOff = 8
    for _, tab in ipairs(tabs) do
        local btn = CreateFrame("Button", nil, bar)
        btn:SetPoint("TOPLEFT", xOff, 0)
        btn:SetHeight(height)

        local label = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        -- Offset right to leave room for the active dot, so the label does not
        -- shift horizontally when selection changes.
        label:SetPoint("CENTER", 0, 1)
        label:SetText(tab.label)
        label:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

        local textWidth = label:GetStringWidth()
        btn:SetWidth(math.max(textWidth + LABEL_PAD, 60))

        -- Selection is the accent bar, laid on its side. A row marks itself with
        -- a bar down its left edge; a tab is a row turned horizontal, so the
        -- same mark belongs along its bottom. This replaces an indigo dot beside
        -- the label, which was a second vocabulary for the one idea.
        local indicator = btn:CreateTexture(nil, "OVERLAY")
        indicator:SetPoint("BOTTOMLEFT", 0, 0)
        indicator:SetPoint("BOTTOMRIGHT", 0, 0)
        indicator:SetHeight(Style.Row.bar - 1)
        indicator:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
        if indicator.SetSnapToPixelGrid then
            indicator:SetSnapToPixelGrid(false)
            indicator:SetTexelSnappingBias(0)
        end
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
