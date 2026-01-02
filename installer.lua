-- =====================================================
-- Asmelit OS Installer v2.5
-- Устанавливает систему на диск с очисткой
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
    {url = "os.lua", path = "/home/os.lua"},
    {url = "run.lua", path = "/home/run.lua", required = true}, -- <-- ОБЯЗАТЕЛЬНО ДЛЯ ЗАПУСКА СИСТЕМЫ ПОСЛЕ ПРОШИВКИ БИОС
    {url = "logo.lua", path = "/home/logo.lua"},
    {url = "bootloader.lua", path = "/home/bootloader.lua"},
    {url = "installer.lua", path = "/home/installer_new.lua"} -- Сохраняем новый инсталлер
}

-- ФУНКЦИЯ: Очистка всего диска (кроме installer.lua)
local function cleanDisk()
    local fs = require("filesystem")
    
    print("Начинаю очистку диска...")
    
    -- Список файлов/папок для удаления
    local toDelete = {
        "/home/startup.lua",
        "/home/startup",
        "/home/os.lua",
        "/home/run.lua",
        "/home/logo.lua",
        "/home/bootloader.lua",
        "/home/user",
        "/home/apps",
        "/home/docs",
        "/home/system",
        "/bootloader.lua",
        "/startup.lua",
        "/os.lua"
    }
    
    -- Функция безопасного удаления
    local function safeRemove(path)
        if fs.exists(path) then
            local ok, err = pcall(fs.remove, path)
            if ok then
                print("✓ Удалено: " .. path)
                return true
            else
                print("✗ Ошибка: " .. path .. " - " .. tostring(err))
                return false
            end
        end
        return true
    end
    
    -- Удаляем файлы
    for _, path in ipairs(toDelete) do
        safeRemove(path)
        os.sleep(0.05)
    end
    
    -- Удаляем всё из /home (кроме папки)
    if fs.exists("/home") then
        for item in fs.list("/home") do
            -- НЕ удаляем текущий installer.lua если он есть
            if item ~= "installer.lua" and item ~= "installer_new.lua" then
                safeRemove("/home/" .. item)
            end
        end
    end
    
    print("✓ Диск очищен!")
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
        if #content > 100000 then -- Лимит 100KB
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

