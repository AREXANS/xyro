-- magnet.lua
--[[
    Skrip ini membuat GUI magnet yang dapat digeser dengan kontrol untuk 
    memulai/menghentikan efek magnet, dan menyesuaikan kekuatan serta jangkauannya.
    Gaya visualnya meniru 'Arexanstools.lua' untuk konsistensi.
    
    VERSI INSTAN & FINAL:
    - Mesin fisika dirombak total menggunakan AssemblyLinearVelocity untuk performa instan tanpa delay.
    - Tata letak GUI diperbaiki agar semua elemen terlihat dan tidak terpotong.
    - Menambahkan fitur Scan untuk mencari parts dalam jangkauan tertentu.
    - Fungsi Play/Stop sekarang hanya akan mempengaruhi parts yang sudah di-scan.
    - Menambahkan notifikasi scan di bagian bawah layar.
    - Status magnet kini tersimpan, sehingga akan otomatis aktif kembali setelah respawn.
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
local magnetPower = 50
local magnetRange = 50
local magnetDirection = "Ke Karakter" -- Opsi: "Ke Karakter", "Acak"
local magnetConnection = nil
local scannedParts = {} -- Menyimpan parts hasil scan
local isRemoveEnabled = false
local touchConnections = {}
local notificationFrame = nil -- Untuk notifikasi global di bawah layar
local notificationLabel = nil
local notificationTween = nil

-- ====================================================================
-- == FUNGSI UTILITAS GUI                                            ==
-- ====================================================================

local function MakeDraggable(guiObject, dragHandle)
    local dragInput = nil
    local dragStart = nil
    local startPos = nil

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

local function createCompactTextBox(parent, name, defaultValue)
    local frame = Instance.new("Frame", parent); frame.BackgroundTransparency = 1; frame.Size = UDim2.new(0, 55, 1, 0)
    local label = Instance.new("TextLabel", frame); label.Size = UDim2.new(1, 0, 0, 12); label.BackgroundTransparency = 1; label.Font = Enum.Font.SourceSans
    label.Text = name; label.TextColor3 = Color3.fromRGB(200, 200, 200); label.TextSize = 10; label.TextXAlignment = Enum.TextXAlignment.Center
    local textBox = Instance.new("TextBox", frame); textBox.Size = UDim2.new(1, 0, 1, -14); textBox.Position = UDim2.new(0, 0, 0, 14)
    textBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35); textBox.TextColor3 = Color3.fromRGB(220, 220, 220); textBox.Text = tostring(defaultValue)
    textBox.Font = Enum.Font.SourceSans; textBox.TextSize = 12; textBox.TextXAlignment = Enum.TextXAlignment.Center
    local corner = Instance.new("UICorner", textBox); corner.CornerRadius = UDim.new(0, 4)
    return textBox
end

local function createToggle(parent, name, initialState, callback)
    local frame = Instance.new("Frame", parent); frame.Size = UDim2.new(1, 0, 0, 25); frame.BackgroundTransparency = 1
    local label = Instance.new("TextLabel", frame); label.Size = UDim2.new(1, -45, 1, 0); label.BackgroundTransparency = 1; label.Font = Enum.Font.SourceSans
    label.Text = name; label.TextColor3 = Color3.fromRGB(220, 220, 220); label.TextSize = 12; label.TextXAlignment = Enum.TextXAlignment.Left
    local switch = Instance.new("TextButton", frame); switch.Size = UDim2.new(0, 40, 0, 20); switch.Position = UDim2.new(1, -40, 0.5, -10)
    switch.BackgroundColor3 = initialState and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(60, 60, 60); switch.Text = ""
    local switchCorner = Instance.new("UICorner", switch); switchCorner.CornerRadius = UDim.new(1, 0)
    local thumb = Instance.new("Frame", switch); thumb.Size = UDim2.new(0, 16, 0, 16)
    thumb.Position = initialState and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8); thumb.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
    local thumbCorner = Instance.new("UICorner", thumb); thumbCorner.CornerRadius = UDim.new(1, 0)
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
local powerTextBox, rangeTextBox, toggleButton

local function stopMagnet()
    if not isMagnetActive then return end
    isMagnetActive = false
    if magnetConnection then magnetConnection:Disconnect(); magnetConnection = nil end
    
    -- Reset kecepatan part agar berhenti melayang
    task.spawn(function()
        for _, part in ipairs(scannedParts) do
            if part and part.Parent and part:IsA("BasePart") then
                part.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end)
    
    print("Magnet dihentikan.")
end

