-------------------------------------------------------------------------------
-- Набор макросов для работы со строчным комментированием в редакторе. © SimSU
-------------------------------------------------------------------------------
-- Умеет:
--   комментировать строку и выделенные строки;
--   понимает различные расширения файлов;
--   самонастраивается :)
-- Если вызвать комментирование/разкомментирование в новом(ранее не определённом расширении) файле, то
-- появится меню выбора типа(расширения) файла, в котором можно выбрать нужный тип или создать новый.
-- После этого появится диалог настройки, в котором надо задать список расширений (по правилам FAR),
-- Символы строчного комментирования которые будут вставляться в начало строки и, если хотите, комментарий.
-- Настройки можно переопределять/изменять/добавять/удалять по средствам самого макроса.

---- Настройки
local function Settings()
-- Начало файла Profile\SimSU\Editor_Remarks.cfg
return{
  KeyComment  ="CtrlShift[";     --PriorComment  =50; --SortComment  =50; -- Комментирование текущей строки или выделенного блока.
  KeyUnComment="CtrlShift]";    --PriorUnComment=50; --SortUnComment=50; -- Снятие комментирования текущей строки или выделенного блока.
  KeyOptions  ="ShiftF12"; --PriorOptions  =50; --SortOptions  =50; -- Настройка комментирования для различных типов файлов.
  KeyTab      ="Tab";      --PriorTab      =50; --SortTab      =50; -- Табулирование строк выделенного блока.
  KeyUnTab    ="ShiftTab"; --PriorUnTab    =50; --SortUnTab    =50; -- Отмена табулирования строк выделенного блока.
}
-- Конец файла Profile\SimSU\Editor_Remarks.cfg
end

-- Встроенные языки / Built-in laguages
local function Messages()
local lang = win.GetEnv("FARLANG")
if lang=="Russian" then
-- Начало файла Profile\SimSU\Editor_RemarksRussian.lng
return{
  DescrOptions="Настройка комментирования помеченного блока. © SimSU";
  DescrComment="Комментирование помеченного блока. © SimSU";
  DescrUnComment= "Разкомментирование помеченного блока. © SimSU";
  DescrTab="Табулирование строк выделенного блока. © SimSU";
  DescrUnTab= "Отмена табулирования строк выделенного блока. © SimSU";

  MenuTitle="Комментирование";
  DlgTitle="Настройка комментирования";
  Mask="&Маска файлов";
  Symbol="&Символы строчного комментирования";
  description="&Описание";
  Yes="&Да";
  No="&Нет";
  Delete="&Удалить";
}
-- Конец файла Profile\SimSU\Editor_RemarksRussian.lng
else--if far.lang=="English" then
-- Begin of file Profile\SimSU\Editor_RemarksEnglish.lng
return{
  DescrOptions="Настройка комментирования помеченного блока. © SimSU";
  DescrComment="Комментирование помеченного блока. © SimSU";
  DescrUnComment= "Разкомментирование помеченного блока. © SimSU";
  DescrTab="Табулирование строк выделенного блока. © SimSU";
  DescrUnTab= "Отмена табулирования строк выделенного блока. © SimSU";

  MenuTitle="Commenting";
  DlgTitle="Comment settings";
  Mask="&Mask of files";
  Symbol="&String comment symbols";
  description="D&escription";
  Yes="&Yes";
  No="&No";
  Delete="&Delete"
}
-- End of file Profile\SimSU\Editor_RemarksEnglish.lng
end end

--local M=(loadfile(win.GetEnv("FARPROFILE").."\\SimSU\\Editor_Remarks"..far.lang..".lng") or Messages)()
--local S=(loadfile(win.GetEnv("FARLOCALPROFILE").."\\SimSU\\Editor_Remarks.cfg") or loadfile(win.GetEnv("FARPROFILE").."\\SimSU\\Editor_Remarks.cfg") or Settings)()
local M=Messages()
local S=Settings()

local SimSU=_G.SimSU or {}
-------------------------------------------------------------------------------
local F=far.Flags
local Rem=mf.mload("SimSU","Remarks") or {}

