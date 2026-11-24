-- PeaversCommons EditModePanel Module
--
-- A settings panel that opens beside the Edit Mode dialog, one group at a time.
--
-- The dialog Blizzard's Edit Mode opens is a vertical layout frame with no
-- scroll bar: it grows until it runs off the bottom of the screen. That caps
-- what can honestly be put in it at roughly a dozen rows. So the dialog keeps
-- only what you reach for while dragging a frame - whether it is on, and how
-- big - and every other group becomes a button that opens this, which scrolls.
--
-- It is drawn with Blizzard's own Edit Mode controls - the same check box,
-- stepper slider, dropdown and colour swatch the dialog is made of - on the
-- same grid, inside the same border. It used to be drawn with the collection's
-- own widgets, which put two visual languages side by side: Blizzard's dialog
-- and, one click away, a flat dark panel that looked like it had wandered in
-- from the settings window. Everything in Edit Mode now looks like Edit Mode.
--
-- The rows are built here rather than borrowed from LibEditMode's pools. The
-- library releases every pooled widget whenever its dialog redraws - which it
-- does each time a frame is dropped - and its widgets report changes to their
-- grandparent, assuming that is the dialog. Neither survives being put in a
-- second window. What is shared is the templates, which is where the look
-- comes from.

local PeaversCommons = _G.PeaversCommons
local EditModePanel = {}
PeaversCommons.EditModePanel = EditModePanel

local FrameUtils = PeaversCommons.FrameUtils

-- One grid for the dialog and the panel. EditModeStyle owns the numbers; the
-- fallbacks are the same numbers, for the case where it failed to load.
local Metrics = (PeaversCommons.EditModeStyle and PeaversCommons.EditModeStyle.Metrics) or {}
local LABEL_WIDTH = Metrics.labelWidth or 150
local CONTROL_WIDTH = Metrics.controlWidth or 200
local GAP = Metrics.gap or 5
local ROW_WIDTH = LABEL_WIDTH + GAP + CONTROL_WIDTH
local ROW_HEIGHT = Metrics.rowHeight or 32
local ROW_SPACING = Metrics.rowSpacing or 4
local SLIDER_WIDTH = Metrics.sliderWidth or 148

-- The scroll bar gets a gutter of its own rather than sitting over the rows.
local LEFT_INSET = 20
local SCROLL_GUTTER = 28
local PANEL_WIDTH = LEFT_INSET + ROW_WIDTH + SCROLL_GUTTER

local HEADER_HEIGHT = 40
local FOOTER_HEIGHT = 14
local MAX_HEIGHT = 520
local MIN_HEIGHT = 120
local PANEL_GAP = 12

local DIVIDER_HEIGHT = 16
local NUMBER_WIDTH = 80

--------------------------------------------------------------------------------
-- Rows
--
-- Each kind of row is a label in the left column and one Blizzard control in
-- the right. A row is told what to show by Setup and reports a change through
-- row.commit, and knows nothing else about schemas or settings.
--------------------------------------------------------------------------------

local function ShowTooltip(self)
    if not self.desc or self.desc == "" then return end

    local tooltip = rawget(_G, "SettingsTooltip") or GameTooltip
    tooltip:SetOwner(self, "ANCHOR_NONE")
    tooltip:SetPoint("BOTTOMRIGHT", self, "TOPLEFT")
    tooltip:SetText(self.title or "", 1, 1, 1)
    tooltip:AddLine(self.desc, nil, nil, nil, true)
    tooltip:Show()
end

local function HideTooltip()
    local tooltip = rawget(_G, "SettingsTooltip") or GameTooltip
    tooltip:Hide()
end

local function SetLabelEnabled(row, enabled)
    local color = enabled and WHITE_FONT_COLOR or DISABLED_FONT_COLOR
    row.Label:SetTextColor(color:GetRGB())
end

local function NewRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(ROW_WIDTH, ROW_HEIGHT)
    -- For the tooltip. Not every client turns the mouse on for a frame just
    -- because it was given an OnEnter.
    row:EnableMouse(true)
    row:SetScript("OnEnter", ShowTooltip)
    row:SetScript("OnLeave", HideTooltip)

    local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    label:SetPoint("LEFT")
    label:SetSize(LABEL_WIDTH, ROW_HEIGHT)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    row.Label = label

    return row
end

local Factories = {}

----------------------------------------------------------------- checkbox ---

