-- PeaversCommons SettingsSchema Module
--
-- Describes an addon's settings once so that more than one surface can render
-- them: the settings page in PeaversConfig, and the dialog Blizzard's Edit Mode
-- opens when you select a frame.
--
-- Before this each surface carried its own hand-written copy of the same
-- settings, in its own widget vocabulary, with the ranges typed out again. Two
-- copies drift: add a setting and one surface silently lacks it, rename a config
-- key and the other silently stops working. Across a dozen addons that does not
-- hold.
--
-- Most of what a setting *is* was already written down. ConfigSchema.Common has
-- carried the label, range, type and default of every standard Peavers setting
-- for a long time; SettingsObjects has just been the only thing reading it. So
-- an addon using the standard settings declares almost nothing here - a key, a
-- section and where it should appear:
--
--   { key = "barHeight", section = "bars", surface = "both" }
--
-- and the label, kind, range and default are resolved from ConfigSchema.Common.
-- Only settings an addon invents need spelling out in full.
--
-- An entry says what a setting IS, never how it is drawn:
--
--   key       the field in the config table
--   section   which group it belongs to, shared by every surface
--   surface   "both", or "config" for settings the Edit Mode dialog should skip
--   label     defaults to the common schema's label
--   kind      checkbox | slider | dropdown | color; defaults from the common type
--   unit      px | pt | percent, for formatting a slider's value
--   values    dropdown options, as a list, a map, or a function returning either
--   desc      a sentence for the tooltip
--   read      optional: stored value -> what the widget shows
--   write     optional: what the widget gives -> stored value
--   hidden    optional: f(scope) -> hide this row entirely
--   disabled  optional: f(scope) -> grey this row out
--   global    optional: this setting is addon-wide, not per-thing - it is read
--             and written on the config itself, ignoring the scope
--   getValue  optional: f(config, context) -> value, replacing the key lookup
--   setValue  optional: f(config, context, value), replacing the key write
--
-- getValue/setValue are for settings that are not simply a field: a colour kept
-- in a nested table per stat, say, or one derived from something else. An entry
-- using them still needs a key, because that is what identifies it to the
-- surfaces and to whatever the addon does after a write.
--
-- `surface` is the one worth thinking about. "both" is for anything decided by
-- looking at the frame while you drag it: sizes, spacing, opacity. "config" is
-- for anything picked off a list once and then forgotten - display modes, aura
-- filters, fonts. Those are worse in an Edit Mode dialog, which has no room to
-- explain the options and no scroll bar to grow into, and better on a settings
-- page that has both.

local PeaversCommons = _G.PeaversCommons
local SettingsSchema = {}
PeaversCommons.SettingsSchema = SettingsSchema

local ConfigSchema = PeaversCommons.ConfigSchema

--------------------------------------------------------------------------------
-- Resolution against ConfigSchema.Common
--------------------------------------------------------------------------------

local KIND_BY_TYPE = {
    number = "slider",
    integer = "slider",
    boolean = "checkbox",
    dropdown = "dropdown",
    color = "color",
    font = "dropdown",
    texture = "dropdown",
}

-- The standard settings whose numbers mean something other than a bare count.
-- A value column reading "30" above "40" tells you nothing when one is a
-- percentage and the other is pixels.
local COMMON_UNITS = {
    frameWidth = "px",
    frameHeight = "px",
    frameX = "px",
    frameY = "px",
    barHeight = "px",
    barSpacing = "px",
    fontSize = "pt",
    barAlpha = "percent",
    barBgAlpha = "percent",
    textAlpha = "percent",
    bgAlpha = "percent",
}

local FORMATTERS = {
    px = function(value) return math.floor(value + 0.5) .. "px" end,
    pt = function(value) return math.floor(value + 0.5) .. "pt" end,
    percent = function(value) return math.floor((value * 100) + 0.5) .. "%" end,
}

-- Some addons store the outline as the flag the font API wants, others as a
-- plain boolean, and both are in the wild. The widget is a tick either way, so
-- the stored shape is preserved rather than corrected.
local OUTLINE_TRANSFORM = {
    read = function(stored)
        if type(stored) == "string" then return stored == "OUTLINE" end
        return stored ~= false
    end,
    write = function(shown, stored)
        if type(stored) == "string" or stored == nil then
            return shown and "OUTLINE" or ""
        end
        return shown and true or false
    end,
}

local function Resolve(value, ...)
    if type(value) == "function" then return value(...) end
    return value
end

