-- =====================================================
-- ASMELIT INSTALLER v2.0 - Главный установщик системы
-- Скачивает, устанавливает и настраивает всю систему
-- =====================================================

local component = require("component")
local computer = require("computer")
local fs = require("filesystem")
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

-- Интерфейс установщика
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
    drawHeader("ASMELIT INSTALLER - Шаг " .. step .. " из " .. total)
    
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
    
    os.sleep(0.5)
end

function downloadFile(filename, savePath)
    if not internet then
        return false, "Нет интернет-соединения"
    end
    
    local url = GITHUB_BASE .. filename
    local handle, err = pcall(internet.request, url)
    
    if not handle or type(handle) ~= "table" then
        return false, "Ошибка запроса: " .. tostring(err)
    end
    
    local content = ""
    local chunks = 0
    
    for chunk in handle do
        content = content .. chunk
        chunks = chunks + 1
        
        -- Проверка размера
        if #content > 1000000 then -- 1MB лимит
            return false, "Файл слишком большой"
        end
        
        -- Пауза для отзывчивости
        if chunks % 10 == 0 then
            os.sleep(0.01)
        end
    end
    
    -- Сохраняем файл
    local file = io.open(savePath, "w")
    if file then
        file:write(content)
        file:close()
        return true, "Успешно"
    else
        return false, "Ошибка записи файла"
    end
end

function createInitLoader()
    -- Создаём наш init.lua который грузит ОС напрямую
    local init_code = [[
-- ASMELIT SYSTEM LOADER v2.0
-- Загружает Asmelit OS напрямую

local component = require("component")
local computer = require("computer")
local fs = require("filesystem")
local event = require("event")

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
    local w, h = gpu.getResolution()
    local cx = math.floor(w/2)
    
    gpu.set(cx-10, 5, "╔════════════════════════╗")
    gpu.set(cx-10, 6, "║     ASMELIT OS v2.1    ║")
    gpu.set(cx-10, 7, "║                        ║")
    gpu.set(cx-10, 8, "║    Initializing...     ║")
    gpu.set(cx-10, 9, "╚════════════════════════╝")
    
    -- Прогресс
    for i = 1, 20 do
        gpu.set(cx-10+i, 11, "█")
        os.sleep(0.05)
    end
end

function loadOS()
    -- Поиск ОС в порядке приоритета
    local paths = {
        "/os.lua",
        "/home/os.lua",
        "/system/os.lua",
        "/AsmelitOS.lua"
    }
    
    for _, path in ipairs(paths) do
        if fs.exists(path) then
            local file = io.open(path, "r")
            if file then
                local code = file:read("*a")
                file:close()
                
                if #code > 5000 then -- Проверка что это действительно ОС
                    print("Loading: " .. path)
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
    if computer.freeMemory() < 2048 then
        gpu.setForeground(0xFF0000)
        gpu.set(30, 15, "ERROR: Low memory!")
        os.sleep(3)
        require("shell").execute()
        return
    end
    
    -- Показать загрузочный экран
    local ok, err = pcall(showBootScreen)
    if not ok then
        print("Boot screen error: " .. tostring(err))
    end
    
    -- Загрузить ОС
    local os_func, os_err = loadOS()
    if os_func then
        -- Запустить ОС
        local success, error_msg = pcall(os_func)
        if not success then
            -- Ошибка запуска ОС
            gpu.setBackground(0xFF0000)
            gpu.setForeground(0xFFFFFF)
            term.clear()
            gpu.set(1, 1, "OS CRASH: " .. tostring(error_msg))
            gpu.set(1, 3, "Press any key for shell...")
            event.pull("key_down")
            require("shell").execute()
        end
    else
        -- ОС не найдена
        gpu.setBackground(0xFF0000)
        gpu.setForeground(0xFFFFFF)
        term.clear()
        gpu.set(1, 1, "FATAL: Operating System not found!")
        gpu.set(1, 3, "Expected files:")
        gpu.set(1, 4, "  /os.lua")
        gpu.set(1, 5, "  /home/os.lua")
        gpu.set(1, 7, "Press any key for shell...")
        event.pull("key_down")
        require("shell").execute()
    end
end

-- Запустить загрузку
main()
]]
    
    -- Сохраняем init.lua в несколько мест для надежности
    local paths = {
        "/init.lua",
        "/home/init.lua",
        "/boot/init.lua"
    }
    
    for _, path in ipairs(paths) do
        local file = io.open(path, "w")
        if file then
            file:write(init_code)
            file:close()
        end
    end
    
    return true
