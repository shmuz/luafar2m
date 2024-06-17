-- [ coding: UTF-8 ]
-- Name:    Sqlarc (Far Manager plugin)
-- Started: 2019-12-25
-- Author:  Shmuel Zeigerman
------------------------------

-- Settings/Options ----------------------------------------------------------------------------
local Opt = {
  Application_id  = { 0x25,0x05,0x82,0x22 }; -- "sqlarc" literal: see misc\sqlite_app_id.lua
  RecordMaxSize   = 0x4000000; -- (64 MiB) max. size of a part when storing big files as multiple parts
  PutCommitSize   = 0x4000000; -- (64 MiB) total size of put and deleted files accumulated for commit
  GetChunkSize    = 0x100000;  -- (1 Mib) size of chunks to read from DB
  PutChunkSize    = 0x100000;  -- (1 Mib) size of chunks to write into DB
  PrBarMessageWid = 60;
  PrBarHeaderWid  = 10;
  PrBarUpdatePeriod = 0.1; -- (in seconds)
  FileExistsDialogGuid    = win.Uuid("E9C4F565-D4A1-4295-A87E-CC34A582D73A");
  ConfirmDeleteDialogGuid = win.Uuid("E9D1D88D-E8F7-4548-AD4B-4FA61DBD0AFF");
  ExtractDialogGuid       = win.Uuid("7804AF5A-0F67-467D-8879-670E2005B955");
  MakeFolderDialogGuid    = win.Uuid("E5A63040-CE75-4A43-8637-1D8CB233E05C");
  ExtractPathHistoryName  = "Sqlarc_extract_path";
  DefaultExtension        = ".sqlarc";
}
Opt.GetPrBarFileSize = 2*Opt.GetChunkSize; -- minimal file size to show progress (reading from DB)
Opt.PutPrBarFileSize = 2*Opt.PutChunkSize; -- minimal file size to show progress (writing to DB)
-- End of settings -----------------------------------------------------------------------------

far.ReloadDefaultScript = true

local F = far.Flags
local band, bor, bnot, bnew = bit64.band, bit64.bor, bit64.bnot, bit64.new

local sql3 = require "lsqlite3"
local SimpleDialog = require "far2.simpledialog"

local PluginGuid, Title do
  local info = far.GetPluginGlobalInfo()
  PluginGuid, Title = info.Guid, info.Title
end

local QCreateFiles = [[
CREATE TABLE sqlarc_files (
  id         INTEGER  PRIMARY KEY NOT NULL,
  parent     INTEGER  NOT NULL REFERENCES sqlarc_files(id) ON DELETE CASCADE ON UPDATE CASCADE,
  name       TEXT     NOT NULL COLLATE utf8_ncase,
  attrib     TEXT,
  t_create   INTEGER,
  t_write    INTEGER,
  isdir      INTEGER NOT NULL,
  -- columns used for files only --
  size       INTEGER DEFAULT 0,
  content    BLOB DEFAULT '',
  -- constraints --
  UNIQUE     (parent,name)
); ]]

local CheckAppId, SetAppId do
  local r1 = string.char(unpack(Opt.Application_id))
  local r2 = ("PRAGMA application_id=0x%02X%02X%02X%02X"):format(unpack(Opt.Application_id))
  CheckAppId = function(buf) return string.sub(buf,69,72) == r1; end
  SetAppId   = function(db) db:exec(r2); end
end

local function join(s1, s2)
  return win.JoinPath(s1, s2)
end

local function extract_name(fullpath)
  return fullpath:match("[^/]*$")
end

local function CommonErrMsg (msg)
  far.Message(msg, Title, nil, "w")
end

local function DbErrMsg (db)
  local msg, code = db:errmsg(), db:errcode()
  far.Message(debug.traceback(msg,2), "SQLite error ["..code.."]", nil, "lw")
  return false
end

-- Normalize a string. Use for schema, table and column names.
local function Norm (str)
  return "'" .. string.gsub(str, "'", "''") .. "'"
end

local function GetOneDbItem (db, query)
  local stmt, ret = db:prepare(query), nil
  if stmt then
    for item in stmt:nrows() do -- luacheck: only
      ret=item; break
    end
    stmt:finalize()
  end
  return ret
end

local function ClearSelection(item)
  item.Flags = band(item.Flags, bnot(F.PPIF_SELECTED))
end

