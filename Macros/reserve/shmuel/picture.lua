-- luacheck: no max line length
if not jit then return end

local ffi = require("ffi")
local C   = ffi.C

local band, bor, lshift, rshift = bit.band, bit.bor, bit.lshift, bit.rshift
local ceil, floor, min = math.ceil, math.floor, math.min

local function Set(list)
  local set = {}
  for _, l in ipairs(list) do set[l] = true end
  return set
end

local F = far.Flags
local K = far.Colors

local Refresh = Set{"CtrlLeft", "CtrlRight", "CtrlUp", "CtrlDown", "CtrlClear",
                    "CtrlNum4", "CtrlNum6", "CtrlNum2", "CtrlNum8"}
local Ignore = Set{"Ctrl", "RCtrl", "Alt", "Shift", "CtrlAlt", "CtrlShift", "AltShift", }

-- From WinPort/WinCompat.h
local WP_IMG_RGBA = 0
local WP_IMG_RGB  = 1

-- ============================================================================
-- C Declarations: WinPort & Imlib2
-- ============================================================================
pcall(ffi.cdef, [[
  typedef void* HANDLE;
  typedef int BOOL;

  typedef struct _COORD {
    short X, Y;
  } COORD;

  typedef struct _SMALL_RECT {
    short Left, Top, Right, Bottom;
  } SMALL_RECT;

  typedef struct {
    uint64_t Caps;
    COORD PixPerCell;
  } WinportGraphicsInfo;

  BOOL WINPORT_GetConsoleImageCaps(HANDLE hConsoleOutput, size_t sizeof_wgi, WinportGraphicsInfo *wgi);
  BOOL WINPORT_SetConsoleImage(HANDLE hConsoleOutput, const char *id, uint64_t flags, const SMALL_RECT *area, uint32_t width, uint32_t height, const void *buffer);
  BOOL WINPORT_DeleteConsoleImage(HANDLE hConsoleOutput, const char *id);

  // Imlib2
  typedef void* Imlib_Image;
  typedef uint32_t DATA32;

  Imlib_Image imlib_load_image(const char *file);
  void imlib_free_image(void);
  void imlib_context_set_image(Imlib_Image image);
  int imlib_image_get_width(void);
  int imlib_image_get_height(void);
  Imlib_Image imlib_create_cropped_scaled_image(int src_x, int src_y, int src_w, int src_h, int dst_w, int dst_h);
  DATA32* imlib_image_get_data(void);
  DATA32* imlib_image_get_data_for_reading_only(void);
]])

local function load_lib(names)
  for _, name in ipairs(names) do
    local ok, lib = pcall(ffi.load, name)
    if ok then return lib end
  end
  error("Failed to load library: " .. table.concat(names, ", "))
end

local imlib2 = load_lib({"Imlib2", "libImlib2.so.1", "libImlib2.so"})

-- ============================================================================
-- Helper Functions & RAW/DNG Extractor
-- ============================================================================
local function getDNG(filename)
  local function intBE(b)
    local result = 0
    for _, v in ipairs(b) do
      if not v then break end
      result = result * 256 + v
    end
    return result
  end
  local result, thumbs = false, {}
  local int = function(b) return (b[1] or 0) + (b[2] or 0)*256 + (b[3] or 0)*65536 + (b[4] or 0)*16777216 end
  local fix = function(a) return a end
  local function get(file, bytes) return int({string.byte(file:read(bytes), 1, bytes)}) end
  local function get2(file) return get(file, 2) end
  local function get4(file) return get(file, 4) end
  local function parse_ifd(file, base, process)
    local entries, index = get2(file), #thumbs + 1
    thumbs[index] = {size = 0, compression = 6}
    for _ = 1, entries do
      local d = {f = file, process = process, value = thumbs[index], base = base, tag = get2(file), type = get2(file), count = get4(file), offset = get4(file)}
      process(d)
    end
  end
  local f = io.open(filename, "rb")
  if f then
    local tag = f:read(2)
    if tag == "II" or tag == "MM" then
      if tag == "MM" then
        int = intBE
        fix = function(a) return a / 65536 end
      end
      get2(f)
      while true do
        local offset = get4(f)
        if offset == 0 then break end
        f:seek('set', offset)
        parse_ifd(f, 0, function(d)
          if d.tag == 46 then d.value.data, d.value.size = (d.base + d.offset), d.count
          elseif d.tag == 259 then d.value.compression = fix(d.offset)
          elseif (d.tag == 273 or d.tag == 513) and d.offset ~= 0xffffffff then d.value.data = d.base + d.offset
          elseif d.tag == 277 then d.value.samples = fix(d.offset)
          elseif (d.tag == 279 or d.tag == 514) and d.offset > 0 then d.value.size = d.offset
          elseif d.tag == 330 then
            local size, pos = 4 * d.count, d.f:seek()
            for ii = 1, d.count do
              d.f:seek('set', d.base + d.offset + (ii - 1) * 4)
              if size > 4 then d.f:seek('set', get4(d.f)) end
              parse_ifd(d.f, d.base, d.process)
            end
            d.f:seek('set', pos)
          elseif d.tag == 50752 then d.value.raw = true end
        end)
      end
    end
    table.sort(thumbs, function(a, b) return a.size > b.size end)
    for _, v in ipairs(thumbs) do
      if v.data and not v.raw and (v.compression == 6 or (v.samples == 3 and v.compression == 7)) then
        result = far.MkTemp()
        local w = io.open(result, "wb")
        if w then
          f:seek('set', v.data)
          w:write(f:read(v.size))
          w:close()
        end
        break
      end
    end
    f:close()
  end
  return result
