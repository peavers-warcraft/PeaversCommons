local PeaversCommons = _G.PeaversCommons
local ConfigRegistry = {}
PeaversCommons.ConfigRegistry = ConfigRegistry

local registeredAddons = {}
local registrationOrder = {}

function ConfigRegistry:Register(addonInfo)
    if not addonInfo or not addonInfo.name then
        return false
    end

    if not addonInfo.displayName then
        addonInfo.displayName = addonInfo.name:gsub("^Peavers", "")
    end

    addonInfo.order = addonInfo.order or 99

    registeredAddons[addonInfo.name] = addonInfo

    if not self:IsRegistered(addonInfo.name) then
        table.insert(registrationOrder, addonInfo.name)
    end

    return true
end

function ConfigRegistry:Unregister(addonName)
    registeredAddons[addonName] = nil
    for i, name in ipairs(registrationOrder) do
        if name == addonName then
            table.remove(registrationOrder, i)
            break
        end
    end
end

function ConfigRegistry:IsRegistered(addonName)
    for _, name in ipairs(registrationOrder) do
        if name == addonName then
            return true
        end
    end
    return false
end

function ConfigRegistry:GetAddon(addonName)
    return registeredAddons[addonName]
end

function ConfigRegistry:GetRegisteredAddons()
    return registeredAddons
end

function ConfigRegistry:GetSortedAddons()
    local sorted = {}
    for _, info in pairs(registeredAddons) do
        table.insert(sorted, info)
    end
    table.sort(sorted, function(a, b)
        if a.order ~= b.order then
            return a.order < b.order
        end
        return a.displayName < b.displayName
    end)
    return sorted
end

function ConfigRegistry:GetAddonCount()
    local count = 0
    for _ in pairs(registeredAddons) do
        count = count + 1
    end
    return count
end

return ConfigRegistry
