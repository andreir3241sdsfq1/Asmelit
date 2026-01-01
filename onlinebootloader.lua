-- =====================================================
-- Asmelit Internet Bootloader v3.0
-- Загружает и устанавливает ОС с GitHub
-- =====================================================

local component = require("component")
local computer = require("computer")
local term = require("term")
local gpu = component.gpu
local event = require("event")

-- Настройки
local GITHUB_USER = "andreir3241sdsfq1"
local GITHUB_REPO = "Asmelit"
local GITHUB_BRANCH = "main"
local GITHUB_BASE = "https://raw.githubusercontent.com/" .. GITHUB_USER .. "/" .. GITHUB_REPO .. "/" .. GITHUB_BRANCH .. "/"

-- Проверка интернета
local internet = nil
if component.isAvailable("internet") then
    local ok, internetLib = pcall(require, "internet")
    if ok then
        internet = internetLib
    end
end

-- Отображение лого
function showLogo()
    gpu.setBackground(0x000000)
    gpu.setForeground(0x00FF00)
    term.clear()
    
    local logo = [[
╔══════════════════════════════╗
║  █████╗ ███████╗███╗   ███╗  ║
║ ██╔══██╗██╔════╝████╗ ████║  ║
║ ███████║███████╗██╔████╔██║  ║
║ ██╔══██║╚════██║██║╚██╔╝██║  ║
║ ██║  ██║███████║██║ ╚═╝ ██║  ║
║ ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝  ║
║   Internet Bootloader v3.0   ║
╚══════════════════════════════╝
    ]]
    
    local lines = {}
    for line in logo:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    
    local maxWidth, maxHeight = gpu.getResolution()
    local centerX = math.floor(maxWidth / 2)
    local centerY = math.floor(maxHeight / 2)
    
    for i, line in ipairs(lines) do
        local x = centerX - math.floor(#line / 2)
        local y = centerY - math.floor(#lines / 2) + i
        gpu.set(x, y, line)
    end
    
    return lines
end

-- Загрузка файла с GitHub
function downloadFile(filename)
    if not internet then
        return nil, "Нет интернет-карты"
    end
    
    local url = GITHUB_BASE .. filename
    local ok, handle = pcall(internet.request, url)
    
    if not ok or not handle then
        return nil, "Не удалось подключиться"
    end
    
    local content = ""
    for chunk in handle do
        content = content .. chunk
        -- Защита от больших файлов
        if #content > 500000 then -- 500KB лимит
            return nil, "Файл слишком большой"
        end
    end
    
    return content
end

-- Меню выбора
function showMenu()
    local maxWidth, maxHeight = gpu.getResolution()
    local centerX = math.floor(maxWidth / 2)
    local selected = 1
    
    local menuItems = {
        {text = "Установить Asmelit OS (с интернета)", action = "install"},
        {text = "Запустить ОС (если установлена)", action = "boot"},
        {text = "Запустить установщик", action = "installer"},
        {text = "Обновить систему", action = "update"},
        {text = "Запустить стандартную оболочку", action = "shell"},
        {text = "Перезагрузить", action = "reboot"}
    }
    
    while true do
        gpu.setBackground(0x000033)
        gpu.setForeground(0xFFFFFF)
        term.clear()
        
        -- Заголовок
        local title = "ASMELIT INTERNET BOOTLOADER"
        gpu.set(centerX - math.floor(#title / 2), 3, title)
        
        local subtitle = "Выберите действие:"
        gpu.set(centerX - math.floor(#subtitle / 2), 5, subtitle)
        
        -- Меню
        local startY = 8
        for i, item in ipairs(menuItems) do
            local y = startY + i * 2
            
            if i == selected then
                gpu.setBackground(0x00AA00)
                gpu.setForeground(0x000000)
            else
                gpu.setBackground(0x000033)
                gpu.setForeground(0xFFFFFF)
            end
            
            gpu.fill(centerX - 20, y, 40, 1, " ")
            local text = (i == selected and "▶ " or "  ") .. item.text
            gpu.set(centerX - 18, y, text)
        end
        
        -- Статус
        local status = internet and "✓ Интернет доступен" or "✗ Нет интернета"
        gpu.setBackground(0x000033)
        gpu.setForeground(internet and 0x00FF00 or 0xFF0000)
        gpu.set(centerX - math.floor(#status / 2), maxHeight - 5, status)
        
        local memStatus = "Память: " .. math.floor(computer.freeMemory() / 1024) .. "K"
        gpu.setForeground(0xAAAAAA)
        gpu.set(centerX - math.floor(#memStatus / 2), maxHeight - 4, memStatus)
        
        -- Подсказка
        local help = "↑↓ - Выбор | Enter - Подтвердить | ESC - Выход"
        gpu.set(centerX - math.floor(#help / 2), maxHeight - 2, help)
        
        -- Обработка ввода
        local eventType, _, char, code = event.pull()
        
        if eventType == "key_down" then
            if code == 200 then -- Up
                selected = selected > 1 and selected - 1 or #menuItems
            elseif code == 208 then -- Down
                selected = selected < #menuItems and selected + 1 or 1
            elseif code == 28 then -- Enter
                local action = menuItems[selected].action
                return action
            elseif code == 1 then -- ESC
                return "shell"
            end
        end
    end
end

-- Процесс установки
function installProcess()
    local maxWidth, maxHeight = gpu.getResolution()
    local centerX = math.floor(maxWidth / 2)
    
    gpu.setBackground(0x000033)
    gpu.setForeground(0xFFFFFF)
    term.clear()
    
    local title = "УСТАНОВКА ASMELIT OS"
    gpu.set(centerX - math.floor(#title / 2), 3, title)
    
    -- Список файлов для загрузки
    local files = {
        "os.lua",
        "logo.lua",
        "installer.lua",
        "bootloader.lua"
    }
    
    local y = 6
    for i, filename in ipairs(files) do
        gpu.set(centerX - 25, y, "Загрузка " .. filename .. "...")
        
        local content, err = downloadFile(filename)
        if content then
            -- Сохраняем файл
            local fs = require("filesystem")
            local path = "/home/" .. filename
            
            if filename == "os.lua" then
                path = "/home/startup.lua" -- Главный файл ОС
            end
            
            local file = io.open(path, "w")
            if file then
                file:write(content)
                file:close()
                
                gpu.setForeground(0x00FF00)
                gpu.set(centerX + 10, y, "✓ Успешно")
                gpu.setForeground(0xFFFFFF)
            else
                gpu.setForeground(0xFF0000)
                gpu.set(centerX + 10, y, "✗ Ошибка записи")
                gpu.setForeground(0xFFFFFF)
            end
        else
            gpu.setForeground(0xFF0000)
            gpu.set(centerX + 10, y, "✗ " .. (err or "Ошибка"))
            gpu.setForeground(0xFFFFFF)
        end
        
        y = y + 2
        
        -- Проверка отмены
        for j = 1, 5 do
            local e = {event.pull(0.1)}
            if e[1] == "key_down" and e[4] == 1 then -- ESC
                return false
            end
        end
    end
    
    -- Создаем структуру папок
    local fs = require("filesystem")
    local dirs = {"/home/user", "/home/apps", "/bin", "/lib", "/tmp"}
    for _, dir in ipairs(dirs) do
        if not fs.exists(dir) then
            fs.makeDirectory(dir)
        end
    end
    
    gpu.setForeground(0x00FF00)
    gpu.set(centerX - 15, y + 2, "Установка завершена успешно!")
    gpu.setForeground(0xFFFFFF)
    gpu.set(centerX - 10, y + 3, "Нажмите любую клавишу...")
    
    event.pull("key_down")
    return true
end

-- Запуск ОС
function bootOS()
    local fs = require("filesystem")
    
    if fs.exists("/home/startup.lua") then
        local file = io.open("/home/startup.lua", "r")
        if file then
            local osCode = file:read("*a")
            file:close()
            
            local func, err = load(osCode, "=AsmelitOS")
            if func then
                return pcall(func)
            else
                return false, "Ошибка загрузки: " .. tostring(err)
            end
        end
    end
    
    return false, "ОС не установлена"
end

-- Запуск установщика
function runInstaller()
    local fs = require("filesystem")
    
    if fs.exists("/home/installer.lua") then
        local file = io.open("/home/installer.lua", "r")
        if file then
            local code = file:read("*a")
            file:close()
            
            local func, err = load(code, "=Installer")
            if func then
                return pcall(func)
            end
        end
    end
    
    -- Если нет установщика, пробуем скачать
    if internet then
        local content, err = downloadFile("installer.lua")
        if content then
            local func, err = load(content, "=Installer")
            if func then
                return pcall(func)
            end
        end
    end
    
    return false, "Не могу запустить установщик"
end

-- Главная функция
function main()
    showLogo()
    os.sleep(1)
    
    while true do
        local action = showMenu()
        
        if action == "install" then
            if not internet then
                gpu.setBackground(0x000033)
                gpu.setForeground(0xFF0000)
                term.clear()
                gpu.set(centerX - 15, centerY, "ОШИБКА: Нет интернет-соединения!")
                os.sleep(3)
            else
                installProcess()
            end
            
        elseif action == "boot" then
            local ok, err = bootOS()
            if not ok then
                gpu.setBackground(0x000033)
                gpu.setForeground(0xFF0000)
                term.clear()
                gpu.set(centerX - 15, centerY, "ОШИБКА: " .. tostring(err))
                os.sleep(3)
            end
            
        elseif action == "installer" then
            local ok, err = runInstaller()
            if not ok then
                gpu.setBackground(0x000033)
                gpu.setForeground(0xFF0000)
                term.clear()
                gpu.set(centerX - 15, centerY, "ОШИБКА: " .. tostring(err))
                os.sleep(3)
            end
            
        elseif action == "update" then
            if not internet then
                gpu.setBackground(0x000033)
                gpu.setForeground(0xFF0000)
                term.clear()
                gpu.set(centerX - 15, centerY, "ОШИБКА: Нет интернета для обновления!")
                os.sleep(3)
            else
                installProcess() -- Тот же процесс что и установка
            end
            
        elseif action == "shell" then
            require("shell").execute()
            
        elseif action == "reboot" then
            computer.shutdown(true)
        end
    end
end

-- Запуск с обработкой ошибок
local ok, err = pcall(main)
if not ok then
    gpu.setBackground(0xFF0000)
    gpu.setForeground(0xFFFFFF)
    term.clear()
    gpu.set(1, 1, "КРИТИЧЕСКАЯ ОШИБКА БУТЛОАДЕРА:")
    gpu.set(1, 3, tostring(err))
    gpu.set(1, 5, "Переход к оболочке через 5 сек...")
    os.sleep(5)
    require("shell").execute()
end
