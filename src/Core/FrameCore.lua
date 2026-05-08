local PeaversCommons = _G.PeaversCommons
local FrameCore = {}
PeaversCommons.FrameCore = FrameCore

function FrameCore:New(addon, options)
    local core = {}
    
    options = options or {}
    options.frameName = options.frameName or (addon.name .. "Frame")
    options.width = options.width or 200
    options.height = options.height or 100
    options.showTitleBar = (options.showTitleBar ~= false)
    options.backgroundColor = options.backgroundColor or {r = 0, g = 0, b = 0, a = 0.5}
    options.createBars = (options.createBars ~= false)
    
    function core:Initialize()
        core.inCombat = false
        
        core.frame = CreateFrame("Frame", options.frameName, UIParent, "BackdropTemplate")
        core.frame:SetSize(addon.Config.frameWidth or options.width, addon.Config.frameHeight or options.height)
        core.frame:SetBackdrop({
            bgFile = "Interface\\BUTTONS\\WHITE8X8",
            edgeFile = "Interface\\BUTTONS\\WHITE8X8",
            tile = true, tileSize = 16, edgeSize = 1,
        })
        
        local bgColor = addon.Config.bgColor or options.backgroundColor
        core.frame:SetBackdropColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
        core.frame:SetBackdropBorderColor(0, 0, 0, bgColor.a)
        
        if addon.TitleBar and options.showTitleBar then
            local titleBar = addon.TitleBar:Create(core.frame)
            core.titleBar = titleBar
        end
        
        core.contentFrame = CreateFrame("Frame", nil, core.frame)
        if core.titleBar and options.showTitleBar then
            core.contentFrame:SetPoint("TOPLEFT", core.frame, "TOPLEFT", 0, -20)
        else
            core.contentFrame:SetPoint("TOPLEFT", core.frame, "TOPLEFT", 0, 0)
        end
        core.contentFrame:SetPoint("BOTTOMRIGHT", core.frame, "BOTTOMRIGHT", 0, 0)
        
        if core.UpdateTitleBarVisibility then
            core:UpdateTitleBarVisibility()
        end
        
        if addon.BarManager and options.createBars then
            addon.BarManager:CreateBars(core.contentFrame)
            core:AdjustFrameHeight()
        end
        
        local point = addon.Config.framePoint or "CENTER"
        local x = addon.Config.frameX or 0
        local y = addon.Config.frameY or 0
        core.frame:SetPoint(point, x, y)
        
        core:UpdateFrameLock()
        core:UpdateFrameVisibility()
        
        return core
    end
    
    function core:UpdateFrameLock()
        local locked = addon.Config.lockPosition
        
        if locked then
            core.frame:SetMovable(false)
            core.frame:EnableMouse(true)
            core.frame:RegisterForDrag("")
            core.frame:SetScript("OnDragStart", nil)
            core.frame:SetScript("OnDragStop", nil)
            
            if core.contentFrame then
                core.contentFrame:SetMovable(false)
                core.contentFrame:EnableMouse(true)
                core.contentFrame:RegisterForDrag("")
                core.contentFrame:SetScript("OnDragStart", nil)
                core.contentFrame:SetScript("OnDragStop", nil)
            end
        else
            core.frame:SetMovable(true)
            core.frame:EnableMouse(true)
            core.frame:RegisterForDrag("LeftButton")
            core.frame:SetScript("OnDragStart", core.frame.StartMoving)
            core.frame:SetScript("OnDragStop", function(frame)
                frame:StopMovingOrSizing()
                
                local point, _, _, x, y = frame:GetPoint()
                addon.Config.framePoint = point
                addon.Config.frameX = x
                addon.Config.frameY = y
                if addon.Config.Save then
                    addon.Config:Save()
                end
            end)
            
            if core.contentFrame then
                core.contentFrame:SetMovable(true)
                core.contentFrame:EnableMouse(true)
                core.contentFrame:RegisterForDrag("LeftButton")
                core.contentFrame:SetScript("OnDragStart", function()
                    core.frame:StartMoving()
                end)
                core.contentFrame:SetScript("OnDragStop", function()
                    core.frame:StopMovingOrSizing()
                    
                    local point, _, _, x, y = core.frame:GetPoint()
                    addon.Config.framePoint = point
                    addon.Config.frameX = x
                    addon.Config.frameY = y
                    if addon.Config.Save then
                        addon.Config:Save()
                    end
                end)
            end
        end
    end
    
    function core:UpdateTitleBarVisibility()
        if core.titleBar then
            if addon.Config.showTitleBar then
                core.titleBar:Show()
                core.contentFrame:SetPoint("TOPLEFT", core.frame, "TOPLEFT", 0, -20)
            else
                core.titleBar:Hide()
                core.contentFrame:SetPoint("TOPLEFT", core.frame, "TOPLEFT", 0, 0)
            end
            
            if core.AdjustFrameHeight then
                core:AdjustFrameHeight()
            end
            
            core:UpdateFrameLock()
        end
    end
    
    function core:AdjustFrameHeight()
        if addon.BarManager and addon.BarManager.AdjustFrameHeight then
            addon.BarManager:AdjustFrameHeight(core.frame, core.contentFrame, addon.Config.showTitleBar)
        end
    end
    
    function core:UpdateFrameVisibility()
        if not core.frame then return end
        
        local shouldShow = true
        local inCombat = core.inCombat or InCombatLockdown()
        
        if addon.Config.displayMode then
            local isInParty = IsInGroup() and not IsInRaid()
            local isInRaid = IsInRaid()
            
            shouldShow = false
            if addon.Config.displayMode == "ALWAYS" then
                shouldShow = true
            elseif addon.Config.displayMode == "PARTY_ONLY" and isInParty then
                shouldShow = true
            elseif addon.Config.displayMode == "RAID_ONLY" and isInRaid then
                shouldShow = true
            elseif addon.Config.displayMode == "PARTY_AND_RAID" and (isInParty or isInRaid) then
                shouldShow = true
            end
        end
        
        if shouldShow and addon.Config.hideOutOfCombat and not inCombat then
            shouldShow = false
        end
        
        if shouldShow and addon.Config.showOnLogin then
            core.frame:Show()
        else
            core.frame:Hide()
        end
    end
    
    return core
end

return FrameCore