local function Options()
-- Функция настройки символов комментирования.
  local FileName=editor.GetFileName()
  local Items,Index={},{} local Idx,item
  for Mask,Data in pairs(Rem) do
    local a=(Mask or ""):sub(1,20)..(" "):rep(20-((Mask or ""):len())).."  │  "..(Data.Desc or "")
    Items[#Items+1]={text=a}
    Index[#Index+1]=Mask
    if mf.fmatch(FileName,Mask)==1 then
      Idx=Idx or #Items
    end
  end
  Items[#Items+1]={text="                      │                     "}
  --Idx=Menu.Show(Items,M.MenuTitle,0x8+0x80,Idx)
  item,Idx=far.Menu({Title=M.MenuTitle; Flags="FMENU_AUTOHIGHLIGHT";},Items)

  local Mask; local Data={}
  if item then
    Mask=Index[Idx]
    Data=Mask and Rem[Mask] or {}
    Items={
      --[[01]]  {"DI_DOUBLEBOX", 3, 1,40,10, 0,nil,0,0,M.DlgTitle},
      --[[02]]  {"DI_TEXT",      5, 2,38, 2, 0,nil,0,0,M.Mask},
      --[[03]]  {"DI_EDIT",      5, 3,38, 3, 0,nil,0,0,Mask},
      --[[04]]  {"DI_TEXT",      5, 4,38, 4, 0,nil,0,0,M.Symbol},
      --[[05]]  {"DI_EDIT",      5, 5,38, 5, 0,nil,0,0,Data.Symb},
      --[[06]]  {"DI_TEXT",      5, 6,38, 4, 0,nil,0,0,M.description},
      --[[07]]  {"DI_EDIT",      5, 7,38, 5, 0,nil,0,0,Data.Desc},
      --[[08]]  {"DI_TEXT",      3, 8,40, 8, 0,nil,"DIF_SEPARATOR",0,nil},
      --[[09]]  {"DI_BUTTON",    0, 9, 0, 6, 0,nil,{DIF_CENTERGROUP=1},1,M.Yes},
      --[[10]]  {"DI_BUTTON",    0, 9, 0, 6, 0,nil,"DIF_CENTERGROUP",0,M.No},
      --[[11]]  {"DI_BUTTON",    0, 9, 0, 6, 0,nil,"DIF_CENTERGROUP",0,M.Delete},
    }
    local guid = win.Uuid("c3487851-e1d8-450c-b696-51ac45a46b2b")
    local result=far.Dialog(-1,-1,44,12,nil,Items)
    if result==9 then
      Mask=Items[3][10]
      Data.Symb=Items[5][10]
      Data.Desc=Items[7][10]
      if Index[Idx] then Rem[Index[Idx]]=nil end
      Rem[Mask]=Data
    elseif result==11 and Index[Idx] then
      Rem[Mask]=nil
      Data={}
    end
    mf.msave("SimSU","Remarks",Rem)
  else
    Data.Symb=nil
  end
  return Data.Symb
end

local function CommUnComm(Comm,Symb)
  local FileName=editor.GetFileName()
  if not Symb then
    for Mask in pairs(Rem) do
      if mf.fmatch(FileName,Mask)==1 then
        Symb=Rem[Mask].Symb
        break
      end
    end
  end
  if not Symb then Symb=Options() end
  local len=Symb and Symb:len()+1 or 1
  if len>1 then
    local tEdt=editor.GetInfo()
    local ID=tEdt.EditorID
    local tSel=editor.GetSelection()
    local Beg = tSel and tSel.StartLine or tEdt.CurLine
    local End = tSel and tSel.EndLine-(tSel and tSel.EndPos==0 and tSel.BlockType~=F.BTYPE_COLUMN and 1 or 0) or tEdt.CurLine
    if (tEdt.CurLine>=Beg and tEdt.CurLine<=End) or (tSel and tSel.EndPos==0 and tEdt.CurLine==tSel.EndLine) then
      editor.UndoRedo(0)
      local Str,Eol
      for i=Beg,End do
        Str,Eol=editor.GetString(i,3)
        if Comm then
          editor.SetString(i,Symb..Str,Eol)
        elseif Str:find(Symb,1,true)==1 then
          editor.SetString(i,Str:sub(len),Eol)
        end
      end
      editor.UndoRedo(1)
    end
  end
end

-------------------------------------------------------------------------------
local Editor_Remarks={
  CommUnComm = CommUnComm;
  Options    = Options   ;
}
local function filename() if Area.Editor then return CommUnComm() end end
-------------------------------------------------------------------------------
if _filename then return filename(...) end
if not Macro then return {Editor_Remarks=Editor_Remarks} end
SimSU.Editor_Remarks=Editor_Remarks; _G.SimSU=SimSU
-------------------------------------------------------------------------------

Macro {id="25cce9ac-0dcf-44af-8a4b-bb286f05276e";
  area="Editor"; key=S.KeyOptions;   priority=S.PriorOptions;   sortpriority=S.SortOptions;   description=M.DescrOptions;
  action=function() return Options() end;
}
Macro {id="05194455-816f-435b-9887-3ecd382fd699";
  area="Editor"; key=S.KeyComment;   priority=S.PriorComment;   sortpriority=S.SortComment;   description=M.DescrComment;
  action=function() return CommUnComm(true) end;
}
Macro {id="e2f89002-2a3d-48f6-ab29-59905b9446b5";
  area="Editor"; key=S.KeyUnComment; priority=S.PriorUnComment; sortpriority=S.SortUnComment; description=M.DescrUnComment;
  action=function() return CommUnComm(false) end;
}
-- Macro {id="63c9f50f-c1d9-4027-914f-49976e1e2808";
--   area="Editor"; key=S.KeyTab;       priority=S.PriorTab;       sortpriority=S.SortTab;       description=M.DescrTab;
--   condition=function() return editor.GetInfo().BlockType==F.BTYPE_STREAM end;
--   action=function() return CommUnComm(true,"\t") end;
-- }
-- Macro {id="dc7e93d1-39ac-4cee-800e-06d94e3b9ec3";
--   area="Editor"; key=S.KeyUnTab;     priority=S.PriorUnTab;     sortpriority=S.SortUnTab;     description=M.DescrUnTab;     flags="EVSelection";
--   action=function() return CommUnComm(false,"\t") end;
-- }
