-- =====================================================
-- Asmelit OS Installer
-- Устанавливает систему в EEPROM
-- =====================================================

local component = require("component")
local computer = require("computer")
local term = require("term")
local gpu = component.gpu
local event = require("event")

-- Настройки
local maxWidth, maxHeight = gpu.getResolution()
local centerX = math.floor(maxWidth / 2)
local centerY = math.floor(maxHeight / 2)

-- Анимация установки (5 кадров)
local animationFrames = {
    -- Эти фреймы будут загружены с GitHub
}

-- Загрузка анимации с GitHub
local function loadAnimation()
    local frames = {}
    local frameUrls = {
        "https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/refs/heads/main/gif1.lua",
        "https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/refs/heads/main/gif2.lua",
        "https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/refs/heads/main/gif3.lua",
        "https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/refs/heads/main/gif4.lua",
        "https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/refs/heads/main/gif5.lua"
    }
    
    if component.isAvailable("internet") then
        local internet = require("internet")
        for i, url in ipairs(frameUrls) do
            local ok, frame = pcall(function()
                local handle = internet.request(url)
                local data = ""
                for chunk in handle do
                    data = data .. chunk
                end
                return data
            end)
            
            if ok then
                frames[i] = frame
            else
                -- Запасные ASCII арты
                if i == 1 then
                    frames[i] = [[
 ____________________
/ LUA BUILD TOOL   \
!█                               !
!                                 !
\____________________/
         !  !
         !  !
         L_ !
        / _)!
       / /__L
 _____/ (____)
        (____)
 _____  (____)
      \_(____)
         !  !
         !  !
         \__/]]
                else
                    frames[i] = "Кадр " .. i .. " | Установка..."
                end
            end
        end
    else
        -- Без интернета - простые кадры
        for i = 1, 5 do
            frames[i] = "===[ Кадр " .. i .. " ]===\nУстановка Asmelit OS..."
        end
    end
    
    return frames
end

