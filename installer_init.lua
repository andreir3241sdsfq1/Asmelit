-- installer_init.lua - Заменяет стандартный init.lua на наш
local component = require("component")
local computer = require("computer")
local fs = require("filesystem")

print("=== ASMELIT INIT INSTALLER ===")
print("Заменяем системный загрузчик...")

-- Наш init.lua который грузит ОС напрямую
local our_init_code = [[
-- ASMELIT DIRECT BOOTLOADER
-- Загружает ОС напрямую без run.lua

local component = require("component")
local computer = require("computer")
local event = require("event")
local gpu = component.gpu
local term = require("term")

-- Очистка экрана
gpu.setBackground(0x000000)
gpu.setForeground(0x00FF00)
term.clear()

-- Показать загрузочное сообщение
gpu.set(35, 10, "ASMELIT OS")
gpu.set(33, 12, "Loading system...")

-- Проверить память
if computer.freeMemory() < 2048 then
    gpu.setForeground(0xFF0000)
    gpu.set(30, 15, "ERROR: Low memory!")
    os.sleep(3)
    require("shell").execute()
    return
end

-- Функция загрузки ОС напрямую
local function loadDirectOS()
    -- Список возможных путей к ОС
    local paths = {
        "/os.lua",
        "/home/os.lua",
        "/system/os.lua"
    }
    
    for _, path in ipairs(paths) do
        if fs.exists(path) then
            local file = io.open(path, "r")
            if file then
                local code = file:read("*a")
                file:close()
                
                if #code > 5000 then -- ОС должна быть достаточно большой
                    print("Found OS at: " .. path)
                    local func, err = load(code, "=AsmelitOS")
                    if func then
                        return func
                    else
                        print("Load error: " .. tostring(err))
                    end
                end
            end
        end
    end
    return nil
end

-- Загрузочный экран
function bootScreen()
    local w, h = gpu.getResolution()
    local cx = math.floor(w/2)
    local cy = math.floor(h/2)
    
    gpu.setBackground(0x000000)
    gpu.setForeground(0x00AAFF)
    term.clear()
    
    -- Попробовать загрузить лого
    local logoText = "ASMELIT OS"
    if fs.exists("/home/logo.lua") then
        local file = io.open("/home/logo.lua", "r")
        if file then
            local content = file:read("*a")
            file:close()
            if #content > 10 then
                logoText = content
            end
        end
    end
    
    -- Отобразить лого
    local logoLines = {}
    for line in logoText:gmatch("[^\r\n]+") do
        table.insert(logoLines, line)
    end
    
    local logoStartY = 3
    for i, line in ipairs(logoLines) do
        local x = cx - math.floor(#line/2)
        gpu.set(x, logoStartY + i, line)
    end
    
    -- Прогресс бар
    local barWidth = 40
    local barX = cx - math.floor(barWidth/2)
    local barY = logoStartY + #logoLines + 3
    
    gpu.set(barX, barY - 1, "Loading system...")
    
    for i = 1, barWidth do
        gpu.setBackground(0x00AAFF)
        gpu.set(barX + i - 1, barY, " ")
        gpu.setBackground(0x000000)
        os.sleep(0.02)
    end
    
    os.sleep(0.5)
    return true
end

-- Основная функция запуска
function startSystem()
    -- Запустить загрузочный экран
    local ok, err = pcall(bootScreen)
    if not ok then
        print("Boot error: " .. tostring(err))
    end
    
    -- Загрузить ОС
    local os_func = loadDirectOS()
    if os_func then
        -- Запустить ОС
        local success, error_msg = pcall(os_func)
        if not success then
            gpu.setBackground(0xFF0000)
            gpu.setForeground(0xFFFFFF)
            term.clear()
            gpu.set(1, 1, "OS CRASHED: " .. tostring(error_msg))
            gpu.set(1, 3, "Press any key for shell...")
            event.pull("key_down")
            require("shell").execute()
        end
    else
        -- ОС не найдена
        gpu.setBackground(0xFF0000)
        gpu.setForeground(0xFFFFFF)
        term.clear()
        gpu.set(1, 1, "ERROR: Operating System not found!")
        gpu.set(1, 3, "Files checked:")
        gpu.set(1, 4, "- /os.lua")
        gpu.set(1, 5, "- /home/os.lua")
        gpu.set(1, 6, "- /system/os.lua")
        gpu.set(1, 8, "Press any key for shell...")
        event.pull("key_down")
        require("shell").execute()
    end
end

-- Начать загрузку
startSystem()
]]

-- Сохраняем наш init.lua
local init_paths = {
    "/init.lua",           -- Основной путь
    "/home/init.lua",      -- Альтернативный
    "/boot/init.lua"       -- Для совместимости
}

print("\n1. Сохраняем наш загрузчик...")
for _, path in ipairs(init_paths) do
    local file = io.open(path, "w")
    if file then
        file:write(our_init_code)
        file:close()
        print("  ✓ Записано в " .. path)
    else
        print("  ✗ Ошибка записи в " .. path)
    end
end

-- 2. Создаём или проверяем os.lua
print("\n2. Проверка наличия ОС...")
if not fs.exists("/os.lua") and not fs.exists("/home/os.lua") then
    print("  ⚠ ОС не найдена!")
    print("  Запускаю online bootloader для установки...")
    
    -- Если есть интернет, скачиваем ОС
    if component.isAvailable("internet") then
        local internet = require("internet")
        local url = "https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/main/os.lua"
        
        local handle = internet.request(url)
        if handle then
            local content = ""
            for chunk in handle do
                content = content .. chunk
            end
            
            local file = io.open("/os.lua", "w")
            if file then
                file:write(content)
                file:close()
                print("  ✓ ОС скачана и сохранена как /os.lua")
            end
        end
    else
        print("  ⚠ Нет интернета, ОС нужно установить вручную")
    end
else
    print("  ✓ ОС найдена")
end

-- 3. Настройка EEPROM (если есть)
print("\n3. Настройка EEPROM...")
if component.isAvailable("eeprom") then
    local eeprom = component.eeprom
    
    -- Минимальный BIOS для EEPROM
    local bios_code = [[
c = component
g = c.gpu
g.setBackground(0x000000)
g.setForeground(0x00FF00)
term.clear()
g.set(35,10,"ASMELIT BIOS")
os.sleep(1)
loadfile("/init.lua")()
]]
    
    if #bios_code <= 4096 then
        eeprom.set(bios_code)
        eeprom.setLabel("Asmelit Direct Boot")
        print("  ✓ EEPROM прошит")
        print("  ✓ Метка: Asmelit Direct Boot")
    else
        print("  ⚠ EEPROM код слишком большой")
    end
else
    print("  ⚠ EEPROM не найден")
end

-- 4. Итоги
print("\n" .. string.rep("=", 50))
print("УСТАНОВКА ЗАВЕРШЕНА!")
print("=" .. string.rep("=", 50))
print("\nЧто изменилось:")
print("1. init.lua заменён на наш загрузчик")
print("2. Загрузчик грузит ОС напрямую (не через run.lua)")
print("3. EEPROM прошит (если был доступен)")
print("4. Проверена установка ОС")
print("\nПосле перезагрузки система запустит os.lua напрямую")
print("\nПерезагрузить сейчас? (y/n)")
local answer = io.read()

if answer:lower() == "y" then
    print("Перезагрузка...")
    os.sleep(1)
    computer.shutdown(true)
else
    print("Перезагрузите компьютер вручную для применения изменений")
end
