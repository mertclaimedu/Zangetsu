local Players, Lighting, UserInputService, RunService = game:GetService("Players"), game:GetService("Lighting"), game:GetService("UserInputService"), game:GetService("RunService")
local Stats = game:GetService("Stats")
local player, camera = Players.LocalPlayer, workspace.CurrentCamera
local character, rootPart, humanoid
local originalSettings = {MaxZoom = player.CameraMaxZoomDistance, FOV = camera.FieldOfView, ClockTime = Lighting.ClockTime, Materials = {}, Transparency = {}}
local colorCorrection = Lighting:FindFirstChild("CustomColorCorrection") or Instance.new("ColorCorrectionEffect", Lighting) colorCorrection.Name = "CustomColorCorrection"
local defaultAnimations = {}
local animationSpeedMultiplier = 1
local originalAnimationSpeed = 1
local aimlockActive, espActive, wallhackActive, lowTextureActive = false, false, false, false
local silentAimActive, predictionActive = false, false
local aimlockToggleMode, aimlockLocked = false, false
local espHighlights, espNames = {}, {}
local keybinds = {
	Menu = {Type = "Keyboard", Value = Enum.KeyCode.G},
	Aimlock = {Type = "Keyboard", Value = Enum.KeyCode.Q},
	ESP = {Type = "Keyboard", Value = Enum.KeyCode.J},
	ClickTeleport = {Type = "Keyboard", Value = Enum.KeyCode.E},
	Fly = nil,
	FreeCam = {Type = "Keyboard", Value = Enum.KeyCode.P},
	Speed = nil
}
local aimlockFOV, showFOVCone, fovCone = 150, false, nil
local speedValue, flySpeedValue, freeCamSpeed = 300, 300, 200
local speedActive, flyActive, freeCamActive, noclipActive, clickTeleportActive = false, false, false, false, false
local freeCamPosition, freeCamYaw, freeCamPitch, freeCamSensitivity, freeCamBoost = nil, 0, 0, 0.01, 1
local lockedTarget, targetedPlayer
local aimlockTargetPart = "Head"
local menuTransparency = 0.1
local timeLocked = false
local bodyVelocity, bodyGyro
local colors = {
	Background = Color3.fromRGB(0, 0, 0),
	Header = Color3.fromRGB(49, 49, 49),
	Text = Color3.fromRGB(255, 255, 255),
	Button = Color3.fromRGB(49, 49, 49),
	Interface = Color3.fromRGB(69, 32, 106),
	ToggleOn = Color3.fromRGB(69, 32, 106),
	ToggleOff = Color3.fromRGB(49, 49, 49),
	Outline = Color3.fromRGB(40, 40, 40),
	ESP = Color3.fromRGB(75, 0, 130),
	KeybindsBG = Color3.fromRGB(49, 49, 49),
	TabSelected = Color3.fromRGB(60, 0, 120),
	TabUnselected = Color3.fromRGB(49, 49, 49)
}
local sliderValues = {}
local toggleStates = {}
local cachedPlayers = Players:GetPlayers()
local seenPlayers = {}
local httprequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
local loadAllToggle = false

-- Utility Functions
local function create(class, props) local inst = Instance.new(class) for k, v in pairs(props) do inst[k] = v end return inst end
local function getMovement(cf, vert)
	local dir = Vector3.new()
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
	if vert then
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.yAxis end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.yAxis end
	end
	return dir
end
local function clampPosition(pos)
	local b = 10000
	return Vector3.new(math.clamp(pos.X, -b, b), math.clamp(pos.Y, -b, b), math.clamp(pos.Z, -b, b))
end
local function notify(title, message, duration)
	game:GetService("StarterGui"):SetCore("SendNotification", {Title = title, Text = message, Duration = duration})
end
local function PlayAnim(id, time, speed)
	pcall(function()
		local hum = character.Humanoid
		for _, track in pairs(hum:GetPlayingAnimationTracks()) do track:Stop() end
		local Anim = Instance.new("Animation")
		Anim.AnimationId = "rbxassetid://" .. id
		local loadanim = hum:LoadAnimation(Anim)
		loadanim:Play()
		loadanim.TimePosition = time
		loadanim:AdjustSpeed(speed)
		loadanim.Stopped:Connect(function()
			for _, track in pairs(hum:GetPlayingAnimationTracks()) do track:Stop() end
		end)
	end)
end
local function StopAnim()
	for _, track in pairs(character.Humanoid:GetPlayingAnimationTracks()) do track:Stop() end
end

-- GUI Setup
local gui = create("ScreenGui", {Name = "Zangetsu", ResetOnSpawn = false, IgnoreGuiInset = true, Parent = player:WaitForChild("PlayerGui")})
local mainFrame = create("Frame", {Size = UDim2.new(0, 540, 0, 520), Position = UDim2.new(0.5, -270, 0.5, -260), BackgroundColor3 = colors.Background, BackgroundTransparency = menuTransparency, Visible = false, Parent = gui})
create("UICorner", {CornerRadius = UDim.new(0, 12), Parent = mainFrame})
create("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(20, 20, 40), Color3.fromRGB(50, 50, 80)), Rotation = 45, Parent = mainFrame})
local header = create("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = colors.Header, Parent = mainFrame})
create("UICorner", {CornerRadius = UDim.new(0, 12), Parent = header})
create("TextLabel", {Size = UDim2.new(0.7, 0, 0, 40), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = "Zangetsu", TextColor3 = colors.Text, TextSize = 28, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = header})

-- FPS, Ping, Player Counter
if not RunService:IsStudio() then
	local statsLabel = create("TextLabel", {Size = UDim2.new(0, 260, 0, 24), Position = UDim2.new(0.5, -130, 0, 8), BackgroundTransparency = 1, Text = "", TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, Parent = header})
	local frameCount, lastUpdate, fps = 0, tick(), 60
	RunService.RenderStepped:Connect(function()
		frameCount = frameCount + 1
		local now = tick()
		if now - lastUpdate >= 1 then
			fps = frameCount
			frameCount = 0
			lastUpdate = now
			local ping = math.floor((Stats.Network.ServerStatsItem["Data Ping"]:GetValue() or 0) + 0.5)
			local playerCount = #Players:GetPlayers()
			statsLabel.Text = string.format("FPS: %d  |  Ping: %dms  |  Players: %d", fps, ping, playerCount)
		end
	end)
end

-- Tab System
local tabFrame = create("Frame", {Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 40), BackgroundTransparency = 1, Parent = mainFrame})
local uiListLayout = create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 5), Parent = tabFrame})
local tabs, tabContents = {}, {}
local function addTab(name, width)
	local btn = create("TextButton", {Size = UDim2.new(0, width or 70, 0, 25), BackgroundColor3 = colors.TabUnselected, Text = name, TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, Parent = tabFrame})
	create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = btn})
	local cont = create("ScrollingFrame", {Size = UDim2.new(1, -18, 1, -70), Position = UDim2.new(0, 9, 0, 70), BackgroundTransparency = 1, ScrollBarThickness = 0, CanvasSize = UDim2.new(0, 0, 0, 0), Visible = false, Parent = mainFrame})
	tabs[name] = btn
	tabContents[name] = cont
	btn.MouseButton1Click:Connect(function()
		for tName, t in pairs(tabs) do t.BackgroundColor3 = tName == name and colors.TabSelected or colors.TabUnselected end
		for _, c in pairs(tabContents) do c.Visible = false end
		cont.Visible = true
	end)
	return cont
end

local visualsTab = addTab("Visuals", 70)
local playerTab = addTab("Player", 70)
local combatTab = addTab("Combat", 70)
local targetTab = addTab("Target", 70)
local animationsTab = addTab("Animations", 70)
local settingsTab = addTab("Settings", 70)
local keybindsFrame = create("Frame", {Size = UDim2.new(0, 200, 0, 520), Position = UDim2.new(1, 0, 0, 0), BackgroundColor3 = colors.KeybindsBG, BackgroundTransparency = menuTransparency, Visible = false, Parent = mainFrame})
create("UICorner", {CornerRadius = UDim.new(0, 12), Parent = keybindsFrame})
create("UIGradient", {Color = ColorSequence.new(colors.KeybindsBG, colors.Header), Rotation = 45, Parent = keybindsFrame})
local keybindsScroll = create("ScrollingFrame", {Size = UDim2.new(1, -10, 1, -10), Position = UDim2.new(0, 5, 0, 5), BackgroundTransparency = 1, ScrollBarThickness = 0, CanvasSize = UDim2.new(0, 0, 0, 400), Parent = keybindsFrame})
local function toggleKeybindsFrame() keybindsFrame.Visible = not keybindsFrame.Visible end
create("ImageButton", {Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(1, -68, 0, 8), BackgroundTransparency = 1, Image = "rbxassetid://6023565895", ImageColor3 = colors.Text, Parent = header}).MouseButton1Click:Connect(toggleKeybindsFrame)

