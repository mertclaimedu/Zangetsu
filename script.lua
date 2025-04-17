-- Group services into a table
local Services = {
	Players = game:GetService("Players"),
	Lighting = game:GetService("Lighting"),
	TweenService = game:GetService("TweenService"),
	UserInputService = game:GetService("UserInputService"),  
	RunService = game:GetService("RunService")
}

-- Group player-related data
local PlayerData = {
	player = Services.Players.LocalPlayer,
	camera = workspace.CurrentCamera,
	character = nil,
	rootPart = nil,
	humanoid = nil
}

-- Group original settings
local OriginalSettings = {
	MaxZoom = PlayerData.player.CameraMaxZoomDistance,
	FOV = PlayerData.camera.FieldOfView,
	ClockTime = Services.Lighting.ClockTime,
	Materials = {},
	Transparency = {}
}

-- Group effects
local Effects = {
	colorCorrection = Services.Lighting:FindFirstChild("CustomColorCorrection") or Instance.new("ColorCorrectionEffect", Services.Lighting)
}
Effects.colorCorrection.Name = "CustomColorCorrection"

-- Store default animations for fallback
local DefaultAnimations = {
	idle1 = "",
	idle2 = "",
	walk = "",
	run = "",
	jump = "",
	climb = "",
	fall = "",
	swimAnim = "",
	swimIdle = ""
}

-- Group state variables
local States = {
	aimlockActive = false,
	espActive = false,
	viewTarget = nil,
	wallhackActive = false,
	lowTextureActive = false,
	silentAimActive = false,
	predictionActive = false,
	aimlockToggleMode = false,
	aimlockLocked = false,
	espHighlights = {},
	espNames = {},
	espBoxes = {},
	espTracers = {},
	keybinds = {
		Menu = Enum.KeyCode.G,
		Aimlock = Enum.KeyCode.Q,
		ESP = Enum.KeyCode.J,
		ClickTeleport = Enum.KeyCode.E,
		Fly = Enum.KeyCode.X,
		FreeCam = Enum.KeyCode.P,
		Speed = Enum.KeyCode.C
	},
	aimlockFOV = 150,
	showFOVCone = false,
	fovCone = nil,
	cframeSpeedValue = 300,
	flySpeedValue = 300,
	freeCamSpeed = 200,
	cframeSpeedActive = false,
	flyActive = false,
	freeCamActive = false,
	noclipActive = false,
	clickTeleportActive = false,
	freeCamPosition = nil,
	freeCamYaw = 0,
	freeCamPitch = 0,
	freeCamSensitivity = 0.01,
	freeCamBoost = 1,
	lockedTarget = nil,
	targetedPlayer = nil,
	targetActive = false,
	aimlockTargetPart = "Head",
	animationStages = {
		idle = {name = "Idle", id = ""},
		run = {name = "Run", id = ""},
		walk = {name = "Walk", id = ""},
		jump = {name = "Jump", id = ""},
		fall = {name = "Fall", id = ""},
		climb = {name = "Climb", id = ""},
		swim = {name = "Swim", id = ""}
	},
	selectedAnimStage = nil,
	lastSelectedPreset = nil,
	menuTransparency = 0.1,
	espBoxActive = false,
	espTracerActive = false,
	bodyVelocity = nil,
	bodyGyro = nil
}

-- Group colors
local Colors = {
	Background = Color3.fromRGB(30, 30, 30),
	Header = Color3.fromRGB(40, 40, 40),
	Text = Color3.fromRGB(220, 220, 220),
	Button = Color3.fromRGB(50, 50, 50),
	Interface = Color3.fromRGB(70, 0, 140),
	ToggleOn = Color3.fromRGB(70, 0, 140),
	ToggleOff = Color3.fromRGB(50, 50, 50),
	Outline = Color3.fromRGB(70, 70, 70),
	ESP = Color3.fromRGB(110, 70, 200),
	KeybindsBG = Color3.fromRGB(35, 35, 35),
	TabSelected = Color3.fromRGB(70, 0, 140),
	TabUnselected = Color3.fromRGB(40, 40, 40)
}

-- Group UI states
local UIStates = {
	sliderValues = {},
	toggleStates = {}
}

-- Group cached data
local CachedData = {
	cachedPlayers = Services.Players:GetPlayers(),
	seenPlayers = {},
	ScriptWhitelist = {},
	httprequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
}

-- Helper functions
local function create(class, props)
	local inst = Instance.new(class)
	for k, v in pairs(props) do inst[k] = v end
	return inst
end

local function getMovement(cf, vert)
	local dir = Vector3.new()
	if Services.UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector end
	if Services.UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector end
	if Services.UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
	if Services.UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
	if vert then
		if Services.UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.yAxis end
		if Services.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.yAxis end
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
		local hum = PlayerData.humanoid
		local animtrack = hum:GetPlayingAnimationTracks()
		for _, track in pairs(animtrack) do track:Stop() end
		local Anim = Instance.new("Animation")
		Anim.AnimationId = "rbxassetid://" .. id
		local loadanim = hum:LoadAnimation(Anim)
		loadanim:Play()
		loadanim.TimePosition = time
		loadanim:AdjustSpeed(speed)
		loadanim.Stopped:Connect(function()
			for _, track in pairs(animtrack) do track:Stop() end
		end)
	end)
end

local function StopAnim()
	local animtrack = PlayerData.humanoid:GetPlayingAnimationTracks()
	for _, track in pairs(animtrack) do track:Stop() end
end

-- Initialize GUI
local gui = create("ScreenGui", {Name = "Settings", ResetOnSpawn = false, IgnoreGuiInset = true, Parent = PlayerData.player:WaitForChild("PlayerGui")})
local mainFrame = create("Frame", {Size = UDim2.new(0, 419, 0, 520), Position = UDim2.new(0.5, -210, 0.5, -260), BackgroundColor3 = Colors.Background, BackgroundTransparency = States.menuTransparency, Visible = false, Parent = gui})
create("UICorner", {CornerRadius = UDim.new(0, 12), Parent = mainFrame})
create("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(20, 20, 40), Color3.fromRGB(50, 50, 80)), Rotation = 45, Parent = mainFrame})
local header = create("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Colors.Header, Parent = mainFrame})
create("UICorner", {CornerRadius = UDim.new(0, 12), Parent = header})
create("TextLabel", {Size = UDim2.new(0.7, 0, 0, 40), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = "Settings", TextColor3 = Colors.Text, TextSize = 28, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = header})
local tabFrame = create("Frame", {Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 40), BackgroundTransparency = 1, Parent = mainFrame})
create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 5), Parent = tabFrame})
local tabs, tabContents = {}, {}
local function addTab(name, w)
	local btn = create("TextButton", {Size = UDim2.new(0, w or 80, 0, 25), BackgroundColor3 = Colors.TabUnselected, Text = name, TextColor3 = Colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, Parent = tabFrame})
	create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = btn})
	local cont = create("ScrollingFrame", {Size = UDim2.new(1, -18, 1, -70), Position = UDim2.new(0, 9, 0, 70), BackgroundTransparency = 1, ScrollBarThickness = 0, CanvasSize = UDim2.new(0, 0, 0, 0), Visible = false, Parent = mainFrame})
	tabs[name] = btn
	tabContents[name] = cont
	btn.MouseButton1Click:Connect(function()
		for tName, t in pairs(tabs) do t.BackgroundColor3 = tName == name and Colors.TabSelected or Colors.TabUnselected end
		for _, c in pairs(tabContents) do c.Visible = false end
		cont.Visible = true
	end)
	return cont
end
local visualsTab = addTab("Visuals")
local playerTab = addTab("Player")
local combatTab = addTab("Combat")
local targetTab = addTab("Target")
local animationsTab = addTab("Animations")
local keybindsFrame = create("Frame", {Size = UDim2.new(0, 200, 0, 520), Position = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Colors.KeybindsBG, BackgroundTransparency = States.menuTransparency, Visible = false, Parent = mainFrame})
create("UICorner", {CornerRadius = UDim.new(0, 12), Parent = keybindsFrame})
create("UIGradient", {Color = ColorSequence.new(Colors.KeybindsBG, Colors.Header), Rotation = 45, Parent = keybindsFrame})
local keybindsScroll = create("ScrollingFrame", {Size = UDim2.new(1, -10, 1, -10), Position = UDim2.new(0, 5, 0, 5), BackgroundTransparency = 1, ScrollBarThickness = 0, CanvasSize = UDim2.new(0, 0, 0, 400), Parent = keybindsFrame})
local function toggleKeybindsFrame() keybindsFrame.Visible = not keybindsFrame.Visible end
create("ImageButton", {Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(1, -34, 0, 8), BackgroundTransparency = 1, Image = "rbxassetid://6023565895", ImageColor3 = Colors.Text, Parent = header}).MouseButton1Click:Connect(toggleKeybindsFrame)

local toggleCallbacks = {}
local function addToggle(name, def, y, cb, parent)
	UIStates.toggleStates[name] = def
	local f = create("Frame", {Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, y), BackgroundTransparency = 1, Parent = parent})
	create("TextLabel", {Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.new(0, 5, 0, 0), BackgroundTransparency = 1, Text = name, TextColor3 = Colors.Text, TextSize = 16, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = f})
	local tf = create("Frame", {Size = UDim2.new(0, 40, 0, 20), Position = UDim2.new(0.85, -20, 0.5, -10), BackgroundColor3 = def and Colors.ToggleOn or Colors.ToggleOff, Parent = f})
	create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = tf})
	toggleCallbacks[name] = toggleCallbacks[name] or {}
	table.insert(toggleCallbacks[name], function(s)
		UIStates.toggleStates[name] = s
		tf.BackgroundColor3 = s and Colors.ToggleOn or Colors.ToggleOff
		cb(s)
	end)
	local function upd(s) for _, c in pairs(toggleCallbacks[name]) do c(s) end end
	tf.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then upd(not UIStates.toggleStates[name]) end end)
	return f, upd
