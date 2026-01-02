-- Asmelit Bootloader v3.0 (загружается с диска)

local component = require("component")
local computer = require("computer")
local gpu = component.gpu
local event = require("event")

-- Загрузка и отображение лого
local function showLogo()
    -- Пробуем загрузить logo.lua
    local fs = require("filesystem")
    local logoCode = ""
    
    if fs.exists("/logo.lua") then
        local file = io.open("/logo.lua", "r")
        logoCode = file:read("*a")
        file:close()
    elseif fs.exists("/home/logo.lua") then
        local file = io.open("/home/logo.lua", "r")
        logoCode = file:read("*a")
        file:close()
    end
    
    -- Очищаем экран
    gpu.setBackground(0x000000)
    gpu.setForeground(0x00AA00)
    term.clear()
    
    -- Отображаем лого (если есть) или стандартное
    if #logoCode > 10 then
        local lines = {}
        for line in logoCode:gmatch("[^\r\n]+") do
            table.insert(lines, line)
        end
        
        local w, h = gpu.getResolution()
        local centerY = math.floor(h / 2) - math.floor(#lines / 2)
        
        for i, line in ipairs(lines) do
            local centerX = math.floor(w / 2) - math.floor(#line / 2)
            gpu.set(centerX, centerY + i, line)
        end
    else
        gpu.set(35, 10, "ASMELIT OS")
        gpu.set(33, 12, "Loading system...")
    end
    
    -- Инфо внизу
    gpu.setForeground(0xAAAAAA)
    gpu.set(1, 24, "Memory: " .. math.floor(computer.freeMemory()/1024) .. "KB")
end

-- Меню загрузки
local function bootMenu()
    showLogo()
    
    -- Ждём выбора 5 секунд
    local choice = nil
    local timer = os.startTimer(5)
    
    gpu.setForeground(0xFFFFFF)
    gpu.set(30, 18, "Press: 1-OS  2-Installer  3-Shell")
    
    while true do
        local e = {event.pull()}
        
        if e[1] == "key_down" then
            if e[3] == "1" then choice = "os" break
            elseif e[3] == "2" then choice = "installer" break
            elseif e[3] == "3" then choice = "shell" break
            end
        elseif e[1] == "timer" and e[2] == timer then
            choice = "os" -- авто-выбор ОС
            break
        end
    end
    
    -- Выполняем выбор
    if choice == "os" then
        -- Запускаем run.lua
        local fs = require("filesystem")
        local runPath = "/run.lua"
        if not fs.exists(runPath) then runPath = "/home/run.lua" end
        
        if fs.exists(runPath) then
            dofile(runPath)
        else
            -- Прямой запуск ОС
            local osPath = "/os.lua"
            if not fs.exists(osPath) then osPath = "/home/os.lua" end
            if fs.exists(osPath) then dofile(osPath) end
        end
    elseif choice == "installer" then
        local fs = require("filesystem")
        if fs.exists("/installer.lua") then
            dofile("/installer.lua")
        elseif fs.exists("/home/installer.lua") then
            dofile("/home/installer.lua")
        else
            print("Installer not found!")
        end
    elseif choice == "shell" then
        require("shell").execute()
    end
end

-- Запуск с обработкой ошибок
local ok, err = pcall(bootMenu)
if not ok then
    print("Bootloader error: " .. tostring(err))
    require("shell").execute()
end