-- Close Buttons
local closeBtn = create("TextLabel", {Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(1, -104, 0, 8), BackgroundTransparency = 1, Text = "-", TextColor3 = colors.Text, TextSize = 28, Font = Enum.Font.FredokaOne, Parent = header})
closeBtn.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then mainFrame.Visible = false end end)
local xBtn = create("ImageButton", {Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(1, -34, 0, 8), BackgroundTransparency = 1, Image = "rbxassetid://6031094678", ImageColor3 = Color3.fromRGB(220, 50, 50), Parent = header})
local confirmFrame = create("Frame", {Size = UDim2.new(0, 220, 0, 100), Position = UDim2.new(0.5, -110, 0.5, -50), BackgroundColor3 = colors.Header, Visible = false, Parent = gui})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = confirmFrame})
create("TextLabel", {Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, 10), BackgroundTransparency = 1, Text = "Are you sure u want to close?", TextColor3 = colors.Text, TextSize = 18, Font = Enum.Font.FredokaOne, Parent = confirmFrame})
local yesBtn = create("TextButton", {Size = UDim2.new(0, 80, 0, 30), Position = UDim2.new(0, 20, 0, 55), BackgroundColor3 = Color3.fromRGB(200, 50, 50), Text = "Yes", TextColor3 = colors.Text, Parent = confirmFrame})
local noBtn = create("TextButton", {Size = UDim2.new(0, 80, 0, 30), Position = UDim2.new(0, 120, 0, 55), BackgroundColor3 = Color3.fromRGB(50, 200, 50), Text = "No", TextColor3 = colors.Text, Parent = confirmFrame})
local function cleanupMenu()
	if gui then gui:Destroy() end
	keybinds = {}
	espActive = false
	wallhackActive = false
	for p in pairs(espHighlights) do if espHighlights[p] then espHighlights[p]:Destroy() end end
	for p in pairs(espNames) do if espNames[p] then espNames[p]:Destroy() end end
end
yesBtn.MouseButton1Click:Connect(function() confirmFrame.Visible = false cleanupMenu() end)
noBtn.MouseButton1Click:Connect(function() confirmFrame.Visible = false end)
xBtn.MouseButton1Click:Connect(function() confirmFrame.Visible = true for name, upd in pairs(toggleCallbacks) do for _, cb in pairs(upd) do cb(false) end end end)

-- UI Element Functions
local toggleCallbacks = {}
local function addToggle(name, def, y, cb, parent)
	toggleStates[name] = def
	local f = create("Frame", {Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, y), BackgroundTransparency = 1, Parent = parent})
	create("TextLabel", {Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.new(0, 5, 0, 0), BackgroundTransparency = 1, Text = name, TextColor3 = colors.Text, TextSize = 16, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = f})
	local tf = create("Frame", {Size = UDim2.new(0, 50, 0, 20), Position = UDim2.new(1, -60, 0.5, -10), BackgroundColor3 = def and colors.ToggleOn or colors.ToggleOff, Parent = f})
	create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = tf})
	toggleCallbacks[name] = toggleCallbacks[name] or {}
	table.insert(toggleCallbacks[name], function(s)
		toggleStates[name] = s
		tf.BackgroundColor3 = s and colors.ToggleOn or colors.ToggleOff
		if name == "Speed" and s then for _, c in pairs(toggleCallbacks["Fly"] or {}) do c(false) end end
		if name == "Fly" and s then for _, c in pairs(toggleCallbacks["Speed"] or {}) do c(false) end end
		cb(s)
	end)
	local function upd(s) for _, c in pairs(toggleCallbacks[name]) do c(s) end end
	tf.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then upd(not toggleStates[name]) end end)
	return f, upd
end
local sliderCallbacks = {}
local function addSlider(name, min, max, def, y, cb, parent, nl, nd)
	sliderValues[name] = def
	local f = create("Frame", {Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, y), BackgroundTransparency = 1, Parent = parent})
	local l = nl and nil or create("TextLabel", {Size = UDim2.new(0, 220, 1, 0), Position = UDim2.new(0, 5, 0, 0), BackgroundTransparency = 1, Text = nd and string.format("%s: %d", name, def) or string.format("%s: %.1f", name, def), TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = f})
	local sf = create("Frame", {Size = nl and UDim2.new(0.95, 20, 0, 12) or UDim2.new(0, 320, 0, 12), Position = nl and UDim2.new(0.025, -20, 0.5, -6) or UDim2.new(0, 190, 0.5, -6), BackgroundColor3 = colors.Button, Parent = f})
	create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = sf})
	local fill = create("Frame", {Size = UDim2.new((def - min) / (max - min), 0, 1, 0), BackgroundColor3 = colors.Interface, Parent = sf})
	create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = fill})
	sliderCallbacks[name] = sliderCallbacks[name] or {}
	table.insert(sliderCallbacks[name], function(v)
		sliderValues[name] = v
		fill.Size = UDim2.new((v - min) / (max - min), 0, 1, 0)
		if l then l.Text = nd and string.format("%s: %d", name, math.floor(v)) or string.format("%s: %.1f", name, v) end
		cb(v)
	end)
	local d = false
	sf.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then d = true end end)
	UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then d = false end end)
	UserInputService.InputChanged:Connect(function(i)
		if d and i.UserInputType == Enum.UserInputType.MouseMovement then
			local p = math.clamp((i.Position.X - sf.AbsolutePosition.X) / sf.AbsoluteSize.X, 0, 1)
			local v = min + (max - min) * p
			for _, c in pairs(sliderCallbacks[name]) do c(v) end
		end
	end)
	return f
end
local buttonCallbacks = {}
local function addButton(name, x, y, cb, parent, ts, w)
	local b = create("TextButton", {Size = UDim2.new(0, w or 120, 0, 25), Position = UDim2.new(0, x, 0, y), BackgroundColor3 = ts and colors.ToggleOn or colors.ToggleOff, Text = name, TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, Parent = parent})
	create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = b})
	local s = ts or false
	buttonCallbacks[name] = buttonCallbacks[name] or {}
	table.insert(buttonCallbacks[name], function(state)
		s = state
		b.BackgroundColor3 = s and colors.ToggleOn or colors.ToggleOff
		b.Text = s and name:gsub("(.+)", "Un%1") or name:gsub("Un(.+)", "%1")
		cb(s)
	end)
	local function upd(ns) for _, c in pairs(buttonCallbacks[name]) do c(ns) end end
	b.MouseButton1Click:Connect(function() upd(not s) end)
	return b, upd
end
local function addActionButton(name, x, y, cb, parent, w)
	local b = create("TextButton", {Size = UDim2.new(0, w or 80, 0, 25), Position = UDim2.new(0, x, 0, y), BackgroundColor3 = colors.Button, Text = name, TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, Parent = parent})
	create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = b})
	b.MouseButton1Click:Connect(cb)
	return b
end
local function addKeybind(name, def, y)
	local f = create("Frame", {Size = UDim2.new(1, -10, 0, 30), Position = UDim2.new(0, 5, 0, y), BackgroundTransparency = 1, Parent = keybindsScroll})
	create("TextLabel", {Size = UDim2.new(0.6, 0, 1, 0), BackgroundTransparency = 1, Text = name, TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = f})
	local b = create("TextButton", {Size = UDim2.new(0, 60, 0, 20), Position = UDim2.new(1, -65, 0.5, -10), BackgroundColor3 = colors.Button, Text = def and def.Value.Name or "None", TextColor3 = colors.Text, TextSize = 12, Font = Enum.Font.FredokaOne, Parent = f})
	create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = b})
	b.MouseButton1Click:Connect(function()
		b.Text = "Press..."
		local c
		c = UserInputService.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.Keyboard then
				if i.KeyCode == Enum.KeyCode.Escape then
					keybinds[name] = nil
					b.Text = "None"
				else
					keybinds[name] = {Type = "Keyboard", Value = i.KeyCode}
					b.Text = i.KeyCode.Name
				end
			elseif i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.MouseButton2 or i.UserInputType == Enum.UserInputType.MouseButton3 then
				keybinds[name] = {Type = "MouseButton", Value = i.UserInputType}
				b.Text = i.UserInputType.Name
			end
			if keybinds[name] or i.KeyCode == Enum.KeyCode.Escape then
				c:Disconnect()
			end
		end)
	end)
end
local function addVoiceChatUnban(y, p)
	local f = create("Frame", {Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, y), BackgroundTransparency = 1, Parent = p})
	create("TextLabel", {Size = UDim2.new(0.7, 0, 1, 0), Position = UDim2.new(0, 5, 0, 0), BackgroundTransparency = 1, Text = "VC Unban", TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = f})
	local b = create("TextButton", {Size = UDim2.new(0, 60, 0, 20), Position = UDim2.new(0.85, -16, 0.5, -10), BackgroundColor3 = colors.Interface, Text = "Start", TextColor3 = colors.Text, TextSize = 12, Font = Enum.Font.FredokaOne, Parent = f})
	create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = b})
	b.MouseButton1Click:Connect(function()
		pcall(function() game:GetService("VoiceChatService"):joinVoice() end)
		b.Text = "Done"
		b.BackgroundColor3 = colors.ToggleOn
		b.Active = false
	end)
end

-- Combat Functions
local function predictTargetPosition(tp, dt)
	local vel = tp.Velocity or Vector3.new()
	return tp.Position + vel * dt * math.clamp(vel.Magnitude / 50, 0.5, 2)
