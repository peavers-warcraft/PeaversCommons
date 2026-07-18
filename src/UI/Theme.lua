--[[ UI/Theme.lua
  The single source of truth for the look of every Peavers config surface: palette,
  spacing, radius, typography and motion tokens, plus the small pure helpers that
  the widgets share. No frames are created here — only constants and pure functions.

  Loaded before Widgets.lua so W.Colors can alias Theme.Colors and every consumer
  themes from one place.

  Why this exists: colour literals, the "%02x%02x%02x" hex conversion, and the 1px
  hairline texture idiom were copy-pasted across nine files. Centralising them makes
  a reskin a one-file change.

  IMPORTANT — table identity: consumer addons capture `local C = W.Colors` at file
  load time, holding a reference to this exact table. Never reassign Theme.Colors or
  W.Colors to a fresh table; mutate keys in place. Swapping the table would leave
  every already-loaded addon pointing at the old palette.
]]

local PeaversCommons = _G.PeaversCommons
local Theme = {}
PeaversCommons.Theme = Theme

-- ---------------------------------------------------------------------------
-- Palette — "engineering paper", ported from peavers.io (design/tokens.css)
--
-- A single flat #161616 field with no elevation or surface tinting, where all
-- hierarchy comes from 1px white/10% hairlines rather than cards or shadows.
-- Indigo is used sparingly: eyebrow labels, the active-item dot, badge fills.
--
-- Keys are load-bearing: eleven addons read them by name. Values may change
-- freely, names may not be removed.
--
-- Borders are stored pre-composited against paper (white/10 over #161616 =
-- #2d2d2d) rather than as {1,1,1,0.1}. A translucent border on the main frame
-- would let the 3D world show through the hairline and dissolve it.
-- ---------------------------------------------------------------------------
Theme.Colors = {
    -- Surfaces. bgPanel is deliberately identical to bgBase, and bgInput to
    -- bgNested: the design is flat, so the four-surface ramp collapses to two.
    bgBase      = { 0.086, 0.086, 0.086, 0.97 }, -- #161616 paper
    bgPanel     = { 0.086, 0.086, 0.086, 1.00 }, -- #161616
    bgNested    = { 0.110, 0.110, 0.110, 1.00 }, -- #1c1c1c paper-dim
    bgInput     = { 0.110, 0.110, 0.110, 1.00 }, -- #1c1c1c

    -- Hairlines — the primary hierarchy device.
    border      = { 0.176, 0.176, 0.176, 1.00 }, -- #2d2d2d (white/10 on paper)
    borderHover = { 0.290, 0.290, 0.290, 1.00 }, -- #4a4a4a (white/20 on paper)
    borderFocus = { 0.506, 0.549, 0.973, 1.00 }, -- #818cf8

    -- Accent.
    accent      = { 0.506, 0.549, 0.973, 1.00 }, -- #818cf8 indigo-400
    accentHover = { 0.647, 0.706, 0.988, 1.00 }, -- #a5b4fc indigo-300
    accentLight = { 1.000, 1.000, 1.000, 1.00 }, -- the design expresses emphasis as plain white

    -- gold/success keep their names for compatibility but no longer describe
    -- their values: the site has no gold and no green. Prefer the correctly
    -- named aliases below in new code.
    gold        = { 0.506, 0.549, 0.973, 1.00 }, -- section headers -> indigo eyebrow
    success     = { 0.506, 0.549, 0.973, 1.00 }, -- "Live" status -> primary
    -- Extension beyond the site tokens: the site has no destructive action,
    -- but PeaversConfig deletes profiles and needs one.
    danger      = { 0.973, 0.443, 0.443, 1.00 }, -- #f87171 red-400

    text        = { 1.000, 1.000, 1.000, 1.00 }, -- #ffffff
    textSec     = { 0.725, 0.725, 0.725, 1.00 }, -- #b9b9b9
    textMuted   = { 0.580, 0.580, 0.580, 1.00 }, -- #949494

    selected    = { 0.506, 0.549, 0.973, 0.08 }, -- primary/8, the site's badge fill
    highlight   = { 1.000, 1.000, 1.000, 0.03 }, -- white/3 composites to paper-dim
}

local C = Theme.Colors

-- Correctly-named aliases. Additive — nothing reads these yet, but new code
-- should prefer them over the legacy names above.
C.paper      = C.bgBase
C.paperDim   = C.bgNested
C.eyebrow    = C.accent
C.statusLive = C.accent
C.amber      = { 0.984, 0.749, 0.141, 1.00 } -- #fbbf24, "Beta" status
C.scrollThumb = { 1.000, 1.000, 1.000, 0.20 }

-- ---------------------------------------------------------------------------
-- Layout tokens
-- ---------------------------------------------------------------------------

--- Spacing scale. `gutter` names the panel indent that was a bare 25 in every
--- PeaversConfig panel and most consumer ConfigUI files.
Theme.Spacing = {
    xs = 4,
    sm = 8,
    md = 12,
    lg = 16,
    xl = 24,
    gutter = 25,
    row = 18,
}

--- Corner radii, in pixels. Meaningful once the sliced textures land; defined now
--- so widget code can be written against them and become correct for free.
Theme.Radius = {
    none = 0,
    md   = 6,
    lg   = 8,
    full = 999,
}

--- Motion durations in seconds.
Theme.Motion = {
    fast = 0.12,
    base = 0.20,
}

-- ---------------------------------------------------------------------------
-- Typography
--
-- IBM Plex Mono carries the site's signature treatment: uppercase indigo
-- "eyebrow" labels and mono micro-labels. Shipped as unmodified upstream static
-- TTFs (SIL OFL 1.1) under src/Media/Fonts alongside the licence.
--
-- Body and display text stay on Blizzard's font objects for now. The site uses
-- Archivo, but Google ships it only as a variable font whose default instance is
-- weight 600 — too heavy for body text — and instancing it to static weights
-- would trip the OFL Reserved Font Name clause.
--
-- NOTE: a newly added font file is only picked up on a full client restart;
-- /reload is not enough, and SetFont on a missing path fails silently.
-- ---------------------------------------------------------------------------

local MEDIA_PATH = "Interface\\AddOns\\PeaversCommons\\src\\Media\\"
local FONT_PATH = MEDIA_PATH .. "Fonts\\"

-- Flat texture masters, generated by scripts/generate_media.py. All are white
-- with the shape in the alpha channel, so a single file serves every colour via
-- Texture:SetVertexColor. Like fonts, newly added files need a full client
-- restart before the client will find them.
Theme.Textures = {
    check         = MEDIA_PATH .. "Textures\\Check16.tga",
    circle        = MEDIA_PATH .. "Textures\\Circle64.tga",
    roundedFill   = MEDIA_PATH .. "Textures\\RoundedFill8.tga",
    roundedBorder = MEDIA_PATH .. "Textures\\RoundedBorder8.tga",
    -- Tighter radius for small controls; the 8px master would read as a circle
    -- on an 18px checkbox.
    roundedFill4   = MEDIA_PATH .. "Textures\\RoundedFill4.tga",
    roundedBorder4 = MEDIA_PATH .. "Textures\\RoundedBorder4.tga",
    shadow        = MEDIA_PATH .. "Textures\\Shadow64.tga",
}

--- Apply a rounded 9-sliced fill or border texture to an existing Texture.
--- Returns false (leaving the texture untouched) if the art is unavailable, so
--- callers can fall back.
--- @param tex table Texture object.
--- @param which string "roundedFill" | "roundedBorder".
--- @param color number[]
--- @return boolean applied
function Theme.Slice(tex, which, color)
    tex:SetTexture(Theme.Textures[which])
    if not tex:GetTexture() then return false end

    -- Corner size matches the master: 8px on the 32px pair, 4px on the 16px pair.
    -- Preferred over the legacy nine-texture approach; see SetTextureSliceMargins.
    local margin = which:find("4$") and 4 or 8
    if tex.SetTextureSliceMargins then
        tex:SetTextureSliceMargins(margin, margin, margin, margin)
        if tex.SetTextureSliceMode and Enum and Enum.UITextureSliceMode then
            tex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
        end
    end
    -- Keeps the 1px border crisp instead of shimmering while dragging/resizing.
    if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
    if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end

    tex:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    return true
end

--- Restyle a Blizzard CheckButton as a flat, rounded, themed checkbox.
---
--- Deliberately restyles in place rather than replacing the frame: the widget
--- keeps its CheckButton type, its :GetChecked()/:SetChecked() API and its global
--- name, all of which consumer addons rely on.
---
--- Blizzard drives the checked visual through the CheckedTexture slot, but this
--- design needs the *box* to change colour too, so state is applied by a hook on
--- both OnClick and SetChecked.
--- @param cb table CheckButton.
--- @param size? number Box edge length (default 18).
function Theme.StyleCheckButton(cb, size)
    if cb.__peaversStyled then return cb end
    size = size or 18
    cb:SetSize(size, size)

    -- Drop the stock bevelled art (the big gold tick).
    for _, setter in ipairs({ "SetNormalTexture", "SetPushedTexture",
                              "SetCheckedTexture", "SetDisabledCheckedTexture",
                              "SetHighlightTexture" }) do
        if cb[setter] then pcall(cb[setter], cb, nil) end
    end

    local fill = cb:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints(cb)
    local border = cb:CreateTexture(nil, "BORDER")
    border:SetAllPoints(cb)
    local check = cb:CreateTexture(nil, "OVERLAY")
    check:SetSize(size - 4, size - 4)
    check:SetPoint("CENTER")
    check:SetTexture(Theme.Textures.check)
    check:SetVertexColor(1, 1, 1)

    local rounded = true

    local function Refresh()
        local on = cb:GetChecked()
        local fillColor = on and C.accent or C.bgNested
        local edgeColor = on and C.accent or C.border

        if rounded then
            rounded = Theme.Slice(fill, "roundedFill4", fillColor)
                and Theme.Slice(border, "roundedBorder4", edgeColor)
        end
        if not rounded then
            -- Square fallback when the art is missing (pre-restart client).
            fill:SetColorTexture(fillColor[1], fillColor[2], fillColor[3], fillColor[4] or 1)
            border:Hide()
        end
        check:SetShown(on and true or false)
    end

    cb:HookScript("OnClick", Refresh)
    local originalSetChecked = cb.SetChecked
    cb.SetChecked = function(self, value)
        originalSetChecked(self, value)
        Refresh()
    end

    cb.__peaversStyled = true
    cb.PeaversRefresh = Refresh
    Refresh()
    return cb
end

--- Turn a texture into a filled dot of the given colour.
--- Falls back to a square via SetColorTexture if the art is unavailable.
--- @param tex table Texture object.
--- @param size number
--- @param color number[]
function Theme.Dot(tex, size, color)
    tex:SetSize(size, size)
    tex:SetTexture(Theme.Textures.circle)
    if tex:GetTexture() then
        tex:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    else
        tex:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    end
end

Theme.Fonts = {
    monoRegular  = FONT_PATH .. "IBMPlexMono-Regular.ttf",
    monoMedium   = FONT_PATH .. "IBMPlexMono-Medium.ttf",
    monoSemiBold = FONT_PATH .. "IBMPlexMono-SemiBold.ttf",
}

-- Neither font covers CJK, and Cyrillic coverage is inconsistent, so non-Latin
-- clients keep Blizzard's locale font rather than rendering blank glyphs.
-- Mirrors the existing DefaultConfig.GetDefaultFont() locale switch.
local LATIN_LOCALES = {
    enUS = true, enGB = true, deDE = true, frFR = true,
    esES = true, esMX = true, itIT = true, ptBR = true,
}

function Theme.UsesCustomFonts()
    local locale = GetLocale and GetLocale() or "enUS"
    return LATIN_LOCALES[locale] == true
end

local fontCache = {}

--- Get (and cache) a font object for one of the bundled mono faces.
--- Falls back to a Blizzard font object if the file cannot be loaded — which is
--- what happens when the client has not been restarted since the file was added.
--- @param size number Point size.
--- @param weight? string "regular" | "medium" | "semibold" (default semibold).
--- @return table fontObject Suitable for FontString:SetFontObject.
function Theme.Mono(size, weight)
    weight = weight or "semibold"
    local key = weight .. ":" .. size

    local cached = fontCache[key]
    if cached then return cached end

    local fallback = _G.GameFontNormalSmall
    if not Theme.UsesCustomFonts() then
        fontCache[key] = fallback
        return fallback
    end

    local path = Theme.Fonts.monoSemiBold
    if weight == "regular" then path = Theme.Fonts.monoRegular
    elseif weight == "medium" then path = Theme.Fonts.monoMedium end

    local font = CreateFont("PeaversMono_" .. weight .. "_" .. tostring(size):gsub("%.", "_"))
    font:SetFont(path, size, "")

    -- A missing file leaves the object with no font set; detect and fall back.
    if not font:GetFont() then
        fontCache[key] = fallback
        return fallback
    end

    -- Blizzard font objects carry a 1px black text shadow. It reads as WoW and
    -- fights the flat aesthetic, so clear it explicitly.
    font:SetShadowColor(0, 0, 0, 0)
    font:SetShadowOffset(0, 0)

    fontCache[key] = font
    return font
end

-- ---------------------------------------------------------------------------
-- Helpers (pure)
-- ---------------------------------------------------------------------------

--- Convert a colour table to a six-digit hex string, e.g. "a854f7".
--- Rounds to integers: "%02x" on a non-integer float is undefined behaviour and
--- the copy-pasted call sites this replaces were relying on luck.
--- @param color number[] {r,g,b} components in 0..1.
--- @return string hex Six lowercase hex digits, no prefix.
function Theme.Hex(color)
    return string.format("%02x%02x%02x",
        math.floor(color[1] * 255 + 0.5),
        math.floor(color[2] * 255 + 0.5),
        math.floor(color[3] * 255 + 0.5))
end

--- Wrap text in a colour escape sequence.
--- @param color number[] {r,g,b} components in 0..1.
--- @param text string
--- @return string colored The text wrapped in |cff..|r.
function Theme.Colorize(color, text)
    return "|cff" .. Theme.Hex(color) .. text .. "|r"
end

--- Apply the site's 0.08em eyebrow tracking to a FontString.
---
--- WoW has no letter-spacing API (Font:SetSpacing is *line* spacing), so the
--- glyphs are laid out one FontString per character. This is only sound for a
--- monospace face — every advance width is identical, so one measurement drives
--- the whole run — and only cheap because eyebrows are short.
---
--- Returns a container frame; the caller anchors that instead of the original
--- FontString, which is hidden.
--- @param parent Frame
--- @param text string
--- @param size number
--- @param color number[]
--- @return Frame container
function Theme.TrackedLabel(parent, text, size, color)
    text = tostring(text):upper()
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(size + 4)

    local font = Theme.Mono(size, "semibold")
    local tracking = size * 0.08

    -- Measure one glyph: in a monospace face this is every glyph's advance.
    local probe = container:CreateFontString(nil, "ARTWORK")
    probe:SetFontObject(font)
    probe:SetText("M")
    local advance = probe:GetStringWidth()
    probe:Hide()

    local chars = {}
    local x = 0
    for i = 1, #text do
        local ch = text:sub(i, i)
        local fs = container:CreateFontString(nil, "ARTWORK")
        fs:SetFontObject(font)
        fs:SetText(ch)
        fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
        fs:SetPoint("LEFT", container, "LEFT", x, 0)
        chars[#chars + 1] = fs
        x = x + advance + tracking
    end

    container:SetWidth(math.max(1, x - tracking))
    container.chars = chars
    return container
end

--- Create a 1px hairline along one edge of a frame — the most repeated construct
--- in the UI code.
--- @param parent Frame
--- @param edge string "TOP"|"BOTTOM"|"LEFT"|"RIGHT".
--- @param opts? table { color = number[], alpha = number, inset = number, layer = string }
--- @return table texture
function Theme.Hairline(parent, edge, opts)
    opts = opts or {}
    local color = opts.color or C.border
    local alpha = opts.alpha or color[4] or 1
    local inset = opts.inset or 0

    local tex = parent:CreateTexture(nil, opts.layer or "ARTWORK")
    tex:SetColorTexture(color[1], color[2], color[3], alpha)

    if edge == "TOP" or edge == "BOTTOM" then
        tex:SetHeight(1)
        tex:SetPoint(edge .. "LEFT", inset, 0)
        tex:SetPoint(edge .. "RIGHT", -inset, 0)
    else
        tex:SetWidth(1)
        tex:SetPoint("TOP" .. edge, 0, -inset)
        tex:SetPoint("BOTTOM" .. edge, 0, inset)
    end

    return tex
end

return Theme
