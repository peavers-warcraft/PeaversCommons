--------------------------------------------------------------------------------
-- Core/EditModeSnap.lua - the geometry, driven without a client.
--
--   Run: lua tests/editmode_snap.lua        (from the addon root)
--
-- Plain Lua on purpose. Whether a frame dropped six pixels from another ends up
-- flush against it is arithmetic: given two rectangles and a range there is one
-- right answer, and "it looked about right in game" is how an off-by-one in a
-- snap survives for a year.
--
-- Only Snap.Resolve is exercised. The rest of the file reads frames and draws
-- lines, which needs a client.
--
-- Not addon code, and not packaged (see .pkgmeta).
---@diagnostic disable: undefined-global, lowercase-global, missing-fields
--------------------------------------------------------------------------------

_G = _G or _ENV
_G.PeaversCommons = {}

local Snap = dofile("src/Core/EditModeSnap.lua")

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

local function Rect(left, bottom, width, height, reach)
    return { left = left, right = left + width, bottom = bottom, top = bottom + height, reach = reach }
end

local RANGE = 8

-- Nothing in range: nothing moves and no guide is offered.
do
    local dx, dy, gx, gy = Snap.Resolve(Rect(100, 100, 50, 20), { Rect(400, 400, 50, 20) }, RANGE)
    Check("far: dx", dx, 0)
    Check("far: dy", dy, 0)
    Check("far: guideX", gx, nil)
    Check("far: guideY", gy, nil)
end

-- Stacking. Dropped five below and three right of another frame: the top goes
-- flush to its bottom and the left edges line up, each axis on its own.
do
    local target = Rect(200, 300, 120, 40)
    local dragged = Rect(203, 255, 120, 40)      -- top at 295, five short of 300
    local dx, dy, gx, gy = Snap.Resolve(dragged, { target }, RANGE)
    Check("stack: dx", dx, -3)
    Check("stack: dy", dy, 5)
    Check("stack: guideX", gx, 200)
    Check("stack: guideY", gy, 300)
end

-- Side by side: my left edge to its right edge.
do
    local target = Rect(200, 300, 100, 40)
    local dragged = Rect(306, 300, 80, 40)       -- six right of the target's right edge
    local dx, _, gx = Snap.Resolve(dragged, { target }, RANGE)
    Check("beside: dx", dx, -6)
    Check("beside: guideX", gx, 300)
end

-- Centres, for frames of different widths that share no edge.
do
    local target = Rect(200, 300, 100, 40)       -- centre x 250
    local dragged = Rect(214, 200, 66, 20)       -- centre x 247
    local dx, _, gx = Snap.Resolve(dragged, { target }, RANGE)
    Check("centre: dx", dx, 3)
    Check("centre: guideX", gx, 250)
end

-- The nearest line wins, not the first one found.
do
    local nearer = Rect(102, 500, 50, 20)
    local further = Rect(106, 700, 50, 20)
    local dx = Snap.Resolve(Rect(100, 100, 50, 20), { further, nearer }, RANGE)
    Check("nearest: dx", dx, 2)
end

-- Exactly at the range still snaps; a hair past it does not.
do
    local target = Rect(200, 300, 100, 40)
    local dx = Snap.Resolve(Rect(308, 300, 80, 40), { target }, RANGE)
    Check("edge of range: dx", dx, -8)
    dx = Snap.Resolve(Rect(308.5, 300, 80, 40), { target }, RANGE)
    Check("past range: dx", dx, 0)
end

-- Reach. A frame with one only offers its edges to a neighbour: the same
-- alignment that works across the screen for a collection frame is refused for
-- a Blizzard one that is nowhere near.
do
    local dragged = Rect(203, 100, 100, 40)
    local dx = Snap.Resolve(dragged, { Rect(200, 600, 100, 40) }, RANGE)
    Check("no reach: aligns at a distance", dx, -3)

    dx = Snap.Resolve(dragged, { Rect(200, 600, 100, 40, 16) }, RANGE)
    Check("reach: refused at a distance", dx, 0)

    -- Ten above the dragged frame's top is inside a reach of sixteen.
    dx = Snap.Resolve(dragged, { Rect(200, 150, 100, 40, 16) }, RANGE)
    Check("reach: accepted nearby", dx, -3)
end

-- The screen. An edge snaps to its own side and to the centre lines.
do
    local screen = { screen = true, width = 1920, height = 1080 }

    local dx, dy = Snap.Resolve(Rect(5, 4, 100, 40), { screen }, RANGE)
    Check("screen: left edge", dx, -5)
    Check("screen: bottom edge", dy, -4)

    dx, dy = Snap.Resolve(Rect(1814, 1037, 100, 40), { screen }, RANGE)
    Check("screen: right edge", dx, 6)
    Check("screen: top edge", dy, 3)

    local gx, gy
    dx, dy, gx, gy = Snap.Resolve(Rect(907, 523, 100, 40), { screen }, RANGE)
    Check("screen: centre x", dx, 3)       -- centre 957 -> 960
    Check("screen: centre y", dy, -3)      -- centre 543 -> 540
    Check("screen: centre guideX", gx, 960)
    Check("screen: centre guideY", gy, 540)

    -- A left edge near the right-hand side of the screen is not a snap: taking
    -- it would put the whole frame off the screen.
    dx = Snap.Resolve(Rect(1917, 500, 100, 40), { screen }, RANGE)
    Check("screen: left edge ignores right side", dx, 0)
end

-- The grid, and the tie-break: equally near a frame and a grid line, the frame
-- is what the user was aiming at.
do
    local grid = { grid = true, x = { 400 }, y = {} }
    local dx, _, gx = Snap.Resolve(Rect(404, 100, 50, 20), { grid }, RANGE)
    Check("grid: dx", dx, -4)
    Check("grid: guideX", gx, 400)

    -- Dragged left edge at 300: a grid line at 296 and a frame edge at 304.
    local frame = Rect(304, 500, 50, 20)
    local tied = { grid = true, x = { 296 }, y = {} }
    dx = Snap.Resolve(Rect(300, 100, 80, 20), { tied, frame }, RANGE)
    Check("tie: frame beats grid", dx, 4)

    -- But nearest still wins outright.
    local nearGrid = { grid = true, x = { 299 }, y = {} }
    dx = Snap.Resolve(Rect(300, 100, 80, 20), { nearGrid, frame }, RANGE)
    Check("nearer grid line beats frame", dx, -1)
end

-- A frame already exactly aligned reports no movement but still shows where it
-- sits, so the guide is on screen while it is held in place.
do
    local target = Rect(200, 300, 100, 40)
    local dx, dy, gx, gy = Snap.Resolve(Rect(200, 260, 100, 40), { target }, RANGE)
    Check("aligned: dx", dx, 0)
    Check("aligned: dy", dy, 0)
    Check("aligned: guideX", gx, 200)
    Check("aligned: guideY", gy, 300)
end

-- Calls do not leak into each other: the working state is reused between them.
do
    Snap.Resolve(Rect(203, 255, 120, 40), { Rect(200, 300, 120, 40) }, RANGE)
    local dx, dy, gx, gy = Snap.Resolve(Rect(900, 900, 10, 10), {}, RANGE)
    Check("reuse: dx", dx, 0)
    Check("reuse: dy", dy, 0)
    Check("reuse: guideX", gx, nil)
    Check("reuse: guideY", gy, nil)
end

print(("%d checks, %d failed"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
