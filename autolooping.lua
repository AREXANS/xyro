--[[
    Skrip Kinerja Arexans Tools
    --------------------------
    Versi ini disederhanakan untuk hanya menyertakan fitur Teleport
    dan tab Performa baru dengan Optimized Game & Dark Texture.
    
    Update: Fitur Teleport telah diintegrasikan sepenuhnya dari skrip asli.
    Update 2: Menambahkan fitur auto-looping teleport.
    Update 3: Merapikan UI auto-loop menjadi lebih kompak dan fungsional.
--]]

-- Mencegah GUI dibuat berulang kali jika skrip dieksekusi lebih dari sekali.
if game:GetService("CoreGui"):FindFirstChild("ArexansPerformanceGUI") then
    game:GetService("CoreGui"):FindFirstChild("ArexansPerformanceGUI"):Destroy()
end

task.spawn(function()
    -- ====================================================================
    -- == BAGIAN INISIALISASI & LAYANAN UTAMA                          ==
    -- ====================================================================
    local HttpService = game:GetService("HttpService")
    local CoreGui = game:GetService("CoreGui")
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")
    local Lighting = game:GetService("Lighting")
    local TweenService = game:GetService("TweenService")
    local TeleportService = game:GetService("TeleportService")
    local LocalPlayer = Players.LocalPlayer

    -- ====================================================================
    -- == FUNGSI UTILITAS & HELPER GUI                                 ==
    -- ====================================================================

    local function MakeDraggable(guiObject, dragHandle)
        local dragInput, dragStart, startPos = nil, nil, nil
        dragHandle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragInput, dragStart, startPos = input, input.Position, guiObject.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and dragInput then
                local delta = input.Position - dragStart
                guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
        dragHandle.InputEnded:Connect(function(input) if input == dragInput then dragInput = nil end end)
    end

    local function showNotification(message, color)
        local notifFrame = Instance.new("Frame", CoreGui)
        notifFrame.Name, notifFrame.Size, notifFrame.Position = "PerformanceNotification", UDim2.new(0, 250, 0, 40), UDim2.new(0.5, -125, 0, -50)
        notifFrame.BackgroundColor3, notifFrame.BackgroundTransparency, notifFrame.BorderSizePixel, notifFrame.ZIndex = color or Color3.fromRGB(10, 10, 25), 0.3, 0, 100
        Instance.new("UICorner", notifFrame).CornerRadius = UDim.new(0, 8); local stroke = Instance.new("UIStroke", notifFrame); stroke.Color, stroke.Thickness, stroke.Transparency = Color3.new(1,1,1), 1.5, 0.5
        local notifLabel = Instance.new("TextLabel", notifFrame); notifLabel.Size, notifLabel.Position, notifLabel.BackgroundTransparency = UDim2.new(1, -10, 1, 0), UDim2.new(0, 5, 0, 0), 1
        notifLabel.Text, notifLabel.TextColor3, notifLabel.Font, notifLabel.TextSize, notifLabel.TextWrapped = message, Color3.fromRGB(255, 255, 255), Enum.Font.SourceSansBold, 14, true
        local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out); TweenService:Create(notifFrame, tweenInfo, {Position = UDim2.new(0.5, -125, 0, 15)}):Play()
        task.delay(3, function() if notifFrame and notifFrame.Parent then TweenService:Create(notifFrame, tweenInfo, {Position = UDim2.new(0.5, -125, 0, -50)}):Play(); task.wait(0.4); notifFrame:Destroy() end end)
    end
    
    local function createButton(parent, name, callback)
        local button = Instance.new("TextButton"); button.Size, button.BackgroundColor3, button.BorderSizePixel = UDim2.new(1, 0, 0, 22), Color3.fromRGB(0, 120, 255), 0
        button.Text, button.TextColor3, button.TextSize, button.Font = name, Color3.fromRGB(255, 255, 255), 12, Enum.Font.SourceSansBold
        button.Parent = parent; Instance.new("UICorner", button).CornerRadius = UDim.new(0, 5); button.MouseButton1Click:Connect(callback)
        return button
    end

    local function createToggle(parent, name, initialState, callback)
        local toggleFrame = Instance.new("Frame", parent); toggleFrame.Size, toggleFrame.BackgroundTransparency = UDim2.new(1, 0, 0, 25), 1
        local toggleLabel = Instance.new("TextLabel", toggleFrame); toggleLabel.Size, toggleLabel.Position, toggleLabel.BackgroundTransparency = UDim2.new(0.8, -10, 1, 0), UDim2.new(0, 5, 0, 0), 1
        toggleLabel.Text, toggleLabel.TextColor3, toggleLabel.TextSize, toggleLabel.TextXAlignment, toggleLabel.Font = name, Color3.fromRGB(255, 255, 255), 12, Enum.TextXAlignment.Left, Enum.Font.SourceSans
        local switch = Instance.new("TextButton", toggleFrame); switch.Name, switch.Size, switch.Position = "Switch", UDim2.new(0, 40, 0, 20), UDim2.new(1, -50, 0.5, -10); switch.BackgroundColor3, switch.BorderSizePixel, switch.Text = Color3.fromRGB(50, 50, 50), 0, ""; Instance.new("UICorner", switch).CornerRadius = UDim.new(1, 0)
        local thumb = Instance.new("Frame", switch); thumb.Name, thumb.Size, thumb.Position = "Thumb", UDim2.new(0, 16, 0, 16), UDim2.new(0, 2, 0.5, -8); thumb.BackgroundColor3, thumb.BorderSizePixel = Color3.fromRGB(220, 220, 220), 0; Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)
        local onColor, offColor, onPosition, offPosition, tweenInfo, isToggled = Color3.fromRGB(0, 150, 255), Color3.fromRGB(60, 60, 60), UDim2.new(1, -18, 0.5, -8), UDim2.new(0, 2, 0.5, -8), TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), initialState
        local function updateVisuals(isInstant) local goalPos, goalColor = isToggled and onPosition or offPosition, isToggled and onColor or offColor; if isInstant then thumb.Position, switch.BackgroundColor3 = goalPos, goalColor else TweenService:Create(thumb, tweenInfo, {Position = goalPos}):Play(); TweenService:Create(switch, tweenInfo, {BackgroundColor3 = goalColor}):Play() end end
        switch.MouseButton1Click:Connect(function() isToggled = not isToggled; updateVisuals(false); callback(isToggled) end); updateVisuals(true)
        return toggleFrame, switch
    end

    local function showGenericRenamePrompt(oldName, callback)
        local promptFrame = Instance.new("Frame", CoreGui); promptFrame.Size, promptFrame.Position = UDim2.new(0, 200, 0, 100), UDim2.new(0.5, -100, 0.5, -50); promptFrame.BackgroundColor3, promptFrame.BorderSizePixel, promptFrame.ZIndex = Color3.fromRGB(30, 30, 30), 0, 10
        Instance.new("UICorner", promptFrame).CornerRadius = UDim.new(0, 8); local stroke = Instance.new("UIStroke", promptFrame); stroke.Color, stroke.Thickness = Color3.fromRGB(0, 150, 255), 1
        local title = Instance.new("TextLabel", promptFrame); title.Size, title.Text, title.TextColor3 = UDim2.new(1, 0, 0, 20), "Ganti Nama", Color3.fromRGB(255, 255, 255); title.BackgroundTransparency, title.Font = 1, Enum.Font.SourceSansBold
        local textBox = Instance.new("TextBox", promptFrame); textBox.Size, textBox.Position, textBox.Text = UDim2.new(1, -20, 0, 30), UDim2.new(0.5, -90, 0, 30), oldName; textBox.BackgroundColor3, textBox.TextColor3, textBox.ClearTextOnFocus = Color3.fromRGB(50, 50, 50), Color3.fromRGB(255, 255, 255), false; Instance.new("UICorner", textBox).CornerRadius = UDim.new(0, 5)
        local okButton = createButton(promptFrame, "OK", function() callback(textBox.Text); promptFrame:Destroy() end); okButton.Size, okButton.Position = UDim2.new(0.5, -10, 0, 25), UDim2.new(0, 5, 1, -30)
        local cancelButton = createButton(promptFrame, "Batal", function() promptFrame:Destroy() end); cancelButton.Size, cancelButton.Position, cancelButton.BackgroundColor3 = UDim2.new(0.5, -10, 0, 25), UDim2.new(0.5, 5, 1, -30), Color3.fromRGB(100, 100, 100)
    end

    -- ====================================================================
    -- == BAGIAN UTAMA GUI                                             ==
    -- ====================================================================
    local isSpectatingLocation, areTeleportIconsVisible = false, true
    local savedTeleportLocations = {}
    local SAVE_FOLDER, TELEPORT_SAVE_FILE = "ArexansTools", "ArexansTools/ArexansTools_Teleports_" .. tostring(game.PlaceId) .. ".json"
    if isfolder and not isfolder(SAVE_FOLDER) then pcall(makefolder, SAVE_FOLDER) end

    local ScreenGui = Instance.new("ScreenGui", CoreGui); ScreenGui.Name, ScreenGui.ZIndexBehavior, ScreenGui.ResetOnSpawn = "ArexansPerformanceGUI", Enum.ZIndexBehavior.Sibling, false
    local MainFrame = Instance.new("Frame", ScreenGui); MainFrame.Name, MainFrame.Size, MainFrame.Position = "MainFrame", UDim2.new(0, 200, 0, 350), UDim2.new(0.5, -100, 0.5, -175)
    MainFrame.BackgroundColor3, MainFrame.BackgroundTransparency, MainFrame.BorderSizePixel = Color3.fromRGB(20, 20, 20), 0.5, 0
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8); local UIStroke = Instance.new("UIStroke", MainFrame); UIStroke.Color, UIStroke.Thickness, UIStroke.Transparency = Color3.fromRGB(0, 150, 255), 2, 0.5
    local TitleBar = Instance.new("TextButton", MainFrame); TitleBar.Name, TitleBar.Size = "TitleBar", UDim2.new(1, 0, 0, 30); TitleBar.BackgroundColor3, TitleBar.BorderSizePixel, TitleBar.Text, TitleBar.AutoButtonColor = Color3.fromRGB(25, 25, 25), 0, "", false
    local TitleLabel = Instance.new("TextLabel", TitleBar); TitleLabel.Name, TitleLabel.Size, TitleLabel.BackgroundTransparency = "TitleLabel", UDim2.new(1, 0, 1, 0), 1; TitleLabel.Text, TitleLabel.TextColor3, TitleLabel.TextSize, TitleLabel.Font = "Performance Tools", Color3.fromRGB(0, 200, 255), 14, Enum.Font.SourceSansBold
    local TabsFrame = Instance.new("Frame", MainFrame); TabsFrame.Name, TabsFrame.Size, TabsFrame.Position = "TabsFrame", UDim2.new(0, 70, 1, -30), UDim2.new(0, 0, 0, 30); TabsFrame.BackgroundColor3, TabsFrame.BorderSizePixel = Color3.fromRGB(25, 25, 25), 0
    local TabListLayout = Instance.new("UIListLayout", TabsFrame); TabListLayout.Padding, TabListLayout.HorizontalAlignment, TabListLayout.FillDirection = UDim.new(0, 5), Enum.HorizontalAlignment.Center, Enum.FillDirection.Vertical
    local ContentFrame = Instance.new("Frame", MainFrame); ContentFrame.Name, ContentFrame.Size, ContentFrame.Position, ContentFrame.BackgroundTransparency = "ContentFrame", UDim2.new(1, -70, 1, -30), UDim2.new(0, 70, 0, 30), 1
    MakeDraggable(MainFrame, TitleBar)

    local TeleportTabContent = Instance.new("ScrollingFrame", ContentFrame); TeleportTabContent.Name, TeleportTabContent.Size, TeleportTabContent.Position = "TeleportTab", UDim2.new(1, -10, 1, -10), UDim2.new(0, 5, 0, 5); TeleportTabContent.BackgroundTransparency, TeleportTabContent.Visible, TeleportTabContent.CanvasSize, TeleportTabContent.ScrollBarThickness = 1, false, UDim2.new(0,0,0,0), 6
    local PerformaTabContent = Instance.new("ScrollingFrame", ContentFrame); PerformaTabContent.Name, PerformaTabContent.Size, PerformaTabContent.Position = "PerformaTab", UDim2.new(1, -10, 1, -10), UDim2.new(0, 5, 0, 5); PerformaTabContent.BackgroundTransparency, PerformaTabContent.Visible, PerformaTabContent.CanvasSize, PerformaTabContent.ScrollBarThickness = 1, false, UDim2.new(0,0,0,0), 6
    local TeleportListLayout = Instance.new("UIListLayout", TeleportTabContent); TeleportListLayout.Padding, TeleportListLayout.SortOrder = UDim.new(0, 2), Enum.SortOrder.LayoutOrder
    local PerformaListLayout = Instance.new("UIListLayout", PerformaTabContent); PerformaListLayout.Padding = UDim.new(0, 5)
    local function setupCanvasSize(listLayout, scrollingFrame) listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y) end) end
    setupCanvasSize(TeleportListLayout, TeleportTabContent); setupCanvasSize(PerformaListLayout, PerformaTabContent)

    -- ====================================================================
    -- == BAGIAN LOGIKA FITUR                                          ==
    -- ====================================================================

    --[[ FITUR TELEPORT ]]--
    local updateTeleportList; local isAutoLooping = false
    
    local function naturalCompare(a, b)
        local function split(s) local parts = {}; for text, num in s:gmatch("([^%d]*)(%d*)") do if text ~= "" then table.insert(parts, text:lower()) end; if num ~= "" then table.insert(parts, tonumber(num)) end end; return parts end
        local pA, pB = split(a.Name or ""), split(b.Name or ""); for i=1, math.min(#pA, #pB) do if type(pA[i]) ~= type(pB[i]) then return type(pA[i]) == "number" end; if pA[i] < pB[i] then return true elseif pA[i] > pB[i] then return false end end; return #pA < #pB
    end
    
    local function saveTeleportData() if not writefile then return end; local data = {}; for _, loc in ipairs(savedTeleportLocations) do table.insert(data, {Name = loc.Name, CFrameData = {loc.CFrame:GetComponents()}}) end; pcall(writefile, TELEPORT_SAVE_FILE, HttpService:JSONEncode(data)) end
    
    local function loadTeleportData()
        if not readfile or not isfile or not isfile(TELEPORT_SAVE_FILE) then return end
        pcall(function() local content = readfile(TELEPORT_SAVE_FILE); local data = HttpService:JSONDecode(content); savedTeleportLocations = {}; for _, d in ipairs(data) do table.insert(savedTeleportLocations, {Name = d.Name, CFrame = CFrame.new(unpack(d.CFrameData))}) end; table.sort(savedTeleportLocations, naturalCompare); if updateTeleportList then updateTeleportList() end end)
    end

    local function addTeleportLocation(name, cframe) for _, loc in pairs(savedTeleportLocations) do if loc.Name == name then return end end; table.insert(savedTeleportLocations, {Name = name, CFrame = cframe}); table.sort(savedTeleportLocations, naturalCompare); saveTeleportData(); if updateTeleportList then updateTeleportList() end end
    
    updateTeleportList = function()
        for _, child in pairs(TeleportTabContent:GetChildren()) do if child.Name == "TeleportLocationFrame" then child:Destroy() end end
        for i, locData in ipairs(savedTeleportLocations) do
            local locFrame = Instance.new("Frame", TeleportTabContent); locFrame.Name, locFrame.Size, locFrame.BackgroundTransparency, locFrame.LayoutOrder = "TeleportLocationFrame", UDim2.new(1, 0, 0, 22), 1, i + 7
            local tpButton = createButton(locFrame, locData.Name, function() if LocalPlayer.Character and LocalPlayer.Character.HumanoidRootPart then LocalPlayer.Character.HumanoidRootPart.CFrame = locData.CFrame * CFrame.new(0, 3, 0) end end)
            tpButton.Size, tpButton.TextXAlignment = areTeleportIconsVisible and UDim2.new(1, -65, 1, 0) or UDim2.new(1, 0, 1, 0), Enum.TextXAlignment.Left; Instance.new("UIPadding", tpButton).PaddingLeft = UDim.new(0, 5)
            local actionsFrame = Instance.new("Frame", locFrame); actionsFrame.Name, actionsFrame.Size, actionsFrame.Position, actionsFrame.BackgroundTransparency, actionsFrame.Visible = "ActionsFrame", UDim2.new(0, 62, 1, 0), UDim2.new(1, -62, 0, 0), 1, areTeleportIconsVisible
            local actionsLayout = Instance.new("UIListLayout", actionsFrame); actionsLayout.FillDirection, actionsLayout.Padding = Enum.FillDirection.Horizontal, UDim.new(0, 2)
            createButton(actionsFrame, "👁️", function() end).Size, createButton(actionsFrame, "R", function() showGenericRenamePrompt(locData.Name, function(newName) if newName and newName ~= "" and newName ~= locData.Name then locData.Name = newName; table.sort(savedTeleportLocations, naturalCompare); saveTeleportData(); updateTeleportList() end end) end).Size = UDim2.new(0, 18, 0, 18), UDim2.new(0, 18, 0, 18)
            createButton(actionsFrame, "X", function() table.remove(savedTeleportLocations, i); saveTeleportData(); updateTeleportList() end).Size, createButton(actionsFrame, "X", function() end).BackgroundColor3 = UDim2.new(0, 18, 0, 18), Color3.fromRGB(200, 50, 50)
        end
    end
    
    local function updateTeleportIconVisibility() for _, child in pairs(TeleportTabContent:GetChildren()) do if child.Name == "TeleportLocationFrame" then local actions, tpBtn = child.ActionsFrame, child:FindFirstChildOfClass("TextButton"); if actions and tpBtn then actions.Visible, tpBtn.Size = areTeleportIconsVisible, areTeleportIconsVisible and UDim2.new(1, -65, 1, 0) or UDim2.new(1, 0, 1, 0) end end end end

    --[[ FITUR PERFORMA ]]--
    local IsOptimizedGameEnabled, darkActive = false, false; local storedProperties, originalLighting, partOriginals, modifiedParts = {}, {}, setmetatable({}, {__mode = "k"}), {}
    local function scanAndDisableHeavyObjects() storedProperties = {}; for _, obj in ipairs(Workspace:GetDescendants()) do pcall(function() if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") then storedProperties[obj]={Enabled=obj.Enabled}; obj.Enabled=false elseif obj:IsA("BasePart") and (obj.Name:lower():find("tree") or obj.Name:lower():find("grass")) then storedProperties[obj]={Transparency=obj.Transparency}; obj.Transparency=1 end end) end; storedProperties.LightingProps={GlobalShadows=Lighting.GlobalShadows, FogEnd=Lighting.FogEnd}; pcall(function() Lighting.GlobalShadows=false; Lighting.FogEnd=1e6 end); if Workspace:FindFirstChildOfClass("Terrain") then local T=Workspace:FindFirstChildOfClass("Terrain"); storedProperties.Terrain={Decoration=T.Decoration, WaterReflectance=T.WaterReflectance}; pcall(function() T.Decoration=false; T.WaterReflectance=0 end) end end
    local function restoreHeavyObjects() for obj, props in pairs(storedProperties) do pcall(function() if typeof(obj)=="Instance" and obj.Parent then for k,v in pairs(props) do obj[k]=v end elseif obj=="LightingProps" then Lighting.GlobalShadows, Lighting.FogEnd=props.GlobalShadows, props.FogEnd elseif obj=="Terrain" and Workspace:FindFirstChildOfClass("Terrain") then local T=Workspace:FindFirstChildOfClass("Terrain"); T.Decoration, T.WaterReflectance = props.Decoration, props.WaterReflectance end end) end; storedProperties={} end
    local function applyDarkTotal() if darkActive then return end; darkActive=true; originalLighting={Ambient=Lighting.Ambient, OutdoorAmbient=Lighting.OutdoorAmbient, Brightness=Lighting.Brightness, GlobalShadows=Lighting.GlobalShadows}; Lighting.Ambient, Lighting.OutdoorAmbient, Lighting.Brightness, Lighting.GlobalShadows = Color3.fromRGB(128,128,128), Color3.fromRGB(128,128,128), 1, false; for _,d in ipairs(Workspace:GetDescendants()) do if d:IsA("BasePart") then pcall(function() partOriginals[d]={Color=d.Color, Material=d.Material}; d.Color=Color3.fromRGB(128,128,128); d.Material=Enum.Material.SmoothPlastic; modifiedParts[d]=true end) end end end
    local function restoreDarkTotal() if not darkActive then return end; darkActive=false; for inst in pairs(modifiedParts) do if inst and inst.Parent and partOriginals[inst] then local d=partOriginals[inst]; pcall(function() inst.Color, inst.Material = d.Color, d.Material end) end end; if originalLighting.Ambient then Lighting.Ambient, Lighting.OutdoorAmbient, Lighting.Brightness, Lighting.GlobalShadows = originalLighting.Ambient, originalLighting.OutdoorAmbient, originalLighting.Brightness, originalLighting.GlobalShadows end; partOriginals, modifiedParts = setmetatable({}, {__mode = "k"}), {} end

    -- ====================================================================
    -- == SETUP KONTEN TAB                                             ==
    -- ====================================================================

    local function setupTeleportTab()
        createButton(TeleportTabContent, "Pindai Ulang Map", function() for _, part in pairs(Workspace:GetDescendants()) do if part:IsA("BasePart") then local name = part.Name:lower(); if (name:find("checkpoint") or name:find("pos") or name:find("finish") or name:find("start")) and not Players:GetPlayerFromCharacter(part.Parent) then addTeleportLocation(part.Name, part.CFrame) end end end end).LayoutOrder = 1
        createButton(TeleportTabContent, "Simpan Lokasi Saat Ini", function() if LocalPlayer.Character and LocalPlayer.Character.HumanoidRootPart then addTeleportLocation("Kustom " .. #savedTeleportLocations + 1, LocalPlayer.Character.HumanoidRootPart.CFrame) end end).LayoutOrder = 2
        createToggle(TeleportTabContent, "Tampilkan Ikon", areTeleportIconsVisible, function(v) areTeleportIconsVisible = v; updateTeleportIconVisibility() end).LayoutOrder = 3

        -- FITUR BARU: AUTO LOOPING TELEPORT DENGAN UI KOMPAK
        local autoLoopSettingsFrame = Instance.new("Frame", TeleportTabContent)
        autoLoopSettingsFrame.Name, autoLoopSettingsFrame.Size, autoLoopSettingsFrame.BackgroundTransparency, autoLoopSettingsFrame.Visible, autoLoopSettingsFrame.LayoutOrder = "AutoLoopSettingsFrame", UDim2.new(1, 0, 0, 30), 1, false, 5
        local settingsLayout = Instance.new("UIListLayout", autoLoopSettingsFrame); settingsLayout.FillDirection, settingsLayout.VerticalAlignment, settingsLayout.Padding = Enum.FillDirection.Horizontal, Enum.VerticalAlignment.Center, UDim.new(0, 5)

        local function createCompactInput(parent, label, default)
            local frame = Instance.new("Frame", parent); frame.Size, frame.BackgroundTransparency = UDim2.new(0.4, -12, 1, 0), 1
            local layout = Instance.new("UIListLayout", frame); layout.FillDirection, layout.VerticalAlignment = Enum.FillDirection.Horizontal, Enum.VerticalAlignment.Center
            local textLabel = Instance.new("TextLabel", frame); textLabel.Size = UDim2.new(0, 15, 1, 0); textLabel.Text, textLabel.TextColor3, textLabel.TextSize, textLabel.Font, textLabel.BackgroundTransparency = label, Color3.fromRGB(200,200,200), 11, Enum.Font.SourceSans, 1
            local textBox = Instance.new("TextBox", frame); textBox.Size = UDim2.new(1, -15, 0, 20); textBox.Text, textBox.BackgroundColor3 = default, Color3.fromRGB(50, 50, 50); textBox.TextColor3, textBox.TextSize, textBox.Font = Color3.fromRGB(255,255,255), 12, Enum.Font.SourceSans; Instance.new("UICorner", textBox).CornerRadius = UDim.new(0, 4)
            return textBox
        end

        local repeatInput = createCompactInput(autoLoopSettingsFrame, "U:", "5")
        local delayInput = createCompactInput(autoLoopSettingsFrame, "D:", "2")
        local playStopButton = createButton(autoLoopSettingsFrame, "▶️", function() end)
        playStopButton.Size, playStopButton.BackgroundColor3 = UDim2.new(0.2, 0, 0, 22), Color3.fromRGB(50, 180, 50)

        createToggle(TeleportTabContent, "Auto Loop", false, function(isVisible) autoLoopSettingsFrame.Visible = isVisible end).LayoutOrder = 4

        playStopButton.MouseButton1Click:Connect(function()
            if isAutoLooping then -- Tombol Stop ditekan
                isAutoLooping = false
                playStopButton.Text, playStopButton.BackgroundColor3 = "▶️", Color3.fromRGB(50, 180, 50)
                showNotification("Auto loop dihentikan.", Color3.fromRGB(200, 50, 50))
            else -- Tombol Play ditekan
                local repetitions, delayTime = tonumber(repeatInput.Text), tonumber(delayInput.Text)
                if not repetitions or repetitions <= 0 or not delayTime or delayTime < 0 then showNotification("Input jumlah & delay tidak valid.", Color3.fromRGB(200, 50, 50)); return end
                if #savedTeleportLocations == 0 then showNotification("Tidak ada lokasi teleport.", Color3.fromRGB(200, 50, 50)); return end
                
                isAutoLooping = true
                playStopButton.Text, playStopButton.BackgroundColor3 = "⏹️", Color3.fromRGB(200, 50, 50)
                showNotification("Memulai auto loop...", Color3.fromRGB(50, 200, 50))
                
                task.spawn(function()
                    for i = 1, repetitions do
                        if not isAutoLooping then break end
                        for _, locData in ipairs(savedTeleportLocations) do
                            if not isAutoLooping then break end
                            if LocalPlayer.Character and LocalPlayer.Character.HumanoidRootPart then LocalPlayer.Character.HumanoidRootPart.CFrame = locData.CFrame * CFrame.new(0, 3, 0) else isAutoLooping = false; break end
                            task.wait(delayTime)
                        end
                    end
                    if isAutoLooping then showNotification("Auto loop selesai.", Color3.fromRGB(50, 200, 50)) end
                    isAutoLooping = false; playStopButton.Text, playStopButton.BackgroundColor3 = "▶️", Color3.fromRGB(50, 180, 50)
                end)
            end
        end)
    end
    
    local function setupPerformaTab()
        createToggle(PerformaTabContent, "Optimized Game", IsOptimizedGameEnabled, function(state) IsOptimizedGameEnabled = state; if state then scanAndDisableHeavyObjects() else restoreHeavyObjects() end end).LayoutOrder = 1
        createToggle(PerformaTabContent, "Dark Texture", darkActive, function(state) if state then applyDarkTotal() else restoreDarkTotal() end end).LayoutOrder = 2
    end

    -- ====================================================================
    -- == MANAJEMEN TAB & INISIALISASI AKHIR                           ==
    -- ====================================================================

    local function switchTab(tabName) PerformaTabContent.Visible = (tabName == "Performa"); TeleportTabContent.Visible = (tabName == "Teleport") end
    local function createTabButton(name) local btn = createButton(TabsFrame, name, function() switchTab(name) end); btn.Size, btn.BackgroundColor3 = UDim2.new(1, 0, 0, 25), Color3.fromRGB(30,30,30); return btn end
    createTabButton("Teleport"); createTabButton("Performa")
    setupTeleportTab(); setupPerformaTab(); loadTeleportData(); switchTab("Teleport")
end)