-- Отрисовка анимации
local function drawAnimation(frames, frameIndex, progress, status)
    gpu.setBackground(0x000055)
    gpu.setForeground(0xFFFFFF)
    term.clear()
    
    -- Заголовок
    local title = "УСТАНОВЩИК ASMELIT OS"
    gpu.set(centerX - math.floor(#title / 2), 2, title)
    
    -- Текущий кадр анимации
    local frame = frames[frameIndex] or "Установка..."
    local lines = {}
    for line in frame:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    
    local startY = centerY - math.floor(#lines / 2) - 3
    gpu.setForeground(0x00FF00)
    for i, line in ipairs(lines) do
        local x = centerX - math.floor(#line / 2)
        if startY + i > 4 and startY + i < maxHeight - 6 then
            gpu.set(x, startY + i, line)
        end
    end
    
    -- Прогресс бар
    local barWidth = math.floor(maxWidth * 0.7)
    local barX = centerX - math.floor(barWidth / 2)
    local barY = maxHeight - 8
    
    gpu.setBackground(0x333333)
    gpu.fill(barX, barY, barWidth, 1, "░")
    
    local filled = math.floor(barWidth * progress)
    if filled > 0 then
        gpu.setBackground(0x00FF00)
        gpu.fill(barX, barY, filled, 1, "█")
    end
    
    -- Процент
    local percentText = math.floor(progress * 100) .. "%"
    gpu.setBackground(0x000055)
    gpu.setForeground(0xFFFFFF)
    gpu.set(centerX - math.floor(#percentText / 2), barY + 1, percentText)
    
    -- Статус
    gpu.set(centerX - math.floor(#status / 2), barY + 3, status)
    
    -- Инструкция
    local help = "ESC - Отмена | Enter - Продолжить"
    gpu.set(centerX - math.floor(#help / 2), maxHeight - 2, help)
end

-- Установка системы
local function installSystem()
    local fs = require("filesystem")
    local eeprom = component.eeprom
    
    -- Создаем структуру папок
    local directories = {
        "/home",
        "/home/user",
        "/home/system",
        "/home/apps",
        "/home/docs",
        "/bin",
        "/lib",
        "/tmp"
    }
    
    for _, dir in ipairs(directories) do
        if not fs.exists(dir) then
            fs.makeDirectory(dir)
        end
    end
    
    -- Загружаем основную ОС
    local osCode = ""
    if component.isAvailable("internet") then
        local internet = require("internet")
        local ok, handle = pcall(function()
            return internet.request("https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/refs/heads/main/os.lua")
        end)
        
        if ok and handle then
            for chunk in handle do
                osCode = osCode .. chunk
            end
        end
    end
    
    -- Если не удалось загрузить, используем встроенную версию
    if #osCode < 100 then
        osCode = [[
-- Asmelit OS (мини-версия)
local component = require("component")
local computer = require("computer")
local term = require("term")
local gpu = component.gpu

print("=== Asmelit OS ===")
print("Версия: 2.0")
print("Память: " .. computer.freeMemory() .. "/" .. computer.totalMemory())
print("Введите 'menu' для запуска меню")

while true do
    io.write("> ")
    local cmd = io.read()
    if cmd == "menu" then
        print("Загрузка меню...")
        os.sleep(1)
        -- Здесь будет основное меню
    elseif cmd == "exit" then
        computer.shutdown()
    else
        print("Команда не найдена")
    end
end]]
    end
    
    -- Сохраняем ОС как startup.lua
    local startupFile = io.open("/home/startup.lua", "w")
    startupFile:write(osCode)
    startupFile:close()
    
    -- Записываем в EEPROM если нужно
    local installToEeprom = true
    if installToEeprom and eeprom then
        eeprom.set(osCode)
        eeprom.setLabel("Asmelit OS BIOS")
    end
    
    return true
end

-- Главное меню установщика
local function mainMenu()
    local selected = 1
    local options = {
        {text = "Установить Asmelit OS", action = "install"},
        {text = "Обновить систему", action = "update"},
        {text = "Восстановление системы", action = "recovery"},
        {text = "Настройки BIOS", action = "bios"},
        {text = "Выход", action = "exit"}
    }
    
    while true do
        gpu.setBackground(0x000055)
        gpu.setForeground(0xFFFFFF)
        term.clear()
        
        -- Заголовок
        local title = "ASMELIT OS INSTALLER v2.0"
        gpu.set(centerX - math.floor(#title / 2), 3, title)
        
        local subtitle = "Выберите действие:"
        gpu.set(centerX - math.floor(#subtitle / 2), 5, subtitle)
        
        -- Опции меню
        local startY = centerY - math.floor(#options / 2)
        for i, option in ipairs(options) do
            local x = centerX - 15
            local y = startY + i
            
            if i == selected then
                gpu.setBackground(0x00AA00)
                gpu.setForeground(0x000000)
                gpu.fill(x, y, 30, 1, " ")
            else
                gpu.setBackground(0x000055)
                gpu.setForeground(0xFFFFFF)
            end
            
            local prefix = i == selected and "▶ " or "  "
            gpu.set(x, y, prefix .. option.text)
        end
        
        -- Подсказка
        local help = "↑↓ - Выбор | Enter - Подтвердить | ESC - Выход"
        gpu.setBackground(0x000055)
        gpu.setForeground(0xAAAAAA)
        gpu.set(centerX - math.floor(#help / 2), maxHeight - 2, help)
        
        -- Обработка ввода
        local eventType, _, char, code = event.pull()
        
        if eventType == "key_down" then
            if code == 200 then -- Up
                selected = selected > 1 and selected - 1 or #options
            elseif code == 208 then -- Down
                selected = selected < #options and selected + 1 or 1
            elseif code == 28 then -- Enter
                local action = options[selected].action
                
                if action == "install" then
                    -- Запуск установки
                    local frames = loadAnimation()
                    
                    local stages = {
                        "Проверка системы...",
                        "Загрузка компонентов...",
                        "Создание файловой системы...",
                        "Установка ядра...",
                        "Настройка BIOS...",
                        "Завершение установки..."
                    }
                    
                    for i = 1, #stages do
                        local progress = i / #stages
                        local frameIndex = ((i-1) % 10) + 1
                        if frameIndex > 5 then
                            frameIndex = 10 - frameIndex + 1
                        end
                        
                        drawAnimation(frames, frameIndex, progress, stages[i])
                        
                        -- Имитация работы
                        for j = 1, 5 do
                            local e = {event.pull(0.1)}
                            if e[1] == "key_down" and e[4] == 1 then -- ESC
                                return
                            end
                        end
                    end
                    
                    -- Фактическая установка
                    drawAnimation(frames, 1, 1, "Установка завершена!")
                    
                    if installSystem() then
                        local successMsg = "Asmelit OS успешно установлена!"
                        gpu.set(centerX - math.floor(#successMsg / 2), maxHeight - 5, successMsg)
                        os.sleep(3)
                        
                        -- Перезагрузка
                        computer.shutdown(true)
                    end
                    
                elseif action == "exit" then
                    computer.shutdown()
                else
                    -- Для других опций - заглушки
                    gpu.setBackground(0x000055)
                    gpu.setForeground(0xFFFFFF)
                    term.clear()
                    gpu.set(centerX - 10, centerY, "Функция в разработке")
                    os.sleep(2)
                end
                
            elseif code == 1 then -- ESC
                return
            end
        end
    end
end

-- Точка входа
print("Инициализация установщика...")
os.sleep(1)
mainMenu()
