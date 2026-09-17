--[[ UI/Pixel.lua
  One physical pixel, in UI units, at whatever scale is currently in force.

  THE PROBLEM. WoW draws in UI units, not pixels. A unit is a whole pixel only
  when UIParent's scale is exactly 768 / your screen height - "pixel perfect" -
  and at any other scale it is a fraction of one. The collection's own pack pins
  about 0.53 so its layouts land in the same place on every monitor, and offers a
  size slider from 70% to 200% on top of that, so the pixel perfect scale is the
  one scale most people are NOT on.

  What that does to a one pixel line: SetHeight(1) at a scale of 0.53 on a 1080p
  screen asks for 0.75 of a physical pixel. The client cannot draw three quarters
  of a pixel, so it draws something dimmer and softer than the line that was
  asked for - and, before snapping was switched off on these textures, sometimes
  nothing at all. Every hairline, every border and every bar edge in the
  collection is affected, on every screen that is not pixel perfect.

  THE FIX, borrowed from ElvUI, which has solved this for fifteen years. Do not
  try to be pixel perfect - that is a scale, and the scale is the player's to
  choose. Instead work out how many UI units one physical pixel is *at the
  current scale*, and draw one pixel wide things that many units wide:

      mult = (768 / physicalHeight) / UIParent:GetScale()

  At a scale of 0.53 on 1080p that is 1.333, so a line 1.333 units tall comes out
  exactly one pixel. At pixel perfect it is 1.0 and nothing changes. ElvUI calls
  this E.mult and runs every coordinate through E:Scale; this file is the same
  arithmetic with the parts the collection actually needs.

  WHY A REGISTRY. `mult` depends on the scale, and the scale changes after these
  textures are created - PeaversScaler applies one at login, and the installer's
  size screen changes it while you watch. A line sized once at creation would be
  right until the first change and wrong afterwards, so anything sized in pixels
  is tracked and re-sized when the scale moves. Weak keys, so a texture belonging
  to a frame nobody references any more is collected rather than kept alive by
  this table.

  Depends on nothing but the globals. It is loaded before Theme and Style, which
  are its first consumers.
]]

local PeaversCommons = _G.PeaversCommons
local Pixel = {}
PeaversCommons.Pixel = Pixel

-- WoW's virtual screen height at a scale of 1.0. The one constant the whole of
-- this file is derived from.
local UI_HEIGHT = 768

-- The scale that would make one UI unit one physical pixel.
Pixel.perfect = 1
-- What UIParent is actually set to.
Pixel.scale = 1
-- UI units in one physical pixel: perfect / scale.
Pixel.mult = 1

-- texture -> { axis = "height"|"width", count = <pixels> }
local tracked = setmetatable({}, { __mode = "k" })

-- owner -> function, for the things measured in pixels that are not sizes. A
-- border's corner inset is the case this exists for: it is an anchor offset, and
-- re-sizing the four bars without re-anchoring them leaves the corners either
-- doubled or gapped.
--
-- Keyed on the frame rather than on the callback, and weak, so the work stops
-- when the frame it belongs to is gone. Keying it on the object Style.Border
-- returns would not do: most callers throw that away and keep only the frame.
local hooks = setmetatable({}, { __mode = "k" })

local function Resize(texture, entry)
    local size = Pixel.mult * entry.count
    if entry.axis == "width" then
        texture:SetWidth(size)
    else
        texture:SetHeight(size)
    end
end

--- Recompute from the live screen and scale, and re-size everything tracked.
---
--- Safe to call at any time and cheap enough not to matter: the registry only
--- ever holds the collection's own hairlines and borders, which is tens of
--- textures rather than thousands.
function Pixel:Refresh()
    local height
    if type(_G.GetPhysicalScreenSize) == "function" then
        local ok, _, physical = pcall(_G.GetPhysicalScreenSize)
        if ok and type(physical) == "number" and physical > 0 then
            height = physical
        end
    end

    local scale = _G.UIParent and _G.UIParent:GetScale() or 1
    if type(scale) ~= "number" or scale <= 0 then scale = 1 end

    self.perfect = height and (UI_HEIGHT / height) or 1
    self.scale = scale
    self.mult = self.perfect / scale

    -- A guard rather than a real case: a mult of zero would make every line
    -- vanish, and one that is not a number would error on every Resize.
    if self.mult ~= self.mult or self.mult <= 0 then self.mult = 1 end

    for texture, entry in pairs(tracked) do
        Resize(texture, entry)
    end

    -- pcall because a hook is somebody else's closure over a frame that may have
    -- been taken apart since. One border that cannot re-anchor itself must not
    -- stop every other line on screen being re-sized.
    for _, hook in pairs(hooks) do
        pcall(hook)
    end
