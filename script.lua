local Players, Lighting, TweenService, UserInputService, RunService = game:GetService("Players"), game:GetService("Lighting"), game:GetService("TweenService"), game:GetService("UserInputService"), game:GetService("RunService")
local player, camera = Players.LocalPlayer, workspace.CurrentCamera
local character, rootPart, humanoid
local originalSettings = {MaxZoom = player.CameraMaxZoomDistance, FOV = camera.FieldOfView, ClockTime = Lighting.ClockTime, Materials = {}, Transparency = {}}
local colorCorrection = Lighting:FindFirstChild("CustomColorCorrection") or Instance.new("ColorCorrectionEffect", Lighting) colorCorrection.Name = "CustomColorCorrection"
local aimlockActive, espActive, viewTarget, wallhackActive, lowTextureActive = false, false, nil, false, false
local silentAimActive, predictionActive = false, false
local aimlockToggleMode, aimlockLocked = false, false
local espHighlights, espNames, espBoxes, espTracers = {}, {}, {}, {}
local keybinds = {Menu = Enum.KeyCode.G, Aimlock = Enum.KeyCode.Q, ESP = Enum.KeyCode.J, ClickTeleport = Enum.KeyCode.E, Fly = nil, FreeCam = Enum.KeyCode.P, CFrameSpeed = nil}
local aimlockFOV, showFOVCone, fovCone = 150, false, nil
local cframeSpeedValue, flySpeedValue, freeCamSpeed = 300, 300, 200
local cframeSpeedActive, flyActive, freeCamActive, noclipActive, clickTeleportActive = false, false, false, false, false
local freeCamPosition, freeCamYaw, freeCamPitch, freeCamSensitivity, freeCamBoost = nil, 0, 0, 0.01, 1
local lockedTarget, targetedPlayer, targetActive = nil, nil, false
local aimlockTargetPart = "Head"
local animationStages = {
	idle = {name = "Idle", id = ""},
	walk = {name = "Walk", id = ""},
	run = {name = "Run", id = ""},
	jump = {name = "Jump", id = ""},
	fall = {name = "Fall", id = ""},
	climb = {name = "Climb", id = ""},
	swim = {name = "Swim", id = ""}
}
local selectedAnimStage = nil
local lastSelectedPreset = nil
local menuTransparency = 0.1
local espBoxActive, espTracerActive = false, false
local bodyVelocity, bodyGyro
local colors = {
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
local sliderValues = {}
local toggleStates = {}
local cachedPlayers = Players:GetPlayers()
local seenPlayers = {}
local ScriptWhitelist = {}
local httprequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

local function create(class, props)
	local inst = Instance.new(class)
	for k, v in pairs(props) do inst[k] = v end
	return inst
end

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
	local animtrack = character.Humanoid:GetPlayingAnimationTracks()
	for _, track in pairs(animtrack) do track:Stop() end
end

local gui = create("ScreenGui", {Name = "Settings", ResetOnSpawn = false, IgnoreGuiInset = true, Parent = player:WaitForChild("PlayerGui")})
local mainFrame = create("Frame", {Size = UDim2.new(0, 419, 0, 520), Position = UDim2.new(0.5, -210, 0.5, -260), BackgroundColor3 = colors.Background, BackgroundTransparency = menuTransparency, Visible = false, Parent = gui})
create("UICorner", {CornerRadius = UDim.new(0, 12), Parent = mainFrame})
create("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(20, 20, 40), Color3.fromRGB(50, 50, 80)), Rotation = 45, Parent = mainFrame})
local header = create("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = colors.Header, Parent = mainFrame})
create("UICorner", {CornerRadius = UDim.new(0, 12), Parent = header})
create("TextLabel", {Size = UDim2.new(0.7, 0, 0, 40), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = "Settings", TextColor3 = colors.Text, TextSize = 28, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = header})
local tabFrame = create("Frame", {Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 40), BackgroundTransparency = 1, Parent = mainFrame})
create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 5), Parent = tabFrame})
local tabs, tabContents = {}, {}
local function addTab(name, w)
	local btn = create("TextButton", {Size = UDim2.new(0, w or 80, 0, 25), BackgroundColor3 = colors.TabUnselected, Text = name, TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, Parent = tabFrame})
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
local visualsTab = addTab("Visuals")
local playerTab = addTab("Player")
local combatTab = addTab("Combat")
local targetTab = addTab("Target")
local animationsTab = addTab("Animations")
local keybindsFrame = create("Frame", {Size = UDim2.new(0, 200, 0, 520), Position = UDim2.new(1, 0, 0, 0), BackgroundColor3 = colors.KeybindsBG, BackgroundTransparency = menuTransparency, Visible = false, Parent = mainFrame})
create("UICorner", {CornerRadius = UDim.new(0, 12), Parent = keybindsFrame})
create("UIGradient", {Color = ColorSequence.new(colors.KeybindsBG, colors.Header), Rotation = 45, Parent = keybindsFrame})
local keybindsScroll = create("ScrollingFrame", {Size = UDim2.new(1, -10, 1, -10), Position = UDim2.new(0, 5, 0, 5), BackgroundTransparency = 1, ScrollBarThickness = 0, CanvasSize = UDim2.new(0, 0, 0, 400), Parent = keybindsFrame})
local function toggleKeybindsFrame() keybindsFrame.Visible = not keybindsFrame.Visible end
create("ImageButton", {Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(1, -34, 0, 8), BackgroundTransparency = 1, Image = "rbxassetid://6023565895", ImageColor3 = colors.Text, Parent = header}).MouseButton1Click:Connect(toggleKeybindsFrame)

