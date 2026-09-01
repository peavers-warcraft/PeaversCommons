--[[ UI/Capture.lua
  Stages an addon window for a marketing screenshot and records where it landed.

  WHAT THIS CANNOT DO, AND WHY THE DESIGN LOOKS LIKE THIS
  -------------------------------------------------------
  `Screenshot()` takes no arguments. It captures the whole screen, at whatever
  the client is running, into the client's own Screenshots folder. There is no
  region capture, no render-to-texture, and no way for Lua to write an image
  file. So an addon *cannot* crop, and "capture just this window" is impossible
  in the literal sense.

  What an addon can do is make the crop unambiguous for something outside the
  game. This module therefore does three things:

    1. Puts the target window alone on a full-screen opaque stage, so nothing
       else in the UI is in the frame.
    2. Draws four registration marks in a colour that cannot occur naturally,
       positioned so their inner corners are exactly the crop rectangle.
    3. Records a manifest row in SavedVariables saying which addon, which
       window, and which file the shot went to.

  The compositor (addons.peavers.io, scripts/shots) then crops on the marks.

  WHY MARKS RATHER THAN ARITHMETIC
  --------------------------------
  The rect can be computed: absolute UI units are `GetRect()` times
  `GetEffectiveScale()`, the coordinate space at scale 1 is always 768 units
  tall, so pixels-per-unit is `physicalHeight / 768`. That derivation is written
  down below and stored in the manifest, and it is *not* what the crop uses.

  It is a cross-check, because it is exactly the kind of thing that is wrong by
  a scale factor on somebody's ultrawide and produces a plausible, slightly
  cropped screenshot that nobody looks at closely. The marks are measured from
  the actual pixels of the actual file, so they are right whatever the client,
  the resolution or the UI scale is doing. When the two disagree by more than a
  couple of pixels the compositor says so - which is the only way anyone would
  ever find out that the arithmetic drifted.

  THE STAGE DOES NOT HIDE UIParent
  --------------------------------
  The obvious way to clear the screen is `UIParent:Hide()`, keeping the target
  on a parentless frame. It works, and it puts the entire UI - including every
  other addon and the target's own restore path - behind one call that a Lua
  error in `prepare` would leave the player staring at.

  An opaque frame at FULLSCREEN_DIALOG covers all of it instead, and a stuck
  stage is one visible thing to click away rather than a UI that is simply gone.
  Only TOOLTIP strata draws above, so `GameTooltip` is hidden for the duration
  unless a target asks for it.

  TWO PASSES, AND WHY THE FORMAT IS TGA
  -------------------------------------
  `Theme.Colors.bgBase` has alpha 0.97. A window captured over one background
  has 3% of that background baked into it, so a single capture can only ever be
  composited back onto the colour it was shot on. Shooting each window twice,
  once on white and once on black, recovers true alpha:

      alpha = 1 - (white - black),  colour = black / alpha

  That is 3% for the backdrop and everything for antialiased edges and the
  Shadow64 texture, and it is what lets one capture sit on the paper plate, a
  promo banner and a social card without being re-shot.

  It also means the two files must agree bit for bit on every pixel that is not
  the background. JPEG does not: at quality 10 the differences the equation
  reads are the same size as the ringing around a hairline, and the magenta
  marks smear across a couple of pixels of chroma as well. So a run switches
  `screenshotFormat` to tga and puts it back afterwards. A 1440p TGA is about
  11 MB and a full sweep of the family writes a few hundred MB, once.

  `screenshotSizeOverride` is deliberately left alone. It changes the file's
  dimensions without changing anything this code can observe, and the marks make
  it unnecessary.

  THE MANIFEST IS NOT ON DISK UNTIL YOU RELOAD
  --------------------------------------------
  SavedVariables are written at logout or `/reload`, so the manifest for a run
  does not exist as a file until then. The run says so when it finishes. Without
  that line the compositor finds a pile of screenshots and no manifest, which
  reads as the addon having failed rather than as the run not having been
  flushed yet.
]]

local PeaversCommons = _G.PeaversCommons
local Capture = {}
PeaversCommons.Capture = Capture

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------

