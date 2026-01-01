-- =====================================================
-- Asmelit EEPROM Flasher
-- Прошивает наш загрузчик в EEPROM
-- =====================================================

local component = require("component")
local computer = require("computer")
local fs = require("filesystem")
local term = require("term")
local gpu = component.gpu

-- Проверяем EEPROM
if not component.isAvailable("eeprom") then
    print("ОШИБКА: Нет EEPROM!")
    print("Вставьте EEPROM в компьютер")
    computer.beep(1000, 2)
    return
end

local eeprom = component.eeprom

-- URL нашего бутлоадера для EEPROM
local BOOTLOADER_URL = "https://raw.githubusercontent.com/andreir3241sdsfq1/Asmelit/refs/heads/main/biosbootloader.lua"

-- Цветной интерфейс
gpu.setBackground(0x000033)
gpu.setForeground(0xFFFFFF)
term.clear()

local maxWidth, maxHeight = gpu.getResolution()
local centerX = math.floor(maxWidth / 2)

gpu.set(centerX - 10, 3, "ASMELIT EEPROM FLASHER")
gpu.set(centerX - 20, 5, "=" .. string.rep("=", 40) .. "=")

-- Варианты прошивки
local options = {
    {text = "Прошить EEPROM (скачать с GitHub)", action = "flash_online"},
    {text = "Прошить EEPROM (из файла)", action = "flash_file"},
    {text = "Прочитать текущую прошивку", action = "read"},
    {text = "Очистить EEPROM", action = "clear"},
    {text = "Выход", action = "exit"}
}

local selected = 1
local event = require("event")

while true do
    -- Отрисовка меню
    local y = 8
    for i, option in ipairs(options) do
        if i == selected then
            gpu.setBackground(0x00AA00)
            gpu.setForeground(0x000000)
        else
            gpu.setBackground(0x000033)
            gpu.setForeground(0xFFFFFF)
        end
        
        gpu.fill(centerX - 25, y, 50, 1, " ")
        gpu.set(centerX - 23, y, (i == selected and "▶ " or "  ") .. option.text)
        y = y + 2
    end
    
    -- Статус EEPROM
    gpu.setBackground(0x000033)
    gpu.setForeground(0xAAAAAA)
    local label = eeprom.getLabel() or "Без метки"
    gpu.set(centerX - 15, maxHeight - 5, "EEPROM: " .. label)
    gpu.set(centerX - 15, maxHeight - 4, "Размер: " .. #(eeprom.get() or "") .. " байт")
    
    -- Подсказка
    local help = "↑↓ - Выбор | Enter - Подтвердить | ESC - Выход"
    gpu.set(centerX - math.floor(#help / 2), maxHeight - 2, help)
    
    -- Обработка ввода
    local eventType, _, char, code = event.pull()
    
    if eventType == "key_down" then
        if code == 200 then -- Up
            selected = selected > 1 and selected - 1 or #options
        elseif code == 208 then -- Down
            selected = selected < #options and selected + 1 or 1
        elseif code == 28 then -- Enter
            local action = options[selected].action
            
            if action == "flash_online" then
                -- Скачивание с GitHub
                if component.isAvailable("internet") then
                    local internet = require("internet")
                    
                    gpu.setBackground(0x000033)
                    gpu.setForeground(0x00FF00)
                    term.clear()
                    gpu.set(centerX - 15, centerY, "Скачиваю прошивку...")
                    
                    local handle, err = internet.request(BOOTLOADER_URL)
                    if handle then
                        local code = ""
                        for chunk in handle do
                            code = code .. chunk
                        end
                        
                        gpu.set(centerX - 15, centerY + 2, "Прошиваю EEPROM...")
                        
                        -- Прошиваем EEPROM
                        eeprom.set(code)
                        eeprom.setLabel("Asmelit BIOS")
                        
                        gpu.setForeground(0x00FF00)
                        gpu.set(centerX - 15, centerY + 4, "УСПЕХ! EEPROM прошит")
                        gpu.set(centerX - 15, centerY + 5, "Размер: " .. #code .. " байт")
                    else
                        gpu.setForeground(0xFF0000)
                        gpu.set(centerX - 15, centerY + 2, "ОШИБКА: " .. (err or "неизвестно"))
                    end
                    
                    gpu.set(centerX - 15, centerY + 7, "Нажмите любую клавишу...")
                    event.pull("key_down")
                else
                    gpu.setBackground(0x000033)
                    gpu.setForeground(0xFF0000)
                    term.clear()
                    gpu.set(centerX - 15, centerY, "ОШИБКА: Нет интернет-карты!")
                    os.sleep(3)
                end
                
            elseif action == "flash_file" then
                -- Прошивка из файла
                gpu.setBackground(0x000033)
                gpu.setForeground(0xFFFFFF)
                term.clear()
                gpu.set(centerX - 15, centerY, "Введите путь к файлу:")
                gpu.set(centerX - 15, centerY + 1, "> ")
                
                local path = io.read()
                if fs.exists(path) then
                    local file = io.open(path, "r")
                    local code = file:read("*a")
                    file:close()
                    
                    eeprom.set(code)
                    eeprom.setLabel("Asmelit BIOS")
                    
                    gpu.setForeground(0x00FF00)
                    gpu.set(centerX - 15, centerY + 3, "EEPROM прошит успешно!")
                    gpu.set(centerX - 15, centerY + 4, "Нажмите любую клавишу...")
                    event.pull("key_down")
                else
                    gpu.setForeground(0xFF0000)
                    gpu.set(centerX - 15, centerY + 3, "Файл не найден!")
                    os.sleep(2)
                end
                
            elseif action == "read" then
                -- Чтение EEPROM
                local code = eeprom.get()
                local label = eeprom.getLabel()
                
                gpu.setBackground(0x000033)
                gpu.setForeground(0xFFFFFF)
                term.clear()
                
                gpu.set(1, 1, "EEPROM информация:")
                gpu.set(1, 3, "Метка: " .. (label or "нет"))
                gpu.set(1, 4, "Размер: " .. #code .. " байт")
                gpu.set(1, 6, "Первые 500 символов:")
                gpu.set(1, 7, code:sub(1, 500))
                
                gpu.set(1, maxHeight - 1, "Нажмите любую клавишу...")
                event.pull("key_down")
                
            elseif action == "clear" then
                -- Очистка EEPROM
                eeprom.set("")
                eeprom.setLabel("")
                computer.beep(500, 1)
                
            elseif action == "exit" then
                computer.shutdown()
            end
            
            -- После действия перерисовываем
            gpu.setBackground(0x000033)
            gpu.setForeground(0xFFFFFF)
            term.clear()
            
        elseif code == 1 then -- ESC
            computer.shutdown()
        end
    end
end
