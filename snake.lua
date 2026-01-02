-- snake.lua - Игра Змейка для Asmelit OS
local component = require("component")
local computer = require("computer")
local event = require("event")
local term = require("term")
local gpu = component.gpu

local w, h = gpu.getResolution()
local cx = math.floor(w / 2)
local cy = math.floor(h / 2)

local snake = {}
local food = {x = 0, y = 0}
local direction = "right"
local nextDirection = "right"
local score = 0
local gameOver = false
local gameSpeed = 0.2
local lastUpdate = computer.uptime()
local boardWidth = 20
local boardHeight = 15

function initGame()
    snake = {
        {x = 5, y = 8},
        {x = 4, y = 8},
        {x = 3, y = 8}
    }
    direction = "right"
    nextDirection = "right"
    score = 0
    gameOver = false
    placeFood()
end

function placeFood()
    local placed = false
    while not placed do
        food.x = math.random(1, boardWidth)
        food.y = math.random(1, boardHeight)
        
        placed = true
        for _, segment in ipairs(snake) do
            if segment.x == food.x and segment.y == food.y then
                placed = false
                break
            end
        end
    end
end

function drawGame()
    gpu.setBackground(0x001122)
    gpu.setForeground(0xFFFFFF)
    term.clear()
    
    -- Заголовок
    gpu.setBackground(0x003366)
    gpu.fill(1, 1, w, 1, " ")
    gpu.set(2, 1, "🐍 ЗМЕЙКА")
    gpu.set(w - 20, 1, "Счёт: " .. score)
    
    -- Игровое поле
    local boardX = cx - math.floor(boardWidth / 2)
    local boardY = cy - math.floor(boardHeight / 2)
    
    -- Рамка поля
    gpu.setForeground(0x00FF00)
    gpu.set(boardX - 1, boardY - 1, "╔" .. string.rep("═", boardWidth) .. "╗")
    gpu.set(boardX - 1, boardY + boardHeight, "╚" .. string.rep("═", boardWidth) .. "╝")
    for i = 0, boardHeight - 1 do
        gpu.set(boardX - 1, boardY + i, "║")
        gpu.set(boardX + boardWidth, boardY + i, "║")
    end
    
    -- Еда
    gpu.setForeground(0xFF0000)
    gpu.set(boardX + food.x - 1, boardY + food.y - 1, "●")
    
    -- Змейка
    for i, segment in ipairs(snake) do
        if i == 1 then -- Голова
            gpu.setForeground(0x00FF00)
            local headChar = "○"
            if direction == "up" then headChar = "↑"
            elseif direction == "down" then headChar = "↓"
            elseif direction == "left" then headChar = "←"
            elseif direction == "right" then headChar = "→" end
            gpu.set(boardX + segment.x - 1, boardY + segment.y - 1, headChar)
        else -- Тело
            gpu.setForeground(0x00AA00)
            gpu.set(boardX + segment.x - 1, boardY + segment.y - 1, "■")
        end
    end
    
    -- Сообщение
    if gameOver then
        gpu.setForeground(0xFF0000)
        gpu.set(cx - 10, boardY + boardHeight + 2, "ИГРА ОКОНЧЕНА! Счёт: " .. score)
        gpu.set(cx - 10, boardY + boardHeight + 3, "Нажмите Enter для новой игры")
    end
    
    -- Подсказка
    gpu.setBackground(0x003366)
    gpu.setForeground(0xFFFFFF)
    gpu.fill(1, h, w, 1, " ")
    gpu.set(2, h, "Стрелки - управление | R - перезапуск | ESC - выход")
end

function updateGame()
    if gameOver then return end
    
    local currentTime = computer.uptime()
    if currentTime - lastUpdate < gameSpeed then
        return
    end
    
    lastUpdate = currentTime
    
    -- Обновляем направление
    direction = nextDirection
    
    -- Новая позиция головы
    local newHead = {x = snake[1].x, y = snake[1].y}
    
    if direction == "up" then
        newHead.y = newHead.y - 1
    elseif direction == "down" then
        newHead.y = newHead.y + 1
    elseif direction == "left" then
        newHead.x = newHead.x - 1
    elseif direction == "right" then
        newHead.x = newHead.x + 1
    end
    
    -- Проверка столкновения со стеной
    if newHead.x < 1 or newHead.x > boardWidth or 
       newHead.y < 1 or newHead.y > boardHeight then
        gameOver = true
        return
    end
    
    -- Проверка столкновения с собой
    for i, segment in ipairs(snake) do
        if newHead.x == segment.x and newHead.y == segment.y then
            gameOver = true
            return
        end
    end
    
    -- Добавляем новую голову
    table.insert(snake, 1, newHead)
    
    -- Проверка поедания еды
    if newHead.x == food.x and newHead.y == food.y then
        score = score + 10
        placeFood()
        -- Увеличиваем скорость каждые 50 очков
        if score % 50 == 0 and gameSpeed > 0.05 then
            gameSpeed = gameSpeed - 0.02
        end
    else
        -- Удаляем хвост если не съели еду
        table.remove(snake)
    end
end

function main()
    initGame()
    
    while true do
        updateGame()
        drawGame()
        
        -- Обработка ввода
        local e = {event.pull(0.05)} -- Небольшая задержка для плавности
        
        if e[1] == "key_down" then
            local code = e[4]
            
            if code == 1 then -- ESC
                break
                
            elseif code == 200 then -- Up
                if direction ~= "down" then
                    nextDirection = "up"
                end
                
            elseif code == 208 then -- Down
                if direction ~= "up" then
                    nextDirection = "down"
                end
                
            elseif code == 203 then -- Left
                if direction ~= "right" then
                    nextDirection = "left"
                end
                
            elseif code == 205 then -- Right
                if direction ~= "left" then
                    nextDirection = "right"
                end
                
            elseif code == 28 then -- Enter
                if gameOver then
                    initGame()
                end
                
            elseif e[3] == "r" or e[3] == "R" or e[3] == "к" or e[3] == "К" then
                initGame()
            end
        end
    end
end

main()
