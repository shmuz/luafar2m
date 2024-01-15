CommandLine {
  description = "Time";
  prefixes = "time";
  action = function(prefix,text)
    io.write(prefix, ": ", text, "\n")
    local t1 = win.Clock ()
    win.system(text)
    t1 = (win.Clock ()-t1)
    local str1 = ("%.6f"):format(t1)
    local ret = far.Message(str1.." sec.", "Time", "&OK;&Copy;&Fullcopy")
    if ret == 2 then
      far.CopyToClipboard(str1)
    elseif ret == 3 then
      far.CopyToClipboard(("time=%s, command=%s"):format(str1, text))
    end
  end;
}
