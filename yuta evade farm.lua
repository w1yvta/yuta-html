-- ==================================================
-- [SECURITY] LUNARYUTA AUTO DETECT
-- ==================================================
local isEvade = false
local mapName = game.Name

if string.find(string.lower(game.Name), "evade") then isEvade = true end
local effectsFolder = workspace:FindFirstChild("Effects")
if effectsFolder and effectsFolder:FindFirstChild("Tickets") then
    isEvade = true
    mapName = "Evade (Detected)"
end

if not isEvade then
    local pGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    local warn = Instance.new("ScreenGui", pGui)
    local bg = Instance.new("Frame", warn)
    bg.Size = UDim2.new(0, 300, 0, 80)
    bg.Position = UDim2.new(0.5, -150, 0.5, -40)
    bg.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
    bg.BorderSizePixel = 0
    local c = Instance.new("UICorner", bg)
    c.CornerRadius = UDim.new(0, 8)
    local txt = Instance.new("TextLabel", bg)
    txt.Size = UDim2.new(1, -20, 1, 0)
    txt.Position = UDim2.new(0, 10, 0, 0)
    txt.BackgroundTransparency = 1
    txt.Text = "SCRIPT INI HANYA SUPPORT EVADE!"
    txt.TextColor3 = Color3.new(1, 1, 1)
    txt.Font = Enum.Font.GothamBold
    txt.TextSize = 16
    task.delay(4, function() warn:Destroy() end)
    return 
end
-- ==================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local lp = Players.LocalPlayer

local env = (getgenv and getgenv()) or _G
if env.__EvadeFarm then pcall(env.__EvadeFarm.Stop) end

local CONFIG = {
	SafeHeight = 750,
	PlatformSize = Vector3.new(30, 2, 30),
	Names = {"wisp", "ticket", "visual"}, 
	CollectDelay = 0.70,
	Interval = 0.3,
	StableTime = 5.0, 
}

local State = { Afk = true, Collect = true }
local running = true
local connections = {}
local named = {}                       
local autoSet, autoStats, autoBlack = {}, {}, {}
local lastAuto
local platform, safeCFrame, originCFrame
local needSetup = true
local guiRoot, mainFrame, bubbleFrame
local leaveAfk, afkBtn, afkPaused = false

-- FITUR ANTI TP-LOOP
local recentPositions = {}

-- ===================== RAYFIELD UI =====================
local Theme = {
    Bg = Color3.fromRGB(15, 15, 20), Panel = Color3.fromRGB(25, 25, 32),
    Accent = Color3.fromRGB(160, 100, 255), Text = Color3.fromRGB(240, 240, 240),
    Muted = Color3.fromRGB(140, 140, 150), DarkMuted = Color3.fromRGB(40, 40, 50)
}

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

