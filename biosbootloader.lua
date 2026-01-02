-- ASMELIT BIOS v1.0
local c = component
local comp = computer
local g = c.gpu
local w, h = g.getResolution()

g.setBackground(0x000022)
g.setForeground(0xFFFFFF)
g.fill(1,1,w,h," ")
g.set(35,1,"ASMELIT BIOS")

local function drawMenu()
    g.set(30,8,"1. BOOT OS")
    g.set(30,10,"2. SHUTDOWN")
    g.set(25,13,"Select [1-2]: ")
end

drawMenu()

local run = io.open("/run.lua")
if not run then run = io.open("/home/run.lua") end

while true do
    local char = io.read(1)
    
    if char == "1" then
        if run then
            run:close()
            g.setBackground(0x000000)
            g.setForeground(0x00FF00)
            g.fill(1,1,w,h," ")
            g.set(35,10,"LOADING...")
            os.sleep(1)
            
            local code = ""
            local f = io.open("/run.lua")
            if f then code = f:read("*a") f:close()
            else f = io.open("/home/run.lua") if f then code = f:read("*a") f:close() end
            end
            
            if #code > 100 then
                local func, err = load(code, "=boot")
                if func then func() end
            end
            break
        else
            g.setForeground(0xFF0000)
            g.set(30,15,"No OS found!")
            os.sleep(2)
            drawMenu()
        end
        
    elseif char == "2" then
        g.setBackground(0x000000)
        g.setForeground(0xFFFFFF)
        g.fill(1,1,w,h," ")
        g.set(35,10,"SHUTDOWN")
        os.sleep(1)
        comp.shutdown()
        break
    end
end