end

-- ============================================================================
-- Main Display Logic
-- ============================================================================
local function ShowImage(xpanel)
  local vinfo, pinfo = viewer.GetInfo(), panel.GetPanelInfo(nil, xpanel)
  if not (pinfo and vinfo and vinfo.WindowSizeX == (pinfo.PanelRect.right - pinfo.PanelRect.left - 1) and pinfo.PanelType == F.PTYPE_QVIEWPANEL) then
    return
  end

  local filename = viewer.GetFileName()
  local delete = far.ProcessName(F.PN_CMPNAMELIST, "*.dng,*.pef,*.nef,*.cr2,*.sr2,*.arw,*.orf,*.rw2,*.srw", filename, F.PN_SKIPPATH) and getDNG(filename)
  local target_path = delete or filename

  local src_img = imlib2.imlib_load_image(target_path)
  if src_img == nil then
    if delete then os.remove(delete) end
    return
  end

  imlib2.imlib_context_set_image(src_img)
  local orig_w = imlib2.imlib_image_get_width()
  local orig_h = imlib2.imlib_image_get_height()

  -- Inner panel dimensions in character cells
  local inner_x = pinfo.PanelRect.left + 1
  local inner_y = pinfo.PanelRect.top + 1
  local inner_w_cells = pinfo.PanelRect.right - pinfo.PanelRect.left - 1
  local inner_h_cells = pinfo.PanelRect.bottom - pinfo.PanelRect.top - 1

  -- Query cell pixel size
  local wgi = ffi.new("WinportGraphicsInfo")
  C.WINPORT_GetConsoleImageCaps(nil, ffi.sizeof(wgi), wgi)
  local font_w = wgi.PixPerCell.X > 0 and wgi.PixPerCell.X or 10
  local font_h = wgi.PixPerCell.Y > 0 and wgi.PixPerCell.Y or 22

  local avail_w = inner_w_cells * font_w
  local avail_h = inner_h_cells * font_h

  -- Maintain aspect ratio
  local asp_dst = avail_w / avail_h
  local asp_src = orig_w / orig_h

  local dst_w, dst_h
  if asp_dst < asp_src then
    dst_w = min(avail_w, orig_w)
    dst_h = floor(dst_w / asp_src)
  else
    dst_h = min(avail_h, orig_h)
    dst_w = floor(asp_src * dst_h)
  end

  -- Scale image using Imlib2
  local scaled_img = imlib2.imlib_create_cropped_scaled_image(0, 0, orig_w, orig_h, dst_w, dst_h)
  imlib2.imlib_free_image() -- Frees src_img

  if scaled_img == nil then
    if delete then os.remove(delete) end
    return
  end

  imlib2.imlib_context_set_image(scaled_img)
  local raw_data = imlib2.imlib_image_get_data()

  -- Convert Imlib2 DATA32 (ARGB) to RGBA in-place, compositing alpha over white
  local num_pixels = dst_w * dst_h
  local ptr = ffi.cast("uint32_t*", raw_data)
  for i = 0, num_pixels - 1 do
    local c = ptr[i]
    local a = rshift(c, 24)
    local r = band(rshift(c, 16), 0xFF)
    local g = band(rshift(c, 8), 0xFF)
    local b = band(c, 0xFF)

    if a < 255 then
      local inv_a = 255 - a
      r = floor((r * a + 255 * inv_a) / 255)
      g = floor((g * a + 255 * inv_a) / 255)
      b = floor((b * a + 255 * inv_a) / 255)
    end

    -- Pack as little-endian RGBA (Byte 0: R, Byte 1: G, Byte 2: B, Byte 3: A=255)
    ptr[i] = bor(0xFF000000, lshift(b, 16), lshift(g, 8), r)
  end

  -- Calculate centered position in character cells
  local offset_cell_x = floor((inner_w_cells - floor(dst_w / font_w)) / 2)
  local offset_cell_y = floor((inner_h_cells - floor(dst_h / font_h)) / 2)
  local start_x = inner_x + (offset_cell_x > 0 and offset_cell_x or 0)
  local start_y = inner_y + (offset_cell_y > 0 and offset_cell_y or 0)
  local area = ffi.new("SMALL_RECT", {
    Left   = start_x,
    Top    = start_y,
    Right  = start_x + (ceil(dst_w / font_w) > 0 and ceil(dst_w / font_w) - 1 or 0),
    Bottom = start_y + (ceil(dst_h / font_h) > 0 and ceil(dst_h / font_h) - 1 or 0)
  })

  -- Register image with backend (WP_IMG_RGBA = 0)
  local img_id = "far2m_qview_img"
  C.WINPORT_SetConsoleImage(nil, img_id, WP_IMG_RGBA, area, dst_w, dst_h, raw_data)

  -- Build user control and modal dialog container
  local width  = inner_w_cells
  local height = inner_h_cells
  local buffer = far.CreateUserControl(width, height)
  local color  = actl.GetColor(K.COL_PANELTEXT)
  local textel = {Char = 0x20, Attributes = color}
  for ii = 1, #buffer do buffer[ii] = textel end

  local items = {
    {"DI_DOUBLEBOX", 0, 0, width + 1, height + 1, 0, 0, 0, 0, orig_w .. " x " .. orig_h},
    {"DI_USERCONTROL", 1, 1, width, height, buffer, 0, 0, 0, ""}
  }

  local is_cur_panel = bit64.band(pinfo.Flags, F.PFLAGS_FOCUS) ~= 0
  local has_exited = false

  local function DlgProc(dlg, msg, param1, param2)
    local function CloseDialog(key)
      if key and not has_exited then
        has_exited = true
        mf.postmacro(Keys, "Esc")
        if key ~= "Esc" then
          mf.postmacro(Keys, key)
          if Refresh[key] then mf.postmacro(Keys, "CtrlR") end
        end
        return true
      end
    end

    if msg == F.DN_INITDIALOG then
      dlg:SetMouseEventNotify(1)

    elseif msg == F.DN_CTLCOLORDLGITEM and param1 == 1 then
      return {
        actl.GetColor(is_cur_panel and K.COL_PANELSELECTEDTITLE or K.COL_PANELTITLE),
        actl.GetColor(K.COL_PANELTITLE),
        actl.GetColor(K.COL_PANELTEXT)
      }

    elseif msg == F.DN_MOUSECLICK then
      local bits = param2.ButtonState % 8

      if bits == 1 then -- Left button
        if param2.MousePositionY == pinfo.PanelRect.top then
          CloseDialog("F9")
        elseif param1 == -1 then
          CloseDialog("MsLClick")
        end

      elseif bits == 2 then -- Right button
        if param1 == -1 then
          CloseDialog("MsRClick")
        end
      end

      return true

    elseif msg == F.DN_KEY then
      local name = far.KeyToName(param2)
      if not Ignore[name] then
        return CloseDialog(name)
      end

    elseif msg == F.DN_RESIZECONSOLE then
      CloseDialog("CtrlR")
    end
  end

  local dialog = far.DialogInit(
    win.Uuid("BFC62A3A-1ED5-4590-AF86-A582F6237E6F"),
    pinfo.PanelRect.left, pinfo.PanelRect.top,
    pinfo.PanelRect.right, pinfo.PanelRect.bottom,
    nil, items, F.FDLG_NODRAWSHADOW, DlgProc
  )

  far.DialogRun(dialog)
  far.DialogFree(dialog)

  -- Cleanup image and temporary files
  C.WINPORT_DeleteConsoleImage(nil, img_id)
  imlib2.imlib_context_set_image(scaled_img)
  imlib2.imlib_free_image()
  if delete then os.remove(delete) end
end

-- ============================================================================
-- Events
-- ============================================================================
Event
{
  group = "ViewerEvent";
  action = function(id, event, param)
    if event == F.VE_READ then
      mf.postmacro(
        function()
          local xpanel = 0
          if actl.GetWindowType().Type == F.WTYPE_PANELS then
            if panel.GetPanelInfo(nil, 0).PanelType == F.PTYPE_INFOPANEL then return end
            local type = panel.GetPanelInfo(nil, 1).PanelType
            if type == F.PTYPE_INFOPANEL then return end
            if type == F.PTYPE_QVIEWPANEL then xpanel = 1 end
            for ii = 0, 1 do panel.RedrawPanel(nil, ii) end
          end
          ShowImage(xpanel)
        end)
    end
  end
}
