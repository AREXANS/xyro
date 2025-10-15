-- magnet.lua
--[[
    Skrip ini membuat GUI magnet yang dapat digeser dengan kontrol untuk 
    memulai/menghentikan efek magnet, dan menyesuaikan kekuatan serta jangkauannya.
    Gaya visualnya meniru 'Arexanstools.lua' untuk konsistensi.
]]

-- Layanan Roblox
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

-- Variabel Lokal
local LocalPlayer = Players.LocalPlayer
local isMagnetActive = false
local magnetPower = 50
local magnetRange = 50
local magnetDirection = "Ke Karakter" -- Opsi: "Ke Karakter", "Acak"
local magnetConnection = nil
local attractParts = {}
local isRemoveEnabled = false
local touchConnections = {}

-- ====================================================================
-- == FUNGSI UTILITAS GUI                                            ==
-- ====================================================================

-- Fungsi untuk membuat jendela dapat digeser
local function MakeDraggable(guiObject, dragHandle)
    local dragInput = nil
    local dragStart = nil
    local startPos = nil

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
            dragStart = input.Position
            startPos = guiObject.Position
        end
    end)

    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if dragInput then
                local delta = input.Position - dragStart
                guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end
    end)

    dragHandle.InputEnded:Connect(function(input)
        if input == dragInput then
            dragInput = nil
        end
    end)
end

-- Fungsi untuk membuat slider
-- Fungsi untuk membuat text box input
-- Fungsi untuk membuat text box input yang ringkas
local function createCompactTextBox(parent, name, defaultValue)
    local frame = Instance.new("Frame", parent)
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.new(0, 65, 1, 0) -- Lebar tetap, tinggi mengisi parent

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, 0, 0, 12)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.SourceSans
    label.Text = name
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 10
    label.TextXAlignment = Enum.TextXAlignment.Center

    local textBox = Instance.new("TextBox", frame)
    textBox.Size = UDim2.new(1, 0, 1, -14)
    textBox.Position = UDim2.new(0, 0, 0, 14)
    textBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    textBox.TextColor3 = Color3.fromRGB(220, 220, 220)
    textBox.Text = tostring(defaultValue)
    textBox.Font = Enum.Font.SourceSans
    textBox.TextSize = 12
    textBox.TextXAlignment = Enum.TextXAlignment.Center
    local corner = Instance.new("UICorner", textBox)
    corner.CornerRadius = UDim.new(0, 4)

    return textBox
end

local function createToggle(parent, name, initialState, callback)
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, 0, 0, 25)
    frame.BackgroundTransparency = 1

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, -45, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.SourceSans
    label.Text = name
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left

    local switch = Instance.new("TextButton", frame)
    switch.Size = UDim2.new(0, 40, 0, 20)
    switch.Position = UDim2.new(1, -40, 0.5, -10)
    switch.BackgroundColor3 = initialState and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(60, 60, 60)
    switch.Text = ""
    local switchCorner = Instance.new("UICorner", switch)
    switchCorner.CornerRadius = UDim.new(1, 0)

    local thumb = Instance.new("Frame", switch)
    thumb.Size = UDim2.new(0, 16, 0, 16)
    thumb.Position = initialState and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    thumb.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
    local thumbCorner = Instance.new("UICorner", thumb)
    thumbCorner.CornerRadius = UDim.new(1, 0)
    
    local isToggled = initialState
    switch.MouseButton1Click:Connect(function()
        isToggled = not isToggled
        local goalPosition = isToggled and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        local goalColor = isToggled and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(60, 60, 60)
        TweenService:Create(thumb, TweenInfo.new(0.2), {Position = goalPosition}):Play()
        TweenService:Create(switch, TweenInfo.new(0.2), {BackgroundColor3 = goalColor}):Play()
        callback(isToggled)
    end)

    return frame
end

-- ====================================================================
-- == LOGIKA INTI MAGNET                                             ==
-- ====================================================================

local function stopMagnet()
    if not isMagnetActive then return end
    isMagnetActive = false
    if magnetConnection then
        magnetConnection:Disconnect()
        magnetConnection = nil
    end
    
    -- Hapus BodyPosition dan Constraints dari semua part yang tertarik
    for part, data in pairs(attractParts) do
        if data.BodyPosition and data.BodyPosition.Parent then
            data.BodyPosition:Destroy()
        end
        for _, constraint in ipairs(data.Constraints) do
            if constraint and constraint.Parent then
                constraint:Destroy()
            end
        end
    end
    attractParts = {}
    print("Magnet dihentikan.")
end

local powerTextBox, rangeTextBox, toggleButton -- Deklarasi di luar agar bisa diakses

