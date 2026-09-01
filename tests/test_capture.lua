--------------------------------------------------------------------------------
-- Capture.lua - the arithmetic that decides where a window was on screen.
--
-- None of this is checkable by looking at the game. A crop that is wrong by a
-- scale factor produces a screenshot that is merely a bit tight, which is what
-- a hand-cropped one looks like anyway, so the failure this guards against is
-- one nobody would report.
--------------------------------------------------------------------------------

local harness = dofile((debug.getinfo(1, "S").source:sub(2):match("^(.*)/[^/]+$") or ".") .. "/harness.lua")
local Capture = harness.load("src/UI/Capture.lua")

local check, equal, near = harness.check, harness.equal, harness.near

--------------------------------------------------------------------------------
-- Resolve - the dotted route from _G
--------------------------------------------------------------------------------

local env = {
	PeaversDynamicStats = { Core = { frame = { name = "stats" } } },
	PeaversConfigFrame = { name = "config" },
	Shallow = { leaf = "a string, not a table" },
}

equal("resolves a nested route",
	Capture:Resolve("PeaversDynamicStats.Core.frame", env), env.PeaversDynamicStats.Core.frame)

equal("resolves a top-level route",
	Capture:Resolve("PeaversConfigFrame", env), env.PeaversConfigFrame)

equal("missing route is nil, not an error",
	Capture:Resolve("PeaversNotInstalled.Core.frame", env), nil)

equal("route through a non-table is nil",
	Capture:Resolve("Shallow.leaf.deeper", env), nil)

equal("empty route is nil", Capture:Resolve("", env), nil)
equal("non-string route is nil", Capture:Resolve(nil, env), nil)

--------------------------------------------------------------------------------
-- FramesFor - a target's frames, skipping what is not installed
--------------------------------------------------------------------------------

equal("single path resolves to one frame",
	#Capture:FramesFor({ path = "PeaversConfigFrame" }, env), 1)

equal("a target naming four windows of which two exist yields two",
	#Capture:FramesFor({ paths = {
		"PeaversConfigFrame",
		"PeaversDynamicStats.Core.frame",
		"NotInstalledOne",
		"NotInstalledTwo",
	} }, env), 2)