local function scanForParts()
    local rangeValue = tonumber(rangeTextBox.Text)
    if not rangeValue or rangeValue <= 0 then showNotification("Range tidak valid!", Color3.fromRGB(255, 100, 100), 3); return end
    stopMagnet(); scannedParts = {}
    showNotification("Mencari objek...", Color3.fromRGB(220, 220, 220)); task.wait(0.1)
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then showNotification("Karakter tidak ditemukan!", Color3.fromRGB(255, 100, 100), 3); return end
    local playerPosition = character.HumanoidRootPart.Position
    local partsInWorkspace = workspace:GetPartBoundsInRadius(playerPosition, rangeValue)
    for _, part in ipairs(partsInWorkspace) do
        if part:IsA("BasePart") and not part.Anchored and not character:IsAncestorOf(part) then
            table.insert(scannedParts, part)
        end
    end
    local count = #scannedParts
    showNotification("Scan Selesai: " .. count .. " objek ditemukan.", Color3.fromRGB(100, 255, 100), 4)
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
        local playerPosition = rootPart.Position
        local forceMultiplier = magnetPower * 50 * deltaTime

        for i = #scannedParts, 1, -1 do
            local part = scannedParts[i]
            if part and part.Parent then
                local direction = (playerPosition - part.Position)
                local distance = direction.Magnitude
                if distance < 1 then distance = 1 end
                
                -- Efek magnet yang lebih kuat saat dekat
                local velocity = direction.Unit * forceMultiplier * (1 / distance)
                part.AssemblyLinearVelocity = part.AssemblyLinearVelocity:Lerp(velocity, 0.1)

            else
                table.remove(scannedParts, i)
            end
        end
    end)
    return true
end

-- ====================================================================
-- == LOGIKA FE REMOVE OBJEK                                         ==
-- ====================================================================
local function onTouch(hit)
    if not hit or not hit.Parent or hit:IsA("Terrain") then return end
    if Players:GetPlayerFromCharacter(hit.Parent) or (LocalPlayer.Character and hit.Parent == LocalPlayer.Character) then return end
    if hit:IsA("BasePart") and not hit.Anchored then pcall(function() hit.CFrame = CFrame.new(hit.Position.X, -10000, hit.Position.Z) end) end
end

local function detachTouchListeners()
    for _, conn in ipairs(touchConnections) do conn:Disconnect() end
    table.clear(touchConnections); print("FE Remove Objek dinonaktifkan.")
end

local function attachTouchListeners(character)
    detachTouchListeners()
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then table.insert(touchConnections, part.Touched:Connect(onTouch)) end
    end
    print("FE Remove Objek diaktifkan.")
end

