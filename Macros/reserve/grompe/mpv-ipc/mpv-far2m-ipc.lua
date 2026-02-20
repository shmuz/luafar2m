local farpid = os.getenv("FARPID")
if farpid then
  local pipe_path = "/tmp/far2m-ipc-" .. farpid

  local function send2far(msg)
    local len = #msg
    local f = io.open(pipe_path, "wb")
    if f then
      f:write(string.char(len % 256, math.floor(len / 256)) .. msg)
      f:close()
    end
  end
  
  local function loaded()
    local path = mp.get_property("path")
    if not path then return end
    send2far("goto=" .. path)
  end

  local function selectfile()
    local path = mp.get_property("path")
    if not path then return end
    send2far("select=" .. path)
    mp.commandv('show-text', "selected", 500)
  end

  mp.register_event("file-loaded", loaded)
  mp.add_key_binding("ins", "selectfile", selectfile)
  mp.add_key_binding("kp_ins", "selectfile2", selectfile)
end