end
local function getTargetInFOV()
	local mp = UserInputService:GetMouseLocation()
	local c, md = nil, math.huge
	if targetedPlayer and targetedPlayer.Character then
		local p = targetedPlayer.Character:FindFirstChild(aimlockTargetPart == "Head" and "Head" or "HumanoidRootPart")
		if p then
			local pp, os = camera:WorldToViewportPoint(p.Position)
			if os and (Vector2.new(pp.X, pp.Y) - mp).Magnitude <= aimlockFOV then return p end
		end
	end
	for _, p in pairs(cachedPlayers) do
		if p ~= player then
			local part = p.Character and p.Character:FindFirstChild(aimlockTargetPart == "Head" and "Head" or "HumanoidRootPart")
			if part then
				local pp, os = camera:WorldToViewportPoint(part.Position)
				if os then
					local d = (Vector2.new(pp.X, pp.Y) - mp).Magnitude
					if d <= aimlockFOV and d < md then c = part md = d end
				end
			end
		end
	end
	return c
end

-- ESP Functions
local function updateESP()
	if not espActive then
		for p, h in pairs(espHighlights) do if h then h:Destroy() end espHighlights[p] = nil end
		for p, n in pairs(espNames) do if n then n:Destroy() end espNames[p] = nil end
		seenPlayers = {}
		return
	end
	local currentPlayers = {}
	for _, p in pairs(cachedPlayers) do
		if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			currentPlayers[p] = true
			if not seenPlayers[p] then
				local h = Instance.new("Highlight")
				h.FillColor = colors.ESP
				h.FillTransparency = 0.7
				h.OutlineColor = colors.ESP
				h.OutlineTransparency = 0
				h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				h.Parent = p.Character
				espHighlights[p] = h
				local ng = create("BillboardGui", {Size = UDim2.new(0, 100, 0, 50), StudsOffset = Vector3.new(0, 3, 0), Adornee = p.Character:WaitForChild("Head"), AlwaysOnTop = true, Parent = p.Character})
				create("TextLabel", {Size = UDim2.new(1, 0, 1, 0), Text = p.Name, TextColor3 = colors.ESP, TextSize = 14, BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, Parent = ng})
				espNames[p] = ng
				seenPlayers[p] = true
			end
			if espHighlights[p] then espHighlights[p].Enabled = true end
			if espNames[p] then espNames[p].Enabled = true end
		end
	end
	for p in pairs(seenPlayers) do
		if not currentPlayers[p] then
			if espHighlights[p] then espHighlights[p]:Destroy() espHighlights[p] = nil end
			if espNames[p] then espNames[p]:Destroy() espNames[p] = nil end
			seenPlayers[p] = nil
		end
	end
end
Players.PlayerAdded:Connect(function(p) cachedPlayers = Players:GetPlayers() if espActive then updateESP() end end)
Players.PlayerRemoving:Connect(function(p)
	cachedPlayers = Players:GetPlayers()
	seenPlayers[p] = nil
	if espHighlights[p] then espHighlights[p]:Destroy() espHighlights[p] = nil end
	if espNames[p] then espNames[p]:Destroy() espNames[p] = nil end
end)

-- Visuals Tab
addSlider("Saturation", -1, 2, 0, 0, function(v) if v ~= colorCorrection.Saturation then colorCorrection.Saturation = v end end, visualsTab, false, false)
addSlider("FOV", 30, 120, 70, 40, function(v) if v ~= camera.FieldOfView then camera.FieldOfView = v end end, visualsTab, false, true)
local timeFrame = addSlider("Time", 0, 24, originalSettings.ClockTime, 80, function(v) if not timeLocked and v ~= Lighting.ClockTime then Lighting.ClockTime = v end end, visualsTab, false, false)
local ef, et = addToggle("ESP", false, 120, function(on) espActive = on updateESP() end, visualsTab)
local espColorBtn = create("TextButton", {Size = UDim2.new(0, 60, 0, 25), Position = UDim2.new(0.55, 0, 0, 10), BackgroundColor3 = colors.ESP, Text = "Color", TextColor3 = colors.Text, TextSize = 12, Font = Enum.Font.FredokaOne, Parent = ef})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = espColorBtn})
local function updateESPColor(newColor)
	colors.ESP = newColor
	espColorBtn.BackgroundColor3 = newColor
	for _, highlight in pairs(espHighlights) do
		if highlight and highlight:IsA("Highlight") then
			highlight.FillColor = newColor
			highlight.OutlineColor = newColor
		end
	end
	for p, ng in pairs(espNames) do
		if ng and ng:FindFirstChild("TextLabel") then
			ng.TextLabel.TextColor3 = newColor
		end
	end
	updateESP()
end
espColorBtn.MouseButton1Click:Connect(function() openColorPicker() end)
addToggle("Infinite Zoom", false, 160, function(on) player.CameraMaxZoomDistance = on and 10000000 or originalSettings.MaxZoom end, visualsTab)
addToggle("Wallhack", false, 200, function(on)
	wallhackActive = on
	if on then
		for _, v in pairs(workspace:GetDescendants()) do
			if v:IsA("BasePart") then
				if not originalSettings.Transparency[v] then originalSettings.Transparency[v] = v.Transparency end
				v.Transparency = 0.7
			end
		end
	else
		for p, t in pairs(originalSettings.Transparency) do if p.Parent then p.Transparency = t else originalSettings.Transparency[p] = nil end end
	end
end, visualsTab)
addToggle("Low Texture", false, 240, function(on)
	lowTextureActive = on
	if on then
		for _, v in pairs(workspace:GetDescendants()) do
			if v:IsA("BasePart") then
				if not originalSettings.Materials[v] then originalSettings.Materials[v] = v.Material end
				v.Material = Enum.Material.SmoothPlastic
			end
		end
	else
		for p, m in pairs(originalSettings.Materials) do if p.Parent then p.Material = m else originalSettings.Materials[p] = nil end end
	end
end, visualsTab)
visualsTab.CanvasSize = UDim2.new(0, 0, 0, 290)

