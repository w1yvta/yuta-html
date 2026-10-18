-- ==================================================
-- [SECURITY] GAME GUARD - EXCLUSIVE FOR EVADE
-- ==================================================
local StarterGui = game:GetService("StarterGui")
local isEvade = false

-- 1. Cek berdasarkan Nama Game (Fallback)
if string.find(string.lower(game.Name), "evade") then
    isEvade = true
end

-- 2. Cek berdasarkan PlaceId (ID Map Evade)
-- Jika Evade update dan ganti map, tambahkan ID barunya di bawah ini
local ALLOWED_PLACE_IDS = {
    13431554650, -- Evade (Main Lobby / Game)
}

for _, id in ipairs(ALLOWED_PLACE_IDS) do
    if game.PlaceId == id then
        isEvade = true
        break
    end
end

-- 3. Jika bukan Evade, matikan script secara total
if not isEvade then
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Security System",
            Text = "Script ini hanya berfungsi di Evade!",
            Duration = 5
        })
    end)
    return -- HENTIKAN SCRIPT (UI tidak akan muncul)
end
-- ==================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local lp = Players.LocalPlayer

local env = (getgenv and getgenv()) or _G
if env.__EvadeFarm then
	pcall(env.__EvadeFarm.Stop)
end

local CONFIG = {
	SafeHeight = 750,
	PlatformSize = Vector3.new(30, 2, 30),
	Names = {"wisp"}, 
	CollectDelay = 0.70,
	Interval = 0.3,
	StableTime = 5.0, 
}

local State = { Afk = true, Collect = true }
local running = true
local connections = {}
local named = {}                       
local autoSet, autoStats, autoBlack, autoSeen = {}, {}, {}, {}
local lastAuto
local platform, safeCFrame, originCFrame
local needSetup = true
local guiRoot, mainFrame, bubbleFrame
local leaveAfk, afkBtn, afkPaused = false

-- ===================== MODERN UI =====================
local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

local function getGuiParent()
	local ok, p = pcall(function()
		if gethui then return gethui() end
	end)
	if ok and p then return p end
	local ok2, core = pcall(function() return game:GetService("CoreGui") end)
	if ok2 and core then
		local t = Instance.new("ScreenGui")
		local good = pcall(function() t.Parent = core end)
		t:Destroy()
		if good then return core end
	end
	return lp:WaitForChild("PlayerGui")
end

