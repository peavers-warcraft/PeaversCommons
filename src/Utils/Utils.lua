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

-- ============================================================================
-- Font and Texture Utilities
-- ============================================================================

-- Default font path for WoW
local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"

-- Locale-aware default fonts
local LOCALE_FONTS = {
    ["koKR"] = "Fonts\\2002.TTF",
    ["zhCN"] = "Fonts\\ARKai_T.TTF",
    ["zhTW"] = "Fonts\\blei00d.TTF",
    ["ruRU"] = "Fonts\\FRIZQT___CYR.TTF",
}

-- Gets the locale-appropriate default font
-- @return string Font path
function Utils.GetDefaultFont()
    local locale = GetLocale()
    return LOCALE_FONTS[locale] or DEFAULT_FONT
end

-- Gets list of available fonts, integrating with LibSharedMedia if available
-- @return table Array of {name, path} pairs
function Utils.GetFonts()
    local fonts = {}

    -- Built-in WoW fonts
    local builtInFonts = {
        { name = "Friz Quadrata TT", path = "Fonts\\FRIZQT__.TTF" },
        { name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
        { name = "Skurri", path = "Fonts\\SKURRI.TTF" },
        { name = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
    }

    for _, font in ipairs(builtInFonts) do
        table.insert(fonts, font)
    end

    -- Try to get fonts from LibSharedMedia
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local lsmFonts = LSM:HashTable("font")
        if lsmFonts then
            for name, path in pairs(lsmFonts) do
                -- Avoid duplicates
                local isDuplicate = false
                for _, existing in ipairs(fonts) do
                    if existing.path == path then
                        isDuplicate = true
                        break
                    end
                end
                if not isDuplicate then
                    table.insert(fonts, { name = name, path = path })
                end
            end
        end
    end

    -- Sort alphabetically by name
    table.sort(fonts, function(a, b) return a.name < b.name end)

    return fonts
end

-- Gets list of available bar textures, integrating with LibSharedMedia and Details if available
-- @return table Array of {name, path} pairs
function Utils.GetBarTextures()
    local textures = {}

    -- Built-in textures
    local builtInTextures = {
        { name = "Solid", path = "Interface\\BUTTONS\\WHITE8X8" },
        { name = "Blizzard", path = "Interface\\TargetingFrame\\UI-StatusBar" },
        { name = "Blizzard Raid", path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
        { name = "Minimalist", path = "Interface\\BUTTONS\\WHITE8X8" },
    }

    for _, texture in ipairs(builtInTextures) do
        table.insert(textures, texture)
    end

    -- Try to get textures from LibSharedMedia
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local lsmTextures = LSM:HashTable("statusbar")
        if lsmTextures then
            for name, path in pairs(lsmTextures) do
                -- Avoid duplicates
                local isDuplicate = false
                for _, existing in ipairs(textures) do
                    if existing.path == path then
                        isDuplicate = true
                        break
                    end
                end
                if not isDuplicate then
                    table.insert(textures, { name = name, path = path })
                end
            end
        end
    end

    -- Try to get textures from Details! addon
    local Details = _G.Details
    if Details and Details.SharedMedia and Details.SharedMedia.statusbar then
        for name, path in pairs(Details.SharedMedia.statusbar) do
            local isDuplicate = false
            for _, existing in ipairs(textures) do
                if existing.path == path then
                    isDuplicate = true
                    break
                end
            end
            if not isDuplicate then
                table.insert(textures, { name = "Details: " .. name, path = path })
            end
        end
    end

    -- Sort alphabetically by name
    table.sort(textures, function(a, b) return a.name < b.name end)

    return textures
end

-- Safely sets font on a font string with fallback handling
-- If the primary font fails, falls back to the default locale font
-- @param fontString The font string object to modify
-- @param fontPath The font path to try
-- @param fontSize Font size in points
-- @param fontFlags Font flags like "OUTLINE" (optional)
-- @return boolean True if font was set successfully
function Utils.SafeSetFont(fontString, fontPath, fontSize, fontFlags)
    if not fontString then return false end

    fontSize = fontSize or 12
    fontFlags = fontFlags or ""

    -- Try the requested font
    local success = pcall(function()
        fontString:SetFont(fontPath, fontSize, fontFlags)
    end)

    if success then
        -- Verify the font was actually set
        local currentFont = fontString:GetFont()
        if currentFont then
            return true
        end
    end

    -- Fallback to default font
    local defaultFont = Utils.GetDefaultFont()
    if fontPath ~= defaultFont then
        success = pcall(function()
            fontString:SetFont(defaultFont, fontSize, fontFlags)
        end)
        if success then
            return true
        end
    end

    -- Last resort: basic WoW font
    pcall(function()
        fontString:SetFont(DEFAULT_FONT, fontSize, fontFlags)
    end)

    return false
end

-- Gets a contrasting color for text/overlay visibility
-- @param r Red component (0-1)
-- @param g Green component (0-1)
-- @param b Blue component (0-1)
-- @return r, g, b Contrasting color components
function Utils.GetContrastingColor(r, g, b)
    -- Calculate perceived brightness using standard luminance formula
    local brightness = (r * 0.299) + (g * 0.587) + (b * 0.114)

    if brightness > 0.5 then
        -- Bright color, return darker version
        return r * 0.5, g * 0.5, b * 0.5
    else
        -- Dark color, return lighter version
        return math.min(1, r + 0.5), math.min(1, g + 0.5), math.min(1, b + 0.5)
    end
end

-- Truncates text to fit within a specified width
-- Uses binary search for efficiency (based on PIL's optimization)
-- @param fontString The font string to measure with
-- @param text The text to truncate
-- @param maxWidth Maximum width in pixels
-- @param suffix Suffix to add when truncated (default "...")
-- @return string The truncated text
function Utils.TruncateText(fontString, text, maxWidth, suffix)
    if not fontString or not text or not maxWidth then
        return text or ""
    end

    suffix = suffix or "..."

    -- Check if text already fits
    fontString:SetText(text)
    if fontString:GetStringWidth() <= maxWidth then
        return text
    end

    -- Binary search for optimal length
    local low, high = 1, #text
    local result = ""

    while low <= high do
        local mid = math.floor((low + high) / 2)
        local truncated = text:sub(1, mid) .. suffix
        fontString:SetText(truncated)

        if fontString:GetStringWidth() <= maxWidth then
            result = truncated
            low = mid + 1
        else
            high = mid - 1
        end
    end

    return result ~= "" and result or (text:sub(1, 1) .. suffix)
end

return Utils