-- Player Tab
local csf, cst = addToggle("Speed", false, 0, function(on) if not rootPart then return end if on and flyActive then flyToggle(false) end speedActive = on end, playerTab)
local csi = create("TextBox", {Size = UDim2.new(0.15, 0, 0, 20), Position = UDim2.new(0.6, 0, 0.5, -10), BackgroundColor3 = colors.Button, Text = tostring(speedValue), TextColor3 = colors.Text, TextSize = 12, Font = Enum.Font.FredokaOne, Parent = csf})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = csi})
csi.FocusLost:Connect(function(e) if e then local v = tonumber(csi.Text) if v then speedValue = math.clamp(v, 50, 50000) end end end)
local ff, flyToggle = addToggle("Fly", false, 40, function(on)
	if not rootPart or not humanoid then return end
	if on and speedActive then cst(false) end
	flyActive = on
	humanoid.PlatformStand = on
	if on then
		bodyVelocity = bodyVelocity or Instance.new("BodyVelocity")
		bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		bodyVelocity.Velocity = Vector3.new()
		bodyVelocity.Parent = rootPart
		bodyGyro = bodyGyro or Instance.new("BodyGyro")
		bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
		bodyGyro.P = 20000
		bodyGyro.D = 100
		bodyGyro.Parent = rootPart
	else
		if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
		if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
	end
end, playerTab)
local fsi = create("TextBox", {Size = UDim2.new(0.15, 0, 0, 20), Position = UDim2.new(0.6, 0, 0.5, -10), BackgroundColor3 = colors.Button, Text = tostring(flySpeedValue), TextColor3 = colors.Text, TextSize = 12, Font = Enum.Font.FredokaOne, Parent = ff})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = fsi})
fsi.FocusLost:Connect(function(e) if e then local v = tonumber(fsi.Text) if v then flySpeedValue = math.clamp(v, 50, 50000) end end end)
local fcf, fct = addToggle("Free Cam", false, 80, function(on)
	if not character or not rootPart then return end
	freeCamActive = on
	if on then
		rootPart.Anchored = true
		if humanoid then humanoid.WalkSpeed = 0 end
		camera.CameraType = Enum.CameraType.Scriptable
		freeCamPosition = camera.CFrame.Position
		freeCamPitch, freeCamYaw = camera.CFrame:ToEulerAnglesYXZ()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	else
		rootPart.Anchored = false
		if humanoid then humanoid.WalkSpeed = 16 end
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = character.Humanoid
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end, playerTab)
local fcsi = create("TextBox", {Size = UDim2.new(0.15, 0, 0, 20), Position = UDim2.new(0.6, 0, 0.5, -10), BackgroundColor3 = colors.Button, Text = tostring(freeCamSpeed), TextColor3 = colors.Text, TextSize = 12, Font = Enum.Font.FredokaOne, Parent = fcf})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = fcsi})
fcsi.FocusLost:Connect(function(e) if e then local v = tonumber(fcsi.Text) if v then freeCamSpeed = math.clamp(v, 50, 50000) end end end)
addToggle("Noclip", false, 120, function(on) noclipActive = on end, playerTab)
local y = 160
addToggle("Click Teleport", false, y, function(on) clickTeleportActive = on end, playerTab) y = y + 45
local infiniteJumpEnabled = false
addToggle("Infinite Jump", false, y, function(state) infiniteJumpEnabled = state end, playerTab) y = y + 45
local spinEnabled = false
addToggle("Spin", false, y, function(state) spinEnabled = state end, playerTab) y = y + 45
local spinSpeed = 5
addSlider("Spin Speed", 0, 100, 5, y, function(val) spinSpeed = val end, playerTab, false, true) y = y + 45
addVoiceChatUnban(y, playerTab) y = y + 45
addActionButton("Rejoin", 10, y, function() game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, player) end, playerTab, 120)
addActionButton("Server Hop", 140, y, function()
	if httprequest then
		local servers = {}
		local req = httprequest({ Url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100", game.PlaceId) })
		local body = game:GetService("HttpService"):JSONDecode(req.Body)
		if body and body.data then
			for _, v in next, body.data do
				if type(v) == "table" and tonumber(v.playing) and tonumber(v.maxPlayers) and v.playing < v.maxPlayers and v.id ~= game.JobId then
					table.insert(servers, 1, v.id)
				end
			end
		end
		if #servers > 0 then game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], player) end
	end
end, playerTab, 120)
addActionButton("Jerk", 270, y, function()
	if not character then return end
	local isR6 = character:FindFirstChild("Torso") ~= nil
	local scriptUrl = isR6 and "https://pastefy.app/wa3v2Vgm/raw" or "https://pastefy.app/YZoglOyJ/raw"
	local jerkScript = loadstring(game:HttpGet(scriptUrl))
	if jerkScript then jerkScript() end
end, playerTab, 120)
playerTab.CanvasSize = UDim2.new(0, 0, 0, y + 80)
RunService.RenderStepped:Connect(function() if spinEnabled and character and rootPart then rootPart.CFrame = rootPart.CFrame * CFrame.Angles(0, math.rad(spinSpeed), 0) end end)

-- Combat Tab
local af, at = addToggle("Aimlock", false, 0, function(on) aimlockActive = on if not on then lockedTarget = nil aimlockLocked = false end end, combatTab)
local asf = create("Frame", {Size = UDim2.new(1, 0, 0, 200), Position = UDim2.new(0, 0, 0, 40), BackgroundTransparency = 1, Parent = combatTab})
local sb, st = addButton("Silent Aim", 0, 0, function(s) silentAimActive = s end, asf, false, 80)
local pb, pt = addButton("Prediction", 90, 0, function(s) predictionActive = s end, asf, false, 80)
local thb, tht = addButton("Toggle", 180, 0, function(s) aimlockToggleMode = s thb.Text = s and "Toggle" or "Hold" lockedTarget = nil aimlockLocked = false end, asf, false, 80)
local hb, ht = addButton("Head", 270, 0, function(s) aimlockTargetPart = aimlockTargetPart == "Head" and "Torso" or "Head" lockedTarget = nil hb.Text = aimlockTargetPart end, asf, true, 80)
local fovFrame = addSlider("Aimlock FOV", 30, 320, aimlockFOV, 35, function(v)
	aimlockFOV = v
	if fovCone then fovCone.Size = UDim2.new(0, v * 2, 0, v * 2) fovCone.Position = UDim2.new(0.5, -v, 0.5, -v) end
end, asf, false, true)
local fovLockBtn = create("ImageButton", {Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(0, 110, 0.5, -10), BackgroundColor3 = colors.Button, Image = "rbxassetid://6023565895", ImageColor3 = colors.Text, Parent = fovFrame})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = fovLockBtn})
fovLockBtn.MouseButton1Click:Connect(function()
	showFOVCone = not showFOVCone
	fovLockBtn.BackgroundColor3 = showFOVCone and colors.ToggleOn or colors.Button
	if not fovCone and showFOVCone then
		fovCone = create("Frame", {Size = UDim2.new(0, aimlockFOV * 2, 0, aimlockFOV * 2), Position = UDim2.new(0.5, -aimlockFOV, 0.5, -aimlockFOV), BackgroundTransparency = 0.7, BackgroundColor3 = colors.Outline, BorderSizePixel = 0, Parent = gui})
		create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = fovCone})
	elseif fovCone and not showFOVCone then fovCone:Destroy() fovCone = nil end
	if fovCone then fovCone.Visible = showFOVCone end
end)
combatTab.CanvasSize = UDim2.new(0, 0, 0, 240)
do
	local aimlockSliderY = 120
	local dahoodBtnY = aimlockSliderY + 20
	local function dahoodScript() loadstring(game:HttpGet("https://raw.githubusercontent.com/Actyrn/Scripts/main/AzureModded"))() end
	addActionButton("Dahood", 10, dahoodBtnY, dahoodScript, combatTab, 120)
end

-- Target Tab
local targetInputFrame = create("Frame", {Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1, Parent = targetTab})
local targetInput = create("TextBox", {Size = UDim2.new(0.7, 0, 1, 0), Position = UDim2.new(0, 5, 0, 0), BackgroundColor3 = colors.Button, Text = "", TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, PlaceholderText = "Enter player name", ClearTextOnFocus = false, Parent = targetInputFrame})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = targetInput})
local clickTargetBtn = create("ImageButton", {Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(0.75, 0, 0, 5), BackgroundTransparency = 1, Image = "rbxassetid://2716591855", Parent = targetInputFrame})
local targetImage = create("ImageLabel", {Size = UDim2.new(0, 100, 0, 100), Position = UDim2.new(0, 10, 0, 50), BackgroundColor3 = colors.Background, Image = "rbxassetid://10818605405", Parent = targetTab})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = targetImage})
local userInfoLabel = create("TextLabel", {Size = UDim2.new(0, 200, 0, 75), Position = UDim2.new(0, 120, 0, 50), BackgroundTransparency = 1, Text = "UserID: \nDisplay: \nJoined: ", TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = targetTab})
local viewActive = false
local viewBtn, viewToggle = addButton("View", 10, 160, function(s)
	viewActive = s
	if s then
		if targetedPlayer and targetedPlayer.Character and targetedPlayer.Character:FindFirstChild("Humanoid") then
			camera.CameraSubject = targetedPlayer.Character.Humanoid
		else
			notify("Zangetsu", "No target selected.", 5)
			viewToggle(false)
		end
	else
		camera.CameraSubject = character and character.Humanoid
	end
end, targetTab, false, 120)
addActionButton("Teleport", 140, 160, function()
	if targetedPlayer and targetedPlayer.Character and targetedPlayer.Character:FindFirstChild("HumanoidRootPart") then
		rootPart.CFrame = targetedPlayer.Character.HumanoidRootPart.CFrame + Vector3.new(0, 2, 0)
	else
		notify("Zangetsu", "No target selected.", 5)
	end
end, targetTab, 120)
local flingActive = false
local flingVelocityTask
local flingOldPos
local flingBtn, flingToggle = addButton("Fling", 10, 210, function(s)
	if s then
		if targetedPlayer then
			flingOldPos = rootPart.Position
			flingActive = true
			flingVelocityTask = task.spawn(function()
				while flingActive do
					local originalVelocity = rootPart.Velocity
					rootPart.Velocity = Vector3.new(math.random(-150, 150), -25000, math.random(-150, 150))
					RunService.RenderStepped:Wait()
					rootPart.Velocity = originalVelocity
					RunService.Heartbeat:Wait()
				end
			end)
			task.spawn(function()
				while flingActive do
					if targetedPlayer and targetedPlayer.Character and targetedPlayer.Character:FindFirstChild("HumanoidRootPart") then
						local targetPos = targetedPlayer.Character.HumanoidRootPart.CFrame
						if predictionActive then
							local vel = targetedPlayer.Character.HumanoidRootPart.Velocity
							local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
							targetPos = targetPos + vel * ping
						end
						rootPart.CFrame = targetPos
						task.wait()
					else
						task.wait()
					end
				end
			end)
		else
			notify("Zangetsu", "No target selected.", 5)
			flingToggle(false)
		end
	else
		flingActive = false
		if flingOldPos then
			task.spawn(function()
				local startTime = tick()
				while tick() - startTime < 2 do
					if rootPart then rootPart.CFrame = CFrame.new(flingOldPos) rootPart.Velocity = Vector3.new(0, 0, 0) end
					RunService.Heartbeat:Wait()
				end
			end)
		end
	end
end, targetTab, false, 120)
local bangActive = false
local bangBtn, bangToggle = addButton("Bang", 140, 210, function(s)
	bangActive = s
	if s then
		if targetedPlayer then
			PlayAnim(5918726674, 0, 1)
			task.spawn(function()
				while bangActive do
					if targetedPlayer and targetedPlayer.Character and targetedPlayer.Character:FindFirstChild("HumanoidRootPart") then
						local targetPos = targetedPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 1.1)
						if predictionActive then
							local vel = targetedPlayer.Character.HumanoidRootPart.Velocity
							local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
							targetPos = targetPos + vel * ping
						end
						rootPart.CFrame = targetPos
						rootPart.Velocity = Vector3.new(0, 0, 0)
						task.wait()
					else
						task.wait()
					end
				end
				StopAnim()
			end)
		else
			notify("Zangetsu", "No target selected.", 5)
			bangToggle(false)
		end
	end
