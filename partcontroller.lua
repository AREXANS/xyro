-- Arexans Part Controller v4.3 (Revisi Stabilitas & UX oleh Gemini)
-- Perbaikan: Fitur geser jendela yang tidak mengganggu kamera dan alur tombol scan yang lebih jelas.
print("Loading Arexans Part Controller v4.3...")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

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
    timeOffset = 0,
    connection = nil,
    bodyPositions = {}
}

-- Modes (Fungsi tetap sama)
local MODES = {
    {n="Bring",v="bring",i="⬆",c=Color3.fromRGB(100,150,200)},
    {n="Ring",v="ring",i="◯",c=Color3.fromRGB(150,100,200)},
    {n="Tornado",v="tornado",i="◐",c=Color3.fromRGB(100,200,150)},
    {n="Blackhole",v="blackhole",i="●",c=Color3.fromRGB(50,50,50)},
    {n="Orbit",v="orbit",i="◎",c=Color3.fromRGB(200,150,100)},
    {n="Spiral",v="spiral",i="◉",c=Color3.fromRGB(150,200,100)},
    {n="Wave",v="wave",i="≈",c=Color3.fromRGB(100,180,220)},
    {n="Fountain",v="fountain",i="⌇",c=Color3.fromRGB(120,200,230)},
    {n="Shield",v="shield",i="◈",c=Color3.fromRGB(200,180,100)},
    {n="Sphere",v="sphere",i="○",c=Color3.fromRGB(180,120,200)},
    {n="Launch",v="launch",i="▶",c=Color3.fromRGB(220,100,100)},
    {n="Explosion",v="explosion",i="✸",c=Color3.fromRGB(255,100,50)},
    {n="Galaxy",v="galaxy",i="✦",c=Color3.fromRGB(100,50,200)},
    {n="DNA",v="dna",i="⧈",c=Color3.fromRGB(50,200,100)},
    {n="Supernova",v="supernova",i="✹",c=Color3.fromRGB(255,200,50)},
    {n="Matrix",v="matrix",i="⋮",c=Color3.fromRGB(50,255,100)},
    {n="Vortex",v="vortex",i="◔",c=Color3.fromRGB(80,80,150)},
    {n="Meteor",v="meteor",i="✺",c=Color3.fromRGB(255,150,50)},
    {n="Portal",v="portal",i="◉",c=Color3.fromRGB(100,200,255)},
    {n="Dragon",v="dragon",i="⟁",c=Color3.fromRGB(200,50,50)},
    {n="Infinity",v="infinity",i="∞",c=Color3.fromRGB(150,150,255)},
    {n="Tsunami",v="tsunami",i="≋",c=Color3.fromRGB(50,150,255)},
    {n="Solar",v="solar",i="☉",c=Color3.fromRGB(255,200,100)},
    {n="Quantum",v="quantum",i="⊛",c=Color3.fromRGB(200,100,255)}
}

local function log(m) print("[AREXANS] "..m) end
local function getPos() return player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character.HumanoidRootPart.Position end
local function getLook() return player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character.HumanoidRootPart.CFrame.LookVector or Vector3.new(0,0,-1) end

-- Clean all BodyPositions
local function cleanBodyPositions()
    for _, bp in pairs(state.bodyPositions) do
        if bp and bp.Parent then
            bp:Destroy()
        end
    end
    state.bodyPositions = {}
end

-- Rope Destroyer
local function destroyRopes()
    log("Destroying all ropes...")
    local r,w,a = 0,0,0
    
    for _,obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("RopeConstraint") then
            pcall(function()
                obj.Visible=false 
                obj.Enabled=false 
                obj.Length=0
                local a0,a1 = obj.Attachment0,obj.Attachment1
                obj:Destroy() 
                r=r+1
                if a0 and a0.Parent then a0:Destroy() a=a+1 end
                if a1 and a1.Parent then a1:Destroy() a=a+1 end
            end)
        elseif obj:IsA("WeldConstraint") or obj:IsA("Weld") then
            pcall(function() obj:Destroy() w=w+1 end)
        elseif obj:IsA("Attachment") and not obj.Parent:FindFirstChildOfClass("Humanoid") then
            pcall(function() obj:Destroy() a=a+1 end)
        end
    end
    
    for _,obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and not obj:IsDescendantOf(player.Character) then 
            pcall(function() 
                obj:BreakJoints()
            end) 
        end
    end
    
    log("Destroyed: "..r.." ropes, "..w.." welds, "..a.." attachments")
    return r+w+a
