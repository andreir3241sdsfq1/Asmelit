-- =====================================================
-- Asmelit MINIMAL BIOS Bootloader
-- Загружается из EEPROM (4KB максимум!)
-- =====================================================

local component = require("component")
local computer = require("computer")
local event = require("event")

-- 1. Проверка диска
local fs = require("filesystem")
if not fs.exists("/home/startup.lua") then
    -- Если ОС нет, запускаем установщик
    local internet = component.internet
    if internet then
        local i = require("internet")
        local h = i.request("https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/refs/heads/main/minimal_installer.lua")
        local code = ""
        for chunk in h do code = code .. chunk end
        local f = io.open("/home/startup.lua", "w")
        f:write(code)
        f:close()
    else
        print("Нет интернета. Вставьте диск с ОС.")
        event.pull("key_down")
        computer.shutdown()
        return
    end
end

-- 2. Загрузка ОС с диска
local file = io.open("/home/startup.lua", "r")
local os_code = file:read("*a")
file:close()

-- 3. Запуск ОС
local func, err = load(os_code, "=AsmelitOS")
if func then
    func()
else
    print("Ошибка загрузки ОС:", err)
    computer.beep(1000, 2)
    event.pull(5)
    computer.shutdown(true)
end