local function SetFileTimes (TrgFileName, SrcItem)
  return win.SetFileTimes(TrgFileName, {
    CreationTime = bnew(SrcItem.t_create) * 10000; -- convert 1ms to 100ns
    LastWriteTime = bnew(SrcItem.t_write) * 10000; })
end

local function FormatDataForDialog(element)
  local strsize = tostring(element.size):reverse():gsub("...","%0,"):reverse():gsub("^,","")
  local st = win.FileTimeToSystemTime(win.FileTimeToLocalFileTime(element.t_write))
  return ("%s %04d/%02d/%02d %02d:%02d:%02d"):format(
    strsize, st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond)
end

--[[
╔═════════════════════════════ Warning ══════════════════════════════╗
║                        File already exists                         ║
║ C:\Shmuel_Home\BB\F\Today\11\Lua\alien\alien-0.5.1.zip             ║
╟────────────────────────────────────────────────────────────────────╢
║ New                                    1009157 18/04/2014 12:43:54 ║
║ Existing                               1009157 18/04/2014 12:43:54 ║
╟────────────────────────────────────────────────────────────────────╢
║ [ ] Remember choice                                                ║
╟────────────────────────────────────────────────────────────────────╢
║      { Overwrite } [ Skip ] [ Rename ] [ Append ] [ Cancel ]       ║
╚════════════════════════════════════════════════════════════════════╝
--]]

local function MakeButtonText(sLeft, sRight, nLen)
  return sLeft .. (" "):rep(nLen - sLeft:len() - sRight:len()) .. sRight
end

local function SelectAction(state, filename, new_elem, old_elem)
  local W = 66
  local sNew   = MakeButtonText("New",      FormatDataForDialog(new_elem), W)
  local sExist = MakeButtonText("Existing", FormatDataForDialog(old_elem), W)
  local c1,c2 = "COL_WARNDIALOGTEXT","COL_WARNDIALOGEDITSELECTED"
  local Items = {
    guid = Opt.FileExistsDialogGuid;
    width = W + 10;
    flags = F.FDLG_WARNING;
    ----------------------------------------------------------------------------
    {tp="dbox"; text=Title;                                                   },
    {tp="text"; text="File already exists"; centertext=1;                     },
    {tp="edit"; text=filename; readonly=1; colors={c1,c2,c1,c1};              },
    {tp="sep";                                                                },
    ----------------------------------------------------------------------------
    {tp="butt"; text=sNew;   btnnoclose=1; nobrackets=1;                      },
    {tp="butt"; text=sExist; btnnoclose=1; nobrackets=1;                      },
    {tp="sep";                                                                },
    ----------------------------------------------------------------------------
    {tp="chbox"; text="Remember choice"; focus=1; name="remember";            },
    {tp="sep";                                                                },
    ----------------------------------------------------------------------------
    {tp="butt"; text="&Overwrite"; centergroup=1; default=1; Act="overwrite"; },
    {tp="butt"; text="&Skip";      centergroup=1;            Act="skip";      },
    {tp="butt"; text="&Cancel";    centergroup=1; cancel=1;                   },
  }

  local out, ret = SimpleDialog.New(Items):Run()
  local action = out and Items[ret].Act
  if action then
    if out.remember then state.action = action; end
  else
    action = "skip"
    state.fullcancel = true
  end
  return action
end

local function GetFullDirPath(db, id)
  local t = {}
  while id ~= 1 do
    local item = GetOneDbItem(db, ("SELECT name,parent FROM sqlarc_files WHERE id=%d"):format(id))
    table.insert(t, 1, item.name)
    id = item.parent
  end
  return table.concat(t, "/")
end

local function GetPanelTitle(shorthostname, path)
  local title = "sqlarc:"..shorthostname
  if path ~= "" then title = title..":/"..path end
  return title
end

-- can return either of: false, "pristine", "exist"
local function CheckSqlarc(db)
  local stmt = db:prepare("SELECT rowid FROM sqlarc_files") -- check table 'sqlarc_files' existence
  if not stmt then return "pristine" end -- the table does not exist
  stmt:finalize()
  stmt = db:prepare("SELECT id,parent,name,attrib FROM sqlarc_files") -- check columns existence
  if not stmt then return false; end
  stmt:finalize()
  return "exist"
end