local toggleCallbacks = {}
local function addToggle(name, def, y, cb, parent)
	toggleStates[name] = def
	local f = create("Frame", {Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, y), BackgroundTransparency = 1, Parent = parent})
	create("TextLabel", {Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.new(0, 5, 0, 0), BackgroundTransparency = 1, Text = name, TextColor3 = colors.Text, TextSize = 16, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = f})
	local tf = create("Frame", {Size = UDim2.new(0, 40, 0, 20), Position = UDim2.new(0.85, -20, 0.5, -10), BackgroundColor3 = def and colors.ToggleOn or colors.ToggleOff, Parent = f})
	create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = tf})
	toggleCallbacks[name] = toggleCallbacks[name] or {}
	table.insert(toggleCallbacks[name], function(s)
		toggleStates[name] = s
		tf.BackgroundColor3 = s and colors.ToggleOn or colors.ToggleOff
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
	local l = nl and nil or create("TextLabel", {Size = UDim2.new(0, 180, 1, 0), Position = UDim2.new(0, 5, 0, 0), BackgroundTransparency = 1, Text = nd and string.format("%s: %d", name, def) or string.format("%s: %.1f", name, def), TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = f})
	local sf = create("Frame", {Size = nl and UDim2.new(0.95, 0, 0, 12) or UDim2.new(0, 200, 0, 12), Position = nl and UDim2.new(0.025, 0, 0.5, -6) or UDim2.new(0, 170, 0.5, -6), BackgroundColor3 = colors.Button, Parent = f})
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
local function addButton(name, x, y, cb, parent, ts, w, textUpdater)
	local b = create("TextButton", {Size = UDim2.new(0, w or 80, 0, 25), Position = UDim2.new(0, x, 0, y), BackgroundColor3 = ts and colors.ToggleOn or colors.ToggleOff, Text = name, TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, Parent = parent})
	create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = b})
	local s = ts or false
	textUpdater = textUpdater or function(b, s, name) b.Text = name end
	buttonCallbacks[name] = buttonCallbacks[name] or {}
	table.insert(buttonCallbacks[name], function(state)
		s = state
		b.BackgroundColor3 = s and colors.ToggleOn or colors.ToggleOff
		textUpdater(b, s, name)
		cb(s)
	end)
	local function upd(ns) for _, c in pairs(buttonCallbacks[name]) do c(ns) end end
	b.MouseButton1Click:Connect(function() upd(not s) end)
	textUpdater(b, s, name)
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
	local b = create("TextButton", {Size = UDim2.new(0, 60, 0, 20), Position = UDim2.new(1, -65, 0.5, -10), BackgroundColor3 = colors.Button, Text = def and (def:IsA("KeyCode") and def.Name or (def == Enum.UserInputType.MouseButton1 and "Left Click" or def == Enum.UserInputType.MouseButton2 and "Right Click" or "Middle Click")) or "None", TextColor3 = colors.Text, TextSize = 12, Font = Enum.Font.FredokaOne, Parent = f})
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
					keybinds[name] = i.KeyCode
					b.Text = i.KeyCode.Name
				end
			elseif i.UserInputType == Enum.UserInputType.MouseButton1 then
				keybinds[name] = Enum.UserInputType.MouseButton1
				b.Text = "Left Click"
			elseif i.UserInputType == Enum.UserInputType.MouseButton2 then
				keybinds[name] = Enum.UserInputType.MouseButton2
				b.Text = "Right Click"
			elseif i.UserInputType == Enum.UserInputType.MouseButton3 then
				keybinds[name] = Enum.UserInputType.MouseButton3
				b.Text = "Middle Click"
			end
			c:Disconnect()
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
			if os and (Vector2.new(pp.X, pp.Y) - mp).Magnitude <= aimlockFOV then
				return p
			end
		end
	end
	for _, p in pairs(cachedPlayers) do
		if p ~= player then
			local part = p.Character and p.Character:FindFirstChild(aimlockTargetPart == "Head" and "Head" or "HumanoidRootPart")
			if part then
				local pp, os = camera:WorldToViewportPoint(part.Position)
				if os then
					local d = (Vector2.new(pp.X, pp.Y) - mp).Magnitude
					if d <= aimlockFOV and d < md then
						c = part
						md = d
					end
				end
			end
		end
	end
	return c
end

local function updateESP()
	if not espActive then
		for p, h in pairs(espHighlights) do
			if h then h:Destroy() end
			espHighlights[p] = nil
		end
		for p, n in pairs(espNames) do
			if n then n:Destroy() end
			espNames[p] = nil
		end
		for p, b in pairs(espBoxes) do
			if b then b:Destroy() end
			espBoxes[p] = nil
		end
		for p, t in pairs(espTracers) do
			if t then t:Destroy() end
			espTracers[p] = nil
		end
		return
	end
	local currentPlayers = {}
	for _, p in pairs(Players:GetPlayers()) do
		if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			currentPlayers[p] = true
			if not espHighlights[p] then
				local h = Instance.new("Highlight")
				h.FillColor = colors.ESP
				h.FillTransparency = 0.7
				h.OutlineColor = colors.ESP
				h.OutlineTransparency = 0
				h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				h.Parent = p.Character
				espHighlights[p] = h
			end
			if not espNames[p] then
				local ng = create("BillboardGui", {Size = UDim2.new(0, 100, 0, 50), StudsOffset = Vector3.new(0, 3, 0), Adornee = p.Character:WaitForChild("Head"), AlwaysOnTop = true, Parent = p.Character})
				create("TextLabel", {Size = UDim2.new(1, 0, 1, 0), Text = p.Name, TextColor3 = colors.ESP, TextSize = 14, BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, Parent = ng})
				espNames[p] = ng
			end
			if espBoxActive and not espBoxes[p] then
				local b = Instance.new("BoxHandleAdornment")
				b.Size = Vector3.new(5, 5, 5)
				b.Color3 = colors.ESP
				b.Transparency = 0.7
				b.AlwaysOnTop = true
				b.Adornee = p.Character.HumanoidRootPart
				b.Parent = p.Character
				espBoxes[p] = b
			end
			if espTracerActive and rootPart and not espTracers[p] then
				local t = Instance.new("Beam")
				t.Color = ColorSequence.new(colors.ESP)
				t.Width0 = 0.2
				t.Width1 = 0.2
				t.Transparency = NumberSequence.new(0.3)
				t.Attachment0 = create("Attachment", {Parent = rootPart})
				t.Attachment1 = create("Attachment", {Parent = p.Character.HumanoidRootPart})
				t.Parent = rootPart
				espTracers[p] = t
			end
			if espHighlights[p] then espHighlights[p].Enabled = true end
			if espNames[p] then espNames[p].Enabled = true end
			if espBoxes[p] then espBoxes[p].Visible = espBoxActive end
			if espTracers[p] then espTracers[p].Enabled = espTracerActive end
		end
	end
	for p in pairs(espHighlights) do
		if not currentPlayers[p] then
			if espHighlights[p] then espHighlights[p]:Destroy() end
			if espNames[p] then espNames[p]:Destroy() end
			if espBoxes[p] then espBoxes[p]:Destroy() end
			if espTracers[p] then espTracers[p]:Destroy() end
			espHighlights[p] = nil
			espNames[p] = nil
			espBoxes[p] = nil
			espTracers[p] = nil
		end
	end
end

