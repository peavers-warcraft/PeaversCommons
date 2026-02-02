local MAJOR, MINOR = "PeaversCommons-BarPool", 1
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

local PeaversCommons = _G.PeaversCommons

--[[
    BarPool - Generic frame pooling system for efficient bar reuse

    Based on PeaversItemLevel's pooling pattern, generalized for any addon.

    Usage:
        local pool = PeaversCommons.BarPool:New({
            factory = function(parent, name) return MyStatBar:New(parent, name) end,
            resetter = function(bar) bar:Reset() end,
            maxPoolSize = 50
        })

        local bar = pool:Acquire(parent, "Bar1", "uniqueKey")
        pool:Release("uniqueKey")
        pool:ReleaseAll()
]]

local BarPool = {}
BarPool.__index = BarPool
PeaversCommons.BarPool = BarPool

-- Default options
local DEFAULT_OPTIONS = {
    maxPoolSize = 50,
    factory = nil,      -- Required: function(parent, name) -> bar
    resetter = nil,     -- Optional: function(bar) -> nil
}

-- Creates a new BarPool instance
-- @param options table with factory, resetter (optional), maxPoolSize (optional)
-- @return BarPool instance
function BarPool:New(options)
    options = options or {}

    local instance = setmetatable({}, BarPool)

    -- Validate required options
    if not options.factory then
        error("BarPool:New requires a factory function")
    end

    instance.factory = options.factory
    instance.resetter = options.resetter
    instance.maxPoolSize = options.maxPoolSize or DEFAULT_OPTIONS.maxPoolSize

    -- Storage
    instance.available = {}     -- Pool of unused bars
    instance.inUse = {}         -- Currently active bars (keyed by unique key)
    instance.barCount = 0       -- Total bars created

    return instance
end

-- Acquires a bar from the pool or creates a new one
-- @param parent Frame parent for the bar
-- @param name String name for the bar frame
-- @param key Unique key to identify this bar (e.g., unit ID, stat type)
-- @return bar The acquired or created bar
function BarPool:Acquire(parent, name, key)
    -- Check if we already have a bar for this key
    if self.inUse[key] then
        return self.inUse[key]
    end

    local bar

    -- Try to get a bar from the available pool
    if #self.available > 0 then
        bar = table.remove(self.available)

        -- Reset the bar if resetter is provided
        if self.resetter then
            self.resetter(bar)
        end

        -- Re-parent if needed
        if bar.frame and parent then
            bar.frame:SetParent(parent)
        end
    else
        -- Create a new bar using the factory
        bar = self.factory(parent, name)
        self.barCount = self.barCount + 1
    end

    -- Store in active bars
    self.inUse[key] = bar

    -- Store key on bar for later reference
    if bar then
        bar._poolKey = key
    end

    return bar
end

-- Releases a bar back to the pool
-- @param key The unique key of the bar to release
function BarPool:Release(key)
    local bar = self.inUse[key]
    if not bar then return end

    -- Remove from active
    self.inUse[key] = nil

    -- Hide the bar
    if bar.frame then
        bar.frame:Hide()
    elseif bar.Hide then
        bar:Hide()
    end

    -- Reset the bar if resetter is provided
    if self.resetter then
        self.resetter(bar)
    end

    -- Add to available pool if under max size
    if #self.available < self.maxPoolSize then
        table.insert(self.available, bar)
    end
end

-- Releases all bars back to the pool
function BarPool:ReleaseAll()
    for key, _ in pairs(self.inUse) do
        self:Release(key)
    end
end

-- Gets a bar by its key
-- @param key The unique key
-- @return bar or nil
function BarPool:GetBar(key)
    return self.inUse[key]
end

-- Gets all active bars
-- @return table of all bars currently in use
function BarPool:GetAllBars()
    return self.inUse
end

-- Clears all bars (both available and in use)
function BarPool:Clear()
    -- Hide and clear all in-use bars
    for key, bar in pairs(self.inUse) do
        if bar.frame then
            bar.frame:Hide()
        elseif bar.Hide then
            bar:Hide()
        end
    end

    -- Clear storage
    self.inUse = {}
    self.available = {}
end

-- Gets statistics about the pool
-- @return table with stats
function BarPool:GetStats()
    local inUseCount = 0
    for _ in pairs(self.inUse) do
        inUseCount = inUseCount + 1
    end

    return {
        inUse = inUseCount,
        available = #self.available,
        totalCreated = self.barCount,
        maxPoolSize = self.maxPoolSize,
    }
end

-- Iterates over all active bars
-- @param callback function(key, bar) called for each active bar
function BarPool:ForEach(callback)
    for key, bar in pairs(self.inUse) do
        callback(key, bar)
    end
end

-- Gets the count of active bars
-- @return number
function BarPool:GetActiveCount()
    local count = 0
    for _ in pairs(self.inUse) do
        count = count + 1
    end
    return count
end

return BarPool