local function GetArchiveFileName()
  local actInfo = panel.GetPanelInfo(nil,1)
  if actInfo.SelectedItemsNumber==0 then return false end

  local filename
  local single = actInfo.SelectedItemsNumber==1 and
                 extract_name(panel.GetSelectedPanelItem(nil,1).FileName)
  local isAPanelPlugin = band(actInfo.Flags,F.PFLAGS_PLUGIN) ~= 0

  if isAPanelPlugin then -- use passive panel or user profile directory as the target directory
    local isPPanelPlugin = band(panel.GetPanelInfo(nil,0).Flags, F.PFLAGS_PLUGIN) ~= 0
    local dir = isPPanelPlugin and (win.GetEnv("USERPROFILE") or "") or
                panel.GetPanelDirectory(nil,0).Name
    filename = join(dir, single or "archive")
  else -- use active panel as the target directory
    if single then
      filename = single
    else
      local dir = panel.GetPanelDirectory(nil,1)
      local name = extract_name(dir)
      filename = join(dir, name=="" and "root" or name)
    end
  end

  filename = far.InputBox(
      nil,                            -- Id
      Title..": create archive",      -- Title
      "Archive path:",                -- Prompt
      nil,                            -- HistoryName
      filename..Opt.DefaultExtension) -- SrcText
  return filename and far.ConvertPath(filename)
end

local function CreateObject(filename)
  local bCreateArchive = false
  if not filename then
    bCreateArchive = true
    filename = GetArchiveFileName()
    if not filename then return false end
  end

  local attr = win.GetFileAttr(filename)
  local bNewFile = not attr
  if attr then
    if attr:find("d") then
      return false
    elseif bCreateArchive then
      local msg = "File \""..filename.."\" already exists.\nDo you want to overwrite it?"
      if 1 == far.Message(msg, Title, ";YesNo", "w") then
        if win.DeleteFile(filename) then
          bNewFile = true
        else
          CommonErrMsg("Could not delete file:\n"..filename)
          return false
        end
      else
        return false
      end
    end
  end

  local db = sql3.open(filename)
  if not db then
    CommonErrMsg("Cannot open file:\n"..filename)
    return false
  end
  db:create_collation("utf8_ncase", utf8.ncasecmp)

  -- sql3.open() won't fail on a non-DB file, let's work around with a statement
  local stmt = db:prepare("SELECT * FROM sqlite_master")
  if not stmt then
    -- DbErrMsg(db)
    db:close()
    CommonErrMsg("Probably not an SQLite file:\n"..filename)
    return false
  end
  stmt:finalize()

  -- check the existing database file
  local check = CheckSqlarc(db)
  if not check then return false; end

  if check == "pristine" then
    if not bNewFile then
      -- ask user if it is OK to modify an existing database file
      local query = "To open this file as an Sqlarc archive 2 tables need to be added. Continue?"
      if 1 ~= far.Message(query, Title, ";YesNo", "w") then return false; end
    end
    -- create tables
    db:exec(QCreateFiles)
    -- create hidden directories
    local time = tostring(win.GetSystemTimeAsFileTime())
    db:exec(([[
      INSERT INTO sqlarc_files(id,parent,name,isdir,attrib,t_create) VALUES(0,0,'dummy',1,'d',%s);
      INSERT INTO sqlarc_files(id,parent,name,isdir,attrib,t_create) VALUES(1,0,'\\',   1,'d',%s);
    ]]):format(time,time))
    -- set application_id (only for newly created database file)
    if bNewFile then SetAppId(db); end
  end

  -- turn on foreign keys support
  db:exec("PRAGMA foreign_keys = ON")
  -- create the object and return it
  local fullpath = GetFullDirPath(db, 1)
  local obj = {
    db = db;
    curdir = 1;
    shorthostname = filename:match("[^/]+$");
  }
  obj.openpanelinfo = {
    CurDir = fullpath;
    HostFile = filename;
    PanelTitle = GetPanelTitle(obj.shorthostname, fullpath);
    StartSortMode = nil;  -- F.SM_UNSORTED;
    StartSortOrder = nil; -- 0;
    Flags = F.OPIF_ADDDOTS;
    IsCached = false; -- caching must be reset after any change on this table
  }
  return obj
end

function export.Analyse(Data)
  if Data.FileName == nil then -- ShiftF1
    return true
  else
    return string.find(Data.Buffer,"^SQLite format 3") and CheckAppId(Data.Buffer)
  end
end

function export.OpenFilePlugin(FileName, Data, OpMode)
  if FileName == nil then -- ShiftF1
    return CreateObject()
  elseif string.find(Data,"^SQLite format 3") and CheckAppId(Data) then
    return CreateObject(FileName)
  end
