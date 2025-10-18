--[[
    ArexansTools - Modul Tab Rekaman
    Deskripsi: Berisi semua UI dan logika untuk fitur perekaman dan pemutaran ulang.
    Modul ini mengembalikan sebuah fungsi yang menerima tabel 'shared' berisi dependensi
    dan mengembalikan fungsi 'setup' untuk menginisialisasi tab.
--]]

return function(shared)
    -- Mengimpor dependensi dari skrip utama
    local CoreGui = shared.CoreGui
    local RunService = shared.RunService
    local Players = shared.Players
    local LocalPlayer = shared.LocalPlayer
    local UserInputService = shared.UserInputService
    local HttpService = shared.HttpService
    local TweenService = shared.TweenService
    local Workspace = shared.Workspace

    -- Mengimpor fungsi utilitas dari skrip utama
    local createButton = shared.createButton
    local createToggle = shared.createToggle
    local createSlider = shared.createSlider
    local showNotification = shared.showNotification
    local showGenericRenamePrompt = shared.showGenericRenamePrompt
    local showConfirmationPrompt = shared.showConfirmationPrompt
    local promptInput = shared.promptInput
    local showRecordingFilePicker = shared.showRecordingFilePicker

    -- Variabel status khusus untuk modul ini
    local isRecording = false
    local isPlaying = false
    local isPaused = false
    local recordingConnection = nil
    local playbackConnection = nil
    local savedRecordings = {}
    local currentRecordingData = {}
    local currentRecordingTarget = nil
    local selectedRecordings = {}
    local isAnimationBypassEnabled = false
    local originalPlaybackWalkSpeed = 16
    local playbackMovers = {}
	local IsPlaybackActive = false
	local savedAnimateDisabled = nil

    -- Variabel UI (akan diinisialisasi di dalam setup)
    local recStatusLabel, recordButton, playButton, recordingsListFrame

    -- Deklarasi fungsi di awal
    local updateRecordingsList, startRecording, stopRecording, stopPlayback, playSingleRecording, playSequence, stopActions

    local function saveRecordingsData()
        if not shared.writefile then return end
        pcall(function()
            local jsonData = HttpService:JSONEncode(savedRecordings)
            shared.writefile(shared.RECORDING_SAVE_FILE, jsonData)
        end)
    end

    local function loadRecordingsData()
        if not shared.readfile or not shared.isfile or not shared.isfile(shared.RECORDING_SAVE_FILE) then return end
        local success, result = pcall(function()
            local fileContent = shared.readfile(shared.RECORDING_SAVE_FILE)
            local decodedData = HttpService:JSONDecode(fileContent)
            if type(decodedData) == "table" then
                savedRecordings = decodedData
            end
            if updateRecordingsList then
                updateRecordingsList()
            end
        end)
        if not success then
            warn("Gagal memuat data rekaman:", result)
        end
    end

    updateRecordingsList = function()
        if not recordingsListFrame then return end
        local scrollPos = recordingsListFrame.CanvasPosition
        for _, child in ipairs(recordingsListFrame:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end

        local sortedNames = {}
        for name in pairs(savedRecordings) do table.insert(sortedNames, name) end
        table.sort(sortedNames)

        for _, recName in ipairs(sortedNames) do
            local isSelected = selectedRecordings[recName] or false

            local itemFrame = Instance.new("Frame")
            itemFrame.Name = recName; itemFrame.Size = UDim2.new(1, 0, 0, 22); itemFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35); itemFrame.BackgroundTransparency = isSelected and 0 or 0.3; itemFrame.BorderSizePixel = 0; itemFrame.Parent = recordingsListFrame
            local itemCorner = Instance.new("UICorner", itemFrame); itemCorner.CornerRadius = UDim.new(0, 4)
            local itemLayout = Instance.new("UIListLayout", itemFrame); itemLayout.FillDirection = Enum.FillDirection.Horizontal; itemLayout.VerticalAlignment = Enum.VerticalAlignment.Center; itemLayout.Padding = UDim.new(0, 5)
            local itemPadding = Instance.new("UIPadding", itemFrame); itemPadding.PaddingLeft = UDim.new(0, 5)

            local nameButton = Instance.new("TextButton"); nameButton.Size = UDim2.new(1, -30, 1, 0); nameButton.BackgroundTransparency = 1; nameButton.Font = isSelected and Enum.Font.SourceSansBold or Enum.Font.SourceSans; nameButton.Text = recName; nameButton.TextColor3 = isSelected and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(220, 220, 220); nameButton.TextSize = 12; nameButton.TextXAlignment = Enum.TextXAlignment.Left; nameButton.Parent = itemFrame

            local renameButton = Instance.new("TextButton"); renameButton.Size = UDim2.new(0, 20, 0, 18); renameButton.BackgroundColor3 = Color3.fromRGB(50, 150, 200); renameButton.Font = Enum.Font.SourceSansBold; renameButton.Text = "✏️"; renameButton.TextColor3 = Color3.fromRGB(255, 255, 255); renameButton.TextSize = 12; renameButton.Parent = itemFrame
            local renameCorner = Instance.new("UICorner", renameButton); renameCorner.CornerRadius = UDim.new(0, 4)

            local function toggleSelection()
                selectedRecordings[recName] = not selectedRecordings[recName]
                updateRecordingsList()
            end

            nameButton.MouseButton1Click:Connect(toggleSelection)

            renameButton.MouseButton1Click:Connect(function()
                showGenericRenamePrompt(recName, function(newName)
                    if newName and newName ~= "" and not savedRecordings[newName] then
                        savedRecordings[newName] = savedRecordings[recName]; savedRecordings[recName] = nil
                        if selectedRecordings[recName] then
                            selectedRecordings[recName] = nil
                            selectedRecordings[newName] = true
                        end
                        saveRecordingsData()
                        recStatusLabel.Text = "Nama diubah menjadi " .. newName; updateRecordingsList()
                    else
                        recStatusLabel.Text = "Nama tidak valid atau sudah ada."
                    end
                end)
            end)
        end
        recordingsListFrame.CanvasPosition = scrollPos
    end

    startRecording = function(targetPlayer)
        if isRecording then return end

        targetPlayer = targetPlayer or LocalPlayer
        currentRecordingTarget = targetPlayer

        local char = targetPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")

        if not (hrp and humanoid) then
            recStatusLabel.Text = "Karakter target tidak ditemukan."
            currentRecordingTarget = nil
            return
        end

        isRecording = true
        currentRecordingData = {}
        local startTime = tick()
        recStatusLabel.Text = "Merekam: " .. targetPlayer.DisplayName .. " 🔴"

        recordButton.Text = "⏹️"
        recordButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)

        local lastPosition = hrp.Position
        local TELEPORT_THRESHOLD = 50

        recordingConnection = RunService.Heartbeat:Connect(function()
            if not isRecording then return end

            char = currentRecordingTarget and currentRecordingTarget.Character
            hrp = char and char:FindFirstChild("HumanoidRootPart")
            humanoid = char and char:FindFirstChildOfClass("Humanoid")
            if not (hrp and humanoid and humanoid.Health > 0) then
                recStatusLabel.Text = "Target hilang, perekaman dihentikan."
                stopActions()
                return
            end

            local currentCFrame = hrp.CFrame
            local currentPosition = currentCFrame.Position
            local distance = (currentPosition - lastPosition).Magnitude

            local frameData = {
                time = tick() - startTime,
                cframe = {currentCFrame:GetComponents()},
                state = tostring(humanoid:GetState()),
                anims = {}
            }

            if distance > TELEPORT_THRESHOLD then
                frameData.isTeleport = true
            end

            for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
                table.insert(frameData.anims, {id = track.Animation.AnimationId, time = track.TimePosition})
            end

            table.insert(currentRecordingData, frameData)
            lastPosition = currentPosition
        end)
    end

    local cleanupSinglePlayback

    stopRecording = function()
        if not isRecording then return end
        isRecording = false
        if recordingConnection then recordingConnection:Disconnect(); recordingConnection = nil end

        if #currentRecordingData > 1 then
            local baseName = (currentRecordingTarget and currentRecordingTarget.Name ~= LocalPlayer.Name) and "Rekaman " .. currentRecordingTarget.Name or "Rekaman Diri"
            local newName, i = baseName .. " 1", 1
            while savedRecordings[newName] do i += 1; newName = baseName .. " " .. i end

            local recordingObject = {
                frames = currentRecordingData,
                targetUserId = currentRecordingTarget.UserId
            }
            savedRecordings[newName] = recordingObject

            saveRecordingsData()
            recStatusLabel.Text = "Rekaman disimpan sebagai: " .. newName
            updateRecordingsList()
        else
            recStatusLabel.Text = "Perekaman dibatalkan (terlalu singkat)."
        end
        currentRecordingData = {}
        currentRecordingTarget = nil

        recordButton.Text = "🔴"
        recordButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    end

    cleanupSinglePlayback = function(isSequence)
        isSequence = isSequence or false
        if playbackMovers.guidePart and playbackMovers.guidePart.Parent then
            playbackMovers.guidePart:Destroy()
        end
        if playbackMovers.attachment and playbackMovers.attachment.Parent then
            playbackMovers.attachment:Destroy()
        end
        playbackMovers = {}

        local char = LocalPlayer.Character
        if char then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = originalPlaybackWalkSpeed
                humanoid.PlatformStand = false
                if not isSequence then
                    for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
                        track:Stop(0.1)
                    end
                end
            end

            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local customRunningSound = hrp:FindFirstChild("CustomRunningSound")
                if customRunningSound then customRunningSound:Destroy() end
                pcall(function() hrp.Velocity = Vector3.new(0,0,0) end)
                pcall(function() hrp.Anchored = false end)
            end
            if humanoid then
                pcall(function() humanoid.AutoRotate = true end)
                pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
            end
        end
    end

    stopPlayback = function(isSequence)
        if not isPlaying and not isPaused then return end
        isPlaying = false
        isPaused = false
        if playbackConnection then
            playbackConnection:Disconnect()
            playbackConnection = nil
        end

        cleanupSinglePlayback(isSequence)

        playButton.Text = "▶️"
        playButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)

        if not isRecording then
            recStatusLabel.Text = "Pemutaran ulang dihentikan."
        end
    end

    stopActions = function()
        if isRecording then stopRecording() end
        if isPlaying or isPaused then stopPlayback() end
    end

    playSingleRecording = function(recordingObject, onComplete)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if not (hrp and humanoid) then if onComplete then onComplete() end; return end

        originalPlaybackWalkSpeed = humanoid.WalkSpeed
		IsPlaybackActive = true
		local animateScript = char and char:FindFirstChild("Animate")
		if animateScript then
			savedAnimateDisabled = animateScript.Disabled
			pcall(function() animateScript.Disabled = false end)
		end

        local recordingData = recordingObject.frames or recordingObject
        if not recordingData or #recordingData < 1 then if onComplete then onComplete() end; return end

        local recordingDuration = recordingData[#recordingData].time
        if recordingDuration <= 0 then if onComplete then onComplete() end; return end

        local animationCache = {}
        playbackMovers = {}

        pcall(function()
            local attachment = Instance.new("Attachment", hrp); attachment.Name = "ReplayAttachment"
            local alignPos = Instance.new("AlignPosition", attachment); alignPos.Attachment0 = attachment; alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment; alignPos.Responsiveness = 200; alignPos.MaxForce = 100000
            local alignOrient = Instance.new("AlignOrientation", attachment); alignOrient.Attachment0 = attachment; alignOrient.Mode = Enum.OrientationAlignmentMode.OneAttachment; alignOrient.Responsiveness = 200; alignOrient.MaxTorque = 100000
            playbackMovers.attachment = attachment; playbackMovers.alignPos = alignPos; playbackMovers.alignOrient = alignOrient
        end)

        if isAnimationBypassEnabled then
            pcall(function()
                local guidePart = Instance.new("Part"); guidePart.Name = "PlaybackGuidePart"; guidePart.Size = Vector3.new(1,1,1); guidePart.Transparency = 1; guidePart.CanCollide = false; guidePart.Anchored = true; guidePart.Parent = workspace
                playbackMovers.guidePart = guidePart
            end)
        end

        local soundJumping, soundLanding, customRunningSound
        pcall(function()
            soundJumping = hrp:FindFirstChild("Jumping"); soundLanding = hrp:FindFirstChild("FreeFalling"); customRunningSound = Instance.new("Sound", hrp); customRunningSound.Name = "CustomRunningSound"; customRunningSound.Looped = true
            local originalRunningSound = hrp:FindFirstChild("Running")
            if originalRunningSound and originalRunningSound:IsA("Sound") then customRunningSound.SoundId = originalRunningSound.SoundId; customRunningSound.Volume = originalRunningSound.Volume; customRunningSound.Pitch = originalRunningSound.Pitch
            else customRunningSound.SoundId = "rbxassetid://122226169" end
        end)

        local lastPlayerState = "Idle"; local loopStartTime = tick(); local lastFrameIndex = 1; local wasPaused = false

        playbackConnection = RunService.RenderStepped:Connect(function(dt)
            if not isPlaying then if playbackConnection then playbackConnection:Disconnect(); playbackConnection = nil end; return end

            if isPaused then
                if not wasPaused then
                    if playbackMovers.alignPos then playbackMovers.alignPos.MaxForce = 0 end
                    if playbackMovers.alignOrient then playbackMovers.alignOrient.MaxTorque = 0 end
                    if customRunningSound and customRunningSound.IsPlaying then customRunningSound:Stop() end
                    for id, track in pairs(animationCache) do if track.IsPlaying then track:Stop(0.1) end end
                    wasPaused = true
                end
                loopStartTime = loopStartTime + dt
                return
            end

            if wasPaused then
                if playbackMovers.alignPos then playbackMovers.alignPos.MaxForce = 100000 end
                if playbackMovers.alignOrient then playbackMovers.alignOrient.MaxTorque = 100000 end
                wasPaused = false
            end

            local elapsedTime = tick() - loopStartTime

            if elapsedTime >= recordingDuration then
                if playbackConnection then playbackConnection:Disconnect(); playbackConnection = nil end
                cleanupSinglePlayback(onComplete ~= nil)
                if onComplete then onComplete() end
                return
            end

            local frameToPlay, currentFrame
            for i = lastFrameIndex, #recordingData do
                if recordingData[i].time >= elapsedTime then
                    frameToPlay = recordingData[i]; currentFrame = recordingData[i-1] or recordingData[1]; lastFrameIndex = i; break
                end
            end

            if not frameToPlay then frameToPlay = recordingData[#recordingData]; currentFrame = recordingData[#recordingData] end

            local cframeToPlay = CFrame.new(unpack(frameToPlay.cframe)); local cframeCurrent = CFrame.new(unpack(currentFrame.cframe))

            local velocity = 0; local timeDelta = frameToPlay.time - currentFrame.time
            if timeDelta > 0.001 then local distanceDelta = (cframeToPlay.Position - cframeCurrent.Position).Magnitude; velocity = distanceDelta / timeDelta end

            local interpolatedCFrame
            if frameToPlay.isTeleport then
                if not isAnimationBypassEnabled then hrp.CFrame = cframeToPlay end
                interpolatedCFrame = cframeToPlay; loopStartTime = tick() - frameToPlay.time
            else
                local alpha = (elapsedTime - currentFrame.time) / (frameToPlay.time - currentFrame.time); alpha = math.clamp(alpha, 0, 1)
                interpolatedCFrame = cframeCurrent:Lerp(cframeToPlay, alpha)
            end

            local currentState = currentFrame.state

            if not isAnimationBypassEnabled then
                if playbackMovers.alignPos then
                    playbackMovers.alignPos.Position = interpolatedCFrame.Position
                    playbackMovers.alignOrient.CFrame = interpolatedCFrame
                end
                humanoid.WalkSpeed = originalPlaybackWalkSpeed

                local animFrame = currentFrame; local requiredAnims = {}; local runAnimId = shared.lastAnimations.Run
                local animationSpeed = velocity / (originalPlaybackWalkSpeed > 0 and originalPlaybackWalkSpeed or 16)

                for _, animData in ipairs(animFrame.anims) do
                    requiredAnims[animData.id] = animData.time
                    if not animationCache[animData.id] then local anim = Instance.new("Animation"); anim.AnimationId = animData.id; animationCache[animData.id] = humanoid:LoadAnimation(anim) end
                    local track = animationCache[animData.id]
                    if not track.IsPlaying then track:Play(0.1) end

                    if animData.id == runAnimId and velocity > 1 then track:AdjustSpeed(animationSpeed) else track:AdjustSpeed(1) end
                    track.TimePosition = animData.time
                end
                for id, track in pairs(animationCache) do if not requiredAnims[id] and track.IsPlaying then track:Stop(0.1) end end
            else
                if playbackMovers.alignPos then
                    playbackMovers.alignPos.MaxForce = 100000; playbackMovers.alignOrient.MaxTorque = 100000
                    playbackMovers.alignPos.Position = interpolatedCFrame.Position; playbackMovers.alignOrient.CFrame = interpolatedCFrame
                end
                if next(animationCache) then
                    for id, track in pairs(animationCache) do if track.IsPlaying then track:Stop(0) end; animationCache[id] = nil end
                end
            end

            pcall(function()
                if currentState and currentState ~= lastPlayerState then
                    local stateName = currentState:match("Enum.HumanoidStateType%.(.*)")
                    if stateName and Enum.HumanoidStateType[stateName] then humanoid:ChangeState(Enum.HumanoidStateType[stateName]) end
                    if currentState == "Enum.HumanoidStateType.Jumping" and soundJumping then soundJumping:Play() end
                    if lastPlayerState == "Enum.HumanoidStateType.Freefall" and currentState ~= "Enum.HumanoidStateType.Jumping" and soundLanding then soundLanding:Play() end
                end
                if customRunningSound then
                    local isRunning = (currentState == "Enum.HumanoidStateType.Running" or currentState == "Enum.HumanoidStateType.RunningNoPhysics")
                    if isRunning and velocity > 1 and not customRunningSound.IsPlaying then customRunningSound.PlaybackSpeed = velocity / (originalPlaybackWalkSpeed > 0 and originalPlaybackWalkSpeed or 16); customRunningSound:Play()
                    elseif (not isRunning or velocity <= 1) and customRunningSound.IsPlaying then customRunningSound:Stop() end
                end
                lastPlayerState = currentState
            end)
        end)
    end

    playSequence = function(replayCountBox)
        if isPlaying then return end

        local sortedNames = {}; for name in pairs(savedRecordings) do table.insert(sortedNames, name) end; table.sort(sortedNames)

        local sequenceToPlay = {}; for _, recName in ipairs(sortedNames) do if selectedRecordings[recName] then table.insert(sequenceToPlay, {name=recName, data=savedRecordings[recName]}) end end

        if #sequenceToPlay == 0 then recStatusLabel.Text = "Pilih rekaman untuk diputar."; return end

        local countText = replayCountBox.Text; local replayCount = tonumber(countText)
        if countText == "" or countText == "0" then replayCount = math.huge elseif not replayCount or replayCount < 1 then replayCount = 1 end

        isPlaying = true; isPaused = false; playButton.Text = "⏸️"; playButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)

        local currentPlayRun = 1; local currentSequenceIndex = 1

        local function playNextInSequence()
            if not isPlaying then stopPlayback(); return end
            while isPaused do if not isPlaying then stopPlayback(); return end; task.wait(0.1) end

            if currentSequenceIndex > #sequenceToPlay then
                currentPlayRun = currentPlayRun + 1
                if currentPlayRun > replayCount then stopPlayback(); recStatusLabel.Text = "Pemutaran sekuens selesai."; return end
                currentSequenceIndex = 1; recStatusLabel.Text = string.format("Memutar sekuens: %d/%s", currentPlayRun, tostring(replayCount) == "inf" and "∞" or tostring(replayCount))
            end

            local item = sequenceToPlay[currentSequenceIndex]
            recStatusLabel.Text = string.format("Memutar: %s (%d/%d)", item.name, currentSequenceIndex, #sequenceToPlay)

            playSingleRecording(item.data, function()
                currentSequenceIndex = currentSequenceIndex + 1
                task.wait(0.1)
                playNextInSequence()
            end)
        end

        recStatusLabel.Text = string.format("Memutar sekuens: %d/%s", currentPlayRun, tostring(replayCount) == "inf" and "∞" or tostring(replayCount))
        playNextInSequence()
    end

    -- Fungsi utama untuk membangun UI tab
    local function setup(parentFrame)
        local controlsContainer = Instance.new("Frame"); controlsContainer.Name = "ControlsContainer"; controlsContainer.Size = UDim2.new(1, 0, 0, 155); controlsContainer.Position = UDim2.new(0, 0, 0, 0); controlsContainer.BackgroundTransparency = 1; controlsContainer.Parent = parentFrame
        local controlsLayout = Instance.new("UIListLayout", controlsContainer); controlsLayout.Padding = UDim.new(0, 5); controlsLayout.SortOrder = Enum.SortOrder.LayoutOrder; controlsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

        recordingsListFrame = Instance.new("ScrollingFrame"); recordingsListFrame.Name = "RecordingsListFrame"; recordingsListFrame.Position = UDim2.new(0, 0, 0, controlsContainer.Size.Y.Offset + 5); recordingsListFrame.Size = UDim2.new(1, 0, 1, -(controlsContainer.Size.Y.Offset + 10)); recordingsListFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25); recordingsListFrame.BackgroundTransparency = 0.5; recordingsListFrame.BorderSizePixel = 0; recordingsListFrame.CanvasSize = UDim2.new(0, 0, 0, 0); recordingsListFrame.ScrollBarThickness = 6; recordingsListFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 150, 255); recordingsListFrame.ScrollingDirection = Enum.ScrollingDirection.Y; recordingsListFrame.Parent = parentFrame
        local recListLayout = Instance.new("UIListLayout", recordingsListFrame); recListLayout.Padding = UDim.new(0, 5); recListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; recListLayout.SortOrder = Enum.SortOrder.Name
        local recListPadding = Instance.new("UIPadding", recordingsListFrame); recListPadding.PaddingTop = UDim.new(0, 5); recListPadding.PaddingBottom = UDim.new(0, 5); recListPadding.PaddingLeft = UDim.new(0,5); recListPadding.PaddingRight = UDim.new(0,5)
        recListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            local newY = math.max(recordingsListFrame.AbsoluteSize.Y, recListLayout.AbsoluteContentSize.Y + 10)
            recordingsListFrame.CanvasSize = UDim2.new(0, 0, 0, newY)
        end)

        local function createIconButton(parent, iconText, color, size)
            local btn = Instance.new("TextButton", parent); btn.Size = UDim2.new(0, size, 0, size); btn.BackgroundColor3 = color; btn.Font = Enum.Font.SourceSansBold; btn.Text = iconText; btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.TextSize = 12; local corner = Instance.new("UICorner", btn); corner.CornerRadius = UDim.new(0, 5); local stroke = Instance.new("UIStroke", btn); stroke.Color = Color3.fromRGB(255,255,255); stroke.Transparency = 0.8; stroke.Thickness = 1; return btn
        end

        local controlButtonsFrame = Instance.new("Frame", controlsContainer); controlButtonsFrame.Name = "ControlButtonsFrame"; controlButtonsFrame.Size = UDim2.new(1, 0, 0, 35); controlButtonsFrame.BackgroundTransparency = 1; controlButtonsFrame.LayoutOrder = 1
        local controlLayout = Instance.new("UIListLayout", controlButtonsFrame); controlLayout.FillDirection = Enum.FillDirection.Horizontal; controlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; controlLayout.VerticalAlignment = Enum.VerticalAlignment.Center; controlLayout.Padding = UDim.new(0, 5)

        local importButton = createIconButton(controlButtonsFrame, "📥", Color3.fromRGB(50, 150, 200), 22)
        recordButton = createIconButton(controlButtonsFrame, "🔴", Color3.fromRGB(200, 50, 50), 22)
        local exportButton = createIconButton(controlButtonsFrame, "📤", Color3.fromRGB(50, 150, 200), 22)

        local topButtonsFrame = Instance.new("Frame", controlsContainer); topButtonsFrame.Name = "TopButtonsFrame"; topButtonsFrame.Size = UDim2.new(1, 0, 0, 28); topButtonsFrame.BackgroundTransparency = 1; topButtonsFrame.LayoutOrder = 4
        local topButtonsLayout = Instance.new("UIListLayout", topButtonsFrame); topButtonsLayout.FillDirection = Enum.FillDirection.Horizontal; topButtonsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; topButtonsLayout.VerticalAlignment = Enum.VerticalAlignment.Center; topButtonsLayout.Padding = UDim.new(0, 8)

        local selectAllButton = createIconButton(topButtonsFrame, "☑️", Color3.fromRGB(120, 120, 120), 24)
        playButton = createIconButton(topButtonsFrame, "▶️", Color3.fromRGB(0, 150, 255), 24)
        local stopButton = createIconButton(topButtonsFrame, "⏹️", Color3.fromRGB(200, 80, 80), 24)
        local deleteSelectedButton = createIconButton(topButtonsFrame, "🗑️", Color3.fromRGB(200, 50, 50), 24)

        importButton.MouseButton1Click:Connect(function()
            showRecordingFilePicker(shared.RECORDING_FOLDER, function(importName)
                if not importName or importName == "" then return end
                local RECORDING_IMPORT_FILE = shared.RECORDING_FOLDER .. "/" .. importName .. ".json"
                if not shared.isfile or not shared.isfile(RECORDING_IMPORT_FILE) then showNotification("File '" .. importName .. ".json' tidak ditemukan.", Color3.fromRGB(200, 150, 50)); return end
                local success, content = pcall(shared.readfile, RECORDING_IMPORT_FILE)
                if not success or not content then showNotification("Gagal membaca file impor.", Color3.fromRGB(200, 50, 50)); return end
                local success, decodedData = pcall(HttpService.JSONDecode, HttpService, content)
                if not success or type(decodedData) ~= "table" then showNotification("Data impor rekaman tidak valid!", Color3.fromRGB(200, 50, 50)); return end
                local importedCount = 0
                for recName, recData in pairs(decodedData) do
                    if not savedRecordings[recName] and type(recData) == "table" then savedRecordings[recName] = recData; importedCount = importedCount + 1 end
                end
                if importedCount > 0 then saveRecordingsData(); updateRecordingsList(); showNotification(importedCount .. " rekaman berhasil diimpor!", Color3.fromRGB(50, 200, 50)); pcall(shared.renamefile, RECORDING_IMPORT_FILE, RECORDING_IMPORT_FILE:gsub(".json", "_imported_" .. os.time() .. ".json"))
                else showNotification("Tidak ada rekaman baru untuk diimpor.", Color3.fromRGB(200, 150, 50)) end
            end)
        end)

        selectAllButton.MouseButton1Click:Connect(function()
            local totalRecordings = 0; local selectedCount = 0
            for _ in pairs(savedRecordings) do totalRecordings = totalRecordings + 1 end
            for _, selected in pairs(selectedRecordings) do if selected then selectedCount = selectedCount + 1 end end
            if selectedCount < totalRecordings then for recName in pairs(savedRecordings) do selectedRecordings[recName] = true end
            else selectedRecordings = {} end
            updateRecordingsList()
        end)

        exportButton.MouseButton1Click:Connect(function()
            if not shared.writefile then showNotification("Executor tidak mendukung penyimpanan file!", Color3.fromRGB(200, 50, 50)); return end
            local toExport = {}; local selectionCount = 0
            for name, selected in pairs(selectedRecordings) do if selected then toExport[name] = savedRecordings[name]; selectionCount = selectionCount + 1 end end
            if selectionCount == 0 then showNotification("Pilih rekaman untuk diekspor.", Color3.fromRGB(200, 150, 50)); return end
            local success, jsonData = pcall(HttpService.JSONEncode, HttpService, toExport)
            if not success then showNotification("Gagal meng-encode data rekaman!", Color3.fromRGB(200, 50, 50)); return end
            local exportName = promptInput("Masukkan nama file export (tanpa .json):")
            if not exportName or exportName == "" then showNotification("Nama file tidak boleh kosong.", Color3.fromRGB(200, 50, 50)); return end
            local RECORDING_EXPORT_FILE = shared.RECORDING_FOLDER .. "/" .. exportName .. ".json"
            local writeSuccess, writeError = pcall(shared.writefile, RECORDING_EXPORT_FILE, jsonData)
            if writeSuccess then showNotification(selectionCount .. " rekaman diekspor ke folder Rekaman.", Color3.fromRGB(50, 200, 50))
            else showNotification("Gagal mengekspor data rekaman!", Color3.fromRGB(200, 50, 50)); warn("Export Error:", writeError) end
        end)

        local replayOptionsFrame = Instance.new("Frame", controlsContainer); replayOptionsFrame.Name = "ReplayOptionsFrame"; replayOptionsFrame.Size = UDim2.new(1, 0, 0, 25); replayOptionsFrame.BackgroundTransparency = 1; replayOptionsFrame.LayoutOrder = 2
        local replayOptionsLayout = Instance.new("UIListLayout", replayOptionsFrame); replayOptionsLayout.FillDirection = Enum.FillDirection.Horizontal; replayOptionsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        local replayLabel = Instance.new("TextLabel", replayOptionsFrame); replayLabel.Name = "ReplayLabel"; replayLabel.Size = UDim2.new(0.7, -5, 1, 0); replayLabel.BackgroundTransparency = 1; replayLabel.Font = Enum.Font.SourceSans; replayLabel.Text = "Jumlah Ulang (0 = ∞):"; replayLabel.TextColor3 = Color3.fromRGB(200, 200, 200); replayLabel.TextSize = 12; replayLabel.TextXAlignment = Enum.TextXAlignment.Left
        local replayCountBox = Instance.new("TextBox", replayOptionsFrame); replayCountBox.Name = "ReplayCountBox"; replayCountBox.Size = UDim2.new(0.3, 0, 1, 0); replayCountBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35); replayCountBox.Font = Enum.Font.SourceSans; replayCountBox.Text = "1"; replayCountBox.PlaceholderText = "1"; replayCountBox.TextColor3 = Color3.fromRGB(220, 220, 220); replayCountBox.TextSize = 12; replayCountBox.ClearTextOnFocus = false
        local boxCorner = Instance.new("UICorner", replayCountBox); boxCorner.CornerRadius = UDim.new(0, 4)
        replayCountBox:GetPropertyChangedSignal("Text"):Connect(function() replayCountBox.Text = replayCountBox.Text:gsub("%D", "") end)

        local bypassAnimToggle, bypassAnimSwitch = createToggle(controlsContainer, "Bypass Animasi", isAnimationBypassEnabled, function(v)
            isAnimationBypassEnabled = v
            if v and LocalPlayer.Character then
                shared.applyAllAnimations(LocalPlayer.Character)
                showNotification("Bypass menggunakan set animasi kustom Anda.", Color3.fromRGB(50, 150, 255))
            end
        end)
        bypassAnimToggle.LayoutOrder = 3

        recStatusLabel = Instance.new("TextLabel", controlsContainer); recStatusLabel.Name = "StatusLabel"; recStatusLabel.Size = UDim2.new(1, 0, 0, 20); recStatusLabel.BackgroundTransparency = 1; recStatusLabel.Font = Enum.Font.SourceSansItalic; recStatusLabel.Text = "Siap."; recStatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180); recStatusLabel.TextSize = 12; recStatusLabel.LayoutOrder = 5

        recordButton.MouseButton1Click:Connect(function()
            if isRecording then stopRecording() else
                if shared.IsViewingPlayer and shared.currentlyViewedPlayer then startRecording(shared.currentlyViewedPlayer)
                else startRecording(LocalPlayer) end
            end
        end)

        playButton.MouseButton1Click:Connect(function()
            if isPlaying then
                isPaused = not isPaused
                if isPaused then playButton.Text = "▶️"; playButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255); recStatusLabel.Text = "Pemutaran dijeda."
                else playButton.Text = "⏸️"; playButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80); recStatusLabel.Text = "Melanjutkan pemutaran..." end
            else playSequence(replayCountBox) end
        end)

        stopButton.MouseButton1Click:Connect(function() if isPlaying or isPaused then stopPlayback() end end)

        deleteSelectedButton.MouseButton1Click:Connect(function()
            local deletedCount = 0
            for recName, isSelected in pairs(selectedRecordings) do
                if isSelected then savedRecordings[recName] = nil; deletedCount = deletedCount + 1 end
            end
            if deletedCount > 0 then selectedRecordings = {}; saveRecordingsData(); updateRecordingsList(); recStatusLabel.Text = "Berhasil menghapus " .. deletedCount .. " rekaman."; showNotification("Berhasil menghapus " .. deletedCount .. " rekaman.", Color3.fromRGB(50, 200, 50))
            else recStatusLabel.Text = "Tidak ada rekaman yang dipilih untuk dihapus."; showNotification("Tidak ada rekaman yang dipilih.", Color3.fromRGB(200, 150, 50)) end
        end)

        -- Memuat data saat UI diinisialisasi
        loadRecordingsData()
    end

    -- Mengembalikan objek modul
    return {
        setup = setup,
        stopActions = stopActions,
        startRecording = startRecording,
        stopRecording = stopRecording,
        updateSpectatorGUI = function()
            -- Fungsi ini perlu diimplementasikan di skrip utama atau di-pass ke sini
            -- karena bergantung pada UI spectator. Untuk saat ini, ini adalah placeholder.
            if shared.updateSpectatorGUI then
                shared.updateSpectatorGUI({
                    isRecording = isRecording,
                    currentRecordingTarget = currentRecordingTarget
                })
            end
        end
    }
end