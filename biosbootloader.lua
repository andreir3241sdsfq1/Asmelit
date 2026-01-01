-- Asmelit BIOS v1.0 (ULTRA-MINIMAL)

local c = _G.component
local comp = _G.computer

-- 1. Инициализация (5 строк)
if not c then
    comp.beep(1000, 1)
    comp.shutdown(true)
    return
end

-- 2. Очистка экрана (3 строки)
local g = c.gpu
if g then
    g.setBackground(0x000000)
    g.fill(1, 1, 80, 25, " ")
    g.set(35, 1, "[ BIOS ]")
end

-- 3. Поиск ОС (8 строк)
local function boot()
    local disks = c.list("drive")()
    if disks then
        for addr in disks do
            local proxy = c.proxy(addr)
            if proxy and proxy.exists and proxy.exists("/startup.lua") then
                local file = proxy.open("/startup.lua", "r")
                if file then
                    local code = file.read(math.huge) -- читаем всё
                    file.close()
                    if code and #code > 10 then
                        local ok, err = load(code, "=boot")
                        if ok then ok() end
                    end
                end
            end
        end
    end
end

-- 4. Меню (10 строк)
function menu()
    if g then
        g.set(30, 10, "1. Boot from disk")
        g.set(30, 11, "2. Reboot")
    else
        print("1. Boot\n2. Reboot")
    end
    
    local e = {_G.event.pull()}
    if e[1] == "key_down" then
        if e[4] == 2 then -- '1'
            boot()
        else
            comp.shutdown(true)
        end
    end
end

-- 5. Запуск (3 строки)
local ok, err = pcall(menu)
if not ok and g then g.set(1, 20, "Err:" .. tostring(err):sub(1, 30)) end
_G.event.pull(3)
comp.shutdown(true)
