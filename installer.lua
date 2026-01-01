-- =====================================================
-- Asmelit OS Installer v2.0
-- Устанавливает систему на диск
-- =====================================================

local component = require("component")
local computer = require("computer")
local term = require("term")
local gpu = component.gpu
local event = require("event")

-- Настройки
local maxWidth, maxHeight = gpu.getResolution()
local centerX = math.floor(maxWidth / 2)
local centerY = math.floor(maxHeight / 2)

-- URLs для загрузки
local GITHUB_BASE = "https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/refs/heads/main/"
local FILES_TO_DOWNLOAD = {
    {url = "os.lua", path = "/home/startup.lua"},
    {url = "logo.lua", path = "/home/logo.lua"},
    {url = "bootloader.lua", path = "/home/bootloader.lua"}
}

-- Загрузка файла с GitHub
local function downloadFile(url, path)
    if not component.isAvailable("internet") then
        return false, "Нет интернет-карты"
    end
    
    local internet = require("internet")
    local fs = require("filesystem")
    
    -- Создаем директорию если нужно
    local dir = path:match("(.+)/[^/]+$")
    if dir and not fs.exists(dir) then
        fs.makeDirectory(dir)
    end
    
    local ok, handle = pcall(internet.request, GITHUB_BASE .. url)
    if not ok or not handle then
        return false, "Не удалось подключиться"
    end
    
    local content = ""
    for chunk in handle do
        content = content .. chunk
        if #content > 100000 then -- Лимит 100KB
            return false, "Файл слишком большой"
        end
    end
    
    local file = io.open(path, "w")
    if not file then
        return false, "Не могу создать файл"
    end
    
    file:write(content)
    file:close()
    
    return true, #content
end

