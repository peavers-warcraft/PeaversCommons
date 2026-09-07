-- PeaversCommons EditMode Module
--
-- Puts a Peavers frame into Blizzard's Edit Mode, so it is placed and adjusted
-- where every other frame on the screen is, rather than in a settings window
-- layered over the top of it.
--
-- An addon hands over a frame, a position to save it to, and a SettingsSchema.
-- Everything else - registering with LibEditMode, translating the schema into
-- the dialog's own setting objects, collapsing the dialog into sections, showing
-- the frame while Edit Mode is open - happens here, once, for all of them.
--
-- Two things about the dialog shape the design.
--
-- It has no scroll bar. It is a vertical layout frame that simply grows until it
-- runs off the bottom of the screen, so a frame with thirty settings is
-- unreachable on a short monitor. Every section after the first is therefore
-- collapsible, and only one is open at a time.
--
-- And the selection overlay it draws is created as a *child* of the frame it is
-- given, hard-coded to MEDIUM strata at frame level 1000. A frame that hides
-- itself takes its own Edit Mode handle down with it, and a frame sitting above
-- MEDIUM covers the overlay meant to be receiving the clicks. Addons whose real
-- frame is protected, hidden by a state driver, or floating at DIALOG strata
-- should register a plain mover frame instead and move the real one from the
-- position callback.

local PeaversCommons = _G.PeaversCommons
local EditMode = {}
PeaversCommons.EditMode = EditMode

local LibEditMode = LibStub and LibStub("LibEditMode", true)

EditMode.available = LibEditMode and true or false
EditMode.registrations = {}

local editing = false
local hooked = false

function EditMode:IsEditing()
    return editing
end

--------------------------------------------------------------------------------
-- Groups
--
-- Every group but the first becomes a button in the dialog that opens the
-- settings panel beside it. The accordion that used to live here - expanders,
-- collapse state on the config, a deferred rebuild to keep the arrows honest -
-- existed only to make a dialog with no scroll bar survive thirty rows. The
-- panel scrolls, so none of it is needed.
--------------------------------------------------------------------------------

local function OpenGroup(registration, section)
    local panel = PeaversCommons.EditModePanel
    if not panel then return end

    panel:Show({
        -- Keyed by frame as well as group, so clicking "Bars" on one frame and
        -- then on another reopens rather than toggling shut.
        key = tostring(registration.frame) .. ":" .. section.key,
        title = (registration.name or "") .. " - " .. section.label,
        schema = registration.schema,
        context = registration.context,
        entries = section.entries,
        anchorTo = registration.dialog,
    })
end

--------------------------------------------------------------------------------
-- Schema entry -> Edit Mode setting
--------------------------------------------------------------------------------

local ST = LibEditMode and LibEditMode.SettingType

local function AsColor(value)
    value = value or {}
    return CreateColor(value.r or 1, value.g or 1, value.b or 1)
end

local Builders = {}

function Builders.checkbox(schema, entry, context)
    return {
        kind = ST.Checkbox,
        default = schema:Default(entry, context) and true or false,
        get = function() return schema:Read(entry, context) and true or false end,
        set = function(_, value) schema:Write(entry, context, value and true or false) end,
    }
end

function Builders.slider(schema, entry, context)
    return {
        kind = ST.Slider,
        default = schema:Default(entry, context) or entry.min,
        get = function() return schema:Read(entry, context) or entry.min end,
        set = function(_, value) schema:Write(entry, context, value) end,
        minValue = entry.min,
        maxValue = entry.max,
        valueStep = entry.step,
        formatter = schema:Formatter(entry),
    }
end

