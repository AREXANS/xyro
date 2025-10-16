print("Loading Arexans Part Controller")

-- Layanan Roblox
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
repeat task.wait() until player.Character

-- Config
local config = {
    partLimit = 100,
    radius = 150,
    magnetForce = 1000000,
    speed = 5,
    launchSpeed = 100,
    updateRate = 0.03,
    batchSize = 10
}

-- State
local state = {
    mode = "bring",
    active = false,
    parts = {},
    originalProperties = {},
    removedItems = {}, -- DITAMBAHKAN: Untuk menyimpan tali/sambungan yang "dihapus"
    timeOffset = 0,
    connection = nil,
    bodyPositions = {},
    currentModeIndex = 1
}

-- UI References Table
local UI = {}

-- Modes
local MODES = {
    {n="Bring",v="bring"}, {n="Ring",v="ring"}, {n="Tornado",v="tornado"},
    {n="Blackhole",v="blackhole"}, {n="Orbit",v="orbit"}, {n="Spiral",v="spiral"},
    {n="Wave",v="wave"}, {n="Fountain",v="fountain"}, {n="Shield",v="shield"},
    {n="Sphere",v="sphere"}, {n="Launch",v="launch"}, {n="Explosion",v="explosion"},
    {n="Galaxy",v="galaxy"}, {n="DNA",v="dna"}, {n="Supernova",v="supernova"},
    {n="Matrix",v="matrix"}, {n="Vortex",v="vortex"}, {n="Meteor",v="meteor"},
    {n="Portal",v="portal"}, {n="Dragon",v="dragon"}, {n="Infinity",v="infinity"},
    {n="Tsunami",v="tsunami"}, {n="Solar",v="solar"}, {n="Quantum",v="quantum"}
}

-- ====================================================================
-- == FUNGSI LOGIKA INTI                                           ==
-- ====================================================================
local function log(m) print("[AREXANS] "..m) end
local function getPos() return player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character.HumanoidRootPart.Position end
local function getLook() return player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character.HumanoidRootPart.CFrame.LookVector or Vector3.new(0,0,-1) end

local function updatePlayStopButtonVisuals()
    if UI.toggleButton then
        if state.active then
            UI.toggleButton.Text = "⏹️"
            UI.toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        else
            UI.toggleButton.Text = "▶️"
            UI.toggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        end
    end
end

local function cleanBodyPositions()
    for _, bp in pairs(state.bodyPositions) do
        if bp and bp.Parent then bp:Destroy() end
    end
    state.bodyPositions = {}
end

-- **DIRUBAH TOTAL**: Fungsi ini tidak lagi menghapus, tapi menyimpan.
local function clearAndStoreConstraints()
    log("Menyimpan sementara semua tali dan sambungan...")
    if not UI.temporaryStorage then log("Error: Penyimpanan sementara tidak ditemukan!") return 0 end
    
    local storedCount = 0
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("RopeConstraint") or obj:IsA("WeldConstraint") or obj:IsA("Weld") or (obj:IsA("Attachment") and not obj.Parent:FindFirstChildOfClass("Humanoid")) then
            pcall(function()
                local isStored = false
                for _, entry in pairs(state.removedItems) do if entry.item == obj then isStored = true break end end
                
                if not isStored then
                    table.insert(state.removedItems, {item = obj, parent = obj.Parent})
                    obj.Parent = UI.temporaryStorage
                    storedCount = storedCount + 1
                end
            end)
        end
    end
    log("Menyimpan "..storedCount.." tali/sambungan.")
    return storedCount
end

