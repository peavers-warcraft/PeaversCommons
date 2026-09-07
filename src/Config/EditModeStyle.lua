--------------------------------------------------------------------------------
-- PeaversCommons EditModeStyle Module
--
-- Puts every row of the Edit Mode dialog on one grid.
--
-- Out of the box the dialog is ragged, because its five widget kinds were never
-- built to sit next to each other:
--
--   dropdown     label 100 wide on the left, control at +5   row 305
--   slider       label 100 wide on the left, control at +5   row 343, fixed
--   colour       label 100 wide on the left, swatch at +5    row 137
--   checkbox     *box* on the left, label 300 wide after it  row sized to text
--   divider      no label                                    row 330, centred
--
-- Three different row widths and one widget with its label on the other side of
-- its control, stacked in a layout frame that centres what it is given. Nothing
-- lines up with anything.
--
-- This pass gives all of them the same label column, the same control column and
-- the same row width, and turns the checkbox around to match the rest. Every
-- label then starts at the same x and every control starts at the same x, which
-- is the whole of the difference.
--
-- There is no per-setting way to ask for this: a SettingObject carries kind,
-- name, desc, default, get, set, disabled and hidden, and nothing about layout.
-- The widgets come from pools reachable at LibEditMode.internal:GetPool(kind),
-- so the pool's Acquire is wrapped and each widget is measured once, the first
-- time it is handed out. Nothing in the library itself is modified, so it can
-- still be updated from upstream without carrying a patch forward.
--
-- Note this reaches a shared library. Anything else loading the same LibStub
-- copy of LibEditMode draws its dialog with these metrics too. That is a
-- deliberate trade for one consistent dialog across the collection, and it is
-- cosmetic - no behaviour changes. Loading LibEditMode namespaced instead would
-- contain it to this addon, at the cost of a private copy per addon.
--------------------------------------------------------------------------------

local LibEditMode = LibStub and LibStub("LibEditMode", true)

local PeaversCommons = _G.PeaversCommons
local EditModeStyle = {}
PeaversCommons.EditModeStyle = EditModeStyle

-- The grid. The label column is wide enough for the longest label the unit
-- frames use ("Limit Debuffs To", "Background Opacity") without wrapping, and
-- the control column is the 200 the library's own sliders and dropdowns are
-- built at, so nothing has to be resized to fit.
local LABEL_WIDTH = 150
local CONTROL_WIDTH = 200
local GAP = 5
local ROW_WIDTH = LABEL_WIDTH + GAP + CONTROL_WIDTH
local ROW_HEIGHT = 32

-- Sliders need a narrower control than everything else, because their value box
-- is not inside the control.
--
--   MinimalSliderWithSteppersTemplate
--     Slider     TOPLEFT x=19, BOTTOMRIGHT x=-19   (inset for the arrows)
--     RightText  LEFT of Slider RIGHT, x=25
--
-- The inner slider is already inset 19, so the value text starts six pixels
-- past the widget's own right edge and then runs on for its own width. At the
-- library's default of 200 in a 355 row that put the numbers outside the dialog
-- entirely. The slider is narrowed to leave that overhang a column to sit in.
local VALUE_GUTTER = 52
local SLIDER_WIDTH = CONTROL_WIDTH - VALUE_GUTTER

-- A little more air between rows than the library's default of 2. At thirty-odd
-- settings the difference between 2 and 4 is the difference between a list and a
-- wall.
local ROW_SPACING = 4

--------------------------------------------------------------------------------
-- Per-widget layout
--------------------------------------------------------------------------------

local function LayoutLabel(label)
    if not label then return end
    label:ClearAllPoints()
    label:SetPoint("LEFT")
    label:SetSize(LABEL_WIDTH, ROW_HEIGHT)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
end

-- Anchor a control into the column to the right of the label.
local function LayoutControl(control, label)
    if not control or not label then return end
    control:ClearAllPoints()
    control:SetPoint("LEFT", label, "RIGHT", GAP, 0)
end

local Layouts = {}

-- The odd one out. Blizzard's template anchors the check button at the far left
-- and hangs a 300-wide label off its right, which is the reverse of every other
-- row. Turning it around is what stops the checkbox labels sitting in their own
-- column half an inch right of everything else.
function Layouts.checkbox(frame)
    LayoutLabel(frame.Label)
    LayoutControl(frame.Button, frame.Label)
    -- The template pads its width by -5 to allow for the button hanging off the
    -- left edge. With the button moved inboard that padding is just a gap.
    frame.widthPadding = 0
    frame.fixedWidth = ROW_WIDTH
end

function Layouts.slider(frame)
    LayoutLabel(frame.Label)
    -- Not a ResizeLayoutFrame - the template is a plain frame with a hard 343
    -- width, so it is set rather than driven by fixedWidth.
    frame:SetWidth(ROW_WIDTH)
    if frame.Slider then
        frame.Slider:SetWidth(SLIDER_WIDTH)
        LayoutControl(frame.Slider, frame.Label)
    end