-- EditModeSettingCheckboxTemplate's button, without the template: the template
-- carries a mixin that reports to Blizzard's own dialog, and its label hangs
-- off the right of the box where every other row has it on the left.
function Factories.checkbox(parent)
    local row = NewRow(parent)

    local button = CreateFrame("CheckButton", nil, row)
    button:SetSize(32, 32)
    button:SetPoint("LEFT", row.Label, "RIGHT", GAP, 0)
    button:SetNormalTexture([[Interface\Buttons\UI-CheckBox-Up]])
    button:SetPushedTexture([[Interface\Buttons\UI-CheckBox-Down]])
    button:SetHighlightTexture([[Interface\Buttons\UI-CheckBox-Highlight]], "ADD")
    button:SetCheckedTexture([[Interface\Buttons\UI-CheckBox-Check]])
    button:SetDisabledCheckedTexture([[Interface\Buttons\UI-CheckBox-Check-Disabled]])
    button:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        if row.commit then row.commit(self:GetChecked() and true or false) end
    end)
    row.Button = button

    function row:Setup(value)
        self.Button:SetChecked(value and true or false)
    end

    function row:SetEnabled(enabled)
        self.Button:SetEnabled(enabled)
        SetLabelEnabled(self, enabled)
    end

    return row
end

------------------------------------------------------------------- slider ---

-- A slider hands back whatever fraction the thumb landed on. Stored as it
-- comes, a step of 0.05 turns into 0.30000000000000004 in the saved variables.
local function Quantise(value, min, step)
    if step and step > 0 then
        value = min + math.floor((value - min) / step + 0.5) * step
    end
    return math.floor(value * 10000 + 0.5) / 10000
end

local function SliderEditReset(editBox)
    local row = editBox:GetParent()
    row.Slider:Show()

    editBox:SetText("")
    editBox:ClearFocus()

    editBox:ClearAllPoints()
    editBox:SetPoint("TOPLEFT", row.Slider.RightText)
    editBox:SetPoint("BOTTOMLEFT", row.Slider.RightText)
    editBox:SetPoint("RIGHT", row.Slider.RightText, 5, 0)
end

-- MinimalSliderWithSteppersTemplate, which is what Blizzard's slider row is,
-- plus the typed-value box LibEditMode adds to the dialog's sliders: click the
-- number and it becomes an input, because no amount of dragging lands on 137.
function Factories.slider(parent)
    local row = NewRow(parent)

    local slider = CreateFrame("Frame", nil, row, "MinimalSliderWithSteppersTemplate")
    slider:SetSize(SLIDER_WIDTH, ROW_HEIGHT)
    slider:SetPoint("LEFT", row.Label, "RIGHT", GAP, 0)
    if slider.MinText then slider.MinText:Hide() end
    if slider.MaxText then slider.MaxText:Hide() end
    row.Slider = slider

    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        if row.initialising or not row.commit then return end

        value = Quantise(value, row.min, row.step)
        if value ~= row.value then
            row.value = value
            row.commit(value)
        end
    end, row)

    local editBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    editBox:SetAutoFocus(false)
    editBox:SetJustifyH("CENTER")
    editBox:SetScript("OnEditFocusGained", function(self)
        row.Slider:Hide()

        -- Grow over the slider, so there is room to type.
        self:ClearAllPoints()
        self:SetPoint("RIGHT", row.Slider.RightText, 5, 0)
        self:SetPoint("TOPLEFT", row.Slider)
        self:SetPoint("BOTTOMLEFT", row.Slider)

        self:SetText(tostring(row.value or ""))
        self:SetCursorPosition(0)
    end)
    editBox:SetScript("OnEnterPressed", function(self)
        local entered = tonumber(self:GetText())
        if entered then
            row.Slider:SetValue(math.min(math.max(entered, row.min), row.max))
        end
        self:ClearFocus()
    end)
    editBox:SetScript("OnEscapePressed", SliderEditReset)
    editBox:SetScript("OnEditFocusLost", SliderEditReset)
    row.EditBox = editBox
    SliderEditReset(editBox)

    function row:Setup(value, min, max, step, formatter)
        self.min, self.max, self.step = min, max, step
        self.value = value

        local formatters = {
            [MinimalSliderWithSteppersMixin.Label.Right] =
                CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter),
        }

        -- Init reports the value it was just given as a change.
        self.initialising = true
        self.Slider:Init(value, min, max, (max - min) / step, formatters)
        self.initialising = false
    end

    function row:SetEnabled(enabled)
        self.Slider:SetEnabled(enabled)
        self.EditBox:SetShown(enabled)
        SetLabelEnabled(self, enabled)
    end

    return row
