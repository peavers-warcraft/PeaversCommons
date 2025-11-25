-- LibStub implementation for PeaversCommons
local MAJOR, MINOR = "LibStub", 2  -- Never make this less than 1
local LibStub = _G[MAJOR]

-- Check if we need to create the library
if not LibStub or (LibStub.minor and LibStub.minor < MINOR) then
    LibStub = LibStub or {}
    LibStub.minor = MINOR
    LibStub.libs = LibStub.libs or {}
    LibStub.callbacks = LibStub.callbacks or {}
    
    -- Create a new instance of a library or return the current
    function LibStub:NewLibrary(major, minor)
        if not self.libs[major] or (self.libs[major].minor and self.libs[major].minor < minor) then
            self.libs[major] = self.libs[major] or {}
            self.libs[major].minor = minor
            return self.libs[major]
        end
        return nil
    end
    
    -- Get a library instance
    function LibStub:GetLibrary(major, silent)
        if not self.libs[major] and not silent then
            error(("Cannot find a library instance of %q."):format(tostring(major)), 2)
        end
        return self.libs[major]
    end
    
    -- Make LibStub callable: LibStub("LibName") as shorthand for LibStub:GetLibrary("LibName")
    setmetatable(LibStub, { __call = LibStub.GetLibrary })

    -- Register this lib globally
    _G[MAJOR] = LibStub
end

return LibStub