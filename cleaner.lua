-- =====================================================
-- Disk Cleaner - удаляет старую систему
-- =====================================================

local component = require("component")
local computer = require("computer")
local fs = require("filesystem")
local term = require("term")
local gpu = component.gpu

gpu.setBackground(0x000000)
gpu.setForeground(0xFF0000)
term.clear()

local maxWidth = gpu.getResolution()

print("⚠️  ВНИМАНИЕ: ОПАСНАЯ ОПЕРАЦИЯ ⚠️")
print("=" .. string.rep("=", maxWidth - 2) .. "=")
print("")
print("Эта программа УДАЛИТ:")
print("1. Все файлы в /home")
print("2. Все пользовательские программы")
print("3. Старую операционную систему")
print("")
print("ОСТАНЕТСЯ:")
print("- BIOS (EEPROM)")
print("- Системные библиотеки OpenComputers")
print("")
print("Продолжить? (yes/NO)")

local answer = io.read()
if answer:lower() ~= "yes" then
    print("Отменено.")
    computer.beep(500, 1)
    return
end

print("")
print("Начинаю очистку...")

-- Список файлов/папок для удаления
local toDelete = {
    "/home/startup.lua",
    "/home/installer.lua",
    "/home/logo.lua",
    "/home/user",
    "/home/apps",
    "/home/docs"
}

-- Функция безопасного удаления
local function safeRemove(path)
    if fs.exists(path) then
        local ok, err = pcall(fs.remove, path)
        if ok then
            print("✓ Удалено: " .. path)
            return true
        else
            print("✗ Ошибка: " .. path .. " - " .. tostring(err))
            return false
        end
    end
    return true
end

-- Удаляем файлы
for _, path in ipairs(toDelete) do
    safeRemove(path)
    os.sleep(0.1)
end

-- Удаляем все в /home (кроме самой папки)
if fs.exists("/home") then
    for item in fs.list("/home") do
        safeRemove("/home/" .. item)
    end
end

print("")
print("=" .. string.rep("=", maxWidth - 2) .. "=")
print("ОЧИСТКА ЗАВЕРШЕНА!")
print("")
print("Теперь можно:")
print("1. Установить Asmelit OS через BIOS")
print("2. Или запустить установщик вручную")
print("")
print("Нажмите любую клавишу для выхода...")
io.read()

computer.shutdown()
