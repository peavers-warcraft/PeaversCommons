local PeaversCommons = _G.PeaversCommons
local Debug = PeaversCommons.Debug

Debug.MAX_LOG_ENTRIES = 500
Debug.logEntries = {}

local COLORS = {
    DEBUG = "|cFF00FFFF",
    INFO = "|cFF00FF00",
    WARN = "|cFFFFFF00",
    ERROR = "|cFFFF0000",
    TIMESTAMP = "|cFF888888",
}

local function GetTimestamp()
    return date("%H:%M:%S")
end

local function FormatMessage(source, message, level)
    local timestamp = GetTimestamp()
    local color = COLORS[level] or COLORS.DEBUG
    return string.format("%s%s|r %s[%s]|r %s",
        COLORS.TIMESTAMP, timestamp,
        color, source or "Unknown",
        tostring(message))
end

function Debug:Log(source, message, level)
    level = level or "DEBUG"

    local entry = {
        timestamp = GetTimestamp(),
        source = source or "Unknown",
        message = tostring(message),
        level = level,
        formatted = FormatMessage(source, message, level)
    }

    table.insert(self.logEntries, entry)

    while #self.logEntries > self.MAX_LOG_ENTRIES do
        table.remove(self.logEntries, 1)
    end

    if self.dialog and self.dialog:IsShown() then
        self.dialog:AddMessage(entry.formatted)
    end
end

function Debug:LogDebug(source, ...)
    local message = table.concat({...}, " ")
    self:Log(source, message, "DEBUG")
end

function Debug:LogInfo(source, ...)
    local message = table.concat({...}, " ")
    self:Log(source, message, "INFO")
end

function Debug:LogWarn(source, ...)
    local message = table.concat({...}, " ")
    self:Log(source, message, "WARN")
end

function Debug:LogError(source, ...)
    local message = table.concat({...}, " ")
    self:Log(source, message, "ERROR")
end

function Debug:Clear()
    wipe(self.logEntries)
    if self.dialog and self.dialog.messageFrame then
        self.dialog.messageFrame:Clear()
    end
end

function Debug:GetEntriesAsText()
    local lines = {}
    for _, entry in ipairs(self.logEntries) do
        local plainText = string.format("%s [%s] [%s] %s",
            entry.timestamp,
            entry.level,
            entry.source,
            entry.message)
        table.insert(lines, plainText)
    end
    return table.concat(lines, "\n")
end

function Debug:Show()
    if not self.dialog then
        if PeaversCommons.DebugDialog and PeaversCommons.DebugDialog.Create then
            self.dialog = PeaversCommons.DebugDialog:Create()
        end
    end

    if self.dialog then
        if self.dialog.messageFrame then
            self.dialog.messageFrame:Clear()
            for _, entry in ipairs(self.logEntries) do
                self.dialog.messageFrame:AddMessage(entry.formatted)
            end
        end
        self.dialog:Show()
    end
end

function Debug:Hide()
    if self.dialog then
        self.dialog:Hide()
    end
end

function Debug:Toggle()
    if self.dialog and self.dialog:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

SLASH_PCDEBUG1 = "/pcdebug"
SlashCmdList["PCDEBUG"] = function(msg)
    local cmd = strlower(msg or "")

    if cmd == "show" then
        Debug:Show()
    elseif cmd == "hide" then
        Debug:Hide()
    elseif cmd == "clear" then
        Debug:Clear()
        print("|cFF00FF00[PeaversCommons]|r Debug log cleared.")
    else
        Debug:Toggle()
    end
end

return Debug
