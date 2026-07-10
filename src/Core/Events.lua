local PeaversCommons = _G.PeaversCommons
local Events = PeaversCommons.Events
local Utils = PeaversCommons.Utils

local eventFrame = CreateFrame("Frame")
local registeredEvents = {}
local eventHandlers = {}

function Events:RegisterEvent(event, handler)
    if not registeredEvents[event] then
        registeredEvents[event] = true
        eventFrame:RegisterEvent(event)
    end
    
    if handler then
        if not eventHandlers[event] then
            eventHandlers[event] = {}
        end
        table.insert(eventHandlers[event], handler)
    end
end

function Events:UnregisterEvent(event, handler)
    if handler and eventHandlers[event] then
        for i, registeredHandler in ipairs(eventHandlers[event]) do
            if registeredHandler == handler then
                table.remove(eventHandlers[event], i)
                break
            end
        end
        
        if #eventHandlers[event] == 0 then
            eventHandlers[event] = nil
            registeredEvents[event] = nil
            eventFrame:UnregisterEvent(event)
        end
    else
        eventHandlers[event] = nil
        registeredEvents[event] = nil
        eventFrame:UnregisterEvent(event)
    end
end

local function OnEvent(self, event, ...)
    if eventHandlers[event] then
        -- Iterate a snapshot so handlers can unregister themselves mid-dispatch
        local handlers = {}
        for i, handler in ipairs(eventHandlers[event]) do
            handlers[i] = handler
        end
        for _, handler in ipairs(handlers) do
            handler(event, ...)
        end
    end
end

eventFrame:SetScript("OnEvent", OnEvent)

local updateHandlers = {}
local updateTimers = {}

local function OnUpdate(self, elapsed)
    for key, timer in pairs(updateTimers) do
        timer.elapsed = timer.elapsed + elapsed
        if timer.elapsed >= timer.interval then
            if updateHandlers[key] then
                updateHandlers[key](timer.elapsed)
            end
            timer.elapsed = 0
        end
    end
end

function Events:RegisterOnUpdate(interval, handler, key)
    key = key or handler
    updateHandlers[key] = handler
    updateTimers[key] = {
        interval = interval,
        elapsed = 0
    }

    eventFrame:SetScript("OnUpdate", OnUpdate)
end

function Events:UnregisterOnUpdate(key)
    updateHandlers[key] = nil
    updateTimers[key] = nil

    if not next(updateTimers) then
        eventFrame:SetScript("OnUpdate", nil)
    end
end

function Events:AnnounceLoaded(addon, customMessage)
    local message = customMessage or "Addon loaded"
    
    local function announceHandler()
        Utils.Print(addon, message)
        self:UnregisterEvent("PLAYER_ENTERING_WORLD", announceHandler)
    end
    self:RegisterEvent("PLAYER_ENTERING_WORLD", announceHandler)
end

function Events:RegisterAddonForSupport(addon)
    if not PeaversCommons.SupportUI then
        PeaversCommons.SupportUI = {}
    end
    
    if not PeaversCommons.SupportUI._pendingRegistrations then
        PeaversCommons.SupportUI._pendingRegistrations = {}
    end
    
    table.insert(PeaversCommons.SupportUI._pendingRegistrations, addon)
    return true
end

function Events:Init(addonName, initCallback, options)
    options = options or {}
    local announceMessage = options.announceMessage
    local suppressAnnouncement = options.suppressAnnouncement
    local suppressSupportUI = options.suppressSupportUI
    
    local addonInitialized = false
    
    if addonName == "PeaversCommons" then
        if PeaversCommons.Config and PeaversCommons.Config.Initialize then
            PeaversCommons.Config:Initialize()
        end
    end
    
    local function onAddonLoaded(event, loadedAddon)
        if loadedAddon == addonName and not addonInitialized then
            addonInitialized = true

            local addon = _G[addonName] or { name = addonName }

            if not addon.name then addon.name = addonName end

            if not suppressSupportUI then
                self:RegisterAddonForSupport(addon)
            end

            if initCallback then
                initCallback()
            end

            if not suppressAnnouncement then
                self:AnnounceLoaded(addon, ": " ..  announceMessage)
            end

            -- Only remove this handler; other addons' ADDON_LOADED handlers must survive
            self:UnregisterEvent("ADDON_LOADED", onAddonLoaded)
        end
    end
    self:RegisterEvent("ADDON_LOADED", onAddonLoaded)
    
    local initialized = false
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        if not initialized then
            C_Timer.After(0.5, function()
                if PeaversCommons.SupportUI then
                    if type(PeaversCommons.SupportUI.InitializeAll) == "function" then
                        PeaversCommons.SupportUI:InitializeAll()
                        
                        C_Timer.After(0.5, function()
                            if PeaversCommons.PatronsUI and PeaversCommons.PatronsUI.InitializeForAllAddons then
                                PeaversCommons.PatronsUI:InitializeForAllAddons()
                            end
                        end)
                    end
                end
            end)
            initialized = true
        end
    end)
end

return Events