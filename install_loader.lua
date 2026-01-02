-- install_loader.lua - Устанавливает нашу систему как основную
local component = require("component")
local computer = require("computer")
local fs = require("filesystem")
local internet = require("internet")

print("=== ASMELIT SYSTEM INSTALLER ===")
print("Устанавливаем нашу систему вместо OpenOS...")

-- Файлы для загрузки с GitHub
local GITHUB_BASE = "https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/main/"
local files_to_download = {
    "run.lua",
    "os.lua", 
    "logo.lua"
}

-- 1. Скачиваем файлы
print("\n1. Скачивание файлов системы...")
for _, filename in ipairs(files_to_download) do
    print("  Загрузка " .. filename .. "...")
    
    local handle, err = internet.request(GITHUB_BASE .. filename)
    if handle then
        local content = ""
        for chunk in handle do
            content = content .. chunk
        end
        
        -- Сохраняем в корень
        local file = io.open("/" .. filename, "w")
        if file then
            file:write(content)
            file:close()
            print("    ✓ " .. filename .. " сохранен")
        else
            print("    ✗ Ошибка записи " .. filename)
        end
    else
        print("    ✗ Ошибка загрузки " .. filename)
    end
end

-- 2. Создаём наш init.lua который загрузит run.lua
print("\n2. Создаём загрузчик...")
local init_code = [[
-- ASMELIT BOOTLOADER v1.0
-- Загружает нашу систему вместо OpenOS

local component = require("component")
local computer = require("computer")
local fs = require("filesystem")

-- Инициализация экрана
local gpu = component.gpu
local screen = component.list("screen")()
if gpu and screen then
    gpu.bind(screen)
    gpu.setBackground(0x000000)
    gpu.setForeground(0x00FF00)
    gpu.fill(1, 1, 80, 25, " ")
end

print("ASMELIT BOOTLOADER v1.0")
print("Loading our system...")

-- Пытаемся загрузить нашу систему
local function loadOurSystem()
    -- Проверяем пути в порядке приоритета
    local paths = {
        "/run.lua",
        "/home/run.lua",
        "/os.lua", 
        "/home/os.lua"
    }
    
    for _, path in ipairs(paths) do
        if fs.exists(path) then
            local file = io.open(path, "r")
            if file then
                local code = file:read("*a")
                file:close()
                
                if #code > 100 then
                    print("Found: " .. path)
                    local func, err = load(code, "=boot")
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

-- Загружаем и запускаем
local system = loadOurSystem()
if system then
    print("Starting Asmelit OS...")
    system()
else
    print("ERROR: System not found!")
    print("Falling back to shell...")
    
    -- Аварийный выход в shell
    gpu.setForeground(0xFF0000)
    print("Press any key for emergency shell...")
    os.sleep(2)
    
    local shell = require("shell")
    if shell then
        shell.execute()
    else
        print("Cannot load shell. Rebooting...")
        computer.shutdown(true)
    end
end
]]

-- Сохраняем init.lua
local init_file = io.open("/init.lua", "w")
if init_file then
    init_file:write(init_code)
    init_file:close()
    print("  ✓ init.lua создан")
else
    print("  ✗ Ошибка создания init.lua")
end

-- 3. Проверяем наличие EEPROM и настраиваем
print("\n3. Настройка EEPROM...")
if component.isAvailable("eeprom") then
    local eeprom = component.eeprom
    local current = eeprom.get() or ""
    
    -- Создаём минимальный BIOS для EEPROM
    local bios_code = [[
-- ASMELIT BIOS
c = component
g = c.gpu
w,h = g.getResolution()
g.setBackground(0x000022)
g.setForeground(0xFFFFFF)
g.fill(1,1,w,h," ")
g.set(35,1,"ASMELIT BIOS")
g.set(30,8,"BOOTING...")
os.sleep(2)
local f = io.open("/init.lua")
if f then 
    local code = f:read("*a") 
    f:close()
    load(code)()
end
]]
    
    if #bios_code <= 4096 then
        eeprom.set(bios_code)
        eeprom.setLabel("Asmelit BIOS")
        print("  ✓ EEPROM прошит")
    else
        print("  ⚠ EEPROM код слишком большой (" .. #bios_code .. " байт)")
    end
else
    print("  ⚠ EEPROM не найден, используем только init.lua")
end

-- 4. Создаём структуру папок
print("\n4. Создание структуры папок...")
local dirs = {
    "/home/user",
    "/home/apps",
    "/home/docs",
    "/tmp",
    "/var/log"
}

for _, dir in ipairs(dirs) do
    if not fs.exists(dir) then
        fs.makeDirectory(dir)
        print("  ✓ Создана папка: " .. dir)
    end
end

-- 5. Финализация
print("\n" .. string.rep("=", 50))
print("УСТАНОВКА ЗАВЕРШЕНА!")
print("=" .. string.rep("=", 50))
print("\nЧто сделано:")
print("1. Скачаны файлы системы")
print("2. Создан init.lua (загрузчик)")
print("3. Настроен EEPROM (если доступен)")
print("4. Создана структура папок")
print("\nПосле перезагрузки система запустит Asmelit OS")
print("\nНажмите любую клавишу для перезагрузки...")
io.read()

computer.shutdown(true)
