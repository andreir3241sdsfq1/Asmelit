-- run.lua - Запускает лого и ОС

local component = require("component")
local computer = require("computer")
local gpu = component.gpu

-- 1. Загрузка логотипа
local function loadLogo()
    local fs = require("filesystem")
    local logoPath = "/logo.lua"
    
    if not fs.exists(logoPath) then
        logoPath = "/home/logo.lua"
    end
    
    if fs.exists(logoPath) then
        local file = io.open(logoPath, "r")
        local logo = file:read("*a")
        file:close()
        
        -- Очистка экрана и отображение лого
        gpu.setBackground(0x000000)
        gpu.setForeground(0x00FF00)
        term.clear()
        
        local lines = {}
        for line in logo:gmatch("[^\r\n]+") do
            table.insert(lines, line)
        end
        
        local w, h = gpu.getResolution()
        local startY = math.floor(h / 2) - math.floor(#lines / 2)
        
        for i, line in ipairs(lines) do
            local startX = math.floor(w / 2) - math.floor(#line / 2)
            gpu.set(startX, startY + i, line)
        end
        
        os.sleep(2) -- Показываем лого 2 секунды
    end
end

-- 2. Запуск ОС
local function startOS()
    local fs = require("filesystem")
    local osPath = "/os.lua"
    
    if not fs.exists(osPath) then
        osPath = "/home/os.lua"
    end
    
    if fs.exists(osPath) then
        -- Плавный переход
        gpu.setBackground(0x000000)
        gpu.setForeground(0x00AAFF)
        term.clear()
        gpu.set(35, 12, "Starting Asmelit OS...")
        os.sleep(1)
        
        -- Запуск ОС
        dofile(osPath)
    else
        print("OS not found! Launching shell...")
        require("shell").execute()
    end
end

-- 3. Главная последовательность
loadLogo()
startOS()
