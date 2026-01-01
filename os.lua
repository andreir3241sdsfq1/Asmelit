-- =====================================================
-- Asmelit OS v2.1
-- Исправлены ошибки, улучшен GUI
-- =====================================================

-- Основные библиотеки
local component = require("component")
local computer = require("computer")
local event = require("event")
local term = require("term")
local gpu = component.gpu
local fs = require("filesystem")
local serialization = require("serialization")

-- Переменные системы
local systemLog = {}
local startTime = computer.uptime()
local maxWidth, maxHeight = gpu.getResolution()
local centerX = math.floor(maxWidth / 2)
local centerY = math.floor(maxHeight / 2)

-- Цветовая схема
local colors = {
    background = 0x001122,
    header = 0x003366,
    sidebar = 0x002244,
    text = 0xFFFFFF,
    highlight = 0x00AAFF,
    success = 0x00FF00,
    error = 0xFF0000,
    warning = 0xFFFF00,
    info = 0x00AAFF
}

-- Логирование
function log(message)
    table.insert(systemLog, os.date("%H:%M:%S") .. " - " .. message)
    if #systemLog > 50 then
        table.remove(systemLog, 1)
    end
end

-- Обработка ошибок
function safeCall(func, errorMsg)
    local ok, result = pcall(func)
    if not ok then
        log("ОШИБКА: " .. tostring(result))
        if errorMsg then
            showMessage(errorMsg)
        end
        return nil
    end
    return result
end

