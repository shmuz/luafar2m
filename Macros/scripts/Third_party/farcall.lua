-- Original author: Sergey Oblomov (aka hoopoe)
-- https://forum.farmanager.com/viewtopic.php?t=10204
-- Ported to far2m: Shmuel Zeigerman

local action = function(text)
    local batpath = far.InMyTemp("__farcall")
    local envpath = far.InMyTemp("__farenv")
    local bat = assert(io.open(batpath, "w"))
    bat:write('cd "', far.GetCurrentDirectory(), '" || exit 1\n')
    bat:write(". ", text, ' || exit 2\n') -- 'source' didn't work while '.' did
    bat:write('env > ', envpath, '\n')
    bat:close()
    win.chmod(batpath, tonumber("0774", 8))

    panel.GetUserScreen()
    if 0 == win.system(batpath) then
        for line in io.lines(envpath) do
            local name, value = line:match('^([^=]+)=(.*)')
            if name then
                win.SetEnv(name, value)
            end
        end
    end
    win.DeleteFile(batpath)
    win.DeleteFile(envpath)
    panel.SetUserScreen()
end

CommandLine {
    description = "Far Call Lua Edition";
    prefixes = "call";
    action = function(prefix, text) action(text); end;
}