local function playMagnet()
    if isMagnetActive and magnetConnection then return end -- Sudah aktif, jangan buat koneksi baru

    -- Validasi dan ambil nilai dari text box
    local powerValue = tonumber(powerTextBox.Text)
    local rangeValue = tonumber(rangeTextBox.Text)

    if not powerValue or not rangeValue or powerValue <= 0 or rangeValue <= 0 then
        print("Error: Power dan Range harus berupa angka positif.")
        return
    end
    
    magnetPower = powerValue
    magnetRange = rangeValue
    
    isMagnetActive = true
    print("Magnet dimulai dengan Power: " .. magnetPower .. ", Range: " .. magnetRange)

    magnetConnection = RunService.Heartbeat:Connect(function()
        if not isMagnetActive then return end
        
        local character = LocalPlayer.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then
            -- Karakter tidak ada (mungkin sedang mati/respawn), hentikan loop sementara
            if magnetConnection then
                magnetConnection:Disconnect()
                magnetConnection = nil
            end
            -- Jangan panggil stopMagnet() agar isMagnetActive tetap true
            return
        end
        
        local rootPart = character.HumanoidRootPart
        local playerPosition = rootPart.Position
        
        -- Hapus BodyPosition dan Constraints dari part yang sudah di luar jangkauan
        for part, data in pairs(attractParts) do
            if not part or not part.Parent or (part.Position - playerPosition).Magnitude > magnetRange then
                if data.BodyPosition and data.BodyPosition.Parent then
                    data.BodyPosition:Destroy()
                end
                for _, constraint in ipairs(data.Constraints) do
                    if constraint and constraint.Parent then
                        constraint:Destroy()
                    end
                end
                attractParts[part] = nil
            end
        end
        
        -- Cari part baru di dalam jangkauan
        local partsInWorkspace = workspace:GetPartBoundsInRadius(playerPosition, magnetRange)
        for _, part in ipairs(partsInWorkspace) do
            if part:IsA("BasePart") and not part.Anchored and not character:IsAncestorOf(part) and not attractParts[part] then
                local bp = Instance.new("BodyPosition")
                bp.Name = "MagnetForce"
                
                -- Terapkan kekuatan berbeda berdasarkan mode
                if magnetDirection == "Ke Karakter" then
                    bp.MaxForce = Vector3.new(1, 1, 1) * magnetPower * 100000 -- Jauh lebih kuat
                    bp.P = 50000 -- Lebih responsif
                    bp.D = 1000
                else -- Acak
                    bp.MaxForce = Vector3.new(1, 1, 1) * magnetPower * 1000
                    bp.P = 5000 
                    bp.D = 100 
                end
                
                bp.Position = playerPosition
                bp.Parent = part
                
                -- Buat NoCollisionConstraint antara part dan semua bagian karakter
                local constraints = {}
                for _, charPart in ipairs(character:GetChildren()) do
                    if charPart:IsA("BasePart") then
                        local constraint = Instance.new("NoCollisionConstraint")
                        constraint.Part0 = part
                        constraint.Part1 = charPart
                        constraint.Parent = part
                        table.insert(constraints, constraint)
                    end
                end
                
                attractParts[part] = {BodyPosition = bp, Constraints = constraints}
            end
        end
        
        -- Perbarui posisi target untuk semua BodyPosition yang ada
        for part, data in pairs(attractParts) do
            if data.BodyPosition and data.BodyPosition.Parent then
                local targetPosition
                if magnetDirection == "Ke Karakter" then
                    targetPosition = playerPosition
                elseif magnetDirection == "Acak" then
                    targetPosition = playerPosition + Vector3.new(math.random(-magnetRange, magnetRange), math.random(-magnetRange, magnetRange), math.random(-magnetRange, magnetRange))
                elseif magnetDirection == "Atas" then
                    targetPosition = playerPosition + (rootPart.CFrame.UpVector * magnetRange)
                elseif magnetDirection == "Bawah" then
                    targetPosition = playerPosition - (rootPart.CFrame.UpVector * magnetRange)
                elseif magnetDirection == "Kanan" then
                    targetPosition = playerPosition + (rootPart.CFrame.RightVector * magnetRange)
                elseif magnetDirection == "Kiri" then
                    targetPosition = playerPosition - (rootPart.CFrame.RightVector * magnetRange)
                else
                    targetPosition = playerPosition -- Fallback
                end
                data.BodyPosition.Position = targetPosition
            end
        end
    end)
end


-- ====================================================================
-- == LOGIKA FE REMOVE OBJEK                                         ==
-- ====================================================================

