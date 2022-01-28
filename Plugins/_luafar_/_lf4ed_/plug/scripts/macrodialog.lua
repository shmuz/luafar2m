-- coding: utf-8
-- luacheck: max_line_length 160
-- luacheck: read_globals far

local sd = require "far2.simpledialog"
local F = far.Flags

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

local function MacroDialog (input)
  local hw = 33 -- half-width of space inside the double-box
  local items = {
    width=2*hw+10;
    {tp="dbox"; text="Macro settings"; },
    {tp="text"; text="Command of e&xecution"; width=hw-2; },
    {tp="edit"; hist="MacroKey";           name="MacroKey"; width=hw-2; },
    {tp="text"; text="&Work area"; ystep=-1; x1=hw+6; },
    {tp="combobox"; x1="";                 name="WorkArea"; dropdownlist=1; list=AreaList; },
    {tp="sep"; },
    {tp="vtext"; x1=hw+4; y1=2; y2=4; text="││┴"; },
    ------------------------------------------------------------------------------------------------
    {tp="text"; text="Sequen&ce"; y1=5; },
    {tp="edit";   hist="MacroCmd";         name="Sequence"; focus=1; },
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
    {tp="butt"; text="Check";  btnnoclose=1; centergroup=1; Action="check"; },
    {tp="butt"; text="Cancel"; cancel=1;     centergroup=1; },
  }

  ---------------
  -- Preparations
  ---------------
  local Pos = sd.Indexes(items)

  -- Give all checkboxes a (numeric) names so that
  -- their final values appear in the output table.
  for pos,v in ipairs(items) do
    if v.tp=="chbox" and not v.name then v.name=pos; end
  end

  ---------------------------------
  -- Initialize from the input data
  ---------------------------------
  if type(input) ~= "table" then -- no input data
    for _,v in ipairs(items) do
      if v.DefDialog then v.val=1 end
    end
  else
    for i,v in ipairs(items) do
      if v.DefInput then
        v.val = 1
      end
      if type(v.name)=="string" and input[v.name] ~= nil then
        local val = input[v.name]
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
          if input[k] and input[k] ~= 0 then
            items[i].val = w
          end
        end
      end
    end
  end

  -------------------------------------
  -- Run the dialog and get output data
  -------------------------------------
  items.proc = function(hDlg, Msg, Par1, Par2) -- luacheck: ignore Par2
    if Msg == F.DN_BTNCLICK then
      if items[Par1].Action == "check" then
        local seq = far.SendDlgMessage(hDlg, "DM_GETTEXT", Pos.Sequence)
        far.MacroCheck(seq) -- it pops up a red message box if not OK
      end
    end
  end

  local raw = sd.Run(items)
  if not raw then return nil end
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
        if raw[w.name] then out[w.name]=1; end
      end
    end
  end

  return out
end

return MacroDialog
