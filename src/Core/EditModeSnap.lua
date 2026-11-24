--------------------------------------------------------------------------------
-- PeaversCommons EditModeSnap Module
--
-- Makes the frames in Edit Mode aware of each other: drag one near another and
-- it lines up, the way Blizzard's own frames do.
--
-- LibEditMode moves a frame and reports where it landed, and that is all - its
-- drag handler carries a "TODO: snap position to grid" where this would go.
-- Blizzard's answer, EditModeMagnetismManager, cannot be borrowed: it only
-- knows frames built on EditModeSystemMixin, and registering ours with it means
-- writing into tables that Blizzard's secure Edit Mode code then reads. So the
-- snapping is done here, reading Blizzard's frames without touching them.
--
-- A dragged frame snaps to:
--
--   other Edit Mode frames from the collection   edges and centres, anywhere
--   Blizzard's Edit Mode frames                  edges and centres, when close
--   the screen                                   its edges and its centre lines
--   Blizzard's grid                              while the Grid box is ticked
--
-- and it honours the Snap box in the Edit Mode window, so there is one switch
-- for all of it rather than one of ours beside one of theirs.
--
-- The snap happens when the frame is dropped, not while it is carried: the
-- client is the one moving the frame during a drag, and fighting it for the
-- position every frame makes the frame judder. What is shown while dragging is
-- where it *will* land - the same red guide lines Blizzard draws. Dropping then
-- nudges the frame onto them and tells the addon its new position, in exactly
-- the format it was already being told, so nothing about how a position is
-- saved changes and a snapped frame is not tied to what it snapped to.
--
-- One-way with Blizzard's frames, and that is a limit rather than an oversight:
-- ours line up with theirs, but theirs only know about each other.
--------------------------------------------------------------------------------

local PeaversCommons = _G.PeaversCommons
local Snap = {}
PeaversCommons.EditModeSnap = Snap

local LibEditMode = LibStub and LibStub("LibEditMode", true)

-- Blizzard's own figure (EditModeMagnetismManager.magnetismRange), measured in
-- the same thing theirs is: UIParent units times UIParent's effective scale.
Snap.RANGE = 8

-- How close a Blizzard frame has to be, on the other axis, before its edges are
-- offered. Blizzard only snaps a frame to a neighbour it overlaps or nearly
-- touches, and with thirty-odd system frames on the screen anything looser
-- turns every drag into a crawl from one stranger's edge to the next. Frames
-- from the collection are not held to this - lining the target frame up with
-- the player frame across the width of the screen is the point.
Snap.REACH = 16

-- Ranks only break ties. Nearest wins; when two lines are equally near, a frame
-- is a better thing to be lined up with than the screen, and the screen better
-- than a grid line.
local RANK_FRAME = 1
local RANK_SCREEN = 2
local RANK_GRID = 3

local EPSILON = 0.001

--------------------------------------------------------------------------------
-- The geometry
--
-- Plain numbers in, plain numbers out, so it can be checked without a client
-- (tests/editmode_snap.lua). Everything is in UIParent units with the origin at
-- the bottom left of the screen.
--------------------------------------------------------------------------------

-- The best candidate found so far on each axis. Reused between calls rather
-- than allocated, because Resolve runs every frame of a drag.
local bestX = {}
local bestY = {}

local function Reset(best)
    best.delta = nil
    best.at = nil
    best.rank = nil
    best.distance = nil
end

-- Offer one candidate: moving by `delta` would put an edge on the line `at`.
local function Offer(best, delta, at, rank, range)
    local distance = delta < 0 and -delta or delta
    if distance > range then return end

    local better = best.distance == nil
        or distance < best.distance - EPSILON
        or (distance <= best.distance + EPSILON and rank < best.rank)

    if better then
        best.delta = delta
        best.at = at
        best.rank = rank
        best.distance = distance
    end
end

-- How far apart two spans are along one axis. Zero when they overlap.
local function Gap(aLow, aHigh, bLow, bHigh)
    if aHigh < bLow then return bLow - aHigh end
    if bHigh < aLow then return aLow - bHigh end
    return 0
end