end

local sliderCallbacks = {}
local function addSlider(name, min, max, def, y, cb, parent, nl, nd)
	UIStates.sliderValues[name] = def
	local f = create("Frame", {Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, y), BackgroundTransparency = 1, Parent = parent})
	local l = nl and nil or create("TextLabel", {Size = UDim2.new(0, 180, 1, 0), Position = UDim2.new(0, 5, 0, 0), BackgroundTransparency = 1, Text = nd and string.format("%s: %d", name, def) or string.format("%s: %.1f", name, def), TextColor3 = Colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = f})
	local sf = create("Frame", {Size = nl and UDim2.new(0.95, 0, 0, 12) or UDim2.new(0, 200, 0, 12), Position = nl and UDim2.new(0.025, 0, 0.5, -6) or UDim2.new(0, 170, 0.5, -6), BackgroundColor3 = Colors.Button, Parent = f})
	create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = sf})
	local fill = create("Frame", {Size = UDim2.new((def - min) / (max - min), 0, 1, 0), BackgroundColor3 = Colors.Interface, Parent = sf})
	create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = fill})
	sliderCallbacks[name] = sliderCallbacks[name] or {}
	table.insert(sliderCallbacks[name], function(v)
		UIStates.sliderValues[name] = v
		fill.Size = UDim2.new((v - min) / (max - min), 0, 1, 0)
		if l then l.Text = nd and string.format("%s: %d", name, math.floor(v)) or string.format("%s: %.1f", name, v) end
		cb(v)
	end)
	local d = false
	sf.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then d = true end end)
	Services.UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then d = false end end)
	Services.UserInputService.InputChanged:Connect(function(i)
		if d and i.UserInputType == Enum.UserInputType.MouseMovement then
			local p = math.clamp((i.Position.X - sf.AbsolutePosition.X) / sf.AbsoluteSize.X, 0, 1)
			local v = min + (max - min) * p
			for _, c in pairs(sliderCallbacks[name]) do c(v) end
		end
	end)
	return f
end

local buttonCallbacks = {}
local function addButton(name, x, y, cb, parent, ts, w, textUpdater)
	local b = create("TextButton", {Size = UDim2.new(0, w or 80, 0, 25), Position = UDim2.new(0, x, 0, y), BackgroundColor3 = ts and Colors.ToggleOn or Colors.ToggleOff, Text = name, TextColor3 = Colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, Parent = parent})
	create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = b})
	local s = ts or false
	textUpdater = textUpdater or function(b, s, name) b.Text = name end
	buttonCallbacks[name] = buttonCallbacks[name] or {}
	table.insert(buttonCallbacks[name], function(state)
		s = state
		b.BackgroundColor3 = s and Colors.ToggleOn or Colors.ToggleOff
		textUpdater(b, s, name)
		cb(s)
	end)
	local function upd(ns) for _, c in pairs(buttonCallbacks[name]) do c(ns) end end
	b.MouseButton1Click:Connect(function() upd(not s) end)
	textUpdater(b, s, name)
	return b, upd
end

local function addActionButton(name, x, y, cb, parent, w)
	local b = create("TextButton", {Size = UDim2.new(0, w or 80, 0, 25), Position = UDim2.new(0, x, 0, y), BackgroundColor3 = Colors.Button, Text = name, TextColor3 = Colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, Parent = parent})
	create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = b})
	b.MouseButton1Click:Connect(cb)
	return b
end

local function addKeybind(name, def, y)
	local f = create("Frame", {Size = UDim2.new(1, -10, 0, 30), Position = UDim2.new(0, 5, 0, y), BackgroundTransparency = 1, Parent = keybindsScroll})
	create("TextLabel", {Size = UDim2.new(0.6, 0, 1, 0), BackgroundTransparency = 1, Text = name, TextColor3 = Colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = f})
	local b = create("TextButton", {Size = UDim2.new(0, 60, 0, 20), Position = UDim2.new(1, -65, 0.5, -10), BackgroundColor3 = Colors.Button, Text = def and (def:IsA("KeyCode") and def.Name or (def == Enum.UserInputType.MouseButton1 and "Left Click" or def == Enum.UserInputType.MouseButton2 and "Right Click" or "Middle Click")) or "None", TextColor3 = Colors.Text, TextSize = 12, Font = Enum.Font.FredokaOne, Parent = f})
	create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = b})
	b.MouseButton1Click:Connect(function()
		b.Text = "Press..."
		local c
		c = Services.UserInputService.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.Keyboard then
				if i.KeyCode == Enum.KeyCode.Escape then
					States.keybinds[name] = nil
					b.Text = "None"
				else
					States.keybinds[name] = i.KeyCode
					b.Text = i.KeyCode.Name
				end
			elseif i.UserInputType == Enum.UserInputType.MouseButton1 then
				States.keybinds[name] = Enum.UserInputType.MouseButton1
				b.Text = "Left Click"
			elseif i.UserInputType == Enum.UserInputType.MouseButton2 then
				States.keybinds[name] = Enum.UserInputType.MouseButton2
				b.Text = "Right Click"
			elseif i.UserInputType == Enum.UserInputType.MouseButton3 then
				States.keybinds[name] = Enum.UserInputType.MouseButton3
				b.Text = "Middle Click"
			end
			c:Disconnect()
		end)
	end)
end

local function addVoiceChatUnban(y, p)
	local f = create("Frame", {Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, y), BackgroundTransparency = 1, Parent = p})
	create("TextLabel", {Size = UDim2.new(0.7, 0, 1, 0), Position = UDim2.new(0, 5, 0, 0), BackgroundTransparency = 1, Text = "VC Unban", TextColor3 = Colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = f})
	local b = create("TextButton", {Size = UDim2.new(0, 60, 0, 20), Position = UDim2.new(0.85, -16, 0.5, -10), BackgroundColor3 = Colors.Interface, Text = "Start", TextColor3 = Colors.Text, TextSize = 12, Font = Enum.Font.FredokaOne, Parent = f})
	create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = b})
	b.MouseButton1Click:Connect(function()
		pcall(function() game:GetService("VoiceChatService"):joinVoice() end)
		b.Text = "Done"
		b.BackgroundColor3 = Colors.ToggleOn
		b.Active = false
	end)
end

local function predictTargetPosition(tp, dt)
	local vel = tp.Velocity or Vector3.new()
	return tp.Position + vel * dt * math.clamp(vel.Magnitude / 50, 0.5, 2)
end

local function getTargetInFOV()
	local mp = Services.UserInputService:GetMouseLocation()
	local c, md = nil, math.huge
	if States.targetedPlayer and States.targetedPlayer.Character then
		local p = States.targetedPlayer.Character:FindFirstChild(States.aimlockTargetPart == "Head" and "Head" or "HumanoidRootPart")
		if p then
			local pp, os = PlayerData.camera:WorldToViewportPoint(p.Position)
			if os and (Vector2.new(pp.X, pp.Y) - mp).Magnitude <= States.aimlockFOV then
				return p
			end
		end
	end
	for _, p in pairs(CachedData.cachedPlayers) do
		if p ~= PlayerData.player then
			local part = p.Character and p.Character:FindFirstChild(States.aimlockTargetPart == "Head" and "Head" or "HumanoidRootPart")
			if part then
				local pp, os = PlayerData.camera:WorldToViewportPoint(part.Position)
				if os then
					local d = (Vector2.new(pp.X, pp.Y) - mp).Magnitude
					if d <= States.aimlockFOV and d < md then
						c = part
						md = d
					end
				end
			end
		end
	end
	return c
end

-- Updates ESP visuals for other players
local function updateESP()
	if not States.espActive then
		for p, h in pairs(States.espHighlights) do if h then h:Destroy() end States.espHighlights[p] = nil end
		for p, n in pairs(States.espNames) do if n then n:Destroy() end States.espNames[p] = nil end
		for p, b in pairs(States.espBoxes) do if b then b:Destroy() end States.espBoxes[p] = nil end
		for p, t in pairs(States.espTracers) do if t then t:Destroy() end States.espTracers[p] = nil end
		return
	end
	local currentPlayers = {}
	for _, p in pairs(Services.Players:GetPlayers()) do
		if p ~= PlayerData.player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			currentPlayers[p] = true
			if not States.espHighlights[p] then
				local h = Instance.new("Highlight")
				h.FillColor = Colors.ESP
				h.FillTransparency = 0.7
				h.OutlineColor = Colors.ESP
				h.OutlineTransparency = 0
				h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				h.Parent = p.Character
				States.espHighlights[p] = h
			end
			if not States.espNames[p] then
				local ng = create("BillboardGui", {Size = UDim2.new(0, 100, 0, 50), StudsOffset = Vector3.new(0, 3, 0), Adornee = p.Character:WaitForChild("Head"), AlwaysOnTop = true, Parent = p.Character})
				create("TextLabel", {Size = UDim2.new(1, 0, 1, 0), Text = p.Name, TextColor3 = Colors.ESP, TextSize = 14, BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, Parent = ng})
				States.espNames[p] = ng
			end
			if States.espBoxActive and not States.espBoxes[p] then
				local b = Instance.new("BoxHandleAdornment")
				b.Size = Vector3.new(5, 5, 5)
				b.Color3 = Colors.ESP
				b.Transparency = 0.7
				b.AlwaysOnTop = true
				b.Adornee = p.Character.HumanoidRootPart
				b.Parent = p.Character
				States.espBoxes[p] = b
			end
			if States.espTracerActive and PlayerData.rootPart and not States.espTracers[p] then
				local t = Instance.new("Beam")
				t.Color = ColorSequence.new(Colors.ESP)
				t.Width0 = 0.2
				t.Width1 = 0.2
				t.Transparency = NumberSequence.new(0.3)
				t.Attachment0 = create("Attachment", {Parent = PlayerData.rootPart})
				t.Attachment1 = create("Attachment", {Parent = p.Character.HumanoidRootPart})
				t.Parent = PlayerData.rootPart
				States.espTracers[p] = t
			end
			if States.espHighlights[p] then States.espHighlights[p].Enabled = true end
			if States.espNames[p] then States.espNames[p].Enabled = true end
			if States.espBoxes[p] then States.espBoxes[p].Visible = States.espBoxActive end
			if States.espTracers[p] then States.espTracers[p].Enabled = States.espTracerActive end
		end
	end
	for p in pairs(States.espHighlights) do
		if not currentPlayers[p] then
			if States.espHighlights[p] then States.espHighlights[p]:Destroy() end
			if States.espNames[p] then States.espNames[p]:Destroy() end
			if States.espBoxes[p] then States.espBoxes[p]:Destroy() end
			if States.espTracers[p] then States.espTracers[p]:Destroy() end
			States.espHighlights[p] = nil
			States.espNames[p] = nil
			States.espBoxes[p] = nil
			States.espTracers[p] = nil
		end
	end