--- The registration mark colour. Pure magenta appears nowhere in the palette,
--- nowhere in Blizzard's frame art, and nowhere in a WoW landscape. The
--- compositor thresholds on "much more magenta than anything else", so the
--- exact value matters less than it being unreachable by accident.
local MARK_COLOR = { 1, 0, 1 }

--- Mark size in stage units. Large enough to survive any downscaling the client
--- applies and to be found by a coarse scan, small enough to fit beside a window
--- that nearly fills the stage.
local MARK_SIZE = 24

--- Seconds between the stage being arranged and the shutter. One frame would do
--- in principle; a fifth of a second also covers a bar animating to its value or
--- a texture streaming in, either of which photographs as a half-drawn window.
local SETTLE = 0.2

--- Seconds between successive shots. The client names a screenshot from the
--- clock to the second, so two shots inside one second collide on one filename
--- and the run silently ends up one file short.
local INTERVAL = 1.2

--- The most a window is magnified before the shutter.
---
--- Magnifying in game is not the same as enlarging the image afterwards: fonts
--- re-rasterise at the larger size and the backdrops are solid colour, so this
--- is real detail rather than interpolation. It is where the sharpness in a
--- finished shot comes from, and the compositor cannot make up for a capture
--- taken too small.
---
--- FitScale takes it down to whatever the screen allows, so this is a ceiling
--- and small windows are the ones that reach it. That makes the magnification
--- effectively per-window, which is a deliberate reversal: this was 2 and fixed,
--- on the argument that a pace bar at 4x and a config panel at 1x would carry
--- their hairlines at different thicknesses. True, but the alternative is worse
--- - a small window captured at 2x arrives at a few hundred pixels, and nothing
--- downstream can enlarge it again without it going soft. Fill the frame in the
--- client, where the enlargement is free.
---
--- 4 rather than higher because Theme.Textures are bitmaps: the fonts stay sharp
--- at any magnification but Shadow64 and the rounded fills do not.
local SCALE = 4

--- Stage colours for the two passes, and the order they are taken in.
local PASSES = {
    { name = "black", color = { 0, 0, 0 } },
    { name = "white", color = { 1, 1, 1 } },
}

-- ---------------------------------------------------------------------------
-- The target table
--
-- A target says how to reach a window and, optionally, how to put it into a
-- state worth photographing. `path` is a dotted route from `_G` resolved at
-- capture time rather than a frame reference, because most of these frames do
-- not exist until their addon initialises and several are never given a global
-- name at all - PeaversDynamicStats' main window is reachable only as
-- `PeaversDynamicStats.Core.frame`.
--
-- Keeping them as strings also makes the table plain data, which is what lets
-- the offline test check every route without a running client.
--
-- Consumers override or extend with Capture:Register(); this table only exists
-- so that the common case needs no change in twenty-two addon repos.
-- ---------------------------------------------------------------------------

Capture.builtin = {
    {
        addon = "PeaversDynamicStats",
        id = "stats",
        label = "Secondary stats",
        path = "PeaversDynamicStats.Core.frame",
    },
    {
        addon = "PeaversItemLevel",
        id = "ilvl",
        label = "Group item levels",
        path = "PeaversItemLevel.Core.frame",
    },
    {
        addon = "PeaversConfig",
        id = "config",
        label = "Settings",
        path = "PeaversConfigFrame",
    },
    {
        addon = "PeaversUnitFrames",
        id = "frames",
        label = "Unit frames",
        -- Four separate top-level buttons. The crop is their union, so the
        -- finished image is the set as it is actually arranged rather than four
        -- disconnected shots.
        paths = {
            "PeaversUnitFramesPlayer",
            "PeaversUnitFramesTarget",
            "PeaversUnitFramesTargettarget",
            "PeaversUnitFramesFocus",
        },
    },
    {
        addon = "PeaversTalents",
        id = "builds",
        label = "Talent builds",
        path = "PeaversTalentsExportDialog",
    },
    {
        addon = "PeaversConsumables",
        id = "consumables",
        label = "Consumables",
        path = "PeaversConsumablesFrame",
    },
    {
        addon = "PeaversNeedThat",
        id = "needthat",
        label = "Loot tracker",
        path = "PeaversNeedThatFrame",
    },
    {
        addon = "PeaversRemembersYou",
        id = "remembers",
        label = "Player history",
        path = "PRYListFrame",
    },
    {
        addon = "PeaversCVars",
        id = "cvars",
        label = "CVar browser",
        path = "PeaversCVarsDialog",
    },
    {
        addon = "PeaversSplits",
        id = "pace",
        label = "Pace bar",
        path = "PeaversSplitsPaceBar",
    },
    {
        addon = "PeaversGetThere",
        id = "arrow",
        label = "Waypoint arrow",
        path = "PeaversGetThereArrow",
    },
    {
        addon = "BetterTogether",
        id = "dashboard",
        label = "Dashboard",
        path = "BetterTogetherPanel",
    },
    {
        addon = "PeaversCommons",
        id = "debug",
        label = "Debug log",
        path = "PeaversDebugDialog",
    },
}

