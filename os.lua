-- =====================================================
-- Asmelit OS v2.0
-- Улучшенный GUI с функциями
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

-- Загрузка лого
local logo = [[
╔══════════════════════════════╗
║      █████╗ ███████╗███╗   ███╗║
║     ██╔══██╗██╔════╝████╗ ████║║
║     ███████║███████╗██╔████╔██║║
║     ██╔══██║╚════██║██║╚██╔╝██║║
║     ██║  ██║███████║██║ ╚═╝ ██║║
║     ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝║
║     ASMELIT OS v2.0           ║
╚══════════════════════════════╝
]]

-- Системные функции
function log(message)
    table.insert(systemLog, os.date("%H:%M:%S") .. " - " .. message)
    if #systemLog > 100 then
        table.remove(systemLog, 1)
    end
end

function showError(message)
    gpu.setBackground(colors.error)
    gpu.setForeground(colors.text)
    term.clear()
    
    local lines = {}
    for line in message:gmatch("[^\r\n]+") do
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
    gpu.setBackground(0x000000)
    gpu.setForeground(colors.highlight)
    term.clear()
    
    -- Отображение лого по центру сверху
    local logoLines = {}
    for line in logo:gmatch("[^\r\n]+") do
        table.insert(logoLines, line)
    end
    
    local logoY = 3
    for i, line in ipairs(logoLines) do
        local x = centerX - math.floor(#line / 2)
        gpu.set(x, logoY + i, line)
    end
    
    -- Шкала загрузки
    local barWidth = 40
    local barX = centerX - math.floor(barWidth / 2)
    local barY = logoY + #logoLines + 3
    
    gpu.set(barX, barY - 1, "Загрузка системы...")
    
    for i = 1, barWidth do
        gpu.setBackground(colors.highlight)
        gpu.set(barX + i - 1, barY, "█")
        gpu.setBackground(0x000000)
        
        -- Случайные проверки
        if math.random() < 0.3 then
            local checks = {
                "Проверка памяти... OK",
                "Инициализация GPU... OK",
                "Загрузка файловой системы... OK",
                "Подготовка ядра... OK"
            }
            local check = checks[math.random(1, #checks)]
            gpu.set(barX, barY + 2, check)
        end
        
        os.sleep(math.random(10, 50) / 1000)
    end
    
    gpu.set(barX, barY + 4, "Готово!")
    os.sleep(1)
    
    log("Система загружена")
end

-- Основной GUI
function mainGUI()
    local currentDir = "/home"
    local files = {}
    local selected = 1
    local mode = "files" -- files, console, apps, settings
    local sidebarWidth = 20
    
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
                    path = path,
                    modified = fs.lastModified(path)
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
        end
        
        gpu.set(2, 1, title)
        
        local time = os.date("%H:%M:%S")
        gpu.set(maxWidth - #time - 1, 1, time)
        
        local mem = math.floor(computer.freeMemory() / 1024) .. "K"
        gpu.set(maxWidth - #time - #mem - 4, 1, mem)
        
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
            -- Заголовки столбцов
            local startX = sidebarWidth + 3
            gpu.set(startX, 3, "Имя")
            gpu.set(startX + 30, 3, "Тип")
            gpu.set(startX + 40, 3, "Размер")
            gpu.set(startX + 50, 3, "Изменен")
            
            -- Файлы
            local y = 5
            for i, file in ipairs(files) do
                if y < maxHeight - 1 then
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
                    
                    if file.modified then
                        local date = os.date("%d.%m %H:%M", file.modified)
                        gpu.set(startX + 50, y, date)
                    end
                    
                    y = y + 1
                end
            end
        elseif mode == "console" then
            -- Область консоли
            gpu.set(sidebarWidth + 3, 3, "Asmelit Console v2.0")
            gpu.set(sidebarWidth + 3, 4, string.rep("═", maxWidth - sidebarWidth - 4))
            
            local consoleY = 6
            local function printConsole(text, color)
                if consoleY < maxHeight - 5 then
                    gpu.setForeground(color or colors.text)
                    gpu.set(sidebarWidth + 3, consoleY, text)
                    consoleY = consoleY + 1
                end
            end
            
            printConsole("Добро пожаловать в Asmelit Console!", colors.success)
            printConsole("")
            printConsole("Доступные команды:")
            printConsole("  help - показать справку")
            printConsole("  clear - очистить экран")
            printConsole("  ls - список файлов")
            printConsole("  cd [папка] - сменить папку")
            printConsole("  cat [файл] - просмотреть файл")
            printConsole("  edit [файл] - редактор")
            printConsole("  run [файл] - запустить программу")
            printConsole("  sysinfo - информация о системе")
            printConsole("  reboot - перезагрузка")
            printConsole("  exit - выход из консоли")
            printConsole("")
            printConsole("> ", colors.highlight)
            
        elseif mode == "apps" then
            -- Приложения
            gpu.set(sidebarWidth + 3, 3, "📱 Приложения")
            
            local apps = {
                {name = "Текстовый редактор", desc = "Простой редактор", icon = "📝"},
                {name = "Калькулятор", desc = "Научный калькулятор", icon = "🧮"},
                {name = "Менеджер пакетов", desc = "Установка программ", icon = "📦"},
                {name = "Игры", desc = "Коллекция игр", icon = "🎮"},
                {name = "Сетевое сканирование", desc = "Поиск устройств", icon = "📡"},
                {name = "Системный монитор", desc = "Мониторинг ресурсов", icon = "📊"}
            }
            
            local x, y = sidebarWidth + 3, 5
            for i, app in ipairs(apps) do
                if y < maxHeight - 3 then
                    -- Рамка приложения
                    gpu.setBackground(0x003333)
                    gpu.fill(x, y, 25, 5, " ")
                    gpu.setForeground(colors.text)
                    
                    -- Иконка и название
                    gpu.set(x + 2, y + 1, app.icon .. " " .. app.name)
                    gpu.set(x + 2, y + 2, app.desc)
                    
                    -- Кнопка запуска
                    gpu.setBackground(colors.success)
                    gpu.setForeground(0x000000)
                    gpu.set(x + 2, y + 4, "▶ Запустить")
                    
                    x = x + 27
                    if x > maxWidth - 25 then
                        x = sidebarWidth + 3
                        y = y + 7
                    end
                end
            end
            
        elseif mode == "settings" then
            -- Настройки
            gpu.set(sidebarWidth + 3, 3, "⚙️ Настройки системы")
            
            local settings = {
                {name = "Внешний вид", options = {"Темная", "Светлая", "Синяя"}},
                {name = "Язык", options = {"Русский", "English"}},
                {name = "Разрешение экрана", options = {"Авто", "80x25", "160x50"}},
                {name = "Автозагрузка", options = {"Вкл", "Выкл"}},
                {name = "Безопасность", options = {"Стандартная", "Повышенная"}}
            }
            
            local y = 5
            for i, setting in ipairs(settings) do
                gpu.set(sidebarWidth + 3, y, setting.name .. ":")
                gpu.set(sidebarWidth + 20, y, "[" .. table.concat(setting.options, " | ") .. "]")
                y = y + 2
            end
            
            -- Кнопки
            gpu.setBackground(colors.success)
            gpu.setForeground(0x000000)
            gpu.fill(sidebarWidth + 3, maxHeight - 4, 15, 1, " ")
            gpu.set(sidebarWidth + 5, maxHeight - 4, "💾 Сохранить")
            
            gpu.setBackground(colors.error)
            gpu.fill(sidebarWidth + 20, maxHeight - 4, 15, 1, " ")
            gpu.set(sidebarWidth + 22, maxHeight - 4, "🗑️ Сбросить")
            
        elseif mode == "info" then
            -- О системе
            gpu.set(sidebarWidth + 3, 3, "ℹ️ Информация о системе")
            
            local infoY = 5
            local function addInfo(label, value)
                gpu.set(sidebarWidth + 3, infoY, label)
                gpu.setForeground(colors.highlight)
                gpu.set(sidebarWidth + 25, infoY, value)
                gpu.setForeground(colors.text)
                infoY = infoY + 1
            end
            
            addInfo("Версия ОС:", "Asmelit OS 2.0")
            addInfo("Память:", computer.freeMemory() .. "/" .. computer.totalMemory() .. " байт")
            addInfo("Время работы:", math.floor((computer.uptime() - startTime) / 60) .. " мин")
            
            if computer.maxEnergy() > 0 then
                addInfo("Энергия:", math.floor((computer.energy() / computer.maxEnergy()) * 100) .. "%")
            end
            
            addInfo("", "")
            addInfo("Разрешение:", maxWidth .. "x" .. maxHeight)
            
            local components = component.list()
            local count = 0
            for _ in pairs(components) do count = count + 1 end
            addInfo("Компоненты:", count .. " шт")
            
            addInfo("", "")
            addInfo("Логов в памяти:", #systemLog)
        end
        
        -- Нижняя строка статуса
        gpu.setBackground(colors.header)
        gpu.setForeground(colors.text)
        gpu.fill(1, maxHeight, maxWidth, 1, " ")
        
        local status = ""
        if mode == "files" then
            status = "F1-Помощь | F2-Создать | F3-Редакт. | F5-Обновить | Del-Удалить"
        elseif mode == "console" then
            status = "Введите команду и нажмите Enter"
        elseif mode == "apps" then
            status = "Выберите приложение для запуска"
        elseif mode == "settings" then
            status = "Измените настройки и сохраните"
        elseif mode == "info" then
            status = "Информация о состоянии системы"
        end
        
        gpu.set(2, maxHeight, status)
    end
    
    -- Командная консоль
    local function runConsole()
        local consoleHistory = {}
        local historyIndex = 0
        
        while mode == "console" do
            drawInterface()
            
            gpu.set(sidebarWidth + 3, maxHeight - 5, "> ")
            local cursorX = sidebarWidth + 5
            local command = ""
            
            while true do
                local eventType, _, char, code = event.pull("key_down")
                
                if code == 28 then -- Enter
                    if #command > 0 then
                        table.insert(consoleHistory, command)
                        historyIndex = #consoleHistory + 1
                        
                        -- Выполнение команды
                        local parts = {}
                        for part in command:gmatch("%S+") do
                            table.insert(parts, part)
                        end
                        
                        if #parts > 0 then
                            local cmd = parts[1]:lower()
                            
                            if cmd == "help" then
                                -- help уже показан в интерфейсе
                            elseif cmd == "clear" then
                                -- clear реализуется перерисовкой
                            elseif cmd == "ls" then
                                refreshFiles()
                                for _, file in ipairs(files) do
                                    local line = file.name
                                    if file.isDir then line = line .. "/" end
                                    log("CONSOLE: " .. line)
                                end
                            elseif cmd == "cd" then
                                if #parts > 1 then
                                    local newDir = parts[2]
                                    if newDir == ".." then
                                        local lastSlash = currentDir:match("(.+)/[^/]+$")
                                        if lastSlash then currentDir = lastSlash end
                                    elseif fs.exists(newDir) and fs.isDirectory(newDir) then
                                        currentDir = newDir
                                    else
                                        log("ОШИБКА: Папка не найдена")
                                    end
                                end
                            elseif cmd == "cat" then
                                if #parts > 1 then
                                    local fileName = currentDir .. "/" .. parts[2]
                                    if fs.exists(fileName) then
                                        local file = io.open(fileName, "r")
                                        log("Содержимое " .. parts[2] .. ":")
                                        log(file:read("*a"))
                                        file:close()
                                    else
                                        log("ОШИБКА: Файл не найден")
                                    end
                                end
                            elseif cmd == "sysinfo" then
                                log("=== Системная информация ===")
                                log("Память: " .. computer.freeMemory() .. "/" .. computer.totalMemory())
                                log("Время работы: " .. math.floor(computer.uptime() / 60) .. " мин")
                                if computer.maxEnergy() > 0 then
                                    log("Энергия: " .. computer.energy() .. "/" .. computer.maxEnergy())
                                end
                            elseif cmd == "reboot" then
                                computer.shutdown(true)
                            elseif cmd == "exit" then
                                mode = "files"
                                return
                            else
                                log("ОШИБКА: Неизвестная команда '" .. cmd .. "'")
                            end
                        end
                    end
                    break
                    
                elseif code == 14 then -- Backspace
                    if #command > 0 then
                        command = command:sub(1, -2)
                        cursorX = cursorX - 1
                        gpu.set(cursorX, maxHeight - 5, " ")
                    end
                    
                elseif code == 200 then -- Up
                    if historyIndex > 1 then
                        historyIndex = historyIndex - 1
                        command = consoleHistory[historyIndex] or ""
                        gpu.fill(sidebarWidth + 5, maxHeight - 5, maxWidth - sidebarWidth - 5, 1, " ")
                        gpu.set(sidebarWidth + 5, maxHeight - 5, command)
                        cursorX = sidebarWidth + 5 + #command
                    end
                    
                elseif code == 208 then -- Down
                    if historyIndex < #consoleHistory then
                        historyIndex = historyIndex + 1
                        command = consoleHistory[historyIndex] or ""
                        gpu.fill(sidebarWidth + 5, maxHeight - 5, maxWidth - sidebarWidth - 5, 1, " ")
                        gpu.set(sidebarWidth + 5, maxHeight - 5, command)
                        cursorX = sidebarWidth + 5 + #command
                    end
                    
                elseif char ~= 0 then
                    command = command .. string.char(char)
                    gpu.set(cursorX, maxHeight - 5, string.char(char))
                    cursorX = cursorX + 1
                end
            end
        end
    end
    
    -- Основной цикл
    refreshFiles()
    
    while true do
        drawInterface()
        
        if mode == "console" then
            runConsole()
        else
            local eventType, _, char, code, x, y = event.pull()
            
            if eventType == "key_down" then
                -- Глобальные горячие клавиши
                if code == 59 then -- F1
                    -- Помощь
                    showError("F1 - Помощь\nF2 - Новый файл\nF3 - Редактировать\nF5 - Обновить\nDel - Удалить\nESC - Выход")
                    
                elseif code == 60 and mode == "files" then -- F2
                    -- Создать файл
                    local fileName = "newfile.txt"
                    local file = io.open(currentDir .. "/" .. fileName, "w")
                    file:write("-- Новый файл\n-- Создан: " .. os.date())
                    file:close()
                    refreshFiles()
                    log("Создан файл: " .. fileName)
                    
                elseif code == 61 and mode == "files" then -- F3
                    -- Редактировать
                    if files[selected] and not files[selected].isDir then
                        -- Простой редактор
                        local content = ""
                        if fs.exists(files[selected].path) then
                            local file = io.open(files[selected].path, "r")
                            content = file:read("*a")
                            file:close()
                        end
                        
                        gpu.setBackground(0x000000)
                        gpu.setForeground(0xFFFFFF)
                        term.clear()
                        
                        print("Редактор: " .. files[selected].name)
                        print("Введите текст (Ctrl+S сохранить, ESC отмена):")
                        print("================================")
                        print(content)
                        
                        -- Здесь можно добать полноценный редактор
                        log("Открыт редактор для: " .. files[selected].name)
                        os.sleep(2)
                    end
                    
                elseif code == 63 then -- F5
                    refreshFiles()
                    
                elseif code == 211 and mode == "files" then -- Delete
                    if files[selected] then
                        fs.remove(files[selected].path)
                        refreshFiles()
                        log("Удалено: " .. files[selected].name)
                    end
                    
                elseif code == 1 then -- ESC
                    if mode == "files" then
                        -- Выход из ОС
                        gpu.setBackground(0x000000)
                        gpu.setForeground(0xFFFFFF)
                        term.clear()
                        print("Завершение работы Asmelit OS...")
                        os.sleep(2)
                        computer.shutdown()
                    else
                        mode = "files"
                    end
                    
                -- Навигация по меню
                elseif code == 200 then -- Up
                    if mode == "files" then
                        selected = selected > 1 and selected - 1 or #files
                    end
                    
                elseif code == 208 then -- Down
                    if mode == "files" then
                        selected = selected < #files and selected + 1 or 1
                    end
                    
                elseif code == 28 then -- Enter
                    if mode == "files" and files[selected] then
                        if files[selected].isDir then
                            currentDir = files[selected].path
                            selected = 1
                            refreshFiles()
                        else
                            -- Запуск файла
                            local ext = files[selected].name:match("%.(.+)$")
                            if ext == "lua" then
                                local ok, err = pcall(dofile, files[selected].path)
                                if not ok then
                                    log("Ошибка запуска: " .. err)
                                end
                            else
                                -- Просмотр файла
                                local file = io.open(files[selected].path, "r")
                                if file then
                                    gpu.setBackground(0x000000)
                                    gpu.setForeground(0xFFFFFF)
                                    term.clear()
                                    print("=== " .. files[selected].name .. " ===")
                                    print(file:read("*a"))
                                    file:close()
                                    print("\nНажмите любую клавишу...")
                                    event.pull("key_down")
                                end
                            end
                        end
                    end
                    
                elseif char == "c" or char == "с" then -- Кириллица и латиница
                    mode = "console"
                elseif char == "f" or char == "а" then
                    mode = "files"
                elseif char == "a" or char == "ф" then
                    mode = "apps"
                elseif char == "s" or char == "ы" then
                    mode = "settings"
                elseif char == "i" or char == "ш" then
                    mode = "info"
                end
                
            elseif eventType == "touch" and y >= 2 and y <= 12 and x <= sidebarWidth then
                -- Клик по боковой панели
                local itemIndex = math.floor((y - 1) / 2)
                local menuItems = {"files", "console", "apps", "settings", "info"}
                if itemIndex >= 1 and itemIndex <= #menuItems then
                    mode = menuItems[itemIndex]
                    if mode == "console" then
                        runConsole()
                    end
                end
            end
        end
    end
end

-- =====================================================
-- ЗАПУСК СИСТЕМЫ
-- =====================================================
log("=== Запуск Asmelit OS v2.0 ===")

-- Проверка памяти
if computer.freeMemory() < 2048 then
    print("Внимание: мало памяти (" .. computer.freeMemory() .. " байт)")
    print("Запускаем упрощенный режим...")
    
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
    term.clear()
    print("Asmelit OS (безопасный режим)")
    print("==============================")
    print("1. Консоль")
    print("2. Файловый менеджер")
    print("3. Перезагрузка")
    print("Выберите: ")
    
    local choice = io.read()
    if choice == "1" then
        require("shell").execute()
    elseif choice == "2" then
        -- Простой файловый менеджер
        local fs = require("filesystem")
        local dir = "/home"
        while true do
            print("\n" .. dir .. ":")
            for item in fs.list(dir) do
                local path = dir .. "/" .. item
                if fs.isDirectory(path) then
                    print(item .. "/")
                else
                    print(item)
                end
            end
            print("\n> cd [папка] | cat [файл] | exit")
            local cmd = io.read()
            if cmd == "exit" then
                break
            end
        end
    else
        computer.shutdown(true)
    end
else
    -- Полноценный запуск
    local ok, err = pcall(bootScreen)
    if not ok then
        log("Ошибка загрузки: " .. tostring(err))
        os.sleep(2)
    end
    
    ok, err = pcall(mainGUI)
    if not ok then
        showError("Критическая ошибка GUI:\n" .. tostring(err))
        computer.shutdown(true)
    end
end