Players.PlayerAdded:Connect(function(p)
	cachedPlayers = Players:GetPlayers()
	if espActive then updateESP() end
end)

Players.PlayerRemoving:Connect(function(p)
	cachedPlayers = Players:GetPlayers()
	if espHighlights[p] then
		espHighlights[p]:Destroy() espHighlights[p] = nil
		if espNames[p] then espNames[p]:Destroy() espNames[p] = nil end
		if espBoxes[p] then espBoxes[p]:Destroy() espBoxes[p] = nil end
		if espTracers[p] then espTracers[p]:Destroy() espTracers[p] = nil end
	end
end)

task.spawn(function()
	while true do
		if espActive then updateESP() end
		task.wait(5)
	end
end)

addSlider("Saturation", -1, 2, 0, 0, function(v) if v ~= colorCorrection.Saturation then colorCorrection.Saturation = v end end, visualsTab, false, false)
addSlider("FOV", 30, 120, 70, 40, function(v) if v ~= camera.FieldOfView then camera.FieldOfView = v end end, visualsTab, false, true)
addSlider("Time", 0, 24, originalSettings.ClockTime, 80, function(v) Lighting.ClockTime = v end, visualsTab, false, false)
local ef, et = addToggle("ESP", false, 120, function(on) espActive = on updateESP() end, visualsTab)
local cb = create("TextButton", {Size = UDim2.new(0, 50, 0, 20), Position = UDim2.new(0.55, 0, 0, 10), BackgroundColor3 = colors.ESP, Text = "Color", TextColor3 = colors.Text, TextSize = 12, Font = Enum.Font.FredokaOne, Parent = ef})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = cb})
local function boxTextUpdater(b, s) b.Text = s and "Unbox" or "Box" end
local boxBtn, boxToggle = addButton("Box", 40, 125, function(s) espBoxActive = s updateESP() end, visualsTab, false, 60, boxTextUpdater)
local function tracerTextUpdater(b, s) b.Text = s and "Untrace" or "Trace" end
local tracerBtn, tracerToggle = addButton("Trace", 110, 125, function(s) espTracerActive = s updateESP() end, visualsTab, false, 60, tracerTextUpdater)
addToggle("Infinite Zoom", false, 160, function(on) player.CameraMaxZoomDistance = on and 1000000 or originalSettings.MaxZoom end, visualsTab)
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
		for p, t in pairs(originalSettings.Transparency) do
			if p.Parent then p.Transparency = t else originalSettings.Transparency[p] = nil end
		end
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
		for p, m in pairs(originalSettings.Materials) do
			if p.Parent then p.Material = m else originalSettings.Materials[p] = nil end
		end
	end
end, visualsTab)
visualsTab.CanvasSize = UDim2.new(0, 0, 0, 290)

local csf, cst
local ff, flyToggle
csf, cst = addToggle("CFrame Speed", false, 0, function(on)
	if not rootPart then return end
	cframeSpeedActive = on
	if on and flyActive then flyToggle(false) end
end, playerTab)
local csi = create("TextBox", {Size = UDim2.new(0.15, 0, 0, 20), Position = UDim2.new(0.6, 0, 0.5, -10), BackgroundColor3 = colors.Button, Text = tostring(cframeSpeedValue), TextColor3 = colors.Text, TextSize = 12, Font = Enum.Font.FredokaOne, ClearTextOnFocus = false, Parent = csf})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = csi})
csi.FocusLost:Connect(function(e)
	if e then
		local v = tonumber(csi.Text)
		if v then cframeSpeedValue = math.clamp(v, 50, 50000) end
	end
end)
ff, flyToggle = addToggle("Fly", false, 40, function(on)
	if not rootPart or not humanoid then return end
	flyActive = on
	if on and cframeSpeedActive then cst(false) end
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
local fsi = create("TextBox", {Size = UDim2.new(0.15, 0, 0, 20), Position = UDim2.new(0.6, 0, 0.5, -10), BackgroundColor3 = colors.Button, Text = tostring(flySpeedValue), TextColor3 = colors.Text, TextSize = 12, Font = Enum.Font.FredokaOne, ClearTextOnFocus = false, Parent = ff})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = fsi})
fsi.FocusLost:Connect(function(e)
	if e then
		local v = tonumber(fsi.Text)
		if v then flySpeedValue = math.clamp(v, 50, 50000) end
	end
end)
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
local fcsi = create("TextBox", {Size = UDim2.new(0.15, 0, 0, 20), Position = UDim2.new(0.6, 0, 0.5, -10), BackgroundColor3 = colors.Button, Text = tostring(freeCamSpeed), TextColor3 = colors.Text, TextSize = 12, Font = Enum.Font.FredokaOne, ClearTextOnFocus = false, Parent = fcf})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = fcsi})
fcsi.FocusLost:Connect(function(e)
	if e then
		local v = tonumber(fcsi.Text)
		if v then freeCamSpeed = math.clamp(v, 50, 50000) end
	end
end)
addToggle("Noclip", false, 120, function(on) noclipActive = on end, playerTab)
addToggle("Click Teleport", false, 160, function(on) clickTeleportActive = on end, playerTab)
addVoiceChatUnban(200, playerTab)
local antiFlingActive = false
local antiFlingBtn, antiFlingToggle = addToggle("Anti Fling", false, 240, function(on)
	antiFlingActive = on
	if on then
		RunService.RenderStepped:Connect(function()
			if antiFlingActive and rootPart then
				local velocity = rootPart.Velocity
				if velocity.Magnitude > 500 then
					rootPart.Velocity = Vector3.new(0, velocity.Y, 0)
				end
			end
		end)
	end
end, playerTab)
local rejoinBtn = addActionButton("Rejoin", 10, 280, function()
	game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
end, playerTab, 120)
local serverHopBtn = addActionButton("Server Hop", 140, 280, function()
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
		if #servers > 0 then
			game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], player)
		end
	end
end, playerTab, 120)
local jerkBtn = addActionButton("Jerk", 270, 280, function()
	if not character then return end
	local isR6 = character:FindFirstChild("Torso") ~= nil
	local scriptUrl = isR6 and "https://pastefy.app/wa3v2Vgm/raw" or "https://pastefy.app/YZoglOyJ/raw"
	local jerkScript = loadstring(game:HttpGet(scriptUrl))
	if jerkScript then jerkScript() end
end, playerTab, 120)
playerTab.CanvasSize = UDim2.new(0, 0, 0, 330)