end

function export.GetPluginInfo()
  local info = { Flags=0 }
  info.CommandPrefix = "sqlarc"
  info.PluginMenuGuids = PluginGuid
  info.PluginMenuStrings = { Title }
  -- info.PluginConfigGuids = PluginGuid
  -- info.PluginConfigStrings = { M.ps_title }
  return info
end

local function SetDir(obj, path)
  local cur_id = (path=="" or path:find("^/")) and 1 or obj.curdir
  for dir in path:gmatch("[^/]+") do
    local query = ("SELECT id FROM sqlarc_files WHERE isdir=1 AND parent=%d AND name=%s"):
      format(cur_id, Norm(dir))
    local item = GetOneDbItem(obj.db, query)
    if item then
      cur_id = item.id
    else
      return nil
    end
  end
  return cur_id
end

function export.Open(OpenFrom, Guid, Data)
  if OpenFrom == F.OPEN_ANALYSE then
    return CreateObject(Data.FileName)

  elseif OpenFrom == F.OPEN_SHORTCUT then
    local obj = CreateObject(Data.HostFile)
    if obj then
      if Data.ShortcutData then
        obj.curdir = SetDir(obj, Data.ShortcutData)
      end
      local fullpath = GetFullDirPath(obj.db, obj.curdir)
      local opi = obj.openpanelinfo
      opi.CurDir = fullpath
      opi.PanelTitle = GetPanelTitle(obj.shorthostname, fullpath)
      opi.IsCached = false
      return obj
    end

  elseif OpenFrom == F.OPEN_PLUGINSMENU then
    -- Make sure that current panel item is a real existing file.
    local info = panel.GetPanelInfo(nil,1)
    if info and info.PanelType==F.PTYPE_FILEPANEL --[[and band(info.Flags,F.OPIF_REALNAMES)~=0]] then
      local item = panel.GetCurrentPanelItem(nil,1)
      if item and not item.FileAttributes:find("d") then
        return CreateObject(far.ConvertPath(item.FileName,"CPM_FULL"))
      end
    end

  elseif OpenFrom == F.OPEN_COMMANDLINE then
    Data = Data:match("^%s*(.-)%s*$")
    return CreateObject(far.ConvertPath(Data))
  end
end

function export.GetFindData(obj, handle, OpMode)
  -- Important: do not do "SELECT * ..." as it causes creation
  -- of potentially very large Lua strings due to the field 'content'.
  local items = {}
  local stmt = obj.db:prepare( [[SELECT name, attrib, size, t_create, t_write
    FROM sqlarc_files WHERE parent=]]..obj.curdir)
  for item in stmt:nrows() do
    table.insert(items, {
      FileName = item.name;
      FileAttributes = item.attrib;
      FileSize = item.size;
      CreationTime = item.t_create;
      LastWriteTime = item.t_write;
    })
  end
  stmt:finalize()
  return items
end

function export.GetOpenPanelInfo(obj, handle)
  local opi = obj.openpanelinfo
  if not opi.IsCached then -- caching this table is needed because of performance issues
    local key = "count(*)"
    local dnum = GetOneDbItem(obj.db, "SELECT "..key.." FROM sqlarc_files WHERE isdir<>0 AND id>=2")
    local fnum = GetOneDbItem(obj.db, "SELECT "..key.." FROM sqlarc_files WHERE isdir=0")

    opi.InfoLines = {
      { Text="File count";      Data=fnum[key] },
      { Text="Directory count"; Data=dnum[key] },
    }
    opi.InfoLinesNumber = #opi.InfoLines -- for compatibility with old LuaFAR versions
    opi.IsCached = true
  end
  return opi
end

local TUserBreak = {
  fullcancel = nil;
}
local UserBreakMeta = { __index=TUserBreak }

local function NewUserBreak(properties)
  properties = properties or {}
  properties.time = 0
  return setmetatable(properties, UserBreakMeta)
end

function TUserBreak:ConfirmEscape (in_file)
  local ret = false
  if win.ExtractKey() == "ESCAPE" then
    local hScreen, hScreen2 = far.SaveScreen(), nil
    local msg = "Operation has been interrupted.\nDo you really want to cancel it?"
    if in_file then
      local r = far.Message(msg, Title, "Cancel current file;Cancel all files;Continue", "w")
      if r==1 or r==2 then
        ret = true
        hScreen2 = far.SaveScreen()
        if r==1 then self.cancel = true
        else self.fullcancel = true
        end
      end
    else
      if 1 == far.Message(msg, Title, ";YesNo", "w") then
        ret, self.fullcancel = true, true
        hScreen2 = far.SaveScreen()
      end
    end
    far.RestoreScreen(hScreen)
    if hScreen2 then far.RestoreScreen(hScreen2) end
    far.Text()
  end
  return ret
