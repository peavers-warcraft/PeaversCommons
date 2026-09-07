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
-- Sections
--
-- Collapse state lives in the addon's own config, so it survives a reload and
-- cannot collide with another addon's sections.
--------------------------------------------------------------------------------

local function SectionStore(registration)
    if registration.sectionStore then
        return registration.sectionStore()
    end

    local config = registration.schema.config
    config.editModeSections = config.editModeSections or {}
    return config.editModeSections
end

local function SectionShown(registration, key)
    return SectionStore(registration)[key] and true or false
end

-- Ask Edit Mode to rebuild whichever dialog is open. The library checks that the
-- frame it is handed is the selected one, so offering it every registered frame
-- costs nothing and saves tracking the selection.
local function RebuildOpenDialog()
    for _, registration in ipairs(EditMode.registrations) do
        LibEditMode:RefreshFrameSettings(registration.frame)
    end
end

-- One section open at a time.
--
-- The rebuild afterwards is not cosmetic. An expander widget reads its own open
-- state once, when the dialog is built, and never again; its Refresh only
-- re-evaluates whether it is hidden. A section closed behind its back keeps
-- drawing an open arrow over no rows and takes two clicks to reopen.
--
-- Two things keep that from running away. It is deferred a frame, because this
-- runs from inside the expander's own click handler, which carries on using the
-- widget after we return - and the rebuild releases it back to the pool. And it
-- only happens when a section was actually closed: building the dialog replays
-- this setter once per expander, so without that condition the open one would
-- ask for a rebuild every time, and each rebuild would ask for another.
local function SetSection(registration, key, value)
    local sections = SectionStore(registration)
    local closedAnother = false

    if value then
        for _, section in ipairs(registration.sections) do
            if section.key ~= key and sections[section.key] then
                sections[section.key] = false
                closedAnother = true
            end
        end
    end

    sections[key] = value and true or false

    local config = registration.schema.config
    if config and config.Save then config:Save() end

    if closedAnother then
        C_Timer.After(0, RebuildOpenDialog)
    end
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

local function ToSetting(registration, entry, sectionKey)
    local builder = Builders[entry.kind]
    if not builder then return nil end

    local schema, context = registration.schema, registration.context
    local setting = builder(schema, entry, context)

    setting.name = entry.label
    setting.desc = entry.desc

    -- A row is hidden when its section is collapsed, or when the setting itself
    -- has nothing to offer right now.
    if sectionKey or entry.hidden then
        setting.hidden = function()
            if sectionKey and not SectionShown(registration, sectionKey) then
                return true
            end
            return schema:IsHidden(entry, context)
        end
    end

    if entry.disabled then
        setting.disabled = function() return schema:IsDisabled(entry, context) end
    end

    return setting
end

-- The first section is drawn plain at the top of the dialog rather than behind
-- an expander: turning a frame on and sizing it are what people open this for,
-- and putting them one click away to save a few rows would be a poor trade.
local function BuildSettings(registration)
    local settings = {}

    for index, section in ipairs(registration.sections) do
        local grouped = index > 1 or section.key ~= registration.topSection

        if grouped then
            settings[#settings + 1] = {
                kind = ST.Expander,
                name = section.label,
                default = false,
                get = function() return SectionShown(registration, section.key) end,
                set = function(_, value) SetSection(registration, section.key, value) end,
            }
        end

        for _, entry in ipairs(section.entries) do
            local setting = ToSetting(registration, entry, grouped and section.key or nil)
            if setting then
                settings[#settings + 1] = setting
            end
        end
    end

    return settings
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
--   topSection         section drawn plain above the expanders (default: the first)
--   onPositionChanged  f(frame, point, x, y) - the addon saves and applies
--   onEnter / onExit   f(frame)
--   onLayout           f(frame, layoutName, layoutIndex)
--   buttons            list of { text, click }
--   sectionStore       f() -> table, if collapse state should not live on the config
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
        sectionStore = spec.sectionStore,
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

    if spec.buttons and #spec.buttons > 0 then
        LibEditMode:AddFrameSettingsButtons(spec.frame, spec.buttons)
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
