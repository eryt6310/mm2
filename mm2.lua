-- MM2 Advanced Script.lua (Оптимизированная версия)
-- Функции: Аим на мардера, автоподбор пистолета, ESP через стены, ноклип, изменение скорости

local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local workspace = game:GetService("Workspace")
local camera = workspace.CurrentCamera

-- Настройки
local Settings = {
    AimAssist = true,
    AutoPickup = true,
    ESP = true,
    NoClip = false,
    Speed = 16
}

-- Оптимизация: кэширование объектов
local playerList = players:GetPlayers()
local espObjects = {}
local espEnabled = true

-- GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = player.PlayerGui
ScreenGui.ResetOnSpawn = false

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 250, 0, 300)
Frame.Position = UDim2.new(0, 10, 0, 10)
Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Frame.BackgroundTransparency = 0.2
Frame.Active = true
Frame.Draggable = true
Frame.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
Title.Text = "MM2 Script v2.0"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 18
Title.Parent = Frame

local function CreateToggle(name, default, y, callback)
    local Toggle = Instance.new("TextButton")
    Toggle.Size = UDim2.new(1, -10, 0, 25)
    Toggle.Position = UDim2.new(0, 5, 0, y)
    Toggle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    Toggle.Text = name .. ": OFF"
    Toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    Toggle.Font = Enum.Font.SourceSans
    Toggle.TextSize = 14
    Toggle.Parent = Frame
    
    local state = default
    Toggle.MouseButton1Click:Connect(function()
        state = not state
        Toggle.Text = name .. ": " .. (state and "ON" or "OFF")
        callback(state)
    end)
    return Toggle
end

local function CreateSlider(name, min, max, default, y, callback)
    local SliderFrame = Instance.new("Frame")
    SliderFrame.Size = UDim2.new(1, -10, 0, 40)
    SliderFrame.Position = UDim2.new(0, 5, 0, y)
    SliderFrame.BackgroundTransparency = 1
    SliderFrame.Parent = Frame
    
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 0, 20)
    Label.Text = name .. ": " .. tostring(default)
    Label.TextColor3 = Color3.fromRGB(255, 255, 255)
    Label.Font = Enum.Font.SourceSans
    Label.TextSize = 13
    Label.BackgroundTransparency = 1
    Label.Parent = SliderFrame
    
    local Slider = Instance.new("Frame")
    Slider.Size = UDim2.new(1, 0, 0, 15)
    Slider.Position = UDim2.new(0, 0, 0, 20)
    Slider.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    Slider.Parent = SliderFrame
    
    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    Fill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    Fill.Parent = Slider
    
    local value = default
    local dragging = false
    
    Slider.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            local x = math.clamp((input.Position.X - Slider.AbsolutePosition.X) / Slider.AbsoluteSize.X, 0, 1)
            value = math.floor((x * (max - min)) + min)
            Fill.Size = UDim2.new(x, 0, 1, 0)
            Label.Text = name .. ": " .. tostring(value)
            callback(value)
        end
    end)
    
    Slider.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local x = math.clamp((input.Position.X - Slider.AbsolutePosition.X) / Slider.AbsoluteSize.X, 0, 1)
            value = math.floor((x * (max - min)) + min)
            Fill.Size = UDim2.new(x, 0, 1, 0)
            Label.Text = name .. ": " .. tostring(value)
            callback(value)
        end
    end)
end

-- Создание элементов управления
local yPos = 35
CreateToggle("Aim Assist", true, yPos, function(state) Settings.AimAssist = state end)
yPos = yPos + 30
CreateToggle("Auto Pickup", true, yPos, function(state) Settings.AutoPickup = state end)
yPos = yPos + 30
CreateToggle("ESP", true, yPos, function(state) 
    Settings.ESP = state
    espEnabled = state
    if not state then
        ClearESP()
    end
end)
yPos = yPos + 30
CreateToggle("NoClip", false, yPos, function(state) Settings.NoClip = state end)
yPos = yPos + 30
CreateSlider("Speed", 16, 100, 16, yPos, function(value) Settings.Speed = value end)

-- Очистка ESP
local function ClearESP()
    for _, esp in pairs(espObjects) do
        if esp and esp.Parent then
            esp:Destroy()
        end
    end
    espObjects = {}
end

