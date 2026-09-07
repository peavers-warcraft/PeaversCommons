-- PeaversCommons EditModePanel Module
--
-- A settings panel that opens beside the Edit Mode dialog, one group at a time.
--
-- The dialog Blizzard's Edit Mode opens is a vertical layout frame with no
-- scroll bar: it grows until it runs off the bottom of the screen. That caps
-- what can honestly be put in it at roughly a dozen rows, which is why the
-- collection's settings were split between it and the settings page, and why
-- the ones that stayed behind were the ones needing room to explain themselves.
--
-- So the dialog keeps only what you reach for while dragging a frame - whether
-- it is on, and how big - and every other group becomes a button that opens
-- this. It is our frame, so it has the three things the dialog does not: it
-- scrolls, it can hold any widget the collection has (text inputs included),
-- and it is wide enough to read.
--
-- It is drawn with PeaversCommons.Widgets, so a setting looks the same here as
-- on the settings page, and it borrows Blizzard's dialog border so it reads as
-- part of Edit Mode rather than as a window that wandered in.

local PeaversCommons = _G.PeaversCommons
local EditModePanel = {}
PeaversCommons.EditModePanel = EditModePanel

local W = PeaversCommons.Widgets
local FrameUtils = PeaversCommons.FrameUtils

local PANEL_WIDTH = 400
local MAX_HEIGHT = 520
local MIN_HEIGHT = 120
local GAP = 12
local INDENT = 14

-- The scroll bar gets a gutter of its own rather than sitting over the content.
-- Widget widths are derived from what is left, so a dropdown's arrow is never
-- underneath the bar.
local LEFT_INSET = 12
local SCROLL_GUTTER = 26
local CONTENT_WIDTH = PANEL_WIDTH - LEFT_INSET - SCROLL_GUTTER
local WIDGET_WIDTH = CONTENT_WIDTH - (INDENT * 2)

-- Row heights, matched to the settings page so the two surfaces feel like one.
local ROW = 30
local ROW_DESC = 42
local SLIDER = 52
local DROPDOWN = 58
local INPUT = 52

--------------------------------------------------------------------------------
-- The frame
--------------------------------------------------------------------------------

local function Build()
    local panel = CreateFrame("Frame", "PeaversEditModePanel", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_WIDTH, MAX_HEIGHT)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(400)
    panel:Hide()

    -- Blizzard's own dialog border, so this reads as part of Edit Mode.
    local border = CreateFrame("Frame", nil, panel, "DialogBorderTranslucentTemplate")
    border:SetAllPoints(panel)
    panel.Border = border

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -15)
    panel.Title = title

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() EditModePanel:Hide() end)
    panel.Close = close

    local scrollBox, content, scrollBar = FrameUtils.CreateScrollBox(panel, {
        inset = LEFT_INSET,
        gutter = SCROLL_GUTTER,
        top = -40,
        bottom = 10,
    })

    -- CreateScrollBox declines rather than errors if the modern scroll
    -- templates are not there. The older frame is worse - its bar overlaps the
    -- content - but a panel that scrolls badly beats a panel that does not open.
    if not scrollBox then
        local host = CreateFrame("Frame", nil, panel)
        host:SetPoint("TOPLEFT", 0, -40)
        host:SetPoint("BOTTOMRIGHT", 0, 8)

        local legacyScroll, legacyContent = FrameUtils.CreateScrollFrame(host)
        panel.LegacyScroll = legacyScroll
        content = legacyContent
    end

    panel.ScrollBox = scrollBox
    panel.ScrollBar = scrollBar
    panel.Content = content
    content:SetWidth(CONTENT_WIDTH)

    panel:EnableMouse(true)

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

