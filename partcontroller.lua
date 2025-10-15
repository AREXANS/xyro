-- Warpah Part Controller v4.0 ENHANCED UI
print("Loading Warpah Controller...")

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

-- Modes
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

local function log(m) print("[WARPAH] "..m) end
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

-- Rope Destroyer (dapat dipanggil berkali-kali)
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

-- Scan (dapat dipanggil berkali-kali)
local function scan()
    log("Starting new scan...")
    
    -- Bersihkan parts lama
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
                    -- Break joints dan hapus constraints
                    obj:BreakJoints()
                    for _,c in pairs(obj:GetChildren()) do
                        if c:IsA("RopeConstraint") or c:IsA("Constraint") or c:IsA("Attachment") or c:IsA("Weld") then 
                            c:Destroy() 
                        end
                    end
                    
                    -- Set properties
                    obj.Anchored = false
                    obj.CanCollide = false
                    
                    -- Tambahkan ke list
                    table.insert(state.parts, obj)
                    scanned = scanned + 1
                end)
            end
        end
    end
    
    log("Scanned "..#state.parts.." parts in radius "..config.radius)
    return state.parts
end

-- Apply force dengan sistem yang diperbaiki
local function force(part, targetPos)
    if not part or not part.Parent then return end
    
    pcall(function()
        -- Pastikan part tidak anchored
        part.Anchored = false
        part.CanCollide = false
        
        -- Hapus BodyPosition lama jika ada
        for _, child in pairs(part:GetChildren()) do
            if child:IsA("BodyPosition") or child:IsA("BodyVelocity") or child:IsA("BodyGyro") then
                child:Destroy()
            end
        end
        
        -- Buat BodyPosition baru
        local bp = Instance.new("BodyPosition")
        bp.MaxForce = Vector3.new(config.magnetForce, config.magnetForce, config.magnetForce)
        bp.Position = targetPos
        bp.P = 10000
        bp.D = 500
        bp.Parent = part
        
        -- Simpan referensi
        table.insert(state.bodyPositions, bp)
    end)
end

-- Mode executions (diperbaiki)
local modes = {}

modes.bring = function() 
    local p = getPos() 
    if not p then return end
    
    for i, pt in pairs(state.parts) do
        if pt and pt.Parent then
            local offset = Vector3.new(
                math.random(-15, 15),
                math.random(10, 30),
                math.random(-15, 15)
            )
            force(pt, p + offset)
        end
    end
end

modes.ring = function() 
    local p = getPos() 
    if not p then return end
    local t = tick() * config.speed * 0.5
    
    for i, pt in pairs(state.parts) do
        if pt and pt.Parent then
            local angle = ((i / #state.parts) * math.pi * 2) + t
            local radius = 8
            local offset = Vector3.new(
                math.cos(angle) * radius,
                5,
                math.sin(angle) * radius
            )
            force(pt, p + offset)
        end
    end
end

modes.tornado = function() 
    local p = getPos() 
    if not p then return end
    local t = tick() * config.speed
    
    for i, pt in pairs(state.parts) do
        if pt and pt.Parent then
            local height = ((i - 1) % 10) * 4
            local radius = 5 + (height / 8)
            local angle = t + (i * 0.5)
            
            local offset = Vector3.new(
                math.cos(angle) * radius,
                height,
                math.sin(angle) * radius
            )
            force(pt, p + offset)
        end
    end
end

modes.blackhole = function() 
    local p = getPos() 
    if not p then return end
    local center = p + Vector3.new(0, 10, 0)
    local t = tick() * config.speed
    
    for i, pt in pairs(state.parts) do
        if pt and pt.Parent then
            local angle = (i * 0.5) + (t * 0.3)
            local radius = 3
            
            local offset = Vector3.new(
                math.cos(angle) * radius,
                math.sin(t + i * 0.2) * 2,
                math.sin(angle) * radius
            )
            force(pt, center + offset)
        end
    end
end

modes.orbit = function() 
    local p = getPos() 
    if not p then return end
    local center = p + Vector3.new(0, 8, 0)
    local t = tick() * config.speed * 0.3
    
    for i, pt in pairs(state.parts) do
        if pt and pt.Parent then
            local radius = 10 + ((i % 3) * 3)
            local angle = t + (i * 0.8)
            
            local offset = Vector3.new(
                math.cos(angle) * radius,
                math.sin(angle * 0.5) * 4,
                math.sin(angle) * radius
            )
            force(pt, center + offset)
        end
    end
end

modes.spiral = function() 
    local p = getPos() 
    if not p then return end
    local t = tick() * config.speed * 0.5
    
    for i, pt in pairs(state.parts) do
        if pt and pt.Parent then
            local height = p.Y + (i * 1) + (t % 15)
            local angle = (i * 0.5) + t
            local radius = 8
            
            force(pt, Vector3.new(
                p.X + math.cos(angle) * radius,
                height,
                p.Z + math.sin(angle) * radius
            ))
        end
    end
end

modes.wave = function() 
    local p = getPos() 
    if not p then return end
    local t = tick() * config.speed
    
    for i, pt in pairs(state.parts) do
        if pt and pt.Parent then
            local height = p.Y + 8 + math.sin(t + i * 0.5) * 5
            
            force(pt, Vector3.new(
                p.X + ((i % 10) * 3) - 15,
                height,
                p.Z + math.cos(t + i * 0.3) * 5
            ))
        end
    end
end

modes.fountain = function() 
    local p = getPos() 
    if not p then return end
    local t = tick() * config.speed
    
    for i, pt in pairs(state.parts) do
        if pt and pt.Parent then
            local angle = (i / #state.parts) * math.pi * 2
            local height = p.Y + 3 + math.abs(math.sin(t + i * 0.5)) * 12
            local radius = 4
            
            force(pt, Vector3.new(
                p.X + math.cos(angle) * radius,
                height,
                p.Z + math.sin(angle) * radius
            ))
        end
    end
end

modes.shield = function() 
    local p = getPos() 
    if not p then return end
    local t = tick() * config.speed
    
    for i, pt in pairs(state.parts) do
        if pt and pt.Parent then
            local angle = ((i / #state.parts) * math.pi * 2) + t
            local radius = 8
            
            force(pt, Vector3.new(
                p.X + math.cos(angle) * radius,
                p.Y + 2,
                p.Z + math.sin(angle) * radius
            ))
        end
    end
end

modes.sphere = function() 
    local p = getPos() 
    if not p then return end
    local center = p + Vector3.new(0, 10, 0)
    
    for i, pt in pairs(state.parts) do
        if pt and pt.Parent then
            local phi = math.acos(-1 + (2 * i) / #state.parts)
            local theta = math.sqrt(#state.parts * math.pi) * phi
            local radius = 10
            
            local offset = Vector3.new(
                radius * math.cos(theta) * math.sin(phi),
                radius * math.cos(phi),
                radius * math.sin(theta) * math.sin(phi)
            )
            force(pt, center + offset)
        end
    end
end

modes.launch = function() 
    local p = getPos() 
    if not p then return end
    local look = getLook()
    
    for i = 1, math.min(5, #state.parts) do
        local idx = ((state.timeOffset + i - 1) % #state.parts) + 1
        local pt = state.parts[idx]
        
        if pt and pt.Parent then
            pcall(function()
                pt:BreakJoints()
                
                for _, child in pairs(pt:GetChildren()) do
                    if child:IsA("BodyVelocity") then
                        child:Destroy()
                    end
                end
                
                local bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.Velocity = look * config.launchSpeed + Vector3.new(
                    math.random(-10, 10),
                    math.random(0, 20),
                    math.random(-10, 10)
                )
                bv.Parent = pt
                
                task.delay(2, function()
                    if bv and bv.Parent then
                        bv:Destroy()
                    end
                end)
            end)
        end
    end
end

-- Mode aliases
modes.explosion = modes.launch
modes.galaxy = modes.ring
modes.dna = modes.spiral
modes.supernova = modes.blackhole
modes.matrix = modes.bring
modes.vortex = modes.tornado
modes.meteor = modes.launch
modes.portal = modes.ring
modes.dragon = modes.spiral
modes.infinity = modes.wave
modes.tsunami = modes.wave
modes.solar = modes.orbit
modes.quantum = modes.bring

-- Create GUI
local function createGUI()
    local old = player.PlayerGui:FindFirstChild("WarpahGUI")
    if old then old:Destroy() end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "WarpahGUI"
    gui.ResetOnSpawn = false
    gui.Parent = player.PlayerGui
    
    -- Main Frame dengan Glassmorphism effect
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0,420,0,480)
    frame.Position = UDim2.new(0.5,-210,0.5,-240)
    frame.BackgroundColor3 = Color3.fromRGB(15,15,20)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui
    
    local frameCorner = Instance.new("UICorner",frame)
    frameCorner.CornerRadius = UDim.new(0,16)
    
    local frameStroke = Instance.new("UIStroke",frame)
    frameStroke.Color = Color3.fromRGB(80,80,100)
    frameStroke.Thickness = 1.5
    frameStroke.Transparency = 0.5
    
    -- Gradient overlay untuk depth
    local gradient = Instance.new("UIGradient",frame)
    gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(25,25,35)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15,15,20))
    }
    gradient.Rotation = 45
    
    -- Header dengan glow effect
    local header = Instance.new("Frame",frame)
    header.Size = UDim2.new(1,0,0,65)
    header.BackgroundColor3 = Color3.fromRGB(20,20,30)
    header.BackgroundTransparency = 0.3
    header.BorderSizePixel = 0
    
    local headerCorner = Instance.new("UICorner",header)
    headerCorner.CornerRadius = UDim.new(0,16)
    
    local headerStroke = Instance.new("UIStroke",header)
    headerStroke.Color = Color3.fromRGB(100,150,255)
    headerStroke.Thickness = 1
    headerStroke.Transparency = 0.7
    
    -- Title dengan icon
    local icon = Instance.new("TextLabel",header)
    icon.Size = UDim2.new(0,50,0,50)
    icon.Position = UDim2.new(0,12,0,8)
    icon.BackgroundColor3 = Color3.fromRGB(100,150,255)
    icon.BackgroundTransparency = 0.8
    icon.Text = "⚡"
    icon.TextColor3 = Color3.fromRGB(150,200,255)
    icon.TextSize = 28
    icon.Font = Enum.Font.GothamBold
    local iconCorner = Instance.new("UICorner",icon)
    iconCorner.CornerRadius = UDim.new(0,12)
    
    local title = Instance.new("TextLabel",header)
    title.Size = UDim2.new(1,-180,0,25)
    title.Position = UDim2.new(0,70,0,10)
    title.BackgroundTransparency = 1
    title.Text = "WARPAH CONTROLLER"
    title.TextColor3 = Color3.fromRGB(240,240,255)
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    local subtitle = Instance.new("TextLabel",header)
    subtitle.Size = UDim2.new(1,-180,0,20)
    subtitle.Position = UDim2.new(0,70,0,35)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Parts Controlled: 0"
    subtitle.TextColor3 = Color3.fromRGB(150,150,170)
    subtitle.TextSize = 12
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Control buttons dengan hover effect
    local function createHeaderButton(icon, position, color)
        local btn = Instance.new("TextButton",header)
        btn.Size = UDim2.new(0,36,0,36)
        btn.Position = position
        btn.BackgroundColor3 = color
        btn.BackgroundTransparency = 0.3
        btn.Text = icon
        btn.TextColor3 = Color3.fromRGB(255,255,255)
        btn.TextSize = 18
        btn.Font = Enum.Font.GothamBold
        btn.BorderSizePixel = 0
        
        local btnCorner = Instance.new("UICorner",btn)
        btnCorner.CornerRadius = UDim.new(0,10)
        
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn,TweenInfo.new(0.2,Enum.EasingStyle.Quad),{
                BackgroundTransparency=0,
                Size=UDim2.new(0,38,0,38)
            }):Play()
        end)
        
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn,TweenInfo.new(0.2,Enum.EasingStyle.Quad),{
                BackgroundTransparency=0.3,
                Size=UDim2.new(0,36,0,36)
            }):Play()
        end)
        
        return btn
    end
    
    local minBtn = createHeaderButton("−", UDim2.new(1,-90,0.5,-18), Color3.fromRGB(70,70,90))
    local closeBtn = createHeaderButton("×", UDim2.new(1,-48,0.5,-18), Color3.fromRGB(220,60,80))
    
    -- Content area
    local content = Instance.new("Frame",frame)
    content.Name = "Content"
    content.Size = UDim2.new(1,-30,1,-90)
    content.Position = UDim2.new(0,15,0,75)
    content.BackgroundTransparency = 1
    
    -- Settings Grid
    local settingsGrid = Instance.new("Frame",content)
    settingsGrid.Size = UDim2.new(1,0,0,75)
    settingsGrid.Position = UDim2.new(0,0,0,0)
    settingsGrid.BackgroundTransparency = 1
    
    local function createInputCard(title, defaultValue, position)
        local card = Instance.new("Frame",settingsGrid)
        card.Size = UDim2.new(0.48,0,1,0)
        card.Position = position
        card.BackgroundColor3 = Color3.fromRGB(25,25,35)
        card.BorderSizePixel = 0
        
        local cardCorner = Instance.new("UICorner",card)
        cardCorner.CornerRadius = UDim.new(0,12)
        
        local cardStroke = Instance.new("UIStroke",card)
        cardStroke.Color = Color3.fromRGB(60,60,80)
        cardStroke.Thickness = 1
        cardStroke.Transparency = 0.5
        
        local label = Instance.new("TextLabel",card)
        label.Size = UDim2.new(1,-20,0,22)
        label.Position = UDim2.new(0,10,0,8)
        label.BackgroundTransparency = 1
        label.Text = title
        label.TextColor3 = Color3.fromRGB(180,180,200)
        label.TextSize = 11
        label.Font = Enum.Font.GothamMedium
        label.TextXAlignment = Enum.TextXAlignment.Left
        
        local input = Instance.new("TextBox",card)
        input.Size = UDim2.new(1,-20,0,38)
        input.Position = UDim2.new(0,10,1,-46)
        input.BackgroundColor3 = Color3.fromRGB(35,35,50)
        input.BorderSizePixel = 0
        input.Text = defaultValue
        input.TextColor3 = Color3.fromRGB(220,220,240)
        input.TextSize = 16
        input.Font = Enum.Font.GothamBold
        input.ClearTextOnFocus = false
        
        local inputCorner = Instance.new("UICorner",input)
        inputCorner.CornerRadius = UDim.new(0,8)
        
        input.Focused:Connect(function()
            TweenService:Create(cardStroke,TweenInfo.new(0.2),{
                Color=Color3.fromRGB(100,150,255),
                Transparency=0.2
            }):Play()
        end)
        
        input.FocusLost:Connect(function()
            TweenService:Create(cardStroke,TweenInfo.new(0.2),{
                Color=Color3.fromRGB(60,60,80),
                Transparency=0.5
            }):Play()
        end)
        
        return input
    end
    
    local radiusInput = createInputCard("SCAN RADIUS", tostring(config.radius), UDim2.new(0,0,0,0))
    local speedInput = createInputCard("ANIMATION SPEED", tostring(config.speed), UDim2.new(0.52,0,0,0))
    
    -- Action buttons dengan modern design
    local function createActionButton(text, icon, position, bgColor, textColor)
        local btn = Instance.new("TextButton",content)
        btn.Size = UDim2.new(1,0,0,52)
        btn.Position = position
        btn.BackgroundColor3 = bgColor
        btn.BorderSizePixel = 0
        btn.Text = ""
        btn.AutoButtonColor = false
        
        local btnCorner = Instance.new("UICorner",btn)
        btnCorner.CornerRadius = UDim.new(0,12)
        
        local btnStroke = Instance.new("UIStroke",btn)
        btnStroke.Color = Color3.fromRGB(255,255,255)
        btnStroke.Thickness = 1.5
        btnStroke.Transparency = 0.9
        
        local iconLabel = Instance.new("TextLabel",btn)
        iconLabel.Size = UDim2.new(0,40,1,0)
        iconLabel.Position = UDim2.new(0,15,0,0)
        iconLabel.BackgroundTransparency = 1
        iconLabel.Text = icon
        iconLabel.TextColor3 = textColor
        iconLabel.TextSize = 22
        iconLabel.Font = Enum.Font.GothamBold
        
        local textLabel = Instance.new("TextLabel",btn)
        textLabel.Size = UDim2.new(1,-70,1,0)
        textLabel.Position = UDim2.new(0,55,0,0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = text
        textLabel.TextColor3 = textColor
        textLabel.TextSize = 14
        textLabel.Font = Enum.Font.GothamBold
        textLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn,TweenInfo.new(0.2),{
                BackgroundColor3=Color3.fromRGB(
                    math.min(255,bgColor.R*255+20),
                    math.min(255,bgColor.G*255+20),
                    math.min(255,bgColor.B*255+20)
                )
            }):Play()
            TweenService:Create(btnStroke,TweenInfo.new(0.2),{Transparency=0.7}):Play()
        end)
        
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn,TweenInfo.new(0.2),{BackgroundColor3=bgColor}):Play()
            TweenService:Create(btnStroke,TweenInfo.new(0.2),{Transparency=0.9}):Play()
        end)
        
        return btn, textLabel
    end
    
    local destroyBtn = createActionButton(
        "DESTROY ALL ROPES",
        "💥",
        UDim2.new(0,0,0,90),
        Color3.fromRGB(180,50,60),
        Color3.fromRGB(255,255,255)
    )
    
    local scanBtn, scanText = createActionButton(
        "SCAN PARTS",
        "🔍",
        UDim2.new(0,0,0,155),
        Color3.fromRGB(60,120,220),
        Color3.fromRGB(255,255,255)
    )
    
    -- Mode selector dengan enhanced design
    local modeBtn = Instance.new("TextButton",content)
    modeBtn.Size = UDim2.new(1,0,0,52)
    modeBtn.Position = UDim2.new(0,0,0,220)
    modeBtn.BackgroundColor3 = Color3.fromRGB(100,150,200)
    modeBtn.BorderSizePixel = 0
    modeBtn.Text = ""
    modeBtn.AutoButtonColor = false
    
    local modeBtnCorner = Instance.new("UICorner",modeBtn)
    modeBtnCorner.CornerRadius = UDim.new(0,12)
    
    local modeBtnStroke = Instance.new("UIStroke",modeBtn)
    modeBtnStroke.Color = Color3.fromRGB(255,255,255)
    modeBtnStroke.Thickness = 1.5
    modeBtnStroke.Transparency = 0.8
    
    local modeIcon = Instance.new("TextLabel",modeBtn)
    modeIcon.Size = UDim2.new(0,40,1,0)
    modeIcon.Position = UDim2.new(0,15,0,0)
    modeIcon.BackgroundTransparency = 1
    modeIcon.Text = "⬆"
    modeIcon.TextColor3 = Color3.fromRGB(255,255,255)
    modeIcon.TextSize = 20
    modeIcon.Font = Enum.Font.GothamBold
    
    local modeText = Instance.new("TextLabel",modeBtn)
    modeText.Size = UDim2.new(1,-110,1,0)
    modeText.Position = UDim2.new(0,55,0,0)
    modeText.BackgroundTransparency = 1
    modeText.Text = "MODE: BRING"
    modeText.TextColor3 = Color3.fromRGB(255,255,255)
    modeText.TextSize = 14
    modeText.Font = Enum.Font.GothamBold
    modeText.TextXAlignment = Enum.TextXAlignment.Left
    
    local modeArrow = Instance.new("TextLabel",modeBtn)
    modeArrow.Size = UDim2.new(0,30,1,0)
    modeArrow.Position = UDim2.new(1,-45,0,0)
    modeArrow.BackgroundTransparency = 1
    modeArrow.Text = "▼"
    modeArrow.TextColor3 = Color3.fromRGB(255,255,255)
    modeArrow.TextSize = 16
    modeArrow.Font = Enum.Font.GothamBold
    
    -- Mode dropdown dengan glassmorphism
    local modeScroll = Instance.new("ScrollingFrame",content)
    modeScroll.Size = UDim2.new(1,0,0,0)
    modeScroll.Position = UDim2.new(0,0,0,285)
    modeScroll.BackgroundColor3 = Color3.fromRGB(20,20,30)
    modeScroll.BackgroundTransparency = 0.1
    modeScroll.BorderSizePixel = 0
    modeScroll.Visible = false
    modeScroll.ScrollBarThickness = 4
    modeScroll.ScrollBarImageColor3 = Color3.fromRGB(100,150,255)
    modeScroll.CanvasSize = UDim2.new(0,0,0,#MODES*48)
    modeScroll.ClipsDescendants = true
    
    local modeScrollCorner = Instance.new("UICorner",modeScroll)
    modeScrollCorner.CornerRadius = UDim.new(0,12)
    
    local modeScrollStroke = Instance.new("UIStroke",modeScroll)
    modeScrollStroke.Color = Color3.fromRGB(100,150,255)
    modeScrollStroke.Thickness = 1.5
    modeScrollStroke.Transparency = 0.5
    
    for i,m in ipairs(MODES) do
        local opt = Instance.new("TextButton",modeScroll)
        opt.Size = UDim2.new(1,-16,0,44)
        opt.Position = UDim2.new(0,8,0,(i-1)*48+4)
        opt.BackgroundColor3 = Color3.fromRGB(30,30,45)
        opt.BackgroundTransparency = 0.3
        opt.BorderSizePixel = 0
        opt.Text = ""
        opt.AutoButtonColor = false
        
        local optCorner = Instance.new("UICorner",opt)
        optCorner.CornerRadius = UDim.new(0,10)
        
        local optStroke = Instance.new("UIStroke",opt)
        optStroke.Color = m.c
        optStroke.Thickness = 1
        optStroke.Transparency = 0.7
        
        local colorBar = Instance.new("Frame",opt)
        colorBar.Size = UDim2.new(0,5,1,-12)
        colorBar.Position = UDim2.new(0,6,0,6)
        colorBar.BackgroundColor3 = m.c
        colorBar.BorderSizePixel = 0
        local colorBarCorner = Instance.new("UICorner",colorBar)
        colorBarCorner.CornerRadius = UDim.new(1,0)
        
        local optIcon = Instance.new("TextLabel",opt)
        optIcon.Size = UDim2.new(0,35,1,0)
        optIcon.Position = UDim2.new(0,18,0,0)
        optIcon.BackgroundTransparency = 1
        optIcon.Text = m.i
        optIcon.TextColor3 = m.c
        optIcon.TextSize = 18
        optIcon.Font = Enum.Font.GothamBold
        
        local optText = Instance.new("TextLabel",opt)
        optText.Size = UDim2.new(1,-65,1,0)
        optText.Position = UDim2.new(0,53,0,0)
        optText.BackgroundTransparency = 1
        optText.Text = m.n
        optText.TextColor3 = Color3.fromRGB(220,220,240)
        optText.TextSize = 13
        optText.Font = Enum.Font.GothamMedium
        optText.TextXAlignment = Enum.TextXAlignment.Left
        
        opt.MouseEnter:Connect(function() 
            TweenService:Create(opt,TweenInfo.new(0.15),{
                BackgroundColor3=Color3.fromRGB(45,45,65),
                BackgroundTransparency=0
            }):Play()
            TweenService:Create(optStroke,TweenInfo.new(0.15),{Transparency=0.3}):Play()
        end)
        
        opt.MouseLeave:Connect(function() 
            TweenService:Create(opt,TweenInfo.new(0.15),{
                BackgroundColor3=Color3.fromRGB(30,30,45),
                BackgroundTransparency=0.3
            }):Play()
            TweenService:Create(optStroke,TweenInfo.new(0.15),{Transparency=0.7}):Play()
        end)
        
        opt.MouseButton1Click:Connect(function()
            state.mode = m.v
            modeIcon.Text = m.i
            modeText.Text = "MODE: "..m.n:upper()
            modeBtn.BackgroundColor3 = m.c
            modeScroll.Visible = false
            modeScroll:TweenSize(UDim2.new(1,0,0,0),"Out","Quad",0.25,true)
            frame:TweenSize(UDim2.new(0,420,0,480),"Out","Quad",0.25,true)
            TweenService:Create(modeArrow,TweenInfo.new(0.2),{Rotation=0}):Play()
        end)
    end
    
    -- Toggle button dengan glow effect
    local toggleBtn = Instance.new("TextButton",content)
    toggleBtn.Size = UDim2.new(1,0,0,60)
    toggleBtn.Position = UDim2.new(0,0,1,-65)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(180,50,60)
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Text = ""
    toggleBtn.AutoButtonColor = false
    
    local toggleCorner = Instance.new("UICorner",toggleBtn)
    toggleCorner.CornerRadius = UDim.new(0,14)
    
    local toggleStroke = Instance.new("UIStroke",toggleBtn)
    toggleStroke.Color = Color3.fromRGB(255,100,100)
    toggleStroke.Thickness = 2
    toggleStroke.Transparency = 0.6
    
    local toggleGlow = Instance.new("ImageLabel",toggleBtn)
    toggleGlow.Size = UDim2.new(1,40,1,40)
    toggleGlow.Position = UDim2.new(0.5,-20,0.5,-20)
    toggleGlow.BackgroundTransparency = 1
    toggleGlow.Image = "rbxassetid://5028857084"
    toggleGlow.ImageColor3 = Color3.fromRGB(255,80,80)
    toggleGlow.ImageTransparency = 0.8
    toggleGlow.ZIndex = 0
    
    local toggleStatus = Instance.new("TextLabel",toggleBtn)
    toggleStatus.Size = UDim2.new(0,50,1,0)
    toggleStatus.Position = UDim2.new(0,20,0,0)
    toggleStatus.BackgroundTransparency = 1
    toggleStatus.Text = "●"
    toggleStatus.TextColor3 = Color3.fromRGB(255,255,255)
    toggleStatus.TextSize = 30
    toggleStatus.Font = Enum.Font.GothamBold
    
    local toggleText = Instance.new("TextLabel",toggleBtn)
    toggleText.Size = UDim2.new(1,-90,1,0)
    toggleText.Position = UDim2.new(0,70,0,0)
    toggleText.BackgroundTransparency = 1
    toggleText.Text = "CONTROLLER OFF"
    toggleText.TextColor3 = Color3.fromRGB(255,255,255)
    toggleText.TextSize = 16
    toggleText.Font = Enum.Font.GothamBold
    toggleText.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Events
    closeBtn.MouseButton1Click:Connect(function() 
        if state.active then 
            stopPartController() 
        end
        TweenService:Create(frame,TweenInfo.new(0.3,Enum.EasingStyle.Back,Enum.EasingDirection.In),{
            Size=UDim2.new(0,0,0,0),
            Position=UDim2.new(0.5,0,0.5,0)
        }):Play()
        task.wait(0.3)
        gui:Destroy() 
    end)
    
    minBtn.MouseButton1Click:Connect(function()
        local mini = frame.Size.Y.Offset == 65
        if mini then
            frame:TweenSize(UDim2.new(0,420,0,480),"Out","Quad",0.3,true)
            content.Visible = true
            minBtn.Text = "−"
        else
            frame:TweenSize(UDim2.new(0,420,0,65),"Out","Quad",0.3,true)
            content.Visible = false
            modeScroll.Visible = false
            minBtn.Text = "+"
        end
    end)
    
    radiusInput.FocusLost:Connect(function()
        local v = tonumber(radiusInput.Text)
        if v and v > 0 then 
            config.radius = v
            log("Radius changed to: "..v)
        else 
            radiusInput.Text = tostring(config.radius) 
        end
    end)
    
    speedInput.FocusLost:Connect(function()
        local v = tonumber(speedInput.Text)
        if v and v > 0 then 
            config.speed = v
            config.launchSpeed = v * 20
            log("Speed changed to: "..v)
        else 
            speedInput.Text = tostring(config.speed) 
        end
    end)
    
    destroyBtn.MouseButton1Click:Connect(function()
        local textLabel = destroyBtn:FindFirstChild("TextLabel")
        textLabel.Text = "DESTROYING..."
        
        task.spawn(function()
            local n = destroyRopes()
            task.wait(0.5)
            textLabel.Text = "DESTROYED "..n.." ITEMS"
            destroyBtn.BackgroundColor3 = Color3.fromRGB(60,180,100)
            task.wait(2)
            textLabel.Text = "DESTROY ALL ROPES"
            destroyBtn.BackgroundColor3 = Color3.fromRGB(180,50,60)
        end)
    end)
    
    scanBtn.MouseButton1Click:Connect(function()
        scanText.Text = "SCANNING..."
        scanBtn.BackgroundColor3 = Color3.fromRGB(50,100,200)
        
        task.spawn(function()
            scan()
            subtitle.Text = "Parts Controlled: "..#state.parts
            
            task.wait(0.3)
            scanText.Text = "FOUND "..#state.parts.." PARTS"
            scanBtn.BackgroundColor3 = Color3.fromRGB(60,180,100)
            
            task.wait(2)
            scanText.Text = "SCAN PARTS"
            scanBtn.BackgroundColor3 = Color3.fromRGB(60,120,220)
        end)
    end)
    
    modeBtn.MouseButton1Click:Connect(function()
        modeScroll.Visible = not modeScroll.Visible
        if modeScroll.Visible then
            modeScroll:TweenSize(UDim2.new(1,0,0,200),"Out","Quad",0.3,true)
            frame:TweenSize(UDim2.new(0,420,0,700),"Out","Quad",0.3,true)
            TweenService:Create(modeArrow,TweenInfo.new(0.2),{Rotation=180}):Play()
        else
            modeScroll:TweenSize(UDim2.new(1,0,0,0),"Out","Quad",0.3,true)
            frame:TweenSize(UDim2.new(0,420,0,480),"Out","Quad",0.3,true)
            TweenService:Create(modeArrow,TweenInfo.new(0.2),{Rotation=0}):Play()
        end
    end)
    
    modeBtn.MouseEnter:Connect(function()
        TweenService:Create(modeBtnStroke,TweenInfo.new(0.2),{Transparency=0.5}):Play()
    end)
    
    modeBtn.MouseLeave:Connect(function()
        TweenService:Create(modeBtnStroke,TweenInfo.new(0.2),{Transparency=0.8}):Play()
    end)
    
    toggleBtn.MouseButton1Click:Connect(function()
        if state.active then
            stopPartController()
            toggleText.Text = "CONTROLLER OFF"
            toggleBtn.BackgroundColor3 = Color3.fromRGB(180,50,60)
            toggleStroke.Color = Color3.fromRGB(255,100,100)
            toggleGlow.ImageColor3 = Color3.fromRGB(255,80,80)
        else
            if #state.parts == 0 then
                log("No parts scanned! Scanning now...")
                scan()
                subtitle.Text = "Parts Controlled: "..#state.parts
            end
            
            if #state.parts > 0 then
                startPartController()
                toggleText.Text = "CONTROLLER ON"
                toggleBtn.BackgroundColor3 = Color3.fromRGB(60,180,100)
                toggleStroke.Color = Color3.fromRGB(100,255,150)
                toggleGlow.ImageColor3 = Color3.fromRGB(80,255,120)
            else
                log("Cannot start - no parts found!")
            end
        end
    end)
    
    toggleBtn.MouseEnter:Connect(function()
        TweenService:Create(toggleBtn,TweenInfo.new(0.2),{Size=UDim2.new(1,4,0,64)}):Play()
        TweenService:Create(toggleStroke,TweenInfo.new(0.2),{Transparency=0.3}):Play()
    end)
    
    toggleBtn.MouseLeave:Connect(function()
        TweenService:Create(toggleBtn,TweenInfo.new(0.2),{Size=UDim2.new(1,0,0,60)}):Play()
        TweenService:Create(toggleStroke,TweenInfo.new(0.2),{Transparency=0.6}):Play()
    end)
    
    -- Entrance animation
    frame.Size = UDim2.new(0,0,0,0)
    frame.Position = UDim2.new(0.5,0,0.5,0)
    frame:TweenSizeAndPosition(
        UDim2.new(0,420,0,480),
        UDim2.new(0.5,-210,0.5,-240),
        "Out","Back",0.5,true
    )
    
    log("GUI Created Successfully!")
    return gui
end

-- Start Controller
function startPartController()
    if state.active then return end
    if #state.parts == 0 then 
        log("Cannot start - no parts to control")
        return 
    end
    
    state.active = true
    state.timeOffset = 0
    log("Started: "..state.mode.." with "..#state.parts.." parts")
    
    state.connection = RunService.Heartbeat:Connect(function()
        if not state.active then return end
        
        state.timeOffset = state.timeOffset + config.batchSize
        if state.timeOffset >= #state.parts then 
            state.timeOffset = 0 
        end
        
        local fn = modes[state.mode]
        if fn then 
            pcall(fn)
        end
        
        task.wait(config.updateRate)
    end)
end

-- Stop Controller
function stopPartController()
    if state.connection then 
        state.connection:Disconnect() 
        state.connection = nil 
    end
    
    state.active = false
    cleanBodyPositions()
    log("Stopped!")
end

-- Hotkeys
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    if input.KeyCode == Enum.KeyCode.F1 then
        log("F1 pressed - Scanning...")
        scan()
        local gui = player.PlayerGui:FindFirstChild("WarpahGUI")
        if gui and gui:FindFirstChild("Frame") then
            local header = gui.Frame:FindFirstChild("Frame")
            if header then
                local subtitle = header:GetChildren()
                for _, child in pairs(subtitle) do
                    if child:IsA("TextLabel") and child.Name ~= "TextLabel" then
                        child.Text = "Parts Controlled: "..#state.parts
                        break
                    end
                end
            end
        end
        
    elseif input.KeyCode == Enum.KeyCode.F2 then
        if state.active then 
            stopPartController() 
        else 
            startPartController() 
        end
        
    elseif input.KeyCode == Enum.KeyCode.F4 then
        log("F4 pressed - Destroying ropes...")
        destroyRopes()
        
    elseif input.KeyCode == Enum.KeyCode.F5 then
        stopPartController()
    end
end)

-- Initialize
log("═══════════════════════════════════")
log("WARPAH CONTROLLER v4.0 ENHANCED UI")
log("═══════════════════════════════════")
log("✨ 24 Spectacular Modes")
log("⚠ Ultimate Rope Destroyer (Reusable)")
log("🧲 Enhanced Magnet System")
log("🔄 Repeatable Scan & Destroy")
log("🎨 Modern Glassmorphism Design")
log("")
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
