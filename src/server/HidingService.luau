local Hiding = {}
Hiding.__index = Hiding

function Hiding.new()
	return setmetatable({ occupants = {} }, Hiding)
end

function Hiding:enter(player, closet, exposed)
	if self.occupants[player] or closet.occupant then return false end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return false end
	self.occupants[player] = { closet = closet, root = root, humanoid = humanoid, anchored = root.Anchored, autoRotate = humanoid.AutoRotate, exposed = exposed }
	closet.occupant, closet.prompt.Enabled = player, false
	root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	root.CFrame = CFrame.lookAt(closet.inside, closet.inside + Vector3.new(0, 0, 1))
	root.Anchored, humanoid.AutoRotate = true, false
	return true
end

function Hiding:leave(player, reposition)
	local entry = self.occupants[player]
	if not entry then return false end
	self.occupants[player] = nil
	entry.closet.occupant, entry.closet.prompt.Enabled = nil, true
	if entry.root.Parent then
		if reposition then entry.root.CFrame = CFrame.lookAt(entry.closet.outside, entry.closet.outside + Vector3.new(0, 0, 1)) end
		entry.root.Anchored = entry.anchored
	end
	if entry.humanoid.Parent then entry.humanoid.AutoRotate = entry.autoRotate end
	return true
end

function Hiding:get(player)
	return self.occupants[player]
end

function Hiding:reset()
	for player in self.occupants do self:leave(player, true) end
end

return Hiding
