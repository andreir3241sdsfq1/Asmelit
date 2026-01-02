-- browser.lua - Браузер для Asmelit OS
local component = require("component")
local computer = require("computer")
local event = require("event")
local term = require("term")
local gpu = component.gpu

local w, h = gpu.getResolution()
local cx = math.floor(w / 2)
local cy = math.floor(h / 2)

local currentUrl = ""
local pageContent = ""
local history = {}
local historyIndex = 0

function drawBrowser()
    gpu.setBackground(0x001122)
    gpu.setForeground(0xFFFFFF)
    term.clear()
    
    -- Заголовок
    gpu.setBackground(0x003366)
    gpu.fill(1, 1, w, 1, " ")
    gpu.set(2, 1, "🌐 БРАУЗЕР")
    
    -- Строка URL
    gpu.setBackground(0x002244)
    gpu.fill(1, 3, w, 1, " ")
    gpu.setForeground(0xFFFF00)
    gpu.set(1, 3, "URL: " .. (currentUrl == "" and "Введите адрес" or currentUrl))
    
    -- Кнопки
    gpu.setForeground(0xFFFFFF)
    gpu.set(w - 30, 3, "[←] [→] [↻] [🏠]")
    
    -- Контент
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
    
    if pageContent == "" then
        gpu.set(cx - 20, cy - 3, "Добро пожаловать в браузер Asmelit OS!")
        gpu.set(cx - 25, cy - 1, "Введите URL в строке выше и нажмите Enter")
        gpu.set(cx - 15, cy + 1, "Пример: http://example.com")
        
        -- Быстрые ссылки
        gpu.setForeground(0x00AAFF)
        gpu.set(cx - 10, cy + 4, "Быстрые ссылки:")
        gpu.set(cx - 15, cy + 6, "1. http://example.com")
        gpu.set(cx - 15, cy + 7, "2. http://httpbin.org/get")
        gpu.set(cx - 15, cy + 8, "3. http://google.com")
    else
        -- Отображаем контент
        local lines = {}
        for line in pageContent:gmatch("[^\r\n]+") do
            if #line > w then
                while #line > w do
                    table.insert(lines, line:sub(1, w))
                    line = line:sub(w + 1)
                end
            end
            if #line > 0 then
                table.insert(lines, line)
            end
        end
        
        local startY = 5
        local maxLines = h - 6
        
        for i = 1, math.min(#lines, maxLines) do
            gpu.set(1, startY + i - 1, lines[i])
        end
    end
    
    -- Подсказка
    gpu.setBackground(0x003366)
    gpu.setForeground(0xFFFFFF)
    gpu.fill(1, h, w, 1, " ")
    gpu.set(2, h, "F1-Справка | ESC-Выход | Enter-Перейти | 1-3-Быстрые ссылки")
end

function fetchUrl(url)
    if not component.isAvailable("internet") then
        return "ОШИБКА: Нет интернет-карты"
    end
    
    local internet = require("internet")
    
    -- Добавляем протокол если нет
    if not url:find("^https?://") then
        url = "http://" .. url
    end
    
    showMessage("Загрузка: " .. url, 0xFFFF00, "Браузер")
    
    local handle = internet.request(url)
    if not handle then
        return "ОШИБКА: Не удалось подключиться"
    end
    
    local content = ""
    for chunk in handle do
        content = content .. chunk
        if #content > 100000 then -- Лимит 100KB
            break
        end
    end
    
    -- Добавляем в историю
    table.insert(history, currentUrl)
    historyIndex = #history
    
    currentUrl = url
    return content
end

function showMessage(text, color, title)
    gpu.setBackground(0x000000)
    gpu.setForeground(color)
    term.clear()
    
    gpu.set(cx - math.floor(#title/2), cy - 3, title)
    gpu.set(cx - math.floor(#text/2), cy, text)
    gpu.set(cx - 10, cy + 3, "[Нажмите любую клавишу]")
    
    event.pull("key_down")
    drawBrowser()
end

function main()
    drawBrowser()
    
    local inputUrl = ""
    
    while true do
        local e = {event.pull()}
        
        if e[1] == "key_down" then
            local char, code = e[3], e[4]
            
            if code == 1 then -- ESC
                break
                
            elseif code == 59 then -- F1
                showMessage("Управление:\nВведите URL и нажмите Enter\n←/→ - история\n↻ - обновить\n🏠 - домашняя страница\n1-3 - быстрые ссылки", 0xFFFFFF, "Справка")
                
            elseif code == 28 then -- Enter
                if inputUrl ~= "" then
                    pageContent = fetchUrl(inputUrl)
                    inputUrl = ""
                end
                drawBrowser()
                
            elseif code == 14 then -- Backspace
                if #inputUrl > 0 then
                    inputUrl = inputUrl:sub(1, -2)
                end
                
            elseif code == 203 then -- Left (история назад)
                if historyIndex > 1 then
                    historyIndex = historyIndex - 1
                    currentUrl = history[historyIndex]
                    pageContent = fetchUrl(currentUrl)
                end
                
            elseif code == 205 then -- Right (история вперед)
                if historyIndex < #history then
                    historyIndex = historyIndex + 1
                    currentUrl = history[historyIndex]
                    pageContent = fetchUrl(currentUrl)
                end
                
            elseif char == "1" then
                pageContent = fetchUrl("http://example.com")
                
            elseif char == "2" then
                pageContent = fetchUrl("http://httpbin.org/get")
                
            elseif char == "3" then
                pageContent = fetchUrl("http://google.com")
                
            elseif char >= 32 and char < 127 then
                inputUrl = inputUrl .. string.char(char)
                
                -- Показываем ввод
                gpu.setBackground(0x002244)
                gpu.setForeground(0xFFFF00)
                gpu.set(6, 3, inputUrl .. "_")
            end
        elseif e[1] == "touch" then
            local x, y = e[3], e[4]
            
            -- Кнопка назад
            if y == 3 and x >= w - 30 and x < w - 27 then
                if historyIndex > 1 then
                    historyIndex = historyIndex - 1
                    currentUrl = history[historyIndex]
                    pageContent = fetchUrl(currentUrl)
                    drawBrowser()
                end
                
            -- Кнопка вперед
            elseif y == 3 and x >= w - 27 and x < w - 24 then
                if historyIndex < #history then
                    historyIndex = historyIndex + 1
                    currentUrl = history[historyIndex]
                    pageContent = fetchUrl(currentUrl)
                    drawBrowser()
                end
                
            -- Кнопка обновить
            elseif y == 3 and x >= w - 24 and x < w - 21 then
                if currentUrl ~= "" then
                    pageContent = fetchUrl(currentUrl)
                    drawBrowser()
                end
                
            -- Кнопка домой
            elseif y == 3 and x >= w - 21 and x < w - 18 then
                currentUrl = ""
                pageContent = ""
                drawBrowser()
            end
        end
    end
end

main()
