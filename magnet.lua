-- magnet.lua (Revisi UI & Fitur oleh Gemini)
--[[
    Skrip ini membuat GUI magnet yang dapat digeser.

    PERUBAHAN v2.7 (Perbaikan Header & Minimize Bug):
    - Estetika Header: Menambahkan UICorner ke TitleBar agar memiliki sudut membulat di bagian atas.
    - Tata Letak Header/Konten: Mengatur ContentFrame agar dimulai tepat di bawah TitleBar (Y=25) untuk tampilan yang mulus.
    - Perbaikan Bug Minimize: Logic minimizedSize dihitung menggunakan ukuran absolut MainFrame (lebar 180, tinggi 25) 
      untuk mencegah frame meregang ke seluruh layar saat diminimalkan.
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
local wasMagnetActive = false -- Menyimpan status magnet sebelum mati/respawn
local magnetPower = 999
local magnetRange = 150

local magnetConnection = nil
local scannedParts = {} -- Menyimpan parts hasil scan
local partGoals = {} -- Menyimpan posisi tujuan untuk mode acak
local scanCenterPosition = Vector3.zero -- Titik tengah untuk mode acak

local notificationFrame, notificationLabel, notificationTween -- Untuk notifikasi global
local UI = {} -- Tabel untuk menyimpan referensi elemen UI

-- Konfigurasi Mode
local MODES = {
    {Name = "Ke Karakter", ID = "target_player"},
    {Name = "Acak", ID = "random_free"}
}
local currentModeIndex = 1
local magnetDirection = MODES[currentModeIndex].ID

-- ====================================================================
-- == FUNGSI UTILITAS GUI                                            ==
-- ====================================================================

local function makeDraggable(guiObject, dragHandle)
    local dragInput, dragStart, startPos
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragInput, dragStart, startPos = input, input.Position, guiObject.Position
        end
    end)
    dragHandle.InputChanged:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and dragInput then
            local delta = input.Position - dragStart
            guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    dragHandle.InputEnded:Connect(function(input)
        if input == dragInput then dragInput = nil end
    end)
end

local function showNotification(message, color, duration)
    if notificationTween then notificationTween:Cancel() end
    notificationFrame.Visible = true; notificationLabel.Text = message; notificationLabel.TextColor3 = color
    TweenService:Create(notificationFrame, TweenInfo.new(0.3), {BackgroundTransparency = 0.2}):Play()
    TweenService:Create(notificationLabel, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
    if duration then
        task.delay(duration, function()
            notificationTween = TweenService:Create(notificationFrame, TweenInfo.new(0.5), {BackgroundTransparency = 1})
            notificationTween:Play()
            TweenService:Create(notificationLabel, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
            notificationTween.Completed:Connect(function() notificationFrame.Visible = false end)
        end)
    end
end

-- ====================================================================
-- == LOGIKA INTI MAGNET                                             ==
-- ====================================================================
local powerTextBox, rangeTextBox

local function stopMagnet()
    if not isMagnetActive then return end
    isMagnetActive = false
    if magnetConnection then magnetConnection:Disconnect(); magnetConnection = nil end
    
    task.spawn(function()
        for _, part in ipairs(scannedParts) do
            if part and part.Parent and part:IsA("BasePart") then
                part.AssemblyLinearVelocity = Vector3.zero
                pcall(function() part:SetNetworkOwner(nil) end)
            end
        end
    end)
    
    print("Magnet dihentikan.")
end

local function scanForParts()
    local rangeValue = tonumber(rangeTextBox.Text)
    if not rangeValue or rangeValue <= 0 then showNotification("Range tidak valid!", Color3.fromRGB(255, 100, 100), 3); return end
    
    stopMagnet()
    scannedParts = {}
    partGoals = {} -- Hapus tujuan lama saat scan baru
    
    showNotification("Mencari objek...", Color3.fromRGB(220, 220, 220)); task.wait(0.1)
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then showNotification("Karakter tidak ditemukan!", Color3.fromRGB(255, 100, 100), 3); return end
    
    scanCenterPosition = character.HumanoidRootPart.Position -- Simpan posisi untuk mode acak
    
    local partsInWorkspace = workspace:GetPartBoundsInRadius(scanCenterPosition, rangeValue)
    for _, part in ipairs(partsInWorkspace) do
        if part:IsA("BasePart") and not part.Anchored and not character:IsAncestorOf(part) then
            pcall(function() part:SetNetworkOwner(LocalPlayer) end)
            table.insert(scannedParts, part)
        end
    end
    local count = #scannedParts
    showNotification("Scan Selesai: " .. count .. " objek ditemukan.", Color3.fromRGB(100, 255, 100), 4)
    if UI.statusLabel then
        UI.statusLabel.Text = "Parts: " .. count
        UI.statusLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
    end
    print("Scanning selesai. Ditemukan " .. count .. " part.")
end

local function playMagnet()
    if isMagnetActive then return false end
    local powerValue = tonumber(powerTextBox.Text)
    if not powerValue or powerValue <= 0 then showNotification("Power tidak valid!", Color3.fromRGB(255, 100, 100), 3); return false end
    magnetPower = powerValue
    if #scannedParts == 0 then showNotification("Tidak ada objek hasil scan. Scan dulu!", Color3.fromRGB(255, 200, 100), 3); return false end
    isMagnetActive = true
    print("Magnet dimulai pada " .. #scannedParts .. " part yang di-scan.")

    magnetConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not isMagnetActive then
            if magnetConnection then magnetConnection:Disconnect(); magnetConnection = nil end
            return
        end
        local character = LocalPlayer.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        if not rootPart then stopMagnet(); return end
        
        local forceMultiplier = magnetPower * 2500 * deltaTime

        for i = #scannedParts, 1, -1 do
            local part = scannedParts[i]
            if part and part.Parent then
                local targetPosition
                
                if magnetDirection == "random_free" then
                    local goal = partGoals[part]
                    local distanceToGoal = goal and (part.Position - goal).Magnitude or 100
                    
                    if not goal or distanceToGoal < 15 then
                        local randomOffset = Vector3.new(
                            math.random(-magnetRange, magnetRange),
                            math.random(5, 50),
                            math.random(-magnetRange, magnetRange)
                        )
                        partGoals[part] = scanCenterPosition + randomOffset
                    end
                    targetPosition = partGoals[part]
                else -- Mode "Ke Karakter"
                    targetPosition = rootPart.Position
                end

                local direction = (targetPosition - part.Position)
                local distance = direction.Magnitude
                if distance < 1 then distance = 1 end
                
                local velocity = direction.Unit * forceMultiplier * (1 / distance)
                part.AssemblyLinearVelocity = velocity
            else
                table.remove(scannedParts, i)
            end
        end
    end)
    return true
end

-- ====================================================================
-- == INISIALISASI GUI                                               ==
-- ====================================================================
local function InitializeMagnetGUI()
    if CoreGui:FindFirstChild("MagnetGUI") then CoreGui:FindFirstChild("MagnetGUI"):Destroy() end
    local ScreenGui = Instance.new("ScreenGui", CoreGui); ScreenGui.Name = "MagnetGUI"; ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; ScreenGui.ResetOnSpawn = false
    
    local MainFrame = Instance.new("Frame", ScreenGui)
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 180, 0, 95)
    MainFrame.Position = UDim2.new(0.1, 0, 0.5, -55)
    MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    MainFrame.BackgroundTransparency = 0.5
    local MainUICorner = Instance.new("UICorner", MainFrame); MainUICorner.CornerRadius = UDim.new(0, 8)
    local UIStroke = Instance.new("UIStroke", MainFrame); UIStroke.Color = Color3.fromRGB(0, 150, 255); UIStroke.Thickness = 1.5

    local TitleBar = Instance.new("TextButton", MainFrame)
    TitleBar.Name = "TitleBar"; TitleBar.Size = UDim2.new(1, 0, 0, 25)
    TitleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25); TitleBar.Text = ""
    -- PERBAIKAN: Menambahkan sudut membulat pada TitleBar agar sesuai MainFrame
    local TitleBarCorner = Instance.new("UICorner", TitleBar); TitleBarCorner.CornerRadius = UDim.new(0, 8)
    TitleBar.AutoButtonColor = false; makeDraggable(MainFrame, TitleBar)

    local TitleLabel = Instance.new("TextLabel", TitleBar)
    TitleLabel.Size = UDim2.new(0.4, 0, 1, 0); TitleLabel.Position = UDim2.new(0, 8, 0, 0)
    TitleLabel.BackgroundTransparency = 1; TitleLabel.Text = "Magnet"
    TitleLabel.TextColor3 = Color3.fromRGB(0, 200, 255); TitleLabel.TextSize = 12
    TitleLabel.Font = Enum.Font.SourceSansBold; TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

    UI.statusLabel = Instance.new("TextLabel", TitleBar)
    UI.statusLabel.Size = UDim2.new(0.5, 0, 1, 0); UI.statusLabel.Position = UDim2.new(0.3, 0, 0, 0)
    UI.statusLabel.BackgroundTransparency = 1; UI.statusLabel.Text = "Parts: 0"
    UI.statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180); UI.statusLabel.TextSize = 10
    UI.statusLabel.Font = Enum.Font.SourceSans; UI.statusLabel.TextXAlignment = Enum.TextXAlignment.Center
    
    local closeBtn = Instance.new("TextButton",TitleBar)
    closeBtn.Size = UDim2.new(0,18,0,18); closeBtn.Position = UDim2.new(1,-22,0.5,-9); closeBtn.BackgroundTransparency = 1; closeBtn.Font = Enum.Font.SourceSansBold; closeBtn.Text = "X"; closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255); closeBtn.TextSize = 16

    local minimizeBtn = Instance.new("TextButton", TitleBar)
    minimizeBtn.Size = UDim2.new(0, 18, 0, 18); minimizeBtn.Position = UDim2.new(1, -42, 0.5, -9); minimizeBtn.BackgroundTransparency = 1; minimizeBtn.Font = Enum.Font.SourceSansBold; minimizeBtn.Text = "-"; minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255); minimizeBtn.TextSize = 20

    local ContentFrame = Instance.new("Frame", MainFrame)
    ContentFrame.Name = "ContentFrame"; ContentFrame.ClipsDescendants = true
    ContentFrame.Size = UDim2.new(1, -10, 1, -30) -- Lebar 170px
    -- PERBAIKAN: Posisi Y ContentFrame diatur menjadi 25 agar menempel TitleBar
    ContentFrame.Position = UDim2.new(0, 5, 0, 25)
    ContentFrame.BackgroundTransparency = 1
    local ContentLayout = Instance.new("UIListLayout", ContentFrame); ContentLayout.Padding = UDim.new(0, 4)

    local function createIconButton(parent, text, size, callback)
        local btn = Instance.new("TextButton", parent)
        btn.Size = UDim2.new(0, size, 0, 24); btn.Text = text
        btn.Font = Enum.Font.SourceSansBold; btn.TextSize = 16
        btn.TextColor3 = Color3.new(1, 1, 1)
        local corner = Instance.new("UICorner", btn); corner.CornerRadius = UDim.new(0, 5)
        if callback then btn.MouseButton1Click:Connect(callback) end
        return btn
    end
    
    local function createCompactTextBox(parent, name, defaultValue)
        local frame = Instance.new("Frame", parent)
        frame.BackgroundTransparency = 1; frame.Size = UDim2.new(0, 55, 0, 24)
        
        local label = Instance.new("TextLabel", frame)
        label.Size = UDim2.new(1, 0, 0, 12); label.BackgroundTransparency = 1; label.Font = Enum.Font.SourceSans
        label.Text = name; label.TextColor3 = Color3.fromRGB(200, 200, 200); label.TextSize = 10
        label.TextXAlignment = Enum.TextXAlignment.Center
        
        local textBox = Instance.new("TextBox", frame)
        textBox.Size = UDim2.new(1, 0, 1, -12); textBox.Position = UDim2.new(0, 0, 0, 12)
        textBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35); textBox.TextColor3 = Color3.fromRGB(220, 220, 220)
        textBox.Text = tostring(defaultValue); textBox.Font = Enum.Font.SourceSans; textBox.TextSize = 11
        textBox.TextXAlignment = Enum.TextXAlignment.Center
        local corner = Instance.new("UICorner", textBox); corner.CornerRadius = UDim.new(0, 4)
        
        return frame, textBox 
    end

    -- Baris 1: Range, Power, Scan
    local controlsRow = Instance.new("Frame", ContentFrame)
    controlsRow.BackgroundTransparency = 1; controlsRow.Size = UDim2.new(1, 0, 0, 28)

    -- 1. Textbox Range (Far Left, Posisi X=0, Width 55)
    local rangeFrame
    rangeFrame, rangeTextBox = createCompactTextBox(controlsRow, "Range", magnetRange)
    rangeFrame.Position = UDim2.new(0, 0, 0.5, -12)

    -- 2. Textbox Power (Tengah, Posisi X=70, Width 55)
    local powerFrame 
    powerFrame, powerTextBox = createCompactTextBox(controlsRow, "Power", magnetPower)
    powerFrame.Position = UDim2.new(0, 70, 0.5, -12)

    -- 3. Tombol Scan (Far Right, Posisi X=140, Width 30)
    local scanButton = createIconButton(controlsRow, "📡", 30, scanForParts)
    scanButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
    scanButton.Position = UDim2.new(0, 140, 0.5, -12) 

    -- Baris 2: Mode & Play
    local modeRow = Instance.new("Frame", ContentFrame)
    modeRow.BackgroundTransparency = 1; modeRow.Size = UDim2.new(1, 0, 0, 28)

    local prevBtn = createIconButton(modeRow, "<", 25)
    prevBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    prevBtn.Position = UDim2.new(0, 0, 0.5, -12)

    local nextBtn = createIconButton(modeRow, ">", 25)
    nextBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    nextBtn.Position = UDim2.new(0, 95, 0.5, -12)

    local modeLabel = Instance.new("TextLabel", modeRow)
    modeLabel.Size = UDim2.new(0, 70, 1, 0); 
    modeLabel.Position = UDim2.new(0, 25, 0, 0)
    modeLabel.BackgroundTransparency = 1; modeLabel.Font = Enum.Font.SourceSansBold
    modeLabel.TextSize = 10; modeLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    modeLabel.TextWrapped = true; modeLabel.TextXAlignment = Enum.TextXAlignment.Center
    
    UI.toggleButton = createIconButton(modeRow, "▶️", 30)
    UI.toggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
    UI.toggleButton.Position = UDim2.new(1, -30, 0.5, -12)
    
    local function updateModeDisplay()
        local currentModeData = MODES[currentModeIndex]
        magnetDirection = currentModeData.ID
        modeLabel.Text = currentModeData.Name
    end
    
    prevBtn.MouseButton1Click:Connect(function()
        currentModeIndex = currentModeIndex - 1
        if currentModeIndex < 1 then currentModeIndex = #MODES end
        updateModeDisplay()
    end)
    
    nextBtn.MouseButton1Click:Connect(function()
        currentModeIndex = currentModeIndex + 1
        if currentModeIndex > #MODES then currentModeIndex = 1 end
        updateModeDisplay()
    end)
    
    updateModeDisplay()

    local function toggleMagnet()
        if isMagnetActive then
            stopMagnet(); wasMagnetActive = false; UI.toggleButton.Text = "▶️"; UI.toggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        else
            if playMagnet() then wasMagnetActive = true; UI.toggleButton.Text = "⏹️"; UI.toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50) end
        end
    end
    UI.toggleButton.MouseButton1Click:Connect(toggleMagnet)
    
    closeBtn.MouseButton1Click:Connect(function() if isMagnetActive then stopMagnet() end; ScreenGui:Destroy() end)
    
    -- Logic Minimize yang sudah diperbaiki
    local isMinimized = false; 
    local originalSize = MainFrame.Size -- UDim2.new(0, 180, 0, 95)
    
    -- PERBAIKAN: Hitung ukuran minimal dengan lebar MainFrame (180) dan tinggi TitleBar (25)
    local minimizedSize = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, TitleBar.Size.Y.Offset)
    
    minimizeBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        ContentFrame.Visible = not isMinimized
        
        local targetSize = isMinimized and minimizedSize or originalSize
        TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = targetSize}):Play()
    end)
