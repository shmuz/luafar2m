-- https://bito.ai/
-- https://github.com/gitbito/CLI/raw/main/version-3.3/BitoCLI.msi
-- https://github.com/gitbito/CLI/blob/main/version-3.3/bito.exe
-- https://docs.bito.ai/feature-guides/custom-prompt-templates

--local directory = win.GetEnv("FARHOME")
local linewrap = 80

local F = far.Flags
local idProgress = win.Uuid"3E5021C5-47C7-4446-8E3B-13D3D9052FD8"
local function progress (text, title)
  local len = math.max(text:len(), title and title:len() or 0, 7)
  local items = {
  --[[01]] {F.DI_SINGLEBOX,0,0,len+4,3,0,0,0,                0, title},
  --[[02]] {F.DI_TEXT,     2,1,    0,1,0,0,0,F.DIF_CENTERGROUP, text},
  }
  return far.DialogInit(idProgress, -1, -1, len+4, 3, nil, items, F.FDLG_NONMODAL)
end

local _name = "bito.ai code assistant"
local _prompt = "Ask any technical question / use {{%code%}} as seltext placeholder"
local idInput = win.Uuid"58DD9ECD-CFFA-472E-BFD7-042295C86CAE"
local function bito (prompt)
  prompt = prompt or far.InputBox(idInput, _name, _prompt, "bito.ai prompt", nil, nil, nil, F.FIB_NONE)
  if prompt then
    local root = win.GetEnv("FARLOCALPROFILE").."\\"
    local ctxName = root.."ctx.bito"
    local promptName = root.."prompt.bito"
    local promptFile = assert(io.open(promptName, "w"))
    promptFile:write(prompt)
    promptFile:close()
    local ctx = Editor.SelValue
    local fileName = root.."file.bito"
    local fileFile = assert(io.open(fileName, "w"))
    fileFile:write(ctx=="" and " " or ctx)
    fileFile:close()
    local cmd = ('"%s" -c "%s" -f "%s" -p "%s"'):format("bito.exe", ctxName, fileName, promptName)
    local flags = F.EF_NONMODAL +F.EF_IMMEDIATERETURN +F.EF_DELETEONLYFILEONCLOSE +F.EF_OPENMODE_USEEXISTING
                 +F.EF_DISABLEHISTORY
    editor.Editor("bito.md", nil, nil, nil, nil, nil, flags, nil, nil, 65001)
    editor.SetTitle(nil, "Fetching response...")
    local hDlg = progress("Waiting for data..")

    editor.UndoRedo(nil, F.EUR_BEGIN)
    local ei = editor.GetInfo()
    local s = editor.GetString(nil, ei.TotalLines)
    editor.SetPosition(nil, ei.TotalLines, s.StringLength+1)
    local i = ei.TotalLines
    if s.StringLength>0 then
      editor.InsertString()
      editor.InsertString()
      i = i+2
      editor.SetPosition(nil, i)
    end
    far.Text()

    local pipe = io.popen("cmd /c\""..cmd.."\"", "r")
    --[[
    for line in pipe:lines() do
      editor.SetString(nil, i, line,"\n")
      editor.InsertString()
      i = i+1
      editor.Redraw()
    end
    --]]
    linewrap = linewrap or ei.WindowSizeX-5
    local autowrap = bit64.band(ei.Options, F.EOPT_AUTOINDENT)~=0
    if autowrap then editor.SetParam(nil, F.ESPT_AUTOINDENT, 0) end
    repeat
      local chunk = pipe:read(5)
      if not chunk then break end
      while(not chunk:isvalid()) do
        chunk = chunk..pipe:read(1)
      end
      ei = editor.GetInfo()
      -- !! it would be better to reformat, but..
      if ei.CurPos + chunk:match("^(.-)%s*$"):len() > linewrap then
        chunk = chunk:gsub("^(%p?) ","%1\n"):match".*"
      end
      editor.InsertText(nil, chunk)
      editor.Redraw()
    until false
    if autowrap then editor.SetParam(nil, F.ESPT_AUTOINDENT, 1) end
    editor.UndoRedo(nil, F.EUR_END)
    hDlg:send(F.DM_CLOSE)
    editor.SetTitle(nil, "bito.ai response:")
  end
end

if Macro then
  Macro { description="Ask AI";
    area="Common"; key="CtrlB";
    id="4AFE2367-4DAC-4A74-B1EE-9F14C42991CB";
    action=function()
      mf.acall(bito)
    end;
  }
  return
end

if _cmdline=="" then
  sh.acall(bito)
elseif _cmdline then
  bito(_cmdline)
else
  return bito
end