end, targetTab, false, 120)
local headsitActive = false
local headsitBtn, headsitToggle = addButton("Headsit", 10, 260, function(s)
	headsitActive = s
	if s then
		if targetedPlayer then
			task.spawn(function()
				while headsitActive do
					if targetedPlayer and targetedPlayer.Character and targetedPlayer.Character:FindFirstChild("Head") then
						humanoid.Sit = true
						local targetPos = targetedPlayer.Character.Head.CFrame * CFrame.new(0, 2, 0)
						if predictionActive then
							local vel = targetedPlayer.Character.HumanoidRootPart.Velocity
							local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
							targetPos = targetPos + vel * ping
						end
						rootPart.CFrame = targetPos
						rootPart.Velocity = Vector3.new(0, 0, 0)
						task.wait()
					else
						task.wait()
					end
				end
			end)
		else
			notify("Zangetsu", "No target selected.", 5)
			headsitToggle(false)
		end
	end
end, targetTab, false, 120)
local standActive = false
local standBtn, standToggle = addButton("Stand", 140, 260, function(s)
	standActive = s
	if s then
		if targetedPlayer then
			originalAnimationSpeed = animationSpeedMultiplier
			animationSpeedMultiplier = 0
			PlayAnim(13823324057, 4, 0)
			task.spawn(function()
				while standActive do
					pcall(function()
						local targetRoot = targetedPlayer.Character and targetedPlayer.Character:FindFirstChild("HumanoidRootPart")
						if targetRoot then
							rootPart.CFrame = targetRoot.CFrame * CFrame.new(-3, 1, 0)
							rootPart.Velocity = Vector3.new(0, 0, 0)
						end
					end)
					task.wait()
				end
				StopAnim()
				animationSpeedMultiplier = originalAnimationSpeed
			end)
		else
			notify("Zangetsu", "No target selected.", 5)
			standToggle(false)
		end
	else
		StopAnim()
		animationSpeedMultiplier = originalAnimationSpeed
	end
end, targetTab, false, 120)
local backpackActive = false
local backpackBtn, backpackToggle = addButton("Backpack", 10, 310, function(s)
	backpackActive = s
	if s then
		if targetedPlayer then
			task.spawn(function()
				while backpackActive do
					if targetedPlayer and targetedPlayer.Character and targetedPlayer.Character:FindFirstChild("HumanoidRootPart") then
						humanoid.Sit = true
						local targetPos = targetedPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 1.2) * CFrame.Angles(0, -3, 0)
						if predictionActive then
							local vel = targetedPlayer.Character.HumanoidRootPart.Velocity
							local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
							targetPos = targetPos + vel * ping
						end
						rootPart.CFrame = targetPos
						rootPart.Velocity = Vector3.new(0, 0, 0)
						task.wait()
					else
						task.wait()
					end
				end
			end)
		else
			notify("Zangetsu", "No target selected.", 5)
			backpackToggle(false)
		end
	end
