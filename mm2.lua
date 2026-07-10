-- MM2 Advanced Script.lua
-- Функции: Аим на мардера, автоподбор пистолета, ESP, ноклип, изменение скорости

local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local workspace = game:GetService("Workspace")

-- Настройки
local Settings = {
    AimAssist = true,
    AutoPickup = true,
    ESP = true,
    NoClip = false,
    Speed = 16
}

-- GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = player.PlayerGui

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
Title.Text = "MM2 Script"
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
    Slider.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local x = (input.Position.X - Slider.AbsolutePosition.X) / Slider.AbsoluteSize.X
            value = math.floor((x * (max - min)) + min)
            Fill.Size = UDim2.new(x, 0, 1, 0)
            Label.Text = name .. ": " .. tostring(value)
            callback(value)
        end
    end)
    
    Slider.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and (input.UserInputState == Enum.UserInputState.Left or input.UserInputState == Enum.UserInputState.Down) then
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
CreateToggle("ESP", true, yPos, function(state) Settings.ESP = state end)
yPos = yPos + 30
CreateToggle("NoClip", false, yPos, function(state) Settings.NoClip = state end)
yPos = yPos + 30
CreateSlider("Speed", 16, 100, 16, yPos, function(value) Settings.Speed = value end)

-- AIM ASSIST (на мардера)
local function GetClosestMurderer()
    local closest = nil
    local dist = math.huge
    for _, v in pairs(players:GetPlayers()) do
        if v ~= player and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
            local character = v.Character
            if character:FindFirstChild("Head") and character.Head:FindFirstChild("murderer") then
                local pos = character.HumanoidRootPart.Position
                local mag = (pos - player.Character.HumanoidRootPart.Position).Magnitude
                if mag < dist then
                    dist = mag
                    closest = v
                end
            end
        end
    end
    return closest
end

runService.RenderStepped:Connect(function()
    if Settings.AimAssist then
        local target = GetClosestMurderer()
        if target and target.Character then
            local head = target.Character:FindFirstChild("Head")
            if head then
                local hit, pos = workspace:FindPartOnRay(Ray.new(
                    player.Character.Head.Position,
                    (head.Position - player.Character.Head.Position).Unit * 500
                ))
                -- Угол наведения (на мардера)
                if not hit or hit.Parent:IsA("BasePart") and hit.Parent.Parent ~= target.Character then
                    -- Стрельба через службу
                    local args = {
                        [1] = "Shoot",
                        [2] = head.Position
                    }
                    game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("Gun"):FireServer(unpack(args))
                end
            end
        end
    end
end)

-- AUTO PICKUP (подбор пистолета)
local function FindGun()
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") and v.Name == "Gun" and v.Parent ~= player.Character then
            return v
        end
    end
    return nil
end

runService.Heartbeat:Connect(function()
    if Settings.AutoPickup then
        local gun = FindGun()
        if gun then
            local args = {
                [1] = "Pickup",
                [2] = gun
            }
            game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("Pickup"):FireServer(unpack(args))
        end
    end
end)

-- ESP (все игроки с ролями)
local function UpdateESP()
    if not Settings.ESP then
        for _, v in pairs(players:GetPlayers()) do
            if v ~= player and v.Character and v.Character:FindFirstChild("Head") then
                local head = v.Character.Head
                if head:FindFirstChild("BillboardGui") then
                    head.BillboardGui:Destroy()
                end
            end
        end
        return
    end
    
    for _, v in pairs(players:GetPlayers()) do
        if v ~= player and v.Character and v.Character:FindFirstChild("Head") then
            local head = v.Character.Head
            if not head:FindFirstChild("BillboardGui") then
                local billboard = Instance.new("BillboardGui")
                billboard.Size = UDim2.new(0, 100, 0, 30)
                billboard.Adornee = head
                billboard.Parent = head
                
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.Font = Enum.Font.SourceSansBold
                label.TextSize = 14
                label.Parent = billboard
                
                if head:FindFirstChild("murderer") then
                    label.Text = "🔪 МАРДЕР"
                    label.TextColor3 = Color3.fromRGB(255, 0, 0)
                elseif head:FindFirstChild("sheriff") then
                    label.Text = "⭐ ШЕРИФ"
                    label.TextColor3 = Color3.fromRGB(0, 0, 255)
                elseif head:FindFirstChild("innocent") then
                    label.Text = "👤 НЕВИННЫЙ"
                    label.TextColor3 = Color3.fromRGB(0, 255, 0)
                else
                    label.Text = "❓ НЕИЗВЕСТНО"
                    label.TextColor3 = Color3.fromRGB(255, 255, 0)
                end
            end
        end
    end
end

players.PlayerAdded:Connect(UpdateESP)
players.PlayerRemoving:Connect(UpdateESP)
runService.Heartbeat:Connect(UpdateESP)

-- NO CLIP
runService.Stepped:Connect(function()
    if Settings.NoClip and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        player.Character.HumanoidRootPart.CanCollide = false
        player.Character.HumanoidRootPart.Velocity = Vector3.new(0, 0, 0)
        for _, v in pairs(player.Character:GetDescendants()) do
            if v:IsA("BasePart") then
                v.CanCollide = false
            end
        end
    elseif player.Character then
        for _, v in pairs(player.Character:GetDescendants()) do
            if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
                v.CanCollide = true
            end
        end
        if player.Character:FindFirstChild("HumanoidRootPart") then
            player.Character.HumanoidRootPart.CanCollide = true
        end
    end
end)

-- ИЗМЕНЕНИЕ СКОРОСТИ
runService.Heartbeat:Connect(function()
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid.WalkSpeed = Settings.Speed
    end
end)

-- Защита от ошибок
pcall(function()
    print("MM2 Script загружен успешно!")
end)
