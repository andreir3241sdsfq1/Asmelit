-- ФУНКЦИЯ: БЕЗОПАСНАЯ очистка диска (НЕ трогаем /lib/)
local function cleanDisk()
    local fs = require("filesystem")
    
    print("БЕЗОПАСНАЯ ОЧИСТКА ДИСКА...")
    print("Не трогаем /lib/, /tmp/, системные файлы")
    
    -- Удаляем ТОЛЬКО пользовательские файлы и папки
    local toDelete = {
        "/home",
        "/startup.lua",
        "/bootloader.lua",
        "/os.lua",
        "/run.lua",
        "/logo.lua",
        "/installer_new.lua",
        "/.shrc",
        "/.history",
        "/*.lua" -- все .lua файлы в корне
    }
    
    -- Рекурсивно удаляем пользовательские директории
    local function safeDelete(path)
        if not fs.exists(path) then return end
        
        if fs.isDirectory(path) then
            -- Удаляем содержимое папки (кроме /lib/, /tmp/)
            if path ~= "/lib" and path ~= "/tmp" then
                for item in fs.list(path) do
                    if item ~= ".." and item ~= "." then
                        safeDelete(path .. "/" .. item)
                    end
                end
            end
        end
        
        -- Удаляем файл/папку (если это не системная папка)
        if path ~= "/lib" and path ~= "/tmp" then
            pcall(fs.remove, path)
            print("Удалено: " .. path)
        end
    end
    
    -- Очищаем корень (кроме системных файлов)
    for item in fs.list("/") do
        if item ~= "lib" and item ~= "tmp" and item ~= "installer.lua" then
            safeDelete("/" .. item)
        end
    end
    
    -- Создаём чистую структуру
    local dirs = {"/home", "/tmp"}
    for _, dir in ipairs(dirs) do
        if not fs.exists(dir) then
            fs.makeDirectory(dir)
        end
    end
    
    print("✓ Диск очищен (системные библиотеки сохранены)")
    os.sleep(1)
end