local function onTouch(hit)
    if not hit or not hit.Parent or hit:IsA("Terrain") then return end
    
    -- Validasi dasar: jangan hancurkan pemain lain atau bagian tubuh diri sendiri
    if Players:GetPlayerFromCharacter(hit.Parent) or LocalPlayer.Character and hit.Parent == LocalPlayer.Character then
        return
    end
    
    -- Hanya pindahkan part yang tidak terikat (Anchored = false)
    if hit:IsA("BasePart") and not hit.Anchored then
        pcall(function()
            hit.CFrame = CFrame.new(hit.Position.X, -10000, hit.Position.Z)
        end)
    end
end

local function detachTouchListeners()
    for _, conn in ipairs(touchConnections) do
        conn:Disconnect()
    end
    table.clear(touchConnections)
    print("FE Remove Objek dinonaktifkan.")
end

local function attachTouchListeners(character)
    detachTouchListeners() -- Hapus listener lama sebelum memasang yang baru
    if not character then return end
    
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            local conn = part.Touched:Connect(onTouch)
            table.insert(touchConnections, conn)
        end
    end
    print("FE Remove Objek diaktifkan.")
end

-- ====================================================================
local function InitializeMagnetGUI()
    if CoreGui:FindFirstChild("MagnetGUI") then
        CoreGui:FindFirstChild("MagnetGUI"):Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui", CoreGui)
    ScreenGui.Name = "MagnetGUI"
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.ResetOnSpawn = false

    local MainFrame = Instance.new("Frame", ScreenGui)
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 180, 0, 115) -- Diperbesar lagi untuk toggle baru
    MainFrame.Position = UDim2.new(0.1, 0, 0.5, -55)
    MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    MainFrame.BackgroundTransparency = 0.5
    MainFrame.ClipsDescendants = true

    local MainUICorner = Instance.new("UICorner", MainFrame)
    MainUICorner.CornerRadius = UDim.new(0, 8)
    
    local UIStroke = Instance.new("UIStroke", MainFrame)
    UIStroke.Color = Color3.fromRGB(0, 150, 255)
    UIStroke.Thickness = 1.5

    local TitleBar = Instance.new("TextButton", MainFrame)
    TitleBar.Name = "TitleBar"
    TitleBar.Size = UDim2.new(1, 0, 0, 25)
    TitleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    TitleBar.Text = ""
    TitleBar.AutoButtonColor = false
    MakeDraggable(MainFrame, TitleBar)

    local TitleLabel = Instance.new("TextLabel", TitleBar)
    TitleLabel.Size = UDim2.new(1, 0, 1, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = "Magnet"
    TitleLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
    TitleLabel.TextSize = 12
    TitleLabel.Font = Enum.Font.SourceSansBold

    -- Switch utama (menjadi child langsung dari MainFrame, di atas ScrollingFrame)
    local masterToggleFrame = createToggle(MainFrame, "Magnet Objek", false, function(isEnabled)
        local contentFrame = MainFrame:FindFirstChild("ContentFrame")
        if contentFrame then
            contentFrame.Visible = isEnabled
        end
        
        local targetSize = isEnabled and UDim2.new(0, 180, 0, 155) or UDim2.new(0, 180, 0, 85) -- Ukuran disesuaikan
        TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = targetSize}):Play()

        if not isEnabled then
            stopMagnet()
        end
    end)
    masterToggleFrame.Position = UDim2.new(0, 5, 0, 30)
    masterToggleFrame.Size = UDim2.new(1, -10, 0, 25)

    -- Toggle FE Hapus Objek (juga child langsung dari MainFrame)
    local feRemoveToggleFrame = createToggle(MainFrame, "FE Hapus Objek", isRemoveEnabled, function(isEnabled)
        isRemoveEnabled = isEnabled
        if isEnabled then
            attachTouchListeners(LocalPlayer.Character)
        else
            detachTouchListeners()
        end
    end)
    feRemoveToggleFrame.Position = UDim2.new(0, 5, 0, 58)
    feRemoveToggleFrame.Size = UDim2.new(1, -10, 0, 25)

    -- Kontainer untuk semua kontrol (sekarang di dalam ScrollingFrame)
    local ContentFrame = Instance.new("ScrollingFrame", MainFrame)
    ContentFrame.Name = "ContentFrame"
    ContentFrame.Size = UDim2.new(1, -10, 1, -88) -- Posisi di bawah kedua toggle
    ContentFrame.Position = UDim2.new(0, 5, 0, 86)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    ContentFrame.ElasticBehavior = Enum.ElasticBehavior.Never
    ContentFrame.ScrollBarThickness = 3
    ContentFrame.Visible = false -- Mulai tersembunyi

    local ContentLayout = Instance.new("UIListLayout", ContentFrame)
    ContentLayout.Padding = UDim.new(0, 3)
    ContentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    
    local controlsRow = Instance.new("Frame", ContentFrame)
    controlsRow.BackgroundTransparency = 1
    controlsRow.Size = UDim2.new(1, 0, 0, 30)
    local rowLayout = Instance.new("UIListLayout", controlsRow)
    rowLayout.FillDirection = Enum.FillDirection.Horizontal
    rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    rowLayout.Padding = UDim.new(0, 5)

    local toggleButton = Instance.new("TextButton", controlsRow)
    toggleButton.Name = "ToggleButton" -- Nama ditambahkan
    toggleButton.Size = UDim2.new(0, 30, 1, 0)
    toggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
    toggleButton.Text = "▶️"
    toggleButton.TextColor3 = Color3.new(1, 1, 1)
    toggleButton.Font = Enum.Font.SourceSansBold
    toggleButton.TextSize = 16 -- Ikon diperkecil
    local toggleCorner = Instance.new("UICorner", toggleButton); toggleCorner.CornerRadius = UDim.new(0, 5)
    
    powerTextBox = createCompactTextBox(controlsRow, "Power", magnetPower)
    rangeTextBox = createCompactTextBox(controlsRow, "Range", magnetRange)
    
    local directionFrame = Instance.new("Frame", ContentFrame)
    directionFrame.BackgroundTransparency = 1
    directionFrame.Size = UDim2.new(1, 0, 0, 50) -- Tinggi diperbesar untuk grid
    local directionLayout = Instance.new("UIGridLayout", directionFrame)
    directionLayout.CellPadding = UDim2.new(0, 4, 0, 4)
    directionLayout.CellSize = UDim2.new(0.33, -3, 0.5, -2)
    directionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    directionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    
    local directionButtons = {}
    local function createDirectionButton(name)
        local button = Instance.new("TextButton", directionFrame)
        button.Name = name
        button.Text = name
        button.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        button.TextColor3 = Color3.fromRGB(220, 220, 220)
        button.Font = Enum.Font.SourceSans
        button.TextSize = 11
        local corner = Instance.new("UICorner", button); corner.CornerRadius = UDim.new(0, 4)
        table.insert(directionButtons, button)
    end
    
    createDirectionButton("Ke Karakter")
    createDirectionButton("Acak")
    createDirectionButton("Atas")
    createDirectionButton("Bawah")
    createDirectionButton("Kiri")
    createDirectionButton("Kanan")

    local function updateDirectionButtons()
        for _, button in ipairs(directionButtons) do
            if button.Name == magnetDirection then
                button.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
                button.Font = Enum.Font.SourceSansBold
            else
                button.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
                button.Font = Enum.Font.SourceSans
            end
        end
    end

    for _, button in ipairs(directionButtons) do
        button.MouseButton1Click:Connect(function()
            magnetDirection = button.Name
            updateDirectionButtons()
        end)
    end
    updateDirectionButtons()

    local function toggleMagnet()
        if isMagnetActive then
            stopMagnet()
            toggleButton.Text = "▶️"
            toggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        else
            playMagnet()
            if isMagnetActive then
                toggleButton.Text = "⏹️"
                toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            end
        end
    end
    toggleButton.MouseButton1Click:Connect(toggleMagnet)
    
    ContentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        ContentFrame.CanvasSize = UDim2.new(0, 0, 0, ContentLayout.AbsoluteContentSize.Y)
    end)
end

-- Panggil fungsi inisialisasi utama
InitializeMagnetGUI()

-- Fungsi untuk menangani respawn
local function handleRespawn(character)
    task.wait() -- Tunggu sesaat agar GUI sempat di-reset jika ada
    if isMagnetActive then
        playMagnet()
        
        -- Cari tombol yang ada di GUI saat ini untuk diperbarui
        local magnetGui = CoreGui:FindFirstChild("MagnetGUI", true)
        local currentToggleButton = magnetGui and magnetGui:FindFirstChild("ToggleButton", true)

        if currentToggleButton then
            currentToggleButton.Text = "⏹️"
            currentToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        end
    end
end

-- Hubungkan event CharacterAdded
LocalPlayer.CharacterAdded:Connect(handleRespawn)

-- Hubungkan kembali listener sentuhan jika fitur aktif saat respawn
LocalPlayer.CharacterAdded:Connect(function(character)
    if isRemoveEnabled then
        task.wait(0.5) -- Beri waktu sedikit
        attachTouchListeners(character)
    end
end)

print("Magnet.lua loaded.")
