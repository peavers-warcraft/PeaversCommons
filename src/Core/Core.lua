local MAJOR, MINOR = "PeaversCommons-1.0", 3
local PeaversCommons = LibStub and LibStub:NewLibrary(MAJOR, MINOR) or {}

if not PeaversCommons then return end

PeaversCommons.name = "PeaversCommons"
PeaversCommons.version = MAJOR .. "." .. MINOR

PeaversCommons.Events = {}
PeaversCommons.SlashCommands = {}
PeaversCommons.Utils = {}
PeaversCommons.SupportUI = {}
PeaversCommons.Patrons = {}
PeaversCommons.PatronsUI = {}

PeaversCommons.FrameCore = {}
PeaversCommons.FrameUtils = {}
PeaversCommons.ConfigUIUtils = {}
PeaversCommons.ConfigManager = {}
PeaversCommons.SettingsUI = {}

PeaversCommons.BarManager = {}
PeaversCommons.StatBar = {}
PeaversCommons.TitleBar = {}
PeaversCommons.BarStyles = {}
PeaversCommons.Debug = {}

_G.PeaversCommons = PeaversCommons

return PeaversCommons