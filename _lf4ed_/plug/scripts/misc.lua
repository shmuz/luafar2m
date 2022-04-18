local F = far.Flags

local function InsertTimestamp()
  local ar = far.MacroGetArea()
  if ar~=F.MACROAREA_SHELL and ar~=F.MACROAREA_DIALOG and ar~=F.MACROAREA_EDITOR
    then return; end
  local items = {
      { Pat="%Y-%m-%d"            },
      { Pat="%Y-%m-%d, %a"        },
      { Pat="%Y-%m-%d %H:%M"      },
      { Pat="%Y-%m-%d %H:%M:%S"   },
      { Pat="[%Y-%m-%d]"          },
      { Pat="[%Y-%m-%d, %a]"      },
      { Pat="[%Y-%m-%d %H:%M]"    },
      { Pat="[%Y-%m-%d %H:%M:%S]" },
    }
  for i,v in ipairs(items) do v.text="&"..i..". "..os.date(v.Pat) end
  local item = far.Menu({Title="Insert Timestamp"}, items)
  if not item then return end
  local s = ( [[
    %%ts = %q;
    %%comment = "far.Guids.MakeFolderId";
    $If (Dialog && Dlg.Info.Id == "{FAD00DBE-3FFF-4095-9232-E1CC70C67737}")
      %%ts = replace(%%ts, ":", "-");
    $End
    print(%%ts) ]] ):format(os.date(item.Pat))
  far.MacroPost(s)
end

-- assuming "Show directories first" option is set
-- description="Find an upper non-directory item";
-- area="Shell"; key="CtrlShiftHome";
local function JumpToNonDir()
  local pInfo = panel.GetPanelInfo(1)
  if pInfo then
    local lower, upper = 1, pInfo.ItemsNumber
    while upper-lower >= 2 do -- binary search
      local curr = math.floor((lower+upper)/2)
      local item = panel.GetPanelItem(1,curr)
      if item.FileAttributes:find("d") then lower = curr
      else upper = curr
      end
    end
    panel.RedrawPanel(1,{ CurrentItem=upper; TopPanelItem=upper-8; })
  end
end

AddCommand("timestamp", InsertTimestamp)
AddCommand("JumpToNonDir", JumpToNonDir)