end

Services.Players.PlayerAdded:Connect(function(p)
	CachedData.cachedPlayers = Services.Players:GetPlayers()
	if States.espActive then updateESP() end
end)

Services.Players.PlayerRemoving:Connect(function(p)
	CachedData.cachedPlayers = Services.Players:GetPlayers()
	if States.espHighlights[p] then
		States.espHighlights[p]:Destroy() States.espHighlights[p] = nil
		if States.espNames[p] then States.espNames[p]:Destroy() States.espNames[p] = nil end
		if States.espBoxes[p] then States.espBoxes[p]:Destroy() States.espBoxes[p] = nil end
		if States.espTracers[p] then States.espTracers[p]:Destroy() States.espTracers[p] = nil end
	end
end)

task.spawn(function()
	while true do
		if States.espActive then updateESP() end
		task.wait(5)
	end
end)

addSlider("Saturation", -1, 2, 0, 0, function(v) if v ~= Effects.colorCorrection.Saturation then Effects.colorCorrection.Saturation = v end end, visualsTab, false, false)
addSlider("FOV", 30, 120, 70, 40, function(v) if v ~= PlayerData.camera.FieldOfView then PlayerData.camera.FieldOfView = v end end, visualsTab, false, true)
addSlider("Time", 0, 24, OriginalSettings.ClockTime, 80, function(v) Services.Lighting.ClockTime = v end, visualsTab, false, false)
local ef, et = addToggle("ESP", false, 120, function(on) States.espActive = on updateESP() end, visualsTab)
local cb = create("TextButton", {Size = UDim2.new(0, 50, 0, 20), Position = UDim2.new(0.55, 0, 0, 10), BackgroundColor3 = Colors.ESP, Text = "Color", TextColor3 = Colors.Text, TextSize = 12, Font = Enum.Font.FredokaOne, Parent = ef})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = cb})
local function boxTextUpdater(b, s) b.Text = s and "Unbox" or "Box" end
local boxBtn, boxToggle = addButton("Box", 40, 125, function(s) States.espBoxActive = s updateESP() end, visualsTab, false, 60, boxTextUpdater)
local function tracerTextUpdater(b, s) b.Text = s and "Untrace" or "Trace" end
local tracerBtn, tracerToggle = addButton("Trace", 110, 125, function(s) States.espTracerActive = s updateESP() end, visualsTab, false, 60, tracerTextUpdater)
addToggle("Infinite Zoom", false, 160, function(on) PlayerData.player.CameraMaxZoomDistance = on and 1000000 or OriginalSettings.MaxZoom end, visualsTab)
addToggle("Wallhack", false, 200, function(on)
	States.wallhackActive = on
	if on then
		for _, v in pairs(workspace:GetDescendants()) do
			if v:IsA("BasePart") then
				if not OriginalSettings.Transparency[v] then OriginalSettings.Transparency[v] = v.Transparency end
				v.Transparency = 0.7
			end
		end
	else
		for p, t in pairs(OriginalSettings.Transparency) do
			if p.Parent then p.Transparency = t else OriginalSettings.Transparency[p] = nil end
		end
	end
end, visualsTab)
addToggle("Low Texture", false, 240, function(on)
	States.lowTextureActive = on
	if on then
		for _, v in pairs(workspace:GetDescendants()) do
			if v:IsA("BasePart") then
				if not OriginalSettings.Materials[v] then OriginalSettings.Materials[v] = v.Material end
				v.Material = Enum.Material.SmoothPlastic
			end
		end
	else
		for p, m in pairs(OriginalSettings.Materials) do
			if p.Parent then p.Material = m else OriginalSettings.Materials[p] = nil end
		end
	end
end, visualsTab)
visualsTab.CanvasSize = UDim2.new(0, 0, 0, 290)

local csf, cst
local ff, flyToggle
-- Speed toggle (formerly CFrameSpeed)
csf, cst = addToggle("Speed", false, 0, function(on)
	if not PlayerData.rootPart then return end
	States.cframeSpeedActive = on
	if on and States.flyActive then flyToggle(false) end
end, playerTab)
local csi = create("TextBox", {Size = UDim2.new(0.15, 0, 0, 20), Position = UDim2.new(0.6, 0, 0.5, -10), BackgroundColor3 = Colors.Button, Text = tostring(States.cframeSpeedValue), TextColor3 = Colors.Text, TextSize = 12, Font = Enum.Font.FredokaOne, ClearTextOnFocus = false, Parent = csf})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = csi})
csi.FocusLost:Connect(function(e)
	if e then
		local v = tonumber(csi.Text)
		if v then States.cframeSpeedValue = math.clamp(v, 50, 50000) end
	end
end)
-- Fly toggle
ff, flyToggle = addToggle("Fly", false, 40, function(on)
	if not PlayerData.rootPart or not PlayerData.humanoid then return end
	States.flyActive = on
	if on and States.cframeSpeedActive then cst(false) end
	PlayerData.humanoid.PlatformStand = on
	if on then
		States.bodyVelocity = States.bodyVelocity or Instance.new("BodyVelocity")
		States.bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		States.bodyVelocity.Velocity = Vector3.new()
		States.bodyVelocity.Parent = PlayerData.rootPart
		States.bodyGyro = States.bodyGyro or Instance.new("BodyGyro")
		States.bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
		States.bodyGyro.P = 20000
		States.bodyGyro.D = 100
		States.bodyGyro.Parent = PlayerData.rootPart
	else
		if States.bodyVelocity then States.bodyVelocity:Destroy() States.bodyVelocity = nil end
		if States.bodyGyro then States.bodyGyro:Destroy() States.bodyGyro = nil end
	end
end, playerTab)
local fsi = create("TextBox", {Size = UDim2.new(0.15, 0, 0, 20), Position = UDim2.new(0.6, 0, 0.5, -10), BackgroundColor3 = Colors.Button, Text = tostring(States.flySpeedValue), TextColor3 = Colors.Text, TextSize = 12, Font = Enum.Font.FredokaOne, ClearTextOnFocus = false, Parent = ff})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = fsi})
fsi.FocusLost:Connect(function(e)
	if e then
		local v = tonumber(fsi.Text)
		if v then States.flySpeedValue = math.clamp(v, 50, 50000) end
	end
end)
local fcf, fct = addToggle("Free Cam", false, 80, function(on)
	if not PlayerData.character or not PlayerData.rootPart then return end
	States.freeCamActive = on
	if on then
		PlayerData.rootPart.Anchored = true
		if PlayerData.humanoid then PlayerData.humanoid.WalkSpeed = 0 end
		PlayerData.camera.CameraType = Enum.CameraType.Scriptable
		States.freeCamPosition = PlayerData.camera.CFrame.Position
		States.freeCamPitch, States.freeCamYaw = PlayerData.camera.CFrame:ToEulerAnglesYXZ()
		Services.UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	else
		PlayerData.rootPart.Anchored = false
		if PlayerData.humanoid then PlayerData.humanoid.WalkSpeed = 16 end
		PlayerData.camera.CameraType = Enum.CameraType.Custom
		PlayerData.camera.CameraSubject = PlayerData.character.Humanoid
		Services.UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end, playerTab)
local fcsi = create("TextBox", {Size = UDim2.new(0.15, 0, 0, 20), Position = UDim2.new(0.6, 0, 0.5, -10), BackgroundColor3 = Colors.Button, Text = tostring(States.freeCamSpeed), TextColor3 = Colors.Text, TextSize = 12, Font = Enum.Font.FredokaOne, ClearTextOnFocus = false, Parent = fcf})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = fcsi})
fcsi.FocusLost:Connect(function(e)
	if e then
		local v = tonumber(fcsi.Text)
		if v then States.freeCamSpeed = math.clamp(v, 50, 50000) end
	end
end)
addToggle("Noclip", false, 120, function(on) States.noclipActive = on end, playerTab)
addToggle("Click Teleport", false, 160, function(on) States.clickTeleportActive = on end, playerTab)
addVoiceChatUnban(200, playerTab)
local antiFlingActive = false
local antiFlingBtn, antiFlingToggle = addToggle("Anti Fling", false, 240, function(on)
	antiFlingActive = on
	if on then
		Services.RunService.RenderStepped:Connect(function()
			if antiFlingActive and PlayerData.rootPart then
				local velocity = PlayerData.rootPart.Velocity
				if velocity.Magnitude > 500 then
					PlayerData.rootPart.Velocity = Vector3.new(0, velocity.Y, 0)
				end
			end
		end)
	end
end, playerTab)
local rejoinBtn = addActionButton("Rejoin", 10, 320, function()
	game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, PlayerData.player)