-- Показать сообщение
function showMessage(text, color)
    color = color or colors.text
    gpu.setBackground(0x000000)
    gpu.setForeground(color)
    term.clear()
    
    local lines = {}
    for line in text:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    
    for i, line in ipairs(lines) do
        local x = centerX - math.floor(#line / 2)
        gpu.set(x, centerY - math.floor(#lines / 2) + i, line)
    end
    
    gpu.set(centerX - 10, maxHeight - 2, "Нажмите любую клавишу...")
    event.pull("key_down")
end

-- Загрузочный экран
function bootScreen()
    safeCall(function()
        gpu.setBackground(0x000000)
        gpu.setForeground(colors.highlight)
        term.clear()
        
        -- Пробуем загрузить лого из файла
        local logoText = "ASMELIT OS v2.1"
        if fs.exists("/home/logo.lua") then
            local file = io.open("/home/logo.lua", "r")
            if file then
                local content = file:read("*a")
                file:close()
                if #content > 10 then -- Проверяем что файл не пустой
                    logoText = content
                end
            end
        end
        
        -- Отображение лого
        local logoLines = {}
        for line in logoText:gmatch("[^\r\n]+") do
            table.insert(logoLines, line)
        end
        
        -- Располагаем лого вверху по центру
        local logoStartY = 3
        for i, line in ipairs(logoLines) do
            local x = centerX - math.floor(#line / 2)
            if logoStartY + i < maxHeight - 10 then -- Не выходим за экран
                gpu.set(x, logoStartY + i, line)
            end
        end
        
        -- Шкала загрузки
        local barWidth = 40
        local barX = centerX - math.floor(barWidth / 2)
        local barY = logoStartY + #logoLines + 3
        
        if barY < maxHeight - 5 then
            gpu.set(barX, barY - 1, "Загрузка системы...")
            
            for i = 1, barWidth do
                gpu.setBackground(colors.highlight)
                gpu.set(barX + i - 1, barY, "█")
                gpu.setBackground(0x000000)
                os.sleep(0.02)
            end
            
            gpu.set(barX, barY + 2, "Готово!")
            os.sleep(1)
        end
        
        log("Система загружена")
    end, "Ошибка загрузочного экрана")
end

-- Основной GUI
function mainGUI()
    local currentDir = "/home"
    local files = {}
    local selected = 1
    local mode = "files" -- files, console, apps, settings, info
    local sidebarWidth = 20
    
    -- Безопасное обновление файлов
    local function refreshFiles()
        files = {}
        if fs.exists(currentDir) and fs.isDirectory(currentDir) then
            local success, list = pcall(function()
                local listResult = {}
                for item in fs.list(currentDir) do
                    local path = currentDir .. "/" .. item
                    local isDir = fs.isDirectory(path)
                    table.insert(listResult, {
                        name = item,
                        isDir = isDir,
                        size = isDir and "<DIR>" or tostring(fs.size(path) or "?"),
                        path = path
                    })
                end
                return listResult
            end)
            
            if success then
                files = list
                table.sort(files, function(a, b)
                    if a.isDir and not b.isDir then return true
                    elseif not a.isDir and b.isDir then return false
                    else return a.name:lower() < b.name:lower() end
                end)
            end
        end
    end
    
    -- Безопасное удаление файла
    local function safeDeleteFile(path)
        if not path then return false end
        
        local ok, err = pcall(function()
            if fs.exists(path) then
                return fs.remove(path)
            end
            return false
        end)
        
        if not ok then
            log("Ошибка удаления: " .. tostring(err))
            return false
        end
        
        return ok
    end
    
    -- Отрисовка интерфейса
    local function drawInterface()
        safeCall(function()
            -- Фон
            gpu.setBackground(colors.background)
            gpu.setForeground(colors.text)
            term.clear()
            
            -- Верхняя панель
            gpu.setBackground(colors.header)
            gpu.fill(1, 1, maxWidth, 1, " ")
            
            local title = "Asmelit OS"
            if mode == "files" then
                title = title .. " - " .. currentDir
            elseif mode == "console" then
                title = title .. " - Консоль"
            elseif mode == "apps" then
                title = title .. " - Приложения"
            elseif mode == "settings" then
                title = title .. " - Настройки"
            elseif mode == "info" then
                title = title .. " - О системе"
            end
            
            gpu.set(2, 1, title)
            
            -- Время и память
            local time = os.date("%H:%M:%S")
            local mem = math.floor(computer.freeMemory() / 1024) .. "K"
            local statusText = time .. " | " .. mem
            
            gpu.set(maxWidth - #statusText - 1, 1, statusText)
            
            -- Боковая панель
            gpu.setBackground(colors.sidebar)
            gpu.fill(1, 2, sidebarWidth, maxHeight - 1, " ")
            
            local menuItems = {
                {icon = "📁", text = "Файлы", mode = "files"},
                {icon = "💻", text = "Консоль", mode = "console"},
                {icon = "🚀", text = "Приложения", mode = "apps"},
                {icon = "⚙️", text = "Настройки", mode = "settings"},
                {icon = "ℹ️", text = "О системе", mode = "info"}
            }
            
            for i, item in ipairs(menuItems) do
                local y = 2 + i * 2
                if mode == item.mode then
                    gpu.setBackground(colors.highlight)
                    gpu.setForeground(0x000000)
                else
                    gpu.setBackground(colors.sidebar)
                    gpu.setForeground(colors.text)
                end
                
                gpu.fill(1, y, sidebarWidth, 1, " ")
                gpu.set(2, y, item.icon .. " " .. item.text)
            end
            
            -- Основная область
            gpu.setBackground(colors.background)
            gpu.setForeground(colors.text)
            
            if mode == "files" then
                local startX = sidebarWidth + 3
                
                -- Заголовки
                if maxHeight > 5 then
                    gpu.set(startX, 3, "Имя")
                    gpu.set(startX + 30, 3, "Тип")
                    gpu.set(startX + 40, 3, "Размер")
                end
                
                -- Файлы
                local y = 5
                for i, file in ipairs(files) do
                    if y < maxHeight - 2 then
                        if i == selected then
                            gpu.setBackground(colors.highlight)
                            gpu.setForeground(0x000000)
                        else
                            gpu.setBackground(colors.background)
                            gpu.setForeground(file.isDir and colors.info or colors.text)
                        end
                        
                        -- Очистка строки
                        gpu.fill(startX, y, maxWidth - sidebarWidth - 2, 1, " ")
                        
                        -- Данные
                        local displayName = file.name
                        if file.isDir then displayName = displayName .. "/" end
                        
                        gpu.set(startX, y, displayName)
                        gpu.set(startX + 30, y, file.isDir and "Папка" or "Файл")
                        gpu.set(startX + 40, y, file.size)
                        
                        y = y + 1
                    end
                end
                
            elseif mode == "console" then
                -- Консоль будет обрабатываться отдельно
                local startX = sidebarWidth + 3
                gpu.set(startX, 3, "Asmelit Console v2.1")
                gpu.set(startX, 4, string.rep("═", maxWidth - sidebarWidth - 4))
                gpu.set(startX, 6, "Введите команду и нажмите Enter")
                gpu.set(startX, 7, "Для справки введите 'help'")
                gpu.set(startX, 8, "> ")
                
            elseif mode == "apps" then
                local startX = sidebarWidth + 3
                gpu.set(startX, 3, "📱 Доступные приложения")
                
                local apps = {
                    {name = "Редактор", desc = "Текстовый редактор", func = function() 
                        showMessage("Редактор запущен\nESC для выхода") 
                    end},
                    {name = "Калькулятор", desc = "Простой калькулятор", func = function()
                        showMessage("Калькулятор\nESC для выхода")
                    end},
                    {name = "Системный монитор", desc = "Мониторинг ресурсов", func = function()
                        local info = "Память: " .. computer.freeMemory() .. "\n"
                        if computer.maxEnergy() > 0 then
                            info = info .. "Энергия: " .. math.floor((computer.energy() / computer.maxEnergy()) * 100) .. "%\n"
                        end
                        info = info .. "Время: " .. math.floor(computer.uptime() / 60) .. " мин"
                        showMessage("Системный монитор:\n" .. info)
                    end}
                }
                
                local x, y = startX, 5
                for i, app in ipairs(apps) do
                    if y < maxHeight - 5 then
                        gpu.setBackground(0x003333)
                        gpu.fill(x, y, 25, 4, " ")
                        gpu.setForeground(colors.text)
                        
                        gpu.set(x + 2, y + 1, "▶ " .. app.name)
                        gpu.set(x + 2, y + 2, app.desc)
                        
                        x = x + 27
                        if x > maxWidth - 25 then
                            x = startX
                            y = y + 6
                        end
                    end
                end
                
            elseif mode == "settings" then
                local startX = sidebarWidth + 3
                gpu.set(startX, 3, "⚙️ Настройки системы")
                gpu.set(startX, 5, "Цветовая схема: [Темная | Синяя]")
                gpu.set(startX, 7, "Автозагрузка: [Вкл | Выкл]")
                gpu.set(startX, 9, "Безопасность: [Стандарт | Повыш.]")
                
            elseif mode == "info" then
                local startX = sidebarWidth + 3
                gpu.set(startX, 3, "ℹ️ Информация о системе")
                
                local info = {
                    "Версия: Asmelit OS 2.1",
                    "Память: " .. computer.freeMemory() .. "/" .. computer.totalMemory(),
                    "Время работы: " .. math.floor((computer.uptime() - startTime) / 60) .. " мин",
                    "Логов: " .. #systemLog .. " записей"
                }
                
                if computer.maxEnergy() > 0 then
                    table.insert(info, "Энергия: " .. math.floor((computer.energy() / computer.maxEnergy()) * 100) .. "%")
                end
                
                for i, line in ipairs(info) do
                    gpu.set(startX, 5 + i, line)
                end
            end
            
            -- Нижняя строка
            gpu.setBackground(colors.header)
            gpu.setForeground(colors.text)
            gpu.fill(1, maxHeight, maxWidth, 1, " ")
            
            local status = ""
            if mode == "files" then
                status = "↑↓-Навигация | Enter-Открыть | F2-Новый | F3-Редакт. | Del-Удалить | ESC-Выход"
            elseif mode == "console" then
                status = "Введите команду | ESC-Выход"
            else
                status = "ESC - Назад в файлы"
            end
            
            gpu.set(2, maxHeight, status)
        end, "Ошибка отрисовки интерфейса")
    end
    
    -- Консоль
    local function runConsole()
        local consoleHistory = {}
        local historyIndex = 0
        local consoleText = ""
        
        while mode == "console" do
            drawInterface()
            
            local startX = sidebarWidth + 3
            gpu.set(startX, maxHeight - 5, "> " .. consoleText .. "_")
            
            local eventType, _, char, code = event.pull("key_down")
            
            if code == 28 then -- Enter
                if #consoleText > 0 then
                    table.insert(consoleHistory, consoleText)
                    historyIndex = #consoleHistory + 1
                    
                    local cmd = consoleText:lower()
                    
                    if cmd == "help" then
                        showMessage("Команды:\nhelp - справка\nclear - очистка\nls - файлы\ncd [папка] - смена папки\ncat [файл] - просмотр\nrun [файл] - запуск\nsysinfo - информация\nreboot - перезагрузка\nexit - выход", colors.info)
                    elseif cmd == "clear" then
                        -- Просто выходим и заново рисуем
                    elseif cmd == "ls" then
                        refreshFiles()
                        local fileList = ""
                        for _, file in ipairs(files) do
                            fileList = fileList .. (file.isDir and file.name .. "/\n" or file.name .. "\n")
                        end
                        showMessage("Файлы в " .. currentDir .. ":\n" .. fileList, colors.text)
                    elseif cmd:sub(1,3) == "cd " then
                        local newDir = cmd:sub(4)
                        if newDir == ".." then
                            local last = currentDir:match("(.+)/[^/]+$")
                            if last then currentDir = last end
                        else
                            local testPath = currentDir .. "/" .. newDir
                            if fs.exists(testPath) and fs.isDirectory(testPath) then
                                currentDir = testPath
                            elseif fs.exists(newDir) and fs.isDirectory(newDir) then
                                currentDir = newDir
                            else
                                showMessage("Папка не найдена: " .. newDir, colors.error)
                            end
                        end
                        refreshFiles()
                    elseif cmd:sub(1,4) == "cat " then
                        local fileName = cmd:sub(5)
                        local path = currentDir .. "/" .. fileName
                        if fs.exists(path) and not fs.isDirectory(path) then
                            local file = io.open(path, "r")
                            if file then
                                showMessage("Содержимое " .. fileName .. ":\n" .. file:read("*a"), colors.text)
                                file:close()
                            end
                        else
                            showMessage("Файл не найден: " .. fileName, colors.error)
                        end
                    elseif cmd:sub(1,4) == "run " then
                        local fileName = cmd:sub(5)
                        local path = currentDir .. "/" .. fileName
                        if fs.exists(path) then
                            local ok, err = pcall(dofile, path)
                            if not ok then
                                showMessage("Ошибка запуска: " .. tostring(err), colors.error)
                            end
                        else
                            showMessage("Файл не найден: " .. fileName, colors.error)
                        end
                    elseif cmd == "sysinfo" then
                        local info = "Память: " .. computer.freeMemory() .. "\n"
                        info = info .. "Время: " .. math.floor(computer.uptime() / 60) .. " мин\n"
                        if computer.maxEnergy() > 0 then
                            info = info .. "Энергия: " .. math.floor((computer.energy() / computer.maxEnergy()) * 100) .. "%"
                        end
                        showMessage("Системная информация:\n" .. info, colors.info)
                    elseif cmd == "reboot" then
                        computer.shutdown(true)
                    elseif cmd == "exit" then
                        mode = "files"
                        return
                    else
                        showMessage("Неизвестная команда: " .. cmd, colors.error)
                    end
                    
                    consoleText = ""
                end
                
            elseif code == 14 then -- Backspace
                consoleText = consoleText:sub(1, -2)
            elseif code == 200 then -- Up
                if historyIndex > 1 then
                    historyIndex = historyIndex - 1
                    consoleText = consoleHistory[historyIndex] or ""
                end
            elseif code == 208 then -- Down
                if historyIndex < #consoleHistory then
                    historyIndex = historyIndex + 1
                    consoleText = consoleHistory[historyIndex] or ""
                end
            elseif code == 1 then -- ESC
                mode = "files"
                return
            elseif char ~= 0 then
                consoleText = consoleText .. string.char(char)
            end
        end
    end
    
    -- Основной цикл
    refreshFiles()
    
    while true do
        -- Проверка памяти
        if computer.freeMemory() < 1024 then
            showMessage("Критически мало памяти!\nПерезагрузите систему.", colors.error)
            computer.shutdown(true)
        end
        
        drawInterface()
        
        if mode == "console" then
            runConsole()
        else
            local eventType, _, char, code, x, y = event.pull()
            
            if eventType == "key_down" then
                -- Глобальные горячие клавиши
                if code == 60 and mode == "files" then -- F2
                    -- Новый файл
                    local fileName = "newfile.txt"
                    local file = io.open(currentDir .. "/" .. fileName, "w")
                    if file then
                        file:write("-- Создано " .. os.date())
                        file:close()
                        refreshFiles()
                        log("Создан файл: " .. fileName)
                    end
                    
                elseif code == 61 and mode == "files" then -- F3
                    -- Простой редактор
                    if files[selected] and not files[selected].isDir then
                        local content = ""
                        local path = files[selected].path
                        
                        if fs.exists(path) then
                            local file = io.open(path, "r")
                            if file then
                                content = file:read("*a")
                                file:close()
                            end
                        end
                        
                        showMessage("Редактор: " .. files[selected].name .. "\n(Функция в разработке)", colors.info)
                    end
                    
                elseif code == 211 and mode == "files" then -- Delete
                    -- Безопасное удаление
                    if files[selected] then
                        local path = files[selected].path
                        if path and path ~= "" then
                            if safeDeleteFile(path) then
                                log("Удален: " .. files[selected].name)
                                refreshFiles()
                                if selected > #files then
                                    selected = #files
                                end
                            else
                                showMessage("Ошибка удаления файла", colors.error)
                            end
                        end
                    end
                    
                elseif code == 200 and mode == "files" then -- Up
                    selected = selected > 1 and selected - 1 or #files
                    
                elseif code == 208 and mode == "files" then -- Down
                    selected = selected < #files and selected + 1 or 1
                    
                elseif code == 28 and mode == "files" then -- Enter
                    if files[selected] then
                        if files[selected].isDir then
                            currentDir = files[selected].path
                            selected = 1
                            refreshFiles()
                        else
                            -- Запуск или просмотр
                            local path = files[selected].path
                            if path:sub(-4) == ".lua" then
                                local ok, err = pcall(dofile, path)
                                if not ok then
                                    showMessage("Ошибка: " .. tostring(err), colors.error)
                                end
                            else
                                local file = io.open(path, "r")
                                if file then
                                    showMessage("Содержимое " .. files[selected].name .. ":\n" .. file:read("*a"), colors.text)
                                    file:close()
                                end
                            end
                        end
                    end
                    
                elseif code == 1 then -- ESC
                    if mode == "files" then
                        -- Выход из ОС
                        showMessage("Завершение работы Asmelit OS...", colors.info)
                        os.sleep(2)
                        computer.shutdown()
                    else
                        mode = "files"
                    end
                    
                -- Быстрые клавиши для смены режима
                elseif char == "f" or char == "а" then -- f или русская а
                    mode = "files"
                elseif char == "c" or char == "с" then -- c или русская с
                    mode = "console"
                    runConsole()
                elseif char == "a" or char == "ф" then -- a или русская ф
                    mode = "apps"
                elseif char == "s" or char == "ы" then -- s или русская ы
                    mode = "settings"
                elseif char == "i" or char == "ш" then -- i или русская ш
                    mode = "info"
                end
                
            elseif eventType == "touch" then
                -- Безопасная обработка касания
                local ok = pcall(function()
                    if y >= 2 and y <= 12 and x <= sidebarWidth then
                        local itemIndex = math.floor((y - 2) / 2) + 1
                        if itemIndex >= 1 and itemIndex <= 5 then
                            local modes = {"files", "console", "apps", "settings", "info"}
                            mode = modes[itemIndex]
                            if mode == "console" then
                                runConsole()
                            end
                        end
                    end
                end)
                
                if not ok then
                    log("Ошибка обработки касания")
                end
            end
        end
    end
end

-- =====================================================
-- ЗАПУСК СИСТЕМЫ
-- =====================================================
log("=== Запуск Asmelit OS v2.1 ===")

-- Проверяем память
if computer.freeMemory() < 2048 then
    showMessage("Мало памяти: " .. computer.freeMemory() .. " байт\nЗапуск безопасного режима...", colors.warning)
    os.sleep(2)
    require("shell").execute()
    return
end

-- Запускаем систему
local ok, err = pcall(bootScreen)
if not ok then
    log("Ошибка загрузки: " .. tostring(err))
end

ok, err = pcall(mainGUI)
if not ok then
    showMessage("Критическая ошибка GUI:\n" .. tostring(err) .. "\nПерезагрузка...", colors.error)
    os.sleep(3)
    computer.shutdown(true)
end
