--[[
    Arexans Emote System (Standalone)
    Script ini hanya menyediakan fungsionalitas emote dari Arexanstools.
    Dibuat oleh Arexans, diekstrak dan disederhanakan dengan tampilan yang rapi.
]]

-- Layanan Inti Roblox
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Mencegah GUI dibuat berulang kali
if CoreGui:FindFirstChild("ArexansEmoteStandaloneGUI") then
    CoreGui:FindFirstChild("ArexansEmoteStandaloneGUI"):Destroy()
end
if CoreGui:FindFirstChild("EmoteWindowGUI") then
    CoreGui:FindFirstChild("EmoteWindowGUI"):Destroy()
end


-- Variabel Global untuk Status
local isEmoteWindowVisible = false
local EmoteScreenGui = nil
local saveGuiPositions -- Dideklarasikan di sini agar bisa diakses secara global

-- Fungsi untuk membuat jendela bisa digeser (draggable)
local function MakeDraggable(guiObject, dragHandle)
    local dragInput = nil
    local dragStart = nil
    local startPos = nil
    local wasDragged = false

    dragHandle.InputBegan:Connect(function(input)
        if not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then return end
        if dragInput then return end
        
        dragInput = input
        dragStart = input.Position
        startPos = guiObject.Position
        wasDragged = false
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragInput and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local newPos = input.Position
            local delta = newPos - dragStart
            guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            if not wasDragged and delta.Magnitude > 5 then
                wasDragged = true
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if dragInput and input.UserInputType == dragInput.UserInputType then
            if wasDragged and saveGuiPositions then
                pcall(saveGuiPositions)
            end
            dragInput = nil
        end
    end)
end

-- Manajemen File dan Data
local SAVE_FOLDER = "ArexansTools"
if isfolder and not isfolder(SAVE_FOLDER) then
    pcall(makefolder, SAVE_FOLDER)
end
local GUI_POSITIONS_SAVE_FILE = SAVE_FOLDER .. "/ArexansTools_GuiPositions_" .. tostring(game.PlaceId) .. ".json"
local EMOTE_FAVORITES_SAVE_FILE = SAVE_FOLDER .. "/EmoteFavorites.json"
local favoriteEmotes = {}
local loadedGuiPositions = nil

local function saveFavorites()
    if not writefile then return end
    pcall(function()
        writefile(EMOTE_FAVORITES_SAVE_FILE, HttpService:JSONEncode(favoriteEmotes))
    end)
end

local function loadFavorites()
    if not readfile or not isfile or not isfile(EMOTE_FAVORITES_SAVE_FILE) then return end
    local success, result = pcall(function()
        local content = readfile(EMOTE_FAVORITES_SAVE_FILE)
        local data = HttpService:JSONDecode(content)
        if type(data) == "table" then
            favoriteEmotes = data
        end
    end)
    if not success then
        warn("Gagal memuat favorit emote:", result)
    end
end

-- Fungsi simpan dan muat posisi GUI
saveGuiPositions = function()
    if not writefile then return end
    local guiDataToSave = {}
    if EmoteScreenGui then
        local frame = EmoteScreenGui:FindFirstChild("MainFrame")
        if frame then
             guiDataToSave.EmoteFrame = {
                XScale = frame.Position.X.Scale, XOffset = frame.Position.X.Offset,
                YScale = frame.Position.Y.Scale, YOffset = frame.Position.Y.Offset,
                SizeX = frame.Size.X.Offset, SizeY = frame.Size.Y.Offset
            }
        end
    end
    -- Simpan juga posisi tombol toggle utama
    local toggleButton = CoreGui:FindFirstChild("ArexansEmoteStandaloneGUI") and CoreGui.ArexansEmoteStandaloneGUI:FindFirstChild("EmoteToggleButton")
    if toggleButton then
        guiDataToSave.EmoteToggleButton = {
            XScale = toggleButton.Position.X.Scale, XOffset = toggleButton.Position.X.Offset,
            YScale = toggleButton.Position.Y.Scale, YOffset = toggleButton.Position.Y.Offset
        }
    end

    pcall(function()
        local jsonData = HttpService:JSONEncode(guiDataToSave)
        writefile(GUI_POSITIONS_SAVE_FILE, jsonData)
    end)
end