end

----------------------------------------------------------------- dropdown ---

function Factories.dropdown(parent)
    local row = NewRow(parent)

    local dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
    dropdown:SetSize(CONTROL_WIDTH, 30)
    dropdown:SetPoint("LEFT", row.Label, "RIGHT", GAP, 0)
    row.Dropdown = dropdown

    -- options: a list of { value, label }; menuHeight scrolls a long one.
    function row:Setup(value, options, menuHeight)
        self.value = value

        local function IsSelected(candidate)
            return self.value == candidate
        end

        local function Select(candidate)
            self.value = candidate
            if self.commit then self.commit(candidate) end
        end

        -- A fresh generator each time, which is also what makes the button
        -- redraw its text for a row that has been handed a different setting.
        self.Dropdown:SetupMenu(function(_, root)
            if menuHeight then
                root:SetScrollMode(menuHeight)
            end
            for _, option in ipairs(options) do
                root:CreateRadio(option.label, IsSelected, Select, option.value)
            end
        end)
    end

    function row:SetEnabled(enabled)
        self.Dropdown:SetEnabled(enabled)
        SetLabelEnabled(self, enabled)
    end

    return row
end

-------------------------------------------------------------------- color ---

local function OpenColorPicker(swatch)
    local row = swatch:GetParent()
    local value = row.value or {}
    local before = { r = value.r or 1, g = value.g or 1, b = value.b or 1 }

    -- The picker outlives the click. If the panel has been redrawn underneath
    -- it, this row may now be showing a different setting, and a colour meant
    -- for the old one must not land on the new one.
    local token = row.token

    local function Apply(r, g, b)
        if row.token ~= token then return end
        row.value = { r = r, g = g, b = b }
        row.Swatch:SetColorRGB(r, g, b)
        if row.commit then row.commit(row.value) end
    end

    ColorPickerFrame:SetupColorPickerAndShow({
        r = before.r, g = before.g, b = before.b,
        hasOpacity = false,
        swatchFunc = function()
            Apply(ColorPickerFrame:GetColorRGB())
        end,
        cancelFunc = function()
            Apply(before.r, before.g, before.b)
        end,
    })
end

function Factories.color(parent)
    local row = NewRow(parent)

    local swatch = CreateFrame("Button", nil, row, "ColorSwatchTemplate")
    swatch:SetSize(32, 32)
    swatch:SetPoint("LEFT", row.Label, "RIGHT", GAP, 0)
    swatch:SetScript("OnClick", OpenColorPicker)
    row.Swatch = swatch

    function row:Setup(value)
        value = value or {}
        self.value = { r = value.r or 1, g = value.g or 1, b = value.b or 1 }
        self.Swatch:SetColorRGB(self.value.r, self.value.g, self.value.b)
    end

    function row:SetEnabled(enabled)
        self.Swatch:SetEnabled(enabled)
        SetLabelEnabled(self, enabled)
    end

    return row
end

-------------------------------------------------------------------- input ---

-- The one row the dialog has no answer for: a typed value. The numeric form is
-- what makes exact offsets possible.
function Factories.input(parent)
    local row = NewRow(parent)

    local editBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    editBox:SetHeight(22)
    -- The template draws its left cap five pixels outside the box.
    editBox:SetPoint("LEFT", row.Label, "RIGHT", GAP + 6, 0)
    editBox:SetAutoFocus(false)
    row.EditBox = editBox

    local function Commit()
        local text = editBox:GetText()

        if not row.numeric then
            if text ~= row.value then
                row.value = text
                if row.commit then row.commit(text) end
            end
            return
        end

        local entered = tonumber(text)
        if not entered then
            -- Not a number: put back what is actually stored rather than
            -- leaving the box showing something that was never applied.
            editBox:SetText(tostring(row.value or 0))
            return
        end

        entered = math.floor(entered + 0.5)
        editBox:SetText(tostring(entered))
        if entered ~= row.value then
            row.value = entered
            if row.commit then row.commit(entered) end
        end
    end

    -- Enter also clears focus, so both fire; the second finds nothing changed.
    editBox:SetScript("OnEnterPressed", function(self)
        Commit()
        self:ClearFocus()
    end)
    editBox:SetScript("OnEditFocusLost", Commit)
    editBox:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(row.value or (row.numeric and 0 or "")))
        self:ClearFocus()
    end)

    function row:Setup(value, numeric)
        self.numeric = numeric
        if numeric then
            self.value = tonumber(value) or 0
        else
            self.value = value ~= nil and tostring(value) or ""
        end

        self.EditBox:SetWidth(numeric and NUMBER_WIDTH or (CONTROL_WIDTH - 12))
        self.EditBox:SetText(tostring(self.value))
        self.EditBox:SetCursorPosition(0)
    end

    function row:SetEnabled(enabled)
        self.EditBox:SetEnabled(enabled)
        SetLabelEnabled(self, enabled)
    end

    return row
