-- quick_launch.lua - Быстро скачать и запустить
local component = require("component")

-- Проверяем интернет
if not component.isAvailable("internet") then
    print("Нужна интернет-карта!")
    return
end

local internet = require("internet")

print("Скачиваю Asmelit OS...")
local url = "https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/main/os.lua"
local handle = internet.request(url)

if not handle then
    print("Ошибка загрузки!")
    return
end

local os_code = ""
for chunk in handle do
    os_code = os_code .. chunk
end

print("Загружено: " .. #os_code .. " байт")

-- Пробуем запустить
local func, err = load(os_code, "=AsmelitOS")
if func then
    print("Запускаю ОС...")
    func()
else
    print("Ошибка: " .. tostring(err))
    
    -- Сохраняем для отладки
    local file = io.open("/os_debug.lua", "w")
    if file then
        file:write(os_code)
        file:close()
        print("Сохранено в /os_debug.lua")
    end
end
