-- CXRSXD DUELS ❤️ - free duels by cxrsxd
-- Version finale : float corrigé + stable, UI animation intacte, auto steal permanent

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Waypoints
local rightWaypoints = {
	Vector3.new(-473.04, -6.99, 29.71),
	Vector3.new(-483.57, -5.10, 18.74),
	Vector3.new(-475.00, -6.99, 26.43),
	Vector3.new(-474.67, -6.94, 105.48),
}

local leftWaypoints = {
	Vector3.new(-472.49, -7.00, 90.62),
	Vector3.new(-484.62, -5.10, 100.37),
	Vector3.new(-475.08, -7.00, 93.29),
	Vector3.new(-474.22, -6.96, 16.18),
}

-- Variables globales
local patrolMode = "none"
local floating = false
local currentWaypoint = 1
local waitingForCountdownLeft = false
local waitingForCountdownRight = false
local AUTO_START_DELAY = 0.7

local heartbeatConn
local rightBtn, leftBtn, floatBtn

-- Utilitaires countdown
local function isCountdownNumber(text)
	local num = tonumber(text)
	return num and num >= 1 and num <= 5, num
end

local function isTimerInCountdown(label)
	if not label then return false end
	return (isCountdownNumber(label.Text))
end

local function getCurrentSpeed()
	if patrolMode == "none" then return 0 end
	return currentWaypoint >= 3 and 29.4 or 60
end

local function getCurrentWaypoints()
	if patrolMode == "right" then return rightWaypoints end
	if patrolMode == "left" then return leftWaypoints end
	return {}
end

local function startMovement(mode)
	patrolMode = mode
	currentWaypoint = 1
	if mode == "right" then
		rightBtn.Text = "STOP Right"
		TweenService:Create(rightBtn, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(120, 40, 40)}):Play()
	else
		leftBtn.Text = "STOP Left"
		TweenService:Create(leftBtn, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(120, 40, 40)}):Play()
	end
end

-- Auto steal permanent
local stealCooldown = 0.18
local HOLD_DURATION = 0.45

local function getHRP()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function findNearestStealPrompt(hrp)
	if not hrp then return nil end
	local plots = workspace:FindFirstChild("Plots")
	if not plots then return nil end

	local nearest, minDist = nil, 40
	for _, obj in ipairs(plots:GetDescendants()) do
		if obj:IsA("ProximityPrompt") and obj.Enabled and obj.ActionText == "Steal" then
			local part = obj.Parent
			if part:IsA("BasePart") or (part:IsA("Model") and part.PrimaryPart) then
				part = part:IsA("BasePart") and part or part.PrimaryPart
				local dist = (hrp.Position - part.Position).Magnitude
				if dist < minDist then
					minDist = dist
					nearest = obj
				end
			end
		end
	end
	return nearest
end

local function triggerPrompt(prompt)
	if not prompt or not prompt.Parent then return end
	prompt.MaxActivationDistance = 9999
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	pcall(function()
		fireproximityprompt(prompt, 9999, HOLD_DURATION)
	end)
end

task.spawn(function()
	while true do
		task.wait(stealCooldown)
		local hrp = getHRP()
		if hrp then
			local prompt = findNearestStealPrompt(hrp)
			if prompt then
				triggerPrompt(prompt)
			end
		end
	end
end)