local af, at = addToggle("Aimlock", false, 0, function(on) aimlockActive = on if not on then lockedTarget = nil aimlockLocked = false end end, combatTab)
local asf = create("Frame", {Size = UDim2.new(1, 0, 0, 200), Position = UDim2.new(0, 0, 0, 40), BackgroundTransparency = 1, Parent = combatTab})
local sb, st = addButton("Silent Aim", 0, 0, function(s) silentAimActive = s end, asf, false, 80)
local pb, pt = addButton("Prediction", 90, 0, function(s) predictionActive = s end, asf, false, 80)
local thb, tht = addButton("Toggle", 180, 0, function(s)
	aimlockToggleMode = s
	thb.Text = s and "Toggle" or "Hold"
	lockedTarget = nil
	aimlockLocked = false
end, asf, false, 80)
local hb, ht = addButton("Head", 270, 0, function(s)
	aimlockTargetPart = aimlockTargetPart == "Head" and "Torso" or "Head"
	lockedTarget = nil
	hb.Text = aimlockTargetPart
end, asf, true, 80)
local fovFrame = addSlider("Aimlock FOV", 30, 320, aimlockFOV, 35, function(v)
	aimlockFOV = v
	if fovCone then
		fovCone.Size = UDim2.new(0, v * 2, 0, v * 2)
		fovCone.Position = UDim2.new(0.5, -v, 0.5, -v)
	end
end, asf, false, true)
local fovLockBtn = create("ImageButton", {Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(0, 110, 0.5, -10), BackgroundColor3 = colors.Button, Image = "rbxassetid://6023565895", ImageColor3 = colors.Text, Parent = fovFrame})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = fovLockBtn})
fovLockBtn.MouseButton1Click:Connect(function()
	showFOVCone = not showFOVCone
	fovLockBtn.BackgroundColor3 = showFOVCone and colors.ToggleOn or colors.Button
	if not fovCone and showFOVCone then
		fovCone = create("Frame", {Size = UDim2.new(0, aimlockFOV * 2, 0, aimlockFOV * 2), Position = UDim2.new(0.5, -aimlockFOV, 0.5, -aimlockFOV), BackgroundTransparency = 0.7, BackgroundColor3 = colors.Outline, BorderSizePixel = 0, Parent = gui})
		create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = fovCone})
	elseif fovCone and not showFOVCone then
		fovCone:Destroy()
		fovCone = nil
	end
	if fovCone then fovCone.Visible = showFOVCone end
end)
combatTab.CanvasSize = UDim2.new(0, 0, 0, 240)

local targetInputFrame = create("Frame", {Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1, Parent = targetTab})
local targetInput = create("TextBox", {Size = UDim2.new(0.7, 0, 1, 0), Position = UDim2.new(0, 5, 0, 0), BackgroundColor3 = colors.Button, Text = "", TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, PlaceholderText = "Enter player name", ClearTextOnFocus = false, Parent = targetInputFrame})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = targetInput})
local clickTargetBtn = create("ImageButton", {Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(0.75, 0, 0, 5), BackgroundTransparency = 1, Image = "rbxassetid://2716591855", Parent = targetInputFrame})
local targetImage = create("ImageLabel", {Size = UDim2.new(0, 100, 0, 100), Position = UDim2.new(0, 10, 0, 50), BackgroundColor3 = colors.Background, Image = "rbxassetid://10818605405", Parent = targetTab})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = targetImage})
local userInfoLabel = create("TextLabel", {Size = UDim2.new(0, 200, 0, 75), Position = UDim2.new(0, 120, 0, 50), BackgroundTransparency = 1, Text = "UserID: \nDisplay: \nJoined: ", TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = targetTab})

local predictionIndicator = nil
local targetPredictionFrame = create("Frame", {Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, 130), BackgroundTransparency = 1, Parent = targetTab})
create("TextLabel", {Size = UDim2.new(0.6, 0, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = "Target Prediction", TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = targetPredictionFrame})
local targetPredictionToggle, targetPredictionUpdate = addToggle("", false, 0, function(on)
	predictionActive = on
	targetActive = on
	if predictionIndicator then
		predictionIndicator:Destroy()
		predictionIndicator = nil
	end
	if on and targetedPlayer and targetedPlayer.Character then
		local targetRoot = targetedPlayer.Character:FindFirstChild("HumanoidRootPart")
		if targetRoot then
			predictionIndicator = Instance.new("Highlight")
			predictionIndicator.FillColor = Color3.fromRGB(255, 0, 0)
			predictionIndicator.OutlineColor = Color3.fromRGB(255, 0, 0)
			predictionIndicator.FillTransparency = 0.7
			predictionIndicator.OutlineTransparency = 0.3
			predictionIndicator.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			predictionIndicator.Adornee = targetedPlayer.Character
			predictionIndicator.Parent = targetedPlayer.Character
		end
	end
end, targetPredictionFrame)

local viewActive = false
local viewBtn, viewToggle = addButton("View", 10, 160, function(s)
	viewActive = s
	if s then
		if targetedPlayer and not table.find(ScriptWhitelist, targetedPlayer.UserId) then
			if targetedPlayer.Character and targetedPlayer.Character:FindFirstChild("Humanoid") then
				camera.CameraSubject = targetedPlayer.Character.Humanoid
			end
		else
			notify("System Broken", "Cannot view whitelisted player.", 5)
			viewToggle(false)
		end
	else
		camera.CameraSubject = character and character.Humanoid
	end
end, targetTab, false, 120)

local teleportBtn = addActionButton("Teleport", 140, 160, function()
	if targetedPlayer and not table.find(ScriptWhitelist, targetedPlayer.UserId) then
		if targetedPlayer.Character and targetedPlayer.Character:FindFirstChild("HumanoidRootPart") then
			rootPart.CFrame = targetedPlayer.Character.HumanoidRootPart.CFrame + Vector3.new(0, 2, 0)
		end
	else
		notify("System Broken", "Cannot teleport to whitelisted player.", 5)
	end
end, targetTab, 120)

local headsitActive = false
local headsitBtn, headsitToggle = addButton("Headsit", 10, 200, function(s)
	headsitActive = s
	if s then
		if targetedPlayer and not table.find(ScriptWhitelist, targetedPlayer.UserId) then
			task.spawn(function()
				while headsitActive do
					if targetedPlayer and targetedPlayer.Character and targetedPlayer.Character:FindFirstChild("Head") then
						humanoid.Sit = true
						rootPart.CFrame = targetedPlayer.Character.Head.CFrame * CFrame.new(0, 2, 0)
						rootPart.Velocity = Vector3.new(0, 0, 0)
						task.wait()
					else
						task.wait()
					end
				end
			end)
		else
			notify("System Broken", "Cannot headsit whitelisted player.", 5)
			headsitToggle(false)
		end
	end
end, targetTab, false, 120)

local standActive = false
local standBtn, standToggle = addButton("Stand", 140, 200, function(s)
	standActive = s
	if s then
		if targetedPlayer and not table.find(ScriptWhitelist, targetedPlayer.UserId) then
			PlayAnim(13823324057, 4, 0)
			task.spawn(function()
				while standActive do
					if targetedPlayer and targetedPlayer.Character and targetedPlayer.Character:FindFirstChild("HumanoidRootPart") then
						rootPart.CFrame = targetedPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(-3, 1, 0)
						rootPart.Velocity = Vector3.new(0, 0, 0)
						task.wait()
					else
						task.wait()
					end
				end
				StopAnim()
			end)
		else
			notify("System Broken", "Cannot stand on whitelisted player.", 5)
			standToggle(false)
		end
	end
end, targetTab, false, 120)

local bangActive = false
local bangBtn, bangToggle = addButton("Bang", 10, 240, function(s)
	bangActive = s
	if s then
		if targetedPlayer and not table.find(ScriptWhitelist, targetedPlayer.UserId) then
			PlayAnim(5918726674, 0, 1)
			task.spawn(function()
				while bangActive do
					if targetedPlayer and targetedPlayer.Character and targetedPlayer.Character:FindFirstChild("HumanoidRootPart") then
						rootPart.CFrame = targetedPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 1.1)
						rootPart.Velocity = Vector3.new(0, 0, 0)
						task.wait()
					else
						task.wait()
					end
				end
				StopAnim()
			end)
		else
			notify("System Broken", "Cannot bang whitelisted player.", 5)
			bangToggle(false)
		end
	end
end, targetTab, false, 120)