end, targetTab, false, 120)
local doggyActive = false
local doggyBtn, doggyToggle = addButton("Doggy", 140, 310, function(s)
	doggyActive = s
	if s then
		if targetedPlayer then
			originalAnimationSpeed = animationSpeedMultiplier
			animationSpeedMultiplier = 0
			PlayAnim(13694096724, 3.4, 0)
			task.spawn(function()
				while doggyActive do
					pcall(function()
						local targetRoot = targetedPlayer.Character and targetedPlayer.Character:FindFirstChild("LowerTorso")
						if targetRoot then
							rootPart.CFrame = targetRoot.CFrame * CFrame.new(0, 0.23, 0)
							rootPart.Velocity = Vector3.new(0, 0, 0)
						end
					end)
					task.wait()
				end
				StopAnim()
				animationSpeedMultiplier = originalAnimationSpeed
			end)
		else
			notify("Zangetsu", "No target selected.", 5)
			doggyToggle(false)
		end
	else
		StopAnim()
		animationSpeedMultiplier = originalAnimationSpeed
	end
end, targetTab, false, 120)
local dragActive = false
local dragBtn, dragToggle = addButton("Drag", 10, 360, function(s)
	dragActive = s
	if s then
		if targetedPlayer then
			originalAnimationSpeed = animationSpeedMultiplier
			animationSpeedMultiplier = 0
			PlayAnim(10714360343, 0.5, 0)
			task.spawn(function()
				while dragActive do
					pcall(function()
						local targetHand = targetedPlayer.Character and targetedPlayer.Character:FindFirstChild("RightHand")
						if targetHand then
							rootPart.CFrame = targetHand.CFrame * CFrame.new(0, -2.5, 1) * CFrame.Angles(-2, -3, 0)
							rootPart.Velocity = Vector3.new(0, 0, 0)
						end
					end)
					task.wait()
				end
				StopAnim()
				animationSpeedMultiplier = originalAnimationSpeed
			end)
		else
			notify("Zangetsu", "No target selected.", 5)
			dragToggle(false)
		end
	else
		StopAnim()
		animationSpeedMultiplier = originalAnimationSpeed
	end
end, targetTab, false, 120)
addActionButton("Find Nearest", 140, 360, function()
	local nearestPlayer = nil
	local minDistance = math.huge
	local myPos = rootPart and rootPart.Position
	if not myPos then return end
	for _, p in pairs(Players:GetPlayers()) do
		if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			local distance = (p.Character.HumanoidRootPart.Position - myPos).Magnitude
			if distance < minDistance then minDistance = distance nearestPlayer = p end
		end
	end
	if nearestPlayer then
		targetedPlayer = nearestPlayer
		targetInput.Text = nearestPlayer.Name
		targetImage.Image = Players:GetUserThumbnailAsync(nearestPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		userInfoLabel.Text = ("UserID: %d\nDisplay: %s\nJoined: %s"):format(nearestPlayer.UserId, nearestPlayer.DisplayName, os.date("%d-%m-%Y", os.time() - nearestPlayer.AccountAge * 24 * 3600))
	end
end, targetTab, 120)
addActionButton("Random Target", 10, 400, function()
	local players = Players:GetPlayers()
	if #players > 1 then
		local randomPlayer
		repeat randomPlayer = players[math.random(1, #players)] until randomPlayer ~= player
		targetedPlayer = randomPlayer
		targetInput.Text = randomPlayer.Name
		targetImage.Image = Players:GetUserThumbnailAsync(randomPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		userInfoLabel.Text = ("UserID: %d\nDisplay: %s\nJoined: %s"):format(randomPlayer.UserId, randomPlayer.DisplayName, os.date("%d-%m-%Y", os.time() - randomPlayer.AccountAge * 24 * 3600))
	end
end, targetTab, 120)
targetInput.FocusLost:Connect(function()
	local inputText = targetInput.Text:lower()
	if inputText ~= "" then
		for _, p in pairs(Players:GetPlayers()) do
			if p.Name:lower():sub(1, #inputText) == inputText or p.DisplayName:lower():sub(1, #inputText) == inputText then
				targetedPlayer = p
				targetInput.Text = p.Name
				targetImage.Image = Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
				userInfoLabel.Text = ("UserID: %d\nDisplay: %s\nJoined: %s"):format(p.UserId, p.DisplayName, os.date("%d-%m-%Y", os.time() - p.AccountAge * 24 * 3600))
				break
			end
		end
	else
		targetedPlayer = nil
		targetInput.Text = ""
		targetImage.Image = "rbxassetid://10818605405"
		userInfoLabel.Text = "UserID: \nDisplay: \nJoined: "
	end
end)
clickTargetBtn.MouseButton1Click:Connect(function()
	local GetTargetTool = Instance.new("Tool")
	GetTargetTool.Name = "ClickTarget"
	GetTargetTool.RequiresHandle = false
	GetTargetTool.TextureId = "rbxassetid://2716591855"
	GetTargetTool.ToolTip = "Select Target"
	GetTargetTool.Activated:Connect(function()
		local hit = player:GetMouse().Target
		if hit and hit.Parent then
			local person = Players:GetPlayerFromCharacter(hit.Parent)
			if not person and hit.Parent:IsA("Accessory") then person = Players:GetPlayerFromCharacter(hit.Parent.Parent) end
			if person then
				targetedPlayer = person
				targetInput.Text = person.Name
				targetImage.Image = Players:GetUserThumbnailAsync(person.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
				userInfoLabel.Text = ("UserID: %d\nDisplay: %s\nJoined: %s"):format(person.UserId, person.DisplayName, os.date("%d-%m-%Y", os.time() - person.AccountAge * 24 * 3600))
			end
		end
	end)
	GetTargetTool.Parent = player.Backpack
end)
targetTab.CanvasSize = UDim2.new(0, 0, 0, 450)

-- Animations Tab
local loadingType = nil
local customAnimTextBoxes = {}
local individualLoadButtons = {}

local function applyAnimation(idle, swim, walk, run, jump, climb, fall)
	pcall(function()
		local Animate = character and character:FindFirstChild("Animate")
		if not Animate then return end
		Animate.Disabled = true
		StopAnim()
		local function setAnimId(animObj, id)
			if animObj and id and id ~= "" and tonumber(id) then animObj.AnimationId = "rbxassetid://" .. id end
		end
		setAnimId(Animate.idle:FindFirstChild("Animation1"), idle)
		setAnimId(Animate.idle:FindFirstChild("Animation2"), idle)
		if swim then
			local swimFolder = Animate:FindFirstChild("swim")
			if swimFolder then
				setAnimId(swimFolder:FindFirstChild("SwimAnim") or swimFolder:FindFirstChildOfClass("Animation"), swim)
			end
		end
		setAnimId(Animate.walk:FindFirstChild("WalkAnim"), walk)
		setAnimId(Animate.run:FindFirstChild("RunAnim"), run)
		setAnimId(Animate.jump:FindFirstChild("JumpAnim"), jump)
		setAnimId(Animate.climb:FindFirstChild("ClimbAnim"), climb)
		setAnimId(Animate.fall:FindFirstChild("FallAnim"), fall)
		Animate.Disabled = false
	end)
end

local function createAnimationsGrid(animations, parent)
	local perRow = 5
	local spacing = 10
	local btnWidth = (parent.AbsoluteSize.X - (perRow + 1) * spacing) / perRow
	for i, anim in ipairs(animations) do
		local row = math.floor((i - 1) / perRow)
		local col = (i - 1) % perRow
		local name, idle, swim, walk, run, jump, climb, fall = unpack(anim)
		local btn = create("TextButton", {
			Size = UDim2.new(0, btnWidth, 0, 23),
			Position = UDim2.new(0, spacing + col * (btnWidth + spacing), 0, spacing + row * (30 + spacing)),
			BackgroundColor3 = colors.Button,
			Text = name,
			TextColor3 = colors.Text,
			TextSize = 14.5,
			Font = Enum.Font.FredokaOne,
			Parent = parent
		})
		create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = btn})
		btn.MouseButton1Click:Connect(function()
			if loadAllToggle then
				customAnimTextBoxes["Idle"].Text = idle
				customAnimTextBoxes["Walk"].Text = walk
				customAnimTextBoxes["Run"].Text = run
				customAnimTextBoxes["Jump"].Text = jump
				customAnimTextBoxes["Fall"].Text = fall
				customAnimTextBoxes["Climb"].Text = climb
				customAnimTextBoxes["Swim"].Text = swim
			elseif loadingType then
				customAnimTextBoxes[loadingType].Text = anim[loadingType == "Idle" and 2 or loadingType == "Swim" and 3 or loadingType == "Walk" and 4 or loadingType == "Run" and 5 or loadingType == "Jump" and 6 or loadingType == "Climb" and 7 or loadingType == "Fall" and 8]
				loadingType = nil
				for _, btn in pairs(individualLoadButtons) do btn.Text = "Select" end
			else
				applyAnimation(idle, swim, walk, run, jump, climb, fall)
			end
		end)
	end
end

local animButtons = {
	{"Vampire", "1083445855", "1083450166", "1083473930", "1083462077", "1083455352", "1083439238", "1083443587"},
	{"Hero", "616111295", "616113536", "616122287", "616117076", "616115533", "616104706", "616108001"},
	{"Zombie Classic", "616158929", "616160636", "616168032", "616163682", "616161997", "616156119", "616157476"},
	{"Mage", "707742142", "707855907", "707897309", "707861613", "707853694", "707826056", "707829716"},
	{"Ghost", "616006778", "616008087", "616013216", "616010382", "616008936", "616003713", "616005863"},
	{"Elder", "845397899", "845400520", "845403856", "845386501", "845398858", "845392038", "845396048"},
	{"Astronaut", "891621366", "891633237", "891667138", "891636393", "891627522", "891609353", "891617961"},
	{"Ninja", "656117400", "656118341", "656121766", "656118852", "656117878", "656114359", "656115606"},
	{"Werewolf", "1083195517", "1083214717", "1083178339", "1083216690", "1083218792", "1083182000", "1083189019"},
	{"Cartoon", "742637544", "742638445", "742640026", "742638842", "742637942", "742636889", "742637151"},
	{"Pirate", "750781874", "750782770", "750785693", "750783738", "750782230", "750779899", "750780242"},
	{"Sneaky", "1132473842", "1132477671", "1132510133", "1132494274", "1132489853", "1132461372", "1132469004"},
	{"Toy", "782841498", "782845736", "782843345", "782842708", "782847020", "782843869", "782846423"},
	{"Knight", "657595757", "657568135", "657552124", "657564596", "658409194", "658360781", "657600338"},
	{"Confident", "1069977950", "1069987858", "1070017263", "1070001516", "1069984524", "1069946257", "1069973677"},
	{"Popstar", "1212900985", "1212900985", "1212980338", "1212980348", "1212954642", "1213044953", "1212900995"},
	{"Princess", "941003647", "941013098", "941028902", "941015281", "941008832", "940996062", "941000007"},
	{"Cowboy", "1014390418", "1014398616", "1014421541", "1014401683", "1014394726", "1014380606", "1014384571"},
	{"Patrol", "1149612882", "1150842221", "1151231493", "1150967949", "1150944216", "1148811837", "1148863382"},
	{"FE Zombie", "3489171152", "3489171152", "3489174223", "3489173414", "616161997", "616156119", "616157476"},
	{"Stylized Female", "4708192150", "4708191566", "4708193840", "4708192705", "4708188025", "4708184253", "4708186162"},
	{"Oldschool", "5319828216", "5319831086", "5319847204", "5319844329", "5319841935", "5319816685", "5319839762"},
	{"Rthro", "2510196951", "2510197257", "2510202577", "2510198475", "2510197830", "2510192778", "2510195892"},
	{"Wicked", "118832222982049", "76049494037641", "92072849924640", "72301599441680", "104325245285198", "131326830509784", "121152442762481"},
	{"Stylish", "616136790", "616138447", "616146177", "616140816", "616139451", "616133594", "616134815"},
	{"adidas", "18537376492", "18537371272", "18537392113", "18537384940", "18537380791", "18537363391", "18537367238"},
	{"Robot", "616088211", "616089559", "616095330", "616091570", "616090535", "616086039", "616087089"},
	{"Bold", "16738333868", "16738334710", "16738340646", "16738337225", "16738336650", "16738332169", "16738333171"},
	{"Catwalk", "133806214992291", "94970088341563", "109168724482748", "81024476153754", "116936326516985", "119377220967554", "92294537340807"},
	{"Bubbly", "910004836", "910009958", "910034870", "910025107", "910016857", "909997997", "910001910"},
	{"No Boundaries", "18747067405", "18747063918", "18747074203", "18747070484", "18747069148", "18747060903", "18747062535"},
	{"NFL", "92080889861410", "74451233229259", "110358958299415", "117333533048078", "119846112151352", "134630013742019", "129773241321032"},
	{"R15", "4211217646", "4211218409", "4211223236", "4211220381", "4211219390", "4211214992", "4211216152"},
	{"Ghost 2", "1151221899", "1151221899", "1151221899", "1151221899", "1151221899", "0", "1151221899"},
	{"Udzal", "3303162274", "3303162549", "3303162967", "3236836670", "2510197830", "2510192778", "2510195892"},
	{"Oinan Thickhoof", "657595757", "657568135", "2510202577", "3236836670", "2510197830", "2510192778", "2510195892"},
	{"Borock", "3293641938", "3293642554", "2510202577", "3236836670", "2510197830", "2510192778", "2510195892"},
	{"Blocky Mech", "4417977954", "4417978624", "2510202577", "4417979645", "2510197830", "2510192778", "2510195892"},
	{"Goofy", "18537387180", "18537387180", "18537367238", "18537367238", "18537367238", "18537367238", "18537367238"}
}

createAnimationsGrid(animButtons, animationsTab)

-- Custom Animation Controls
local customAnimHeader = create("TextLabel", {Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 750), BackgroundTransparency = 1, Text = "Custom Animation Controls", TextColor3 = colors.Text, TextSize = 18, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = animationsTab})
local animTypes = {"Idle", "Run", "Walk", "Jump", "Fall", "Swim", "Climb"}
for i, animType in ipairs(animTypes) do
	local yPos = 790 + (i - 1) * 40
	create("TextLabel", {Size = UDim2.new(0, 100, 0, 30), Position = UDim2.new(0, 10, 0, yPos), BackgroundTransparency = 1, Text = animType .. ":", TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = animationsTab})
	local tb = create("TextBox", {Size = UDim2.new(0, 150, 0, 30), Position = UDim2.new(0, 120, 0, yPos), BackgroundColor3 = colors.Button, Text = "", PlaceholderText = "ID", TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, Parent = animationsTab})
	create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = tb})
	customAnimTextBoxes[animType] = tb
	local loadBtn = create("TextButton", {Size = UDim2.new(0, 50, 0, 30), Position = UDim2.new(0, 280, 0, yPos), BackgroundColor3 = colors.Button, Text = "Select", TextColor3 = colors.Text, TextSize = 12, Font = Enum.Font.FredokaOne, Parent = animationsTab})
	create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = loadBtn})
	loadBtn.MouseButton1Click:Connect(function()
		if loadingType == animType then
			loadingType = nil
			loadBtn.Text = "Select"
		else
			for _, btn in pairs(individualLoadButtons) do btn.Text = "Select" end
			loadingType = animType
			loadBtn.Text = "..."
		end
	end)
	individualLoadButtons[animType] = loadBtn