local function loadGuiPositions()
    if not readfile or not isfile or not isfile(GUI_POSITIONS_SAVE_FILE) then
        return
    end
    local success, result = pcall(function()
        local fileContent = readfile(GUI_POSITIONS_SAVE_FILE)
        loadedGuiPositions = HttpService:JSONDecode(fileContent)
    end)
    if not success then
        warn("Gagal memuat posisi GUI:", result)
        loadedGuiPositions = nil
    end
end

-- Fungsi Utama untuk Membuat GUI Emote
local function initializeEmoteGUI()
    if EmoteScreenGui and EmoteScreenGui.Parent then
        EmoteScreenGui:Destroy()
        EmoteScreenGui = nil
        isEmoteWindowVisible = false
        return
    end

    isEmoteWindowVisible = true
    loadFavorites()

    EmoteScreenGui = Instance.new("ScreenGui")
    EmoteScreenGui.Name = "EmoteWindowGUI"
    EmoteScreenGui.Parent = CoreGui
    EmoteScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    EmoteScreenGui.DisplayOrder = 11 -- Di atas tombol toggle

    local EmoteMainFrame = Instance.new("Frame")
    EmoteMainFrame.Name = "MainFrame"
    EmoteMainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    EmoteMainFrame.Size = UDim2.new(0, 160, 0, 180) -- Ukuran default kecil seperti di Asli
    EmoteMainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    
    if loadedGuiPositions and loadedGuiPositions.EmoteFrame then
        local posData = loadedGuiPositions.EmoteFrame
        pcall(function() 
            EmoteMainFrame.Position = UDim2.new(posData.XScale, posData.XOffset, posData.YScale, posData.YOffset)
            EmoteMainFrame.Size = UDim2.new(0, posData.SizeX or 160, 0, posData.SizeY or 180)
        end)
    end
    
    EmoteMainFrame.BackgroundColor3 = Color3.fromRGB(28, 43, 70)
    EmoteMainFrame.BackgroundTransparency = 0.85 
    EmoteMainFrame.BorderColor3 = Color3.fromRGB(90, 150, 255)
    EmoteMainFrame.BorderSizePixel = 1
    EmoteMainFrame.ClipsDescendants = true
    EmoteMainFrame.Parent = EmoteScreenGui
    EmoteMainFrame.Visible = true

    local UICorner = Instance.new("UICorner", EmoteMainFrame)
    UICorner.CornerRadius = UDim.new(0, 8)

    local Header = Instance.new("TextButton") 
    Header.Name = "Header"
    Header.Size = UDim2.new(1, 0, 0, 30)
    Header.BackgroundColor3 = Color3.fromRGB(48, 63, 90)
    Header.BackgroundTransparency = 0.85 
    Header.BorderSizePixel = 0
    Header.Text = "" 
    Header.AutoButtonColor = false 
    Header.Parent = EmoteMainFrame

    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Size = UDim2.new(1, -40, 1, 0)
    Title.Position = UDim2.new(0, 10, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Font = Enum.Font.GothamBold
    Title.Text = "Arexans Emotes"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Header

    local CloseButton = Instance.new("TextButton")
    CloseButton.Name = "CloseButton"
    CloseButton.Size = UDim2.new(0, 20, 0, 20)
    CloseButton.Position = UDim2.new(1, -15, 0.5, 0)
    CloseButton.AnchorPoint = Vector2.new(0.5, 0.5)
    CloseButton.BackgroundTransparency = 1
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.TextSize = 18
    CloseButton.Parent = Header
    CloseButton.MouseButton1Click:Connect(initializeEmoteGUI) 
    
    MakeDraggable(EmoteMainFrame, Header)

    local EmoteResizeHandle = Instance.new("TextButton")
    EmoteResizeHandle.Name = "EmoteResizeHandle"
    EmoteResizeHandle.Text = ""
    EmoteResizeHandle.Size = UDim2.new(0, 15, 0, 15)
    EmoteResizeHandle.Position = UDim2.new(1, -15, 1, -15)
    EmoteResizeHandle.BackgroundColor3 = Color3.fromRGB(90, 150, 255)
    EmoteResizeHandle.BackgroundTransparency = 0.85 
    EmoteResizeHandle.BorderSizePixel = 0
    EmoteResizeHandle.ZIndex = 2
    EmoteResizeHandle.Parent = EmoteMainFrame

    EmoteResizeHandle.InputBegan:Connect(function(input)
        if not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then return end
        local isResizing = true
        local initialMousePosition = UserInputService:GetMouseLocation()
        local initialFrameSize = EmoteMainFrame.AbsoluteSize
        local inputChangedConnection, inputEndedConnection
        inputChangedConnection = UserInputService.InputChanged:Connect(function(changedInput)
            if isResizing and (changedInput.UserInputType == Enum.UserInputType.MouseMovement or changedInput.UserInputType == Enum.UserInputType.Touch) then
                local delta = UserInputService:GetMouseLocation() - initialMousePosition
                local newSizeX = math.max(160, initialFrameSize.X + delta.X)
                local newSizeY = math.max(180, initialFrameSize.Y + delta.Y)
                EmoteMainFrame.Size = UDim2.new(0, newSizeX, 0, newSizeY)
            end
        end)
        inputEndedConnection = UserInputService.InputEnded:Connect(function(endedInput)
            if endedInput.UserInputType == input.UserInputType then
                isResizing = false
                if inputChangedConnection then inputChangedConnection:Disconnect() end
                if inputEndedConnection then inputEndedConnection:Disconnect() end
                saveGuiPositions()
            end
        end)
    end)

    local SearchBox = Instance.new("TextBox")
    SearchBox.Name = "SearchBox"
    SearchBox.Size = UDim2.new(1, -20, 0, 25)
    SearchBox.Position = UDim2.new(0, 10, 0, 35)
    SearchBox.BackgroundColor3 = Color3.fromRGB(48, 63, 90)
    SearchBox.BackgroundTransparency = 0.85
    SearchBox.PlaceholderText = "Cari emote..."
    SearchBox.Text = ""
    SearchBox.PlaceholderColor3 = Color3.fromRGB(180, 190, 210)
    SearchBox.Font = Enum.Font.Gotham
    SearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    SearchBox.ClearTextOnFocus = false
    SearchBox.Parent = EmoteMainFrame
    local SearchCorner = Instance.new("UICorner", SearchBox); SearchCorner.CornerRadius = UDim.new(0, 6)
    local SearchPadding = Instance.new("UIPadding", SearchBox); SearchPadding.PaddingLeft = UDim.new(0, 10); SearchPadding.PaddingRight = UDim.new(0, 10)

    local FilterFrame = Instance.new("Frame")
    FilterFrame.Name = "FilterFrame"
    FilterFrame.Size = UDim2.new(1, -20, 0, 25)
    FilterFrame.Position = UDim2.new(0, 10, 0, 65)
    FilterFrame.BackgroundTransparency = 1
    FilterFrame.Parent = EmoteMainFrame

    local FilterLayout = Instance.new("UIListLayout", FilterFrame)
    FilterLayout.FillDirection = Enum.FillDirection.Horizontal
    FilterLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    FilterLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    FilterLayout.Padding = UDim.new(0, 5)

    local filterButtons = {}
    local favoriteFilterState = 1 -- 1: Semua, 2: Favorit, 3: Bukan Favorit
    local function createFilterButton(text, state)
        local button = Instance.new("TextButton", FilterFrame)
        button.Name = text .. "FilterButton"
        button.Size = UDim2.new(0.33, -5, 1, 0)
        button.BackgroundTransparency = 0.85 
        button.Font = Enum.Font.SourceSansBold
        button.Text = text
        button.TextSize = 12
        local btnCorner = Instance.new("UICorner", button); btnCorner.CornerRadius = UDim.new(0, 4)
        table.insert(filterButtons, {button=button, state=state})
        return button
    end

    -- DIUBAH: Mengatur ulang urutan pembuatan tombol
    local favButton = createFilterButton("Favorite", 2)
    local allButton = createFilterButton("Semua", 1)
    local unfavButton = createFilterButton("Unfavorite", 3)

    local function updateFilterButtons()
        for _, btnInfo in ipairs(filterButtons) do
            local isActive = (btnInfo.state == favoriteFilterState)
            btnInfo.button.BackgroundColor3 = isActive and Color3.fromRGB(90, 150, 255) or Color3.fromRGB(48, 63, 90)
            btnInfo.button.TextColor3 = isActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 190, 210)
        end
    end
    
    local EmoteArea = Instance.new("ScrollingFrame")
    EmoteArea.Name = "EmoteArea"
    EmoteArea.Size = UDim2.new(1, 0, 1, -100)
    EmoteArea.Position = UDim2.new(0, 0, 0, 95)
    EmoteArea.BackgroundTransparency = 1
    EmoteArea.BorderSizePixel = 0
    EmoteArea.ScrollBarImageColor3 = Color3.fromRGB(90, 150, 255)
    EmoteArea.ScrollBarThickness = 5
    EmoteArea.ScrollingDirection = Enum.ScrollingDirection.Y
    EmoteArea.Parent = EmoteMainFrame
    local UIPadding = Instance.new("UIPadding", EmoteArea); UIPadding.PaddingLeft = UDim.new(0, 10); UIPadding.PaddingRight = UDim.new(0, 10); UIPadding.PaddingTop = UDim.new(0, 5); UIPadding.PaddingBottom = UDim.new(0, 10)

    local UIGridLayout = Instance.new("UIGridLayout")
    UIGridLayout.CellPadding = UDim2.new(0, 4, 0, 4) -- Padding kecil
    UIGridLayout.CellSize = UDim2.new(0, 32, 0, 44) -- Ukuran sel kecil
    UIGridLayout.SortOrder = Enum.SortOrder.Name
    UIGridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    UIGridLayout.Parent = EmoteArea
    
    local function populateEmotes(filter)
        filter = filter and filter:lower() or ""
        for _, container in pairs(EmoteArea:GetChildren()) do
            if container:IsA("Frame") and container:FindFirstChild("EmoteImageButton") then
                local isFavorite = favoriteEmotes[container.Name] == true
                local passesSearch = (filter == "" or container.Name:lower():find(filter, 1, true))
                
                local passesFavoriteFilter = false
                if favoriteFilterState == 1 then passesFavoriteFilter = true
                elseif favoriteFilterState == 2 then if isFavorite then passesFavoriteFilter = true end
                elseif favoriteFilterState == 3 then if not isFavorite then passesFavoriteFilter = true end
                end
                
                container.Visible = passesSearch and passesFavoriteFilter
            end
        end
        task.wait()
        EmoteArea.CanvasSize = UDim2.new(0, 0, 0, UIGridLayout.AbsoluteContentSize.Y)
    end
    
    for _, btnInfo in ipairs(filterButtons) do
        btnInfo.button.MouseButton1Click:Connect(function()
            favoriteFilterState = btnInfo.state
            updateFilterButtons()
            loadFavorites() 
            populateEmotes(SearchBox.Text)
        end)
    end
    
    updateFilterButtons()

    local currentTrack, currentAnimId = nil, nil
    local function toggleAnimation(animId)
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("Humanoid") then return end
        local humanoid = char.Humanoid
        if currentTrack and currentAnimId == animId then
            currentTrack:Stop(0.2); currentTrack = nil; currentAnimId = nil; return
        end
        if currentTrack then currentTrack:Stop(0.2) end
        local anim = Instance.new("Animation"); anim.AnimationId = animId
        local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid
        if animator then
            local track = animator:LoadAnimation(anim)
            track:Play(0.1); currentTrack = track; currentAnimId = animId
            track.Stopped:Once(function() if currentTrack == track then currentTrack = nil; currentAnimId = nil end end)
        end
        anim:Destroy()
    end

    local function createEmoteButton(emoteData)
        local container = Instance.new("Frame")
        container.Name = emoteData.name
        container.Size = UDim2.new(0, 32, 0, 44) -- Disesuaikan dengan CellSize
        container.BackgroundTransparency = 1
        container.Parent = EmoteArea

        local button = Instance.new("ImageButton", container)
        button.Name = "EmoteImageButton"
        button.BackgroundColor3 = Color3.fromRGB(48, 63, 90)
        button.BackgroundTransparency = 0.85
        button.Size = UDim2.new(1, 0, 1, 0)
        local corner = Instance.new("UICorner", button); corner.CornerRadius = UDim.new(0, 6)

        local image = Instance.new("ImageLabel", button)
        image.Size = UDim2.new(1, -4, 0, 30) -- Disesuaikan
        image.Position = UDim2.new(0.5, 0, 0, 2)
        image.AnchorPoint = Vector2.new(0.5, 0)
        image.BackgroundTransparency = 1
        image.Image = "rbxthumb://type=Asset&id=" .. tostring(emoteData.id) .. "&w=420&h=420"

        local nameLabel = Instance.new("TextLabel", button)
        nameLabel.Size = UDim2.new(1, -4, 0, 10) -- Disesuaikan
        nameLabel.Position = UDim2.new(0, 2, 1, -11)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.Text = emoteData.name
        nameLabel.TextScaled = true
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)

        button.MouseButton1Click:Connect(function() toggleAnimation(emoteData.animationid) end)

        local starButton = Instance.new("TextButton", container)
        starButton.Name = "FavoriteButton"
        starButton.Size = UDim2.new(0, 16, 0, 16)
        starButton.Position = UDim2.new(1, 0, 0, 0)
        starButton.AnchorPoint = Vector2.new(1, 0)
        starButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        starButton.BackgroundTransparency = 0.85
        starButton.Font = Enum.Font.SourceSansBold
        starButton.Text = "♥"
        starButton.TextSize = 12
        starButton.ZIndex = 2
        local starCorner = Instance.new("UICorner", starButton); starCorner.CornerRadius = UDim.new(0, 4)

        local function updateStarVisual()
            local isFavorite = favoriteEmotes[emoteData.name] == true
            starButton.TextColor3 = isFavorite and Color3.fromRGB(255, 80, 120) or Color3.fromRGB(150, 150, 150)
        end

        starButton.MouseButton1Click:Connect(function()
            favoriteEmotes[emoteData.name] = not favoriteEmotes[emoteData.name]
            saveFavorites()
            updateStarVisual()
            populateEmotes(SearchBox.Text)
        end)
        updateStarVisual()
    end

    task.spawn(function()
        local success, result = pcall(function() return HttpService:JSONDecode(game:HttpGet("https://raw.githubusercontent.com/AREXANS/emoteff/refs/heads/main/emote.json")) end)
        if success and type(result) == "table" then
            local existingEmotes = {}
            for _, emote in pairs(result) do
                if emote.name and emote.animationid and emote.id and not existingEmotes[emote.name:lower()] then
                    createEmoteButton(emote); existingEmotes[emote.name:lower()] = true
                end
            end
        else
            warn("Gagal mengambil daftar emote:", result)
        end
        populateEmotes("")
    end)
    SearchBox:GetPropertyChangedSignal("Text"):Connect(function() populateEmotes(SearchBox.Text) end)