end

local function set_progress (LEN, ratio)
  local uchar = ("").char
  local uchar1, uchar2 = uchar(9608), uchar(9617)
  local len = math.floor(ratio*LEN + 0.5)
  local text = uchar1:rep(len) .. uchar2:rep(LEN-len) .. ("%3d%%"):format(ratio*100)
  return text
end

local DisplaySearchState do
  local lastclock = 0
  local wTail = Opt.PrBarMessageWid - Opt.PrBarHeaderWid - 3
  DisplaySearchState = function (fullname, cntFound, cntTotal, ratio, strOp, force)
    local newclock = win.Clock()
    if force or newclock >= lastclock then
      lastclock = newclock + Opt.PrBarUpdatePeriod
      local len = fullname:len()
      local s = len<=Opt.PrBarMessageWid and fullname..(" "):rep(Opt.PrBarMessageWid-len) or
        fullname:sub(1,Opt.PrBarHeaderWid).. "..." .. fullname:sub(-wTail)
      local text = ("%s\n%s\nFiles %s: %d/%d"):format(s, set_progress(Opt.PrBarMessageWid-4, ratio),
        strOp, cntFound, cntTotal)
      far.Message(text, Title, "")
    end
  end
end

local function ExtractFile(state, parent_id, file_name, DestPath, Move)
  local db = state.db

  local query = ([[SELECT id,attrib,size,t_create,t_write FROM sqlarc_files
    WHERE isdir=0 AND parent=%d AND name=%s]]):format(parent_id, Norm(file_name))
  local Item = GetOneDbItem(db, query)
  if not Item then return false; end

  local fullname = join(DestPath, file_name)
  local attr = win.GetFileAttr(fullname)
  if attr then
    if attr:find("d") then
      return false
    end
    local file = win.GetFileInfo(fullname)
    if not file then
      return false
    end
    local action = state.action
    if not action then
      local new_elem = {size=Item.size, t_write=Item.t_write}
      local old_elem = {size=file.FileSize, t_write=file.LastWriteTime}
      action = SelectAction(state, fullname, new_elem, old_elem)
    end
    if action=="skip" or
       action=="overwrite" and not (win.SetFileAttr(fullname,"") and win.DeleteFile(fullname))
    then
      return false
    end
  end

  local Fp = io.open(fullname, "wb")
  if not Fp then
    -- CommonErrMsg("Cannot open file:\n\""..fullname.."\"")
    return false
  end

  local curr_id = Item.id
  local show_progress = (Item.size >= Opt.GetPrBarFileSize)
  local OK, Esc = true, false
  local Pos = 0

  while true do
    local Blob = db:open_blob("main", "sqlarc_files", "content", curr_id, 0)
    if not Blob then OK=false; break; end

    local blobsize = Blob:bytes()
    local pos = 0
    while OK and (pos < blobsize) do
      if show_progress then
        if not state.silent_mode then
          DisplaySearchState(file_name, state.nfiles, state.nfiles, (Pos+pos)/Item.size, "extracted")
        end
        Esc = state:ConfirmEscape(true)
        if Esc then break end
      end
      local nbytes = math.min(blobsize-pos, Opt.GetChunkSize)
      Fp:write(Blob:read(nbytes, pos))
      pos = pos + nbytes
      OK = Fp:seek()==(Pos+pos)
    end

    Blob:close()
    Pos = Pos + blobsize
    if Esc then break; end

    local next_part = GetOneDbItem(db, "SELECT id FROM sqlarc_files WHERE parent="..curr_id)
    if not next_part then break; end
    curr_id = next_part.id
  end
  Fp:close()

  if OK and not Esc then
    SetFileTimes(fullname, Item)
    win.SetFileAttr(fullname, Item.attrib)
    state.nfiles = state.nfiles + 1
    if not state.silent_mode then
      DisplaySearchState(file_name, state.nfiles, state.nfiles, 0, "extracted")
    end
    if Move then
      local query = ("DELETE FROM sqlarc_files WHERE isdir=0 AND parent=%d AND name=%s"):
        format(parent_id, Norm(file_name))
      db:exec(query)
    end
    return true
  else
    win.DeleteFile(fullname)
    return false
  end
