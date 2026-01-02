-- calculator.lua - Калькулятор для Asmelit OS
local component = require("component")
local computer = require("computer")
local event = require("event")
local term = require("term")
local gpu = component.gpu

local w, h = gpu.getResolution()
local cx = math.floor(w / 2)
local cy = math.floor(h / 2)

local display = "0"
local memory = 0
local lastOperation = nil
local lastValue = nil
local waitingForSecondNumber = false

function drawCalculator()
    gpu.setBackground(0x001122)
    gpu.setForeground(0xFFFFFF)
    term.clear()
    
    -- Заголовок
    gpu.set(cx - 6, 2, "🧮 КАЛЬКУЛЯТОР")
    gpu.set(cx - 10, 3, string.rep("═", 20))
    
    -- Дисплей
    gpu.setBackground(0x002244)
    gpu.fill(cx - 15, 5, 30, 3, " ")
    gpu.setForeground(0x00FF00)
    gpu.set(cx - 14 + math.max(0, 28 - #display), 6, display)
    
    -- Кнопки
    local buttons = {
        {"7", "8", "9", "/", "C"},
        {"4", "5", "6", "*", "⌫"},
        {"1", "2", "3", "-", "M+"},
        {"0", ".", "=", "+", "MR"}
    }
    
    local startX = cx - 12
    local startY = 9
    
    for row = 1, 4 do
        for col = 1, 5 do
            local btn = buttons[row][col]
            local x = startX + (col-1) * 6
            local y = startY + (row-1) * 3
            
            gpu.setBackground(0x003366)
            gpu.fill(x, y, 5, 2, " ")
            gpu.setForeground(0xFFFFFF)
            gpu.set(x + 2, y + 1, btn)
        end
    end
    
    -- Подсказка
    gpu.setBackground(0x001122)
    gpu.setForeground(0xAAAAAA)
    gpu.set(cx - 15, h - 2, "ESC - Выход | M - Память | C - Очистить")
    
    -- Память
    if memory ~= 0 then
        gpu.setForeground(0xFFFF00)
        gpu.set(cx - 10, h - 4, "Память: " .. memory)
    end
end

function calculate()
    if lastOperation and lastValue then
        local a = tonumber(lastValue)
        local b = tonumber(display)
        
        if a and b then
            if lastOperation == "+" then
                display = tostring(a + b)
            elseif lastOperation == "-" then
                display = tostring(a - b)
            elseif lastOperation == "*" then
                display = tostring(a * b)
            elseif lastOperation == "/" then
                if b ~= 0 then
                    display = tostring(a / b)
                else
                    display = "ERROR"
                end
            end
        end
        lastOperation = nil
        lastValue = nil
        waitingForSecondNumber = false
    end
end

function handleButton(btn)
    if btn == "C" then
        display = "0"
        lastOperation = nil
        lastValue = nil
        waitingForSecondNumber = false
        
    elseif btn == "⌫" then
        if #display > 1 then
            display = display:sub(1, -2)
        else
            display = "0"
        end
        
    elseif btn == "M+" then
        memory = tonumber(display) or 0
        
    elseif btn == "MR" then
        if memory ~= 0 then
            display = tostring(memory)
        end
        
    elseif btn == "+" or btn == "-" or btn == "*" or btn == "/" then
        if not waitingForSecondNumber then
            lastValue = display
            lastOperation = btn
            waitingForSecondNumber = true
            display = "0"
        end
        
    elseif btn == "=" then
        calculate()
        
    elseif btn == "." then
        if not display:find("%.") then
            display = display .. "."
        end
        
    elseif tonumber(btn) then
        if display == "0" or display == "ERROR" or waitingForSecondNumber then
            display = btn
            waitingForSecondNumber = false
        else
            display = display .. btn
        end
    end
end

function main()
    drawCalculator()
    
    while true do
        local e = {event.pull()}
        
        if e[1] == "key_down" then
            local char, code = e[3], e[4]
            
            if code == 1 then -- ESC
                break
                
            elseif char == "c" or char == "C" or char == "с" or char == "С" then
                handleButton("C")
                
            elseif char == "m" or char == "M" or char == "ь" or char == "Ь" then
                if code == 16 then -- M
                    handleButton("M+")
                elseif code == 19 then -- R
                    handleButton("MR")
                end
                
            elseif char == "0" then handleButton("0")
            elseif char == "1" then handleButton("1")
            elseif char == "2" then handleButton("2")
            elseif char == "3" then handleButton("3")
            elseif char == "4" then handleButton("4")
            elseif char == "5" then handleButton("5")
            elseif char == "6" then handleButton("6")
            elseif char == "7" then handleButton("7")
            elseif char == "8" then handleButton("8")
            elseif char == "9" then handleButton("9")
            elseif char == "." then handleButton(".")
            elseif char == "+" then handleButton("+")
            elseif char == "-" then handleButton("-")
            elseif char == "*" then handleButton("*")
            elseif char == "/" then handleButton("/")
            elseif char == "=" or code == 28 then handleButton("=") -- Enter
            elseif code == 14 then handleButton("⌫") -- Backspace
            end
            
            drawCalculator()
            
        elseif e[1] == "touch" then
            local x, y = e[3], e[4]
            local startX = cx - 12
            local startY = 9
            
            -- Проверяем нажатие на кнопки
            for row = 1, 4 do
                for col = 1, 5 do
                    local btnX = startX + (col-1) * 6
                    local btnY = startY + (row-1) * 3
                    
                    if x >= btnX and x < btnX + 5 and y >= btnY and y < btnY + 2 then
                        local buttons = {
                            {"7", "8", "9", "/", "C"},
                            {"4", "5", "6", "*", "⌫"},
                            {"1", "2", "3", "-", "M+"},
                            {"0", ".", "=", "+", "MR"}
                        }
                        handleButton(buttons[row][col])
                        drawCalculator()
                        break
                    end
                end
            end
        end
    end
end

main()