local logLabel, logScroll
local logLines = {}
local function log(...)
	local parts = {}
	for _, v in ipairs({...}) do parts[#parts + 1] = tostring(v) end
	local line = table.concat(parts, " ")
	print("[EvadeFarm]", line)
	table.insert(logLines, line)
	if #logLines > 30 then table.remove(logLines, 1) end
	if logLabel then
		logLabel.Text = table.concat(logLines, "\n")
		if logScroll then logScroll.CanvasPosition = Vector2.new(0, 1e6) end
	end
end

local function buildUI()
	guiRoot = make("ScreenGui", {
		Name = "SystemCore", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, getGuiParent())

	-- MAIN FRAME (Dark Theme)
	mainFrame = make("Frame", {
		Size = UDim2.new(0, 260, 0, 300), Position = UDim2.new(0, 20, 0.3, 0),
		BackgroundColor3 = Color3.fromRGB(20, 20, 25), BorderSizePixel = 0,
	}, guiRoot)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, mainFrame)
	make("UIStroke", { Color = Color3.fromRGB(60, 60, 70), Thickness = 1.5 }, mainFrame)

	-- HEADER
	local header = make("Frame", {
		Size = UDim2.new(1, 0, 0, 35), BackgroundColor3 = Color3.fromRGB(30, 30, 38),
		BorderSizePixel = 0,
	}, mainFrame)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, header)
	-- Tutup sudut bawah header yang ikut rounded
	make("Frame", { Size = UDim2.new(1, 0, 0.5, 0), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Color3.fromRGB(30, 30, 38), BorderSizePixel = 0 }, header)

	local title = make("TextLabel", {
		Size = UDim2.new(1, -60, 1, 0), BackgroundTransparency = 1, Text = "CORE SYSTEM",
		Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.fromRGB(200, 200, 200),
		TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 12, 0, 0)
	}, header)

	-- MINIMIZE BUTTON
	local minBtn = make("TextButton", {
		Size = UDim2.new(0, 30, 0, 35), Position = UDim2.new(1, -35, 0, 0),
		BackgroundTransparency = 1, Text = "-", Font = Enum.Font.GothamBold,
		TextSize = 18, TextColor3 = Color3.fromRGB(150, 150, 150),
	}, header)
	minBtn.MouseButton1Click:Connect(function()
		mainFrame.Visible = false
		bubbleFrame.Visible = true
	end)

	-- DRAG LOGIC
	local dragging, dragStart, startPos
	table.insert(connections, header.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPos = true, i.Position, mainFrame.Position
		end
	end))
	table.insert(connections, UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart
			mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))
	table.insert(connections, UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))

	-- TOGGLE BUTTONS
	local function createToggle(text, y, key, onChange)
		local btn = make("TextButton", {
			Size = UDim2.new(1, -20, 0, 34), Position = UDim2.new(0, 10, 0, y),
			BorderSizePixel = 0, Font = Enum.Font.GothamSemibold, TextSize = 12,
			TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false,
		}, mainFrame)
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, btn)
		local stroke = make("UIStroke", { Color = Color3.fromRGB(100, 100, 100), Thickness = 1 }, btn)
		
		local function refresh()
			btn.Text = text .. ": " .. (State[key] and "ON" or "OFF")
			btn.BackgroundColor3 = State[key] and Color3.fromRGB(45, 45, 55) or Color3.fromRGB(30, 30, 35)
			btn.TextColor3 = State[key] and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(120, 120, 120)
			stroke.Color = State[key] and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(60, 60, 70)
		end
		refresh()
		btn.MouseButton1Click:Connect(function()
			State[key] = not State[key]
			refresh()
			if onChange then pcall(onChange, State[key]) end
		end)
		return btn
	end

	afkBtn = createToggle("Auto AFK", 45, "Afk", function(on)
		needSetup = true
		if not on and leaveAfk then leaveAfk() end
	end)
	createToggle("Auto Collect Item", 85, "Collect")

	-- LOG BOX
	logScroll = make("ScrollingFrame", {
		Size = UDim2.new(1, -20, 0, 90), Position = UDim2.new(0, 10, 0, 125),
		BackgroundColor3 = Color3.fromRGB(15, 15, 18), BorderSizePixel = 0,
		ScrollBarThickness = 3, CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, mainFrame)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, logScroll)
	make("UIStroke", { Color = Color3.fromRGB(50, 50, 60), Thickness = 1 }, logScroll)
	
	logLabel = make("TextLabel", {
		Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, Text = "", Font = Enum.Font.Code, TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true, TextColor3 = Color3.fromRGB(180, 180, 180), Position = UDim2.new(0, 4, 0, 4)
	}, logScroll)

	-- SCAN BUTTON
	local nearBtn = make("TextButton", {
		Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0, 10, 0, 225),
		BackgroundColor3 = Color3.fromRGB(40, 80, 150), BorderSizePixel = 0,
		Text = "Scan Area", Font = Enum.Font.GothamSemibold, TextSize = 12,
		TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false
	}, mainFrame)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, nearBtn)
	nearBtn.MouseButton1Click:Connect(function() pcall(env.__EvadeFarm_near) end)

	-- CLOSE BUTTON
	local closeBtn = make("TextButton", {
		Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0, 10, 0, 260),
		BackgroundColor3 = Color3.fromRGB(150, 40, 40), BorderSizePixel = 0,
		Text = "Terminate Script", Font = Enum.Font.GothamSemibold, TextSize = 12,
		TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false
	}, mainFrame)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, closeBtn)
	closeBtn.MouseButton1Click:Connect(function() env.__EvadeFarm.Stop() end)

	-- BUBBLE (MINIMIZED STATE)
	bubbleFrame = make("TextButton", {
		Size = UDim2.new(0, 50, 0, 50), Position = UDim2.new(0, 20, 0.3, 0),
		BackgroundColor3 = Color3.fromRGB(30, 30, 38), BorderSizePixel = 0,
		Text = "SYS", Font = Enum.Font.GothamBold, TextSize = 12,
		TextColor3 = Color3.fromRGB(0, 255, 150), Visible = false, AutoButtonColor = false
	}, guiRoot)
	make("UICorner", { CornerRadius = UDim.new(0, 25) }, bubbleFrame)
	make("UIStroke", { Color = Color3.fromRGB(0, 255, 150), Thickness = 1.5 }, bubbleFrame)
	
	bubbleFrame.MouseButton1Click:Connect(function()
		bubbleFrame.Visible = false
		mainFrame.Visible = true
	end)
