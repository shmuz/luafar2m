-- started: 2026-05-27
-- Multi-line "Describe files" dialog

local MacroKey = "CtrlShiftZ"
-- local F = far.Flags

local OP_WRITE, OP_DELETE = 1,2
local Utf8Bom = "\239\187\191"

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
  local Prompt = ("Enter description for \"%s\":"):format(fname)
  local Items = {
    guid = "3371CF06-7F0B-45DF-8591-7CFE53E2DAC7";
    -- help = "Contents";
    -- width = 76;
    { tp="dbox"; text="Describe file"; },
    { tp="text"; text=Prompt; },
    { tp="memo"; height=5; val=diz; name="memo"; },
    { tp="sep" },
    { tp="butt"; centergroup=1; text="&1 Write";  name="write";  default=1; },
    { tp="butt"; centergroup=1; text="&2 Delete"; name="delete"; },
    { tp="butt"; centergroup=1; text="&3 Cancel"; cancel=1; },
  }

  local Dlg = sd.New(Items)
  local Pos = Dlg:Indexes()

  local out, pos = Dlg:Run()
  if pos == Pos.write or pos == Pos.delete then
    if pos == Pos.write and out.memo:find("%S") then
      return OP_WRITE, out.memo
    else
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
  local FileList = Far.GetConfig("Descriptions.ListNames")

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
    local fname, diz             = line:match('^"([^"]+)"%s+(.*)')
    if not fname then fname, diz = line:match('^(%S+)%s+(.*)') end
    if not fname then diz        = line:match('^%s+(%S.*)') end

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
    far.Message("Could not open file", "Error", nil, "w")
    return
  end

  fp:write(Utf8Bom)
  for _,obj in ipairs(self.DizData) do
    if not obj.Deleted and obj.Diz:find("%S") then
      local fname = obj.FileName
      if fname:find("%s") then
        fname = '"' ..obj.FileName.. '"'
      end
      fp:write(fname)
      for line in obj.Diz:gmatch("[^\n]+") do
        fp:write("  ", line, "\n")
      end
    end
  end
  fp:close()
end

function DizList:DescribeFiles()
  self:Read()

  local API = panel.GetPanelInfo(nil,1)
  for i=1,API.SelectedItemsNumber do
    local item = panel.GetSelectedPanelItem(nil,1,i)

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
    else -- canceled
      break
    end
  end
end

local function main()
  local MyDizList = NewDizList()
  MyDizList:DescribeFiles()
end

Macro {
  id="2C3BDD46-C3FD-4D3D-925D-5D457497F3E2";
  description="Edit file descriptions";
  flags="NoPluginPanels";
  area="Shell"; key=MacroKey;
  action=function()
    main()
  end;
}
