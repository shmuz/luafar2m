-- coding: utf-8
-- luacheck: max_line_length 160
-- luacheck: read_globals far

local sd = require "far2.simpledialog"
local F = far.Flags
local KEEP_DIALOG_OPEN = 0

local AreaShortNames = {
  "Dialog", "Disks", "Editor", "Help", "Info", "MainMenu", "Menu", "QView", "Search", "Shell",
  "Tree", "Viewer", "Other", "Common", "FindFolder", "UserMenu", "AutoCompletion",
}

local AreaList = {
  {Text="Dialog windows"}, {Text="Disks Menu"},       {Text="Text editor"},
  {Text="Help window"},    {Text="Info panel"},       {Text="Main menu"},
  {Text="Other menus"},    {Text="Quick view panel"}, {Text="Quick search files"},
  {Text="File panels"},    {Text="Tree panel"},       {Text="Internal viewer"},
  {Text="Other areas"},    {Text="Common macros"},    {Text="Find folder panel"},
  {Text="User menu"},      {Text="AutoCompletion"},
}

local function MacroDialog (aTitle, aInput, aCanClose)
  local hw = 33 -- half-width of space inside the double-box
  local items = {
    guid = "E5DBC50D-DEAC-49C0-AE3A-357602A418AE";
    width=2*hw+10;
    {tp="dbox"; text=aTitle; },
    {tp="text"; text="Command of e&xecution"; width=hw-2; },
    {tp="edit"; hist="MacroKey";           name="MacroKey"; width=hw-2; },
    {tp="text"; text="&Work area"; ystep=-1; x1=hw+6; },
    {tp="combobox"; x1="";                 name="WorkArea"; dropdownlist=1; list=AreaList; },
    {tp="sep"; },
    {tp="vtext"; x1=hw+4; y1=2; y2=4; text="││┴"; },
    ------------------------------------------------------------------------------------------------
    {tp="text"; text="Sequen&ce"; y1=5; },
    {tp="edit";   hist="MacroCmd";         name="Sequence"; focus=aInput; },
    {tp="text"; text="&Description"; },
    {tp="edit";   hist="MacroDescr";       name="Description"; },
    {tp="sep"; },
    ------------------------------------------------------------------------------------------------
    {tp="chbox"; text="&Run after FAR start";                                           Flags={ ["RunAfterFARStart"]=1}; },
    {tp="chbox"; text="Disa&ble screen output";    x1=hw+6; y1="";  DefDialog=1;        Flags={ ["DisableOutput"]=1}; },
    {tp="chbox"; text="Command &line state";                        tristate=1; val=2;  Flags={ ["EmptyCommandLine"]=0; ["NotEmptyCommandLine"]=1;}, },
    {tp="chbox"; text="Block selection &presents"; x1=hw+6; y1="";  tristate=1; val=2;  Flags={ ["NoEVSelection"]=0,    ["EVSelection"]=1}, },
    {tp="text";  text="Active panel"; },
    {tp="text";  text="Passive panel";             x1=hw+6; y1=""; },
    {tp="chbox"; text="Plugin/file panel"; x1=7;                    tristate=1; val=2;  Flags={ ["NoPluginPanels"] =0, ["NoFilePanels"] =1}; },
    {tp="chbox"; text="Plugin/file panel"; x1=hw+8; y1="";          tristate=1; val=2;  Flags={ ["NoPluginPPanels"]=0, ["NoFilePPanels"]=1}; },
    {tp="chbox"; text="Folder/file under cursor"; x1=7;             tristate=1; val=2;  Flags={ ["NoFolders"]      =0, ["NoFiles"]      =1}; },
    {tp="chbox"; text="Folder/file under cursor"; x1=hw+8; y1="";   tristate=1; val=2;  Flags={ ["NoPFolders"]     =0, ["NoPFiles"]     =1}; },
    {tp="chbox"; text="Folder/file selected"; x1=7;                 tristate=1; val=2;  Flags={ ["NoSelection"]    =0, ["Selection"]    =1}; },
    {tp="chbox"; text="Folder/file selected"; x1=hw+8; y1="";       tristate=1; val=2;  Flags={ ["NoPSelection"]   =0, ["PSelection"]   =1}; },
    {tp="sep"; },
    {tp="vtext"; text="┬││││││┴"; x1=hw+4; ystep=-7; },
    ------------------------------------------------------------------------------------------------
    {tp="chbox"; text="S&end macro to plugins";    y1=17; DefDialog=1; DefInput=1;      Flags={ ["NoSendKeysToPlugins"]=0; }; },
    {tp="sep"; },
    ------------------------------------------------------------------------------------------------
    {tp="chbox"; text="Deactivate macr&o"; name="Deactivate"; },
    {tp="sep"; },
    ------------------------------------------------------------------------------------------------
    {tp="butt"; text="&Save";  default=1;    centergroup=1; },
    {tp="butt"; text="Check";  btnnoclose=1; centergroup=1; name="btnCheck"; },
    {tp="butt"; text="Cancel"; cancel=1;     centergroup=1; },
  }

  ---------------
  -- Preparations
  ---------------
  local Pos, Elem = sd.Indexes(items)

  -- Give all checkboxes a (numeric) names so that
  -- their final values appear in the output table.
  for pos,v in ipairs(items) do
    if v.tp=="chbox" and not v.name then v.name=pos; end
  end

  ---------------------------------
  -- Initialize from the input data
  ---------------------------------
  if type(aInput) ~= "table" then -- no input data
    local area = far.MacroGetArea()
    local item = items[Pos.WorkArea]
    if     area == F.MACROAREA_DIALOG         then item.val =  1
    elseif area == F.MACROAREA_DISKS          then item.val =  2
    elseif area == F.MACROAREA_EDITOR         then item.val =  3
    elseif area == F.MACROAREA_HELP           then item.val =  4
    elseif area == F.MACROAREA_INFOPANEL      then item.val =  5
    elseif area == F.MACROAREA_MAINMENU       then item.val =  6
    elseif area == F.MACROAREA_MENU           then item.val =  7
    elseif area == F.MACROAREA_QVIEWPANEL     then item.val =  8
    elseif area == F.MACROAREA_SEARCH         then item.val =  9
    elseif area == F.MACROAREA_SHELL          then item.val = 10
    elseif area == F.MACROAREA_TREEPANEL      then item.val = 11
    elseif area == F.MACROAREA_VIEWER         then item.val = 12
    elseif area == F.MACROAREA_OTHER          then item.val = 13
    elseif area == F.MACROAREA_FINDFOLDER     then item.val = 15
    elseif area == F.MACROAREA_USERMENU       then item.val = 16
    elseif area == F.MACROAREA_AUTOCOMPLETION then item.val = 17
    else                                           item.val = 14 -- Common
    end

    for _,v in ipairs(items) do
      if v.DefDialog then v.val=1 end
    end
  else
    for i,v in ipairs(items) do
      if v.DefInput then
        v.val = 1
      end
      if type(v.name)=="string" and aInput[v.name] ~= nil then
        local val = aInput[v.name]
        if v.tp == "edit" then
          if type(val) == "string" then
            v.val = val
          end
        elseif v.tp == "combobox" then
          for k,w in ipairs(AreaShortNames) do
            if w == val then v.val=k; break; end
          end
        elseif v.tp == "chbox" then
          v.val = val and val ~= 0
        end
      elseif v.Flags then
        for k,w in pairs(v.Flags) do
          if aInput[k] and aInput[k] ~= 0 then
            items[i].val = w
          end
        end
      end
    end
  end

  -------------------------------------
  -- Run the dialog and get output data
  -------------------------------------

  local function CheckSeq(hDlg)
    local seq = hDlg:GetText(Pos.Sequence)
    if far.MacroGetState() == F.MACROSTATE_NOMACRO then
      return far.MacroCheck(seq) == 0
    else
      -- do silent check due to FAR's lock-screen bug
      local code, posX, posY, msg = far.MacroCheck(seq,"KSFLAGS_SILENTCHECK")
      if code == 0 then return true end
      local errmsg = ("Line %d, Pos %d:\n%s"):format(posY, posX, msg)
      local title  = ("Error parsing macro (code %d)"):format(code)
      far.Message(errmsg, title, nil, "wl")
      return false
    end
  end

  Elem.btnCheck.action = CheckSeq

  local function ConvertOutput(raw)
    local out = {}
    for i,w in ipairs(items) do
      if w.tp == "edit" then
        if raw[w.name]:find("%S") then
          out[w.name] = raw[w.name]:match("^%s*(.-)%s*$") -- strip spaces from both ends
        end
      elseif w.tp == "combobox" then -- there is 1 combobox only
        out[w.name] = AreaShortNames[raw[w.name]]
      elseif w.tp == "chbox" then
        if w.Flags then
          for k,v in pairs(items[i].Flags) do
            v = (v ~= 0) -- convert 0,1 -> false,true
            if raw[i]==v then out[k]=1; break; end
          end
        elseif w.name then
          if raw[w.name] then out[w.name]=1; end -- [x] Deactivate macro
        end
      end
    end
    return out
  end

  items.closeaction = function(hDlg, Par1, tOut)
    local nm = tOut.MacroKey : match("^%s*(.-)%s*$")
    if not far.NameToKey(nm) then
      far.Message("Invalid Macro Key: "..nm, "Error", nil, "w")
      return KEEP_DIALOG_OPEN
    end
    if not (CheckSeq(hDlg) and aCanClose(ConvertOutput(tOut))) then
      return KEEP_DIALOG_OPEN
    end
  end

  local raw = sd.Run(items)
  return raw and ConvertOutput(raw)
end

return MacroDialog
