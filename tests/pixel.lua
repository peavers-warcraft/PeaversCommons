--------------------------------------------------------------------------------
-- UI/Pixel.lua, driven against stand-in globals.
--
--   Run: lua tests/pixel.lua        (from the addon root)
--
-- Plain Lua on purpose. The arithmetic in Pixel.lua is the kind that is easy to
-- get subtly wrong and impossible to eyeball in game - a line half a pixel out
-- looks like a line - and none of it needs a client to check: given a screen
-- height and a scale, there is one right answer.
--
-- Not addon code, and not packaged (see .pkgmeta). It overwrites globals on
-- purpose to drive the file under test.
---@diagnostic disable: undefined-global, duplicate-set-field, lowercase-global, missing-fields
--------------------------------------------------------------------------------

local screenHeight, uiScale = 1080, 1.0
local frames = {}

_G = _G or _ENV
_G.GetPhysicalScreenSize = function() return screenHeight * 16 / 9, screenHeight end
_G.UIParent = { GetScale = function() return uiScale end }
_G.CreateFrame = function()
    local f = { events = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:SetScript(_, fn) self.script = fn end
    frames[#frames + 1] = f
    return f
end
-- No C_Timer: Pixel falls back to refreshing straight away, which is what we want
-- in a test with no frame loop.
_G.PeaversCommons = {}

local Pixel = dofile("src/UI/Pixel.lua")

local function Texture()
    local t = {}
    function t:SetWidth(v) self.w = v end
    function t:SetHeight(v) self.h = v end
    return t
end

local function Close(a, b) return math.abs(a - b) < 1e-9 end
local checks = 0
local function Check(cond, msg)
    checks = checks + 1
    if not cond then error("FAIL: " .. msg, 2) end
end

--------------------------------------------------------------------------------
-- The arithmetic
--------------------------------------------------------------------------------

-- Pixel perfect: one unit is one pixel, so nothing changes.
screenHeight, uiScale = 1080, 768 / 1080
Pixel:Refresh()
Check(Close(Pixel.mult, 1), "at the pixel perfect scale mult must be 1, got " .. Pixel.mult)

-- The pack's own canvas on a 1080p screen: 0.5333 scale, so one pixel is 1.333
-- units. This is the case the whole file exists for - SetHeight(1) here asks for
-- three quarters of a pixel.
screenHeight, uiScale = 1080, 768 / 1440
Pixel:Refresh()
Check(Close(Pixel.mult, 4 / 3), "0.5333 on 1080p should give mult 1.333, got " .. Pixel.mult)

-- 4K at the same canvas: one pixel is 2.666 units.
screenHeight, uiScale = 2160, 768 / 1440
Pixel:Refresh()
Check(Close(Pixel.mult, (768 / 2160) / (768 / 1440)), "4K mult wrong, got " .. Pixel.mult)

--------------------------------------------------------------------------------
-- A tracked line follows the scale
--------------------------------------------------------------------------------

screenHeight, uiScale = 1080, 768 / 1080
Pixel:Refresh()

local line = Pixel:Thin(Texture())
Check(Close(line.h, 1), "a one pixel line at pixel perfect should be 1 unit, got " .. tostring(line.h))

local edge = Pixel:Thin(Texture(), "width")
Check(Close(edge.w, 1), "a vertical line should set width, got " .. tostring(edge.w))
Check(edge.h == nil, "a vertical line must not set height")

local double = Pixel:Thin(Texture(), "height", 2)
Check(Close(double.h, 2), "two pixels should be 2 units at pixel perfect, got " .. tostring(double.h))

-- The scale moves under it: every tracked line follows without being asked.
uiScale = 768 / 1440
Pixel:Refresh()
Check(Close(line.h, 4 / 3), "a line did not follow the scale, got " .. tostring(line.h))
Check(Close(edge.w, 4 / 3), "a vertical line did not follow the scale, got " .. tostring(edge.w))
Check(Close(double.h, 8 / 3), "a two pixel line did not follow the scale, got " .. tostring(double.h))

-- Released lines stop following.
Pixel:Release(double)
uiScale = 768 / 1080
Pixel:Refresh()
Check(Close(line.h, 1), "a live line should have followed back")
Check(Close(double.h, 8 / 3), "a released line must stop being rewritten")

--------------------------------------------------------------------------------
-- Position hooks
--------------------------------------------------------------------------------

local owner, ran = {}, 0
Pixel:OnRefresh(owner, function() ran = ran + 1 end)
Pixel:Refresh()
Check(ran == 1, "a position hook should run on refresh, got " .. ran)

-- One broken hook must not stop the rest of the screen updating.
Pixel:OnRefresh({}, function() error("boom") end)
uiScale = 768 / 1440
Pixel:Refresh()
Check(Close(line.h, 4 / 3), "a throwing hook stopped the lines being re-sized")
Check(ran == 2, "a throwing hook stopped other hooks running")

--------------------------------------------------------------------------------
-- Snap
--------------------------------------------------------------------------------

screenHeight, uiScale = 1080, 768 / 1440   -- mult 1.3333
Pixel:Refresh()

-- 4 units is exactly three pixels at mult 4/3, and must survive intact. This is
-- the case the naive remainder gets wrong: 4 / (4/3) is 2.9999999999999996 in
-- floating point, so `x - x % mult` quietly returns two pixels' worth.
Check(Close(Pixel:Snap(4), 4), "an exact number of pixels must be left alone, got " .. Pixel:Snap(4))
Check(Close(Pixel:Snap(-4), -4), "the same below zero, got " .. Pixel:Snap(-4))

-- And a value that is genuinely between two pixels falls to the lower one.
Check(Close(Pixel:Snap(10), (4 / 3) * 7), "Snap(10) should fall to 7 pixels, got " .. Pixel:Snap(10))
Check(Close(Pixel:Snap(-10), -(4 / 3) * 7), "Snap(-10) should fall to -7 pixels, got " .. Pixel:Snap(-10))

Check(Pixel:Snap(0) == 0, "Snap(0) is 0")
Check(Close(Pixel:Snap(4 / 3), 4 / 3), "an exact pixel is left alone")
Check(Pixel:Snap("x") == "x", "Snap passes non-numbers through untouched")

-- Mirrored about zero: the whole point of handling the sign by hand.
Check(Close(Pixel:Snap(10), -Pixel:Snap(-10)), "Snap must be symmetric about zero")

--------------------------------------------------------------------------------
-- Degenerate screens
--------------------------------------------------------------------------------

local saved = _G.GetPhysicalScreenSize
_G.GetPhysicalScreenSize = function() return 0, 0 end
Pixel:Refresh()
Check(Pixel.mult > 0, "a screen with no height must not give a mult of zero")
_G.GetPhysicalScreenSize = saved

_G.GetPhysicalScreenSize = nil
Pixel:Refresh()
Check(Pixel.mult > 0, "a client without the API must still give a usable mult")
_G.GetPhysicalScreenSize = saved

Pixel:Refresh()
Check(#frames == 1, "exactly one watcher frame, got " .. #frames)
Check(frames[1].events.UI_SCALE_CHANGED, "the watcher must listen for UI_SCALE_CHANGED")
Check(frames[1].events.DISPLAY_SIZE_CHANGED, "the watcher must listen for DISPLAY_SIZE_CHANGED")

print(("Pixel: %d checks passed"):format(checks))
