--[[ UI/Style.lua
  The design system every Peavers config surface is drawn with: the numbers, and
  the handful of pieces built from them. Theme.lua owns the palette; this file
  owns how that palette is spent.

  It exists because a window built from tidy parts can still read as untidy. The
  installer carried its spacing as literals at the point of use - 6, 8, 10, 12,
  14, 44, 82 - and let its accent colour do five different jobs at once. Nothing
  there was wrong on its own, and the result looked unfinished.

  THE SYSTEM, IN FULL:

    ONE ACCENT, AND ONLY FOR STATE. The accent marks what is selected and the
    one primary action. Never body text, never a heading, never a panel fill,
    never decoration. If something is accent-coloured it is because the player
    chose it or is about to press it.

    HIERARCHY IS ALPHA, NOT SIZE OR WEIGHT. Primary text is white at 1.0,
    secondary at 0.53, muted at 0.41. A label beside its value needs no second
    font size to read correctly - it needs the value dimmer.

    THREE SIZES DO THE WORK. 13 for labels, 12 for values and descriptions, 11
    for section headings. One hero size for a page title. Nothing is bold and
    nothing is outlined.

    ROWS ARE FLUSH, SEPARATED BY TONE. A list is rows of one height with no gap
    between them and alternating black overlays at 10% and 20%. Whitespace
    between rows is what makes a list look scattered; banding is what makes it
    look like a table. The banding restarts at every section heading.

    EVERY HAIRLINE IS ONE PIXEL, GRADED BY IMPORTANCE. A section rule is barely
    there, a divider slightly more, the window's own chrome more again. White at
    low alpha rather than an authored grey, so one value is correct on whatever
    the paper happens to be.

    HOVER IS ALPHA. SELECTION IS THE BAR. Hover lifts a row's highlight and its
    text; selection draws the accent bar down the left edge. The two can never
    be mistaken for each other - which is the failure this replaces, where a
    selected card signalled three times over (accent border, accent edge and a
    recoloured title) while a hovered one changed its border, so at a glance the
    two states looked alike.

  Borrowed from the way EllesmereUI's options window is built, because it is the
  tidiest thing in the ecosystem and every reason it is tidy is systemic rather
  than decorative. The button values in particular are taken from it literally -
  see the note above Style.Button for why "roughly that" was not good enough.

  Depends on Theme only, never on Widgets, so it loads immediately after
  Theme.lua. Consumers hold references to Theme's colour tables the same way
  Widgets does; see the table-identity note in Theme.lua and do not reassign.
]]

local PeaversCommons = _G.PeaversCommons
local Style = {}
PeaversCommons.Style = Style

local Theme = PeaversCommons.Theme
local C = Theme.Colors

-- ---------------------------------------------------------------------------
-- The numbers
-- ---------------------------------------------------------------------------

-- Type. One hero, three working sizes, one for metadata.
Style.Size = {
    hero    = 18,
    label   = 13,
    value   = 12,
    section = 11,
    meta    = 10,
}

-- Hierarchy. Every piece of text picks one of these and nothing else.
Style.Alpha = {
    primary   = 1.00,
    secondary = 0.53,
    muted     = 0.41,
    disabled  = 0.25,
}

-- Hairlines, graded by importance. White over paper rather than an authored
-- grey, so the same value is correct on a lighter or darker background.
Style.Rule = {
    section = 0.05,
    divider = 0.09,
    chrome  = 0.16,
}

-- Rows. Flush, banded, and inset from their own edges rather than from the
-- window's - the row is the grid, and everything inside it lines up with the
-- row above.
Style.Row = {
    height    = 30,
    tall      = 40,
    inset     = 14,
    zebraOdd  = 0.10,
    zebraEven = 0.20,
    hover     = 0.06,
    selected  = 0.08,
    bar       = 3,
}

-- Layout. Content is inset from the window edge once, here, and every page
-- derives its width from it.
Style.Pad = {
    content = 28,
    section = 12,
    gap     = 10,
}

Style.Accent = C.accent

-- ---------------------------------------------------------------------------
-- Text
-- ---------------------------------------------------------------------------

-- The face every config surface is drawn with, buttons included. One typeface,
-- whatever the player's own font settings are: matching the rest of the
-- collection matters more here than matching their bars.
--
-- A second face for button labels alone was tried and taken back out. Noted so
-- it is not tried a third time: it did not read as a deliberate pairing, it
-- read as a button from some other window dropped into this one.
local function Face()
    local display = Theme.Fonts and Theme.Fonts.display
    return display or "Fonts\\FRIZQT__.TTF"
end

