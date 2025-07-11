-- cross.lua

local F = far.Flags
local ColorFlags = bit64.bor(0, F.ECF_AUTODELETE) -- was: F.ECF_TABMARKCURRENT
local Color1 = 0x71
local Color2 = 0xE1

local Editors do
  local guid = "72A977B4-8DF6-476A-9230-A46C9BB2D56B"
  Editors = _G[guid] or {}
  _G[guid] = Editors
end

local function ToggleCross()
  local info = editor.GetInfo()
  if info then
    local state = Editors[info.EditorID]
    if state then
      state.active = not state.active
      editor.Redraw()
    end
  end
end

local function RedrawCross (EI)
  local ID = EI.EditorID
  local BottomLine = math.min(EI.TopScreenLine+EI.WindowSizeY-1, EI.TotalLines)
  for y=EI.TopScreenLine,BottomLine  do
    local toreal = function(pos) return editor.TabToReal(ID,y,pos) end
    if y == EI.CurLine then
      local from, to = toreal(EI.LeftPos), toreal(EI.LeftPos+EI.WindowSizeX-1)
      editor.AddColor(ID, y, from, to, ColorFlags, Color1)
    end
    local offs = toreal(EI.CurPos)
    editor.AddColor(ID, y, offs, offs, ColorFlags, y==EI.CurLine and Color2 or Color1)
  end
end

Event {
  group="EditorEvent";
  action=function(id, event, param)
    if event == F.EE_READ then
      Editors[id] = Editors[id] or {}
    elseif event == F.EE_CLOSE then
      Editors[id] = nil
    elseif event == F.EE_REDRAW then
      local state = Editors[id] or {}
      Editors[id] = state
      if state.active then
        if param == F.EEREDRAW_ALL then
          local EI = editor.GetInfo(id)
          RedrawCross(EI)
        else
          editor.Redraw()
        end
      end
    end
  end;
}

Macro {
  id="7FF2576D-9538-499A-A22E-BFD6DEF6E57F";
  description="Toggle cross On/Off";
  area="Editor"; key="F1";
  action=function() ToggleCross(); end;
}
