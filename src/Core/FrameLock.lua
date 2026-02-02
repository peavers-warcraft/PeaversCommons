--------------------------------------------------------------------------------
-- FrameLock Module
-- Provides consistent frame locking/dragging behavior across Peavers addons
--------------------------------------------------------------------------------

local PeaversCommons = _G.PeaversCommons
local FrameLock = {}
PeaversCommons.FrameLock = FrameLock

-- Apply frame lock settings from config to a frame
-- @param frame: The main frame to make lockable/draggable
-- @param contentFrame: Optional content frame that should also trigger dragging
-- @param config: Config table with lockPosition, framePoint, frameX, frameY fields
-- @param saveCallback: Optional function to call after dragging to save position
function FrameLock:ApplyFromConfig(frame, contentFrame, config, saveCallback)
    if not frame then return end
    if not config then return end

    local locked = config.lockPosition

    if locked then
        -- Lock the frame - disable dragging
        frame:SetMovable(false)
        frame:EnableMouse(true)
        frame:RegisterForDrag("")
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)

        if contentFrame then
            contentFrame:SetMovable(false)
            contentFrame:EnableMouse(true)
            contentFrame:RegisterForDrag("")
            contentFrame:SetScript("OnDragStart", nil)
            contentFrame:SetScript("OnDragStop", nil)
        end
    else
        -- Unlock the frame - enable dragging
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", function(f)
            f:StopMovingOrSizing()

            local point, _, _, x, y = f:GetPoint()
            config.framePoint = point
            config.frameX = x
            config.frameY = y

            if saveCallback then
                saveCallback()
            elseif config.Save then
                config:Save()
            end
        end)

        if contentFrame then
            contentFrame:SetMovable(true)
            contentFrame:EnableMouse(true)
            contentFrame:RegisterForDrag("LeftButton")
            contentFrame:SetScript("OnDragStart", function()
                frame:StartMoving()
            end)
            contentFrame:SetScript("OnDragStop", function()
                frame:StopMovingOrSizing()

                local point, _, _, x, y = frame:GetPoint()
                config.framePoint = point
                config.frameX = x
                config.frameY = y

                if saveCallback then
                    saveCallback()
                elseif config.Save then
                    config:Save()
                end
            end)
        end
    end
end

-- Toggle the lock state and apply
-- @param frame: The main frame
-- @param contentFrame: Optional content frame
-- @param config: Config table
-- @param saveCallback: Optional save callback
-- @return: New lock state (true = locked)
function FrameLock:Toggle(frame, contentFrame, config, saveCallback)
    if not config then return nil end

    config.lockPosition = not config.lockPosition
    self:ApplyFromConfig(frame, contentFrame, config, saveCallback)

    return config.lockPosition
end

-- Set a specific lock state
-- @param frame: The main frame
-- @param contentFrame: Optional content frame
-- @param config: Config table
-- @param locked: Boolean lock state
-- @param saveCallback: Optional save callback
function FrameLock:SetLocked(frame, contentFrame, config, locked, saveCallback)
    if not config then return end

    config.lockPosition = locked
    self:ApplyFromConfig(frame, contentFrame, config, saveCallback)
end

return FrameLock
