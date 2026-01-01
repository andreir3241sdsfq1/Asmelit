-- =====================================================
-- Asmelit MINIMAL BIOS Bootloader
-- ЗАГРУЗЧИК ДЛЯ EEPROM (работает до загрузки библиотек)
-- =====================================================

-- В EEPROM require() недоступен! Используем component.* напрямую
local component = _G.component or _G.components
local computer = _G.computer
local event = _G.event

-- 1. Инициализация самого необходимого
if not component then
    -- Если даже component нет, показываем ошибку и ждем
    _G.print = _G.print or function(...)
        local args = {...}
        for i=1, #args do
            io.write(tostring(args[i]) .. (i < #args and "\t" or "\n"))
        end
    end
    
    print("ERROR: No component API")
    print("Wait for key...")
    if event then
        event.pull("key_down")
    end
    return
end

-- 2. Ищем диск с ОС
local function findOSDisk()
    -- Ищем через низкоуровневый доступ к компонентам
    local disks = component.list("drive")()
    if disks then
        -- Монтируем первый диск
        local addr, type = disks()
        if addr then
            -- Пытаемся прочитать startup.lua
            local proxy = component.proxy(addr)
            if proxy and proxy.read then
                -- Читаем сектор
                local data = proxy.read(0) -- или другой метод чтения
                if data then
                    return data
                end
            end
        end
    end
    return nil
end

-- 3. Основная загрузка
function main()
    -- Минимальный вывод
    local gpu = component.gpu
    if gpu then
        gpu.set(1, 1, "Asmelit BIOS v1.0")
        gpu.set(1, 2, "Memory: " .. (computer and computer.totalMemory() or "unknown"))
    else
        print("Asmelit BIOS v1.0")
    end
    
    -- Ищем ОС
    local osCode = findOSDisk()
    
    if not osCode then
        -- Нет ОС - показываем меню
        if gpu then
            gpu.set(1, 4, "No OS found!")
            gpu.set(1, 5, "F1 - Install from internet")
            gpu.set(1, 6, "F2 - Boot from floppy")
        else
            print("No OS found!")
            print("F1 - Install from internet")
            print("F2 - Boot from floppy")
        end
        
        -- Ждём выбора
        local _, _, _, code = event.pull("key_down")
        
        if code == 59 then -- F1
            installFromInternet()
        else
            computer.shutdown(true)
        end
    else
        -- ОС найдена - запускаем
        if gpu then gpu.set(1, 4, "Loading OS...") end
        load(osCode)()
    end
end

-- 4. Установка через интернет (только если есть карта)
function installFromInternet()
    local internet = component.internet
    if not internet then
        if gpu then
            gpu.set(1, 8, "No internet card!")
        else
            print("No internet card!")
        end
        event.pull(3)
        return
    end
    
    -- Здесь код скачивания
    -- Но в EEPROM это сложно, лучше оставить минимальный BIOS
    if gpu then
        gpu.set(1, 8, "Install via flasher.lua")
    end
end

-- 5. Запускаем с защитой
local ok, err = pcall(main)
if not ok then
    -- Минимальный вывод ошибки
    if gpu then
        gpu.set(1, 10, "BIOS ERROR: " .. tostring(err))
    else
        print("BIOS ERROR: " .. tostring(err))
    end
    event.pull(5)
end

computer.shutdown(true)