end, playerTab, 120)
local serverHopBtn = addActionButton("Server Hop", 140, 320, function()
	if CachedData.httprequest then
		local servers = {}
		local req = CachedData.httprequest({ Url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100", game.PlaceId) })
		local body = game:GetService("HttpService"):JSONDecode(req.Body)
		if body and body.data then
			for _, v in next, body.data do
				if type(v) == "table" and tonumber(v.playing) and tonumber(v.maxPlayers) and v.playing < v.maxPlayers and v.id ~= game.JobId then
					table.insert(servers, 1, v.id)
				end
			end
		end
		if #servers > 0 then
			game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], PlayerData.player)
		end
	end
end, playerTab, 120)
local jerkBtn = addActionButton("Jerk", 270, 320, function()
	if not PlayerData.character then return end
	local isR6 = PlayerData.character:FindFirstChild("Torso") ~= nil
	local scriptUrl = isR6 and "https://pastefy.app/wa3v2Vgm/raw" or "https://pastefy.app/YZoglOyJ/raw"
	local jerkScript = loadstring(game:HttpGet(scriptUrl))
	if jerkScript then jerkScript() end
end, playerTab, 120)
playerTab.CanvasSize = UDim2.new(0, 0, 0, 370)

local af, at = addToggle("Aimlock", false, 0, function(on) States.aimlockActive = on if not on then States.lockedTarget = nil States.aimlockLocked = false end end, combatTab)
local asf = create("Frame", {Size = UDim2.new(1, 0, 0, 200), Position = UDim2.new(0, 0, 0, 40), BackgroundTransparency = 1, Parent = combatTab})
local sb, st = addButton("Silent Aim", 0, 0, function(s) States.silentAimActive = s end, asf, false, 80)
local pb, pt = addButton("Prediction", 90, 0, function(s) States.predictionActive = s end, asf, false, 80)
local thb, tht = addButton("Toggle", 180, 0, function(s)
	States.aimlockToggleMode = s
	thb.Text = s and "Toggle" or "Hold"
	States.lockedTarget = nil
	States.aimlockLocked = false
end, asf, false, 80)
local hb, ht = addButton("Head", 270, 0, function(s)
	States.aimlockTargetPart = States.aimlockTargetPart == "Head" and "Torso" or "Head"
	States.lockedTarget = nil
	hb.Text = States.aimlockTargetPart
end, asf, true, 80)
local fovFrame = addSlider("Aimlock FOV", 30, 320, States.aimlockFOV, 35, function(v)
	States.aimlockFOV = v
	if States.fovCone then
		States.fovCone.Size = UDim2.new(0, v * 2, 0, v * 2)
		States.fovCone.Position = UDim2.new(0.5, -v, 0.5, -v)
	end
end, asf, false, true)
local fovLockBtn = create("ImageButton", {Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(0, 110, 0.5, -10), BackgroundColor3 = Colors.Button, Image = "rbxassetid://6023565895", ImageColor3 = Colors.Text, Parent = fovFrame})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = fovLockBtn})
fovLockBtn.MouseButton1Click:Connect(function()
	States.showFOVCone = not States.showFOVCone
	fovLockBtn.BackgroundColor3 = States.showFOVCone and Colors.ToggleOn or Colors.Button
	if not States.fovCone and States.showFOVCone then
		States.fovCone = create("Frame", {Size = UDim2.new(0, States.aimlockFOV * 2, 0, States.aimlockFOV * 2), Position = UDim2.new(0.5, -States.aimlockFOV, 0.5, -States.aimlockFOV), BackgroundTransparency = 0.7, BackgroundColor3 = Colors.Outline, BorderSizePixel = 0, Parent = gui})
		create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = States.fovCone})
	elseif States.fovCone and not States.showFOVCone then
		States.fovCone:Destroy()
		States.fovCone = nil
	end
	if States.fovCone then States.fovCone.Visible = States.showFOVCone end
end)
combatTab.CanvasSize = UDim2.new(0, 0, 0, 240)

local targetInputFrame = create("Frame", {Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1, Parent = targetTab})
local targetInput = create("TextBox", {Size = UDim2.new(0.7, 0, 1, 0), Position = UDim2.new(0, 5, 0, 0), BackgroundColor3 = Colors.Button, Text = "", TextColor3 = Colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, PlaceholderText = "Enter player name", ClearTextOnFocus = false, Parent = targetInputFrame})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = targetInput})
local clickTargetBtn = create("ImageButton", {Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(0.75, 0, 0, 5), BackgroundTransparency = 1, Image = "rbxassetid://2716591855", Parent = targetInputFrame})
local targetImage = create("ImageLabel", {Size = UDim2.new(0, 100, 0, 100), Position = UDim2.new(0, 10, 0, 50), BackgroundColor3 = Colors.Background, Image = "rbxassetid://10818605405", Parent = targetTab})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = targetImage})
local userInfoLabel = create("TextLabel", {Size = UDim2.new(0, 200, 0, 75), Position = UDim2.new(0, 120, 0, 50), BackgroundTransparency = 1, Text = "UserID: \nDisplay: \nJoined: ", TextColor3 = Colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = targetTab})

local predictionIndicator = nil
local targetPredictionFrame = create("Frame", {Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, 130), BackgroundTransparency = 1, Parent = targetTab})
create("TextLabel", {Size = UDim2.new(0.6, 0, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = "Target Prediction", TextColor3 = Colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = targetPredictionFrame})
local targetPredictionToggle, targetPredictionUpdate = addToggle("", false, 0, function(on)
	States.predictionActive = on
	States.targetActive = on
	if predictionIndicator then predictionIndicator:Destroy() predictionIndicator = nil end
	if on and States.targetedPlayer and States.targetedPlayer.Character then
		local targetRoot = States.targetedPlayer.Character:FindFirstChild("HumanoidRootPart")
		if targetRoot then
			predictionIndicator = Instance.new("Highlight")
			predictionIndicator.FillColor = Color3.fromRGB(255, 0, 0)
			predictionIndicator.OutlineColor = Color3.fromRGB(255, 0, 0)
			predictionIndicator.FillTransparency = 0.7
			predictionIndicator.OutlineTransparency = 0.3
			predictionIndicator.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			predictionIndicator.Adornee = States.targetedPlayer.Character
			predictionIndicator.Parent = States.targetedPlayer.Character
		end
	end
end, targetPredictionFrame)

local viewActive = false
local viewBtn, viewToggle = addButton("View", 10, 160, function(s)
	viewActive = s
	if s then
		if States.targetedPlayer and not table.find(CachedData.ScriptWhitelist, States.targetedPlayer.UserId) then
			if States.targetedPlayer.Character and States.targetedPlayer.Character:FindFirstChild("Humanoid") then
				PlayerData.camera.CameraSubject = States.targetedPlayer.Character.Humanoid
			end
		else
			notify("Skye", "Cannot view whitelisted player.", 5)
			viewToggle(false)
		end
	else
		PlayerData.camera.CameraSubject = PlayerData.character and PlayerData.character.Humanoid
	end
end, targetTab, false, 120)

local teleportBtn = addActionButton("Teleport", 140, 160, function()
	if States.targetedPlayer and not table.find(CachedData.ScriptWhitelist, States.targetedPlayer.UserId) then
		if States.targetedPlayer.Character and States.targetedPlayer.Character:FindFirstChild("HumanoidRootPart") then
			PlayerData.rootPart.CFrame = States.targetedPlayer.Character.HumanoidRootPart.CFrame + Vector3.new(0, 2, 0)
		end
	else
		notify("Skye", "Cannot teleport to whitelisted player.", 5)
	end
end, targetTab, 120)

local headsitActive = false
local headsitBtn, headsitToggle = addButton("Headsit", 10, 200, function(s)
	headsitActive = s
	if s then
		if States.targetedPlayer and not table.find(CachedData.ScriptWhitelist, States.targetedPlayer.UserId) then
			task.spawn(function()
				while headsitActive do
					if States.targetedPlayer and States.targetedPlayer.Character and States.targetedPlayer.Character:FindFirstChild("Head") then
						PlayerData.humanoid.Sit = true
						PlayerData.rootPart.CFrame = States.targetedPlayer.Character.Head.CFrame * CFrame.new(0, 2, 0)
						PlayerData.rootPart.Velocity = Vector3.new(0, 0, 0)
						task.wait()
					else
						task.wait()
					end
				end
			end)
		else
			notify("Skye", "Cannot headsit whitelisted player.", 5)
			headsitToggle(false)
		end
	end
end, targetTab, false, 120)

local standActive = false
local standBtn, standToggle = addButton("Stand", 140, 200, function(s)
	standActive = s
	if s then
		if States.targetedPlayer and not table.find(CachedData.ScriptWhitelist, States.targetedPlayer.UserId) then
			PlayAnim(13823324057, 4, 0)
			task.spawn(function()
				while standActive do
					if States.targetedPlayer and States.targetedPlayer.Character and States.targetedPlayer.Character:FindFirstChild("HumanoidRootPart") then
						PlayerData.rootPart.CFrame = States.targetedPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(-3, 1, 0)
						PlayerData.rootPart.Velocity = Vector3.new(0, 0, 0)
						task.wait()
					else
						task.wait()
					end
				end
				StopAnim()
			end)
		else
			notify("Skye", "Cannot stand on whitelisted player.", 5)
			standToggle(false)
		end
	end
end, targetTab, false, 120)

local bangActive = false
local bangBtn, bangToggle = addButton("Bang", 10, 240, function(s)
	bangActive = s
	if s then
		if States.targetedPlayer and not table.find(CachedData.ScriptWhitelist, States.targetedPlayer.UserId) then
			PlayAnim(5918726674, 0, 1)
			task.spawn(function()
				while bangActive do
					if States.targetedPlayer and States.targetedPlayer.Character and States.targetedPlayer.Character:FindFirstChild("HumanoidRootPart") then
						PlayerData.rootPart.CFrame = States.targetedPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 1.1)
						PlayerData.rootPart.Velocity = Vector3.new(0, 0, 0)
						task.wait()
					else
						task.wait()
					end
				end
				StopAnim()
			end)
		else
			notify("Skye", "Cannot bang whitelisted player.", 5)
			bangToggle(false)
		end
	end
end, targetTab, false, 120)