-- One axis of a frame against one axis of another: both edges to both edges,
-- and centre to centre. Edge to its own side is alignment, edge to the opposite
-- side is sitting flush against it, and one pass offers both.
local function OfferSpan(best, low, high, targetLow, targetHigh, rank, range)
    Offer(best, targetLow - low, targetLow, rank, range)
    Offer(best, targetHigh - high, targetHigh, rank, range)
    Offer(best, targetHigh - low, targetHigh, rank, range)
    Offer(best, targetLow - high, targetLow, rank, range)

    local centre = (low + high) / 2
    local targetCentre = (targetLow + targetHigh) / 2
    Offer(best, targetCentre - centre, targetCentre, rank, range)
end

-- A single line - a grid line, or the middle of the screen - which any of the
-- frame's two edges or its centre may sit on.
local function OfferLine(best, low, high, at, rank, range)
    Offer(best, at - low, at, rank, range)
    Offer(best, at - high, at, rank, range)
    Offer(best, at - (low + high) / 2, at, rank, range)
end

-- rect     { left, right, bottom, top } of the frame being dragged
-- targets  a list, each one of
--            { left, right, bottom, top, reach }   a frame; `reach` limits it
--                                                  to neighbours, nil does not
--            { screen = true, width, height }      the screen
--            { grid = true, x = {...}, y = {...} } grid lines
-- range    how near counts, in the same units
--
-- Returns dx, dy, guideX, guideY: how far to move, and the line on each axis
-- that the move lands on (nil where that axis did not snap).
function Snap.Resolve(rect, targets, range)
    Reset(bestX)
    Reset(bestY)

    range = range or Snap.RANGE

    for _, target in ipairs(targets) do
        if target.screen then
            -- An edge only snaps to its own side of the screen - the left edge
            -- of a frame sitting on the right edge of the screen is a frame
            -- that has left it - while the centre lines take anything.
            Offer(bestX, 0 - rect.left, 0, RANK_SCREEN, range)
            Offer(bestX, target.width - rect.right, target.width, RANK_SCREEN, range)
            OfferLine(bestX, rect.left, rect.right, target.width / 2, RANK_SCREEN, range)

            Offer(bestY, 0 - rect.bottom, 0, RANK_SCREEN, range)
            Offer(bestY, target.height - rect.top, target.height, RANK_SCREEN, range)
            OfferLine(bestY, rect.bottom, rect.top, target.height / 2, RANK_SCREEN, range)

        elseif target.grid then
            for _, x in ipairs(target.x) do
                OfferLine(bestX, rect.left, rect.right, x, RANK_GRID, range)
            end
            for _, y in ipairs(target.y) do
                OfferLine(bestY, rect.bottom, rect.top, y, RANK_GRID, range)
            end

        else
            local reach = target.reach

            -- A frame's left and right edges are only worth lining up with if
            -- it is near enough vertically to be seen as a neighbour, and the
            -- same the other way round.
            if not reach or Gap(rect.bottom, rect.top, target.bottom, target.top) <= reach then
                OfferSpan(bestX, rect.left, rect.right, target.left, target.right, RANK_FRAME, range)
            end
            if not reach or Gap(rect.left, rect.right, target.left, target.right) <= reach then
                OfferSpan(bestY, rect.bottom, rect.top, target.bottom, target.top, RANK_FRAME, range)
            end
        end
    end

    return bestX.delta or 0, bestY.delta or 0, bestX.at, bestY.at
end

--------------------------------------------------------------------------------
-- Reading the screen
--------------------------------------------------------------------------------

-- Midnight hands some frame geometry back as a secret value, and arithmetic on
-- one is an error rather than a wrong answer. Anything that will not say where
-- it is cannot be snapped to.
local issecret = rawget(_G, "issecretvalue")

local function IsUsable(value)
    return type(value) == "number" and not (issecret and issecret(value))
end