local flingActive = false
local flingVelocityTask
local flingOldPos
local flingBtn, flingToggle = addButton("Fling", 140, 240, function(s)
	if s then
		if targetedPlayer and not table.find(ScriptWhitelist, targetedPlayer.UserId) then
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
						rootPart.CFrame = targetedPlayer.Character.HumanoidRootPart.CFrame
						task.wait()
					else
						task.wait()
					end
				end
			end)
		else
			notify("System Broken", "Cannot fling whitelisted player.", 5)
		end
	else
		flingActive = false
		if flingOldPos then
			task.spawn(function()
				local startTime = tick()
				while tick() - startTime < 2 do
					if rootPart then
						rootPart.CFrame = CFrame.new(flingOldPos)
						rootPart.Velocity = Vector3.new(0, 0, 0)
					end
					RunService.Heartbeat:Wait()
				end
			end)
		end
	end
end, targetTab, false, 120)

local backpackActive = false
local backpackBtn, backpackToggle = addButton("Backpack", 10, 280, function(s)
	backpackActive = s
	if s then
		if targetedPlayer and not table.find(ScriptWhitelist, targetedPlayer.UserId) then
			task.spawn(function()
				while backpackActive do
					if targetedPlayer and targetedPlayer.Character and targetedPlayer.Character:FindFirstChild("HumanoidRootPart") then
						humanoid.Sit = true
						rootPart.CFrame = targetedPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 1.2) * CFrame.Angles(0, -3, 0)
						rootPart.Velocity = Vector3.new(0, 0, 0)
						task.wait()
					else
						task.wait()
					end
				end
			end)
		else
			notify("System Broken", "Cannot backpack whitelisted player.", 5)
			backpackToggle(false)
		end
	end
end, targetTab, false, 120)

local doggyActive = false
local doggyBtn, doggyToggle = addButton("Doggy", 140, 280, function(s)
	doggyActive = s
	if s then
		if targetedPlayer and not table.find(ScriptWhitelist, targetedPlayer.UserId) then
			PlayAnim(13694096724, 3.4, 0)
			task.spawn(function()
				while doggyActive do
					if targetedPlayer and targetedPlayer.Character and targetedPlayer.Character:FindFirstChild("LowerTorso") then
						rootPart.CFrame = targetedPlayer.Character.LowerTorso.CFrame * CFrame.new(0, 0.23, 0)
						rootPart.Velocity = Vector3.new(0, 0, 0)
						task.wait()
					else
						task.wait()
					end
				end
				StopAnim()
			end)
		else
			notify("System Broken", "Cannot doggy whitelisted player.", 5)
			doggyToggle(false)
		end
	end
end, targetTab, false, 120)

local dragActive = false
local dragBtn, dragToggle = addButton("Drag", 10, 320, function(s)
	dragActive = s
	if s then
		if targetedPlayer and not table.find(ScriptWhitelist, targetedPlayer.UserId) then
			PlayAnim(10714360343, 0.5, 0)
			task.spawn(function()
				while dragActive do
					if targetedPlayer and targetedPlayer.Character and targetedPlayer.Character:FindFirstChild("RightHand") then
						rootPart.CFrame = targetedPlayer.Character.RightHand.CFrame * CFrame.new(0, -2.5, 1) * CFrame.Angles(-2, -3, 0)
						rootPart.Velocity = Vector3.new(0, 0, 0)
						task.wait()
					else
						task.wait()
					end
				end
				StopAnim()
			end)
		else
			notify("System Broken", "Cannot drag whitelisted player.", 5)
			dragToggle(false)
		end
	end
end, targetTab, false, 120)