end

local function ExtractTree(state, parent_id, tree_name, DestPath, Move)
  local db = state.db
  local path = join(DestPath, tree_name)
  local result = win.CreateDir(path, "t")
  if result then
    local t_query = ("SELECT * FROM sqlarc_files WHERE isdir=1 AND parent=%d AND name=%s"):
      format(parent_id, Norm(tree_name))
    local item = GetOneDbItem(db, t_query)
    local q = ("SELECT name,isdir FROM sqlarc_files WHERE parent=%d"):format(item.id)
    for f in db:nrows(q) do
      if f.isdir == 0 then
        result = ExtractFile(state, item.id, f.name, path, false) and result
      else
        result = ExtractTree(state, item.id, f.name, path, false) and result
      end
      if state.fullcancel or state:ConfirmEscape(false) then
        result = false
        break
      end
    end
    -- set directory times *after* extracting child subdirs and files
    -- to avoid write times modification.
    SetFileTimes(path, item)
    if Move and result then
      local q = ("DELETE FROM sqlarc_files WHERE isdir=1 AND parent=%d AND name=%s"):
        format(parent_id, Norm(tree_name))
      db:exec(q)
    end
  end
  return result
end

function export.GetFiles(obj, handle, PanelItems, Move, DestPath, OpMode)
  if not (PanelItems[1] and PanelItems[1].FileName ~= "..") then
    return 0 -- bug: Far calls GetFilesW on F5 press when the cursor stands on ".."
  end

  local silent_mode = 0 ~= band(OpMode, bor(F.OPM_SILENT, F.OPM_FIND))
  if not silent_mode then
    DestPath = far.InputBox(Opt.ExtractDialogGuid, "Extract files", "&Extract files to",
                            Opt.ExtractPathHistoryName, DestPath)
    if DestPath then
      DestPath = far.ConvertPath(DestPath, "CPM_FULL") -- convert relative path (if any) to absolute
    else
      return 0 -- user canceled the dialog
    end
  end

  if not win.CreateDir(DestPath, "t") then
    if not silent_mode then
      CommonErrMsg(("Invalid destination path:\n\"%s\""):format(DestPath))
    end
    return 0
  end

  local result = 1
  local state = NewUserBreak {
    action = silent_mode and "overwrite";
    db = obj.db;
    nfiles = 0;
    silent_mode = silent_mode;
  }
  for _,item in ipairs(PanelItems) do
    if state.fullcancel or state:ConfirmEscape(false) then
      return -1
    end
    local OK
    if item.FileAttributes:find("d") then
      OK = ExtractTree(state, obj.curdir, item.FileName, DestPath, Move)
    else
      OK = ExtractFile(state, obj.curdir, item.FileName, DestPath, Move)
    end
    if OK then
      ClearSelection(item)
    else
      result = 0
    end
  end
  return result
end

function export.MakeDirectory(obj, handle, _, OpMode)
  local Name = far.InputBox(Opt.MakeFolderDialogGuid, "Make folder", "Create the folder:")
  if Name then
    local time = tostring(win.GetSystemTimeAsFileTime())
    local query =
      "INSERT INTO sqlarc_files(parent,name,isdir,attrib,t_create,t_write) VALUES(?,?,1,'d',?,?)"
    local stmt = obj.db:prepare(query)
    stmt:bind(1, obj.curdir)
    stmt:bind(2, Name)
    stmt:bind(3, time)
    stmt:bind(4, time)
    local result = (stmt:step()==sql3.DONE) and 1 or 0
    stmt:finalize()
    return result, Name
  else
    return -1
  end
end

function export.SetDirectory (obj, handle, Dir, OpMode, UserData)
--win.OutputDebugString("Dir: "..Dir)
  local result = false
  if Dir == ".." then
    if obj.curdir ~= 1 then
      local q = ("SELECT parent FROM sqlarc_files WHERE isdir=1 AND id=%d"):format(obj.curdir)
      local item = GetOneDbItem(obj.db, q)
      if item then
        obj.curdir, result = item.parent, true
      end
    end
  else
    local cur_id = SetDir(obj, Dir)
    if cur_id then
      obj.curdir, result = cur_id, true
    end
  end
  if result then
    local fullpath = GetFullDirPath(obj.db, obj.curdir)
    local opi = obj.openpanelinfo
    opi.CurDir = fullpath
    opi.PanelTitle = GetPanelTitle(obj.shorthostname, fullpath)
    opi.IsCached = false
  end
  return result
