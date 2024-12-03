-- The file was renamed to bin2text_mf.lua to avoid require() itself

local CommonKey = "AltShiftF6"

local function ShowProgress(Title, Size)
  if Size then
    if win.ExtractKey()=="ESCAPE" and 1==far.Message("Break the operation?",Title,"&Yes;&No","w") then
      return true
    end
    far.Message(math.floor(Size/0x100000).." MB", Title, "")
  else
    far.Message("Working, please wait...", Title, "")
    far.AdvControl("ACTL_REDRAWALL")
  end
end

local function GetFileName (aTitle, aPrompt, aDefault)
  while true do
    local fname = far.InputBox(nil, aTitle, aPrompt, nil, aDefault)
    if not fname then
      return
    end
    local fullname = fname:find("^/") and fname or win.JoinPath(APanel.Path, fname)
    if not win.GetFileAttr(fullname) or
       1==far.Message("File already exists, overwrite?", aTitle, "&Yes;&No", "w")
    then
      return fullname
    end
  end
end

local function DecodeFile(method)
  local lib = require("bin2text")[method]
  local Title = method:upper().."-decode"
  local fp_in, fp_out, message -- set inside the loop, handle outside

  while true do -- luacheck: only
    local fname_in = win.JoinPath(APanel.Path, APanel.Current)
    fp_in, message = io.open(fname_in)
    if not fp_in then break end

    local ln1 = fp_in:read("*l") or ""
    local fname_out = ln1:match("^begin%s+[0-7]+%s+\"(.-)\"%s*$") or  -- try to match (1) quoted
                      ln1:match("^begin%s+[0-7]+%s+([^\"%s]+)%s*$")   -- then (2) unquoted
    if not fname_out then
      message = "Source file: invalid format of the first line"
      break
    end

    local full_out = GetFileName(Title, "Enter output file name", fname_out)
    if not full_out then break end
    fp_out, message = io.open(full_out, "wb")
    if not fp_out then break end

    ShowProgress(Title)
    local NumErr = 0
    local cache, cnt = {}, 0 -- minimize number of disk write operations (important for flash disks)
    for ln in fp_in:lines() do
      local chunk,nerr = lib.decode(ln)
      NumErr = NumErr + nerr
      if chunk ~= "" then
        cnt = cnt + 1
        cache[cnt] = chunk
        if cnt == 1000 then
          fp_out:write(table.concat(cache,"",1,cnt))
          cnt = 0
          if win.ExtractKey()=="ESCAPE" then
            if 1==far.Message("Break the operation?",Title,"&Yes;&No","w") then
              break
            else
              ShowProgress(Title)
            end
          end
        end
      else
        break
      end
    end
    if cnt > 0 then
      fp_out:write(table.concat(cache,"",1,cnt))
    end
    if NumErr ~= 0 then
      far.Message("Total number of errors: "..NumErr, Title, nil, "w")
    end

    break
  end

  if fp_out then fp_out:close() end
  if fp_in then fp_in:close() end
  if message then
    far.Message(message, Title, nil, "w")
  else
    panel.UpdatePanel(nil, 1)
    panel.UpdatePanel(nil, 0)
    far.AdvControl("ACTL_REDRAWALL")
  end
end

local function EncodeFile(method, ext)
  local lib = require("bin2text")[method]
  local Title = method:upper().."-encode"
  local outname = GetFileName(Title, "Enter output file name", APanel.Current.."."..ext)
  if outname then
    local firstline = "begin 644 "..APanel.Current:match("[^\\/]+$")
    assert( lib.encfile(win.JoinPath(APanel.Path, APanel.Current), outname, firstline,
                        function(size) return ShowProgress(Title,size) end) )
    panel.UpdatePanel(nil, 1)
    far.AdvControl("ACTL_REDRAWALL")
  end
end

Macro {
  id="28AC0E2E-FBC4-4CDA-9364-FC7C4F09BDEE";
  description="Create XX-Encoded file";
  area="Shell"; key=CommonKey;
  flags="NoPluginPanels NoFolders";
  sortpriority=65;
  action=function() EncodeFile("xx", "xxe") end;
}

Macro {
  id="A01F0EFE-9C50-4EBE-9D7F-5801434C6967";
  description="Create UU-Encoded file";
  area="Shell"; key=CommonKey;
  flags="NoPluginPanels NoFolders";
  sortpriority=60;
  action=function() EncodeFile("uu", "uue") end;
}

Macro {
  id="A54E1BB9-2547-479F-A2AC-3ABBFDD168CA";
  description="Unpack XX-Encoded file";
  area="Shell"; key=CommonKey;
  flags="NoPluginPanels NoFolders";
  sortpriority=55;
  action=function() DecodeFile("xx") end;
}

Macro {
  id="2263CFC4-6A1A-4A4E-8D75-0A95CCA43683";
  description="Unpack UU-Encoded file";
  area="Shell"; key=CommonKey;
  flags="NoPluginPanels NoFolders";
  sortpriority=50;
  action=function() DecodeFile("uu") end;
}