local flingActive = false
local flingVelocityTask
local flingOldPos
local flingBtn, flingToggle = addButton("Fling", 140, 240, function(s)
	if s then
		if States.targetedPlayer and not table.find(CachedData.ScriptWhitelist, States.targetedPlayer.UserId) then
			flingOldPos = PlayerData.rootPart.Position
			flingActive = true
			flingVelocityTask = task.spawn(function()
				while flingActive do
					local originalVelocity = PlayerData.rootPart.Velocity
					PlayerData.rootPart.Velocity = Vector3.new(math.random(-150, 150), -25000, math.random(-150, 150))
					Services.RunService.RenderStepped:Wait()
					PlayerData.rootPart.Velocity = originalVelocity
					Services.RunService.Heartbeat:Wait()
				end
			end)
			task.spawn(function()
				while flingActive do
					if States.targetedPlayer and States.targetedPlayer.Character and States.targetedPlayer.Character:FindFirstChild("HumanoidRootPart") then
						PlayerData.rootPart.CFrame = States.targetedPlayer.Character.HumanoidRootPart.CFrame
						task.wait()
					else
						task.wait()
					end
				end
			end)
		else
			notify("Skye", "Cannot fling whitelisted player.", 5)
		end
	else
		flingActive = false
		if flingOldPos then
			task.spawn(function()
				local startTime = tick()
				while tick() - startTime < 2 do
					if PlayerData.rootPart then
						PlayerData.rootPart.CFrame = CFrame.new(flingOldPos)
						PlayerData.rootPart.Velocity = Vector3.new(0, 0, 0)
					end
					Services.RunService.Heartbeat:Wait()
				end
			end)
		end
	end
end, targetTab, false, 120)

local backpackActive = false
local backpackBtn, backpackToggle = addButton("Backpack", 10, 280, function(s)
	backpackActive = s
	if s then
		if States.targetedPlayer and not table.find(CachedData.ScriptWhitelist, States.targetedPlayer.UserId) then
			task.spawn(function()
				while backpackActive do
					if States.targetedPlayer and States.targetedPlayer.Character and States.targetedPlayer.Character:FindFirstChild("HumanoidRootPart") then
						PlayerData.humanoid.Sit = true
						PlayerData.rootPart.CFrame = States.targetedPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 1.2) * CFrame.Angles(0, -3, 0)
						PlayerData.rootPart.Velocity = Vector3.new(0, 0, 0)
						task.wait()
					else
						task.wait()
					end
				end
			end)
		else
			notify("Skye", "Cannot backpack whitelisted player.", 5)
			backpackToggle(false)
		end
	end
end, targetTab, false, 120)

local doggyActive = false
local doggyBtn, doggyToggle = addButton("Doggy", 140, 280, function(s)
	doggyActive = s
	if s then
		if States.targetedPlayer and not table.find(CachedData.ScriptWhitelist, States.targetedPlayer.UserId) then
			PlayAnim(13694096724, 3.4, 0)
			task.spawn(function()
				while doggyActive do
					if States.targetedPlayer and States.targetedPlayer.Character and States.targetedPlayer.Character:FindFirstChild("LowerTorso") then
						PlayerData.rootPart.CFrame = States.targetedPlayer.Character.LowerTorso.CFrame * CFrame.new(0, 0.23, 0)
						PlayerData.rootPart.Velocity = Vector3.new(0, 0, 0)
						task.wait()
					else
						task.wait()
					end
				end
				StopAnim()
			end)
		else
			notify("Skye", "Cannot doggy whitelisted player.", 5)
			doggyToggle(false)
		end
	end
end, targetTab, false, 120)

local dragActive = false
local dragBtn, dragToggle = addButton("Drag", 10, 320, function(s)
	dragActive = s
	if s then
		if States.targetedPlayer and not table.find(CachedData.ScriptWhitelist, States.targetedPlayer.UserId) then
			PlayAnim(10714360343, 0.5, 0)
			task.spawn(function()
				while dragActive do
					if States.targetedPlayer and States.targetedPlayer.Character and States.targetedPlayer.Character:FindFirstChild("RightHand") then
						PlayerData.rootPart.CFrame = States.targetedPlayer.Character.RightHand.CFrame * CFrame.new(0, -2.5, 1) * CFrame.Angles(-2, -3, 0)
						PlayerData.rootPart.Velocity = Vector3.new(0, 0, 0)
						task.wait()
					else
						task.wait()
					end
				end
				StopAnim()
			end)
		else
			notify("Skye", "Cannot drag whitelisted player.", 5)
			dragToggle(false)
		end
	end
end, targetTab, false, 120)

local whitelistBtn = addActionButton("Whitelist", 140, 320, function()
	if States.targetedPlayer then
		if table.find(CachedData.ScriptWhitelist, States.targetedPlayer.UserId) then
			for i, v in pairs(CachedData.ScriptWhitelist) do
				if v == States.targetedPlayer.UserId then table.remove(CachedData.ScriptWhitelist, i) end
			end
			notify("Skye", States.targetedPlayer.Name .. " removed from whitelist.", 5)
		else
			table.insert(CachedData.ScriptWhitelist, States.targetedPlayer.UserId)
			notify("Skye", States.targetedPlayer.Name .. " added to whitelist.", 5)
		end
	end
end, targetTab, 120)