--- Targets added by consumer addons, keyed the same way as the built-ins.
Capture.registered = {}

---Register a capture target, or replace a built-in one.
---
---Called by an addon that wants a demo state set up before the shutter, or that
---has a second window worth showing. A target whose `addon` and `id` match a
---built-in replaces it, so an addon can improve its own entry without the
---built-in list needing to know.
---@param addonName string
---@param target table
function Capture:Register(addonName, target)
    if type(target) ~= "table" then return end
    target.addon = addonName
    target.id = target.id or "main"
    table.insert(self.registered, target)
end

---Every target, with registered entries shadowing built-ins of the same key.
---@return table[]
function Capture:Targets()
    local byKey, order = {}, {}

    local function put(target)
        local key = target.addon .. ":" .. (target.id or "main")
        if byKey[key] == nil then table.insert(order, key) end
        byKey[key] = target
    end

    for _, target in ipairs(self.builtin) do put(target) end
    for _, target in ipairs(self.registered) do put(target) end

    local out = {}
    for _, key in ipairs(order) do table.insert(out, byKey[key]) end
    return out
end

-- ---------------------------------------------------------------------------
-- Resolving a target to frames
-- ---------------------------------------------------------------------------

---Walk a dotted route from `_G`, e.g. "PeaversDynamicStats.Core.frame".
---
---Returns nil rather than erroring for every failure - a route into an addon
---that is not installed is the normal case on any given machine, not a fault.
---@param path string
---@param env table? defaults to _G; the tests pass a fake
---@return table|nil
function Capture:Resolve(path, env)
    if type(path) ~= "string" or path == "" then return nil end

    local node = env or _G
    for step in string.gmatch(path, "[^.]+") do
        if type(node) ~= "table" then return nil end
        node = node[step]
        if node == nil then return nil end
    end

    return node
end

---The frames a target names, in order, skipping any that do not resolve.
---
---A target with four routes of which two resolve is still worth shooting; a
---target with none is skipped by the caller.
---@param target table
---@param env table?
---@return table[]
function Capture:FramesFor(target, env)
    local frames = {}

    if type(target.frame) == "function" then
        local ok, frame = pcall(target.frame)
        if ok and frame then table.insert(frames, frame) end
    end

    local paths = target.paths
    if not paths and target.path then paths = { target.path } end

    if paths then
        for _, path in ipairs(paths) do
            local frame = self:Resolve(path, env)
            if frame then table.insert(frames, frame) end
        end
    end

    return frames
end

-- ---------------------------------------------------------------------------
-- Geometry
--
-- Pure arithmetic, kept out of the staging code so the offline test can check
-- it against numbers rather than against a running client.
-- ---------------------------------------------------------------------------

---The union of several frames' rects, in the absolute (scale 1) UI space.
---
---`GetRect` answers in the frame's own scaled space, so each is multiplied by
---its own effective scale before they can be compared - two frames at different
---scales otherwise union into a box that contains neither.
---@param frames table[]
---@return number? left
---@return number? bottom
---@return number? width
---@return number? height
function Capture:UnionRect(frames)
    local minL, minB, maxR, maxT

    for _, frame in ipairs(frames) do
        if frame.GetRect and frame.GetEffectiveScale then
            local left, bottom, width, height = frame:GetRect()
            if left and bottom and width and height then
                local scale = frame:GetEffectiveScale() or 1
                local l, b = left * scale, bottom * scale
                local r, t = l + width * scale, b + height * scale

                if not minL or l < minL then minL = l end
                if not minB or b < minB then minB = b end
                if not maxR or r > maxR then maxR = r end
                if not maxT or t > maxT then maxT = t end
            end
        end
    end

    if not minL then return nil end
    return minL, minB, maxR - minL, maxT - minB