equal("no route resolving yields none",
	#Capture:FramesFor({ path = "NotInstalled" }, env), 0)

-- The error inside a frame() accessor is the interesting case: an addon that
-- half-initialised should be skipped, not take the whole run down with it.
equal("a frame accessor that errors is skipped, not propagated",
	#Capture:FramesFor({ frame = function() error("half loaded") end }, env), 0)

--------------------------------------------------------------------------------
-- UnionRect - normalising scale before combining
--------------------------------------------------------------------------------

local single = { harness.frame({ 100, 200, 300, 100 }, 1) }
local left, bottom, width, height = Capture:UnionRect(single)
near("single frame: left", left, 100)
near("single frame: bottom", bottom, 200)
near("single frame: width", width, 300)
near("single frame: height", height, 100)

-- A frame at scale 2 reports HALF the absolute size in its own space. Two frames
-- at different scales are the case a naive union gets wrong, and a default UI
-- never exercises it because everything sits at scale 1.
local mixed = {
	harness.frame({ 0, 0, 100, 100 }, 1),   -- absolute 0..100
	harness.frame({ 100, 0, 50, 50 }, 2),   -- absolute 200..300
}
left, bottom, width, height = Capture:UnionRect(mixed)
near("mixed scales: left is the leftmost absolute edge", left, 0)
near("mixed scales: width spans to the far frame's absolute right", width, 300)
near("mixed scales: height is the taller frame in absolute units", height, 100)

-- Children are not clipped to their parent in WoW, so the rect of a window is
-- not the window. PeaversUnitFrames hangs its aura icons above the unit button,
-- outside its rect, and the first finished screenshot had the whole buff row
-- cropped off - which looked deliberate, the way a tight crop always does.
local withAuras = {
	harness.frame({ 100, 100, 200, 50 }, 1, nil, {
		harness.frame({ 100, 160, 200, 30 }, 1), -- auras, above the button
		harness.frame({ 100, 90, 200, 8 }, 1),   -- cast bar, below it
	}),
}
left, bottom, width, height = Capture:UnionRect(withAuras)
near("children above the frame extend the union upwards", bottom + height, 190)
near("children below the frame extend it downwards", bottom, 90)
near("the union is as wide as the widest of them", width, 200)

-- A hidden child parked off-screen must not drag the crop across the screen.
local hidden = harness.frame({ 4000, 4000, 50, 50 }, 1)
function hidden:IsVisible() return false end
left, bottom, width, height = Capture:UnionRect({
	harness.frame({ 100, 100, 200, 50 }, 1, nil, { hidden }),
})
near("a hidden child is ignored", width, 200)

check("no frames yields nil rather than a zero rect",
	Capture:UnionRect({}) == nil)

check("a frame with no geometry is skipped",
	Capture:UnionRect({ { name = "not a frame" } }) == nil)

--------------------------------------------------------------------------------
-- ToPixels - absolute UI units to image pixels
--
-- The coordinate space at scale 1 is 768 units tall whatever the resolution, so
-- on a 2560x1440 client one unit is 1440/768 = 1.875 px.
--------------------------------------------------------------------------------

local pixels = Capture:ToPixels(100, 200, 300, 100, 2560, 1440)
near("perUnit is physicalHeight/768", pixels.perUnit, 1.875)
near("x scales by perUnit", pixels.x, 187.5)
near("w scales by perUnit", pixels.w, 562.5)
near("h scales by perUnit", pixels.h, 187.5)

-- GetRect measures up from the bottom; an image measures down from the top. The
-- top of this rect is at 300 units, i.e. 562.5 px up from the bottom of a
-- 1440 px image, so 877.5 px down from its top.
near("y is flipped to measure from the top", pixels.y, 877.5)

-- A rect flush with the bottom-left of the screen lands at the bottom-left of
-- the image, which is the check that catches a flip applied twice.
local corner = Capture:ToPixels(0, 0, 768 * (2560 / 1440), 768, 2560, 1440)
near("full-screen rect starts at x=0", corner.x, 0)
near("full-screen rect starts at y=0", corner.y, 0)
near("full-screen rect is the full image height", corner.h, 1440)
near("full-screen rect is the full image width", corner.w, 2560, 1e-6)

--------------------------------------------------------------------------------
-- FitScale - magnify, but never past the edge of the stage
--------------------------------------------------------------------------------

-- Against the exposed ceiling rather than a repeated literal: the first version
-- of this hardcoded 2, and silently became a false assertion the moment the
-- ceiling was raised.
near("a small window takes the full magnification",
	Capture:FitScale(100, 100, 1000, 1000), Capture.MAX_SCALE)

-- 1000 * 0.86 / 500 = 1.72, below the requested 2.
near("a large window is held back so its marks stay on screen",
	Capture:FitScale(500, 500, 1000, 1000), 1.72)

-- The binding constraint is the wide axis, not the tall one.
near("the tighter axis wins",
	Capture:FitScale(2000, 100, 1000, 1000), 0.43)

check("a window wider than the screen shrinks below 1",
	Capture:FitScale(4000, 100, 1000, 1000) < 1)

near("a degenerate rect does not divide by zero",
	Capture:FitScale(0, 0, 1000, 1000), 1)

--------------------------------------------------------------------------------
-- PredictFilename - the client names a shot from the clock
--------------------------------------------------------------------------------

local filename = Capture:PredictFilename("tga")
check("predicted filename matches the client's naming",
	filename:match("^WoWScrnShot_%d%d%d%d%d%d_%d%d%d%d%d%d%.tga$") ~= nil,
	filename)

--------------------------------------------------------------------------------
-- Targets - registration shadows a built-in of the same key
--------------------------------------------------------------------------------

local builtinCount = #Capture:Targets()

Capture:Register("PeaversDynamicStats", { id = "stats", label = "Replaced", path = "Somewhere.Else" })
local afterReplace = Capture:Targets()
equal("replacing a built-in does not add a target", #afterReplace, builtinCount)

local replaced
for _, target in ipairs(afterReplace) do
	if target.addon == "PeaversDynamicStats" and target.id == "stats" then replaced = target end
end
equal("the registered target wins", replaced and replaced.label, "Replaced")

Capture:Register("PeaversDynamicStats", { id = "second", label = "Another window", path = "X" })
equal("a new id adds a target", #Capture:Targets(), builtinCount + 1)

Capture:Register("SomeAddon", "not a table")
equal("a malformed registration is ignored", #Capture:Targets(), builtinCount + 1)

--------------------------------------------------------------------------------
-- The built-in table is data, so it can be checked as data
--
-- A typo in a route is invisible in game: the addon simply reports as "not
-- loaded", which is also what an uninstalled addon looks like.
--------------------------------------------------------------------------------

local seen = {}
for _, target in ipairs(Capture.builtin) do
	local key = target.addon .. ":" .. (target.id or "main")

	check("built-in has an addon name", type(target.addon) == "string" and target.addon ~= "")
	check("built-in has a label: " .. key, type(target.label) == "string" and target.label ~= "")
	check("built-in key is unique: " .. key, seen[key] == nil)
	seen[key] = true

	local paths = target.paths or { target.path }
	check("built-in names at least one route: " .. key, #paths > 0)

	for _, path in ipairs(paths) do
		check("route is a non-empty string: " .. key, type(path) == "string" and path ~= "")
		check("route has no empty segment: " .. key .. " " .. tostring(path),
			path:match("%.%.") == nil and path:match("^%.") == nil and path:match("%.$") == nil)
	end
end

os.exit(harness.report("test_capture"))
