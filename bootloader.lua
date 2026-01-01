-- =====================================================
-- Asmelit Bootloader v2.0
-- BIOS для загрузки системы с диска
-- =====================================================

local component = require("component")
local computer = require("computer")
local gpu = component.gpu
local term = require("term")

-- Настройки
local BOOT_DEVICE = "/"
local OS_PATH = "/home/startup.lua"
local INSTALLER_PATH = "/home/installer.lua"
local LOGO_PATH = "/home/logo.lua"

-- Отображение лого
function showBootLogo()
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
║      Asmelit Bootloader      ║
║           v2.0               ║
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

-- Проверка файловой системы
function checkFilesystem()
    local fs = require("filesystem")
    
    -- Создаем базовые директории если их нет
    local dirs = {"/home", "/bin", "/tmp", "/lib"}
    for _, dir in ipairs(dirs) do
        if not fs.exists(dir) then
            fs.makeDirectory(dir)
        end
    end
    
    -- Проверяем наличие ОС
    local hasOS = fs.exists(OS_PATH)
    local hasInstaller = fs.exists(INSTALLER_PATH)
    
    return hasOS, hasInstaller
end

-- Загрузка системы
function bootSystem()
    local fs = require("filesystem")
    
    -- Показываем лого
    local logoLines = showBootLogo()
    local maxWidth, maxHeight = gpu.getResolution()
    local centerX = math.floor(maxWidth / 2)
    
    -- Информация о загрузке
    gpu.setForeground(0xFFFFFF)
    gpu.set(centerX - 10, maxHeight - 8, "Проверка системы...")
    
    -- Проверяем файловую систему
    local hasOS, hasInstaller = checkFilesystem()
    
    gpu.set(centerX - 10, maxHeight - 6, "Память: " .. computer.freeMemory() .. " байт")
    
    if computer.maxEnergy() > 0 then
        local energyPercent = math.floor((computer.energy() / computer.maxEnergy()) * 100)
        gpu.set(centerX - 10, maxHeight - 5, "Энергия: " .. energyPercent .. "%")
    end
    
    -- Выбор действия
    gpu.set(centerX - 15, maxHeight - 3, "Нажмите: 1-ОС, 2-Установщик, 3-Оболочка")
    
    -- Ожидаем выбора
    local choice = nil
    for i = 1, 300 do -- 30 секунд
        local event = {require("event").pull(0.1, "key_down")}
        if event[1] == "key_down" then
            local char = event[3]
            if char == "1" or char == "2" or char == "3" then
                choice = char
                break
            end
        end
    end
    
    -- Автовыбор если не выбрано
    if not choice then
        if hasOS then
            choice = "1"
        elseif hasInstaller then
            choice = "2"
        else
            choice = "3"
        end
    end
    
    -- Выполняем выбор
    if choice == "1" and hasOS then
        -- Загрузка ОС
        gpu.set(centerX - 10, maxHeight - 1, "Загрузка Asmelit OS...")
        os.sleep(1)
        
        local file = io.open(OS_PATH, "r")
        if file then
            local osCode = file:read("*a")
            file:close()
            
            local func, err = load(osCode, "=AsmelitOS")
            if func then
                local ok, result = pcall(func)
                if not ok then
                    gpu.setBackground(0xFF0000)
                    gpu.setForeground(0xFFFFFF)
                    term.clear()
                    gpu.set(1, 1, "Ошибка ОС: " .. tostring(result))
                    gpu.set(1, 3, "Нажмите любую клавишу для оболочки...")
                    require("event").pull("key_down")
                    require("shell").execute()
                end
            else
                error("Ошибка загрузки ОС: " .. tostring(err))
            end
        else
            error("Не могу открыть " .. OS_PATH)
        end
        
    elseif choice == "2" and hasInstaller then
        -- Запуск установщика
        gpu.set(centerX - 10, maxHeight - 1, "Запуск установщика...")
        os.sleep(1)
        
        local file = io.open(INSTALLER_PATH, "r")
        if file then
            local installerCode = file:read("*a")
            file:close()
            
            local func, err = load(installerCode, "=Installer")
            if func then
                func()
            else
                error("Ошибка установщика: " .. tostring(err))
            end
        end
        
    else
        -- Стандартная оболочка OpenComputers
        gpu.set(centerX - 10, maxHeight - 1, "Загрузка оболочки...")
        os.sleep(1)
        require("shell").execute()
    end
end

-- Главная функция
function main()
    local ok, err = pcall(bootSystem)
    if not ok then
        gpu.setBackground(0xFF0000)
        gpu.setForeground(0xFFFFFF)
        term.clear()
        gpu.set(1, 1, "Ошибка загрузчика: " .. tostring(err))
        gpu.set(1, 3, "Переход к оболочке через 5 сек...")
        os.sleep(5)
        require("shell").execute()
    end
end

-- Запуск
main()
