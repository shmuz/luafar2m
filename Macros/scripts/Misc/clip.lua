-- Description : when far2l/far2m exit their clipboard is erased. This is a workaround for far2m.
-- Started     : 2025-10-01

local KEY, NAME = "shmuz", "clipboard"

Event {
  description="Save clipboard on FAR exit";
  group="ExitFAR";
  action=function(Reload)
    if not Reload then
      local text = far.PasteFromClipboard()
      if text and text ~= "" then mf.msave(KEY,NAME,text) end
    end
  end;
}

Macro {
  description="Copy saved value to clipboard";
  area="Common"; flags="RunAfterFARStart";
  action=function()
    local txt = far.PasteFromClipboard()
    if txt==nil or txt=="" then
      far.CopyToClipboard(mf.mload(KEY,NAME))
    end
  end;
}