local logLabel, logScroll, logLines = nil, nil, {}
local function log(...)
	local parts = {}
	for _, v in ipairs({...}) do parts[#parts + 1] = tostring(v) end
	local line = table.concat(parts, " ")
	print("[LunarYuta]", line)
	table.insert(logLines, line)
	if #logLines > 30 then table.remove(logLines, 1) end
	if logLabel then
		logLabel.Text = table.concat(logLines, "\n")
		if logScroll then logScroll.CanvasPosition = Vector2.new(0, 1e6) end
	end
end

local function buildUI()
	guiRoot = make("ScreenGui", {
		Name = "LunarYutaSystem", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 999, IgnoreGuiInset = true,
	}, lp:WaitForChild("PlayerGui"))

    -- ===================== LOADING SCREEN WITH SOUND =====================
    local loadScreen = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0,0,0), ZIndex = 1000}, guiRoot)
    
    -- Memunculkan Suara Loading (Cinematic Boom)
    local loadSound = Instance.new("Sound")
    loadSound.SoundId = "rbxassetid://1837862987" -- ID Suara Cinematic Boom
    loadSound.Volume = 3
    loadSound.Parent = loadScreen
    loadSound:Play()

    local loadTitle = make("TextLabel", {Size = UDim2.new(1,0,0,50), Position = UDim2.new(0,0,0.45,0), BackgroundTransparency = 1, Text = "LUNAR YUTA", Font = Enum.Font.GothamBlack, TextSize = 36, TextColor3 = Theme.Accent, ZIndex = 1001}, loadScreen)
    local loadMap = make("TextLabel", {Size = UDim2.new(1,0,0,30), Position = UDim2.new(0,0,0.45,55), BackgroundTransparency = 1, Text = "Map : " .. tostring(mapName), Font = Enum.Font.GothamMedium, TextSize = 16, TextColor3 = Color3.new(1,1,1), ZIndex = 1001}, loadScreen)

    task.spawn(function()
        task.wait(2.5) -- Waktu loading screen
        local tInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local t1 = TweenService:Create(loadScreen, tInfo, {BackgroundTransparency = 1})
        local t2 = TweenService:Create(loadTitle, tInfo, {TextTransparency = 1})
        local t3 = TweenService:Create(loadMap, tInfo, {TextTransparency = 1})
        
        -- Suara memudar perlahan bersamaan dengan layar
        local t4 = TweenService:Create(loadSound, TweenInfo.new(1), {Volume = 0})
        
        t1:Play() t2:Play() t3:Play() t4:Play()
        t1.Completed:Wait()
        loadScreen:Destroy()
    end)

    -- ===================== MAIN UI =====================
	mainFrame = make("Frame", {Size = UDim2.new(0, 280, 0, 340), Position = UDim2.new(0, 20, 0.3, 0), BackgroundColor3 = Theme.Bg, BorderSizePixel = 0, Active = true, Visible = false}, guiRoot)
    task.delay(2.5, function() if mainFrame then mainFrame.Visible = true end end)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, mainFrame)
	make("UIStroke", { Color = Theme.Accent, Thickness = 1.5, Transparency = 0.5 }, mainFrame)

	local header = make("Frame", {Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Active = true}, mainFrame)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, header)
	make("Frame", { Size = UDim2.new(1, 0, 0.5, 0), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0 }, header)
    make("UIStroke", { Color = Theme.Accent, Thickness = 1, Transparency = 0.7 }, header)

	make("TextLabel", {Size = UDim2.new(1, -40, 0, 25), BackgroundTransparency = 1, Text = "LunarYuta", Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 15, 0, 5)}, header)
    make("TextLabel", {Size = UDim2.new(1, -40, 0, 15), BackgroundTransparency = 1, Text = "made by Yuta", Font = Enum.Font.GothamMedium, TextSize = 10, TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 15, 0, 25)}, header)

	local minBtn = make("TextButton", {Size = UDim2.new(0, 35, 0, 35), Position = UDim2.new(1, -40, 0, 8), BackgroundTransparency = 1, Text = "-", Font = Enum.Font.GothamBold, TextSize = 20, TextColor3 = Theme.Muted}, header)
	minBtn.MouseButton1Click:Connect(function() mainFrame.Visible = false; bubbleFrame.Visible = true end)

	local dragging, dragStart, startPos
	table.insert(connections, header.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging, dragStart, startPos = true, i.Position, mainFrame.Position end
	end))
	table.insert(connections, UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart
			mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))
	table.insert(connections, UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end))

	local function createToggle(text, y, key, onChange)
		local btn = make("TextButton", {Size = UDim2.new(1, -20, 0, 38), Position = UDim2.new(0, 10, 0, y), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Font = Enum.Font.GothamSemibold, TextSize = 12, TextColor3 = Theme.Text, AutoButtonColor = false, TextXAlignment = Enum.TextXAlignment.Left}, mainFrame)
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, btn)
        local indicator = make("Frame", {Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Visible = false}, btn)
        make("UICorner", { CornerRadius = UDim.new(0, 6) }, indicator)
        make("Frame", {Size = UDim2.new(1,0,1,0), Position = UDim2.new(0,4,0,0), BackgroundColor3 = Theme.Panel}, indicator)
        local txtLabel = make("TextLabel", {Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 15, 0, 0), BackgroundTransparency = 1, Text = text .. ": OFF", TextColor3 = Theme.Muted, Font = Enum.Font.GothamSemibold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left}, btn)

		local function refresh()
            if State[key] then
                btn.BackgroundColor3 = Theme.DarkMuted; indicator.Visible = true; txtLabel.Text = text .. ": ON"; txtLabel.TextColor3 = Theme.Text
            else
                btn.BackgroundColor3 = Theme.Panel; indicator.Visible = false; txtLabel.Text = text .. ": OFF"; txtLabel.TextColor3 = Theme.Muted
            end
		end
		refresh()
		btn.MouseButton1Click:Connect(function() State[key] = not State[key]; refresh(); if onChange then pcall(onChange, State[key]) end end)
		return btn
	end

	afkBtn = createToggle("Auto AFK", 60, "Afk", function(on) needSetup = true; if not on and leaveAfk then leaveAfk() end end)
	createToggle("Auto Collect Item", 105, "Collect")

	logScroll = make("ScrollingFrame", {Size = UDim2.new(1, -20, 0, 95), Position = UDim2.new(0, 10, 0, 150), BackgroundColor3 = Color3.fromRGB(10, 10, 12), BorderSizePixel = 0, ScrollBarThickness = 2, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y}, mainFrame)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, logScroll)
	make("UIStroke", { Color = Theme.DarkMuted, Thickness = 1 }, logScroll)
	logLabel = make("TextLabel", {Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Text = "", Font = Enum.Font.Code, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, TextColor3 = Theme.Accent, Position = UDim2.new(0, 5, 0, 5)}, logScroll)

	local nearBtn = make("TextButton", {Size = UDim2.new(1, -20, 0, 32), Position = UDim2.new(0, 10, 0, 255), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Text = "Scan Area", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Accent, AutoButtonColor = false}, mainFrame)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, nearBtn)
    make("UIStroke", { Color = Theme.Accent, Thickness = 1, Transparency = 0.5 }, nearBtn)
	nearBtn.MouseButton1Click:Connect(function() pcall(env.__EvadeFarm_near) end)

	local closeBtn = make("TextButton", {Size = UDim2.new(1, -20, 0, 32), Position = UDim2.new(0, 10, 0, 295), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Text = "Terminate Script", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.fromRGB(255, 80, 80), AutoButtonColor = false}, mainFrame)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, closeBtn)
    make("UIStroke", { Color = Color3.fromRGB(255, 80, 80), Thickness = 1, Transparency = 0.5 }, closeBtn)
	closeBtn.MouseButton1Click:Connect(function() env.__EvadeFarm.Stop() end)

	bubbleFrame = make("TextButton", {Size = UDim2.new(0, 50, 0, 50), Position = UDim2.new(0, 20, 0.3, 0), BackgroundColor3 = Theme.Bg, BorderSizePixel = 0, Text = "LY", Font = Enum.Font.GothamBlack, TextSize = 14, TextColor3 = Theme.Accent, Visible = false, AutoButtonColor = false}, guiRoot)
	make("UICorner", { CornerRadius = UDim.new(0, 25) }, bubbleFrame)
	make("UIStroke", { Color = Theme.Accent, Thickness = 2 }, bubbleFrame)
	bubbleFrame.MouseButton1Click:Connect(function() bubbleFrame.Visible = false; mainFrame.Visible = true end)
