-- editor.lua - Текстовый редактор для Asmelit OS
local component = require("component")
local computer = require("computer")
local event = require("event")
local term = require("term")
local gpu = component.gpu
local fs = require("filesystem")

local w, h = gpu.getResolution()
local cx = math.floor(w / 2)
local cy = math.floor(h / 2)

local lines = {""}
local currentLine = 1
local cursorPos = 1
local filename = ""
local modified = false
local scroll = 0

function drawEditor()
    gpu.setBackground(0x001122)
    gpu.setForeground(0xFFFFFF)
    term.clear()
    
    -- Заголовок
    gpu.setBackground(0x003366)
    gpu.fill(1, 1, w, 1, " ")
    local title = "📝 РЕДАКТОР"
    if filename ~= "" then
        title = title .. " - " .. filename .. (modified and " *" or "")
    else
        title = title .. " - Новый файл" .. (modified and " *" or "")
    end
    gpu.set(2, 1, title)
    
    -- Статус
    local status = "Строка: " .. currentLine .. " | Позиция: " .. cursorPos .. " | Всего строк: " .. #lines
    gpu.set(w - #status - 1, 1, status)
    
    -- Область текста
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
    
    local startY = 3
    local visibleLines = h - 5
    
    for i = 1, visibleLines do
        local lineIdx = i + scroll
        if lineIdx <= #lines then
            gpu.set(1, startY + i - 1, string.format("%3d", lineIdx) .. " │ " .. lines[lineIdx])
        else
            gpu.set(1, startY + i - 1, string.format("%3d", lineIdx) .. " │ ")
        end
    end
    
    -- Курсор
    local cursorY = startY + (currentLine - scroll) - 1
    if cursorY >= startY and cursorY < startY + visibleLines then
        gpu.set(7 + cursorPos, cursorY, "_")
    end
    
    -- Подсказка внизу
    gpu.setBackground(0x003366)
    gpu.setForeground(0xFFFFFF)
    gpu.fill(1, h, w, 1, " ")
    gpu.set(2, h, "F1-Справка | F2-Сохранить | F3-Загрузить | F5-Новый | ESC-Выход")
end

function insertChar(char)
    if char == 8 then -- Backspace
        if cursorPos > 1 then
            lines[currentLine] = lines[currentLine]:sub(1, cursorPos-2) .. lines[currentLine]:sub(cursorPos)
            cursorPos = cursorPos - 1
        elseif currentLine > 1 then
            cursorPos = #lines[currentLine-1] + 1
            lines[currentLine-1] = lines[currentLine-1] .. lines[currentLine]
            table.remove(lines, currentLine)
            currentLine = currentLine - 1
        end
    elseif char == 13 then -- Enter
        local before = lines[currentLine]:sub(1, cursorPos-1)
        local after = lines[currentLine]:sub(cursorPos)
        lines[currentLine] = before
        table.insert(lines, currentLine + 1, after)
        currentLine = currentLine + 1
        cursorPos = 1
    elseif char >= 32 and char < 127 then -- Печатные символы
        lines[currentLine] = lines[currentLine]:sub(1, cursorPos-1) .. string.char(char) .. lines[currentLine]:sub(cursorPos)
        cursorPos = cursorPos + 1
    end
    modified = true
end

function saveFile()
    if filename == "" then
        showMessage("Введите имя файла:", 0xFFFFFF, "Сохранение")
        local input = readInput()
        if input and input ~= "" then
            filename = input
        else
            return
        end
    end
    
    local file = io.open(filename, "w")
    if file then
        for i, line in ipairs(lines) do
            file:write(line)
            if i < #lines then
                file:write("\n")
            end
        end
        file:close()
        modified = false
        showMessage("Файл сохранен: " .. filename, 0x00FF00, "Успех")
    else
        showMessage("Ошибка сохранения файла", 0xFF0000, "Ошибка")
    end
end

function loadFile()
    showMessage("Введите имя файла:", 0xFFFFFF, "Загрузка")
    local input = readInput()
    if input and input ~= "" then
        if fs.exists(input) then
            local file = io.open(input, "r")
            if file then
                lines = {}
                for line in file:lines() do
                    table.insert(lines, line)
                end
                file:close()
                filename = input
                currentLine = 1
                cursorPos = 1
                scroll = 0
                modified = false
                showMessage("Файл загружен: " .. filename, 0x00FF00, "Успех")
            else
                showMessage("Ошибка чтения файла", 0xFF0000, "Ошибка")
            end
        else
            showMessage("Файл не найден: " .. input, 0xFF0000, "Ошибка")
        end
    end
end

function showMessage(text, color, title)
    gpu.setBackground(0x000000)
    gpu.setForeground(color)
    term.clear()
    
    gpu.set(cx - math.floor(#title/2), cy - 3, title)
    gpu.set(cx - math.floor(#text/2), cy, text)
    gpu.set(cx - 10, cy + 3, "[Нажмите любую клавишу]")
    
    event.pull("key_down")
    drawEditor()
end

function readInput()
    local input = ""
    while true do
        local e = {event.pull()}
        if e[1] == "key_down" then
            local char, code = e[3], e[4]
            if code == 28 then -- Enter
                break
            elseif code == 14 then -- Backspace
                if #input > 0 then
                    input = input:sub(1, -2)
                end
            elseif char >= 32 and char < 127 then
                input = input .. string.char(char)
            elseif code == 1 then -- ESC
                return nil
            end
            
            -- Показываем ввод
            gpu.setBackground(0x000000)
            gpu.setForeground(0xFFFFFF)
            term.clear()
            gpu.set(cx - 10, cy - 1, "Введите имя файла:")
            gpu.set(cx - 10, cy, "> " .. input .. "_")
        end
    end
    return input
end

function main()
    drawEditor()
    
    while true do
        local e = {event.pull()}
        
        if e[1] == "key_down" then
            local char, code = e[3], e[4]
            
            if code == 1 then -- ESC
                if modified then
                    showMessage("Сохранить изменения перед выходом? (y/n)", 0xFFFF00, "Выход")
                    local choice = readInput()
                    if choice and choice:lower() == "y" then
                        saveFile()
                    end
                end
                break
                
            elseif code == 59 then -- F1
                showMessage("Управление:\nСтрелки - навигация\nEnter - новая строка\nBackspace - удалить\nF2 - сохранить\nF3 - загрузить\nF5 - новый файл", 0xFFFFFF, "Справка")
                
            elseif code == 60 then -- F2
                saveFile()
                
            elseif code == 61 then -- F3
                loadFile()
                
            elseif code == 63 then -- F5
                if modified then
                    showMessage("Сохранить текущий файл? (y/n)", 0xFFFF00, "Новый файл")
                    local choice = readInput()
                    if choice and choice:lower() == "y" then
                        saveFile()
                    end
                end
                lines = {""}
                filename = ""
                currentLine = 1
                cursorPos = 1
                scroll = 0
                modified = false
                drawEditor()
                
            elseif code == 200 then -- Up
                if currentLine > 1 then
                    currentLine = currentLine - 1
                    cursorPos = math.min(cursorPos, #lines[currentLine] + 1)
                    if currentLine <= scroll then
                        scroll = scroll - 1
                    end
                end
                
            elseif code == 208 then -- Down
                if currentLine < #lines then
                    currentLine = currentLine + 1
                    cursorPos = math.min(cursorPos, #lines[currentLine] + 1)
                    if currentLine > scroll + (h - 5) then
                        scroll = scroll + 1
                    end
                end
                
            elseif code == 203 then -- Left
                if cursorPos > 1 then
                    cursorPos = cursorPos - 1
                elseif currentLine > 1 then
                    currentLine = currentLine - 1
                    cursorPos = #lines[currentLine] + 1
                end
                
            elseif code == 205 then -- Right
                if cursorPos <= #lines[currentLine] then
                    cursorPos = cursorPos + 1
                elseif currentLine < #lines then
                    currentLine = currentLine + 1
                    cursorPos = 1
                end
                
            else
                insertChar(char)
            end
            
            drawEditor()
        end
    end
end

main()
