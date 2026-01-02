-- monitor.lua - Системный монитор для Asmelit OS
local component = require("component")
local computer = require("computer")
local event = require("event")
local term = require("term")
local gpu = component.gpu
local fs = require("filesystem")

local w, h = gpu.getResolution()
local cx = math.floor(w / 2)
local cy = math.floor(h / 2)

local memoryHistory = {}
local cpuHistory = {}
local maxHistory = 50
local updateInterval = 1 -- секунда
local lastUpdate = computer.uptime()

function drawMonitor()
    gpu.setBackground(0x001122)
    gpu.setForeground(0xFFFFFF)
    term.clear()
    
    -- Заголовок
    gpu.setBackground(0x003366)
    gpu.fill(1, 1, w, 1, " ")
    gpu.set(2, 1, "📊 СИСТЕМНЫЙ МОНИТОР")
    
    -- Время
    local time = os.date("%H:%M:%S")
    gpu.set(w - #time - 1, 1, time)
    
    -- Основная информация
    local startY = 3
    
    -- Память
    local totalMem = computer.totalMemory()
    local freeMem = computer.freeMemory()
    local usedMem = totalMem - freeMem
    local memPercent = math.floor((usedMem / totalMem) * 100)
    
    gpu.setForeground(0x00AAFF)
    gpu.set(2, startY, "ПАМЯТЬ:")
    gpu.setForeground(0xFFFFFF)
    gpu.set(10, startY, string.format("Использовано: %d/%d байт (%d%%)", usedMem, totalMem, memPercent))
    
    -- График памяти
    drawBar(2, startY + 1, w - 4, memPercent, 0x00AAFF, "Память")
    
    -- Энергия (если есть)
    if computer.maxEnergy() > 0 then
        local energyPercent = math.floor((computer.energy() / computer.maxEnergy()) * 100)
        gpu.setForeground(0x00FF00)
        gpu.set(2, startY + 3, "ЭНЕРГИЯ:")
        gpu.setForeground(0xFFFFFF)
        gpu.set(10, startY + 3, string.format("%d/%d (%d%%)", computer.energy(), computer.maxEnergy(), energyPercent))
        drawBar(2, startY + 4, w - 4, energyPercent, 0x00FF00, "Энергия")
        startY = startY + 5
    else
        startY = startY + 3
    end
    
    -- Диски
    gpu.setForeground(0xFFAA00)
    gpu.set(2, startY, "ДИСКИ:")
    startY = startY + 1
    
    local driveCount = 0
    for addr in component.list("drive") do
        local proxy = component.proxy(addr)
        if proxy then
            driveCount = driveCount + 1
            local capacity = proxy.capacity() or 0
            local used = proxy.spaceUsed() or 0
            local free = capacity - used
            local percent = capacity > 0 and math.floor((used / capacity) * 100) or 0
            
            local label = proxy.getLabel() or "Диск " .. driveCount
            if #label > 15 then label = label:sub(1, 12) .. "..." end
            
            gpu.setForeground(0xFFFFFF)
            gpu.set(4, startY, label .. ":")
            gpu.set(20, startY, string.format("%dK/%dK (%d%%)", math.floor(used/1024), math.floor(capacity/1024), percent))
            
            drawBar(2, startY + 1, w - 4, percent, 0xFFAA00, "")
            
            startY = startY + 3
        end
    end
    
    if driveCount == 0 then
        gpu.setForeground(0xAAAAAA)
        gpu.set(4, startY, "Диски не обнаружены")
        startY = startY + 2
    end
    
    -- Компоненты
    gpu.setForeground(0xFF55FF)
    gpu.set(2, startY, "КОМПОНЕНТЫ:")
    startY = startY + 1
    
    local compY = startY
    local compX = 2
    local compCount = 0
    
    for type, count in pairs(getComponentCount()) do
        gpu.setForeground(0xFFFFFF)
        gpu.set(compX, compY, type .. ": " .. count)
        
        compX = compX + 20
        if compX > w - 20 then
            compX = 2
            compY = compY + 1
        end
        compCount = compCount + 1
    end
    
    if compCount == 0 then
        gpu.setForeground(0xAAAAAA)
        gpu.set(4, compY, "Компоненты не обнаружены")
    end
    
    -- График использования памяти во времени
    if #memoryHistory > 5 then
        drawGraph(2, h - 10, w - 4, 8, memoryHistory, 0x00AAFF, "Использование памяти")
    end
    
    -- Подсказка
    gpu.setBackground(0x003366)
    gpu.setForeground(0xFFFFFF)
    gpu.fill(1, h, w, 1, " ")
    gpu.set(2, h, "F5-Обновить | ESC-Выход | Автообновление каждую секунду")
end

function drawBar(x, y, width, percent, color, label)
    gpu.setBackground(0x333333)
    gpu.fill(x, y, width, 1, " ")
    
    local fillWidth = math.floor(width * percent / 100)
    if fillWidth > 0 then
        gpu.setBackground(color)
        gpu.fill(x, y, fillWidth, 1, "█")
    end
    
    gpu.setBackground(0x001122)
    gpu.setForeground(0xFFFFFF)
    if label ~= "" then
        gpu.set(x + math.floor((width - #label) / 2), y, label)
    end
end

function drawGraph(x, y, width, height, data, color, title)
    if #data < 2 then return end
    
    -- Заголовок
    gpu.setForeground(color)
    gpu.set(x, y - 1, title)
    
    -- Рамка
    gpu.setForeground(0x666666)
    gpu.set(x, y, "┌" .. string.rep("─", width - 2) .. "┐")
    gpu.set(x, y + height, "└" .. string.rep("─", width - 2) .. "┘")
    for i = 1, height - 1 do
        gpu.set(x, y + i, "│")
        gpu.set(x + width - 1, y + i, "│")
    end
    
    -- Находим максимум
    local maxValue = 0
    for _, value in ipairs(data) do
        if value > maxValue then maxValue = value end
    end
    if maxValue == 0 then maxValue = 1 end
    
    -- Рисуем график
    local points = {}
    for i, value in ipairs(data) do
        local pointX = x + 1 + math.floor((i - 1) * (width - 2) / (#data - 1))
        local pointY = y + height - 1 - math.floor((value / maxValue) * (height - 2))
        table.insert(points, {pointX, pointY})
    end
    
    for i = 1, #points - 1 do
        local x1, y1 = points[i][1], points[i][2]
        local x2, y2 = points[i+1][1], points[i+1][2]
        
        -- Линия
        gpu.setForeground(color)
        if y1 == y2 then
            gpu.fill(math.min(x1, x2), y1, math.abs(x2 - x1) + 1, 1, "─")
        else
            -- Простая аппроксимация
            local steps = math.max(math.abs(x2 - x1), math.abs(y2 - y1))
            for s = 0, steps do
                local px = math.floor(x1 + (x2 - x1) * s / steps)
                local py = math.floor(y1 + (y2 - y1) * s / steps)
                gpu.set(px, py, "·")
            end
        end
    end
    
    -- Подписи
    gpu.setForeground(0xAAAAAA)
    gpu.set(x + 1, y + height + 1, "0%")
    gpu.set(x + width - 3, y + height + 1, "100%")
end

function getComponentCount()
    local counts = {}
    for type in component.list() do
        counts[type] = (counts[type] or 0) + 1
    end
    return counts
end

function updateData()
    local totalMem = computer.totalMemory()
    local freeMem = computer.freeMemory()
    local usedMem = totalMem - freeMem
    local memPercent = math.floor((usedMem / totalMem) * 100)
    
    table.insert(memoryHistory, memPercent)
    if #memoryHistory > maxHistory then
        table.remove(memoryHistory, 1)
    end
    
    -- Простая "загрузка CPU"
    local uptime = computer.uptime()
    local idleTime = uptime - lastUpdate
    local cpuLoad = math.min(100, math.floor(idleTime * 10)) -- Простая эмуляция
    table.insert(cpuHistory, cpuLoad)
    if #cpuHistory > maxHistory then
        table.remove(cpuHistory, 1)
    end
    
    lastUpdate = uptime
end

function main()
    -- Инициализация истории
    for i = 1, maxHistory do
        table.insert(memoryHistory, 0)
        table.insert(cpuHistory, 0)
    end
    
    local lastDraw = 0
    
    while true do
        local currentTime = computer.uptime()
        
        -- Обновляем данные каждую секунду
        if currentTime - lastUpdate >= updateInterval then
            updateData()
        end
        
        -- Перерисовываем каждые 0.5 секунды
        if currentTime - lastDraw >= 0.5 then
            drawMonitor()
            lastDraw = currentTime
        end
        
        -- Обработка событий
        local e = {event.pull(0.1)}
        
        if e[1] == "key_down" then
            local code = e[4]
            
            if code == 1 then -- ESC
                break
                
            elseif code == 63 then -- F5
                updateData()
                drawMonitor()
            end
        end
    end
end

main()
