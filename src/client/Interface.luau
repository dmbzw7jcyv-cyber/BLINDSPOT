local UI = {}
local green = Color3.fromRGB(178, 177, 166)
function UI.label(parent, text, position, size, textSize)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position, label.Size = position, size
	label.Text, label.TextColor3, label.TextSize = text, green, textSize or 16
	label.Font = Enum.Font.Code
	label.TextWrapped = true
	label.Parent = parent
	return label
end
function UI.frame(parent, position, size, color)
	local frame = Instance.new("Frame")
	frame.Position, frame.Size = position, size
	frame.BackgroundColor3, frame.BorderSizePixel = color or Color3.fromRGB(15, 16, 16), 0
	frame.Parent = parent
	return frame
end
function UI.button(parent, text, y, callback)
	local button = Instance.new("TextButton")
	button.Position, button.Size = UDim2.fromOffset(8, y), UDim2.new(1, -16, 0, 26)
	button.BackgroundColor3, button.TextColor3 = Color3.fromRGB(32, 33, 32), green
	button.Font, button.TextSize, button.Text = Enum.Font.Code, 13, text
	button.Parent = parent
	button.Activated:Connect(callback)
	return button
end
function UI.station(parent, title)
	local panel = UI.frame(parent, UDim2.fromScale(0.5, 0.52), UDim2.fromScale(0.62, 0.76))
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(850, 740)
	constraint.Parent = panel
	local titleLabel = UI.label(panel, title, UDim2.fromScale(0.04, 0.01), UDim2.fromScale(0.92, 0.08), 15)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	return panel
end
function UI.map(parent)
	local panel = UI.station(parent, "NAVIGATION // FACILITY 01")
	local canvas = UI.frame(panel, UDim2.fromScale(0.5, 0.49), UDim2.fromScale(0.94, 0.74))
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = canvas
	UI.label(panel, "N ↑   • YOU GUIDE THE RUNNER\nAmber: relay / Green: online / E: exit / H: closet", UDim2.fromScale(0.03, 0.88), UDim2.fromScale(0.94, 0.1), 12)
	local marker, cells, built = nil, {}, false
	return panel, function(packet)
		local rows, width, height = packet.rows, #packet.rows[1], #packet.rows
		aspect.AspectRatio = width / height
		if not built then
			built = true
			for z, row in rows do
				for x = 1, #row do
					local symbol = row:sub(x, x)
					local cell = UI.frame(canvas, UDim2.fromScale((x - 1) / width, (z - 1) / height), UDim2.new(1 / width, -1, 1 / height, -1), if symbol == "#" then Color3.fromRGB(57, 59, 56) else Color3.fromRGB(22, 24, 23))
					if symbol:match("[ABCEH]") then
						cells[symbol] = UI.label(cell, symbol, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 14)
					end
				end
			end
			marker = UI.frame(canvas, UDim2.fromScale(0, 0), UDim2.fromOffset(7, 7), Color3.fromRGB(215, 211, 194))
			marker.AnchorPoint = Vector2.new(0.5, 0.5)
		end
		for _, objective in packet.objectives do
			cells[objective.id].TextColor3 = if objective.done then Color3.fromRGB(136, 154, 126) else Color3.fromRGB(183, 145, 87)
		end
		marker.Visible = packet.runner ~= nil
		if packet.runner then marker.Position = UDim2.fromScale((packet.runner.X / packet.cell + 0.5) / width, (packet.runner.Z / packet.cell + 0.5) / height) end
	end
end
function UI.radar(parent)
	local panel = UI.station(parent, "TRACKING // SONAR LINK")
	local scope = UI.frame(panel, UDim2.fromScale(0.5, 0.46), UDim2.fromScale(0.68, 0.68))
	scope.AnchorPoint = Vector2.new(0.5, 0.5)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio, aspect.Parent = 1, scope
	for _, scale in { 1, 0.66, 0.33 } do
		local ring = UI.frame(scope, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(scale, scale))
		ring.AnchorPoint, ring.BackgroundTransparency = Vector2.new(0.5, 0.5), 1
		local corner = Instance.new("UICorner")
		corner.CornerRadius, corner.Parent = UDim.new(1, 0), ring
		local stroke = Instance.new("UIStroke")
		stroke.Color, stroke.Transparency, stroke.Parent = green, 0.7, ring
	end
	UI.label(scope, "N", UDim2.fromScale(0.45, 0), UDim2.fromScale(0.1, 0.08))
	UI.label(scope, "+", UDim2.fromScale(0.45, 0.45), UDim2.fromScale(0.1, 0.1), 22)
	local dot = UI.frame(scope, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(8, 8), Color3.fromRGB(175, 91, 72))
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	local readout = UI.label(panel, "Awaiting scan…", UDim2.fromScale(0.03, 0.82), UDim2.fromScale(0.94, 0.16), 16)
	local pulse = UI.frame(scope, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0, 0))
	pulse.AnchorPoint, pulse.BackgroundTransparency = Vector2.new(0.5, 0.5), 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(1, 0), pulse
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Parent = green, pulse
	local TweenService = game:GetService("TweenService")
	return panel, function(packet)
		dot.Visible = packet.available
		if not packet.available then readout.Text = "NO ACTIVE RUNNER SIGNAL"; return end
		local angle, radius = math.rad(packet.bearing), math.min(packet.distance / 180, 1) * 0.46
		dot.Position = UDim2.fromScale(0.5 + math.sin(angle) * radius, 0.5 - math.cos(angle) * radius)
		local direction = ({ "N", "NE", "E", "SE", "S", "SW", "W", "NW" })[math.floor((packet.bearing + 22.5) / 45) % 8 + 1]
		readout.Text = string.format("%s  ~%d studs %s (%03d°)\nRelative to facing: %03d° clockwise\n1 sec scans • no wall / route data", if packet.danger then "DANGER" else "CONTACT", packet.distance, direction, packet.bearing, packet.relative)
		readout.TextColor3 = if packet.danger then Color3.fromRGB(255, 100, 83) else green
		pulse.Size, stroke.Transparency = UDim2.fromScale(0, 0), 0
		TweenService:Create(pulse, TweenInfo.new(0.9), { Size = UDim2.fromScale(1, 1) }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.9), { Transparency = 1 }):Play()
	end
end
return UI