targetInput.FocusLost:Connect(function()
	local inputText = targetInput.Text:lower()
	if inputText ~= "" then
		for _, p in pairs(Services.Players:GetPlayers()) do
			if p.Name:lower():sub(1, #inputText) == inputText or p.DisplayName:lower():sub(1, #inputText) == inputText then
				States.targetedPlayer = p
				targetInput.Text = p.Name
				targetImage.Image = Services.Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
				userInfoLabel.Text = ("UserID: %d\nDisplay: %s\nJoined: %s"):format(p.UserId, p.DisplayName, os.date("%d-%m-%Y", os.time() - p.AccountAge * 24 * 3600))
				break
			end
		end
	else
		States.targetedPlayer = nil
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
		local hit = PlayerData.player:GetMouse().Target
		if hit and hit.Parent then
			local person = Services.Players:GetPlayerFromCharacter(hit.Parent)
			if not person and hit.Parent:IsA("Accessory") then
				person = Services.Players:GetPlayerFromCharacter(hit.Parent.Parent)
			end
			if person then
				States.targetedPlayer = person
				targetInput.Text = person.Name
				targetImage.Image = Services.Players:GetUserThumbnailAsync(person.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
				userInfoLabel.Text = ("UserID: %d\nDisplay: %s\nJoined: %s"):format(person.UserId, person.DisplayName, os.date("%d-%m-%Y", os.time() - person.AccountAge * 24 * 3600))
			end
		end
	end)
	GetTargetTool.Parent = PlayerData.player.Backpack
end)
targetTab.CanvasSize = UDim2.new(0, 0, 0, 370)

-- Applies preset animations to the character
local function applyAnimation(idle1, idle2, walk, run, jump, climb, fall)
	pcall(function()
		local Animate = PlayerData.character:FindFirstChild("Animate")
		if not Animate then warn("Animate script not found in character!") return end
		Animate.Disabled = true
		StopAnim()
		local animation1 = Animate.idle:FindFirstChild("Animation1")
		if animation1 then animation1.AnimationId = "rbxassetid://" .. idle1 end
		local animation2 = Animate.idle:FindFirstChild("Animation2")
		if animation2 then animation2.AnimationId = "rbxassetid://" .. idle2 end
		local walkAnim = Animate.walk:FindFirstChild("WalkAnim")
		if walkAnim then walkAnim.AnimationId = "rbxassetid://" .. walk end
		local runAnim = Animate.run:FindFirstChild("RunAnim")
		if runAnim then runAnim.AnimationId = "rbxassetid://" .. run end
		local jumpAnim = Animate.jump:FindFirstChild("JumpAnim")
		if jumpAnim then jumpAnim.AnimationId = "rbxassetid://" .. jump end
		local climbAnim = Animate.climb:FindFirstChild("ClimbAnim")
		if climbAnim then climbAnim.AnimationId = "rbxassetid://" .. climb end
		local fallAnim = Animate.fall:FindFirstChild("FallAnim")
		if fallAnim then fallAnim.AnimationId = "rbxassetid://" .. fall end
		Animate.Disabled = false
	end)
end

-- Checks if an animation ID is valid
local function isValidAnimationId(id)
	if id == "" then return false end
	local success, info = pcall(function()
		return game:GetService("MarketplaceService"):GetProductInfo(tonumber(id))
	end)
	return success and info and info.AssetTypeId == 24
end

-- Applies custom animations with fallback to default if ID is invalid
local function applyCustomAnimations()
	pcall(function()
		local Animate = PlayerData.character:FindFirstChild("Animate")
		if not Animate then warn("Animate script not found in character!") return end
		Animate.Disabled = true
		StopAnim()
		-- Idle
		local idleId = States.animationStages.idle.id
		if idleId ~= "" and isValidAnimationId(idleId) then
			local animation1 = Animate.idle:FindFirstChild("Animation1")
			if animation1 then animation1.AnimationId = "rbxassetid://" .. idleId end
			local animation2 = Animate.idle:FindFirstChild("Animation2")
			if animation2 then animation2.AnimationId = "rbxassetid://" .. idleId end
		else
			local animation1 = Animate.idle:FindFirstChild("Animation1")
			if animation1 then animation1.AnimationId = DefaultAnimations.idle1 end
			local animation2 = Animate.idle:FindFirstChild("Animation2")
			if animation2 then animation2.AnimationId = DefaultAnimations.idle2 end
		end
		-- Run
		local runId = States.animationStages.run.id
		if runId ~= "" and isValidAnimationId(runId) then
			local runAnim = Animate.run:FindFirstChild("RunAnim")
			if runAnim then runAnim.AnimationId = "rbxassetid://" .. runId end
		else
			local runAnim = Animate.run:FindFirstChild("RunAnim")
			if runAnim then runAnim.AnimationId = DefaultAnimations.run end
		end
		-- Walk
		local walkId = States.animationStages.walk.id
		if walkId ~= "" and isValidAnimationId(walkId) then
			local walkAnim = Animate.walk:FindFirstChild("WalkAnim")
			if walkAnim then walkAnim.AnimationId = "rbxassetid://" .. walkId end
		else
			local walkAnim = Animate.walk:FindFirstChild("WalkAnim")
			if walkAnim then walkAnim.AnimationId = DefaultAnimations.walk end
		end
		-- Jump
		local jumpId = States.animationStages.jump.id
		if jumpId ~= "" and isValidAnimationId(jumpId) then
			local jumpAnim = Animate.jump:FindFirstChild("JumpAnim")
			if jumpAnim then jumpAnim.AnimationId = "rbxassetid://" .. jumpId end
		else
			local jumpAnim = Animate.jump:FindFirstChild("JumpAnim")
			if jumpAnim then jumpAnim.AnimationId = DefaultAnimations.jump end
		end
		-- Fall
		local fallId = States.animationStages.fall.id
		if fallId ~= "" and isValidAnimationId(fallId) then
			local fallAnim = Animate.fall:FindFirstChild("FallAnim")
			if fallAnim then fallAnim.AnimationId = "rbxassetid://" .. fallId end
		else
			local fallAnim = Animate.fall:FindFirstChild("FallAnim")
			if fallAnim then fallAnim.AnimationId = DefaultAnimations.fall end
		end
		-- Climb
		local climbId = States.animationStages.climb.id
		if climbId ~= "" and isValidAnimationId(climbId) then
			local climbAnim = Animate.climb:FindFirstChild("ClimbAnim")
			if climbAnim then climbAnim.AnimationId = "rbxassetid://" .. climbId end
		else
			local climbAnim = Animate.climb:FindFirstChild("ClimbAnim")
			if climbAnim then climbAnim.AnimationId = DefaultAnimations.climb end
		end
		-- Swim
		local swimId = States.animationStages.swim.id
		if swimId ~= "" and isValidAnimationId(swimId) then
			local swimAnim = Animate.swim:FindFirstChild("SwimAnim")
			if swimAnim then swimAnim.AnimationId = "rbxassetid://" .. swimId end
			local swimIdle = Animate.swim:FindFirstChild("SwimIdle")
			if swimIdle then swimIdle.AnimationId = "rbxassetid://" .. swimId end
		else
			local swimAnim = Animate.swim:FindFirstChild("SwimAnim")
			if swimAnim then swimAnim.AnimationId = DefaultAnimations.swimAnim end
			local swimIdle = Animate.swim:FindFirstChild("SwimIdle")
			if swimIdle then swimIdle.AnimationId = DefaultAnimations.swimIdle end
		end
		Animate.Disabled = false
	end)
end

local animButtonsFrame = create("Frame", {Size = UDim2.new(1, 0, 0, 400), Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1, Parent = animationsTab})
local animGrid = create("UIGridLayout", {CellSize = UDim2.new(0, 90, 0, 25), CellPadding = UDim2.new(0, 10, 0, 10), Parent = animButtonsFrame})
local animStagesFrame = create("Frame", {Size = UDim2.new(1, 0, 0, 280), Position = UDim2.new(0, 0, 0, 410), BackgroundTransparency = 1, Parent = animationsTab})
local divider = create("Frame", {Size = UDim2.new(0.9, 0, 0, 2), Position = UDim2.new(0.05, 0, 0, 395), BackgroundColor3 = Colors.Outline, BackgroundTransparency = 0.5, Parent = animationsTab})
create("UICorner", {CornerRadius = UDim.new(0, 1), Parent = divider})
create("TextLabel", {Size = UDim2.new(1, 0, 0, 25), Position = UDim2.new(0, 0, 0, 380), BackgroundTransparency = 1, Text = "Custom Animation Controls", TextColor3 = Colors.Text, TextSize = 16, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Center, Parent = animationsTab})

local loadPresetBtn = create("TextButton", {Size = UDim2.new(0, 120, 0, 25), Position = UDim2.new(0.5, -60, 0, 330), BackgroundColor3 = Colors.Button, Text = "Load to Custom", TextColor3 = Colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, Parent = animationsTab})
create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = loadPresetBtn})
loadPresetBtn.MouseButton1Click:Connect(function()
	if States.lastSelectedPreset then
		local name, idle1, idle2, walk, run, jump, climb, fall = unpack(States.lastSelectedPreset)
		States.animationStages.idle.id = idle1
		States.animationStages.run.id = run
		States.animationStages.walk.id = walk
		States.animationStages.jump.id = jump
		States.animationStages.fall.id = fall
		States.animationStages.climb.id = climb
		States.animationStages.swim.id = idle1
		for stage, info in pairs(States.animationStages) do
			for _, child in pairs(animStagesFrame:GetChildren()) do
				if child:IsA("Frame") then
					local stageName = child:FindFirstChildOfClass("TextLabel")
					if stageName and stageName.Text == info.name then
						local idInput = child:FindFirstChildOfClass("TextBox")
						if idInput then idInput.Text = info.id end
						break
					end
				end
			end
		end
	else
		notify("No preset selected", "Please select a preset first.", 5)
	end
end)

local function addAnimStageRow(stage, y)
	local stageFrame = create("Frame", {Size = UDim2.new(1, -10, 0, 30), Position = UDim2.new(0, 5, 0, y), BackgroundTransparency = 1, Parent = animStagesFrame})
	create("TextLabel", {Size = UDim2.new(0, 60, 1, 0), Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1, Text = States.animationStages[stage].name, TextColor3 = Colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = stageFrame})
	local selectBtn = create("TextButton", {Size = UDim2.new(0, 25, 0, 25), Position = UDim2.new(0, 70, 0, 2), BackgroundColor3 = Colors.Button, Text = "⊕", TextColor3 = Colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, Parent = stageFrame})
	create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = selectBtn})
	local idInput = create("TextBox", {Size = UDim2.new(0, 100, 0, 25), Position = UDim2.new(0, 105, 0, 2), BackgroundColor3 = Colors.Button, Text = States.animationStages[stage].id, PlaceholderText = "ID", TextColor3 = Colors.Text, TextSize = 12, Font = Enum.Font.FredokaOne, ClearTextOnFocus = false, Parent = stageFrame})
	create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = idInput})
	idInput.FocusLost:Connect(function()
		local id = idInput.Text
		if id == "" then
			States.animationStages[stage].id = ""
			return
		end
		if isValidAnimationId(id) then
			States.animationStages[stage].id = id
		else
			States.animationStages[stage].id = ""
			idInput.Text = ""
			notify("Invalid Animation ID", "The entered ID is not a valid animation.", 5)
		end
	end)
	selectBtn.MouseButton1Click:Connect(function()
		States.selectedAnimStage = stage
		for _, child in pairs(animStagesFrame:GetChildren()) do
			if child:IsA("Frame") then
				local btn = child:FindFirstChildOfClass("TextButton")
				if btn then btn.BackgroundColor3 = Colors.Button end
			end
		end
		selectBtn.BackgroundColor3 = Colors.ToggleOn
	end)
	return stageFrame
end

local orderedStages = {"idle", "run", "walk", "jump", "fall", "climb", "swim"}
local stageOffset = 0
for _, stage in ipairs(orderedStages) do
	addAnimStageRow(stage, stageOffset)
	stageOffset = stageOffset + 35
end

local applyBtn = create("TextButton", {Size = UDim2.new(0, 120, 0, 30), Position = UDim2.new(0, 10, 0, stageOffset + 10), BackgroundColor3 = Colors.Interface, Text = "Apply Animations", TextColor3 = Colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, Parent = animStagesFrame})
create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = applyBtn})
applyBtn.MouseButton1Click:Connect(applyCustomAnimations)

local resetBtn = create("TextButton", {Size = UDim2.new(0, 120, 0, 30), Position = UDim2.new(0, 140, 0, stageOffset + 10), BackgroundColor3 = Colors.Button, Text = "Reset to Default", TextColor3 = Colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, Parent = animStagesFrame})
create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = resetBtn})
resetBtn.MouseButton1Click:Connect(function()
	local Animate = PlayerData.character:FindFirstChild("Animate")
	if Animate then
		Animate.Disabled = true
		StopAnim()
		local animation1 = Animate.idle:FindFirstChild("Animation1")
		if animation1 then animation1.AnimationId = DefaultAnimations.idle1 end
		local animation2 = Animate.idle:FindFirstChild("Animation2")
		if animation2 then animation2.AnimationId = DefaultAnimations.idle2 end
		local walkAnim = Animate.walk:FindFirstChild("WalkAnim")
		if walkAnim then walkAnim.AnimationId = DefaultAnimations.walk end
		local runAnim = Animate.run:FindFirstChild("RunAnim")
		if runAnim then runAnim.AnimationId = DefaultAnimations.run end
		local jumpAnim = Animate.jump:FindFirstChild("JumpAnim")
		if jumpAnim then jumpAnim.AnimationId = DefaultAnimations.jump end
		local climbAnim = Animate.climb:FindFirstChild("ClimbAnim")
		if climbAnim then climbAnim.AnimationId = DefaultAnimations.climb end
		local fallAnim = Animate.fall:FindFirstChild("FallAnim")
		if fallAnim then fallAnim.AnimationId = DefaultAnimations.fall end
		local swimAnim = Animate.swim:FindFirstChild("SwimAnim")
		if swimAnim then swimAnim.AnimationId = DefaultAnimations.swimAnim end
		local swimIdle = Animate.swim:FindFirstChild("SwimIdle")
		if swimIdle then swimIdle.AnimationId = DefaultAnimations.swimIdle end
		Animate.Disabled = false
	end
	for stage in pairs(States.animationStages) do States.animationStages[stage].id = "" end
	for _, child in pairs(animStagesFrame:GetChildren()) do
		if child:IsA("Frame") then
			local idInput = child:FindFirstChildOfClass("TextBox")
			if idInput then idInput.Text = "" end
		end
	end
end)