--- Set a font string's size and alpha in one call.
--- @param fontString FontString
--- @param size number     one of Style.Size
--- @param alpha number    one of Style.Alpha
--- @param color? table    rgb, white unless the text carries state
function Style.Text(fontString, size, alpha, color)
    if not fontString then return end
    fontString:SetFont(Face(), size or Style.Size.label, "")
    local rgb = color or { 1, 1, 1 }
    fontString:SetTextColor(rgb[1], rgb[2], rgb[3], alpha or Style.Alpha.primary)
end

--- A label, sized and dimmed in one step.
function Style.Label(parent, text, size, alpha, opts)
    opts = opts or {}
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetText(text or "")
    Style.Text(label, size, alpha, opts.color)
    if opts.width then
        label:SetWidth(opts.width)
        label:SetJustifyH(opts.justifyH or "LEFT")
        label:SetJustifyV("TOP")
        label:SetWordWrap(opts.wrap ~= false)
    else
        label:SetWordWrap(false)
        if opts.justifyH then label:SetJustifyH(opts.justifyH) end
    end
    return label
end

--- A wrapping paragraph, and the height it actually came out at.
--- Nothing below a paragraph is ever placed by a guess.
function Style.Paragraph(parent, text, width, alpha)
    local label = Style.Label(parent, text, Style.Size.value,
        alpha or Style.Alpha.secondary, { width = width, wrap = true })
    local height = label.GetStringHeight and label:GetStringHeight() or 0
    if not height or height < 1 then height = Style.Size.value + 2 end
    return label, height
end

-- ---------------------------------------------------------------------------
-- Lines
-- ---------------------------------------------------------------------------

-- WoW's own pixel snapping is what makes a one-pixel line disappear at a
-- fractional UI scale, so it is switched off on anything this thin.
local function Thin(texture)
    if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false) end
    if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0) end
    return texture
end

--- A one-pixel horizontal rule at one of the graded alphas.
function Style.Hairline(parent, alpha)
    local line = Thin(parent:CreateTexture(nil, "ARTWORK"))
    line:SetHeight(1)
    line:SetColorTexture(1, 1, 1, alpha or Style.Rule.divider)
    return line
end

--- A one-pixel border, drawn as four textures rather than a backdrop edge.
---
--- SetBackdrop multiplies its edgeSize by the frame's effective scale, and a
--- fractional scale - the UI pack pins about 0.53 on a 1440 canvas - rounds a
--- nominal one-pixel edge up on some sides and down on others: one pixel along
--- the top and left, two along the bottom and right. Textures can be told not
--- to snap to the pixel grid, the same trick every hairline here uses, so the
--- border is four of them and comes out even on all four sides.
function Style.Border(frame)
    local sides = {}
    for _, side in ipairs({ "top", "bottom", "left", "right" }) do
        sides[side] = Thin(frame:CreateTexture(nil, "BORDER"))
    end

    sides.top:SetPoint("TOPLEFT", 0, 0)
    sides.top:SetPoint("TOPRIGHT", 0, 0)
    sides.top:SetHeight(1)

    sides.bottom:SetPoint("BOTTOMLEFT", 0, 0)
    sides.bottom:SetPoint("BOTTOMRIGHT", 0, 0)
    sides.bottom:SetHeight(1)

    -- Inset by one so the corners are not painted twice: overlapping alpha at
    -- four corners shows as a brighter dot on a dim border.
    sides.left:SetPoint("TOPLEFT", 0, -1)
    sides.left:SetPoint("BOTTOMLEFT", 0, 1)
    sides.left:SetWidth(1)

    sides.right:SetPoint("TOPRIGHT", 0, -1)
    sides.right:SetPoint("BOTTOMRIGHT", 0, 1)
    sides.right:SetWidth(1)

    local border = {}

    function border:SetColor(r, g, b, a)
        for _, texture in pairs(sides) do
            texture:SetColorTexture(r, g, b, a or 1)
        end
    end

    function border:SetShown(shown)
        for _, texture in pairs(sides) do
            texture:SetShown(shown)
        end
    end

    return border
end

-- ---------------------------------------------------------------------------
-- Sections
--
-- Ten pixels of air, a small uppercase heading at the muted alpha, and a rule
-- beneath it. The rule belongs to the content below rather than the heading
-- above, which is why the heading sits close to it and far from whatever came
-- before.
-- ---------------------------------------------------------------------------

--- @return number nextY
function Style.Section(parent, text, y, width)
    y = y - Style.Pad.section

    local label = Style.Label(parent, tostring(text):upper(),
        Style.Size.section, Style.Alpha.muted)
    label:SetPoint("TOPLEFT", 0, y)

    local rule = Style.Hairline(parent, Style.Rule.section)
    rule:SetPoint("TOPLEFT", 0, y - Style.Size.section - 8)
    rule:SetWidth(width)

    -- Banding restarts per section, so the first row of every group is the
    -- lighter tone and groups never drift out of phase with each other.
    parent.styleZebra = 0

    return y - Style.Size.section - 10
