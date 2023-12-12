-- shmuel 14.06.2014 08:31:00 +0200 - build 1
-- http://forum.farmanager.com/viewtopic.php?p=119751#p119751
---------------------------------------------------------------------------------------
-- NOTE: for SciTE-like functionality of blocks duplication use CtrlP (built-in in Far)
---------------------------------------------------------------------------------------

Macro {
  description="Duplicate current line";
  area="Editor"; key="CtrlD";
  action=function()
    local info = editor.GetInfo()
    local line = editor.GetString()
    local eol = line.StringEOL ~= "" and line.StringEOL or nil
    editor.UndoRedo(nil,"EUR_BEGIN")
    editor.SetPosition(nil,nil,1)
    editor.InsertString()
    editor.SetPosition(nil, info.CurLine, info.CurPos)
    editor.SetString(nil, nil, line.StringText, eol)
    editor.UndoRedo(nil,"EUR_END")
    info.CurLine = info.CurLine + 1
    editor.SetPosition(nil,info)
    editor.Redraw()
  end;
}
