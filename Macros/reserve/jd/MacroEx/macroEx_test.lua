local Info = Info or package.loaded.regscript or function(...) return ... end --luacheck: ignore 113/Info
local nfo = Info { _filename or ...,
  name        = "macroEx test";
  description = "sample macros to test MacroEx";
  version     = "3"; --http://semver.org/lang/ru/
  author      = "jd";
  url         = "http://forum.farmanager.com/viewtopic.php?f=15&t=8764";
  id          = "931E8931-11D0-4FD9-B493-657898578F1B";
  parent_id   = "115C9534-8273-4F5A-94EB-E321D6DC8618";
  --disabled    = true;
}
if not nfo or nfo.disabled then return end

Macro {
  description="test";
  area="Editor"; key="CtrlF9";
  action=function()
    far.Message"plain macro"
  end
}

for _,k in ipairs {
  "CtrlF9:Hold","CtrlF9:Double",
  "ShiftF8-F8",
  "CtrlF8-F9",
  "AltF1:Hold",
  "CtrlAltF1:Hold",
  "RCtrlRAltF2:Hold",
  "LCtrlLAltF2:Hold",
  "ShiftF1:Hold",
  "^:Hold","::Double",
  --"qwerty-0",--error
  "CtrlAlt:Hold","CtrlAlt:Double",
  "CtrlAlt-F8","CtrlF8-Alt",

  } do

  Macro {
    area="Editor";
    key=k;
    description=k;
    action=function() 
      far.Message(k)
    end
  }
end

Macro {
  description="CtrlF9:Double (Common)";
  area="Common"; key="CtrlF9:Double"; priority=40;
  action=function()
    far.Message"CtrlF9:Double (Common)"
  end;
}
