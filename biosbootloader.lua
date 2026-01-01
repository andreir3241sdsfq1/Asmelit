-- =====================================================
-- Asmelit BIOS Bootloader
-- Загружается из EEPROM, ставит ОС на диск
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

-- Отображение лого BIOS
function showBiosLogo()
    gpu.setBackground(0x000000)
    gpu.setForeground(0x00AAFF)
    term.clear()
    
    local logo = [[
╔══════════════════════════════╗
║     █████╗ ███████╗███╗   ███╗║
║    ██╔══██╗██╔════╝████╗ ████║║
║    ███████║███████╗██╔████╔██║║
║    ██╔══██║╚════██║██║╚██╔╝██║║
║    ██║  ██║███████║██║ ╚═╝ ██║║
║    ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝║
║         B I O S               ║
║        Version 1.0            ║
╚══════════════════════════════╝
    ]]
    
    local lines = {}
    for line in logo:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    
    for i, line in ipairs(lines) do
        local x = centerX - math.floor(#line / 2)
        local y = centerY - math.floor(#lines / 2) + i
        gpu.set(x, y, line)
    end
    
    -- Информация о системе
    gpu.setForeground(0xAAAAAA)
    gpu.set(centerX - 15, maxHeight - 5, "Память: " .. computer.totalMemory() .. " байт")
    
    if computer.maxEnergy() > 0 then
        gpu.set(centerX - 15, maxHeight - 4, "Энергия: " .. computer.energy() .. "/" .. computer.maxEnergy())
    end
    
    return lines
end

-- Очистка диска и установка ОС
function installOS()
    local fs = require("filesystem")
    
    gpu.setBackground(0x000033)
    gpu.setForeground(0xFFFFFF)
    term.clear()
    
    gpu.set(centerX - 10, 3, "УСТАНОВКА ASMELIT OS")
    
    local steps = {
        "Проверка дисков...",
        "Очистка старой системы...",
        "Создание структуры папок...",
        "Установка загрузчика...",
        "Настройка системы..."
    }
    
    local y = 6
    for i, step in ipairs(steps) do
        gpu.set(centerX - 20, y, step)
        
        -- Имитация работы
        for j = 1, 3 do
            gpu.set(centerX + 15, y, string.rep(".", j))
            os.sleep(0.3)
        end
        
        gpu.setForeground(0x00FF00)
        gpu.set(centerX + 15, y, " ✓")
        gpu.setForeground(0xFFFFFF)
        
        y = y + 2
        
        -- Проверка отмены
        local e = {event.pull(0.1)}
        if e[1] == "key_down" and e[4] == 1 then -- ESC
            return false
        end
    end
    
    -- Создаем структуру папок
    local dirs = {
        "/", "/home", "/home/user", "/home/system", 
        "/home/apps", "/bin", "/lib", "/tmp", "/etc"
    }
    
    for _, dir in ipairs(dirs) do
        if not fs.exists(dir) then
            fs.makeDirectory(dir)
        end
    end
    
    -- Записываем минимальную ОС
    local osCode = [[
-- Asmelit OS (минимальная версия)
local component = require("component")
local computer = require("computer")
local term = require("term")
local gpu = component.gpu

gpu.setBackground(0x000000)
gpu.setForeground(0x00FF00)
term.clear()

print("=== Asmelit OS ===")
print("Установлена из BIOS")
print("Память: " .. computer.freeMemory() .. " байт")
print("")
print("Команды:")
print("  install - запустить установщик")
print("  shell - стандартная оболочка")
print("  reboot - перезагрузка")

while true do
    io.write("> ")
    local cmd = io.read()
    
    if cmd == "install" then
        if component.isAvailable("internet") then
            local internet = require("internet")
            local handle = internet.request("https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/refs/heads/main/installer.lua")
            local code = ""
            for chunk in handle do code = code .. chunk end
            load(code)()
        else
            print("Нужна интернет-карта!")
        end
    elseif cmd == "shell" then
        require("shell").execute()
    elseif cmd == "reboot" then
        computer.shutdown(true)
    else
        print("Неизвестная команда")
    end
end
]]
    
    -- Сохраняем ОС
    local file = io.open("/home/startup.lua", "w")
    file:write(osCode)
    file:close()
    
    -- Создаем установщик
    local installerCode = [[
-- Минимальный установщик
print("=== Asmelit Installer ===")
print("Скачиваю полную ОС...")

if not component.isAvailable("internet") then
    print("ОШИБКА: Нужна интернет-карта!")
    return
end

local internet = require("internet")

-- Скачиваем ОС
local url = "https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/refs/heads/main/os.lua"
local handle = internet.request(url)
local osCode = ""
for chunk in handle do osCode = osCode .. chunk end

-- Сохраняем
local file = io.open("/home/startup.lua", "w")
file:write(osCode)
file:close()

print("ОС установлена! Перезагрузитесь.")
]]
    
    local installerFile = io.open("/home/installer.lua", "w")
    installerFile:write(installerCode)
    installerFile:close()
    
    gpu.setForeground(0x00FF00)
    gpu.set(centerX - 15, maxHeight - 5, "УСТАНОВКА ЗАВЕРШЕНА!")
    gpu.set(centerX - 20, maxHeight - 4, "Система готова к использованию")
    
    os.sleep(3)
    return true
end

-- Главное меню BIOS
function biosMenu()
    local selected = 1
    local menuItems = {
        {text = "Установить Asmelit OS на диск", action = "install"},
        {text = "Загрузить существующую ОС", action = "boot"},
        {text = "Настройки BIOS", action = "setup"},
        {text = "Информация о системе", action = "info"},
        {text = "Перезагрузить", action = "reboot"}
    }
    
    while true do
        gpu.setBackground(0x000011)
        gpu.setForeground(0xFFFFFF)
        term.clear()
        
        -- Заголовок
        local title = "ASMELIT BIOS SETUP UTILITY"
        gpu.set(centerX - math.floor(#title / 2), 3, title)
        
        local subtitle = "Основное меню"
        gpu.set(centerX - math.floor(#subtitle / 2), 5, subtitle)
        
        -- Меню
        local startY = 8
        for i, item in ipairs(menuItems) do
            local y = startY + i * 2
            
            if i == selected then
                gpu.setBackground(0x00AA00)
                gpu.setForeground(0x000000)
            else
                gpu.setBackground(0x000011)
                gpu.setForeground(0xFFFFFF)
            end
            
            gpu.fill(centerX - 25, y, 50, 1, " ")
            local text = (i == selected and "▶ " or "  ") .. item.text
            gpu.set(centerX - 23, y, text)
        end
        
        -- Подсказка
        local help = "F1 - Установка | F2 - Загрузка | F10 - Сохранить и перезагрузить"
        gpu.setForeground(0xAAAAAA)
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
                
                if action == "install" then
                    installOS()
                elseif action == "boot" then
                    -- Пробуем загрузить ОС с диска
                    local fs = require("filesystem")
                    if fs.exists("/home/startup.lua") then
                        local file = io.open("/home/startup.lua", "r")
                        local code = file:read("*a")
                        file:close()
                        
                        local func, err = load(code, "=AsmelitOS")
                        if func then
                            func()
                        else
                            gpu.setBackground(0x000011)
                            gpu.setForeground(0xFF0000)
                            term.clear()
                            gpu.set(centerX - 15, centerY, "Ошибка загрузки ОС")
                            os.sleep(2)
                        end
                    else
                        gpu.setBackground(0x000011)
                        gpu.setForeground(0xFFFF00)
                        term.clear()
                        gpu.set(centerX - 20, centerY, "ОС не установлена. Выберите установку.")
                        os.sleep(2)
                    end
                elseif action == "setup" then
                    -- Настройки BIOS
                    gpu.setBackground(0x000011)
                    gpu.setForeground(0xFFFFFF)
                    term.clear()
                    gpu.set(centerX - 10, centerY, "Настройки BIOS")
                    gpu.set(centerX - 15, centerY + 2, "Здесь будут настройки...")
                    os.sleep(2)
                elseif action == "info" then
                    -- Информация
                    gpu.setBackground(0x000011)
                    gpu.setForeground(0xFFFFFF)
                    term.clear()
                    
                    gpu.set(1, 1, "=== СИСТЕМНАЯ ИНФОРМАЦИЯ ===")
                    gpu.set(1, 3, "Память ОЗУ: " .. computer.totalMemory())
                    gpu.set(1, 4, "Свободно: " .. computer.freeMemory())
                    gpu.set(1, 5, "Время работы: " .. computer.uptime())
                    
                    if computer.maxEnergy() > 0 then
                        gpu.set(1, 6, "Энергия: " .. computer.energy() .. "/" .. computer.maxEnergy())
                    end
                    
                    local fs = require("filesystem")
                    gpu.set(1, 8, "Диски:")
                    local diskCount = 0
                    for addr, type in component.list("drive") do
                        diskCount = diskCount + 1
                        gpu.set(1, 9 + diskCount, "  Диск " .. diskCount .. ": " .. type)
                    end
                    
                    gpu.set(1, maxHeight - 1, "Нажмите любую клавишу...")
                    event.pull("key_down")
                    
                elseif action == "reboot" then
                    computer.shutdown(true)
                end
                
            elseif code == 59 then -- F1
                installOS()
            elseif code == 60 then -- F2
                -- Быстрая загрузка
                local fs = require("filesystem")
                if fs.exists("/home/startup.lua") then
                    local file = io.open("/home/startup.lua", "r")
                    local code = file:read("*a")
                    file:close()
                    load(code)()
                end
            elseif code == 68 then -- F10
                computer.shutdown(true)
            end
        end
    end
end

-- Главная функция
function main()
    showBiosLogo()
    os.sleep(1)
    biosMenu()
end

-- Запуск
local ok, err = pcall(main)
if not ok then
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFF0000)
    term.clear()
    gpu.set(1, 1, "BIOS ERROR: " .. tostring(err))
    gpu.set(1, 3, "Press any key for shell...")
    event.pull("key_down")
    require("shell").execute()
end
