-- =====================================================
-- ASMELIT INSTALLER v2.1 - РАБОЧАЯ ВЕРСИЯ
-- Исправлены ошибки загрузки и инициализации
-- =====================================================

local component = require("component")
local computer = require("computer")
local fs = require("filesystem")
local term = require("term")
local gpu = component.gpu
local event = require("event")

-- ПРАВИЛЬНЫЙ URL для GitHub
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

-- Интерфейс
local w, h = gpu.getResolution()
local centerX = math.floor(w / 2)
local centerY = math.floor(h / 2)

function drawHeader(title)
    gpu.setBackground(0x000033)
    gpu.setForeground(0xFFFFFF)
    gpu.fill(1, 1, w, 1, " ")
    gpu.set(centerX - math.floor(#title / 2), 1, title)
    
    local status = "Mem: " .. math.floor(computer.freeMemory() / 1024) .. "K"
    if internet then
        status = "✓ Online | " .. status
    else
        status = "✗ Offline | " .. status
    end
    gpu.set(w - #status - 1, 1, status)
end

function showProgress(step, total, message)
    drawHeader("ASMELIT INSTALLER")
    
    gpu.setBackground(0x000022)
    gpu.setForeground(0xFFFFFF)
    gpu.fill(1, 3, w, h-3, " ")
    
    gpu.set(centerX - math.floor(#message / 2), centerY - 2, message)
    
    -- Прогресс бар
    local barWidth = 40
    local barX = centerX - math.floor(barWidth / 2)
    local barY = centerY
    
    gpu.setBackground(0x333333)
    gpu.fill(barX, barY, barWidth, 1, " ")
    
    local progress = math.floor((step / total) * barWidth)
    gpu.setBackground(0x00AA00)
    gpu.fill(barX, barY, progress, 1, " ")
    
    gpu.setBackground(0x000022)
    gpu.setForeground(0xAAAAAA)
    local percent = math.floor((step / total) * 100)
    gpu.set(centerX - 2, barY + 2, percent .. "%")
end

-- ИСПРАВЛЕННАЯ функция загрузки
function downloadFile(filename)
    if not internet then
        return false, "Нет интернета"
    end
    
    local url = GITHUB_BASE .. filename
    print("Загрузка: " .. url)
    
    local handle, err = pcall(function()
        return internet.request(url)
    end)
    
    if not handle or type(handle) ~= "table" then
        return false, "Ошибка: " .. tostring(err)
    end
    
    local content = ""
    local ok = true
    local downloadErr = nil
    
    -- Обработка чанков с защитой от ошибок
    for chunk in handle do
        if chunk then
            content = content .. chunk
            if #content > 500000 then -- 500KB лимит
                return false, "Файл слишком большой"
            end
        end
    end
    
    -- Проверяем что скачалось что-то
    if #content < 100 then
        return false, "Пустой ответ или ошибка загрузки"
    end
    
    -- Сохраняем файл
    local file = io.open("/" .. filename, "w")
    if file then
        file:write(content)
        file:close()
        return true, "Успешно (" .. #content .. " байт)"
    else
        return false, "Ошибка записи"
    end
end

-- ИСПРАВЛЕННЫЙ init.lua
function createFixedInit()
    local init_code = [[
-- ASMELIT BOOTLOADER v2.1 - FIXED
local component = require("component")
local computer = require("computer")
local fs = require("filesystem")
local event = require("event")
local term = require("term")

-- Инициализация экрана
local gpu = component.gpu
local screen = component.list("screen")()
if gpu and screen then
    gpu.bind(screen)
    gpu.setBackground(0x000000)
    gpu.setForeground(0x00AAFF)
    term.clear()
end

function showBootScreen()
    if gpu then
        local w, h = gpu.getResolution()
        local cx = math.floor(w/2)
        
        gpu.set(cx-10, 5, "╔════════════════════════╗")
        gpu.set(cx-10, 6, "║     ASMELIT OS v2.1    ║")
        gpu.set(cx-10, 7, "║                        ║")
        gpu.set(cx-10, 8, "║    Initializing...     ║")
        gpu.set(cx-10, 9, "╚════════════════════════╝")
        
        for i = 1, 20 do
            gpu.set(cx-10+i, 11, "█")
            os.sleep(0.05)
        end
    end
end

function loadOS()
    -- Проверяем файлы в порядке приоритета
    local paths = {"/os.lua", "/home/os.lua", "/system/os.lua"}
    
    for _, path in ipairs(paths) do
        if fs.exists(path) then
            local file = io.open(path, "r")
            if file then
                local code = file:read("*a")
                file:close()
                
                if #code > 1000 then
                    print("Found OS: " .. path .. " (" .. #code .. " bytes)")
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
    
    return nil, "OS not found"
end

-- Основной процесс загрузки
local function main()
    -- Проверка памяти
    if computer.freeMemory() < 1024 then
        if gpu then
            gpu.setForeground(0xFF0000)
            gpu.set(30, 15, "ERROR: Low memory!")
        end
        os.sleep(3)
        local shell = require("shell")
        if shell then shell.execute() end
        return
    end
    
    -- Загрузочный экран
    local ok, err = pcall(showBootScreen)
    if not ok then
        print("Boot screen error: " .. tostring(err))
    end
    
    -- Загружаем ОС
    local os_func, os_err = loadOS()
    if os_func then
        -- Запускаем ОС
        local success, error_msg = pcall(os_func)
        if not success then
            -- Ошибка ОС
            if gpu then
                gpu.setBackground(0xFF0000)
                gpu.setForeground(0xFFFFFF)
                term.clear()
                gpu.set(1, 1, "OS CRASH: " .. tostring(error_msg))
                gpu.set(1, 3, "Press any key for shell...")
            end
            event.pull("key_down")
            require("shell").execute()
        end
    else
        -- ОС не найдена
        if gpu then
            gpu.setBackground(0xFF0000)
            gpu.setForeground(0xFFFFFF)
            term.clear()
            gpu.set(1, 1, "ERROR: OS NOT FOUND")
            gpu.set(1, 3, "Checked paths:")
            gpu.set(1, 4, "1. /os.lua")
            gpu.set(1, 5, "2. /home/os.lua")
            gpu.set(1, 6, "3. /system/os.lua")
            gpu.set(1, 8, "Press any key for shell...")
        end
        event.pull("key_down")
        require("shell").execute()
    end
end

-- Запуск
main()
]]
    
    -- Сохраняем в несколько мест
    local paths = {"/init.lua", "/home/init.lua"}
    
    for _, path in ipairs(paths) do
        local file = io.open(path, "w")
        if file then
            file:write(init_code)
            file:close()
            print("✓ init.lua создан: " .. path)
        end
    end
end

function createDirectoryStructure()
    local dirs = {
        "/home/user",
        "/home/apps",
        "/home/docs",
        "/home/config",
        "/system",
        "/tmp"
    }
    
    for _, dir in ipairs(dirs) do
        if not fs.exists(dir) then
            fs.makeDirectory(dir)
        end
    end
end

function checkExistingFiles()
    print("\n=== ПРОВЕРКА СУЩЕСТВУЮЩИХ ФАЙЛОВ ===")
    
    local files = {
        {path = "/os.lua", name = "OS файл"},
        {path = "/home/os.lua", name = "OS (home)"},
        {path = "/init.lua", name = "Загрузчик"},
        {path = "/run.lua", name = "Запускатель"},
        {path = "/logo.lua", name = "Логотип"}
    }
    
    for _, file in ipairs(files) do
        if fs.exists(file.path) then
            local size = fs.size(file.path)
            print("✓ " .. file.name .. ": " .. file.path .. " (" .. size .. " байт)")
        else
            print("✗ " .. file.name .. ": не найден")
        end
    end
end

-- ГЛАВНАЯ ФУНКЦИЯ УСТАНОВКИ
function mainInstallation()
    print("=== НАЧАЛО УСТАНОВКИ ===")
    
    -- Шаг 1: Проверка существующих файлов
    showProgress(1, 6, "Проверка файлов...")
    checkExistingFiles()
    os.sleep(1)
    
    -- Шаг 2: Загрузка ОС (если нет)
    showProgress(2, 6, "Загрузка Asmelit OS...")
    if not fs.exists("/os.lua") and not fs.exists("/home/os.lua") then
        if internet then
            print("Скачиваю os.lua...")
            local ok, msg = downloadFile("os.lua")
            if ok then
                print("✓ " .. msg)
            else
                print("✗ Ошибка: " .. msg)
                print("⚠ ОС не скачана, нужна локальная копия")
            end
        else
            print("⚠ Нет интернета, ОС должна быть установлена вручную")
        end
    else
        print("✓ ОС уже существует")
    end
    
    -- Шаг 3: Дополнительные файлы
    showProgress(3, 6, "Загрузка дополнительных файлов...")
    local extra_files = {"logo.lua", "run.lua"}
    
    for _, file in ipairs(extra_files) do
        if not fs.exists("/" .. file) and internet then
            print("Скачиваю " .. file .. "...")
            local ok, msg = downloadFile(file)
            if ok then print("✓ " .. msg) end
        end
    end
    
    -- Шаг 4: Создание init.lua
    showProgress(4, 6, "Создание загрузчика...")
    createFixedInit()
    
    -- Шаг 5: Структура папок
    showProgress(5, 6, "Создание структуры папок...")
    createDirectoryStructure()
    
    -- Шаг 6: Финальная проверка
    showProgress(6, 6, "Финальная проверка...")
    
    -- Проверяем что всё установлено
    term.clear()
    drawHeader("УСТАНОВКА ЗАВЕРШЕНА")
    
    gpu.setBackground(0x002200)
    gpu.setForeground(0x00FF00)
    gpu.fill(1, 3, w, h-3, " ")
    
    gpu.set(centerX - 15, centerY - 4, "=== ИТОГИ УСТАНОВКИ ===")
    
    local checks = {
        {name = "Загрузчик (init.lua)", path = "/init.lua"},
        {name = "Операционная система", path = "/os.lua"},
        {name = "Структура папок", check = function() return fs.exists("/home/user") end}
    }
    
    local y = centerY - 2
    for i, check in ipairs(checks) do
        local status = "✗"
        local color = 0xFF0000
        
        if check.path then
            if fs.exists(check.path) then
                local size = fs.size(check.path)
                status = "✓ (" .. size .. " байт)"
                color = 0x00FF00
            end
        elseif check.check then
            if check.check() then
                status = "✓"
                color = 0x00FF00
            end
        end
        
        gpu.setForeground(color)
        gpu.set(centerX - 20, y, check.name .. ": " .. status)
        y = y + 2
    end
    
    if not fs.exists("/os.lua") and not fs.exists("/home/os.lua") then
        gpu.setForeground(0xFFFF00)
        gpu.set(centerX - 25, y + 2, "ВНИМАНИЕ: ОС НЕ НАЙДЕНА!")
        gpu.set(centerX - 25, y + 3, "Система не запустится без os.lua")
    end
    
    gpu.setForeground(0xFFFFFF)
    gpu.set(centerX - 20, h - 4, "Выберите действие:")
    gpu.set(centerX - 20, h - 3, "1. Перезагрузить сейчас")
    gpu.set(centerX - 20, h - 2, "2. Выйти в оболочку")
    
    gpu.set(centerX - 20, h - 1, "> ")
    
    local choice = io.read()
    
    if choice == "1" then
        print("Перезагрузка через 2 секунды...")
        os.sleep(2)
        computer.shutdown(true)
    else
        require("shell").execute()
    end
end

-- ЗАПУСК УСТАНОВЩИКА
gpu.setBackground(0x000000)
gpu.setForeground(0xFFFFFF)
term.clear()

drawHeader("ASMELIT INSTALLER v2.1")

gpu.set(centerX - 25, centerY - 6, "╔══════════════════════════════════════╗")
gpu.set(centerX - 25, centerY - 5, "║        ASMELIT SYSTEM INSTALLER      ║")
gpu.set(centerX - 25, centerY - 4, "║                 v2.1                 ║")
gpu.set(centerX - 25, centerY - 3, "╠══════════════════════════════════════╣")
gpu.set(centerX - 25, centerY - 2, "║  Установит Asmelit OS и загрузчик    ║")
gpu.set(centerX - 25, centerY - 1, "║  Заменит стандартный init.lua        ║")
gpu.set(centerX - 25, centerY,     "║  Создаст структуру папок             ║")
gpu.set(centerX - 25, centerY + 1, "║                                      ║")
gpu.set(centerX - 25, centerY + 2, "╚══════════════════════════════════════╝")

if internet then
    gpu.setForeground(0x00FF00)
    gpu.set(centerX - 10, centerY + 4, "✓ Интернет доступен")
else
    gpu.setForeground(0xFFFF00)
    gpu.set(centerX - 12, centerY + 4, "⚠ Нет интернета - только локальные файлы")
end

gpu.setForeground(0xFFFFFF)
gpu.set(centerX - 15, centerY + 6, "Начать установку? (y/n)")
gpu.set(centerX - 15, centerY + 7, "> ")

local answer = io.read()

if answer:lower() == "y" or answer == "д" then  -- поддержка русской раскладки
    local ok, err = pcall(mainInstallation)
    if not ok then
        gpu.setBackground(0xFF0000)
        gpu.setForeground(0xFFFFFF)
        term.clear()
        gpu.set(1, 1, "КРИТИЧЕСКАЯ ОШИБКА УСТАНОВКИ:")
        gpu.set(1, 3, tostring(err))
        gpu.set(1, 5, "Нажмите любую клавишу...")
        event.pull("key_down")
        require("shell").execute()
    end
else
    print("Установка отменена.")
    require("shell").execute()
end