end

local function PutDirectory(state, item, parent_id)
  local stmt = state.d_stmt
  stmt:reset()
  stmt:bind(1, parent_id)
  stmt:bind(2, item.FileName)
  stmt:bind(3, item.FileAttributes)
  stmt:bind(4, tostring(item.CreationTime))
  stmt:bind(5, tostring(item.LastWriteTime))
  stmt:step()
end

local function PutFile(state, SrcPath, Item, parent_id)
  local db, f_stmt = state.db, state.f_stmt

  local fullname, filename
  if Item.FileName:find("^/") then -- TmpPanel, etc.
    fullname = Item.FileName
    filename = fullname:gsub(".*/", "")
  else -- Far panel
    fullname = join(SrcPath, Item.FileName)
    filename = Item.FileName
  end

  local query = ("SELECT id,isdir,size,t_write FROM sqlarc_files WHERE parent=%d AND name=%s"):
    format(parent_id, Norm(filename))
  local existing = GetOneDbItem(db, query)
  if existing then
    if existing.isdir ~= 0 then
      return false -- cannot put file when a subdirectory with that name exists
    else
      local action = state.action
      if not action then
        local new_elem = {size=Item.FileSize, t_write=Item.LastWriteTime}
        local old_elem = {size=existing.size, t_write=existing.t_write}
        action = SelectAction(state, filename, new_elem, old_elem)
      end
      if action == "skip" then
        return false
      else -- overwrite
        if 0 == db:exec("DELETE FROM sqlarc_files WHERE id="..existing.id) then
          state.accum = state.accum + existing.size
        else
          return DbErrMsg(db)
        end
      end
    end
  end

  if state.Fp then state.Fp:close(); end
  state.Fp = io.open(fullname, "rb")
  if not state.Fp then return false end

  local cur_parent_id = parent_id
  local show_progress = (Item.FileSize >= Opt.PutPrBarFileSize)
  local total_left = Item.FileSize

  local part1_id = false
  local function DeleteThisEntry()
    if part1_id then
      db:exec("DELETE FROM sqlarc_files WHERE isdir=0 AND rowid="..part1_id)
    end
  end

  repeat
    if state.accum >= Opt.PutCommitSize then
      db:exec("COMMIT; BEGIN TRANSACTION;")
      state.accum = 0
    end

    local part_nbytes = math.min(total_left, Opt.RecordMaxSize)
    f_stmt:reset()
    if not (true
      and 0==f_stmt:bind(1, cur_parent_id)
      and 0==f_stmt:bind(2, filename)
      and 0==f_stmt:bind(3, Item.FileAttributes)
      and 0==f_stmt:bind(4, Item.FileSize)
      and 0==f_stmt:bind(5, tostring(Item.CreationTime))
      and 0==f_stmt:bind(6, tostring(Item.LastWriteTime))
      and 0==f_stmt:bind_zeroblob(7, part_nbytes) )
    then
      DbErrMsg(db)
      DeleteThisEntry()
      return false
    end

    if f_stmt:step() == sql3.DONE then
      if cur_parent_id == parent_id then
        part1_id = db:last_insert_rowid()
      end
    else
      DbErrMsg(db)
      DeleteThisEntry()
      return false
    end

    if total_left > 0 then
      cur_parent_id = db:last_insert_rowid()
      local Blob = db:open_blob("main", "sqlarc_files", "content", cur_parent_id, 1)
      if Blob then
        local total_pos = Item.FileSize - total_left
        local pos, left = 0, part_nbytes
        while left > 0 do
          if show_progress then
            DisplaySearchState(fullname, state.nfiles, state.nfiles, (total_pos+pos)/Item.FileSize, "added")
            if state:ConfirmEscape(true) then
              Blob:close()
              DeleteThisEntry()
              return false
            end
          end
          local nbytes = math.min(left, Opt.PutChunkSize)
          Blob:write(state.Fp:read(nbytes), pos)
          pos = pos + nbytes
          left = left - nbytes
        end
        Blob:close()
        total_left = total_left - part_nbytes
        state.accum = state.accum + part_nbytes
      else
        DeleteThisEntry()
        return false
      end
    end
  until total_left == 0

  state.nfiles = state.nfiles + 1
  DisplaySearchState(fullname, state.nfiles, state.nfiles, 0, "added")
  return true
end