end

---How much to magnify a block of this size so it still fits on the stage.
---
---SCALE is what we want; this is what the screen allows. The 0.86 leaves room
---for the registration marks, which sit outside the crop - a window magnified
---until it exactly filled the screen would push its own marks off the edge, and
---the compositor would then find two of four and refuse the shot.
---@param width number block width in stage units at 1x
---@param height number
---@param stageWidth number
---@param stageHeight number
---@return number
function Capture:FitScale(width, height, stageWidth, stageHeight)
    if width <= 0 or height <= 0 then return 1 end

    local room = 0.86
    local fit = math.min((stageWidth * room) / width, (stageHeight * room) / height)

    -- Below 1 when the window is larger than the screen. Shrinking is the only
    -- way to photograph it whole, so it is allowed rather than clamped.
    return math.min(SCALE, fit)
end

---Convert an absolute-UI-space rect to pixels in the screenshot, measured from
---the top left.
---
---The UI coordinate space at scale 1 is always 768 units tall whatever the
---resolution, which is the whole of the conversion: one unit is
---`physicalHeight / 768` pixels, on both axes, because the pixels are square.
---
---This is the cross-check, not the crop. See the header.
---@param left number
---@param bottom number
---@param width number
---@param height number
---@param physicalWidth number
---@param physicalHeight number
---@return table rect {x, y, w, h}
function Capture:ToPixels(left, bottom, width, height, physicalWidth, physicalHeight)
    local perUnit = physicalHeight / 768

    return {
        x = left * perUnit,
        -- GetRect measures up from the bottom, images measure down from the top.
        y = physicalHeight - (bottom + height) * perUnit,
        w = width * perUnit,
        h = height * perUnit,
        perUnit = perUnit,
        screenW = physicalWidth,
        screenH = physicalHeight,
    }
end

-- ---------------------------------------------------------------------------
-- The stage
-- ---------------------------------------------------------------------------

local stage, marks

---Build the stage once and keep it. It is hidden between runs.
local function EnsureStage()
    if stage then return stage end

    stage = CreateFrame("Frame", "PeaversCaptureStage", UIParent)
    stage:SetAllPoints(UIParent)
    stage:SetFrameStrata("FULLSCREEN_DIALOG")
    stage:SetFrameLevel(1)
    stage:EnableMouse(true) -- swallow clicks so nothing underneath reacts
    stage:Hide()

    stage.bg = stage:CreateTexture(nil, "BACKGROUND")
    stage.bg:SetAllPoints(stage)
    stage.bg:SetColorTexture(0, 0, 0, 1)

    marks = {}
    for i = 1, 4 do
        local mark = stage:CreateTexture(nil, "OVERLAY")
        mark:SetSize(MARK_SIZE, MARK_SIZE)
        mark:SetColorTexture(MARK_COLOR[1], MARK_COLOR[2], MARK_COLOR[3], 1)
        marks[i] = mark
    end

    return stage
end

---Place the four marks so their inner corners are exactly the crop rectangle.
---
---Each mark sits diagonally outside one corner and touches the crop at a single
---point: the top-left mark's bottom-right corner *is* the crop's top-left. Along
---the edges of the crop there is no mark at all, so a mark's own antialiasing
---can only ever reach the one corner pixel of the finished image.
---
---Coordinates are stage units measured from the stage's bottom-left, which is
---the screen's bottom-left because the stage covers UIParent.
---@param left number
---@param bottom number
---@param width number
---@param height number
local function PlaceMarks(left, bottom, width, height)
    local right, top = left + width, bottom + height

    marks[1]:ClearAllPoints()
    marks[1]:SetPoint("BOTTOMRIGHT", stage, "BOTTOMLEFT", left, top)

    marks[2]:ClearAllPoints()
    marks[2]:SetPoint("BOTTOMLEFT", stage, "BOTTOMLEFT", right, top)

    marks[3]:ClearAllPoints()
    marks[3]:SetPoint("TOPRIGHT", stage, "BOTTOMLEFT", left, bottom)

    marks[4]:ClearAllPoints()
    marks[4]:SetPoint("TOPLEFT", stage, "BOTTOMLEFT", right, bottom)

    for _, mark in ipairs(marks) do mark:Show() end
