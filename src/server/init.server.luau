local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Config = require(ReplicatedStorage.Shared.Config)
local Facility = require(script.Facility).build()
local Monster = require(script.MonsterService).new(Facility)
local Hiding = require(script.HidingService).new()
local studio = RunService:IsStudio()
Players.CharacterAutoLoads = false
Lighting.ClockTime, Lighting.Brightness = 0, 0.5
Lighting.Ambient, Lighting.OutdoorAmbient = Color3.fromRGB(35, 40, 48), Color3.fromRGB(8, 10, 14)
Lighting.GlobalShadows = true
Lighting.FogColor, Lighting.FogStart, Lighting.FogEnd = Color3.fromRGB(15, 15, 13), 32, 105

local remotes = Instance.new("Folder")
remotes.Name, remotes.Parent = "BlindspotRemotes", ReplicatedStorage
local function remote(name)
	local event = Instance.new("RemoteEvent")
	event.Name, event.Parent = name, remotes
	return event
end
local stateEvent, mapEvent, scanEvent, creatureEvent = remote("State"), remote("Map"), remote("Scan"), remote("Creature")
local readyEvent = remote("Ready")
local leaveClosetEvent = remote("LeaveCloset")
-- The debug remote does not even exist outside Studio. Every request is also gated below.
local debugEvent = if studio then remote("Debug") else nil
local roles, ready, lastRequest, reveal = {}, {}, {}, {}
local state, message, deadline, runner = "Waiting", "Waiting for three operators", 0, nil
local savedRunnerPosition = Facility.Start
local setupGeneration = 0
local soloRound, eligibleSince = false, nil
local mapRows = {}
for _, row in Facility.Rows do table.insert(mapRows, (row:gsub("[SM]", "."))) end
local beginRound, finish

local function root(player)
	return player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end
local function humanoid(player)
	return player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
end
local function runnerPosition()
	local r = root(runner)
	if r and roles[runner] == "Runner" then return r.Position end
	if studio and #Players:GetPlayers() == 1 then return savedRunnerPosition end
	return nil
end
local function completed()
	local count = 0
	for _, item in Facility.Objectives do if item.done then count += 1 end end
	return count
end
local function sendState(player)
	if not ready[player] then return end
	stateEvent:FireClient(player, { state = state, message = message, role = roles[player] or "Observer", completed = completed(), studio = studio, paused = Monster.paused, reveal = studio and reveal[player] == true, hiding = Hiding:get(player) ~= nil })
end
local function broadcast()
	for _, player in Players:GetPlayers() do sendState(player) end
end
local function transition(nextState, text)
	state, message = nextState, text
	broadcast()
end
local function teleport(player, position)
	if Hiding:leave(player, false) then sendState(player) end
	local r = root(player)
	if r then
		r.AssemblyLinearVelocity, r.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
		player.Character:PivotTo(CFrame.lookAt(position, position + Vector3.new(1, 0, 0)))
	end
end
local function place(player)
	local h = humanoid(player)
	if h then h.WalkSpeed, h.JumpPower, h.JumpHeight = Config.WalkSpeed, 0, 0 end
	teleport(player, if roles[player] == "Runner" then savedRunnerPosition else Facility.Control + Vector3.new(0, 0, 4))
end
local function setRole(player, role)
	local entry = Hiding:get(player)
	if entry then savedRunnerPosition = entry.closet.outside; Hiding:leave(player, true) end
	roles[player], reveal[player] = role, nil
	-- A single atomic state packet makes the client tear down its previous role UI/data.
	sendState(player)
	place(player)
end

finish = function(won, reason)
	if state ~= "Playing" then return end
	Hiding:reset()
	deadline = os.clock() + Config.ResultDuration
	transition(if won then "Won" else "Lost", reason)
end

