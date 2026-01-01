-- =====================================================
-- Asmelit OS для OpenComputers
-- Версия 1.1 (исправлены проверки ошибок)
-- =====================================================

-- Основные библиотеки
local component = require("component")
local computer = require("computer")
local event = require("event")
local term = require("term")
local gpu = component.gpu
local fs = require("filesystem")
local serialization = require("serialization")
local internet
if component.isAvailable("internet") then
    internet = require("internet")
end
local colors = require("colors")

-- Глобальные переменные
local logoData = nil
local systemLog = {}
local bootTime = math.random(5, 15) -- Уменьшено время загрузки
local startTime = computer.uptime()
local maxWidth, maxHeight = gpu.getResolution()
local centerX = math.floor(maxWidth / 2)
local centerY = math.floor(maxHeight / 2)

-- =====================================================
-- 3. СИСТЕМА ОБРАБОТКИ ОШИБОК (КРАСНЫЙ ЭКРАН СМЕРТИ)
-- =====================================================
function triggerFatalError(errorMsg)
    table.insert(systemLog, "ФАТАЛЬНАЯ ОШИБКА: " .. errorMsg)
    
    -- Красный экран
    gpu.setBackground(0xFF0000)
    gpu.setForeground(0xFFFFFF)
    term.clear()
    
    -- Заголовок ошибки
    local errorTitle = "}}}}}}}}}}}}ASMELIT FATAL ERROR{{{{{{{{{{{{{{{"
    local titleX = math.floor((maxWidth - #errorTitle) / 2)
    gpu.set(titleX, 3, errorTitle)
    
    -- Сообщение об ошибке
    local msgX = math.floor((maxWidth - #errorMsg) / 2)
    gpu.set(msgX, 5, errorMsg)
    
    -- Разделитель
    gpu.set(1, 7, string.rep("=", maxWidth))
    
    -- Последние логи системы
    gpu.set(5, 9, "Последние логи системы:")
    
    local startLog = math.max(1, #systemLog - 10) -- Уменьшено количество логов
    local y = 11
    for i = startLog, #systemLog do
        if y < maxHeight - 3 then
            gpu.set(5, y, systemLog[i])
            y = y + 1
        end
    end
    
    -- Инструкция внизу
    local instruction = "Нажмите любую клавишу для перезагрузки..."
    gpu.set(math.floor((maxWidth - #instruction) / 2), maxHeight - 2, instruction)
    
    -- Ожидание нажатия (30 секунд)
    for i = 1, 300 do
        local e = {event.pull(0.1, "key_down", "touch")}
        if e[1] then
            break
        end
    end
    computer.shutdown(true) -- Перезагрузка
end

-- Фоновая проверка на ошибки (ОЧЕНЬ ЛИБЕРАЛЬНАЯ)
function checkForErrors()
    -- Проверка памяти - только если ОЧЕНЬ мало
    if computer.freeMemory() < 100 then -- было 512
        triggerFatalError("Критически мало памяти: " .. computer.freeMemory() .. " байт")
        return
    end
    
    -- Проверка энергии - только если ПРАКТИЧЕСКИ нет
    if computer.maxEnergy() > 0 then
        local energyPercent = (computer.energy() / computer.maxEnergy()) * 100
        if energyPercent < 5 then -- было 1000 энергии
            triggerFatalError("Критически мало энергии: " .. math.floor(energyPercent) .. "%")
            return
        end
    end
    
    -- Проверка основного диска
    if not fs.exists("/") then
        triggerFatalError("Файловая система недоступна")
        return
    end
end

-- =====================================================
-- 1. ФУНКЦИЯ ЗАГРУЗКИ И ДИАГНОСТИКИ
-- =====================================================
function bootScreen()
    -- Очистка экрана
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
    term.clear()
    
    -- Загрузка лого с GitHub (опционально)
    local function loadLogo()
        if internet then
            local ok = pcall(function()
                local handle = internet.request("https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/refs/heads/main/logo.lua")
                local data = ""
                for chunk in handle do
                    data = data .. chunk
                    if #data > 10000 then break end -- Ограничение размера
                end
                logoData = data
                table.insert(systemLog, "Лого загружено")
            end)
            if not ok then
                logoData = "Asmelit OS v1.1"
                table.insert(systemLog, "Используется стандартное лого")
            end
        else
            logoData = "Asmelit OS v1.1"
            table.insert(systemLog, "Нет интернета, стандартное лого")
        end
    end
    
    -- Диагностика системы (только информация)
    local function systemDiagnostics()
        table.insert(systemLog, "=== ДИАГНОСТИКА ===")
        
        -- Память
        local freeMem = computer.freeMemory()
        local totalMem = computer.totalMemory()
        table.insert(systemLog, string.format("Память: %d/%d байт", freeMem, totalMem))
        
        -- Компоненты
        local components = component.list()
        local compCount = 0
        for _ in pairs(components) do
            compCount = compCount + 1
        end
        table.insert(systemLog, string.format("Компонентов: %d", compCount))
        
        -- Энергия
        if computer.maxEnergy() > 0 then
            local percent = math.floor((computer.energy() / computer.maxEnergy()) * 100)
            table.insert(systemLog, string.format("Энергия: %d%%", percent))
        end
        
        table.insert(systemLog, "Диагностика OK")
    end
    
    -- Анимированная шкала загрузки
    local function drawProgressBar(progress)
        local barWidth = math.floor(maxWidth * 0.6)
        local barStartX = centerX - math.floor(barWidth / 2)
        local barY = centerY + 3
        
        -- Очистка области
        gpu.fill(barStartX, barY, barWidth, 1, " ")
        
        -- Вычисление заполненной части
        local filled = math.floor(barWidth * progress)
        if filled > barWidth then filled = barWidth end
        
        -- Отрисовка заполненной части
        if filled > 0 then
            gpu.setBackground(0x00FF00)
            gpu.fill(barStartX, barY, filled, 1, "█")
        end
        
        -- Отрисовка незаполненной части
        if filled < barWidth then
            gpu.setBackground(0x333333)
            gpu.fill(barStartX + filled, barY, barWidth - filled, 1, "░")
        end
        
        gpu.setBackground(0x000000)
    end
    
    -- Главная функция загрузки
    loadLogo()
    
    -- Отображение лого
    gpu.setForeground(0x00FF00)
    if type(logoData) == "string" and #logoData > 0 then
        local lines = {}
        for line in logoData:gmatch("[^\r\n]+") do
            table.insert(lines, line)
            if #lines >= 10 then break end -- Ограничение
        end
        
        local logoStartY = centerY - math.floor(#lines / 2) - 2
        for i, line in ipairs(lines) do
            local x = centerX - math.floor(#line / 2)
            gpu.set(x, logoStartY + i, line)
        end
    else
        local title = "ASMELIT OS v1.1"
        gpu.set(centerX - math.floor(#title / 2), centerY - 1, title)
    end
    
    -- Надпись "запуск Asmelit"
    gpu.setForeground(0x00FF00)
    local msg = "(запуск Asmelit)"
    gpu.set(centerX - math.floor(#msg / 2), centerY + 5, msg)
    
    -- Запуск диагностики
    systemDiagnostics()
    
    -- Анимация загрузки
    local elapsed = 0
    while elapsed < bootTime do
        local progress = elapsed / bootTime
        drawProgressBar(progress)
        
        os.sleep(0.3)
        elapsed = elapsed + 0.3
    end
    
    -- Завершение загрузки
    drawProgressBar(1.0)
    os.sleep(0.5)
end

-- =====================================================
-- 2. ОСНОВНОЙ ИНТЕРФЕЙС (упрощенный)
-- =====================================================
function mainGUI()
    local currentDir = "/home"
    local files = {}
    local selected = 1
    
    -- Простой интерфейс
    local function drawInterface()
        gpu.setBackground(0x000000)
        gpu.setForeground(0xFFFFFF)
        term.clear()
        
        -- Заголовок
        gpu.set(1, 1, "Asmelit OS - " .. currentDir)
        gpu.set(1, 2, string.rep("=", maxWidth))
        
        -- Список файлов
        local y = 4
        for i, file in ipairs(files) do
            if y < maxHeight - 3 then
                if i == selected then
                    gpu.setBackground(0xFFFFFF)
                    gpu.setForeground(0x000000)
                else
                    gpu.setBackground(0x000000)
                    gpu.setForeground(file.isDir and 0x00AAAA or 0x00FF00)
                end
                
                local display = file.name
                if file.isDir then
                    display = display .. "/"
                end
                gpu.set(1, y, display)
                y = y + 1
            end
        end
        
        -- Статус
        gpu.setBackground(0x000000)
        gpu.setForeground(0xAAAAAA)
        gpu.set(1, maxHeight - 1, string.format("Файлов: %d | Память: %d | F1-Справка | Enter-Открыть", #files, computer.freeMemory()))
        gpu.set(1, maxHeight, "> ")
    end
    
    -- Обновление списка файлов
    local function refreshFiles()
        files = {}
        if fs.exists(currentDir) and fs.isDirectory(currentDir) then
            for item in fs.list(currentDir) do
                local path = currentDir .. "/" .. item
                table.insert(files, {
                    name = item,
                    isDir = fs.isDirectory(path),
                    path = path
                })
            end
        end
    end
    
    -- Основной цикл
    refreshFiles()
    
    while true do
        -- Только ОЧЕНЬ критичные проверки
        if computer.freeMemory() < 50 then
            break
        end
        
        drawInterface()
        
        local eventType, _, char, code = event.pull()
        
        if eventType == "key_down" then
            if code == 200 then -- Up
                if selected > 1 then
                    selected = selected - 1
                end
            elseif code == 208 then -- Down
                if selected < #files then
                    selected = selected + 1
                end
            elseif code == 28 then -- Enter
                if files[selected] then
                    if files[selected].isDir then
                        currentDir = files[selected].path
                        selected = 1
                        refreshFiles()
                    else
                        -- Простой просмотр
                        local file = io.open(files[selected].path, "r")
                        if file then
                            gpu.setBackground(0x000000)
                            gpu.setForeground(0xFFFFFF)
                            term.clear()
                            print("=== " .. files[selected].name .. " ===")
                            local content = file:read("*a")
                            if #content > 1000 then
                                print(content:sub(1, 1000) .. "...")
                            else
                                print(content)
                            end
                            file:close()
                            print("\nНажмите любую клавишу...")
                            event.pull("key_down")
                        end
                    end
                end
            elseif code == 59 then -- F1
                -- Простая справка
                gpu.setBackground(0x000000)
                gpu.setForeground(0xFFFFFF)
                term.clear()
                print("=== Asmelit OS ===")
                print("Управление:")
                print("  Стрелки - навигация")
                print("  Enter - открыть")
                print("  F1 - эта справка")
                print("  ESC - выход")
                print("\nКоманды в консоли:")
                print("  help - показать команды")
                print("  exit - выход из ОС")
                print("\nНажмите любую клавишу...")
                event.pull("key_down")
            elseif code == 1 then -- ESC
                -- Выход в консоль
                gpu.setBackground(0x000000)
                gpu.setForeground(0xFFFFFF)
                term.clear()
                print("Выход в консоль Asmelit")
                print("Введите 'help' для списка команд")
                break
            end
        end
    end
    
    -- Простая консоль
    print("Asmelit Console > ")
    while true do
        local line = io.read()
        if line == "help" then
            print("Команды:")
            print("  ls - список файлов")
            print("  cd [папка] - сменить папку")
            print("  cat [файл] - просмотреть файл")
            print("  run [файл] - запустить программу")
            print("  exit - выход из ОС")
            print("  reboot - перезагрузка")
        elseif line:sub(1,3) == "cd " then
            local dir = line:sub(4)
            if dir == ".." then
                local last = currentDir:match("(.+)/[^/]+$")
                if last then currentDir = last end
            elseif fs.exists(dir) and fs.isDirectory(dir) then
                currentDir = dir
            else
                local newDir = currentDir .. "/" .. dir
                if fs.exists(newDir) and fs.isDirectory(newDir) then
                    currentDir = newDir
                else
                    print("Папка не найдена")
                end
            end
            print("Текущая папка: " .. currentDir)
        elseif line:sub(1,3) == "cat " then
            local file = line:sub(4)
            local path = currentDir .. "/" .. file
            if fs.exists(path) and not fs.isDirectory(path) then
                local f = io.open(path, "r")
                print(f:read("*a"))
                f:close()
            else
                print("Файл не найден")
            end
        elseif line:sub(1,4) == "run " then
            local file = line:sub(5)
            local path = currentDir .. "/" .. file
            if fs.exists(path) then
                local ok, err = pcall(dofile, path)
                if not ok then
                    print("Ошибка: " .. err)
                end
            else
                print("Файл не найден")
            end
        elseif line == "ls" then
            refreshFiles()
            for _, f in ipairs(files) do
                if f.isDir then
                    print(f.name .. "/")
                else
                    print(f.name)
                end
            end
        elseif line == "exit" then
            computer.shutdown()
        elseif line == "reboot" then
            computer.shutdown(true)
        elseif line == "" then
            -- Ничего
        else
            print("Неизвестная команда. Введите 'help'")
        end
        print("> ")
    end
end

-- =====================================================
-- ГЛАВНАЯ ФУНКЦИЯ
-- =====================================================
function main()
    table.insert(systemLog, "=== ASMELIT OS START ===")
    
    -- Пробуем загрузиться
    local ok, err = pcall(bootScreen)
    if not ok then
        print("Ошибка загрузки: " .. tostring(err))
        os.sleep(2)
    end
    
    -- Пробуем запустить интерфейс
    ok, err = pcall(mainGUI)
    if not ok then
        print("Ошибка GUI: " .. tostring(err))
        print("Запускаю резервную консоль...")
        os.sleep(2)
        require("shell").execute()
    end
end

-- Безопасный запуск
local ok, err = pcall(main)
if not ok then
    print("Критическая ошибка: " .. tostring(err))
    print("Переход к стандартной оболочке...")
    os.sleep(3)
    require("shell").execute()
end
