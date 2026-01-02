-- =====================================================
-- Asmelit OS Installer v2.6
-- Полная очистка диска и установка
-- =====================================================

local component = require("component")
local computer = require("computer")
local term = require("term")
local gpu = component.gpu
local event = require("event")

-- Настройки
local maxWidth, maxHeight = gpu.getResolution()
local centerX = math.floor(maxWidth / 2)
local centerY = math.floor(maxHeight / 2)

-- URLs для загрузки
local GITHUB_BASE = "https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/refs/heads/main/"
local FILES_TO_DOWNLOAD = {
    {url = "os.lua", path = "/os.lua"},
    {url = "run.lua", path = "/run.lua", required = true},
    {url = "logo.lua", path = "/logo.lua"},
    {url = "bootloader.lua", path = "/bootloader.lua"},
    {url = "installer.lua", path = "/installer_new.lua"}
}

-- ФУНКЦИЯ: ПОЛНАЯ очистка диска (ВСЁ удаляем!)
local function cleanDisk()
    local fs = require("filesystem")
    
    print("ПОЛНАЯ ОЧИСТКА ДИСКА...")
    
    -- УДАЛЯЕМ ВСЁ в корне и /home
    local function deleteEverything(dir)
        if not fs.exists(dir) then return end
        
        -- Сначала удаляем все файлы и подпапки
        for item in fs.list(dir) do
            local path = dir .. "/" .. item
            if fs.isDirectory(path) then
                deleteEverything(path) -- Рекурсивно удаляем подпапки
            end
            
            -- НЕ удаляем текущий installer.lua
            if not (dir == "/" and item == "installer.lua") and
               not (dir == "/" and item == "installer_new.lua") then
                pcall(fs.remove, path)
                print("Удалено: " .. path)
            end
        end
    end
    
    -- Очищаем корень и /home
    deleteEverything("/")
    if fs.exists("/home") then
        deleteEverything("/home")
    end
    
    -- Создаём чистую структуру
    local dirs = {"/home", "/tmp", "/bin", "/lib"}
    for _, dir in ipairs(dirs) do
        if not fs.exists(dir) then
            fs.makeDirectory(dir)
        end
    end
    
    print("✓ ДИСК ПОЛНОСТЬЮ ОЧИЩЕН!")
    os.sleep(1)
end

-- ФУНКЦИЯ: Загрузка файла с GitHub
local function downloadFile(url, path)
    if not component.isAvailable("internet") then
        return false, "Нет интернет-карты"
    end
    
    local internet = require("internet")
    local fs = require("filesystem")
    
    -- Создаем директорию если нужно
    local dir = path:match("(.+)/[^/]+$")
    if dir and not fs.exists(dir) then
        fs.makeDirectory(dir)
    end
    
    local ok, handle = pcall(internet.request, GITHUB_BASE .. url)
    if not ok or not handle then
        return false, "Не удалось подключиться"
    end
    
    local content = ""
    for chunk in handle do
        content = content .. chunk
        if #content > 100000 then
            return false, "Файл слишком большой"
        end
    end
    
    local file = io.open(path, "w")
    if not file then
        return false, "Не могу создать файл"
    end
    
    file:write(content)
    file:close()
    
    return true, #content
end

-- ФУНКЦИЯ: Установка run.lua (ОБЯЗАТЕЛЬНО!)
local function installRunLua()
    local fs = require("filesystem") -- <-- ИСПРАВЛЕНО: добавлен fs здесь
    
    if not component.isAvailable("internet") then
        return false, "Нет интернет-карты для загрузки run.lua"
    end
    
    print("Устанавливаю run.lua...")
    
    local ok, result = downloadFile("run.lua", "/run.lua")
    if not ok then
        return false, "Ошибка загрузки run.lua: " .. tostring(result)
    end
    
    -- Также копируем в /home для совместимости
    if fs.exists("/run.lua") then
        local file = io.open("/run.lua", "r")
        if file then
            local content = file:read("*a")
            file:close()
            
            local homeFile = io.open("/home/run.lua", "w")
            if homeFile then
                homeFile:write(content)
                homeFile:close()
                print("✓ run.lua скопирован в /home")
            end
        end
    end
    
    return true, "run.lua установлен"
end

