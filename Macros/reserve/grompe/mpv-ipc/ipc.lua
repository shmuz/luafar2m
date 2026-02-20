local ffi = require("ffi")

ffi.cdef[[
  int open(const char *path, int flags);
  int read(int fd, void *buf, size_t count);
  int close(int fd);
  int mkfifo(const char *pathname, unsigned int mode);
]]

local function goto_file(path)
  local dir = path:match("(.*)/")
  local file = path:match(".*/(.*)") or path
  if dir and APanel.Path ~= dir then
    Panel.SetPath(0, dir)
  end
  Panel.SetPos(0, file)
  --panel.UpdatePanel(0) -- doesn't seem necessary
end

local cmd_table = {
  select = function(v)
    goto_file(v)
    Panel.Select(0, 2, 1) -- 2 = toggle
  end,
  goto = function(v)
    goto_file(v)
  end,
}

local function processcmd(cmd)
  local k, v = cmd:match("([^=]+)=(.*)")
  if not k then k = cmd end
  if cmd_table[k] then cmd_table[k](v) end
end

local O_RDONLY = 0
local O_NONBLOCK = 2048
local pipe_path = "/tmp/far2m-ipc-" .. os.getenv("FARPID")

ffi.C.mkfifo(pipe_path, tonumber(600, 8))
local fd = ffi.C.open(pipe_path, O_RDONLY + O_NONBLOCK)
local buffer = ffi.new("unsigned char[65536]")

local function checkinput()
  while true do
    local bytes = ffi.C.read(fd, buffer, 2)
    if bytes < 2 then return end
    local msglen = buffer[0] + buffer[1] * 256
    if msglen >= 65534 then -- ignore message that's too large
      repeat
        local ignoredbytes = ffi.C.read(fd, buffer, 65536)
      until ignoredbytes < 65536
      return
    end
    local bytes = ffi.C.read(fd, buffer, msglen)
    if bytes < msglen then return end -- ignore message that's incomplete

    local cmd = ffi.string(buffer, bytes)
    processcmd(cmd)
  end
end

local timer = far.Timer(2000, checkinput)
local last_run = 0

Event {
  group="ConsoleInput"; -- fires also on window activation or mouse over
  action=function()
    local now = os.time()
    if now - last_run >= 2 then
      last_run = now
      checkinput()
    end
  end;
}

Event {
  group = "ExitFar",
  action = function()
    if fd >= 0 then
      ffi.C.close(fd)
      os.remove(pipe_path)
    end
    if timer then
      timer:Close()
    end
  end
}