end

local applyBtn = create("TextButton", {Size = UDim2.new(0, 120, 0, 25), Position = UDim2.new(0, 10, 0, 1100), BackgroundColor3 = colors.Interface, Text = "Apply Animation", TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, Parent = animationsTab})
create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = applyBtn})
local resetBtn = create("TextButton", {Size = UDim2.new(0, 120, 0, 25), Position = UDim2.new(0, 140, 0, 1100), BackgroundColor3 = colors.Button, Text = "Reset Animation", TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, Parent = animationsTab})
create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = resetBtn})
local loadAnimationBtn = create("TextButton", {Size = UDim2.new(0, 120, 0, 25), Position = UDim2.new(0, 270, 0, 1100), BackgroundColor3 = colors.Button, Text = "Load Animation", TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, Parent = animationsTab})
create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = loadAnimationBtn})
loadAnimationBtn.MouseButton1Click:Connect(function()
	loadAllToggle = not loadAllToggle
	loadAnimationBtn.Text = loadAllToggle and "Select Animation" or "Load Animation"
end)

local animSpeedSlider = addSlider("Animation Speed", 0, 25, 1, 1140, function(v) animationSpeedMultiplier = v end, animationsTab, false, false)
local emoteBtnY = 1180
local function emoteScript() loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Gi7331/scripts/main/Emote.lua"))() end
addActionButton("Emote", 10, emoteBtnY, emoteScript, animationsTab, 120)

local function applyCustomAnimations()
	if not character or not character:FindFirstChild("Animate") then return end
	local Animate = character.Animate
	Animate.Disabled = true
	StopAnim()
	local function setAnimId(animObj, id)
		if animObj and id and id ~= "" and tonumber(id) then animObj.AnimationId = "rbxassetid://" .. id end
	end
	setAnimId(Animate.idle:FindFirstChild("Animation1"), customAnimTextBoxes["Idle"].Text)
	setAnimId(Animate.idle:FindFirstChild("Animation2"), customAnimTextBoxes["Idle"].Text)
	setAnimId(Animate.walk:FindFirstChild("WalkAnim"), customAnimTextBoxes["Walk"].Text)
	setAnimId(Animate.run:FindFirstChild("RunAnim"), customAnimTextBoxes["Run"].Text)
	setAnimId(Animate.jump:FindFirstChild("JumpAnim"), customAnimTextBoxes["Jump"].Text)
	setAnimId(Animate.fall:FindFirstChild("FallAnim"), customAnimTextBoxes["Fall"].Text)
	setAnimId(Animate.climb:FindFirstChild("ClimbAnim"), customAnimTextBoxes["Climb"].Text)
	if Animate:FindFirstChild("swim") then
		local swimId = customAnimTextBoxes["Swim"].Text
		if swimId == "" or not tonumber(swimId) then swimId = defaultAnimations["Swim"] end
		setAnimId(Animate.swim:FindFirstChild("SwimAnim") or Animate.swim:FindFirstChildOfClass("Animation"), swimId)
	end
	Animate.Disabled = false
end

local function resetAnimations()
	if not character or not character:FindFirstChild("Animate") then return end
	local Animate = character.Animate
	Animate.Disabled = true
	StopAnim()
	local function setAnimId(animObj, id) if animObj and id then animObj.AnimationId = id end end
	setAnimId(Animate.idle:FindFirstChild("Animation1"), defaultAnimations["Idle"])
	setAnimId(Animate.idle:FindFirstChild("Animation2"), defaultAnimations["Idle"])
	setAnimId(Animate.walk:FindFirstChild("WalkAnim"), defaultAnimations["Walk"])
	setAnimId(Animate.run:FindFirstChild("RunAnim"), defaultAnimations["Run"])
	setAnimId(Animate.jump:FindFirstChild("JumpAnim"), defaultAnimations["Jump"])
	setAnimId(Animate.fall:FindFirstChild("FallAnim"), defaultAnimations["Fall"])
	setAnimId(Animate.climb:FindFirstChild("ClimbAnim"), defaultAnimations["Climb"])
	if Animate:FindFirstChild("swim") and defaultAnimations["Swim"] then
		local swimAnim = Animate.swim:FindFirstChild("SwimAnim") or Animate.swim:FindFirstChildOfClass("Animation")
		setAnimId(swimAnim, defaultAnimations["Swim"])
	end
	Animate.Disabled = false
end

applyBtn.MouseButton1Click:Connect(applyCustomAnimations)
resetBtn.MouseButton1Click:Connect(resetAnimations)
animationsTab.CanvasSize = UDim2.new(0, 0, 0, 1230)

-- Keybinds
addKeybind("Menu", keybinds.Menu, 0)
addKeybind("Aimlock", keybinds.Aimlock, 30)
addKeybind("ESP", keybinds.ESP, 60)
addKeybind("ClickTeleport", keybinds.ClickTeleport, 90)
addKeybind("Fly", keybinds.Fly, 120)
addKeybind("FreeCam", keybinds.FreeCam, 150)
addKeybind("Speed", keybinds.Speed, 180)

-- Settings Tab
addSlider("Transparency", 0, 1, menuTransparency, 20, function(v) mainFrame.BackgroundTransparency = v keybindsFrame.BackgroundTransparency = v end, settingsTab, false, false)

-- Color Picker
local cpf = create("Frame", {Size = UDim2.new(0, 180, 0, 140), Position = UDim2.new(0.5, -90, 0.5, -70), BackgroundColor3 = colors.Background, Visible = false, Parent = gui})
create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = cpf})
local db = create("Frame", {Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = colors.Header, Parent = cpf})
create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = db})
create("TextLabel", {Size = UDim2.new(0.8, 0, 1, 0), Position = UDim2.new(0.1, 0, 0, 0), BackgroundTransparency = 1, Text = "Color Picker", TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Center, Parent = db})
local cbx = create("TextButton", {Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(1, -24, 0, 2), BackgroundColor3 = colors.Button, Text = "X", TextColor3 = colors.Text, TextSize = 12, Font = Enum.Font.FredokaOne, Parent = db})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = cbx})
cbx.MouseButton1Click:Connect(function() cpf.Visible = false end)
local cp = create("Frame", {Size = UDim2.new(0, 160, 0, 16), Position = UDim2.new(0, 10, 0, 114), BackgroundColor3 = colors.ESP, Parent = cpf})
create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = cp})
local function createSlider(label, y, callback)
	local sf = create("Frame", {Size = UDim2.new(0, 160, 0, 16), Position = UDim2.new(0, 10, 0, y), BackgroundColor3 = colors.Button, Parent = cpf})
	create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = sf})
	local fill = create("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = colors.Interface, Parent = sf})
	create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = fill})
	create("TextLabel", {Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(-0.15, 0, 0, 0), BackgroundTransparency = 1, Text = label, TextColor3 = colors.Text, TextSize = 12, Font = Enum.Font.FredokaOne, Parent = sf})
	local dragging = false
	sf.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end end)
	UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local p = math.clamp((input.Position.X - sf.AbsolutePosition.X) / sf.AbsoluteSize.X, 0, 1)
			fill.Size = UDim2.new(p, 0, 1, 0)
			callback(p)
		end
	end)
	return fill
end
local hf = createSlider("H", 30, function(v) local h, s, v_old = colors.ESP:ToHSV() local newColor = Color3.fromHSV(v, s, v_old) cp.BackgroundColor3 = newColor updateESPColor(newColor) end)
local sf = createSlider("S", 54, function(v) local h, _, v_old = colors.ESP:ToHSV() local newColor = Color3.fromHSV(h, v, v_old) cp.BackgroundColor3 = newColor updateESPColor(newColor) end)
local vf = createSlider("V", 78, function(v) local h, s = colors.ESP:ToHSV() local newColor = Color3.fromHSV(h, s, v) cp.BackgroundColor3 = newColor updateESPColor(newColor) end)
function openColorPicker()
	cpf.Visible = not cpf.Visible
	if cpf.Visible then
		local h, s, v = colors.ESP:ToHSV()
		hf.Size = UDim2.new(h, 0, 1, 0)
		sf.Size = UDim2.new(s, 0, 1, 0)
		vf.Size = UDim2.new(v, 0, 1, 0)
		cp.BackgroundColor3 = colors.ESP
	end