-- **DIRUBAH**: Fungsi scan kini menyimpan, bukan menghancurkan.
local function scan()
    log("Memulai scan baru...")
    state.parts = {}
    cleanBodyPositions()
    local p = getPos()
    if not p then log("Tidak bisa scan - Posisi pemain tidak ditemukan") return {} end
    
    local scanned = 0
    for _, obj in pairs(workspace:GetDescendants()) do
        if scanned >= config.partLimit then break end
        if obj:IsA("BasePart") and not (player.Character and obj:IsDescendantOf(player.Character)) then
            if (obj.Position - p).Magnitude <= config.radius then
                pcall(function()
                    if not state.originalProperties[obj] then
                        state.originalProperties[obj] = {Anchored = obj.Anchored, CanCollide = obj.CanCollide}
                    end
                    
                    -- Ganti :BreakJoints() dan :Destroy() dengan memindahkan sambungan
                    for _, c in pairs(obj:GetChildren()) do
                        if c:IsA("Constraint") or c:IsA("Weld") or c:IsA("Attachment") then
                            local isStored = false
                            for _, entry in pairs(state.removedItems) do if entry.item == c then isStored = true break end end
                            if not isStored and UI.temporaryStorage then
                                table.insert(state.removedItems, {item = c, parent = c.Parent})
                                c.Parent = UI.temporaryStorage
                            end
                        end
                    end
                    
                    obj.Anchored = false
                    obj.CanCollide = false
                    table.insert(state.parts, obj)
                    scanned = scanned + 1
                end)
            end
        end
    end
    log("Menscan "..#state.parts.." part dalam radius "..config.radius)
    return state.parts
end

local function force(part, targetPos)
    if not part or not part.Parent then return end
    pcall(function()
        part.Anchored = false
        part.CanCollide = false
        for _, child in pairs(part:GetChildren()) do if child:IsA("BodyPosition") or child:IsA("BodyVelocity") or child:IsA("BodyGyro") then child:Destroy() end end
        local bp = Instance.new("BodyPosition")
        bp.MaxForce = Vector3.new(config.magnetForce, config.magnetForce, config.magnetForce)
        bp.Position = targetPos; bp.P = 10000; bp.D = 500; bp.Parent = part
        table.insert(state.bodyPositions, bp)
    end)
end

local modes = {}
modes.bring = function() local p=getPos() if not p then return end for i,pt in pairs(state.parts) do if pt and pt.Parent then local o=Vector3.new(math.random(-15,15),math.random(10,30),math.random(-15,15)) force(pt,p+o) end end end
modes.ring = function() local p=getPos() if not p then return end local t=tick()*config.speed*0.5 for i,pt in pairs(state.parts) do if pt and pt.Parent then local a=((i/#state.parts)*math.pi*2)+t local r=8 local o=Vector3.new(math.cos(a)*r,5,math.sin(a)*r) force(pt,p+o) end end end
modes.tornado = function() local p=getPos() if not p then return end local t=tick()*config.speed for i,pt in pairs(state.parts) do if pt and pt.Parent then local h=((i-1)%10)*4 local r=5+(h/8) local a=t+(i*0.5) local o=Vector3.new(math.cos(a)*r,h,math.sin(a)*r) force(pt,p+o) end end end
modes.blackhole = function() local p=getPos() if not p then return end local c=p+Vector3.new(0,10,0) local t=tick()*config.speed for i,pt in pairs(state.parts) do if pt and pt.Parent then local a=(i*0.5)+(t*0.3) local r=3 local o=Vector3.new(math.cos(a)*r,math.sin(t+i*0.2)*2,math.sin(a)*r) force(pt,c+o) end end end
modes.orbit = function() local p=getPos() if not p then return end local c=p+Vector3.new(0,8,0) local t=tick()*config.speed*0.3 for i,pt in pairs(state.parts) do if pt and pt.Parent then local r=10+((i%3)*3) local a=t+(i*0.8) local o=Vector3.new(math.cos(a)*r,math.sin(a*0.5)*4,math.sin(a)*r) force(pt,c+o) end end end
modes.spiral = function() local p=getPos() if not p then return end local t=tick()*config.speed*0.5 for i,pt in pairs(state.parts) do if pt and pt.Parent then local h=p.Y+(i*1)+(t%15) local a=(i*0.5)+t local r=8 force(pt,Vector3.new(p.X+math.cos(a)*r,h,p.Z+math.sin(a)*r)) end end end
modes.wave = function() local p=getPos() if not p then return end local t=tick()*config.speed for i,pt in pairs(state.parts) do if pt and pt.Parent then local h=p.Y+8+math.sin(t+i*0.5)*5 force(pt,Vector3.new(p.X+((i%10)*3)-15,h,p.Z+math.cos(t+i*0.3)*5)) end end end
modes.fountain = function() local p=getPos() if not p then return end local t=tick()*config.speed for i,pt in pairs(state.parts) do if pt and pt.Parent then local a=(i/#state.parts)*math.pi*2 local h=p.Y+3+math.abs(math.sin(t+i*0.5))*12 local r=4 force(pt,Vector3.new(p.X+math.cos(a)*r,h,p.Z+math.sin(a)*r)) end end end
modes.shield = function() local p=getPos() if not p then return end local t=tick()*config.speed for i,pt in pairs(state.parts) do if pt and pt.Parent then local a=((i/#state.parts)*math.pi*2)+t local r=8 force(pt,Vector3.new(p.X+math.cos(a)*r,p.Y+2,p.Z+math.sin(a)*r)) end end end
modes.sphere = function() local p=getPos() if not p then return end local c=p+Vector3.new(0,10,0) for i,pt in pairs(state.parts) do if pt and pt.Parent then local phi=math.acos(-1+(2*i)/#state.parts) local theta=math.sqrt(#state.parts*math.pi)*phi local r=10 local o=Vector3.new(r*math.cos(theta)*math.sin(phi),r*math.cos(phi),r*math.sin(theta)*math.sin(phi)) force(pt,c+o) end end end
modes.launch = function() local p=getPos() if not p then return end local l=getLook() for i=1,math.min(5,#state.parts) do local idx=((state.timeOffset+i-1)%#state.parts)+1 local pt=state.parts[idx] if pt and pt.Parent then pcall(function() pt:BreakJoints() for _,c in pairs(pt:GetChildren()) do if c:IsA("BodyVelocity") then c:Destroy() end end local bv=Instance.new("BodyVelocity") bv.MaxForce=Vector3.new(math.huge,math.huge,math.huge) bv.Velocity=l*config.launchSpeed+Vector3.new(math.random(-10,10),math.random(0,20),math.random(-10,10)) bv.Parent=pt task.delay(2,function() if bv and bv.Parent then bv:Destroy() end end) end) end end end
modes.explosion=modes.launch; modes.galaxy=modes.ring; modes.dna=modes.spiral; modes.supernova=modes.blackhole; modes.matrix=modes.bring; modes.vortex=modes.tornado; modes.meteor=modes.launch; modes.portal=modes.ring; modes.dragon=modes.spiral; modes.infinity=modes.wave; modes.tsunami=modes.wave; modes.solar=modes.orbit; modes.quantum=modes.bring

local function startPartController()
    if state.active then return end
    if #state.parts == 0 then scan() end
    if #state.parts == 0 then log("Tidak bisa mulai - tidak ada part ditemukan!"); return end
    
    state.active = true
    state.timeOffset = 0
    log("Dimulai: "..state.mode.." dengan "..#state.parts.." part")
    state.connection = RunService.Heartbeat:Connect(function()
        if not state.active then return end
        state.timeOffset = (state.timeOffset + config.batchSize) % #state.parts
        local fn = modes[state.mode]
        if fn then pcall(fn) end
    end)
    updatePlayStopButtonVisuals()
end

local function stopPartController()
    if state.connection then state.connection:Disconnect(); state.connection=nil end
    state.active = false
    cleanBodyPositions()
    log("Berhenti!")
    updatePlayStopButtonVisuals()
end

-- ====================================================================
-- == FUNGSI BARU: PENGEMBALIAN TOTAL SAAT DITUTUP                   ==
-- ====================================================================
local function fullRestore()
    log("Memulai proses pengembalian total...")
    stopPartController()

    log("Mengembalikan "..#state.removedItems.." tali/sambungan...")
    for _, entry in pairs(state.removedItems) do
        if entry.item and entry.parent and entry.parent.Parent then
            pcall(function() entry.item.Parent = entry.parent end)
        end
    end

    log("Mengembalikan properti fisika untuk part...")
    for part, properties in pairs(state.originalProperties) do
        if part and part.Parent then
            pcall(function()
                part.Anchored = properties.Anchored
                part.CanCollide = properties.CanCollide
            end)
        end
    end

    log("Membersihkan state skrip...")
    state.parts = {}
    state.originalProperties = {}
    state.removedItems = {}
    if UI.statusLabel then UI.statusLabel.Text = "Parts: 0" end
    log("Pengembalian total selesai. Skrip telah di-reset sepenuhnya.")
end

-- ====================================================================
-- == INISIALISASI GUI                                             ==
-- ====================================================================
local function createGUI()
    if CoreGui:FindFirstChild("ArexansPartControllerGUI") then CoreGui:FindFirstChild("ArexansPartControllerGUI"):Destroy() end
    local ScreenGui = Instance.new("ScreenGui", CoreGui); ScreenGui.Name = "ArexansPartControllerGUI"; ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; ScreenGui.ResetOnSpawn = false
    
    -- DITAMBAHKAN: Folder untuk menyimpan item yang "dihapus"
    UI.temporaryStorage = Instance.new("Folder", ScreenGui); UI.temporaryStorage.Name = "TemporaryStorage"

    local MainFrame = Instance.new("Frame", ScreenGui)
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 180, 0, 95)
    MainFrame.Position = UDim2.new(0.5, -90, 0.5, -47)
    MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    MainFrame.BackgroundTransparency = 0.5
    local MainUICorner = Instance.new("UICorner", MainFrame); MainUICorner.CornerRadius = UDim.new(0, 8)
    local UIStroke = Instance.new("UIStroke", MainFrame); UIStroke.Color = Color3.fromRGB(0, 150, 255); UIStroke.Thickness = 1.5

    local TitleBar = Instance.new("TextButton", MainFrame)
    TitleBar.Name = "TitleBar"; TitleBar.Size = UDim2.new(1, 0, 0, 25)
    TitleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25); TitleBar.Text = ""
    local TitleBarCorner = Instance.new("UICorner", TitleBar); TitleBarCorner.CornerRadius = UDim.new(0, 8)
    TitleBar.AutoButtonColor = false

    local TitleLabel = Instance.new("TextLabel", TitleBar)
    TitleLabel.Size = UDim2.new(0.4, 0, 1, 0); TitleLabel.Position = UDim2.new(0, 8, 0, 0)
    TitleLabel.BackgroundTransparency = 1; TitleLabel.Text = "P-Controller"
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

    local function makeDraggable(guiObject, dragHandle)
        local dragInput, dragStart, startPos
        dragHandle.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragInput, dragStart, startPos = input, input.Position, guiObject.Position end end)
        dragHandle.InputChanged:Connect(function(input) if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and dragInput then local delta = input.Position - dragStart; guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)
        dragHandle.InputEnded:Connect(function(input) if input == dragInput then dragInput = nil end end)
    end
    makeDraggable(MainFrame, TitleBar)

    local ContentFrame = Instance.new("Frame", MainFrame)
    ContentFrame.Name = "ContentFrame"; ContentFrame.ClipsDescendants = true
    ContentFrame.Size = UDim2.new(1, -10, 1, -30)
    ContentFrame.Position = UDim2.new(0, 5, 0, 25)
    ContentFrame.BackgroundTransparency = 1
    local ContentLayout = Instance.new("UIListLayout", ContentFrame); ContentLayout.Padding = UDim.new(0, 4)

    local function createIconButton(parent, text, size, callback)
        local btn = Instance.new("TextButton", parent); btn.Size = UDim2.new(0, size, 0, 24); btn.Text = text
        btn.Font = Enum.Font.SourceSansBold; btn.TextSize = 16; btn.TextColor3 = Color3.new(1, 1, 1)
        local corner = Instance.new("UICorner", btn); corner.CornerRadius = UDim.new(0, 5)
        if callback then btn.MouseButton1Click:Connect(callback) end
        return btn
    end
    
    local function createCompactTextBox(parent, name, defaultValue, callback)
        local frame = Instance.new("Frame", parent); frame.BackgroundTransparency = 1; frame.Size = UDim2.new(0, 48, 0, 24)
        local label = Instance.new("TextLabel", frame); label.Size = UDim2.new(1, 0, 0, 12); label.BackgroundTransparency = 1; label.Font = Enum.Font.SourceSans
        label.Text = name; label.TextColor3 = Color3.fromRGB(200, 200, 200); label.TextSize = 10; label.TextXAlignment = Enum.TextXAlignment.Center
        local textBox = Instance.new("TextBox", frame); textBox.Size = UDim2.new(1, 0, 1, -12); textBox.Position = UDim2.new(0, 0, 0, 12)
        textBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35); textBox.TextColor3 = Color3.fromRGB(220, 220, 220); textBox.Text = tostring(defaultValue); textBox.Font = Enum.Font.SourceSans; textBox.TextSize = 11
        textBox.TextXAlignment = Enum.TextXAlignment.Center; textBox.ClearTextOnFocus = false
        local corner = Instance.new("UICorner", textBox); corner.CornerRadius = UDim.new(0, 4)
        textBox.FocusLost:Connect(function(enterPressed) local num = tonumber(textBox.Text) if num and callback then callback(num) else textBox.Text = tostring(defaultValue) end end)
        return frame, textBox 
    end

    local controlsRow = Instance.new("Frame", ContentFrame)
    controlsRow.BackgroundTransparency = 1; controlsRow.Size = UDim2.new(1, 0, 0, 28)
    local radiusFrame, radiusBox = createCompactTextBox(controlsRow, "Radius", config.radius, function(v) config.radius = v end); radiusFrame.Position = UDim2.new(0, 0, 0.5, -12)
    local speedFrame, speedBox = createCompactTextBox(controlsRow, "Speed", config.speed, function(v) config.speed = v; config.launchSpeed = v * 20 end); speedFrame.Position = UDim2.new(0, 52, 0.5, -12)
    
    local destroyBtn = createIconButton(controlsRow, "🚯", 30, function()
        destroyBtn.Text = "..."
        task.spawn(function()
            local n = clearAndStoreConstraints(); destroyBtn.Text = "🚯"; UI.statusLabel.Text = "Stored "..n; UI.statusLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
            task.wait(2); UI.statusLabel.Text = "Parts: "..#state.parts; UI.statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        end)
    end)
    destroyBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40); destroyBtn.Position = UDim2.new(0, 104, 0.5, -12) 
    
    local isScanning = false
    local scanButton = createIconButton(controlsRow, "🔍", 30, function()
        if isScanning then return end; isScanning = true; UI.statusLabel.Text = "Scanning..."; UI.statusLabel.TextColor3 = Color3.fromRGB(255, 180, 80)
        task.spawn(function()
            task.wait(); local foundParts = scan(); UI.statusLabel.Text = "Parts: " .. #foundParts; UI.statusLabel.TextColor3 = Color3.fromRGB(120, 255, 120); isScanning = false
        end)
    end)
    scanButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255); scanButton.Position = UDim2.new(0, 138, 0.5, -12)

    local modeRow = Instance.new("Frame", ContentFrame); modeRow.BackgroundTransparency = 1; modeRow.Size = UDim2.new(1, 0, 0, 28)
    local prevBtn = createIconButton(modeRow, "<", 25); prevBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60); prevBtn.Position = UDim2.new(0, 0, 0.5, -12)
    local modeLabel = Instance.new("TextLabel", modeRow); modeLabel.Size = UDim2.new(0, 70, 1, 0); modeLabel.Position = UDim2.new(0, 29, 0, 0)
    modeLabel.BackgroundTransparency = 1; modeLabel.Font = Enum.Font.SourceSansBold; modeLabel.TextSize = 10; modeLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    modeLabel.TextWrapped = true; modeLabel.TextXAlignment = Enum.TextXAlignment.Center
    local nextBtn = createIconButton(modeRow, ">", 25); nextBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60); nextBtn.Position = UDim2.new(0, 103, 0.5, -12)
    UI.toggleButton = createIconButton(modeRow, "▶️", 30); UI.toggleButton.Position = UDim2.new(0, 138, 0.5, -12)
    
    local function updateModeDisplay() local currentModeData = MODES[state.currentModeIndex]; state.mode = currentModeData.v; modeLabel.Text = currentModeData.n end
    prevBtn.MouseButton1Click:Connect(function() state.currentModeIndex = state.currentModeIndex - 1; if state.currentModeIndex < 1 then state.currentModeIndex = #MODES end; updateModeDisplay() end)
    nextBtn.MouseButton1Click:Connect(function() state.currentModeIndex = state.currentModeIndex + 1; if state.currentModeIndex > #MODES then state.currentModeIndex = 1 end; updateModeDisplay() end)
    updateModeDisplay()

    UI.toggleButton.MouseButton1Click:Connect(function() if state.active then stopPartController() else startPartController() end end)
    updatePlayStopButtonVisuals()
    
    -- **DIRUBAH**: Tombol close kini menjalankan pengembalian total.
    closeBtn.MouseButton1Click:Connect(function()
        fullRestore()
        ScreenGui:Destroy()
    end)
    
    local isMinimized = false; local originalSize = MainFrame.Size; local minimizedSize = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, TitleBar.Size.Y.Offset)
    minimizeBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized; ContentFrame.Visible = not isMinimized; local targetSize = isMinimized and minimizedSize or originalSize
        TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = targetSize}):Play()
    end)
    
    log("GUI Berhasil Dibuat!")
end

-- Hotkeys
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F1 then
        scan()
        if UI.statusLabel then UI.statusLabel.Text = "Parts: " .. #state.parts end
    elseif input.KeyCode == Enum.KeyCode.F2 then
        if state.active then stopPartController() else startPartController() end
    elseif input.KeyCode == Enum.KeyCode.F4 then
        clearAndStoreConstraints()
    elseif input.KeyCode == Enum.KeyCode.F5 then
        stopPartController()
    end
end)

-- Initialize
log("═══════════════════════════════════")
log("AREXANS PART CONTROLLER v6.6 (Perbaikan Total)")
log("═══════════════════════════════════")
log("✓ Mekanisme pengembalian total saat ditutup ditambahkan.")
log("✓ Tali & sambungan kini disimpan, bukan dihancurkan.")
log("✓ Semua mode partikel berfungsi normal.")
log("Loading GUI...")
task.wait(0.5)
createGUI()
log("═══════════════════════════════════")
log("✓ READY!")
log("Hotkeys:")
log("  F1 = Scan Parts")
log("  F2 = Toggle ON/OFF")
log("  F4 = Clear & Store Ropes")
log("  F5 = Force Stop")
log("═══════════════════════════════════")


