--[[
    Arexans Emote System (Standalone)
    Extracted from Arexanstools.lua
    This script provides only the emote functionality.
]]

-- Core Services
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Prevent duplicate GUIs
if game:GetService("CoreGui"):FindFirstChild("EmoteGuiStandalone") then
    game:GetService("CoreGui"):FindFirstChild("EmoteGuiStandalone"):Destroy()
end

-- Draggable Function
local function MakeDraggable(guiObject, dragHandle, isDraggableCheck, clickCallback)
    local dragInput = nil
    local dragStart = nil
    local startPos = nil
    local wasDragged = false

    dragHandle.InputBegan:Connect(function(input)
        if not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then return end
        if dragInput then return end

        if isDraggableCheck and not isDraggableCheck() then
            if clickCallback then
                local timeSinceBegan = tick()
                local endedConn
                endedConn = UserInputService.InputEnded:Connect(function(endInput)
                    if endInput.UserInputType == input.UserInputType then
                        if tick() - timeSinceBegan < 0.2 then
                            clickCallback()
                        end
                        if endedConn then endedConn:Disconnect() end
                    end
                end)
            end
            return
        end
        
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
            if not wasDragged and clickCallback then
                clickCallback()
            end
            if wasDragged and saveGuiPositions then
                pcall(saveGuiPositions)
            end
            dragInput = nil
        end
    end)
end

-- File and Data Management
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

local function saveGuiPositions()
    -- This function will be defined inside the GUI initialization
    -- but we need a placeholder here for the draggable function to see.
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