end

-- ---------------------------------------------------------------------------
-- Rows
-- ---------------------------------------------------------------------------

--- A banded row. Flush with its neighbours; tone is what separates them.
---
--- @param opts table { height, onClick }
--- @return Frame row, number nextY
function Style.MakeRow(parent, y, width, opts)
    opts = opts or {}
    local height = opts.height or Style.Row.height

    local row = CreateFrame(opts.onClick and "Button" or "Frame", nil, parent)
    row:SetSize(width, height)
    row:SetPoint("TOPLEFT", 0, y)

    parent.styleZebra = (parent.styleZebra or 0) + 1
    local band = (parent.styleZebra % 2 == 1) and Style.Row.zebraOdd or Style.Row.zebraEven

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, band)

    local highlight = row:CreateTexture(nil, "ARTWORK")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, Style.Row.hover)
    highlight:Hide()
    row.styleHighlight = highlight

    -- The selection mark: an accent bar down the left edge, and nothing else.
    local bar = Thin(row:CreateTexture(nil, "OVERLAY"))
    bar:SetPoint("TOPLEFT", 0, 0)
    bar:SetPoint("BOTTOMLEFT", 0, 0)
    bar:SetWidth(Style.Row.bar)
    bar:SetColorTexture(Style.Accent[1], Style.Accent[2], Style.Accent[3], 1)
    bar:Hide()
    row.styleBar = bar

    function row:SetSelected(selected)
        self.selected = selected and true or false
        bar:SetShown(self.selected)
        bg:SetColorTexture(0, 0, 0, self.selected and 0 or band)
        highlight:SetShown(self.selected)
        if self.selected then
            highlight:SetColorTexture(1, 1, 1, Style.Row.selected)
        else
            highlight:SetColorTexture(1, 1, 1, Style.Row.hover)
        end
    end

    if opts.onClick then
        row:SetScript("OnEnter", function(self)
            if not self.selected then highlight:Show() end
        end)
        row:SetScript("OnLeave", function(self)
            if not self.selected then highlight:Hide() end
        end)
        row:SetScript("OnClick", opts.onClick)
    end

    return row, y - height
end

--- Label on the left, value on the right, both inset from the row's own edges.
function Style.RowText(row, label, value, opts)
    opts = opts or {}

    local left = Style.Label(row, label, Style.Size.label, Style.Alpha.primary)
    left:SetPoint("LEFT", Style.Row.inset, 0)
    row.styleLabel = left

    if value then
        local right = Style.Label(row, value, Style.Size.value,
            opts.valueAlpha or Style.Alpha.secondary, { color = opts.valueColor })
        right:SetPoint("RIGHT", -Style.Row.inset, 0)
        row.styleValue = right

        -- The label stops short of the value rather than running under it.
        left:SetWordWrap(false)
        left:SetPoint("RIGHT", right, "LEFT", -12, 0)
        left:SetJustifyH("LEFT")
    end

    return row
end

-- ---------------------------------------------------------------------------
-- Buttons
--
-- Taken from EllesmereUI's popup action buttons down to the literal values,
-- because "roughly that" is exactly what produced the version this replaces.
--
-- The button is a SOLID dark panel, not a translucent one. That is the whole
-- difference: at 35% black the window showed through and the thing read as a
-- faint outline drawn onto the background rather than as an object sitting on
-- top of it, which is what made correct borders and correct type still look
-- wrong.
--
-- Emphasis is the accent on the outline and the label, never as a fill. Both
-- variants share one background, so the eye separates them by colour and alpha
-- alone, and the fill does not move on hover - only the border and the text do.
-- ---------------------------------------------------------------------------

-- Near-black at 92%, the same on every button in every state.
local BUTTON_FILL = { 0.06, 0.08, 0.10, 0.92 }
local BUTTON_HEIGHT = 32

local VARIANTS = {
    primary = {
        color = Style.Accent,
        border = 0.90, borderHover = 1.00,
        textAlpha = 0.90, hoverAlpha = 1.00,
    },
    secondary = {
        color = { 1, 1, 1 },
        border = 0.35, borderHover = 0.60,
        textAlpha = 0.55, hoverAlpha = 1.00,
    },
    -- A text link rather than a button: no fill and no border at all, for the
    -- way out of a screen, which should be available without competing with the
    -- way on. Having no `border` is what marks it as one.
    link = {
        color = { 1, 1, 1 },
        textAlpha = 0.50, hoverAlpha = 1.00,
    },
}