-- Отрисовка анимации установки
local function drawInstallAnimation(frame, progress, status)
    gpu.setBackground(0x000033)
    gpu.setForeground(0xFFFFFF)
    term.clear()
    
    -- Заголовок
    local title = "УСТАНОВКА ASMELIT OS"
    gpu.set(centerX - math.floor(#title / 2), 2, title)
    
    -- Анимация (простая)
    local animFrames = {
        "▌          ",
        "██         ",
        "██▌        ",
        "████       ",
        "████▌      ",
        "██████     ",
        "██████▌    ",
        "████████   ",
        "████████▌  ",
        "██████████ "
    }
    
    local frameIdx = ((frame - 1) % #animFrames) + 1
    local anim = animFrames[frameIdx]
    gpu.setForeground(0x00FF00)
    gpu.set(centerX - math.floor(#anim / 2), centerY - 2, anim)
    
    -- Статус
    gpu.setForeground(0xFFFFFF)
    gpu.set(centerX - math.floor(#status / 2), centerY, status)
    
    -- Прогресс бар
    local barWidth = math.floor(maxWidth * 0.6)
    local barX = centerX - math.floor(barWidth / 2)
    local barY = centerY + 3
    
    gpu.setBackground(0x333333)
    gpu.fill(barX, barY, barWidth, 1, "░")
    
    local filled = math.floor(barWidth * progress)
    if filled > 0 then
        gpu.setBackground(0x00FF00)
        gpu.fill(barX, barY, filled, 1, "█")
    end
    
    -- Процент
    local percent = math.floor(progress * 100)
    local percentText = percent .. "%"
    gpu.setBackground(0x000033)
    gpu.setForeground(0x00FF00)
    gpu.set(centerX - math.floor(#percentText / 2), barY + 1, percentText)
    
    -- Подсказка
    local help = "ESC - Отмена установки"
    gpu.setForeground(0xAAAAAA)
    gpu.set(centerX - math.floor(#help / 2), maxHeight - 2, help)
end

-- Главное меню
local function mainMenu()
    local selected = 1
    local menuItems = {
        {text = "Установить Asmelit OS", action = "install"},
        {text = "Обновить систему", action = "update"},
        {text = "Восстановить загрузчик", action = "repair"},
        {text = "Настройки BIOS", action = "bios"},
        {text = "Выход в оболочку", action = "shell"}
    }
    
    while true do
        gpu.setBackground(0x000033)
        gpu.setForeground(0xFFFFFF)
        term.clear()
        
        -- Заголовок
        local title = "ASMELIT OS INSTALLER v2.0"
        gpu.set(centerX - math.floor(#title / 2), 3, title)
        
        local subtitle = "Выберите действие:"
        gpu.set(centerX - math.floor(#subtitle / 2), 5, subtitle)
        
        -- Меню
        local startY = centerY - math.floor(#menuItems / 2)
        for i, item in ipairs(menuItems) do
            local x = centerX - 15
            local y = startY + i
            
            if i == selected then
                gpu.setBackground(0x00AA00)
                gpu.setForeground(0x000000)
                gpu.fill(x, y, 30, 1, " ")
                gpu.set(x, y, "▶ " .. item.text)
            else
                gpu.setBackground(0x000033)
                gpu.setForeground(0xFFFFFF)
                gpu.set(x, y, "  " .. item.text)
            end
        end
        
        -- Статус системы
        gpu.setForeground(0xAAAAAA)
        local mem = "Память: " .. computer.freeMemory() .. " байт"
        gpu.set(centerX - math.floor(#mem / 2), maxHeight - 5, mem)
        
        if computer.maxEnergy() > 0 then
            local energy = "Энергия: " .. math.floor((computer.energy() / computer.maxEnergy()) * 100) .. "%"
            gpu.set(centerX - math.floor(#energy / 2), maxHeight - 4, energy)
        end
        
        -- Подсказка
        local help = "↑↓ - Выбор | Enter - Подтвердить | ESC - Выход"
        gpu.set(centerX - math.floor(#help / 2), maxHeight - 2, help)
        
        -- Обработка ввода
        local eventType, _, char, code = event.pull()
        
        if eventType == "key_down" then
            if code == 200 then -- Up
                selected = selected > 1 and selected - 1 or #menuItems
            elseif code == 208 then -- Down
                selected = selected < #menuItems and selected + 1 or 1
            elseif code == 28 then -- Enter
                local action = menuItems[selected].action
                
                if action == "install" then
                    -- Установка
                    if not component.isAvailable("internet") then
                        gpu.setBackground(0x000033)
                        gpu.setForeground(0xFF0000)
                        term.clear()
                        gpu.set(centerX - 15, centerY, "ОШИБКА: Нет интернет-карты!")
                        os.sleep(3)
                        return
                    end
                    
                    local frame = 1
                    local totalFiles = #FILES_TO_DOWNLOAD
                    
                    for i, fileInfo in ipairs(FILES_TO_DOWNLOAD) do
                        local progress = i / totalFiles
                        local status = "Загрузка " .. fileInfo.url .. "..."
                        
                        drawInstallAnimation(frame, progress, status)
                        frame = frame + 1
                        
                        -- Проверка отмены
                        local cancel = false
                        for j = 1, 10 do
                            local e = {event.pull(0.05)}
                            if e[1] == "key_down" and e[4] == 1 then -- ESC
                                cancel = true
                                break
                            end
                        end
                        
                        if cancel then
                            gpu.set(centerX - 10, centerY + 5, "Установка отменена")
                            os.sleep(2)
                            return
                        end
                        
                        -- Загрузка файла
                        local ok, result = downloadFile(fileInfo.url, fileInfo.path)
                        if not ok then
                            gpu.setBackground(0x000033)
                            gpu.setForeground(0xFF0000)
                            gpu.set(centerX - 15, centerY + 5, "Ошибка: " .. tostring(result))
                            os.sleep(3)
                            return
                        end
                    end
                    
                    -- Установка завершена
                    drawInstallAnimation(frame, 1, "Установка завершена!")
                    
                    -- Создаем структуру папок
                    local fs = require("filesystem")
                    local dirs = {"/home/user", "/home/apps", "/home/docs", "/bin", "/lib", "/tmp"}
                    for _, dir in ipairs(dirs) do
                        if not fs.exists(dir) then
                            fs.makeDirectory(dir)
                        end
                    end
                    
                    gpu.setForeground(0x00FF00)
                    gpu.set(centerX - 20, centerY + 5, "Asmelit OS успешно установлена!")
                    gpu.set(centerX - 15, centerY + 6, "Перезагрузите компьютер")
                    
                    os.sleep(5)
                    computer.shutdown(true)
                    
                elseif action == "shell" then
                    require("shell").execute()
                else
                    -- Заглушки для других опций
                    gpu.setBackground(0x000033)
                    gpu.setForeground(0xFFFF00)
                    term.clear()
                    gpu.set(centerX - 10, centerY, "Функция в разработке")
                    os.sleep(2)
                end
                
            elseif code == 1 then -- ESC
                return
            end
        end
    end
end

-- Запуск установщика
print("Инициализация установщика...")
os.sleep(1)
mainMenu()