local whitelistBtn = addActionButton("Whitelist", 140, 320, function()
	if targetedPlayer then
		if table.find(ScriptWhitelist, targetedPlayer.UserId) then
			for i, v in pairs(ScriptWhitelist) do
				if v == targetedPlayer.UserId then table.remove(ScriptWhitelist, i) end
			end
			notify("System Broken", targetedPlayer.Name .. " removed from whitelist.", 5)
		else
			table.insert(ScriptWhitelist, targetedPlayer.UserId)
			notify("System Broken", targetedPlayer.Name .. " added to whitelist.", 5)
		end
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
			if not person and hit.Parent:IsA("Accessory") then
				person = Players:GetPlayerFromCharacter(hit.Parent.Parent)
			end
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
targetTab.CanvasSize = UDim2.new(0, 0, 0, 370)

local function applyAnimation(idle1, idle2, walk, run, jump, climb, fall)
	pcall(function()
		local Animate = character:FindFirstChild("Animate")
		if not Animate then warn("Animate script not found in character!") return end
		Animate.Disabled = true
		StopAnim()
		local animation1 = Animate.idle:FindFirstChild("Animation1")
		if animation1 then animation1.AnimationId = "rbxassetid://" .. idle1 else warn("Animation1 not found!") end
		local animation2 = Animate.idle:FindFirstChild("Animation2")
		if animation2 then animation2.AnimationId = "rbxassetid://" .. idle2 else warn("Animation2 not found!") end
		local walkAnim = Animate.walk:FindFirstChild("WalkAnim")
		if walkAnim then walkAnim.AnimationId = "rbxassetid://" .. walk else warn("WalkAnim not found!") end
		local runAnim = Animate.run:FindFirstChild("RunAnim")
		if runAnim then runAnim.AnimationId = "rbxassetid://" .. run else warn("RunAnim not found!") end
		local jumpAnim = Animate.jump:FindFirstChild("JumpAnim")
		if jumpAnim then jumpAnim.AnimationId = "rbxassetid://" .. jump else warn("JumpAnim not found!") end
		local climbAnim = Animate.climb:FindFirstChild("ClimbAnim")
		if climbAnim then climbAnim.AnimationId = "rbxassetid://" .. climb else warn("ClimbAnim not found!") end
		local fallAnim = Animate.fall:FindFirstChild("FallAnim")
		if fallAnim then fallAnim.AnimationId = "rbxassetid://" .. fall else warn("FallAnim not found!") end
		character.Humanoid:ChangeState(3)
		Animate.Disabled = false
	end)
end

local function applyCustomAnimations()
	pcall(function()
		local Animate = character:FindFirstChild("Animate")
		if not Animate then warn("Animate script not found in character!") return end
		Animate.Disabled = true
		StopAnim()
		if animationStages.idle.id ~= "" then
			local animation1 = Animate.idle:FindFirstChild("Animation1")
			if animation1 then animation1.AnimationId = "rbxassetid://" .. animationStages.idle.id end
			local animation2 = Animate.idle:FindFirstChild("Animation2")
			if animation2 then animation2.AnimationId = "rbxassetid://" .. animationStages.idle.id end
		end
		if animationStages.walk.id ~= "" then
			local walkAnim = Animate.walk:FindFirstChild("WalkAnim")
			if walkAnim then walkAnim.AnimationId = "rbxassetid://" .. animationStages.walk.id end
		end
		if animationStages.run.id ~= "" then
			local runAnim = Animate.run:FindFirstChild("RunAnim")
			if runAnim then runAnim.AnimationId = "rbxassetid://" .. animationStages.run.id end
		end
		if animationStages.jump.id ~= "" then
			local jumpAnim = Animate.jump:FindFirstChild("JumpAnim")
			if jumpAnim then jumpAnim.AnimationId = "rbxassetid://" .. animationStages.jump.id end
		end
		if animationStages.climb.id ~= "" then
			local climbAnim = Animate.climb:FindFirstChild("ClimbAnim")
			if climbAnim then climbAnim.AnimationId = "rbxassetid://" .. animationStages.climb.id end
		end
		if animationStages.fall.id ~= "" then
			local fallAnim = Animate.fall:FindFirstChild("FallAnim")
			if fallAnim then fallAnim.AnimationId = "rbxassetid://" .. animationStages.fall.id end
		end
		if animationStages.swim.id ~= "" then
			local swimAnim = Animate.swim:FindFirstChild("SwimAnim")
			if swimAnim then swimAnim.AnimationId = "rbxassetid://" .. animationStages.swim.id end
			local swimIdle = Animate.swim:FindFirstChild("SwimIdle")
			if swimIdle then swimIdle.AnimationId = "rbxassetid://" .. animationStages.swim.id end
		end
		character.Humanoid:ChangeState(3)
		Animate.Disabled = false
	end)
end

local animButtonsFrame = create("Frame", {Size = UDim2.new(1, 0, 0, 400), Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1, Parent = animationsTab})
local animGrid = create("UIGridLayout", {CellSize = UDim2.new(0, 90, 0, 25), CellPadding = UDim2.new(0, 10, 0, 10), Parent = animButtonsFrame})
local animStagesFrame = create("Frame", {Size = UDim2.new(1, 0, 0, 280), Position = UDim2.new(0, 0, 0, 410), BackgroundTransparency = 1, Parent = animationsTab})
local divider = create("Frame", {Size = UDim2.new(0.9, 0, 0, 2), Position = UDim2.new(0.05, 0, 0, 395), BackgroundColor3 = colors.Outline, BackgroundTransparency = 0.5, Parent = animationsTab})
create("UICorner", {CornerRadius = UDim.new(0, 1), Parent = divider})
create("TextLabel", {Size = UDim2.new(1, 0, 0, 25), Position = UDim2.new(0, 0, 0, 380), BackgroundTransparency = 1, Text = "Custom Animation Controls", TextColor3 = colors.Text, TextSize = 16, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Center, Parent = animationsTab})

local loadPresetBtn = create("TextButton", {Size = UDim2.new(0, 120, 0, 25), Position = UDim2.new(0.5, -60, 0, 330), BackgroundColor3 = colors.Button, Text = "Load to Custom", TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, Parent = animationsTab})
create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = loadPresetBtn})
loadPresetBtn.MouseButton1Click:Connect(function()
	if lastSelectedPreset then
		local name, idle1, idle2, walk, run, jump, climb, fall = unpack(lastSelectedPreset)
		animationStages.idle.id = idle1
		animationStages.walk.id = walk
		animationStages.run.id = run
		animationStages.jump.id = jump
		animationStages.climb.id = climb
		animationStages.fall.id = fall
		animationStages.swim.id = idle1
		for stage, info in pairs(animationStages) do
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
	create("TextLabel", {Size = UDim2.new(0, 60, 1, 0), Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1, Text = animationStages[stage].name, TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = stageFrame})
	local selectBtn = create("TextButton", {Size = UDim2.new(0, 25, 0, 25), Position = UDim2.new(0, 70, 0, 2), BackgroundColor3 = colors.Button, Text = "⊕", TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, Parent = stageFrame})
	create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = selectBtn})
	local idInput = create("TextBox", {Size = UDim2.new(0, 100, 0, 25), Position = UDim2.new(0, 105, 0, 2), BackgroundColor3 = colors.Button, Text = animationStages[stage].id, PlaceholderText = "ID", TextColor3 = colors.Text, TextSize = 12, Font = Enum.Font.FredokaOne, ClearTextOnFocus = false, Parent = stageFrame})
	create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = idInput})
	idInput.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			animationStages[stage].id = idInput.Text
		end
	end)
	selectBtn.MouseButton1Click:Connect(function()
		selectedAnimStage = stage
		for _, child in pairs(animStagesFrame:GetChildren()) do
			if child:IsA("Frame") then
				local btn = child:FindFirstChildOfClass("TextButton")
				if btn then btn.BackgroundColor3 = colors.Button end
			end
		end
		selectBtn.BackgroundColor3 = colors.ToggleOn
	end)
	return stageFrame