-- ====================================================================
local function InitializeMagnetGUI()
    if CoreGui:FindFirstChild("MagnetGUI") then CoreGui:FindFirstChild("MagnetGUI"):Destroy() end
    local ScreenGui = Instance.new("ScreenGui", CoreGui); ScreenGui.Name = "MagnetGUI"; ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; ScreenGui.ResetOnSpawn = false
    local MainFrame = Instance.new("Frame", ScreenGui); MainFrame.Name = "MainFrame"; MainFrame.Size = UDim2.new(0, 180, 0, 85)
    MainFrame.Position = UDim2.new(0.1, 0, 0.5, -55); MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20); MainFrame.BackgroundTransparency = 0.5
    MainFrame.ClipsDescendants = true; local MainUICorner = Instance.new("UICorner", MainFrame); MainUICorner.CornerRadius = UDim.new(0, 8)
    local UIStroke = Instance.new("UIStroke", MainFrame); UIStroke.Color = Color3.fromRGB(0, 150, 255); UIStroke.Thickness = 1.5
    local TitleBar = Instance.new("TextButton", MainFrame); TitleBar.Name = "TitleBar"; TitleBar.Size = UDim2.new(1, 0, 0, 25); TitleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    TitleBar.Text = ""; TitleBar.AutoButtonColor = false; MakeDraggable(MainFrame, TitleBar)
    local TitleLabel = Instance.new("TextLabel", TitleBar); TitleLabel.Size = UDim2.new(1, 0, 1, 0); TitleLabel.BackgroundTransparency = 1; TitleLabel.Text = "Magnet"
    TitleLabel.TextColor3 = Color3.fromRGB(0, 200, 255); TitleLabel.TextSize = 12; TitleLabel.Font = Enum.Font.SourceSansBold

    local masterToggleFrame = createToggle(MainFrame, "Magnet Objek", false, function(isEnabled)
        local contentFrame = MainFrame:FindFirstChild("ContentFrame"); if contentFrame then contentFrame.Visible = isEnabled end
        -- PERBAIKAN: Ukuran frame disesuaikan agar semua muat
        local targetSize = isEnabled and UDim2.new(0, 180, 0, 160) or UDim2.new(0, 180, 0, 85)
        TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = targetSize}):Play()
        if not isEnabled then stopMagnet(); wasMagnetActive = false end
    end)
    masterToggleFrame.Position = UDim2.new(0, 5, 0, 30); masterToggleFrame.Size = UDim2.new(1, -10, 0, 25)

    local feRemoveToggleFrame = createToggle(MainFrame, "FE Hapus Objek", isRemoveEnabled, function(isEnabled)
        isRemoveEnabled = isEnabled
        if isEnabled then attachTouchListeners(LocalPlayer.Character) else detachTouchListeners() end
    end)
    feRemoveToggleFrame.Position = UDim2.new(0, 5, 0, 58); feRemoveToggleFrame.Size = UDim2.new(1, -10, 0, 25)

    local ContentFrame = Instance.new("Frame", MainFrame); ContentFrame.Name = "ContentFrame"; ContentFrame.Size = UDim2.new(1, -10, 1, -88)
    ContentFrame.Position = UDim2.new(0, 5, 0, 86); ContentFrame.BackgroundTransparency = 1; ContentFrame.Visible = false
    local ContentLayout = Instance.new("UIListLayout", ContentFrame); ContentLayout.Padding = UDim.new(0, 5); ContentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    
    local controlsRow = Instance.new("Frame", ContentFrame); controlsRow.BackgroundTransparency = 1; controlsRow.Size = UDim2.new(1, 0, 0, 30)
    local rowLayout = Instance.new("UIListLayout", controlsRow); rowLayout.FillDirection = Enum.FillDirection.Horizontal; rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; rowLayout.Padding = UDim.new(0, 5)

    toggleButton = Instance.new("TextButton", controlsRow); toggleButton.Name = "ToggleButton"; toggleButton.Size = UDim2.new(0, 30, 1, 0)
    toggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100); toggleButton.Text = "▶️"; toggleButton.TextColor3 = Color3.new(1, 1, 1)
    toggleButton.Font = Enum.Font.SourceSansBold; toggleButton.TextSize = 16; local tc = Instance.new("UICorner", toggleButton); tc.CornerRadius = UDim.new(0, 5)
    
    local scanButton = Instance.new("TextButton", controlsRow); scanButton.Name = "ScanButton"; scanButton.Size = UDim2.new(0, 30, 1, 0)
    scanButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255); scanButton.Text = "📡"; scanButton.TextColor3 = Color3.new(1, 1, 1)
    scanButton.Font = Enum.Font.SourceSansBold; scanButton.TextSize = 16; local sc = Instance.new("UICorner", scanButton); sc.CornerRadius = UDim.new(0, 5)
    scanButton.MouseButton1Click:Connect(scanForParts)
    
    powerTextBox = createCompactTextBox(controlsRow, "Power", magnetPower); rangeTextBox = createCompactTextBox(controlsRow, "Range", magnetRange)

    local directionFrame = Instance.new("Frame", ContentFrame); directionFrame.BackgroundTransparency = 1; directionFrame.Size = UDim2.new(1, 0, 0, 25)
	local directionDropdown = Instance.new("TextButton", directionFrame); directionDropdown.Name = "Dropdown"; directionDropdown.Size = UDim2.new(1, 0, 1, 0)
	directionDropdown.BackgroundColor3 = Color3.fromRGB(40, 40, 60); directionDropdown.TextColor3 = Color3.fromRGB(220, 220, 220); directionDropdown.Text = "Arah: Ke Karakter"
	directionDropdown.Font = Enum.Font.SourceSans; directionDropdown.TextSize = 12; local c = Instance.new("UICorner", directionDropdown); c.CornerRadius = UDim.new(0, 4)
	local options = {"Ke Karakter", "Acak"}; local currentOption = 1
	directionDropdown.MouseButton1Click:Connect(function()
		currentOption = currentOption % #options + 1; magnetDirection = options[currentOption]; directionDropdown.Text = "Arah: " .. magnetDirection
	end)

    local function toggleMagnet()
        if isMagnetActive then
            stopMagnet(); wasMagnetActive = false; toggleButton.Text = "▶️"; toggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        else
            if playMagnet() then wasMagnetActive = true; toggleButton.Text = "⏹️"; toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50) end
        end
    end
    toggleButton.MouseButton1Click:Connect(toggleMagnet)
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
    if wasMagnetActive and playMagnet() then
        local magnetGui = CoreGui:FindFirstChild("MagnetGUI", true)
        local currentToggleButton = magnetGui and magnetGui:FindFirstChild("ToggleButton", true)
        if currentToggleButton then currentToggleButton.Text = "⏹️"; currentToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50) end
    end
    if isRemoveEnabled then attachTouchListeners(character) end
end

LocalPlayer.CharacterAdded:Connect(handleRespawn)

print("Magnet.lua (Versi Instan & Final) loaded.")


