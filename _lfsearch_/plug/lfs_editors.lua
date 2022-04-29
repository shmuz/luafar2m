-- luacheck: globals _Plugin

local F = far.Flags

local Editors do
  Editors = _Plugin.Editors or {}
  _Plugin.Editors = Editors
end

local function ProcessEditorEvent (event, param)
  local info = editor.GetInfo()
  if info then
    local id = info.EditorID
    if event == F.EE_READ then
      Editors[id] = Editors[id] or {}
      Editors[id].sLastOp = "search"
    elseif event == F.EE_CLOSE then
      Editors[id] = nil
    elseif event == F.EE_REDRAW then
      local state = Editors[id] or {}
      Editors[id] = state
    end
  end
end

return {
  GetState = function(Id) return Editors[Id] end,
  ProcessEditorEvent = ProcessEditorEvent,
}