end

function createDirectoryStructure()
    local dirs = {
        "/home/user",
        "/home/apps",
        "/home/docs",
        "/home/config",
        "/home/logs",
        "/system",
        "/var",
        "/var/log",
        "/tmp"
    }
    
    for _, dir in ipairs(dirs) do
        if not fs.exists(dir) then
            fs.makeDirectory(dir)
        end
    end
end

function backupOriginalSystem()
    -- Создаем backup оригинальных файлов
    local backupDir = "/backup_original_" .. os.date("%Y%m%d")
    if not fs.exists(backupDir) then
        fs.makeDirectory(backupDir)
    end
    
    local files_to_backup = {
        "/init.lua",
        "/boot/init.lua",
        "/autorun.lua",
        "/.shrc"
    }
    
    for _, file in ipairs(files_to_backup) do
        if fs.exists(file) then
            local content = ""
            local f = io.open(file, "r")
            if f then
                content = f:read("*a")
                f:close()
                
                local backupFile = io.open(backupDir .. file, "w")
                if backupFile then
                    backupFile:write(content)
                    backupFile:close()
                end
            end
        end
    end
    
    return backupDir
end

function mainInstallation()
    -- Шаг 1: Подготовка
    showProgress(1, 8, "Подготовка к установке...")
    local backupDir = backupOriginalSystem()
    print("Backup создан в: " .. backupDir)
    
    -- Шаг 2: Загрузка ОС
    showProgress(2, 8, "Загрузка Asmelit OS...")
    if internet then
        local ok, err = downloadFile("os.lua", "/os.lua")
        if ok then
            print("✓ ОС загружена")
        else
            print("⚠ Ошибка загрузки ОС: " .. err)
            print("  Используем локальную копию если есть...")
        end
    end
    
    -- Шаг 3: Загрузка дополнительных файлов
    showProgress(3, 8, "Загрузка дополнительных файлов...")
    local files_to_download = {
        "logo.lua",
        "run.lua",
        "installer.lua",
        "bootloader.lua"
    }
    
    for _, file in ipairs(files_to_download) do
        if internet then
            downloadFile(file, "/" .. file)
        end
    end
    
    -- Шаг 4: Создание init.lua
    showProgress(4, 8, "Создание системного загрузчика...")
    createInitLoader()
    
    -- Шаг 5: Создание структуры папок
    showProgress(5, 8, "Создание структуры папок...")
    createDirectoryStructure()
    
    -- Шаг 6: Создание файла автозапуска
    showProgress(6, 8, "Настройка автозапуска...")
    local startup_code = [[
-- Asmelit OS Startup
print("Asmelit OS v2.1")
print("System ready")
]]
    
    local startup = io.open("/home/startup.lua", "w")
    if startup then
        startup:write(startup_code)
        startup:close()
    end
    
    -- Шаг 7: Создание файла конфигурации
    showProgress(7, 8, "Создание конфигурации...")
    local config_code = [[
-- Asmelit OS Configuration
config = {
    version = "2.1",
    autologin = true,
    gui_enabled = true,
    shell = "/bin/bash.lua"
}
]]
    
    local config = io.open("/home/config/system.cfg", "w")
    if config then
        config:write(config_code)
        config:close()
    end
    
    -- Шаг 8: Завершение
    showProgress(8, 8, "Завершение установки...")
    
    -- Финальный экран
    drawHeader("УСТАНОВКА ЗАВЕРШЕНА")
    
    gpu.setBackground(0x000022)
    gpu.setForeground(0x00FF00)
    gpu.fill(1, 3, w, h-3, " ")
    
    gpu.set(centerX - 10, centerY - 4, "╔══════════════════════════════╗")
    gpu.set(centerX - 10, centerY - 3, "║    УСТАНОВКА УСПЕШНА!       ║")
    gpu.set(centerX - 10, centerY - 2, "╠══════════════════════════════╣")
    gpu.set(centerX - 10, centerY - 1, "║  Asmelit OS v2.1 установлен  ║")
    gpu.set(centerX - 10, centerY,     "║                              ║")
    gpu.set(centerX - 10, centerY + 1, "║  Перезагрузите компьютер    ║")
    gpu.set(centerX - 10, centerY + 2, "║  для запуска новой системы  ║")
    gpu.set(centerX - 10, centerY + 3, "╚══════════════════════════════╝")
    
    gpu.setForeground(0xFFFFFF)
    gpu.set(centerX - 15, centerY + 6, "Backup оригинальной системы в: " .. backupDir)
    
    if not internet then
        gpu.setForeground(0xFFFF00)
        gpu.set(centerX - 12, centerY + 8, "⚠ Установка без интернета - проверьте файлы!")
    end
    
    gpu.setForeground(0xAAAAAA)
    gpu.set(centerX - 20, h - 2, "Нажмите любую клавишу для выхода в меню...")
    
    event.pull("key_down")
    
    -- Меню после установки
    gpu.setBackground(0x000033)
    gpu.setForeground(0xFFFFFF)
    term.clear()
    
    drawHeader("ASMELIT INSTALLER - МЕНЮ")
    
    gpu.set(centerX - 15, centerY - 2, "Установка завершена!")
    gpu.set(centerX - 15, centerY, "Выберите действие:")
    gpu.set(centerX - 15, centerY + 2, "1. Перезагрузить сейчас")
    gpu.set(centerX - 15, centerY + 3, "2. Запустить Asmelit OS")
    gpu.set(centerX - 15, centerY + 4, "3. Выйти в оболочку")
    gpu.set(centerX - 15, centerY + 5, "4. Проверить установку")
    
    gpu.set(centerX - 15, centerY + 7, "Выбор [1-4]: ")
    
    local choice = io.read()
    
    if choice == "1" then
        print("Перезагрузка...")
        os.sleep(2)
        computer.shutdown(true)
    elseif choice == "2" then
        -- Запустить ОС напрямую
        if fs.exists("/os.lua") then
            dofile("/os.lua")
        else
            print("ОС не найдена!")
            os.sleep(2)
            require("shell").execute()
        end
    elseif choice == "3" then
        require("shell").execute()
    elseif choice == "4" then
        -- Проверка установки
        term.clear()
        print("=== ПРОВЕРКА УСТАНОВКИ ===")
        print("1. init.lua: " .. (fs.exists("/init.lua") and "✓" or "✗"))
        print("2. os.lua: " .. (fs.exists("/os.lua") and "✓ (" .. fs.size("/os.lua") .. " bytes)" or "✗"))
        print("3. Структура папок: " .. (fs.exists("/home/user") and "✓" or "✗"))
        print("4. Backup: " .. backupDir)
        print("\nНажмите любую клавишу...")
        io.read()
        require("shell").execute()
    else
        require("shell").execute()
    end
