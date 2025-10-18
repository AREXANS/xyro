--[[
    ArexansTools - Modul Tab Pengaturan
    Deskripsi: Berisi semua UI dan logika untuk tab pengaturan.
    Modul ini mengembalikan sebuah fungsi yang menerima tabel 'shared' berisi dependensi
    dan mengembalikan fungsi 'setup' untuk menginisialisasi tab.
--]]

return function(shared)
    -- Mengimpor dependensi dari skrip utama
    local CoreGui = shared.CoreGui
    local Players = shared.Players
    local LocalPlayer = shared.LocalPlayer
    local UserInputService = shared.UserInputService
    local TeleportService = shared.TeleportService
    local HttpService = shared.HttpService
    local SCRIPT_URL = shared.SCRIPT_URL

    -- Mengimpor fungsi utilitas dari skrip utama
    local createButton = shared.createButton
    local createToggle = shared.createToggle
    local createSlider = shared.createSlider
    local showNotification = shared.showNotification
    local saveGuiPositions = shared.saveGuiPositions
    local CloseScript = shared.CloseScript
    local HandleLogout = shared.HandleLogout

    -- Mengimpor variabel status yang dapat diubah dari skrip utama
    -- 'shared.states' akan menjadi tabel yang berisi referensi ke variabel status
    local states = shared.states

    -- Fungsi khusus untuk modul ini
    local function HopServer()
        if SCRIPT_URL == "GANTI_DENGAN_URL_RAW_PASTEBIN_ATAU_GIST_ANDA" then
            showNotification("URL Skrip belum diatur!", Color3.fromRGB(255, 100, 0))
            return
        end

        local servers = {}
        local success, response = pcall(function()
            return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100"))
        end)

        if not success or not response or not response.data then
            showNotification("Gagal mengambil daftar server.", Color3.fromRGB(200, 50, 50))
            warn("Server Hop Error:", response)
            return
        end

        for _, server in ipairs(response.data) do
            if type(server) == 'table' and server.id ~= game.JobId and server.playing < server.maxPlayers then
                table.insert(servers, server.id)
            end
        end

        if #servers > 0 then
            local randomServer = servers[math.random(1, #servers)]

            shared.saveFeatureStates()
            saveGuiPositions()

            if shared.queue_on_teleport and type(shared.queue_on_teleport) == "function" then
                local loaderCode = "loadstring(game:HttpGet('" .. SCRIPT_URL .. "'))()"
                shared.queue_on_teleport(loaderCode)
                showNotification("Re-eksekusi terjadwal, pindah server...", Color3.fromRGB(50, 150, 255))
            else
                showNotification("Executor tidak mendukung 'queue_on_teleport'. Gunakan auto-exec.", Color3.fromRGB(255, 150, 0))
            end

            task.wait(0.1)

            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, randomServer, LocalPlayer)
            end)
        else
            showNotification("Tidak ada server lain yang ditemukan.", Color3.fromRGB(200, 150, 50))
        end
    end

    -- Fungsi utama untuk membangun UI tab
    local function setup(parentFrame, miniToggleButton)
        createToggle(parentFrame, "Kunci Bar Tombol", not states.isMiniToggleDraggable, function(v)
            states.isMiniToggleDraggable = not v
        end).LayoutOrder = 1

        createSlider(parentFrame, "Ukuran Tombol Navigasi", 10, 50, 30, "px", 1, function(v)
            if miniToggleButton then
                miniToggleButton.Size = UDim2.new(0, v, 0, v)
                miniToggleButton.TextSize = math.floor(v * 0.6)
            end
        end).LayoutOrder = 2

        createButton(parentFrame, "Simpan Posisi UI", saveGuiPositions).LayoutOrder = 3
        createButton(parentFrame, "Hop Server", function() HopServer() end).LayoutOrder = 4

        createToggle(parentFrame, "Anti-Lag", states.IsAntiLagEnabled, function(v)
            states.IsAntiLagEnabled = v
            shared.ToggleAntiLag(v)
        end).LayoutOrder = 5

        createToggle(parentFrame, "Boost FPS", states.IsBoostFPSEnabled, function(v)
            states.IsBoostFPSEnabled = v
            shared.ToggleBoostFPS(v)
        end).LayoutOrder = 6

        -- Inisialisasi Dark Texture Toggle (Patch V2)
        pcall(function()
            local darkContainer, darkSwitch = createToggle(parentFrame, "Dark Texture", shared.darkActive, function(state)
                shared.ToggleDarkTotal(state)
            end)
            darkContainer.LayoutOrder = 7
        end)

        -- Inisialisasi Optimized Game Toggle
        pcall(function()
            local optContainer, optSwitch = createToggle(parentFrame, "Optimized Game", shared.IsOptimizedGameEnabled, function(state)
                shared.ToggleOptimizedGame(state)
            end)
            optContainer.LayoutOrder = 8
        end)

        createToggle(parentFrame, "Shift Lock", states.IsShiftLockEnabled, function(v)
            states.IsShiftLockEnabled = v
            shared.ToggleShiftLock(v)
        end).LayoutOrder = 9

        createButton(parentFrame, "Tutup", CloseScript).LayoutOrder = 11

        local logoutButton = createButton(parentFrame, "Logout", HandleLogout)
        logoutButton.LayoutOrder = 12
        logoutButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    end

    return {
        setup = setup
    }
end