end

-- Scan
local function scan()
    log("Starting new scan...")
    state.parts = {}
    cleanBodyPositions()
    
    local p = getPos()
    if not p then 
        log("Cannot scan - Player position not found")
        return {} 
    end
    
    local scanned = 0
    for _,obj in pairs(workspace:GetDescendants()) do
        if scanned >= config.partLimit then break end
        
        if obj:IsA("BasePart") and not(player.Character and obj:IsDescendantOf(player.Character)) then
            local dist = (obj.Position - p).Magnitude
            if dist <= config.radius then
                pcall(function()
                    obj:BreakJoints()
                    for _,c in pairs(obj:GetChildren()) do
                        if c:IsA("Constraint") or c:IsA("Attachment") or c:IsA("Weld") then 
                            c:Destroy() 
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
    
    log("Scanned "..#state.parts.." parts in radius "..config.radius)
    return state.parts
end

-- Apply force
local function force(part, targetPos)
    if not part or not part.Parent then return end
    
    pcall(function()
        part.Anchored = false
        part.CanCollide = false
        
        for _, child in pairs(part:GetChildren()) do
            if child:IsA("BodyPosition") or child:IsA("BodyVelocity") or child:IsA("BodyGyro") then
                child:Destroy()
            end
        end
        
        local bp = Instance.new("BodyPosition")
        bp.MaxForce = Vector3.new(config.magnetForce, config.magnetForce, config.magnetForce)
        bp.Position = targetPos
        bp.P = 10000
        bp.D = 500
        bp.Parent = part
        
        table.insert(state.bodyPositions, bp)
    end)
end

-- Mode executions
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

local function startPartController() if state.active then return end if #state.parts==0 then log("Cannot start - no parts to control") return end state.active=true state.timeOffset=0 log("Started: "..state.mode.." with "..#state.parts.." parts") state.connection=RunService.Heartbeat:Connect(function() if not state.active then return end state.timeOffset=state.timeOffset+config.batchSize if state.timeOffset>=#state.parts then state.timeOffset=0 end local fn=modes[state.mode] if fn then pcall(fn) end task.wait(config.updateRate) end) end
local function stopPartController() if state.connection then state.connection:Disconnect() state.connection=nil end state.active=false cleanBodyPositions() log("Stopped!") end

-- Create GUI
local function createGUI()
    local old = player.PlayerGui:FindFirstChild("ArexansPartControllerGUI")
    if old then old:Destroy() end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "ArexansPartControllerGUI"
    gui.ResetOnSpawn = false
    gui.Parent = player.PlayerGui
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 11

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0,180,0,290)
    frame.Position = UDim2.new(0.5,-90,0.5,-145)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BackgroundTransparency = 0.5
    frame.BorderSizePixel = 0
    frame.Parent = gui
    
    local frameCorner = Instance.new("UICorner",frame); frameCorner.CornerRadius = UDim.new(0,6)
    local frameStroke = Instance.new("UIStroke",frame); frameStroke.Color = Color3.fromRGB(0, 150, 255); frameStroke.Thickness = 1.5; frameStroke.Transparency = 0.5
    
    -- Bilah judul diubah menjadi TextButton untuk properti Modal, tapi tampilan tetap sama
    local titleBar = Instance.new("TextButton",frame) 
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1,0,0,25)
    titleBar.BackgroundColor3 = Color3.fromRGB(25,25,25)
    titleBar.BorderSizePixel = 0
    titleBar.Text = "" -- Kosongkan teks agar tidak mengganggu
    titleBar.AutoButtonColor = false -- Matikan efek klik visual
    
    local title = Instance.new("TextLabel",titleBar)
    title.Size = UDim2.new(1,-45,1,0)
    title.Position = UDim2.new(0,8,0,0)
    title.BackgroundTransparency = 1
    title.Text = "Part Controller"
    title.TextColor3 = Color3.fromRGB(0,200,255)
    title.TextSize = 12
    title.Font = Enum.Font.SourceSansBold
    title.TextXAlignment = Enum.TextXAlignment.Left

    local closeBtn = Instance.new("TextButton",titleBar)
    closeBtn.Size = UDim2.new(0,18,0,18)
    closeBtn.Position = UDim2.new(1,-22,0,3.5)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Font = Enum.Font.SourceSansBold
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 16

    local minimizeBtn = Instance.new("TextButton", titleBar)
    minimizeBtn.Size = UDim2.new(0, 18, 0, 18)
    minimizeBtn.Position = UDim2.new(1, -42, 0, 3.5)
    minimizeBtn.BackgroundTransparency = 1
    minimizeBtn.Font = Enum.Font.SourceSansBold
    minimizeBtn.Text = "-"
    minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minimizeBtn.TextSize = 20

    -- [[ FUNGSI GESER JENDELA BARU YANG TIDAK MENGGANGGU KAMERA ]] --
    local function makeDraggableAndSinkInput(frameToDrag, handle)
        handle.Modal = true -- Kunci utama: Menyerap input agar tidak tembus ke game
        local isDragging = false
        
        handle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                isDragging = true
                local startPosition = input.Position
                local frameStartPosition = frameToDrag.Position
                
                local moveConnection
                moveConnection = UserInputService.InputChanged:Connect(function(moveInput)
                    if (moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch) and isDragging then
                        local delta = moveInput.Position - startPosition
                        frameToDrag.Position = UDim2.new(frameStartPosition.X.Scale, frameStartPosition.X.Offset + delta.X, frameStartPosition.Y.Scale, frameStartPosition.Y.Offset + delta.Y)
                    end
                end)
                
                local endConnection
                endConnection = UserInputService.InputEnded:Connect(function(endInput)
                    if endInput.UserInputType == input.UserInputType then
                        isDragging = false
                        moveConnection:Disconnect()
                        endConnection:Disconnect()
                    end
                end)
            end
        end)
    end
    makeDraggableAndSinkInput(frame, titleBar)

    local contentScroll = Instance.new("ScrollingFrame",frame)
    contentScroll.Size = UDim2.new(1,-10,1,-30)
    contentScroll.Position = UDim2.new(0,5,0,25)
    contentScroll.BackgroundTransparency = 1
    contentScroll.BorderSizePixel = 0
    contentScroll.ScrollBarThickness = 3
    contentScroll.ScrollBarImageColor3 = Color3.fromRGB(0, 150, 255)

    local contentLayout = Instance.new("UIListLayout", contentScroll)
    contentLayout.Padding = UDim.new(0, 4)

    local function createButton(parent, name, callback)
        local button = Instance.new("TextButton"); button.Size = UDim2.new(1,0,0,20); button.BackgroundColor3 = Color3.fromRGB(0,120,255); button.BorderSizePixel = 0; button.Text = name; button.TextColor3 = Color3.fromRGB(255,255,255); button.TextSize = 11; button.Font = Enum.Font.SourceSansBold; button.Parent = parent; local c = Instance.new("UICorner",button); c.CornerRadius = UDim.new(0,4); button.MouseButton1Click:Connect(callback); return button
    end
    local function createToggle(parent, name, initialState, callback)
        local f=Instance.new("Frame",parent);f.Size=UDim2.new(1,0,0,22);f.BackgroundTransparency=1;local l=Instance.new("TextLabel",f);l.Size=UDim2.new(0.8,-10,1,0);l.Position=UDim2.new(0,5,0,0);l.BackgroundTransparency=1;l.Text=name;l.TextColor3=Color3.fromRGB(255,255,255);l.TextSize=11;l.TextXAlignment=Enum.TextXAlignment.Left;l.Font=Enum.Font.SourceSans;local s=Instance.new("TextButton",f);s.Name="Switch";s.Size=UDim2.new(0,36,0,18);s.Position=UDim2.new(1,-45,0.5,-9);s.BackgroundColor3=Color3.fromRGB(50,50,50);s.BorderSizePixel=0;s.Text="";local sc=Instance.new("UICorner",s);sc.CornerRadius=UDim.new(1,0);local t=Instance.new("Frame",s);t.Name="Thumb";t.Size=UDim2.new(0,14,0,14);t.Position=UDim2.new(0,2,0.5,-7);t.BackgroundColor3=Color3.fromRGB(220,220,220);t.BorderSizePixel=0;local tc=Instance.new("UICorner",t);tc.CornerRadius=UDim.new(1,0);local onC,offC=Color3.fromRGB(0,150,255),Color3.fromRGB(60,60,60);local onP,offP=UDim2.new(1,-16,0.5,-7),UDim2.new(0,2,0.5,-7);local ti=TweenInfo.new(0.2,Enum.EasingStyle.Quint,Enum.EasingDirection.Out);local tog=initialState;local function update(i) local gp,gc=tog and onP or offP,tog and onC or offC;if i then t.Position,s.BackgroundColor3=gp,gc else TweenService:Create(t,ti,{Position=gp}):Play();TweenService:Create(s,ti,{BackgroundColor3=gc}):Play() end end;s.MouseButton1Click:Connect(function() tog=not tog;update(false);callback(tog) end);update(true);return f,s
    end
    local function createTextBox(parent, name, initialValue, callback)
        local f = Instance.new("Frame", parent); f.Size = UDim2.new(1, 0, 0, 22); f.BackgroundTransparency = 1
        local l = Instance.new("TextLabel", f); l.Size = UDim2.new(0.5, -5, 1, 0); l.Position = UDim2.new(0, 5, 0, 0); l.BackgroundTransparency = 1; l.Text = name; l.TextColor3 = Color3.fromRGB(220, 220, 220); l.TextSize = 11; l.Font = Enum.Font.SourceSans; l.TextXAlignment = Enum.TextXAlignment.Left
        local tb = Instance.new("TextBox", f); tb.Size = UDim2.new(0.5, -5, 1, 0); tb.Position = UDim2.new(0.5, 0, 0, 0); tb.BackgroundColor3 = Color3.fromRGB(35, 35, 35); tb.BorderSizePixel = 0; tb.TextColor3 = Color3.fromRGB(255, 255, 255); tb.TextSize = 11; tb.Font = Enum.Font.SourceSans; tb.Text = tostring(initialValue); tb.ClearTextOnFocus = false
        local c = Instance.new("UICorner", tb); c.CornerRadius = UDim.new(0, 4)
        local s = Instance.new("UIStroke", tb); s.Color = Color3.fromRGB(80, 80, 80); s.Thickness = 1
        tb.FocusLost:Connect(function(enterPressed)
            local num = tonumber(tb.Text)
            if num then
                callback(num)
            else
                tb.Text = tostring(initialValue)
            end
        end)
        return f
    end

    local statusLabel = Instance.new("TextLabel", contentScroll)
    statusLabel.Size = UDim2.new(1,0,0,15)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Parts: 0"
    statusLabel.TextColor3 = Color3.fromRGB(180,180,180)
    statusLabel.TextSize = 10
    statusLabel.Font = Enum.Font.SourceSans
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	
    -- [[ LOGIKA TOMBOL SCAN BARU ]] --
    local isScanning = false
    local scanBtn = createButton(contentScroll, "Scan Parts", function()
        if isScanning then return end
        isScanning = true
        
        statusLabel.Text = "Scanning..."
        statusLabel.TextColor3 = Color3.fromRGB(255, 180, 80) -- Warna oranye saat loading
    
        task.spawn(function()
            task.wait() -- Tunggu frame berikutnya agar UI sempat update
            local foundParts = scan()
            
            statusLabel.Text = "Found: " .. #foundParts .. " parts"
            statusLabel.TextColor3 = Color3.fromRGB(120, 255, 120) -- Warna hijau tanda sukses
            
            isScanning = false
        end)
    end)
    
    local destroyBtn = createButton(contentScroll, "Destroy All Ropes", function()
        destroyBtn.Text = "Destroying..."
        task.spawn(function()
            local n = destroyRopes()
            destroyBtn.Text = "Destroyed "..n
            task.wait(2)
            destroyBtn.Text = "Destroy All Ropes"
        end)
    end)
    destroyBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)

    createTextBox(contentScroll, "Scan Radius", config.radius, function(v) config.radius = v end)
    createTextBox(contentScroll, "Anim Speed", config.speed, function(v) config.speed = v; config.launchSpeed = v * 20 end)

    local modeDropdownFrame = Instance.new("Frame", contentScroll)
    modeDropdownFrame.Size = UDim2.new(1,0,0,20)
    modeDropdownFrame.BackgroundTransparency = 1
    
    local modeBtn = createButton(modeDropdownFrame, "Mode: Bring", function() end)
    
    local modeScroll = Instance.new("ScrollingFrame", contentScroll)
    modeScroll.Size = UDim2.new(1,0,0,100)
    modeScroll.BackgroundTransparency = 1
    modeScroll.Visible = false
    modeScroll.BorderSizePixel = 0
    modeScroll.BackgroundColor3 = Color3.fromRGB(35,35,35)
    modeScroll.ScrollBarThickness = 3
    local modeScrollCorner = Instance.new("UICorner",modeScroll); modeScrollCorner.CornerRadius = UDim.new(0,5)
    local modeListLayout = Instance.new("UIListLayout", modeScroll)
    modeListLayout.Padding = UDim.new(0,2)

    modeBtn.MouseButton1Click:Connect(function() modeScroll.Visible = not modeScroll.Visible end)

    for _,m in ipairs(MODES) do
        local opt = createButton(modeScroll, m.n, function()
            state.mode = m.v
            modeBtn.Text = "Mode: "..m.n
            modeScroll.Visible = false
        end)
        opt.BackgroundColor3 = Color3.fromRGB(40,40,60)
    end
    
    local toggleFrame, toggleSwitch = createToggle(contentScroll, "Controller Active", state.active, function(isOn)
        if isOn then
            if #state.parts == 0 then
                log("No parts scanned, scanning now..."); scan(); statusLabel.Text = "Found: " .. #state.parts .. " parts"
            end
            if #state.parts > 0 then startPartController() else log("Cannot start - no parts found!") end
        else
            stopPartController()
        end
    end)
    
    contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        contentScroll.CanvasSize = UDim2.new(0,0,0, contentLayout.AbsoluteContentSize.Y)
    end)
    
    closeBtn.MouseButton1Click:Connect(function() 
        if state.active then stopPartController() end
        gui:Destroy() 
    end)

    local isMinimized = false
    local originalFrameSize = frame.Size
    local minimizedFrameSize = UDim2.new(0, 180, 0, 25)
    minimizeBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        
        if isMinimized then
            contentScroll.Visible = false
            TweenService:Create(frame, tweenInfo, {Size = minimizedFrameSize}):Play()
        else
            contentScroll.Visible = true
            TweenService:Create(frame, tweenInfo, {Size = originalFrameSize}):Play()
        end
    end)
    
    log("GUI Created Successfully!")
    return gui
end

-- Hotkeys
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F1 then log("F1 pressed - Scanning...") scan() local g = player.PlayerGui:FindFirstChild("ArexansPartControllerGUI") if g then local s = g:FindFirstChild("StatusLabel",true) if s then s.Text = "Parts: "..#state.parts end end
    elseif input.KeyCode == Enum.KeyCode.F2 then if state.active then stopPartController() else startPartController() end
    elseif input.KeyCode == enum.KeyCode.F4 then log("F4 pressed - Destroying ropes...") destroyRopes()
    elseif input.KeyCode == Enum.KeyCode.F5 then stopPartController()
    end
end)

-- Initialize
log("═══════════════════════════════════")
log("AREXANS PART CONTROLLER v4.3 (UX Fix)")
log("═══════════════════════════════════")
log("✓ Fitur geser jendela stabil & tidak mengganggu kamera.")
log("✓ Alur tombol scan disempurnakan.")
log("Loading GUI...")
task.wait(1)
createGUI()
log("═══════════════════════════════════")
log("✓ READY!")
log("Hotkeys:")
log("  F1 = Scan Parts")
log("  F2 = Toggle ON/OFF")
log("  F4 = Destroy Ropes")
log("  F5 = Force Stop")
log("═══════════════════════════════════")