-- Main Emote GUI Function
local function initializeEmoteGUI()
    local EmoteScreenGui = nil
    
    local function destroyEmoteGUI()
        if EmoteScreenGui and EmoteScreenGui.Parent then
            EmoteScreenGui:Destroy()
        end
        EmoteScreenGui = nil
    end

    destroyEmoteGUI()

    local EmoteList = {}
    local currentTrack = nil
    local currentAnimId = nil
    local favoriteFilterState = 1 -- 1: All, 2: Starred, 3: Not Starred
    loadFavorites()

    local TempEmoteGui = Instance.new("ScreenGui")
    TempEmoteGui.Name = "EmoteGuiStandalone"
    TempEmoteGui.Parent = CoreGui
    TempEmoteGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    TempEmoteGui.DisplayOrder = 10
    EmoteScreenGui = TempEmoteGui

    local EmoteMainFrame = Instance.new("Frame")
    EmoteMainFrame.Name = "MainFrame"
    EmoteMainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    EmoteMainFrame.Size = UDim2.new(0, 160, 0, 180)
    EmoteMainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    
    loadGuiPositions() -- Load positions before applying them
    if loadedGuiPositions and loadedGuiPositions.EmoteFrame then
        local posData = loadedGuiPositions.EmoteFrame
        pcall(function() 
            EmoteMainFrame.Position = UDim2.new(posData.XScale, posData.XOffset, posData.YScale, posData.YOffset)
            EmoteMainFrame.Size = UDim2.new(0, posData.SizeX or 160, 0, posData.SizeY or 180)
        end)
    end
    
    EmoteMainFrame.BackgroundColor3 = Color3.fromRGB(28, 43, 70)
    EmoteMainFrame.BorderColor3 = Color3.fromRGB(90, 150, 255)
    EmoteMainFrame.BorderSizePixel = 1
    EmoteMainFrame.ClipsDescendants = true
    EmoteMainFrame.Parent = TempEmoteGui
    EmoteMainFrame.Visible = true -- Make it visible by default

    local UICorner = Instance.new("UICorner", EmoteMainFrame)
    UICorner.CornerRadius = UDim.new(0, 8)

    local Header = Instance.new("TextButton") 
    Header.Name = "Header"
    Header.Size = UDim2.new(1, 0, 0, 30)
    Header.BackgroundColor3 = Color3.fromRGB(48, 63, 90)
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
    CloseButton.MouseButton1Click:Connect(destroyEmoteGUI)
    
    MakeDraggable(EmoteMainFrame, Header, function() return true end, nil)
    
    -- Redefine saveGuiPositions to work within this scope
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
        pcall(function()
            local jsonData = HttpService:JSONEncode(guiDataToSave)
            writefile(GUI_POSITIONS_SAVE_FILE, jsonData)
        end)
    end

    local EmoteResizeHandle = Instance.new("TextButton")
    EmoteResizeHandle.Name = "EmoteResizeHandle"
    EmoteResizeHandle.Text = ""
    EmoteResizeHandle.Size = UDim2.new(0, 15, 0, 15)
    EmoteResizeHandle.Position = UDim2.new(1, -15, 1, -15)
    EmoteResizeHandle.BackgroundColor3 = Color3.fromRGB(90, 150, 255)
    EmoteResizeHandle.BackgroundTransparency = 0.5
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
    local function createFilterButton(text, state)
        local button = Instance.new("TextButton", FilterFrame)
        button.Name = text .. "FilterButton"
        button.Size = UDim2.new(0.33, -5, 1, 0)
        button.Font = Enum.Font.SourceSansBold
        button.Text = text
        button.TextSize = 12
        local btnCorner = Instance.new("UICorner", button); btnCorner.CornerRadius = UDim.new(0, 4)
        table.insert(filterButtons, {button=button, state=state})
        return button
    end

    local allButton = createFilterButton("[Semua]", 1)
    local favButton = createFilterButton("[Favorite]", 2)
    local unfavButton = createFilterButton("[Unfavorite]", 3)

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
    UIGridLayout.CellPadding = UDim2.new(0, 4, 0, 4)
    UIGridLayout.CellSize = UDim2.new(0, 32, 0, 44)
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
                if favoriteFilterState == 1 then -- Semua
                    passesFavoriteFilter = true
                elseif favoriteFilterState == 2 then -- Hanya Favorit
                    if isFavorite then
                        passesFavoriteFilter = true
                    end
                elseif favoriteFilterState == 3 then -- Hanya Tidak Favorit
                    if not isFavorite then
                        passesFavoriteFilter = true
                    end
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
        container.Size = UDim2.new(0, 36, 0, 50)
        container.BackgroundTransparency = 1
        container.Parent = EmoteArea

        local button = Instance.new("ImageButton", container)
        button.Name = "EmoteImageButton"
        button.BackgroundColor3 = Color3.fromRGB(48, 63, 90)
        button.Size = UDim2.new(1, 0, 1, 0)
        local corner = Instance.new("UICorner", button); corner.CornerRadius = UDim.new(0, 6)

        local image = Instance.new("ImageLabel", button)
        image.Size = UDim2.new(1, -4, 0, 32)
        image.Position = UDim2.new(0.5, 0, 0, 3)
        image.AnchorPoint = Vector2.new(0.5, 0)
        image.BackgroundTransparency = 1
        image.Image = "rbxthumb://type=Asset&id=" .. tostring(emoteData.id) .. "&w=420&h=420"

        local nameLabel = Instance.new("TextLabel", button)
        nameLabel.Size = UDim2.new(1, -4, 0, 12)
        nameLabel.Position = UDim2.new(0, 2, 0, 36)
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
        starButton.BackgroundTransparency = 0.5
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
            if favoriteEmotes[emoteData.name] then
                favoriteEmotes[emoteData.name] = nil
            else
                favoriteEmotes[emoteData.name] = true
            end
            saveFavorites()
            updateStarVisual()
            populateEmotes(SearchBox.Text)
        end)

        updateStarVisual()
        return container
    end

    task.spawn(function()
        local success, result = pcall(function() return HttpService:JSONDecode(game:HttpGet("https://raw.githubusercontent.com/AREXANS/emoteff/refs/heads/main/emote.json")) end)
        if success and type(result) == "table" then
            EmoteList = result; local existingEmotes = {}
            for _, emote in pairs(EmoteList) do
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

    EmoteArea:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        if EmoteArea.CanvasPosition.Y < -30 then
            pcall(function()
                loadFavorites()
                populateEmotes(SearchBox and SearchBox.Text or "")
            end)
        end
    end)
end

-- Run the GUI
initializeEmoteGUI()