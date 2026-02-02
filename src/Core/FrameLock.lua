local MAJOR, MINOR = "PeaversCommons-FrameLock", 1
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

local PeaversCommons = _G.PeaversCommons

--[[
    FrameLock - Consolidated frame locking/dragging logic

    Extracted from PSB, PDS, and PIL to eliminate duplication.
    Handles frame dragging, position saving, and lock state.

    Usage:
        PeaversCommons.FrameLock:ApplyLock(frame, contentFrame, {
            lockPosition = true/false,
            saveCallback = function(point, x, y) ... end,
        })
]]

local FrameLock = {}
PeaversCommons.FrameLock = FrameLock

-- Applies lock state to a frame and optional content frame
-- @param frame The main frame to apply lock state to
-- @param contentFrame Optional content frame that should also be draggable (can be nil)
-- @param options Table with:
--   lockPosition: boolean - whether the frame is locked
--   saveCallback: function(point, x, y) - called when frame is moved
function FrameLock:ApplyLock(frame, contentFrame, options)
    if not frame then return end

    options = options or {}
    local locked = options.lockPosition
    local saveCallback = options.saveCallback

    if locked then
        -- Lock the frame
        frame:SetMovable(false)
        frame:EnableMouse(true)  -- Keep mouse enabled for tooltips
        frame:RegisterForDrag("")
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)

        -- Lock content frame if provided
        if contentFrame then
            contentFrame:SetMovable(false)
            contentFrame:EnableMouse(true)
            contentFrame:RegisterForDrag("")
            contentFrame:SetScript("OnDragStart", nil)
            contentFrame:SetScript("OnDragStop", nil)
        end
    else
        -- Unlock the frame
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", function(f)
            f:StopMovingOrSizing()

            -- Save position if callback provided
            if saveCallback then
                local point, _, _, x, y = f:GetPoint()
                saveCallback(point, x, y)
            end
        end)

        -- Unlock content frame if provided (drags the main frame)
        if contentFrame then
            contentFrame:SetMovable(true)
            contentFrame:EnableMouse(true)
            contentFrame:RegisterForDrag("LeftButton")
            contentFrame:SetScript("OnDragStart", function()
                frame:StartMoving()
            end)
            contentFrame:SetScript("OnDragStop", function()
                frame:StopMovingOrSizing()

                -- Save position if callback provided
                if saveCallback then
                    local point, _, _, x, y = frame:GetPoint()
                    saveCallback(point, x, y)
                end
            end)
        end
    end
end

-- Creates a standard save callback for an addon config
-- @param config The config table to save to
-- @param saveFunc Optional function to call after updating config (e.g., config:Save())
-- @return function The save callback
function FrameLock:CreateSaveCallback(config, saveFunc)
    return function(point, x, y)
        config.framePoint = point
        config.frameX = x
        config.frameY = y

        if saveFunc then
            saveFunc()
        end
    end
end

-- Applies lock from addon config (convenience method)
-- @param frame The main frame
-- @param contentFrame Optional content frame
-- @param config Addon config with lockPosition, framePoint, frameX, frameY fields
-- @param saveFunc Optional function to call after position changes (e.g., config:Save)
function FrameLock:ApplyFromConfig(frame, contentFrame, config, saveFunc)
    local saveCallback
    if config then
        saveCallback = self:CreateSaveCallback(config, saveFunc)
    end

    self:ApplyLock(frame, contentFrame, {
        lockPosition = config and config.lockPosition,
        saveCallback = saveCallback,
    })
end

-- Applies frame position from config
-- @param frame The frame to position
-- @param config Config table with framePoint, frameX, frameY fields
function FrameLock:ApplyPosition(frame, config)
    if not frame or not config then return end

    frame:ClearAllPoints()
    frame:SetPoint(
        config.framePoint or "CENTER",
        config.frameX or 0,
        config.frameY or 0
    )
end

return FrameLock
