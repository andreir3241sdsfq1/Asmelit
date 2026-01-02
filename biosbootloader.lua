local c = _G.component
local comp = _G.computer or {}
local g = c and c.gpu
local ev = _G.event

if g then
    g.setBackground(0x000000)
    g.fill(1, 1, 80, 25, " ")
    g.setForeground(0x00AA00)
    g.set(35, 1, "[Asmelit BIOS]")
end

local function findAndRun()
    local drives = c.list("drive")()
    if not drives then
        if g then g.set(1, 3, "No drives") end
        return false
    end
    
    for addr in drives do
        local drive = c.proxy(addr)
        if drive and drive.exists then
            local paths = {"/bootloader.lua", "/startup.lua", "/home/startup.lua"}
            for _, path in ipairs(paths) do
                if drive.exists(path) then
                    local f = drive.open(path, "r")
                    if f then
                        local code = f.read(math.huge)
                        f.close()
                        if code and #code > 10 then
                            local func, err = load(code, "=boot")
                            if func then
                                if g then g.set(1, 5, "Booting...") end
                                return func()
                            end
                        end
                    end
                end
            end
        end
    end
    return false
end

local booted = false
for i = 1, 30 do
    if findAndRun() then
        booted = true
        break
    end
    if ev then ev.pull(0.1) end
end

if not booted then
    if g then
        g.set(1, 10, "Press any key for shell...")
        g.setForeground(0xFFFFFF)
    end
    if ev then ev.pull("key_down") end
    
    -- Fallback
    if g then
        g.set(1, 12, "Cannot load shell")
        g.set(1, 13, "Rebooting...")
    end
    
    -- Безопасный beep и shutdown
    if comp.beep then comp.beep(1000, 1) end
    if comp.shutdown then comp.shutdown(true) end
end
