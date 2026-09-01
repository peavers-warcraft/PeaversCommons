--------------------------------------------------------------------------------
-- The offline harness - loads a PeaversCommons module under a stubbed client so
-- its arithmetic can be checked without a running game.
--
-- Only modules whose load does not touch the client can be driven this way.
-- Capture.lua is written to qualify: everything that calls CreateFrame or
-- Screenshot sits inside a function, and the slash registration is guarded on
-- SlashCmdList existing. That is deliberate - the geometry is the part that can
-- be wrong in a way nobody sees, so the geometry is the part kept testable.
--
-- Run with the system lua (tests/run.sh). Two things differ from WoW's 5.1:
-- loop control variables are const in 5.4+, and `unpack` is `table.unpack`.
-- Neither may appear in addon code - it would work in game and break here,
-- which is where the checking happens.
--------------------------------------------------------------------------------

local harness = {}

---This file is `<PeaversCommons>/tests/harness.lua`, whatever the checkout is
---called and wherever a worktree puts it, so the addon root is two levels up.
---@return string
local function root()
	local here = debug.getinfo(1, "S").source:sub(2)
	local testsDir = here:match("^(.*)/[^/]+$") or "."
	return testsDir .. "/.."
end

harness.root = root

--------------------------------------------------------------------------------
-- Stubs
--------------------------------------------------------------------------------

---A stand-in for a Frame, answering only the geometry the code reads.
---
---`rect` is in the frame's OWN coordinate space, exactly as GetRect reports it,
---and `scale` is the effective scale. Keeping those separate is the whole point:
---a union that forgets to multiply them agrees with a correct one whenever every
---frame is at scale 1, which is every frame in a default UI.
---@param rect table {left, bottom, width, height}
---@param scale number? effective scale, default 1
---@param own number? the frame's own SetScale value, default = scale
---@param children table[]? visible child frames, as the client would report them
function harness.frame(rect, scale, own, children)
	local frame = {}
	local effective = scale or 1

	function frame:GetRect()
		return rect[1], rect[2], rect[3], rect[4]
	end

	function frame:IsVisible()
		return true
	end

	if children then
		function frame:GetChildren()
			return table.unpack(children)
		end
	end

	function frame:GetEffectiveScale()
		return effective
	end

	function frame:GetScale()
		return own or effective
	end

	return frame
end

---Load a module under a minimal `_G.PeaversCommons`, returning what it exports.
---@param relativePath string e.g. "src/UI/Capture.lua"
---@return any
function harness.load(relativePath)
	_G.PeaversCommons = _G.PeaversCommons or {}

	-- The client exposes os.date and os.time as bare globals, and addon code is
	-- written against those. Standard Lua does not, so they are stubbed here
	-- rather than the addon reaching for `os.` and being wrong in game.
	_G.date = _G.date or os.date
	_G.time = _G.time or os.time

	local path = root() .. "/" .. relativePath
	local chunk = assert(loadfile(path), "cannot load " .. path)
	return chunk()
end

--------------------------------------------------------------------------------
-- Assertions
--------------------------------------------------------------------------------

local failures, checks = {}, 0

function harness.check(label, ok, detail)
	checks = checks + 1
	if not ok then
		table.insert(failures, label .. (detail and ("  -> " .. detail) or ""))
	end
end

function harness.equal(label, got, want)
	harness.check(label, got == want,
		("got %s, want %s"):format(tostring(got), tostring(want)))
end

---Floating point, to a tolerance. The geometry is all divisions by scales, so
---exact equality would fail on arithmetic that is entirely correct.
function harness.near(label, got, want, tolerance)
	tolerance = tolerance or 1e-9
	local ok = type(got) == "number" and math.abs(got - want) <= tolerance
	harness.check(label, ok,
		("got %s, want %s"):format(tostring(got), tostring(want)))
end

function harness.report(name)
	if #failures == 0 then
		print(("%s: %d checks OK"):format(name, checks))
		return 0
	end

	print(("%s: %d of %d checks FAILED"):format(name, #failures, checks))
	for _, failure in ipairs(failures) do
		print("  " .. failure)
	end
	return 1
end

return harness
