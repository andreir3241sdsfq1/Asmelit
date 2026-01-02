-- =====================================================
-- Asmelit OS v4.0 - Полная версия
-- Загружает приложения с GitHub при запуске
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
local keyboard = require("keyboard")

-- Глобальные переменные системы
local systemLog = {}
local startTime = computer.uptime()
local maxWidth, maxHeight = gpu.getResolution()
local centerX = math.floor(maxWidth / 2)
local centerY = math.floor(maxHeight / 2)

-- Цветовая схема
local theme = {
    background = 0x0A0A1E,
    header = 0x1A1A3E,
    sidebar = 0x151530,
    text = 0xE0E0FF,
    highlight = 0x4A7BFF,
    accent = 0x00D4FF,
    success = 0x00FF88,
    error = 0xFF5555,
    warning = 0xFFAA00,
    info = 0x00AAFF,
    button = 0x2A2A5A,
    button_hover = 0x3A3A7A,
    button_active = 0x4A7BFF,
    border = 0x303060,
    shadow = 0x050510
}

-- Список приложений для загрузки с GitHub
local appsToDownload = {
    {
        name = "Калькулятор",
        url = "https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/refs/heads/main/calculator.lua",
        filename = "calculator.lua",
        icon = "🧮",
        key = "1"
    },
    {
        name = "Редактор", 
        url = "https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/refs/heads/main/editor.lua",
        filename = "editor.lua",
        icon = "📝",
        key = "2"
    },
    {
        name = "Браузер",
        url = "https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/refs/heads/main/browser.lua",
        filename = "browser.lua",
        icon = "🌐",
        key = "3"
    },
    {
        name = "Монитор",
        url = "https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/refs/heads/main/monitor.lua",
        filename = "monitor.lua",
        icon = "📊",
        key = "4"
    },
    {
        name = "Сапёр",
        url = "https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/refs/heads/main/sapper.lua",
        filename = "sapper.lua",
        icon = "💣",
        key = "5"
    },
    {
        name = "Змейка",
        url = "https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/refs/heads/main/snake.lua",
        filename = "snake.lua",
        icon = "🐍",
        key = "6"
    }
}

-- Логирование в системе
function log(message)
    local timestamp = os.date("%H:%M:%S")
    local entry = timestamp .. " - " .. message
    table.insert(systemLog, entry)
    if #systemLog > 100 then
        table.remove(systemLog, 1)
    end
end