-- Where a frame is, in UIParent units. GetScaledRect answers in screen units
-- whatever the frame's own scale or its parents', which is what makes a scaled
-- frame line up with an unscaled one.
local function RectOf(region, into)
    if not region or not region.GetScaledRect then return nil end

    local ok, left, bottom, width, height = pcall(region.GetScaledRect, region)
    if not ok then return nil end
    if not (IsUsable(left) and IsUsable(bottom) and IsUsable(width) and IsUsable(height)) then
        return nil
    end
    if width <= 0 or height <= 0 then return nil end

    local scale = UIParent:GetEffectiveScale()
    if not scale or scale <= 0 then return nil end

    into = into or {}
    into.left = left / scale
    into.right = (left + width) / scale
    into.bottom = bottom / scale
    into.top = (bottom + height) / scale
    return into
end

-- Also what EditMode uses to stand the dialog beside a frame.
Snap.RectOf = RectOf

-- The Snap box in the Edit Mode window. Asked rather than cached: it can be
-- ticked while a frame is selected.
local function IsEnabled()
    local manager = rawget(_G, "EditModeManagerFrame")
    if manager and type(manager.IsSnapEnabled) == "function" then
        local ok, enabled = pcall(manager.IsSnapEnabled, manager)
        if ok then return enabled and true or false end
    end
    return true
end