end

-- ===================== HOTKEY LOGIC (Right Ctrl) =====================
table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.RightControl then
		if mainFrame.Visible then
			mainFrame.Visible = false
			bubbleFrame.Visible = false
		else
			mainFrame.Visible = true
			bubbleFrame.Visible = false
		end
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
	if inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	end
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
		if d:IsA("BasePart") and not d:IsA("Terrain") and d.Size.Magnitude <= 8
			and not isExcluded(d) and not inAnyCharacter(d) then
			local dist = (d.Position - root.Position).Magnitude
			if dist <= RADIUS then
				local tags = {}
				if d:FindFirstChildWhichIsA("ParticleEmitter", true) then tags[#tags + 1] = "particle" end
				if d:FindFirstChildWhichIsA("PointLight", true) then tags[#tags + 1] = "light" end
				if d:FindFirstChildWhichIsA("TouchTransmitter") then tags[#tags + 1] = "touch" end
				if d:FindFirstChildWhichIsA("ProximityPrompt", true) then tags[#tags + 1] = "prompt" end
				if d:FindFirstChildWhichIsA("BillboardGui", true) then tags[#tags + 1] = "gui" end
				if #tags > 0 then
					list[#list + 1] = { part = d, dist = dist, tags = table.concat(tags, ",") }
				end
			end
		end
	end
	table.sort(list, function(a, b) return a.dist < b.dist end)
	log("scan sekitar (30 stud):", #list, "objek")
	for i = 1, math.min(6, #list) do
		local e = list[i]
		log(string.format("%.0fst [%s]", e.dist, e.tags), e.part:GetFullName())
	end
	if #list == 0 then
		log("tidak ada objek berpartikel/cahaya/sentuh.")
	end
end

local function nameMatches(s)
	local lower = string.lower(s)
	for _, k in ipairs(CONFIG.Names) do
		if string.find(lower, k, 1, true) then return true end
	end
	return false
end

local function considerNamed(inst)
	if not (inst:IsA("BasePart") or inst:IsA("Model")) then return end
	if isExcluded(inst) or inAnyCharacter(inst) then return end
	if not nameMatches(inst.Name) then return end
	if inst:IsA("Model") and Players:GetPlayerFromCharacter(inst) then return end
	local p = inst.Parent
	while p and p ~= workspace do
		if named[p] then return end
		p = p.Parent
	end
	named[inst] = true
	if not autoSeen[inst.Name] then
		autoSeen[inst.Name] = true
		log("terdeteksi (nama):", inst:GetFullName())
	end
end

local recentAdds, burstUntil = {}, 0
local function isHint(d)
	return d:IsA("TouchTransmitter") or d:IsA("ProximityPrompt")
		or d:IsA("ParticleEmitter") or d:IsA("PointLight")
end

local function noteAdd(d)
	if isHint(d) then
		local now = os.clock()
		recentAdds[#recentAdds + 1] = now
		while recentAdds[1] and now - recentAdds[1] > 2 do
			table.remove(recentAdds, 1)
		end
		if #recentAdds > 40 then burstUntil = now + 5 end
	end
end

local function considerAuto(d)
	if not running then return end
	if not isHint(d) then return end
	if os.clock() < burstUntil then return end
	local owner = d.Parent
	if not owner or not owner:IsA("BasePart") then return end
	if isExcluded(owner) or inAnyCharacter(owner) then return end
	if owner.CanCollide then return end          
	if owner.Size.Magnitude > 10 then return end
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
	task.delay(CONFIG.StableTime, function()
		if not running or not target.Parent or not part.Parent then return end
		if (part.Position - p0).Magnitude > 1 then return end
		if autoBlack[target.Name] or autoSet[target] then return end
		autoSet[target] = true
		if not autoSeen[target.Name] then
			autoSeen[target.Name] = true
			log("terdeteksi (auto):", target:GetFullName())
		end
	end)
end

local function buildPlatform(root)
	if platform then platform:Destroy() end
	originCFrame = root.CFrame
	local base = root.Position + Vector3.new(0, CONFIG.SafeHeight, 0)
	platform = make("Part", {
		Name = "SafePlatform", Anchored = true, CanCollide = true,
		Size = CONFIG.PlatformSize, Transparency = 0.5, Position = base,
	}, workspace)
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
	if inst:IsA("BasePart") then
		parts[1] = inst
	else
		for _, d in ipairs(inst:GetDescendants()) do
			if d:IsA("BasePart") then
				parts[#parts + 1] = d
				if #parts >= 5 then break end
			end
		end
	end
	for _, p in ipairs(parts) do
		if firetouchinterest then
			pcall(function()
				firetouchinterest(root, p, 0)
				task.wait()
				firetouchinterest(root, p, 1)
			end)
		end
	end
	local prompt = inst:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt and fireproximityprompt then
		pcall(fireproximityprompt, prompt)
	end
end

local function collectSet(set, verify)
	local did = false
	local trips = 0
	for inst in pairs(set) do
		if not running or not State.Collect then break end
		trips += 1
		if verify and trips > 3 then break end 
		local r = getRoot()
		if not r then break end
		local part = resolvePart(inst)
		if part and part.Parent and not (verify and autoBlack[inst.Name]) then
			did = true
			if verify then lastAuto = { name = inst.Name, t = os.clock() } end
			pcall(function()
				tp(r, part.CFrame)
				touchAll(r, inst)
			end)
			task.wait(CONFIG.CollectDelay)
			if verify then
				local s = autoStats[inst.Name]
				if not s then s = { try = 0, ok = 0 }; autoStats[inst.Name] = s end
				s.try += 1
				local gone = (not inst.Parent) or (not part.Parent) or part.Transparency >= 1
				if gone then
					s.ok += 1
					set[inst] = nil
				elseif s.try >= 4 and s.ok == 0 then
					autoBlack[inst.Name] = true
					set[inst] = nil
					log("skip (tidak pernah hilang):", inst.Name)
				end
			end
		else
			set[inst] = nil
		end
	end
	return did
end

local function setAfkPaused(p)
	afkPaused = p
	if afkBtn then
		afkBtn.Text = p and "Auto AFK: PAUSE" or ("Auto AFK: " .. (State.Afk and "ON" or "OFF"))
	end
end

-- ===================== START & LOOP =====================
buildUI()

table.insert(connections, workspace.DescendantAdded:Connect(function(d)
	noteAdd(d)
	task.defer(considerNamed, d)
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
			local hasWork = next(named) ~= nil or next(autoSet) ~= nil
			if hasWork and State.Afk then setAfkPaused(true) end
			local did = collectSet(named, false)
			if not did then did = collectSet(autoSet, true) end
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
	Config = CONFIG,
	State = State,
	Stop = function()
		running = false
		for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
		if platform then pcall(function() platform:Destroy() end) end
		if guiRoot then pcall(function() guiRoot:Destroy() end) end
		table.clear(named)
		table.clear(autoSet)
		print("[EvadeFarm] stopped")
	end,
}

log("sistem siap. menunggu target.")