local function PutTree(state, SrcPath, dir_item, parent_id)
  PutDirectory(state, dir_item, parent_id)
  local query = ("SELECT id FROM sqlarc_files WHERE isdir=1 AND parent=%d AND name=%s"):
    format(parent_id, Norm(dir_item.FileName))
  local curr_id
  for id in state.db:urows(query) do curr_id=id; break; end -- luacheck: only
  if not curr_id then return false; end

  local result = true
  local dir_path = join(SrcPath, dir_item.FileName)
  far.RecursiveSearch(dir_path, "*",
    function(item, fullpath)
      if state:ConfirmEscape(false) then
        result = false; return true
      else
        if item.FileAttributes:find("d") then
          result = PutTree(state, dir_path, item, curr_id) and result
        else
          result = PutFile(state, dir_path, item, curr_id) and result
        end
        if state.fullcancel then return true; end
      end
    end) -- not recursive
  return result
end

function export.PutFiles(obj, handle, Items, Move, SrcPath, OpMode)
  if Items[1].FileName == ".." then
    return 0 -- bug: Far calls PutFilesW on F5 press when the cursor stands on ".." - even without a dialog
  end

  local f_query = [[INSERT INTO sqlarc_files(parent,name,isdir,attrib,size,t_create,t_write,content)
                    VALUES(?,?,0,?,?,?,?,?)]]
  local d_query = [[INSERT INTO sqlarc_files(parent,name,isdir,attrib,t_create,t_write)
                    VALUES(?,?,1,?,?,?)]]
  local state = NewUserBreak {
    db     = obj.db;
    f_stmt = obj.db:prepare(f_query);
    d_stmt = obj.db:prepare(d_query);
    nfiles = 0;
    accum  = 0;   -- accumulated (not committed) bytes
    Fp     = nil; -- file handle
    action = band(OpMode, F.OPM_SILENT) ~= 0 and "overwrite";
  }

  obj.db:exec("BEGIN TRANSACTION")
  local result = 1
  for _,item in ipairs(Items) do
    local OK
    state.cancel = false
    if item.FileAttributes:find("d") then
      OK = PutTree(state, SrcPath, item, obj.curdir)
    else
      OK = PutFile(state, SrcPath, item, obj.curdir)
    end
    if state.fullcancel then result = -1; break;
    elseif state.cancel then result = -1;
    elseif OK           then ClearSelection(item);
    elseif result ~= -1 then result = 0;
    end
  end
  DisplaySearchState("Please wait...", state.nfiles, state.nfiles, 0, "added", true)
  obj.db:exec("COMMIT")

  state.d_stmt:finalize()
  state.f_stmt:finalize()
  if state.Fp then state.Fp:close(); end
  far.AdvControl("ACTL_REDRAWALL")
  return result
end

function export.DeleteFiles(obj, handle, PanelItems, OpMode)
  if #PanelItems==1 and PanelItems[1].FileName==".." then
    return false
  end
  local canDelete = band(OpMode,F.OPM_SILENT) ~= 0
    or 1 == far.Message("Confirm deletion", Title, ";YesNo", "w", nil, Opt.ConfirmDeleteDialogGuid)
  if canDelete then
    obj.db:exec("BEGIN TRANSACTION")
    for _,item in ipairs(PanelItems) do
      local isdir = item.FileAttributes:find("d") and 1 or 0
      local query = ("DELETE FROM sqlarc_files WHERE isdir=%d AND name=%s AND parent=%d"):
        format(isdir, Norm(item.FileName), obj.curdir)
      obj.db:exec(query)
    end
    obj.db:exec("COMMIT")
    return true
  end
  return false
end

function export.ProcessHostFile(obj, handle, PanelItems, OpMode)
  local item_vacuum = { text="Vacuum" }
  local props = { Title="Sqlarc commands" }
  local items = { item_vacuum }

  local res_item = far.Menu(props, items)
  if res_item == item_vacuum then
    far.Message("Please wait...", Title, "")
    obj.db:exec("VACUUM")
    panel.UpdatePanel(nil, 1)
    far.AdvControl("ACTL_REDRAWALL")
  end
end

function export.ClosePanel(obj, handle)
  obj.db:close()
end

-- local oldexport = export
-- export = setmetatable(
--   { GetGlobalInfo=export.GetGlobalInfo; }, -- GetGlobalInfo is in another file that is not reloaded
--   { __index=function(t,key) win.OutputDebugString(key) return rawget(oldexport,key) end; })
