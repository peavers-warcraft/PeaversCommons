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
        { name = "Brian Huddleston", tier = "gold" },
        { name = "Michael Giallourakis", tier = "gold" },
        { name = "patreon.r1z2i", tier = "gold" },
        { name = "Bill Chirico", tier = "silver" },
        { name = "Chris Turner", tier = "silver" },
        { name = "James Toal", tier = "silver" },
        { name = "Jeremy ", tier = "silver" },
        { name = "Jordan Love", tier = "silver" },
        { name = "Kaitonel", tier = "silver" },
        { name = "Nick", tier = "silver" },
        { name = "Nova One", tier = "silver" },
        { name = "Riaan Piketh", tier = "silver" },
        { name = "Sarah Altrowitz", tier = "silver" },
        { name = "Spectro", tier = "silver" },
        { name = "tyronious88", tier = "silver" },
    })

    return true
end

InitializePatrons()

return InitializePatrons