function Builders.dropdown(schema, entry, context)
    return {
        kind = ST.Dropdown,
        default = schema:Default(entry, context),
        get = function() return schema:Read(entry, context) end,
        set = function(_, value) schema:Write(entry, context, value) end,
        -- The dialog wants `text` where the settings page wants `label`.
        values = function()
            local out = {}
            for _, option in ipairs(schema:Values(entry)) do
                out[#out + 1] = { value = option.value, text = option.label }
            end
            return out
        end,
        height = entry.height,
    }
end

function Builders.color(schema, entry, context)
    return {
        kind = ST.ColorPicker,
        default = AsColor(schema:Default(entry, context)),
        get = function() return AsColor(schema:Read(entry, context)) end,
        set = function(_, color)
            schema:Write(entry, context, { r = color.r, g = color.g, b = color.b })
        end,
    }
end

local function ToSetting(registration, entry)
    local builder = Builders[entry.kind]
    if not builder then return nil end

    local schema, context = registration.schema, registration.context
    local setting = builder(schema, entry, context)

    setting.name = entry.label
    setting.desc = entry.desc

    if entry.hidden then
        setting.hidden = function() return schema:IsHidden(entry, context) end
    end

    if entry.disabled then
        setting.disabled = function() return schema:IsDisabled(entry, context) end
    end

    return setting
end

-- Only the first group is drawn in the dialog itself. Turning a frame on and
-- sizing it are what people open Edit Mode for, and those belong under your
-- cursor rather than a click away; everything else is a button that opens the
-- panel, where there is room to read it.
local function BuildSettings(registration)
    local settings = {}

    local top = registration.sections[1]
    if top and top.key == registration.topSection then
        for _, entry in ipairs(top.entries) do
            local setting = ToSetting(registration, entry)
            if setting then
                settings[#settings + 1] = setting
            end
        end
    end

    return settings
end

-- One button per remaining group, ahead of whatever buttons the addon adds of
-- its own. The trailing ellipsis is the only thing distinguishing "opens a
-- panel" from "does something", since the dialog gives them the same widget.
local function BuildGroupButtons(registration)
    local buttons = {}

    for index, section in ipairs(registration.sections) do
        if index > 1 or section.key ~= registration.topSection then
            buttons[#buttons + 1] = {
                text = section.label .. "...",
                click = function() OpenGroup(registration, section) end,
            }
        end
    end

    return buttons
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

local function HookCallbacks()
    if hooked then return end
    hooked = true

    LibEditMode:RegisterCallback("enter", function()
        editing = true
        for _, registration in ipairs(EditMode.registrations) do
            if registration.onEnter then registration.onEnter(registration.frame) end
        end
    end)

    LibEditMode:RegisterCallback("exit", function()
        editing = false

        -- The panel hangs off the dialog and has no business outliving it.
        if PeaversCommons.EditModePanel then
            PeaversCommons.EditModePanel:Hide()
        end

        for _, registration in ipairs(EditMode.registrations) do
            if registration.onExit then registration.onExit(registration.frame) end
        end
    end)

    LibEditMode:RegisterCallback("layout", function(layoutName, layoutIndex)
        for _, registration in ipairs(EditMode.registrations) do
            if registration.onLayout then
                registration.onLayout(registration.frame, layoutName, layoutIndex)
            end
        end
    end)
end

-- spec:
--   frame              the frame Edit Mode drags - see the note at the top
--   name               what the dialog is titled
--   schema             a SettingsSchema
--   context            passed through to the schema's scope, for per-thing configs
--   default            { point, x, y } for the Reset Position button
--   topSection         group drawn in the dialog itself (default: the first)
--   onPositionChanged  f(frame, point, x, y) - the addon saves and applies
--   onEnter / onExit   f(frame)
--   onLayout           f(frame, layoutName, layoutIndex)
--   buttons            list of { text, click }, added after the group buttons
function EditMode.Register(_, spec)
    if not EditMode.available then return nil end
    if not spec or not spec.frame or not spec.schema then return nil end

    local registration = {
        frame = spec.frame,
        schema = spec.schema,
        context = spec.context,
        onEnter = spec.onEnter,
        onExit = spec.onExit,
        onLayout = spec.onLayout,
        name = spec.name,
        sections = spec.schema:SectionsForSurface("editmode"),
    }
    registration.topSection = spec.topSection or (registration.sections[1] and registration.sections[1].key)

    local default = spec.default or { point = "CENTER", x = 0, y = 0 }

    LibEditMode:AddFrame(spec.frame, function(frame, _, point, x, y)
        if spec.onPositionChanged then
            spec.onPositionChanged(frame, point, x, y)
        end
    end, default, spec.name)

    LibEditMode:AddFrameSettings(spec.frame, BuildSettings(registration))

    -- The dialog is built by the first AddFrame, so this is the earliest the
    -- panel can be told what to anchor itself to.
    registration.dialog = LibEditMode.internal and LibEditMode.internal.dialog

    local buttons = BuildGroupButtons(registration)
    for _, button in ipairs(spec.buttons or {}) do
        buttons[#buttons + 1] = button
    end
    if #buttons > 0 then
        LibEditMode:AddFrameSettingsButtons(spec.frame, buttons)
    end

    EditMode.registrations[#EditMode.registrations + 1] = registration

    HookCallbacks()

    -- After the first registration, because that is what creates the dialog this
    -- squares up.
    if PeaversCommons.EditModeStyle then
        PeaversCommons.EditModeStyle:Apply()
    end

    return registration
end

return EditMode
