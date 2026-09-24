-- Run in SERVER Command Bar during Play. Isolated AI; does not alter the live round.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
local facility = require(game.ServerScriptService.Server.Facility)
-- Command Bar has its own module cache; use the live geometry without building again.
facility.Model = workspace.Facility
facility.Start, facility.MonsterStart = facility.position(2, 2), facility.position(22, 18)
facility.Patrol = { facility.Start, facility.MonsterStart }
facility.Objectives = {}
for _, id in { "A", "B", "C" } do facility.Objectives[id] = { part = workspace.Facility["Terminal_" .. id] } end
local Monster = require(game.ServerScriptService.Server.MonsterService)
local m = Monster.new(facility)
m.position = facility.Start
local target = facility.Start + Vector3.new(28, 0, 0)
local killed = false
for _ = 1, 40 do
	killed = m:step(0.2, target, os.clock())
	if killed then break end
	task.wait(0.2)
end
assert(m.state == "Chase" and killed, "Real navmesh chase must reach the target")
local service = game:GetService("PathfindingService")
for id, objective in facility.Objectives do
	local path = service:CreatePath({ AgentRadius = 2, AgentHeight = 6, AgentCanJump = false })
	path:ComputeAsync(facility.Start, objective.part.Position + Vector3.new(4, 0, 0))
	assert(path.Status == Enum.PathStatus.Success, "Navmesh cannot reach relay " .. id)
	path:Destroy()
end
for _, cabinet in workspace.Facility:GetChildren() do
	if cabinet.Name:match("^Closet_") then
		local path = service:CreatePath({ AgentRadius = 2, AgentHeight = 6, AgentCanJump = false })
		path:ComputeAsync(facility.Start, cabinet.Door.Position + Vector3.new(0, 0.85, 3.35))
		assert(path.Status == Enum.PathStatus.Success, "Unreachable closet " .. cabinet.Name)
		path:Destroy()
	end
end
print("BLINDSPOT ENGINE AI TESTS PASSED: real navmesh chase/contact and routes to all relays")
