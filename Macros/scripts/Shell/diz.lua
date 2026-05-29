-- Started:      2026-05-27
-- Author:       Shmuel Zeigerman
-- Purpose:      "Describe files" functionality with a multi-line dialog editor
-- Portability:  far2m (only)
-- Plugin:       LuaMacro (only)

local MacroKey = "CtrlShiftZ"

local Eng = {
  Title       = "Describe file";
  EnterDescr  = "Enter description for";
  ButtWrite   = "&1 Write";
  ButtSkip    = "&2 Skip";
  ButtDelete  = "&3 Delete";
  ButtCancel  = "&4 Cancel";
  Error       = "Error";
  ErrOpenFile = "Could not open file";
}

local Rus = {
  Title       = "Описание файла";
  EnterDescr  = "Введите описание для";
  ButtWrite   = "&1 Записать";
  ButtSkip    = "&2 Пропустить";
  ButtDelete  = "&3 Удалить";
  ButtCancel  = "&4 Отмена";
  Error       = "Ошибка";
  ErrOpenFile = "Ошибка открытия файла";
}

local F = far.Flags -- luacheck:ignore (unused)
local M = Eng

local OP_WRITE, OP_DELETE, OP_SKIP = 1,2,3
local Utf8Bom = "\239\187\191"

local function EscapeFileName(name)
  return name:find( "[%s\"]" )
    and '"' .. name:gsub("[\"\\]", "\\%0") .. '"' or name
end

local SplitPatt = [[
  ^(?:
      " ( (?: \\ | \" | [^"] )+ ) "
      |
      ( \S+ )
   )
   \s?
   ( .* )
]]

local function SplitDizLine(str)
  local c1, c2, c3 = regex.match(str, SplitPatt, 1, "x")
  c1 = c1 and c1:gsub("\\([\"\\])", "%1")
  return c1 or c2, c3
end

local DizList = {}
local DizListMeta = { __index=DizList }

local function NewDizList()
  local self = {
    DizData = {};
    Map = {};
  }
  return setmetatable(self, DizListMeta)
end

local function GetDiz(fname, diz)
  local sd = require "far2.simpledialog"
  local Prompt = ("%s \"%s\":"):format(M.EnterDescr, fname)
  local Items = {
    guid = "3371CF06-7F0B-45DF-8591-7CFE53E2DAC7";
    -- help = "Contents";
    -- width = 76;
    { tp="dbox"; text=M.Title; },
    { tp="text"; text=Prompt; },
    { tp="memo"; height=5; val=diz; name="memo"; },
    { tp="sep" },
    { tp="butt"; centergroup=1; text=M.ButtWrite;  name="write";  default=1; },
    { tp="butt"; centergroup=1; text=M.ButtSkip;   name="skip"; },
    { tp="butt"; centergroup=1; text=M.ButtDelete; name="delete"; },
    { tp="butt"; centergroup=1; text=M.ButtCancel; cancel=1; },
  }

  local Dlg = sd.New(Items)
  local Pos = Dlg:Indexes()

  ---- Uncomment this if you want the Tab key to be handled by the editor.
  -- function Items.proc(hDlg, Msg, Param1, Param2)
  --   if Msg == "EVENT_KEY" and Param1 == Pos.memo and Param2 == "Tab" then
  --     editor.ProcessKey(nil, F.KEY_TAB)
  --     return true -- tell Far the key was processed
  --   end
  -- end

  local out, pos = Dlg:Run()
  if out then
    if pos == Pos.write then
      if out.memo:find("%S") then
        return OP_WRITE, out.memo
      else
        return OP_DELETE
      end
    elseif pos == Pos.skip then
      return OP_SKIP
    elseif pos == Pos.delete then
      return OP_DELETE
    end
  end
  return nil
end

local function GetString(Fp, CodePage)
  local DoConvert = false
  if CodePage ~= 65001 then
    local Info = win.GetCPInfo(CodePage)
    DoConvert = Info and Info.MaxCharSize == 1
  end
  return function()
    local line = Fp:read("*l")
    if line and DoConvert then
      line = win.MultiByteToWideChar(line, CodePage)
      line = win.WideCharToMultiByte(line, 65001)
    end
    return line
  end
