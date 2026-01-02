-- =====================================================
-- Asmelit OS v3.0
-- Улучшенный интерфейс, исправлены ошибки
-- =====================================================

-- Основные библиотеки
local component = require("component")
local computer = require("computer")
local event = require("event")
local term = require("term")
local gpu = component.gpu
local fs = require("filesystem")
local serialization = require("serialization")
local sides = require("sides")
local colors = require("colors")

-- Переменные системы
local systemLog = {}
local startTime = computer.uptime()
local maxWidth, maxHeight = gpu.getResolution()
local centerX = math.floor(maxWidth / 2)
local centerY = math.floor(maxHeight / 2)

-- Цветовая схема (улучшенная)
local theme = {
    -- Основные цвета
    background = 0x0A0A1E,
    header = 0x1A1A3E,
    sidebar = 0x151530,
    text = 0xE0E0FF,
    highlight = 0x4A7BFF,
    accent = 0x00D4FF,
    
    -- Статусные цвета
    success = 0x00FF88,
    error = 0xFF5555,
    warning = 0xFFAA00,
    info = 0x00AAFF,
    
    -- Кнопки
    button = 0x2A2A5A,
    button_hover = 0x3A3A7A,
    button_active = 0x4A7BFF,
    
    -- Элементы UI
    border = 0x303060,
    shadow = 0x050510
}

-- Логирование
function log(message)
    local timestamp = os.date("%H:%M:%S")
    local entry = timestamp .. " - " .. message
    table.insert(systemLog, entry)
    
    -- Ограничиваем размер лога
    if #systemLog > 100 then
        table.remove(systemLog, 1)
    end
    
    -- Отладочный вывод
    if false then -- поменять на true для отладки
        print("[LOG] " .. entry)
    end
end

-- Обработка ошибок
function safeCall(func, errorMsg)
    local ok, result = pcall(func)
    if not ok then
        log("ОШИБКА: " .. tostring(result))
        if errorMsg then
            showMessage(errorMsg, theme.error)
        end
        return nil, result
    end
    return result
end

