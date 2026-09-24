local PathfindingService = game:GetService("PathfindingService")
local Monster = {}
Monster.__index = Monster

function Monster.new(facility)
	return setmetatable({ facility = facility, position = facility.MonsterStart, state = "Patrol", paused = false, route = {}, index = 1, nextPath = 0, lastSeen = 0, generation = 0 }, Monster)
end

function Monster:reset()
	self.generation += 1
	self.position, self.state, self.paused = self.facility.MonsterStart, "Patrol", false
	self.route, self.index, self.nextPath, self.lastSeen, self.target = {}, 1, 0, 0, nil
end

function Monster:clearSight(target)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { self.facility.Model }
	return workspace:Raycast(self.position, target - self.position, params) == nil
end

function Monster:step(dt, runnerPosition, now, hidden)
	if self.paused then return false end
	local distance = (runnerPosition - self.position).Magnitude
	local visible = not hidden and distance < 62 and self:clearSight(runnerPosition)
	if visible then
		self.state, self.lastSeen, self.target = "Chase", now, runnerPosition
	elseif self.state == "Chase" then
		self.state = "Search"
	elseif self.state == "Search" and now - self.lastSeen > 6 then
		self.state, self.target = "Patrol", nil
	end
	-- Resolve contact before taking a movement step or selecting another patrol goal.
	if distance < 4 and visible then return true end
	if not self.target or (self.target - self.position).Magnitude < 4 then
		self.target = self.facility.Patrol[math.random(1, #self.facility.Patrol)]
	end
	if now >= self.nextPath and not self.computing then
		self.nextPath, self.computing = now + 1.25, true
		local generation, target = self.generation, self.target
		task.spawn(function()
			local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 6, AgentCanJump = false, WaypointSpacing = 5 })
			local ok = pcall(function() path:ComputeAsync(self.position, target) end)
			if generation == self.generation then
				if ok and path.Status == Enum.PathStatus.Success then
					self.route, self.index = path:GetWaypoints(), 2
				else
					self.route = {}
					if self.state == "Patrol" then self.target = nil end
				end
			end
			self.computing = false
			path:Destroy()
		end)
	end
	local waypoint = self.route[self.index]
	if waypoint then
		local destination = Vector3.new(waypoint.Position.X, 3, waypoint.Position.Z)
		local delta = destination - self.position
		local step = math.min(delta.Magnitude, (if self.state == "Chase" then 12 else 8) * dt)
		if delta.Magnitude > 0.01 then
			local nextPosition = self.position + delta.Unit * step
			if self:clearSight(nextPosition) then self.position = nextPosition else self.route = {} end
		end
		if delta.Magnitude < 1 then self.index += 1 end
	end
	return not hidden and (runnerPosition - self.position).Magnitude < 4 and self:clearSight(runnerPosition)
end

return Monster
