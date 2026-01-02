-- init.lua - минимальный загрузчик для нашей системы
local component = require("component")
local computer = require("computer")
local fs = require("filesystem")

-- Инициализация
local gpu = component.gpu
local screen = component.list("screen")()
if gpu and screen then
    gpu.bind(screen)
    gpu.setBackground(0x000000)
    gpu.setForeground(0x00FF00)
    gpu.fill(1, 1, 80, 25, " ")
    gpu.set(35, 10, "ASMELIT OS")
    gpu.set(33, 12, "Loading...")
end

-- Загружаем нашу систему
local function loadSystem()
    local paths = {"/run.lua", "/home/run.lua", "/os.lua"}
    for _, path in ipairs(paths) do
        if fs.exists(path) then
            local file = io.open(path, "r")
            if file then
                local code = file:read("*a")
                file:close()
                if #code > 100 then
                    local func, err = load(code, "=boot")
                    if func then
                        return func
                    end
                end
            end
        end
    end
    return nil
end

-- Запуск
local system = loadSystem()
if system then
    system()
else
    -- Аварийный режим
    if gpu then
        gpu.setForeground(0xFF0000)
        gpu.set(30, 15, "SYSTEM NOT FOUND!")
    end
    os.sleep(3)
    computer.shutdown(true)
end
