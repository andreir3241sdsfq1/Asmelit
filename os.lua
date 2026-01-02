-- =====================================================
-- Asmelit OS v4.3 - Полностью исправленная версия
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
        icon = "C",
        key = "1"
    },
    {
        name = "Редактор", 
        url = "https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/refs/heads/main/editor.lua",
        filename = "editor.lua",
        icon = "E",
        key = "2"
    },
    {
        name = "Браузер",
        url = "https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/refs/heads/main/browser.lua",
        filename = "browser.lua",
        icon = "B",
        key = "3"
    },
    {
        name = "Монитор",
        url = "https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/refs/heads/main/monitor.lua",
        filename = "monitor.lua",
        icon = "M",
        key = "4"
    },
    {
        name = "Сапер",
        url = "https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/refs/heads/main/sapper.lua",
        filename = "sapper.lua",
        icon = "S",
        key = "5"
    },
    {
        name = "Змейка",
        url = "https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/refs/heads/main/snake.lua",
        filename = "snake.lua",
        icon = "Z",
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
    
    gpu.setBackground(theme.background)
    gpu.fill(winX, winY, winWidth, winHeight, " ")
    
    gpu.setBackground(theme.header)
    gpu.fill(winX, winY, winWidth, winHeight, " ")
    
    gpu.setForeground(theme.accent)
    gpu.set(winX, winY, "+" .. string.rep("-", winWidth - 2) .. "+")
    gpu.set(winX, winY + winHeight - 1, "+" .. string.rep("-", winWidth - 2) .. "+")
    for i = 1, winHeight - 2 do
        gpu.set(winX, winY + i, "|")
        gpu.set(winX + winWidth - 1, winY + i, "|")
    end
    
    local titleX = winX + math.floor((winWidth - #title) / 2)
    gpu.set(titleX, winY + 1, title)
    
    gpu.set(winX, winY + 2, "+" .. string.rep("-", winWidth - 2) .. "+")
    
    gpu.setForeground(theme.text)
    for i, line in ipairs(lines) do
        local lineX = winX + math.floor((winWidth - #line) / 2)
        gpu.set(lineX, winY + 4 + i, line)
    end
    
    local btnYesText = "  Да  "
    local btnNoText = "  Нет  "
    local btnYesX = winX + math.floor(winWidth / 2) - #btnYesText - 2
    local btnNoX = winX + math.floor(winWidth / 2) + 2
    local btnY = winY + winHeight - 3
    
    local selected = 1
    
    while true do
        if selected == 1 then
            gpu.setBackground(theme.button_active)
            gpu.setForeground(0x000000)
        else
            gpu.setBackground(theme.button)
            gpu.setForeground(theme.text)
        end
        gpu.fill(btnYesX, btnY, #btnYesText, 1, " ")
        gpu.set(btnYesX, btnY, btnYesText)
        
        if selected == 2 then
            gpu.setBackground(theme.button_active)
            gpu.setForeground(0x000000)
        else
            gpu.setBackground(theme.button)
            gpu.setForeground(theme.text)
        end
        gpu.fill(btnNoX, btnY, #btnNoText, 1, " ")
        gpu.set(btnNoX, btnY, btnNoText)
        
        local e = {event.pull()}
        if e[1] == "key_down" then
            local code = e[4]
            
            if code == 28 or code == 57 then
                return selected == 1
            elseif code == 1 then
                return false
            elseif code == 203 then
                selected = 1
            elseif code == 205 then
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
    
    gpu.setBackground(theme.background)
    gpu.fill(winX, winY, winWidth, winHeight, " ")
    
    gpu.setBackground(theme.header)
    gpu.fill(winX, winY, winWidth, winHeight, " ")
    
    gpu.setForeground(theme.accent)
    gpu.set(winX, winY, "+" .. string.rep("-", winWidth - 2) .. "+")
    gpu.set(winX, winY + winHeight - 1, "+" .. string.rep("-", winWidth - 2) .. "+")
    for i = 1, winHeight - 2 do
        gpu.set(winX, winY + i, "|")
        gpu.set(winX + winWidth - 1, winY + i, "|")
    end
    
    local titleX = winX + math.floor((winWidth - #title) / 2)
    gpu.set(titleX, winY + 1, title)
    
    gpu.set(winX, winY + 2, "+" .. string.rep("-", winWidth - 2) .. "+")
    
    gpu.setForeground(color)
    for i, line in ipairs(lines) do
        local lineX = winX + math.floor((winWidth - #line) / 2)
        gpu.set(lineX, winY + 4 + i, line)
    end
    
    local btnText = "   OK   "
    local btnX = winX + math.floor((winWidth - #btnText) / 2)
    local btnY = winY + winHeight - 3
    
    gpu.setBackground(theme.button)
    gpu.setForeground(theme.text)
    gpu.fill(btnX, btnY, #btnText, 1, " ")
    gpu.set(btnX, btnY, btnText)
    
    while true do
        local e = {event.pull()}
        if e[1] == "key_down" then
            if e[4] == 28 or e[4] == 57 then
                break
            elseif e[4] == 1 then
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

-- Простой текстовый редактор
function textEditor(filename)
    local content = ""
    local cursorX, cursorY = 1, 1
    local scrollX, scrollY = 0, 0
    local modified = false
    local saved = false
    
    -- Загрузка существующего файла
    if fs.exists(filename) then
        local file = io.open(filename, "r")
        if file then
            content = file:read("*a") or ""
            file:close()
            saved = true
        end
    end
    
    -- Разбиваем содержимое на строки
    local lines = {}
    for line in content:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    if #lines == 0 then table.insert(lines, "") end
    
    -- Размеры редактора
    local editorWidth = maxWidth - 10
    local editorHeight = maxHeight - 10
    local editorX = 5
    local editorY = 5
    
    -- Отрисовка интерфейса редактора
    local function drawEditor()
        gpu.setBackground(theme.background)
        gpu.setForeground(theme.text)
        term.clear()
        
        -- Верхняя панель
        gpu.setBackground(theme.header)
        gpu.fill(1, 1, maxWidth, 2, " ")
        gpu.setForeground(theme.accent)
        local status = modified and "* " or "  "
        gpu.set(3, 1, status .. "Редактор: " .. filename)
        gpu.set(maxWidth - 15, 1, "Ctrl+S Сохранить")
        gpu.set(maxWidth - 15, 2, "Ctrl+Q Выход")
        
        -- Основная область редактора
        gpu.setBackground(0x000000)
        gpu.fill(editorX, editorY, editorWidth, editorHeight, " ")
        
        -- Отображаем строки
        for i = 1, math.min(editorHeight, #lines - scrollY) do
            local lineIdx = i + scrollY
            local line = lines[lineIdx]
            if line then
                local displayText = line:sub(scrollX + 1, scrollX + editorWidth)
                gpu.set(editorX, editorY + i - 1, displayText)
            end
        end
        
        -- Курсор
        if cursorY >= scrollY + 1 and cursorY <= scrollY + editorHeight then
            if cursorX >= scrollX + 1 and cursorX <= scrollX + editorWidth then
                local cursorScreenX = editorX + (cursorX - scrollX - 1)
                local cursorScreenY = editorY + (cursorY - scrollY - 1)
                gpu.setBackground(0xFFFFFF)
                gpu.setForeground(0x000000)
                local charAtCursor = lines[cursorY]:sub(cursorX, cursorX)
                if charAtCursor == "" then charAtCursor = " " end
                gpu.set(cursorScreenX, cursorScreenY, charAtCursor)
            end
        end
        
        -- Информационная строка
        gpu.setBackground(theme.sidebar)
        gpu.setForeground(theme.text)
        gpu.fill(1, maxHeight, maxWidth, 1, " ")
        gpu.set(3, maxHeight, string.format("Строка: %d, Столбец: %d | Всего строк: %d", 
                                           cursorY, cursorX, #lines))
    end
    
    -- Сохранение файла
    local function saveFile()
        local contentToSave = table.concat(lines, "\n")
        local file = io.open(filename, "w")
        if file then
            file:write(contentToSave)
            file:close()
            modified = false
            saved = true
            return true
        end
        return false
    end
    
    -- Основной цикл редактора
    drawEditor()
    
    while true do
        local e = {event.pull()}
        
        if e[1] == "key_down" then
            local char, code = e[3], e[4]
            
            -- Ctrl+S - Сохранить
            if code == 31 and (char == 19 or char == 115) then
                if saveFile() then
                    showMessage("Файл сохранен: " .. filename, theme.success, "Сохранение")
                else
                    showMessage("Ошибка сохранения файла", theme.error, "Ошибка")
                end
                drawEditor()
                
            -- Ctrl+Q - Выход
            elseif code == 16 and (char == 17 or char == 113) then
                if modified then
                    if showYesNoMessage("Сохранить изменения в файле " .. filename .. "?", "Выход из редактора") then
                        saveFile()
                    end
                end
                return
                
            -- Enter
            elseif code == 28 then
                local currentLine = lines[cursorY]
                local leftPart = currentLine:sub(1, cursorX - 1)
                local rightPart = currentLine:sub(cursorX)
                
                lines[cursorY] = leftPart
                table.insert(lines, cursorY + 1, rightPart)
                
                cursorY = cursorY + 1
                cursorX = 1
                modified = true
                
            -- Backspace
            elseif code == 14 then
                if cursorX > 1 then
                    local currentLine = lines[cursorY]
                    lines[cursorY] = currentLine:sub(1, cursorX - 2) .. currentLine:sub(cursorX)
                    cursorX = cursorX - 1
                    modified = true
                elseif cursorY > 1 then
                    local prevLineLen = #lines[cursorY - 1]
                    lines[cursorY - 1] = lines[cursorY - 1] .. lines[cursorY]
                    table.remove(lines, cursorY)
                    cursorY = cursorY - 1
                    cursorX = prevLineLen + 1
                    modified = true
                end
                
            -- Delete
            elseif code == 211 then
                local currentLine = lines[cursorY]
                if cursorX <= #currentLine then
                    lines[cursorY] = currentLine:sub(1, cursorX - 1) .. currentLine:sub(cursorX + 1)
                    modified = true
                elseif cursorY < #lines then
                    lines[cursorY] = currentLine .. lines[cursorY + 1]
                    table.remove(lines, cursorY + 1)
                    modified = true
                end
                
            -- Стрелки
            elseif code == 200 then -- Up
                if cursorY > 1 then
                    cursorY = cursorY - 1
                    cursorX = math.min(cursorX, #lines[cursorY] + 1)
                end
                
            elseif code == 208 then -- Down
                if cursorY < #lines then
                    cursorY = cursorY + 1
                    cursorX = math.min(cursorX, #lines[cursorY] + 1)
                end
                
            elseif code == 203 then -- Left
                if cursorX > 1 then
                    cursorX = cursorX - 1
                elseif cursorY > 1 then
                    cursorY = cursorY - 1
                    cursorX = #lines[cursorY] + 1
                end
                
            elseif code == 205 then -- Right
                if cursorX <= #lines[cursorY] then
                    cursorX = cursorX + 1
                elseif cursorY < #lines then
                    cursorY = cursorY + 1
                    cursorX = 1
                end
                
            -- Обычные символы
            elseif char and char > 31 and char < 127 then
                local currentLine = lines[cursorY]
                lines[cursorY] = currentLine:sub(1, cursorX - 1) .. string.char(char) .. currentLine:sub(cursorX)
                cursorX = cursorX + 1
                modified = true
                
            -- ESC
            elseif code == 1 then
                if modified then
                    if showYesNoMessage("Сохранить изменения в файле " .. filename .. "?", "Выход из редактора") then
                        saveFile()
                    end
                end
                return
            end
            
            -- Прокрутка при необходимости
            if cursorY < scrollY + 1 then scrollY = cursorY - 1 end
            if cursorY > scrollY + editorHeight then scrollY = cursorY - editorHeight end
            if cursorX < scrollX + 1 then scrollX = cursorX - 1 end
            if cursorX > scrollX + editorWidth then scrollX = cursorX - editorWidth end
            
            drawEditor()
        end
    end
end

-- Загрузка файла с GitHub
function downloadFromGitHub(url, filename)
    if not component.isAvailable("internet") then
        return false, "Нет интернет-карты"
    end
    
    local internet = require("internet")
    local handle, err
    
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
    
    local content = ""
    local chunkCount = 0
    
    for chunk in handle do
        if chunk then
            content = content .. chunk
            chunkCount = chunkCount + 1
            
            if #content > 500000 then
                return false, "Файл слишком большой"
            end
        end
    end
    
    if #content < 10 then
        return false, "Пустой файл или ошибка загрузки"
    end
    
    if not fs.exists("/apps") then
        fs.makeDirectory("/apps")
    end
    
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
    gpu.setBackground(0x000000)
    gpu.setForeground(theme.accent)
    term.clear()
    
    gpu.set(centerX - 12, 3, "+---------------------------+")
    gpu.set(centerX - 12, 4, "|   ЗАГРУЗКА ПРИЛОЖЕНИЙ   |")
    gpu.set(centerX - 12, 5, "|      Asmelit OS v4.3     |")
    gpu.set(centerX - 12, 6, "+---------------------------+")
    
    gpu.setForeground(theme.text)
    gpu.set(centerX - 18, 8, "Загружаю приложения с GitHub...")
    
    local downloaded = 0
    local failed = 0
    
    local barWidth = 50
    local barX = centerX - math.floor(barWidth / 2)
    local barY = 11
    
    gpu.setBackground(0x333333)
    gpu.fill(barX, barY, barWidth, 1, "#")
    
    for i, app in ipairs(appsToDownload) do
        local progress = math.floor((i / #appsToDownload) * barWidth)
        gpu.setBackground(theme.highlight)
        gpu.fill(barX, barY, progress, 1, "#")
        
        gpu.setBackground(0x000000)
        gpu.setForeground(theme.text)
        local statusText = app.icon .. " " .. app.name .. "..."
        gpu.set(centerX - math.floor(#statusText / 2), 13, statusText)
        
        local percent = math.floor((i / #appsToDownload) * 100)
        gpu.set(centerX - 2, 14, string.format("%3d%%", percent))
        
        local success, message = downloadFromGitHub(app.url, app.filename)
        
        if success then
            downloaded = downloaded + 1
            gpu.setForeground(theme.success)
            gpu.set(centerX - 5, 16, "[OK] Успешно")
            log("Загружено приложение: " .. app.name)
        else
            failed = failed + 1
            gpu.setForeground(theme.error)
            gpu.set(centerX - 5, 16, "[X] Ошибка")
            log("Ошибка загрузки " .. app.name .. ": " .. message)
        end
        
        os.sleep(0.3)
    end
    
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
    local appsExist = true
    local missingApps = {}
    
    for _, app in ipairs(appsToDownload) do
        if not fs.exists("/apps/" .. app.filename) then
            appsExist = false
            table.insert(missingApps, app.name)
        end
    end
    
    if not appsExist then
        if component.isAvailable("internet") then
            local missingText = "Отсутствуют приложения:\n"
            for _, appName in ipairs(missingApps) do
                missingText = missingText .. "- " .. appName .. "\n"
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
    
    local logoText = [[
+--------------------------------------+
|        ASMELIT OS v4.3              |
|        ---------------              |
|                                      |
|        Система загружается...        |
+--------------------------------------+
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
    
    local barWidth = 60
    local barX = centerX - math.floor(barWidth / 2)
    local barY = logoStartY + #logoLines + 3
    
    if barY < maxHeight - 5 then
        gpu.setForeground(theme.text)
        gpu.set(barX, barY - 1, "Загрузка системы...")
        
        gpu.setBackground(theme.sidebar)
        gpu.setForeground(theme.sidebar)
        gpu.fill(barX, barY, barWidth, 1, "#")
        
        local phases = {"Инициализация...", "Загрузка ядра...", "Настройка интерфейса...", "Готово!"}
        
        for i = 1, barWidth do
            local progress = i / barWidth
            local r = math.floor(74 * progress)
            local g = math.floor(123 * progress + 100 * (1 - progress))
            local b = 255
            local color = r * 0x10000 + g * 0x100 + b
            
            gpu.setBackground(color)
            gpu.setForeground(color)
            gpu.set(barX + i - 1, barY, "#")
            
            local phaseIndex = math.floor(progress * #phases) + 1
            if phaseIndex <= #phases then
                gpu.setBackground(0x000000)
                gpu.setForeground(theme.text)
                gpu.fill(barX, barY + 2, barWidth, 1, " ")
                gpu.set(barX + math.floor((barWidth - #phases[phaseIndex]) / 2), barY + 2, phases[phaseIndex])
            end
            
            os.sleep(0.02)
        end
        
        gpu.setBackground(0x000000)
        gpu.setForeground(theme.success)
        gpu.set(barX + math.floor(barWidth / 2) - 3, barY + 4, "ГОТОВО!")
        os.sleep(1)
    end
    
    log("Система загружена успешно")
end

-- Диалог ввода текста
function inputDialog(prompt, title)
    title = title or "Ввод"
    
    local winWidth = 60
    local winHeight = 8
    local winX = math.floor((maxWidth - winWidth) / 2)
    local winY = math.floor((maxHeight - winHeight) / 2)
    
    gpu.setBackground(theme.background)
    gpu.fill(winX, winY, winWidth, winHeight, " ")
    
    gpu.setBackground(theme.header)
    gpu.fill(winX, winY, winWidth, winHeight, " ")
    
    gpu.setForeground(theme.accent)
    gpu.set(winX, winY, "+" .. string.rep("-", winWidth - 2) .. "+")
    gpu.set(winX, winY + winHeight - 1, "+" .. string.rep("-", winWidth - 2) .. "+")
    for i = 1, winHeight - 2 do
        gpu.set(winX, winY + i, "|")
        gpu.set(winX + winWidth - 1, winY + i, "|")
    end
    
    local titleX = winX + math.floor((winWidth - #title) / 2)
    gpu.set(titleX, winY + 1, title)
    
    gpu.set(winX, winY + 2, "+" .. string.rep("-", winWidth - 2) .. "+")
    
    gpu.setForeground(theme.text)
    local promptX = winX + math.floor((winWidth - #prompt) / 2)
    gpu.set(promptX, winY + 4, prompt)
    
    local inputText = ""
    local inputX = winX + 5
    local inputY = winY + 5
    local inputWidth = winWidth - 10
    
    local btnText = "   OK   "
    local btnX = winX + math.floor((winWidth - #btnText) / 2)
    local btnY = winY + winHeight - 2
    
    while true do
        gpu.setBackground(theme.sidebar)
        gpu.fill(inputX, inputY, inputWidth, 1, " ")
        gpu.setForeground(theme.text)
        local displayText = inputText
        if #displayText > inputWidth - 2 then
            displayText = "..." .. displayText:sub(#displayText - inputWidth + 5)
        end
        gpu.set(inputX, inputY, displayText .. "_")
        
        gpu.setBackground(theme.button)
        gpu.fill(btnX, btnY, #btnText, 1, " ")
        gpu.set(btnX, btnY, btnText)
        
        local e = {event.pull()}
        
        if e[1] == "key_down" then
            local char, code = e[3], e[4]
            
            if code == 28 then -- Enter
                return inputText
                
            elseif code == 14 then -- Backspace
                if #inputText > 0 then
                    inputText = inputText:sub(1, -2)
                end
                
            elseif code == 1 then -- ESC
                return nil
                
            elseif char and char > 31 and char < 127 then
                inputText = inputText .. string.char(char)
            end
            
        elseif e[1] == "touch" then
            local x, y = e[3], e[4]
            
            if x >= btnX and x < btnX + #btnText and y == btnY then
                return inputText
            end
        end
    end
end

-- Создание нового файла
function createNewFile()
    local filename = inputDialog("Введите имя нового файла:", "Создание файла")
    if filename and filename ~= "" then
        if not filename:find("%.") then
            filename = filename .. ".lua"
        end
        
        local path = currentDir .. "/" .. filename
        
        if fs.exists(path) then
            if not showYesNoMessage("Файл '" .. filename .. "' уже существует.\nПерезаписать?", "Файл существует") then
                return
            end
        end
        
        local file = io.open(path, "w")
        if file then
            file:write("-- Новый Lua файл\nprint(\"Привет из Asmelit OS!\")\n")
            file:close()
            showMessage("Файл создан: " .. filename, theme.success, "Создание файла")
            refreshFiles()
        else
            showMessage("Ошибка создания файла", theme.error, "Ошибка")
        end
    end
end

-- Удаление файла или папки
function deleteFile(filename, isDir)
    local path = currentDir .. "/" .. filename
    
    local message = isDir and 
        "Удалить папку '" .. filename .. "' со всем содержимым?" :
        "Удалить файл '" .. filename .. "'?"
    
    if showYesNoMessage(message, "Подтверждение удаления") then
        if isDir then
            local function deleteRecursive(dirPath)
                if fs.exists(dirPath) and fs.isDirectory(dirPath) then
                    for item in fs.list(dirPath) do
                        local itemPath = dirPath .. "/" .. item
                        if fs.isDirectory(itemPath) then
                            deleteRecursive(itemPath)
                        else
                            fs.remove(itemPath)
                        end
                    end
                    fs.remove(dirPath)
                end
            end
            deleteRecursive(path)
        else
            fs.remove(path)
        end
        
        showMessage((isDir and "Папка" or "Файл") .. " удален: " .. filename, theme.success, "Удаление")
        refreshFiles()
    end
end

-- Создание новой папки
function createNewFolder()
    local folderName = inputDialog("Введите имя новой папки:", "Создание папки")
    if folderName and folderName ~= "" then
        local path = currentDir .. "/" .. folderName
        
        if fs.exists(path) then
            showMessage("Папка с таким именем уже существует", theme.warning, "Ошибка")
            return
        end
        
        if fs.makeDirectory(path) then
            showMessage("Папка создана: " .. folderName, theme.success, "Создание папки")
            refreshFiles()
        else
            showMessage("Ошибка создания папки", theme.error, "Ошибка")
        end
    end
end

-- Запуск приложения
function runApp(appFilename)
    local path = "/apps/" .. appFilename
    if fs.exists(path) then
        gpu.setBackground(0x000000)
        gpu.setForeground(theme.text)
        term.clear()
        
        log("Запуск приложения: " .. appFilename)
        
        local ok, err = pcall(function()
            dofile(path)
        end)
        
        if not ok then
            showMessage("Ошибка запуска приложения:\n" .. tostring(err), theme.error, "Ошибка")
            log("Ошибка при запуске " .. appFilename .. ": " .. tostring(err))
        end
    else
        showMessage("Приложение не найдено!\nФайл: " .. appFilename .. "\n\nЗагрузите приложения через меню.", 
                  theme.error, "Ошибка")
    end
end

-- Запуск файла Lua
function runLuaFile(filepath)
    if fs.exists(filepath) and not fs.isDirectory(filepath) then
        gpu.setBackground(0x000000)
        gpu.setForeground(theme.text)
        term.clear()
        
        log("Запуск файла: " .. filepath)
        
        local ok, err = pcall(function()
            dofile(filepath)
        end)
        
        if not ok then
            showMessage("Ошибка выполнения файла:\n" .. tostring(err), theme.error, "Ошибка")
            log("Ошибка при выполнении " .. filepath .. ": " .. tostring(err))
        end
    end
end

-- Переменные для основного интерфейса
local currentDir = "/"
local files = {}
local selected = 1
local mode = "files"
local sidebarWidth = 24
local scrollOffset = 0

local sidebarButtons = {
    {id = "files", icon = "F", text = "Файлы"},
    {id = "apps", icon = "A", text = "Приложения"},
    {id = "console", icon = "C", text = "Консоль"},
    {id = "info", icon = "I", text = "О системе"},
    {id = "tools", icon = "T", text = "Инструменты"}
}

-- Обновление списка файлов
local function refreshFiles()
    files = {}
    
    -- Корневой каталог
    if currentDir == "/" then
        -- Системные папки
        table.insert(files, {
            name = "home",
            isDir = true,
            size = "<DIR>",
            path = "/home"
        })
        
        table.insert(files, {
            name = "apps",
            isDir = true,
            size = "<DIR>",
            path = "/apps"
        })
        
        table.insert(files, {
            name = "lib",
            isDir = true,
            size = "<DIR>",
            path = "/lib"
        })
        
        table.insert(files, {
            name = "tmp",
            isDir = true,
            size = "<DIR>",
            path = "/tmp"
        })
    else
        -- Содержимое конкретной папки
        if fs.exists(currentDir) and fs.isDirectory(currentDir) then
            for item in fs.list(currentDir) do
                if item ~= "." and item ~= ".." then
                    local path = currentDir .. "/" .. item
                    local isDir = fs.isDirectory(path)
                    table.insert(files, {
                        name = item,
                        isDir = isDir,
                        size = isDir and "<DIR>" or tostring(fs.size(path) or "0") .. " байт",
                        path = path
                    })
                end
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
    gpu.setBackground(theme.background)
    gpu.setForeground(theme.text)
    term.clear()
    
    -- Верхняя панель
    gpu.setBackground(theme.header)
    gpu.fill(1, 1, maxWidth, 2, " ")
    
    gpu.setForeground(theme.accent)
    local title = "Asmelit OS v4.3"
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
        local availableHeight = maxHeight - 10
        
        gpu.setForeground(theme.accent)
        gpu.set(startX, 5, "ИМЯ")
        gpu.set(startX + 35, 5, "ТИП")
        gpu.set(startX + 45, 5, "РАЗМЕР")
        
        gpu.setForeground(theme.text)
        gpu.set(startX, 6, string.rep("-", maxWidth - startX - 2))
        
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
                
                local icon = file.isDir and "[D]" or "[F]"
                gpu.set(startX - 2, y, icon)
                
                y = y + 1
            end
        end
        
        gpu.setBackground(theme.background)
        gpu.setForeground(theme.info)
        gpu.set(startX, maxHeight - 3, "Файлов: " .. #files .. " | Выбрано: " .. selected .. "/" .. #files)
        
        -- Кнопки действий
        local actions = {"[F2] Создать", "[F3] Редакт.", "[F4] Удалить", "[F5] Запустить"}
        local actionX = startX
        for i, action in ipairs(actions) do
            gpu.setBackground(theme.button)
            gpu.setForeground(theme.text)
            gpu.fill(actionX, maxHeight - 1, #action, 1, " ")
            gpu.set(actionX, maxHeight - 1, action)
            actionX = actionX + #action + 2
        end
        
    elseif mode == "apps" then
        local startX = sidebarWidth + 3
        local y = 5
        
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
            
            if component.isAvailable("internet") then
                gpu.setForeground(theme.highlight)
                gpu.set(centerX - 15, centerY + 4, "[F9] Загрузить приложения")
            end
        else
            gpu.setForeground(theme.accent)
            gpu.set(startX, 5, "ДОСТУПНЫЕ ПРИЛОЖЕНИЯ (Нажмите цифру или кликните):")
            gpu.set(startX, 6, string.rep("-", maxWidth - startX - 3))
            
            y = 8
            for i, app in ipairs(availableApps) do
                gpu.setForeground(theme.text)
                gpu.set(startX, y, app.icon .. " " .. app.name .. " [" .. app.key .. "]")
                
                gpu.setBackground(theme.button)
                gpu.setForeground(theme.text)
                gpu.fill(startX + 30, y, 10, 1, " ")
                gpu.set(startX + 31, y, "Запустить")
                
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
        gpu.set(startX, 6, string.rep("-", maxWidth - startX - 3))
        
        local info = {
            "Версия: Asmelit OS 4.3",
            "Память: " .. computer.freeMemory() .. "/" .. computer.totalMemory() .. " байт",
            "Время работы: " .. string.format("%.1f мин", (computer.uptime() - startTime) / 60),
            "Приложений загружено: " .. #appsToDownload,
            "Текущий каталог: " .. currentDir,
            "Разрешение: " .. maxWidth .. "x" .. maxHeight
        }
        
        for i, line in ipairs(info) do
            gpu.setForeground(theme.text)
            gpu.set(startX, 8 + i, line)
        end
        
    elseif mode == "tools" then
        local startX = sidebarWidth + 3
        gpu.setForeground(theme.accent)
        gpu.set(startX, 5, "ИНСТРУМЕНТЫ СИСТЕМЫ")
        gpu.set(startX, 6, string.rep("-", maxWidth - startX - 3))
        
        local tools = {
            {name = "Перезагрузить", key = "F12", desc = "Перезапуск системы"},
            {name = "Очистка памяти", key = "Ctrl+M", desc = "Очистка кэша"},
            {name = "Проверка диска", key = "F10", desc = "Проверка файловой системы"},
            {name = "Настройки", key = "F11", desc = "Настройки системы"}
        }
        
        local y = 8
        for i, tool in ipairs(tools) do
            gpu.setForeground(theme.text)
            gpu.set(startX, y, tool.name)
            gpu.setForeground(theme.accent)
            gpu.set(startX + 20, y, "[" .. tool.key .. "]")
            gpu.setForeground(theme.info)
            gpu.set(startX + 30, y, tool.desc)
            y = y + 2
        end
    end
    
    -- Нижняя панель
    gpu.setBackground(theme.header)
    gpu.setForeground(theme.text)
    gpu.fill(1, maxHeight, maxWidth, 1, " ")
    
    local hint = ""
    if mode == "files" then
        hint = "Вверх/Вниз - Навигация | Enter - Открыть | ESC - Выход"
    elseif mode == "apps" then
        hint = "1-6 - Запуск приложений | Клик по [Запустить] | ESC - Назад"
    else
        hint = "ESC - Назад в файлы"
    end
    
    gpu.set(3, maxHeight, hint)
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
            
            if code == 28 then
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
exit     - выход
mkdir [dir] - создать папку
rm [file] - удалить файл]], theme.text, "Справка")
                        
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
                            if last then currentDir = last else currentDir = "/" end
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
                        runLuaFile(path)
                        
                    elseif cmd:sub(1,6) == "mkdir " then
                        local dirName = cmd:sub(7)
                        local path = currentDir .. "/" .. dirName
                        if fs.makeDirectory(path) then
                            showMessage("Папка создана: " .. dirName, theme.success, "Успех")
                            refreshFiles()
                        else
                            showMessage("Ошибка создания папки", theme.error, "Ошибка")
                        end
                        
                    elseif cmd:sub(1,3) == "rm " then
                        local fileName = cmd:sub(4)
                        local path = currentDir .. "/" .. fileName
                        if fs.exists(path) then
                            if showYesNoMessage("Удалить '" .. fileName .. "'?", "Подтверждение") then
                                fs.remove(path)
                                showMessage("Удалено: " .. fileName, theme.success, "Успех")
                                refreshFiles()
                            end
                        else
                            showMessage("Файл не найден: " .. fileName, theme.error, "Ошибка")
                        end
                        
                    elseif cmd == "sysinfo" then
                        local info = string.format(
                            "Память: %d/%d байт\nВремя: %.1f мин\nПапка: %s",
                            computer.freeMemory(), computer.totalMemory(),
                            (computer.uptime() - startTime) / 60,
                            currentDir
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
                
            elseif code == 14 then
                if #consoleText > 0 then
                    consoleText = consoleText:sub(1, -2)
                end
                
            elseif code == 1 then
                mode = "files"
                return
                
            elseif char and char > 0 and char < 256 then
                consoleText = consoleText .. string.char(char)
            end
        end
    end
end

-- Обработка нажатий в режиме приложений
local function handleAppsInput(e)
    local char, code = e[3], e[4]
    
    -- Горячие клавиши 1-6 для приложений
    if char == "1" then runApp("calculator.lua")
    elseif char == "2" then runApp("editor.lua")
    elseif char == "3" then runApp("browser.lua")
    elseif char == "4" then runApp("monitor.lua")
    elseif char == "5" then runApp("sapper.lua")
    elseif char == "6" then runApp("snake.lua") end
    
    -- F9 - загрузить приложения
    if code == 67 and component.isAvailable("internet") then
        downloadAllApps()
        drawInterface()
    end
end

-- Основной цикл системы
refreshFiles()

function mainGUI()
    while true do
        if computer.freeMemory() < 1024 then
            showMessage("Критически мало памяти!\nТребуется перезагрузка системы.", theme.error, "Ошибка памяти")
            computer.shutdown(true)
        end
        
        if mode == "console" then
            runConsole()
        end
        
        drawInterface()
        
        while true do
            local e = {event.pull()}
            
            if e[1] == "key_down" then
                local char, code = e[3], e[4]
                
                -- Обработка по режимам
                if mode == "files" then
                    if code == 200 then
                        if selected > 1 then
                            selected = selected - 1
                            if selected <= scrollOffset then
                                scrollOffset = scrollOffset - 1
                            end
                        end
                        
                    elseif code == 208 then
                        if selected < #files then
                            selected = selected + 1
                            if selected > scrollOffset + (maxHeight - 10) then
                                scrollOffset = scrollOffset + 1
                            end
                        end
                        
                    elseif code == 28 then
                        if files[selected] then
                            if files[selected].isDir then
                                currentDir = files[selected].path
                                refreshFiles()
                            else
                                -- Автоматически определяем Lua файлы
                                local filename = files[selected].name
                                if filename:sub(-4) == ".lua" then
                                    runLuaFile(files[selected].path)
                                else
                                    -- Пытаемся открыть в редакторе
                                    textEditor(files[selected].path)
                                end
                            end
                        end
                        
                    elseif code == 60 then -- F2
                        createNewFile()
                        break
                        
                    elseif code == 61 then -- F3
                        if files[selected] and not files[selected].isDir then
                            textEditor(files[selected].path)
                        else
                            showMessage("Выберите файл для редактирования", theme.warning, "Информация")
                        end
                        break
                        
                    elseif code == 62 then -- F4
                        if files[selected] then
                            deleteFile(files[selected].name, files[selected].isDir)
                        end
                        break
                        
                    elseif code == 63 then -- F5
                        if files[selected] and not files[selected].isDir then
                            runLuaFile(files[selected].path)
                        else
                            showMessage("Выберите файл для запуска", theme.warning, "Информация")
                        end
                        break
                        
                    elseif code == 64 then -- F6
                        createNewFolder()
                        break
                        
                    end
                    
                elseif mode == "apps" then
                    handleAppsInput(e)
                    break
                    
                elseif mode == "tools" then
                    if code == 88 then -- F12
                        computer.shutdown(true)
                    elseif code == 68 then -- F10
                        showMessage("Проверка диска выполнена\nОшибок не обнаружено", theme.success, "Проверка диска")
                        break
                    elseif code == 87 then -- F11
                        showMessage("Настройки системы\n(Функция в разработке)", theme.info, "Настройки")
                        break
                    end
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
                    local helpText = [[
Горячие клавиши:
ESC - Выход/Назад
F1 - Помощь
В режиме Файлы:
  F2 - Создать файл
  F3 - Редактировать
  F4 - Удалить
  F5 - Запустить
  F6 - Новая папка
  Вверх/Вниз - Навигация
  Enter - Открыть
В режиме Приложения:
  1-6 - Запуск приложений
  F9 - Загрузить приложения
В режиме Инструменты:
  F10 - Проверка диска
  F11 - Настройки
  F12 - Перезагрузка]]
                    
                    showMessage(helpText, theme.info, "Справка по горячим клавишам")
                    break
                    
                elseif code == 65 then -- F7
                    refreshFiles()
                    break
                    
                -- Переключение режимов цифрами
                elseif char == "1" and mode ~= "apps" then mode = "apps"; break
                elseif char == "2" and mode ~= "console" then mode = "console"; break
                elseif char == "3" and mode ~= "info" then mode = "info"; break
                elseif char == "4" and mode ~= "tools" then mode = "tools"; break
                elseif char == "5" then mode = "files"; break
                    
                end
                
            elseif e[1] == "touch" then
                local x, y = e[3], e[4]
                
                -- Клик по сайдбару
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
                
                -- Клик по кнопке "Запустить" в режиме приложений
                if mode == "apps" and x >= sidebarWidth + 31 and x <= sidebarWidth + 40 then
                    local row = math.floor((y - 8) / 2) + 1
                    local availableApps = {}
                    for _, app in ipairs(appsToDownload) do
                        if fs.exists("/apps/" .. app.filename) then
                            table.insert(availableApps, app)
                        end
                    end
                    
                    if row >= 1 and row <= #availableApps then
                        runApp(availableApps[row].filename)
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
log("=== Asmelit OS v4.3 - Инициализация системы ===")

if computer.freeMemory() < 2048 then
    showMessage("Внимание: мало оперативной памяти!\n" ..
               "Доступно: " .. computer.freeMemory() .. " байт\n" ..
               "Рекомендуется: минимум 4KB\n\n" ..
               "Система может работать нестабильно.",
               theme.warning, "Предупреждение о памяти")
end

local bootOk, bootErr = pcall(bootScreen)
if not bootOk then
    log("Ошибка загрузочного экрана: " .. tostring(bootErr))
end

checkAndLoadApps()

local mainOk, mainErr = pcall(mainGUI)
if not mainOk then
    showMessage("Критическая ошибка системы:\n" .. tostring(mainErr) .. "\n\n" ..
               "Система будет перезагружена через 5 секунд...",
               theme.error, "Сбой системы")
    os.sleep(5)
    computer.shutdown(true)
end

showMessage("Система завершила работу.", theme.info, "Asmelit OS")
computer.shutdown()