local function Render(panel, spec)
    local content = panel.Content
    local schema, context = spec.schema, spec.context

    -- Widgets are placed at fixed offsets rather than laid out, so a redraw
    -- means starting from an empty frame.
    for _, child in ipairs({ content:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    for _, region in ipairs({ content:GetRegions() }) do
        region:Hide()
        region:SetParent(nil)
    end

    local width = WIDGET_WIDTH
    local y = -8

    local function Place(widget, height)
        widget:SetPoint("TOPLEFT", INDENT, y)
        y = y - height
    end

    local function Commit(entry, value)
        schema:Write(entry, context, value)

        -- Only settings that change which *other* settings apply force a
        -- redraw. Doing it on every write would rebuild the panel under the
        -- user's cursor at every step of a slider.
        if entry.revealsOthers then
            EditModePanel:Refresh()
        end
    end

    for _, entry in ipairs(spec.entries) do
        if not schema:IsHidden(entry, context) then
            local value = schema:Read(entry, context)

            if entry.kind == "checkbox" then
                Place(W:CreateCheckbox(content, entry.label, {
                    checked = value and true or false,
                    width = width,
                    description = entry.desc,
                    onChange = function(checked) Commit(entry, checked) end,
                }), entry.desc and ROW_DESC or ROW)

            elseif entry.kind == "slider" then
                Place(W:CreateSlider(content, entry.label, {
                    min = entry.min, max = entry.max, step = entry.step,
                    value = value or entry.min,
                    width = width,
                    format = schema:Formatter(entry),
                    onChange = function(v) Commit(entry, v) end,
                }), SLIDER)

            elseif entry.kind == "dropdown" then
                Place(W:CreateDropdown(content, entry.label, {
                    options = schema:Values(entry),
                    selected = value,
                    width = width,
                    onChange = function(v) Commit(entry, v) end,
                }), DROPDOWN)

            elseif entry.kind == "color" then
                local c = value or {}
                Place(W:CreateColorPicker(content, entry.label, {
                    r = c.r or 1, g = c.g or 1, b = c.b or 1,
                    width = width,
                    onChange = function(r, g, b) Commit(entry, { r = r, g = g, b = b }) end,
                }), ROW)

            elseif entry.kind == "text" or entry.kind == "number" then
                -- The widget the Edit Mode dialog has no answer for at all. The
                -- numeric variant is what makes typed offsets possible: lining
                -- two frames up exactly means entering the same number twice,
                -- which no amount of dragging will do for you.
                local numeric = entry.kind == "number"
                local input = W:CreateInput(content, entry.label, {
                    width = width,
                    text = tostring(value or (numeric and 0 or "")),
                })
                input:SetPoint("TOPLEFT", INDENT, y)
                y = y - INPUT

                local function CommitInput()
                    local text = input:GetText()

                    if not numeric then
                        Commit(entry, text)
                        return
                    end

                    local entered = tonumber(text)
                    if entered then
                        entered = math.floor(entered + 0.5)
                        input:SetText(tostring(entered))
                        Commit(entry, entered)
                    else
                        -- Not a number: put back what is actually stored rather
                        -- than leaving the box showing something never applied.
                        input:SetText(tostring(schema:Read(entry, context) or 0))
                    end
                end

                -- Enter also clears focus, so both fire; committing is
                -- idempotent.
                input.editBox:HookScript("OnEnterPressed", CommitInput)
                input.editBox:HookScript("OnEditFocusLost", CommitInput)
            end
        end
    end

    local used = math.abs(y) + 16
    content:SetWidth(CONTENT_WIDTH)
    content:SetHeight(used)

    local height = math.max(MIN_HEIGHT, math.min(MAX_HEIGHT, used + 56))
    panel:SetHeight(height)

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

local function Anchor(panel, anchorTo)
    panel:ClearAllPoints()

    if not anchorTo or not anchorTo:IsShown() then
        panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        return
    end

    local right = anchorTo:GetRight()
    local edge = UIParent:GetRight()
    local fitsRight = right and edge and ((right + GAP + PANEL_WIDTH) <= edge)

    if fitsRight then
        panel:SetPoint("TOPLEFT", anchorTo, "TOPRIGHT", GAP, 0)
    else
        panel:SetPoint("TOPRIGHT", anchorTo, "TOPLEFT", -GAP, 0)
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
--   anchorTo  the Edit Mode dialog this hangs off
--   key       identifies the open group, so clicking it again closes it
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
    Anchor(panel, spec.anchorTo)
    panel:Show()

    return true
end

-- Redraw whatever is open, in place. Used when a setting changes which other
-- settings apply.
function EditModePanel.Refresh(_)
    local panel = EditModePanel.frame
    if not panel or not panel:IsShown() or not EditModePanel.spec then return end

    Render(panel, EditModePanel.spec)
    Anchor(panel, EditModePanel.spec.anchorTo)
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

return EditModePanel