end
local dragging, startPos, startFramePos
db.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true startPos = input.Position startFramePos = cpf.Position end end)
UserInputService.InputChanged:Connect(function(input) if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then local delta = input.Position - startPos cpf.Position = UDim2.new(startFramePos.X.Scale, startFramePos.X.Offset + delta.X, startFramePos.Y.Scale, startFramePos.Y.Offset + delta.Y) end end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
tabs["Visuals"].BackgroundColor3 = colors.TabSelected
tabContents["Visuals"].Visible = true

-- Helper Functions for Keybinds
local function isKeybindPressed(keybind, input)
	if not keybind then return false end
	if keybind.Type == "Keyboard" and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == keybind.Value then
		return true
	elseif keybind.Type == "MouseButton" and input.UserInputType == keybind.Value then
		return true
	end
	return false
end

local function isKeybindDown(keybind)
	if not keybind then return false end
	if keybind.Type == "Keyboard" then
		return UserInputService:IsKeyDown(keybind.Value)
	elseif keybind.Type == "MouseButton" then
		return UserInputService:IsMouseButtonPressed(keybind.Value)
	end
	return false
end

-- Main Loop
RunService.RenderStepped:Connect(function(dt)
	if not character or not rootPart then return end
	local cf = camera.CFrame
	if viewActive then camera.CameraType = Enum.CameraType.Follow return end
	local movement = nil
	if aimlockActive then
		local t = lockedTarget or getTargetInFOV()
		if t then
			if aimlockToggleMode then if aimlockLocked then lockedTarget = t else lockedTarget = nil end else lockedTarget = isKeybindDown(keybinds.Aimlock) and t or nil end
			if lockedTarget then
				local tp = predictionActive and predictTargetPosition(lockedTarget, dt) or lockedTarget.Position
				local tc = CFrame.new(cf.Position, tp)
				if not silentAimActive then camera.CFrame = tc end
			end
		else
			if not aimlockToggleMode then lockedTarget = nil end
		end
	end
	if showFOVCone and fovCone then fovCone.Position = UDim2.new(0.5, -aimlockFOV, 0.5, -aimlockFOV) end
	if speedActive then
		movement = movement or getMovement(cf, false)
		if movement.Magnitude > 0 then
			local mxz = Vector3.new(movement.X, 0, movement.Z).Unit * speedValue * dt
			rootPart.CFrame = CFrame.new(rootPart.Position + mxz) * rootPart.CFrame.Rotation
		end
	end
	if flyActive and bodyVelocity and bodyGyro then
		movement = movement or getMovement(cf, true)
		bodyVelocity.Velocity = movement.Magnitude > 0 and movement.Unit * flySpeedValue or Vector3.new()
		bodyGyro.CFrame = cf
	end
	if freeCamActive then
		movement = movement or getMovement(cf, true)
		if movement.Magnitude > 0 then freeCamPosition = clampPosition(freeCamPosition + movement.Unit * freeCamSpeed * freeCamBoost * dt) end
		camera.CFrame = CFrame.new(freeCamPosition) * CFrame.Angles(0, freeCamYaw, 0) * CFrame.Angles(freeCamPitch, 0, 0)
	end
	if noclipActive then for _, p in pairs(character:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end
	if timeLocked then Lighting.ClockTime = sliderValues["Time"] or originalSettings.ClockTime end
	if character and character.Humanoid then for _, track in pairs(character.Humanoid:GetPlayingAnimationTracks()) do track:AdjustSpeed(animationSpeedMultiplier) end end
end)

-- Infinite Jump
UserInputService.JumpRequest:Connect(function() if infiniteJumpEnabled and character and humanoid then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end end)

-- Character Update
local function updateCharacter(c)
	if not c then return end
	character = c
	rootPart = c:WaitForChild("HumanoidRootPart", 3)
	humanoid = c:WaitForChild("Humanoid", 3)
	if not rootPart then return end
	task.wait(0.5)
	local Animate = character:FindFirstChild("Animate")
	if Animate then
		local function getAnimId(folderName, animName)
			local folder = Animate:FindFirstChild(folderName)
			if folder then
				local anim = folder:FindFirstChild(animName)
				if anim then return anim.AnimationId end
			end
			return nil
		end
		defaultAnimations["Idle"] = getAnimId("idle", "Animation1")
		defaultAnimations["Walk"] = getAnimId("walk", "WalkAnim")
		defaultAnimations["Run"] = getAnimId("run", "RunAnim")
		defaultAnimations["Jump"] = getAnimId("jump", "JumpAnim")
		defaultAnimations["Fall"] = getAnimId("fall", "FallAnim")
		defaultAnimations["Climb"] = getAnimId("climb", "ClimbAnim")
		local swimFolder = Animate:FindFirstChild("swim")
		if swimFolder then
			local swimAnim = swimFolder:FindFirstChild("SwimAnim") or swimFolder:FindFirstChildOfClass("Animation")
			if swimAnim then defaultAnimations["Swim"] = swimAnim.AnimationId end
		end
	end
	if flyActive then
		humanoid.PlatformStand = true
		bodyVelocity = bodyVelocity or Instance.new("BodyVelocity")
		bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		bodyVelocity.Velocity = Vector3.new()
		bodyVelocity.Parent = rootPart
		bodyGyro = bodyGyro or Instance.new("BodyGyro")
		bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
		bodyGyro.P = 20000
		bodyGyro.D = 100
		bodyGyro.Parent = rootPart
	end
	if espActive then updateESP() end
end
player.CharacterAdded:Connect(updateCharacter)
if player.Character then updateCharacter(player.Character) end

-- GUI Dragging
local d, ds, spos
header.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then d = true ds = i.Position spos = mainFrame.Position end end)
UserInputService.InputChanged:Connect(function(i) if d and i.UserInputType == Enum.UserInputType.MouseMovement then local delta = i.Position - ds mainFrame.Position = UDim2.new(spos.X.Scale, spos.X.Offset + delta.X, spos.Y.Scale, spos.Y.Offset + delta.Y) end end)
UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then d = false end end)

-- Menu Toggle
local r = false
local function toggleMenu() mainFrame.Visible = not mainFrame.Visible end
UserInputService.InputBegan:Connect(function(i, gp)
	if gp then return end
	if keybinds.Menu and isKeybindPressed(keybinds.Menu, i) then toggleMenu()
	elseif keybinds.ESP and isKeybindPressed(keybinds.ESP, i) then et(not espActive)
	elseif keybinds.FreeCam and isKeybindPressed(keybinds.FreeCam, i) then fct(not freeCamActive)
	elseif keybinds.Aimlock and isKeybindPressed(keybinds.Aimlock, i) and aimlockActive then
		if aimlockToggleMode then aimlockLocked = not aimlockLocked else lockedTarget = getTargetInFOV() end
	elseif freeCamActive and i.UserInputType == Enum.UserInputType.MouseButton2 then r = true UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	elseif i.KeyCode == Enum.KeyCode.LeftShift or i.KeyCode == Enum.KeyCode.RightShift then freeCamBoost = 2
	elseif silentAimActive and i.UserInputType == Enum.UserInputType.MouseButton1 then
		local currentTarget = getTargetInFOV()
		if currentTarget then
			local mp = UserInputService:GetMouseLocation()
			local nextTarget, md = nil, math.huge
			for _, p in pairs(cachedPlayers) do
				if p ~= player and p ~= Players:GetPlayerFromCharacter(currentTarget.Parent) then
					local part = p.Character and p.Character:FindFirstChild(aimlockTargetPart == "Head" and "Head" or "HumanoidRootPart")
					if part then
						local pp, os = camera:WorldToViewportPoint(part.Position)
						if os then
							local d = (Vector2.new(pp.X, pp.Y) - mp).Magnitude
							if d <= aimlockFOV and d < md then nextTarget = part md = d end
						end
					end
				end
			end
			if nextTarget then lockedTarget = nextTarget local tp = predictionActive and predictTargetPosition(nextTarget, 0.1) or nextTarget.Position end
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if keybinds.Speed and isKeybindPressed(keybinds.Speed, input) then
		for _, c in pairs(toggleCallbacks["Speed"] or {}) do c(not toggleStates["Speed"]) end
	elseif keybinds.Fly and isKeybindPressed(keybinds.Fly, input) then
		for _, c in pairs(toggleCallbacks["Fly"] or {}) do c(not toggleStates["Fly"]) end
	end
end)
UserInputService.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton2 then r = false UserInputService.MouseBehavior = Enum.MouseBehavior.Default end
	if i.KeyCode == Enum.KeyCode.LeftShift or i.KeyCode == Enum.KeyCode.RightShift then freeCamBoost = 1 end
	if keybinds.Aimlock and isKeybindPressed(keybinds.Aimlock, i) and not aimlockToggleMode then lockedTarget = nil end
end)
UserInputService.InputChanged:Connect(function(i)
	if r and i.UserInputType == Enum.UserInputType.MouseMovement and not lockedTarget then
		freeCamYaw = freeCamYaw - i.Delta.X * freeCamSensitivity
		freeCamPitch = math.clamp(freeCamPitch - i.Delta.Y * freeCamSensitivity, -math.pi / 2, math.pi / 2)
	end
end)

-- Click Teleport
local m = player:GetMouse()
m.Button1Down:Connect(function()
	if clickTeleportActive and keybinds.ClickTeleport and isKeybindDown(keybinds.ClickTeleport) and rootPart then
		local targetPos = m.Hit.Position + Vector3.new(0, 3, 0)
		local cameraLook = camera.CFrame.LookVector
		local yaw = math.atan2(-cameraLook.X, -cameraLook.Z)
		rootPart.CFrame = CFrame.new(targetPos) * CFrame.Angles(0, yaw, 0)
	end
end)