-- Показать окно сообщения
function showMessage(text, color, title)
    color = color or theme.text
    title = title or "Сообщение"
    
    -- Подготовка окна
    local lines = {}
    for line in text:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    
    local maxLineWidth = #title
    for _, line in ipairs(lines) do
        if #line > maxLineWidth then maxLineWidth = #line end
    end
    
    local winWidth = math.max(40, maxLineWidth + 8)
    local winHeight = #lines + 8
    local winX = math.floor((maxWidth - winWidth) / 2)
    local winY = math.floor((maxHeight - winHeight) / 2)
    
    -- Очищаем область под окно
    gpu.setBackground(theme.background)
    gpu.fill(winX, winY, winWidth, winHeight, " ")
    
    -- Рисуем тень
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
    
    -- Разделитель под заголовком
    gpu.set(winX, winY + 2, "╠" .. string.rep("═", winWidth - 2) .. "╣")
    
    -- Текст сообщения
    gpu.setForeground(color)
    for i, line in ipairs(lines) do
        local lineX = winX + math.floor((winWidth - #line) / 2)
        gpu.set(lineX, winY + 4 + i, line)
    end
    
    -- Кнопка OK
    local btnText = " OK "
    local btnX = winX + math.floor((winWidth - #btnText) / 2)
    local btnY = winY + winHeight - 3
    
    gpu.setBackground(theme.button)
    gpu.setForeground(theme.text)
    gpu.fill(btnX, btnY, #btnText, 1, " ")
    gpu.set(btnX, btnY, btnText)
    
    -- Ожидаем нажатия
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

-- Загрузка файла с GitHub
function downloadFromGitHub(url, filename)
    -- Проверяем наличие интернет-карты
    if not component.isAvailable("internet") then
        return false, "Нет интернет-карты"
    end
    
    local internet = require("internet")
    local handle, err = pcall(internet.request, url)
    
    if not handle then
        return false, "Ошибка запроса: " .. tostring(err)
    end
    
    -- Читаем содержимое файла
    local content = ""
    local chunkCount = 0
    
    for chunk in handle do
        content = content .. chunk
        chunkCount = chunkCount + 1
        
        -- Защита от слишком больших файлов
        if #content > 500000 then -- 500KB лимит
            return false, "Файл слишком большой"
        end
        
        -- Даем системе передышку
        if chunkCount % 10 == 0 then
            os.sleep(0.01)
        end
    end
    
    -- Проверяем что файл не пустой
    if #content < 10 then
        return false, "Пустой файл"
    end
    
    -- Создаем папку для приложений если нет
    if not fs.exists("/apps") then
        fs.makeDirectory("/apps")
    end
    
    -- Сохраняем файл
    local file = io.open("/apps/" .. filename, "w")
    if file then
        file:write(content)
        file:close()
        return true, "Загружено " .. #content .. " байт"
    else
        return false, "Ошибка записи файла"
    end
end

-- Загрузка всех приложений
function downloadAllApps()
    -- Очищаем экран и показываем заголовок
    gpu.setBackground(0x000000)
    gpu.setForeground(theme.accent)
    term.clear()
    
    gpu.set(centerX - 12, 3, "╔══════════════════════════╗")
    gpu.set(centerX - 12, 4, "║   ЗАГРУЗКА ПРИЛОЖЕНИЙ   ║")
    gpu.set(centerX - 12, 5, "║      Asmelit OS v4.0     ║")
    gpu.set(centerX - 12, 6, "╚══════════════════════════╝")
    
    gpu.setForeground(theme.text)
    gpu.set(centerX - 18, 8, "Загружаю приложения с GitHub...")
    
    local downloaded = 0
    local failed = 0
    
    -- Прогресс-бар
    local barWidth = 50
    local barX = centerX - math.floor(barWidth / 2)
    local barY = 11
    
    gpu.setBackground(0x333333)
    gpu.fill(barX, barY, barWidth, 1, "█")
    
    -- Загружаем каждое приложение
    for i, app in ipairs(appsToDownload) do
        -- Обновляем прогресс-бар
        local progress = math.floor((i / #appsToDownload) * barWidth)
        gpu.setBackground(theme.highlight)
        gpu.fill(barX, barY, progress, 1, "█")
        
        -- Показываем текущее приложение
        gpu.setBackground(0x000000)
        gpu.setForeground(theme.text)
        local statusText = app.icon .. " " .. app.name .. "..."
        gpu.set(centerX - math.floor(#statusText / 2), 13, statusText)
        
        -- Показываем процент
        local percent = math.floor((i / #appsToDownload) * 100)
        gpu.set(centerX - 2, 14, string.format("%3d%%", percent))
        
        -- Загружаем приложение
        local success, message = downloadFromGitHub(app.url, app.filename)
        
        if success then
            downloaded = downloaded + 1
            gpu.setForeground(theme.success)
            gpu.set(centerX - 5, 16, "✓ Успешно")
            log("Загружено приложение: " .. app.name)
        else
            failed = failed + 1
            gpu.setForeground(theme.error)
            gpu.set(centerX - 5, 16, "✗ Ошибка")
            log("Ошибка загрузки " .. app.name .. ": " .. message)
        end
        
        os.sleep(0.3) -- Небольшая пауза между загрузками
    end
    
    -- Показываем итоги
    gpu.setBackground(0x000000)
    gpu.setForeground(theme.text)
    gpu.set(centerX - 15, 18, string.format("Загружено: %d из %d", downloaded, #appsToDownload))
    
    if failed > 0 then
        gpu.setForeground(theme.warning)
        gpu.set(centerX - 15, 19, string.format("Ошибок: %d", failed))
    end
    
    if downloaded == 0 then
        gpu.setForeground(theme.warning)
        gpu.set(centerX - 25, 21, "Приложения не загружены. Проверьте интернет-соединение.")
    else
        gpu.setForeground(theme.success)
        gpu.set(centerX - 10, 21, "Приложения загружены!")
    end
    
    gpu.setForeground(theme.text)
    gpu.set(centerX - 15, 23, "[ Нажмите любую клавишу для продолжения ]")
    
    event.pull("key_down")
    
    return downloaded > 0
end

-- Проверка и загрузка приложений при старте
function checkAndLoadApps()
    -- Проверяем есть ли уже загруженные приложения
    local appsExist = true
    local missingApps = {}
    
    for _, app in ipairs(appsToDownload) do
        if not fs.exists("/apps/" .. app.filename) then
            appsExist = false
            table.insert(missingApps, app.name)
        end
    end
    
    -- Если приложений нет, предлагаем загрузить
    if not appsExist then
        if component.isAvailable("internet") then
            local missingText = "Отсутствуют приложения:\n"
            for _, appName in ipairs(missingApps) do
                missingText = missingText .. "• " .. appName .. "\n"
            end
            
            showMessage(missingText .. "\nЗагрузить приложения с GitHub?", theme.warning, "Обнаружены отсутствующие приложения")
            downloadAllApps()
        else
            showMessage("Нет интернет-карты.\nПриложения не будут доступны.\n\nОтсутствуют:\n" .. 
                       table.concat(missingApps, "\n"), theme.warning, "Предупреждение")
            os.sleep(3)
        end
    else
        log("Все приложения найдены")
    end
end

-- Загрузочный экран
function bootScreen()
    gpu.setBackground(0x000000)
    gpu.setForeground(theme.accent)
    term.clear()
    
    -- Пробуем загрузить лого из файла
    local logoText = [[
╔══════════════════════════════════════╗
║        █████╗ ███████╗███╗   ███╗   ║
║       ██╔══██╗██╔════╝████╗ ████║   ║
║       ███████║███████╗██╔████╔██║   ║
║       ██╔══██║╚════██║██║╚██╔╝██║   ║
║       ██║  ██║███████║██║ ╚═╝ ██║   ║
║       ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝   ║
║                                      ║
║           ASMELIT OS v4.0            ║
╚══════════════════════════════════════╝
]]
    
    if fs.exists("/logo.lua") then
        local file = io.open("/logo.lua", "r")
        if file then
            local content = file:read("*a")
            file:close()
            if #content > 10 then
                logoText = content
            end
        end
    end
    
    -- Отображаем лого
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
    local barWidth = 60
    local barX = centerX - math.floor(barWidth / 2)
    local barY = logoStartY + #logoLines + 3
    
    if barY < maxHeight - 5 then
        -- Подпись
        gpu.setForeground(theme.text)
        gpu.set(barX, barY - 1, "Загрузка системы...")
        
        -- Фон прогресс-бара
        gpu.setBackground(theme.sidebar)
        gpu.setForeground(theme.sidebar)
        gpu.fill(barX, barY, barWidth, 1, "█")
        
        -- Анимация заполнения
        local phases = {"Инициализация...", "Загрузка ядра...", "Настройка интерфейса...", "Готово!"}
        
        for i = 1, barWidth do
            -- Вычисляем цвет
            local progress = i / barWidth
            local r = math.floor(74 * progress)
            local g = math.floor(123 * progress + 100 * (1 - progress))
            local b = 255
            local color = r * 0x10000 + g * 0x100 + b
            
            gpu.setBackground(color)
            gpu.setForeground(color)
            gpu.set(barX + i - 1, barY, "█")
            
            -- Показываем фазы загрузки
            local phaseIndex = math.floor(progress * #phases) + 1
            if phaseIndex <= #phases then
                gpu.setBackground(0x000000)
                gpu.setForeground(theme.text)
                gpu.fill(barX, barY + 2, barWidth, 1, " ")
                gpu.set(barX + math.floor((barWidth - #phases[phaseIndex]) / 2), barY + 2, phases[phaseIndex])
            end
            
            os.sleep(0.02)
        end
        
        -- Финальное сообщение
        gpu.setBackground(0x000000)
        gpu.setForeground(theme.success)
        gpu.set(barX + math.floor(barWidth / 2) - 3, barY + 4, "ГОТОВО!")
        os.sleep(1)
    end
    
    log("Система загружена успешно")
end

-- Основной графический интерфейс
function mainGUI()
    local currentDir = "/home"
    local files = {}
    local selected = 1
    local mode = "files"
    local sidebarWidth = 24
    local scrollOffset = 0
    local hoverButton = nil
    
    local sidebarButtons = {
        {id = "files", icon = "📁", text = "Файлы", hint = "Файловый менеджер"},
        {id = "apps", icon = "🚀", text = "Приложения", hint = "Запуск программ"},
        {id = "console", icon = "💻", text = "Консоль", hint = "Командная строка"},
        {id = "info", icon = "ℹ️", text = "О системе", hint = "Информация о системе"}
    }
    
    local buttonPositions = {}
    
    -- Обновление списка файлов
    local function refreshFiles()
        files = {}
        if fs.exists(currentDir) and fs.isDirectory(currentDir) then
            for item in fs.list(currentDir) do
                if item ~= "." and item ~= ".." then
                    local path = currentDir .. "/" .. item
                    local isDir = fs.isDirectory(path)
                    table.insert(files, {
                        name = item,
                        isDir = isDir,
                        size = isDir and "<DIR>" or tostring(fs.size(path) or "0"),
                        path = path,
                        modified = fs.lastModified(path) or 0
                    })
                end
            end
        end
        
        -- Сортировка: сначала папки, потом файлы, по алфавиту
        table.sort(files, function(a, b)
            if a.isDir and not b.isDir then return true
            elseif not a.isDir and b.isDir then return false
            else return a.name:lower() < b.name:lower() end
        end)
        
        selected = math.min(selected, #files)
        if selected == 0 and #files > 0 then selected = 1 end
        scrollOffset = 0
    end
    
    -- Отрисовка интерфейса
    local function drawInterface()
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
        
        -- Заголовок окна
        gpu.setBackground(theme.header)
        gpu.setForeground(theme.accent)
        
        local title = "Asmelit OS v4.0"
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
        
        -- Системная информация в правом углу
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
        
        -- Вертикальная граница сайдбара
        gpu.setForeground(theme.border)
        gpu.set(sidebarWidth, 4, "├")
        gpu.set(sidebarWidth, maxHeight, "╘")
        for i = 5, maxHeight - 1 do
            gpu.set(sidebarWidth, i, "│")
        end
        
        -- Кнопки сайдбара
        buttonPositions = {}
        local buttonY = 6
        
        for _, btn in ipairs(sidebarButtons) do
            local isActive = (mode == btn.id)
            local isHover = (hoverButton == btn.id)
            
            -- Подсветка при наведении/активности
            if isHover and not isActive then
                gpu.setBackground(theme.button_hover)
            elseif isActive then
                gpu.setBackground(theme.button_active)
            else
                gpu.setBackground(theme.sidebar)
            end
            
            -- Фон кнопки
            gpu.fill(1, buttonY, sidebarWidth - 1, 1, " ")
            
            -- Текст кнопки
            if isActive then
                gpu.setForeground(0x000000)
            else
                gpu.setForeground(theme.text)
            end
            
            gpu.set(3, buttonY, btn.icon .. " " .. btn.text)
            
            -- Сохраняем позицию для обработки кликов
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
        
        -- Основная область контента
        gpu.setBackground(theme.background)
        gpu.setForeground(theme.text)
        
        if mode == "files" then
            drawFileManager()
        elseif mode == "apps" then
            drawApps()
        elseif mode == "console" then
            drawConsole()
        elseif mode == "info" then
            drawSystemInfo()
        end
        
        -- Нижняя панель с подсказками
        gpu.setBackground(theme.header)
        gpu.setForeground(theme.text)
        gpu.fill(1, maxHeight, maxWidth, 1, " ")
        
        local hints = ""
        if mode == "files" then
            hints = "↑↓: Навигация | Enter: Открыть | F2: Новый файл | Del: Удалить | ESC: Выход"
        elseif mode == "apps" then
            hints = "1-6: Запуск приложений | ESC: Назад"
        elseif mode == "console" then
            hints = "Введите команду | Enter: Выполнить | ESC: Назад"
        else
            hints = "ESC: Назад в файлы | F5: Обновить"
        end
        
        gpu.set(3, maxHeight, "💡 " .. hints)
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
        
        -- Разделитель
        gpu.setForeground(theme.border)
        gpu.set(startX, 6, string.rep("─", maxWidth - startX - 2))
        
        -- Список файлов
        local y = 7
        for i = 1, visibleFiles do
            local fileIndex = i + scrollOffset
            local file = files[fileIndex]
            
            if file then
                -- Выделение текущего файла
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
                
                -- Иконка
                local icon = file.isDir and "📁" or "📄"
                gpu.set(startX - 2, y, icon)
                
                y = y + 1
            end
        end
        
        -- Статусная строка
        gpu.setBackground(theme.background)
        gpu.setForeground(theme.info)
        local status = string.format("Файлов: %d | Выбрано: %d", #files, selected)
        if #files > visibleFiles then
            status = status .. string.format(" | Прокрутка: %d-%d", scrollOffset + 1, scrollOffset + visibleFiles)
        end
        gpu.set(startX, maxHeight - 2, status)
    end
    
    -- Экран приложений
    function drawApps()
        local startX = sidebarWidth + 3
        gpu.setForeground(theme.accent)
        gpu.set(startX, 5, "🚀 ДОСТУПНЫЕ ПРИЛОЖЕНИЯ")
        gpu.set(startX, 6, string.rep("─", maxWidth - startX - 3))
        
        -- Проверяем какие приложения доступны
        local availableApps = {}
        for _, app in ipairs(appsToDownload) do
            if fs.exists("/apps/" .. app.filename) then
                table.insert(availableApps, app)
            end
        end
        
        if #availableApps == 0 then
            gpu.setForeground(theme.warning)
            gpu.set(centerX - 20, centerY - 2, "Приложения не загружены!")
            gpu.set(centerX - 25, centerY, "Запустите систему с интернет-картой")
            gpu.set(centerX - 20, centerY + 2, "для автоматической загрузки приложений")
            return
        end
        
        -- Отображаем доступные приложения
        local x, y = startX, 8
        local appWidth = 25
        local appHeight = 6
        
        for i, app in ipairs(availableApps) do
            if y + appHeight < maxHeight - 3 then
                -- Цвет фона приложения
                local color = 0x00AAFF
                if i == 1 then color = 0x00FF88      -- Калькулятор - зеленый
                elseif i == 2 then color = 0x00AAFF  -- Редактор - синий
                elseif i == 3 then color = 0x55FFFF  -- Браузер - голубой
                elseif i == 4 then color = 0xFFAA00  -- Монитор - оранжевый
                elseif i == 5 then color = 0xFF55FF  -- Сапер - фиолетовый
                elseif i == 6 then color = 0xFF5555 end -- Змейка - красный
                
                -- Фон приложения
                gpu.setBackground(color)
                gpu.setForeground(0x000000)
                gpu.fill(x, y, appWidth, appHeight, " ")
                
                -- Рамка приложения
                gpu.set(x, y, "┌" .. string.rep("─", appWidth - 2) .. "┐")
                gpu.set(x, y + appHeight - 1, "└" .. string.rep("─", appWidth - 2) .. "┘")
                for j = 1, appHeight - 2 do
                    gpu.set(x, y + j, "│")
                    gpu.set(x + appWidth - 1, y + j, "│")
                end
                
                -- Название приложения
                gpu.set(x + 2, y + 1, app.icon .. " " .. app.name)
                
                -- Горячая клавиша
                gpu.set(x + 2, y + 2, "Клавиша: " .. app.key)
                
                -- Кнопка запуска
                gpu.setBackground(0x000000)
                gpu.setForeground(color)
                gpu.fill(x + 2, y + appHeight - 2, 12, 1, " ")
                gpu.set(x + 3, y + appHeight - 2, "▶ Запустить")
                
                x = x + appWidth + 2
                if x + appWidth > maxWidth then
                    x = startX
                    y = y + appHeight + 2
                end
            end
        end
        
        -- Подсказка по горячим клавишам
        gpu.setBackground(theme.background)
        gpu.setForeground(theme.info)
        gpu.set(startX, maxHeight - 4, "Используйте цифры 1-6 для быстрого запуска приложений")
    end
    
    -- Консоль
    function drawConsole()
        local startX = sidebarWidth + 3
        gpu.setForeground(theme.accent)
        gpu.set(startX, 5, "╔════════════════════════════════════════════════╗")
        gpu.set(startX, 6, "║              КОНСОЛЬ ASMELIT OS               ║")
        gpu.set(startX, 7, "╚════════════════════════════════════════════════╝")
        
        gpu.setForeground(theme.text)
        gpu.set(startX, 9, "Текущая директория: " .. currentDir)
        gpu.set(startX, 10, string.rep("─", maxWidth - startX - 3))
        
        -- Показываем историю логов
        gpu.set(startX, 12, "Последние события системы:")
        local y = 13
        for i = math.max(1, #systemLog - 5), #systemLog do
            if y < maxHeight - 5 then
                gpu.set(startX + 2, y, "• " .. systemLog[i])
                y = y + 1
            end
        end
        
        gpu.set(startX, maxHeight - 4, string.rep("═", maxWidth - startX - 3))
        gpu.set(startX, maxHeight - 3, "> ")
    end
    
    -- Информация о системе
    function drawSystemInfo()
        local startX = sidebarWidth + 3
        gpu.setForeground(theme.accent)
        gpu.set(startX, 5, "ℹ️ ИНФОРМАЦИЯ О СИСТЕМЕ")
        gpu.set(startX, 6, string.rep("─", maxWidth - startX - 3))
        
        -- Основная информация
        local infoLines = {
            "Версия: Asmelit OS 4.0",
            "Память: " .. computer.freeMemory() .. " / " .. computer.totalMemory() .. " байт",
            "Время работы: " .. string.format("%.1f минут", (computer.uptime() - startTime) / 60),
            "Логов в памяти: " .. #systemLog .. " записей",
            "Экран: " .. maxWidth .. "x" .. maxHeight,
            "Дисковое пространство:"
        }
        
        -- Информация о дисках
        local driveCount = 0
        local totalSpace = 0
        local usedSpace = 0
        
        for addr in component.list("drive") do
            local proxy = component.proxy(addr)
            if proxy then
                driveCount = driveCount + 1
                local capacity = proxy.capacity() or 0
                local used = proxy.spaceUsed() or 0
                totalSpace = totalSpace + capacity
                usedSpace = usedSpace + used
                
                local free = capacity - used
                local percent = capacity > 0 and math.floor((used / capacity) * 100) or 0
                
                table.insert(infoLines, string.format("  Диск %d: %dK / %dK (%d%% свободно)", 
                    driveCount, math.floor(used/1024), math.floor(capacity/1024), 100-percent))
            end
        end
        
        if driveCount == 0 then
            table.insert(infoLines, "  Диски не обнаружены")
        end
        
        -- Энергия
        if computer.maxEnergy() > 0 then
            table.insert(infoLines, "")
            table.insert(infoLines, "Энергия: " .. math.floor((computer.energy() / computer.maxEnergy()) * 100) .. "%")
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
        
        -- График использования памяти (если есть место)
        if y < maxHeight - 10 then
            gpu.setForeground(theme.accent)
            gpu.set(startX, y, "Использование памяти:")
            y = y + 1
            
            local usedPercent = math.floor((1 - computer.freeMemory() / computer.totalMemory()) * 100)
            local barWidth = 40
            local barX = startX
            
            -- Фон графика
            gpu.setBackground(theme.sidebar)
            gpu.fill(barX, y, barWidth, 1, "█")
            
            -- Заполненная часть
            local filledWidth = math.floor(barWidth * usedPercent / 100)
            gpu.setBackground(theme.highlight)
            gpu.fill(barX, y, filledWidth, 1, "█")
            
            -- Подпись
            gpu.setBackground(theme.background)
            gpu.setForeground(theme.text)
            gpu.set(barX + barWidth + 2, y, string.format("%d%%", usedPercent))
        end
    end
    
    -- Запуск приложения
    local function runApp(appFilename)
        local path = "/apps/" .. appFilename
        if fs.exists(path) then
            showMessage("Запускаю приложение...", theme.info, "Запуск")
            local ok, err = pcall(dofile, path)
            if not ok then
                showMessage("Ошибка запуска приложения:\n" .. tostring(err), theme.error, "Ошибка")
            end
        else
            showMessage("Приложение не найдено!\nФайл: " .. appFilename .. "\n\nЗагрузите приложения через меню.", 
                       theme.error, "Ошибка")
        end
    end
    
    -- Функция консоли
    local function runConsole()
        local consoleText = ""
        local consoleHistory = {}
        local historyIndex = 0
        
        while mode == "console" do
            drawInterface()
            
            local startX = sidebarWidth + 3
            gpu.set(startX, maxHeight - 3, "> " .. consoleText .. "_")
            
            local e = {event.pull()}
            
            if e[1] == "key_down" then
                local char, code = e[3], e[4]
                
                if code == 28 then -- Enter
                    if #consoleText > 0 then
                        -- Сохраняем в историю
                        table.insert(consoleHistory, consoleText)
                        historyIndex = #consoleHistory + 1
                        
                        local cmd = consoleText:lower()
                        
                        -- Обработка команд
                        if cmd == "help" then
                            showMessage([[
Доступные команды:
help     - эта справка
clear    - очистить экран
ls       - список файлов
cd [dir] - сменить директорию
cat [file] - показать файл
run [file] - запустить программу
sysinfo  - информация о системе
reboot   - перезагрузка
exit     - выход из консоли]], theme.text, "Справка по командам")
                            
                        elseif cmd == "clear" then
                            consoleText = ""
                            
                        elseif cmd == "ls" then
                            refreshFiles()
                            local fileList = ""
                            for _, file in ipairs(files) do
                                fileList = fileList .. (file.isDir and file.name .. "/\n" or file.name .. "\n")
                            end
                            showMessage("Файлы в " .. currentDir .. ":\n" .. fileList, theme.text, "Список файлов")
                            
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
                                    showMessage("Папка не найдена: " .. newDir, theme.error, "Ошибка")
                                end
                            end
                            refreshFiles()
                            
                        elseif cmd:sub(1,4) == "cat " then
                            local fileName = cmd:sub(5)
                            local path = currentDir .. "/" .. fileName
                            if fs.exists(path) and not fs.isDirectory(path) then
                                local file = io.open(path, "r")
                                if file then
                                    local content = file:read("*a")
                                    file:close()
                                    showMessage(content, theme.text, "Файл: " .. fileName)
                                end
                            else
                                showMessage("Файл не найден: " .. fileName, theme.error, "Ошибка")
                            end
                            
                        elseif cmd:sub(1,4) == "run " then
                            local fileName = cmd:sub(5)
                            local path = currentDir .. "/" .. fileName
                            if fs.exists(path) then
                                local ok, err = pcall(dofile, path)
                                if not ok then
                                    showMessage("Ошибка запуска: " .. tostring(err), theme.error, "Ошибка")
                                end
                            else
                                showMessage("Файл не найден: " .. fileName, theme.error, "Ошибка")
                            end
                            
                        elseif cmd == "sysinfo" then
                            local info = string.format(
                                "Память: %d/%d байт (свободно: %d)\n" ..
                                "Время работы: %.1f минут\n" ..
                                "Энергия: %s",
                                computer.freeMemory(), computer.totalMemory(),
                                computer.totalMemory() - computer.freeMemory(),
                                (computer.uptime() - startTime) / 60,
                                computer.maxEnergy() > 0 and 
                                math.floor((computer.energy() / computer.maxEnergy()) * 100) .. "%" or "N/A"
                            )
                            showMessage(info, theme.text, "Информация о системе")
                            
                        elseif cmd == "reboot" then
                            showMessage("Перезагрузка системы...", theme.info, "Перезагрузка")
                            os.sleep(1)
                            computer.shutdown(true)
                            
                        elseif cmd == "exit" then
                            mode = "files"
                            return
                            
                        else
                            showMessage("Неизвестная команда: " .. cmd .. "\nВведите 'help' для списка команд", 
                                      theme.warning, "Ошибка")
                        end
                        
                        consoleText = ""
                    end
                    
                elseif code == 14 then -- Backspace
                    if #consoleText > 0 then
                        consoleText = consoleText:sub(1, -2)
                    end
                    
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
                    
                elseif char and char > 0 and char < 256 then -- Безопасная проверка
                    consoleText = consoleText .. string.char(char)
                end
            end
        end
    end
    
    -- Основной цикл системы
    refreshFiles()
    
    while true do
        -- Проверка памяти
        if computer.freeMemory() < 1024 then
            showMessage("Критически мало памяти!\nТребуется перезагрузка системы.", theme.error, "Ошибка памяти")
            computer.shutdown(true)
        end
        
        -- Если режим консоли, запускаем консоль
        if mode == "console" then
            runConsole()
        end
        
        -- Рисуем интерфейс
        drawInterface()
        
        -- Обработка событий
        while true do
            local e = {event.pull()}
            
            if e[1] == "key_down" then
                local char, code = e[3], e[4]
                
                -- Обработка по режимам
                if mode == "files" then
                    if code == 200 then -- Up
                        if selected > 1 then
                            selected = selected - 1
                            if selected <= scrollOffset then
                                scrollOffset = scrollOffset - 1
                            end
                        end
                        
                    elseif code == 208 then -- Down
                        if selected < #files then
                            selected = selected + 1
                            if selected > scrollOffset + (maxHeight - 8) then
                                scrollOffset = scrollOffset + 1
                            end
                        end
                        
                    elseif code == 28 then -- Enter
                        if files[selected] then
                            if files[selected].isDir then
                                currentDir = files[selected].path
                                refreshFiles()
                            else
                                local path = files[selected].path
                                if path:sub(-4) == ".lua" then
                                    local ok, err = pcall(dofile, path)
                                    if not ok then
                                        showMessage("Ошибка запуска:\n" .. tostring(err), theme.error, "Ошибка")
                                    end
                                else
                                    showMessage("Файл '" .. files[selected].name .. "' нельзя запустить как программу.\nТолько .lua файлы могут быть выполнены.", 
                                              theme.warning, "Информация")
                                end
                            end
                        end
                        
                    elseif code == 60 then -- F2
                        showMessage("Функция создания файлов в разработке.\nБудет доступна в следующей версии.", 
                                  theme.info, "Информация")
                        
                    elseif code == 211 then -- Delete
                        if files[selected] then
                            showMessage("Удалить '" .. files[selected].name .. "'?\n\n(Функция удаления в разработке)", 
                                      theme.warning, "Подтверждение удаления")
                        end
                    end
                    
                elseif mode == "apps" then
                    -- Горячие клавиши для приложений
                    if char == "1" then runApp("calculator.lua")
                    elseif char == "2" then runApp("editor.lua")
                    elseif char == "3" then runApp("browser.lua")
                    elseif char == "4" then runApp("monitor.lua")
                    elseif char == "5" then runApp("sapper.lua")
                    elseif char == "6" then runApp("snake.lua") end
                end
                
                -- Глобальные горячие клавиши
                if code == 1 then -- ESC
                    if mode == "files" then
                        local choice = showMessage("Завершить работу Asmelit OS?", theme.warning, "Выход из системы")
                        if choice then
                            showMessage("Завершение работы...", theme.info, "Asmelit OS")
                            os.sleep(1)
                            computer.shutdown()
                        end
                    else
                        mode = "files"
                    end
                    break
                    
                elseif code == 59 then -- F1
                    showMessage(
                        "Горячие клавиши:\n" ..
                        "ESC - Выход/Назад\n" ..
                        "F1 - Помощь\n" ..
                        "F2 - Новый файл\n" ..
                        "F5 - Обновить\n" ..
                        "В приложениях: 1-6 - запуск приложений\n" ..
                        "В файлах: ↑↓ - навигация, Enter - открыть",
                        theme.info, "Справка по горячим клавишам"
                    )
                    break
                    
                elseif code == 63 then -- F5
                    refreshFiles()
                    break
                end
                
            elseif e[1] == "touch" then
                local x, y = e[3], e[4]
                
                -- Клик по сайдбару
                for btnId, pos in pairs(buttonPositions) do
                    if x >= pos.x1 and x <= pos.x2 and y >= pos.y1 and y <= pos.y2 then
                        mode = btnId
                        if mode == "console" then
                            runConsole()
                        end
                        break
                    end
                end
                
                -- Клик по приложениям (в режиме приложений)
                if mode == "apps" then
                    local startX = sidebarWidth + 3
                    local startY = 8
                    local appWidth = 25
                    local appHeight = 6
                    
                    local currentX, currentY = startX, startY
                    local appIndex = 1
                    
                    -- Проверяем все приложения
                    for _, app in ipairs(appsToDownload) do
                        if fs.exists("/apps/" .. app.filename) then
                            if x >= currentX and x < currentX + appWidth and
                               y >= currentY and y < currentY + appHeight then
                                runApp(app.filename)
                                break
                            end
                            
                            currentX = currentX + appWidth + 2
                            if currentX + appWidth > maxWidth then
                                currentX = startX
                                currentY = currentY + appHeight + 2
                            end
                        end
                        appIndex = appIndex + 1
                    end
                end
                
                break
                
            elseif e[1] == "scroll" then
                if mode == "files" then
                    local delta = e[5]
                    if delta > 0 and scrollOffset > 0 then
                        scrollOffset = scrollOffset - 1
                        if selected > scrollOffset + 1 then
                            selected = math.max(1, selected - 1)
                        end
                    elseif delta < 0 and scrollOffset + (maxHeight - 8) < #files then
                        scrollOffset = scrollOffset + 1
                        if selected < scrollOffset + (maxHeight - 9) then
                            selected = math.min(#files, selected + 1)
                        end
                    end
                    break
                end
            end
        end
    end
end

-- =====================================================
-- ТОЧКА ВХОДА СИСТЕМЫ
-- =====================================================
log("=== Asmelit OS v4.0 - Инициализация системы ===")

-- Проверяем достаточно ли памяти
if computer.freeMemory() < 2048 then
    showMessage("Внимание: мало оперативной памяти!\n" ..
               "Доступно: " .. computer.freeMemory() .. " байт\n" ..
               "Рекомендуется: минимум 4KB\n\n" ..
               "Система может работать нестабильно.",
               theme.warning, "Предупреждение о памяти")
end

-- Запускаем загрузочный экран
local bootOk, bootErr = pcall(bootScreen)
if not bootOk then
    log("Ошибка загрузочного экрана: " .. tostring(bootErr))
end

-- Проверяем и загружаем приложения
checkAndLoadApps()

-- Запускаем основной интерфейс
local mainOk, mainErr = pcall(mainGUI)
if not mainOk then
    showMessage("Критическая ошибка системы:\n" .. tostring(mainErr) .. "\n\n" ..
               "Система будет перезагружена через 5 секунд...",
               theme.error, "Сбой системы")
    os.sleep(5)
    computer.shutdown(true)
end

-- Если mainGUI завершился (чего не должно быть в нормальных условиях)
showMessage("Система завершила работу.", theme.info, "Asmelit OS")
computer.shutdown()
