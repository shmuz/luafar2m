-- Author           : Vadim Yegorov (zg)
-- Original URL     : https://github.com/trexinc/evil-programmers/tree/master/LuaCustomFolderState
-- Modifications by : Shmuel Zeigerman
-- Portable         : far3 and far2m

res,init=pcall require,"customfolderstate_user"
if not res then init={}
F=far.Flags
insert=table.insert

dirsep=package.config\sub 1,1
osWin=dirsep=='\\'
zeroId=osWin and (string.rep '\0',16) or 0

normPluginId=(id)->
  if osWin then id and (36==id\len!) and (win.Uuid id) or zeroId
  else id or zeroId

expandrnv=(str)->
  str\gsub (osWin and "%%(.-)%%" or "%$%{(.-)%}"),win.GetEnv

class Panel
  new: (panel)=>
    with panel
      @Name=osWin and .Name\lower! or .Name
      @Param=.Param
      @PluginId=.PluginId
      @File=osWin and .File\lower! or .File
      @Sort=.Sort
      @Order=.Order
      @Action=.Action
    @Special=false
  __eq: (a,b)->
    cmp=(a,b)->
      parent=a.Name\match('(.*)'..dirsep..'%*$')
      parent and parent==b.Name\sub 1,parent\len!
    (a.Name==b.Name or (cmp a,b) or (cmp b,a)) and a.Param==b.Param and a.PluginId==b.PluginId and a.File==b.File

active,passive=1,0
empty={Name:'',File:''}

panels=()->
  {[active]:(Panel panel.GetPanelDirectory nil,active),[passive]:Panel panel.GetPanelDirectory nil,passive}

last=
  [active]:Panel empty
  [passive]:Panel empty
folders={}

setpanelstate=(idx,sort,order)->
  info=panel.GetPanelInfo nil,idx
  top=info and info.TopPanelItem
  if (type sort)=="number" and sort>=F.SM_USER
    -- use _G, as the name "Panel" is taken by this script
    _G.Panel.SetCustomSortMode sort,1-idx,sort==info.SortMode and "current" or "auto"
  else
    panel.SetSortMode nil,idx,sort
    panel.SetSortOrder nil,idx,order
  if top
    info=panel.GetPanelInfo nil,idx
    if info and info.CurrentItem
      panel.RedrawPanel nil,idx,{CurrentItem:info.CurrentItem,TopPanelItem:top}

process=(idx,current)->
  found=false
  for folder in *folders
    if current==folder
      found=folder
      break
  if last[idx].Special
    current.Sort=last[idx].Sort
    current.Order=last[idx].Order
  else
    info=panel.GetPanelInfo nil,idx
    if info
      current.Sort=info.SortMode
      current.Order=(bit64.band info.Flags,F.PFLAGS_REVERSESORTORDER)==F.PFLAGS_REVERSESORTORDER
  sort,order=current.Sort,current.Order
  if found and found.Sort
    with found
      sort=.Sort
      order=.Order
    current.Special=true
  setpanelstate idx,sort,order
  if current.Special or current.PluginId == zeroId
    last[idx]=current
  func=found and found.Action or not found and folders.Action
  if 'function'==type func
    func idx,{Name:current.Name,Param:current.Param,PluginId:current.PluginId,File:current.File}

folders.Action=init.Action
for folder in *init
  switch type folder
    when 'string'
      folder=
        Name:folder
        PluginId:zeroId
    when 'table'
      nil
    else
      folder={}
  with folder
    if .Name and .Name!=''
      isset=(v,d)->if nil==v then d else v
      .Name=expandrnv .Name
      .Param=.Param or ''
      .PluginId=normPluginId .PluginId
      .File=expandrnv (.File or '')
      .Sort=isset .Sort,init.Sort
      .Order=isset .Order,init.Order
      insert folders,Panel folder

main=()->
  current=panels!
  if current[active]==last[passive] and current[passive]==last[active]
    last[active],last[passive]=last[passive],last[active]
  else
    for ii in *{active,passive}
      if last[ii]!=current[ii]
        process ii,current[ii]
main!
Event
  group:"FolderChanged"
  action:main
Event
  group:"ExitFAR"
  action:()->
    for ii in *{active,passive}
      if last[ii].Special
        setpanelstate ii,last[ii].Sort,last[ii].Order