beginRound = function()
	if state == "Setup" then return end
	setupGeneration += 1
	local generation = setupGeneration
	Hiding:reset()
	transition("Setup", "Establishing operator links…")
	Facility.reset()
	Monster:reset()
	savedRunnerPosition = Facility.Start
	local list = Players:GetPlayers()
	soloRound = studio and #list == 1
	table.sort(list, function(a, b) return a.UserId < b.UserId end)
	runner = list[1]
	for index, player in list do
		roles[player] = Config.Roles[index] or "Observer"
		reveal[player] = nil
	end
	for _, player in list do
		local ok, err = pcall(function() player:LoadCharacterAsync() end)
		if not ok then warn("Character load failed: ", err) end
		if generation ~= setupGeneration then return end
		place(player)
	end
	if generation ~= setupGeneration then return end
	local count = #Players:GetPlayers()
	if not root(runner) or not (#list >= 3 and count >= 3 or soloRound and count == 1) then
		transition("Waiting", "Waiting for three operators / character load")
		return
	end
	transition("Playing", "Restore three relays. Communicate. Survive.")
end

local function canInteract(player, position)
	local r, h = root(player), humanoid(player)
	if state ~= "Playing" or roles[player] ~= "Runner" or Hiding:get(player) or not r or not h or h.Health <= 0 then return false end
	if (r.Position - position).Magnitude > 9 then return false end
	local params = RaycastParams.new()
	params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Include, { Facility.Model }
	local delta = position - r.Position
	local hit = workspace:Raycast(r.Position, delta, params)
	return not hit or (hit.Position - position).Magnitude < 3
end
for _, objective in Facility.Objectives do
	objective.prompt.Triggered:Connect(function(player)
		if objective.done or not canInteract(player, objective.part.Position) then return end
		objective.done, objective.prompt.Enabled = true, false
		objective.part.Color = Color3.fromRGB(65, 205, 155)
		if completed() == 3 then
			Facility.Door.CanCollide, Facility.Door.Transparency = false, 0.7
			Facility.ExitPrompt.ObjectText = "EXIT • unlocked"
			message = "ALL RELAYS ONLINE • EXIT UNLOCKED"
		else message = "Relay restored • " .. completed() .. "/3 online" end
		broadcast()
	end)
end
Facility.ExitPrompt.Triggered:Connect(function(player)
	if completed() == 3 and canInteract(player, Facility.Door.Position) then finish(true, "TEAM EXTRACTED • signal secured") end
end)

for _, closet in Facility.Closets do
	closet.prompt.Triggered:Connect(function(player)
		if not canInteract(player, closet.door.Position) then return end
		local r = root(player)
		if (r.Position - closet.door.Position).Magnitude > 7 then return end
		-- Being seen entering is not an escape: the hostile checks the doorway.
		local exposed = (r.Position - Monster.position).Magnitude < 62 and Monster:clearSight(r.Position)
		if Hiding:enter(player, closet, exposed) then sendState(player) end
	end)
end

local function throttle(player, interval)
	local now = os.clock()
	if now - (lastRequest[player] or -100) < interval then return false end
	lastRequest[player] = now
	return true
end
readyEvent.OnServerEvent:Connect(function(player)
	if not throttle(player, 0.5) then return end
	ready[player] = true
	sendState(player)
end)
leaveClosetEvent.OnServerEvent:Connect(function(player)
	if not throttle(player, 0.25) then return end
	-- No client-provided target or position; can only exit your own server entry.
	if Hiding:leave(player, true) then sendState(player) end
end)
if debugEvent then
	debugEvent.OnServerEvent:Connect(function(player, action)
		if not RunService:IsStudio() or typeof(action) ~= "string" or not throttle(player, 0.2) then return end
		if action == "Reset Round" then
			if state ~= "Setup" then task.spawn(beginRound) end
		elseif action == "Spawn/Reset Monster" then Monster:reset()
		elseif action == "Pause Monster AI" then Monster.paused = true
		elseif action == "Resume Monster AI" then Monster.paused = false
		elseif action == "Reveal Map" then reveal[player] = not reveal[player]
		elseif action == "Teleport to Runner area" then teleport(player, savedRunnerPosition)
		elseif action == "Teleport to Control Room" then teleport(player, Facility.Control)
		elseif table.find(Config.Roles, action) and #Players:GetPlayers() == 1 and state == "Playing" then
			if roles[player] == "Runner" and root(player) and not Hiding:get(player) then savedRunnerPosition = root(player).Position end
			-- The solo Runner's last position remains the simulated target during station inspection.
			setRole(player, action)
		end
		broadcast()
	end)
end

local function joined(player)
	roles[player] = "Observer"
	player.CharacterAdded:Connect(function(character)
		local h = character:WaitForChild("Humanoid", 10)
		character:WaitForChild("HumanoidRootPart", 10)
		if not h then return end
		place(player)
		h.Died:Connect(function()
			Hiding:leave(player, false)
			if roles[player] == "Runner" then finish(false, "RUNNER LOST • connection terminated") end
		end)
	end)
	task.spawn(function()
		if state ~= "Setup" then player:LoadCharacterAsync() end
	end)
end
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player)
	Hiding:leave(player, false)
	local active = roles[player] and roles[player] ~= "Observer"
	roles[player], ready[player], lastRequest[player], reveal[player] = nil, nil, nil, nil
	if active then finish(false, "Operator disconnected • round aborted") end
