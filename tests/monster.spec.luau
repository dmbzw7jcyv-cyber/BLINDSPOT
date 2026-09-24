-- Minimal vector/navmesh mock; executes the actual MonsterService source below.
local Vector3 = {}
local mt = {}
function Vector3.new(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, mt) end
mt.__add = function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
mt.__sub = function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
mt.__mul = function(a,b) return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
mt.__index = function(a,k)
	if k == "Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end
	if k == "Unit" then return a * (1/a.Magnitude) end
end
local blocked, pathCount, failPath = false, 0, false
local workspace = { Raycast = function() return if blocked then {} else nil end }
local RaycastParams = { new = function() return {} end }
local Enum = { RaycastFilterType = { Include = 1 }, PathStatus = { Success = 1 } }
local task = { spawn = function(fn) fn() end }
local service = { CreatePath = function()
	local target
	return {
		Status = if failPath then 0 else 1,
		ComputeAsync = function(_, _, destination) pathCount += 1; target = destination end,
		GetWaypoints = function() return { { Position = Vector3.new(0,3,0) }, { Position = target } } end,
		Destroy = function() end,
	}
end }
local game = { GetService = function() return service end }
local Monster = (function()
-- MONSTER_SOURCE
end)()
local facility = { Model = {}, MonsterStart = Vector3.new(0,3,0), Patrol = { Vector3.new(80,3,0) } }
local m = Monster.new(facility)
assert(m.state == "Patrol")
m:step(0.2, Vector3.new(100,3,0), 1)
assert(m.state == "Patrol" and m.position.X > 0, "Patrol movement")
m:step(0.2, Vector3.new(25,3,0), 2)
assert(m.state == "Chase", "Visible nearby Runner triggers chase")
blocked = true
m:step(0.2, Vector3.new(25,3,0), 3)
assert(m.state == "Search", "Lost line of sight triggers search")
m:step(0.2, Vector3.new(100,3,0), 10)
assert(m.state == "Patrol", "Search timeout returns to patrol")
local before = m.position
m.paused = true
assert(not m:step(0.2, m.position, 11) and m.position == before, "Pause prevents movement and kill")
m:reset()
assert(not m.paused and m.state == "Patrol" and #m.route == 0, "Reset clears AI state")
assert(not m:step(0.2, Vector3.new(1,3,0), 12), "Cannot kill through a wall")
blocked = false
assert(m:step(0.2, Vector3.new(1,3,0), 13), "Close visible Runner is killed")
m:reset()
local pathsBefore = pathCount
for i=1,10 do m:step(0.2, Vector3.new(30,3,0), 20+i*0.02) end
assert(pathCount - pathsBefore == 1, "Pathfinding is rate limited")
failPath = true
m:reset()
m:step(0.2, Vector3.new(100,3,0), 30)
assert(#m.route == 0 and m.target == nil, "Failed patrol path retries a new destination")
print("PASS monster patrol, chase, search, pause, reset, occlusion, kill, path rate limit and path failure")
failPath = false
m:reset()
m:step(0.2, Vector3.new(20,3,0), 40)
assert(m.state == "Chase")
assert(not m:step(0.2, m.position, 41, true), "Hidden Runner cannot be killed or reacquired")
assert(m.state == "Search", "Hiding breaks visual tracking")
m:step(0.2, m.position, 48, true)
assert(m.state == "Patrol", "Hidden Runner is not tracked after search timeout")
assert(m:step(0.2, m.position, 49, false), "Leaving cover or witnessed entry permits contact")
print("PASS hiding blocks detection and damage, search expires, exposed contact remains lethal")
