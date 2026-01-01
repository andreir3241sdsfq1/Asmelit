-- =====================================================
-- Asmelit OS для OpenComputers
-- Версия 1.0
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
local bootTime = math.random(10, 30) -- случайное время загрузки 10-30 сек
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
    
    local startLog = math.max(1, #systemLog - 15)
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
    
    -- Ожидание нажатия
    event.pull("key_down")
    computer.shutdown(true) -- Перезагрузка
end

-- Фоновая проверка на ошибки
function checkForErrors()
    -- Проверка памяти
    if computer.freeMemory() < 512 then
        triggerFatalError("Критическое заполнение буфера памяти")
    end
    
    -- Проверка энергии (если доступно)
    if computer.maxEnergy() > 0 and computer.energy() < 1000 then
        triggerFatalError("Недостаточно энергии")
    end
    
    -- Проверка основного диска
    if not fs.exists("/") then
        triggerFatalError("Файловая система недоступна (диск извлечен?)")
    end
    
    -- Проверка процессора (косвенная)
    local uptime = computer.uptime()
    if uptime - startTime > 3600 then -- Через час работы
        table.insert(systemLog, "Длительная работа системы: " .. uptime .. " тиков")
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
    
    -- Загрузка лого с GitHub
    local function loadLogo()
        if internet then
            local ok, err = pcall(function()
                local handle = internet.request("https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/refs/heads/main/logo.lua")
                local data = ""
                for chunk in handle do
                    data = data .. chunk
                end
                logoData = data
                table.insert(systemLog, "Лого загружено с GitHub")
            end)
            if not ok then
                logoData = "Asmelit OS v1.0"
                table.insert(systemLog, "Не удалось загрузить лого, используется стандартное")
            end
        else
            logoData = "Asmelit OS v1.0"
            table.insert(systemLog, "Интернет-карта отсутствует, используется стандартное лого")
        end
    end
    
    -- Диагностика системы
    local function systemDiagnostics()
        table.insert(systemLog, "=== ДИАГНОСТИКА СИСТЕМЫ ===")
        
        -- Проверка памяти
        local freeMem = computer.freeMemory()
        local totalMem = computer.totalMemory()
        table.insert(systemLog, string.format("Память: %d/%d байт", freeMem, totalMem))
        
        if freeMem < 1024 then
            triggerFatalError("Недостаточно памяти для запуска ОС")
        end
        
        -- Проверка компонентов
        local components = component.list()
        local compCount = 0
        for addr, type in pairs(components) do
            compCount = compCount + 1
        end
        table.insert(systemLog, string.format("Найдено компонентов: %d", compCount))
        
        -- Проверка файловой системы
        if not fs.exists("/home") then
            table.insert(systemLog, "ВНИМАНИЕ: Домашняя директория не найдена")
        end
        
        -- Проверка энергии
        local energy = computer.energy()
        local maxEnergy = computer.maxEnergy()
        if maxEnergy > 0 then
            local percent = math.floor((energy / maxEnergy) * 100)
            table.insert(systemLog, string.format("Энергия: %d%%", percent))
        end
        
        table.insert(systemLog, "Диагностика завершена")
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
            gpu.setBackground(0x00FF00) -- Зеленый
            gpu.fill(barStartX, barY, filled, 1, "█")
        end
        
        -- Отрисовка незаполненной части
        if filled < barWidth then
            gpu.setBackground(0x333333) -- Темно-серый
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
        end
        
        local logoStartY = centerY - math.floor(#lines / 2) - 2
        for i, line in ipairs(lines) do
            local x = centerX - math.floor(#line / 2)
            gpu.set(x, logoStartY + i, line)
        end
    else
        local title = "ASMELIT OS"
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
        
        -- Случайные проверки во время загрузки
        if math.random() < 0.3 then
            local checkName = {"Файловая система", "Сеть", "Память", "Процессор"}
            local check = checkName[math.random(1, #checkName)]
            table.insert(systemLog, string.format("Проверка: %s... OK", check))
        end
        
        os.sleep(0.5)
        elapsed = elapsed + 0.5
    end
    
    -- Завершение загрузки
    drawProgressBar(1.0)
    os.sleep(1)
end

-- =====================================================
-- 2. ОСНОВНОЙ ИНТЕРФЕЙС И ФАЙЛОВЫЙ МЕНЕДЖЕР
-- =====================================================
function mainGUI()
    local currentDir = "/home"
    local files = {}
    local selected = 1
    local mode = "browser" -- browser, command, editor
    
    -- Цвета как в DOS
    local colorsDOS = {
        background = 0x0000AA, -- Синий фон
        text = 0xFFFFFF,      -- Белый текст
        highlight = 0xAAAA00, -- Желтый выделение
        directory = 0x00AAAA, -- Голубой для папок
        file = 0x00FF00      -- Зеленый для файлов
    }
    
    -- Обновление списка файлов
    local function refreshFiles()
        files = {}
        if fs.exists(currentDir) and fs.isDirectory(currentDir) then
            for item in fs.list(currentDir) do
                local path = currentDir .. "/" .. item
                local isDir = fs.isDirectory(path)
                table.insert(files, {
                    name = item,
                    isDir = isDir,
                    size = isDir and "<DIR>" or tostring(fs.size(path)),
                    path = path
                })
            end
        end
        table.sort(files, function(a, b)
            if a.isDir and not b.isDir then return true
            elseif not a.isDir and b.isDir then return false
            else return a.name:lower() < b.name:lower() end
        end)
    end
    
    -- Отрисовка интерфейса
    local function drawInterface()
        -- Очистка и фон
        gpu.setBackground(colorsDOS.background)
        gpu.setForeground(colorsDOS.text)
        term.clear()
        
        -- Заголовок
        gpu.fill(1, 1, maxWidth, 1, " ")
        local title = "Asmelit OS - " .. currentDir
        gpu.set(math.floor((maxWidth - #title) / 2), 1, title)
        
        -- Панель файлов
        gpu.set(1, 3, "Имя")
        gpu.set(30, 3, "Тип")
        gpu.set(40, 3, "Размер")
        
        local y = 5
        for i, file in ipairs(files) do
            if y < maxHeight - 5 then
                -- Выделение выбранного файла
                if i == selected then
                    gpu.setBackground(colorsDOS.highlight)
                    gpu.setForeground(0x000000)
                else
                    gpu.setBackground(colorsDOS.background)
                    gpu.setForeground(file.isDir and colorsDOS.directory or colorsDOS.file)
                end
                
                -- Очистка строки
                gpu.fill(1, y, maxWidth, 1, " ")
                
                -- Данные файла
                gpu.set(1, y, file.name)
                gpu.set(30, y, file.isDir and "Папка" or "Файл")
                gpu.set(40, y, file.size)
                
                y = y + 1
            end
        end
        
        -- Статус бар
        gpu.setBackground(0x000000)
        gpu.setForeground(0xFFFFFF)
        gpu.fill(1, maxHeight - 2, maxWidth, 1, " ")
        
        local status = string.format("Файлов: %d | Память: %d/%d | F1-Справка | F3-Редакт. | F5-Обновить",
            #files, computer.freeMemory(), computer.totalMemory())
        gpu.set(1, maxHeight - 2, status)
        
        -- Командная строка
        gpu.fill(1, maxHeight, maxWidth, 1, " ")
        gpu.set(1, maxHeight, currentDir .. "> ")
        
        gpu.setBackground(colorsDOS.background)
        gpu.setForeground(colorsDOS.text)
    end
    
    -- Всплывающее окно
    local function showMessageBox(title, text)
        local width = math.min(maxWidth - 10, 70)
        local lines = {}
        
        for line in text:gmatch("[^\r\n]+") do
            while #line > width - 4 do
                table.insert(lines, line:sub(1, width - 4))
                line = line:sub(width - 3)
            end
            table.insert(lines, line)
        end
        
        local height = math.min(#lines + 6, maxHeight - 10)
        local x = math.floor((maxWidth - width) / 2)
        local y = math.floor((maxHeight - height) / 2)
        
        -- Рамка
        gpu.setBackground(0x000000)
        gpu.setForeground(0xFFFFFF)
        gpu.fill(x, y, width, height, " ")
        gpu.fill(x + 1, y + 1, width - 2, height - 2, " ")
        
        -- Заголовок
        gpu.setBackground(0x0000AA)
        gpu.fill(x, y, width, 1, " ")
        local titleX = x + math.floor((width - #title) / 2)
        gpu.set(titleX, y, title)
        
        -- Текст
        gpu.setBackground(0x000000)
        for i, line in ipairs(lines) do
            if i <= height - 5 then
                gpu.set(x + 2, y + 2 + i, line)
            end
        end
        
        -- Кнопка OK
        gpu.setBackground(0x00AA00)
        gpu.fill(x + math.floor(width/2) - 4, y + height - 2, 8, 1, " ")
        gpu.set(x + math.floor(width/2) - 1, y + height - 2, "OK")
        
        -- Ожидание нажатия
        while true do
            local eventType, _, xClick, yClick = event.pull("touch")
            if eventType == "touch" then
                if yClick == y + height - 2 and 
                   xClick >= x + math.floor(width/2) - 4 and 
                   xClick <= x + math.floor(width/2) + 4 then
                    break
                end
            end
        end
    end
    
    -- Редактор файлов
    local function openEditor(filePath)
        mode = "editor"
        local content = ""
        
        if fs.exists(filePath) then
            local file = io.open(filePath, "r")
            content = file:read("*a")
            file:close()
        end
        
        gpu.setBackground(0x000000)
        gpu.setForeground(0xFFFFFF)
        term.clear()
        
        local title = "Редактор: " .. filePath
        gpu.set(math.floor((maxWidth - #title) / 2), 1, title)
        gpu.set(1, 3, "F1 - Сохранить и выйти | ESC - Выход без сохранения")
        
        -- Отображение текста
        local lines = {}
        for line in content:gmatch("[^\r\n]*") do
            table.insert(lines, line)
        end
        
        local offset = 0
        local cursorX, cursorY = 1, 5
        
        while true do
            -- Отображение текста
            for i = 1, maxHeight - 5 do
                local lineNum = i + offset
                if lines[lineNum] then
                    gpu.set(1, 4 + i, lines[lineNum] .. " ")
                else
                    gpu.fill(1, 4 + i, maxWidth, 1, " ")
                end
            end
            
            -- Курсор
            gpu.set(cursorX, cursorY, "_")
            
            local eventType, _, char, code = event.pull()
            
            if eventType == "key_down" then
                gpu.set(cursorX, cursorY, " ") -- Убрать курсор
                
                if code == 28 then -- Enter
                    table.insert(lines, offset + cursorY - 4, "")
                    cursorY = cursorY + 1
                    cursorX = 1
                    
                elseif code == 14 then -- Backspace
                    if cursorX > 1 then
                        local line = lines[offset + cursorY - 4] or ""
                        lines[offset + cursorY - 4] = line:sub(1, cursorX - 2) .. line:sub(cursorX)
                        cursorX = cursorX - 1
                    end
                    
                elseif code == 200 then -- Up
                    if cursorY > 5 then
                        cursorY = cursorY - 1
                    elseif offset > 0 then
                        offset = offset - 1
                    end
                    
                elseif code == 208 then -- Down
                    if cursorY < maxHeight - 1 then
                        cursorY = cursorY + 1
                    elseif offset + maxHeight - 5 < #lines then
                        offset = offset + 1
                    end
                    
                elseif code == 203 then -- Left
                    if cursorX > 1 then
                        cursorX = cursorX - 1
                    end
                    
                elseif code == 205 then -- Right
                    cursorX = cursorX + 1
                    
                elseif code == 59 then -- F1 (Сохранить)
                    local file = io.open(filePath, "w")
                    for _, line in ipairs(lines) do
                        file:write(line .. "\n")
                    end
                    file:close()
                    table.insert(systemLog, "Сохранен файл: " .. filePath)
                    break
                    
                elseif code == 1 then -- ESC
                    break
                    
                elseif char ~= 0 then
                    local line = lines[offset + cursorY - 4] or ""
                    lines[offset + cursorY - 4] = line:sub(1, cursorX - 1) .. string.char(char) .. line:sub(cursorX)
                    cursorX = cursorX + 1
                end
            end
        end
        
        mode = "browser"
        refreshFiles()
    end
    
    -- Выполнение команды
    local function executeCommand(cmd)
        table.insert(systemLog, "Выполнена команда: " .. cmd)
        
        local parts = {}
        for part in cmd:gmatch("%S+") do
            table.insert(parts, part)
        end
        
        if #parts == 0 then return end
        
        local command = parts[1]:lower()
        
        if command == "cd" then
            -- Смена директории
            if #parts > 1 then
                local newDir = parts[2]
                if newDir == ".." then
                    -- На уровень вверх
                    local lastSlash = currentDir:sub(1, -2):find(".*/")
                    if lastSlash then
                        currentDir = currentDir:sub(1, lastSlash)
                    end
                elseif newDir:sub(1, 1) == "/" then
                    -- Абсолютный путь
                    currentDir = newDir
                else
                    -- Относительный путь
                    currentDir = currentDir .. "/" .. newDir
                end
                
                if not fs.exists(currentDir) or not fs.isDirectory(currentDir) then
                    currentDir = "/home"
                end
                
                -- Убираем двойные слеши
                currentDir = currentDir:gsub("//+", "/")
                selected = 1
                refreshFiles()
            end
            
        elseif command == "edit" then
            -- Редактирование файла
            if #parts > 1 then
                local fileName = parts[2]
                if fileName:sub(1, 1) ~= "/" then
                    fileName = currentDir .. "/" .. fileName
                end
                openEditor(fileName)
            end
            
        elseif command == "del" or command == "rm" then
            -- Удаление файла/папки
            if #parts > 1 then
                local target = parts[2]
                if target:sub(1, 1) ~= "/" then
                    target = currentDir .. "/" .. target
                end
                
                if fs.exists(target) then
                    fs.remove(target)
                    refreshFiles()
                    table.insert(systemLog, "Удален: " .. target)
                end
            end
            
        elseif command == "mkdir" then
            -- Создание папки
            if #parts > 1 then
                local dirName = parts[2]
                if dirName:sub(1, 1) ~= "/" then
                    dirName = currentDir .. "/" .. dirName
                end
                fs.makeDirectory(dirName)
                refreshFiles()
                table.insert(systemLog, "Создана папка: " .. dirName)
            end
            
        elseif command == "copy" then
            -- Копирование файла
            if #parts > 2 then
                local src = parts[2]
                local dst = parts[3]
                
                if src:sub(1, 1) ~= "/" then src = currentDir .. "/" .. src end
                if dst:sub(1, 1) ~= "/" then dst = currentDir .. "/" .. dst end
                
                if fs.exists(src) and not fs.isDirectory(src) then
                    local srcFile = io.open(src, "r")
                    local dstFile = io.open(dst, "w")
                    dstFile:write(srcFile:read("*a"))
                    srcFile:close()
                    dstFile:close()
                    refreshFiles()
                    table.insert(systemLog, "Скопировано: " .. src .. " -> " .. dst)
                end
            end
            
        elseif command == "type" or command == "cat" then
            -- Просмотр файла
            if #parts > 1 then
                local fileName = parts[2]
                if fileName:sub(1, 1) ~= "/" then
                    fileName = currentDir .. "/" .. fileName
                end
                
                if fs.exists(fileName) and not fs.isDirectory(fileName) then
                    local file = io.open(fileName, "r")
                    showMessageBox("Содержимое: " .. fileName, file:read("*a"))
                    file:close()
                end
            end
            
        elseif command == "run" then
            -- Запуск программы
            if #parts > 1 then
                local progName = parts[2]
                if progName:sub(1, 1) ~= "/" then
                    progName = currentDir .. "/" .. progName
                end
                
                if fs.exists(progName) then
                    local ok, err = pcall(function()
                        dofile(progName)
                    end)
                    if not ok then
                        showMessageBox("Ошибка выполнения", err)
                    end
                end
            end
            
        elseif command == "log" then
            -- Просмотр логов системы
            local logText = table.concat(systemLog, "\n")
            showMessageBox("Логи системы", logText)
            
        elseif command == "clear" then
            -- Очистка логов
            systemLog = {}
            table.insert(systemLog, "Логи очищены")
            
        elseif command == "help" then
            -- Справка
            local helpText = [[
Команды Asmelit OS:
  cd [папка]      - сменить директорию
  edit [файл]     - редактировать файл
  del/rm [файл]   - удалить файл/папку
  mkdir [папка]   - создать папку
  copy src dst    - копировать файл
  type/cat [файл] - просмотреть файл
  run [программа] - запустить программу
  log             - показать логи системы
  clear           - очистить логи
  help            - эта справка
  exit            - выход из системы
  
Горячие клавиши:
  F1 - Справка
  F3 - Редактировать
  F5 - Обновить список
  Стрелки - навигация
  Enter - открыть/запустить
            ]]
            showMessageBox("Справка", helpText)
            
        elseif command == "exit" then
            -- Выход из системы
            computer.shutdown()
            
        else
            -- Неизвестная команда
            showMessageBox("Ошибка", "Неизвестная команда: " .. command)
        end
    end
    
    -- Основной цикл GUI
    refreshFiles()
    
    while true do
        -- Проверка на ошибки
        checkForErrors()
        
        drawInterface()
        
        local commandBuffer = ""
        local processingEvents = true
        
        while processingEvents do
            local eventType, _, char, code, _
            
            if mode == "browser" then
                local result = {event.pull(0.1, "key_down", "touch")}
                if #result > 0 then
                    eventType = result[1]
                    char = result[3]
                    code = result[4]
                end
            else
                processingEvents = false
            end
            
            if not eventType then
                -- Таймаут, продолжаем
                -- Ничего не делаем, просто продолжаем цикл
            else
                if eventType == "key_down" then
                    -- Функциональные клавиши
                    if code == 59 then -- F1
                        executeCommand("help")
                        processingEvents = false
                        
                    elseif code == 61 then -- F3
                        -- Редактировать выбранный файл
                        if files[selected] and not files[selected].isDir then
                            openEditor(files[selected].path)
                            processingEvents = false
                        end
                        
                    elseif code == 63 then -- F5
                        refreshFiles()
                        processingEvents = false
                        
                    elseif code == 200 then -- Up
                        if selected > 1 then
                            selected = selected - 1
                            processingEvents = false
                        end
                        
                    elseif code == 208 then -- Down
                        if selected < #files then
                            selected = selected + 1
                            processingEvents = false
                        end
                        
                    elseif code == 28 then -- Enter
                        if files[selected] then
                            if files[selected].isDir then
                                executeCommand("cd " .. files[selected].name)
                            else
                                executeCommand("type " .. files[selected].name)
                            end
                            processingEvents = false
                        end
                        
                    elseif code == 210 then -- Insert
                        -- Ввод команды
                        mode = "command"
                        gpu.set(1, maxHeight, currentDir .. "> ")
                        processingEvents = false
                        
                    elseif char ~= 0 then
                        -- Начало ввода команды
                        mode = "command"
                        commandBuffer = string.char(char)
                        gpu.set(#currentDir + 3, maxHeight, commandBuffer)
                        processingEvents = false
                    end
                    
                elseif eventType == "touch" then
                    -- Обработка касания (для сенсорных экранов)
                    -- Можно добавить позже
                end
            end
        end
        
        -- Режим командной строки
        if mode == "command" then
            gpu.setBackground(0x000000)
            gpu.setForeground(0xFFFFFF)
            gpu.fill(1, maxHeight, maxWidth, 1, " ")
            gpu.set(1, maxHeight, currentDir .. "> " .. commandBuffer .. "_")
            
            local inputting = true
            while inputting do
                local eventType, _, char, code = event.pull("key_down")
                
                if code == 28 then -- Enter
                    executeCommand(commandBuffer)
                    commandBuffer = ""
                    mode = "browser"
                    inputting = false
                    
                elseif code == 14 then -- Backspace
                    if #commandBuffer > 0 then
                        commandBuffer = commandBuffer:sub(1, -2)
                        gpu.set(#currentDir + 3, maxHeight, commandBuffer .. "  ")
                        gpu.set(#currentDir + 3 + #commandBuffer, maxHeight, "_")
                    end
                    
                elseif code == 1 then -- ESC
                    commandBuffer = ""
                    mode = "browser"
                    inputting = false
                    
                elseif char ~= 0 then
                    commandBuffer = commandBuffer .. string.char(char)
                    gpu.set(#currentDir + 3, maxHeight, commandBuffer .. "_")
                end
            end
        end
    end
end

-- =====================================================
-- ГЛАВНАЯ ФУНКЦИЯ ЗАПУСКА ОС
-- =====================================================
function main()
    -- Регистрация в логах
    table.insert(systemLog, "=== ASMELIT OS START ===")
    table.insert(systemLog, "Время загрузки: " .. bootTime .. " сек")
    table.insert(systemLog, "Разрешение: " .. maxWidth .. "x" .. maxHeight)
    
    -- Запуск
    local ok, err = pcall(bootScreen)
    if not ok then
        -- Если загрузочный экран упал
        gpu.setBackground(0xFF0000)
        gpu.setForeground(0xFFFFFF)
        term.clear()
        gpu.set(1, 1, "Ошибка при загрузке: " .. err)
        os.sleep(5)
        computer.shutdown()
    end
    
    -- Запуск основного интерфейса
    ok, err = pcall(mainGUI)
    if not ok then
        triggerFatalError("Ошибка в основном интерфейсе: " .. err)
    end
end

-- Запуск системы с обработкой ошибок
local ok, err = pcall(main)
if not ok then
    -- Последний шанс показать ошибку
    gpu.setBackground(0xFF0000)
    gpu.setForeground(0xFFFFFF)
    term.clear()
    gpu.set(1, 1, "КРИТИЧЕСКИЙ СБОЙ СИСТЕМЫ")
    gpu.set(1, 3, err)
    gpu.set(1, 5, "Система будет перезагружена через 10 секунд...")
    os.sleep(10)
    computer.shutdown(true)
end