-- Создание ESP для игрока
local function CreateESPForPlayer(target)
    if not target or target == player or not target.Character then return end
    
    local head = target.Character:FindFirstChild("Head")
    if not head then return end
    
    -- Удаляем старый ESP если есть
    if espObjects[target] then
        espObjects[target]:Destroy()
        espObjects[target] = nil
    end
    
    -- Создаем BillboardGui
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 120, 0, 40)
    billboard.Adornee = head
    billboard.AlwaysOnTop = true -- Видно через стены
    billboard.MaxDistance = 1000
    billboard.Parent = head
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 14
    label.TextStrokeTransparency = 0.3
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Parent = billboard
    
    -- Определяем роль
    if head:FindFirstChild("murderer") then
        label.Text = "🔪 МАРДЕР"
        label.TextColor3 = Color3.fromRGB(255, 0, 0)
    elseif head:FindFirstChild("sheriff") then
        label.Text = "⭐ ШЕРИФ"
        label.TextColor3 = Color3.fromRGB(0, 150, 255)
    elseif head:FindFirstChild("innocent") then
        label.Text = "👤 НЕВИННЫЙ"
        label.TextColor3 = Color3.fromRGB(0, 255, 0)
    else
        label.Text = "❓ НЕИЗВЕСТНО"
        label.TextColor3 = Color3.fromRGB(255, 255, 0)
        -- Пытаемся определить роль через другие методы
        local char = target.Character
        if char:FindFirstChild("murderer") then
            label.Text = "🔪 МАРДЕР"
            label.TextColor3 = Color3.fromRGB(255, 0, 0)
        elseif char:FindFirstChild("sheriff") then
            label.Text = "⭐ ШЕРИФ"
            label.TextColor3 = Color3.fromRGB(0, 150, 255)
        elseif char:FindFirstChild("innocent") then
            label.Text = "👤 НЕВИННЫЙ"
            label.TextColor3 = Color3.fromRGB(0, 255, 0)
        end
    end
    
    -- Добавляем полоску здоровья
    local healthBar = Instance.new("Frame")
    healthBar.Size = UDim2.new(1, 0, 0, 4)
    healthBar.Position = UDim2.new(0, 0, 1, 2)
    healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    healthBar.Parent = billboard
    
    local healthBg = Instance.new("Frame")
    healthBg.Size = UDim2.new(1, 0, 0, 4)
    healthBg.Position = UDim2.new(0, 0, 1, 2)
    healthBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    healthBg.BackgroundTransparency = 0.5
    healthBg.Parent = billboard
    healthBg.ZIndex = 0
    
    espObjects[target] = billboard
    
    -- Обновление здоровья
    game:GetService("RunService").Heartbeat:Connect(function()
        if not target or not target.Character or not target.Character:FindFirstChild("Humanoid") then
            if espObjects[target] then
                espObjects[target]:Destroy()
                espObjects[target] = nil
            end
            return
        end
        
        local humanoid = target.Character.Humanoid
        local healthPercent = humanoid.Health / humanoid.MaxHealth
        healthBar.Size = UDim2.new(healthPercent, 0, 0, 4)
        
        if healthPercent > 0.5 then
            healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
        elseif healthPercent > 0.25 then
            healthBar.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
        else
            healthBar.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        end
    end)
end

-- Обновление ESP для всех игроков
local function UpdateESP()
    if not espEnabled then
        ClearESP()
        return
    end
    
    for _, target in pairs(players:GetPlayers()) do
        if target ~= player then
            if target.Character and target.Character:FindFirstChild("Head") then
                -- Проверяем существует ли ESP
                if not espObjects[target] or not espObjects[target].Parent then
                    CreateESPForPlayer(target)
                end
            else
                if espObjects[target] then
                    espObjects[target]:Destroy()
                    espObjects[target] = nil
                end
            end
        end
    end
    
    -- Удаляем ESP для игроков, которых уже нет
    for target, esp in pairs(espObjects) do
        if not target or not target.Parent then
            esp:Destroy()
            espObjects[target] = nil
        end
    end
end

-- Обработчики событий
players.PlayerAdded:Connect(function(newPlayer)
    wait(0.5)
    UpdateESP()
end)

players.PlayerRemoving:Connect(function(removedPlayer)
    if espObjects[removedPlayer] then
        espObjects[removedPlayer]:Destroy()
        espObjects[removedPlayer] = nil
    end
end)