-- Красивое сообщение
function showMessage(text, color, title)
    color = color or theme.text
    title = title or "Сообщение"
    
    -- Создаем окно сообщения
    local lines = {}
    for line in text:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    
    -- Находим максимальную ширину
    local maxLineWidth = #title
    for _, line in ipairs(lines) do
        if #line > maxLineWidth then
            maxLineWidth = #line
        end
    end
    
    local winWidth = math.max(40, maxLineWidth + 8)
    local winHeight = #lines + 8
    local winX = math.floor((maxWidth - winWidth) / 2)
    local winY = math.floor((maxHeight - winHeight) / 2)
    
    -- Рисуем окно
    gpu.setBackground(theme.background)
    term.clear()
    
    -- Тень окна
    gpu.setBackground(theme.shadow)
    gpu.fill(winX + 2, winY + 2, winWidth, winHeight, " ")
    
    -- Основное окно
    gpu.setBackground(theme.header)
    gpu.fill(winX, winY, winWidth, winHeight, " ")
    
    -- Рамка
    gpu.setForeground(theme.border)
    gpu.set(winX, winY, "╔" .. string.rep("═", winWidth - 2) .. "╗")
    gpu.set(winX, winY + winHeight - 1, "╚" .. string.rep("═", winWidth - 2) .. "╝")
    for i = 1, winHeight - 2 do
        gpu.set(winX, winY + i, "║")
        gpu.set(winX + winWidth - 1, winY + i, "║")
    end
    
    -- Заголовок
    gpu.setForeground(theme.accent)
    local titleX = winX + math.floor((winWidth - #title) / 2)
    gpu.set(titleX, winY + 1, title)
    
    -- Разделитель
    gpu.set(winX, winY + 2, "╠" .. string.rep("═", winWidth - 2) .. "╣")
    
    -- Текст сообщения
    gpu.setForeground(color)
    for i, line in ipairs(lines) do
        local lineX = winX + math.floor((winWidth - #line) / 2)
        gpu.set(lineX, winY + 4 + i, line)
    end
    
    -- Кнопка
    local btnText = " OK "
    local btnX = winX + math.floor((winWidth - #btnText) / 2)
    local btnY = winY + winHeight - 3
    
    gpu.setBackground(theme.button)
    gpu.setForeground(theme.text)
    gpu.fill(btnX, btnY, #btnText, 1, " ")
    gpu.set(btnX, btnY, btnText)
    
    -- Ждем нажатия
    while true do
        local e = {event.pull()}
        if e[1] == "key_down" then
            if e[4] == 28 or e[4] == 57 then -- Enter или Space
                break
            elseif e[4] == 1 then -- ESC
                break
            end
        elseif e[1] == "touch" then
            local x, y = e[3], e[4]
            if x >= btnX and x < btnX + #btnText and y == btnY then
                break
            end
        end
    end
end

-- Загрузочный экран (улучшенный)
function bootScreen()
    return safeCall(function()
        gpu.setBackground(0x000000)
        gpu.setForeground(theme.accent)
        term.clear()
        
        -- Пробуем загрузить лого из файла
        local logoText = [[
╔══════════════════════════════╗
║       ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄       ║
║       ███████████████       ║
║       ██▀▀▀███▀▀▀███       ║
║       ██   ███   ███       ║
║       ███████████████       ║
║       ███████████████       ║
║       ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀       ║
║                              ║
║        ASMELIT OS v3.0       ║
╚══════════════════════════════╝
]]
        
        if fs.exists("/home/logo.lua") or fs.exists("/logo.lua") then
            local path = fs.exists("/home/logo.lua") and "/home/logo.lua" or "/logo.lua"
            local file = io.open(path, "r")
            if file then
                local content = file:read("*a")
                file:close()
                if #content > 10 then
                    logoText = content
                end
            end
        end
        
        -- Отображение лого
        local logoLines = {}
        for line in logoText:gmatch("[^\r\n]+") do
            table.insert(logoLines, line)
        end
        
        local logoStartY = math.floor((maxHeight - #logoLines) / 2) - 5
        for i, line in ipairs(logoLines) do
            local x = centerX - math.floor(#line / 2)
            local y = logoStartY + i
            if y >= 1 and y <= maxHeight then
                gpu.set(x, y, line)
            end
        end
        
        -- Анимированная шкала загрузки
        local barWidth = 50
        local barX = centerX - math.floor(barWidth / 2)
        local barY = logoStartY + #logoLines + 2
        
        if barY < maxHeight - 3 then
            -- Подпись
            gpu.setForeground(theme.text)
            gpu.set(barX, barY - 1, "Загрузка системы...")
            
            -- Фон прогресс-бара
            gpu.setBackground(theme.sidebar)
            gpu.setForeground(theme.sidebar)
            gpu.fill(barX, barY, barWidth, 1, "█")
            
            -- Анимация заполнения
            for i = 1, barWidth do
                -- Вычисляем цвет от синего к голубому
                local progress = i / barWidth
                local r = math.floor(74 * progress) -- 4A -> FF
                local g = math.floor(123 * progress + 100 * (1 - progress)) -- 7B -> D4
                local b = 255 -- FF
                local color = r * 0x10000 + g * 0x100 + b
                
                gpu.setBackground(color)
                gpu.setForeground(color)
                gpu.set(barX + i - 1, barY, "█")
                
                -- Динамическая подпись
                if i % 5 == 0 then
                    local percent = math.floor((i / barWidth) * 100)
                    gpu.setForeground(theme.text)
                    gpu.set(barX + math.floor(barWidth / 2) - 2, barY + 1, string.format("%3d%%", percent))
                end
                
                os.sleep(0.01)
            end
            
            -- Финальное сообщение
            gpu.setForeground(theme.success)
            gpu.set(barX + math.floor(barWidth / 2) - 3, barY + 3, "ГОТОВО!")
            os.sleep(0.5)
        end
        
        log("Система загружена успешно")
        return true
    end, "Ошибка загрузочного экрана")
end

-- Рисуем красивую кнопку
function drawButton(x, y, text, active, hover)
    local bg = theme.button
    local fg = theme.text
    
    if active then
        bg = theme.button_active
        fg = 0x000000
    elseif hover then
        bg = theme.button_hover
    end
    
    gpu.setBackground(bg)
    gpu.setForeground(fg)
    gpu.fill(x, y, #text + 4, 1, " ")
    gpu.set(x + 2, y, text)
    
    return {x = x, y = y, width = #text + 4, height = 1}
end

-- Основной GUI (полностью переработан)
function mainGUI()
    local currentDir = "/home"
    local files = {}
    local selected = 1
    local mode = "files" -- files, console, apps, settings, info
    local sidebarWidth = 24
    local scrollOffset = 0
    local hoverButton = nil
    local lastClickTime = 0
    local doubleClickDelay = 0.5
    
    -- Кнопки сайдбара
    local sidebarButtons = {
        {id = "files", icon = "📁", text = "Файлы", hint = "Файловый менеджер"},
        {id = "console", icon = "💻", text = "Консоль", hint = "Терминал команд"},
        {id = "apps", icon = "🚀", text = "Приложения", hint = "Программы и утилиты"},
        {id = "settings", icon = "⚙️", text = "Настройки", hint = "Системные настройки"},
        {id = "info", icon = "ℹ️", text = "О системе", hint = "Информация о системе"}
    }
    
    -- Позиции кнопок (заполнятся при отрисовке)
    local buttonPositions = {}
    
    -- Обновление списка файлов
    local function refreshFiles()
        files = {}
        if fs.exists(currentDir) and fs.isDirectory(currentDir) then
            local success, list = pcall(function()
                local listResult = {}
                for item in fs.list(currentDir) do
                    if item ~= "." and item ~= ".." then
                        local path = currentDir .. "/" .. item
                        local isDir = fs.isDirectory(path)
                        table.insert(listResult, {
                            name = item,
                            isDir = isDir,
                            size = isDir and "<DIR>" or tostring(fs.size(path) or "0"),
                            path = path,
                            modified = fs.lastModified(path) or 0
                        })
                    end
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
        selected = 1
        scrollOffset = 0
    end
    
    -- Отрисовка интерфейса
    local function drawInterface()
        safeCall(function()
            -- Фон
            gpu.setBackground(theme.background)
            gpu.setForeground(theme.text)
            term.clear()
            
            -- Верхняя панель с градиентом
            for i = 1, 3 do
                local color = theme.header - (i-1) * 0x050505
                gpu.setBackground(color)
                gpu.fill(1, i, maxWidth, 1, " ")
            end
            
            -- Заголовок
            gpu.setBackground(theme.header)
            gpu.setForeground(theme.accent)
            local title = "Asmelit OS"
            if mode == "files" then
                title = title .. " » " .. currentDir
            else
                for _, btn in ipairs(sidebarButtons) do
                    if btn.id == mode then
                        title = title .. " » " .. btn.text
                        break
                    end
                end
            end
            gpu.set(3, 2, "◈ " .. title)
            
            -- Системная информация
            local time = os.date("%H:%M:%S")
            local mem = math.floor(computer.freeMemory() / 1024) .. "K"
            local energy = ""
            if computer.maxEnergy() > 0 then
                energy = " ⚡" .. math.floor((computer.energy() / computer.maxEnergy()) * 100) .. "%"
            end
            
            local statusText = time .. " | " .. mem .. energy
            gpu.set(maxWidth - #statusText - 2, 2, statusText)
            
            -- Боковая панель
            gpu.setBackground(theme.sidebar)
            gpu.fill(1, 4, sidebarWidth, maxHeight - 3, " ")
            
            -- Рамка сайдбара
            gpu.setForeground(theme.border)
            gpu.set(sidebarWidth, 4, "║")
            gpu.set(sidebarWidth, maxHeight, "╚")
            for i = 5, maxHeight - 1 do
                gpu.set(sidebarWidth, i, "║")
            end
            
            -- Кнопки сайдбара
            buttonPositions = {}
            local buttonY = 6
            
            for i, btn in ipairs(sidebarButtons) do
                local isActive = (mode == btn.id)
                local isHover = (hoverButton == btn.id)
                
                -- Подсветка при наведении
                if isHover and not isActive then
                    gpu.setBackground(theme.button_hover)
                elseif isActive then
                    gpu.setBackground(theme.button_active)
                else
                    gpu.setBackground(theme.sidebar)
                end
                
                -- Фон кнопки
                gpu.fill(1, buttonY, sidebarWidth - 1, 1, " ")
                
                -- Иконка и текст
                if isActive then
                    gpu.setForeground(0x000000)
                else
                    gpu.setForeground(theme.text)
                end
                
                gpu.set(3, buttonY, btn.icon .. " " .. btn.text)
                
                -- Сохраняем позицию для кликов
                buttonPositions[btn.id] = {
                    x1 = 1, y1 = buttonY,
                    x2 = sidebarWidth - 1, y2 = buttonY
                }
                
                -- Подсказка при наведении
                if isHover and btn.hint then
                    gpu.setForeground(theme.info)
                    gpu.set(sidebarWidth + 2, buttonY, "→ " .. btn.hint)
                end
                
                buttonY = buttonY + 2
            end
            
            -- Основная область
            gpu.setBackground(theme.background)
            gpu.setForeground(theme.text)
            
            if mode == "files" then
                drawFileManager()
            elseif mode == "console" then
                drawConsole()
            elseif mode == "apps" then
                drawApps()
            elseif mode == "settings" then
                drawSettings()
            elseif mode == "info" then
                drawSystemInfo()
            end
            
            -- Нижняя панель
            gpu.setBackground(theme.header)
            gpu.setForeground(theme.text)
            gpu.fill(1, maxHeight, maxWidth, 1, " ")
            
            -- Подсказки
            local hints = ""
            if mode == "files" then
                hints = "↑↓: Навигация | Enter: Открыть | F2: Создать | Del: Удалить | ESC: Выход"
            elseif mode == "console" then
                hints = "Введите команду | Tab: Автодополнение | ESC: Назад"
            else
                hints = "ESC: Назад в файлы | F1: Помощь"
            end
            
            gpu.set(3, maxHeight, "💡 " .. hints)
            
        end, "Ошибка отрисовки интерфейса")
    end
    
    -- Файловый менеджер
    function drawFileManager()
        local startX = sidebarWidth + 3
        local availableHeight = maxHeight - 7
        local visibleFiles = math.min(#files - scrollOffset, availableHeight)
        
        -- Заголовки колонок
        gpu.setForeground(theme.accent)
        gpu.set(startX, 5, "ИМЯ")
        gpu.set(startX + 35, 5, "ТИП")
        gpu.set(startX + 45, 5, "РАЗМЕР")
        gpu.set(startX + 58, 5, "ИЗМЕНЕН")
        
        -- Разделитель
        gpu.setForeground(theme.border)
        gpu.set(startX, 6, string.rep("─", maxWidth - startX - 2))
        
        -- Список файлов
        local y = 7
        for i = 1, visibleFiles do
            local fileIndex = i + scrollOffset
            local file = files[fileIndex]
            
            if file then
                -- Выделение
                if fileIndex == selected then
                    gpu.setBackground(theme.highlight)
                    gpu.setForeground(0x000000)
                else
                    gpu.setBackground(theme.background)
                    gpu.setForeground(file.isDir and theme.accent or theme.text)
                end
                
                -- Очистка строки
                gpu.fill(startX, y, maxWidth - startX - 2, 1, " ")
                
                -- Имя файла
                local displayName = file.name
                if file.isDir then displayName = displayName .. "/" end
                if #displayName > 30 then
                    displayName = displayName:sub(1, 27) .. "..."
                end
                
                gpu.set(startX, y, displayName)
                
                -- Тип
                gpu.set(startX + 35, y, file.isDir and "Папка" or "Файл")
                
                -- Размер
                gpu.set(startX + 45, y, file.size)
                
                -- Дата изменения
                if file.modified > 0 then
                    local date = os.date("%d.%m %H:%M", file.modified)
                    gpu.set(startX + 58, y, date)
                end
                
                -- Иконка
                local icon = file.isDir and "📁" or "📄"
                gpu.set(startX - 2, y, icon)
                
                y = y + 1
            end
        end
        
        -- Статус
        gpu.setBackground(theme.background)
        gpu.setForeground(theme.info)
        local status = string.format("Файлов: %d | Выбрано: %d", #files, selected)
        if #files > visibleFiles then
            status = status .. string.format(" | Прокрутка: %d-%d", scrollOffset + 1, scrollOffset + visibleFiles)
        end
        gpu.set(startX, maxHeight - 2, status)
    end
    
    -- Консоль
    function drawConsole()
        local startX = sidebarWidth + 3
        gpu.setForeground(theme.accent)
        gpu.set(startX, 5, "╔══ ASMELIT CONSOLE v3.0 ═══════════════════════════════╗")
        gpu.set(startX, 6, "║ Введите команду и нажмите Enter                      ║")
        gpu.set(startX, 7, "║ Для справки введите 'help'                           ║")
        gpu.set(startX, 8, "╚══════════════════════════════════════════════════════╝")
        
        gpu.setForeground(theme.text)
        gpu.set(startX, 10, "Текущая директория: " .. currentDir)
        gpu.set(startX, 11, string.rep("─", maxWidth - startX - 3))
        
        -- История команд (последние 5)
        if #systemLog > 0 then
            gpu.set(startX, 13, "Последние действия:")
            local y = 14
            for i = math.max(1, #systemLog - 4), #systemLog do
                if y < maxHeight - 5 then
                    gpu.set(startX + 2, y, "• " .. systemLog[i])
                    y = y + 1
                end
            end
        end
        
        gpu.set(startX, maxHeight - 4, string.rep("═", maxWidth - startX - 3))
        gpu.set(startX, maxHeight - 3, "> ")
    end
    
    -- Приложения
    function drawApps()
        local startX = sidebarWidth + 3
        gpu.setForeground(theme.accent)
        gpu.set(startX, 5, "📱 ДОСТУПНЫЕ ПРИЛОЖЕНИЯ")
        gpu.set(startX, 6, string.rep("─", maxWidth - startX - 3))
        
        local apps = {
            {name = "📝 Редактор", desc = "Текстовый редактор", color = 0x00AAFF},
            {name = "🧮 Калькулятор", desc = "Простой калькулятор", color = 0x00FF88},
            {name = "📊 Монитор", desc = "Системный монитор", color = 0xFFAA00},
            {name = "🎮 Игры", desc = "Коллекция игр", color = 0xFF55FF},
            {name = "🌐 Браузер", desc = "Веб-браузер", color = 0x55FFFF},
            {name = "🎵 Плеер", desc = "Медиа-плеер", color = 0xFF5555}
        }
        
        local x, y = startX, 8
        local appWidth = 25
        local appHeight = 6
        
        for i, app in ipairs(apps) do
            if y + appHeight < maxHeight - 3 then
                -- Фон приложения
                gpu.setBackground(app.color)
                gpu.setForeground(0x000000)
                gpu.fill(x, y, appWidth, appHeight, " ")
                
                -- Рамка
                gpu.setForeground(0x000000)
                gpu.set(x, y, "┌" .. string.rep("─", appWidth - 2) .. "┐")
                gpu.set(x, y + appHeight - 1, "└" .. string.rep("─", appWidth - 2) .. "┘")
                for j = 1, appHeight - 2 do
                    gpu.set(x, y + j, "│")
                    gpu.set(x + appWidth - 1, y + j, "│")
                end
                
                -- Название
                gpu.set(x + 2, y + 1, app.name)
                
                -- Описание
                gpu.set(x + 2, y + 3, app.desc)
                
                -- Кнопка запуска
                gpu.setBackground(0x000000)
                gpu.setForeground(app.color)
                gpu.set(x + 2, y + appHeight - 2, "▶ Запустить")
                
                x = x + appWidth + 2
                if x + appWidth > maxWidth then
                    x = startX
                    y = y + appHeight + 2
                end
            end
        end
    end
    
    -- Настройки
    function drawSettings()
        local startX = sidebarWidth + 3
        gpu.setForeground(theme.accent)
        gpu.set(startX, 5, "⚙️ НАСТРОЙКИ СИСТЕМЫ")
        gpu.set(startX, 6, string.rep("─", maxWidth - startX - 3))
        
        local settings = {
            {name = "Тема интерфейса", value = "Темная", options = {"Темная", "Светлая", "Синяя"}},
            {name = "Автозагрузка", value = "Включена", options = {"Включена", "Выключена"}},
            {name = "Звук", value = "Включен", options = {"Включен", "Выключен"}},
            {name = "Безопасность", value = "Стандартная", options = {"Стандартная", "Повышенная"}},
            {name = "Язык", value = "Русский", options = {"Русский", "English"}}
        }
        
        local y = 8
        for i, setting in ipairs(settings) do
            gpu.setForeground(theme.text)
            gpu.set(startX, y, setting.name .. ":")
            
            -- Текущее значение
            gpu.setBackground(theme.button)
            gpu.setForeground(theme.text)
            gpu.fill(startX + 25, y, 15, 1, " ")
            gpu.set(startX + 27, y, setting.value)
            
            -- Стрелки для изменения
            gpu.setForeground(theme.accent)
            gpu.set(startX + 23, y, "◀")
            gpu.set(startX + 41, y, "▶")
            
            y = y + 2
        end
    end
    
    -- Информация о системе
    function drawSystemInfo()
        local startX = sidebarWidth + 3
        gpu.setForeground(theme.accent)
        gpu.set(startX, 5, "ℹ️ ИНФОРМАЦИЯ О СИСТЕМЕ")
        gpu.set(startX, 6, string.rep("─", maxWidth - startX - 3))
        
        local infoLines = {
            "Версия: Asmelit OS 3.0",
            "Память: " .. computer.freeMemory() .. " / " .. computer.totalMemory() .. " байт",
            "Время работы: " .. string.format("%.1f", (computer.uptime() - startTime) / 60) .. " минут",
            "Логов в памяти: " .. #systemLog .. " записей",
            "Экран: " .. maxWidth .. "x" .. maxHeight
        }
        
        if computer.maxEnergy() > 0 then
            table.insert(infoLines, "Энергия: " .. math.floor((computer.energy() / computer.maxEnergy()) * 100) .. "%")
        end
        
        -- Информация о дисках
        table.insert(infoLines, "")
        table.insert(infoLines, "ДИСКИ:")
        
        local driveCount = 0
        for addr in component.list("drive") do
            local proxy = component.proxy(addr)
            if proxy then
                driveCount = driveCount + 1
                local capacity = proxy.capacity() or 0
                local used = proxy.spaceUsed() or 0
                local free = capacity - used
                local percent = capacity > 0 and math.floor((used / capacity) * 100) or 0
                
                table.insert(infoLines, string.format("  Диск %d: %dK / %dK (%d%%)", 
                    driveCount, math.floor(used/1024), math.floor(capacity/1024), percent))
            end
        end
        
        -- Отображение информации
        local y = 8
        for i, line in ipairs(infoLines) do
            if y < maxHeight - 3 then
                gpu.setForeground(theme.text)
                gpu.set(startX, y, line)
                y = y + 1
            end
        end
        
        -- График использования памяти
        if y < maxHeight - 10 then
            gpu.setForeground(theme.accent)
            gpu.set(startX, y, "Использование памяти:")
            y = y + 1
            
            local usedPercent = math.floor((1 - computer.freeMemory() / computer.totalMemory()) * 100)
            local barWidth = 40
            local barX = startX
            
            gpu.setBackground(theme.sidebar)
            gpu.fill(barX, y, barWidth, 1, "█")
            
            gpu.setBackground(theme.highlight)
            gpu.fill(barX, y, math.floor(barWidth * usedPercent / 100), 1, "█")
            
            gpu.setBackground(theme.background)
            gpu.setForeground(theme.text)
            gpu.set(barX + barWidth + 2, y, string.format("%d%%", usedPercent))
        end
    end
    
    -- Обработка консоли
    local function runConsole()
        local consoleHistory = {}
        local historyIndex = 0
        local consoleText = ""
        local cursorPos = 1
        
        while mode == "console" do
            drawInterface()
            
            local startX = sidebarWidth + 3
            gpu.set(startX, maxHeight - 3, "> " .. consoleText)
            gpu.set(startX + 2 + cursorPos - 1, maxHeight - 3, "_")
            
            local e = {event.pull()}
            
            if e[1] == "key_down" then
                local char, code = e[3], e[4]
                
                if code == 28 then -- Enter
                    if #consoleText > 0 then
                        table.insert(consoleHistory, consoleText)
                        historyIndex = #consoleHistory + 1
                        
                        local cmd = consoleText:lower()
                        local output = ""
                        
                        -- Обработка команд
                        if cmd == "help" then
                            output = [[
Доступные команды:
help     - эта справка
clear    - очистить экран
ls       - список файлов
cd [dir] - сменить директорию
cat [file] - показать файл
run [file] - запустить программу
sysinfo  - информация о системе
reboot   - перезагрузка
exit     - выход из консоли
]]
                        elseif cmd == "clear" then
                            consoleText = ""
                            cursorPos = 1
                        elseif cmd == "ls" then
                            refreshFiles()
                            for _, file in ipairs(files) do
                                output = output .. (file.isDir and file.name .. "/\n" or file.name .. "\n")
                            end
                        elseif cmd:sub(1,3) == "cd " then
                            local newDir = cmd:sub(4)
                            -- обработка смены директории
                        elseif cmd == "sysinfo" then
                            output = string.format(
                                "Память: %d/%d байт\nВремя: %.1f мин\nЭнергия: %s",
                                computer.freeMemory(), computer.totalMemory(),
                                (computer.uptime() - startTime) / 60,
                                computer.maxEnergy() > 0 and 
                                math.floor((computer.energy() / computer.maxEnergy()) * 100) .. "%" or "N/A"
                            )
                        elseif cmd == "reboot" then
                            computer.shutdown(true)
                        elseif cmd == "exit" then
                            mode = "files"
                            return
                        else
                            output = "Неизвестная команда: " .. cmd
                        end
                        
                        if output ~= "" then
                            showMessage(output, theme.text, "Результат команды")
                        end
                        
                        consoleText = ""
                        cursorPos = 1
                    end
                    
                elseif code == 14 then -- Backspace
                    if cursorPos > 1 then
                        consoleText = consoleText:sub(1, cursorPos - 2) .. consoleText:sub(cursorPos)
                        cursorPos = cursorPos - 1
                    end
                    
                elseif code == 15 then -- Tab
                    -- Автодополнение
                    
                elseif code == 200 then -- Up
                    if historyIndex > 1 then
                        historyIndex = historyIndex - 1
                        consoleText = consoleHistory[historyIndex] or ""
                        cursorPos = #consoleText + 1
                    end
                    
                elseif code == 208 then -- Down
                    if historyIndex < #consoleHistory then
                        historyIndex = historyIndex + 1
                        consoleText = consoleHistory[historyIndex] or ""
                        cursorPos = #consoleText + 1
                    end
                    
                elseif code == 203 then -- Left
                    if cursorPos > 1 then
                        cursorPos = cursorPos - 1
                    end
                    
                elseif code == 205 then -- Right
                    if cursorPos <= #consoleText then
                        cursorPos = cursorPos + 1
                    end
                    
                elseif code == 1 then -- ESC
                    mode = "files"
                    return
                    
                elseif char ~= 0 then
                    consoleText = consoleText:sub(1, cursorPos - 1) .. string.char(char) .. consoleText:sub(cursorPos)
                    cursorPos = cursorPos + 1
                end
            end
        end
    end
    
    -- Основной цикл
    refreshFiles()
    drawInterface()
    
    while true do
        -- Проверка памяти
        if computer.freeMemory() < 1024 then
            showMessage("Критически мало памяти!\nПерезагрузите систему.", theme.error, "Ошибка памяти")
            computer.shutdown(true)
        end
        
        if mode == "console" then
            runConsole()
            drawInterface()
        else
            local e = {event.pull()}
            
            if e[1] == "key_down" then
                local char, code = e[3], e[4]
                
                if mode == "files" then
                    if code == 200 then -- Up
                        if selected > 1 then
                            selected = selected - 1
                            if selected <= scrollOffset then
                                scrollOffset = scrollOffset - 1
                            end
                            drawInterface()
                        end
                        
                    elseif code == 208 then -- Down
                        if selected < #files then
                            selected = selected + 1
                            if selected > scrollOffset + (maxHeight - 8) then
                                scrollOffset = scrollOffset + 1
                            end
                            drawInterface()
                        end
                        
                    elseif code == 28 then -- Enter
                        if files[selected] then
                            if files[selected].isDir then
                                currentDir = files[selected].path
                                refreshFiles()
                                drawInterface()
                            else
                                local path = files[selected].path
                                if path:sub(-4) == ".lua" then
                                    local ok, err = pcall(dofile, path)
                                    if not ok then
                                        showMessage("Ошибка запуска:\n" .. tostring(err), theme.error, "Ошибка")
                                    end
                                    drawInterface()
                                else
                                    showMessage("Файл нельзя запустить как программу", theme.warning, "Информация")
                                end
                            end
                        end
                        
                    elseif code == 60 then -- F2
                        -- Создание файла
                        showMessage("Введите имя нового файла:", theme.text, "Создание файла")
                        -- здесь будет запрос имени файла
                        
                    elseif code == 211 then -- Delete
                        -- Удаление файла
                        if files[selected] then
                            showMessage("Удалить '" .. files[selected].name .. "'?", theme.warning, "Подтверждение")
                            -- здесь будет подтверждение удаления
                        end
                    end
                end
                
                -- Глобальные горячие клавиши
                if code == 1 then -- ESC
                    if mode == "files" then
                        local choice = showMessage("Завершить работу системы?", theme.warning, "Выход")
                        if choice then
                            showMessage("Завершение работы...", theme.info, "Asmelit OS")
                            os.sleep(1)
                            computer.shutdown()
                        end
                    else
                        mode = "files"
                        drawInterface()
                    end
                    
                elseif code == 59 then -- F1
                    showMessage(
                        "Горячие клавиши:\n" ..
                        "ESC - Выход/Назад\n" ..
                        "F1 - Помощь\n" ..
                        "F2 - Новый файл\n" ..
                        "F3 - Редактировать\n" ..
                        "F5 - Обновить\n" ..
                        "Tab - Переключение вкладок",
                        theme.info, "Помощь"
                    )
                    drawInterface()
                    
                elseif code == 61 then -- F3
                    if mode == "files" and files[selected] then
                        showMessage("Редактирование файлов в разработке", theme.info, "Информация")
                    end
                    
                elseif code == 63 then -- F5
                    refreshFiles()
                    drawInterface()
                end
                
            elseif e[1] == "touch" then
                local x, y = e[3], e[4]
                local now = computer.uptime()
                
                -- Проверка клика по сайдбару
                for btnId, pos in pairs(buttonPositions) do
                    if x >= pos.x1 and x <= pos.x2 and y >= pos.y1 and y <= pos.y2 then
                        -- Двойной клик
                        if now - lastClickTime < doubleClickDelay and hoverButton == btnId then
                            mode = btnId
                            if mode == "console" then
                                runConsole()
                            end
                            drawInterface()
                        else
                            -- Подсветка при наведении
                            hoverButton = btnId
                            drawInterface()
                        end
                        lastClickTime = now
                        break
                    end
                end
                
                -- Сброс подсветки если кликнули не на кнопку
                if hoverButton and not buttonPositions[hoverButton] then
                    hoverButton = nil
                    drawInterface()
                end
                
            elseif e[1] == "drag" or e[1] == "drop" then
                -- Обработка drag&drop если нужно
                
            elseif e[1] == "scroll" then
                if mode == "files" then
                    local delta = e[5]
                    if delta > 0 and scrollOffset > 0 then
                        scrollOffset = scrollOffset - 1
                        if selected > scrollOffset + 1 then
                            selected = math.max(1, selected - 1)
                        end
                        drawInterface()
                    elseif delta < 0 and scrollOffset + (maxHeight - 8) < #files then
                        scrollOffset = scrollOffset + 1
                        if selected < scrollOffset + (maxHeight - 9) then
                            selected = math.min(#files, selected + 1)
                        end
                        drawInterface()
                    end
                end
            end
        end
    end
end

-- =====================================================
-- ЗАПУСК СИСТЕМЫ
-- =====================================================
log("=== Запуск Asmelit OS v3.0 ===")

-- Проверяем память
if computer.freeMemory() < 4096 then
    showMessage("Недостаточно памяти: " .. computer.freeMemory() .. " байт\nРекомендуется минимум 4KB", theme.warning, "Предупреждение")
    os.sleep(2)
end

-- Запускаем систему
local ok, err = pcall(bootScreen)
if not ok then
    log("Ошибка загрузочного экрана: " .. tostring(err))
end

ok, err = pcall(mainGUI)
if not ok then
    showMessage("Критическая ошибка системы:\n" .. tostring(err) .. "\nПерезагрузка...", theme.error, "Сбой системы")
    os.sleep(3)
    computer.shutdown(true)
end