end

-- ---------------------------------------------------------------------------
-- Saving and restoring a frame
-- ---------------------------------------------------------------------------

---Everything the stage is about to change, so it can be put back exactly.
---
---Points are captured individually rather than as "it was centred": most of
---these windows are user-positioned and dragged, and restoring them to the
---middle of the screen would quietly rearrange somebody's UI as the price of
---taking a screenshot.
local function SaveState(frame)
    local points = {}
    for i = 1, frame:GetNumPoints() do
        points[i] = { frame:GetPoint(i) }
    end

    return {
        frame = frame,
        parent = frame:GetParent(),
        strata = frame:GetFrameStrata(),
        level = frame:GetFrameLevel(),
        scale = frame:GetScale(),
        alpha = frame:GetAlpha(),
        shown = frame:IsShown(),
        points = points,
    }
end

local function RestoreState(state)
    local frame = state.frame

    frame:ClearAllPoints()
    frame:SetParent(state.parent)
    frame:SetFrameStrata(state.strata)
    frame:SetFrameLevel(state.level)
    frame:SetScale(state.scale)
    frame:SetAlpha(state.alpha)

    for _, point in ipairs(state.points) do
        -- pcall: a point anchored to a frame that has since gone away would
        -- error here, and failing to restore one window must not abandon the
        -- rest of the run with the stage still up.
        pcall(function() frame:SetPoint(point[1], point[2], point[3], point[4], point[5]) end)
    end

    if state.shown then frame:Show() else frame:Hide() end
end

-- ---------------------------------------------------------------------------
-- The manifest
-- ---------------------------------------------------------------------------

---The filename the client is about to choose.
---
---WoW names a screenshot `WoWScrnShot_MMDDYY_HHMMSS` from the local clock, so
---this is predictable rather than discoverable - there is no API that reports
---the file that was just written. INTERVAL keeps two shots out of the same
---second, which is the only way this goes wrong.
---@param extension string
---@return string
function Capture:PredictFilename(extension)
    return "WoWScrnShot_" .. date("%m%d%y_%H%M%S") .. "." .. extension
end

local function Manifest()
    PeaversCommonsDB = PeaversCommonsDB or {}
    PeaversCommonsDB.capture = PeaversCommonsDB.capture or {}
    PeaversCommonsDB.capture.shots = PeaversCommonsDB.capture.shots or {}
    return PeaversCommonsDB.capture.shots
end

-- ---------------------------------------------------------------------------
-- Running a capture
-- ---------------------------------------------------------------------------

local running = false
local previousFormat, previousQuality

local function Say(...)
    print("|cff3abdf7Peavers|rCapture:", ...)
end

---Put the client into lossless screenshots, remembering what it was on.
local function BeginRun()
    previousFormat = GetCVar("screenshotFormat")
    previousQuality = GetCVar("screenshotQuality")
    SetCVar("screenshotFormat", "tga")
    SetCVar("screenshotQuality", "10")
end

local function EndRun()
    if previousFormat then SetCVar("screenshotFormat", previousFormat) end
    if previousQuality then SetCVar("screenshotQuality", previousQuality) end
    previousFormat, previousQuality = nil, nil

    if stage then stage:Hide() end
    running = false
end