-- Обновляем ESP каждые 0.5 секунды (оптимизация)
local lastESPUpdate = 0
game:GetService("RunService").Heartbeat:Connect(function()
    if tick() - lastESPUpdate > 0.5 then
        UpdateESP()
        lastESPUpdate = tick()
    end
end)

-- AIM ASSIST (на мардера)
local function GetClosestMurderer()
    local closest = nil
    local dist = math.huge
    for _, v in pairs(players:GetPlayers()) do
        if v ~= player and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
            local character = v.Character
            local head = character:FindFirstChild("Head")
            if head then
                local isMurderer = head:FindFirstChild("murderer") or character:FindFirstChild("murderer")
                if isMurderer then
                    local pos = character.HumanoidRootPart.Position
                    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                        local mag = (pos - player.Character.HumanoidRootPart.Position).Magnitude
                        if mag < dist then
                            dist = mag
                            closest = v
                        end
                    end
                end
            end
        end
    end
    return closest
end

-- Автострельба (с задержкой для оптимизации)
local lastShot = 0
runService.RenderStepped:Connect(function()
    if Settings.AimAssist and tick() - lastShot > 0.15 then
        local target = GetClosestMurderer()
        if target and target.Character then
            local head = target.Character:FindFirstChild("Head")
            if head and player.Character and player.Character:FindFirstChild("Head") then
                -- Проверяем есть ли у игрока пистолет
                local hasGun = false
                if player.Character:FindFirstChild("Tool") then
                    hasGun = true
                end
                
                if hasGun then
                    local raycastParams = RaycastParams.new()
                    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                    raycastParams.FilterDescendantsInstances = {player.Character}
                    
                    local rayResult = workspace:Raycast(
                        player.Character.Head.Position,
                        (head.Position - player.Character.Head.Position).Unit * 500,
                        raycastParams
                    )
                    
                    if not rayResult or rayResult.Instance.Parent == target.Character then
                        -- Стрельба
                        game:GetService("ReplicatedStorage"):FindFirstChild("Events"):FindFirstChild("Gun"):FireServer("Shoot", head.Position)
                        lastShot = tick()
                    end
                end
            end
        end
    end
end)

-- AUTO PICKUP (подбор пистолета)
local function FindGun()
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("Tool") and v.Name == "Gun" and v.Parent ~= player.Character then
            return v
        end
        -- Некоторые версии MM2 используют BasePart
        if v:IsA("BasePart") and v.Name == "Gun" and v.Parent and v.Parent:IsA("Model") then
            return v.Parent
        end
    end
    return nil
end

runService.Heartbeat:Connect(function()
    if Settings.AutoPickup then
        local gun = FindGun()
        if gun then
            -- Пытаемся подобрать разными способами
            pcall(function()
                if gun:IsA("Tool") then
                    player.Character:FindFirstChild("Humanoid"):EquipTool(gun)
                else
                    -- Для старых версий
                    local args = {
                        [1] = "Pickup",
                        [2] = gun
                    }
                    local event = game:GetService("ReplicatedStorage"):FindFirstChild("Events"):FindFirstChild("Pickup")
                    if event then
                        event:FireServer(unpack(args))
                    end
                end
            end)
        end
    end
end)

-- NO CLIP (оптимизированный)
local noclipEnabled = false
runService.Stepped:Connect(function()
    if Settings.NoClip ~= noclipEnabled then
        noclipEnabled = Settings.NoClip
        if player.Character then
            for _, v in pairs(player.Character:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.CanCollide = not Settings.NoClip
                end
            end
        end
    end
    
    if Settings.NoClip and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        player.Character.HumanoidRootPart.Velocity = Vector3.new(0, 0, 0)
    end
end)

-- ИЗМЕНЕНИЕ СКОРОСТИ (оптимизированный)
local currentSpeed = 16
runService.Heartbeat:Connect(function()
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        local humanoid = player.Character.Humanoid
        if humanoid.WalkSpeed ~= Settings.Speed then
            humanoid.WalkSpeed = Settings.Speed
        end
    end
end)

-- Защита от ошибок и вывод в консоль
pcall(function()
    print("MM2 Script v2.0 загружен успешно!")
    print("ESP отображается через стены (AlwaysOnTop)")
end)

-- Очистка при выгрузке скрипта
game:GetService("Players").LocalPlayer.CharacterAdded:Connect(function()
    wait(0.5)
    ClearESP()
    UpdateESP()
end)