end

-- =============================================================
-- ============ INISIALISASI TOMBOL TOGGLE UTAMA ===============
-- =============================================================

local function createMainToggleButton()
    loadGuiPositions()
    
    local ToggleScreenGui = Instance.new("ScreenGui")
    ToggleScreenGui.Name = "ArexansEmoteStandaloneGUI"
    ToggleScreenGui.Parent = CoreGui
    ToggleScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ToggleScreenGui.DisplayOrder = 10 -- Tampilkan di atas yang lain

    local EmoteToggleButton = Instance.new("TextButton")
    EmoteToggleButton.Name = "EmoteToggleButton"
    EmoteToggleButton.Size = UDim2.new(0, 25, 0, 25) -- Ukuran kecil seperti di Asli
    EmoteToggleButton.Position = UDim2.new(1, -50, 0.5, -20) -- Posisi default
    if loadedGuiPositions and loadedGuiPositions.EmoteToggleButton then
        local posData = loadedGuiPositions.EmoteToggleButton
        pcall(function() 
            EmoteToggleButton.Position = UDim2.new(posData.XScale, posData.XOffset, posData.YScale, posData.YOffset)
        end)
    end
    EmoteToggleButton.BackgroundColor3 = Color3.fromRGB(48, 63, 90)
    EmoteToggleButton.BackgroundTransparency = 0.85
    EmoteToggleButton.Font = Enum.Font.GothamBold
    EmoteToggleButton.Text = "🤡"
    EmoteToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    EmoteToggleButton.TextSize = 24 -- Ukuran font disesuaikan
    EmoteToggleButton.Parent = ToggleScreenGui
    
    local EmoteToggleCorner = Instance.new("UICorner", EmoteToggleButton)
    EmoteToggleCorner.CornerRadius = UDim.new(0, 8)

    local EmoteToggleStroke = Instance.new("UIStroke", EmoteToggleButton)
    EmoteToggleStroke.Color = Color3.fromRGB(90, 150, 255)
    EmoteToggleStroke.Thickness = 1
    EmoteToggleStroke.Transparency = 0.5

    -- Buat tombol ini bisa digeser
    MakeDraggable(EmoteToggleButton, EmoteToggleButton)

    -- Hubungkan klik ke fungsi utama
    EmoteToggleButton.MouseButton1Click:Connect(initializeEmoteGUI)

    -- Bind ke close untuk membersihkan GUI saat game ditutup
    game:BindToClose(function()
        if ToggleScreenGui and ToggleScreenGui.Parent then ToggleScreenGui:Destroy() end
        if EmoteScreenGui and EmoteScreenGui.Parent then EmoteScreenGui:Destroy() end
    end)
end

-- Jalankan skrip
createMainToggleButton()