end

local stageOffset = 0
for stage, info in pairs(animationStages) do
	addAnimStageRow(stage, stageOffset)
	stageOffset = stageOffset + 35
end

local applyBtn = create("TextButton", {Size = UDim2.new(0, 120, 0, 30), Position = UDim2.new(0.5, -60, 0, stageOffset + 10), BackgroundColor3 = colors.Interface, Text = "Apply Animations", TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, Parent = animStagesFrame})
create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = applyBtn})
applyBtn.MouseButton1Click:Connect(applyCustomAnimations)

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
	{"FE Zombie", "3489171152", "3489171152", "3489174223", "3489173414", "616161997", "616156119", "616157476"}
}

for _, anim in pairs(animButtons) do
	local name, idle1, idle2, walk, run, jump, climb, fall = unpack(anim)
	local b = create("TextButton", {Size = UDim2.new(0, 90, 0, 25), BackgroundColor3 = colors.Button, Text = name, TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, Parent = animButtonsFrame})
	create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = b})
	b.MouseButton1Click:Connect(function()
		lastSelectedPreset = anim
		if selectedAnimStage then
			local stageId = ""
			if selectedAnimStage == "idle" then stageId = idle1
			elseif selectedAnimStage == "walk" then stageId = walk
			elseif selectedAnimStage == "run" then stageId = run
			elseif selectedAnimStage == "jump" then stageId = jump
			elseif selectedAnimStage == "climb" then stageId = climb
			elseif selectedAnimStage == "fall" then stageId = fall
			elseif selectedAnimStage == "swim" then stageId = idle1
			end
			if stageId ~= "" then
				animationStages[selectedAnimStage].id = stageId
				for _, child in pairs(animStagesFrame:GetChildren()) do
					if child:IsA("Frame") then
						local stageName = child:FindFirstChildOfClass("TextLabel")
						if stageName and stageName.Text == animationStages[selectedAnimStage].name then
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

addKeybind("Menu", keybinds.Menu, 0)
addKeybind("Aimlock", keybinds.Aimlock, 30)
addKeybind("ESP", keybinds.ESP, 60)
addKeybind("ClickTeleport", keybinds.ClickTeleport, 90)
addKeybind("Fly", keybinds.Fly, 120)
addKeybind("FreeCam", keybinds.FreeCam, 150)
addKeybind("CFrameSpeed", keybinds.CFrameSpeed, 180)
addSlider("", 0, 1, menuTransparency, 210, function(v)
	menuTransparency = v
	mainFrame.BackgroundTransparency = v
	keybindsFrame.BackgroundTransparency = v
end, keybindsScroll, true, false).BackgroundTransparency = 1

local cpf = create("Frame", {Size = UDim2.new(0, 200, 0, 150), Position = UDim2.new(0.5, -100, 0.5, -75), BackgroundColor3 = colors.Background, Visible = false, Parent = gui})
create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = cpf})
local db = create("Frame", {Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = colors.Header, Parent = cpf})
create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = db})
create("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "ESP Color Picker", TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Center, Parent = db})
local cbx = create("TextButton", {Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(1, -25, 0, 0), BackgroundColor3 = colors.Button, Text = "X", TextColor3 = colors.Text, TextSize = 12, Font = Enum.Font.FredokaOne, Parent = db})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = cbx})
cbx.MouseButton1Click:Connect(function() cpf.Visible = false end)
local cp = create("Frame", {Size = UDim2.new(0, 180, 0, 20), Position = UDim2.new(0, 10, 0, 120), BackgroundColor3 = colors.ESP, Parent = cpf})
create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = cp})
local function createColorSlider(l, min, max, y, cb)
	local sf = create("Frame", {Size = UDim2.new(0, 180, 0, 20), Position = UDim2.new(0, 10, 0, y), BackgroundColor3 = colors.Button, Parent = cpf})
	create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = sf})
	local f = create("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = colors.Interface, Parent = sf})
	create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = f})
	create("TextLabel", {Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(-0.15, 0, 0, 0), BackgroundTransparency = 1, Text = l, TextColor3 = colors.Text, TextSize = 14, Font = Enum.Font.FredokaOne, Parent = sf})
	local d = false
	sf.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then d = true end end)
	UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then d = false end end)
	UserInputService.InputChanged:Connect(function(i)
		if d and i.UserInputType == Enum.UserInputType.MouseMovement then
			local p = math.clamp((i.Position.X - sf.AbsolutePosition.X) / sf.AbsoluteSize.X, 0, 1)
			f.Size = UDim2.new(p, 0, 1, 0)
			cb(min + (max - min) * p)
		end
	end)
	return f
end
local hf = createColorSlider("H", 0, 360, 30, function(v) colors.ESP = Color3.fromHSV(v / 360, colors.ESP:ToHSV()) cp.BackgroundColor3 = colors.ESP cb.BackgroundColor3 = colors.ESP updateESP() end)
local sf = createColorSlider("S", 0, 1, 60, function(v) local h = colors.ESP:ToHSV() colors.ESP = Color3.fromHSV(h, v, select(3, colors.ESP:ToHSV())) cp.BackgroundColor3 = colors.ESP cb.BackgroundColor3 = colors.ESP updateESP() end)
local vf = createColorSlider("V", 0, 1, 90, function(v) local h, s = colors.ESP:ToHSV() colors.ESP = Color3.fromHSV(h, s, v) cp.BackgroundColor3 = colors.ESP cb.BackgroundColor3 = colors.ESP updateESP() end)
local function openColorPicker()
	if cpf.Visible then cpf.Visible = false else
		cpf.Visible = true
		local h, s, v = colors.ESP:ToHSV()
		hf.Size = UDim2.new(h, 0, 1, 0)
		sf.Size = UDim2.new(s, 0, 1, 0)
		vf.Size = UDim2.new(v, 0, 1, 0)
		cp.BackgroundColor3 = colors.ESP
	end