end

function Layouts.dropdown(frame)
    LayoutLabel(frame.Label)
    if frame.Dropdown then
        frame.Dropdown:SetWidth(CONTROL_WIDTH)
        LayoutControl(frame.Dropdown, frame.Label)
    end
    frame.fixedWidth = ROW_WIDTH
end

function Layouts.colorpicker(frame)
    LayoutLabel(frame.Label)
    LayoutControl(frame.Swatch, frame.Label)
    frame.fixedWidth = ROW_WIDTH
end

-- Section headers.
--
-- The library centres these and prints them in the same font as a setting
-- label, which makes them read as another row rather than as a break between
-- groups - and centred, they are the only thing in the dialog not aligned to
-- the left edge. They now sit in the label column like everything else, in the
-- gold heading font, on a faint bar that gives the eye something to catch.
--
-- The library's own rule texture is left alone but made invisible rather than
-- hidden, because the expander re-shows it on every toggle and would undo a
-- Hide. Alpha it cannot see.
function Layouts.expander(frame)
    frame:SetWidth(ROW_WIDTH)

    if frame.Divider then
        frame.Divider:SetAlpha(0)
    end

    if not frame.peaversHeaderBar then
        local bar = frame:CreateTexture(nil, "BACKGROUND")
        bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -4)
        bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 2)
        bar:SetColorTexture(1, 1, 1, 0.07)
        frame.peaversHeaderBar = bar
    end

    local label = frame.Label
    if label then
        label:ClearAllPoints()
        label:SetPoint("LEFT", frame, "LEFT", 8, -1)
        label:SetWidth(ROW_WIDTH - 16)
        label:SetJustifyH("LEFT")
        label:SetJustifyV("MIDDLE")
        label:SetFontObject("GameFontNormalMedium")
    end
end

function Layouts.divider(frame)
    frame:SetWidth(ROW_WIDTH)
end

-- The dialog's buttons come from two different Blizzard templates - the settings
-- "Reset to default" from one, the extra buttons from another - and they are
-- built at different widths, so the stack at the bottom of the dialog ended up
-- with one narrow left-aligned button above two full-width ones. Same width for
-- all of them.
function Layouts.button(frame)
    frame:SetWidth(ROW_WIDTH)
    frame.align = "center"
end

--------------------------------------------------------------------------------
-- Application
--------------------------------------------------------------------------------

-- Widgets are pooled and reused, and the pool's resetter does not undo anchors,
-- so each one only needs measuring the first time it is handed out.
local function Wrap(pool, layout)
    if not pool or pool.peaversStyled then return end
    pool.peaversStyled = true

    local Acquire = pool.Acquire
    pool.Acquire = function(self, parent)
        local widget, isNew = Acquire(self, parent)
        if widget and not widget.peaversLaidOut then
            widget.peaversLaidOut = true
            pcall(layout, widget)
        end
        return widget, isNew
    end
end

-- The dialog itself is built once, on the first AddFrame, so its own furniture
-- is squared up directly rather than through a pool.
local function StyleDialog(internal)
    local dialog = internal.dialog
    if not dialog or dialog.peaversStyled then return end
    dialog.peaversStyled = true

    local settings = dialog.Settings
    if settings then
        settings.spacing = ROW_SPACING
        if settings.Divider then
            settings.Divider:SetSize(ROW_WIDTH, 16)
        end
        -- Lives in the settings list rather than the button block below it, so
        -- it is the one button the button pool never sees.
        if settings.ResetButton then
            Layouts.button(settings.ResetButton)
        end
    end

    if dialog.Buttons then
        dialog.Buttons.spacing = ROW_SPACING
    end
end

-- Called once, after the frames have been registered - registration is what
-- creates the dialog and, through it, nothing else; the pools are created when
-- the widget files load, which is well before this.
function EditModeStyle:Apply()
    if not LibEditMode then return false end

    local internal = LibEditMode.internal
    if not internal or not internal.GetPool then return false end

    local ST = LibEditMode.SettingType
    local byKind = {
        [ST.Checkbox] = Layouts.checkbox,
        [ST.Slider] = Layouts.slider,
        [ST.Dropdown] = Layouts.dropdown,
        [ST.ColorPicker] = Layouts.colorpicker,
        [ST.Expander] = Layouts.expander,
        [ST.Divider] = Layouts.divider,
        -- Not a SettingType; the library keys the button pool by this string.
        button = Layouts.button,
    }

    for kind, layout in pairs(byKind) do
        if kind ~= nil then
            Wrap(internal:GetPool(kind), layout)
        end
    end

    StyleDialog(internal)

    return true
end

return EditModeStyle