-- Отрисовка анимации установки
local function drawInstallAnimation(frame, progress, status)
    gpu.setBackground(0x000033)
    gpu.setForeground(0xFFFFFF)
    term.clear()
    
    local title = "УСТАНОВКА ASMELIT OS v2.6"
    gpu.set(centerX - math.floor(#title / 2), 2, title)
    
    local animFrames = {"▌", "██", "██▌", "████", "████▌", "██████", "██████▌", "████████", "████████▌", "██████████"}
    local frameIdx = ((frame - 1) % #animFrames) + 1
    local anim = animFrames[frameIdx]
    gpu.setForeground(0x00FF00)
    gpu.set(centerX - math.floor(#anim / 2), centerY - 2, anim)
    
    gpu.setForeground(0xFFFFFF)
    gpu.set(centerX - math.floor(#status / 2), centerY, status)
    
    local barWidth = math.floor(maxWidth * 0.6)
    local barX = centerX - math.floor(barWidth / 2)
    local barY = centerY + 3
    
    gpu.setBackground(0x333333)
    gpu.fill(barX, barY, barWidth, 1, "░")
    
    local filled = math.floor(barWidth * progress)
    if filled > 0 then
        gpu.setBackground(0x00FF00)
        gpu.fill(barX, barY, filled, 1, "█")
    end
    
    local percent = math.floor(progress * 100)
    local percentText = percent .. "%"
    gpu.setBackground(0x000033)
    gpu.setForeground(0x00FF00)
    gpu.set(centerX - math.floor(#percentText / 2), barY + 1, percentText)
    
    local help = "ESC - Отмена установки"
    gpu.setForeground(0xAAAAAA)
    gpu.set(centerX - math.floor(#help / 2), maxHeight - 2, help)
end

-- Главное меню
local function mainMenu()
    local selected = 1
    local menuItems = {
        {text = "ПОЛНАЯ УСТАНОВКА (очистка + всё)", action = "install_full"},
        {text = "ТОЛЬКО ОЧИСТИТЬ ДИСК (ВСЁ удалить!)", action = "clean_only"},
        {text = "ТОЛЬКО run.lua (после прошивки BIOS!)", action = "install_run"},
        {text = "Выход в оболочку", action = "shell"}
    }
    
    while true do
        gpu.setBackground(0x000033)
        gpu.setForeground(0xFFFFFF)
        term.clear()
        
        local title = "ASMELIT OS INSTALLER v2.6"
        gpu.set(centerX - math.floor(#title / 2), 3, title)
        gpu.set(centerX - 25, 5, "УДАЛЯЕТ ВСЁ НА ДИСКЕ! Будьте осторожны!")
        
        local subtitle = "Выберите действие:"
        gpu.set(centerX - math.floor(#subtitle / 2), 7, subtitle)
        
        local startY = centerY - 2
        for i, item in ipairs(menuItems) do
            local x = centerX - 20
            local y = startY + i
            
            if i == selected then
                gpu.setBackground(0x00AA00)
                gpu.setForeground(0x000000)
                gpu.fill(x, y, 40, 1, " ")
                local prefix = "▶ "
                if item.action == "install_run" then
                    prefix = "⚠ "
                elseif item.action == "clean_only" then
                    prefix = "☢ "
                end
                gpu.set(x, y, prefix .. item.text)
            else
                gpu.setBackground(0x000033)
                if item.action == "install_run" then
                    gpu.setForeground(0xFFFF00)
                elseif item.action == "clean_only" then
                    gpu.setForeground(0xFF6666)
                else
                    gpu.setForeground(0xFFFFFF)
                end
                gpu.set(x, y, "  " .. item.text)
            end
        end
        
        gpu.setForeground(0xAAAAAA)
        local mem = "Память: " .. computer.freeMemory() .. " байт"
        gpu.set(centerX - math.floor(#mem / 2), maxHeight - 5, mem)
        
        local help = "↑↓ - Выбор | Enter - Подтвердить | ESC - Выход"
        gpu.set(centerX - math.floor(#help / 2), maxHeight - 2, help)
        
        local eventType, _, char, code = event.pull()
        
        if eventType == "key_down" then
            if code == 200 then
                selected = selected > 1 and selected - 1 or #menuItems
            elseif code == 208 then
                selected = selected < #menuItems and selected + 1 or 1
            elseif code == 28 then
                local action = menuItems[selected].action
                
                if action == "install_full" then
                    if not component.isAvailable("internet") then
                        gpu.setBackground(0x000033)
                        gpu.setForeground(0xFF0000)
                        term.clear()
                        gpu.set(centerX - 15, centerY, "ОШИБКА: Нет интернет-карты!")
                        os.sleep(3)
                        return
                    end
                    
                    -- 1. ПОЛНАЯ очистка
                    cleanDisk()
                    
                    -- 2. run.lua
                    local runOk, runMsg = installRunLua()
                    if not runOk then
                        gpu.setBackground(0x000033)
                        gpu.setForeground(0xFF0000)
                        term.clear()
                        gpu.set(centerX - 15, centerY, "ОШИБКА: " .. runMsg)
                        os.sleep(3)
                        return
                    end
                    
                    -- 3. Остальные файлы
                    local frame = 1
                    local totalFiles = #FILES_TO_DOWNLOAD
                    
                    for i, fileInfo in ipairs(FILES_TO_DOWNLOAD) do
                        local progress = i / totalFiles
                        local status = "Загрузка " .. fileInfo.url .. "..."
                        
                        drawInstallAnimation(frame, progress, status)
                        frame = frame + 1
                        
                        local cancel = false
                        for j = 1, 10 do
                            local e = {event.pull(0.05)}
                            if e[1] == "key_down" and e[4] == 1 then
                                cancel = true
                                break
                            end
                        end
                        
                        if cancel then
                            gpu.set(centerX - 10, centerY + 5, "Установка отменена")
                            os.sleep(2)
                            return
                        end
                        
                        local ok, result = downloadFile(fileInfo.url, fileInfo.path)
                        if not ok then
                            gpu.setBackground(0x000033)
                            gpu.setForeground(0xFF0000)
                            gpu.set(centerX - 15, centerY + 5, "Ошибка: " .. tostring(result))
                            os.sleep(3)
                            return
                        end
                    end
                    
                    -- Создаём startup.lua
                    local startupCode = [[-- Asmelit OS Startup
local fs = require("filesystem")

if fs.exists("/run.lua") then
    dofile("/run.lua")
elseif fs.exists("/home/run.lua") then
    dofile("/home/run.lua")
else
    print("ERROR: No run.lua!")
    require("shell").execute()
end]]
                    
                    local startupFile = io.open("/home/startup.lua", "w")
                    if startupFile then
                        startupFile:write(startupCode)
                        startupFile:close()
                    end
                    
                    drawInstallAnimation(frame, 1, "Установка завершена!")
                    
                    gpu.setForeground(0x00FF00)
                    gpu.set(centerX - 25, centerY + 5, "Asmelit OS успешно установлена!")
                    gpu.set(centerX - 20, centerY + 6, "Диск очищен, run.lua установлен")
                    gpu.set(centerX - 15, centerY + 7, "Перезагрузите компьютер")
                    
                    os.sleep(5)
                    computer.shutdown(true)
                    
                elseif action == "clean_only" then
                    -- Подтверждение
                    gpu.setBackground(0x000033)
                    gpu.setForeground(0xFF0000)
                    term.clear()
                    gpu.set(centerX - 20, centerY - 2, "⚠ ВНИМАНИЕ! ⚠")
                    gpu.set(centerX - 25, centerY, "УДАЛИТ ВСЕ ФАЙЛЫ НА ДИСКЕ!")
                    gpu.set(centerX - 15, centerY + 2, "ВСЁ будет удалено.")
                    gpu.set(centerX - 20, centerY + 4, "Продолжить? (yes/NO)")
                    
                    local answer = io.read()
                    if answer:lower() ~= "yes" then
                        print("Отменено.")
                        os.sleep(1)
                        return
                    end
                    
                    cleanDisk()
                    gpu.setBackground(0x000033)
                    gpu.setForeground(0x00FF00)
                    term.clear()
                    gpu.set(centerX - 10, centerY, "Диск очищен!")
                    os.sleep(2)
                    
                elseif action == "install_run" then
                    if not component.isAvailable("internet") then
                        gpu.setBackground(0x000033)
                        gpu.setForeground(0xFF0000)
                        term.clear()
                        gpu.set(centerX - 15, centerY, "ОШИБКА: Нет интернет-карты!")
                        os.sleep(3)
                        return
                    end
                    
                    gpu.setBackground(0x000033)
                    gpu.setForeground(0xFFFFFF)
                    term.clear()
                    gpu.set(centerX - 20, centerY, "Установка run.lua...")
                    
                    local ok, msg = installRunLua()
                    if ok then
                        gpu.setForeground(0x00FF00)
                        gpu.set(centerX - 15, centerY + 2, "✓ run.lua установлен!")
                        gpu.set(centerX - 30, centerY + 3, "Теперь BIOS сможет запустить систему")
                    else
                        gpu.setForeground(0xFF0000)
                        gpu.set(centerX - 15, centerY + 2, "✗ Ошибка: " .. msg)
                    end
                    
                    gpu.set(centerX - 15, centerY + 5, "Нажмите любую клавишу...")
                    event.pull("key_down")
                    
                elseif action == "shell" then
                    require("shell").execute()
                end
                
            elseif code == 1 then
                return
            end
        end
    end
end

print("Asmelit OS Installer v2.6 запущен...")
os.sleep(1)
mainMenu()