end
cb.MouseButton1Click:Connect(openColorPicker)
local dc, ds, sp
db.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dc = true ds = i.Position sp = cpf.Position end end)
UserInputService.InputChanged:Connect(function(i) if dc and i.UserInputType == Enum.UserInputType.MouseMovement then local d = i.Position - ds cpf.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y) end end)
UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dc = false end end)
tabs["Visuals"].BackgroundColor3 = colors.TabSelected
tabContents["Visuals"].Visible = true

local function isBindDown(bind)
	if bind == nil then return false end
	if bind:IsA("KeyCode") then
		return UserInputService:IsKeyDown(bind)
	elseif bind:IsA("UserInputType") then
		if bind == Enum.UserInputType.MouseButton1 or bind == Enum.UserInputType.MouseButton2 or bind == Enum.UserInputType.MouseButton3 then
			return UserInputService:IsMouseButtonPressed(bind)
		end
	end
	return false
end

local function isBindPressed(bind, input)
	if bind == nil then return false end
	if bind:IsA("KeyCode") then
		return input.KeyCode == bind
	elseif bind:IsA("UserInputType") then
		return input.UserInputType == bind
	end
	return false
end

RunService.RenderStepped:Connect(function(dt)
	if not character or not rootPart then return end
	local cf = camera.CFrame
	if viewTarget then camera.CameraType = Enum.CameraType.Follow return end
	local movement = nil
	if aimlockActive then
		local t = lockedTarget or getTargetInFOV()
		if t then
			if aimlockToggleMode then
				if aimlockLocked then lockedTarget = t else lockedTarget = nil end
			else
				lockedTarget = isBindDown(keybinds.Aimlock) and t or nil
			end
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
	if cframeSpeedActive then
		movement = movement or getMovement(cf, false)
		if movement.Magnitude > 0 then
			local mxz = Vector3.new(movement.X, 0, movement.Z).Unit * cframeSpeedValue * dt
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
		if movement.Magnitude > 0 then
			freeCamPosition = clampPosition(freeCamPosition + movement.Unit * freeCamSpeed * freeCamBoost * dt)
		end
		camera.CFrame = CFrame.new(freeCamPosition) * CFrame.Angles(0, freeCamYaw, 0) * CFrame.Angles(freeCamPitch, 0, 0)
	end
	if noclipActive then
		for _, p in pairs(character:GetDescendants()) do
			if p:IsA("BasePart") then p.CanCollide = false end
		end
	end
end)

local function updateCharacter(c)
	if not c then return end
	character = c
	rootPart = c:WaitForChild("HumanoidRootPart", 3)
	humanoid = c:WaitForChild("Humanoid", 3)
	if not rootPart then warn("No HumanoidRootPart!") return end
	task.wait(0.5)
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
	if espTracerActive then updateESP() end
end
player.CharacterAdded:Connect(updateCharacter)
if player.Character then updateCharacter(player.Character) end

local d, ds, spos
header.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then d = true ds = i.Position spos = mainFrame.Position end end)
UserInputService.InputChanged:Connect(function(i) if d and i.UserInputType == Enum.UserInputType.MouseMovement then local delta = i.Position - ds mainFrame.Position = UDim2.new(spos.X.Scale, spos.X.Offset + delta.X, spos.Y.Scale, spos.Y.Offset + delta.Y) end end)
UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then d = false end end)

local r = false
local function toggleMenu()
	mainFrame.Visible = not mainFrame.Visible
	mainFrame.Position = mainFrame.Visible and UDim2.new(0.5, -210, 0.5, -260) or UDim2.new(-0.5, -210, 0.5, -260)
end
UserInputService.InputBegan:Connect(function(i, gp)
	if gp then return end
	if keybinds.Menu and isBindPressed(keybinds.Menu, i) then toggleMenu()
	elseif keybinds.ESP and isBindPressed(keybinds.ESP, i) then et(not espActive)
	elseif keybinds.Fly and isBindPressed(keybinds.Fly, i) then
		flyToggle(not flyActive)
		if flyActive then cst(false) end
	elseif keybinds.CFrameSpeed and isBindPressed(keybinds.CFrameSpeed, i) then
		cst(not cframeSpeedActive)
		if cframeSpeedActive then flyToggle(false) end
	elseif keybinds.FreeCam and isBindPressed(keybinds.FreeCam, i) then fct(not freeCamActive)
	elseif keybinds.Aimlock and isBindPressed(keybinds.Aimlock, i) and aimlockActive then
		if aimlockToggleMode then aimlockLocked = not aimlockLocked else lockedTarget = getTargetInFOV() end
	elseif freeCamActive and i.UserInputType == Enum.UserInputType.MouseButton2 then
		r = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
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
							if d <= aimlockFOV and d < md then
								nextTarget = part
								md = d
							end
						end
					end
				end
			end
			if nextTarget then
				lockedTarget = nextTarget
				local tp = predictionActive and predictTargetPosition(nextTarget, 0.1) or nextTarget.Position
			end
		end
	end
end)
UserInputService.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton2 then r = false UserInputService.MouseBehavior = Enum.MouseBehavior.Default end
	if i.KeyCode == Enum.KeyCode.LeftShift or i.KeyCode == Enum.KeyCode.RightShift then freeCamBoost = 1 end
	if keybinds.Aimlock and not aimlockToggleMode then lockedTarget = nil end
end)
UserInputService.InputChanged:Connect(function(i)
	if r and i.UserInputType == Enum.UserInputType.MouseMovement and not lockedTarget then
		freeCamYaw = freeCamYaw - i.Delta.X * freeCamSensitivity
		freeCamPitch = math.clamp(freeCamPitch - i.Delta.Y * freeCamSensitivity, -math.pi / 2, math.pi / 2)
	end
end)

local m = player:GetMouse()
m.Button1Down:Connect(function()
	if clickTeleportActive and keybinds.ClickTeleport and isBindDown(keybinds.ClickTeleport) and rootPart then
		local targetPos = m.Hit.Position + Vector3.new(0, 3, 0)
		local cameraLook = camera.CFrame.LookVector
		local yaw = math.atan2(-cameraLook.X, -cameraLook.Z)
		rootPart.CFrame = CFrame.new(targetPos) * CFrame.Angles(0, yaw, 0)
	end
end)

print("Settings geladen. Drücke " .. (keybinds.Menu and (keybinds.Menu:IsA("KeyCode") and keybinds.Menu.Name or (keybinds.Menu == Enum.UserInputType.MouseButton1 and "Left Click" or keybinds.Menu == Enum.UserInputType.MouseButton2 and "Right Click" or "Middle Click")) or "G") .. " zum Umschalten.")
