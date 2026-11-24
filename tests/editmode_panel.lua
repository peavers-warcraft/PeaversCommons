--------------------------------------------------------------------------------
-- Core/EditMode.lua, Config/EditModePanel.lua and the frame half of
-- Core/EditModeSnap.lua, driven against stand-in frames.
--
--   Run: lua tests/editmode_panel.lua        (from the addon root)
--
-- Plain Lua on purpose. None of this can be looked at without a client, but
-- most of what goes wrong in it is not visual: a row handed back to the pool
-- still wired to the last setting, a group's dropdown writing to the wrong
-- stat, a panel left open beside another frame's dialog, a snap applied in the
-- wrong units to a scaled frame. Those are plumbing, and plumbing can be driven.
--
-- The frames here answer the handful of methods whose results matter and
-- swallow the rest, so this proves the logic and says nothing about whether a
-- template exists or a texture path is right.
--
-- Not addon code, and not packaged (see .pkgmeta).
---@diagnostic disable: undefined-global, lowercase-global, missing-fields, duplicate-set-field
--------------------------------------------------------------------------------

_G = _G or _ENV

local failures, checks = 0, 0

local function Check(name, got, want)
    checks = checks + 1
    local same = got == want
    if type(got) == "number" and type(want) == "number" then
        same = math.abs(got - want) < 1e-6
    end
    if not same then
        failures = failures + 1
        print(("FAIL  %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
    end
end

--------------------------------------------------------------------------------
-- Stand-in client
--------------------------------------------------------------------------------

local inCombat = false
local timers = {}

local function RunTimers()
    local due = timers
    timers = {}
    for _, fn in ipairs(due) do fn() end
end

-- Anything that looks like a widget method and is not defined below does
-- nothing. Anything else is absent, so `if frame.MinText then` still means it.
local SWALLOWED = {
    "^Set%u", "^Get%u", "^Is%u", "^Clear%u", "^Enable%u", "^Register%u", "^Unregister%u",
    "^Full%u", "^Has%u", "^Add%u", "^Raise$", "^Lower$",
}

local FrameMeta = {}
FrameMeta.__index = function(_, key)
    if FrameMeta[key] ~= nil then return FrameMeta[key] end
    if type(key) == "string" then
        for _, pattern in ipairs(SWALLOWED) do
            if key:find(pattern) then return function() end end
        end
    end
    return nil
end

local function NewFrame(kind, parent, template)
    local frame = setmetatable({
        kind = kind, parentFrame = parent, template = template,
        scripts = {}, points = {}, shown = true, scale = 1,
    }, FrameMeta)

    if template == "MinimalSliderWithSteppersTemplate" then
        frame.RightText = NewFrame("FontString", frame)
        frame.MinText = NewFrame("FontString", frame)
        frame.MaxText = NewFrame("FontString", frame)
    end

    return frame
end

function FrameMeta:GetParent() return self.parentFrame end
function FrameMeta:SetParent(parent) self.parentFrame = parent end
function FrameMeta:Show() self.shown = true end
function FrameMeta:Hide()
    local was = self.shown
    self.shown = false
    if was and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function FrameMeta:SetShown(shown) if shown then self:Show() else self:Hide() end end
function FrameMeta:IsShown() return self.shown end
function FrameMeta:IsVisible() return self.shown end
function FrameMeta:SetScript(name, fn) self.scripts[name] = fn end
function FrameMeta:GetScript(name) return self.scripts[name] end
function FrameMeta:HookScript(name, fn)
    local before = self.scripts[name]
    self.scripts[name] = function(...)
        if before then before(...) end
        fn(...)
    end
end
function FrameMeta:Fire(name, ...)
    if self.scripts[name] then return self.scripts[name](self, ...) end
end
function FrameMeta:CreateFontString() return NewFrame("FontString", self) end
function FrameMeta:CreateTexture() return NewFrame("Texture", self) end
function FrameMeta:CreateLine() return NewFrame("Line", self) end
function FrameMeta:SetText(text) self.text = text end
function FrameMeta:GetText() return self.text end
function FrameMeta:SetChecked(checked) self.checked = checked end
function FrameMeta:GetChecked() return self.checked end
function FrameMeta:SetEnabled(enabled) self.enabled = enabled end
function FrameMeta:SetHeight(height) self.height = height end
function FrameMeta:GetHeight() return self.height end
function FrameMeta:SetPoint(...) self.points[#self.points + 1] = { ... } end
function FrameMeta:ClearAllPoints() self.points = {} end
function FrameMeta:GetRight() return self.right end
function FrameMeta:GetScale() return self.scale end
function FrameMeta:GetEffectiveScale() return self.scale end
function FrameMeta:GetWidth() return self.width end
function FrameMeta:SetColorRGB(r, g, b) self.color = { r, g, b } end
-- Losing focus is only reported by a box that had it, as in the client.
function FrameMeta:SetFocus() self.focused = true end
function FrameMeta:ClearFocus()
    if not self.focused then return end
    self.focused = false
    if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
end

-- left, bottom, width, height in screen units, as the client reports them.
function FrameMeta:GetScaledRect()
    if not self.rect then return nil end
    return self.rect[1], self.rect[2], self.rect[3], self.rect[4]
end

-- The slider template: remembers what it was set up with, and reports a change
-- to whoever registered for it.
function FrameMeta:RegisterCallback(_, fn, owner)
    self.callback, self.callbackOwner = fn, owner
end
function FrameMeta:Init(value, min, max, steps, formatters)
    self.value, self.min, self.max, self.steps, self.formatters = value, min, max, steps, formatters
    -- The real one reports the value it was given; the row has to ignore that.
    if self.callback then self.callback(self.callbackOwner, value) end
end
function FrameMeta:SetValue(value)
    self.value = value
    if self.callback then self.callback(self.callbackOwner, value) end
end

-- The dropdown template: keeps the generator, and can be asked what it offers.
function FrameMeta:SetupMenu(generator) self.generator = generator end
function FrameMeta:Menu()
    local items = {}
    local root = {
        SetScrollMode = function(_, height) items.scroll = height end,
        CreateRadio = function(_, text, isSelected, select, data)
            items[#items + 1] = { text = text, isSelected = isSelected, select = select, data = data }
        end,
    }
    self.generator(self, root)
    return items
end

_G.UIParent = NewFrame("Frame")
UIParent.width, UIParent.height, UIParent.right = 1920, 1080, 1920
function UIParent:GetHeight() return self.height end

_G.CreateFrame = function(kind, _, parent, template) return NewFrame(kind, parent, template) end
_G.InCombatLockdown = function() return inCombat end
_G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
_G.PlaySound = function() end
_G.SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 1 }
_G.WHITE_FONT_COLOR = { GetRGB = function() return 1, 1, 1 end }
_G.DISABLED_FONT_COLOR = { GetRGB = function() return 0.5, 0.5, 0.5 end }
_G.GameTooltip = NewFrame("GameTooltip")
_G.MinimalSliderWithSteppersMixin = { Event = { OnValueChanged = "OnValueChanged" }, Label = { Right = 2 } }
_G.CreateMinimalSliderFormatter = function(_, formatter) return formatter end
_G.CreateColor = function(r, g, b) return { r = r, g = g, b = b } end
_G.hooksecurefunc = function(target, name, hook)
    local original = target[name]
    target[name] = function(...)
        local a, b, c = original(...)
        hook(...)
        return a, b, c
    end
end

local picker
_G.ColorPickerFrame = {
    SetupColorPickerAndShow = function(_, info) picker = info end,
    GetColorRGB = function() return 0.2, 0.4, 0.6 end,
}

-- Blizzard's side of Edit Mode: the Snap box, and one of its own frames.
local snapEnabled = true
local blizzardFrame = NewFrame("Frame")
blizzardFrame.system, blizzardFrame.systemIndex = 7, nil
_G.EditModeManagerFrame = {
    IsSnapEnabled = function() return snapEnabled end,
    SelectSystem = function() end,
    registeredSystemFrames = { blizzardFrame },
}
_G.EditModeSystemSettingsDialog = NewFrame("Frame")

-- LibEditMode, as far as EditMode.lua and EditModeSnap.lua reach into it.
local moves = {}
local lib = {
    SettingType = { Checkbox = "c", Slider = "s", Dropdown = "d", ColorPicker = "p", Expander = "e", Divider = "v" },
    frameSelections = {}, settings = {}, buttons = {}, callbacks = {},
    internal = {},
}
function lib:AddFrame(frame)
    local selection = NewFrame("Frame", frame)
    selection.parent = frame
    selection.shown = false
    self.frameSelections[frame] = selection
    if not self.internal.dialog then
        self.internal.dialog = NewFrame("Frame")
        self.internal.dialog.right = 600
        self.internal.dialog.Update = function(dialog, shown) dialog.selection = shown end
    end
end
function lib:AddFrameSettings(frame, settings) self.settings[frame] = settings end
function lib:AddFrameSettingsButtons(frame, buttons) self.buttons[frame] = buttons end
function lib:AddSystemSettings() end
function lib:AddSystemSettingsButtons(_, buttons) self.systemButtons = buttons end
function lib:RegisterCallback(event, fn) self.callbacks[event] = fn end
function lib.internal:GetPool() return nil end
function lib.internal:MoveParent(selection, x, y)
    moves[#moves + 1] = { selection = selection, x = x, y = y }
end
_G.LibStub = function() return lib end

_G.PeaversCommons = {
    FrameUtils = {
        CreateScrollBox = function(parent)
            return NewFrame("Frame", parent), NewFrame("Frame", parent), NewFrame("Frame", parent)
        end,
        UpdateScrollBox = function() end,
    },
}

dofile("src/Config/ConfigSchema.lua")
dofile("src/Config/SettingsSchema.lua")
dofile("src/Config/EditModeStyle.lua")
local Panel = dofile("src/Config/EditModePanel.lua")
local Snap = dofile("src/Core/EditModeSnap.lua")
local EditMode = dofile("src/Core/EditMode.lua")

--------------------------------------------------------------------------------
-- An addon
--------------------------------------------------------------------------------

local applied = {}
local config = {
    enabled = true,
    size = 40,
    opacity = 0.5,
    mode = "A",
    tint = { r = 1, g = 0, b = 0 },
    offset = 10,
    title = "hello",
    fancy = false,
    fancyAmount = 3,
    perThing = { one = { shown = true }, two = { shown = false } },
    defaults = {},
    Save = function() end,
}

local schema = PeaversCommons.SettingsSchema:New({
    config = config,
    sections = {
        { key = "frame", label = "Frame" },
        { key = "look", label = "Appearance" },
        {
            key = "things", label = "Things",
            selector = {
                label = "Thing",
                values = { { value = "one", label = "One" }, { value = "two", label = "Two" } },
            },
        },
    },
    entries = {
        { key = "enabled", label = "Enabled", kind = "checkbox", section = "frame" },
        { key = "size", label = "Size", kind = "slider", section = "frame", min = 10, max = 100, step = 1 },

        { key = "opacity", label = "Opacity", kind = "slider", section = "look", min = 0, max = 1, step = 0.05 },
        {
            key = "mode", label = "Mode", kind = "dropdown", section = "look", height = 300,
            values = { { value = "A", label = "First" }, { value = "B", label = "Second" } },
        },
        { key = "tint", label = "Tint", kind = "color", section = "look" },
        { key = "offset", label = "Offset", kind = "number", section = "look" },
        { key = "title", label = "Title", kind = "text", section = "look" },
        { key = "fancy", label = "Fancy", kind = "checkbox", section = "look", revealsOthers = true },
        {
            key = "fancyAmount", label = "How Fancy", kind = "slider", section = "look",
            min = 1, max = 5, step = 1, desc = "Only when fancy.",
            hidden = function(cfg) return not cfg.fancy end,
        },
        {
            key = "locked", label = "Locked Thing", kind = "checkbox", section = "look",
            disabled = function() return true end,
        },

        {
            key = "thingShown", label = "Show This Thing", kind = "checkbox", section = "things",
            getValue = function(cfg, thing) return cfg.perThing[thing].shown end,
            setValue = function(cfg, thing, value) cfg.perThing[thing].shown = value end,
        },
    },
    apply = function(entry, context, value)
        applied[#applied + 1] = { key = entry.key, context = context, value = value }
    end,
})

local saved = {}
local frameA = NewFrame("Frame", UIParent)
local frameB = NewFrame("Frame", UIParent)

local registrationA = EditMode:Register({
    frame = frameA, name = "Addon A", schema = schema,
    onPositionChanged = function(_, point, x, y) saved[#saved + 1] = { point, x, y } end,
})
EditMode:Register({ frame = frameB, name = "Addon B", schema = schema })

local selectionA = lib.frameSelections[frameA]
local selectionB = lib.frameSelections[frameB]
local dialog = lib.internal.dialog

--------------------------------------------------------------------------------
-- The dialog: the first group's settings, and a button per other group
--------------------------------------------------------------------------------

Check("register: returns a registration", type(registrationA), "table")
Check("dialog: settings from the first group only", #lib.settings[frameA], 2)
Check("dialog: one button per other group", #lib.buttons[frameA], 2)
Check("dialog: button text", lib.buttons[frameA][1].text, "Appearance...")
Check("dialog: second button text", lib.buttons[frameA][2].text, "Things...")

--------------------------------------------------------------------------------
-- The panel
--------------------------------------------------------------------------------

-- The panel does not expose its rows, so they are found the way a user finds
-- them: by what they say. A row handed back to the pool has no anchor.
local created = {}
do
    local original = _G.CreateFrame
    _G.CreateFrame = function(kind, name, parent, template)
        local frame = original(kind, name, parent, template)
        created[#created + 1] = frame
        return frame
    end
end

local function RowLabelled(text)
    for _, frame in ipairs(created) do
        if frame.Label and frame.Label.text == text and frame.shown and #frame.points > 0 then
            return frame
        end
    end
    return nil
end

local function ShownRowCount()
    local count = 0
    for _, frame in ipairs(created) do
        if frame.Label and frame.shown and #frame.points > 0 then count = count + 1 end
    end
    return count
end

dialog:Update(selectionA)
lib.buttons[frameA][1].click()

Check("panel: opens", Panel:IsShown(), true)
Check("panel: title", Panel.frame.Title.text, "Addon A - Appearance")
Check("panel: owner is the frame", Panel:Owner(), tostring(frameA))
-- Seven of the eight entries: "How Fancy" is hidden until Fancy is ticked.
Check("panel: hidden row is not drawn", ShownRowCount(), 7)
Check("panel: no hidden row", RowLabelled("How Fancy"), nil)

-- Check box.
do
    local row = RowLabelled("Fancy")
    Check("checkbox: shows the stored value", row.Button.checked, false)
    row.Button.checked = true
    row.Button:Fire("OnClick")
    Check("checkbox: writes", config.fancy, true)
    Check("checkbox: applies", applied[#applied].key, "fancy")

    -- revealsOthers redraws, but not from inside the click.
    Check("reveal: not redrawn inside the click", RowLabelled("How Fancy"), nil)
    RunTimers()
    Check("reveal: redrawn a frame later", RowLabelled("How Fancy") ~= nil, true)
    Check("reveal: row count", ShownRowCount(), 8)
    Check("reveal: tooltip text carried", RowLabelled("How Fancy").desc, "Only when fancy.")
end

-- Slider: set up without reporting, quantised when it does.
do
    local before = #applied
    local row = RowLabelled("Opacity")
    Check("slider: value", row.Slider.value, 0.5)
    Check("slider: steps", row.Slider.steps, 20)
    Check("slider: setting up is not a change", #applied, before)

    row.Slider:SetValue(0.30000000000000004)
    Check("slider: quantised", config.opacity, 0.3)
    Check("slider: one write", #applied, before + 1)

    row.Slider:SetValue(0.3)
    Check("slider: same value is not written again", #applied, before + 1)

    -- Typed into the value box.
    row.EditBox.text = "0.72"
    row.EditBox:Fire("OnEnterPressed")
    Check("slider: typed value snaps to the step", config.opacity, 0.7)

    row.EditBox.text = "99"
    row.EditBox:Fire("OnEnterPressed")
    Check("slider: typed value is clamped", config.opacity, 1)
end

-- Dropdown.
do
    local row = RowLabelled("Mode")
    local menu = row.Dropdown:Menu()
    Check("dropdown: options", #menu, 2)
    Check("dropdown: option text", menu[2].text, "Second")
    Check("dropdown: scrolls a long list", menu.scroll, 300)
    Check("dropdown: current is selected", menu[1].isSelected(menu[1].data), true)
    Check("dropdown: other is not", menu[2].isSelected(menu[2].data), false)

    menu[2].select(menu[2].data)
    Check("dropdown: writes", config.mode, "B")
    Check("dropdown: selection follows", menu[2].isSelected(menu[2].data), true)
end

-- Colour, including a picker that outlives the row it was opened from.
do
    local row = RowLabelled("Tint")
    Check("colour: swatch shows the stored colour", row.Swatch.color[1], 1)

    row.Swatch:Fire("OnClick")
    picker.swatchFunc()
    Check("colour: writes", config.tint.g, 0.4)
    picker.cancelFunc()
    Check("colour: cancel restores", config.tint.r, 1)

    -- Reopen the panel on another group: the row is recycled, and the old
    -- picker must not write through it.
    local stale = picker
    local writes = #applied
    lib.buttons[frameA][2].click()
    stale.swatchFunc()
    Check("colour: a stale picker writes nothing", #applied, writes)
    lib.buttons[frameA][1].click()
end

-- Typed number and text.
do
    local row = RowLabelled("Offset")
    Check("number: shows the stored value", row.EditBox.text, "10")

    row.EditBox:SetFocus()
    row.EditBox.text = "12.6"
    row.EditBox:Fire("OnEnterPressed")
    Check("number: rounds and writes", config.offset, 13)
    Check("number: box shows what was stored", row.EditBox.text, "13")

    local writes = #applied
    row.EditBox.text = "abc"
    row.EditBox:Fire("OnEnterPressed")
    Check("number: rubbish is not written", #applied, writes)
    Check("number: rubbish is put back", row.EditBox.text, "13")

    row.EditBox.text = "-40"
    row.EditBox:Fire("OnEnterPressed")
    Check("number: negatives", config.offset, -40)

    local text = RowLabelled("Title")
    text.EditBox.text = "goodbye"
    text.EditBox:Fire("OnEditFocusLost")
    Check("text: writes on losing focus", config.title, "goodbye")
end

-- Disabled.
do
    local row = RowLabelled("Locked Thing")
    Check("disabled: control is disabled", row.Button.enabled, false)
    Check("enabled: control is enabled", RowLabelled("Fancy").Button.enabled, true)
end

-- A group with a selector: the dropdown's choice is what the settings mean.
do
    lib.buttons[frameA][2].click()
    Check("selector: title", Panel.frame.Title.text, "Addon A - Things")

    local shown = RowLabelled("Show This Thing")
    Check("selector: reads the first choice", shown.Button.checked, true)

    local menu = RowLabelled("Thing").Dropdown:Menu()
    menu[2].select(menu[2].data)
    RunTimers()

    shown = RowLabelled("Show This Thing")
    Check("selector: reads the new choice", shown.Button.checked, false)

    shown.Button.checked = true
    shown.Button:Fire("OnClick")
    Check("selector: writes to the new choice", config.perThing.two.shown, true)
    Check("selector: leaves the other alone", config.perThing.one.shown, true)
    Check("selector: apply is told which", applied[#applied].context, "two")
end

-- Clicking the open group's button closes it.
do
    lib.buttons[frameA][2].click()
    Check("toggle: second click closes", Panel:IsShown(), false)
    lib.buttons[frameA][2].click()
    Check("toggle: third click reopens", Panel:IsShown(), true)
end

-- The panel does not outlive the selection it belongs to.
do
    dialog:Update(selectionA)
    Check("owner: dropping the same frame keeps it open", Panel:IsShown(), true)

    dialog:Update(selectionB)
    Check("owner: selecting another frame closes it", Panel:IsShown(), false)

    dialog:Update(selectionA)
    lib.buttons[frameA][1].click()
    Check("owner: reopened", Panel:IsShown(), true)
    dialog:Hide()
    Check("owner: closing the dialog closes it", Panel:IsShown(), false)
    dialog:Show()

    lib.buttons[frameA][1].click()
    EditModeManagerFrame:SelectSystem(blizzardFrame)
    Check("owner: selecting a Blizzard frame closes it", Panel:IsShown(), false)
end

--------------------------------------------------------------------------------
-- Snapping
--------------------------------------------------------------------------------

do
    Check("snap: registered frames are hooked", selectionA.peaversSnap, true)

    -- B sits at 200..320 x 300..340. A is dropped five below and three right.
    frameB.rect = { 200, 300, 120, 40 }
    frameA.rect = { 203, 255, 120, 40 }
    blizzardFrame.rect = { 1500, 900, 100, 40 }

    selectionA:Fire("OnDragStart")
    Check("snap: a drag is in progress", Snap:IsDragging(), true)
    selectionA:Fire("OnDragStop")
    Check("snap: the drag is over", Snap:IsDragging(), false)

    Check("snap: one move", #moves, 1)
    Check("snap: moved the dragged frame", moves[1].selection, selectionA)
    Check("snap: dx", moves[1].x, -3)
    Check("snap: dy", moves[1].y, 5)

    -- A frame at half scale is told to move twice as far in its own units.
    frameA.scale = 0.5
    selectionA:Fire("OnDragStart")
    selectionA:Fire("OnDragStop")
    Check("snap: scaled dx", moves[2].x, -6)
    Check("snap: scaled dy", moves[2].y, 10)
    frameA.scale = 1

    -- Already in place: nothing to do, so the addon is not told twice.
    frameA.rect = { 200, 260, 120, 40 }
    selectionA:Fire("OnDragStart")
    selectionA:Fire("OnDragStop")
    Check("snap: aligned frame is left alone", #moves, 2)

    -- The Snap box in the Edit Mode window is the switch.
    frameA.rect = { 203, 255, 120, 40 }
    snapEnabled = false
    selectionA:Fire("OnDragStart")
    Check("snap: off means no drag is tracked", Snap:IsDragging(), false)
    selectionA:Fire("OnDragStop")
    Check("snap: off means no move", #moves, 2)
    snapEnabled = true

    -- Combat ends a drag without snapping.
    selectionA:Fire("OnDragStart")
    inCombat = true
    selectionA:Fire("OnDragStop")
    Check("snap: nothing moves in combat", #moves, 2)
    Check("snap: and the drag is still cleared", Snap:IsDragging(), false)
    inCombat = false

    -- A hidden frame is not something to line up with.
    frameB.shown = false
    selectionA:Fire("OnDragStart")
    selectionA:Fire("OnDragStop")
    Check("snap: hidden frames are ignored", #moves, 2)
    frameB.shown = true

    -- Blizzard's frames count, but only as neighbours.
    frameB.shown = false
    blizzardFrame.rect = { 400, 300, 100, 40 }
    frameA.rect = { 504, 302, 80, 40 }           -- four right of its right edge
    selectionA:Fire("OnDragStart")
    selectionA:Fire("OnDragStop")
    Check("snap: to a Blizzard frame", #moves, 3)
    Check("snap: Blizzard dx", moves[3].x, -4)
    Check("snap: Blizzard dy", moves[3].y, -2)

    blizzardFrame.rect = { 400, 800, 100, 40 }   -- same edges, far above
    selectionA:Fire("OnDragStart")
    selectionA:Fire("OnDragStop")
    Check("snap: a distant Blizzard frame is ignored", #moves, 3)
    frameB.shown = true

    -- An addon can opt a frame out of snapping; it stays a target for others.
    local frameC = NewFrame("Frame", UIParent)
    EditMode:Register({ frame = frameC, name = "Addon C", schema = schema, snap = false })
    Check("snap: opt-out is not hooked", lib.frameSelections[frameC].peaversSnap, nil)
end

print(("%d checks, %d failed"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
