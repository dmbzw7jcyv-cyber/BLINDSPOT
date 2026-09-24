-- Appended to monster.spec.luau to reuse its Vector3 mock.
Vector3.zero = Vector3.new(0, 0, 0)
local CFrame = { lookAt = function(position, target) return { Position = position, target = target } end }
local Hiding = (function()
-- HIDING_SOURCE
end)()
local hiding = Hiding.new()
local function player()
	local root = { Parent = true, Anchored = false }
	local humanoid = { Parent = true, Health = 100, AutoRotate = true }
	return { Character = {
		FindFirstChild = function() return root end,
		FindFirstChildOfClass = function() return humanoid end,
	} }, root, humanoid
end
local function closet()
	return { inside = Vector3.new(0,3,-4.5), outside = Vector3.new(0,3,1), prompt = { Enabled = true } }
end
local a, aRoot, aHumanoid = player()
local b, bRoot = player()
local cabinet = closet()
assert(hiding:enter(a, cabinet, false))
assert(aRoot.Anchored and not aHumanoid.AutoRotate and not cabinet.prompt.Enabled)
assert(aRoot.CFrame.Position == cabinet.inside and not hiding:get(a).exposed)
assert(not hiding:enter(b, cabinet, false), "Occupied closet rejects second player")
assert(not hiding:enter(a, closet(), true), "No nested hiding entries")
assert(not hiding:leave(b, true), "Cannot exit someone else's closet")
assert(hiding:leave(a, true))
assert(not aRoot.Anchored and aHumanoid.AutoRotate and cabinet.prompt.Enabled)
assert(aRoot.CFrame.Position == cabinet.outside and hiding:get(a) == nil)
aHumanoid.Health = 0
assert(not hiding:enter(a, cabinet, false), "Dead Runner cannot enter")
aHumanoid.Health = 100
assert(hiding:enter(a, cabinet, true) and hiding:get(a).exposed)
assert(hiding:enter(b, closet(), false))
hiding:reset()
assert(not aRoot.Anchored and not bRoot.Anchored and next(hiding.occupants) == nil)
assert(cabinet.prompt.Enabled and cabinet.occupant == nil)
print("PASS closet occupancy, anchoring, safe exit, dead character rejection and reset cleanup")
