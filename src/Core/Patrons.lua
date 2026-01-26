-- PeaversCommons Patrons Module
local PeaversCommons = _G.PeaversCommons
local Patrons = {}
PeaversCommons.Patrons = Patrons

-- Get Utils module for debugging
local Utils = PeaversCommons.Utils or {}

-- Patrons data list
Patrons.List = {
    -- Example patron format: 
    -- { name = "PatronName", tier = "gold" }  -- tier can be "bronze", "silver", "gold", "platinum"
    
    -- Initial patrons can be added here
    -- { name = "Patron1", tier = "gold" },
    -- { name = "Patron2", tier = "silver" },
}

-- Tier colors for UI display (WoW color escape codes)
Patrons.TierColors = {
    gold = "|cffffd700",      -- Gold - paying patrons
    silver = "|cffc0c0c0",    -- Silver - free followers
    bronze = "|cffcd7f32",    -- Bronze (reserved)
    platinum = "|cffe5e4e2",  -- Platinum (reserved)
    standard = "|cffffffff",  -- White - default
}

-- Function to add a patron to the list
function Patrons:AddPatron(name, tier)
    if not name or name == "" then
        return false
    end

    -- Default to standard tier if not specified
    tier = tier or "standard"

    -- Check if patron already exists
    for i, patron in ipairs(self.List) do
        if patron.name == name then
            -- Update tier if changed
            patron.tier = tier
            return true
        end
    end

    -- Add new patron
    table.insert(self.List, { name = name, tier = tier })
    return true
end

-- Function to add multiple patrons at once
function Patrons:AddPatrons(patronsList)
    if not patronsList or type(patronsList) ~= "table" then
        return false
    end

    local successCount = 0

    for _, patronEntry in ipairs(patronsList) do
        if type(patronEntry) == "table" then
            -- Format: { name = "Name", tier = "gold" }
            if patronEntry.name then
                if self:AddPatron(patronEntry.name, patronEntry.tier) then
                    successCount = successCount + 1
                end
            end
        elseif type(patronEntry) == "string" then
            -- Simple format: just the name (defaults to standard tier)
            if self:AddPatron(patronEntry) then
                successCount = successCount + 1
            end
        end
    end

    return successCount > 0, successCount
end

-- Function to remove a patron from the list
function Patrons:RemovePatron(name)
    if not name or name == "" then return false end
    
    for i, patron in ipairs(self.List) do
        if patron.name == name then
            table.remove(self.List, i)
            return true
        end
    end
    
    return false
end

-- Function to get all patrons
function Patrons:GetAll()
    return self.List
end

-- Function to get color code for a tier
function Patrons:GetTierColor(tier)
    return self.TierColors[tier] or self.TierColors.standard
end

-- Function to get a patron's name with color applied
function Patrons:GetColoredName(patron)
    local color = self:GetTierColor(patron.tier)
    return color .. patron.name .. "|r"
end

-- Function to get patrons by tier
function Patrons:GetByTier(tier)
    if not tier then return {} end
    
    local result = {}
    for _, patron in ipairs(self.List) do
        if patron.tier == tier then
            table.insert(result, patron)
        end
    end
    
    return result
end

-- Sort patrons by tier and then alphabetically
function Patrons:GetSorted()
    -- Create copy to avoid modifying original
    -- Use Utils.DeepCopy if available, otherwise create a simple copy
    local sortedList
    if Utils and Utils.DeepCopy then
        sortedList = Utils.DeepCopy(self.List)
    else
        -- Fallback: simple copy of patron entries
        sortedList = {}
        for i, patron in ipairs(self.List) do
            sortedList[i] = { name = patron.name, tier = patron.tier }
        end
    end

    -- Tier order mapping (higher number = higher priority in display)
    local tierOrder = {
        standard = 0,
        bronze = 1,
        silver = 2,
        gold = 3,
        platinum = 4
    }

    -- Sort by tier (descending) and then by name (ascending)
    table.sort(sortedList, function(a, b)
        local aTier = tierOrder[a.tier] or 0
        local bTier = tierOrder[b.tier] or 0
        if aTier ~= bTier then
            return aTier > bTier
        else
            return a.name < b.name
        end
    end)

    return sortedList
end

-- Function to clear all patrons
function Patrons:Clear()
    wipe(self.List)
end

-- Return the module
return Patrons