---Stage one target for one pass and fire the shutter.
---
---`onDone` is called after the shot regardless of outcome, so a target that
---fails to stage does not strand the queue.
local function Shoot(target, pass, onDone)
    local frames = Capture:FramesFor(target)
    if #frames == 0 then return onDone(false, "no frame") end

    local states = {}
    for i, frame in ipairs(frames) do states[i] = SaveState(frame) end

    local function restoreAll()
        for i = #states, 1, -1 do pcall(RestoreState, states[i]) end
    end

    local ok, err = pcall(function()
        EnsureStage()
        stage.bg:SetColorTexture(pass.color[1], pass.color[2], pass.color[3], 1)
        stage:Show()

        if target.prepare then target.prepare() end
        for _, frame in ipairs(frames) do frame:Show() end
    end)

    if not ok then
        restoreAll()
        if stage then stage:Hide() end
        return onDone(false, tostring(err))
    end

    -- A frame later, `prepare` has run and anything it showed has laid out, so
    -- the rects are worth reading. Reading them in the same tick returns where
    -- the windows were before, not where they now are.
    C_Timer.After(0.05, function()
        local uLeft, uBottom, uWidth, uHeight = Capture:UnionRect(frames)
        if not uLeft or uWidth <= 0 or uHeight <= 0 then
            restoreAll()
            stage:Hide()
            return onDone(false, "empty rect")
        end

        -- The stage covers UIParent at its scale, so stage units are UIParent
        -- units. The union arrived in absolute (scale 1) units and comes back.
        local stageScale = stage:GetEffectiveScale()
        local magnify = Capture:FitScale(
            uWidth / stageScale, uHeight / stageScale,
            stage:GetWidth(), stage:GetHeight())

        -- Move the whole union as one block: every frame is re-anchored to the
        -- stage at its own offset *within* the union, so a multi-frame target
        -- keeps its arrangement. Centring each frame instead would stack the
        -- four unit frames on top of each other.
        local blockW = uWidth * magnify / stageScale
        local blockH = uHeight * magnify / stageScale
        local originX = (stage:GetWidth() - blockW) / 2
        local originY = (stage:GetHeight() - blockH) / 2

        for _, frame in ipairs(frames) do
            local fLeft, fBottom = frame:GetRect()
            local fScale = frame:GetEffectiveScale() or 1
            local dx = (fLeft * fScale - uLeft) * magnify / stageScale
            local dy = (fBottom * fScale - uBottom) * magnify / stageScale

            -- Its own scale times the magnification, so frames that the user
            -- had at different sizes stay at different sizes relative to
            -- each other.
            local newScale = (frame:GetScale() or 1) * magnify

            frame:SetParent(stage)
            frame:SetFrameStrata("FULLSCREEN_DIALOG")
            frame:SetFrameLevel(10)
            frame:SetScale(newScale)
            frame:SetAlpha(1)
            frame:ClearAllPoints()
            -- SetPoint offsets are in the anchored frame's own coordinate
            -- space, and the frame is now a child of the stage, so a stage-unit
            -- position divides by the frame's scale to get there.
            frame:SetPoint("BOTTOMLEFT", stage, "BOTTOMLEFT",
                (originX + dx) / newScale, (originY + dy) / newScale)
        end

        PlaceMarks(originX, originY, blockW, blockH)

        local physicalWidth, physicalHeight = GetPhysicalScreenSize()
        local pixels = Capture:ToPixels(
            originX * stageScale, originY * stageScale,
            blockW * stageScale, blockH * stageScale,
            physicalWidth, physicalHeight)
        pixels.magnify = magnify

        C_Timer.After(SETTLE, function()
            local file = Capture:PredictFilename("tga")
            Screenshot()

            table.insert(Manifest(), {
                addon = target.addon,
                id = target.id or "main",
                label = target.label,
                pass = pass.name,
                file = file,
                mark = { size = MARK_SIZE, color = MARK_COLOR },
                scale = pixels.magnify,
                rect = pixels,
                taken = time(),
            })

            restoreAll()
            if target.restore then pcall(target.restore) end
            onDone(true)
        end)
    end)
end