local animButtons = {
	{"Vampire", "1083445855", "1083450166", "1083473930", "1083462077", "1083455352", "1083439238", "1083443587"},
	{"Hero", "616111295", "616113536", "616122287", "616117076", "616115533", "616104706", "616108001"},
	{"Zombie Classic", "616158929", "616160636", "616168032", "616163682", "616161997", "616156119", "616157476"},
	{"Mage", "707742142", "707855907", "707897309", "707861613", "707853694", "707826056", "707829716"},
	{"Ghost", "616006778", "616008087", "616010382", "616013216", "616008936", "616003713", "616005863"},
	{"Elder", "845397899", "845400520", "845403856", "845386501", "845398858", "845392038", "845396048"},
	{"Levitation", "616006778", "616008087", "616013216", "616010382", "616008936", "616003713", "616005863"},
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
	{"Oldschool", "10921230744", "10921232093", "10921244891", "10921240218", "10921242013", "10921229866", "10921241244"},
	{"Rthro", "10921259953", "10921258489", "10921269718", "10921261968", "10921263860", "10921257536", "10921262864"},
	{"Wicked", "118832222982049", "76049494037641", "92072849924640", "72301599441680", "104325245285198", "131326830509784", "121152442762481"},
	{"Stylish", "10921272275", "10921273958", "10921283326", "10921276116", "10921279832", "10921271391", "10921278648"},
	{"adidas", "18537376492", "18537371272", "18537392113", "18537384940", "18537380791", "18537363391", "18537367238"},
	{"Robot", "10921248039", "10921248831", "10921255446", "10921250460", "10921252123", "10921247141", "10921251156"},
	{"Bold", "16738333868", "16738334710", "16738340646", "16738337225", "16738336650", "16738332169", "16738333171"},
	{"Catwalk", "133806214992291", "94970088341563", "109168724482748", "81024476153754", "116936326516985", "119377220967554", "92294537340807"},
	{"Bubbly", "10921054344", "10921055107", "10980888364", "10921057244", "10921062673", "10921053544", "10921061530"},
	{"No Boundaries", "18747067405", "18747063918", "18747074203", "18747070484", "18747069148", "18747060903", "18747062535"},
	{"Superhero", "10921288909", "10921290167", "10921298616", "10921291831", "10921294559", "10921286911", "10921293373"},
	{"NFL", "92080889861410", "74451233229259", "110358958299415", "117333533048078", "119846112151352", "134630013742019", "129773241321032"}
}

for _, anim in pairs(animButtons) do
	local name, idle1, idle2, walk, run, jump, climb, fall = unpack(anim)
	local b = create("TextButton", {Size = UDim2.new(0, 90, 0, 25), BackgroundColor3 = Colors.Button, Text = name, TextColor3 = Colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, Parent = animButtonsFrame})
	create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = b})
	b.MouseButton1Click:Connect(function()
		States.lastSelectedPreset = anim
		if States.selectedAnimStage then
			local stageId = ""
			if States.selectedAnimStage == "idle" then stageId = idle1
			elseif States.selectedAnimStage == "run" then stageId = run
			elseif States.selectedAnimStage == "walk" then stageId = walk
			elseif States.selectedAnimStage == "jump" then stageId = jump
			elseif States.selectedAnimStage == "fall" then stageId = fall
			elseif States.selectedAnimStage == "climb" then stageId = climb
			elseif States.selectedAnimStage == "swim" then stageId = idle1
			end
			if stageId ~= "" then
				States.animationStages[States.selectedAnimStage].id = stageId
				for _, child in pairs(animStagesFrame:GetChildren()) do
					if child:IsA("Frame") then
						local stageName = child:FindFirstChildOfClass("TextLabel")
						if stageName and stageName.Text == States.animationStages[States.selectedAnimStage].name then
							local idInput = child:FindFirstChildOfClass("TextBox")
							if idInput then idInput.Text = stageId end
							break
						end
					end
				end
			end
		else
			applyAnimation(idle1, idle2, walk, run, jump, climb, fall)
		end
	end)
end

animationsTab.CanvasSize = UDim2.new(0, 0, 0, stageOffset + 460)

addKeybind("Menu", States.keybinds.Menu, 0)
addKeybind("Aimlock", States.keybinds.Aimlock, 30)
addKeybind("ESP", States.keybinds.ESP, 60)
addKeybind("ClickTeleport", States.keybinds.ClickTeleport, 90)
addKeybind("Fly", States.keybinds.Fly, 120)
addKeybind("FreeCam", States.keybinds.FreeCam, 150)
addKeybind("Speed", States.keybinds.Speed, 180)
addSlider("", 0, 1, States.menuTransparency, 240, function(v)
	States.menuTransparency = v
	mainFrame.BackgroundTransparency = v
	keybindsFrame.BackgroundTransparency = v
end, keybindsScroll, true, false).BackgroundTransparency = 1

local cpf = create("Frame", {Size = UDim2.new(0, 200, 0, 150), Position = UDim2.new(0.5, -100, 0.5, -75), BackgroundColor3 = Colors.Background, Visible = false, Parent = gui})
create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = cpf})
local db = create("Frame", {Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = Colors.Header, Parent = cpf})
create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = db})
create("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "ESP Color Picker", TextColor3 = Colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Center, Parent = db})
local cbx = create("TextButton", {Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(1, -25, 0, 0), BackgroundColor3 = Colors.Button, Text = "X", TextColor3 = Colors.Text, TextSize = 12, Font = Enum.Font.FredokaOne, Parent = db})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = cbx})
cbx.MouseButton1Click:Connect(function() cpf.Visible = false end)
local cp = create("Frame", {Size = UDim2.new(0, 180, 0, 20), Position = UDim2.new(0, 10, 0, 120), BackgroundColor3 = Colors.ESP, Parent = cpf})
create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = cp})
local function createColorSlider(l, min, max, y, cb)
	local sf = create("Frame", {Size = UDim2.new(0, 180, 0, 20), Position = UDim2.new(0, 10, 0, y), BackgroundColor3 = Colors.Button, Parent = cpf})
	create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = sf})
	local f = create("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Colors.Interface, Parent = sf})
	create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = f})
	create("TextLabel", {Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(-0.15, 0, 0, 0), BackgroundTransparency = 1, Text = l, TextColor3 = Colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, Parent = sf})
	local d = false
	sf.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then d = true end end)
	Services.UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then d = false end end)
	Services.UserInputService.InputChanged:Connect(function(i)
		if d and i.UserInputType == Enum.UserInputType.MouseMovement then
			local p = math.clamp((i.Position.X - sf.AbsolutePosition.X) / sf.AbsoluteSize.X, 0, 1)
			f.Size = UDim2.new(p, 0, 1, 0)
			cb(min + (max - min) * p)
		end
	end)
	return f
end
local hf = createColorSlider("H", 0, 360, 30, function(v) Colors.ESP = Color3.fromHSV(v / 360, Colors.ESP:ToHSV()) cp.BackgroundColor3 = Colors.ESP cb.BackgroundColor3 = Colors.ESP updateESP() end)
local sf = createColorSlider("S", 0, 1, 60, function(v) local h = Colors.ESP:ToHSV() Colors.ESP = Color3.fromHSV(h, v, select(3, Colors.ESP:ToHSV())) cp.BackgroundColor3 = Colors.ESP cb.BackgroundColor3 = Colors.ESP updateESP() end)
local vf = createColorSlider("V", 0, 1, 90, function(v) local h, s = Colors.ESP:ToHSV() Colors.ESP = Color3.fromHSV(h, s, v) cp.BackgroundColor3 = Colors.ESP cb.BackgroundColor3 = Colors.ESP updateESP() end)
local function openColorPicker()
	if cpf.Visible then cpf.Visible = false else
		cpf.Visible = true
		local h, s, v = Colors.ESP:ToHSV()
		hf.Size = UDim2.new(h, 0, 1, 0)
		sf.Size = UDim2.new(s, 0, 1, 0)
		vf.Size = UDim2.new(v, 0, 1, 0)
		cp.BackgroundColor3 = Colors.ESP
	end
end
cb.MouseButton1Click:Connect(openColorPicker)
local dc, ds, sp
db.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dc = true ds = i.Position sp = cpf.Position end end)
Services.UserInputService.InputChanged:Connect(function(i) if dc and i.UserInputType == Enum.UserInputType.MouseMovement then local d = i.Position - ds cpf.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y) end end)
Services.UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dc = false end end)
tabs["Visuals"].BackgroundColor3 = Colors.TabSelected
tabContents["Visuals"].Visible = true

local function isBindDown(bind)
	if bind == nil then return false end
	if bind:IsA("KeyCode") then return Services.UserInputService:IsKeyDown(bind)
	elseif bind:IsA("UserInputType") then
		if bind == Enum.UserInputType.MouseButton1 or bind == Enum.UserInputType.MouseButton2 or bind == Enum.UserInputType.MouseButton3 then
			return Services.UserInputService:IsMouseButtonPressed(bind)
		end
	end
	return false
end

local function isBindPressed(bind, input)
	if bind == nil then return false end
	if bind:IsA("KeyCode") then return input.KeyCode == bind
	elseif bind:IsA("UserInputType") then return input.UserInputType == bind
	end
	return false
end

