-- sapper.lua - Игра Сапёр для Asmelit OS
local component = require("component")
local computer = require("computer")
local event = require("event")
local term = require("term")
local gpu = component.gpu

local w, h = gpu.getResolution()
local cx = math.floor(w / 2)
local cy = math.floor(h / 2)

local board = {}
local revealed = {}
local flags = {}
local gameOver = false
local gameWon = false
local mines = 10
local boardSize = 9
local startTime = 0
local remainingFlags = mines

function createBoard()
    board = {}
    revealed = {}
    flags = {}
    gameOver = false
    gameWon = false
    remainingFlags = mines
    startTime = computer.uptime()
    
    -- Создаем пустую доску
    for x = 1, boardSize do
        board[x] = {}
        revealed[x] = {}
        flags[x] = {}
        for y = 1, boardSize do
            board[x][y] = 0
            revealed[x][y] = false
            flags[x][y] = false
        end
    end
    
    -- Расставляем мины
    local placed = 0
    while placed < mines do
        local x = math.random(1, boardSize)
        local y = math.random(1, boardSize)
        
        if board[x][y] ~= -1 then
            board[x][y] = -1
            placed = placed + 1
            
            -- Увеличиваем счетчики вокруг мины
            for dx = -1, 1 do
                for dy = -1, 1 do
                    local nx, ny = x + dx, y + dy
                    if nx >= 1 and nx <= boardSize and ny >= 1 and ny <= boardSize and board[nx][ny] ~= -1 then
                        board[nx][ny] = board[nx][ny] + 1
                    end
                end
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
    gpu.set(2, 1, "💣 САПЁР")
    
    -- Статистика
    local time = math.floor(computer.uptime() - startTime)
    gpu.set(w - 30, 1, string.format("Флагов: %d/%d | Время: %dс", remainingFlags, mines, time))
    
    -- Игровое поле
    local boardX = cx - math.floor(boardSize * 2)
    local boardY = cy - math.floor(boardSize / 2) + 2
    
    for x = 1, boardSize do
        for y = 1, boardSize do
            local cellX = boardX + (x-1) * 4
            local cellY = boardY + (y-1) * 2
            
            -- Рамка клетки
            gpu.setBackground(0x333333)
            gpu.fill(cellX, cellY, 3, 1, " ")
            
            if revealed[x][y] then
                if board[x][y] == -1 then
                    -- Мина
                    gpu.setForeground(0xFF0000)
                    gpu.set(cellX + 1, cellY, "💣")
                elseif board[x][y] > 0 then
                    -- Число
                    local colors = {
                        [1] = 0x0000FF, -- синий
                        [2] = 0x008000, -- зеленый
                        [3] = 0xFF0000, -- красный
                        [4] = 0x000080, -- темно-синий
                        [5] = 0x800000, -- темно-красный
                        [6] = 0x008080, -- бирюзовый
                        [7] = 0x000000, -- черный
                        [8] = 0x808080  -- серый
                    }
                    gpu.setForeground(colors[board[x][y]] or 0xFFFFFF)
                    gpu.set(cellX + 1, cellY, tostring(board[x][y]))
                else
                    -- Пустая клетка
                    gpu.setForeground(0x666666)
                    gpu.set(cellX + 1, cellY, "·")
                end
            elseif flags[x][y] then
                -- Флаг
                gpu.setForeground(0xFF0000)
                gpu.set(cellX + 1, cellY, "🚩")
            else
                -- Скрытая клетка
                gpu.setForeground(0xCCCCCC)
                gpu.set(cellX + 1, cellY, "█")
            end
        end
    end
    
    -- Сообщение о статусе игры
    if gameOver then
        gpu.setForeground(0xFF0000)
        gpu.set(cx - 10, boardY + boardSize * 2 + 2, "ИГРА ОКОНЧЕНА! Вы подорвались на мине!")
    elseif gameWon then
        gpu.setForeground(0x00FF00)
        gpu.set(cx - 10, boardY + boardSize * 2 + 2, "ПОБЕДА! Все мины найдены!")
    end
    
    -- Подсказка
    gpu.setBackground(0x003366)
    gpu.setForeground(0xFFFFFF)
    gpu.fill(1, h, w, 1, " ")
    gpu.set(2, h, "ЛКМ - открыть | ПКМ - флаг | R - перезапуск | ESC - выход")
end

function reveal(x, y)
    if x < 1 or x > boardSize or y < 1 or y > boardSize then return end
    if revealed[x][y] or flags[x][y] then return end
    
    revealed[x][y] = true
    
    if board[x][y] == -1 then
        gameOver = true
        -- Показываем все мины
        for mx = 1, boardSize do
            for my = 1, boardSize do
                if board[mx][my] == -1 then
                    revealed[mx][my] = true
                end
            end
        end
    elseif board[x][y] == 0 then
        -- Открываем соседние пустые клетки
        for dx = -1, 1 do
            for dy = -1, 1 do
                if not (dx == 0 and dy == 0) then
                    reveal(x + dx, y + dy)
                end
            end
        end
    end
    
    -- Проверка победы
    checkWin()
end

function toggleFlag(x, y)
    if x < 1 or x > boardSize or y < 1 or y > boardSize then return end
    if revealed[x][y] then return end
    
    if flags[x][y] then
        flags[x][y] = false
        remainingFlags = remainingFlags + 1
    elseif remainingFlags > 0 then
        flags[x][y] = true
        remainingFlags = remainingFlags - 1
    end
    
    checkWin()
end

function checkWin()
    -- Проверяем, все ли мины отмечены флагами
    local correct = true
    for x = 1, boardSize do
        for y = 1, boardSize do
            if board[x][y] == -1 and not flags[x][y] then
                correct = false
                break
            end
        end
        if not correct then break end
    end
    
    if correct then
        gameWon = true
        -- Отмечаем все флаги как правильные
        for x = 1, boardSize do
            for y = 1, boardSize do
                if board[x][y] == -1 then
                    flags[x][y] = true
                end
            end
        end
    end
end

function getCellFromClick(x, y)
    local boardX = cx - math.floor(boardSize * 2)
    local boardY = cy - math.floor(boardSize / 2) + 2
    
    for cellX = 1, boardSize do
        for cellY = 1, boardSize do
            local screenX = boardX + (cellX-1) * 4
            local screenY = boardY + (cellY-1) * 2
            
            if x >= screenX and x < screenX + 3 and y == screenY then
                return cellX, cellY
            end
        end
    end
    
    return nil, nil
end

function main()
    math.randomseed(computer.uptime())
    createBoard()
    
    while true do
        drawGame()
        
        local e = {event.pull()}
        
        if e[1] == "key_down" then
            local char, code = e[3], e[4]
            
            if code == 1 then -- ESC
                break
                
            elseif char == "r" or char == "R" or char == "к" or char == "К" then
                createBoard()
                
            elseif (gameOver or gameWon) and code == 28 then -- Enter
                createBoard()
            end
            
        elseif e[1] == "touch" then
            local x, y, button = e[3], e[4], e[5]
            local cellX, cellY = getCellFromClick(x, y)
            
            if cellX and cellY then
                if button == 0 then -- ЛКМ
                    if not gameOver and not gameWon then
                        reveal(cellX, cellY)
                    end
                elseif button == 1 then -- ПКМ
                    if not gameOver and not gameWon then
                        toggleFlag(cellX, cellY)
                    end
                end
            end
        end
    end
end

main()