local function AddFrame(targets, region, reach)
    local rect = RectOf(region)
    if rect then
        rect.reach = reach
        targets[#targets + 1] = rect
    end
end

-- Everything the dragged frame could line up with. Gathered once when the drag
-- starts: nothing else moves while one frame is being carried.
local function CollectTargets(dragged, reach)
    local targets = {}

    -- The collection's own frames first, so that on a dead heat with one of
    -- Blizzard's it is ours that wins. This is every frame registered with the
    -- shared LibEditMode, which is every frame with a handle to grab.
    if LibEditMode and LibEditMode.frameSelections then
        for frame in pairs(LibEditMode.frameSelections) do
            if frame ~= dragged and frame.IsVisible and frame:IsVisible() then
                AddFrame(targets, frame, nil)
            end
        end
    end

    local manager = rawget(_G, "EditModeManagerFrame")

    -- Blizzard's. Read, never written: the list and the frames in it belong to
    -- secure code. Blizzard measures a system by its selection overlay rather
    -- than the frame, since some overlays are padded, so this does too.
    local systems = manager and manager.registeredSystemFrames
    if type(systems) == "table" then
        for _, system in ipairs(systems) do
            pcall(function()
                if system == dragged then return end
                if system.IsForbidden and system:IsForbidden() then return end
                if not system:IsVisible() then return end
                AddFrame(targets, system.Selection or system, reach)
            end)
        end
    end

    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    if IsUsable(width) and IsUsable(height) and width > 0 and height > 0 then
        targets[#targets + 1] = { screen = true, width = width, height = height }

        -- The grid is drawn outwards from the middle of the screen, a line
        -- every `gridSpacing`, and only exists while it is showing.
        local grid = manager and manager.Grid
        local spacing = grid and grid.gridSpacing
        if grid and grid.IsShown and grid:IsShown() and IsUsable(spacing) and spacing > 0 then
            local lines = { grid = true, x = {}, y = {} }
            for i = 1, math.floor((width / spacing) / 2) do
                lines.x[#lines.x + 1] = width / 2 + i * spacing
                lines.x[#lines.x + 1] = width / 2 - i * spacing
            end
            for i = 1, math.floor((height / spacing) / 2) do
                lines.y[#lines.y + 1] = height / 2 + i * spacing
                lines.y[#lines.y + 1] = height / 2 - i * spacing
            end
            targets[#targets + 1] = lines
        end
    end

    return targets
end

--------------------------------------------------------------------------------
-- Guide lines
--
-- Blizzard's MagnetismPreviewLineTemplate, by hand: red, a pixel and a half,
-- the full height or width of the screen, on a HIGH frame over everything.
--------------------------------------------------------------------------------

local guides

local function CreateGuide(container)
    local line = container:CreateLine(nil, "OVERLAY")
    line:SetColorTexture(1, 0, 0, 1)

    local thickness = 1.5
    if PixelUtil and PixelUtil.GetNearestPixelSize then
        thickness = PixelUtil.GetNearestPixelSize(1.5, container:GetEffectiveScale(), 1.5)
    end
    line:SetThickness(thickness)
    line:Hide()

    return line
end

local function GetGuides()
    if guides then return guides end

    local container = CreateFrame("Frame", nil, UIParent)
    container:SetAllPoints(UIParent)
    container:SetFrameStrata("HIGH")

    guides = {
        vertical = CreateGuide(container),
        horizontal = CreateGuide(container),
    }
    return guides
end

local function ShowGuides(x, y)
    local lines = GetGuides()

    if x then
        lines.vertical:SetStartPoint("BOTTOMLEFT", UIParent, x, 0)
        lines.vertical:SetEndPoint("TOPLEFT", UIParent, x, 0)
    end
    lines.vertical:SetShown(x ~= nil)

    if y then
        lines.horizontal:SetStartPoint("BOTTOMLEFT", UIParent, 0, y)
        lines.horizontal:SetEndPoint("BOTTOMRIGHT", UIParent, 0, y)
    end
    lines.horizontal:SetShown(y ~= nil)
end

local function HideGuides()
    if not guides then return end
    guides.vertical:Hide()
    guides.horizontal:Hide()
end

--------------------------------------------------------------------------------
-- The drag
--------------------------------------------------------------------------------

-- The one drag in progress, if there is one: { selection, frame, targets, range }.
local active
local driver
local scratch = {}

local function OnUpdate()
    if not active then return end

    local rect = RectOf(active.frame, scratch)
    if not rect then
        HideGuides()
        return
    end

    local _, _, guideX, guideY = Snap.Resolve(rect, active.targets, active.range)
    ShowGuides(guideX, guideY)
end

local function Begin(selection)
    active = nil
    HideGuides()

    local frame = selection.parent or selection:GetParent()
    if not frame or InCombatLockdown() or not IsEnabled() then return end

    local scale = UIParent:GetEffectiveScale()
    if not scale or scale <= 0 then return end

    active = {
        selection = selection,
        frame = frame,
        range = Snap.RANGE / scale,
        targets = CollectTargets(frame, Snap.REACH / scale),
    }

    driver = driver or CreateFrame("Frame")
    driver:SetScript("OnUpdate", OnUpdate)
end

-- LibEditMode has already stopped the frame and reported where it is by the
-- time this runs. The nudge goes back through the library's own mover - the one
-- its arrow keys use - so the frame is re-anchored, the addon is told the new
-- position and the dialog's Reset button is updated, all by the code that
-- already does those things.
local function Finish(selection, apply)
    local state = active
    if not state or state.selection ~= selection then return end

    active = nil
    if driver then driver:SetScript("OnUpdate", nil) end
    HideGuides()

    if not apply or InCombatLockdown() or not IsEnabled() then return end

    local internal = LibEditMode and LibEditMode.internal
    if not internal or type(internal.MoveParent) ~= "function" then return end

    local rect = RectOf(state.frame, scratch)
    if not rect then return end

    local dx, dy = Snap.Resolve(rect, state.targets, state.range)
    if dx == 0 and dy == 0 then return end

    -- The library works in the frame's own units, so a frame drawn at half
    -- scale has to be told to move twice as far.
    local scale = state.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if not scale or scale <= 0 then return end

    internal:MoveParent(selection, dx / scale, dy / scale)
end

--------------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------------

-- Give a frame already registered with LibEditMode the snapping. Called by
-- EditMode:Register for every frame in the collection, so an addon gets this by
-- registering and does nothing else.
function Snap.Attach(_, frame)
    if not LibEditMode or not LibEditMode.frameSelections then return false end

    local selection = LibEditMode.frameSelections[frame]
    if not selection or selection.peaversSnap then return false end
    selection.peaversSnap = true

    -- Hooks, not replacements: the library's own handlers still start and stop
    -- the move, and these run after them.
    selection:HookScript("OnDragStart", Begin)
    selection:HookScript("OnDragStop", function(self) Finish(self, true) end)

    -- The library ends a drag itself when combat starts, calling its handler
    -- directly rather than through the script, and Edit Mode can be closed with
    -- a frame still in hand. Either way the drag is over and nothing snaps.
    selection:HookScript("OnEvent", function(self) Finish(self, false) end)
    selection:HookScript("OnHide", function(self) Finish(self, false) end)

    return true
end

function Snap.IsDragging(_)
    return active ~= nil
end

return Snap
