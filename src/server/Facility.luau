local Facility = {}
-- Server-only fixed layout. # = wall; all other cells are walkable.
Facility.Rows = {
	"###############",
	"#S....#......E#",
	"#.###.#.#####.#",
	"#...#...#.....#",
	"###.#####.###.#",
	"#...#A....#...#",
	"#.###.#####.#.#",
	"#.....#B....#.#",
	"#.#####.#####.#",
	"#...#.....#...#",
	"###.#.###.#.#.#",
	"#C....#.....#M#",
	"###############",
}
Facility.Cell = 14
Facility.Control = Vector3.new(-90, 4, 20)

function Facility.position(x, z)
	return Vector3.new((x - 1) * Facility.Cell, 3, (z - 1) * Facility.Cell)
end

local function part(parent, name, size, position, color)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Position = name, size, position
	p.Anchored = true
	p.Material = Enum.Material.Metal
	p.Color = color or Color3.fromRGB(45, 49, 53)
	p.Parent = parent
	return p
end

function Facility.build()
	local model = Instance.new("Model")
	model.Name = "Facility"
	model.Parent = workspace
	Facility.Model, Facility.Objectives, Facility.Patrol = model, {}, {}
	local width, depth = #Facility.Rows[1] * 14, #Facility.Rows * 14
	local center = Vector3.new((width - 14) / 2, -1, (depth - 14) / 2)
	local floor = part(model, "Floor", Vector3.new(width, 2, depth), center, Color3.fromRGB(39, 38, 35))
	floor.Material = Enum.Material.DiamondPlate
	part(model, "Ceiling", Vector3.new(width, 1, depth), center + Vector3.new(0, 14, 0))
	for z, row in Facility.Rows do
		local x = 1
		while x <= #row do
			local symbol = row:sub(x, x)
			if symbol == "#" then
				local first = x
				while x <= #row and row:sub(x, x) == "#" do x += 1 end
				local wall = part(model, "Wall", Vector3.new((x - first) * 14, 13, 14), Facility.position((first + x - 1) / 2, z) + Vector3.new(0, 3.5, 0), Color3.fromRGB(57, 55, 49))
				wall.Material = Enum.Material.Concrete
			else
				local position = Facility.position(x, z)
				table.insert(Facility.Patrol, position)
				if symbol == "S" then Facility.Start = position end
				if symbol == "M" then Facility.MonsterStart = position end
				if symbol:match("[ABC]") then
					local terminal = part(model, "Terminal_" .. symbol, Vector3.new(3, 4, 2), position, Color3.fromRGB(170, 112, 35))
					local prompt = Instance.new("ProximityPrompt")
					prompt.ActionText, prompt.ObjectText = "Restore power", "Relay " .. symbol
					prompt.HoldDuration, prompt.MaxActivationDistance = 1.2, 8
					prompt.Parent = terminal
					Facility.Objectives[symbol] = { part = terminal, prompt = prompt, done = false, x = x, z = z }
				end
				if symbol == "E" then
					Facility.Exit = position
					Facility.Door = part(model, "ExitDoor", Vector3.new(10, 10, 1), position + Vector3.new(0, 2, -5), Color3.fromRGB(140, 45, 35))
					local prompt = Instance.new("ProximityPrompt")
					prompt.ActionText, prompt.ObjectText = "Evacuate", "EXIT • restore 3 relays"
					prompt.MaxActivationDistance = 8
					prompt.Parent = Facility.Door
					Facility.ExitPrompt = prompt
				end
				if (x + z) % 5 == 0 then
					local lamp = part(model, "Lamp", Vector3.new(3.5, 0.25, 0.7), position + Vector3.new(0, 7.6, 0), Color3.fromRGB(156, 137, 98))
					lamp.Material = Enum.Material.Neon
					local light = Instance.new("PointLight")
					light.Brightness, light.Range, light.Shadows = 0.35, 24, true
					light.Color = lamp.Color
					light.Parent = lamp
					local horizontal = row:sub(x - 1, x - 1) ~= "#" and row:sub(x + 1, x + 1) ~= "#"
					local beamSize = if horizontal then Vector3.new(0.6, 0.8, 13.5) else Vector3.new(13.5, 0.8, 0.6)
					part(model, "SupportBeam", beamSize, position + Vector3.new(0, 8.2, 0), Color3.fromRGB(43, 36, 29))
					for _, side in { -1, 1 } do
						local offset = if horizontal then Vector3.new(0, 2.8, side * 6.45) else Vector3.new(side * 6.45, 2.8, 0)
						part(model, "Support", Vector3.new(0.55, 11.6, 0.55), position + offset, Color3.fromRGB(43, 36, 29))
					end
					local pipeSize = if horizontal then Vector3.new(14, 0.45, 0.45) else Vector3.new(0.45, 0.45, 14)
					local pipeOffset = if horizontal then Vector3.new(0, 7, 5.8) else Vector3.new(5.8, 7, 0)
					part(model, "RustConduit", pipeSize, position + pipeOffset, Color3.fromRGB(77, 51, 35))
				end
				x += 1
			end
		end
	end
	local c = Facility.Control
	part(model, "ControlFloor", Vector3.new(42, 2, 34), c + Vector3.new(0, -5, 0))
	part(model, "ControlRoof", Vector3.new(42, 1, 34), c + Vector3.new(0, 12, 0))
	for _, offset in { Vector3.new(-21, 3, 0), Vector3.new(21, 3, 0) } do
		part(model, "ControlWall", Vector3.new(1, 18, 34), c + offset)
	end
	for _, offset in { Vector3.new(0, 3, -17), Vector3.new(0, 3, 17) } do
		part(model, "ControlWall", Vector3.new(42, 18, 1), c + offset)
	end
	for i, name in { "NAVIGATION", "TRACKING" } do
		local desk = part(model, name, Vector3.new(12, 4, 4), c + Vector3.new((i - 1.5) * 20, -1, -11))
		local gui = Instance.new("BillboardGui")
		gui.Size, gui.StudsOffset = UDim2.fromOffset(180, 40), Vector3.new(0, 4, 0)
		gui.Parent = desk
		local label = Instance.new("TextLabel")
		label.Size, label.BackgroundTransparency, label.Text = UDim2.fromScale(1, 1), 1, name
		label.TextColor3, label.TextSize = Color3.fromRGB(173, 170, 152), 14
		label.Parent = gui
		local light = Instance.new("PointLight")
		light.Range, light.Brightness, light.Parent = 35, 1, desk
	end
	return Facility
end

function Facility.reset()
	for _, objective in Facility.Objectives do
		objective.done, objective.prompt.Enabled = false, true
		objective.part.Color = Color3.fromRGB(170, 112, 35)
	end
	Facility.Door.CanCollide, Facility.Door.Transparency = true, 0
	Facility.ExitPrompt.ObjectText = "EXIT • restore 3 relays"
end

return Facility
