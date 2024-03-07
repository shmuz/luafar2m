-- started: 2020-06-15
-- url:     https://forum.ru-board.com/topic.cgi?forum=5&topic=50439&start=980#19
-- url:     https://forum.farmanager.com/viewtopic.php?p=161334#p161334

CommandLine {
  description = "Time";
  prefixes = "time";
  action = function(prefix,text)
    local t1 = win.Clock()
    far.Execute(text)
    t1 = win.Clock() - t1
    local str1 = ("%.6f"):format(t1)
    local ret = far.Message(str1.." sec.", "Time", "&OK;&Copy;&Fullcopy")
    if ret == 2 then
      far.CopyToClipboard(str1)
    elseif ret == 3 then
      far.CopyToClipboard(("time=%s, command=%s"):format(str1, text))
    end
    actl.RedrawAll()
  end;
}