-- Update walking → float amélioré + stable
local function updateWalking()
	local char = player.Character
	if not char then return end

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local vel = root.AssemblyLinearVelocity

	-- Float logic
	if floating then
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = {char}
		params.FilterType = Enum.RaycastFilterType.Blacklist
		params.IgnoreWater = true

		local rayOrigin = root.Position + Vector3.new(0, 3, 0)
		local rayDir = Vector3.new(0, -70, 0)
		local result = workspace:Raycast(rayOrigin, rayDir, params)

		if result then
			local targetY = result.Position.Y + 7.5
			local yDiff = targetY - root.Position.Y
			local targetVY = yDiff * 16
			targetVY = math.clamp(targetVY, -30, 50)

			root.AssemblyLinearVelocity = Vector3.new(
				vel.X,
				targetVY,
				vel.Z
			)
		else
			-- Pas de sol → descente contrôlée
			root.AssemblyLinearVelocity = Vector3.new(vel.X, math.max(vel.Y - 20, -45), vel.Z)
		end
	else
		-- Reset Y quand float désactivé
		if math.abs(vel.Y) > 2 then
			root.AssemblyLinearVelocity = Vector3.new(vel.X, vel.Y * 0.6, vel.Z)
		end
	end

	-- Patrol logic
	if patrolMode ~= "none" then
		local waypoints = getCurrentWaypoints()
		if #waypoints == 0 then return end

		local target = waypoints[currentWaypoint]
		local distXZ = (Vector3.new(target.X, 0, target.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude

		if distXZ > 3.2 then
			local dir = (Vector3.new(target.X, 0, target.Z) - root.Position).Unit
			local speed = getCurrentSpeed()
			root.AssemblyLinearVelocity = Vector3.new(
				dir.X * speed,
				vel.Y,  -- on garde la composante Y du float
				dir.Z * speed
			)
		else
			if currentWaypoint >= #waypoints then
				patrolMode = "none"
				waitingForCountdownLeft = false
				waitingForCountdownRight = false
				rightBtn.Text = "AutoRight"
				leftBtn.Text = "AutoLeft"
				TweenService:Create(rightBtn, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(50, 120, 220)}):Play()
				TweenService:Create(leftBtn, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(50, 120, 220)}):Play()
				root.AssemblyLinearVelocity = Vector3.new(0, vel.Y, 0)
			else
				currentWaypoint += 1
			end
		end
	end
end

-- UI
local sg = Instance.new("ScreenGui")
sg.Name = "CXRSXDDuels"
sg.ResetOnSpawn = false
sg.Parent = playerGui

-- Launcher CD
local launcher = Instance.new("Frame")
launcher.Size = UDim2.new(0, 58, 0, 58)
launcher.Position = UDim2.new(1, -80, 0, 25)
launcher.BackgroundColor3 = Color3.fromRGB(20, 140, 255)
launcher.BorderSizePixel = 0
launcher.Active = true
launcher.Draggable = true
launcher.Parent = sg

local lc = Instance.new("UICorner")
lc.CornerRadius = UDim.new(1)
lc.Parent = launcher

local ls = Instance.new("UIStroke")
ls.Color = Color3.fromRGB(100, 200, 255)
ls.Thickness = 2.5
ls.Parent = launcher

local lt = Instance.new("TextLabel")
lt.Size = UDim2.new(1,0,1,0)
lt.BackgroundTransparency = 1
lt.Text = "CD"
lt.TextColor3 = Color3.new(1,1,1)
lt.Font = Enum.Font.GothamBlack
lt.TextSize = 32
lt.Parent = launcher

-- Main frame
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 260, 0, 210)
main.Position = UDim2.new(0.5, -130, 0.5, -120)
main.BackgroundTransparency = 0.2
main.BackgroundColor3 = Color3.fromRGB(15, 25, 50)
main.BorderSizePixel = 0
main.Visible = false
main.Active = true
main.Draggable = true
main.Parent = sg

local mc = Instance.new("UICorner")
mc.CornerRadius = UDim.new(0, 16)
mc.Parent = main

local mg = Instance.new("UIGradient")
mg.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 190, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 100, 220))
}
mg.Rotation = 135
mg.Parent = main

local ms = Instance.new("UIStroke")
ms.Color = Color3.fromRGB(140, 210, 255)
ms.Thickness = 1.8
ms.Transparency = 0.3
ms.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,40)
title.BackgroundTransparency = 1
title.Text = "CXRSXD DUELS ❤️"
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamBlack
title.TextSize = 20
title.Parent = main

local cred = Instance.new("TextLabel")
cred.Size = UDim2.new(1,0,0,18)
cred.Position = UDim2.new(0,0,1,-24)
cred.BackgroundTransparency = 1
cred.Text = "free duels by cxrsxd"
cred.TextColor3 = Color3.fromRGB(180, 220, 255)
cred.Font = Enum.Font.Gotham
cred.TextSize = 12
cred.Parent = main

-- Bouton factory
local function createButton(text, y, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.88, 0, 0, 42)
	btn.Position = UDim2.new(0.06, 0, 0, y)
	btn.BackgroundColor3 = Color3.fromRGB(50, 120, 220)
	btn.Text = text
	btn.TextColor3 = Color3.new(1,1,1)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 15
	btn.BorderSizePixel = 0
	btn.Parent = main

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = btn

	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(70, 140, 240)}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(50, 120, 220)}):Play()
	end)

	btn.MouseButton1Click:Connect(callback)
	return btn
