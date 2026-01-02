-- =====================================================
-- Asmelit OS v4.1 - Исправленная версия
-- =====================================================

-- Основные библиотеки
local component = require("component")
local computer = require("computer")
local event = require("event")
local term = require("term")
local gpu = component.gpu
local fs = require("filesystem")
local serialization = require("serialization")

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
    button_active = 0x4A7BFF
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

-- Логирование
function log(message)
    local timestamp = os.date("%H:%M:%S")
    local entry = timestamp .. " - " .. message
    table.insert(systemLog, entry)
    if #systemLog > 50 then
        table.remove(systemLog, 1)
    end
end

-- Показать окно с выбором Да/Нет
function showYesNoMessage(text, title)
    title = title or "Вопрос"
    
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
    
    -- Основное окно
    gpu.setBackground(theme.header)
    gpu.fill(winX, winY, winWidth, winHeight, " ")
    
    -- Рамка
    gpu.setForeground(theme.accent)
    gpu.set(winX, winY, "╔" .. string.rep("═", winWidth - 2) .. "╗")
    gpu.set(winX, winY + winHeight - 1, "╚" .. string.rep("═", winWidth - 2) .. "╝")
    for i = 1, winHeight - 2 do
        gpu.set(winX, winY + i, "║")
        gpu.set(winX + winWidth - 1, winY + i, "║")
    end
    
    -- Заголовок
    local titleX = winX + math.floor((winWidth - #title) / 2)
    gpu.set(titleX, winY + 1, title)
    
    -- Разделитель
    gpu.set(winX, winY + 2, "╠" .. string.rep("═", winWidth - 2) .. "╣")
    
    -- Текст сообщения
    gpu.setForeground(theme.text)
    for i, line in ipairs(lines) do
        local lineX = winX + math.floor((winWidth - #line) / 2)
        gpu.set(lineX, winY + 4 + i, line)
    end
    
    -- Кнопки
    local btnYesText = "  Да  "
    local btnNoText = "  Нет  "
    local btnYesX = winX + math.floor(winWidth / 2) - #btnYesText - 2
    local btnNoX = winX + math.floor(winWidth / 2) + 2
    local btnY = winY + winHeight - 3
    
    -- Выбранная кнопка
    local selected = 1 -- 1 = Да, 2 = Нет
    
    while true do
        -- Кнопка Да
        if selected == 1 then
            gpu.setBackground(theme.button_active)
            gpu.setForeground(0x000000)
        else
            gpu.setBackground(theme.button)
            gpu.setForeground(theme.text)
        end
        gpu.fill(btnYesX, btnY, #btnYesText, 1, " ")
        gpu.set(btnYesX, btnY, btnYesText)
        
        -- Кнопка Нет
        if selected == 2 then
            gpu.setBackground(theme.button_active)
            gpu.setForeground(0x000000)
        else
            gpu.setBackground(theme.button)
            gpu.setForeground(theme.text)
        end
        gpu.fill(btnNoX, btnY, #btnNoText, 1, " ")
        gpu.set(btnNoX, btnY, btnNoText)
        
        -- Обработка ввода
        local e = {event.pull()}
        if e[1] == "key_down" then
            local code = e[4]
            
            if code == 28 or code == 57 then -- Enter или Space
                return selected == 1
            elseif code == 1 then -- ESC
                return false
            elseif code == 203 then -- Left
                selected = 1
            elseif code == 205 then -- Right
                selected = 2
            end
            
        elseif e[1] == "touch" then
            local x, y = e[3], e[4]
            
            if x >= btnYesX and x < btnYesX + #btnYesText and y == btnY then
                return true
            elseif x >= btnNoX and x < btnNoX + #btnNoText and y == btnY then
                return false
            end
        end
    end
end

-- Показать сообщение с кнопкой OK
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
    
    -- Основное окно
    gpu.setBackground(theme.header)
    gpu.fill(winX, winY, winWidth, winHeight, " ")
    
    -- Рамка
    gpu.setForeground(theme.accent)
    gpu.set(winX, winY, "╔" .. string.rep("═", winWidth - 2) .. "╗")
    gpu.set(winX, winY + winHeight - 1, "╚" .. string.rep("═", winWidth - 2) .. "╝")
    for i = 1, winHeight - 2 do
        gpu.set(winX, winY + i, "║")
        gpu.set(winX + winWidth - 1, winY + i, "║")
    end
    
    -- Заголовок
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
    
    -- Кнопка OK
    local btnText = "   OK   "
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

-- Загрузка файла с GitHub (ИСПРАВЛЕННАЯ ВЕРСИЯ)
function downloadFromGitHub(url, filename)
    -- Проверяем наличие интернет-карты
    if not component.isAvailable("internet") then
        return false, "Нет интернет-карты"
    end
    
    local internet = require("internet")
    local handle, err
    
    -- Безопасный запрос с pcall
    local ok, result = pcall(function()
        return internet.request(url)
    end)
    
    if not ok then
        return false, "Ошибка запроса: " .. tostring(result)
    end
    
    handle = result
    
    if not handle then
        return false, "Не удалось получить ответ от сервера"
    end
    
    -- Читаем содержимое файла
    local content = ""
    local chunkCount = 0
    
    for chunk in handle do
        if chunk then
            content = content .. chunk
            chunkCount = chunkCount + 1
            
            -- Защита от слишком больших файлов
            if #content > 500000 then -- 500KB лимит
                return false, "Файл слишком большой"
            end
        end
    end
    
    -- Проверяем что файл не пустой
    if #content < 10 then
        return false, "Пустой файл или ошибка загрузки"
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
    gpu.set(centerX - 12, 5, "║      Asmelit OS v4.1     ║")
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
            
            if showYesNoMessage(missingText .. "\nЗагрузить приложения с GitHub?", "Обнаружены отсутствующие приложения") then
                downloadAllApps()
            else
                showMessage("Приложения не будут загружены.\nНекоторые функции могут быть недоступны.", 
                          theme.warning, "Информация")
            end
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
║           ASMELIT OS v4.1            ║
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
    
    local sidebarButtons = {
        {id = "files", icon = "📁", text = "Файлы"},
        {id = "apps", icon = "🚀", text = "Приложения"},
        {id = "console", icon = "💻", text = "Консоль"},
        {id = "info", icon = "ℹ️", text = "О системе"}
    }
    
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
                        path = path
                    })
                end
            end
        end
        
        -- Сортировка
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
        
        -- Верхняя панель
        gpu.setBackground(theme.header)
        gpu.fill(1, 1, maxWidth, 2, " ")
        
        gpu.setForeground(theme.accent)
        local title = "Asmelit OS v4.1"
        if mode == "files" then
            title = title .. " - " .. currentDir
        else
            for _, btn in ipairs(sidebarButtons) do
                if btn.id == mode then
                    title = title .. " - " .. btn.text
                    break
                end
            end
        end
        gpu.set(3, 1, title)
        
        -- Время и память
        local time = os.date("%H:%M")
        local mem = math.floor(computer.freeMemory() / 1024) .. "K"
        gpu.set(maxWidth - #time - #mem - 3, 1, time .. " | " .. mem)
        
        -- Боковая панель
        gpu.setBackground(theme.sidebar)
        gpu.fill(1, 3, sidebarWidth, maxHeight - 2, " ")
        
        -- Кнопки сайдбара
        local buttonY = 5
        for _, btn in ipairs(sidebarButtons) do
            local isActive = (mode == btn.id)
            
            if isActive then
                gpu.setBackground(theme.button_active)
                gpu.setForeground(0x000000)
            else
                gpu.setBackground(theme.sidebar)
                gpu.setForeground(theme.text)
            end
            
            gpu.fill(1, buttonY, sidebarWidth, 1, " ")
            gpu.set(3, buttonY, btn.icon .. " " .. btn.text)
            buttonY = buttonY + 2
        end
        
        -- Основная область
        gpu.setBackground(theme.background)
        gpu.setForeground(theme.text)
        
        if mode == "files" then
            local startX = sidebarWidth + 3
            local availableHeight = maxHeight - 7
            
            gpu.setForeground(theme.accent)
            gpu.set(startX, 5, "ИМЯ")
            gpu.set(startX + 35, 5, "ТИП")
            gpu.set(startX + 45, 5, "РАЗМЕР")
            
            gpu.setForeground(theme.text)
            gpu.set(startX, 6, string.rep("─", maxWidth - startX - 2))
            
            local y = 7
            for i = 1, math.min(#files - scrollOffset, availableHeight) do
                local idx = i + scrollOffset
                local file = files[idx]
                
                if file then
                    if idx == selected then
                        gpu.setBackground(theme.highlight)
                        gpu.setForeground(0x000000)
                    else
                        gpu.setBackground(theme.background)
                        gpu.setForeground(file.isDir and theme.accent or theme.text)
                    end
                    
                    gpu.fill(startX, y, maxWidth - startX - 2, 1, " ")
                    
                    local name = file.name
                    if file.isDir then name = name .. "/" end
                    if #name > 30 then name = name:sub(1, 27) .. "..." end
                    
                    gpu.set(startX, y, name)
                    gpu.set(startX + 35, y, file.isDir and "Папка" or "Файл")
                    gpu.set(startX + 45, y, file.size)
                    
                    local icon = file.isDir and "📁" or "📄"
                    gpu.set(startX - 2, y, icon)
                    
                    y = y + 1
                end
            end
            
            gpu.setBackground(theme.background)
            gpu.setForeground(theme.info)
            gpu.set(startX, maxHeight - 2, "Файлов: " .. #files .. " | Выбрано: " .. selected)
            
        elseif mode == "apps" then
            local startX = sidebarWidth + 3
            local y = 5
            
            -- Проверяем какие приложения есть
            local availableApps = {}
            for _, app in ipairs(appsToDownload) do
                if fs.exists("/apps/" .. app.filename) then
                    table.insert(availableApps, app)
                end
            end
            
            if #availableApps == 0 then
                gpu.set(centerX - 20, centerY - 2, "Приложения не загружены")
                gpu.set(centerX - 25, centerY, "Запустите систему с интернет-картой")
                gpu.set(centerX - 20, centerY + 2, "для автоматической загрузки приложений")
            else
                gpu.setForeground(theme.accent)
                gpu.set(startX, 5, "ДОСТУПНЫЕ ПРИЛОЖЕНИЯ:")
                gpu.set(startX, 6, string.rep("─", maxWidth - startX - 3))
                
                y = 8
                for i, app in ipairs(availableApps) do
                    gpu.setForeground(theme.text)
                    gpu.set(startX, y, app.icon .. " " .. app.name .. " (клавиша " .. app.key .. ")")
                    gpu.set(startX + 30, y, "[Запустить]")
                    y = y + 2
                end
            end
            
        elseif mode == "console" then
            local startX = sidebarWidth + 3
            gpu.set(startX, 5, "Введите 'help' для списка команд")
            gpu.set(startX, 6, "> ")
            
        elseif mode == "info" then
            local startX = sidebarWidth + 3
            gpu.setForeground(theme.accent)
            gpu.set(startX, 5, "ИНФОРМАЦИЯ О СИСТЕМЕ")
            gpu.set(startX, 6, string.rep("─", maxWidth - startX - 3))
            
            local info = {
                "Версия: Asmelit OS 4.1",
                "Память: " .. computer.freeMemory() .. "/" .. computer.totalMemory() .. " байт",
                "Время работы: " .. string.format("%.1f мин", (computer.uptime() - startTime) / 60),
                "Приложений загружено: " .. #appsToDownload
            }
            
            for i, line in ipairs(info) do
                gpu.setForeground(theme.text)
                gpu.set(startX, 8 + i, line)
            end
        end
        
        -- Нижняя панель
        gpu.setBackground(theme.header)
        gpu.setForeground(theme.text)
        gpu.fill(1, maxHeight, maxWidth, 1, " ")
        
        local hint = ""
        if mode == "files" then
            hint = "↑↓ - Выбрать | Enter - Открыть | ESC - Выход"
        elseif mode == "apps" then
            hint = "Выберите приложение для запуска | ESC - Назад"
        else
            hint = "ESC - Назад в файлы"
        end
        
        gpu.set(3, maxHeight, hint)
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
        
        while mode == "console" do
            drawInterface()
            
            local startX = sidebarWidth + 3
            gpu.set(startX, 6, "> " .. consoleText .. "_")
            
            local e = {event.pull()}
            
            if e[1] == "key_down" then
                local char, code = e[3], e[4]
                
                if code == 28 then -- Enter
                    if #consoleText > 0 then
                        local cmd = consoleText:lower()
                        
                        if cmd == "help" then
                            showMessage([[
Доступные команды:
help     - справка
clear    - очистить
ls       - файлы
cd [dir] - смена папки
cat [file] - просмотр
run [file] - запуск
sysinfo  - информация
reboot   - перезагрузка
exit     - выход]], theme.text, "Справка")
                            
                        elseif cmd == "clear" then
                            consoleText = ""
                            
                        elseif cmd == "ls" then
                            refreshFiles()
                            local list = ""
                            for _, file in ipairs(files) do
                                list = list .. (file.isDir and file.name .. "/\n" or file.name .. "\n")
                            end
                            showMessage("Файлы в " .. currentDir .. ":\n" .. list, theme.text, "Список файлов")
                            
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
                                "Память: %d/%d байт\nВремя: %.1f мин",
                                computer.freeMemory(), computer.totalMemory(),
                                (computer.uptime() - startTime) / 60
                            )
                            showMessage(info, theme.text, "Информация о системе")
                            
                        elseif cmd == "reboot" then
                            computer.shutdown(true)
                            
                        elseif cmd == "exit" then
                            mode = "files"
                            return
                            
                        else
                            showMessage("Неизвестная команда: " .. cmd, theme.warning, "Ошибка")
                        end
                        
                        consoleText = ""
                    end
                    
                elseif code == 14 then -- Backspace
                    if #consoleText > 0 then
                        consoleText = consoleText:sub(1, -2)
                    end
                    
                elseif code == 1 then -- ESC
                    mode = "files"
                    return
                    
                elseif char and char > 0 and char < 256 then
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
                        if showYesNoMessage("Завершить работу Asmelit OS?", "Выход из системы") then
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
                
                -- Клик по сайдбару (приблизительная позиция)
                if x >= 1 and x <= sidebarWidth then
                    if y >= 5 and y <= 5 + (#sidebarButtons * 2) then
                        local buttonIndex = math.floor((y - 5) / 2) + 1
                        if buttonIndex >= 1 and buttonIndex <= #sidebarButtons then
                            mode = sidebarButtons[buttonIndex].id
                            if mode == "console" then
                                runConsole()
                            end
                        end
                    end
                end
                
                break
            end
        end
    end
end

-- =====================================================
-- ТОЧКА ВХОДА СИСТЕМЫ
-- =====================================================
log("=== Asmelit OS v4.1 - Инициализация системы ===")

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

-- Если mainGUI завершился
showMessage("Система завершила работу.", theme.info, "Asmelit OS")
computer.shutdown()
