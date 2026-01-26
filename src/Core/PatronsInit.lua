-- AUTO-GENERATED FILE - DO NOT EDIT MANUALLY
-- This file is automatically updated by GitHub Actions from Patreon data
-- Last updated: See git commit timestamp

local PeaversCommons = _G.PeaversCommons
local Patrons = PeaversCommons.Patrons

local function InitializePatrons()
    if not Patrons or not Patrons.AddPatrons then
        return false
    end

    -- Clear existing patrons to prevent duplicates on reload
    if Patrons.Clear then
        Patrons:Clear()
    end

    Patrons:AddPatrons({
        { name = "Kyrshiro - Kel'Thuzad", tier = "gold" },
        { name = "Plunger - Kel'Thuzad", tier = "gold" },
    })

    return true
end

InitializePatrons()

return InitializePatrons
