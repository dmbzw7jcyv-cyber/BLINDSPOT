-- Run this file's contents in Studio's CLIENT Command Bar during a solo playtest.
-- Intentionally outside the Rojo tree. Uses only Studio debug and real prompts.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
local players = game:GetService("Players")
assert(#players:GetPlayers() == 1 and players.LocalPlayer, "Solo CLIENT context required")
local player = players.LocalPlayer
local remotes = game.ReplicatedStorage.BlindspotRemotes
local latest, maps, scans, creatures = nil, 0, 0, 0
local connections = {
	remotes.State.OnClientEvent:Connect(function(p) latest = p end),
	remotes.Map.OnClientEvent:Connect(function(p)
		maps += 1
		assert(p.monster == nil and p.bearing == nil and p.distance == nil)
		assert(not table.concat(p.rows):find("M"), "Monster spawn must not be in map payload")
	end),
	remotes.Scan.OnClientEvent:Connect(function(p)
		scans += 1
		assert(p.rows == nil and p.objectives == nil and p.runner == nil and p.position == nil)
	end),
	remotes.Creature.OnClientEvent:Connect(function() creatures += 1 end),
}
local function command(action)
	remotes.Debug:FireServer(action)
	task.wait(0.7)
end
local function moveTo(position)
	player.Character:PivotTo(CFrame.new(position))
	task.wait(0.8)
end
local function activate(prompt)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local head = player.Character.Head.Position
	camera.CFrame = CFrame.lookAt(head, prompt.Parent.Position)
	task.wait(0.5) -- the prompt must be on screen before simulated hold input
	prompt:InputHoldBegin()
	task.wait(prompt.HoldDuration + 0.5)
	prompt:InputHoldEnd()
	task.wait(0.5)
	camera.CameraType = Enum.CameraType.Custom
end
local ok, err = pcall(function()
	command("Reset Round")
	task.wait(4)
	command("Pause Monster AI")
	assert(latest and latest.state == "Playing" and latest.role == "Runner")
	maps, scans = 0, 0
	task.wait(1.5)
	assert(maps == 0 and scans == 0, "Runner must receive no map/radar")
	print("BLINDSPOT TEST PASS: Runner packet separation")
	command("Navigator")
	maps, scans, creatures = 0, 0, 0
	task.wait(1.5)
	assert(latest.role == "Navigator" and maps > 0 and scans == 0 and creatures == 0)
	assert(player.CameraMinZoomDistance >= 8, "Station camera must leave first person")
	print("BLINDSPOT TEST PASS: Navigator packets and camera")
	command("Tracker")
	maps, scans, creatures = 0, 0, 0
	task.wait(1.5)
	assert(latest.role == "Tracker" and maps == 0 and scans > 0 and creatures == 0)
	print("BLINDSPOT TEST PASS: Tracker packet separation")
	local terminal = workspace.Facility.Terminal_A
	moveTo(terminal.Position + Vector3.new(4, 0, 0))
	activate(terminal.ProximityPrompt)
	assert(latest.completed == 0, "Tracker cannot activate relay")
	print("BLINDSPOT TEST PASS: non-Runner interaction denied")
	command("Runner")
	activate(terminal.ProximityPrompt)
	assert(latest.completed == 0, "Remote-distance interaction denied")
	print("BLINDSPOT TEST PASS: distant interaction denied")
	local cabinet = workspace.Facility.Closet_1
	local approach = cabinet.Door.Position + Vector3.new(0, 0.85, 3.35)
	moveTo(approach)
	activate(cabinet.Door.ProximityPrompt)
	assert(latest.hiding and player.Character.HumanoidRootPart.Anchored, "Closet entry anchors Runner")
	assert(not workspace.LocalFlashlight.SpotLight.Enabled, "Flashlight goes dark in closet")
	remotes.LeaveCloset:FireServer()
	task.wait(0.7)
	assert(not latest.hiding and not player.Character.HumanoidRootPart.Anchored, "Exit restores movement")
	activate(cabinet.Door.ProximityPrompt)
	assert(latest.hiding)
	command("Navigator")
	assert(not latest.hiding and not player.Character.HumanoidRootPart.Anchored, "Role switch clears hiding")
	command("Runner")
	moveTo(approach)
	activate(cabinet.Door.ProximityPrompt)
	assert(latest.hiding)
	command("Reset Round")
	task.wait(4)
	command("Pause Monster AI")
	assert(not latest.hiding and not player.Character.HumanoidRootPart.Anchored, "Reset clears closet occupant")
	assert(cabinet.Door.ProximityPrompt.Enabled)
	print("BLINDSPOT TEST PASS: closet entry, flashlight, exit, role switch and reset cleanup")
	for _, id in { "A", "B", "C" } do
		local part = workspace.Facility["Terminal_" .. id]
		moveTo(part.Position + Vector3.new(4, 0, 0))
		activate(part.ProximityPrompt)
	end
	assert(latest.completed == 3 and not workspace.Facility.ExitDoor.CanCollide)
	print("BLINDSPOT TEST PASS: three real prompts unlock exit")
	moveTo(workspace.Facility.ExitDoor.Position + Vector3.new(0, -2, 5))
	assert(latest.state == "Won", "Unlocked exit wins")
	print("BLINDSPOT TEST PASS: extraction wins")
	command("Reset Round")
	task.wait(4)
	assert(latest.state == "Playing" and latest.completed == 0 and workspace.Facility.ExitDoor.CanCollide)
	print("BLINDSPOT TEST PASS: round reset")
	command("Pause Monster AI")
	moveTo(Vector3.new(294, 3, 238)) -- fixed M cell in the expanded southeast wing
	command("Spawn/Reset Monster") -- resume at the exact contact point
	local untilTime = os.clock() + 6
	while latest.state ~= "Lost" and os.clock() < untilTime do task.wait(0.1) end
	assert(latest.state == "Lost", "Monster killing Runner loses")
	print("BLINDSPOT TEST PASS: authoritative monster kill / Runner death loses")
end)
for _, connection in connections do connection:Disconnect() end
assert(ok, err)
print("BLINDSPOT SOLO INTEGRATION TESTS PASSED")