end

------------------------------------------------------------------ divider ---

-- The rule the dialog draws between its settings and its buttons.
function Factories.divider(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(ROW_WIDTH, DIVIDER_HEIGHT)
    row.height = DIVIDER_HEIGHT

    local texture = row:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints()
    texture:SetTexture([[Interface\FriendsFrame\UI-FriendsFrame-OnlineDivider]])

    return row
end

--------------------------------------------------------------------------------
-- Pools
--
-- A frame cannot be destroyed, and the panel is redrawn every time a group is
-- opened or a setting reveals others, so rows are handed back and reused
-- rather than made again.
--------------------------------------------------------------------------------

local pools = {}

local function Acquire(kind, parent)
    local pool = pools[kind]
    if not pool then
        pool = { free = {}, used = {} }
        pools[kind] = pool
    end

    local row = table.remove(pool.free)
    if not row then
        -- A template missing on this client costs that one row, not the panel.
        -- The reason is kept, because "a row is missing" is otherwise all
        -- anyone has to go on.
        local ok, created = pcall(Factories[kind], parent)
        if not ok or not created then
            EditModePanel.lastError = kind .. ": " .. tostring(created)
            return nil
        end
        row = created
    end

    pool.used[#pool.used + 1] = row
    return row
end

local function ReleaseAll()
    for _, pool in pairs(pools) do
        for index = #pool.used, 1, -1 do
            local row = pool.used[index]
            row:Hide()
            row:ClearAllPoints()
            row.commit = nil
            -- Anything still holding this row - an open colour picker - is now
            -- holding a stale one.
            row.token = (row.token or 0) + 1
            pool.free[#pool.free + 1] = row
            pool.used[index] = nil
        end
    end
end

--------------------------------------------------------------------------------
-- The frame
--------------------------------------------------------------------------------

local function Build()
    local panel = CreateFrame("Frame", "PeaversEditModePanel", UIParent)
    panel:SetSize(PANEL_WIDTH, MAX_HEIGHT)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(400)
    panel:EnableMouse(true)
    panel:Hide()

    -- The dialog's own furniture: its border, its title font, its close button.
    local border = CreateFrame("Frame", nil, panel, "DialogBorderTranslucentTemplate")
    border:SetAllPoints()
    panel.Border = border

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -15)
    -- Clear of the close button, and one line: "Peavers Consumable Bar - What
    -- To Show" is as long as these get.
    title:SetWidth(PANEL_WIDTH - 70)
    title:SetWordWrap(false)
    panel.Title = title

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() EditModePanel:Hide() end)
    panel.Close = close

    local scrollBox, content, scrollBar = FrameUtils.CreateScrollBox(panel, {
        inset = LEFT_INSET,
        gutter = SCROLL_GUTTER,
        top = -HEADER_HEIGHT,
        bottom = FOOTER_HEIGHT,
    })

    -- CreateScrollBox declines rather than errors if the modern scroll
    -- templates are not there. The older frame is worse - its bar overlaps the
    -- content - but a panel that scrolls badly beats a panel that does not open.
    if not scrollBox then
        local host = CreateFrame("Frame", nil, panel)
        host:SetPoint("TOPLEFT", LEFT_INSET, -HEADER_HEIGHT)
        host:SetPoint("BOTTOMRIGHT", 0, FOOTER_HEIGHT)

        local legacyScroll, legacyContent = FrameUtils.CreateScrollFrame(host)
        panel.LegacyScroll = legacyScroll
        content = legacyContent
    end

    panel.ScrollBox = scrollBox
    panel.ScrollBar = scrollBar
    panel.Content = content
    content:SetWidth(ROW_WIDTH)

    return panel
end

local function GetPanel()
    if not EditModePanel.frame then
        EditModePanel.frame = Build()
    end
    return EditModePanel.frame
end

--------------------------------------------------------------------------------
-- Drawing a group
--------------------------------------------------------------------------------

-- Which choice a selector group is currently showing, remembered per group so
-- that closing the panel and reopening it lands back on the same one.
local selection = {}

local function Resolve(value, ...)
    if type(value) == "function" then return value(...) end
    return value
end

-- The context a group's settings are read and written against: normally the
-- registration's own (a unit, say), but a selector group's is whatever its
-- dropdown is pointing at.
local function ContextFor(spec)
    if not spec.selector then return spec.context end

    local current = selection[spec.key]
    if current ~= nil then return current end

    local values = Resolve(spec.selector.values) or {}
    local default = Resolve(spec.selector.default)
    if default == nil then
        default = values[1] and values[1].value
    end

    selection[spec.key] = default
    return default
end

-- A redraw is asked for from inside a control's own click handler - a dropdown
-- mid-selection, a check box mid-click - and rebuilding the row it lives in
-- before that handler has returned is asking for trouble. It waits a frame.
local refreshQueued = false

local function QueueRefresh()
    if refreshQueued then return end
    refreshQueued = true

    C_Timer.After(0, function()
        refreshQueued = false
        EditModePanel:Refresh()
    end)
end

-- What each kind of setting is drawn with, and how it is filled in.
local Kinds = {}

function Kinds.checkbox(row, _, _, value)
    row:Setup(value)
end

function Kinds.slider(row, schema, entry, value)
    local min = entry.min or 0
    local max = entry.max or 1
    local step = entry.step or 1
    row:Setup(value or min, min, max, step, schema:Formatter(entry))
end

function Kinds.dropdown(row, schema, entry, value)
    row:Setup(value, schema:Values(entry), entry.height)
end

function Kinds.color(row, _, _, value)
    row:Setup(value)
end

function Kinds.text(row, _, _, value)
    row:Setup(value, false)
end

function Kinds.number(row, _, _, value)
    row:Setup(value, true)
end

local ROW_FOR_KIND = {
    checkbox = "checkbox",
    slider = "slider",
    dropdown = "dropdown",
    color = "color",
    text = "input",
    number = "input",
}

local function Render(panel, spec)
    local content = panel.Content
    local schema = spec.schema
    local context = ContextFor(spec)

    ReleaseAll()

    local y = -4

    local function Place(row)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        row:Show()
        y = y - (row.height or ROW_HEIGHT) - ROW_SPACING
    end

    -- The selector sits above the settings it governs, because it decides what
    -- they mean.
    if spec.selector then
        local row = Acquire("dropdown", content)
        if row then
            row.title = spec.selector.label or "Adjust"
            row.desc = nil
            row.Label:SetText(row.title)
            row:Setup(context, Resolve(spec.selector.values) or {})
            row:SetEnabled(true)
            row.commit = function(value)
                selection[spec.key] = value
                QueueRefresh()
            end
            Place(row)
        end

        local divider = Acquire("divider", content)
        if divider then Place(divider) end
    end

    for _, entry in ipairs(spec.entries) do
        local kind = ROW_FOR_KIND[entry.kind]

        if kind and not schema:IsHidden(entry, context) then
            local row = Acquire(kind, content)

            if row then
                row.title = entry.label or ""
                row.desc = entry.desc
                row.Label:SetText(row.title)

                -- These panels are the only place most of these settings can
                -- be changed, so a row that cannot be filled in costs that row
                -- and is drawn blank, rather than taking the rest of the group
                -- down with it.
                local ok, problem = pcall(function()
                    Kinds[entry.kind](row, schema, entry, schema:Read(entry, context))
                    row:SetEnabled(not schema:IsDisabled(entry, context))
                end)
                if not ok then
                    EditModePanel.lastError = tostring(entry.key) .. ": " .. tostring(problem)
                end

                row.commit = function(value)
                    schema:Write(entry, context, value)

                    -- Only settings that change which *other* settings apply
                    -- force a redraw. Doing it on every write would rebuild the
                    -- panel under the cursor at every step of a slider.
                    if entry.revealsOthers then
                        QueueRefresh()
                    end
                end

                Place(row)
            end
        end
    end

    local used = math.abs(y) + 4
    content:SetWidth(ROW_WIDTH)
    content:SetHeight(used)

    local height = used + HEADER_HEIGHT + FOOTER_HEIGHT
    panel:SetHeight(math.max(MIN_HEIGHT, math.min(MAX_HEIGHT, height)))

    -- Re-measure once the panel is its final height, or the scroll box is still
    -- working from the previous group's extent and the bar shows when it should
    -- not.
    FrameUtils.UpdateScrollBox(panel.ScrollBox, panel.ScrollBar)
end

--------------------------------------------------------------------------------
-- Placement
--
-- To the right of the dialog by preference, flipped to the left when there is
-- no room - the Edit Mode dialog is itself draggable, so it can be anywhere.
--------------------------------------------------------------------------------

-- Whether the panel, hung off the right of the dialog, would sit on top of the
-- frame being edited. The dialog stands beside that frame, so when it is on the
-- frame's left its right-hand side is exactly where the frame is.
local function WouldCover(panel, anchorTo, avoid, panelLeft)
    local Snap = PeaversCommons.EditModeSnap
    local rect = avoid and Snap and Snap.RectOf and Snap.RectOf(avoid)
    local top = anchorTo:GetTop()
    if not rect or not top then return false end

    local bottom = top - (panel:GetHeight() or MAX_HEIGHT)

    return rect.left < panelLeft + PANEL_WIDTH and rect.right > panelLeft
        and rect.bottom < top and rect.top > bottom
end

local function Anchor(panel, anchorTo, avoid)
    panel:ClearAllPoints()

    if not anchorTo or not anchorTo:IsShown() then
        panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        return
    end

    local left, right = anchorTo:GetLeft(), anchorTo:GetRight()
    local edge = UIParent:GetRight()
    local fitsRight = right and edge and ((right + PANEL_GAP + PANEL_WIDTH) <= edge)
    local fitsLeft = left and ((left - PANEL_GAP - PANEL_WIDTH) >= 0)

    -- Settings are judged by looking at the frame, so the panel gives way to it
    -- when it has somewhere else to go.
    if fitsRight and fitsLeft and WouldCover(panel, anchorTo, avoid, right + PANEL_GAP) then
        fitsRight = false
    end

    if fitsRight then
        panel:SetPoint("TOPLEFT", anchorTo, "TOPRIGHT", PANEL_GAP, 0)
    else
        panel:SetPoint("TOPRIGHT", anchorTo, "TOPLEFT", -PANEL_GAP, 0)
    end
end

--------------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------------

-- spec:
--   title     what to head the panel with
--   schema    a SettingsSchema
--   context   passed through to the schema, for per-thing configs
--   entries   the group's entries, in order
--   selector  optional { label, values, default }: a dropdown above the group
--             whose choice replaces the context
--   anchorTo  the Edit Mode dialog this hangs off
--   avoid     the frame being edited, which the panel keeps off when it can
--   key       identifies the open group, so clicking it again closes it
--   owner     identifies whose settings these are - a frame, or a system key -
--             so the panel can be shut when something else is selected
function EditModePanel.Show(_, spec)
    if not spec or not spec.schema or not spec.entries then return false end
    if InCombatLockdown() then return false end

    local panel = GetPanel()

    -- Clicking the group that is already open closes it, which is the only way
    -- back to a bare dialog without hunting for the close button.
    if panel:IsShown() and EditModePanel.openKey == spec.key then
        EditModePanel:Hide()
        return false
    end

    EditModePanel.openKey = spec.key
    EditModePanel.spec = spec

    panel.Title:SetText(spec.title or "")
    Render(panel, spec)
    Anchor(panel, spec.anchorTo, spec.avoid)
    panel:Show()

    return true
end

-- Redraw whatever is open, in place. Used when a setting changes which other
-- settings apply.
function EditModePanel.Refresh(_)
    local panel = EditModePanel.frame
    if not panel or not panel:IsShown() or not EditModePanel.spec then return end

    Render(panel, EditModePanel.spec)
    Anchor(panel, EditModePanel.spec.anchorTo, EditModePanel.spec.avoid)
end

function EditModePanel.Hide(_)
    EditModePanel.openKey = nil
    EditModePanel.spec = nil
    if EditModePanel.frame then
        EditModePanel.frame:Hide()
    end
end

function EditModePanel.IsShown(_)
    return EditModePanel.frame and EditModePanel.frame:IsShown() or false
end

-- Whose settings are showing, or nil when the panel is shut.
function EditModePanel.Owner(_)
    if not EditModePanel:IsShown() or not EditModePanel.spec then return nil end
    return EditModePanel.spec.owner
end

return EditModePanel