end

-- Запуск установщика
gpu.setBackground(0x000000)
gpu.setForeground(0xFFFFFF)
term.clear()

drawHeader("ASMELIT SYSTEM INSTALLER v2.0")

gpu.set(centerX - 15, centerY - 4, "Добро пожаловать в установщик Asmelit OS!")
gpu.set(centerX - 15, centerY - 2, "Этот установщик:")
gpu.set(centerX - 15, centerY - 1, "1. Скачает и установит Asmelit OS")
gpu.set(centerX - 15, centerY,     "2. Заменит системный загрузчик (init.lua)")
gpu.set(centerX - 15, centerY + 1, "3. Создаст структуру папок")
gpu.set(centerX - 15, centerY + 2, "4. Настроит автозапуск")

if not internet then
    gpu.setForeground(0xFFFF00)
    gpu.set(centerX - 15, centerY + 4, "⚠ ВНИМАНИЕ: Нет интернет-соединения!")
    gpu.set(centerX - 15, centerY + 5, "   Установка будет произведена только из")
    gpu.set(centerX - 15, centerY + 6, "   локальных файлов, если они есть.")
    gpu.setForeground(0xFFFFFF)
end

gpu.set(centerX - 15, centerY + 8, "Продолжить установку? (y/n)")
gpu.set(centerX - 15, centerY + 9, "> ")

local answer = io.read()

if answer:lower() == "y" then
    local ok, err = pcall(mainInstallation)
    if not ok then
        gpu.setBackground(0xFF0000)
        gpu.setForeground(0xFFFFFF)
        term.clear()
        gpu.set(1, 1, "ОШИБКА УСТАНОВКИ!")
        gpu.set(1, 3, tostring(err))
        gpu.set(1, 5, "Нажмите любую клавишу для выхода в оболочку...")
        event.pull("key_down")
        require("shell").execute()
    end
else
    print("Установка отменена.")
    require("shell").execute()
end
