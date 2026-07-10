-- Universal AimBot & ESP для Roblox
-- Работает во всех режимах (FPS, TPS, любые игры)
-- Оптимизированная версия с настройками

local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local userInput = game:GetService("UserInputService")

-- ============================================
-- НАСТРОЙКИ (можно менять)
-- ============================================
local Settings = {
    AimBot = {
        Enabled = true,
        Key = "Q",           -- Клавиша активации (зажми для прицеливания)
        FOV = 200,           -- Радиус поиска цели (пиксели)
        Smoothness = 0.3,    -- Плавность (0 - мгновенно, 1 - очень плавно)
        TeamCheck = true,    -- Не стрелять по своим (если есть команды)
        VisibleCheck = true, -- Стрелять только по видимым целям
        HitChance = 1,       -- Шанс попадания (0.1 - 1.0)
        TargetPart = "Head"  -- Часть тела для атаки ("Head", "HumanoidRootPart", "Torso")
    },
    ESP = {
        Enabled = true,
        Box = true,          -- Прямоугольник вокруг игрока
        Name = true,         -- Имя игрока
        Health = true,       -- Полоска здоровья
        Distance = true,     -- Расстояние до игрока
        ThroughWalls = true  -- Видеть через стены
    }
}

-- ============================================
-- СИСТЕМА ЦЕЛЕЙ
-- ============================================
local targets = {}
local currentTarget = nil

-- Получение всех игроков
local function GetPlayers()
    local list = {}
    for _, v in pairs(players:GetPlayers()) do
        if v ~= player and v.Character and v.Character:FindFirstChild("Humanoid") and v.Character.Humanoid.Health > 0 then
            -- Проверка на команду (если есть)
            local teamCheck = true
            if Settings.AimBot.TeamCheck and player.Team and v.Team then
                teamCheck = player.Team ~= v.Team
            end
            if teamCheck then
                table.insert(list, v)
            end
        end
    end
    return list
end

-- Получение позиции цели
local function GetTargetPosition(target)
    local character = target.Character
    if not character then return nil end
    
    local part = character:FindFirstChild(Settings.AimBot.TargetPart)
    if not part then
        part = character:FindFirstChild("HumanoidRootPart")
    end
    if not part then
        part = character:FindFirstChild("Torso")
    end
    if not part then
        part = character:FindFirstChild("Head")
    end
    
    return part and part.Position or nil
end

-- Проверка видимости
local function IsVisible(target)
    if not Settings.AimBot.VisibleCheck then return true end
    
    local pos = GetTargetPosition(target)
    if not pos then return false end
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {player.Character}
    
    local result = workspace:Raycast(camera.CFrame.Position, (pos - camera.CFrame.Position).Unit * 500, raycastParams)
    if not result then return true end
    
    local targetChar = target.Character
    if not targetChar then return false end
    
    local hit = result.Instance
    while hit and hit.Parent do
        if hit.Parent == targetChar then
            return true
        end
        hit = hit.Parent
    end
    return false
end

-- Поиск лучшей цели
local function GetClosestTarget()
    local playersList = GetPlayers()
    if #playersList == 0 then return nil end
    
    local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local bestTarget = nil
    local bestDistance = math.huge
    
    for _, v in pairs(playersList) do
        local pos = GetTargetPosition(v)
        if pos then
            local screenPos, onScreen = camera:WorldToViewportPoint(pos)
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                if dist < Settings.AimBot.FOV and dist < bestDistance then
                    if IsVisible(v) then
                        bestTarget = v
                        bestDistance = dist
                    end
                end
            end
        end
    end
    
    return bestTarget
end

-- ============================================
-- AИМ БОТ
-- ============================================
local isAiming = false

-- Плавное наведение
local function SmoothAim(targetPos)
    if not targetPos then return end
    
    local currentPos = camera.CFrame.Position
    local direction = (targetPos - currentPos).Unit
    local targetCFrame = CFrame.lookAt(currentPos, targetPos)
    
    -- Плавное интерполирование
    local smoothness = Settings.AimBot.Smoothness
    if smoothness < 0.1 then smoothness = 0.1 end
    
    camera.CFrame = camera.CFrame:Lerp(targetCFrame, smoothness)
