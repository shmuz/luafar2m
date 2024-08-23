
local action = function(text)
    local temp = win.GetEnv("TEMP");
    local batpath = temp .. "\\___farcall.cmd";
    local envpath = temp .. "\\___farenv.cmd";
    local bat = io.open(batpath, "w");
    bat:write('@cd "' .. far.GetCurrentDirectory() .. '"\n');
    bat:write("@call " .. text .. "\n");
    bat:write('@set > "' .. envpath .. '"\n');
    bat:close(bat);
    panel.GetUserScreen();
    win.system('"' .. batpath .. '"');
    for line in io.lines(envpath) do
        local name = line:match('[^=]+');
        local value = line:match('=(.*)');

        if(name) then
            win.SetEnv(name, value)
        end;
    end
    win.DeleteFile(batpath);
    win.DeleteFile(envpath);
    panel.SetUserScreen();
end;

CommandLine {
    description = "Far Call Lua Edition";
    prefixes = "call";
    action = function(prefix, text) action(text); end;
}