---Shoot a list of targets, both passes each, one at a time.
---
---Sequential rather than parallel because the client has one shutter and one
---filename per second; the whole run is therefore about 2.4 seconds per window.
local function RunQueue(targets, passes)
    local queue = {}
    for _, target in ipairs(targets) do
        for _, pass in ipairs(passes) do
            table.insert(queue, { target = target, pass = pass })
        end
    end

    if #queue == 0 then
        Say("nothing to capture - none of the targets resolved to a frame.")
        return EndRun()
    end

    Say(("capturing %d window(s), %d shot(s), about %ds."):format(
        #targets, #queue, math.ceil(#queue * INTERVAL)))

    local index, taken, failed = 0, 0, {}

    local function step()
        index = index + 1
        local job = queue[index]

        if not job then
            EndRun()
            Say(("done - %d shot(s) written to your Screenshots folder."):format(taken))
            for _, failure in ipairs(failed) do
                Say(("  skipped %s: %s"):format(failure.name, failure.why))
            end
            -- The one instruction without which a successful run looks like a
            -- broken one: the manifest is still in memory at this point.
            Say("|cfffbbf24Type /reload now|r - the manifest is only written to disk on reload or logout.")
            return
        end

        Shoot(job.target, job.pass, function(ok, why)
            if ok then
                taken = taken + 1
            else
                table.insert(failed, {
                    name = job.target.addon .. ":" .. (job.target.id or "main") .. " (" .. job.pass.name .. ")",
                    why = why or "unknown",
                })
            end
            C_Timer.After(INTERVAL - SETTLE, step)
        end)
    end

    step()
end

---Capture one target, or every target that resolves.
---@param filter string? an addon name, a target id, or nil for everything
function Capture:Run(filter)
    if running then
        Say("a capture run is already going.")
        return
    end

    -- Reparenting and rescaling in combat is not protected for these frames,
    -- but a screenshot of a raid window mid-pull is not what anyone wants and
    -- the stage would blind the player for the duration.
    if InCombatLockdown() then
        Say("not in combat.")
        return
    end

    local wanted = {}
    for _, target in ipairs(self:Targets()) do
        local matches = not filter
            or string.lower(target.addon) == string.lower(filter)
            or string.lower(target.id or "") == string.lower(filter)

        if matches and #self:FramesFor(target) > 0 then
            table.insert(wanted, target)
        end
    end

    if #wanted == 0 then
        Say(filter and ("nothing matching '" .. filter .. "' is loaded and showing.")
            or "no capture targets resolved - are the addons loaded?")
        return
    end

    running = true
    BeginRun()
    RunQueue(wanted, PASSES)
end

---What would be captured, and what would not.
function Capture:List()
    Say("capture targets:")
    for _, target in ipairs(self:Targets()) do
        local frames = self:FramesFor(target)
        local state = #frames > 0
            and ("|cff4ade80ready|r (" .. #frames .. " frame(s))")
            or "|cff949494not loaded|r"
        print(("  %-22s %-12s %s"):format(target.addon, target.id or "main", state))
    end
    Say("shots recorded this session: " .. #Manifest())
end

---Forget the manifest. The image files are left alone.
function Capture:Clear()
    PeaversCommonsDB = PeaversCommonsDB or {}
    PeaversCommonsDB.capture = PeaversCommonsDB.capture or {}
    PeaversCommonsDB.capture.shots = {}
    Say("manifest cleared. Reload to write that to disk.")
end

-- ---------------------------------------------------------------------------
-- Slash command
--
-- Registered directly rather than through SlashCommands:Register, which assumes
-- a per-addon prefix with a config page behind it. This is one command shared
-- by the whole family and has no settings.
-- ---------------------------------------------------------------------------

function Capture:SetupSlash()
    _G.SLASH_PEAVERSCAPTURE1 = "/pshot"

    SlashCmdList["PEAVERSCAPTURE"] = function(input)
        local trimmed = string.gsub(input or "", "^%s*(.-)%s*$", "%1")
        local command, rest = string.match(trimmed, "^(%S*)%s*(.*)$")
        command = string.lower(command or "")

        if command == "" or command == "help" then
            Say("usage:")
            print("  |cffffff00/pshot list|r          - what can be captured right now")
            print("  |cffffff00/pshot all|r           - capture every loaded window")
            print("  |cffffff00/pshot <addon>|r       - capture one, e.g. /pshot PeaversDynamicStats")
            print("  |cffffff00/pshot clear|r         - forget the manifest")
            print("Shots go to your Screenshots folder; /reload writes the manifest.")
        elseif command == "list" then
            self:List()
        elseif command == "clear" then
            self:Clear()
        elseif command == "all" then
            self:Run(nil)
        else
            self:Run(rest ~= "" and rest or command)
        end
    end
end

-- Guarded so the offline test can load this file without stubbing the client's
-- slash-command plumbing: the geometry is what the test is about.
if _G.SlashCmdList then Capture:SetupSlash() end

return Capture