Services.RunService.RenderStepped:Connect(function(dt)
	if not PlayerData.character or not PlayerData.rootPart then return end
	local cf = PlayerData.camera.CFrame
	if States.viewTarget then PlayerData.camera.CameraType = Enum.CameraType.Follow return end
	local movement = nil
	if States.aimlockActive then
		local t = States.lockedTarget or getTargetInFOV()
		if t then
			if States.aimlockToggleMode then
				if States.aimlockLocked then States.lockedTarget = t else States.lockedTarget = nil end
			else
				States.lockedTarget = isBindDown(States.keybinds.Aimlock) and t or nil
			end
			if States.lockedTarget then
				local tp = States.predictionActive and predictTargetPosition(States.lockedTarget, dt) or States.lockedTarget.Position
				local tc = CFrame.new(cf.Position, tp)
				if not States.silentAimActive then PlayerData.camera.CFrame = tc end
			end
		else
			if not States.aimlockToggleMode then States.lockedTarget = nil end
		end
	end
	if States.showFOVCone and States.fovCone then States.fovCone.Position = UDim2.new(0.5, -States.aimlockFOV, 0.5, -States.aimlockFOV) end
	if States.cframeSpeedActive then
		movement = movement or getMovement(cf, false)
		if movement.Magnitude > 0 then
			local mxz = Vector3.new(movement.X, 0, movement.Z).Unit * States.cframeSpeedValue * dt
			PlayerData.rootPart.CFrame = CFrame.new(PlayerData.rootPart.Position + mxz) * PlayerData.rootPart.CFrame.Rotation
		end
	end
	if States.flyActive and States.bodyVelocity and States.bodyGyro then
		movement = movement or getMovement(cf, true)
		States.bodyVelocity.Velocity = movement.Magnitude > 0 and movement.Unit * States.flySpeedValue or Vector3.new()
		States.bodyGyro.CFrame = cf
	end
	if States.freeCamActive then
		movement = movement or getMovement(cf, true)
		if movement.Magnitude > 0 then
			States.freeCamPosition = clampPosition(States.freeCamPosition + movement.Unit * States.freeCamSpeed * States.freeCamBoost * dt)
		end
		PlayerData.camera.CFrame = CFrame.new(States.freeCamPosition) * CFrame.Angles(0, States.freeCamYaw, 0) * CFrame.Angles(States.freeCamPitch, 0, 0)
	end
	if States.noclipActive then
		for _, p in pairs(PlayerData.character:GetDescendants()) do
			if p:IsA("BasePart") then p.CanCollide = false end
		end
	end
end)

local function storeDefaultAnimations()
	local Animate = PlayerData.character:FindFirstChild("Animate")
	if Animate then
		DefaultAnimations.idle1 = Animate.idle:FindFirstChild("Animation1") and Animate.idle:FindFirstChild("Animation1").AnimationId or ""
		DefaultAnimations.idle2 = Animate.idle:FindFirstChild("Animation2") and Animate.idle:FindFirstChild("Animation2").AnimationId or ""
		DefaultAnimations.walk = Animate.walk:FindFirstChild("WalkAnim") and Animate.walk:FindFirstChild("WalkAnim").AnimationId or ""
		DefaultAnimations.run = Animate.run:FindFirstChild("RunAnim") and Animate.run:FindFirstChild("RunAnim").AnimationId or ""
		DefaultAnimations.jump = Animate.jump:FindFirstChild("JumpAnim") and Animate.jump:FindFirstChild("JumpAnim").AnimationId or ""
		DefaultAnimations.climb = Animate.climb:FindFirstChild("ClimbAnim") and Animate.climb:FindFirstChild("ClimbAnim").AnimationId or ""
		DefaultAnimations.fall = Animate.fall:FindFirstChild("FallAnim") and Animate.fall:FindFirstChild("FallAnim").AnimationId or ""
		DefaultAnimations.swimAnim = Animate.swim:FindFirstChild("SwimAnim") and Animate.swim:FindFirstChild("SwimAnim").AnimationId or ""
		DefaultAnimations.swimIdle = Animate.swim:FindFirstChild("SwimIdle") and Animate.swim:FindFirstChild("SwimIdle").AnimationId or ""
	end
end

local function updateCharacter(c)
	if not c then return end
	PlayerData.character = c
	PlayerData.rootPart = c:WaitForChild("HumanoidRootPart", 3)
	PlayerData.humanoid = c:WaitForChild("Humanoid", 3)
	if not PlayerData.rootPart then warn("No HumanoidRootPart!") return end
	task.wait(0.5)
	storeDefaultAnimations()
	if States.flyActive then
		PlayerData.humanoid.PlatformStand = true
		States.bodyVelocity = States.bodyVelocity or Instance.new("BodyVelocity")
		States.bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		States.bodyVelocity.Velocity = Vector3.new()
		States.bodyVelocity.Parent = PlayerData.rootPart
		States.bodyGyro = States.bodyGyro or Instance.new("BodyGyro")
		States.bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
		States.bodyGyro.P = 20000
		States.bodyGyro.D = 100
		States.bodyGyro.Parent = PlayerData.rootPart
	end
	if States.espTracerActive then updateESP() end
end
PlayerData.player.CharacterAdded:Connect(updateCharacter)
if PlayerData.player.Character then updateCharacter(PlayerData.player.Character) end

local d, ds, spos
header.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then d = true ds = i.Position spos = mainFrame.Position end end)
Services.UserInputService.InputChanged:Connect(function(i) if d and i.UserInputType == Enum.UserInputType.MouseMovement then local delta = i.Position - ds mainFrame.Position = UDim2.new(spos.X.Scale, spos.X.Offset + delta.X, spos.Y.Scale, spos.Y.Offset + delta.Y) end end)
Services.UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then d = false end end)

local r = false
local function toggleMenu()
	mainFrame.Visible = not mainFrame.Visible
	mainFrame.Position = mainFrame.Visible and UDim2.new(0.5, -210, 0.5, -260) or UDim2.new(-0.5, -210, 0.5, -260)
end
Services.UserInputService.InputBegan:Connect(function(i, gp)
	if gp then return end
	if States.keybinds.Menu and isBindPressed(States.keybinds.Menu, i) then toggleMenu()
	elseif States.keybinds.ESP and isBindPressed(States.keybinds.ESP, i) then et(not States.espActive)
	elseif States.keybinds.Fly and isBindPressed(States.keybinds.Fly, i) then
		flyToggle(not States.flyActive)
		if States.flyActive then cst(false) end
	elseif States.keybinds.Speed and isBindPressed(States.keybinds.Speed, i) then
		cst(not States.cframeSpeedActive)
		if States.cframeSpeedActive then flyToggle(false) end
	elseif States.keybinds.FreeCam and isBindPressed(States.keybinds.FreeCam, i) then fct(not States.freeCamActive)
	elseif States.keybinds.Aimlock and isBindPressed(States.keybinds.Aimlock, i) and States.aimlockActive then
		if States.aimlockToggleMode then States.aimlockLocked = not States.aimlockLocked else States.lockedTarget = getTargetInFOV() end
	elseif States.freeCamActive and i.UserInputType == Enum.UserInputType.MouseButton2 then
		r = true
		Services.UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	elseif i.KeyCode == Enum.KeyCode.LeftShift or i.KeyCode == Enum.KeyCode.RightShift then States.freeCamBoost = 2
	elseif States.silentAimActive and i.UserInputType == Enum.UserInputType.MouseButton1 then
		local currentTarget = getTargetInFOV()
		if currentTarget then
			local mp = Services.UserInputService:GetMouseLocation()
			local nextTarget, md = nil, math.huge
			for _, p in pairs(CachedData.cachedPlayers) do
				if p ~= PlayerData.player and p ~= Services.Players:GetPlayerFromCharacter(currentTarget.Parent) then
					local part = p.Character and p.Character:FindFirstChild(States.aimlockTargetPart == "Head" and "Head" or "HumanoidRootPart")
					if part then
						local pp, os = PlayerData.camera:WorldToViewportPoint(part.Position)
						if os then
							local d = (Vector2.new(pp.X, pp.Y) - mp).Magnitude
							if d <= States.aimlockFOV and d < md then
								nextTarget = part
								md = d
							end
						end
					end
				end
			end
			if nextTarget then
				States.lockedTarget = nextTarget
				local tp = States.predictionActive and predictTargetPosition(nextTarget, 0.1) or nextTarget.Position
			end
		end
	end
end)
Services.UserInputService.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton2 then r = false Services.UserInputService.MouseBehavior = Enum.MouseBehavior.Default end
	if i.KeyCode == Enum.KeyCode.LeftShift or i.KeyCode == Enum.KeyCode.RightShift then States.freeCamBoost = 1 end
	if States.keybinds.Aimlock and not States.aimlockToggleMode then States.lockedTarget = nil end
end)
Services.UserInputService.InputChanged:Connect(function(i)
	if r and i.UserInputType == Enum.UserInputType.MouseMovement and not States.lockedTarget then
		States.freeCamYaw = States.freeCamYaw - i.Delta.X * States.freeCamSensitivity
		States.freeCamPitch = math.clamp(States.freeCamPitch - i.Delta.Y * States.freeCamSensitivity, -math.pi / 2, math.pi / 2)
	end
end)

local m = PlayerData.player:GetMouse()
m.Button1Down:Connect(function()
	if States.clickTeleportActive and States.keybinds.ClickTeleport and isBindDown(States.keybinds.ClickTeleport) and PlayerData.rootPart then
		local targetPos = m.Hit.Position + Vector3.new(0, 3, 0)
		local cameraLook = PlayerData.camera.CFrame.LookVector
		local yaw = math.atan2(-cameraLook.X, -cameraLook.Z)
		PlayerData.rootPart.CFrame = CFrame.new(targetPos) * CFrame.Angles(0, yaw, 0)
	end
end)