-- Turn either shape of option list into { value, label } pairs. ConfigSchema
-- writes dropdowns as a value->label map, which has no order, so those are
-- sorted by label to at least be stable.
local function AsOptions(values)
    if not values then return nil end

    if values[1] ~= nil then
        return values
    end

    local out = {}
    for value, label in pairs(values) do
        out[#out + 1] = { value = value, label = tostring(label) }
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

--------------------------------------------------------------------------------
-- Schema objects
--------------------------------------------------------------------------------

local Schema = {}
Schema.__index = Schema

-- definition:
--   config          the addon's config object
--   entries         list of entries, in the order they should be drawn
--   sections        list of { key, label }, in order
--   scope           f(config, context) -> the table a setting is stored in
--                   (defaults to the config itself; per-unit addons override it)
--   scopeDefaults   f(config, context) -> the matching table of defaults
--   apply           f(entry, context, value) run after a successful write
function SettingsSchema.New(_, definition)
    local self = setmetatable({}, Schema)

    self.config = definition.config
    self.sections = definition.sections or {}
    self.scope = definition.scope or function(config) return config end
    self.scopeDefaults = definition.scopeDefaults or function(config) return config.defaults or {} end
    self.apply = definition.apply

    self.entries = {}
    for _, entry in ipairs(definition.entries or {}) do
        self.entries[#self.entries + 1] = self:Fill(entry)
    end

    return self
end

-- Fill in whatever the entry did not say from the common schema.
function Schema:Fill(entry)
    local common = ConfigSchema and ConfigSchema.Common and ConfigSchema.Common[entry.key]

    local filled = {}
    for key, value in pairs(entry) do filled[key] = value end

    filled.surface = filled.surface or "both"

    if common then
        filled.label = filled.label or common.label or entry.key
        filled.kind = filled.kind or KIND_BY_TYPE[common.type]
        filled.desc = filled.desc or common.tooltip
        filled.default = filled.default ~= nil and filled.default or common.default

        if filled.kind == "slider" then
            filled.min = filled.min or common.min
            filled.max = filled.max or common.max
            filled.step = filled.step or common.step
        end

        if common.type == "font" then
            filled.values = filled.values or function()
                return PeaversCommons.ConfigManager.GetFonts()
            end
            filled.fallback = filled.fallback or function()
                return PeaversCommons.ConfigManager.GetDefaultFont()
            end
        elseif common.type == "texture" then
            filled.values = filled.values or function()
                return PeaversCommons.ConfigManager.GetBarTextures()
            end
            filled.fallback = filled.fallback or function()
                return PeaversCommons.ConfigManager.GetDefaultBarTexture()
            end
        else
            filled.values = filled.values or common.options
        end
    end

    filled.label = filled.label or entry.key
    filled.unit = filled.unit or COMMON_UNITS[entry.key]

    if entry.key == "fontOutline" and not filled.read and not filled.write then
        filled.read = OUTLINE_TRANSFORM.read
        filled.outlineWrite = true
    end

    return filled
end

--------------------------------------------------------------------------------
-- Reading and writing
--------------------------------------------------------------------------------

-- Where a setting is stored. Addon-wide settings sit on the config itself, which
-- is what a schema with no scope of its own would have used anyway; the scope
-- exists only for addons whose settings repeat per frame, per unit or per bar.
function Schema:Scope(context, entry)
    if entry and entry.global then
        return self.config
    end
    return self.scope(self.config, context) or {}
end

function Schema:Defaults(context, entry)
    if entry and entry.global then
        return self.config.defaults or {}
    end
    return self.scopeDefaults(self.config, context) or {}
end

function Schema:Formatter(entry)
    return entry.unit and FORMATTERS[entry.unit] or nil
end

function Schema:Values(entry)
    return AsOptions(Resolve(entry.values)) or {}
end

local function Transform(entry, stored)
    if entry.read then return entry.read(stored) end
    return stored
end

function Schema:Read(entry, context)
    if entry.getValue then
        return Transform(entry, entry.getValue(self.config, context))
    end

    local stored = self:Scope(context, entry)[entry.key]

    if stored == nil then
        stored = self:Defaults(context, entry)[entry.key]
    end
    if stored == nil then
        stored = entry.default
    end
    if stored == nil then
        stored = Resolve(entry.fallback)
    end

    return Transform(entry, stored)
end

function Schema:Default(entry, context)
    -- A setting with its own accessor has no field to read a default from, so
    -- the entry has to carry one.
    if entry.getValue then
        return Transform(entry, entry.default)
    end

    local stored = self:Defaults(context, entry)[entry.key]
    if stored == nil then stored = entry.default end
    if stored == nil then stored = Resolve(entry.fallback) end

    return Transform(entry, stored)
end

function Schema:Write(entry, context, value)
    local scope = self:Scope(context, entry)

    local stored = value
    if entry.outlineWrite then
        stored = OUTLINE_TRANSFORM.write(value, scope[entry.key])
    elseif entry.write then
        stored = entry.write(value, scope[entry.key])
    end

    if entry.setValue then
        entry.setValue(self.config, context, stored)
    else
        scope[entry.key] = stored
    end

    if self.config and self.config.Save then
        self.config:Save()
    end

    if self.apply then
        self.apply(entry, context, stored)
    end
end

function Schema:IsHidden(entry, context)
    if not entry.hidden then return false end
    return entry.hidden(self:Scope(context, entry)) and true or false
end

function Schema:IsDisabled(entry, context)
    if not entry.disabled then return false end
    return entry.disabled(self:Scope(context, entry)) and true or false
end

--------------------------------------------------------------------------------
-- Selection
--------------------------------------------------------------------------------

function Schema:ForSurface(surface)
    local out = {}
    for _, entry in ipairs(self.entries) do
        if entry.kind and (entry.surface == "both" or entry.surface == surface) then
            out[#out + 1] = entry
        end
    end
    return out
end

-- The same, grouped, skipping any section this surface has nothing in.
function Schema:SectionsForSurface(surface)
    local bySection = {}
    for _, entry in ipairs(self:ForSurface(surface)) do
        bySection[entry.section] = bySection[entry.section] or {}
        local list = bySection[entry.section]
        list[#list + 1] = entry
    end

    local out = {}
    for _, section in ipairs(self.sections) do
        local entries = bySection[section.key]
        if entries and #entries > 0 then
            out[#out + 1] = { key = section.key, label = section.label, entries = entries }
        end
    end
    return out
end

return SettingsSchema