end

table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.RightControl then
		if mainFrame.Visible then mainFrame.Visible = false; bubbleFrame.Visible = false
		else mainFrame.Visible = true; bubbleFrame.Visible = false end
	end
end))

-- ===================== CORE LOGIC =====================
local function getRoot()
	local char = lp.Character
	if not char then return nil end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if root and hum and hum.Health > 0 then return root end
	return nil
end

local function resolvePart(inst)
	if inst:IsA("BasePart") then return inst end
	if inst:IsA("Model") then return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true) end
	return nil
end

local function isExcluded(inst)
	if lp.Character and inst:IsDescendantOf(lp.Character) then return true end
	if platform and (inst == platform or inst:IsDescendantOf(platform)) then return true end
	if guiRoot and inst:IsDescendantOf(guiRoot) then return true end
	return false
end

local function inAnyCharacter(inst)
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character and inst:IsDescendantOf(p.Character) then return true end
	end
	return false
end

local function tp(root, cf)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = cf
end

env.__EvadeFarm_near = function()
	local root = getRoot()
	if not root then log("karakter belum siap"); return end
	local RADIUS = 30
	local list = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") and not d:IsA("Terrain") and d.Size.Magnitude <= 8 and not isExcluded(d) and not inAnyCharacter(d) then
			local dist = (d.Position - root.Position).Magnitude
			if dist <= RADIUS then
				local tags = {}
				if d:FindFirstChildWhichIsA("ParticleEmitter", true) then tags[#tags + 1] = "particle" end
				if d:FindFirstChildWhichIsA("PointLight", true) then tags[#tags + 1] = "light" end
				if d:FindFirstChildWhichIsA("TouchTransmitter") then tags[#tags + 1] = "touch" end
				if d:FindFirstChildWhichIsA("ProximityPrompt", true) then tags[#tags + 1] = "prompt" end
				if #tags > 0 then list[#list + 1] = { part = d, dist = dist, tags = table.concat(tags, ",") } end
			end
		end
	end
	table.sort(list, function(a, b) return a.dist < b.dist end)
	log("scan sekitar (30 stud):", #list, "objek")
	for i = 1, math.min(6, #list) do
		local e = list[i]
		log(string.format("%.0fst [%s]", e.dist, e.tags), e.part:GetFullName())
	end
end

local function isHint(d)
	return d:IsA("TouchTransmitter") or d:IsA("ProximityPrompt") or d:IsA("ParticleEmitter") or d:IsA("PointLight")
end

local recentAdds, burstUntil = {}, 0
local function noteAdd(d)
	if isHint(d) then
		local now = os.clock()
		recentAdds[#recentAdds + 1] = now
		while recentAdds[1] and now - recentAdds[1] > 2 do table.remove(recentAdds, 1) end
		if #recentAdds > 40 then burstUntil = now + 5 end
	end
end

local function considerAuto(d)
	if not running or not isHint(d) or os.clock() < burstUntil then return end
	local owner = d.Parent
	if not owner or not owner:IsA("BasePart") or isExcluded(owner) or inAnyCharacter(owner) then return end
	if owner.CanCollide or owner.Size.Magnitude > 10 then return end
	
	local target = owner
	local m = owner:FindFirstAncestorOfClass("Model")
	if m and m ~= workspace then
		if m:FindFirstChildWhichIsA("Humanoid", true) then return end
		local ok, size = pcall(function() return m:GetExtentsSize() end)
		if ok and size.Magnitude < 12 then target = m end
	end
	if autoBlack[target.Name] or autoSet[target] then return end
	
	local part = resolvePart(target)
	if not part then return end
	local p0 = part.Position
	
	if recentPositions[p0] and tick() - recentPositions[p0] < 10 then return end

	task.delay(CONFIG.StableTime, function()
		if not running or not target.Parent or not part.Parent then return end
		if (part.Position - p0).Magnitude > 1 then return end
		if autoBlack[target.Name] or autoSet[target] then return end
		
		if recentPositions[p0] and tick() - recentPositions[p0] < 10 then return end
		
		autoSet[target] = true
		log("terdeteksi:", target.Name)
	end)
end

local function buildPlatform(root)
	if platform then platform:Destroy() end
	originCFrame = root.CFrame
	local base = root.Position + Vector3.new(0, CONFIG.SafeHeight, 0)
	platform = make("Part", {Name = "SafePlatform", Anchored = true, CanCollide = true, Size = CONFIG.PlatformSize, Transparency = 0.5, Position = base}, workspace)
	safeCFrame = CFrame.new(base + Vector3.new(0, CONFIG.PlatformSize.Y / 2 + 3, 0))
end

leaveAfk = function()
	local root = getRoot()
	if root and originCFrame then pcall(tp, root, originCFrame) end
	if platform then platform:Destroy(); platform = nil end
	safeCFrame = nil
end

local function touchAll(root, inst)
	local parts = {}
	if inst:IsA("BasePart") then parts[1] = inst
	else
		for _, d in ipairs(inst:GetDescendants()) do
			if d:IsA("BasePart") then parts[#parts + 1] = d; if #parts >= 5 then break end end
		end
	end
	for _, p in ipairs(parts) do
		if firetouchinterest then pcall(function() firetouchinterest(root, p, 0); task.wait(); firetouchinterest(root, p, 1) end) end
	end
	local prompt = inst:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt and fireproximityprompt then pcall(fireproximityprompt, prompt) end
end

local function collectSet(set)
	local did = false
	local safeKeys = {}
	for k in pairs(set) do table.insert(safeKeys, k) end

	for _, inst in ipairs(safeKeys) do
		if not running or not State.Collect then break end
		if set[inst] then
			local r = getRoot()
			if r then
				local part = resolvePart(inst)
				if part and part.Parent and part.Transparency < 1 then
					did = true
					set[inst] = nil 
					recentPositions[part.Position] = tick() 
					
					pcall(function() tp(r, part.CFrame); touchAll(r, inst) end)
					task.wait(CONFIG.CollectDelay)
					log("Mengambil:", inst.Name)
				else
					set[inst] = nil 
				end
			end
		end
	end
	return did
end

local function setAfkPaused(p)
	afkPaused = p
	if afkBtn then
        local txtLabel = afkBtn:FindFirstChildWhichIsA("TextLabel")
        local indicator = afkBtn:FindFirstChildWhichIsA("Frame")
        if p then
            txtLabel.Text = "Auto AFK: PAUSE"; txtLabel.TextColor3 = Theme.Accent
            if indicator then indicator.Visible = true end
            afkBtn.BackgroundColor3 = Theme.DarkMuted
        else
            txtLabel.Text = "Auto AFK: " .. (State.Afk and "ON" or "OFF")
            txtLabel.TextColor3 = State.Afk and Theme.Text or Theme.Muted
            if indicator then indicator.Visible = State.Afk end
            afkBtn.BackgroundColor3 = State.Afk and Theme.DarkMuted or Theme.Panel
        end
	end
end

-- ===================== START & LOOP =====================
buildUI()

table.insert(connections, workspace.DescendantAdded:Connect(function(d)
	noteAdd(d)
	task.delay(0.3, considerAuto, d)
end))
table.insert(connections, workspace.DescendantRemoving:Connect(function(d)
	named[d] = nil
	autoSet[d] = nil
end))
table.insert(connections, lp.CharacterAdded:Connect(function()
	needSetup = true
	if lastAuto and os.clock() - lastAuto.t < 6 then
		autoBlack[lastAuto.name] = true
		table.clear(autoSet)
		log("blacklist (mati setelah teleport):", lastAuto.name)
		lastAuto = nil
	end
end))

local function step()
	local root = getRoot()
	if root then
		if State.Afk then
			if needSetup then
				needSetup = false
				pcall(buildPlatform, root)
				task.wait(0.2)
				if safeCFrame then pcall(tp, root, safeCFrame) end
			end
		else
			needSetup = false
		end

		if State.Collect then
			local home = (State.Afk and safeCFrame) or root.CFrame
			
			local hasWork = false
			for _ in pairs(named) do hasWork = true; break end
			if not hasWork then
				for _ in pairs(autoSet) do hasWork = true; break end
			end

			if hasWork and State.Afk then setAfkPaused(true) end
			
			local did = collectSet(named)
			if not did then did = collectSet(autoSet) end
			
			local r2 = getRoot()
			if did and r2 then pcall(tp, r2, home) end
			setAfkPaused(false)
		end

		if State.Afk and safeCFrame and not afkPaused then
			local r3 = getRoot()
			if r3 and (r3.Position - safeCFrame.Position).Magnitude > 8 then
				pcall(tp, r3, safeCFrame)
			end
		end
	end
end

task.spawn(function()
	while running do
		local ok, err = pcall(step)
		if not ok then
			log("ERROR loop:", tostring(err))
			task.wait(2)
		end
		task.wait(CONFIG.Interval)
	end
end)

env.__EvadeFarm = {
	Config = CONFIG, State = State,
	Stop = function()
		running = false
		for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
		if platform then pcall(function() platform:Destroy() end) end
		if guiRoot then pcall(function() guiRoot:Destroy() end) end
		table.clear(named); table.clear(autoSet); table.clear(recentPositions)
		print("[LunarYuta] stopped")
	end,
}

log("Sistem LunarYuta siap. Menunggu target.")