end

rightBtn = createButton("AutoRight", 50, function()
	if patrolMode == "right" or waitingForCountdownRight then
		patrolMode = "none"
		currentWaypoint = 1
		waitingForCountdownRight = false
		rightBtn.Text = "AutoRight"
		TweenService:Create(rightBtn, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(50,120,220)}):Play()
		local hrp = getHRP()
		if hrp then hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0) end
	else
		local label
		pcall(function()
			label = playerGui.DuelsMachineTopFrame.DuelsMachineTopFrame.Timer.Label
		end)
		if label and isTimerInCountdown(label) then
			waitingForCountdownRight = true
			rightBtn.Text = "Waiting..."
			TweenService:Create(rightBtn, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(255,200,60)}):Play()
		else
			startMovement("right")
		end
	end
end)

leftBtn = createButton("AutoLeft", 105, function()
	if patrolMode == "left" or waitingForCountdownLeft then
		patrolMode = "none"
		currentWaypoint = 1
		waitingForCountdownLeft = false
		leftBtn.Text = "AutoLeft"
		TweenService:Create(leftBtn, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(50,120,220)}):Play()
		local hrp = getHRP()
		if hrp then hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0) end
	else
		local label
		pcall(function()
			label = playerGui.DuelsMachineTopFrame.DuelsMachineTopFrame.Timer.Label
		end)
		if label and isTimerInCountdown(label) then
			waitingForCountdownLeft = true
			leftBtn.Text = "Waiting..."
			TweenService:Create(leftBtn, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(255,200,60)}):Play()
		else
			startMovement("left")
		end
	end
end)

floatBtn = createButton("Float OFF", 160, function()
	floating = not floating
	floatBtn.Text = floating and "Float ON" or "Float OFF"
	TweenService:Create(floatBtn, TweenInfo.new(0.25), {
		BackgroundColor3 = floating and Color3.fromRGB(40,180,100) or Color3.fromRGB(50,120,220)
	}):Play()
end)

-- Animation toggle UI (inchangée)
local function toggleUI()
	if main.Visible then
		TweenService:Create(main, TweenInfo.new(0.36, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Size = UDim2.new(0,0,0,0),
			Position = UDim2.new(0.5,0,0.5,0),
			BackgroundTransparency = 1
		}):Play()
		task.delay(0.38, function() main.Visible = false end)
	else
		main.Size = UDim2.new(0,0,0,0)
		main.Position = UDim2.new(0.5,0,0.5,0)
		main.BackgroundTransparency = 1
		main.Visible = true
		TweenService:Create(main, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(0,260,0,210),
			Position = UDim2.new(0.5,-130,0.5,-120),
			BackgroundTransparency = 0.2
		}):Play()
	end
end

launcher.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		toggleUI()
	end
end)

-- Connexions
heartbeatConn = RunService.Heartbeat:Connect(updateWalking)

player.CharacterAdded:Connect(function()
	task.wait(1)
	patrolMode = "none"
	currentWaypoint = 1
	waitingForCountdownLeft = false
	waitingForCountdownRight = false
	floating = false
	rightBtn.Text = "AutoRight"
	leftBtn.Text = "AutoLeft"
	floatBtn.Text = "Float OFF"
	TweenService:Create(rightBtn, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(50,120,220)}):Play()
	TweenService:Create(leftBtn, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(50,120,220)}):Play()
	TweenService:Create(floatBtn, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(50,120,220)}):Play()
end)

-- Détection timer countdown
task.spawn(function()
	local label
	local success = pcall(function()
		local top = playerGui:WaitForChild("DuelsMachineTopFrame", 12)
		local inner = top:WaitForChild("DuelsMachineTopFrame", 8)
		local timer = inner:WaitForChild("Timer", 8)
		label = timer:WaitForChild("Label", 8)
	end)

	if success and label then
		label:GetPropertyChangedSignal("Text"):Connect(function()
			local ok, num = isCountdownNumber(label.Text)
			if ok and num == 1 then
				task.wait(AUTO_START_DELAY)
				if waitingForCountdownRight then
					waitingForCountdownRight = false
					startMovement("right")
				end
				if waitingForCountdownLeft then
					waitingForCountdownLeft = false
					startMovement("left")
				end
			end
		end)
	end
end)

print("CXRSXD DUELS ❤️ - fully fixed version loaded")
print("Float should now work smoothly | Auto steal always running")