function Style.Button(parent, text, opts)
    opts = opts or {}
    local variant = VARIANTS[opts.variant or "secondary"] or VARIANTS.secondary
    local size = opts.size or Style.Size.label
    local color = variant.color

    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(opts.width or 110, opts.height or BUTTON_HEIGHT)

    local border
    if variant.border then
        local fill = btn:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        fill:SetColorTexture(unpack(BUTTON_FILL))

        border = Style.Border(btn)
        border:SetColor(color[1], color[2], color[3], variant.border)
    end

    -- Set directly rather than through Style.Text because re-applying a font on
    -- every hover is work for nothing: only the colour moves between states.
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER")
    label:SetText(text)
    label:SetFont(Face(), size, "")
    label:SetTextColor(color[1], color[2], color[3], variant.textAlpha)

    local function Paint(textAlpha, borderAlpha)
        label:SetTextColor(color[1], color[2], color[3], textAlpha)
        if border then
            border:SetColor(color[1], color[2], color[3], borderAlpha)
        end
    end

    btn:SetScript("OnEnter", function() Paint(variant.hoverAlpha, variant.borderHover) end)
    btn:SetScript("OnLeave", function() Paint(variant.textAlpha, variant.border) end)
    if opts.onClick then btn:SetScript("OnClick", opts.onClick) end

    function btn:SetLabel(value)
        label:SetText(value)
    end

    return btn
end

-- ---------------------------------------------------------------------------
-- Checkbox
--
-- The whole row is the hit area, because a 14 pixel box is a small target and
-- there is nothing else on the row to hit by accident.
-- ---------------------------------------------------------------------------

--- @return Frame row, number nextY
function Style.Checkbox(parent, y, width, opts)
    opts = opts or {}
    local checked = opts.checked and true or false

    local height = Style.Row.height
    local descHeight

    local row = CreateFrame("Button", nil, parent)
    row:SetPoint("TOPLEFT", 0, y)

    -- Banded like every other row. A column of checkboxes with nothing behind
    -- them is the scattered list the banding exists to prevent, and a checkbox
    -- is a row whatever else it is.
    parent.styleZebra = (parent.styleZebra or 0) + 1
    local band = (parent.styleZebra % 2 == 1) and Style.Row.zebraOdd or Style.Row.zebraEven
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, band)

    local box = row:CreateTexture(nil, "ARTWORK")
    box:SetSize(14, 14)
    box:SetPoint("TOPLEFT", Style.Row.inset, -8)

    local border = Thin(row:CreateTexture(nil, "BORDER"))
    border:SetPoint("TOPLEFT", box, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 1, -1)

    -- A filled box does read as "on", but only once you have worked out it is a
    -- checkbox at all, so it wants the tick the rest of the collection draws.
    -- The collection's own flat mask rather than Blizzard's UI-CheckBox-Check,
    -- which has bevel, inner shading and a glow baked into the art and goes
    -- muddy the moment it sits on a flat fill.
    local check = row:CreateTexture(nil, "OVERLAY")
    check:SetSize(10, 10)
    check:SetPoint("CENTER", box, "CENTER", 0, 0)
    check:SetTexture(Theme.Textures and Theme.Textures.check)
    if not check:GetTexture() then
        check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    end
    check:SetVertexColor(1, 1, 1)
    check:Hide()

    local label = Style.Label(row, opts.label, Style.Size.label, Style.Alpha.primary)
    label:SetPoint("TOPLEFT", box, "TOPRIGHT", 10, 2)

    local descLabel
    if opts.description then
        descLabel, descHeight = Style.Paragraph(row, opts.description,
            width - Style.Row.inset - 24, Style.Alpha.muted)
        descLabel:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -6)
        height = 8 + 14 + 6 + descHeight + 8
    end

    row:SetSize(width, height)

    local function Paint()
        check:SetShown(checked)
        if checked then
            box:SetColorTexture(Style.Accent[1], Style.Accent[2], Style.Accent[3], 1)
            border:SetColorTexture(Style.Accent[1], Style.Accent[2], Style.Accent[3], 0.35)
        else
            box:SetColorTexture(1, 1, 1, 0.06)
            border:SetColorTexture(1, 1, 1, 0.18)
        end
    end
    Paint()

    row:SetScript("OnEnter", function()
        Style.Text(label, Style.Size.label, Style.Alpha.primary)
        if not checked then border:SetColorTexture(1, 1, 1, 0.30) end
    end)
    row:SetScript("OnLeave", function()
        Style.Text(label, Style.Size.label, Style.Alpha.primary)
        Paint()
    end)
    row:SetScript("OnClick", function()
        checked = not checked
        Paint()
        if opts.onChange then opts.onChange(checked) end
    end)

    function row:SetChecked(value)
        checked = value and true or false
        Paint()
    end
    function row:GetChecked() return checked end

    return row, y - height
end

return Style