-- ФУНКЦИЯ: Установка run.lua (ОБЯЗАТЕЛЬНО ДЛЯ ЗАПУСКА СИСТЕМЫ ПОСЛЕ ПРОШИВКИ БИОС)
local function installRunLua()
    if not component.isAvailable("internet") then
        return false, "Нет интернет-карты для загрузки run.lua"
    end
    
    print("Устанавливаю run.lua...")
    
    local ok, result = downloadFile("run.lua", "/home/run.lua")
    if not ok then
        return false, "Ошибка загрузки run.lua: " .. tostring(result)
    end
    
    -- Также копируем в корень для совместимости
    if fs.exists("/home/run.lua") then
        local file = io.open("/home/run.lua", "r")
        if file then
            local content = file:read("*a")
            file:close()
            
            local rootFile = io.open("/run.lua", "w")
            if rootFile then
                rootFile:write(content)
                rootFile:close()
                print("✓ run.lua скопирован в корень")
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
    
    -- Заголовок
    local title = "УСТАНОВКА ASMELIT OS v2.5"
    gpu.set(centerX - math.floor(#title / 2), 2, title)
    
    -- Анимация
    local animFrames = {"▌", "██", "██▌", "████", "████▌", "██████", "██████▌", "████████", "████████▌", "██████████"}
    local frameIdx = ((frame - 1) % #animFrames) + 1
    local anim = animFrames[frameIdx]
    gpu.setForeground(0x00FF00)
    gpu.set(centerX - math.floor(#anim / 2), centerY - 2, anim)
    
    -- Статус
    gpu.setForeground(0xFFFFFF)
    gpu.set(centerX - math.floor(#status / 2), centerY, status)
    
    -- Прогресс бар
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
    
    -- Процент
    local percent = math.floor(progress * 100)
    local percentText = percent .. "%"
    gpu.setBackground(0x000033)
    gpu.setForeground(0x00FF00)
    gpu.set(centerX - math.floor(#percentText / 2), barY + 1, percentText)
    
    -- Подсказка
    local help = "ESC - Отмена установки"
    gpu.setForeground(0xAAAAAA)
    gpu.set(centerX - math.floor(#help / 2), maxHeight - 2, help)
end

-- Главное меню
local function mainMenu()
    local selected = 1
    local menuItems = {
        {text = "Установить Asmelit OS (очистка + установка)", action = "install_full"},
        {text = "Только очистить диск", action = "clean_only"},
        {text = "Только установить run.lua", action = "install_run"}, -- <-- ОБЯЗАТЕЛЬНО ДЛЯ ЗАПУСКА СИСТЕМЫ ПОСЛЕ ПРОШИВКИ БИОС
        {text = "Восстановить загрузчик", action = "repair"},
        {text = "Выход в оболочку", action = "shell"}
    }
    
    while true do
        gpu.setBackground(0x000033)
        gpu.setForeground(0xFFFFFF)
        term.clear()
        
        -- Заголовок
        local title = "ASMELIT OS INSTALLER v2.5"
        gpu.set(centerX - math.floor(#title / 2), 3, title)
        gpu.set(centerX - 20, 5, "После прошивки BIOS УСТАНОВИТЕ run.lua!")
        
        local subtitle = "Выберите действие:"
        gpu.set(centerX - math.floor(#subtitle / 2), 7, subtitle)
        
        -- Меню
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
                    prefix = "⚠ " -- Особое обозначение для run.lua
                end
                gpu.set(x, y, prefix .. item.text)
            else
                gpu.setBackground(0x000033)
                gpu.setForeground(0xFFFFFF)
                local prefix = "  "
                if item.action == "install_run" then
                    gpu.setForeground(0xFFFF00) -- Желтый для важного пункта
                end
                gpu.set(x, y, prefix .. item.text)
            end
        end
        
        -- Статус системы
        gpu.setForeground(0xAAAAAA)
        local mem = "Память: " .. computer.freeMemory() .. " байт"
        gpu.set(centerX - math.floor(#mem / 2), maxHeight - 5, mem)
        
        if computer.maxEnergy() > 0 then
            local energy = "Энергия: " .. math.floor((computer.energy() / computer.maxEnergy()) * 100) .. "%"
            gpu.set(centerX - math.floor(#energy / 2), maxHeight - 4, energy)
        end
        
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
                
                if action == "install_full" then
                    -- Полная установка: очистка + загрузка
                    if not component.isAvailable("internet") then
                        gpu.setBackground(0x000033)
                        gpu.setForeground(0xFF0000)
                        term.clear()
                        gpu.set(centerX - 15, centerY, "ОШИБКА: Нет интернет-карты!")
                        os.sleep(3)
                        return
                    end
                    
                    -- 1. Очистка диска
                    cleanDisk()
                    
                    -- 2. Установка run.lua (ОБЯЗАТЕЛЬНО ДЛЯ ЗАПУСКА СИСТЕМЫ ПОСЛЕ ПРОШИВКИ БИОС)
                    local runOk, runMsg = installRunLua()
                    if not runOk then
                        gpu.setBackground(0x000033)
                        gpu.setForeground(0xFF0000)
                        term.clear()
                        gpu.set(centerX - 15, centerY, "ОШИБКА: " .. runMsg)
                        os.sleep(3)
                        return
                    end
                    
                    -- 3. Установка остальных файлов
                    local frame = 1
                    local totalFiles = #FILES_TO_DOWNLOAD
                    
                    for i, fileInfo in ipairs(FILES_TO_DOWNLOAD) do
                        local progress = i / totalFiles
                        local status = "Загрузка " .. fileInfo.url .. "..."
                        
                        drawInstallAnimation(frame, progress, status)
                        frame = frame + 1
                        
                        -- Проверка отмены
                        local cancel = false
                        for j = 1, 10 do
                            local e = {event.pull(0.05)}
                            if e[1] == "key_down" and e[4] == 1 then -- ESC
                                cancel = true
                                break
                            end
                        end
                        
                        if cancel then
                            gpu.set(centerX - 10, centerY + 5, "Установка отменена")
                            os.sleep(2)
                            return
                        end
                        
                        -- Загрузка файла
                        local ok, result = downloadFile(fileInfo.url, fileInfo.path)
                        if not ok then
                            gpu.setBackground(0x000033)
                            gpu.setForeground(0xFF0000)
                            gpu.set(centerX - 15, centerY + 5, "Ошибка: " .. tostring(result))
                            os.sleep(3)
                            return
                        end
                    end
                    
                    -- Создаем структуру папок
                    local fs = require("filesystem")
                    local dirs = {"/home/user", "/home/apps", "/home/docs", "/bin", "/lib", "/tmp"}
                    for _, dir in ipairs(dirs) do
                        if not fs.exists(dir) then
                            fs.makeDirectory(dir)
                        end
                    end
                    
                    -- Создаем startup.lua который запускает run.lua
                    local startupCode = [[-- Asmelit OS Startup
-- Запускает систему через run.lua
local fs = require("filesystem")

if fs.exists("/run.lua") then
    dofile("/run.lua")
elseif fs.exists("/home/run.lua") then
    dofile("/home/run.lua")
else
    print("ERROR: No run.lua found!")
    print("Please install run.lua from installer")
    require("shell").execute()
end]]
                    
                    local startupFile = io.open("/home/startup.lua", "w")
                    if startupFile then
                        startupFile:write(startupCode)
                        startupFile:close()
                    end
                    
                    -- Установка завершена
                    drawInstallAnimation(frame, 1, "Установка завершена!")
                    
                    gpu.setForeground(0x00FF00)
                    gpu.set(centerX - 20, centerY + 5, "Asmelit OS успешно установлена!")
                    gpu.set(centerX - 25, centerY + 6, "ВАЖНО: run.lua установлен - система запустится")
                    gpu.set(centerX - 15, centerY + 7, "Перезагрузите компьютер")
                    
                    os.sleep(5)
                    computer.shutdown(true)
                    
                elseif action == "clean_only" then
                    -- Только очистка
                    cleanDisk()
                    gpu.setBackground(0x000033)
                    gpu.setForeground(0x00FF00)
                    term.clear()
                    gpu.set(centerX - 10, centerY, "Диск очищен!")
                    os.sleep(2)
                    
                elseif action == "install_run" then
                    -- Только установка run.lua (ОБЯЗАТЕЛЬНО ДЛЯ ЗАПУСКА СИСТЕМЫ ПОСЛЕ ПРОШИВКИ БИОС)
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
                else
                    -- Заглушки для других опций
                    gpu.setBackground(0x000033)
                    gpu.setForeground(0xFFFF00)
                    term.clear()
                    gpu.set(centerX - 10, centerY, "Функция в разработке")
                    os.sleep(2)
                end
                
            elseif code == 1 then -- ESC
                return
            end
        end
    end
end

-- Запуск установщика
print("Asmelit OS Installer v2.5 запущен...")
os.sleep(1)
mainMenu()