end

-- Обработка нажатия клавиши
userInput.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode[Settings.AimBot.Key] then
        isAiming = true
    end
end)

userInput.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode[Settings.AimBot.Key] then
        isAiming = false
    end
end)

-- Основной цикл AimBot
runService.RenderStepped:Connect(function()
    if not Settings.AimBot.Enabled or not isAiming then 
        currentTarget = nil
        return 
    end
    
    -- Выбор цели
    local target = GetClosestTarget()
    if not target then 
        currentTarget = nil
        return 
    end
    
    local targetPos = GetTargetPosition(target)
    if not targetPos then 
        currentTarget = nil
        return 
    end
    
    -- Применение шанса попадания
    if math.random() > Settings.AimBot.HitChance then
        -- Случайное смещение для промаха
        local offset = Vector3.new(
            math.random(-5, 5),
            math.random(-5, 5),
            math.random(-5, 5)
        )
        targetPos = targetPos + offset
    end
    
    currentTarget = target
    SmoothAim(targetPos)
end)

-- ============================================
-- ESP СИСТЕМА
-- ============================================
local espObjects = {}
local espUpdateTime = 0

-- Создание ESP для игрока
local function CreateESP(target)
    if not target or target == player or not target.Character then return end
    
    -- Удаляем старый ESP
    if espObjects[target] then
        espObjects[target]:Destroy()
        espObjects[target] = nil
    end
    
    local character = target.Character
    if not character then return end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    
    -- Главный Billboard
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 200, 0, 80)
    billboard.Adornee = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
    billboard.AlwaysOnTop = Settings.ESP.ThroughWalls
    billboard.MaxDistance = 1000
    billboard.ResetOnSpawn = false
    billboard.Parent = billboard.Adornee
    
    -- Отрисовка игрока (бокс)
    if Settings.ESP.Box then
        local box = Instance.new("Frame")
        box.Size = UDim2.new(0, 50, 0, 100)
        box.Position = UDim2.new(0.5, -25, 0.5, -50)
        box.BackgroundTransparency = 0.6
        box.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        box.BorderSizePixel = 2
        box.BorderColor3 = Color3.fromRGB(255, 255, 255)
        box.Parent = billboard
    end
    
    -- Имя
    if Settings.ESP.Name then
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, 0, 0, 20)
        nameLabel.Position = UDim2.new(0, 0, 0, -10)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = target.Name
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextScaled = true
        nameLabel.Font = Enum.Font.SourceSansBold
        nameLabel.TextStrokeTransparency = 0.3
        nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        nameLabel.Parent = billboard
    end
    
    -- Полоска здоровья
    if Settings.ESP.Health then
        local healthBg = Instance.new("Frame")
        healthBg.Size = UDim2.new(0.8, 0, 0, 8)
        healthBg.Position = UDim2.new(0.1, 0, 0.6, 0)
        healthBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        healthBg.Parent = billboard
        
        local healthBar = Instance.new("Frame")
        healthBar.Size = UDim2.new(1, 0, 1, 0)
        healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
        healthBar.Parent = healthBg
        
        -- Обновление здоровья
        local healthConnection
        healthConnection = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
            local healthPercent = humanoid.Health / humanoid.MaxHealth
            healthBar.Size = UDim2.new(healthPercent, 0, 1, 0)
            
            if healthPercent > 0.6 then
                healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
            elseif healthPercent > 0.3 then
                healthBar.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
            else
                healthBar.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
            end
        end)
        
        -- Сохраняем связь для очистки
        healthBar:SetAttribute("Connection", healthConnection)
    end
    
    -- Расстояние
    if Settings.ESP.Distance then
        local distLabel = Instance.new("TextLabel")
        distLabel.Size = UDim2.new(1, 0, 0, 20)
        distLabel.Position = UDim2.new(0, 0, 0.8, 0)
        distLabel.BackgroundTransparency = 1
        distLabel.Text = "0m"
        distLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        distLabel.TextScaled = true
        distLabel.Font = Enum.Font.SourceSans
        distLabel.TextStrokeTransparency = 0.5
        distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        distLabel.Parent = billboard
        
        -- Обновление расстояния
        runService.Heartbeat:Connect(function()
            if not character or not character:FindFirstChild("HumanoidRootPart") or not player.Character then
                return
            end
            local dist = (character.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
            distLabel.Text = math.floor(dist) .. "m"
        end)
    end
    
    espObjects[target] = billboard
end

-- Очистка ESP
local function ClearESP()
    for _, esp in pairs(espObjects) do
        if esp and esp.Parent then
            esp:Destroy()
        end
    end
    espObjects = {}
end

-- Обновление ESP
local function UpdateESP()
    if not Settings.ESP.Enabled then
        ClearESP()
        return
    end
    
    for _, v in pairs(players:GetPlayers()) do
        if v ~= player and v.Character then
            local humanoid = v.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 then
                if not espObjects[v] or not espObjects[v].Parent then
                    CreateESP(v)
                end
            else
                if espObjects[v] then
                    espObjects[v]:Destroy()
                    espObjects[v] = nil
                end
            end
        end
    end
end

-- Обновление ESP с интервалом
runService.Heartbeat:Connect(function()
    if tick() - espUpdateTime > 0.5 then
        UpdateESP()
        espUpdateTime = tick()
    end
end)

-- События игроков
players.PlayerAdded:Connect(function()
    wait(0.5)
    UpdateESP()
end)

players.PlayerRemoving:Connect(function(v)
    if espObjects[v] then
        espObjects[v]:Destroy()
        espObjects[v] = nil
    end
end)

player.CharacterAdded:Connect(function()
    wait(1)
    ClearESP()
    UpdateESP()
end)

-- ============================================
-- GUI НАСТРОЕК (опционально)
-- ============================================
local function CreateGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Parent = player.PlayerGui
    screenGui.Name = "AimBotGUI"
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 220, 0, 250)
    frame.Position = UDim2.new(0, 10, 0, 10)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BackgroundTransparency = 0.2
    frame.Active = true
    frame.Draggable = true
    frame.Parent = screenGui
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    title.Text = "⚡ AimBot & ESP"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 16
    title.Parent = frame
    
    local function CreateToggle(name, setting, y, callback)
        local toggle = Instance.new("TextButton")
        toggle.Size = UDim2.new(1, -10, 0, 25)
        toggle.Position = UDim2.new(0, 5, 0, y)
        toggle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        toggle.Text = name .. ": ON"
        toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
        toggle.Font = Enum.Font.SourceSans
        toggle.TextSize = 14
        toggle.Parent = frame
        
        local state = true
        toggle.MouseButton1Click:Connect(function()
            state = not state
            toggle.Text = name .. ": " .. (state and "ON" or "OFF")
            callback(state)
        end)
        return toggle
    end
    
    local y = 35
    CreateToggle("AimBot", Settings.AimBot.Enabled, y, function(state)
        Settings.AimBot.Enabled = state
        if not state then isAiming = false end
    end)
    y = y + 30
    CreateToggle("ESP", Settings.ESP.Enabled, y, function(state)
        Settings.ESP.Enabled = state
        if not state then ClearESP() end
    end)
    y = y + 30
    CreateToggle("Через стены", Settings.ESP.ThroughWalls, y, function(state)
        Settings.ESP.ThroughWalls = state
        UpdateESP()
    end)
end

-- Запуск GUI
pcall(CreateGUI)

-- ============================================
-- ВЫВОД В КОНСОЛЬ
-- ============================================
print("=== Universal AimBot & ESP ===")
print("Клавиша для Aim: " .. Settings.AimBot.Key)
print("ESP активен: " .. tostring(Settings.ESP.Enabled))
print("================================")
