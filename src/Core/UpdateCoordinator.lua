local MAJOR, MINOR = "PeaversCommons-UpdateCoordinator", 1
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

local PeaversCommons = _G.PeaversCommons

--[[
    UpdateCoordinator - Debounced event batching for UI updates

    Based on PeaversItemLevel's update coordination pattern.
    Prevents excessive UI updates by batching multiple events into single updates.

    Update Priority (higher priority wins):
        1. fullRebuild  - Complete rebuild of all bars
        2. sortRequired - Re-sort and reposition bars
        3. dataRefresh  - Update existing bar values only

    Usage:
        local coordinator = PeaversCommons.UpdateCoordinator:New({
            debounceInterval = 0.1,
            combatBehavior = "dataRefreshOnly",  -- or "normal" or "defer"
            updateHandlers = {
                fullRebuild = function() addon.BarManager:RebuildBars() end,
                sortRequired = function() addon.BarManager:ReorderBars() end,
                dataRefresh = function() addon.BarManager:UpdateAllBars() end,
            }
        })

        coordinator:ScheduleUpdate("dataRefresh")
]]

local UpdateCoordinator = {}
UpdateCoordinator.__index = UpdateCoordinator
PeaversCommons.UpdateCoordinator = UpdateCoordinator

-- Update type priorities (higher = more important)
local UPDATE_PRIORITY = {
    dataRefresh = 1,
    sortRequired = 2,
    fullRebuild = 3,
}

-- Default options
local DEFAULT_OPTIONS = {
    debounceInterval = 0.1,         -- Seconds to wait before processing updates
    combatBehavior = "dataRefreshOnly", -- "normal", "dataRefreshOnly", or "defer"
    updateHandlers = nil,           -- Required: table of handler functions
}

-- Creates a new UpdateCoordinator instance
-- @param options table with updateHandlers (required), debounceInterval (optional), combatBehavior (optional)
-- @return UpdateCoordinator instance
function UpdateCoordinator:New(options)
    options = options or {}

    local instance = setmetatable({}, UpdateCoordinator)

    -- Validate required options
    if not options.updateHandlers then
        error("UpdateCoordinator:New requires updateHandlers table")
    end

    instance.updateHandlers = options.updateHandlers
    instance.debounceInterval = options.debounceInterval or DEFAULT_OPTIONS.debounceInterval
    instance.combatBehavior = options.combatBehavior or DEFAULT_OPTIONS.combatBehavior

    -- State
    instance.pendingUpdates = {}    -- Set of pending update types
    instance.updateTimer = nil      -- C_Timer handle
    instance.inCombat = false       -- Combat state
    instance.deferredUpdate = nil   -- Highest priority update deferred until combat ends

    return instance
end

-- Schedules an update of the specified type
-- @param updateType string: "fullRebuild", "sortRequired", or "dataRefresh"
function UpdateCoordinator:ScheduleUpdate(updateType)
    if not UPDATE_PRIORITY[updateType] then
        error("Unknown update type: " .. tostring(updateType))
    end

    -- Handle combat restrictions
    if self.inCombat then
        if self.combatBehavior == "defer" then
            -- Defer all updates until combat ends
            if not self.deferredUpdate or UPDATE_PRIORITY[updateType] > UPDATE_PRIORITY[self.deferredUpdate] then
                self.deferredUpdate = updateType
            end
            return
        elseif self.combatBehavior == "dataRefreshOnly" then
            -- Only allow dataRefresh during combat, defer others
            if updateType ~= "dataRefresh" then
                if not self.deferredUpdate or UPDATE_PRIORITY[updateType] > UPDATE_PRIORITY[self.deferredUpdate] then
                    self.deferredUpdate = updateType
                end
                return
            end
        end
        -- "normal" behavior continues without restrictions
    end

    -- Add to pending updates
    self.pendingUpdates[updateType] = true

    -- Cancel existing timer if any
    if self.updateTimer then
        self.updateTimer:Cancel()
        self.updateTimer = nil
    end

    -- Schedule new timer
    self.updateTimer = C_Timer.NewTimer(self.debounceInterval, function()
        self:ProcessUpdates()
    end)
end

-- Processes all pending updates
-- Executes only the highest priority update type
function UpdateCoordinator:ProcessUpdates()
    self.updateTimer = nil

    -- Find highest priority update
    local highestPriority = 0
    local updateToExecute = nil

    for updateType, _ in pairs(self.pendingUpdates) do
        local priority = UPDATE_PRIORITY[updateType] or 0
        if priority > highestPriority then
            highestPriority = priority
            updateToExecute = updateType
        end
    end

    -- Clear pending updates
    self.pendingUpdates = {}

    -- Execute the update
    if updateToExecute and self.updateHandlers[updateToExecute] then
        self.updateHandlers[updateToExecute]()
    end
end

-- Clears all pending updates
function UpdateCoordinator:ClearAll()
    if self.updateTimer then
        self.updateTimer:Cancel()
        self.updateTimer = nil
    end
    self.pendingUpdates = {}
    self.deferredUpdate = nil
end

-- Sets combat state
-- @param inCombat boolean
function UpdateCoordinator:SetCombatState(inCombat)
    local wasInCombat = self.inCombat
    self.inCombat = inCombat

    -- When exiting combat, process any deferred updates
    if wasInCombat and not inCombat and self.deferredUpdate then
        local deferredType = self.deferredUpdate
        self.deferredUpdate = nil
        self:ScheduleUpdate(deferredType)
    end
end

-- Registers combat events for automatic state tracking
-- @param addon The addon namespace (optional, for storing inCombat flag)
function UpdateCoordinator:RegisterCombatEvents(addon)
    local frame = CreateFrame("Frame")
    local self = self

    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")

    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            self:SetCombatState(true)
            if addon then
                addon.inCombat = true
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            self:SetCombatState(false)
            if addon then
                addon.inCombat = false
            end
        end
    end)

    -- Set initial state
    local inCombat = InCombatLockdown()
    self:SetCombatState(inCombat)
    if addon then
        addon.inCombat = inCombat
    end

    return frame
end

-- Forces immediate processing of pending updates (ignores debounce)
function UpdateCoordinator:Flush()
    if self.updateTimer then
        self.updateTimer:Cancel()
        self.updateTimer = nil
    end
    self:ProcessUpdates()
end

-- Checks if there are pending updates
-- @return boolean
function UpdateCoordinator:HasPendingUpdates()
    for _ in pairs(self.pendingUpdates) do
        return true
    end
    return false
end

-- Gets the current combat state
-- @return boolean
function UpdateCoordinator:IsInCombat()
    return self.inCombat
end

return UpdateCoordinator