end)
for _, player in Players:GetPlayers() do joined(player) end

local nextScan = 0
task.spawn(function()
	while true do
		task.wait(Config.Tick)
		local now, list = os.clock(), Players:GetPlayers()
		local enough = #list >= 3 or (studio and #list == 1)
		if state == "Waiting" then
			if enough then
				eligibleSince = eligibleSince or now
				if now - eligibleSince >= 3 then eligibleSince = nil; task.spawn(beginRound) end
			else eligibleSince = nil end
		end
		if state == "Playing" and soloRound and #list >= 3 then task.spawn(beginRound) end
		if (state == "Won" or state == "Lost") and now >= deadline then
			transition("Resetting", "Reinitializing facility…")
			if enough then task.spawn(beginRound) else transition("Waiting", "Waiting for three operators") end
		end
		local position = runnerPosition()
		if state == "Playing" and position then
			-- Freeze the simulated target while solo developer inspects a station.
			if runner and roles[runner] == "Runner" then
				local entry = Hiding:get(runner)
				savedRunnerPosition = if entry then entry.closet.outside else position
				if entry and (not entry.root.Parent or not entry.root.Anchored or (entry.root.Position - entry.closet.inside).Magnitude > 1.5) then
					Hiding:leave(runner, true)
					sendState(runner)
					entry = nil
				end
				local target = if entry and entry.exposed then entry.closet.outside else position
				if Monster:step(Config.Tick, target, now, entry ~= nil and not entry.exposed) then
					local h = humanoid(runner)
					if h then h.Health = 0 end
					finish(false, "RUNNER LOST • hostile contact")
				end
				if not entry and completed() == 3 and (position - Facility.Exit).Magnitude < 5 then finish(true, "TEAM EXTRACTED • signal secured") end
			end
		end
		for _, player in list do
			if not ready[player] then continue end
			local role = roles[player]
			if role == "Navigator" or (studio and reveal[player]) then
				local objectives = {}
				for id, item in Facility.Objectives do table.insert(objectives, { id = id, x = item.x, z = item.z, done = item.done }) end
				mapEvent:FireClient(player, { rows = mapRows, cell = Facility.Cell, runner = position, objectives = objectives, debug = role ~= "Navigator" })
			end
			if role == "Runner" then
				-- Render only to Runner; never replicate a monster model or coordinates globally.
				creatureEvent:FireClient(player, if state == "Playing" and position and (position - Monster.position).Magnitude < 75 then Monster.position else nil)
			end
			if role == "Tracker" and now >= nextScan then
				local packet = { available = state == "Playing" and position ~= nil }
				if packet.available then
					local delta = Monster.position - position
					packet.distance = math.floor(delta.Magnitude / 5 + 0.5) * 5
					packet.bearing = math.floor((math.deg(math.atan2(delta.X, -delta.Z)) % 360) / 15 + 0.5) * 15 % 360
					local r = root(runner)
					local forward = if r and roles[runner] == "Runner" then r.CFrame.LookVector else Vector3.new(0, 0, -1)
					packet.relative = (packet.bearing - math.deg(math.atan2(forward.X, -forward.Z))) % 360
					packet.danger = delta.Magnitude < 25
				end
				scanEvent:FireClient(player, packet)
			end
		end
		if now >= nextScan then nextScan = now + Config.ScanInterval end
	end
end)
print("BLINDSPOT server ready; Studio debug:", studio)
