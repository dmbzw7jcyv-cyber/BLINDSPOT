local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UI = require(script.Interface)
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("BlindspotRemotes")
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset = "BLINDSPOT", false, false
gui.Parent = player:WaitForChild("PlayerGui")
local header = UI.label(gui, "BLINDSPOT / CONNECTING", UDim2.new(0, 22, 1, -84), UDim2.new(0.65, 0, 0, 18), 12)
header.TextXAlignment = Enum.TextXAlignment.Left
header.TextTransparency = 0.22
local status = UI.label(gui, "", UDim2.new(0, 22, 1, -63), UDim2.new(0.75, 0, 0, 32), 12)
status.TextXAlignment, status.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
local roleLayer = UI.frame(gui, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
roleLayer.BackgroundTransparency = 1
local role, roundState, mapUpdate, radarUpdate, debugMap, debugPanel = nil, "Waiting", nil, nil, nil, nil
local monsterPart, monsterTarget, lamp, lampPart = nil, nil, nil, nil
local monsterPieces = {}
local flashlightOn = true
local hiding = false

local function clearMonster()
	if monsterPart then monsterPart:Destroy(); monsterPart = nil end
	monsterTarget = nil
	monsterPieces = {}
end
local function clearLamp()
	if lampPart then lampPart:Destroy() end
	lampPart, lamp = nil, nil
end
local function configureCamera()
	player.CameraMode = if role == "Runner" then Enum.CameraMode.LockFirstPerson else Enum.CameraMode.Classic
	player.CameraMaxZoomDistance = if role == "Runner" then 0.5 else 18
	player.CameraMinZoomDistance = if role == "Runner" then 0.5 else 8
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end
local function switchRole(nextRole)
	role = nextRole
	roleLayer:ClearAllChildren()
	mapUpdate, radarUpdate, debugMap = nil, nil, nil
	clearMonster()
	clearLamp()
	configureCamera()
	if role == "Runner" then
		local reticle = UI.label(roleLayer, "·", UDim2.fromScale(0.49, 0.48), UDim2.fromScale(0.02, 0.04), 12)
		reticle.TextTransparency = 0.6
		local hint = UI.label(roleLayer, "F  light    E  interact", UDim2.new(0, 22, 1, -26), UDim2.new(0.5, 0, 0, 15), 11)
		hint.TextXAlignment, hint.TextTransparency = Enum.TextXAlignment.Left, 0.45
	elseif role == "Navigator" then
		local _, update = UI.map(roleLayer)
		mapUpdate = update
	elseif role == "Tracker" then
		local _, update = UI.radar(roleLayer)
		radarUpdate = update
	else
		UI.label(roleLayer, "OPERATOR STANDBY\nThree operators required. Extra players wait for the next round.", UDim2.fromScale(0.25, 0.35), UDim2.fromScale(0.5, 0.3), 20)
	end
end

local function addDebug()
	if debugPanel or not RunService:IsStudio() then return end
	local remote = remotes:WaitForChild("Debug")
	debugPanel = UI.frame(gui, UDim2.new(1, -222, 0, 52), UDim2.fromOffset(214, 388))
	UI.label(debugPanel, "STUDIO DEBUG [F2]", UDim2.fromOffset(4, 4), UDim2.new(1, -8, 0, 24), 14)
	local actions = { "Runner", "Navigator", "Tracker", "Spawn/Reset Monster", "Pause Monster AI", "Resume Monster AI", "Teleport to Runner area", "Teleport to Control Room", "Reveal Map", "Reset Round" }
	for i, action in actions do
		UI.button(debugPanel, action, 28 + (i - 1) * 30, function()
			if action == "Reveal Map" and debugMap then debugMap:Destroy(); debugMap, mapUpdate = nil, nil end
			remote:FireServer(action)
		end)
	end
	UI.label(debugPanel, "Role switching: solo only\nStation inspection freezes AI\nF2 releases Runner cursor", UDim2.fromOffset(5, 330), UDim2.new(1, -10, 0, 55), 12)
	debugPanel.Visible = false
end

remotes:WaitForChild("State").OnClientEvent:Connect(function(packet)
	if role ~= packet.role then switchRole(packet.role) end
	if debugMap and not packet.reveal then debugMap:Destroy(); debugMap, mapUpdate = nil, nil end
	roundState = packet.state
	hiding = packet.hiding == true and role == "Runner" and roundState == "Playing"
	if workspace.CurrentCamera then workspace.CurrentCamera.CameraType = if hiding then Enum.CameraType.Scriptable else Enum.CameraType.Custom end
	if roundState ~= "Playing" then clearMonster() end
	header.Text = string.upper(packet.role) .. " / " .. string.upper(packet.state)
	status.Text = if hiding then "Inside closet / E to leave" else packet.message .. "   [" .. packet.completed .. "/3]"
	if packet.studio and RunService:IsStudio() then addDebug() end
end)
remotes:WaitForChild("Map").OnClientEvent:Connect(function(packet)
	if role ~= "Navigator" then
		if not RunService:IsStudio() or not packet.debug then return end
		if not debugMap then debugMap, mapUpdate = UI.map(roleLayer) end
	end
	if mapUpdate then mapUpdate(packet) end
end)
remotes:WaitForChild("Scan").OnClientEvent:Connect(function(packet)
	if role == "Tracker" and radarUpdate then radarUpdate(packet) end
end)
remotes:WaitForChild("Creature").OnClientEvent:Connect(function(position)
	if role ~= "Runner" or roundState ~= "Playing" or not position then clearMonster(); return end
	monsterTarget = position
	if not monsterPart then
		monsterPart = Instance.new("Part")
		monsterPart.Name, monsterPart.Size = "LocalHostile", Vector3.new(2.2, 4, 1.5)
		monsterPart.Anchored, monsterPart.CanCollide, monsterPart.CanQuery = true, false, false
		monsterPart.Color, monsterPart.Material = Color3.fromRGB(32, 29, 27), Enum.Material.Slate
		monsterPart.Position, monsterPart.Parent = position, workspace
		local function piece(name, size, offset, color, material)
			local p = Instance.new("Part")
			p.Name, p.Size, p.Color = name, size, color or monsterPart.Color
			p.Material = material or Enum.Material.Slate
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
			p.CFrame, p.Parent = CFrame.new(position) * offset, monsterPart
			table.insert(monsterPieces, { part = p, offset = offset })
		end
		-- A gaunt, asymmetrical silhouette; no global NPC model or replicated coordinates.
		piece("Head", Vector3.new(1.45, 1.9, 1.2), CFrame.new(0.2, 2.6, -0.65) * CFrame.Angles(0, 0, math.rad(16)), Color3.fromRGB(103, 96, 82))
		piece("Face", Vector3.new(0.8, 1.25, 0.15), CFrame.new(0.23, 2.5, -1.29), Color3.fromRGB(9, 8, 8))
		piece("Shoulders", Vector3.new(3.3, 0.65, 1.8), CFrame.new(0, 1.4, 0.1) * CFrame.Angles(0, 0, math.rad(-9)))
		piece("LeftArm", Vector3.new(0.6, 4.7, 0.65), CFrame.new(-1.55, -0.35, -0.2) * CFrame.Angles(0, 0, math.rad(-8)))
		piece("RightArm", Vector3.new(0.55, 5.1, 0.65), CFrame.new(1.6, -0.2, -0.5) * CFrame.Angles(math.rad(-12), 0, math.rad(11)))
		for _, x in { -0.65, 0.65 } do
			piece("Leg", Vector3.new(0.65, 3.2, 0.7), CFrame.new(x, -1.35, 0.15))
		end
		for _, x in { -0.06, 0.49 } do
			piece("Eye", Vector3.new(0.11, 0.14, 0.08), CFrame.new(x, 2.8, -1.4), Color3.fromRGB(158, 137, 96), Enum.Material.Neon)
		end
		if Config.Sounds.Monster ~= "" then
			local sound = Instance.new("Sound")
			sound.SoundId, sound.Looped, sound.Volume, sound.RollOffMaxDistance = Config.Sounds.Monster, true, 0.6, 65
			sound.Parent = monsterPart
			sound:Play()
		end
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E and hiding then remotes.LeaveCloset:FireServer(); return end
	if input.KeyCode == Enum.KeyCode.F then flashlightOn = not flashlightOn end
	if input.KeyCode == Enum.KeyCode.F2 and debugPanel then
		debugPanel.Visible = not debugPanel.Visible
		if role == "Runner" then player.CameraMode = if debugPanel.Visible then Enum.CameraMode.Classic else Enum.CameraMode.LockFirstPerson end
	end
end)
player.CharacterAdded:Connect(function() clearLamp(); configureCamera() end)
RunService.RenderStepped:Connect(function(dt)
	local camera = workspace.CurrentCamera
	if hiding and camera then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local eye = root.Position + Vector3.new(0, 1.7, 0)
			camera.CFrame = CFrame.lookAt(eye, eye + Vector3.new(0, 0, 1))
		end
	end
	if role ~= "Runner" then UserInputService.MouseBehavior = Enum.MouseBehavior.Default end
	if role == "Runner" and camera then
		if not lampPart then
			lampPart = Instance.new("Part")
			lampPart.Name, lampPart.Size, lampPart.Transparency = "LocalFlashlight", Vector3.new(0.1, 0.1, 0.1), 1
			lampPart.Anchored, lampPart.CanCollide, lampPart.CanQuery, lampPart.CastShadow = true, false, false, false
			lampPart.Parent = workspace
			lamp = Instance.new("SpotLight")
			-- Unshadowed camera light avoids avatar hats occluding the entire beam.
			-- Fixed facility lights still cast environmental shadows.
			lamp.Face, lamp.Angle, lamp.Range, lamp.Brightness, lamp.Shadows = Enum.NormalId.Front, 68, 60, 5, false
			lamp.Color = Color3.fromRGB(225, 214, 184)
			lamp.Parent = lampPart
		end
		lampPart.CFrame, lamp.Enabled = camera.CFrame * CFrame.new(0, -0.2, -1), flashlightOn and not hiding
		if debugPanel and debugPanel.Visible then UserInputService.MouseBehavior = Enum.MouseBehavior.Default end
	end
	if monsterPart and monsterTarget and camera then
		local position = monsterPart.Position:Lerp(monsterTarget, math.min(dt * 12, 1))
		local facing = Vector3.new(camera.CFrame.Position.X, position.Y, camera.CFrame.Position.Z)
		monsterPart.CFrame = if (facing - position).Magnitude > 0.01 then CFrame.lookAt(position, facing) else CFrame.new(position)
		for _, item in monsterPieces do
			item.part.CFrame = monsterPart.CFrame * item.offset
		end
	end
end)
if Config.Sounds.Ambient ~= "" then
	local sound = Instance.new("Sound")
	sound.SoundId, sound.Looped, sound.Volume = Config.Sounds.Ambient, true, 0.18
	sound.Parent = game:GetService("SoundService")
	sound:Play()
end
-- Low-frequency cosmetic flicker, no remotes or per-frame raycasts.
task.spawn(function()
	while gui.Parent do
		task.wait(4 + math.random() * 5)
		local facility = workspace:FindFirstChild("Facility")
		if facility then
			for _, child in facility:GetChildren() do
				if child.Name == "Lamp" and math.random() < 0.12 then
					local light = child:FindFirstChildOfClass("PointLight")
					if light then light.Enabled = false; task.delay(0.15, function() if light.Parent then light.Enabled = true end end) end
				end
			end
		end
	end
end)
remotes:WaitForChild("Ready"):FireServer()
