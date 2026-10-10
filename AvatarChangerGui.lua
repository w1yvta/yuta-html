-- AvatarChangerGui
-- Taruh sebagai **LocalScript** di StarterPlayer > StarterPlayerScripts
-- GUI dibuat otomatis lewat kode, jadi tidak perlu bikin ScreenGui manual.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("AvatarChangerEvent")

local BG = Color3.fromRGB(28, 30, 38)
local PANEL = Color3.fromRGB(42, 45, 56)
local ACCENT = Color3.fromRGB(80, 140, 255)
local TEXT = Color3.fromRGB(240, 240, 245)
local GOOD = Color3.fromRGB(90, 200, 120)
local BAD = Color3.fromRGB(235, 90, 90)

local function make(class, props, parent)
	local obj = Instance.new(class)
	for k, v in pairs(props) do
		obj[k] = v
	end
	obj.Parent = parent
	return obj
end

local function round(obj, radius)
	make("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, obj)
end

local function button(text, pos, size, parent, color)
	local b = make("TextButton", {
		Text = text,
		Position = pos,
		Size = size,
		BackgroundColor3 = color or ACCENT,
		TextColor3 = TEXT,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		AutoButtonColor = true,
	}, parent)
	round(b)
	return b
end

-- ===== GUI =====
local gui = make("ScreenGui", {
	Name = "YutaHubGui",
	ResetOnSpawn = false,
}, player:WaitForChild("PlayerGui"))

local toggle = button("Avatar", UDim2.new(0, 10, 0.5, -18), UDim2.new(0, 90, 0, 36), gui)

local main = make("Frame", {
	Size = UDim2.new(0, 300, 0, 420),
	Position = UDim2.new(0.5, -150, 0.5, -210),
	BackgroundColor3 = BG,
	Visible = false,
}, gui)
round(main, 12)

make("TextLabel", {
	Text = "Yuta Hub",
	Size = UDim2.new(1, -50, 0, 36),
	Position = UDim2.new(0, 12, 0, 4),
	BackgroundTransparency = 1,
	TextColor3 = TEXT,
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left,
}, main)

local close = button("X", UDim2.new(1, -40, 0, 6), UDim2.new(0, 30, 0, 28), main, BAD)

-- Rig R15 / R6
local btnR15 = button("R15", UDim2.new(0, 12, 0, 46), UDim2.new(0.5, -16, 0, 34), main, PANEL)
local btnR6 = button("R6", UDim2.new(0.5, 4, 0, 46), UDim2.new(0.5, -16, 0, 34), main, PANEL)

local function highlightRig(rigName)
	btnR15.BackgroundColor3 = (rigName == "R15") and ACCENT or PANEL
	btnR6.BackgroundColor3 = (rigName == "R6") and ACCENT or PANEL
end

-- Input
local input = make("TextBox", {
	Text = "",
	PlaceholderText = "Username / UserId / Outfit ID",
	Size = UDim2.new(1, -24, 0, 34),
	Position = UDim2.new(0, 12, 0, 88),
	BackgroundColor3 = PANEL,
	TextColor3 = TEXT,
	PlaceholderColor3 = Color3.fromRGB(150, 150, 160),
	Font = Enum.Font.Gotham,
	TextSize = 14,
	ClearTextOnFocus = false,
}, main)
round(input)

local btnUser = button("Pakai User", UDim2.new(0, 12, 0, 130), UDim2.new(0.5, -16, 0, 34), main)
local btnOutfit = button("Pakai Outfit ID", UDim2.new(0.5, 4, 0, 130), UDim2.new(0.5, -16, 0, 34), main)
local btnReset = button("Reset ke Avatar Asli", UDim2.new(0, 12, 0, 172), UDim2.new(1, -24, 0, 34), main, PANEL)

local status = make("TextLabel", {
	Text = "",
	Size = UDim2.new(1, -24, 0, 22),
	Position = UDim2.new(0, 12, 0, 212),
	BackgroundTransparency = 1,
	TextColor3 = TEXT,
	Font = Enum.Font.Gotham,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
}, main)

make("TextLabel", {
	Text = "Copy dari pemain di server:",
	Size = UDim2.new(1, -24, 0, 20),
	Position = UDim2.new(0, 12, 0, 238),
	BackgroundTransparency = 1,
	TextColor3 = Color3.fromRGB(180, 180, 190),
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
}, main)

local list = make("ScrollingFrame", {
	Size = UDim2.new(1, -24, 0, 150),
	Position = UDim2.new(0, 12, 0, 262),
	BackgroundColor3 = PANEL,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, main)
round(list)
make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.Name }, list)
make("UIPadding", {
	PaddingTop = UDim.new(0, 4),
	PaddingBottom = UDim.new(0, 4),
	PaddingLeft = UDim.new(0, 4),
	PaddingRight = UDim.new(0, 4),
}, list)

-- ===== Logika =====
local function setStatus(msg, ok)
	status.Text = msg
	status.TextColor3 = ok and GOOD or BAD
end

local function refreshList(ignore)
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p ~= ignore then
			local b = make("TextButton", {
				Name = p.Name,
				Text = p.DisplayName .. " (@" .. p.Name .. ")",
				Size = UDim2.new(1, -4, 0, 30),
				BackgroundColor3 = BG,
				TextColor3 = TEXT,
				Font = Enum.Font.Gotham,
				TextSize = 13,
			}, list)
			round(b, 6)
			b.MouseButton1Click:Connect(function()
				setStatus("Memproses...", true)
				remote:FireServer("CopyPlayer", p.UserId)
			end)
		end
	end
end

toggle.MouseButton1Click:Connect(function()
	main.Visible = not main.Visible
	if main.Visible then
		refreshList()
	end
end)
close.MouseButton1Click:Connect(function()
	main.Visible = false
end)

btnR15.MouseButton1Click:Connect(function()
	setStatus("Memproses...", true)
	remote:FireServer("SetRig", "R15")
end)
btnR6.MouseButton1Click:Connect(function()
	setStatus("Memproses...", true)
	remote:FireServer("SetRig", "R6")
end)

btnUser.MouseButton1Click:Connect(function()
	local text = input.Text:gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then
		setStatus("Isi username / UserId dulu", false)
		return
	end
	setStatus("Memproses...", true)
	remote:FireServer("ByName", text)
end)

btnOutfit.MouseButton1Click:Connect(function()
	local id = tonumber(input.Text)
	if not id then
		setStatus("Outfit ID harus angka", false)
		return
	end
	setStatus("Memproses...", true)
	remote:FireServer("Outfit", id)
end)

btnReset.MouseButton1Click:Connect(function()
	setStatus("Memproses...", true)
	remote:FireServer("Reset")
end)

remote.OnClientEvent:Connect(function(kind, msg, ok)
	if kind == "Status" then
		setStatus(msg, ok)
	end
end)

Players.PlayerAdded:Connect(function()
	refreshList()
end)
Players.PlayerRemoving:Connect(function(leaving)
	refreshList(leaving)
end)

-- Highlight rig sesuai karakter saat ini
local function watchCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		highlightRig(humanoid.RigType.Name)
	end
end
player.CharacterAdded:Connect(watchCharacter)
if player.Character then
	task.spawn(watchCharacter, player.Character)
end
