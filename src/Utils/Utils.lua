local PeaversCommons = _G.PeaversCommons
local Utils = PeaversCommons.Utils

function Utils.Debug(addon, ...)
    if addon and addon.Config and addon.Config.DEBUG_ENABLED then
        print("|cFF00FFFF[" .. addon.name .. " Debug]|r", ...)
    end

    if PeaversCommons.Debug and PeaversCommons.Debug.Log then
        local source = addon and addon.name or "Unknown"
        local message = table.concat({...}, " ")
        PeaversCommons.Debug:Log(source, message, "DEBUG")
    end
end

function Utils.Print(addon, ...)
    if addon and addon.name then
        print("|cFF00FF00[" .. addon.name .. "]|r", ...)
    else
        print(...)
    end
end

function Utils.DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[Utils.DeepCopy(orig_key)] = Utils.DeepCopy(orig_value)
        end
        setmetatable(copy, Utils.DeepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

function Utils.MergeDefaults(target, defaults)
    if type(target) ~= "table" then target = {} end
    if type(defaults) ~= "table" then return target end
    
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            target[k] = Utils.MergeDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
    
    return target
end

function Utils.FormatNumber(num)
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    else
        return tostring(num)
    end
end

function Utils.IsInCombat()
    return InCombatLockdown() or UnitAffectingCombat("player")
end

function Utils.GetPlayerInfo()
    local name, realm = UnitFullName("player")
    realm = realm or GetRealmName()
    local fullName = name .. "-" .. realm
    local class, classFilename, classID = UnitClass("player")
    local level = UnitLevel("player")
    
    local specIndex = GetSpecialization()
    local specID, specName, specDesc, specIcon
    if specIndex then
        specID, specName, specDesc, specIcon = GetSpecializationInfo(specIndex)
    end
    
    return {
        name = name,
        realm = realm, 
        fullName = fullName,
        class = classFilename,
        classID = classID,
        className = class,
        level = level,
        specIndex = specIndex,
        specID = specID,
        specName = specName
    }
end

function Utils.GetCharacterKey()
    local info = Utils.GetPlayerInfo()
    return info.name .. "-" .. info.realm
end

function Utils.FormatPercent(value, decimals)
    decimals = decimals or 2
    return string.format("%." .. decimals .. "f%%", value or 0)
end

function Utils.FormatChange(value, decimals)
    decimals = decimals or 2
    local format = "%." .. decimals .. "f"
    if value > 0 then
        return string.format("+" .. format, value)
    elseif value < 0 then
        return string.format(format, value)
    else
        return "0"
    end
end

function Utils.Round(value, decimals)
    decimals = decimals or 0
    local mult = 10 ^ decimals
    return math.floor(value * mult + 0.5) / mult
end

function Utils.FormatTime(seconds)
    if not seconds or seconds <= 0 then
        return "0s"
    end

    local days = math.floor(seconds / 86400)
    seconds = seconds % 86400

    local hours = math.floor(seconds / 3600)
    seconds = seconds % 3600

    local minutes = math.floor(seconds / 60)
    seconds = math.floor(seconds % 60)

    local parts = {}

    if days > 0 then
        table.insert(parts, days .. "d")
    end

    if hours > 0 then
        table.insert(parts, hours .. "h")
    end

    if minutes > 0 then
        table.insert(parts, minutes .. "m")
    end

    if seconds > 0 and #parts < 2 then
        table.insert(parts, seconds .. "s")
    end

    if #parts > 2 then
        return table.concat({parts[1], parts[2]}, " ")
    else
        return table.concat(parts, " ")
    end
end

function Utils.FormatMoney(copper)
    if not copper or copper == 0 then
        return "0g"
    end
    
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperRemain = copper % 100
    
    local result = ""
    if gold > 0 then
        result = gold .. "g"
    end
    
    if silver > 0 then
        result = result .. " " .. silver .. "s"
    end
    
    if copperRemain > 0 and (gold == 0 or silver == 0) then
        result = result .. " " .. copperRemain .. "c"
    end
    
    return result
end

function Utils.TableContains(tbl, value)
    if type(tbl) ~= "table" then return false end
    
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

function Utils.TableFindKey(tbl, value)
    if type(tbl) ~= "table" then return nil end
    
    for k, v in pairs(tbl) do
        if v == value then
            return k
        end
    end
    return nil
end

function Utils.TableCount(tbl)
    if type(tbl) ~= "table" then return 0 end
    
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

function Utils.TableKeys(tbl)
    if type(tbl) ~= "table" then return {} end
    
    local keys = {}
    for k, _ in pairs(tbl) do
        table.insert(keys, k)
    end
    return keys
end

return Utils