end

--- Run `fn` whenever the pixel size changes, for as long as `owner` is alive.
--- For pixel measurements that are positions rather than sizes.
function Pixel:OnRefresh(owner, fn)
    hooks[owner] = fn
end

--- How many UI units `count` physical pixels are, right now.
---
--- For sizes worked out once at draw time and not kept - a border inset, a gap
--- that wants to be exactly two pixels. Anything that has to survive a change of
--- scale should be registered with Thin instead.
--- @param count number|nil defaults to 1
function Pixel:Size(count)
    return self.mult * (count or 1)
end

--- Truncate a coordinate to a whole number of physical pixels, towards zero.
---
--- ElvUI's E:Scale, restated. A frame edge on a fraction of a pixel is what
--- makes a border look soft on one side and sharp on the other, and this is what
--- every position would go through if the collection ever drew frames from one
--- place rather than each module drawing its own.
function Pixel:Snap(value)
    if type(value) ~= "number" then return value end

    local m = self.mult
    if m <= 0 or value == 0 then return value end

    -- Counted in whole pixels rather than taken as a remainder. ElvUI's version
    -- is `x - x % mult`, which is the same idea and loses a pixel on the values
    -- that are already an exact number of them: with mult 4/3, 4 is exactly
    -- three pixels, but 4 / (4/3) comes out of the floating point unit as
    -- 2.9999999999999996 and the remainder throws the third one away.
    --
    -- The epsilon is what stops that. It is far below half a pixel, so it can
    -- only ever rescue a value that was meant to be exact.
    --
    -- Sign handled by hand, towards zero: Lua's % takes the sign of its divisor,
    -- and a coordinate above the middle of the screen must not round the other
    -- way from its mirror image below it.
    local sign = value < 0 and -1 or 1
    local steps = math.floor((value * sign) / m + 1e-9)
    return sign * steps * m
end

--- Size a texture in physical pixels, and keep it that size when the scale moves.
--- @param texture table
--- @param axis string|nil "height" (default) or "width"
--- @param count number|nil how many pixels; defaults to 1
--- @return table texture
function Pixel:Thin(texture, axis, count)
    local entry = { axis = axis == "width" and "width" or "height", count = count or 1 }
    tracked[texture] = entry
    Resize(texture, entry)
    return texture
end

--- Stop tracking a texture. Rarely needed - the registry is weak - but a texture
--- being reused for something that is no longer a line should not keep having
--- its size rewritten underneath it.
function Pixel:Release(texture)
    tracked[texture] = nil
end

--------------------------------------------------------------------------------
-- Keeping up with the scale
--
-- UI_SCALE_CHANGED covers the CVar being written, which is what Blizzard's own
-- settings and PeaversScaler both do. DISPLAY_SIZE_CHANGED covers the window
-- being resized, which changes the physical height and therefore the pixel size
-- without anybody touching the scale.
--
-- Deferred a frame in both cases. UI_SCALE_CHANGED fires synchronously from
-- SetCVar, before an addon that writes the CVar and then calls SetScale with a
-- truer value has made its second call - PeaversScaler does exactly that for any
-- scale outside the CVar's own [0.64, 1.15] clamp. Reading the scale on the next
-- frame reads the one that ended up applied rather than the one in flight.
--------------------------------------------------------------------------------

local pending = false

local function RefreshSoon()
    if pending then return end
    pending = true

    if type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function" then
        _G.C_Timer.After(0, function()
            pending = false
            Pixel:Refresh()
        end)
    else
        pending = false
        Pixel:Refresh()
    end
end

Pixel.RefreshSoon = RefreshSoon

if _G.CreateFrame then
    local watcher = _G.CreateFrame("Frame")
    watcher:RegisterEvent("UI_SCALE_CHANGED")
    watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:SetScript("OnEvent", RefreshSoon)
end

-- At load, so anything drawn before the first event is already the right size.
Pixel:Refresh()

return Pixel