end

function DizList:Read()
  local DizData, Map = self.DizData, self.Map
  local Record = nil
  local CurDir = panel.GetPanelDirectory(nil,1).Name
  local FileList = Far.GetConfig("Descriptions.ListNames") -- via Macro API

  for str in FileList:gmatch("[^,]+") do
    local fname = win.JoinPath(CurDir, str)
    local attr = win.GetFileAttr(fname)
    if attr and not attr:find("d") then
      self.DizFileName = fname
      break
    end
  end

  if not self.DizFileName then return end
  local CodePage = far.DetectCodePage(self.DizFileName) or 65001

  local Fp = io.open(self.DizFileName)
  if not Fp then return end

  local Bom = Fp:read(#Utf8Bom)
  if Bom == Utf8Bom then
    CodePage = 65001
  else
    Fp:seek("set",0)
  end

  for line in GetString(Fp, CodePage) do
    local fname, diz = SplitDizLine(line)
    if not fname then diz = line:match('^%s(.*)') end

    if fname then
      Record = nil
      if Map[fname] == nil then -- ignore duplicate file names
        Record = { FileName=fname; Diz=diz; }
        Map[fname] = Record
        table.insert(DizData, Record)
      end
    elseif diz and Record then
      Record.Diz = Record.Diz.."\n"..diz
    else
      Record = nil
    end
  end
  Fp:close()
end

function DizList:Flush()
  if self.DizFileName == nil then
    local CurDir = panel.GetPanelDirectory(nil,1).Name
    local FileList = Far.GetConfig("Descriptions.ListNames")
    local fname = FileList:match("^[^,]+") or "Descript.ion"
    self.DizFileName = win.JoinPath(CurDir, fname)
  end

  local fp = io.open(self.DizFileName, "w")
  if not fp then
    far.Message(M.ErrOpenFile, M.Error, nil, "w")
    return
  end

  fp:write(Utf8Bom)
  for _,obj in ipairs(self.DizData) do
    if not obj.Deleted and obj.Diz:find("%S") then
      local fname = EscapeFileName(obj.FileName)
      fp:write(fname)
      for line, eol in obj.Diz:gmatch("([^\n]*)(\n?)") do
        fp:write(" ", line, "\n")
        if eol == "" then break end
      end
    end
  end
  fp:close()
end

function DizList:DescribeFiles()
  self:Read()

  local Items = {}
  local API = panel.GetPanelInfo(nil,1)

  -- collect selected items in advance to make possible unselect them one by one
  for i=1,API.SelectedItemsNumber do
    table.insert(Items, panel.GetSelectedPanelItem(nil,1,i))
  end

  for _,item in ipairs(Items) do
    local obj = self.Map[item.FileName]
    if obj == nil then
      obj = { FileName=item.FileName; Diz=""; }
      table.insert(self.DizData, obj)
      self.Map[item.FileName] = obj
    end

    local op, txt = GetDiz(obj.FileName, obj.Diz)
    if op == OP_WRITE then
      obj.Diz = txt
      self:Flush()
    elseif op == OP_DELETE then
      self.Map[obj.FileName] = nil
      obj.Deleted = true
      self:Flush()
    elseif op == OP_SKIP then -- luacheck:ignore (empty if branch)
      -- no action needed
    else
      break -- canceled by the user
    end

    Panel.Select(0,0,2,obj.FileName) -- unselect (via Macro API)
  end
end

local function main()
  M = win.GetEnv("FARLANG")=="Russian" and Rus or Eng
  local MyDizList = NewDizList()
  MyDizList:DescribeFiles()
end

Macro {
  id="2C3BDD46-C3FD-4D3D-925D-5D457497F3E2";
  description="Edit file descriptions";
  flags="NoPluginPanels";
  area="Shell"; key=MacroKey;
  action=function()
    mf.acall(main)
  end;
}