end

local function InitializeNotificationGUI()
    if CoreGui:FindFirstChild("ScanNotificationGui") then CoreGui:FindFirstChild("ScanNotificationGui"):Destroy() end
    local ScreenGui = Instance.new("ScreenGui", CoreGui); ScreenGui.Name = "ScanNotificationGui"; ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; ScreenGui.ResetOnSpawn = false
    notificationFrame = Instance.new("Frame", ScreenGui); notificationFrame.Name = "NotificationFrame"; notificationFrame.Size = UDim2.new(0, 280, 0, 35)
    notificationFrame.Position = UDim2.new(0.5, -140, 1, -80); notificationFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    notificationFrame.BackgroundTransparency = 1; notificationFrame.Visible = false; local corner = Instance.new("UICorner", notificationFrame); corner.CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", notificationFrame); stroke.Color = Color3.fromRGB(80, 80, 80); stroke.Thickness = 1
    notificationLabel = Instance.new("TextLabel", notificationFrame); notificationLabel.Name = "NotificationLabel"; notificationLabel.Size = UDim2.new(1, 0, 1, 0); notificationLabel.BackgroundTransparency = 1
    notificationLabel.Font = Enum.Font.SourceSansBold; notificationLabel.Text = ""; notificationLabel.TextColor3 = Color3.fromRGB(255, 255, 255); notificationLabel.TextSize = 14; notificationLabel.TextTransparency = 1
end

InitializeMagnetGUI(); InitializeNotificationGUI()

local function handleRespawn(character)
    task.wait(0.5)
    if wasMagnetActive then
        if playMagnet() and UI.toggleButton then
            UI.toggleButton.Text = "⏹️"
            UI.toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        end
    end
end

LocalPlayer.CharacterAdded:Connect(handleRespawn)

print("Magnet.lua (Revisi Gemini v2.7) loaded.")

