-- Started : 2026-10-22
-- Name    : Backup fa2m config

-- Backups are created in two types, differing only in the destination folder: Monthly and Daily.
-- A monthly backup is created once a month and is never deleted.
-- Daily backups are created once a day. The 10 most recent are kept; the rest are deleted.
-- A backup’s filename follows this format: "YYYY-MM-DD--HH-mm-SS.7z" (time: UTC).
-- Plugin ArcLite is used or 7z if ArcLite is unavailable.

local Dir_root = "/media/sf_shared_dir/far2m/Bkup/configs"
local Dir_monthly = Dir_root .. "/Monthly"
local Dir_daily = Dir_root .. "/Daily"
local Dir_source = far.InMyConfig()
local Max_daily = 10
local ArcLite = 0x65642111

if win.GetHostName() ~= "shmuel-VirtualBox" then return end -- on this computer only
if not Dir_source:find("/work/?$") then return end -- this custom config only

local function ErrMsg(msg, title)
  far.Message(msg, title or "Backup", nil, "w")
end

local function Backup(dir_target, name)
  local attr = win.GetFileAttr(dir_target)
  if attr and attr:find("d") then
    local source = win.JoinPath(Dir_source, "*")
    local target = win.JoinPath(dir_target, name)
    if far.FindPlugin("PFM_SYSID", ArcLite) then
      local ret = Plugin.SyncCall(ArcLite, "c", target, source)
      if not ret then
        ErrMsg(dir_target, "ArcLite backup failed")
      end
      return ret
    else
      local cmd = ('7z a -mx5 "%s" "%s"'):format(target, source)
      if os.execute(cmd) ~= 0 then
        ErrMsg(dir_target, "7z backup failed")
      end
    end
  else
    ErrMsg(dir_target, "Directory not found")
  end
end

local function Monthly(dir)
  local fname = os.date("!%Y-%m-%d--%H-%M-%S.7z") -- "!" for UTC time
  local found = false
  local mask = fname:sub(1,7) .. "*.7z" -- e.g. "2026-10*.7z"
  far.RecursiveSearch(dir, mask, function() found = true; return true; end)
  if not found then Backup(dir, fname) end
end

local function Daily(dir)
  local fname = os.date("!%Y-%m-%d--%H-%M-%S.7z") -- "!" for UTC time
  local files = {}
  far.RecursiveSearch(dir, "*.7z", function(item) files[#files+1]=item.FileName; end)
  table.sort(files) -- older first
  local backup_needed = files[1] == nil or files[#files]:sub(1,10) ~= fname:sub(1,10)
  if backup_needed then
    if Backup(dir, fname) then
      files[#files] = fname
    end
  end

  for n=1, #files - Max_daily do
    win.DeleteFile(win.JoinPath(dir, files[n]))
  end

end

Macro {
  id="EFA08118-E8D2-4A84-8853-AD80B054ABFA";
  description="Backup far2m config";
  area="Shell"; flags="RunAfterFARStart";
  action=function()
    Monthly(Dir_monthly)
    Daily(Dir_daily)
  end;
}
