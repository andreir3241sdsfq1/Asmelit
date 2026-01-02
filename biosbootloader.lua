-- BIOS v1.2 - 3812 bytes
local c = _G.component
local comp = _G.computer
local e = _G.event
local g = c and c.gpu

if not g then return end

local w, h = g.getResolution()
local cx = math.floor(w/2)
local cy = math.floor(h/2)

g.setBackground(0x000033)
g.setForeground(0xFFFFFF)
g.fill(1,1,w,h," ")

local sel = 1
local opts = {
    {txt="BOOT OS", act="boot"},
    {txt="SHUTDOWN", act="off"}
}

while true do
    g.setBackground(0x000033)
    g.fill(1,1,w,1," ")
    g.set(cx-7,1,"ASMELIT BIOS")
    g.set(w-15,1,"Mem:"..math.floor((comp.freeMemory or function() return 0 end)()/1024).."K")
    
    g.set(cx-6,cy-4,"ASMELIT OS")
    g.set(cx-8,cy-3,"====================")
    
    for i, o in ipairs(opts) do
        local y = cy + (i-1)*3
        if i == sel then
            g.setBackground(0x0077CC)
            g.setForeground(0x000000)
        else
            g.setBackground(0x0055AA)
            g.setForeground(0xFFFFFF)
        end
        
        g.fill(cx-10,y,20,1," ")
        g.set(cx-8,y,(i==sel and "> " or "  ")..o.txt)
    end
    
    g.setBackground(0x000033)
    g.setForeground(0xAAAAAA)
    g.set(cx-15,h-3,"UP/DOWN - Select | ENTER - Confirm")
    
    local ev = {e.pull()}
    if ev[1] == "key_down" then
        local code = ev[4]
        if code == 200 then -- up
            sel = sel>1 and sel-1 or #opts
        elseif code == 208 then -- down
            sel = sel<#opts and sel+1 or 1
        elseif code == 28 then -- enter
            local act = opts[sel].act
            if act == "boot" then
                g.setBackground(0x000000)
                g.setForeground(0x00FF00)
                g.fill(1,1,w,h," ")
                g.set(cx-4,cy,"LOADING...")
                
                local function loadFile(path)
                    local f = io.open(path,"r")
                    if f then
                        local code = f:read("*a")
                        f:close()
                        if #code > 100 then
                            local func, err = load(code,"=boot")
                            if func then return func end
                        end
                    end
                    return nil
                end
                
                local func = loadFile("/run.lua") or loadFile("/home/run.lua")
                if func then
                    os.sleep(1)
                    func()
                    break
                else
                    g.setForeground(0xFF0000)
                    g.set(cx-10,cy+4,"No OS found!")
                    os.sleep(2)
                    break
                end
                
            elseif act == "off" then
                g.setBackground(0x000000)
                g.setForeground(0xFFFFFF)
                g.fill(1,1,w,h," ")
                g.set(cx-5,cy,"GOODBYE")
                os.sleep(1)
                if comp.shutdown then comp.shutdown() end
                break
            end
        end
    end
end
