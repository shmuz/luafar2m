-- Author    : Dmitry Suhodoev
-- Published : https://forum.farmanager.com/viewtopic.php?p=140825&hilit=cclike#p140825
-- Note      : Works in Far3, doesn't work in far2m build 2025-10-12
-- Note      : I'm placing it here as it's an interesting case for study

-----------------------------------------------------------------------------
-- raVen's c&c like input 20160913-01
-----------------------------------------------------------------------------
local cccolor = 0xcf
local pattern = '[%a%d%p%w%s]'
local F = far.Flags

local cx, cy
Event {
  group = 'EditorInput';
  description = 'command and conquer like input';
  action = function(param)
    if param.EventType ~= F.KEY_EVENT then return; end
    if param.UnicodeChar:match(pattern) == nil then return; end
    local ei = editor.GetInfo()
    if param.KeyDown then
      cx, cy = ei.CurPos, ei.CurLine
    else
      editor.Redraw(ei.EditorID)
    end;
  end;
}

Event {
  group = 'EditorEvent';
  description = 'command and conquer like input';
  action = function(eid, event)
    if event == F.EE_REDRAW then
      if cx then
        editor.AddColor(eid, cy, cx, cx, far.Flags.ECF_AUTODELETE, cccolor)
        cx = nil
      end
    end
  end;
}
